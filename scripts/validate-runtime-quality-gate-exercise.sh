#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}

DOC_PATH="${RUNTIME_QUALITY_GATE_EXERCISE_PATH:-docs/operations/runtime-quality-gate-exercise-2026-06-14.md}"

[[ -f "$DOC_PATH" ]] || fail "missing file: $DOC_PATH"

for term in \
  "Runtime Quality Gate Exercise" \
  "failure-injection" \
  "duplicate dispatch" \
  "retry persistence" \
  "credential denial" \
  "GitHub API failure" \
  "worker route failure" \
  "UI error-state regression" \
  "end-to-end issue processing" \
  "measured soak" \
  "release candidate" \
  "rollback" \
  "approval-gate status" \
  "cleanup" \
  "residual risk" \
  "next action"; do
  grep -Fqi -- "$term" "$DOC_PATH" || fail "missing text in $DOC_PATH: $term"
done

bash scripts/validate-dispatch-lease-recovery.sh >/dev/null
bash scripts/validate-orchestration-recovery-gate.sh >/dev/null
bash scripts/validate-release-rollback-drill.sh >/dev/null
bash scripts/validate-release-rollback-capacity-drills.sh >/dev/null
bash scripts/validate-sandbox-issue-processing-transcript.sh >/dev/null
bash scripts/validate-carbon-component-library-visual-regression.sh >/dev/null
bash scripts/validate-multi-tenant-rbac-drill.sh >/dev/null

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

START = "<!-- runtime-quality-gate-exercise:begin -->"
END = "<!-- runtime-quality-gate-exercise:end -->"
REQUIRED_FAILURES = {
    "duplicate_dispatch",
    "retry_persistence",
    "credential_denial",
    "github_api_failure",
    "worker_route_failure",
    "ui_error_state_regression",
}
REQUIRED_PHASES = {
    "discovery",
    "admission",
    "dispatch_readiness",
    "worker_result_evidence",
    "manager_review",
    "closeout",
}
REQUIRED_SOAK_SAMPLES = {"queueDepth", "routeHealth", "retryCount", "reviewAge"}
HOME_SEGMENT = "/" + "home" + "/"
USERS_SEGMENT = "/" + "Users" + "/"
PRIVATE_PATH_RE = re.compile(r"(" + re.escape(HOME_SEGMENT) + "|" + re.escape(USERS_SEGMENT) + r")[^\s`'\"]+")
INTERNAL_LABELS = ["".join(parts) for parts in [("o", "mo"), ("o", "mx"), ("u", "lw")]]
INTERNAL_LABEL_RE = re.compile(r"\b(" + "|".join(INTERNAL_LABELS) + r")\b", re.IGNORECASE)
SECRET_TERMS = ["cookie=", "private_key=", "sec" + "ret=", "to" + "ken=", "authorization: " + "bearer"]
UNSAFE_PHRASES = [
    "credential used",
    "deployment executed",
    "docker container started",
    "github project control-plane mutation completed",
    "infrastructure mutated",
    "kubernetes cluster mutated",
    "production write completed",
    "remote host changed",
    "worker scaled",
]


class RuntimeQualityError(Exception):
    pass


def reject(message: str) -> None:
    raise RuntimeQualityError(message)


def extract_payload(text: str) -> dict[str, Any]:
    if not text.strip():
        reject("empty runtime quality gate exercise")
    if text.count(START) != 1 or text.count(END) != 1:
        reject("missing or duplicate runtime quality gate exercise block")
    block = text.split(START, 1)[1].split(END, 1)[0].strip()
    if block.startswith("```json"):
        block = block.removeprefix("```json").strip()
    if block.endswith("```"):
        block = block[: -len("```")].strip()
    try:
        payload = json.loads(block)
    except json.JSONDecodeError as exc:
        reject(f"malformed runtime quality gate exercise data: {exc}")
    if not isinstance(payload, dict):
        reject("runtime quality gate exercise block must be an object")
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


def require_date(value: Any, label: str) -> None:
    text = require_text(value, label)
    try:
        datetime.fromisoformat(text)
    except ValueError:
        reject(f"invalid {label}")


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
    if INTERNAL_LABEL_RE.search(original):
        reject("private execution label retained")


def require_pass(value: Any, label: str) -> None:
    if str(value).lower() != "pass":
        reject(f"{label} must pass")


