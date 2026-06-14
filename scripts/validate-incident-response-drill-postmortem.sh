#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}

DOC_PATH="${INCIDENT_RESPONSE_DRILL_POSTMORTEM_PATH:-docs/operations/incident-response-drill-postmortem-2026-06-14.md}"

[[ -f "$DOC_PATH" ]] || fail "missing file: $DOC_PATH"

for term in \
  "incident response drill" \
  "postmortem exercise" \
  "detection input" \
  "severity declaration" \
  "commander assignment" \
  "communication timeline" \
  "mitigation decision" \
  "rollback or recovery decision" \
  "alert routing decision" \
  "validation output" \
  "approval-gate status" \
  "cleanup receipt" \
  "postmortem evidence" \
  "residual risk" \
  "next action"; do
  grep -Fqi -- "$term" "$DOC_PATH" || fail "missing text in $DOC_PATH: $term"
done

command -v python3 >/dev/null || fail "missing command: python3"

python3 - "$DOC_PATH" <<'PY'
from __future__ import annotations

import copy
import json
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

START = "<!-- incident-response-drill-postmortem:begin -->"
END = "<!-- incident-response-drill-postmortem:end -->"
REQUIRED = [
    "version",
    "exerciseId",
    "issueUrl",
    "date",
    "permissionLevel",
    "sourceRunbook",
    "sourceBaselines",
    "detectionInput",
    "severityDeclaration",
    "commanderAssignment",
    "communicationTimeline",
    "mitigationDecision",
    "rollbackOrRecoveryDecision",
    "alertRoutingDecision",
    "validationOutput",
    "postmortemEvidence",
    "approvalGateStatus",
    "cleanupReceipt",
    "residualRisk",
    "nextAction",
    "followUpIssueUrl",
]
BASELINES = [
    "docs/operations/sre-operating-baseline.md",
    "docs/operations/on-call-paging-alerting.md",
]
COMMANDS = [
    "validate-incident-response-drill-postmortem.sh",
    "validate-incident-response-runbook.sh",
    "validate-sre-operating-baseline.sh",
    "validate-on-call-paging-alerting.sh",
    "validate-readiness-criteria.sh",
    "validate-contract-docs.sh",
]
TIMELINE_EVENTS = [
    "detection",
    "severity declaration",
    "commander assignment",
    "mitigation decision",
    "alert routing decision",
    "rollback or recovery decision",
    "validation",
    "postmortem complete",
    "closeout",
]
HOME_SEGMENT = "/" + "home" + "/"
USERS_SEGMENT = "/" + "Users" + "/"
PRIVATE_PATH_RE = re.compile(
    r"(" + re.escape(HOME_SEGMENT) + "|" + re.escape(USERS_SEGMENT) + r")[^\s`'\"]+",
    re.IGNORECASE,
)
SECRET_TERMS = ["cookie=", "private_key=", "sec" + "ret=", "to" + "ken=", "authorization: bearer"]
SECRET_PATTERNS = [
    ("github classic access key", r"\bgh[pousr]_[A-Za-z0-9_]{16,}\b"),
    ("github fine-grained access key", r"\bgithub_pat_[A-Za-z0-9_]{20,}\b"),
    ("cloud access key", r"\bA[KS]IA[A-Z0-9]{16}\b"),
]
UNSAFE_PATTERNS = [
    r"\bproduction\s+(deploy|deployment|release|rollback|write)\s+(succeeded|completed|executed|started)\b",
    r"\bdocker\s+(compose\s+)?(up|run|start|started|created|executed|completed)\b",
    r"\bkubectl\s+(apply|create|delete|rollout|scale|set|patch)\b",
    r"\bremote\s+host\s+(was\s+)?(changed|updated|mutated|configured|restarted)\b",
    r"\bworker\s+dispatch\s+(was\s+)?(completed|started|executed|launched)\b",
    r"\bgithub\s+project\s+(setting|settings|field|fields|schema|control-plane)\s+(was\s+)?(changed|updated|mutated|created|deleted|completed)\b",
    r"\bcredential\s+(used|issued|granted|exported|rotated)\b",
    r"\binfrastructure\s+(mutated|changed|updated|created|deleted)\b",
    r"\bdeploy(ment)?\s+(can|may|will)\s+proceed\b",
    r"\bcredentials?\s+(are|is)?\s*authorized\b",
]


class DrillError(Exception):
    pass


def reject(message: str) -> None:
    raise DrillError(message)


def flatten(value: Any) -> list[str]:
    if isinstance(value, str):
        return [value]
    if isinstance(value, list):
        return [item for child in value for item in flatten(child)]
    if isinstance(value, dict):
        return [item for child in value.values() for item in flatten(child)]
    return []


