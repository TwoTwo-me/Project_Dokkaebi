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

DOC_PATH="${ON_CALL_DELIVERY_SANDBOX_PATH:-docs/operations/on-call-delivery-sandbox-2026-06-14.md}"
RUNNER_PATH="scripts/run-on-call-delivery-sandbox.sh"

for term in \
  "on-call delivery sandbox gate" \
  "approved local sandbox delivery" \
  "SEV1" \
  "SEV2" \
  "alert input" \
  "routing decision" \
  "quiet-hours decision" \
  "delivery receipt" \
  "escalation receipt" \
  "approval-gate status" \
  "cleanup receipt" \
  "residual risk" \
  "next action" \
  "does not authorize"; do
  require_text "$DOC_PATH" "$term"
done

[[ -f "$RUNNER_PATH" ]] || fail "missing runner: $RUNNER_PATH"
command -v python3 >/dev/null || fail "missing command: python3"

python3 - "$DOC_PATH" "$RUNNER_PATH" <<'PY'
from __future__ import annotations

import copy
import hashlib
import json
import re
import subprocess
import sys
from datetime import date
from pathlib import Path
from typing import Any

START = "<!-- on-call-delivery-sandbox:begin -->"
END = "<!-- on-call-delivery-sandbox:end -->"
EXPECTED_ISSUE = "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/82"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
MANIFEST_FIELDS = [
    "sandboxBackend",
    "escalationRoster",
    "quietHoursDecision",
    "alertDeliveries",
    "deliveryReceipts",
    "escalationReceipts",
    "validationOutput",
    "approvalGateStatus",
    "cleanup",
    "residualRisk",
    "readinessDecision",
]
VALIDATION_OUTPUT = {
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
}
DENIED_TERMS = [
    "live alerting service",
    "live paging service",
    "metrics service",
    "credential",
    "infrastructure",
    "worker",
    "remote host",
    "docker",
    "kubernetes",
    "deployment",
    "production",
    "github project",
]
HOME_SEGMENT = "/" + "home" + "/"
USERS_SEGMENT = "/" + "users" + "/"
PRIVATE_PATH_RE = re.compile(r"(?i)(" + re.escape(HOME_SEGMENT) + "|" + re.escape(USERS_SEGMENT) + r")[^\s`'\"]+")
INTERNAL_LABELS = ["".join(parts) for parts in [("o", "mo"), ("o", "mx"), ("u", "lw")]]
INTERNAL_LABEL_RE = re.compile(r"\b(" + "|".join(INTERNAL_LABELS) + r")\b", re.IGNORECASE)
SECRET_TERMS = [
    "cookie=",
    "private" + "_key=",
    "sec" + "ret=",
    "to" + "ken=",
    "authorization: bearer",
    "-----begin private key-----",
]
SECRET_PATTERNS = [
    re.compile(r"\bgh[pousr]_[A-Za-z0-9_]{16,}\b"),
    re.compile(r"\bgithub_pat_[A-Za-z0-9_]{20,}\b"),
    re.compile(r"\bA[KS]IA[A-Z0-9]{16}\b"),
]
UNSAFE_PATTERNS = [
    ("live page delivery", r"(?<!no\s)\blive\s+(page|paging|delivery)\s+((was|is)\s+)?(sent|delivered|configured|connected|executed|completed)\b"),
    ("live backend connection", r"(?<!no\s)\blive\s+(paging|alerting|metrics)\s+backend\s+((was|is)\s+)?(connected|configured|created|updated|started)\b"),
    ("service mutation", r"\b(alerting|paging|metrics)\s+service\s+((was|is)\s+)?(mutated|changed|updated|created|deleted|started|configured|connected)\b"),
    ("credential use", r"(?<!no\s)\bcredentials?\s+((was|were|is|are)\s+)?used\b"),
    ("deployment claim", r"\b(deployment|production write|infrastructure change)\s+(was\s+)?(performed|completed|executed)\b"),
    ("container claim", r"\b(docker|kubernetes)\s+(resource|cluster|container|job)\s+(was\s+)?(created|started|mutated)\b"),
    ("project settings claim", r"\bgithub project\s+(field|settings|control-plane)\s+(was\s+)?(created|updated|mutated)\b"),
]
ALERTS = {"recovery_time_burn": "SEV1", "dispatch_latency_burn": "SEV2"}
REQUIRED_RECEIPT_TERMS = [
    "PASS SEV1",
    "PASS SEV2",
    "sandbox_primary_on_call_receipt",
    "sandbox_secondary_on_call_receipt",
    "sandbox_business_hours_queue_receipt",
]


class DeliverySandboxError(Exception):
    pass


