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

DOC_PATH="${CENTRAL_METRICS_SANDBOX_BACKEND_PATH:-docs/operations/central-metrics-sandbox-backend-2026-06-14.md}"
RUNNER_PATH="scripts/run-central-metrics-sandbox-backend.sh"

for term in \
  "central metrics sandbox backend" \
  "ephemeral SQLite" \
  "ingestion output" \
  "storage/query output" \
  "dashboard rows" \
  "alert-rule evaluation" \
  "retention/cardinality checks" \
  "approval-gate status" \
  "cleanup receipt" \
  "does not authorize"; do
  require_text "$DOC_PATH" "$term"
done

[[ -f "$RUNNER_PATH" ]] || fail "missing runner: $RUNNER_PATH"
command -v python3 >/dev/null || fail "missing command: python3"

python3 - "$DOC_PATH" "$RUNNER_PATH" <<'PY'
from __future__ import annotations

import copy
import json
import re
import subprocess
import sys
from datetime import date
from pathlib import Path
from typing import Any

START = "<!-- central-metrics-sandbox-backend:begin -->"
END = "<!-- central-metrics-sandbox-backend:end -->"
GROUPS = [
    "dispatch",
    "recovery",
    "review_age",
    "worker_capacity",
    "approval",
    "validation",
    "compliance",
    "runtime_health",
    "audit_export",
]
PANELS = {
    "dispatch latency",
    "recovery time",
    "review age",
    "worker capacity",
    "validation rate",
    "approval blocks",
    "compliance evidence completeness",
    "immutable audit-export verification",
}
ALERTS = {
    "dispatch latency burn",
    "recovery time burn",
    "stale human review age",
    "worker route capacity unavailable",
    "validation failure spike",
    "approval-boundary violation",
    "missing compliance evidence",
}
QUERIES = {
    "dispatch_latency": ("dokkaebi_dispatch_latency_seconds", "412", "900"),
    "recovery_time": ("dokkaebi_recovery_time_seconds", "890", "1800"),
    "review_age": ("dokkaebi_review_age_seconds", "172800", "reminder"),
    "availability_posture": ("dokkaebi_runtime_poll_success_total", "3", "control-loop"),
    "audit_export": ("dokkaebi_audit_export_verified_total", "1", "evidence"),
}
VALIDATION_COMMANDS = {
    "validate-central-metrics-sandbox-backend.sh",
    "run-central-metrics-sandbox-backend.sh",
    "validate-central-metrics-backend.sh",
    "validate-central-metrics-replay.sh",
    "validate-service-level-objectives.sh",
    "validate-on-call-paging-alerting.sh",
    "validate-readiness-criteria.sh",
    "validate-contract-docs.sh",
}
EXPECTED_MANIFEST_SHA256 = "3109cd32c268a2b37f584e6283558940a5ebf07390d2764f1f618073f0995451"
HOME_SEGMENT = "/" + "home" + "/"
USERS_SEGMENT = "/" + "Users" + "/"
PRIVATE_PATH_RE = re.compile(r"(" + re.escape(HOME_SEGMENT) + "|" + re.escape(USERS_SEGMENT) + r")[^\s`'\"]+", re.IGNORECASE)
SECRET_TERMS = ["cookie=", "private_key=", "secret=", "token=", "authorization: bearer"]
SECRET_PATTERNS = [
    ("github classic access key", r"\bgh[pousr]_[A-Za-z0-9_]{16,}\b"),
    ("github fine-grained access key", r"\bgithub_pat_[A-Za-z0-9_]{20,}\b"),
    ("cloud access key", r"\bA[KS]IA[A-Z0-9]{16}\b"),
]
UNSAFE_PATTERNS = [
    ("external service mutation", r"\b(metrics|alerting)\s+service\s+(was\s+)?(created|configured|mutated|started|updated)\b"),
    ("live backend claim", r"(?<!no\s)\blive[-\s]?backend\s+(was\s+)?(connected|started|configured|deployed)\b"),
    ("credential use claim", r"(?<!no\s)\bcredentials?\s+(was|were|is|are)?\s*used\b"),
    ("deployment claim", r"\b(deployment|production write|docker|kubernetes|remote host)\s+(was\s+)?(executed|mutated|started|configured)\b"),
    ("project settings mutation", r"\bgithub project\s+(field|settings|control-plane)\s+(was\s+)?(created|updated|mutated)\b"),
]
BAD_VALIDATION = ("fail", "not run", "skipped", "placeholder")


class SandboxMetricsError(Exception):
    pass


def reject(message: str) -> None:
    raise SandboxMetricsError(message)


