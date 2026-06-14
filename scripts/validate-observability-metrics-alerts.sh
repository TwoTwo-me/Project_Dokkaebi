#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}

DOC_PATH="${OBSERVABILITY_METRICS_ALERTS_PATH:-docs/operations/observability-metrics-alert-rules.md}"

[[ -f "$DOC_PATH" ]] || fail "missing file: $DOC_PATH"

for term in \
  "Metrics Catalog" \
  "Alert Rules" \
  "Trace Correlation" \
  "Redaction And Retention" \
  "Dashboard Panels" \
  "Approval Boundary" \
  "docs-only"; do
  grep -Fq -- "$term" "$DOC_PATH" || fail "missing text in $DOC_PATH: $term"
done

command -v python3 >/dev/null || fail "missing command: python3"

python3 - "$DOC_PATH" <<'PY'
from __future__ import annotations

import copy
import json
import sys
from pathlib import Path
from typing import Any

START = "<!-- observability-metrics-alerts:begin -->"
END = "<!-- observability-metrics-alerts:end -->"
REQUIRED_METRICS = {
    "dokkaebi_dispatch_latency_seconds": "histogram",
    "dokkaebi_queue_depth": "gauge",
    "dokkaebi_worker_health": "gauge",
    "dokkaebi_dispatch_retry_total": "counter",
    "dokkaebi_worker_failure_total": "counter",
    "dokkaebi_credential_denial_total": "counter",
    "dokkaebi_review_age_seconds": "histogram",
    "dokkaebi_audit_export_total": "counter",
}
REQUIRED_ALERTS = {
    "dispatch_latency_burn",
    "queue_depth_growth",
    "worker_health_unavailable",
    "retry_failure_spike",
    "credential_denial_spike",
    "stale_review_age",
    "audit_export_gap",
}
REQUIRED_CORRELATION = {
    "project",
    "repository",
    "environment",
    "route_class",
    "worker_class",
    "issue_number",
    "session_id",
    "run_id",
    "commit_sha",
}
SENSITIVE_TERMS = [
    "credential",
    "worker",
    "remote host",
    "docker",
    "kubernetes",
    "infrastructure",
    "production",
    "deployment",
    "metrics service",
    "alerting service",
    "paging service",
    "control-plane",
    "explicit human approval",
]
UNSAFE_WORDING = [
    "credential mutation authorized",
    "worker execution authorized",
    "remote host mutation authorized",
    "docker mutation authorized",
    "kubernetes mutation authorized",
    "infrastructure mutation authorized",
    "production write authorized",
    "deployment authorized",
    "metrics service configured",
    "alerting service configured",
    "paging service configured",
    "control-plane mutation authorized",
]
DISALLOWED_LABEL_TERMS = {
    "token",
    "cookie",
    "ssh key",
    "auth file path",
    "private machine path",
    "worker command text",
    "credential broker payload",
}


class ValidationError(Exception):
    pass


def reject(message: str) -> None:
    raise ValidationError(message)


def extract_payload(text: str) -> dict[str, Any]:
    if not text.strip():
        reject("empty observability metrics alert baseline")
    if text.count(START) != 1 or text.count(END) != 1:
        reject("missing or duplicate observability metrics alert block")
    block = text.split(START, 1)[1].split(END, 1)[0].strip()
    if block.startswith("```json"):
        block = block.removeprefix("```json").strip()
    if block.endswith("```"):
        block = block[: -len("```")].strip()
    try:
        payload = json.loads(block)
    except json.JSONDecodeError as exc:
        reject(f"malformed observability data: {exc}")
    if not isinstance(payload, dict):
        reject("observability metrics alert block must be an object")
    return payload


def require_text(value: Any, label: str, terms: list[str] | None = None) -> str:
    if not isinstance(value, str) or not value.strip():
        reject(f"missing {label}")
    text = value.lower()
    for term in terms or []:
        if term.lower() not in text:
            reject(f"{label} missing {term}")
    return text


