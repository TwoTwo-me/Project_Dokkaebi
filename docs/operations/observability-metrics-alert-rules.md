# Observability Metrics And Alert Rules

This document defines the docs-only metrics catalog and alert-rule baseline for
Project Dokkaebi. It does not deploy collectors, dashboards, alerting services,
workers, credentials, infrastructure, production systems, or GitHub Project
control-plane configuration.

The goal is to make operator detection paths explicit before a live metrics
backend exists. Every metric and alert below must be safe to quote in result
packets, incident records, readiness reviews, and audit exports without exposing
private worker memory or credential material.

## Enterprise Standard

The observability baseline must let an operator answer these questions from
state, logs, metrics, traces, dashboards, and redacted audit evidence:

- Is dispatch stuck or too slow?
- Is queue depth growing faster than Hammer capacity?
- Are any Worker routes unhealthy or unavailable?
- Are retries, failures, or credential denials spiking?
- Is Human Review aging past the SLO window?
- Can each signal be correlated by project, repository, issue, route, worker
  class, session, run, commit, and environment without leaking secrets?

## Metrics Catalog

| Metric | Type | Operator use |
| --- | --- | --- |
| `dokkaebi_dispatch_latency_seconds` | histogram | Detect slow admission-to-dispatch time and SLO burn. |
| `dokkaebi_queue_depth` | gauge | Detect backlog growth by project, repository, route class, and environment. |
| `dokkaebi_worker_health` | gauge | Detect unavailable local, SSH, Docker, or Kubernetes Hammer routes. |
| `dokkaebi_dispatch_retry_total` | counter | Detect retry storms and recovery-loop churn. |
| `dokkaebi_worker_failure_total` | counter | Detect failing route classes, providers, or repositories. |
| `dokkaebi_credential_denial_total` | counter | Detect broker or authority-denial spikes without exporting secrets. |
| `dokkaebi_review_age_seconds` | histogram | Detect stale Human Review and escalation risk. |
| `dokkaebi_audit_export_total` | counter | Detect missing or failing audit-export evidence. |

Allowed correlation labels are bounded, operational identifiers: `project`,
`repository`, `environment`, `route_class`, `worker_class`, `provider`,
`issue_number`, `pull_request_number`, `session_id`, `run_id`, `commit_sha`,
`check_run_id`, `permission_level`, and `approval_gate_status`.

Disallowed labels include raw prompts, raw issue or pull request body text,
tokens, cookies, SSH keys, auth file paths, private machine paths, worker command
text, unbounded exception messages, credential broker payloads, and GitHub
Project control-plane payloads.

## Alert Rules

Alert rules must map directly to severity and operator action. Until a paging
backend is explicitly approved, notification is limited to GitHub issue or pull
request evidence, runbook updates, and Human Review escalation comments.

| Alert | Severity | Operator action |
| --- | --- | --- |
| Dispatch latency burn | SEV2 | Open an incident issue, check GitHub adapter health, and pause new dispatch if admission evidence is missing. |
| Queue depth growth | SEV3 | Assign Fire operator, check worker capacity, and record backlog mitigation. |
| Worker route unavailable | SEV2 | Mark affected route blocked, preserve lease evidence, and reroute only to approved capability. |
| Retry failure spike | SEV2 | Inspect retry reason, stop duplicate-dispatch risk, and attach validation output. |
| Credential denial spike | SEV2 | Block affected work, notify security reviewer, and verify broker denial evidence is redacted. |
| Stale Human Review age | SEV3 | Remind approver, record review age, and move blocked work only under documented policy. |
| Missing audit export evidence | SEV2 | Stop compliance closeout, regenerate redacted export evidence, and attach manifest status. |

## Trace Correlation

Trace spans must use the same correlation identifiers as metrics. Span names
describe operation classes such as `fire.poll_project`, `manager.preflight`,
`hammer.route.select`, `worker.result.collect`, and `audit.export.prepare`.
Spans must not include prompts, credential payloads, full command text, private
paths, or raw GitHub Project payloads.

## Redaction And Retention

Raw metrics samples are retained for 30 days or less when cost or security
requires. SLO rollups, alert evaluation history, incident snapshots, and
compliance-linked metric evidence are retained for 13 months or with the
associated incident/compliance package, whichever is stricter. Trace retention
starts at 7 days until an approved backend and cost model exist.

Audit exports may include metric names, bounded labels, query windows, alert
decisions, severity, operator action, validation command names, and manifest
hashes. They must not include raw secrets, auth files, cookies, SSH material,
private paths, raw prompts, or raw Worker command text.

## Dashboard Panels

Dashboard or terminal captures must show dispatch latency, queue depth, worker
health, retry/failure counts, credential denials, Human Review age, and
audit-export evidence status. A panel that cannot name its source metric and
SLO linkage is not acceptable readiness evidence.

## Approval Boundary

This baseline authorizes docs-only work and local deterministic validation. Live
metrics collection, trace collection, paging delivery, alerting service changes,
credential access, worker execution, remote host mutation, Docker mutation,
Kubernetes mutation, infrastructure mutation, production mutation, deployment,
or GitHub Project control-plane mutation requires explicit Human approval under
[`../policies/authority-and-safety.md`](../policies/authority-and-safety.md).

