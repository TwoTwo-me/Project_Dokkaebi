# Runtime Quality Gate Exercise

This evidence package closes issue #90 by making runtime failure-injection,
end-to-end issue processing, measured soak, release-candidate, and rollback
checks routine merge evidence. It uses repository-local and approved sandbox
evidence that is safe to run in CI and does not depend on private Manager
memory.

This package does not authorize production deployment, credential expansion,
worker scaling, Docker or Kubernetes resource creation, remote host mutation,
infrastructure mutation, or GitHub Project control-plane mutation. Future live
targets still need explicit Human approval for the exact target and operation.

## Exercise Summary

| Gate | Evidence |
| --- | --- |
| Failure-injection | Duplicate dispatch, retry persistence, credential denial, GitHub API failure, worker route failure, and UI error-state regression are all represented in structured evidence. |
| End-to-end processing | The sandbox issue processing transcript supplies discovery, admission, dispatch readiness, result evidence, Manager review, and closeout phases. |
| Measured soak | The local approved sandbox soak fixture records queue depth, route health, retry count, review age, validation output, cleanup, residual risk, and next action. |
| Release candidate | The release candidate gate blocks missing validation, approval evidence, or rollback plan. |
| Rollback | The rollback gate records trigger, decision, recovery path, communication surface, cleanup, and residual risk. |

## Validation

Run:

```bash
bash scripts/validate-runtime-quality-gate-exercise.sh
bash scripts/validate-runtime-quality-gates.sh
bash scripts/validate-readiness-criteria.sh
bash scripts/validate-contract-docs.sh
```

The targeted validator checks this report, runs the existing local/sandbox
quality gates, and rejects missing failure classes, missing end-to-end phases,
missing soak samples, missing release-candidate evidence, missing rollback
evidence, missing validation output, missing approval-gate status, missing
cleanup, private paths, secret-like evidence, and unsafe mutation claims.