def require_safe(value: Any) -> None:
    text = "\n".join(flatten(value))
    lowered = text.lower()
    for term in SECRET_TERMS:
        if term in lowered:
            reject(f"secret-bearing wording: {term}")
    for name, pattern in SECRET_PATTERNS:
        if re.search(pattern, text):
            reject(f"secret-like pattern: {name}")
    for pattern in UNSAFE_PATTERNS:
        if re.search(pattern, text, re.IGNORECASE):
            reject(f"unsafe mutation wording: {pattern}")
    if PRIVATE_PATH_RE.search(text):
        reject("private local path retained")


def extract(text: str) -> dict[str, Any]:
    if not text.strip():
        reject("empty incident drill content")
    if text.count(START) != 1 or text.count(END) != 1:
        reject("missing or duplicate incident drill block")
    block = text.split(START, 1)[1].split(END, 1)[0].strip()
    if block.startswith("```json"):
        block = block.removeprefix("```json").strip()
    if block.endswith("```"):
        block = block[:-3].strip()
    try:
        payload = json.loads(block)
    except json.JSONDecodeError as exc:
        reject(f"malformed incident drill data: {exc}")
    if not isinstance(payload, dict):
        reject("incident drill block must be an object")
    return payload


def text(value: Any, label: str) -> str:
    if not isinstance(value, str) or not value.strip():
        reject(f"missing {label}")
    return value


def require_dict(value: Any, label: str) -> dict[str, Any]:
    if not isinstance(value, dict) or not value:
        reject(f"missing {label}")
    return value


def require_list(value: Any, label: str, min_items: int = 1) -> list[Any]:
    if not isinstance(value, list) or len(value) < min_items:
        reject(f"missing {label}")
    return value


def require_timestamp(value: Any, label: str) -> datetime:
    raw = text(value, label)
    try:
        return datetime.fromisoformat(raw.replace("Z", "+00:00"))
    except ValueError:
        reject(f"invalid {label}")


def validate(payload: dict[str, Any]) -> None:
    for field in REQUIRED:
        if field not in payload or payload[field] in ("", [], {}):
            reject(f"missing {field}")
    if payload["version"] != 1:
        reject("version must be 1")
    if payload["issueUrl"] != "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/78":
        reject("issueUrl must point to issue #78")
    if payload["permissionLevel"] != "approved-docs-only-local-drill":
        reject("permissionLevel must remain approved-docs-only-local-drill")
    if payload["sourceRunbook"] != "docs/operations/incident-response-runbook-2026-06-13.md":
        reject("sourceRunbook mismatch")
    if require_list(payload["sourceBaselines"], "source baselines", 2) != BASELINES:
        reject("source baselines mismatch")

    detection = require_dict(payload["detectionInput"], "detection input")
    for field in ["source", "signal", "observedAt", "validationSignal"]:
        text(detection.get(field), f"detection input {field}")
    require_timestamp(detection["observedAt"], "detection input observedAt")

    severity = require_dict(payload["severityDeclaration"], "severity declaration")
    if severity.get("severity") not in {"SEV0", "SEV1", "SEV2", "SEV3"}:
        reject("severity declaration must use severity model")
    require_timestamp(severity.get("declaredAt"), "severity declaration declaredAt")
    text(severity.get("rationale"), "severity declaration rationale")

    commander = require_dict(payload["commanderAssignment"], "commander assignment")
    for field in ["role", "assignedBy"]:
        text(commander.get(field), f"commander assignment {field}")
    duties = require_list(commander.get("duties"), "commander duties", 4)
    if any(not isinstance(item, str) or not item.strip() for item in duties):
        reject("missing commander duty item")

    timeline = require_list(payload["communicationTimeline"], "communication timeline", len(TIMELINE_EVENTS))
    seen = []
    previous: datetime | None = None
    for item in timeline:
        entry = require_dict(item, "communication timeline item")
        event = text(entry.get("event"), "communication timeline event")
        at = require_timestamp(entry.get("at"), "communication timeline timestamp")
        text(entry.get("actor"), "communication timeline actor")
        text(entry.get("evidence"), "communication timeline evidence")
        if previous is not None and at < previous:
            reject("communication timeline must be ordered")
        previous = at
        seen.append(event)
    if seen != TIMELINE_EVENTS:
        reject("communication timeline must contain required ordered events")

    mitigation = require_dict(payload["mitigationDecision"], "mitigation decision")
    for field in ["decision", "owner", "rationale"]:
        text(mitigation.get(field), f"mitigation decision {field}")
    if mitigation.get("unsafeDispatchFrozen") is not True:
        reject("mitigation decision must freeze unsafe dispatch")

    recovery = require_dict(payload["rollbackOrRecoveryDecision"], "rollback or recovery decision")
    for field in ["decision", "recoveryPath", "operator", "evidence"]:
        text(recovery.get(field), f"rollback or recovery decision {field}")

    routing = require_dict(payload["alertRoutingDecision"], "alert routing decision")
    for field in ["status", "route", "pagingBackend", "nextEscalation"]:
        text(routing.get(field), f"alert routing decision {field}")

    validation = require_list(payload["validationOutput"], "validation output", len(COMMANDS))
    for command in COMMANDS:
        expected = f"bash scripts/{command}: PASS"
        if expected not in validation:
            reject(f"validation output missing {expected}")
    if any("FAIL" in str(item) or "not run" in str(item).lower() for item in validation):
        reject("validation output contains non-passing marker")

    postmortem = require_dict(payload["postmortemEvidence"], "postmortem evidence")
    for field in [
        "impact",
        "rootCause",
        "contributingFactors",
        "mitigationAndRecovery",
        "validationCommands",
        "evidenceLinks",
        "followUpOwner",
        "residualRisk",
        "actionItems",
    ]:
        if field not in postmortem or postmortem[field] in ("", [], {}):
            reject(f"missing postmortem evidence {field}")
    require_list(postmortem["contributingFactors"], "postmortem contributing factors", 3)
    if require_list(postmortem["validationCommands"], "postmortem validation commands", len(COMMANDS)) != [
        f"bash scripts/{command}" for command in COMMANDS
    ]:
        reject("postmortem validation commands mismatch")
    require_list(postmortem["evidenceLinks"], "postmortem evidence links", 3)
    actions = require_list(postmortem["actionItems"], "postmortem action items", 2)
    for item in actions:
        action = require_dict(item, "postmortem action item")
        for field in ["owner", "issue", "action"]:
            text(action.get(field), f"postmortem action item {field}")

    approval = text(payload["approvalGateStatus"], "approval-gate status").lower()
    for term in ["closed", "no sandbox", "worker", "credential", "infrastructure", "docker", "kubernetes", "remote host", "deployment", "production", "github project control-plane mutation"]:
        if term not in approval:
            reject(f"approval-gate status missing {term}")
    cleanup = require_dict(payload["cleanupReceipt"], "cleanup receipt")
    if cleanup.get("status") != "complete":
        reject("cleanup receipt must be complete")
    text(cleanup.get("receipt"), "cleanup receipt")
    text(cleanup.get("retainedEvidence"), "cleanup retained evidence")
    require_list(payload["residualRisk"], "residual risk", 3)
    text(payload["nextAction"], "next action")
    if payload["followUpIssueUrl"] != "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/82":
        reject("followUpIssueUrl must point to issue #82")
    require_safe(payload)


