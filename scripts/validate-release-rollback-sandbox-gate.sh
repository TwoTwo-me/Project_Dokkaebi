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

DOC_PATH="${RELEASE_ROLLBACK_SANDBOX_GATE_PATH:-docs/operations/release-rollback-sandbox-gate-2026-06-14.md}"
RUNNER_PATH="scripts/run-release-rollback-sandbox-gate.sh"

for term in \
  "approved local sandbox release rollback gate" \
  "release gate blocking" \
  "rollback decision generation" \
  "recovery path generation" \
  "measured soak samples" \
  "approval-gate status" \
  "cleanup receipt" \
  "does not authorize"; do
  require_text "$DOC_PATH" "$term"
done

[[ -f "$RUNNER_PATH" ]] || fail "missing runner: $RUNNER_PATH"
command -v python3 >/dev/null || fail "missing command: python3"

python3 - "$DOC_PATH" "$RUNNER_PATH" <<'PY'
from __future__ import annotations

import copy
import hashlib
import json
import re
import subprocess
import sys
from datetime import date
from pathlib import Path
from typing import Any

START = "<!-- release-rollback-sandbox-gate:begin -->"
END = "<!-- release-rollback-sandbox-gate:end -->"
EXPECTED_ISSUE = "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/76"
REQUIRED_BLOCKS = {
    "block_failed_validation",
    "block_missing_approval_evidence",
    "block_missing_rollback_plan",
}
SOAK_SAMPLES = {"queueDepth", "routeHealth", "retryCount", "reviewAge"}
VALIDATION_OUTPUT = {
    "bash scripts/run-release-rollback-sandbox-gate.sh: PASS",
    "bash scripts/validate-release-rollback-sandbox-gate.sh: PASS",
    "bash scripts/validate-release-rollback-drill.sh: PASS",
    "bash scripts/validate-release-rollback-capacity-drills.sh: PASS",
    "bash scripts/validate-runtime-quality-gate-exercise.sh: PASS",
    "bash scripts/validate-readiness-criteria.sh: PASS",
    "bash scripts/validate-contract-docs.sh: PASS",
    "bash scripts/validate-git-governance.sh: PASS",
}
MANIFEST_FIELDS = [
    "releaseGate",
    "rollbackGate",
    "measuredSoak",
    "validationOutput",
    "approvalGateStatus",
    "cleanup",
    "residualRisk",
    "readinessDecision",
]
HOME_SEGMENT = "/" + "home" + "/"
USERS_SEGMENT = "/" + "Users" + "/"
PRIVATE_PATH_RE = re.compile(r"(" + re.escape(HOME_SEGMENT) + "|" + re.escape(USERS_SEGMENT) + r")[^\s`'\"]+", re.IGNORECASE)
SECRET_TERMS = ["cookie=", "private_" + "key=", "sec" + "ret=", "to" + "ken=", "authorization: " + "bearer"]
SECRET_PATTERNS = [
    ("github classic access key", r"\bgh[pousr]_[A-Za-z0-9_]{16,}\b"),
    ("github fine-grained access key", r"\bgithub" + r"_pat_[A-Za-z0-9_]{20,}\b"),
    ("cloud access key", r"\bA[KS]IA[A-Z0-9]{16}\b"),
]
UNSAFE_PATTERNS = [
    ("live worker mutation claim", r"\blive worker mutation (was )?(performed|completed|executed|authorized)\b"),
    ("credential use claim", r"\bcredentials?\s+(were|was|are|is)?\s*(used|loaded|granted)\b"),
    ("deployment claim", r"\b(deployment|production write|infrastructure change)\s+(was )?(performed|completed|executed)\b"),
    ("container claim", r"\b(docker|kubernetes)\s+(resource|cluster|container|job)\s+(was )?(created|started|mutated)\b"),
    ("project settings claim", r"\bgithub project\s+(field|settings|control-plane)\s+(was )?(created|updated|mutated)\b"),
]
BAD_VALIDATION = ("fail", "not run", "skipped", "placeholder")


class SandboxGateError(Exception):
    pass


def reject(message: str) -> None:
    raise SandboxGateError(message)


def joined(value: Any) -> str:
    if isinstance(value, dict):
        return " ".join(f"{key} {joined(val)}" for key, val in value.items())
    if isinstance(value, list):
        return " ".join(joined(item) for item in value)
    return str(value)


