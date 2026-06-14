# Release Rollback Capacity And Drill Baseline

This runbook defines the docs-only baseline for release, rollback, capacity,
soak, and operations drill evidence. It does not authorize live workers,
Docker, Kubernetes, SSH hosts, GitHub Project control-plane writes,
credentials, infrastructure, deployments, production writes, or customer-facing
operations.

The baseline exists so Fire operators and Human reviewers can evaluate release
readiness without relying on private memory. Later work can replace the local
validation path with an approved sandbox or production drill, but the evidence
shape and approval boundary here must remain intact.
The current local release and rollback drill package is
[`release-rollback-drill-2026-06-13.md`](release-rollback-drill-2026-06-13.md).

## Release Runbook

Every release candidate must move through a staged rollout. A stage is complete
only when its operator, validation evidence, communication surface, and rollback
decision are recorded.

| Stage | Operator | Required evidence | Communication path |
| --- | --- | --- | --- |
| Prepare | Release operator | Issue or PR scope, changed artifacts, linked readiness criteria, and approval-gate status. | GitHub issue or PR timeline. |
| Package | Release operator | Commit SHA, branch, validation commands, and artifact or documentation version. | PR comment. |
| Validate | Release operator plus reviewer | Contract, readiness, governance, and targeted release validation output. | PR check summary. |
| Stage rollout | Release operator | Local or approved-sandbox rollout transcript with staged rollout decision. | GitHub issue or PR timeline. |
| Closeout | Manager reviewer | Result evidence, residual risk, next issue, and rollback decision. | GitHub issue or PR closeout comment. |

The current staged rollout is local validation only. Any sandbox, worker,
remote host, infrastructure, deployment, production, credential, or GitHub
Project control-plane mutation requires explicit Human approval.

## Rollback Runbook

Rollback is triggered when a release candidate violates an approval boundary,
breaks contract validation, loses evidence integrity, causes duplicate
dispatch, causes unbounded retry growth, or exceeds the SRE review-age target.

| Rollback trigger | Operator | Evidence | Communication |
| --- | --- | --- | --- |
| Contract or readiness gate failure | Release operator | Failed command, impacted file, and revert or fix decision. | PR comment. |
| Approval boundary uncertainty | Human owner or delegated release operator | Approval record, blocked scope, and safe rollback decision. | GitHub issue timeline. |
| Duplicate dispatch or retry growth | Fire operator | Lease, route, retry, and closeout evidence. | Incident or work issue. |
| Review-age breach | Manager reviewer | Aged Human Review item, reminder, and escalation evidence. | Issue or PR comment. |

Rollback closeout must name the rollback trigger, operator, evidence, and
communication surface. A rollback is not complete if any of those fields are
missing.

## Capacity And Soak Plan

Capacity work is still local and planning-oriented. The thresholds below are
initial operating tripwires, not measured production capacity guarantees.

| Surface | Threshold | Local validation path |
| --- | --- | --- |
| Queue | More than 25 dispatchable items waiting over 30 minutes triggers capacity review. | Parse GitHub Project or fixture status export. |
| Worker | Any route class below one healthy route for more than 15 minutes blocks new dispatch for that class. | Validate route inventory fixture. |
| Retry | More than 3 retry attempts for one work item or more than 10 retrying items in 30 minutes triggers recovery review. | Validate retry ledger fixture. |
| Review age | Any Human Review item older than 5 business days requires escalation evidence. | Validate issue or PR timestamp fixture. |

The soak baseline is a two-hour local or approved-sandbox drill that records
queue depth, route health, retry count, review-age samples, validation output,
and cleanup evidence. Long-running production soak tests remain future work.
For search and review consistency, this threshold is also named review age in
operator-facing evidence.
The local validation path uses fixtures and command output until an approved
sandbox drill exists.

## Drill Evidence

Drill evidence must be reviewable without private memory. Each drill record
must include:

