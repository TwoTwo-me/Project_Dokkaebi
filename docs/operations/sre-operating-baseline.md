# SRE Operating Baseline

This runbook defines the first production-readiness operating baseline for
Project Dokkaebi. It is intentionally docs-only: it does not mutate production,
workers, Docker, Kubernetes, SSH hosts, GitHub Projects, infrastructure, or
credentials.

The baseline gives Fire operators and Human reviewers a shared operating model
for SLO/SLA language, incident response, on-call ownership, paging decisions,
and error-budget review. Later PRs can replace the manual or deferred parts with
implemented systems, but they must preserve the evidence requirements here.

## Service Objectives

Initial SLOs are governed by
[`service-level-objectives.md`](service-level-objectives.md) and measured from
GitHub issue, PR, project, log, and result-packet evidence until the central
metrics backend design in [`central-metrics-backend.md`](central-metrics-backend.md)
is proven by local replay or approved sandbox metrics evidence.

The three initial SLO names are dispatch latency, recovery time, and review age,
and each one carries an error budget for review.

| SLO | Initial target | Measurement | Error budget |
| --- | --- | --- | --- |
| Dispatch latency | 90 percent of admitted ready work reaches dispatch readiness or an explicit blocked state within 15 minutes. | GitHub Project status change, workpad comment, or Fire log timestamp. | More than 5 misses in 30 days triggers review. |
| Recovery time | 95 percent of failed or stale leased work reaches recovered, blocked, or human-review state within 30 minutes of detection. | Durable lease, retry, route result, or closeout evidence. | More than 3 misses in 30 days freezes risky routing changes. |
| Review age | Human Review items receive reminder evidence within 2 business days and escalation evidence within 5 business days. | Issue comment, PR review, or project status evidence. | Any 5-business-day miss requires owner review. |

The service has no external SLA until a Human owner approves customer-facing
availability commitments. Current targets are internal SLOs for operating
discipline and error-budget discussion only.

## Incident Response

Use this incident response path for Fire, Manager, Hammer route, GitHub adapter,
credential, dispatch, closeout, and evidence-integrity failures.
The dedicated incident response runbook and current docs-only tabletop package
are captured in
[`incident-response-runbook-2026-06-13.md`](incident-response-runbook-2026-06-13.md).
The approved docs-only local incident response drill and postmortem exercise is
captured in
[`incident-response-drill-postmortem-2026-06-14.md`](incident-response-drill-postmortem-2026-06-14.md).

| Severity | Trigger | Response target | Commander |
| --- | --- | --- | --- |
| SEV0 | Production data loss, leaked credential, destructive unauthorized action, or broad duplicate dispatch. | Immediate stop and Human owner page. | Incident commander appointed by project owner. |
| SEV1 | Fire cannot dispatch approved work, all worker routes are unavailable, or closeout evidence is unreliable. | Triage within 30 minutes. | Fire operator until relieved. |
| SEV2 | Degraded dispatch latency, stale Human Review queue, repeated retry failures, or one route class unavailable. | Triage within 1 business day. | Assigned operator. |
| SEV3 | Documentation, dashboard, or non-blocking evidence gap. | Triage in normal planning. | Owning maintainer. |

Incident commander duties:

- declare severity and scope;
- stop unsafe dispatch when approval, credential, duplicate execution, or
  evidence integrity is uncertain;
- name the communication surface;
- assign mitigation owner and next update time;
- preserve issue, PR, log, and result-packet evidence for postmortem.

Communication surfaces:

- GitHub issue for audit-visible incident timeline;
- PR comment when the incident is caused by a proposed change;
- out-of-band Human contact only for urgent credential, production, or
  infrastructure risk, followed by a redacted GitHub summary.

Mitigation sequence:

1. Freeze new dispatch for the affected project, route, or permission class.
2. Confirm approval gates and credential scope.
3. Classify work items as completed, active lease, stale lease, failed retry,
   blocked, or unknown.
4. Recover only through documented lease, route, and closeout contracts.
5. Reopen or block any work item whose result evidence is incomplete.

Postmortem minimum:

- timeline with detection, declaration, mitigation, recovery, and closeout;
- customer or user impact, even when impact is internal only;
- root cause and contributing factors;
- evidence links and validation commands;
- follow-up owner, due date, and residual risk.

## On-Call And Paging

