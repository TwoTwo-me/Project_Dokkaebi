#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}

require_text() {
  local path="$1"
  local needle="$2"
  [[ -f "$path" ]] || fail "missing file: $path"
  grep -Fqi -- "$needle" "$path" || fail "missing text in $path: $needle"
}

DOC_PATH="${RELEASE_ROLLBACK_DRILL_PATH:-docs/operations/release-rollback-drill-2026-06-13.md}"

for term in "local release and rollback drill" "release candidate" "staged rollout step" "rollback trigger" "rollback decision" "recovery path" "operator" "communication surface" "command output" "validation output" "staged rollout decision" "approval-gate status" "cleanup" "residual risk" "next action" "does not authorize"; do
  require_text "$DOC_PATH" "$term"
done

command -v python3 >/dev/null || fail "missing command: python3"

python3 - "$DOC_PATH" <<'PY'
import copy
import json
import re
import sys
from datetime import date
from pathlib import Path

START = "<!-- release-rollback-drill:begin -->"
END = "<!-- release-rollback-drill:end -->"
REQ = ["version", "drillId", "date", "permissionLevel", "sourceRunbook", "releaseCandidate", "stagedRollout", "stagedRolloutDecision", "rollbackTrigger", "rollbackDecision", "recoveryPath", "commandOutput", "validationOutput", "communicationSurface", "operator", "reviewer", "approvalGateStatus", "cleanup", "residualRisk", "nextAction", "followUpIssueUrl"]
CMDS = ["validate-release-rollback-drill.sh", "validate-release-rollback-capacity-drills.sh", "validate-readiness-criteria.sh", "validate-contract-docs.sh", "validate-dokkaebi-plugin.sh", "validate-git-governance.sh"]
HOME, USERS = "/" + "home" + "/", "/" + "users" + "/"
PRIVATE_PATH = re.compile(r"(?i)(" + re.escape(HOME) + "|" + re.escape(USERS) + r")[^\s`'\"]+")
DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
SHA = re.compile(r"^[0-9a-f]{40}$")
PASS = re.compile(r"\bPASS\b")
SECRET_TERMS = ["cookie=", "private" + "_key=", "sec" + "ret=", "to" + "ken=", "authorization: bearer", "-----begin private key-----"]
SECRET_PATTERNS = [("github classic access key", r"\bgh[pousr]_[A-Za-z0-9_]{16,}\b"), ("github fine-grained access key", r"\bgithub_pat_[A-Za-z0-9_]{20,}\b"), ("cloud access key", r"\bA[KS]IA[A-Z0-9]{16}\b")]
UNSAFE_TERMS = ["credential used", "deployment executed", "docker container started", "github project control-plane mutation completed", "infrastructure mutated", "kubernetes cluster mutated", "production write completed", "remote host changed", "worker dispatch completed"]
UNSAFE_PATTERNS = [
    ("production deploy claim", r"(\bproduction\s+(deploy|deployment|release|write)\s+(succeeded|completed|executed|started|finished|ran)\b|\b(deploy|deployment|release)\s+(succeeded|completed|executed|started|finished|ran)\s+in\s+production\b)"),
    ("docker live command claim", r"\bdocker\s+(compose\s+)?(up|run|start|started|created|executed|completed)\b"),
    ("kubernetes live command claim", r"\bkubectl\s+(apply|create|delete|rollout|scale|set|patch)\b"),
    ("kubernetes mutation claim", r"\bkubernetes\s+(cluster|namespace|job|deployment)\s+(mutated|changed|updated|created|deleted|scaled)\b"),
    ("remote host mutation claim", r"\bremote\s+host\s+(was\s+)?(changed|updated|mutated|configured|restarted)\b"),
    ("worker dispatch claim", r"\bworker\s+dispatch\s+(was\s+)?(completed|started|executed|launched)\b"),
    ("project setting mutation claim", r"\bgithub\s+project\s+(setting|settings|field|fields|schema|control-plane)\s+(was\s+)?(changed|updated|mutated|created|deleted|completed)\b"),
    ("credential mutation claim", r"\bcredential\s+(used|issued|granted|exported|rotated)\b"),
    ("infrastructure mutation claim", r"\binfrastructure\s+(mutated|changed|updated|created|deleted)\b"),
    ("deployment proceed claim", r"\bdeploy(ment)?\s+(can|may|will)\s+proceed\b"),
    ("credential authorization claim", r"\bcredentials?\s+(are|is)?\s*authorized\b"),
]
SECRET_RX = [(name, re.compile(pattern)) for name, pattern in SECRET_PATTERNS]
UNSAFE_RX = [(name, re.compile(pattern, re.IGNORECASE)) for name, pattern in UNSAFE_PATTERNS]

class DrillError(Exception):
    pass

def reject(message):
    raise DrillError(message)

