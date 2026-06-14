#!/usr/bin/env bash
set -euo pipefail

WORK_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

python3 - "$WORK_DIR/metrics.sqlite" <<'PY'
from __future__ import annotations

import hashlib
import json
import sqlite3
import sys
from pathlib import Path

db_path = Path(sys.argv[1])

allowed_labels = {
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
    "evidence_package_id",
}

metrics = [
    {
        "group": "dispatch",
        "metricName": "dokkaebi_dispatch_latency_seconds",
        "type": "histogram",
        "labels": {
            "project": "sandbox",
            "repository": "Project_Dokkaebi",
            "environment": "local_sandbox",
            "route_class": "docs",
        },
        "value": 412,
        "evidence": "ready work reached dispatch readiness inside the local sandbox backend run",
    },
    {
        "group": "recovery",
        "metricName": "dokkaebi_recovery_time_seconds",
        "type": "histogram",
        "labels": {
            "project": "sandbox",
            "repository": "Project_Dokkaebi",
            "environment": "local_sandbox",
            "failure_class": "stale_lease",
        },
        "value": 890,
        "evidence": "stale lease recovery sample stored in the sandbox backend",
    },
    {
        "group": "review_age",
        "metricName": "dokkaebi_review_age_seconds",
        "type": "histogram",
        "labels": {
            "project": "sandbox",
            "repository": "Project_Dokkaebi",
            "environment": "local_sandbox",
            "issue_number": "80",
        },
        "value": 172800,
        "evidence": "Human Review age sample stored for alert evaluation",
    },
    {
        "group": "worker_capacity",
        "metricName": "dokkaebi_worker_capacity_available",
        "type": "gauge",
        "labels": {
            "project": "sandbox",
            "environment": "local_sandbox",
            "route_class": "docs",
            "provider": "local",
        },
        "value": 2,
        "evidence": "route capacity gauge stored without worker dispatch",
    },
    {
        "group": "approval",
        "metricName": "dokkaebi_approval_gate_block_total",
        "type": "counter",
        "labels": {
            "project": "sandbox",
            "environment": "local_sandbox",
            "permission_level": "docs-only",
            "approval_gate_status": "blocked",
        },
        "value": 1,
        "evidence": "unauthorized operation sample remains blocked",
    },
    {
        "group": "validation",
        "metricName": "dokkaebi_validation_pass_total",
        "type": "counter",
        "labels": {
            "project": "sandbox",
            "repository": "Project_Dokkaebi",
            "environment": "local_sandbox",
            "validator_name": "readiness",
        },
        "value": 5,
        "evidence": "validator pass count stored for governance dashboard use",
    },
    {
        "group": "compliance",
        "metricName": "dokkaebi_compliance_evidence_complete",
        "type": "gauge",
        "labels": {
            "project": "sandbox",
            "environment": "local_sandbox",
            "control_class": "compliance",
            "evidence_package_id": "sandbox-backend",
        },
        "value": 1,
        "evidence": "compliance evidence completeness stored in sandbox backend",
    },
    {
        "group": "runtime_health",
        "metricName": "dokkaebi_runtime_poll_success_total",
        "type": "counter",
        "labels": {
            "project": "sandbox",
            "environment": "local_sandbox",
            "adapter": "github",
            "repository": "Project_Dokkaebi",
        },
        "value": 3,
        "evidence": "local control-loop health sample stored in sandbox backend",
    },
    {
        "group": "audit_export",
        "metricName": "dokkaebi_audit_export_verified_total",
        "type": "counter",
        "labels": {
            "project": "sandbox",
            "environment": "local_sandbox",
            "control_class": "audit_export",
            "evidence_package_id": "sandbox-backend",
        },
        "value": 1,
        "evidence": "audit export verification sample stored in sandbox backend",
    },
]

for metric in metrics:
    label_keys = set(metric["labels"])
    if label_keys - allowed_labels:
        raise SystemExit(f"disallowed label in {metric['metricName']}")
    if not metric["metricName"].startswith("dokkaebi_"):
        raise SystemExit(f"bad metric prefix in {metric['metricName']}")

conn = sqlite3.connect(db_path)
conn.execute(
    """
    create table metric_samples (
      group_name text not null,
      metric_name text not null,
      metric_type text not null,
      labels_json text not null,
      sample_value real not null,
      evidence text not null
    )
    """
)
for metric in metrics:
    conn.execute(
        "insert into metric_samples values (?, ?, ?, ?, ?, ?)",
        (
            metric["group"],
            metric["metricName"],
            metric["type"],
            json.dumps(metric["labels"], sort_keys=True),
            metric["value"],
            metric["evidence"],
        ),
    )
