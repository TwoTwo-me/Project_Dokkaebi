#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}

require_text() {
  local path="$1"
  local needle="$2"
  [[ -f "$path" ]] || fail "missing file: $path"
  grep -Fqi -- "$needle" "$path" || fail "missing text in $path: $needle"
}

DOC_PATH="${CENTRAL_METRICS_BACKEND_PATH:-docs/operations/central-metrics-backend.md}"

for term in \
  "metric taxonomy" \
  "ingestion path" \
  "storage backend assumptions" \
  "retention" \
  "label and cardinality controls" \
  "dashboard and alert integration" \
  "SLO linkage" \
  "ownership" \
  "security boundary" \
  "rollout phases" \
  "verification steps" \
  "failure handling" \
  "remaining operational gaps" \
  "permission level" \
  "docs-only" \
  "control-plane"; do
  require_text "$DOC_PATH" "$term"
done

command -v python3 >/dev/null || fail "missing command: python3"

python3 - "$DOC_PATH" <<'PY'
from __future__ import annotations

import copy
import json
import sys
from pathlib import Path
from typing import Any

START = "<!-- central-metrics-backend:begin -->"
END = "<!-- central-metrics-backend:end -->"
REQUIRED_GROUPS = {
    "dispatch",
    "recovery",
    "review",
    "worker_capacity",
    "approval_authority",
    "validation",
    "compliance",
    "runtime_health",
}
REQUIRED_SLOS = {"dispatch_latency", "recovery_time", "review_age"}
SENSITIVE_TERMS = [
    "credential",
    "production",
    "infrastructure",
    "remote host",
    "docker",
    "kubernetes",
    "deployment",
    "control-plane",
    "explicit human approval",
]


class MetricsBackendError(Exception):
    pass


def reject(message: str) -> None:
    raise MetricsBackendError(message)


def extract_payload(text: str) -> dict[str, Any]:
    if not text.strip():
        reject("empty metrics backend design")
    if START not in text or END not in text:
        reject("missing central metrics backend block")
    block = text.split(START, 1)[1].split(END, 1)[0].strip()
    if block.startswith("```json"):
        block = block.removeprefix("```json").strip()
    if block.endswith("```"):
        block = block[: -len("```")].strip()
    try:
        payload = json.loads(block)
    except json.JSONDecodeError as exc:
        reject(f"malformed metrics data: {exc}")
    if not isinstance(payload, dict):
        reject("central metrics backend block must be an object")
    return payload


def require_nonempty(value: Any, label: str) -> None:
    if value in (None, "", [], {}):
        reject(f"missing {label}")


def require_list(value: Any, label: str, min_items: int = 1) -> list[Any]:
    if not isinstance(value, list) or len(value) < min_items:
        reject(f"missing {label}")
    return value