def require_list(value: Any, label: str, min_items: int = 1) -> list[Any]:
    if not isinstance(value, list) or len(value) < min_items:
        reject(f"missing {label}")
    return value


def validate_payload(payload: dict[str, Any]) -> None:
    require_text(payload.get("permissionLevel"), "permission level", ["docs-only"])
    boundary = require_text(payload.get("securityBoundary"), "security boundary")
    for term in SENSITIVE_TERMS:
        if term not in boundary:
            reject(f"security boundary missing {term}")
    for phrase in UNSAFE_WORDING:
        if phrase in boundary:
            reject(f"unauthorized sensitive authority wording: {phrase}")

    routing = require_text(payload.get("routingStatus"), "routing status")
    for term in ["github evidence", "deferred", "human approval"]:
        if term not in routing:
            reject(f"routing status missing {term}")

    top_correlation = {str(item) for item in require_list(payload.get("requiredCorrelationIds"), "required correlation ids", 9)}
    missing_top = REQUIRED_CORRELATION - top_correlation
    if missing_top:
        reject("top-level correlation ids missing " + ", ".join(sorted(missing_top)))

    disallowed = {str(item).lower() for item in require_list(payload.get("disallowedLabels"), "disallowed labels", 8)}
    for term in DISALLOWED_LABEL_TERMS:
        if not any(term in item for item in disallowed):
            reject(f"disallowed labels missing {term}")

    metrics = require_list(payload.get("metrics"), "metrics", len(REQUIRED_METRICS))
    by_name: dict[str, dict[str, Any]] = {}
    for metric in metrics:
        if not isinstance(metric, dict):
            reject("metric entry must be an object")
        name = require_text(metric.get("name"), "metric name")
        if name in by_name:
            reject(f"duplicate metric {name}")
        by_name[name] = metric
        if not name.startswith("dokkaebi_"):
            reject(f"metric missing dokkaebi_ prefix: {name}")
        dimensions = {str(item) for item in require_list(metric.get("dimensions"), f"{name} dimensions", 3)}
        for label in dimensions:
            low = label.lower()
            if any(term in low for term in DISALLOWED_LABEL_TERMS):
                reject(f"{name} uses unsafe dimension {label}")
        for field in ["source", "sloLinkage", "operatorUse", "redaction", "retention"]:
            require_text(metric.get(field), f"{name} {field}")
        require_text(metric.get("redaction"), f"{name} redaction", ["no"])

    missing_metrics = set(REQUIRED_METRICS) - set(by_name)
    if missing_metrics:
        reject("missing metrics " + ", ".join(sorted(missing_metrics)))
    for metric_name, metric_type in REQUIRED_METRICS.items():
        metric = by_name[metric_name]
        if metric.get("type") != metric_type:
            reject(f"{metric_name} must be {metric_type}")

    alerts = require_list(payload.get("alerts"), "alerts", len(REQUIRED_ALERTS))
    alert_ids: set[str] = set()
    for alert in alerts:
        if not isinstance(alert, dict):
            reject("alert entry must be an object")
        alert_id = require_text(alert.get("id"), "alert id")
        alert_ids.add(alert_id)
        if alert.get("severity") not in {"SEV1", "SEV2", "SEV3"}:
            reject(f"{alert_id} has invalid severity")
        for field in ["expression", "operatorAction", "owner", "sloLinkage"]:
            require_text(alert.get(field), f"{alert_id} {field}")
        action = require_text(alert.get("operatorAction"), f"{alert_id} operator action")
        if not any(verb in action for verb in ["open", "assign", "mark", "inspect", "block", "remind", "stop"]):
            reject(f"{alert_id} operator action is not actionable")
    missing_alerts = REQUIRED_ALERTS - alert_ids
    if missing_alerts:
        reject("missing alerts " + ", ".join(sorted(missing_alerts)))

    retention = payload.get("retentionRedaction")
    if not isinstance(retention, dict):
        reject("missing retention and redaction")
    for field in ["rawMetrics", "traceSamples", "sloRollups", "incidentSnapshots", "complianceEvidence"]:
        require_text(retention.get(field), f"retention {field}")
    allowed = " ".join(str(item).lower() for item in require_list(retention.get("auditExportAllowed"), "audit export allowed", 5))
    forbidden = " ".join(str(item).lower() for item in require_list(retention.get("auditExportForbidden"), "audit export forbidden", 5))
    for term in ["metric names", "bounded labels", "alert decisions", "manifest hashes"]:
        if term not in allowed:
            reject(f"audit export allowed missing {term}")
    for term in ["raw secrets", "auth files", "cookies", "ssh material", "private paths", "raw prompts"]:
        if term not in forbidden:
            reject(f"audit export forbidden missing {term}")

    trace = payload.get("traceCorrelation")
    if not isinstance(trace, dict):
        reject("missing trace correlation")
    spans = " ".join(str(item) for item in require_list(trace.get("spanNames"), "trace span names", 4))
    for term in ["fire.poll_project", "manager.preflight", "hammer.route.select", "worker.result.collect"]:
        if term not in spans:
            reject(f"trace span names missing {term}")
    trace_ids = {str(item) for item in require_list(trace.get("requiredIds"), "trace required ids", 6)}
    if REQUIRED_CORRELATION - trace_ids:
        reject("trace correlation missing required ids")
    forbidden_fields = " ".join(str(item).lower() for item in require_list(trace.get("forbiddenFields"), "trace forbidden fields", 4))
    for term in ["prompt", "credential", "full command text", "private path"]:
        if term not in forbidden_fields:
            reject(f"trace forbidden fields missing {term}")

    panels = " ".join(str(item).lower() for item in require_list(payload.get("dashboardPanels"), "dashboard panels", 6))
    for term in ["dispatch latency", "queue depth", "worker health", "credential denials", "human review age", "audit-export"]:
        if term not in panels:
            reject(f"dashboard panels missing {term}")
    require_list(payload.get("remainingOperationalGaps"), "remaining operational gaps", 3)
    require_text(payload.get("followUpIssueUrl"), "follow-up issue", ["github.com", "/issues/80"])


