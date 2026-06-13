# On-Call Paging And Alerting Baseline

This document defines the docs-only on-call paging and alerting baseline for
Project Dokkaebi. It does not configure or mutate a paging backend, alerting
service, GitHub Project control plane, infrastructure, workers, Docker,
Kubernetes, SSH hosts, credentials, deployments, production systems, or remote
hosts.

The goal is to give operators a reviewable contract for alert taxonomy, severity
mapping, escalation roster shape, paging backend decision, quiet-hours behavior,
notification routing, test evidence shape, SLO linkage, metrics linkage,
ownership, failure handling, approval boundary, permission level, and remaining
operational gaps before any real paging route is enabled.

## Enterprise Standard

On-call paging and alerting for Dokkaebi must:

- map each alert to an operating question, severity, SLO or metrics source,
  owner, and operator action;
- route urgent failures to an approved escalation roster without silently
  bypassing Human approval gates;
- preserve quiet-hours behavior, audit evidence, delivery evidence, and cleanup
  receipts for every alert routing drill;
- fail closed when the paging backend, escalation roster, notification sink,
  quiet-hours behavior, or test evidence is missing;
- keep all live alerting service, infrastructure, credential, worker, remote
  host, Docker, Kubernetes, deployment, production, and GitHub Project
  control-plane mutation outside this docs-only baseline.

## Alert Taxonomy

| Alert class | Primary signal | Default severity | Operator action |
| --- | --- | --- | --- |
| Dispatch latency burn | Admitted ready work exceeds the dispatch-latency SLO window. | SEV2 | Confirm queue state, worker capacity, approval gate, and dispatch lease state. |
| Recovery time burn | Failed or stale leased work exceeds the recovery-time SLO window. | SEV1 | Freeze risky routing, inspect lease/result evidence, and recover through documented contracts. |
| Stale Human Review | Human Review item misses reminder or escalation windows. | SEV3 escalating to SEV2 | Notify reviewer and project owner with issue or PR evidence. |
| Worker route capacity unavailable | A required route class has no healthy worker capacity. | SEV1 or SEV2 | Confirm route provider health, reject unsafe dispatch, and open capacity follow-up. |
| Validation failure spike | Governance, contract, or readiness validation failures exceed the alert rule. | SEV2 | Inspect failing validator, block merge when required checks fail, and preserve CI output. |
| Approval-boundary violation | A requested action reaches a gated authority class without approval evidence. | SEV0 or SEV1 | Stop execution, preserve evidence, and escalate to security owner and project owner. |
| Missing compliance evidence | Required closeout, audit export, or evidence package fields are absent. | SEV2 | Block closeout, request missing result-packet evidence, and update the audit package. |

## Severity Mapping

| Severity | Page behavior | Response target | Escalation path |
| --- | --- | --- | --- |
| SEV0 | Immediate page after explicit backend approval. | Immediate stop and owner contact. | Primary on-call, incident commander, security reviewer, project owner. |
| SEV1 | Immediate page when the route is approved; otherwise create urgent GitHub evidence and block dispatch. | Triage within 30 minutes. | Primary on-call, secondary on-call, incident commander. |
| SEV2 | Business-hours page or urgent notification based on approved quiet-hours policy. | Triage within 1 business day. | Primary on-call, service owner, affected tenant owner. |
| SEV3 | GitHub issue or PR comment, daily digest, or normal planning queue. | Triage in normal planning. | Owning maintainer or reviewer. |

SEV0 and SEV1 must never be downgraded only to avoid paging. If the paging
backend is not approved, the system must fail closed by creating auditable
GitHub evidence and blocking unsafe dispatch rather than pretending a page was
sent.

## Escalation Roster Shape

The approved roster must identify these roles before live paging:

- primary on-call owner;
- secondary on-call owner;
- incident commander;
- security reviewer for approval-boundary or credential risk;
- SRE owner for SLO, metrics, and routing failures;
- compliance reviewer for missing evidence or export failures;
- tenant owner when an alert is tenant scoped;
- project owner for SEV0, credential, production, infrastructure, or
  destructive-action risk.

Roster evidence must include rotation cadence, timezone, handoff time,
handoff evidence, backup coverage, escalation windows, out-of-office handling,
and the GitHub issue or PR surface where routing decisions are summarized.

## Paging Backend Decision

Paging integration remains deferred until a Human owner approves a concrete
backend, escalation roster, notification sinks, quiet-hours behavior, and alert
routing test plan. Candidate backends may include PagerDuty, Opsgenie, Grafana
OnCall, Alertmanager receivers, Slack or email notification adapters, or a
GitHub-only route for non-urgent notifications, but this document selects none
of them for live delivery.