def reject(message: str) -> None:
    raise DeliverySandboxError(message)


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
    for pattern in SECRET_PATTERNS:
        if pattern.search(text):
            reject(f"secret-like {label}")
    for name, pattern in UNSAFE_PATTERNS:
        if re.search(pattern, text, re.IGNORECASE):
            reject(f"unsafe mutation {label}: {name}")
    if PRIVATE_PATH_RE.search(text):
        reject(f"private local path retained in {label}")
    if INTERNAL_LABEL_RE.search(text):
        reject(f"internal execution label retained in {label}")


def extract(text: str) -> dict[str, Any]:
    if not text.strip():
        reject("empty on-call delivery sandbox content")
    if text.count(START) != 1 or text.count(END) != 1:
        reject("missing or duplicate on-call delivery sandbox block")
    block = text.split(START, 1)[1].split(END, 1)[0].strip()
    if block.startswith("```json"):
        block = block.removeprefix("```json").strip()
    if block.endswith("```"):
        block = block[:-3].strip()
    try:
        payload = json.loads(block)
    except json.JSONDecodeError as exc:
        reject(f"malformed on-call delivery sandbox data: {exc}")
    if not isinstance(payload, dict):
        reject("on-call delivery sandbox block must be an object")
    return payload


def nonempty(value: Any, label: str) -> Any:
    if value in (None, "", [], {}):
        reject(f"missing {label}")
    return value


def require_list(value: Any, label: str, minimum: int = 1) -> list[Any]:
    if not isinstance(value, list) or len(value) < minimum:
        reject(f"missing {label}")
    return value


def fields(value: Any, label: str, names: list[str]) -> dict[str, Any]:
    if not isinstance(value, dict):
        reject(f"missing {label}")
    for name in names:
        nonempty(value.get(name), f"{label} {name}")
    return value


def manifest_hash(payload: dict[str, Any]) -> str:
    manifest = {field: payload[field] for field in MANIFEST_FIELDS}
    return hashlib.sha256(json.dumps(manifest, sort_keys=True).encode()).hexdigest()


def parse_runner_output(output: str) -> dict[str, Any]:
    if "PASS Dokkaebi on-call delivery sandbox runner completed" not in output:
        reject("runner PASS line missing")
    start = output.find("{")
    if start < 0:
        reject("runner JSON missing")
    try:
        payload = json.loads(output[start:])
    except json.JSONDecodeError as exc:
        reject(f"runner JSON malformed: {exc}")
    if not isinstance(payload, dict):
        reject("runner JSON must be an object")
    return payload


def run_runner(path: Path) -> dict[str, Any]:
    completed = subprocess.run(["bash", str(path)], text=True, capture_output=True, check=False)
    if completed.returncode != 0:
        reject("runner failed: " + completed.stderr.strip())
    output = completed.stdout + completed.stderr
    require_safe(output, "runner output")
    payload = parse_runner_output(output)
    validate_payload(payload)
    return payload


def validate_alert_delivery(payload: dict[str, Any]) -> None:
    deliveries = require_list(payload.get("alertDeliveries"), "alert deliveries", len(ALERTS))
    if len(deliveries) != len(ALERTS):
        reject("alert deliveries must contain representative SEV1 and SEV2 alerts")
    by_id = {}
    for item in deliveries:
        delivery = fields(
            item,
            "alert delivery",
            ["alertId", "severity", "metric", "input", "slo", "routeDecision", "deliveryReceipt", "escalationReceipt"],
        )
        by_id[str(delivery["alertId"])] = delivery
    if set(by_id) != set(ALERTS):
        reject("alert deliveries must include recovery_time_burn and dispatch_latency_burn")
    for alert_id, severity in ALERTS.items():
        if by_id[alert_id]["severity"] != severity:
            reject(f"{alert_id} severity mismatch")
        text = joined(by_id[alert_id]).lower()
        for term in ["sandbox", "receipt"]:
            if term not in text:
                reject(f"{alert_id} missing {term}")

    receipt_text = joined(payload.get("deliveryReceipts", []))
    for term in REQUIRED_RECEIPT_TERMS:
        if term not in receipt_text:
            reject(f"delivery receipts missing {term}")
    escalation_text = joined(payload.get("escalationReceipts", [])).lower()
    for term in ["sev1", "sev2", "primary_on_call", "secondary_on_call", "business-hours"]:
        if term not in escalation_text:
            reject(f"escalation receipts missing {term}")