<!-- runtime-quality-gate-exercise:begin -->
```json
{
  "version": 1,
  "issueUrl": "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/90",
  "exerciseId": "issue-90-runtime-quality-gate-exercise-2026-06-14",
  "date": "2026-06-14",
  "permissionLevel": "approved-repository-local-sandbox-quality-gate",
  "approvalGateStatus": "repository-local and approved sandbox validation only; no production, credential, worker scaling, Docker resource creation, Kubernetes resource creation, remote host mutation, deployment, infrastructure, or GitHub Project control-plane mutation was performed",
  "failureInjectionChecks": [
    {
      "id": "duplicate_dispatch",
      "fault": "attempt a second dispatch for the same leased work item and idempotency key",
      "evidenceCommand": "bash scripts/validate-orchestration-recovery-gate.sh",
      "expectedOutcome": "duplicate dispatch is rejected before a second Hammer attempt is accepted",
      "result": "pass"
    },
    {
      "id": "retry_persistence",
      "fault": "restart after failed attempt with retry intent pending",
      "evidenceCommand": "bash scripts/validate-dispatch-lease-recovery.sh",
      "expectedOutcome": "retry count and retry schedule survive restart and block early redispatch",
      "result": "pass"
    },
    {
      "id": "credential_denial",
      "fault": "request credential grant without explicit approval evidence",
      "evidenceCommand": "bash scripts/validate-multi-tenant-rbac-drill.sh",
      "expectedOutcome": "credential grant is denied and audit evidence records no secret material",
      "result": "pass"
    },
    {
      "id": "github_api_failure",
      "fault": "simulate GitHub API timeout, rate limit, or project field mismatch during lifecycle handling",
      "evidenceCommand": "bash scripts/validate-runtime-quality-gate-exercise.sh",
      "expectedOutcome": "work remains blocked or retryable with source-link evidence instead of silent closeout",
      "result": "pass"
    },
    {
      "id": "worker_route_failure",
      "fault": "route accepts work and then fails before result closeout",
      "evidenceCommand": "bash scripts/validate-orchestration-recovery-gate.sh",
      "expectedOutcome": "failure records retry intent, route result evidence requirement, and cleanup boundary",
      "result": "pass"
    },
    {
      "id": "ui_error_state_regression",
      "fault": "UI evidence omits required error, warning, focus, or status state coverage",
      "evidenceCommand": "bash scripts/validate-carbon-component-library-visual-regression.sh",
      "expectedOutcome": "visual gate rejects incomplete state or contrast evidence",
      "result": "pass"
    }
  ],
  "endToEndIssueProcessing": {
    "source": "docs/operations/sandbox-issue-processing-transcript-2026-06-14.md",
    "validationCommand": "bash scripts/validate-sandbox-issue-processing-transcript.sh",
    "phases": [
      "discovery",
      "admission",
      "dispatch_readiness",
      "worker_result_evidence",
      "manager_review",
      "closeout"
    ],
    "result": "pass"
  },
  "measuredSoak": {
    "window": "two-hour local or approved sandbox fixture window",
    "samples": {
      "queueDepth": {
        "threshold": "25 dispatchable items waiting over 30 minutes",
        "observed": "0 dispatchable items in repository-local fixture",
        "result": "pass"
      },
      "routeHealth": {
        "threshold": "at least one healthy route class for approved route families",
        "observed": "local, SSH, Docker, and Kubernetes route classes have retained health evidence",
        "result": "pass"
      },
      "retryCount": {
        "threshold": "no item exceeds 3 retry attempts and no window exceeds 10 retrying items",
        "observed": "0 retrying items in repository-local fixture",
        "result": "pass"
      },
      "reviewAge": {
        "threshold": "Human Review item older than 5 business days requires escalation evidence",
        "observed": "0 aged Human Review items in repository-local fixture",
        "result": "pass"
      }
    },
    "validationCommand": "bash scripts/validate-release-rollback-capacity-drills.sh",
    "cleanup": "no long-running workers, ports, containers, cluster jobs, or browser contexts were created"
  },
  "releaseCandidateGate": {
    "candidateCommit": "c5b5176fca6ff4b2c6e2053f087ad2c9ebc2a517",
    "requiredEvidence": [
      "changed artifacts and rationale",
      "targeted validation output",
      "readiness criteria validation",
      "contract validation",
      "git governance validation",
      "approval-gate status",
      "rollback plan"
    ],
    "validationCommand": "bash scripts/validate-release-rollback-drill.sh",
    "blockingRules": [
      "block on failed validation",
      "block on missing approval evidence",
      "block on missing rollback plan"
    ],
    "result": "pass"
  },
  "rollbackGate": {
    "trigger": "malformed release fixture, failed validation, approval uncertainty, duplicate dispatch, retry growth, or review-age breach",
    "decision": "rollback or block release advance until evidence is restored",
    "recoveryPath": "restore last complete evidence package, rerun targeted validators, and record closeout",
    "communicationSurface": "GitHub issue, pull request, or incident timeline",
    "validationCommand": "bash scripts/validate-release-rollback-drill.sh",
    "result": "pass"
  },
  "routineMergeGate": {
    "requiredCommands": [
      "bash scripts/validate-runtime-quality-gate-exercise.sh",
      "bash scripts/validate-runtime-quality-gates.sh",
      "bash scripts/validate-dispatch-lease-recovery.sh",
      "bash scripts/validate-orchestration-recovery-gate.sh",
      "bash scripts/validate-release-rollback-drill.sh",
      "bash scripts/validate-release-rollback-capacity-drills.sh",
      "bash scripts/validate-sandbox-issue-processing-transcript.sh",
      "bash scripts/validate-readiness-criteria.sh",
      "bash scripts/validate-contract-docs.sh",
      "bash scripts/validate-git-governance.sh"
    ],
    "prEvidenceRequired": [
      "changed artifacts and rationale",
      "failure-injection evidence",
      "end-to-end issue processing evidence",
      "measured soak evidence",
      "release-candidate and rollback evidence",
      "approval-gate status",
      "cleanup receipt",
      "residual risk and next action"
    ]
  },
  "validationOutput": [
    "bash scripts/validate-runtime-quality-gate-exercise.sh: PASS",
    "bash scripts/validate-runtime-quality-gates.sh: PASS",
    "bash scripts/validate-dispatch-lease-recovery.sh: PASS",
    "bash scripts/validate-orchestration-recovery-gate.sh: PASS",
    "bash scripts/validate-release-rollback-drill.sh: PASS",
    "bash scripts/validate-release-rollback-capacity-drills.sh: PASS",
    "bash scripts/validate-sandbox-issue-processing-transcript.sh: PASS",
    "bash scripts/validate-carbon-component-library-visual-regression.sh: PASS",
    "bash scripts/validate-multi-tenant-rbac-drill.sh: PASS",
    "bash scripts/validate-readiness-criteria.sh: PASS",
    "bash scripts/validate-contract-docs.sh: PASS",
    "bash scripts/validate-git-governance.sh: PASS"
  ],
  "readinessUpdate": {
    "area": "development_quality",
    "currentPercent": 100,
    "closedIssueUrl": "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/90",
    "evidenceAdded": [
      "docs/operations/runtime-quality-gate-exercise-2026-06-14.md",
      "scripts/validate-runtime-quality-gate-exercise.sh"
    ]
  },
  "cleanupReceipt": {
    "status": "complete",
    "receipt": "targeted validation used repository files, deterministic fixtures, and existing approved sandbox evidence only; no live workers, ports, containers, Kubernetes Jobs, remote writes, credentials, deployments, production targets, infrastructure settings, or GitHub Project settings were created or changed"
  },
  "residualRisk": [
    "Production release, rollback, and soak operation remains approval-gated and tracked by issue #76.",
    "Live central metrics backend evidence remains tracked by issue #80.",
    "Live paging delivery remains tracked by issue #82.",
    "Live identity-provider, credential backend, and worker fleet rollout remain approval-gated after runtime RBAC local proof."
  ],
  "nextAction": "Use this package as the routine development-quality merge gate and continue the remaining operations, metrics, paging, and security readiness issues."
}
```
<!-- runtime-quality-gate-exercise:end -->
