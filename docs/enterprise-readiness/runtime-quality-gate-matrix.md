# Runtime Quality Gate Matrix

This document defines the docs-only risk-based quality gate matrix for Project
Dokkaebi runtime modules. It maps each high-risk surface to required tests,
review gates, accepted residual risk, evidence artifacts, and next action.
The matrix covers orchestration, credential, GitHub adapter, worker provider,
and UI surfaces.

This matrix does not run live runtime tests, mutate credentials, scale workers,
change infrastructure, deploy, or write production state. Runtime, worker,
credential, infrastructure, Docker, Kubernetes, remote host, deployment,
production, or GitHub Project control-plane mutation requires explicit Human
approval under [`../policies/authority-and-safety.md`](../policies/authority-and-safety.md).

## Matrix Summary

| Risk surface | Required gates | Accepted risk until follow-up |
| --- | --- | --- |
| Orchestration | dispatch lease, recovery gate, replay fixture, release rollback checks | live multi-worker failure injection is not routine |
| Credential | authority policy, credential broker boundary, RBAC design and replay, compliance evidence checks | live broker denial and revocation drills are not routine |
| GitHub adapter | Project lifecycle contract, git governance, PR checks, source-link audit evidence | live GitHub API failure injection is not routine |
| Worker provider | worker ticket/result packet, route metadata, sandbox restore evidence, closeout review checks | multi-provider route failure and capacity soak are not routine |
| UI | Carbon baseline, onboarding troubleshooting, alert routing, focus/contrast/state evidence | cross-browser visual regression and CI artifacts are not routine |

## Required Merge Evidence

Every PR that touches a listed surface must include:

- changed artifacts and rationale;
- targeted validation command output for the touched surface;
- regression validation for adjacent contract surfaces;
- approval-gate status;
- cleanup receipt when runtime, tmux, browser, temp files, or external services
  are spawned;
- accepted residual risk and next action when the routine gate is not yet
  automated.

## Accepted Risk Boundary

Accepted risk is temporary reviewable evidence, not a release waiver. A surface
may rely on accepted risk only when it names the missing routine gate, links the
follow-up issue, and records why the current PR remains docs-only or local
validation. Missing accepted-risk text fails validation.

## Residual Risk And Next Action

Runtime failure injection, end-to-end issue processing, measured soak,
release-candidate verification, and rollback gates are still not routine merge
gates. Next action: complete issue #90 with runtime or explicitly approved
sandbox evidence.