def joined(value: Any) -> str:
    if isinstance(value, dict):
        return " ".join(f"{key} {joined(val)}" for key, val in value.items())
    if isinstance(value, list):
        return " ".join(joined(item) for item in value)
    return str(value)


def require_safe(value: Any, label: str) -> None:
    text = joined(value)
    lowered = text.lower()
    for term in SECRET_TERMS:
        if term in lowered:
            reject(f"secret-bearing {label}: {term}")
    for name, pattern in SECRET_PATTERNS:
        if re.search(pattern, text):
            reject(f"secret-like {label}: {name}")
    for name, pattern in UNSAFE_PATTERNS:
        if re.search(pattern, text, re.IGNORECASE):
            reject(f"unsafe mutation {label}: {name}")
    if PRIVATE_PATH_RE.search(text):
        reject(f"private local path retained in {label}")


def extract(text: str) -> dict[str, Any]:
    if not text.strip():
        reject("empty central metrics sandbox backend content")
    if text.count(START) != 1 or text.count(END) != 1:
        reject("missing or duplicate central metrics sandbox backend block")
    block = text.split(START, 1)[1].split(END, 1)[0].strip()
    if block.startswith("```json"):
        block = block.removeprefix("```json").strip()
    if block.endswith("```"):
        block = block[:-3].strip()
    try:
        payload = json.loads(block)
    except json.JSONDecodeError as exc:
        reject(f"malformed central metrics sandbox backend data: {exc}")
    if not isinstance(payload, dict):
        reject("central metrics sandbox backend block must be an object")
    return payload


def nonempty(value: Any, label: str) -> Any:
    if value in (None, "", [], {}):
        reject(f"missing {label}")
    return value


def require_list(value: Any, label: str, minimum: int = 1) -> list[Any]:
    if not isinstance(value, list) or len(value) < minimum:
        reject(f"missing {label}")
    return value


def text_list(value: Any, label: str, minimum: int = 1) -> list[str]:
    values = [str(item).strip() for item in require_list(value, label, minimum)]
    if any(not item for item in values):
        reject(f"missing {label} item")
    return values


def fields(value: Any, label: str, names: list[str]) -> dict[str, Any]:
    if not isinstance(value, dict):
        reject(f"missing {label}")
    for name in names:
        nonempty(value.get(name), f"{label} {name}")
    return value


def require_exact(items: list[str], expected: set[str] | list[str], label: str) -> None:
    expected_set = set(expected)
    if len(items) != len(expected_set) or set(items) != expected_set:
        reject(f"{label} must match expected set")


def validate_runner_payload(payload: dict[str, Any]) -> None:
    if payload.get("version") != 1:
        reject("runner version must be 1")
    if payload.get("backend") != "ephemeral sqlite local sandbox backend":
        reject("runner backend mismatch")
    if payload.get("acceptedSamples") != len(GROUPS) or payload.get("rejectedSamples") != 0:
        reject("runner sample counts invalid")
    require_exact([str(item) for item in payload.get("storedGroups", [])], GROUPS, "runner stored groups")
    if not re.fullmatch(r"[0-9a-f]{64}", str(payload.get("manifestSha256", ""))):
        reject("runner manifest hash missing")
    cleanup = fields(payload.get("cleanup"), "runner cleanup", ["status", "receipt"])
    if cleanup.get("status") != "complete":
        reject("runner cleanup must be complete")
    require_safe(payload, "runner payload")