def validate_payload(payload: dict[str, Any]) -> None:
    required = [
        "version",
        "evidenceId",
        "date",
        "issueUrl",
        "permissionLevel",
        "approvalRecord",
        "sandboxBackend",
        "escalationRoster",
        "quietHoursDecision",
        "alertDeliveries",
        "deliveryReceipts",
        "escalationReceipts",
        "validationOutput",
        "approvalGateStatus",
        "cleanup",
        "residualRisk",
        "readinessDecision",
        "nextAction",
        "manifestSha256",
        "runner",
    ]
    for field in required:
        nonempty(payload.get(field), field)
    if payload["version"] != 1:
        reject("version must be 1")
    try:
        date.fromisoformat(str(payload["date"]))
    except ValueError:
        reject("date must be ISO yyyy-mm-dd")
    if payload["issueUrl"] != EXPECTED_ISSUE:
        reject("issue URL must point to issue 82")
    if payload["permissionLevel"] != "approved-local-sandbox-on-call-delivery":
        reject("permission level mismatch")

    approval = fields(payload["approvalRecord"], "approval record", ["approvedTarget", "scope", "approvedSurfaces", "deniedTargets", "evidence"])
    approval_text = joined(approval).lower()
    for term in ["local", "sandbox", "issue #82", "backend substitute", "notification sinks", "quiet-hours"]:
        if term not in approval_text:
            reject(f"approval record missing {term}")
    denied = " ".join(str(item).lower() for item in require_list(approval["deniedTargets"], "denied targets", 10))
    for term in DENIED_TERMS:
        if term not in denied:
            reject(f"approval denied targets missing {term}")

    backend = fields(payload["sandboxBackend"], "sandbox backend", ["target", "backend", "notificationSinks", "mutationBoundary"])
    if "local sandbox" not in str(backend["target"]).lower():
        reject("sandbox backend target must be local sandbox")
    if len(require_list(backend["notificationSinks"], "notification sinks", 4)) < 4:
        reject("notification sinks must include representative sandbox sinks")
    if "no live alerting service" not in str(backend["mutationBoundary"]).lower():
        reject("sandbox backend mutation boundary must deny live alerting service")

    roster = fields(payload["escalationRoster"], "escalation roster", ["rotationCadence", "timezone", "roles", "handoffEvidence", "backupCoverage"])
    roles = set(str(role) for role in require_list(roster["roles"], "roster roles", 5))
    for role in ["primary_on_call", "secondary_on_call", "incident_commander", "sre_owner", "service_owner"]:
        if role not in roles:
            reject(f"escalation roster missing {role}")

    quiet = fields(payload["quietHoursDecision"], "quiet-hours decision", ["timezone", "sampleTime", "businessHours", "isQuietHours", "sev1Behavior", "sev2Behavior", "auditEvidence"])
    if quiet["isQuietHours"] is not True:
        reject("quiet-hours decision must exercise quiet-hours path")
    quiet_text = joined(quiet).lower()
    for term in ["sev1", "sev2", "sandbox", "audit"]:
        if term not in quiet_text:
            reject(f"quiet-hours decision missing {term}")

    validate_alert_delivery(payload)

    validation = [str(item) for item in require_list(payload["validationOutput"], "validation output", len(VALIDATION_OUTPUT))]
    missing_output = VALIDATION_OUTPUT - set(validation)
    if missing_output:
        reject("validation output missing exact PASS commands: " + ", ".join(sorted(missing_output)))

    approval_status = str(payload["approvalGateStatus"]).lower()
    for term in ["approved local sandbox", "no live alerting service", "live paging service", "metrics service", "not authorized"]:
        if term not in approval_status:
            reject(f"approval-gate status missing {term}")
    cleanup = fields(payload["cleanup"], "cleanup", ["status", "receipt"])
    if cleanup["status"] != "complete":
        reject("cleanup status must be complete")
    if "no resources remain" not in str(cleanup["receipt"]).lower():
        reject("cleanup receipt must state no resources remain")
    residual = " ".join(str(item).lower() for item in require_list(payload["residualRisk"], "residual risk", 3))
    for term in ["live paging backend", "production notification", "production roster"]:
        if term not in residual:
            reject(f"residual risk missing {term}")
    readiness = fields(payload["readinessDecision"], "readiness decision", ["logging_observability", "on_call_paging_alerting", "basis"])
    if readiness["logging_observability"] != 100 or readiness["on_call_paging_alerting"] != 100:
        reject("readiness decision must score observability and on-call alerting at 100")
    if "human approval" not in str(payload["nextAction"]).lower():
        reject("next action must retain Human approval boundary")
    runner = fields(payload["runner"], "runner", ["path", "command", "result"])
    if runner["path"] != "scripts/run-on-call-delivery-sandbox.sh":
        reject("runner path mismatch")
    if runner["command"] != "bash scripts/run-on-call-delivery-sandbox.sh":
        reject("runner command mismatch")
    if "PASS Dokkaebi on-call delivery sandbox runner completed" not in str(runner["result"]):
        reject("runner output missing pass result")
    if not SHA256_RE.fullmatch(str(payload["manifestSha256"])):
        reject("manifest hash must be sha256")
    if payload["manifestSha256"] != manifest_hash(payload):
        reject("manifest hash mismatch")
    require_safe(payload, "payload")


