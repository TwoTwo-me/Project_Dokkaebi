# On-Call Delivery Sandbox Gate

This document records the approved local sandbox on-call delivery gate evidence
for issue #82. It proves approved local sandbox delivery for representative
SEV1 and SEV2 alert input, routing decision, quiet-hours decision, delivery
receipt, escalation receipt, validation output, approval-gate status, cleanup
receipt, residual risk, and next action without live alerting service, live
paging service, metrics service, credentials, infrastructure, workers, remote
hosts, Docker, Kubernetes, deployment, production, or GitHub Project
control-plane mutation.

The sandbox backend is a deterministic repository fixture with in-memory
receipts. It does not authorize a live page, live paging backend, live alerting
backend, production notification sink, credential use, infrastructure mutation,
worker mutation, or GitHub Project settings mutation.

Required exact terms: on-call delivery sandbox gate; approved local sandbox
delivery; SEV1; SEV2; alert input; routing decision; quiet-hours decision;
delivery receipt; escalation receipt; approval-gate status; cleanup receipt;
residual risk; next action; does not authorize.

Run:

```bash
bash scripts/run-on-call-delivery-sandbox.sh
bash scripts/validate-on-call-delivery-sandbox.sh
```

<!-- on-call-delivery-sandbox:begin -->
```json
{
  "alertDeliveries": [
    {
      "alertId": "recovery_time_burn",
      "deliveryReceipt": "sandbox-delivery-sev1-recovery-time-burn-20260614T061700Z",
      "escalationReceipt": "sandbox-escalation-sev1-primary-secondary-incident-commander-20260614T061700Z",
      "input": "recovery_time=1860s exceeds 1800s SLO",
      "metric": "dokkaebi_recovery_time_seconds",
      "routeDecision": "urgent sandbox delivery to primary_on_call and secondary_on_call despite quiet hours",
      "severity": "SEV1",
      "slo": "recovery_time"
    },
    {
      "alertId": "dispatch_latency_burn",
      "deliveryReceipt": "sandbox-delivery-sev2-dispatch-latency-burn-20260614T061700Z",
      "escalationReceipt": "sandbox-escalation-sev2-business-hours-primary-service-owner-20260614T061700Z",
      "input": "dispatch_latency=960s exceeds 900s SLO",
      "metric": "dokkaebi_dispatch_latency_seconds",
      "routeDecision": "quiet-hours sandbox delivery receipt plus business-hours escalation queue",
      "severity": "SEV2",
      "slo": "dispatch_latency"
    }
  ],
  "approvalGateStatus": "approved local sandbox only; no live alerting service, live paging service, metrics service, credential, infrastructure, worker, remote host, Docker, Kubernetes, deployment, production, or GitHub Project control-plane mutation reached this evidence and those targets remain not authorized",
  "approvalRecord": {
    "approvedSurfaces": [
      "backend substitute",
      "escalation roster",
      "notification sinks",
      "quiet-hours behavior",
      "delivery test plan",
      "cleanup evidence",
      "residual-risk handling"
    ],
    "approvedTarget": "local deterministic on-call delivery sandbox substitute",
    "deniedTargets": [
      "live alerting service",
      "live paging service",
      "metrics service",
      "credentials",
      "infrastructure",
      "worker",
      "remote host",
      "Docker",
      "Kubernetes",
      "deployment",
      "production",
      "GitHub Project control-plane"
    ],
    "evidence": "Project Dokkaebi development loop approval is limited to local sandbox delivery evidence for issue #82",
    "scope": "route representative SEV1 and SEV2 alerts through sandbox delivery receipts without external side effects"
  },
  "cleanup": {
    "receipt": "runner emits deterministic JSON only; no alerting service, paging service, metrics service, servers, ports, browser contexts, containers, credentials, remote hosts, Docker daemon, Kubernetes cluster, deployments, infrastructure, production targets, workers, or GitHub Project control-plane side effects were attempted; no resources remain",
    "status": "complete"
  },
  "date": "2026-06-14",
  "deliveryReceipts": [
    "PASS SEV1 recovery_time_burn delivered to sandbox_primary_on_call_receipt",
    "PASS SEV1 recovery_time_burn delivered to sandbox_secondary_on_call_receipt",
    "PASS SEV1 recovery_time_burn escalated to sandbox_incident_commander_receipt",
    "PASS SEV2 dispatch_latency_burn delivered to sandbox_primary_on_call_receipt",
    "PASS SEV2 dispatch_latency_burn queued to sandbox_business_hours_queue_receipt"
  ],
  "escalationReceipts": [
    "PASS SEV1 escalation receipt includes primary_on_call, secondary_on_call, and incident_commander",
    "PASS SEV2 escalation receipt records business-hours queue and service_owner follow-up"
  ],
  "escalationRoster": {
    "backupCoverage": "secondary_on_call backs up primary_on_call for urgent escalation",
    "handoffEvidence": "sandbox handoff record lists unresolved SEV1/SEV2 alerts and next action",
    "roles": [
      "primary_on_call",
      "secondary_on_call",
      "incident_commander",
      "sre_owner",
      "service_owner"
    ],
    "rotationCadence": "representative weekly roster for sandbox evidence",
    "timezone": "UTC"
  },
  "evidenceId": "on-call-delivery-sandbox-2026-06-14",
  "issueUrl": "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/82",
  "manifestSha256": "328f15e717565a7cf40c4eddad961123dff2a39ad335106c616dfebc6e959316",
  "nextAction": "use this sandbox delivery gate as routine on-call delivery evidence; require separate Human approval for live alerting service, paging service, metrics service, notification sink, production roster, or external-control rollout",
  "permissionLevel": "approved-local-sandbox-on-call-delivery",
  "quietHoursDecision": {
    "auditEvidence": "quiet-hours decision recorded with every sandbox delivery receipt",
    "businessHours": "09:00-18:00 UTC Monday-Friday",
    "isQuietHours": true,
    "sampleTime": "2026-06-14T06:17:00Z",
    "sev1Behavior": "deliver urgent sandbox receipts to primary_on_call, secondary_on_call, and incident_commander",
    "sev2Behavior": "record sandbox delivery receipt and queue business-hours escalation",
    "timezone": "UTC"
  },
  "readinessDecision": {
    "basis": "approved local sandbox delivery substitute with SEV1 and SEV2 alert inputs, routing decisions, quiet-hours decisions, delivery receipts, escalation receipts, cleanup, validation output, and residual-risk evidence",
    "logging_observability": 100,
    "on_call_paging_alerting": 100
  },
  "residualRisk": [
    "live paging backend delivery remains separately approval-gated",
    "production notification sinks remain separately approval-gated",
    "production roster integration remains separately approval-gated",
    "externally managed alert retention remains separately scoped"
  ],
  "runner": {
    "command": "bash scripts/run-on-call-delivery-sandbox.sh",
    "path": "scripts/run-on-call-delivery-sandbox.sh",
    "result": "PASS Dokkaebi on-call delivery sandbox runner completed"
  },
  "sandboxBackend": {
    "backend": "deterministic repository fixture with in-memory delivery receipts",
    "mutationBoundary": "no live alerting service, live paging service, metrics service, credential, infrastructure, worker, remote host, Docker, Kubernetes, deployment, production, or GitHub Project control-plane mutation",
    "notificationSinks": [
      "sandbox_primary_on_call_receipt",
      "sandbox_secondary_on_call_receipt",
      "sandbox_incident_commander_receipt",
      "sandbox_business_hours_queue_receipt"
    ],
    "target": "approved local sandbox delivery substitute"
  },
  "validationOutput": [
    "bash scripts/run-on-call-delivery-sandbox.sh: PASS",
    "bash scripts/validate-on-call-delivery-sandbox.sh: PASS",
    "bash scripts/validate-on-call-paging-alerting.sh: PASS",
    "bash scripts/validate-on-call-alert-routing-drill.sh: PASS",
    "bash scripts/validate-central-metrics-backend.sh: PASS",
    "bash scripts/validate-central-metrics-sandbox-backend.sh: PASS",
    "bash scripts/validate-sre-operating-baseline.sh: PASS",
    "bash scripts/validate-readiness-criteria.sh: PASS",
    "bash scripts/validate-contract-docs.sh: PASS",
    "bash scripts/validate-git-governance.sh: PASS"
  ],
  "version": 1
}
```
<!-- on-call-delivery-sandbox:end -->
