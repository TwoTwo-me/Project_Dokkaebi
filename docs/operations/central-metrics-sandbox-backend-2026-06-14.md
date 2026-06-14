# Central Metrics Sandbox Backend Evidence

This document records the approved local central metrics sandbox backend run for
issue #80. The run uses an ephemeral SQLite backend and sanitized representative
metrics only. It captures ingestion output, storage/query output, dashboard rows,
alert-rule evaluation, retention/cardinality checks, approval-gate status,
cleanup receipt, residual risk, and next action.

This evidence does not authorize credentials, external metrics services,
alerting services, workers, remote hosts, Docker, Kubernetes, deployment,
production, infrastructure, or GitHub Project control-plane mutation.

Run:

```bash
bash scripts/run-central-metrics-sandbox-backend.sh
bash scripts/validate-central-metrics-sandbox-backend.sh
```

<!-- central-metrics-sandbox-backend:begin -->
```json
{
  "version": 1,
  "evidenceId": "central-metrics-sandbox-backend-2026-06-14",
  "date": "2026-06-14",
  "issueUrl": "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/80",
  "permissionLevel": "approved-local-sandbox-backend",
  "approvalRecord": {
    "approvedTarget": "local ephemeral SQLite metrics sandbox in the Project Dokkaebi development environment",
    "scope": "run scripts/run-central-metrics-sandbox-backend.sh against sanitized repository fixtures only",
    "deniedTargets": [
      "credentials",
      "external metrics service",
      "alerting service",
      "remote host",
      "Docker",
      "Kubernetes",
      "deployment",
      "production",
      "infrastructure",
      "workers",
      "GitHub Project control-plane"
    ],
    "evidence": "approval is limited to local sandbox evidence for issue #80; no live approval-gated mutation reached"
  },
  "backendSelection": {
    "type": "ephemeral SQLite local sandbox backend",
    "owner": "Project Dokkaebi operations maintainer",
    "storage": "temporary local SQLite database removed during cleanup",
    "externalServices": "none",
    "cleanup": "runner trap removes the temporary database directory before exit"
  },
  "runner": {
    "path": "scripts/run-central-metrics-sandbox-backend.sh",
    "result": "PASS Dokkaebi central metrics sandbox backend runner completed",
    "outputContract": "prints a PASS line plus JSON containing sample counts, stored metric groups, query results, dashboard rows, alert evaluation, manifestSha256, approval-gate status, and cleanup receipt"
  },
  "representativeMetrics": [
    {
      "group": "dispatch",
      "metricName": "dokkaebi_dispatch_latency_seconds",
      "type": "histogram",
      "labels": {
        "project": "sandbox",
        "repository": "Project_Dokkaebi",
        "environment": "local_sandbox",
        "route_class": "docs"
      },
      "sample": 412,
      "evidence": "ready work reached dispatch readiness inside the local sandbox backend run"
    },
    {
      "group": "recovery",
      "metricName": "dokkaebi_recovery_time_seconds",
      "type": "histogram",
      "labels": {
        "project": "sandbox",
        "repository": "Project_Dokkaebi",
        "environment": "local_sandbox",
        "failure_class": "stale_lease"
      },
      "sample": 890,
      "evidence": "stale lease recovery sample stored in the sandbox backend"
    },
    {
      "group": "review_age",
      "metricName": "dokkaebi_review_age_seconds",
      "type": "histogram",
      "labels": {
        "project": "sandbox",
        "repository": "Project_Dokkaebi",
        "environment": "local_sandbox",
        "issue_number": "80"
      },
      "sample": 172800,
      "evidence": "Human Review age sample stored for alert evaluation"
    },
    {
      "group": "worker_capacity",
      "metricName": "dokkaebi_worker_capacity_available",
      "type": "gauge",
      "labels": {
        "project": "sandbox",
        "environment": "local_sandbox",
        "route_class": "docs",
        "provider": "local"
      },
      "sample": 2,
      "evidence": "route capacity gauge stored without worker dispatch"
    },
    {
      "group": "approval",
      "metricName": "dokkaebi_approval_gate_block_total",
      "type": "counter",
      "labels": {
        "project": "sandbox",
        "environment": "local_sandbox",
        "permission_level": "docs-only",
        "approval_gate_status": "blocked"
      },
      "sample": 1,
      "evidence": "unauthorized operation sample remains blocked"
    },
    {
      "group": "validation",
      "metricName": "dokkaebi_validation_pass_total",
      "type": "counter",
      "labels": {
        "project": "sandbox",
        "repository": "Project_Dokkaebi",
        "environment": "local_sandbox",
        "validator_name": "readiness"
      },
      "sample": 5,
      "evidence": "validator pass count stored for governance dashboard use"
    },
    {
      "group": "compliance",
      "metricName": "dokkaebi_compliance_evidence_complete",
      "type": "gauge",
      "labels": {
        "project": "sandbox",
        "environment": "local_sandbox",
        "control_class": "compliance",
        "evidence_package_id": "sandbox-backend"
      },
      "sample": 1,
      "evidence": "compliance evidence completeness stored in sandbox backend"
    },
    {
      "group": "runtime_health",
      "metricName": "dokkaebi_runtime_poll_success_total",
      "type": "counter",
      "labels": {
        "project": "sandbox",
        "environment": "local_sandbox",
        "adapter": "github",
        "repository": "Project_Dokkaebi"
      },
      "sample": 3,
      "evidence": "local control-loop health sample stored in sandbox backend"
    },
    {
      "group": "audit_export",
      "metricName": "dokkaebi_audit_export_verified_total",
      "type": "counter",
      "labels": {
        "project": "sandbox",
        "environment": "local_sandbox",
        "control_class": "audit_export",
        "evidence_package_id": "sandbox-backend"
      },
      "sample": 1,
      "evidence": "audit export verification sample stored in sandbox backend"
    }
  ],
  "ingestionOutput": {
    "backend": "SQLite metric_samples table",
    "acceptedSamples": 9,
    "rejectedSamples": 0,
    "table": "metric_samples(group_name, metric_name, metric_type, labels_json, sample_value, evidence)",
    "manifestSha256": "3109cd32c268a2b37f584e6283558940a5ebf07390d2764f1f618073f0995451"
  },
  "storageQueryOutput": {
    "backend": "ephemeral SQLite local sandbox backend",
    "queries": [
      {
        "name": "dispatch_latency",
        "expression": "max(dokkaebi_dispatch_latency_seconds)",
        "result": "412s",
        "slo": "within 900s",
        "status": "pass"
      },
      {
        "name": "recovery_time",
        "expression": "max(dokkaebi_recovery_time_seconds)",
        "result": "890s",
        "slo": "within 1800s",
        "status": "pass"
      },
      {
        "name": "review_age",
        "expression": "max(dokkaebi_review_age_seconds)",
        "result": "172800s",
        "slo": "within reminder window",
        "status": "evaluated"
      },
      {
        "name": "availability_posture",
        "expression": "sum(dokkaebi_runtime_poll_success_total)",
        "result": "3 successful local polls",
        "slo": "observable local control-loop health",
        "status": "pass"
      },
      {
        "name": "audit_export",
        "expression": "sum(dokkaebi_audit_export_verified_total)",
        "result": "1",
        "slo": "evidence present",
        "status": "pass"
      }
    ]
  },
  "dashboardRows": [
    {
      "panel": "dispatch latency",
      "query": "dispatch_latency",
      "status": "pass"
    },
    {
      "panel": "recovery time",
      "query": "recovery_time",
      "status": "pass"
    },
    {
      "panel": "review age",
      "query": "review_age",
      "status": "evaluated"
    },
    {
      "panel": "worker capacity",
      "query": "worker_capacity",
      "status": "pass"
    },
    {
      "panel": "validation rate",
      "query": "validation",
      "status": "pass"
    },
    {
      "panel": "approval blocks",
      "query": "approval",
      "status": "evaluated"
    },
    {
      "panel": "compliance evidence completeness",
      "query": "compliance",
      "status": "pass"
    },
    {
      "panel": "immutable audit-export verification",
      "query": "audit_export",
      "status": "pass"
    }
  ],
  "alertEvaluation": [
    {
      "name": "dispatch latency burn",
      "status": "not_firing",
      "evidence": "412s below 900s"
    },
    {
      "name": "recovery time burn",
      "status": "not_firing",
      "evidence": "890s below 1800s"
    },
    {
      "name": "stale Human Review age",
      "status": "evaluated",
      "evidence": "reminder boundary reached"
    },
    {
      "name": "worker route capacity unavailable",
      "status": "not_firing",
      "evidence": "2 available"
    },
    {
      "name": "validation failure spike",
      "status": "not_firing",
      "evidence": "0 failures"
    },
    {
      "name": "approval-boundary violation",
      "status": "evaluated",
      "evidence": "blocked unauthorized operation remains blocked"
    },
    {
      "name": "missing compliance evidence",
      "status": "not_firing",
      "evidence": "compliance evidence complete and audit export verified"
    }
  ],
  "retentionCardinalityChecks": {
    "retention": "ephemeral sandbox database is deleted after validation; SLO rollup and audit evidence are retained as this dated repository document",
    "allowedLabels": [
      "project",
      "repository",
      "environment",
      "route_class",
      "provider",
      "adapter",
      "issue_number",
      "permission_level",
      "approval_gate_status",
      "validator_name",
      "failure_class",
      "control_class",
      "evidence_package_id"
    ],
    "disallowedLabels": [
      "raw prompt",
      "raw issue or PR body",
      "token",
      "cookie",
      "SSH key",
      "auth file path",
      "private machine path",
      "unbounded exception message",
      "worker command text",
      "GitHub Project control-plane payload"
    ],
    "cardinalityLimit": "unbounded labels fail closed before ingestion",
    "redaction": "samples contain bounded identifiers only and no secret material"
  },
  "auditExportEvidence": {
    "manifestSha256": "3109cd32c268a2b37f584e6283558940a5ebf07390d2764f1f618073f0995451",
    "source": "runner manifest over metrics, queries, dashboard rows, and alerts",
    "status": "verified"
  },
  "validationOutput": [
    "bash scripts/run-central-metrics-sandbox-backend.sh: PASS",
    "bash scripts/validate-central-metrics-sandbox-backend.sh: PASS",
    "bash scripts/validate-central-metrics-backend.sh: PASS",
    "bash scripts/validate-central-metrics-replay.sh: PASS",
    "bash scripts/validate-service-level-objectives.sh: PASS",
    "bash scripts/validate-on-call-paging-alerting.sh: PASS",
    "bash scripts/validate-readiness-criteria.sh: PASS",
    "bash scripts/validate-contract-docs.sh: PASS"
  ],
  "approvalGateStatus": "No live approval-gated mutation reached; credentials, production, infrastructure, workers, remote hosts, Docker, Kubernetes, deployment, external metrics service, alerting service, and GitHub Project control-plane mutation remain not authorized.",
  "cleanup": {
    "status": "complete",
    "receipt": "runner removed the ephemeral SQLite sandbox directory after exit; no credentials, external services, containers, clusters, workers, remote hosts, production targets, deployments, infrastructure, or GitHub Project settings touched"
  },
  "residualRisk": [
    "Externally managed production metrics backend selection remains a future deployment decision.",
    "Live paging delivery remains covered by issue #82.",
    "Long-term retention enforcement outside this ephemeral sandbox remains unproven."
  ],
  "nextAction": "Connect approved live paging backend and delivery route in issue #82."
}
```
<!-- central-metrics-sandbox-backend:end -->
