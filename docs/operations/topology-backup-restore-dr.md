# Topology Backup Restore And Disaster Recovery Baseline

This runbook defines the docs-only baseline for Project Dokkaebi environment
topology, backup, restore, and disaster recovery evidence. It does not
authorize live workers, Docker, Kubernetes, SSH hosts, Proxmox changes, GitHub
Project control-plane writes, credentials, infrastructure mutation,
deployments, production writes, or customer-facing operations.

The baseline exists so Fire operators and Human reviewers can evaluate whether
development, sandbox, staging, and production concerns are separated before any
runtime environment is promoted. Later work can replace this local validation
path with an approved sandbox or production drill, but the evidence shape and
approval boundary here must remain intact.

## Environment Topology

Each environment tier has a separate purpose, isolation rule, worker-route
policy, and mutation boundary.

| Tier | Purpose | Isolation | Worker routes | Mutation boundary |
| --- | --- | --- | --- | --- |
| Development | Local coding, docs, deterministic validators, and fixture-based recovery checks. | User-local workspace and disposable worktrees. | Local route only unless a named dev worker was explicitly approved. | Docs and local validation only. |
| Sandbox | Approved issue-processing and worker-routing exercises against non-production projects or fixtures. | Dedicated sandbox project, branch, worktree, and credentials. | Local, SSH, Docker, or Kubernetes routes only when the exact target and operation are approved. | Sandbox mutation requires recorded Human approval. |
| Staging | Release-candidate verification, restore rehearsal, route inventory proof, and rollback rehearsal before production. | Separate repository/project state, separated credentials, and no production data. | Only routes proven by the toolchain bootstrap contract and named in the release issue. | Staging mutation requires explicit approval and closeout evidence. |
| Production | Human-approved service operation for real users and durable audit records. | Production credentials, data, project state, logs, and backups are isolated from all lower tiers. | Production worker routes are disabled until a later ADR grants a narrow exception. | Production mutation requires explicit Human approval and result evidence. |

The HA assumption is active/passive for Fire until runtime clustering is proven:
one active Fire instance owns leases, a standby instance may recover only from
the durable lease and backup surfaces, and no environment may dispatch from two
active controllers at once. GitHub remains an external dependency; local state
must be recoverable from issue, PR, lease, route, log, and result-packet
evidence.

## Backup Targets

The backup target list is intentionally narrow and evidence-oriented. It names
what must be backed up before production use, without claiming that production
backup automation already exists.

| Backup target | Source | Target | Cadence | Retention | Owner |
| --- | --- | --- | --- | --- | --- |
| Project state export | GitHub issues, PRs, project item fields, labels, and workpad comments. | Versioned export bundle or approved object storage path. | Before release and daily after production approval. | 90 days minimum for pilot, one year after production approval. | Fire operator. |
| Lease and retry state | Durable lease store, idempotency keys, retry ledger, and route-result summaries. | Encrypted backup bundle or approved database snapshot. | Hourly after durable storage exists. | 30 days minimum. | Fire operator. |
| Worker route inventory | Local, SSH, Docker, and Kubernetes route configuration without secrets. | Checked-in sanitized inventory or approved config backup. | Before route changes and after bootstrap. | One year. | Release operator. |
| Evidence package | Validation logs, result packets, approval-gate status, rollback decisions, and closeout summaries. | GitHub issue/PR timeline plus immutable export once implemented. | Every PR or incident closeout. | One year minimum; longer retention requires compliance decision. | Manager reviewer. |

Backup material must not include raw secrets, auth files, cookies, tokens, or
private machine state. Secret material must stay behind the credential broker.

## Restore Path

Every restore drill must record each restore step, the operator, the evidence
surface, and the approval-gate status.

| Restore step | Operator | Evidence |
| --- | --- | --- |
| Identify restore point | Restore operator | Backup ID, timestamp, source environment, and requested RPO. |
| Rebuild isolated target | Restore operator | Environment tier, worktree or runtime target, and no-production-data statement. |
| Restore project and lease state | Fire operator | Project export, lease snapshot, retry ledger, route-result summary, and idempotency check. |
| Validate service contract | Manager reviewer | Contract docs, readiness, targeted topology/DR validation, and result-packet evidence. |
| Close drill | Human owner or delegated reviewer | RPO result, RTO result, residual risk, next issue, and approval boundary. |

