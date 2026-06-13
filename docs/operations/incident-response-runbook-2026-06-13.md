# Incident Response Runbook And Tabletop

This document records a docs-only incident response runbook and tabletop drill
for [`sre-operating-baseline.md`](sre-operating-baseline.md) and
[`on-call-paging-alerting.md`](on-call-paging-alerting.md). It does not
authorize credentials, production writes, infrastructure mutation, worker
dispatch, remote host operations, Docker, Kubernetes, deployment, or GitHub
Project control-plane mutation.

The runbook captures severity model, incident commander, detection,
communication surface, mitigation sequence, rollback or recovery decision,
alert routing decision, postmortem template, evidence retention,
approval-gate status, cleanup, residual risk, and next action.

Required exact terms: incident response runbook; tabletop drill; severity
model; incident commander; detection; communication surface; mitigation
sequence; rollback or recovery decision; alert routing decision; postmortem
template; evidence retention; approval-gate status; cleanup; residual risk;
next action; does not authorize.

## Runbook Summary

The tabletop simulates a SEV1 dispatch failure where Fire cannot dispatch
approved work and closeout evidence is potentially stale. The commander freezes
new dispatch for the affected route class, records the communication surface,
routes the alert to the current non-paging path, validates no live mutation was
authorized, and closes with a postmortem template plus follow-up work.

## Validation

Run:

```bash
bash scripts/validate-incident-response-runbook.sh
```

The validator accepts this complete docs-only package and rejects empty content,
malformed incident data, missing severity model, missing commander, missing
detection, missing communication surface, missing mitigation sequence, missing
rollback or recovery decision, missing alert routing decision, missing
postmortem template, missing evidence retention, missing approval-gate status,
missing cleanup, missing residual risk, missing next action, unsafe mutation
wording, private local paths, and secret-bearing wording.

<!-- incident-response:begin -->
```json
{
  "version": 1,
  "runbookId": "incident-response-tabletop-2026-06-13",
  "date": "2026-06-13",
  "permissionLevel": "docs-only-tabletop",
  "sourceBaselines": [
    "docs/operations/sre-operating-baseline.md",
    "docs/operations/on-call-paging-alerting.md"
  ],
  "scenario": {
    "severity": "SEV1",
    "trigger": "Fire cannot dispatch approved work and closeout evidence may be stale",
    "scope": "local tabletop fixture only",
    "customerImpact": "internal operator workflow risk only"
  },
  "severityModel": [
    {
      "severity": "SEV0",
      "trigger": "production data loss, leaked credential, destructive unauthorized action, or broad duplicate dispatch",
      "target": "immediate stop and Human owner page"
    },
    {
      "severity": "SEV1",
      "trigger": "Fire cannot dispatch approved work, all worker routes are unavailable, or closeout evidence is unreliable",
      "target": "triage within 30 minutes"
    },
    {
      "severity": "SEV2",
      "trigger": "degraded dispatch latency, stale Human Review queue, repeated retry failures, or one route class unavailable",
      "target": "triage within 1 business day"
    },
    {
      "severity": "SEV3",
      "trigger": "documentation, dashboard, or non-blocking evidence gap",
      "target": "triage in normal planning"
    }
  ],
  "incidentCommander": {
    "role": "Fire operator until relieved by project owner",
    "duties": [
      "declare severity and scope",
      "freeze unsafe dispatch when approval, credential, duplicate execution, or evidence integrity is uncertain",
      "name communication surface and next update time",
      "assign mitigation owner",
      "preserve issue, PR, log, validation, and result-packet evidence"
    ]
  },
  "detection": {
    "source": "dispatch latency and recovery-time alert fixture",
    "signal": "approved work remained undispatched and stale closeout evidence was detected",
    "validation": "bash scripts/validate-incident-response-runbook.sh: PASS"
  },
  "communicationSurface": "GitHub issue #25 and pull request timeline record severity, commander, mitigation, validation, postmortem, and closeout.",
  "mitigationSequence": [
    "Freeze new dispatch for the affected project, route, or permission class.",
    "Confirm approval gates and credential scope.",
    "Classify work items as completed, active lease, stale lease, failed retry, blocked, or unknown.",
    "Recover only through documented lease, route, and closeout contracts.",
    "Reopen or block any work item whose result evidence is incomplete."
  ],
  "rollbackOrRecoveryDecision": {
    "decision": "recover through documented lease, route, and closeout contracts only",
    "operator": "incident_commander",
    "evidence": "no live route, credential, deployment, production, or GitHub Project control-plane mutation reached"
  },
  "alertRoutingDecision": {
    "status": "dry-run-current-path",
    "route": "Fire operator watches GitHub issue, PR, workflow, and result-packet surfaces",
    "pagingBackend": "deferred until approved in the on-call paging baseline",
    "nextEscalation": "project owner for SEV0, credential, production, infrastructure, or destructive action risk"
  },
  "postmortemTemplate": {
    "requiredFields": [
      "timeline",
      "impact",
      "root cause",
      "contributing factors",
      "mitigation and recovery",
      "validation commands",
      "evidence links",
      "follow-up owner",
      "residual risk"
    ],
    "minimumTimelineEvents": [
      "detection",
      "severity declaration",
      "commander assignment",
      "mitigation decision",
      "recovery decision",
      "validation",
      "closeout"
    ]
  },
  "evidenceRetention": {
    "surface": "GitHub issue, pull request, validation transcript, and checked-in sanitized runbook",
    "redaction": "no secrets, auth files, cookies, tokens, private local paths, or raw credential material",
    "retentionOwner": "incident_commander"
  },
  "validationOutput": [
    "bash scripts/validate-incident-response-runbook.sh: PASS",
    "bash scripts/validate-sre-operating-baseline.sh: PASS",
    "bash scripts/validate-on-call-paging-alerting.sh: PASS",
    "bash scripts/validate-readiness-criteria.sh: PASS",
    "bash scripts/validate-contract-docs.sh: PASS"
  ],
  "approvalGateStatus": "No live approval-gated mutation reached; credential, production, infrastructure, worker, remote host, Docker, Kubernetes, deployment, and GitHub Project control-plane mutation remain not authorized.",
  "cleanup": {
    "status": "complete",
    "receipt": "No incident command touched a live system, and worker, remote host, container, cluster, production, credential, and GitHub Project configuration surfaces remained untouched."
  },
  "residualRisk": [
    "Approved sandbox incident drill evidence is not captured.",
    "Live paging backend delivery is not implemented.",
    "Automated postmortem generation and reminder evidence are not implemented.",
    "Production incident response remains unclaimed and approval-gated."
  ],
  "nextAction": "Run approved incident response drill and postmortem exercise in issue #78.",
  "followUpIssueUrl": "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/78"
}
```
<!-- incident-response:end -->