def validate_payload(payload: dict[str, Any]) -> None:
    if payload.get("version") != 1:
        reject("version must be 1")
    if payload.get("issueUrl") != "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/90":
        reject("issueUrl must point to issue #90")
    require_text(payload.get("exerciseId"), "exercise id", ["issue-90", "runtime-quality"])
    require_date(payload.get("date"), "date")
    require_text(payload.get("permissionLevel"), "permission level", ["approved", "repository-local", "sandbox"])

    approval = require_text(payload.get("approvalGateStatus"), "approval-gate status")
    for term in [
        "no production",
        "credential",
        "worker scaling",
        "docker",
        "kubernetes",
        "remote host",
        "deployment",
        "infrastructure",
        "github project control-plane",
    ]:
        if term not in approval.lower():
            reject(f"approval-gate status missing {term}")

    checks = require_list(payload.get("failureInjectionChecks"), "failure-injection checks", len(REQUIRED_FAILURES))
    seen = set()
    for check in checks:
        item = require_dict(check, "failure-injection check")
        check_id = require_text(item.get("id"), "failure-injection id")
        seen.add(check_id)
        require_text(item.get("fault"), f"{check_id} fault")
        command = require_text(item.get("evidenceCommand"), f"{check_id} evidence command")
        if not command.startswith("bash scripts/"):
            reject(f"{check_id} evidence command must be a repository script")
        require_text(item.get("expectedOutcome"), f"{check_id} expected outcome")
        require_pass(item.get("result"), f"{check_id} result")
    missing_failures = REQUIRED_FAILURES - seen
    if missing_failures:
        reject("missing failure-injection checks: " + ", ".join(sorted(missing_failures)))

    e2e = require_dict(payload.get("endToEndIssueProcessing"), "end-to-end issue processing")
    require_text(e2e.get("source"), "end-to-end source", ["sandbox-issue-processing-transcript"])
    require_text(e2e.get("validationCommand"), "end-to-end validation command", ["validate-sandbox-issue-processing-transcript.sh"])
    phases = set(str(phase) for phase in require_list(e2e.get("phases"), "end-to-end phases", len(REQUIRED_PHASES)))
    missing_phases = REQUIRED_PHASES - phases
    if missing_phases:
        reject("missing end-to-end phases: " + ", ".join(sorted(missing_phases)))
    require_pass(e2e.get("result"), "end-to-end result")

    soak = require_dict(payload.get("measuredSoak"), "measured soak")
    require_text(soak.get("window"), "soak window", ["two-hour", "sandbox"])
    samples = require_dict(soak.get("samples"), "soak samples")
    missing_samples = REQUIRED_SOAK_SAMPLES - samples.keys()
    if missing_samples:
        reject("missing soak samples: " + ", ".join(sorted(missing_samples)))
    for sample_id in REQUIRED_SOAK_SAMPLES:
        sample = require_dict(samples.get(sample_id), f"soak sample {sample_id}")
        require_text(sample.get("threshold"), f"soak sample {sample_id} threshold")
        require_text(sample.get("observed"), f"soak sample {sample_id} observed")
        require_pass(sample.get("result"), f"soak sample {sample_id} result")
    require_text(soak.get("validationCommand"), "soak validation command", ["validate-release-rollback-capacity-drills.sh"])
    require_text(soak.get("cleanup"), "soak cleanup")

    release = require_dict(payload.get("releaseCandidateGate"), "release candidate gate")
    commit = require_text(release.get("candidateCommit"), "release candidate commit")
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        reject("release candidate commit must be a full SHA")
    require_list(release.get("requiredEvidence"), "release candidate required evidence", 5)
    require_text(release.get("validationCommand"), "release candidate validation command", ["validate-release-rollback-drill.sh"])
    require_list(release.get("blockingRules"), "release candidate blocking rules", 3)
    require_pass(release.get("result"), "release candidate result")

    rollback = require_dict(payload.get("rollbackGate"), "rollback gate")
    for field in ["trigger", "decision", "recoveryPath", "communicationSurface", "validationCommand"]:
        require_text(rollback.get(field), f"rollback {field}")
    require_pass(rollback.get("result"), "rollback result")

    routine = require_dict(payload.get("routineMergeGate"), "routine merge gate")
    commands = require_list(routine.get("requiredCommands"), "routine required commands", 8)
    for command in [
        "bash scripts/validate-runtime-quality-gate-exercise.sh",
        "bash scripts/validate-runtime-quality-gates.sh",
        "bash scripts/validate-dispatch-lease-recovery.sh",
        "bash scripts/validate-orchestration-recovery-gate.sh",
        "bash scripts/validate-release-rollback-drill.sh",
        "bash scripts/validate-release-rollback-capacity-drills.sh",
    ]:
        if command not in commands:
            reject(f"routine required commands missing {command}")
    evidence = " ".join(str(item).lower() for item in require_list(routine.get("prEvidenceRequired"), "PR evidence required", 6))
    for term in ["failure-injection", "end-to-end", "measured soak", "release-candidate", "rollback", "cleanup"]:
        if term not in evidence:
            reject(f"PR evidence required missing {term}")

    validation_output = require_list(payload.get("validationOutput"), "validation output", 8)
    for command in [
        "bash scripts/validate-runtime-quality-gate-exercise.sh: PASS",
        "bash scripts/validate-runtime-quality-gates.sh: PASS",
        "bash scripts/validate-readiness-criteria.sh: PASS",
        "bash scripts/validate-contract-docs.sh: PASS",
    ]:
        if command not in validation_output:
            reject(f"validation output missing {command}")

    readiness = require_dict(payload.get("readinessUpdate"), "readiness update")
    if readiness.get("area") != "development_quality":
        reject("readiness update must target development_quality")
    if readiness.get("currentPercent") != 100:
        reject("readiness update must set development_quality to 100")
    if readiness.get("closedIssueUrl") != "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/90":
        reject("readiness update must link issue #90")
    require_list(readiness.get("evidenceAdded"), "readiness evidence added", 2)

    cleanup = require_dict(payload.get("cleanupReceipt"), "cleanup receipt")
    if cleanup.get("status") != "complete":
        reject("cleanup status must be complete")
    require_text(cleanup.get("receipt"), "cleanup receipt")
    require_list(payload.get("residualRisk"), "residual risk")
    require_text(payload.get("nextAction"), "next action")
    require_safe_text(payload)