Initial RPO is 24 hours for project/evidence exports and 1 hour for lease/retry
state after durable storage exists. Initial RTO is 4 hours for a docs-only or
sandbox restore and 8 hours for a future approved production restore. These are
planning assumptions, not external SLA promises.

## Disaster Recovery Roles

The DR role model keeps authority separate from execution:

- Incident commander declares severity, scope, communication surface, and stop
  condition.
- Restore operator executes the documented restore step sequence.
- Fire operator validates lease, route, retry, and closeout integrity.
- Human approver authorizes any sandbox, staging, production, credential, or
  infrastructure mutation.
- Manager reviewer verifies evidence retention, residual risk, and next action.

Communication belongs in a GitHub issue, PR, incident timeline, or checked-in
result packet. Private memory is not acceptable disaster recovery evidence.

## Evidence Retention

Evidence retention has three layers:

1. GitHub timeline evidence for issues, PRs, approvals, checks, and closeout.
2. Repository evidence for docs, validators, fixtures, and sanitized examples.
3. Future immutable audit export for signed evidence bundles and retention
   policy enforcement.

Until immutable export exists, the gap must remain visible in readiness
criteria. Retained evidence must be redacted for secrets and private machine
state before it is linked from issues, PRs, or result packets.

## Drill Evidence

DR drill evidence must include:

- drill ID and date;
- environment tier;
- permission level;
- backup target and restore point;
- restore step transcript;
- RPO result and RTO result;
- DR roles and operator identities;
- validation output;
- evidence retention surface;
- approval-gate status;
- residual risk and next action.

The drill evidence shape is reusable for local fixture drills, approved sandbox
drills, and future production drills. A production drill still requires a
separate Human approval record.

## Approval Boundary

This document authorizes docs-only planning and local validation that does not
mutate live systems. It does not authorize live mutation. Any sandbox, worker,
Docker, Kubernetes, SSH, Proxmox, remote host, credential, production,
deployment, infrastructure, or GitHub Project control-plane operation requires
explicit Human approval under
[`../policies/authority-and-safety.md`](../policies/authority-and-safety.md).

## Validation

Run:

```bash
bash scripts/validate-topology-backup-restore-dr.sh
```

The validator checks the human-readable runbook and the structured control
block below. It rejects empty baseline content, malformed control data, missing
environment tier, HA assumption, backup target, restore step, RPO, RTO, DR role,
evidence retention, drill evidence shape, approval boundary, or unauthorized
live mutation wording.

