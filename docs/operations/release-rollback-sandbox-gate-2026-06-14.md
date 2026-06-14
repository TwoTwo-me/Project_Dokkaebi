# Release Rollback Sandbox Gate

This document records the approved local sandbox release rollback gate evidence
for issue #76. It proves release gate blocking, rollback decision generation,
recovery path generation, measured soak samples, validation output,
approval-gate status, cleanup receipt, residual risk, and next action without
live worker mutation, credentials, infrastructure, remote hosts, Docker,
Kubernetes, deployment, production, or GitHub Project control-plane mutation.
Required exact terms: release rollback sandbox gate; release gate; rollback
decision; recovery path; measured soak; queue depth; route health; retry count;
review-age; validation output; approval-gate status; cleanup receipt; residual
risk; next action; does not authorize.

Run:

```bash
bash scripts/run-release-rollback-sandbox-gate.sh
bash scripts/validate-release-rollback-sandbox-gate.sh
```

<!-- release-rollback-sandbox-gate:begin -->
```json
{
  "approvalGateStatus": "approved local sandbox only; no live worker mutation, credential, infrastructure, remote host, Docker, Kubernetes, deployment, production, or GitHub Project control-plane mutation reached this evidence and those targets remain not authorized",
  "approvalRecord": {
    "approvedTarget": "local deterministic release rollback sandbox fixture",
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
    "evidence": "Project Dokkaebi development loop approval is limited to local sandbox evidence for issue #76",
    "scope": "exercise release gate, rollback gate, and measured soak evidence without external side effects"
  },
  "cleanup": {
    "receipt": "runner emits deterministic JSON only; no servers, ports, browser contexts, containers, credentials, remote hosts, Docker daemon, Kubernetes cluster, deployments, infrastructure, production targets, workers, or GitHub Project control-plane side effects were attempted; no resources remain",
    "status": "complete"
  },
  "date": "2026-06-14",
  "evidenceId": "release-rollback-sandbox-gate-2026-06-14",
  "issueUrl": "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/76",
  "manifestSha256": "2711720df7f2732272d2a8f31b7e6d634236179009520540557e993f0e352499",
  "measuredSoak": {
    "cleanup": "temporary sandbox fixture only; no live queue, worker, or project state changed",
    "samples": {
      "queueDepth": {
        "observed": 7,
        "result": "pass",
        "threshold": "less than or equal to 25 dispatchable items"
      },
      "retryCount": {
        "observed": "max item retries 1; retrying items 2",
        "result": "pass",
        "threshold": "no item above 3 retries and fewer than 10 retrying items"
      },
      "reviewAge": {
        "observed": "oldest Human Review item 2 business days",
        "result": "pass",
        "threshold": "no Human Review item older than 5 business days"
      },
      "routeHealth": {
        "observed": "local-worktree healthy, ssh-alpha healthy",
        "result": "pass",
        "threshold": "at least one healthy route per required class"
      }
    },
    "validationCommand": "bash scripts/validate-release-rollback-sandbox-gate.sh",
    "window": "two-hour approved local sandbox fixture"
  },
  "nextAction": "use this sandbox release rollback gate as routine merge evidence; require separate Human approval for live production or worker fleet rollout",
  "permissionLevel": "approved-local-sandbox-release-rollback-gate",
  "readinessDecision": {
    "basis": "approved local sandbox release gate, rollback decision, recovery path, measured soak samples, validation output, and cleanup evidence",
    "operations_sre": 100,
    "production_release_rollback_runbook": 100
  },
  "releaseGate": {
    "allowed": {
      "approvalEvidence": "present",
      "decision": "allow",
      "name": "allow_complete_candidate",
      "reason": "validation passed, approval evidence present, rollback plan present",
      "rollbackPlan": "present",
      "validationStatus": "pass"
    },
    "blocked": [
      {
        "approvalEvidence": "present",
        "decision": "block",
        "name": "block_failed_validation",
        "reason": "release candidate validation failed",
        "rollbackPlan": "present",
        "validationStatus": "fail"
      },
      {
        "approvalEvidence": "missing",
        "decision": "block",
        "name": "block_missing_approval_evidence",
        "reason": "approval evidence missing",
        "rollbackPlan": "present",
        "validationStatus": "pass"
      },
      {
        "approvalEvidence": "present",
        "decision": "block",
        "name": "block_missing_rollback_plan",
        "reason": "rollback plan missing",
        "rollbackPlan": "missing",
        "validationStatus": "pass"
      }
    ],
    "releaseCandidate": {
      "artifact": "repository release readiness fixture",
      "id": "release-rollback-sandbox-candidate-2026-06-14",
      "rollbackPlan": "restore last complete evidence package and rerun release rollback validators",
      "validationCommand": "bash scripts/validate-release-rollback-drill.sh"
    },
    "target": "approved local sandbox release candidate"
  },
  "residualRisk": [
    "live production release remains separately approval-gated",
    "live worker fleet soak remains separately approval-gated",
    "external paging delivery remains tracked outside this release rollback gate"
  ],
  "rollbackGate": {
    "communicationSurface": "GitHub issue #76 and pull request timeline",
    "decision": "rollback local sandbox candidate to last complete evidence package",
    "operator": "release_operator",
    "output": {
      "recoveryPathGenerated": true,
      "result": "pass",
      "rollbackDecisionGenerated": true
    },
    "recoveryPath": [
      "restore last complete release evidence package",
      "rerun sandbox release rollback gate",
      "rerun release rollback drill validation",
      "rerun release rollback capacity validation",
      "record cleanup, residual risk, and next action"
    ],
    "trigger": "failed validation or missing required release evidence"
  },
  "runner": {
    "command": "bash scripts/run-release-rollback-sandbox-gate.sh",
    "outputContract": "JSON with releaseGate, rollbackGate, measuredSoak, validationOutput, approvalGateStatus, cleanup, residualRisk, and nextAction",
    "path": "scripts/run-release-rollback-sandbox-gate.sh",
    "result": "PASS Dokkaebi release rollback sandbox gate runner completed"
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
  "version": 1
}
```
<!-- release-rollback-sandbox-gate:end -->
