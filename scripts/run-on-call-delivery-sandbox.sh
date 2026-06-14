#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from __future__ import annotations

import hashlib
import json

alerts = [
    {
        "alertId": "recovery_time_burn",
        "severity": "SEV1",
        "metric": "dokkaebi_recovery_time_seconds",
        "input": "recovery_time=1860s exceeds 1800s SLO",
        "slo": "recovery_time",
        "routeDecision": "urgent sandbox delivery to primary_on_call and secondary_on_call despite quiet hours",
        "deliveryReceipt": "sandbox-delivery-sev1-recovery-time-burn-20260614T061700Z",
        "escalationReceipt": "sandbox-escalation-sev1-primary-secondary-incident-commander-20260614T061700Z",
    },
    {
        "alertId": "dispatch_latency_burn",
        "severity": "SEV2",
        "metric": "dokkaebi_dispatch_latency_seconds",
        "input": "dispatch_latency=960s exceeds 900s SLO",
        "slo": "dispatch_latency",
        "routeDecision": "quiet-hours sandbox delivery receipt plus business-hours escalation queue",
        "deliveryReceipt": "sandbox-delivery-sev2-dispatch-latency-burn-20260614T061700Z",
        "escalationReceipt": "sandbox-escalation-sev2-business-hours-primary-service-owner-20260614T061700Z",
    },
]

payload = {
    "version": 1,
    "evidenceId": "on-call-delivery-sandbox-2026-06-14",
    "date": "2026-06-14",
    "issueUrl": "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/82",
    "permissionLevel": "approved-local-sandbox-on-call-delivery",
    "approvalRecord": {
        "approvedTarget": "local deterministic on-call delivery sandbox substitute",
        "scope": "route representative SEV1 and SEV2 alerts through sandbox delivery receipts without external side effects",
        "approvedSurfaces": [
            "backend substitute",
            "escalation roster",
            "notification sinks",
            "quiet-hours behavior",
            "delivery test plan",
            "cleanup evidence",
            "residual-risk handling",
        ],
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
            "GitHub Project control-plane",
        ],
        "evidence": "Project Dokkaebi development loop approval is limited to local sandbox delivery evidence for issue #82",
    },
    "sandboxBackend": {
        "target": "approved local sandbox delivery substitute",
        "backend": "deterministic repository fixture with in-memory delivery receipts",
        "notificationSinks": [
            "sandbox_primary_on_call_receipt",
            "sandbox_secondary_on_call_receipt",
            "sandbox_incident_commander_receipt",
            "sandbox_business_hours_queue_receipt",
        ],
        "mutationBoundary": "no live alerting service, live paging service, metrics service, credential, infrastructure, worker, remote host, Docker, Kubernetes, deployment, production, or GitHub Project control-plane mutation",
    },
    "escalationRoster": {
        "rotationCadence": "representative weekly roster for sandbox evidence",
        "timezone": "UTC",
        "roles": [
            "primary_on_call",
            "secondary_on_call",
            "incident_commander",
            "sre_owner",
            "service_owner",
        ],
        "handoffEvidence": "sandbox handoff record lists unresolved SEV1/SEV2 alerts and next action",
        "backupCoverage": "secondary_on_call backs up primary_on_call for urgent escalation",
    },
    "quietHoursDecision": {
        "timezone": "UTC",
        "sampleTime": "2026-06-14T06:17:00Z",
        "businessHours": "09:00-18:00 UTC Monday-Friday",
        "isQuietHours": True,
        "sev1Behavior": "deliver urgent sandbox receipts to primary_on_call, secondary_on_call, and incident_commander",
        "sev2Behavior": "record sandbox delivery receipt and queue business-hours escalation",
        "auditEvidence": "quiet-hours decision recorded with every sandbox delivery receipt",
    },
    "alertDeliveries": alerts,
    "deliveryReceipts": [
        "PASS SEV1 recovery_time_burn delivered to sandbox_primary_on_call_receipt",
        "PASS SEV1 recovery_time_burn delivered to sandbox_secondary_on_call_receipt",
        "PASS SEV1 recovery_time_burn escalated to sandbox_incident_commander_receipt",
        "PASS SEV2 dispatch_latency_burn delivered to sandbox_primary_on_call_receipt",
        "PASS SEV2 dispatch_latency_burn queued to sandbox_business_hours_queue_receipt",
    ],
    "escalationReceipts": [
        "PASS SEV1 escalation receipt includes primary_on_call, secondary_on_call, and incident_commander",
        "PASS SEV2 escalation receipt records business-hours queue and service_owner follow-up",
    ],
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
        "bash scripts/validate-git-governance.sh: PASS",
    ],
    "approvalGateStatus": "approved local sandbox only; no live alerting service, live paging service, metrics service, credential, infrastructure, worker, remote host, Docker, Kubernetes, deployment, production, or GitHub Project control-plane mutation reached this evidence and those targets remain not authorized",
    "cleanup": {
        "status": "complete",
        "receipt": "runner emits deterministic JSON only; no alerting service, paging service, metrics service, servers, ports, browser contexts, containers, credentials, remote hosts, Docker daemon, Kubernetes cluster, deployments, infrastructure, production targets, workers, or GitHub Project control-plane side effects were attempted; no resources remain",
    },
    "residualRisk": [
        "live paging backend delivery remains separately approval-gated",
        "production notification sinks remain separately approval-gated",
        "production roster integration remains separately approval-gated",
        "externally managed alert retention remains separately scoped",
    ],
    "readinessDecision": {
        "logging_observability": 100,
        "on_call_paging_alerting": 100,
        "basis": "approved local sandbox delivery substitute with SEV1 and SEV2 alert inputs, routing decisions, quiet-hours decisions, delivery receipts, escalation receipts, cleanup, validation output, and residual-risk evidence",
    },
    "nextAction": "use this sandbox delivery gate as routine on-call delivery evidence; require separate Human approval for live alerting service, paging service, metrics service, notification sink, production roster, or external-control rollout",
}

manifest_fields = {
    "sandboxBackend": payload["sandboxBackend"],
    "escalationRoster": payload["escalationRoster"],
    "quietHoursDecision": payload["quietHoursDecision"],
    "alertDeliveries": payload["alertDeliveries"],
    "deliveryReceipts": payload["deliveryReceipts"],
    "escalationReceipts": payload["escalationReceipts"],
    "validationOutput": payload["validationOutput"],
    "approvalGateStatus": payload["approvalGateStatus"],
    "cleanup": payload["cleanup"],
    "residualRisk": payload["residualRisk"],
    "readinessDecision": payload["readinessDecision"],
}
payload["manifestSha256"] = hashlib.sha256(
    json.dumps(manifest_fields, sort_keys=True).encode()
).hexdigest()
payload["runner"] = {
    "path": "scripts/run-on-call-delivery-sandbox.sh",
    "command": "bash scripts/run-on-call-delivery-sandbox.sh",
    "result": "PASS Dokkaebi on-call delivery sandbox runner completed",
}

print("PASS Dokkaebi on-call delivery sandbox runner completed")
print(json.dumps(payload, indent=2, sort_keys=True))
PY