<!-- topology-backup-dr:begin -->
```json
{
  "version": 1,
  "permissionLevel": "docs-only",
  "approvalGateStatus": "no live, worker, Docker, Kubernetes, SSH, Proxmox, remote host, credential, production, deployment, infrastructure, or GitHub Project control-plane mutation reached",
  "environments": {
    "development": {
      "purpose": "Local coding, docs, deterministic validators, and fixture-based recovery checks",
      "isolation": "User-local workspace and disposable worktrees",
      "workerRoutes": ["local"],
      "mutationBoundary": "Docs and local validation only"
    },
    "sandbox": {
      "purpose": "Approved issue-processing and worker-routing exercises against non-production projects or fixtures",
      "isolation": "Dedicated sandbox project, branch, worktree, and credentials",
      "workerRoutes": ["local", "ssh", "docker", "kubernetes when approved"],
      "mutationBoundary": "Sandbox mutation requires recorded Human approval"
    },
    "staging": {
      "purpose": "Release-candidate verification, restore rehearsal, route inventory proof, and rollback rehearsal before production",
      "isolation": "Separate repository/project state, separated credentials, and no production data",
      "workerRoutes": ["routes proven by toolchain bootstrap and named in the release issue"],
      "mutationBoundary": "Staging mutation requires explicit approval and closeout evidence"
    },
    "production": {
      "purpose": "Human-approved service operation for real users and durable audit records",
      "isolation": "Production credentials, data, project state, logs, and backups are isolated from lower tiers",
      "workerRoutes": ["disabled until a later ADR grants a narrow exception"],
      "mutationBoundary": "Production mutation requires explicit Human approval and result evidence"
    }
  },
  "haAssumptions": {
    "fire": "Active/passive Fire controller until runtime clustering is proven",
    "github": "GitHub is an external dependency whose state must be exported for recovery evidence",
    "workers": "Worker routes are replaceable capacity, not authoritative state stores",
    "storage": "Durable leases and evidence exports are required before production claims"
  },
  "backupTargets": [
    {
      "id": "project_state_export",
      "source": "GitHub issues, PRs, project item fields, labels, and workpad comments",
      "target": "Versioned export bundle or approved object storage path",
      "cadence": "Before release and daily after production approval",
      "retention": "90 days minimum for pilot, one year after production approval",
      "owner": "Fire operator",
      "evidence": "Export manifest and validation output"
    },
    {
      "id": "lease_retry_state",
      "source": "Durable lease store, idempotency keys, retry ledger, and route-result summaries",
      "target": "Encrypted backup bundle or approved database snapshot",
      "cadence": "Hourly after durable storage exists",
      "retention": "30 days minimum",
      "owner": "Fire operator",
      "evidence": "Snapshot manifest and restore validation"
    },
    {
      "id": "evidence_package",
      "source": "Validation logs, result packets, approval-gate status, rollback decisions, and closeout summaries",
      "target": "GitHub timeline plus immutable export once implemented",
      "cadence": "Every PR or incident closeout",
      "retention": "One year minimum",
      "owner": "Manager reviewer",
      "evidence": "Evidence package manifest"
    }
  ],
  "restorePlan": {
    "steps": [
      "Identify restore point",
      "Rebuild isolated target",
      "Restore project and lease state",
      "Validate service contract",
      "Close drill"
    ],
    "verification": "Contract docs, readiness, targeted topology/DR validation, lease/retry idempotency, and result-packet evidence",
    "rpo": "24 hours for project/evidence exports and 1 hour for lease/retry state after durable storage exists",
    "rto": "4 hours for docs-only or sandbox restore and 8 hours for future approved production restore"
  },
  "disasterRecovery": {
    "roles": {
      "incidentCommander": "Declares severity, scope, communication surface, and stop condition",
      "restoreOperator": "Executes the documented restore step sequence",
      "fireOperator": "Validates lease, route, retry, and closeout integrity",
      "humanApprover": "Authorizes sandbox, staging, production, credential, or infrastructure mutation",
      "managerReviewer": "Verifies evidence retention, residual risk, and next action"
    },
    "failoverDecision": "Human owner approval is required before staging or production failover",
    "communicationSurface": "GitHub issue, PR, incident timeline, or checked-in result packet"
  },
  "evidenceRetention": {
    "storageSurface": "GitHub timeline, repository fixtures, and future immutable export",
    "retentionPolicy": "90 days minimum for pilot evidence and one year minimum after production approval",
    "immutableExportGap": "Immutable audit export remains a separate readiness gap until implemented",
    "redactionPolicy": "No secrets, auth files, cookies, tokens, or private machine state in retained evidence"
  },
  "drillEvidence": {
    "shape": {
      "drillId": "required",
      "environment": "required",
      "permissionLevel": "required",
      "backupTarget": "required",
      "restorePoint": "required",
      "rpo": "required",
      "rto": "required",
      "restoreSteps": "required",
      "drRoles": "required",
      "validationOutput": "required",
      "evidenceRetention": "required",
      "approvalGateStatus": "required",
      "residualRisk": "required"
    },
    "privateMemoryPolicy": "Evidence must be captured in GitHub issue, PR, result packet, or checked-in fixture without secrets, auth files, cookies, tokens, or private machine state",
    "storageSurface": "GitHub issue, pull request, result packet, or checked-in example fixture"
  },
  "requiredEvidence": [
    "changed artifacts and rationale",
    "acceptance-criteria evidence",
    "validation command output",
    "approval-gate status",
    "residual risk and next action"
  ]
}
```
<!-- topology-backup-dr:end -->

## Remaining Gaps

This baseline does not finish infrastructure readiness. Remaining work includes
approved sandbox restore evidence, measured restore drill timing, real backup
automation, immutable audit export, production topology approval, central
metrics, and routine disaster recovery exercises.