def validate_payload(payload: dict[str, Any]) -> None:
    permission = str(payload.get("permissionLevel", "")).lower()
    if "docs-only" not in permission:
        reject("missing permission level")

    boundary = str(payload.get("securityBoundary", "")).lower()
    require_nonempty(boundary, "security boundary")
    for term in SENSITIVE_TERMS:
        if term not in boundary:
            reject(f"security boundary missing {term}")
    if (
        "credential mutation authorized" in boundary
        or "production write authorized" in boundary
        or "infrastructure mutation authorized" in boundary
        or "remote host mutation authorized" in boundary
        or "docker mutation authorized" in boundary
        or "kubernetes mutation authorized" in boundary
        or "deployment authorized" in boundary
        or "control-plane mutation authorized" in boundary
    ):
        reject("unauthorized sensitive mutation wording")

    taxonomy = payload.get("metricTaxonomy")
    if not isinstance(taxonomy, dict):
        reject("missing metric taxonomy")
    groups = set(str(group) for group in require_list(taxonomy.get("groups"), "metric taxonomy groups", 4))
    missing_groups = REQUIRED_GROUPS - groups
    if missing_groups:
        reject("metric taxonomy missing " + ", ".join(sorted(missing_groups)))
    types = set(str(item) for item in require_list(taxonomy.get("types"), "metric taxonomy types", 3))
    if {"counter", "histogram", "gauge"} - types:
        reject("metric taxonomy must include counter, histogram, and gauge")
    if str(taxonomy.get("prefix", "")) != "dokkaebi_":
        reject("metric taxonomy prefix must be dokkaebi_")

    ingestion = payload.get("ingestionPath")
    if not isinstance(ingestion, dict):
        reject("missing ingestion path")
    for field in ["preferred", "localReplay"]:
        require_nonempty(ingestion.get(field), f"ingestion path {field}")
    correlation = " ".join(str(item).lower() for item in require_list(ingestion.get("correlationIds"), "ingestion correlation ids", 5))
    for term in ["project", "repository", "route_class", "environment", "approval_gate_status"]:
        if term not in correlation:
            reject(f"ingestion path missing correlation id {term}")

    storage = payload.get("storageBackendAssumptions")
    if not isinstance(storage, dict):
        reject("missing storage assumptions")
    for field in ["shortTerm", "longTerm", "dashboard", "alertEvaluation", "auditExport"]:
        require_nonempty(storage.get(field), f"storage assumptions {field}")

    retention = payload.get("retention")
    if not isinstance(retention, dict):
        reject("missing retention")
    for field in ["rawSamples", "sloRollups", "incidentSnapshots", "complianceSnapshots", "ownerDecision"]:
        require_nonempty(retention.get(field), f"retention {field}")

    labels = payload.get("labelCardinalityControls")
    if not isinstance(labels, dict):
        reject("missing label or cardinality controls")
    allowed = " ".join(str(item).lower() for item in require_list(labels.get("allowedLabels"), "allowed labels", 6))
    disallowed = " ".join(str(item).lower() for item in require_list(labels.get("disallowedLabels"), "disallowed labels", 6))
    for term in ["project", "repository", "route_class", "permission_level"]:
        if term not in allowed:
            reject(f"allowed labels missing {term}")
    for term in ["token", "cookie", "ssh key", "private machine path", "worker command text"]:
        if term not in disallowed:
            reject(f"disallowed labels missing {term}")
    require_nonempty(labels.get("reviewRule"), "label review rule")

    dashboard_alert = payload.get("dashboardAlertIntegration")
    if not isinstance(dashboard_alert, dict):
        reject("missing dashboard or alert integration")
    dashboards = " ".join(str(item).lower() for item in require_list(dashboard_alert.get("dashboards"), "dashboards", 5))
    alerts = " ".join(str(item).lower() for item in require_list(dashboard_alert.get("alerts"), "alerts", 5))
    for term in ["dispatch latency", "recovery time", "review age", "worker capacity"]:
        if term not in dashboards:
            reject(f"dashboard integration missing {term}")
    for term in ["dispatch latency", "recovery time", "worker route capacity", "validation failure"]:
        if term not in alerts:
            reject(f"alert integration missing {term}")
    require_nonempty(dashboard_alert.get("pagingStatus"), "paging status")

    slo = payload.get("sloLinkage")
    if not isinstance(slo, dict):
        reject("missing SLO linkage")
    missing_slos = REQUIRED_SLOS - set(slo.keys())
    if missing_slos:
        reject("SLO linkage missing " + ", ".join(sorted(missing_slos)))
    for slo_id in REQUIRED_SLOS:
        text = str(slo[slo_id]).lower()
        for term in ["metric", "query", "error-budget", "dashboard", "fallback"]:
            if term not in text:
                reject(f"SLO linkage {slo_id} missing {term}")

    ownership = payload.get("ownership")
    if not isinstance(ownership, dict):
        reject("missing ownership")
    for field in [
        "metricsBackendOwner",
        "sreOwner",
        "securityReviewer",
        "retentionOwner",
        "dashboardOwner",
        "alertOwner",
        "complianceReviewer",
    ]:
        require_nonempty(ownership.get(field), f"ownership {field}")

    require_list(payload.get("rolloutPhases"), "rollout phases", 5)
    verification = " ".join(str(item).lower() for item in require_list(payload.get("verificationSteps"), "verification steps", 6))
    for term in ["taxonomy", "ingestion", "retention", "cardinality", "dashboard", "security boundary"]:
        if term not in verification:
            reject(f"verification steps missing {term}")
    failure = " ".join(str(item).lower() for item in require_list(payload.get("failureHandling"), "failure handling", 6))
    for term in ["labels", "cardinality", "retention", "slo", "alert", "dashboard"]:
        if term not in failure:
            reject(f"failure handling missing {term}")
    require_list(payload.get("remainingOperationalGaps"), "remaining operational gaps", 3)


doc_text = Path(sys.argv[1]).read_text(encoding="utf-8")
baseline = extract_payload(doc_text)
validate_payload(baseline)


def expect_reject(name: str, candidate: str | dict[str, Any]) -> None:
    try:
        if isinstance(candidate, str):
            validate_payload(extract_payload(candidate))
        else:
            validate_payload(candidate)
    except MetricsBackendError:
        return
    reject(f"negative fixture unexpectedly passed: {name}")


expect_reject("empty design", "")
expect_reject(
    "malformed metrics data",
    START + "\n```json\n{\"version\": \n```\n" + END,
)

for field in [
    "metricTaxonomy",
    "ingestionPath",
    "storageBackendAssumptions",
    "retention",
    "labelCardinalityControls",
    "dashboardAlertIntegration",
    "sloLinkage",
    "ownership",
    "securityBoundary",
    "rolloutPhases",
    "verificationSteps",
    "failureHandling",
    "remainingOperationalGaps",
    "permissionLevel",
]:
    mutated = copy.deepcopy(baseline)
    if field in {"rolloutPhases", "verificationSteps", "failureHandling", "remainingOperationalGaps"}:
        mutated[field] = []
    else:
        mutated[field] = ""
    expect_reject(f"missing {field}", mutated)

mutated = copy.deepcopy(baseline)
mutated["securityBoundary"] = "credential mutation authorized and production write authorized"
expect_reject("unauthorized sensitive mutation wording", mutated)

print("PASS Dokkaebi central metrics backend validation passed")
PY