doc_text = Path(sys.argv[1]).read_text(encoding="utf-8")
baseline = extract_payload(doc_text)
validate_payload(baseline)


def expect_reject(name: str, candidate: str | dict[str, Any]) -> None:
    try:
        if isinstance(candidate, str):
            validate_payload(extract_payload(candidate))
        else:
            validate_payload(candidate)
    except ValidationError:
        return
    reject(f"negative fixture unexpectedly passed: {name}")


expect_reject("empty doc", "")
expect_reject("malformed json", START + "\n```json\n{\"version\": \n```\n" + END)

for field in ["permissionLevel", "routingStatus", "securityBoundary", "metrics", "alerts", "retentionRedaction", "traceCorrelation"]:
    mutated = copy.deepcopy(baseline)
    mutated[field] = [] if field in {"metrics", "alerts"} else ""
    expect_reject(f"missing {field}", mutated)

mutated = copy.deepcopy(baseline)
mutated["metrics"] = [m for m in mutated["metrics"] if m["name"] != "dokkaebi_queue_depth"]
expect_reject("missing queue depth metric", mutated)

mutated = copy.deepcopy(baseline)
mutated["metrics"][0]["dimensions"].append("token")
expect_reject("unsafe metric label", mutated)

mutated = copy.deepcopy(baseline)
mutated["alerts"][0]["operatorAction"] = "observe"
expect_reject("non-actionable alert", mutated)

mutated = copy.deepcopy(baseline)
mutated["securityBoundary"] = "production write authorized"
expect_reject("unauthorized production wording", mutated)

print("PASS Dokkaebi observability metrics and alert rules validation passed")
PY
