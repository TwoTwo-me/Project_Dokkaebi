# Central Metrics Backend Integration

This document defines the docs-only central metrics backend integration design
for Project Dokkaebi. It does not deploy Prometheus, OpenTelemetry, Grafana,
Alertmanager, managed metrics services, Docker, Kubernetes, infrastructure,
workers, credentials, production systems, or GitHub Project control-plane
configuration.

The goal is to make SLO, alerting, capacity, incident, and audit evidence
measurable without relying on private worker memory. A later verification drill
must prove ingestion, storage, query, dashboard, and alert evaluation with a
local replay or an approved sandbox target before this capability can be treated
as operational.

The validation contract for this docs-only baseline explicitly covers metric
taxonomy, ingestion path, storage backend assumptions, retention, label and
cardinality controls, dashboard and alert integration, SLO linkage, ownership,
security boundary, rollout phases, verification steps, failure handling,
remaining operational gaps, permission level, and control-plane authority
boundaries.

## Enterprise Standard

A central metrics backend for Dokkaebi must:

- collect Manager, Fire, Hammer route, GitHub adapter, validation, compliance,
  and infrastructure-adjacent metrics through a stable ingestion path;
- store metrics with retention, query, and export behavior that supports SLO
  review, alerting, capacity planning, incident response, and audit evidence;
- control labels and cardinality so issue, route, worker, project, repository,
  environment, and commit dimensions are useful without leaking secrets or
  private machine state;
- connect dashboards and alert rules to the SRE operating baseline;
- keep credential, production, infrastructure, worker, remote host, Docker,
  Kubernetes, deployment, and GitHub Project control-plane mutation outside this
  docs-only design.

## Metric Taxonomy

Metrics are grouped by the user-visible operating question they answer.

| Group | Examples | Required dimensions |
| --- | --- | --- |
| Dispatch | admitted work count, dispatch latency, blocked-before-dispatch count | project, repository, issue number, route class, environment |
| Recovery | stale lease count, retry count, recovery time, duplicate-dispatch prevention count | project, route class, lease owner, failure class |
| Review | Human Review age, reminder count, escalation count | project, issue number, reviewer role |
| Worker capacity | available workers, busy workers, rejected route attempts, cleanup failures | route class, provider, environment |
| Approval and authority | approval-gate reached count, blocked unauthorized operation count | permission level, authority class, project |
| Validation | validation pass/fail count, validation duration, CI check result count | validator name, repository, branch class |
| Compliance | result-packet completeness, audit package review, immutable export verification status | control class, evidence package id |
| Runtime health | poll success, API rate-limit pressure, webhook reconciliation, queue depth | adapter, project, environment |

Metric names must use a `dokkaebi_` prefix, monotonically increasing counters
for events, histograms for latency and age, and gauges only for current state.

## Ingestion Path

The preferred ingestion path is OpenTelemetry metrics emitted by Fire and helper
adapters, received by an OpenTelemetry Collector, and exported to a
Prometheus-compatible backend. A smaller local replay may emit the same logical
metrics as Prometheus exposition text for validation.

The ingestion path must preserve these correlation identifiers when available:

- project id or stable project slug;
- repository owner/name;
- issue or pull request number;
- route class and provider;
- worker class, not worker secret or prompt content;
- commit SHA or check-run id;
- environment tier;
- permission level and approval-gate status.

The ingestion path must not emit raw prompts, tokens, cookies, SSH keys, auth
files, private home-directory paths, raw credential broker output, or
secret-bearing evidence.

## Storage Backend Assumptions

The design supports:

- short-term query storage through a Prometheus-compatible time-series backend;
- long-term retention through a remote-write target such as Mimir, Thanos,
  Cortex, or a managed equivalent;
- dashboard rendering through Grafana or an equivalent read-only dashboard
  surface;
- alert evaluation through Alertmanager, Grafana-managed alerts, or an approved
  notification adapter;
- read-only audit export of metric query evidence.

The repository does not choose or provision a production storage backend in this
PR. A future implementation must record the selected backend, owner, retention
class, access boundary, backup expectation, and rollback plan.

## Retention

Minimum retention metadata:

- raw high-cardinality samples: 30 days or shorter when cost/security requires;
- SLO rollups and alert evaluation history: 13 months;
- incident-linked metric snapshots: retained with the incident record;
- compliance-linked metric evidence: retained with the compliance package;
- deletion or extension decision: owned by the metrics backend owner.

Retention decisions must be represented in result evidence before metrics can
be cited as compliance or SRE proof.

## Label And Cardinality Controls

Allowed labels:

