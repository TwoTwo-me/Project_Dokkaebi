# On-Call Alert Routing Dry-Run Drill

This document captures a docs-only local dry-run drill for the on-call paging
and alerting baseline. It uses the selected GitHub evidence dry-run sink from
[`on-call-paging-alerting.md`](on-call-paging-alerting.md), SLO context from
[`service-level-objectives.md`](service-level-objectives.md), and representative
metrics from
[`central-metrics-replay-2026-06-13.md`](central-metrics-replay-2026-06-13.md).
It does not configure or mutate a live alerting service, paging service,
metrics service, credential, production system, infrastructure, worker, remote
host, Docker daemon, Kubernetes cluster, deployment, or GitHub Project
control-plane setting.

The drill proves routing decisions, quiet-hours behavior, dry-run delivery
output, approval-gate status, cleanup, residual risk, and next action for the
seven alert classes in issue
[#63](https://github.com/TwoTwo-me/Project_Dokkaebi/issues/63).
The structured drill block includes explicit dry-run delivery output for every
representative alert class.

## Local Dry-Run Scope

The selected sink is `github_evidence_dry_run`. It means the route produces an
auditable issue or PR evidence packet and does not send a live page. The roster
and quiet-hours policy are representative operating data, not a production
rotation. Live delivery remains blocked until issue
[#82](https://github.com/TwoTwo-me/Project_Dokkaebi/issues/82) records explicit
Human approval for the backend, roster, notification sinks, quiet-hours
behavior, delivery test plan, cleanup, and residual-risk handling.

## Validation

Run:

```bash
bash scripts/validate-on-call-alert-routing-drill.sh
```

The validator rejects missing selected sink, roster, escalation windows,
quiet-hours evidence, alert classes, routing decisions, dry-run delivery
output, validation output, approval-gate status, cleanup, residual risk, next
action, follow-up issue, unsafe live delivery claims, private local paths, and
secret-like material.

<!-- on-call-alert-routing-drill:begin -->
```json
{
  "version": 1,
  "drillId": "on-call-alert-routing-dry-run-2026-06-13",
  "date": "2026-06-13",
  "permissionLevel": "docs-only-local-dry-run",
  "sourceBaselines": [
    "docs/operations/on-call-paging-alerting.md",
    "docs/operations/service-level-objectives.md",
    "docs/operations/central-metrics-replay-2026-06-13.md"
  ],
  "selectedDryRunSink": {
    "id": "github_evidence_dry_run",
    "backendStatus": "not_live_paging",
    "primarySink": "GitHub issue evidence packet",
    "secondarySink": "GitHub PR comment evidence packet",
    "deliveryMode": "dry_run_only",
    "evidenceSurface": "issue #63 result evidence"
  },
  "escalationRoster": {
    "rotationCadence": "representative weekly roster for dry-run evidence",
    "timezone": "UTC",
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
    "handoffEvidence": "dry-run handoff record lists owner, backup, unresolved alerts, and next action",
    "backupCoverage": "secondary_on_call backs up primary_on_call for every escalation window"
  },
  "escalationWindows": [
    {
      "severity": "SEV0",
      "window": "immediate owner contact after approved live backend exists",
      "dryRunAction": "blocked from live page; create evidence packet and security escalation note"
    },
    {
      "severity": "SEV1",
      "window": "30 minutes",
      "dryRunAction": "urgent evidence packet to primary_on_call and secondary_on_call"
    },
    {
      "severity": "SEV2",
      "window": "1 business day",
      "dryRunAction": "business-hours evidence packet to primary_on_call and service owner"
    },
    {
      "severity": "SEV3",
      "window": "normal planning",
      "dryRunAction": "planning evidence packet to owning maintainer"
    }
  ],
  "quietHoursDecision": {
    "timezone": "UTC",
    "sampleTime": "2026-06-13T21:00:00Z",
    "businessHours": "09:00-18:00 UTC Monday-Friday",
    "isQuietHours": true,
    "decision": "SEV1 and approval-boundary alerts create urgent dry-run evidence; SEV2 and SEV3 route to deferred evidence packets",
    "auditEvidence": "quiet-hours decision recorded for every routing decision"
  },
  "representativeAlerts": [
    {
      "id": "dispatch_latency_burn",
      "severity": "SEV2",
      "metric": "dokkaebi_dispatch_latency_seconds",
      "input": "412s below 900s SLO",
      "slo": "dispatch_latency"
    },
    {
      "id": "recovery_time_burn",
      "severity": "SEV1",
      "metric": "dokkaebi_recovery_time_seconds",
      "input": "890s below 1800s SLO",
      "slo": "recovery_time"
    },
    {
      "id": "stale_human_review",
      "severity": "SEV3 escalating to SEV2",
      "metric": "dokkaebi_review_age_seconds",
      "input": "172800s triggers reminder evidence",
      "slo": "review_age"
    },
    {
      "id": "worker_route_capacity",
      "severity": "SEV1",
      "metric": "dokkaebi_worker_capacity_available",
      "input": "2 available local route slots",
      "slo": "route_capacity"
    },
    {
      "id": "validation_failure_spike",
      "severity": "SEV2",
      "metric": "dokkaebi_validation_failures_total",
      "input": "0 failures in replay window",
      "slo": "validation_health"
    },
    {
      "id": "approval_boundary_violation",
      "severity": "SEV0",
      "metric": "dokkaebi_approval_gate_block_total",
      "input": "blocked authority request evidence",
      "slo": "approval_boundary"
    },
    {
      "id": "missing_compliance_evidence",
      "severity": "SEV2",
      "metric": "dokkaebi_compliance_evidence_missing_total",
      "input": "audit export verified and missing evidence count 0",
      "slo": "compliance_evidence"
    }
  ],
  "routingDecisions": [
    {
      "alertId": "dispatch_latency_burn",
      "targetRole": "primary_on_call",
      "primarySink": "GitHub issue evidence packet",
      "secondarySink": "GitHub PR comment evidence packet",
      "quietHoursApplied": true,
      "deliveryMode": "dry_run_only",
      "decision": "defer to business-hours evidence packet because severity is SEV2"
    },
    {
      "alertId": "recovery_time_burn",
      "targetRole": "primary_on_call",
      "primarySink": "GitHub issue evidence packet",
      "secondarySink": "secondary_on_call evidence mention",
      "quietHoursApplied": true,
      "deliveryMode": "dry_run_only",
      "decision": "create urgent dry-run evidence because severity is SEV1"
    },
    {
      "alertId": "stale_human_review",
      "targetRole": "tenant_owner",
      "primarySink": "GitHub issue evidence packet",
      "secondarySink": "project owner digest evidence",
      "quietHoursApplied": true,
      "deliveryMode": "dry_run_only",
      "decision": "defer reminder to digest evidence unless escalation reaches SEV2"
    },
    {
      "alertId": "worker_route_capacity",
      "targetRole": "sre_owner",
      "primarySink": "GitHub issue evidence packet",
      "secondarySink": "incident commander evidence mention",
      "quietHoursApplied": true,
      "deliveryMode": "dry_run_only",
      "decision": "create urgent dry-run evidence because route capacity can block dispatch"
    },
    {
      "alertId": "validation_failure_spike",
      "targetRole": "sre_owner",
      "primarySink": "GitHub PR comment evidence packet",
      "secondarySink": "GitHub issue evidence packet",
      "quietHoursApplied": true,
      "deliveryMode": "dry_run_only",
      "decision": "defer to business-hours evidence because replay has zero failures"
    },
    {
      "alertId": "approval_boundary_violation",
      "targetRole": "security_reviewer",
      "primarySink": "GitHub issue evidence packet",
      "secondarySink": "project owner evidence mention",
      "quietHoursApplied": true,
      "deliveryMode": "dry_run_only",
      "decision": "create immediate blocked-state evidence and do not send live page"
    },
    {
      "alertId": "missing_compliance_evidence",
      "targetRole": "compliance_reviewer",
      "primarySink": "GitHub issue evidence packet",
      "secondarySink": "audit package evidence packet",
      "quietHoursApplied": true,
      "deliveryMode": "dry_run_only",
      "decision": "defer to business-hours evidence because missing evidence count is zero"
    }
  ],
  "deliveryOutput": [
    "DRY_RUN dispatch_latency_burn -> GitHub issue evidence packet: deferred business-hours evidence",
    "DRY_RUN recovery_time_burn -> GitHub issue evidence packet: urgent evidence packet",
    "DRY_RUN stale_human_review -> GitHub issue evidence packet: digest evidence",
    "DRY_RUN worker_route_capacity -> GitHub issue evidence packet: urgent evidence packet",
    "DRY_RUN validation_failure_spike -> GitHub PR comment evidence packet: deferred evidence",
    "DRY_RUN approval_boundary_violation -> GitHub issue evidence packet: blocked-state evidence",
    "DRY_RUN missing_compliance_evidence -> GitHub issue evidence packet: deferred evidence"
  ],
  "validationOutput": [
    "bash scripts/validate-on-call-alert-routing-drill.sh: PASS",
    "bash scripts/validate-on-call-paging-alerting.sh: PASS",
    "bash scripts/validate-central-metrics-replay.sh: PASS",
    "bash scripts/validate-central-metrics-backend.sh: PASS",
    "bash scripts/validate-sre-operating-baseline.sh: PASS",
    "bash scripts/validate-readiness-criteria.sh: PASS",
    "bash scripts/validate-contract-docs.sh: PASS"
  ],
  "approvalGateStatus": "No live alerting service, paging service, metrics service, credential, production, infrastructure, worker, remote host, Docker, Kubernetes, deployment, or GitHub Project control-plane mutation reached; those authorities remain not authorized.",
  "cleanup": {
    "status": "complete",
    "receipt": "Dry-run used checked-in sanitized evidence only; no backend, alerting service, paging service, metric service, container, cluster, credential, worker, remote host, production system, or GitHub Project setting was touched."
  },
  "residualRisk": [
    "Live paging backend delivery is not implemented.",
    "Approved live roster and notification sinks are not connected.",
    "Escalation receipt from an approved live or approved sandbox backend is not captured."
  ],
  "nextAction": "Connect approved live paging backend and delivery route in issue #82.",
  "followUpIssueUrl": "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/82"
}
```
<!-- on-call-alert-routing-drill:end -->

## Residual Risk And Next Action

The dry-run proves routing decisions and evidence shape, but it is not live
paging. Issue [#82](https://github.com/TwoTwo-me/Project_Dokkaebi/issues/82)
must connect an explicitly approved backend or approved sandbox substitute
before on-call paging and alerting can approach completion.
