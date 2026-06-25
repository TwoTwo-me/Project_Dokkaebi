#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

python3 - <<'PY'
from __future__ import annotations

import json
from pathlib import Path
import sys

errors: list[str] = []
path = Path("docs/enterprise-readiness/k8s-result-reconciliation-matrix.json")


def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


if not path.is_file():
    print(f"FAIL missing file: {path}", file=sys.stderr)
    sys.exit(1)

try:
    matrix = json.loads(path.read_text(encoding="utf-8"))
except json.JSONDecodeError as exc:
    print(f"FAIL invalid JSON in {path}: {exc}", file=sys.stderr)
    sys.exit(1)

require(matrix.get("matrixId") == "k8s_result_packet_reconciliation", "matrixId must be k8s_result_packet_reconciliation")
require(matrix.get("matrixVersion") == 1, "matrixVersion must be 1")
for term in [
    "GitHub Project",
    "Kubernetes Job",
    "PR/check",
    "result-packet",
    "Done is rejected unless",
]:
    require(term in json.dumps(matrix, sort_keys=True), f"matrix missing reconciliation term: {term}")

cases = matrix.get("cases")
require(isinstance(cases, list) and cases, "cases must be a non-empty list")
case_map = {
    case.get("caseId"): case
    for case in cases or []
    if isinstance(case, dict) and isinstance(case.get("caseId"), str)
}

required_cases = {
    "accepted-closeout": "move-to-human-review",
    "missing-result-packet": "reject-closeout",
    "failed-job": "fix-requested-or-failed",
    "done-while-job-running": "reopen-or-block-done",
    "stale-job": "create-recovery-ticket",
    "pr-check-failed": "fix-requested",
    "missing-approval": "reject-closeout",
}


def replay_manager_decision(case: dict) -> str:
    github_status = str(case.get("githubProjectStatus", ""))
    job_state = str(case.get("kubernetesJobState", ""))
    logs = str(case.get("logs", ""))
    result_packet = str(case.get("resultPacket", ""))
    pull_request = str(case.get("pullRequestState", ""))
    approval = str(case.get("approvalEvidence", ""))
    cleanup = str(case.get("cleanupEvidence", ""))

    if approval == "missing":
        return "reject-closeout"
    if job_state == "RunningPastTtlOrLease" or logs == "stale":
        return "create-recovery-ticket"
    if github_status == "Done" and (
        job_state != "Complete"
        or logs != "present"
        or result_packet != "present"
        or pull_request != "checks-passed"
        or cleanup != "present"
    ):
        return "reopen-or-block-done"
    if job_state == "Failed":
        return "fix-requested-or-failed"
    if pull_request == "checks-failed":
        return "fix-requested"
    if result_packet == "missing":
        return "reject-closeout"
    if (
        github_status == "Needs Review"
        and job_state == "Complete"
        and logs == "present"
        and result_packet == "present"
        and pull_request == "checks-passed"
        and approval == "present"
        and cleanup == "present"
    ):
        return "move-to-human-review"
    return "reject-closeout"

missing = sorted(set(required_cases) - set(case_map))
extra = sorted(set(case_map) - set(required_cases))
if missing:
    errors.append("missing reconciliation cases: " + ", ".join(missing))
if extra:
    errors.append("unexpected reconciliation cases: " + ", ".join(extra))

terminal_done_rejected = False
replay_trace: list[str] = []
for case_id, expected_decision in required_cases.items():
    case = case_map.get(case_id)
    if not case:
        continue
    replayed_decision = replay_manager_decision(case)
    replay_trace.append(f"REPLAY {case_id}: {replayed_decision}")
    if replayed_decision != expected_decision:
        errors.append(
            f"{case_id} replayed Manager decision must be {expected_decision}, got {replayed_decision}"
        )
    if case.get("expectedManagerDecision") != expected_decision:
        errors.append(f"{case_id} expectedManagerDecision must be {expected_decision}")
    for field in [
        "githubProjectStatus",
        "kubernetesJobState",
        "logs",
        "resultPacket",
        "pullRequestState",
        "approvalEvidence",
        "cleanupEvidence",
    ]:
        if not isinstance(case.get(field), str) or not case.get(field):
            errors.append(f"{case_id} missing {field}")
    evidence = case.get("requiredEvidence")
    if not isinstance(evidence, list) or len(evidence) < 2:
        errors.append(f"{case_id} requiredEvidence must list at least two evidence items")
    if case.get("githubProjectStatus") == "Done" and case.get("expectedManagerDecision") != "move-to-human-review":
        terminal_done_rejected = True

accepted = case_map.get("accepted-closeout", {})
if accepted:
    expected_evidence = set(accepted.get("requiredEvidence", []))
    for item in ["ticket id", "route profile", "ServiceAccount", "exit status", "PR/check link", "cleanup receipt"]:
        if item not in expected_evidence:
            errors.append(f"accepted-closeout missing required evidence item: {item}")

for case_id in ["missing-result-packet", "failed-job", "done-while-job-running", "stale-job", "pr-check-failed", "missing-approval"]:
    case = case_map.get(case_id, {})
    if case.get("expectedManagerDecision") == "move-to-human-review":
        errors.append(f"{case_id} must not be accepted")

require(terminal_done_rejected, "matrix must reject a Done GitHub Project state when Kubernetes/result evidence disagrees")

criteria = json.loads(Path("docs/enterprise-readiness/criteria.json").read_text(encoding="utf-8"))
k8s_area = next((area for area in criteria.get("areas", []) if area.get("id") == "k8s_platformization"), None)
require(isinstance(k8s_area, dict), "criteria.json missing k8s_platformization")
if isinstance(k8s_area, dict):
    evidence = k8s_area.get("currentEvidence", [])
    for evidence_path in [
        "docs/enterprise-readiness/k8s-result-reconciliation-matrix.json",
        "scripts/validate-k8s-result-reconciliation.sh",
    ]:
        if evidence_path not in evidence:
            errors.append(f"k8s_platformization currentEvidence missing {evidence_path}")
    subcriteria = {
        item.get("id"): item
        for item in k8s_area.get("subCriteria", [])
        if isinstance(item, dict)
    }
    reconciliation = subcriteria.get("k8s_result_packet_reconciliation", {})
    if "docs/enterprise-readiness/k8s-result-reconciliation-matrix.json" not in reconciliation.get("currentEvidence", []):
        errors.append("k8s_result_packet_reconciliation missing reconciliation matrix evidence")

if errors:
    for error in errors:
        print("FAIL " + error, file=sys.stderr)
    sys.exit(1)

for trace in replay_trace:
    print(trace)
print("PASS Dokkaebi K8S result reconciliation matrix validation passed")
PY