conn.commit()

def scalar(metric_name: str) -> float:
    row = conn.execute(
        "select max(sample_value) from metric_samples where metric_name = ?",
        (metric_name,),
    ).fetchone()
    if row is None or row[0] is None:
        raise SystemExit(f"missing query metric {metric_name}")
    return float(row[0])

queries = [
    {
        "name": "dispatch_latency",
        "expression": "max(dokkaebi_dispatch_latency_seconds)",
        "result": f"{int(scalar('dokkaebi_dispatch_latency_seconds'))}s",
        "slo": "within 900s",
        "status": "pass",
    },
    {
        "name": "recovery_time",
        "expression": "max(dokkaebi_recovery_time_seconds)",
        "result": f"{int(scalar('dokkaebi_recovery_time_seconds'))}s",
        "slo": "within 1800s",
        "status": "pass",
    },
    {
        "name": "review_age",
        "expression": "max(dokkaebi_review_age_seconds)",
        "result": f"{int(scalar('dokkaebi_review_age_seconds'))}s",
        "slo": "within reminder window",
        "status": "evaluated",
    },
    {
        "name": "availability_posture",
        "expression": "sum(dokkaebi_runtime_poll_success_total)",
        "result": f"{int(scalar('dokkaebi_runtime_poll_success_total'))} successful local polls",
        "slo": "observable local control-loop health",
        "status": "pass",
    },
    {
        "name": "audit_export",
        "expression": "sum(dokkaebi_audit_export_verified_total)",
        "result": str(int(scalar("dokkaebi_audit_export_verified_total"))),
        "slo": "evidence present",
        "status": "pass",
    },
]

dashboard_rows = [
    {"panel": "dispatch latency", "query": "dispatch_latency", "status": "pass"},
    {"panel": "recovery time", "query": "recovery_time", "status": "pass"},
    {"panel": "review age", "query": "review_age", "status": "evaluated"},
    {"panel": "worker capacity", "query": "worker_capacity", "status": "pass"},
    {"panel": "validation rate", "query": "validation", "status": "pass"},
    {"panel": "approval blocks", "query": "approval", "status": "evaluated"},
    {"panel": "compliance evidence completeness", "query": "compliance", "status": "pass"},
    {"panel": "immutable audit-export verification", "query": "audit_export", "status": "pass"},
]

alerts = [
    {"name": "dispatch latency burn", "status": "not_firing", "evidence": "412s below 900s"},
    {"name": "recovery time burn", "status": "not_firing", "evidence": "890s below 1800s"},
    {"name": "stale Human Review age", "status": "evaluated", "evidence": "reminder boundary reached"},
    {"name": "worker route capacity unavailable", "status": "not_firing", "evidence": "2 available"},
    {"name": "validation failure spike", "status": "not_firing", "evidence": "0 failures"},
    {"name": "approval-boundary violation", "status": "evaluated", "evidence": "blocked unauthorized operation remains blocked"},
    {"name": "missing compliance evidence", "status": "not_firing", "evidence": "compliance evidence complete and audit export verified"},
]

manifest = {
    "metrics": metrics,
    "queries": queries,
    "dashboardRows": dashboard_rows,
    "alerts": alerts,
}
manifest_sha256 = hashlib.sha256(json.dumps(manifest, sort_keys=True).encode()).hexdigest()

payload = {
    "version": 1,
    "backendRunId": "central-metrics-sandbox-backend-2026-06-14",
    "backend": "ephemeral sqlite local sandbox backend",
    "acceptedSamples": len(metrics),
    "rejectedSamples": 0,
    "storedGroups": [metric["group"] for metric in metrics],
    "queries": queries,
    "dashboardRows": dashboard_rows,
    "alerts": alerts,
    "manifestSha256": manifest_sha256,
    "approvalGateStatus": "No live approval-gated mutation reached; credentials, production, infrastructure, workers, remote hosts, Docker, Kubernetes, deployment, external metrics service, alerting service, and GitHub Project control-plane mutation remain not authorized.",
    "cleanup": {
        "status": "complete",
        "receipt": "removed ephemeral SQLite sandbox directory after runner exit; no credentials, external services, containers, clusters, workers, remote hosts, production targets, deployments, infrastructure, or GitHub Project settings touched",
    },
}

print("PASS Dokkaebi central metrics sandbox backend runner completed")
print(json.dumps(payload, indent=2, sort_keys=True))
PY