- `project`, `repository`, `environment`, `route_class`, `provider`;
- `issue_number` or `pull_request_number` when bounded to active work;
- `permission_level`, `approval_gate_status`, `validator_name`;
- `failure_class`, `control_class`, `evidence_package_id`.

Disallowed labels:

- raw prompt content;
- raw issue or PR body;
- token, cookie, SSH key, auth file path, or raw credential identifier;
- private machine path or home-directory path;
- unbounded exception message;
- worker command text that may include secrets;
- full GitHub Project control-plane payload.

New labels require review when they can grow with every user, command, path,
secret, stack trace, or arbitrary string.

## Dashboard And Alert Integration

Dashboard views must cover:

- dispatch latency and dispatch volume;
- recovery time, stale leases, retries, and duplicate-dispatch prevention;
- Human Review age and escalation status;
- worker capacity by route class and provider;
- validation pass/fail rate and duration;
- approval-gate blocks by authority class;
- compliance evidence completeness and immutable export verification status.

Initial alert rules:

- dispatch latency burn alert;
- recovery time burn alert;
- stale Human Review age alert;
- worker route capacity unavailable alert;
- validation failure spike alert;
- approval-gate or credential-boundary violation alert;
- missing compliance evidence alert.

Paging remains deferred until the on-call owner approves a backend, roster,
quiet-hours behavior, and test evidence. The on-call paging and alerting
baseline in [`on-call-paging-alerting.md`](on-call-paging-alerting.md) defines
the alert taxonomy, severity mapping, notification routing, SLO linkage, metrics
linkage, approval boundary, and test evidence shape that future alert
evaluation drills must satisfy.

## SLO Linkage

The service-level objectives document and SRE operating baseline name dispatch
latency, recovery time, and review age as the initial SLOs. The central metrics
backend must map those SLOs to:

- source metric names;
- query expressions or alert expressions;
- error-budget windows;
- dashboard panels;
- incident and postmortem evidence fields;
- fallback GitHub/log evidence when metrics are unavailable.

Until measured metrics exist, SLO readiness remains partially manual.

## Ownership

Every central metrics backend implementation must name:

- metrics backend owner;
- SRE owner;
- security reviewer;
- retention owner;
- dashboard owner;
- alert owner;
- compliance reviewer.

## Security Boundary

This design authorizes docs-only planning and local validation. It does not
authorize credential, production, infrastructure, worker, remote host, Proxmox,
Docker, Kubernetes, SSH, deployment, metrics service, alerting service, or
GitHub Project control-plane mutation. Any such operation requires explicit
Human approval under
[`../policies/authority-and-safety.md`](../policies/authority-and-safety.md).

Metrics must be redacted before export. Any metric that could contain secret
material or private machine state is rejected, not sanitized after ingestion.

## Rollout Phases

1. Design and deterministic validation in repository docs.
2. Local replay that emits representative metrics and evaluates sample queries.
3. Approved sandbox collection from a non-production Fire route.
4. Dashboard and alert-rule review with quiet-hours and notification behavior.
5. Retention and export verification for incident and compliance evidence.
6. Production proposal with access, backup, rollback, and owner approval.

## Verification Steps

1. Validate metric taxonomy and required SLO mappings.
2. Validate ingestion path and storage assumptions.
3. Validate retention metadata.
4. Validate label and cardinality controls.
5. Validate dashboard and alert integration.
6. Validate ownership and security boundary.
7. Validate rollout phases and remaining operational gaps.
8. Reject any design that authorizes sensitive mutation without approval.

## Failure Handling

Metrics evidence fails closed when required labels are missing, disallowed labels
are present, cardinality is unbounded, retention metadata is missing, SLO
mapping is missing, alert integration is missing, dashboard integration is
missing, storage assumptions are missing, ownership is missing, or the design
claims sensitive operational authority that was not explicitly approved.

## Validation

Run:

```bash
bash scripts/validate-central-metrics-backend.sh
```

The validator rejects empty design content, malformed metrics data, missing
metric taxonomy, missing ingestion path, missing storage assumptions, missing
retention, missing label or cardinality controls, missing dashboard or alert
integration, missing SLO linkage, missing ownership, missing security boundary,
missing rollout phases, missing validation steps, missing failure handling,
missing remaining operational gaps, missing permission level, or unauthorized
credential, production, infrastructure, remote host, Docker, Kubernetes,
deployment, or GitHub Project control-plane mutation wording.