def validate_doc_payload(payload: dict[str, Any]) -> None:
    required = [
        "version",
        "evidenceId",
        "date",
        "issueUrl",
        "permissionLevel",
        "approvalRecord",
        "backendSelection",
        "runner",
        "representativeMetrics",
        "ingestionOutput",
        "storageQueryOutput",
        "dashboardRows",
        "alertEvaluation",
        "retentionCardinalityChecks",
        "auditExportEvidence",
        "validationOutput",
        "approvalGateStatus",
        "cleanup",
        "residualRisk",
        "nextAction",
    ]
    for field in required:
        nonempty(payload.get(field), field)
    if payload["version"] != 1:
        reject("version must be 1")
    try:
        date.fromisoformat(str(payload["date"]))
    except ValueError:
        reject("date must be ISO yyyy-mm-dd")
    if payload["issueUrl"] != "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/80":
        reject("issue URL must point to issue 80")
    if payload["permissionLevel"] != "approved-local-sandbox-backend":
        reject("permission level must be approved-local-sandbox-backend")

    approval = fields(payload["approvalRecord"], "approval record", ["approvedTarget", "scope", "deniedTargets", "evidence"])
    if "local" not in str(approval["approvedTarget"]).lower() or "sandbox" not in str(approval["approvedTarget"]).lower():
        reject("approval target must name local sandbox")
    denied = " ".join(text_list(approval["deniedTargets"], "denied targets", 8)).lower()
    for term in ["credential", "remote host", "docker", "kubernetes", "production", "deployment", "github project"]:
        if term not in denied:
            reject(f"approval denied targets missing {term}")

    backend = fields(payload["backendSelection"], "backend selection", ["type", "owner", "storage", "externalServices", "cleanup"])
    if "sqlite" not in str(backend["type"]).lower() or "none" not in str(backend["externalServices"]).lower():
        reject("backend selection must be ephemeral SQLite with no external services")
    runner = fields(payload["runner"], "runner", ["path", "result", "outputContract"])
    if runner["path"] != "scripts/run-central-metrics-sandbox-backend.sh":
        reject("runner path mismatch")
    if "PASS" not in str(runner["result"]):
        reject("runner result must pass")

    metrics = require_list(payload["representativeMetrics"], "representative metrics", len(GROUPS))
    groups = []
    for metric in metrics:
        item = fields(metric, "representative metric", ["group", "metricName", "type", "labels", "sample", "evidence"])
        groups.append(str(item["group"]))
        if not str(item["metricName"]).startswith("dokkaebi_"):
            reject("metric name must use dokkaebi_ prefix")
        if item["type"] not in {"counter", "histogram", "gauge"}:
            reject("metric type must be counter, histogram, or gauge")
        if not isinstance(item["sample"], (int, float)) or item["sample"] < 0:
            reject("metric sample must be non-negative")
    require_exact(groups, GROUPS, "representative metric groups")

    ingestion = fields(payload["ingestionOutput"], "ingestion output", ["backend", "acceptedSamples", "rejectedSamples", "table", "manifestSha256"])
    if ingestion["acceptedSamples"] != len(GROUPS) or ingestion["rejectedSamples"] != 0:
        reject("ingestion sample counts invalid")
    if "sqlite" not in str(ingestion["backend"]).lower():
        reject("ingestion backend must name SQLite")
    if ingestion["manifestSha256"] != EXPECTED_MANIFEST_SHA256:
        reject("ingestion manifest hash missing")

    storage = fields(payload["storageQueryOutput"], "storage/query output", ["backend", "queries"])
    queries = {str(fields(q, "query output", ["name", "expression", "result", "slo", "status"])["name"]): q for q in require_list(storage["queries"], "queries", len(QUERIES))}
    require_exact(list(queries), set(QUERIES), "query names")
    for name, (metric, result, slo) in QUERIES.items():
        text = f"{queries[name]['expression']} {queries[name]['result']} {queries[name]['slo']}".lower()
        if metric not in text or result.lower() not in text or slo.lower() not in text:
            reject(f"query {name} is not bound to expected metric, result, and SLO")

    dashboard_rows = require_list(payload["dashboardRows"], "dashboard rows", len(PANELS))
    require_exact([str(fields(row, "dashboard row", ["panel", "query", "status"])["panel"]).lower() for row in dashboard_rows], PANELS, "dashboard panels")
    alert_rows = require_list(payload["alertEvaluation"], "alert evaluation", len(ALERTS))
    require_exact([str(fields(row, "alert row", ["name", "status", "evidence"])["name"]).lower() for row in alert_rows], ALERTS, "alert rules")

    checks = fields(payload["retentionCardinalityChecks"], "retention/cardinality checks", ["retention", "allowedLabels", "disallowedLabels", "cardinalityLimit", "redaction"])
    allowed = " ".join(text_list(checks["allowedLabels"], "allowed labels", 8)).lower()
    for term in ["project", "repository", "environment", "route_class", "permission_level", "approval_gate_status"]:
        if term not in allowed:
            reject(f"allowed labels missing {term}")
    disallowed = " ".join(text_list(checks["disallowedLabels"], "disallowed labels", 8)).lower()
    for term in ["raw prompt", "token", "cookie", "ssh key", "private machine path", "worker command text"]:
        if term not in disallowed:
            reject(f"disallowed labels missing {term}")
    cardinality = str(checks["cardinalityLimit"]).lower()
    if "unbounded" in cardinality and "fail" not in cardinality:
        reject("unbounded label policy must fail closed")

    audit = fields(payload["auditExportEvidence"], "audit export evidence", ["manifestSha256", "source", "status"])
    if audit["manifestSha256"] != EXPECTED_MANIFEST_SHA256:
        reject("audit export manifest hash missing")
    validation = text_list(payload["validationOutput"], "validation output", len(VALIDATION_COMMANDS))
    for item in validation:
        if any(marker in item.lower() for marker in BAD_VALIDATION):
            reject("validation output contains non-passing marker")
    for command in VALIDATION_COMMANDS:
        if f"bash scripts/{command}: PASS" not in validation:
            reject(f"validation output missing exact PASS for {command}")

    approval_status = str(payload["approvalGateStatus"]).lower()
    if "no live approval-gated mutation reached" not in approval_status or "remain not authorized" not in approval_status:
        reject("approval-gate status must preserve no-live boundary")
    cleanup = fields(payload["cleanup"], "cleanup", ["status", "receipt"])
    if cleanup["status"] != "complete":
        reject("cleanup must be complete")
    residual = " ".join(text_list(payload["residualRisk"], "residual risk", 2)).lower()
    if "approved sandbox metrics backend ingestion is not captured" in residual:
        reject("stale docs-only replay residual risk retained")
    if "issue #82" not in str(payload["nextAction"]).lower():
        reject("next action must point to issue #82")
    require_safe(payload, "document payload")