def require_safe(value: Any, label: str) -> None:
    text = joined(value)
    lowered = text.lower()
    for term in SECRET_TERMS:
        if term in lowered:
            reject(f"secret-bearing {label}: {term}")
    for name, pattern in SECRET_PATTERNS:
        if re.search(pattern, text):
            reject(f"secret-like {label}: {name}")
    for name, pattern in UNSAFE_PATTERNS:
        if re.search(pattern, text, re.IGNORECASE):
            reject(f"unsafe mutation {label}: {name}")
    if PRIVATE_PATH_RE.search(text):
        reject(f"private local path retained in {label}")


def extract(text: str) -> dict[str, Any]:
    if not text.strip():
        reject("empty release rollback sandbox gate content")
    if text.count(START) != 1 or text.count(END) != 1:
        reject("missing or duplicate release rollback sandbox gate block")
    block = text.split(START, 1)[1].split(END, 1)[0].strip()
    if block.startswith("```json"):
        block = block.removeprefix("```json").strip()
    if block.endswith("```"):
        block = block[:-3].strip()
    try:
        payload = json.loads(block)
    except json.JSONDecodeError as exc:
        reject(f"malformed release rollback sandbox gate data: {exc}")
    if not isinstance(payload, dict):
        reject("release rollback sandbox gate block must be an object")
    return payload


def nonempty(value: Any, label: str) -> Any:
    if value in (None, "", [], {}):
        reject(f"missing {label}")
    return value


def require_list(value: Any, label: str, minimum: int = 1) -> list[Any]:
    if not isinstance(value, list) or len(value) < minimum:
        reject(f"missing {label}")
    return value


def fields(value: Any, label: str, names: list[str]) -> dict[str, Any]:
    if not isinstance(value, dict):
        reject(f"missing {label}")
    for name in names:
        nonempty(value.get(name), f"{label} {name}")
    return value


def manifest_hash(payload: dict[str, Any]) -> str:
    manifest = {field: payload[field] for field in MANIFEST_FIELDS}
    return hashlib.sha256(json.dumps(manifest, sort_keys=True).encode()).hexdigest()


def validate_release_gate(payload: dict[str, Any]) -> None:
    gate = fields(payload.get("releaseGate"), "release gate", ["target", "releaseCandidate", "allowed", "blocked"])
    candidate = fields(
        gate["releaseCandidate"],
        "release candidate",
        ["id", "artifact", "validationCommand", "rollbackPlan"],
    )
    if candidate["validationCommand"] != "bash scripts/validate-release-rollback-drill.sh":
        reject("release candidate validation command mismatch")

    allowed = fields(
        gate["allowed"],
        "allowed release decision",
        ["name", "decision", "reason", "validationStatus", "approvalEvidence", "rollbackPlan"],
    )
    if allowed["decision"] != "allow":
        reject("complete candidate must be allowed")
    if allowed["validationStatus"] != "pass":
        reject("complete candidate must require passing validation")
    if allowed["approvalEvidence"] != "present":
        reject("complete candidate must require approval evidence")
    if allowed["rollbackPlan"] != "present":
        reject("complete candidate must require rollback plan")

    blocks = require_list(gate["blocked"], "blocked release decisions", len(REQUIRED_BLOCKS))
    names = set()
    for block in blocks:
        item = fields(
            block,
            "blocked release decision",
            ["name", "decision", "reason", "validationStatus", "approvalEvidence", "rollbackPlan"],
        )
        names.add(str(item["name"]))
        if item["decision"] != "block":
            reject("negative release decision must block")
    if names != REQUIRED_BLOCKS:
        reject("release gate missing required block decisions")


def validate_rollback_gate(payload: dict[str, Any]) -> None:
    gate = fields(
        payload.get("rollbackGate"),
        "rollback gate",
        ["trigger", "decision", "operator", "communicationSurface", "recoveryPath", "output"],
    )
    if "rollback" not in str(gate["decision"]).lower():
        reject("rollback decision output missing")
    if "issue #76" not in str(gate["communicationSurface"]).lower():
        reject("rollback communication must link issue #76")
    recovery_path = require_list(gate["recoveryPath"], "recovery path", 4)
    recovery_text = " ".join(str(item).lower() for item in recovery_path)
    for term in ["restore", "rerun", "validation", "cleanup"]:
        if term not in recovery_text:
            reject(f"recovery path missing {term}")
    output = fields(gate["output"], "rollback output", ["rollbackDecisionGenerated", "recoveryPathGenerated", "result"])
    if output["rollbackDecisionGenerated"] is not True or output["recoveryPathGenerated"] is not True:
        reject("rollback output must generate decision and recovery path")
    if output["result"] != "pass":
        reject("rollback output result must pass")