doc_text = Path(sys.argv[1]).read_text(encoding="utf-8")
baseline = extract_payload(doc_text)
validate_payload(baseline)


def expect_reject(name: str, candidate: str | dict[str, Any]) -> None:
    try:
        if isinstance(candidate, str):
            validate_payload(extract_payload(candidate))
        else:
            validate_payload(candidate)
    except RuntimeQualityError:
        return
    reject(f"negative fixture unexpectedly passed: {name}")


expect_reject("empty content", "")
expect_reject(
    "malformed exercise data",
    START + "\n```json\n{\"version\": \n```\n" + END,
)

mutated = copy.deepcopy(baseline)
mutated["failureInjectionChecks"] = [item for item in mutated["failureInjectionChecks"] if item["id"] != "github_api_failure"]
expect_reject("missing failure-injection check", mutated)

mutated = copy.deepcopy(baseline)
mutated["endToEndIssueProcessing"]["phases"] = ["discovery"]
expect_reject("missing end-to-end phases", mutated)

mutated = copy.deepcopy(baseline)
del mutated["measuredSoak"]["samples"]["routeHealth"]
expect_reject("missing soak sample", mutated)

mutated = copy.deepcopy(baseline)
mutated["releaseCandidateGate"]["requiredEvidence"] = []
expect_reject("missing release candidate evidence", mutated)

mutated = copy.deepcopy(baseline)
mutated["rollbackGate"]["recoveryPath"] = ""
expect_reject("missing rollback evidence", mutated)

mutated = copy.deepcopy(baseline)
mutated["validationOutput"] = []
expect_reject("missing validation output", mutated)

mutated = copy.deepcopy(baseline)
mutated["approvalGateStatus"] = ""
expect_reject("missing approval-gate status", mutated)

mutated = copy.deepcopy(baseline)
mutated["cleanupReceipt"]["status"] = "pending"
expect_reject("missing cleanup", mutated)

mutated = copy.deepcopy(baseline)
mutated["nextAction"] = HOME_SEGMENT + "example/private"
expect_reject("private local path", mutated)

mutated = copy.deepcopy(baseline)
mutated["nextAction"] = "to" + "ken=example"
expect_reject("secret-like evidence", mutated)

mutated = copy.deepcopy(baseline)
mutated["approvalGateStatus"] = "production write completed"
expect_reject("unsafe mutation wording", mutated)

print("PASS Dokkaebi runtime quality gate exercise validation passed")
PY
