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

DOC_PATH="${ON_CALL_PAGING_ALERTING_PATH:-docs/operations/on-call-paging-alerting.md}"

for term in \
  "alert taxonomy" \
  "severity mapping" \
  "escalation roster shape" \
  "paging backend decision" \
  "quiet-hours behavior" \
  "notification routing" \
  "test evidence shape" \
  "SLO linkage" \
  "metrics linkage" \
  "ownership" \
  "failure handling" \
  "approval boundary" \
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

START = "<!-- on-call-paging-alerting:begin -->"
END = "<!-- on-call-paging-alerting:end -->"
REQUIRED_ALERTS = {
    "dispatch_latency_burn",
    "recovery_time_burn",
    "stale_human_review",
    "worker_route_capacity",
    "validation_failure_spike",
    "approval_boundary_violation",
    "missing_compliance_evidence",
}
REQUIRED_SEVERITIES = {"SEV0", "SEV1", "SEV2", "SEV3"}
REQUIRED_ROLES = {
    "primary_on_call",
    "secondary_on_call",
    "incident_commander",
    "security_reviewer",
    "sre_owner",
    "compliance_reviewer",
    "tenant_owner",
    "project_owner",
}
REQUIRED_SLOS = {"dispatch_latency", "recovery_time", "review_age"}
REQUIRED_METRICS = {
    "dispatch",
    "recovery",
    "review",
    "worker_capacity",
    "validation",
    "approval_authority",
    "compliance",
}
REQUIRED_TOP_LEVEL = [
    "permissionLevel",
    "approvalBoundary",
    "alertTaxonomy",
    "severityMapping",
    "escalationRosterShape",
    "pagingBackendDecision",
    "quietHoursBehavior",
    "notificationRouting",
    "testEvidenceShape",
    "sloLinkage",
    "metricsLinkage",
    "ownership",
    "failureHandling",
    "remainingOperationalGaps",
]
SENSITIVE_TERMS = [
    "credential",
    "production",
    "infrastructure",
    "worker",
    "remote host",
    "docker",
    "kubernetes",
    "deployment",
    "alerting service",
    "control-plane",
    "explicit human approval",
]
UNAUTHORIZED_PHRASES = [
    "credential mutation authorized",
    "production write authorized",
    "infrastructure mutation authorized",
    "worker privilege expansion authorized",
    "remote host mutation authorized",
    "docker mutation authorized",
    "kubernetes mutation authorized",
    "deployment authorized",
    "alerting service mutation authorized",
    "control-plane mutation authorized",
]


class AlertingBaselineError(Exception):
    pass


def reject(message: str) -> None:
    raise AlertingBaselineError(message)


def extract_payload(text: str) -> dict[str, Any]:
    if not text.strip():
        reject("empty on-call paging baseline")
    if START not in text or END not in text:
        reject("missing on-call paging alerting block")
    block = text.split(START, 1)[1].split(END, 1)[0].strip()
    if block.startswith("```json"):
        block = block.removeprefix("```json").strip()
    if block.endswith("```"):
        block = block[: -len("```")].strip()
    try:
        payload = json.loads(block)
    except json.JSONDecodeError as exc:
        reject(f"malformed alerting data: {exc}")
    if not isinstance(payload, dict):
        reject("on-call paging alerting block must be an object")
    return payload


def require_nonempty(value: Any, label: str) -> None:
    if value in (None, "", [], {}):
        reject(f"missing {label}")


def require_list(value: Any, label: str, min_items: int = 1) -> list[Any]:
    if not isinstance(value, list) or len(value) < min_items:
        reject(f"missing {label}")
    return value


def require_dict(value: Any, label: str) -> dict[str, Any]:
    if not isinstance(value, dict) or not value:
        reject(f"missing {label}")
    return value


def text_join(value: Any) -> str:
    if isinstance(value, dict):
        return " ".join(f"{key} {text_join(val)}" for key, val in value.items())
    if isinstance(value, list):
        return " ".join(text_join(item) for item in value)
    return str(value)


def require_terms(value: Any, required: list[str], label: str) -> None:
    text = text_join(value).lower()
    for term in required:
        if term not in text:
            reject(f"{label} missing {term}")