Paging integration is intentionally deferred until a Human owner approves a
specific paging backend and escalation roster. The detailed on-call paging and
alerting contract now lives in
[`on-call-paging-alerting.md`](on-call-paging-alerting.md). That owner decision
prevents the project from pretending it has production paging before a real
operator path exists.

Current on-call path:

- Primary: Fire operator watching GitHub issue, PR, and workflow surfaces.
- Escalation: project owner for SEV0, credential, production, infrastructure,
  or destructive action risk.
- Review-age reminders: GitHub issue or PR comments until alerting automation is
  implemented.
- Paging path: deferred; future implementation must name backend, roster,
  escalation windows, quiet-hours behavior, and test evidence.
- Approved sandbox delivery path: `on-call-delivery-sandbox-2026-06-14.md`
  captures SEV1/SEV2 routing, quiet-hours, delivery, escalation, cleanup, and
  residual-risk evidence without live paging authority.
- Alerting baseline: [`on-call-paging-alerting.md`](on-call-paging-alerting.md)
  defines alert taxonomy, severity mapping, escalation roster shape,
  notification routing, SLO linkage, metrics linkage, approval boundary, and
  test evidence shape.

No worker, Docker, Kubernetes, SSH, credential, deployment, production, or
GitHub Project control-plane mutation is authorized by this document.

## Validation

Run:

```bash
bash scripts/validate-sre-operating-baseline.sh
```

The validator checks the human-readable runbook and the structured control block
below. It rejects an empty or malformed baseline and rejects missing dispatch
SLO, recovery SLO, review-age SLO, incident commander, communication,
mitigation, postmortem, or resolved on-call decision.

<!-- sre-baseline:begin -->
```json
{
  "version": 1,
  "permissionLevel": "docs-only",
  "approvalGateStatus": "no live, infrastructure, credential, worker, deployment, production, or GitHub Project control-plane mutation reached",
  "slos": [
    {
      "id": "dispatch_latency",
      "name": "Dispatch latency",
      "target": "P90 admitted ready work reaches dispatch readiness or explicit blocked state within 15 minutes",
      "measurement": "GitHub Project status change, workpad comment, or Fire log timestamp",
      "errorBudget": "More than 5 misses in 30 days triggers review"
    },
    {
      "id": "recovery_time",
      "name": "Recovery time",
      "target": "P95 failed or stale leased work reaches recovered, blocked, or human-review state within 30 minutes of detection",
      "measurement": "Durable lease, retry, route result, or closeout evidence",
      "errorBudget": "More than 3 misses in 30 days freezes risky routing changes"
    },
    {
      "id": "review_age",
      "name": "Review age",
      "target": "Human Review items receive reminder evidence within 2 business days and escalation evidence within 5 business days",
      "measurement": "Issue comment, PR review, or project status evidence",
      "errorBudget": "Any 5-business-day miss requires owner review"
    }
  ],
  "incidentRunbook": {
    "severityLevels": ["SEV0", "SEV1", "SEV2", "SEV3"],
    "commander": "Incident commander is appointed by project owner for SEV0/SEV1 and defaults to Fire operator until relieved",
    "communication": "GitHub issue or PR timeline is the audit-visible communication surface; urgent out-of-band contact must be summarized back to GitHub",
    "mitigation": "Freeze affected dispatch, confirm approval and credential scope, classify leases/results, recover only through documented contracts",
    "postmortem": "Postmortem records timeline, impact, root cause, evidence, validation, owner, due date, and residual risk"
  },
  "onCallPaging": {
    "status": "intentionally_deferred",
    "ownerDecision": "Paging backend and rota are deferred until a Human owner approves a specific backend, roster, and escalation window",
    "currentPath": "Fire operator watches GitHub issue, PR, workflow, and result-packet surfaces",
    "pagingPath": "Deferred paging path must name backend, roster, quiet-hours behavior, and test evidence before production use; approved local sandbox delivery evidence is captured in docs/operations/on-call-delivery-sandbox-2026-06-14.md"
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
<!-- sre-baseline:end -->

## Remaining Gaps

This baseline does not authorize live operations by itself. Approved local
incident response, on-call delivery, central metrics, release rollback, restore,
and route-health sandbox evidence exists, while live paging delivery, runtime
postmortem automation, capacity planning, long-running soak tests, and
production operations exercises remain separately approval-gated.