def mutate(payload: dict[str, Any], path: tuple[Any, ...], value: Any, *, refresh: bool = True) -> dict[str, Any]:
    changed = copy.deepcopy(payload)
    target: Any = changed
    for key in path[:-1]:
        target = target[key]
    target[path[-1]] = value
    if refresh and "manifestSha256" in changed and all(field in changed for field in MANIFEST_FIELDS):
        changed["manifestSha256"] = manifest_hash(changed)
    return changed


def expect_reject(name: str, candidate: str | dict[str, Any]) -> None:
    try:
        if isinstance(candidate, str):
            validate_payload(extract(candidate))
        else:
            validate_payload(candidate)
    except DeliverySandboxError:
        return
    reject(f"negative fixture unexpectedly passed: {name}")


doc_text = Path(sys.argv[1]).read_text(encoding="utf-8")
require_safe(doc_text, "document")
baseline = extract(doc_text)
validate_payload(baseline)
runner_payload = run_runner(Path(sys.argv[2]))
if baseline["manifestSha256"] != runner_payload["manifestSha256"]:
    reject("document manifest hash must match runner manifest hash")

expect_reject("empty content", "")
expect_reject("malformed data", START + "\n```json\n{\"version\": \n```\n" + END)
for field in ["approvalRecord", "sandboxBackend", "escalationRoster", "quietHoursDecision", "alertDeliveries", "deliveryReceipts", "escalationReceipts", "cleanup", "residualRisk"]:
    expect_reject(f"missing {field}", mutate(baseline, (field,), ""))
expect_reject("wrong issue", mutate(baseline, ("issueUrl",), "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/1"))
expect_reject("bad permission", mutate(baseline, ("permissionLevel",), "docs-only"))
expect_reject("missing approved surfaces", mutate(baseline, ("approvalRecord", "approvedSurfaces"), []))
expect_reject("missing denied live service", mutate(baseline, ("approvalRecord", "deniedTargets"), ["production"]))
expect_reject("live backend target", mutate(baseline, ("sandboxBackend", "target"), "live paging backend"))
expect_reject("missing sinks", mutate(baseline, ("sandboxBackend", "notificationSinks"), []))
expect_reject("missing roster", mutate(baseline, ("escalationRoster", "roles"), ["primary_on_call"]))
expect_reject("not quiet-hours", mutate(baseline, ("quietHoursDecision", "isQuietHours"), False))
expect_reject("missing SEV1", mutate(baseline, ("alertDeliveries",), [baseline["alertDeliveries"][1]]))
expect_reject("missing SEV2", mutate(baseline, ("alertDeliveries",), [baseline["alertDeliveries"][0]]))
expect_reject("wrong severity", mutate(baseline, ("alertDeliveries", 0, "severity"), "SEV3"))
expect_reject("missing delivery receipt", mutate(baseline, ("deliveryReceipts",), baseline["deliveryReceipts"][:1]))
expect_reject("missing escalation receipt", mutate(baseline, ("escalationReceipts",), []))
expect_reject("not passing validation", mutate(baseline, ("validationOutput",), ["bash scripts/run-on-call-delivery-sandbox.sh: FAIL"]))
expect_reject("cleanup incomplete", mutate(baseline, ("cleanup", "status"), "pending"))
expect_reject("not ready", mutate(baseline, ("readinessDecision", "on_call_paging_alerting"), 99))
expect_reject("live page claim", mutate(baseline, ("nextAction",), "live page was sent"))
expect_reject("live backend claim", mutate(baseline, ("nextAction",), "live paging backend was connected"))
expect_reject("service mutation", mutate(baseline, ("nextAction",), "paging service was configured"))
expect_reject("credential use", mutate(baseline, ("nextAction",), "credential was used for delivery"))
expect_reject("private path", mutate(baseline, ("cleanup", "receipt"), HOME_SEGMENT + "private/pager"))
expect_reject("secret-like evidence", mutate(baseline, ("nextAction",), "gh" + "p_" + "A" * 20))
bad_hash = mutate(baseline, ("manifestSha256",), "0" * 64, refresh=False)
expect_reject("mismatched manifest hash", bad_hash)

print("PASS Dokkaebi on-call delivery sandbox validation passed")
PY