def expect_reject(label: str, candidate: dict[str, Any] | str) -> None:
    try:
        if isinstance(candidate, str):
            validate(extract(candidate))
        else:
            validate(candidate)
    except DrillError:
        return
    reject(f"negative fixture unexpectedly passed: {label}")


doc = Path(sys.argv[1])
payload = extract(doc.read_text(encoding="utf-8"))
validate(payload)

expect_reject("empty content", "")
expect_reject("malformed drill data", START + "\n```json\n{\"version\": \n```\n" + END)
for field in REQUIRED:
    mutated = copy.deepcopy(payload)
    mutated[field] = []
    expect_reject(f"missing {field}", mutated)

mutated = copy.deepcopy(payload)
mutated["detectionInput"]["signal"] = ""
expect_reject("missing detection input", mutated)

mutated = copy.deepcopy(payload)
mutated["severityDeclaration"]["severity"] = "LOW"
expect_reject("missing severity declaration", mutated)

mutated = copy.deepcopy(payload)
mutated["commanderAssignment"]["role"] = ""
expect_reject("missing commander assignment", mutated)

mutated = copy.deepcopy(payload)
mutated["communicationTimeline"] = mutated["communicationTimeline"][:-1]
expect_reject("missing communication timeline", mutated)

mutated = copy.deepcopy(payload)
mutated["mitigationDecision"]["unsafeDispatchFrozen"] = False
expect_reject("missing mitigation decision", mutated)

mutated = copy.deepcopy(payload)
mutated["rollbackOrRecoveryDecision"]["decision"] = ""
expect_reject("missing rollback or recovery decision", mutated)

mutated = copy.deepcopy(payload)
mutated["alertRoutingDecision"]["route"] = ""
expect_reject("missing alert routing decision", mutated)

mutated = copy.deepcopy(payload)
mutated["validationOutput"] = payload["validationOutput"][:-1]
expect_reject("missing validation output", mutated)

mutated = copy.deepcopy(payload)
mutated["postmortemEvidence"]["rootCause"] = ""
expect_reject("missing postmortem evidence", mutated)

mutated = copy.deepcopy(payload)
mutated["approvalGateStatus"] = "production deployment completed"
expect_reject("unsafe approval-gate status", mutated)

mutated = copy.deepcopy(payload)
mutated["cleanupReceipt"]["status"] = "pending"
expect_reject("missing cleanup receipt", mutated)

mutated = copy.deepcopy(payload)
mutated["nextAction"] = HOME_SEGMENT + "operator/private"
expect_reject("private local path", mutated)

mutated = copy.deepcopy(payload)
mutated["postmortemEvidence"]["residualRisk"] = "to" + "ken=example"
expect_reject("secret-like evidence", mutated)

print("PASS Dokkaebi incident response drill postmortem validation passed")
PY