<!-- central-metrics-backend:begin -->
```json
{
  "version": 1,
  "permissionLevel": "docs-only design and local validation",
  "securityBoundary": "This design does not authorize credential, production, infrastructure, worker, remote host, Proxmox, Docker, Kubernetes, SSH, deployment, metrics service, alerting service, or GitHub Project control-plane mutation without explicit Human approval",
  "metricTaxonomy": {
    "prefix": "dokkaebi_",
    "groups": [
      "dispatch",
      "recovery",
      "review",
      "worker_capacity",
      "approval_authority",
      "validation",
      "compliance",
      "runtime_health"
    ],
    "types": ["counter", "histogram", "gauge"]
  },
  "ingestionPath": {
    "preferred": "OpenTelemetry metrics from Fire and adapters to OpenTelemetry Collector to Prometheus-compatible backend",
    "localReplay": "Prometheus exposition text with the same logical metric names",
    "correlationIds": [
      "project",
      "repository",
      "issue_number",
      "route_class",
      "provider",
      "commit_sha",
      "environment",
      "permission_level",
      "approval_gate_status"
    ]
  },
  "storageBackendAssumptions": {
    "shortTerm": "Prometheus-compatible time-series backend",
    "longTerm": "remote-write target such as Mimir, Thanos, Cortex, or managed equivalent",
    "dashboard": "Grafana or equivalent read-only dashboard surface",
    "alertEvaluation": "Alertmanager, Grafana-managed alerts, or approved notification adapter",
    "auditExport": "read-only metric query evidence"
  },
  "retention": {
    "rawSamples": "30 days or shorter when cost/security requires",
    "sloRollups": "13 months",
    "incidentSnapshots": "retained with incident record",
    "complianceSnapshots": "retained with compliance package",
    "ownerDecision": "metrics backend owner records deletion or extension decision"
  },
  "labelCardinalityControls": {
    "allowedLabels": [
      "project",
      "repository",
      "environment",
      "route_class",
      "provider",
      "issue_number",
      "pull_request_number",
      "permission_level",
      "approval_gate_status",
      "validator_name",
      "failure_class",
      "control_class",
      "evidence_package_id"
    ],
    "disallowedLabels": [
      "raw prompt content",
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
    "reviewRule": "New labels require review when they can grow with every user, command, path, secret, stack trace, or arbitrary string"
  },
  "dashboardAlertIntegration": {
    "dashboards": [
      "dispatch latency",
      "recovery time",
      "review age",
      "worker capacity",
      "validation rate",
      "approval blocks",
      "compliance evidence"
    ],
    "alerts": [
      "dispatch latency burn",
      "recovery time burn",
      "stale Human Review age",
      "worker route capacity unavailable",
      "validation failure spike",
      "approval boundary violation",
      "missing compliance evidence"
    ],
    "pagingStatus": "deferred until on-call owner approves backend, roster, quiet-hours behavior, and test evidence"
  },
  "sloLinkage": {
    "dispatch_latency": "metric names, query expression, error-budget window, dashboard panel, incident field, fallback evidence",
    "recovery_time": "metric names, query expression, error-budget window, dashboard panel, incident field, fallback evidence",
    "review_age": "metric names, query expression, error-budget window, dashboard panel, incident field, fallback evidence"
  },
  "ownership": {
    "metricsBackendOwner": "required",
    "sreOwner": "required",
    "securityReviewer": "required",
    "retentionOwner": "required",
    "dashboardOwner": "required",
    "alertOwner": "required",
    "complianceReviewer": "required"
  },
  "rolloutPhases": [
    "docs-only design and deterministic validation",
    "local replay with representative metrics and sample queries",
    "approved sandbox collection from non-production Fire route",
    "dashboard and alert-rule review",
    "retention and export verification",
    "production proposal with access, backup, rollback, and owner approval"
  ],
  "verificationSteps": [
    "validate metric taxonomy and required SLO mappings",
    "validate ingestion path and storage assumptions",
    "validate retention metadata",
    "validate label and cardinality controls",
    "validate dashboard and alert integration",
    "validate ownership and security boundary",
    "validate rollout phases and remaining operational gaps",
    "reject sensitive mutation without approval"
  ],
  "failureHandling": [
    "missing required labels fail closed",
    "disallowed labels fail closed",
    "unbounded cardinality fails closed",
    "missing retention metadata fails closed",
    "missing SLO mapping fails closed",
    "missing alert integration fails closed",
    "missing dashboard integration fails closed",
    "unauthorized sensitive authority wording fails closed"
  ],
  "remainingOperationalGaps": [
    "measured local replay is not captured",
    "approved sandbox collection is not captured",
    "production storage backend is not selected",
    "dashboard screenshots or parsed dashboard evidence are not captured",
    "alert-rule evaluation evidence is not captured",
    "retention enforcement is not operational"
  ],
  "followUpIssueUrl": "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/57"
}
```
<!-- central-metrics-backend:end -->
