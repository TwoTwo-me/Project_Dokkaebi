# Central Metrics Local Replay

This document records a docs-only local central metrics replay for
[`central-metrics-backend.md`](central-metrics-backend.md),
[`service-level-objectives.md`](service-level-objectives.md), and
[`on-call-paging-alerting.md`](on-call-paging-alerting.md). It does not
authorize credentials, production writes, infrastructure mutation, worker
dispatch, remote host operations, Docker, Kubernetes, deployment, metrics
service mutation, alerting service mutation, or GitHub Project control-plane
mutation.

The replay captures representative metrics, ingestion output, storage/query
output, parsed dashboard view, alert-rule evaluation, retention/cardinality
checks, approval-gate status, cleanup, residual risk, and next action.

Required exact terms: local central metrics replay; representative metrics;
ingestion output; storage/query output; parsed dashboard view; alert-rule
evaluation; retention/cardinality checks; approval-gate status; cleanup;
residual risk; next action; does not authorize.

## Replay Summary

The replay emits sanitized Prometheus-style samples for dispatch, recovery,
review-age, worker-capacity, approval, validation, compliance, runtime-health,
and audit-export evidence. The samples are parsed locally into query results,
dashboard rows, and dry-run alert decisions. No live backend is started.

## Validation

Run:

```bash
bash scripts/validate-central-metrics-replay.sh
```

The validator accepts this complete docs-only package and rejects incomplete
metrics groups, ingestion output, storage/query output, dashboard views, alert
evaluations, retention/cardinality checks, approval status, cleanup, residual
risk, unsafe mutation wording, private local paths, and secret-bearing wording.

