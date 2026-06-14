#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}

DOC_PATH="${SANDBOX_ISSUE_PROCESSING_TRANSCRIPT_PATH:-docs/operations/sandbox-issue-processing-transcript-2026-06-14.md}"

[[ -f "$DOC_PATH" ]] || fail "missing file: $DOC_PATH"

for term in \
  "Sandbox Issue Processing Transcript" \
  "discovery" \
  "admission" \
  "dispatch readiness" \
  "Worker result evidence" \
  "Manager review" \
  "closeout" \
  "approval-gate status" \
  "authority boundary" \
  "private Manager memory"; do
  grep -Fqi -- "$term" "$DOC_PATH" || fail "missing text in $DOC_PATH: $term"
done

command -v python3 >/dev/null || fail "missing command: python3"

python3 - "$DOC_PATH" <<'PY'
from __future__ import annotations

import copy
import json
import re
import sys
from pathlib import Path
from typing import Any

START = "<!-- sandbox-issue-processing-transcript:begin -->"
END = "<!-- sandbox-issue-processing-transcript:end -->"
REQUIRED_PHASES = [
    "discovery",
    "admission",
    "dispatch_readiness",
    "worker_result_evidence",
    "manager_review",
    "closeout",
]
REQUIRED_BLOCKED = {
    "live worker mutation",
    "Docker mutation",
    "Kubernetes mutation",
    "remote host mutation",
    "credential expansion",
    "production write",
    "deployment",
    "GitHub Project control-plane mutation",
}
REQUIRED_COMMANDS = {
    "bash scripts/validate-sandbox-issue-processing-transcript.sh",
    "bash scripts/validate-readiness-criteria.sh",
    "bash scripts/validate-contract-docs.sh",
}
HOME_SEGMENT = "/" + "home" + "/"
USERS_SEGMENT = "/" + "Users" + "/"
PRIVATE_PATH_RE = re.compile(r"(" + re.escape(HOME_SEGMENT) + "|" + re.escape(USERS_SEGMENT) + r")[^\s`'\"]+")
INTERNAL_LABELS = ["".join(parts) for parts in [("o", "mo"), ("o", "mx"), ("u", "lw")]]
INTERNAL_LABEL_RE = re.compile(r"\b(" + "|".join(INTERNAL_LABELS) + r")\b", re.IGNORECASE)
SECRET_TERMS = ["cookie=", "private_key=", "secret=", "token=", "authorization: bearer"]
UNSAFE_PHRASES = [
    "live worker mutation completed",
    "docker mutation completed",
    "kubernetes mutation completed",
    "remote host mutation completed",
    "credential copied",
    "production write completed",
    "deployment executed",
    "github project control-plane mutation completed",
]


class TranscriptError(Exception):
    pass


def reject(message: str) -> None:
    raise TranscriptError(message)


def extract_payload(text: str) -> dict[str, Any]:
    if not text.strip():
        reject("empty sandbox issue processing transcript")
    if text.count(START) != 1 or text.count(END) != 1:
        reject("missing or duplicate sandbox issue processing transcript block")
    block = text.split(START, 1)[1].split(END, 1)[0].strip()
    if block.startswith("```json"):
        block = block.removeprefix("```json").strip()
    if block.endswith("```"):
        block = block[: -len("```")].strip()
    try:
        payload = json.loads(block)
    except json.JSONDecodeError as exc:
        reject(f"malformed sandbox transcript data: {exc}")
    if not isinstance(payload, dict):
        reject("sandbox transcript block must be an object")
    return payload


def require_text(value: Any, label: str, terms: list[str] | None = None) -> str:
    if not isinstance(value, str) or not value.strip():
        reject(f"missing {label}")
    lowered = value.lower()
    for term in terms or []:
        if term.lower() not in lowered:
            reject(f"{label} missing {term}")
    return value


def require_dict(value: Any, label: str) -> dict[str, Any]:
    if not isinstance(value, dict) or not value:
        reject(f"missing {label}")
    return value


def require_list(value: Any, label: str, min_items: int = 1) -> list[Any]:
    if not isinstance(value, list) or len(value) < min_items:
        reject(f"missing {label}")
    return value


def flatten(value: Any) -> list[str]:
    if isinstance(value, str):
        return [value]
    if isinstance(value, list):
        return [item for child in value for item in flatten(child)]
    if isinstance(value, dict):
        return [item for child in value.values() for item in flatten(child)]
    return []


def require_safe_text(payload: dict[str, Any]) -> None:
    original = "\n".join(flatten(payload))
    lowered = original.lower()
    for term in SECRET_TERMS:
        if term in lowered:
            reject(f"secret-bearing wording: {term}")
    for phrase in UNSAFE_PHRASES:
        if phrase in lowered:
            reject(f"unsafe authority wording: {phrase}")
    if PRIVATE_PATH_RE.search(original):
        reject("private local path retained")
    if INTERNAL_LABEL_RE.search(lowered):
        reject("private execution label retained")