def validate_payload(payload: dict[str, Any]) -> None:
    for field in REQUIRED_TOP_LEVEL:
        require_nonempty(payload.get(field), field)

    permission = str(payload.get("permissionLevel", "")).lower()
    if "docs-only" not in permission:
        reject("missing permission level")

    boundary = str(payload.get("approvalBoundary", "")).lower()
    for phrase in UNAUTHORIZED_PHRASES:
        if phrase in boundary:
            reject("unauthorized sensitive mutation wording")
    for term in SENSITIVE_TERMS:
        if term not in boundary:
            reject(f"approval boundary missing {term}")

    taxonomy = require_list(payload.get("alertTaxonomy"), "alert taxonomy", len(REQUIRED_ALERTS))
    taxonomy_by_id = {str(item.get("id")): item for item in taxonomy if isinstance(item, dict)}
    missing_alerts = REQUIRED_ALERTS - set(taxonomy_by_id)
    if missing_alerts:
        reject("alert taxonomy missing " + ", ".join(sorted(missing_alerts)))
    for alert_id, item in taxonomy_by_id.items():
        for field in ["severity", "signal", "operatorAction"]:
            require_nonempty(item.get(field), f"alert taxonomy {alert_id} {field}")

    severities = require_dict(payload.get("severityMapping"), "severity mapping")
    missing_severities = REQUIRED_SEVERITIES - set(severities)
    if missing_severities:
        reject("severity mapping missing " + ", ".join(sorted(missing_severities)))
    for severity in REQUIRED_SEVERITIES:
        mapping = require_dict(severities.get(severity), f"severity mapping {severity}")
        for field in ["pageBehavior", "responseTarget", "escalationPath"]:
            require_nonempty(mapping.get(field), f"severity mapping {severity} {field}")

    roster = require_dict(payload.get("escalationRosterShape"), "escalation roster shape")
    roles = set(str(role) for role in require_list(roster.get("roles"), "escalation roster roles", len(REQUIRED_ROLES)))
    missing_roles = REQUIRED_ROLES - roles
    if missing_roles:
        reject("escalation roster shape missing " + ", ".join(sorted(missing_roles)))
    for field in ["rotationCadence", "timezone", "handoffEvidence", "backupCoverage"]:
        require_nonempty(roster.get(field), f"escalation roster shape {field}")

    backend = require_dict(payload.get("pagingBackendDecision"), "paging backend decision")
    if backend.get("status") != "deferred_until_human_approval":
        reject("paging backend decision must be deferred until Human approval")
    require_terms(
        backend,
        ["github", "not production paging", "backend", "roster", "quiet-hours", "alert routing test plan"],
        "paging backend decision",
    )

    quiet = require_dict(payload.get("quietHoursBehavior"), "quiet-hours behavior")
    for field in ["timezone", "criticalBypass", "sev1Behavior", "nonCriticalHandling", "tenantOverrides", "auditEvidence"]:
        require_nonempty(quiet.get(field), f"quiet-hours behavior {field}")

    routing = " ".join(str(item).lower() for item in require_list(payload.get("notificationRouting"), "notification routing", 3))
    for term in ["severity", "alert class", "source slo", "metric", "tenant", "primary sink", "secondary sink", "quiet-hours", "delivery output", "cleanup receipt"]:
        if term not in routing:
            reject(f"notification routing missing {term}")

    evidence = " ".join(str(item).lower() for item in require_list(payload.get("testEvidenceShape"), "test evidence shape", 8))
    for term in ["alert input", "metric evaluation", "severity", "slo linkage", "metrics linkage", "quiet-hours", "delivery output", "dry-run output", "approval-gate", "cleanup receipt", "residual risk"]:
        if term not in evidence:
            reject(f"test evidence shape missing {term}")

    slo = require_dict(payload.get("sloLinkage"), "SLO linkage")
    missing_slos = REQUIRED_SLOS - set(slo)
    if missing_slos:
        reject("SLO linkage missing " + ", ".join(sorted(missing_slos)))
    for slo_id in REQUIRED_SLOS:
        require_terms(slo[slo_id], ["slo", "error-budget", "metrics query", "fallback github evidence"], f"SLO linkage {slo_id}")

    metrics = require_dict(payload.get("metricsLinkage"), "metrics linkage")
    missing_metrics = REQUIRED_METRICS - set(metrics)
    if missing_metrics:
        reject("metrics linkage missing " + ", ".join(sorted(missing_metrics)))

    ownership = require_dict(payload.get("ownership"), "ownership")
    for field in [
        "onCallOwner",
        "alertOwner",
        "sreOwner",
        "metricsOwner",
        "securityReviewer",
        "complianceReviewer",
        "tenantOwner",
        "projectOwner",
    ]:
        require_nonempty(ownership.get(field), f"ownership {field}")

    failure = " ".join(str(item).lower() for item in require_list(payload.get("failureHandling"), "failure handling", 8))
    for term in ["severity mapping", "owner mapping", "paging backend", "escalation roster", "quiet-hours", "notification routing", "cleanup evidence", "slo linkage", "metrics linkage", "explicit human approval"]:
        if term not in failure:
            reject(f"failure handling missing {term}")

    gaps = " ".join(str(item).lower() for item in require_list(payload.get("remainingOperationalGaps"), "remaining operational gaps", 4))
    for term in ["paging backend", "escalation roster", "quiet-hours", "alert routing", "cleanup"]:
        if term not in gaps:
            reject(f"remaining operational gaps missing {term}")


doc_text = Path(sys.argv[1]).read_text(encoding="utf-8")
baseline = extract_payload(doc_text)
validate_payload(baseline)


def expect_reject(name: str, candidate: str | dict[str, Any]) -> None:
    try:
        if isinstance(candidate, str):
            validate_payload(extract_payload(candidate))
        else:
            validate_payload(candidate)
    except AlertingBaselineError:
        return
    reject(f"negative fixture unexpectedly passed: {name}")


expect_reject("empty baseline", "")
expect_reject(
    "malformed alerting data",
    START + "\n```json\n{\"version\": \n```\n" + END,
)

for field in REQUIRED_TOP_LEVEL:
    mutated = copy.deepcopy(baseline)
    if field in {"alertTaxonomy", "notificationRouting", "testEvidenceShape", "failureHandling", "remainingOperationalGaps"}:
        mutated[field] = []
    else:
        mutated[field] = ""
    expect_reject(f"missing {field}", mutated)

mutated = copy.deepcopy(baseline)
mutated["approvalBoundary"] = "credential mutation authorized and alerting service mutation authorized"
expect_reject("unauthorized sensitive mutation wording", mutated)

mutated = copy.deepcopy(baseline)
mutated["severityMapping"].pop("SEV1")
expect_reject("missing SEV1 severity mapping", mutated)

mutated = copy.deepcopy(baseline)
mutated["escalationRosterShape"]["roles"] = ["primary_on_call"]
expect_reject("missing escalation roster roles", mutated)

mutated = copy.deepcopy(baseline)
mutated["pagingBackendDecision"]["status"] = "implemented"
expect_reject("implemented backend without approval", mutated)

print("PASS Dokkaebi on-call paging alerting validation passed")
PY