<!-- central-metrics-replay:begin -->
```json
{
  "version": 1,
  "replayId": "central-metrics-local-replay-2026-06-13",
  "date": "2026-06-13",
  "permissionLevel": "docs-only-local-replay",
  "sourceDesigns": [
    "docs/operations/central-metrics-backend.md",
    "docs/operations/service-level-objectives.md",
    "docs/operations/on-call-paging-alerting.md"
  ],
  "representativeMetrics": [
    {
      "group": "dispatch",
      "metricName": "dokkaebi_dispatch_latency_seconds",
      "type": "histogram",
      "labels": ["project", "repository", "environment", "route_class"],
      "sample": 412,
      "evidence": "ready issue moved to dispatch readiness in local replay"
    },
    {
      "group": "recovery",
      "metricName": "dokkaebi_recovery_time_seconds",
      "type": "histogram",
      "labels": ["project", "repository", "environment", "failure_class"],
      "sample": 890,
      "evidence": "stale lease classified and recovered in local replay"
    },
    {
      "group": "review_age",
      "metricName": "dokkaebi_review_age_seconds",
      "type": "histogram",
      "labels": ["project", "repository", "environment", "issue_number"],
      "sample": 172800,
      "evidence": "Human Review reminder threshold evaluated"
    },
    {
      "group": "worker_capacity",
      "metricName": "dokkaebi_worker_capacity_available",
      "type": "gauge",
      "labels": ["project", "environment", "route_class", "provider"],
      "sample": 2,
      "evidence": "route capacity parsed from local replay fixture"
    },
    {
      "group": "approval",
      "metricName": "dokkaebi_approval_gate_block_total",
      "type": "counter",
      "labels": ["project", "environment", "permission_level", "approval_gate_status"],
      "sample": 1,
      "evidence": "unauthorized operation remained blocked"
    },
    {
      "group": "validation",
      "metricName": "dokkaebi_validation_pass_total",
      "type": "counter",
      "labels": ["project", "repository", "environment", "validator_name"],
      "sample": 5,
      "evidence": "required validators reported PASS"
    },
    {
      "group": "compliance",
      "metricName": "dokkaebi_compliance_evidence_complete",
      "type": "gauge",
      "labels": ["project", "environment", "control_class", "evidence_package_id"],
      "sample": 1,
      "evidence": "evidence package completeness parsed"
    },
    {
      "group": "runtime_health",
      "metricName": "dokkaebi_runtime_poll_success_total",
      "type": "counter",
      "labels": ["project", "environment", "adapter", "repository"],
      "sample": 3,
      "evidence": "local replay poll cycle succeeded"
    },
    {
      "group": "audit_export",
      "metricName": "dokkaebi_audit_export_verified_total",
      "type": "counter",
      "labels": ["project", "environment", "control_class", "evidence_package_id"],
      "sample": 1,
      "evidence": "audit-export verification status parsed"
    }
  ],
  "ingestionOutput": {
    "format": "Prometheus exposition text",
    "parser": "local deterministic parser",
    "acceptedSamples": 9,
    "rejectedSamples": 0,
    "expositionLines": [
      "dokkaebi_dispatch_latency_seconds_bucket{project=\"sandbox\",repository=\"Project_Dokkaebi\",environment=\"local\",route_class=\"docs\"} 412",
      "dokkaebi_recovery_time_seconds_bucket{project=\"sandbox\",repository=\"Project_Dokkaebi\",environment=\"local\",failure_class=\"stale_lease\"} 890",
      "dokkaebi_review_age_seconds_bucket{project=\"sandbox\",repository=\"Project_Dokkaebi\",environment=\"local\",issue_number=\"57\"} 172800",
      "dokkaebi_worker_capacity_available{project=\"sandbox\",environment=\"local\",route_class=\"docs\",provider=\"local\"} 2",
      "dokkaebi_approval_gate_block_total{project=\"sandbox\",environment=\"local\",permission_level=\"docs-only\",approval_gate_status=\"blocked\"} 1",
      "dokkaebi_validation_pass_total{project=\"sandbox\",repository=\"Project_Dokkaebi\",environment=\"local\",validator_name=\"readiness\"} 5",
      "dokkaebi_compliance_evidence_complete{project=\"sandbox\",environment=\"local\",control_class=\"compliance\",evidence_package_id=\"local-replay\"} 1",
      "dokkaebi_runtime_poll_success_total{project=\"sandbox\",environment=\"local\",adapter=\"github\",repository=\"Project_Dokkaebi\"} 3",
      "dokkaebi_audit_export_verified_total{project=\"sandbox\",environment=\"local\",control_class=\"audit_export\",evidence_package_id=\"local-replay\"} 1"
    ]
  },
  "storageQueryOutput": {
    "backend": "local in-memory replay table, not a live metrics service",
    "queries": [
      {"name": "dispatch_latency", "expression": "histogram_quantile(0.90, dokkaebi_dispatch_latency_seconds)", "result": "412s", "slo": "within 900s"},
      {"name": "recovery_time", "expression": "histogram_quantile(0.95, dokkaebi_recovery_time_seconds)", "result": "890s", "slo": "within 1800s"},
      {"name": "review_age", "expression": "max(dokkaebi_review_age_seconds)", "result": "172800s", "slo": "within reminder window"},
      {"name": "availability_posture", "expression": "sum(dokkaebi_runtime_poll_success_total)", "result": "3 successful local polls", "slo": "observable local control-loop health"},
      {"name": "audit_export", "expression": "sum(dokkaebi_audit_export_verified_total)", "result": "1", "slo": "evidence present"}
    ]
  },
  "dashboardView": {
    "surface": "parsed local table",
    "panels": [
      "dispatch latency",
      "recovery time",
      "review age",
      "worker capacity",
      "validation rate",
      "approval blocks",
      "compliance evidence completeness",
      "immutable audit-export verification"
    ]
  },
  "alertEvaluation": {
    "mode": "dry-run-local",
    "rules": [
      {"name": "dispatch latency burn", "status": "not_firing", "evidence": "412s below 900s"},
      {"name": "recovery time burn", "status": "not_firing", "evidence": "890s below 1800s"},
      {"name": "stale Human Review age", "status": "evaluated", "evidence": "reminder boundary reached"},
      {"name": "worker route capacity unavailable", "status": "not_firing", "evidence": "2 available"},
      {"name": "validation failure spike", "status": "not_firing", "evidence": "0 failures"},
      {"name": "approval-boundary violation", "status": "evaluated", "evidence": "blocked unauthorized operation remains blocked"},
      {"name": "missing compliance evidence", "status": "not_firing", "evidence": "compliance evidence complete and audit export verified"}
    ]
  },
  "retentionCardinalityChecks": {
    "retention": "raw samples 30 days; SLO rollups 13 months; incident and compliance snapshots retained with evidence package",
    "allowedLabels": ["project", "repository", "environment", "route_class", "provider", "adapter", "issue_number", "permission_level", "approval_gate_status", "validator_name", "failure_class", "control_class", "evidence_package_id"],
    "disallowedLabels": ["raw issue or PR body", "raw prompt content", "token", "cookie", "SSH key", "auth file path", "private machine path", "unbounded exception message", "worker command text", "GitHub Project control-plane payload"],
    "cardinalityLimit": "bounded labels only; no raw issue body, prompt, command text, stack trace, or arbitrary path",
    "redaction": "no secrets, cookies, private paths, credential material, or raw control-plane payload"
  },
  "validationOutput": [
    "bash scripts/validate-central-metrics-replay.sh: PASS",
    "bash scripts/validate-central-metrics-backend.sh: PASS",
    "bash scripts/validate-service-level-objectives.sh: PASS",
    "bash scripts/validate-on-call-paging-alerting.sh: PASS",
    "bash scripts/validate-readiness-criteria.sh: PASS",
    "bash scripts/validate-contract-docs.sh: PASS"
  ],
  "approvalGateStatus": "No live approval-gated mutation reached; credential, production, infrastructure, worker, remote host, Docker, Kubernetes, deployment, metrics service, alerting service, and GitHub Project control-plane mutation remain not authorized.",
  "cleanup": {
    "status": "complete",
    "receipt": "Local replay used checked-in sanitized data only; no backend, alert service, container, cluster, credential, worker, remote host, production system, or GitHub Project setting was touched."
  },
  "residualRisk": [
    "Approved sandbox metrics backend ingestion is not captured.",
    "Live dashboard and alert delivery are not implemented.",
    "Long-term retention and export verification against a real backend remain unproven."
  ],
  "nextAction": "Connect approved central metrics sandbox backend in issue #80.",
  "followUpIssueUrl": "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/80"
}
```
<!-- central-metrics-replay:end -->