<!-- runtime-quality-gates:begin -->
```json
{
  "version": 1,
  "permissionLevel": "docs-only quality gate matrix",
  "approvalBoundary": "This matrix does not authorize credential, infrastructure, worker, Docker, Kubernetes, remote host, deployment, production, or GitHub Project control-plane mutation without explicit Human approval",
  "globalGates": {
    "defaultCommands": [
      "bash scripts/validate-readiness-criteria.sh",
      "bash scripts/validate-contract-docs.sh",
      "bash scripts/validate-git-governance.sh"
    ],
    "prEvidence": [
      "changed artifacts and rationale",
      "targeted validation command output",
      "adjacent regression validation",
      "approval-gate status",
      "cleanup receipt when resources are spawned",
      "accepted residual risk and next action"
    ],
    "failureHandling": [
      "missing required tests fails closed",
      "missing accepted risk fails closed",
      "missing approval-gate status fails closed",
      "missing cleanup receipt fails closed when runtime resources are spawned",
      "unsafe authority wording fails closed"
    ]
  },
  "surfaces": [
    {
      "id": "orchestration",
      "name": "Orchestration",
      "riskLevel": "critical",
      "owner": "Runtime quality owner",
      "riskClasses": [
        "duplicate dispatch",
        "retry loss after restart",
        "stale lease recovery",
        "closeout without result evidence"
      ],
      "requiredTests": [
        "bash scripts/validate-dispatch-lease-recovery.sh",
        "bash scripts/validate-orchestration-recovery-gate.sh",
        "bash scripts/validate-release-rollback-drill.sh",
        "bash scripts/validate-release-rollback-capacity-drills.sh"
      ],
      "mergeGateCommands": [
        "bash scripts/validate-dispatch-lease-recovery.sh",
        "bash scripts/validate-orchestration-recovery-gate.sh",
        "bash scripts/validate-contract-docs.sh"
      ],
      "evidenceArtifacts": [
        "docs/operations/dispatch-lease-recovery.md",
        "docs/operations/orchestration-recovery-gate.md",
        "docs/operations/sandbox-issue-processing-transcript-2026-06-14.md",
        "docs/examples/replays/accepted-manager-fire-hammer.md"
      ],
      "acceptedRisk": [
        "repository-local sandbox issue processing transcript is captured",
        "live multi-worker failure injection is not a routine merge gate"
      ],
      "nextAction": "Add routine runtime failure-injection and soak quality gates in issue #90"
    },
    {
      "id": "credential",
      "name": "Credential",
      "riskLevel": "critical",
      "owner": "Security quality owner",
      "riskClasses": [
        "credential grant without approval",
        "secret-bearing evidence",
        "missing revocation path",
        "cross-tenant access"
      ],
      "requiredTests": [
        "bash scripts/validate-multi-tenant-rbac.sh",
        "bash scripts/validate-multi-tenant-rbac-drill.sh",
        "bash scripts/validate-compliance-package.sh",
        "bash scripts/validate-compliance-audit-review.sh"
      ],
      "mergeGateCommands": [
        "bash scripts/validate-multi-tenant-rbac.sh",
        "bash scripts/validate-contract-docs.sh"
      ],
      "evidenceArtifacts": [
        "docs/policies/authority-and-safety.md",
        "docs/policies/multi-tenant-rbac.md",
        "docs/policies/multi-tenant-rbac-drill-2026-06-13.md"
      ],
      "acceptedRisk": [
        "live broker denial and credential revocation drills are not routine merge gates",
        "runtime RBAC enforcement remains tracked by issue #74"
      ],
      "nextAction": "Implement runtime multi-tenant RBAC enforcement gates in issue #74"
    },
    {
      "id": "github_adapter",
      "name": "GitHub adapter",
      "riskLevel": "high",
      "owner": "Project integration quality owner",
      "riskClasses": [
        "project status mismatch",
        "missing source links",
        "PR checks bypassed",
        "GitHub API failure"
      ],
      "requiredTests": [
        "bash scripts/validate-git-governance.sh",
        "bash scripts/validate-contract-docs.sh",
        "bash scripts/validate-readiness-criteria.sh"
      ],
      "mergeGateCommands": [
        "bash scripts/validate-git-governance.sh",
        "bash scripts/validate-contract-docs.sh"
      ],
      "evidenceArtifacts": [
        "WORKFLOW.md",
        "docs/policies/git-governance.md",
        "docs/github-project-v2-symphony-playbook.md"
      ],
      "acceptedRisk": [
        "live GitHub API failure injection is not a routine merge gate",
        "repository-local sandbox issue processing transcript is captured; live GitHub Project control-plane mutation remains approval-gated"
      ],
      "nextAction": "Add routine runtime failure-injection and soak quality gates in issue #90"
    },
    {
      "id": "worker_provider",
      "name": "Worker provider",
      "riskLevel": "high",
      "owner": "Worker quality owner",
      "riskClasses": [
        "wrong route selected",
        "missing route metadata",
        "worker result packet incomplete",
        "capacity unavailable"
      ],
      "requiredTests": [
        "bash scripts/validate-sandbox-restore-drill.sh",
        "bash scripts/validate-backup-restore-drill.sh",
        "bash scripts/validate-topology-backup-restore-dr.sh",
        "bash scripts/validate-contract-docs.sh"
      ],
      "mergeGateCommands": [
        "bash scripts/validate-sandbox-restore-drill.sh",
        "bash scripts/validate-contract-docs.sh"
      ],
      "evidenceArtifacts": [
        "docs/templates/worker-ticket.md",
        "docs/templates/worker-result-packet.md",
        "docs/operations/sandbox-restore-drill-2026-06-13.md"
      ],
      "acceptedRisk": [
        "multi-provider route failure and capacity soak are not routine merge gates",
        "multi-provider worker route-health proof remains tracked by issue #103"
      ],
      "nextAction": "Prove multi-provider worker route health and remote bootstrap rebuild in issue #103"
    },
    {
      "id": "ui",
      "name": "UI",
      "riskLevel": "high",
      "owner": "Product quality owner",
      "riskClasses": [
        "contrast regression",
        "missing keyboard focus state",
        "unclear onboarding action",
        "alert state not visible"
      ],
      "requiredTests": [
        "bash scripts/validate-carbon-ui-baseline.sh",
        "bash scripts/validate-onboarding-troubleshooting.sh",
        "bash scripts/validate-on-call-alert-routing-drill.sh",
        "bash scripts/validate-readiness-criteria.sh"
      ],
      "mergeGateCommands": [
        "bash scripts/validate-carbon-ui-baseline.sh",
        "bash scripts/validate-onboarding-troubleshooting.sh",
        "bash scripts/validate-readiness-criteria.sh"
      ],
      "evidenceArtifacts": [
        "docs/design/carbon-ui-baseline.md",
        "docs/product/onboarding-troubleshooting.md",
        "docs/operations/on-call-alert-routing-drill-2026-06-13.md"
      ],
      "acceptedRisk": [
        "cross-browser visual regression and CI artifacts are not routine merge gates",
        "component library and CI visual regression evidence remain tracked by issue #67"
      ],
      "nextAction": "Add component library and CI visual regression gate in issue #67"
    }
  ],
  "followUpIssueUrl": "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/90"
}
```
<!-- runtime-quality-gates:end -->