## Validation

Run:

```bash
bash scripts/validate-observability-metrics-alerts.sh
```

The validator rejects missing required metrics, missing alert actions, unsafe
labels, missing retention or redaction policy, missing SLO linkage, missing
trace correlation, and wording that claims sensitive operational authority
without explicit Human approval.

<!-- observability-metrics-alerts:begin -->
```json
{
  "version": 1,
  "permissionLevel": "docs-only design and local deterministic validation",
  "routingStatus": "GitHub evidence dry-run plus approved local sandbox delivery evidence; live paging and live alert delivery remain deferred until explicit Human approval",
  "securityBoundary": "This baseline does not authorize credential, worker, remote host, Docker, Kubernetes, infrastructure, production, deployment, metrics service, alerting service, paging service, or GitHub Project control-plane mutation without explicit Human approval",
  "requiredCorrelationIds": [
    "project",
    "repository",
    "environment",
    "route_class",
    "worker_class",
    "issue_number",
    "pull_request_number",
    "session_id",
    "run_id",
    "commit_sha",
    "check_run_id",
    "permission_level",
    "approval_gate_status"
  ],
  "disallowedLabels": [
    "raw prompt content",
    "raw issue body",
    "raw pull request body",
    "token",
    "cookie",
    "SSH key",
    "auth file path",
    "private machine path",
    "worker command text",
    "unbounded exception message",
    "credential broker payload",
    "GitHub Project control-plane payload"
  ],
  "metrics": [
    {
      "name": "dokkaebi_dispatch_latency_seconds",
      "type": "histogram",
      "source": "Fire admission-to-dispatch transition",
      "dimensions": ["project", "repository", "environment", "route_class", "issue_number", "session_id", "run_id", "commit_sha"],
      "sloLinkage": "dispatch_latency SLO, dispatch-latency dashboard panel, burn alert, incident field, fallback GitHub evidence",
      "operatorUse": "identify stalled dispatch within minutes",
      "redaction": "no prompts, credentials, private paths, or raw command text",
      "retention": "raw samples 30 days; SLO rollups 13 months"
    },
    {
      "name": "dokkaebi_queue_depth",
      "type": "gauge",
      "source": "Fire project polling and dispatch queue snapshot",
      "dimensions": ["project", "repository", "environment", "route_class"],
      "sloLinkage": "capacity and soak evidence, queue dashboard panel, backlog mitigation field",
      "operatorUse": "detect backlog growth and route pressure",
      "redaction": "no prompts, credentials, private paths, or raw command text; bounded project and repository labels only",
      "retention": "raw samples 30 days; incident snapshots retained with incident"
    },
    {
      "name": "dokkaebi_worker_health",
      "type": "gauge",
      "source": "Hammer route registry health check",
      "dimensions": ["project", "environment", "route_class", "worker_class", "provider"],
      "sloLinkage": "recovery_time SLO, worker-capacity dashboard panel, route-unavailable alert",
      "operatorUse": "detect unavailable or unhealthy Worker routes",
      "redaction": "no host secrets, private paths, credentials, prompts, or command text; worker class only",
      "retention": "raw samples 30 days; outage snapshots retained with incident"
    },
    {
      "name": "dokkaebi_dispatch_retry_total",
      "type": "counter",
      "source": "durable lease and retry scheduler",
      "dimensions": ["project", "repository", "environment", "route_class", "failure_class", "run_id"],
      "sloLinkage": "recovery_time SLO, retry dashboard panel, retry failure spike alert",
      "operatorUse": "detect retry storms and recovery churn",
      "redaction": "no raw exception message, prompts, credentials, private paths, or command text; failure class only",
      "retention": "counter samples 30 days; incident-linked counts retained with incident"
    },
    {
      "name": "dokkaebi_worker_failure_total",
      "type": "counter",
      "source": "Worker result packet and route-result collection",
      "dimensions": ["project", "repository", "environment", "route_class", "worker_class", "failure_class", "run_id"],
      "sloLinkage": "recovery_time SLO, failure dashboard panel, retry failure spike alert",
      "operatorUse": "detect failing routes or repositories",
      "redaction": "no stack trace, raw command text, prompts, credentials, or private paths; failure class only",
      "retention": "counter samples 30 days; failure evidence retained with result packet"
    },
    {
      "name": "dokkaebi_credential_denial_total",
      "type": "counter",
      "source": "credential broker and authority preflight denial",
      "dimensions": ["project", "repository", "environment", "permission_level", "approval_gate_status", "run_id"],
      "sloLinkage": "security-authority evidence, approval-block dashboard panel, credential-denial alert",
      "operatorUse": "detect broker or authority-denial spikes without exposing secrets",
      "redaction": "no token, cookie, SSH key, auth path, prompt, credential payload, or private path; denial class only",
      "retention": "counter samples 30 days; audit-linked denial summary 13 months"
    },
    {
      "name": "dokkaebi_review_age_seconds",
      "type": "histogram",
      "source": "GitHub Project Human Review and PR review state",
      "dimensions": ["project", "repository", "environment", "issue_number", "pull_request_number", "approval_gate_status"],
      "sloLinkage": "review_age SLO, review-age dashboard panel, stale review alert, fallback GitHub evidence",
      "operatorUse": "detect stale Human Review and escalation risk",
      "redaction": "no prompts, credentials, private paths, or raw review body; review role and bounded item number only",
      "retention": "raw samples 30 days; SLO rollups 13 months"
    },
    {
      "name": "dokkaebi_audit_export_total",
      "type": "counter",
      "source": "audit package export and verification step",
      "dimensions": ["project", "repository", "environment", "control_class", "evidence_package_id"],
      "sloLinkage": "compliance package evidence, audit-export dashboard panel, missing audit export alert",
      "operatorUse": "detect missing or failing redacted audit exports",
      "redaction": "no raw secret-bearing evidence, credentials, prompts, private paths, or command text; manifest metadata and hash only",
      "retention": "retained with compliance package or stricter policy"
    }
  ],
  "alerts": [
    {
      "id": "dispatch_latency_burn",
      "severity": "SEV2",
      "expression": "dokkaebi_dispatch_latency_seconds p95 breaches dispatch_latency error-budget window",
      "operatorAction": "open incident issue, check GitHub adapter health, pause new dispatch when admission evidence is missing",
      "owner": "Fire operator",
      "sloLinkage": "dispatch_latency"
    },
    {
      "id": "queue_depth_growth",
      "severity": "SEV3",
      "expression": "dokkaebi_queue_depth grows for two review windows without matching worker capacity",
      "operatorAction": "assign Fire operator, check Hammer capacity, record backlog mitigation in GitHub evidence",
      "owner": "SRE owner",
      "sloLinkage": "capacity and soak evidence"
    },
    {
      "id": "worker_health_unavailable",
      "severity": "SEV2",
      "expression": "dokkaebi_worker_health == 0 for an approved route class",
      "operatorAction": "mark route blocked, preserve lease evidence, reroute only to approved capability",
      "owner": "Hammer operator",
      "sloLinkage": "recovery_time"
    },
    {
      "id": "retry_failure_spike",
      "severity": "SEV2",
      "expression": "dokkaebi_dispatch_retry_total or dokkaebi_worker_failure_total spikes by failure_class",
      "operatorAction": "inspect retry reason, stop duplicate-dispatch risk, attach validation output",
      "owner": "Fire operator",
      "sloLinkage": "recovery_time"
    },
    {
      "id": "credential_denial_spike",
      "severity": "SEV2",
      "expression": "dokkaebi_credential_denial_total spikes by permission_level or approval_gate_status",
      "operatorAction": "block affected work, notify security reviewer, verify broker denial evidence is redacted",
      "owner": "Security reviewer",
      "sloLinkage": "security-authority evidence"
    },
    {
      "id": "stale_review_age",
      "severity": "SEV3",
      "expression": "dokkaebi_review_age_seconds breaches review_age SLO window",
      "operatorAction": "remind approver, record review age, move blocked work only under documented policy",
      "owner": "Approver",
      "sloLinkage": "review_age"
    },
    {
      "id": "audit_export_gap",
      "severity": "SEV2",
      "expression": "dokkaebi_audit_export_total missing for a completed compliance package",
      "operatorAction": "stop compliance closeout, regenerate redacted export evidence, attach manifest status",
      "owner": "Compliance reviewer",
      "sloLinkage": "compliance package evidence"
    }
  ],
  "retentionRedaction": {
    "rawMetrics": "30 days or less when cost or security requires",
    "traceSamples": "7 days until approved backend and cost model exist",
    "sloRollups": "13 months",
    "incidentSnapshots": "retained with incident record",
    "complianceEvidence": "retained with compliance package",
    "auditExportAllowed": ["metric names", "bounded labels", "query windows", "alert decisions", "severity", "operator action", "validation command names", "manifest hashes"],
    "auditExportForbidden": ["raw secrets", "auth files", "cookies", "SSH material", "private paths", "raw prompts", "raw Worker command text"]
  },
  "traceCorrelation": {
    "spanNames": ["fire.poll_project", "manager.preflight", "hammer.route.select", "worker.result.collect", "audit.export.prepare"],
    "requiredIds": ["project", "repository", "issue_number", "route_class", "worker_class", "session_id", "run_id", "commit_sha", "environment"],
    "forbiddenFields": ["prompt", "credential payload", "full command text", "private path", "raw GitHub Project payload"]
  },
  "dashboardPanels": [
    "dispatch latency",
    "queue depth",
    "worker health",
    "retry and failure counts",
    "credential denials",
    "Human Review age",
    "audit-export evidence status"
  ],
  "remainingOperationalGaps": [
    "approved sandbox or live metrics backend is not connected",
    "live trace collection is not captured",
    "approved local sandbox on-call delivery evidence is captured while live paging delivery remains separately approval-gated",
    "backend retention and export enforcement outside approved local sandboxes remains separately approval-gated"
  ],
  "followUpIssueUrl": "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/80"
}
```
<!-- observability-metrics-alerts:end -->
