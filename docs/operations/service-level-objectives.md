# Service-Level Objectives And SLA Boundary

This document defines the initial service-level objectives for Project
Dokkaebi. It is intentionally docs-only and local-validation-only: it does not
mutate credentials, workers, remote hosts, Docker, Kubernetes, Proxmox,
deployment, production, infrastructure, alerting services, or GitHub Project
control-plane state.

The objectives below are internal operating SLOs. They are not an external SLA,
customer-facing promise, support contract, uptime warranty, or production
availability commitment. External SLA language requires explicit Human owner
approval, named customer-facing scope, legal or commercial review, measurement
source approval, escalation ownership, and a later ADR or signed operating
agreement.

## Scope

The initial SLO scope covers the Manager, Fire, Hammer route, GitHub adapter,
result-packet closeout, and Human Review surfaces that are already described in
the Manager contract, SRE baseline, central metrics design, and on-call alerting
baseline.

The SLOs are measured from central metrics once issue #57 proves ingestion,
storage, query, dashboard, and alert evaluation evidence. Until then, they are
reviewable through fallback GitHub issue, pull request, workflow, local replay,
and result-packet evidence.

## Initial SLOs

| ID | Objective | Initial target | Measurement source | Fallback evidence | Error budget |
| --- | --- | --- | --- | --- | --- |
| `dispatch_latency` | Ready work reaches dispatch readiness or an explicit blocked state. | P90 within 15 minutes. | `dokkaebi_dispatch_latency_seconds` histogram from the central metrics backend. | GitHub Project status transition, issue comment, workflow timestamp, or local replay transcript. | More than 5 misses in 30 days triggers error-budget review. |
| `recovery_time` | Failed or stale leased work reaches recovered, blocked, or Human Review state after detection. | P95 within 30 minutes. | `dokkaebi_recovery_time_seconds` histogram and stale lease counters. | Durable lease evidence, retry record, route result, result packet, or local replay transcript. | More than 3 misses in 30 days freezes risky routing changes. |
| `review_age` | Human Review work receives reminder and escalation evidence before it becomes stale. | Reminder within 2 business days, escalation within 5 business days. | `dokkaebi_review_age_seconds` histogram and review queue gauges. | Issue comment, PR review, project status evidence, or local replay transcript. | Any 5-business-day miss requires owner review. |

## Availability Posture

The internal availability posture is a development-stage operating target, not
an external SLA. During supported operating windows, Fire control-loop health
should remain observable and recoverable. The initial review target is 99
percent observable Fire control-loop availability during approved operating
windows, measured by future central metrics health samples and backed by
fallback workflow or local replay evidence while the backend is being proven.

Availability does not include external GitHub outages, unapproved worker
targets, credential provider outages, or production customer commitments unless
a Human owner approves a specific SLA surface.

## Error-Budget Policy

Error-budget review is a governance action, not an automatic permission grant.
When a budget burns, the Manager must preserve evidence and require an owner
decision before risky routing, worker scaling, deployment, credential, or
production changes proceed.

Budget review includes:

1. the SLO ID and window;
2. observed misses and total eligible events;
3. source metric query or fallback GitHub evidence;
4. impact summary and affected project or route class;
5. owner action, freeze decision, and follow-up issue;
6. approval-gate status and residual risk.

## Review Cadence

| Cadence | Action |
| --- | --- |
| Per PR | Confirm changed behavior preserves SLO measurement, fallback evidence, and authority boundaries. |
| Weekly while active | Review dispatch latency, recovery time, review age, and availability posture from available metrics or fallback evidence. |
| Monthly | Record error-budget summary, follow-up owners, and readiness scoring changes. |
| Incident closeout | Attach SLO miss, budget impact, mitigation, validation, residual risk, and next action to the incident timeline. |

## Owner Actions

| Role | Required action |
| --- | --- |
| SRE owner | Owns SLO target review, error-budget review, and follow-up prioritization. |
| Fire operator | Captures dispatch, recovery, stale lease, and review queue evidence. |
| Manager reviewer | Confirms result-packet closeout and readiness scoring evidence. |
| Human approver | Approves any external SLA, production commitment, credential expansion, infrastructure change, worker scaling, deployment, or live alerting backend. |
| Compliance reviewer | Confirms retained SLO evidence is redacted, exportable, and linked to audit evidence where needed. |

## External SLA Boundary

External SLA status is **not approved**. The project must not claim customer
uptime, paid support response, production recovery guarantees, or contractual
availability until the Human owner records:

- service tier and customer-facing scope;
- measurement source and exclusion policy;
- support hours and escalation roster;
- incident communication commitments;
- compensation or commercial consequence if any;
- legal or commercial review;
- owner approval record and later ADR or signed operating agreement.

## Validation

Run:

```bash
bash scripts/validate-service-level-objectives.sh
```

The validator checks the human-readable document and the structured control
block below. It rejects incomplete SLO definitions, missing fallback evidence,
invalid numeric thresholds, missing error-budget policy, missing review cadence,
missing owner actions, missing external SLA approval boundary, secret-bearing or
over-authorized wording, and malformed control data.

## Residual Risk And Next Action