def parse_runner_output(output: str) -> dict[str, Any]:
    if "PASS Dokkaebi central metrics sandbox backend runner completed" not in output:
        reject("runner PASS line missing")
    start = output.find("{")
    if start < 0:
        reject("runner JSON missing")
    try:
        payload = json.loads(output[start:])
    except json.JSONDecodeError as exc:
        reject(f"runner JSON malformed: {exc}")
    if not isinstance(payload, dict):
        reject("runner JSON must be object")
    return payload


def run_runner(path: Path) -> dict[str, Any]:
    completed = subprocess.run(["bash", str(path)], text=True, capture_output=True, check=False)
    if completed.returncode != 0:
        reject("runner failed: " + completed.stderr.strip())
    output = completed.stdout + completed.stderr
    require_safe(output, "runner output")
    payload = parse_runner_output(output)
    validate_runner_payload(payload)
    return payload


def mutate(payload: dict[str, Any], path: tuple[Any, ...], value: Any) -> dict[str, Any]:
    changed = copy.deepcopy(payload)
    target: Any = changed
    for key in path[:-1]:
        target = target[key]
    target[path[-1]] = value
    return changed


def expect_reject(name: str, candidate: str | dict[str, Any]) -> None:
    try:
        if isinstance(candidate, str):
            validate_doc_payload(extract(candidate))
        else:
            validate_doc_payload(candidate)
    except SandboxMetricsError:
        return
    reject(f"negative fixture unexpectedly passed: {name}")


doc_text = Path(sys.argv[1]).read_text(encoding="utf-8")
require_safe(doc_text, "document")
baseline = extract(doc_text)
validate_doc_payload(baseline)
runner_payload = run_runner(Path(sys.argv[2]))
doc_hash = baseline["ingestionOutput"]["manifestSha256"]
if doc_hash != runner_payload["manifestSha256"]:
    reject("document manifest hash must match runner manifest hash")

expect_reject("empty content", "")
expect_reject("malformed data", START + "\n```json\n{\"version\": \n```\n" + END)
for field in [
    "approvalRecord",
    "backendSelection",
    "runner",
    "representativeMetrics",
    "ingestionOutput",
    "storageQueryOutput",
    "dashboardRows",
    "alertEvaluation",
    "retentionCardinalityChecks",
    "approvalGateStatus",
    "cleanup",
    "residualRisk",
    "validationOutput",
]:
    expect_reject(f"missing {field}", mutate(baseline, (field,), [] if isinstance(baseline.get(field), list) else ""))
expect_reject("bad permission", mutate(baseline, ("permissionLevel",), "docs-only-local-replay"))
expect_reject("missing backend owner", mutate(baseline, ("backendSelection", "owner"), ""))
expect_reject("unsafe service mutation", mutate(baseline, ("nextAction",), "Metrics service was configured."))
expect_reject("live backend claim", mutate(baseline, ("backendSelection", "storage"), "Live backend was connected."))
expect_reject("private path", mutate(baseline, ("cleanup", "receipt"), HOME_SEGMENT + "private/metrics"))
expect_reject("secret-like evidence", mutate(baseline, ("nextAction",), "ghp_" + "A" * 20))
expect_reject("stale replay gap", mutate(baseline, ("residualRisk",), ["Approved sandbox metrics backend ingestion is not captured."]))
expect_reject("unbounded labels accepted", mutate(baseline, ("retentionCardinalityChecks", "cardinalityLimit"), "unbounded arbitrary labels accepted"))
expect_reject("bad manifest", mutate(baseline, ("ingestionOutput", "manifestSha256"), "0" * 64))

print("PASS Dokkaebi central metrics sandbox backend validation passed")
PY