- drill ID and date;
- scope and permission level;
- release candidate or fixture under test;
- staged rollout decision;
- rollback trigger and rollback decision;
- operator and reviewer;
- communication surface;
- command output, transcript, or approved sandbox evidence;
- approval-gate status;
- residual risk and next action.

Drill evidence can be stored in a GitHub issue, PR, result packet, or checked-in
example fixture. It must not include secrets, auth files, cookies, tokens, or
private machine state.

## Approval Boundary

This document authorizes docs-only planning and local validation that does not
mutate live systems. It does not authorize live mutation. Any sandbox, worker,
Docker, Kubernetes, SSH, remote host, credential, production, deployment,
infrastructure, or GitHub Project control-plane operation requires explicit
Human approval under
[`../policies/authority-and-safety.md`](../policies/authority-and-safety.md).

## Validation

Run:

```bash
bash scripts/validate-release-rollback-capacity-drills.sh
```

The validator checks the human-readable runbook and the structured control
block below. It rejects empty baseline content, malformed control data, missing
staged rollout, rollback trigger, operator, evidence, communication, queue
threshold, worker threshold, retry threshold, review-age threshold, local
validation path, drill evidence shape, approval boundary, or unauthorized live
mutation wording.

<!-- release-rollback-capacity:begin -->
```json
{
  "version": 1,
  "permissionLevel": "docs-only",
  "approvalGateStatus": "no live, worker, Docker, Kubernetes, SSH, remote host, credential, production, deployment, infrastructure, or GitHub Project control-plane mutation reached",
  "release": {
    "stagedRollout": [
      "prepare",
      "package",
      "validate",
      "stage rollout",
      "closeout"
    ],
    "operator": "Release operator records scope, commit, validation, staged rollout decision, and closeout evidence",
    "evidence": [
      "issue or PR scope",
      "changed artifacts",
      "validation commands",
      "staged rollout transcript",
      "rollback decision"
    ],
    "communication": "GitHub issue or PR timeline is the audit-visible communication surface"
  },
  "rollback": {
    "trigger": "Approval uncertainty, failed contract/readiness gate, evidence integrity loss, duplicate dispatch, unbounded retry growth, or review-age breach",
    "operator": "Release operator, Fire operator, Manager reviewer, or Human owner according to trigger severity",
    "evidence": [
      "failed command or breach evidence",
      "impacted scope",
      "rollback or fix decision",
      "closeout result"
    ],
    "communication": "GitHub issue, PR, or incident timeline records rollback trigger and decision"
  },
  "capacity": {
    "queueThreshold": "More than 25 dispatchable items waiting over 30 minutes triggers capacity review",
    "workerThreshold": "Any route class below one healthy route for more than 15 minutes blocks new dispatch for that class",
    "retryThreshold": "More than 3 retry attempts for one item or more than 10 retrying items in 30 minutes triggers recovery review",
    "reviewAgeThreshold": "Any Human Review item older than 5 business days requires escalation evidence",
    "soakWindow": "Two-hour local or approved-sandbox drill records queue depth, route health, retry count, review-age samples, validation output, and cleanup evidence",
    "localValidationPath": "Validate queue, route inventory, retry ledger, and review-age fixtures without live mutation"
  },
  "drillEvidence": {
    "shape": {
      "drillId": "required",
      "permissionLevel": "required",
      "releaseCandidate": "required",
      "stagedRolloutDecision": "required",
      "rollbackTrigger": "required",
      "rollbackDecision": "required",
      "operator": "required",
      "communicationSurface": "required",
      "validationOutput": "required",
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
<!-- release-rollback-capacity:end -->

## Remaining Gaps

This baseline does not finish operations readiness. A local release and rollback
drill is captured in
[`release-rollback-drill-2026-06-13.md`](release-rollback-drill-2026-06-13.md),
but automated runtime release gates, approved sandbox rollback evidence,
measured capacity and soak evidence, production paging implementation, central
metrics, approved sandbox restore evidence, multi-provider route-health proof,
and routine operations exercises remain.