def joined(value):
    if isinstance(value, dict):
        return " ".join(f"{key} {joined(val)}" for key, val in value.items())
    if isinstance(value, list):
        return " ".join(joined(item) for item in value)
    return str(value)

def require_safe(value, label):
    text = joined(value)
    lowered = text.lower()
    for term in SECRET_TERMS:
        if term in lowered:
            reject(f"secret-bearing {label} wording: {term}")
    for name, pattern in SECRET_RX:
        if pattern.search(text):
            reject(f"secret-like {label} pattern: {name}")
    for term in UNSAFE_TERMS:
        if term in lowered:
            reject(f"unsafe mutation {label} wording: {term}")
    for name, pattern in UNSAFE_RX:
        if pattern.search(text):
            reject(f"unsafe mutation {label} pattern: {name}")
    if PRIVATE_PATH.search(lowered):
        reject(f"private local path retained in {label}")

def extract(text):
    if not text.strip():
        reject("empty release rollback drill content")
    if text.count(START) != 1 or text.count(END) != 1:
        reject("missing or duplicate release rollback drill block")
    start, end = text.index(START), text.index(END)
    if end < start:
        reject("release rollback drill block markers out of order")
    block = text[start + len(START):end].strip()
    if block.startswith("```json"):
        block = block.removeprefix("```json").strip()
    if block.endswith("```"):
        block = block[:-3].strip()
    try:
        payload = json.loads(block)
    except json.JSONDecodeError as exc:
        reject(f"malformed release rollback drill data: {exc}")
    if not isinstance(payload, dict):
        reject("release rollback drill block must be an object")
    return payload

def nonempty(value, label):
    if value in (None, "", [], {}):
        reject(f"missing {label}")
    return value

def require_list(value, label, minimum=1):
    if not isinstance(value, list) or len(value) < minimum:
        reject(f"missing {label}")
    return value

def text_list(value, label, minimum=1):
    values = [str(item).strip() for item in require_list(value, label, minimum)]
    if any(not item for item in values):
        reject(f"missing {label} item")
    return values

def fields(value, label, names):
    if not isinstance(value, dict) or not value:
        reject(f"missing {label}")
    for name in names:
        nonempty(value.get(name), f"{label} {name}")
    return value

def validate(payload):
    for field in REQ:
        nonempty(payload.get(field), field)
    if payload["version"] != 1:
        reject("version must be 1")
    if not DATE.fullmatch(str(payload["date"])):
        reject("date must be ISO yyyy-mm-dd")
    try:
        date.fromisoformat(str(payload["date"]))
    except ValueError:
        reject("date must be ISO yyyy-mm-dd")
    if payload["permissionLevel"] != "docs-only-local-drill":
        reject("permissionLevel must remain docs-only-local-drill")
    if payload["sourceRunbook"] != "docs/operations/release-rollback-capacity-drills.md":
        reject("source runbook must point to release rollback capacity baseline")
    if payload["followUpIssueUrl"] != "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/76":
        reject("follow-up issue URL must point to issue 76")
    candidate = fields(payload["releaseCandidate"], "release candidate", ["id", "commit", "artifact", "scope"])
    if not SHA.fullmatch(str(candidate["commit"])):
        reject("release candidate commit must be a 40-character lowercase SHA")
    rollout = require_list(payload["stagedRollout"], "staged rollout", 5)
    steps = {str(fields(item, "staged rollout step", ["step", "operator", "decision", "evidence"])["step"]) for item in rollout}
    for expected in ["prepare", "package", "validate", "stage rollout", "closeout"]:
        if expected not in steps:
            reject(f"missing staged rollout step {expected}")
    staged = fields(payload["stagedRolloutDecision"], "staged rollout decision", ["decision", "operator", "evidence", "communicationSurface"])
    if "local" not in joined(staged).lower() or "rollback" not in joined(staged).lower():
        reject("staged rollout decision must name local rollback handling")
    trigger = fields(payload["rollbackTrigger"], "rollback trigger", ["trigger", "detectedBy", "decision", "reason"])
    if str(trigger["decision"]).lower() != "rollback":
        reject("rollback trigger decision must be rollback")
    decision = fields(payload["rollbackDecision"], "rollback decision", ["decision", "operator", "communicationSurface", "closeoutEvidence"])
    if "rollback" not in joined(decision).lower():
        reject("rollback decision must name rollback")
    text_list(payload["recoveryPath"], "recovery path", 4)
    command_output = text_list(payload["commandOutput"], "command output", 3)
    output_text = " ".join(command_output).lower()
    if not any(PASS.search(item) for item in command_output):
        reject("command output missing PASS")
    for term in ["malformed", "rejected", "recovered"]:
        if not re.search(rf"\b{term}\b", output_text):
            reject(f"command output missing {term}")
    validation_output = text_list(payload["validationOutput"], "validation output", len(CMDS))
    for command in CMDS:
        matches = [item for item in validation_output if command in item]
        if not matches:
            reject(f"validation output missing {command}")
        if not any(PASS.search(item) for item in matches):
            reject(f"validation output missing PASS for {command}")
    approval = str(payload["approvalGateStatus"]).lower()
    if "no live approval-gated mutation reached" not in approval or "remain not authorized" not in approval:
        reject("approval-gate status must state no live approval-gated mutation reached and remain not authorized")
    if re.search(r"\b(can|may|will)\s+proceed\b", approval) or "authorized and" in approval:
        reject("approval-gate status must not authorize later action")
    cleanup = fields(payload["cleanup"], "cleanup", ["status", "receipt"])
    if cleanup["status"] != "complete":
        reject("cleanup must be complete")
    text_list(payload["residualRisk"], "residual risk", 3)
    nonempty(payload["nextAction"], "next action")
    require_safe(payload, "payload")