The current approved path is audit-visible GitHub issue or PR evidence for
alerts and reminders. That path is not production paging. It is a fallback until
issue [#63](https://github.com/TwoTwo-me/Project_Dokkaebi/issues/63) captures
approved backend, roster, quiet-hours, delivery, cleanup, and residual-risk
evidence.

## Quiet-Hours Behavior

Quiet-hours policy must be explicit before live routing:

- timezone and business-hours window;
- SEV0 and approval-boundary exceptions that bypass quiet hours after backend
  approval;
- SEV1 routing behavior for recovery-time and route-capacity failures;
- SEV2 deferral, digest, or urgent notification rules;
- SEV3 digest or normal planning behavior;
- tenant-specific override rules;
- audit evidence showing whether quiet hours applied;
- cleanup evidence for any drill notification sink.

Without that policy, alert routing may create GitHub evidence and blocked state,
but it must not send live pages.

## Notification Routing

Notification routing must map every alert to:

- severity and alert class;
- source SLO or metric;
- project, repository, issue or PR, tenant, environment, and route class when
  available;
- primary and secondary sinks;
- quiet-hours decision;
- owner and escalation role;
- delivery or dry-run output;
- evidence link and cleanup receipt.

Initial sinks are GitHub issue comments, PR comments, check-run output, and
result-packet evidence. Chat, email, pager, Alertmanager, Grafana-managed
alerts, or managed paging services remain approval-gated until the backend
decision is recorded.

## Test Evidence Shape

Every alert routing drill must capture:

1. alert input fixture or metric evaluation output;
2. mapped alert class, severity, SLO linkage, and metrics linkage;
3. target roster role and notification sink;
4. quiet-hours decision;
5. delivery output or dry-run output;
6. approval-gate status;
7. cleanup receipt for any runtime, sink, temp file, or session used by the
   drill;
8. residual risk and next action;
9. link back to the issue, PR, result packet, or audit package that carries the
   evidence.

## SLO Linkage

The on-call baseline links to the SRE operating baseline:

- dispatch latency burn alerts map to the dispatch-latency SLO, error-budget
  review, dashboard panel, and fallback GitHub evidence;
- recovery time burn alerts map to the recovery-time SLO, stale lease evidence,
  route result evidence, and incident mitigation path;
- stale Human Review alerts map to the review-age SLO, reminder evidence,
  escalation evidence, and project owner review.

No external SLA is implied by this document. External SLA language still
requires explicit Human owner approval.

## Metrics Linkage

The central metrics backend design names the metric groups and alert rules that
feed this baseline:

- dispatch metrics for dispatch latency burn;
- recovery metrics for recovery time burn and stale lease counts;
- review metrics for Human Review age and reminder/escalation counts;
- worker capacity metrics for unavailable route classes;
- validation metrics for failure spikes;
- approval and authority metrics for approval-boundary violations;
- compliance metrics for missing evidence and immutable export failures.

Until metrics are replayed or captured from an approved sandbox, alert evidence
may use GitHub issue, PR, workflow, log, and result-packet timestamps as
fallback proof.

## Ownership

Every approved implementation must name:

- on-call owner;
- alert owner;
- SRE owner;
- metrics owner;
- security reviewer;
- compliance reviewer;
- tenant owner or tenant owner lookup rule;
- project owner for SEV0 and gated authority escalation.

## Failure Handling

Alerting fails closed when severity mapping is missing, owner mapping is
missing, the paging backend is unapproved, the roster is unapproved, quiet-hours
behavior is unknown, notification routing is ambiguous, delivery evidence is
missing, cleanup evidence is missing, SLO linkage is missing, metrics linkage is
missing, or the requested action would mutate credentials, infrastructure,
workers, Docker, Kubernetes, deployment, production, remote hosts, alerting
services, or GitHub Project control-plane settings without explicit Human
approval.

## Validation

Run:

```bash
bash scripts/validate-on-call-paging-alerting.sh
```

The validator rejects empty baseline content, malformed alerting data, missing
alert taxonomy, missing severity mapping, missing escalation roster shape,
missing paging backend decision, missing quiet-hours behavior, missing
notification routing, missing test evidence shape, missing SLO linkage, missing
metrics linkage, missing ownership, missing failure handling, missing approval
boundary, missing remaining operational gaps, missing permission level, or
unauthorized credential, production, infrastructure, worker, remote host,
Docker, Kubernetes, deployment, alerting service, or GitHub Project
control-plane mutation wording.

<!-- on-call-paging-alerting:begin -->
```json
{
  "version": 1,
  "permissionLevel": "docs-only baseline and local validation",
  "approvalBoundary": "This baseline does not authorize credential, production, infrastructure, worker, remote host, Docker, Kubernetes, SSH, deployment, alerting service, metrics service, paging service, or GitHub Project control-plane mutation without explicit Human approval",
  "alertTaxonomy": [
    {
      "id": "dispatch_latency_burn",
      "severity": "SEV2",
      "signal": "dispatch latency SLO burn from central metrics or fallback GitHub evidence",
      "operatorAction": "confirm queue state, worker capacity, approval gate, and dispatch lease state"
    },
    {
      "id": "recovery_time_burn",
      "severity": "SEV1",
      "signal": "recovery time SLO burn, stale lease count, or route result failure",
      "operatorAction": "freeze risky routing, inspect lease and result evidence, and recover through documented contracts"
    },
    {
      "id": "stale_human_review",
      "severity": "SEV3 escalating to SEV2",
      "signal": "review age SLO miss or missing reminder and escalation evidence",
      "operatorAction": "notify reviewer and project owner with issue or PR evidence"
    },
    {
      "id": "worker_route_capacity",
      "severity": "SEV1 or SEV2",
      "signal": "required worker route class unavailable",
      "operatorAction": "block unsafe dispatch and open capacity follow-up"
    },
    {
      "id": "validation_failure_spike",
      "severity": "SEV2",
      "signal": "governance, contract, readiness, or CI validation failure spike",
      "operatorAction": "inspect failing validator, block merge when required checks fail, and preserve CI output"
    },
    {
      "id": "approval_boundary_violation",
      "severity": "SEV0 or SEV1",
      "signal": "credential, production, infrastructure, worker, deployment, or control-plane authority reached without approval evidence",
      "operatorAction": "stop execution, preserve evidence, and escalate to security owner and project owner"
    },
    {
      "id": "missing_compliance_evidence",
      "severity": "SEV2",
      "signal": "result packet, audit export, compliance package, or immutable evidence missing required fields",
      "operatorAction": "block closeout, request missing evidence, and update audit package"
    }
  ],
  "severityMapping": {
    "SEV0": {
      "pageBehavior": "Immediate page after approved backend and roster exist",
      "responseTarget": "Immediate stop and owner contact",
      "escalationPath": ["primary_on_call", "incident_commander", "security_reviewer", "project_owner"]
    },
    "SEV1": {
      "pageBehavior": "Immediate page when route is approved; otherwise urgent GitHub evidence and blocked state",
      "responseTarget": "Triage within 30 minutes",
      "escalationPath": ["primary_on_call", "secondary_on_call", "incident_commander"]
    },
    "SEV2": {
      "pageBehavior": "Business-hours page or urgent notification based on approved quiet-hours policy",
      "responseTarget": "Triage within 1 business day",
      "escalationPath": ["primary_on_call", "service_owner", "tenant_owner"]
    },
    "SEV3": {
      "pageBehavior": "GitHub issue or PR comment, daily digest, or normal planning queue",
      "responseTarget": "Triage in normal planning",
      "escalationPath": ["owning_maintainer", "reviewer"]
    }
  },
  "escalationRosterShape": {
    "roles": [
      "primary_on_call",
      "secondary_on_call",
      "incident_commander",
      "security_reviewer",
      "sre_owner",
      "compliance_reviewer",
      "tenant_owner",
      "project_owner"
    ],
    "rotationCadence": "weekly or explicitly approved project cadence",
    "timezone": "recorded per roster entry",
    "handoffEvidence": "GitHub issue or PR comment records handoff time, outgoing owner, incoming owner, unresolved alerts, and next action",
    "backupCoverage": "secondary owner or project owner must be named for every active escalation window"
  },
  "pagingBackendDecision": {
    "status": "deferred_until_human_approval",
    "currentPath": "GitHub issue or PR evidence is the audit-visible fallback and is not production paging",
    "candidateBackends": ["PagerDuty", "Opsgenie", "Grafana OnCall", "Alertmanager receiver", "Slack adapter", "email adapter", "GitHub-only non-urgent route"],
    "approvalRequiredBeforeLiveUse": "Human owner must approve backend, roster, sinks, quiet-hours behavior, alert routing test plan, cleanup, and residual-risk handling"
  },
  "quietHoursBehavior": {
    "timezone": "must be recorded before live routing",
    "criticalBypass": "SEV0 and approval-boundary exceptions may bypass quiet hours only after backend approval",
    "sev1Behavior": "SEV1 recovery-time and route-capacity failures route according to approved escalation window",
    "nonCriticalHandling": "SEV2 may defer, digest, or notify based on approved policy; SEV3 stays in GitHub or planning queue",
    "tenantOverrides": "tenant-specific override rules must be recorded before use",
    "auditEvidence": "routing evidence records whether quiet hours applied and which rule decided the sink"
  },
  "notificationRouting": [
    "Map each alert to severity, alert class, source SLO or metric, project, repository, issue or PR, tenant, environment, route class, owner, primary sink, secondary sink, quiet-hours decision, delivery output, evidence link, and cleanup receipt",
    "Initial sinks are GitHub issue comments, PR comments, check-run output, and result-packet evidence",
    "Chat, email, pager, Alertmanager, Grafana-managed alerts, managed paging services, alerting service integrations, and GitHub Project control-plane changes remain approval-gated"
  ],
  "testEvidenceShape": [
    "alert input fixture or metric evaluation output",
    "mapped alert class, severity, SLO linkage, and metrics linkage",
    "target roster role and notification sink",
    "quiet-hours decision",
    "delivery output or dry-run output",
    "approval-gate status",
    "cleanup receipt",
    "residual risk and next action",
    "issue, PR, result packet, or audit package evidence link"
  ],
  "sloLinkage": {
    "dispatch_latency": "dispatch latency burn alert links to the dispatch latency SLO, error-budget review, metrics query, dashboard panel, operator action, and fallback GitHub evidence",
    "recovery_time": "recovery time burn alert links to the recovery time SLO, error-budget review, metrics query, stale lease evidence, route result evidence, incident mitigation, and fallback GitHub evidence",
    "review_age": "stale Human Review alert links to the review age SLO, error-budget review, metrics query, reminder evidence, escalation evidence, owner review, and fallback GitHub evidence"
  },
  "metricsLinkage": {
    "dispatch": "dispatch metrics feed dispatch latency burn",
    "recovery": "recovery metrics feed recovery time burn and stale lease alerts",
    "review": "review metrics feed Human Review age and escalation alerts",
    "worker_capacity": "worker capacity metrics feed route capacity unavailable alerts",
    "validation": "validation metrics feed failure spike alerts",
    "approval_authority": "approval and authority metrics feed approval-boundary violation alerts",
    "compliance": "compliance metrics feed missing evidence alerts"
  },
  "ownership": {
    "onCallOwner": "named before live paging",
    "alertOwner": "owns taxonomy and routing rules",
    "sreOwner": "owns SLO and runbook linkage",
    "metricsOwner": "owns metrics and dashboard linkage",
    "securityReviewer": "reviews approval-boundary and credential-risk alerts",
    "complianceReviewer": "reviews evidence and audit export alerts",
    "tenantOwner": "resolved from project or tenant mapping",
    "projectOwner": "owns SEV0 and gated authority escalation"
  },
  "failureHandling": [
    "Fail closed when severity mapping is missing",
    "Fail closed when owner mapping is missing",
    "Fail closed when paging backend is unapproved",
    "Fail closed when escalation roster is unapproved",
    "Fail closed when quiet-hours behavior is unknown",
    "Fail closed when notification routing is ambiguous",
    "Fail closed when delivery or dry-run evidence is missing",
    "Fail closed when cleanup evidence is missing",
    "Fail closed when SLO linkage or metrics linkage is missing",
    "Fail closed when credential, production, infrastructure, worker, remote host, Docker, Kubernetes, deployment, alerting service, or GitHub Project control-plane mutation lacks explicit Human approval"
  ],
  "remainingOperationalGaps": [
    "Approved paging backend and notification sinks are not selected",
    "Approved escalation roster and rotation cadence are not captured",
    "Quiet-hours behavior is not tested against a live or dry-run notification sink",
    "Alert routing drill evidence is not captured from replayed metrics or approved sandbox metrics",
    "Delivery evidence, cleanup receipts, and residual-risk closeout remain follow-up work"
  ],
  "followUpIssue": "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/63"
}
```
<!-- on-call-paging-alerting:end -->

## Remaining Gaps

This baseline raises the reviewable standard but does not finish on-call
readiness. Remaining operational gaps are tracked by issue
[#63](https://github.com/TwoTwo-me/Project_Dokkaebi/issues/63): approved paging
backend, approved roster, quiet-hours drill, alert routing delivery or dry-run
output, cleanup receipts, and readiness reassessment from captured evidence.