Residual risk remains because central metrics ingestion, query, dashboard,
alert evaluation, and sandbox replay evidence are still pending. The next
action is issue #57, which must produce or replay representative central metrics
and alert evidence before the SLO/SLA capability can approach completion.

<!-- service-level-objectives:begin -->
```json
{
  "version": 1,
  "permissionLevel": "docs-only",
  "approvalGateStatus": "no live, credential, worker, remote host, Docker, Kubernetes, Proxmox, deployment, production, infrastructure, alerting service, or GitHub Project control-plane mutation reached",
  "serviceScope": [
    "Manager",
    "Fire",
    "Hammer route",
    "GitHub adapter",
    "result-packet closeout",
    "Human Review"
  ],
  "slos": [
    {
      "id": "dispatch_latency",
      "name": "Dispatch latency",
      "target": "P90 admitted ready work reaches dispatch readiness or explicit blocked state within 15 minutes",
      "percentile": 90,
      "thresholdSeconds": 900,
      "measurementSource": "dokkaebi_dispatch_latency_seconds metric histogram from central metrics backend",
      "fallbackEvidence": "fallback evidence from GitHub Project status transition, issue comment, workflow timestamp, or local replay transcript",
      "errorBudget": "More than 5 misses in 30 days triggers error-budget review",
      "ownerAction": "SRE owner reviews queue health and Fire operator captures dispatch evidence"
    },
    {
      "id": "recovery_time",
      "name": "Recovery time",
      "target": "P95 failed or stale leased work reaches recovered, blocked, or Human Review state within 30 minutes of detection",
      "percentile": 95,
      "thresholdSeconds": 1800,
      "measurementSource": "dokkaebi_recovery_time_seconds metric histogram and stale lease counters",
      "fallbackEvidence": "fallback evidence from durable lease evidence, retry record, route result, result packet, or local replay transcript",
      "errorBudget": "More than 3 misses in 30 days freezes risky routing changes",
      "ownerAction": "Fire operator classifies stale leases and Manager reviewer verifies closeout evidence"
    },
    {
      "id": "review_age",
      "name": "Review age",
      "target": "Human Review items receive reminder evidence within 2 business days and escalation evidence within 5 business days",
      "percentile": 100,
      "thresholdSeconds": 432000,
      "measurementSource": "dokkaebi_review_age_seconds metric histogram and review queue gauges",
      "fallbackEvidence": "fallback evidence from issue comment, PR review, project status evidence, or local replay transcript",
      "errorBudget": "Any 5-business-day miss requires owner review",
      "ownerAction": "Manager reviewer records reminder and escalation evidence"
    }
  ],
  "availabilityPosture": {
    "internalTarget": "99 percent observable Fire control-loop availability during approved operating windows",
    "measurementSource": "central metrics health sample and future sandbox replay evidence",
    "fallbackEvidence": "workflow status, issue timeline, or local replay transcript while metrics backend is pending",
    "noExternalCommitment": "no customer-facing SLA, uptime warranty, or production availability commitment is approved"
  },
  "errorBudgetPolicy": {
    "burnCalculation": "misses divided by eligible events in the SLO window",
    "reviewCadence": "weekly active review and monthly readiness summary",
    "freezeRule": "budget burn freezes risky routing, worker scaling, deployment, credential, infrastructure, and production changes until an owner decision is recorded",
    "resetPolicy": "budget resets only after owner review records mitigation, validation, residual risk, and next action"
  },
  "reviewCadence": {
    "perPullRequest": "confirm SLO measurement and fallback evidence are preserved",
    "weekly": "review dispatch latency, recovery time, review age, and availability posture",
    "monthly": "record error-budget summary, follow-up owners, and readiness scoring changes",
    "incidentCloseout": "attach SLO miss, budget impact, mitigation, validation, residual risk, and next action"
  },
  "ownerActions": {
    "sreOwner": "owns SLO target review, error-budget review, and follow-up prioritization",
    "fireOperator": "captures dispatch, recovery, stale lease, and review queue evidence",
    "managerReviewer": "confirms result-packet closeout and readiness scoring evidence",
    "humanApprover": "approves any external SLA, production commitment, credential expansion, infrastructure change, worker scaling, deployment, or live alerting backend",
    "complianceReviewer": "confirms retained SLO evidence is redacted, exportable, and linked to audit evidence where needed"
  },
  "externalSlaBoundary": {
    "status": "not_approved",
    "approvalRequired": "Human owner approval, customer-facing scope, legal or commercial review, measurement source approval, escalation ownership, and later ADR or signed operating agreement",
    "forbiddenClaims": [
      "customer uptime guarantee",
      "paid support response promise",
      "production recovery guarantee",
      "contractual availability commitment"
    ]
  },
  "followUpIssue": "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/57",
  "residualRisk": [
    "Central metrics ingestion is not yet measured",
    "Dashboard and alert evaluation evidence is not yet captured",
    "External SLA approval is not recorded"
  ],
  "nextAction": "Run central metrics backend sandbox verification under issue #57",
  "requiredEvidence": [
    "changed artifacts and rationale",
    "acceptance-criteria evidence",
    "validation command output",
    "approval-gate status",
    "residual risk and next action"
  ]
}
```
<!-- service-level-objectives:end -->