def validate_soak(payload: dict[str, Any]) -> None:
    soak = fields(payload.get("measuredSoak"), "measured soak", ["window", "samples", "validationCommand", "cleanup"])
    if "two-hour" not in str(soak["window"]).lower() or "sandbox" not in str(soak["window"]).lower():
        reject("measured soak must name two-hour approved local sandbox fixture")
    if soak["validationCommand"] != "bash scripts/validate-release-rollback-sandbox-gate.sh":
        reject("measured soak validation command mismatch")
    samples = fields(soak["samples"], "measured soak samples", list(SOAK_SAMPLES))
    for sample_id in SOAK_SAMPLES:
        sample = fields(samples[sample_id], f"measured soak sample {sample_id}", ["threshold", "observed", "result"])
        if sample["result"] != "pass":
            reject(f"measured soak sample {sample_id} must pass")


def validate_payload(payload: dict[str, Any], *, from_runner: bool) -> None:
    required = [
        "version",
        "evidenceId",
        "date",
        "issueUrl",
        "permissionLevel",
        "approvalRecord",
        "runner",
        "releaseGate",
        "rollbackGate",
        "measuredSoak",
        "validationOutput",
        "approvalGateStatus",
        "cleanup",
        "residualRisk",
        "readinessDecision",
        "nextAction",
        "manifestSha256",
    ]
    for field in required:
        nonempty(payload.get(field), field)
    if payload["version"] != 1:
        reject("version must be 1")
    try:
        date.fromisoformat(str(payload["date"]))
    except ValueError:
        reject("date must be ISO yyyy-mm-dd")
    if payload["issueUrl"] != EXPECTED_ISSUE:
        reject("issue URL must point to issue 76")
    if payload["permissionLevel"] != "approved-local-sandbox-release-rollback-gate":
        reject("permission level mismatch")

    approval = fields(payload["approvalRecord"], "approval record", ["approvedTarget", "scope", "deniedTargets", "evidence"])
    approval_text = joined(approval).lower()
    for term in ["local", "sandbox", "issue #76"]:
        if term not in approval_text:
            reject(f"approval record missing {term}")
    denied = " ".join(str(item).lower() for item in require_list(approval["deniedTargets"], "denied targets", 8))
    for term in ["worker", "credential", "infrastructure", "remote host", "docker", "kubernetes", "deployment", "production", "github project"]:
        if term not in denied:
            reject(f"approval denied targets missing {term}")

    runner = fields(payload["runner"], "runner", ["path", "command", "outputContract", "result"])
    if runner["path"] != "scripts/run-release-rollback-sandbox-gate.sh":
        reject("runner path mismatch")
    if runner["command"] != "bash scripts/run-release-rollback-sandbox-gate.sh":
        reject("runner command mismatch")
    if "PASS Dokkaebi release rollback sandbox gate runner completed" not in str(runner["result"]):
        reject("runner output missing pass result")
    if "releaseGate" not in str(runner["outputContract"]) or "rollbackGate" not in str(runner["outputContract"]):
        reject("runner output contract missing gate surfaces")

    validate_release_gate(payload)
    validate_rollback_gate(payload)
    validate_soak(payload)

    validation = [str(item) for item in require_list(payload["validationOutput"], "validation output", len(VALIDATION_OUTPUT))]
    for item in validation:
        if any(marker in item.lower() for marker in BAD_VALIDATION):
            reject("validation output contains non-passing marker")
    missing_output = VALIDATION_OUTPUT - set(validation)
    if missing_output:
        reject("validation output missing exact PASS commands: " + ", ".join(sorted(missing_output)))

    approval_status = str(payload["approvalGateStatus"]).lower()
    for term in ["approved local sandbox", "no live worker", "credential", "remote host", "docker", "kubernetes", "deployment", "production", "github project", "not authorized"]:
        if term not in approval_status:
            reject(f"approval-gate status missing {term}")

    cleanup = fields(payload["cleanup"], "cleanup", ["status", "receipt"])
    if cleanup["status"] != "complete":
        reject("cleanup status must be complete")
    residual = " ".join(str(item).lower() for item in require_list(payload["residualRisk"], "residual risk", 2))
    if "approval-gated" not in residual:
        reject("residual risk must keep live targets approval-gated")
    readiness = fields(payload["readinessDecision"], "readiness decision", ["operations_sre", "production_release_rollback_runbook", "basis"])
    if readiness["operations_sre"] != 100 or readiness["production_release_rollback_runbook"] != 100:
        reject("readiness decision must score release rollback evidence at 100")
    if "human approval" not in str(payload["nextAction"]).lower():
        reject("next action must retain Human approval boundary")

    if not re.fullmatch(r"[0-9a-f]{64}", str(payload["manifestSha256"])):
        reject("manifest hash must be sha256")
    if payload["manifestSha256"] != manifest_hash(payload):
        reject("manifest hash mismatch")
    if from_runner and payload["manifestSha256"] != manifest_hash(payload):
        reject("runner manifest hash mismatch")
    require_safe(payload, "payload")


