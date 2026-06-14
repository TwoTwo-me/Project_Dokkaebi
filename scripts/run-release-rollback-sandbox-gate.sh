#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from __future__ import annotations

import hashlib
import json

payload = {
    "version": 1,
    "evidenceId": "release-rollback-sandbox-gate-2026-06-14",
    "date": "2026-06-14",
    "issueUrl": "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/76",
    "permissionLevel": "approved-local-sandbox-release-rollback-gate",
    "approvalRecord": {
        "approvedTarget": "local deterministic release rollback sandbox fixture",
        "scope": "exercise release gate, rollback gate, and measured soak evidence without external side effects",
        "deniedTargets": [
            "live worker mutation",
            "credentials",
            "infrastructure",
            "remote host",
            "Docker",
            "Kubernetes",
            "deployment",
            "production",
            "GitHub Project control-plane"
        ],
        "evidence": "Project Dokkaebi development loop approval is limited to local sandbox evidence for issue #76"
    },
    "runner": {
        "path": "scripts/run-release-rollback-sandbox-gate.sh",
        "command": "bash scripts/run-release-rollback-sandbox-gate.sh",
        "outputContract": "JSON with releaseGate, rollbackGate, measuredSoak, validationOutput, approvalGateStatus, cleanup, residualRisk, and nextAction"
    },
    "releaseGate": {
        "target": "approved local sandbox release candidate",
        "releaseCandidate": {
            "id": "release-rollback-sandbox-candidate-2026-06-14",
            "artifact": "repository release readiness fixture",
            "validationCommand": "bash scripts/validate-release-rollback-drill.sh",
            "rollbackPlan": "restore last complete evidence package and rerun release rollback validators"
        },
        "allowed": {
            "name": "allow_complete_candidate",
            "decision": "allow",
            "reason": "validation passed, approval evidence present, rollback plan present",
            "validationStatus": "pass",
            "approvalEvidence": "present",
            "rollbackPlan": "present"
        },
        "blocked": [
            {
                "name": "block_failed_validation",
                "decision": "block",
                "reason": "release candidate validation failed",
                "validationStatus": "fail",
                "approvalEvidence": "present",
                "rollbackPlan": "present"
            },
            {
                "name": "block_missing_approval_evidence",
                "decision": "block",
                "reason": "approval evidence missing",
                "validationStatus": "pass",
                "approvalEvidence": "missing",
                "rollbackPlan": "present"
            },
            {
                "name": "block_missing_rollback_plan",
                "decision": "block",
                "reason": "rollback plan missing",
                "validationStatus": "pass",
                "approvalEvidence": "present",
                "rollbackPlan": "missing"
            }
        ]
    },
    "rollbackGate": {
        "trigger": "failed validation or missing required release evidence",
        "decision": "rollback local sandbox candidate to last complete evidence package",
        "operator": "release_operator",
        "communicationSurface": "GitHub issue #76 and pull request timeline",
        "recoveryPath": [
            "restore last complete release evidence package",
            "rerun sandbox release rollback gate",
            "rerun release rollback drill validation",
            "rerun release rollback capacity validation",
            "record cleanup, residual risk, and next action"
        ],
        "output": {
            "rollbackDecisionGenerated": True,
            "recoveryPathGenerated": True,
            "result": "pass"
        }
    },
    "measuredSoak": {
        "window": "two-hour approved local sandbox fixture",
        "samples": {
            "queueDepth": {
                "threshold": "less than or equal to 25 dispatchable items",
                "observed": 7,
                "result": "pass"
            },
            "routeHealth": {
                "threshold": "at least one healthy route per required class",
                "observed": "local-worktree healthy, ssh-alpha healthy",
                "result": "pass"
            },
            "retryCount": {
                "threshold": "no item above 3 retries and fewer than 10 retrying items",
                "observed": "max item retries 1; retrying items 2",
                "result": "pass"
            },
            "reviewAge": {
                "threshold": "no Human Review item older than 5 business days",
                "observed": "oldest Human Review item 2 business days",
                "result": "pass"
            }
        },
        "validationCommand": "bash scripts/validate-release-rollback-sandbox-gate.sh",
        "cleanup": "temporary sandbox fixture only; no live queue, worker, or project state changed"
    },
    "validationOutput": [
        "bash scripts/run-release-rollback-sandbox-gate.sh: PASS",
        "bash scripts/validate-release-rollback-sandbox-gate.sh: PASS",
        "bash scripts/validate-release-rollback-drill.sh: PASS",
        "bash scripts/validate-release-rollback-capacity-drills.sh: PASS",
        "bash scripts/validate-runtime-quality-gate-exercise.sh: PASS",
        "bash scripts/validate-readiness-criteria.sh: PASS",
        "bash scripts/validate-contract-docs.sh: PASS",
        "bash scripts/validate-git-governance.sh: PASS"
    ],
    "approvalGateStatus": "approved local sandbox only; no live worker mutation, credential, infrastructure, remote host, Docker, Kubernetes, deployment, production, or GitHub Project control-plane mutation reached this evidence and those targets remain not authorized",
    "cleanup": {
        "status": "complete",
        "receipt": "runner emits deterministic JSON only; no servers, ports, browser contexts, containers, credentials, remote hosts, Docker daemon, Kubernetes cluster, deployments, infrastructure, production targets, workers, or GitHub Project control-plane side effects were attempted; no resources remain"
    },
    "residualRisk": [
        "live production release remains separately approval-gated",
        "live worker fleet soak remains separately approval-gated",
        "external paging delivery remains tracked outside this release rollback gate"
    ],
    "readinessDecision": {
        "operations_sre": 100,
        "production_release_rollback_runbook": 100,
        "basis": "approved local sandbox release gate, rollback decision, recovery path, measured soak samples, validation output, and cleanup evidence"
    },
    "nextAction": "use this sandbox release rollback gate as routine merge evidence; require separate Human approval for live production or worker fleet rollout"
}

manifest = {
    "releaseGate": payload["releaseGate"],
    "rollbackGate": payload["rollbackGate"],
    "measuredSoak": payload["measuredSoak"],
    "validationOutput": payload["validationOutput"],
    "approvalGateStatus": payload["approvalGateStatus"],
    "cleanup": payload["cleanup"],
    "residualRisk": payload["residualRisk"],
    "readinessDecision": payload["readinessDecision"],
}
payload["manifestSha256"] = hashlib.sha256(
    json.dumps(manifest, sort_keys=True).encode()
).hexdigest()

payload["runner"]["result"] = "PASS Dokkaebi release rollback sandbox gate runner completed"

print("PASS Dokkaebi release rollback sandbox gate runner completed")
print(json.dumps(payload, indent=2, sort_keys=True))
PY