def validate_doc(text):
    require_safe(text, "document")
    payload = extract(text)
    validate(payload)
    return payload

def mutate(payload, path, value):
    changed = copy.deepcopy(payload)
    target = changed
    for key in path[:-1]:
        target = target[key]
    target[path[-1]] = value
    return changed

def expect_reject(name, candidate):
    try:
        validate_doc(candidate) if isinstance(candidate, str) else validate(candidate)
    except DrillError:
        return
    reject(f"negative fixture unexpectedly passed: {name}")

def run():
    doc_text = Path(sys.argv[1]).read_text(encoding="utf-8")
    baseline = validate_doc(doc_text)
    expect_reject("empty content", "")
    expect_reject("malformed drill data", START + "\n```json\n{\"version\": \n```\n" + END)
    expect_reject("markers out of order", END + "\n" + START + "\n{}\n")
    for field in REQ:
        expect_reject(f"missing {field}", mutate(baseline, (field,), [] if isinstance(baseline.get(field), list) else ""))
    cases = [
        ("bad version", ("version",), 2), ("bad compact date", ("date",), "20260613"), ("bad week date", ("date",), "2026-W24-6"), ("bad commit", ("releaseCandidate", "commit"), "not-a-sha"),
        ("missing rollout step", ("stagedRollout", 0, "step"), "skipped"), ("missing staged rollout decision evidence", ("stagedRolloutDecision", "evidence"), ""), ("non-rollback trigger decision", ("rollbackTrigger", "decision"), "advance"),
        ("empty recovery path item", ("recoveryPath",), ["", "", "", ""]), ("missing command pass", ("commandOutput",), ["not run", "malformed rejected", "recovered"]), ("false command pass substring", ("commandOutput",), ["bypass", "malformed rejected", "recovered"]),
        ("empty validation output item", ("validationOutput",), [""] * len(CMDS)), ("missing contract validation output", ("validationOutput",), ["bash scripts/validate-release-rollback-drill.sh: PASS"]), ("false validation pass substring", ("validationOutput",), [f"bash scripts/{command}: bypass" for command in CMDS]),
        ("cleanup incomplete", ("cleanup", "status"), "pending"), ("bare follow-up URL", ("followUpIssueUrl",), "https://github.com/"), ("unsafe wording", ("nextAction",), "deployment executed"),
        ("unsafe production deploy wording", ("nextAction",), "Deployment completed in production and Docker compose up completed for tracking issue 76."), ("unsafe project setting wording", ("nextAction",), "GitHub Project field was updated, Worker dispatch was completed, and Remote host was changed after kubectl apply completed."),
        ("private path", ("nextAction",), HOME + "private/release"), ("secret wording", ("nextAction",), "".join(("to", "ken=", "example"))), ("secret pattern", ("nextAction",), "".join(("gh", "p_", "A" * 20))), ("cloud secret pattern", ("nextAction",), "ASIA" + "A" * 16),
        ("empty residual risk item", ("residualRisk",), ["", "", ""]), ("approval authorizes action", ("approvalGateStatus",), "no live approval-gated mutation reached; credentials are authorized and deploy can proceed; remain not authorized is historical text"),
    ]
    for name, path, value in cases:
        expect_reject(name, mutate(baseline, path, value))
    expect_reject("private path outside payload", "Operator scratch: " + HOME + "private/release\n" + doc_text)
    expect_reject("secret pattern outside payload", "Operator scratch: " + "".join(("gh", "p_", "A" * 20)) + "\n" + doc_text)
    expect_reject("unsafe wording outside payload", "Production deployment succeeded and Docker compose up completed.\n" + doc_text)

try:
    run()
except DrillError as exc:
    print(f"FAIL {exc}", file=sys.stderr)
    sys.exit(1)
print("PASS Dokkaebi release rollback drill validation passed")
PY