def parse_runner_output(output: str) -> dict[str, Any]:
    if "PASS Dokkaebi release rollback sandbox gate runner completed" not in output:
        reject("runner PASS line missing")
    start = output.find("{")
    if start < 0:
        reject("runner JSON missing")
    try:
        payload = json.loads(output[start:])
    except json.JSONDecodeError as exc:
        reject(f"runner JSON malformed: {exc}")
    if not isinstance(payload, dict):
        reject("runner JSON must be an object")
    return payload


def run_runner(path: Path) -> dict[str, Any]:
    completed = subprocess.run(["bash", str(path)], text=True, capture_output=True, check=False)
    if completed.returncode != 0:
        reject("runner failed: " + completed.stderr.strip())
    output = completed.stdout + completed.stderr
    require_safe(output, "runner output")
    payload = parse_runner_output(output)
    validate_payload(payload, from_runner=True)
    return payload


def mutate(payload: dict[str, Any], path: tuple[Any, ...], value: Any) -> dict[str, Any]:
    changed = copy.deepcopy(payload)
    target: Any = changed
    for key in path[:-1]:
        target = target[key]
    target[path[-1]] = value
    if "manifestSha256" in changed and all(field in changed for field in MANIFEST_FIELDS):
        changed["manifestSha256"] = manifest_hash(changed)
    return changed


def expect_reject(name: str, candidate: str | dict[str, Any]) -> None:
    try:
        if isinstance(candidate, str):
            validate_payload(extract(candidate), from_runner=False)
        else:
            validate_payload(candidate, from_runner=False)
    except SandboxGateError:
        return
    reject(f"negative fixture unexpectedly passed: {name}")


doc_text = Path(sys.argv[1]).read_text(encoding="utf-8")
require_safe(doc_text, "document")
baseline = extract(doc_text)
validate_payload(baseline, from_runner=False)
runner_payload = run_runner(Path(sys.argv[2]))
if baseline["manifestSha256"] != runner_payload["manifestSha256"]:
    reject("document manifest hash must match runner manifest hash")

expect_reject("empty content", "")
expect_reject("malformed data", START + "\n```json\n{\"version\": \n```\n" + END)
for field in ["approvalRecord", "runner", "releaseGate", "rollbackGate", "measuredSoak", "cleanup", "residualRisk"]:
    expect_reject(f"missing {field}", mutate(baseline, (field,), ""))
expect_reject("missing issue closeout linkage", mutate(baseline, ("issueUrl",), "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/999"))
expect_reject("missing release candidate", mutate(baseline, ("releaseGate", "releaseCandidate"), {}))
expect_reject("missing validation pass", mutate(baseline, ("releaseGate", "allowed", "validationStatus"), "fail"))
expect_reject("missing approval evidence", mutate(baseline, ("releaseGate", "allowed", "approvalEvidence"), "missing"))
expect_reject("missing rollback plan", mutate(baseline, ("releaseGate", "releaseCandidate", "rollbackPlan"), ""))
expect_reject("missing rollback decision", mutate(baseline, ("rollbackGate", "decision"), ""))
expect_reject("missing recovery path", mutate(baseline, ("rollbackGate", "recoveryPath"), []))
expect_reject("missing queue depth sample", mutate(baseline, ("measuredSoak", "samples", "queueDepth"), {}))
expect_reject("missing route health sample", mutate(baseline, ("measuredSoak", "samples", "routeHealth"), {}))
expect_reject("missing retry count sample", mutate(baseline, ("measuredSoak", "samples", "retryCount"), {}))
expect_reject("missing review age sample", mutate(baseline, ("measuredSoak", "samples", "reviewAge"), {}))
expect_reject("private path", mutate(baseline, ("cleanup", "receipt"), HOME_SEGMENT + "private/release"))
expect_reject("secret-like evidence", mutate(baseline, ("nextAction",), "gh" + "p_" + "A" * 20))
expect_reject("unsafe worker mutation claim", mutate(baseline, ("nextAction",), "live worker mutation completed"))
bad_hash = copy.deepcopy(baseline)
bad_hash["manifestSha256"] = "0" * 64
expect_reject("mismatched runner manifest output", bad_hash)

print("PASS Dokkaebi release rollback sandbox gate validation passed")
PY