def validate_payload(payload: dict[str, Any]) -> None:
    if payload.get("version") != 1:
        reject("version must be 1")
    require_text(payload.get("date"), "date")
    require_text(payload.get("permissionLevel"), "permission level", ["local", "sandbox", "validation"])

    boundary = require_text(payload.get("approvalBoundary"), "approval boundary")
    for term in [
        "read-only issue inspection",
        "repository-local replay",
        "local validation",
        "does not authorize",
        "live worker",
        "docker",
        "kubernetes",
        "remote host",
        "credential",
        "production",
        "deployment",
        "github project control-plane mutation",
        "explicit human approval",
    ]:
        if term not in boundary.lower():
            reject(f"approval boundary missing {term}")

    target = require_dict(payload.get("sandboxTarget"), "sandbox target")
    require_text(target.get("id"), "sandbox target id")
    require_text(target.get("type"), "sandbox target type", ["repository-local"])
    require_text(target.get("approvalStatus"), "sandbox target approval status", ["local replay", "blocked"])
    allowed = " ".join(str(item).lower() for item in require_list(target.get("allowedOperations"), "allowed operations", 4))
    for term in ["read-only", "repository-local", "local deterministic validation", "pull request"]:
        if term not in allowed:
            reject(f"allowed operations missing {term}")
    blocked = set(str(item) for item in require_list(target.get("blockedOperations"), "blocked operations", 8))
    if blocked != REQUIRED_BLOCKED:
        reject("blocked operations mismatch")

    issue = require_dict(payload.get("issue"), "issue")
    if issue.get("number") != 44:
        reject("issue number must be 44")
    require_text(issue.get("title"), "issue title", ["sandbox issue processing transcript"])
    require_text(issue.get("url"), "issue url", ["https://github.com/TwoTwo-me/Project_Dokkaebi/issues/44"])
    require_text(issue.get("sourceOfTruth"), "source of truth", ["GitHub issue", "transcript"])

    phases = require_list(payload.get("lifecyclePhases"), "lifecycle phases", len(REQUIRED_PHASES))
    phase_ids = [item.get("id") for item in phases if isinstance(item, dict)]
    if phase_ids != REQUIRED_PHASES:
        reject("lifecycle phases must appear in required order")
    for phase in phases:
        phase_id = phase.get("id", "<missing>")
        require_text(phase.get("status"), f"{phase_id} status")
        require_text(phase.get("operation"), f"{phase_id} operation")
        require_list(phase.get("evidence"), f"{phase_id} evidence", 2)
        gate = require_text(phase.get("approvalGateStatus"), f"{phase_id} approval-gate status")
        boundary_text = require_text(phase.get("authorityBoundary"), f"{phase_id} authority boundary")
        if "approval" not in gate.lower() and "allowed" not in gate.lower() and "blocked" not in gate.lower():
            reject(f"{phase_id} approval-gate status must be explicit")
        if not any(term in boundary_text.lower() for term in ["credential", "worker", "project", "production", "deployment", "remote"]):
            reject(f"{phase_id} authority boundary must name a constrained surface")

    replay = " ".join(str(item) for item in require_list(payload.get("replayInstructions"), "replay instructions", 4))
    for term in ["issue #44", "validate-sandbox-issue-processing-transcript", "validate-readiness-criteria", "validate-contract-docs"]:
        if term not in replay:
            reject(f"replay instructions missing {term}")

    commands = set(str(item) for item in require_list(payload.get("validationCommands"), "validation commands", 3))
    if not REQUIRED_COMMANDS.issubset(commands):
        reject("validation commands missing required checks")

    require_text(payload.get("cleanupReceipt"), "cleanup receipt", ["No long-running", "in-memory"])
    require_text(payload.get("privateMemoryPolicy"), "private memory policy", ["private Manager memory", "not sufficient"])
    residual = " ".join(str(item).lower() for item in require_list(payload.get("residualRisk"), "residual risk", 2))
    for term in ["repository-local sandbox", "live worker", "github project"]:
        if term not in residual:
            reject(f"residual risk missing {term}")
    require_text(payload.get("nextAction"), "next action")
    require_safe_text(payload)


def expect_reject(label: str, candidate: dict[str, Any] | str) -> None:
    try:
        if isinstance(candidate, str):
            validate_payload(extract_payload(candidate))
        else:
            validate_payload(candidate)
    except TranscriptError:
        return
    reject(f"negative fixture unexpectedly passed: {label}")


doc = Path(sys.argv[1])
payload = extract_payload(doc.read_text(encoding="utf-8"))
validate_payload(payload)

expect_reject("empty doc", "")
expect_reject("malformed json", START + "\n```json\n{\"version\": \n```\n" + END)

for field in ["sandboxTarget", "issue", "lifecyclePhases", "replayInstructions", "validationCommands", "approvalBoundary"]:
    mutated = copy.deepcopy(payload)
    mutated[field] = [] if field in {"lifecyclePhases", "replayInstructions", "validationCommands"} else {}
    expect_reject(f"missing {field}", mutated)

mutated = copy.deepcopy(payload)
mutated["lifecyclePhases"] = mutated["lifecyclePhases"][:-1]
expect_reject("missing closeout phase", mutated)

mutated = copy.deepcopy(payload)
mutated["lifecyclePhases"][2].pop("approvalGateStatus")
expect_reject("missing approval-gate status", mutated)

mutated = copy.deepcopy(payload)
mutated["lifecyclePhases"][3].pop("authorityBoundary")
expect_reject("missing authority boundary", mutated)

mutated = copy.deepcopy(payload)
mutated["sandboxTarget"]["blockedOperations"] = mutated["sandboxTarget"]["blockedOperations"][:-1]
expect_reject("missing blocked operation", mutated)

mutated = copy.deepcopy(payload)
mutated["privateMemoryPolicy"] = "private notes are enough"
expect_reject("private memory accepted", mutated)

mutated = copy.deepcopy(payload)
mutated["nextAction"] = "live worker mutation completed"
expect_reject("unsafe live operation claim", mutated)

mutated = copy.deepcopy(payload)
mutated["nextAction"] = HOME_SEGMENT + "sam/private"
expect_reject("private local path", mutated)

print("PASS Dokkaebi sandbox issue processing transcript validation passed")
PY
