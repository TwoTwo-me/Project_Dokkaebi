#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
fail() { printf 'FAIL %s\n' "$1" >&2; exit 1; }
require_text() {
  local path="$1" needle="$2"
  [[ -f "$path" ]] || fail "missing file: $path"
  grep -Fqi -- "$needle" "$path" || fail "missing text in $path: $needle"
}
DOC_PATH="${ON_CALL_ALERT_ROUTING_DRILL_PATH:-docs/operations/on-call-alert-routing-drill-2026-06-13.md}"
for term in "on-call alert routing dry-run drill" "selected GitHub evidence dry-run sink" "quiet-hours behavior" "dry-run delivery output" "approval-gate status" "cleanup" "residual risk" "next action" "does not configure or mutate"; do
  require_text "$DOC_PATH" "$term"
done
command -v python3 >/dev/null || fail "missing command: python3"
python3 - "$DOC_PATH" <<'PY'
import copy, json, re, sys
from datetime import date
from pathlib import Path
START = "<!-- on-call-alert-routing-drill:begin -->"
END = "<!-- on-call-alert-routing-drill:end -->"
REQ = ["version", "drillId", "date", "permissionLevel", "sourceBaselines", "selectedDryRunSink", "escalationRoster", "escalationWindows", "quietHoursDecision", "representativeAlerts", "routingDecisions", "deliveryOutput", "validationOutput", "approvalGateStatus", "cleanup", "residualRisk", "nextAction", "followUpIssueUrl"]
BASELINES = ["docs/operations/on-call-paging-alerting.md", "docs/operations/service-level-objectives.md", "docs/operations/central-metrics-replay-2026-06-13.md"]
ALERTS = {"dispatch_latency_burn", "recovery_time_burn", "stale_human_review", "worker_route_capacity", "validation_failure_spike", "approval_boundary_violation", "missing_compliance_evidence"}
ROLES = {"primary_on_call", "secondary_on_call", "incident_commander", "security_reviewer", "sre_owner", "compliance_reviewer", "tenant_owner", "project_owner"}
CMDS = ["validate-on-call-alert-routing-drill.sh", "validate-on-call-paging-alerting.sh", "validate-central-metrics-replay.sh", "validate-central-metrics-backend.sh", "validate-sre-operating-baseline.sh", "validate-readiness-criteria.sh", "validate-contract-docs.sh"]
HOME, USERS = "/" + "home" + "/", "/" + "users" + "/"
PRIVATE_PATH = re.compile(r"(?i)(" + re.escape(HOME) + "|" + re.escape(USERS) + r")[^\s`'\"]+")
DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
SECRET_TERMS = ["cookie=", "private" + "_key=", "sec" + "ret=", "to" + "ken=", "authorization: bearer", "-----begin " + "private key-----"]
SECRET_RX = [("github classic access key", re.compile(r"\bgh[pousr]_[A-Za-z0-9_]{16,}\b")), ("github fine-grained access key", re.compile(r"\bgithub_pat_[A-Za-z0-9_]{20,}\b")), ("cloud access key", re.compile(r"\bA[KS]IA[A-Z0-9]{16}\b"))]
UNSAFE_TERMS = ["live page sent", "paging service mutated", "alerting service mutated", "metrics service mutated", "credential used", "production write completed", "infrastructure mutated", "worker dispatch completed", "remote host changed", "docker container started", "kubernetes cluster mutated", "github project control-plane mutation completed"]
UNSAFE_RX = [
    ("live page delivery", re.compile(r"(?<!no\s)\blive\s+(page|paging|delivery)\s+((was|is)\s+)?(sent|delivered|configured|connected|executed|completed)\b", re.I)),
    ("live backend connection", re.compile(r"(?<!no\s)\blive\s+(paging|alerting|metrics)\s+backend\s+((was|is)\s+)?(connected|configured|created|updated|started)\b", re.I)),
    ("service mutation", re.compile(r"\b(alerting|paging|metrics)\s+service\s+((was|is)\s+)?(mutated|changed|updated|created|deleted|started|configured|connected)\b", re.I)),
    ("production mutation", re.compile(r"\bproduction\s+(deploy|deployment|release|rollback|write)\s+(succeeded|completed|executed|started|finished|ran)\b", re.I)),
    ("credential use", re.compile(r"(?<!no\s)\bcredentials?\s+((was|were|is|are)\s+)?used\b", re.I)),
    ("docker command", re.compile(r"\bdocker\s+(compose\s+)?(up|run|start|started|created|executed|completed)\b", re.I)),
    ("kubernetes command", re.compile(r"\bkubectl\s+(apply|create|delete|rollout|scale|set|patch)\b", re.I)),
    ("control-plane mutation", re.compile(r"\bgithub\s+project\s+(setting|settings|field|fields|schema|control-plane)\s+((was|is)\s+)?(changed|updated|mutated|created|deleted|completed)\b", re.I)),
    ("control-plane setting mutation", re.compile(r"\bgithub\s+project\s+control-plane\s+(setting|settings|field|fields|schema)\s+((was|is)\s+)?(changed|updated|mutated|created|deleted|completed)\b", re.I)),
]
BAD_VALIDATION = ("fail", "not run", "skipped", "placeholder")
class DrillError(Exception): pass
def reject(message): raise DrillError(message)
def joined(value):
    if isinstance(value, dict): return " ".join(f"{k} {joined(v)}" for k, v in value.items())
    if isinstance(value, list): return " ".join(joined(item) for item in value)
    return str(value)
def require_safe(value, label):
    text, lowered = joined(value), joined(value).lower()
    for term in SECRET_TERMS:
        if term in lowered: reject(f"secret-bearing {label} wording: {term}")
    for name, pattern in SECRET_RX:
        if pattern.search(text): reject(f"secret-like {label} pattern: {name}")
    for term in UNSAFE_TERMS:
        if term in lowered: reject(f"unsafe mutation {label} wording: {term}")
    for name, pattern in UNSAFE_RX:
        if pattern.search(text): reject(f"unsafe mutation {label} pattern: {name}")
    if PRIVATE_PATH.search(lowered): reject(f"private local path retained in {label}")
def extract(text):
    if not text.strip(): reject("empty alert routing drill content")
    if text.count(START) != 1 or text.count(END) != 1: reject("missing or duplicate alert routing drill block")
    start, end = text.index(START), text.index(END)
    if end < start: reject("alert routing drill block markers out of order")
    block = text[start + len(START):end].strip()
    if block.startswith("```json"): block = block.removeprefix("```json").strip()
    if block.endswith("```"): block = block[:-3].strip()
    try: payload = json.loads(block)
    except json.JSONDecodeError as exc: reject(f"malformed alert routing drill data: {exc}")
    if not isinstance(payload, dict): reject("alert routing drill block must be an object")
    return payload
def nonempty(value, label):
    if value in (None, "", [], {}): reject(f"missing {label}")
    return value
def require_list(value, label, minimum=1):
    if not isinstance(value, list) or len(value) < minimum: reject(f"missing {label}")
    return value
def text_list(value, label, minimum=1):
    values = [str(item).strip() for item in require_list(value, label, minimum)]
    if any(not item for item in values): reject(f"missing {label} item")
    return values
def fields(value, label, names):
    if not isinstance(value, dict) or not value: reject(f"missing {label}")
    for name in names: nonempty(value.get(name), f"{label} {name}")
    return value
def exact(items, expected, label):
    if len(items) != len(expected) or set(items) != set(expected): reject(f"{label} must match expected set")
def validate(payload):
    for field in REQ: nonempty(payload.get(field), field)
    if payload["version"] != 1: reject("version must be 1")
    if not DATE.fullmatch(str(payload["date"])): reject("date must be ISO yyyy-mm-dd")
    try: date.fromisoformat(str(payload["date"]))
    except ValueError: reject("date must be ISO yyyy-mm-dd")
    if payload["permissionLevel"] != "docs-only-local-dry-run": reject("permissionLevel must remain docs-only-local-dry-run")
    if payload["sourceBaselines"] != BASELINES: reject("source baselines must match on-call, SLO, and metrics replay")
    if payload["followUpIssueUrl"] != "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/82": reject("follow-up issue URL must point to issue 82")
    sink = fields(payload["selectedDryRunSink"], "selected dry-run sink", ["id", "backendStatus", "primarySink", "secondarySink", "deliveryMode", "evidenceSurface"])
    if sink["id"] != "github_evidence_dry_run" or sink["backendStatus"] != "not_live_paging" or sink["deliveryMode"] != "dry_run_only": reject("selected sink must remain GitHub evidence dry-run")
    roster = fields(payload["escalationRoster"], "escalation roster", ["rotationCadence", "timezone", "roles", "handoffEvidence", "backupCoverage"])
    exact(text_list(roster["roles"], "roster roles", len(ROLES)), ROLES, "roster roles")
    window_items = require_list(payload["escalationWindows"], "escalation windows", 4)
    if len(window_items) != 4: reject("escalation windows must match expected set")
    severities = {fields(item, "escalation window", ["severity", "window", "dryRunAction"])["severity"] for item in window_items}
    exact(list(severities), {"SEV0", "SEV1", "SEV2", "SEV3"}, "escalation windows")
    quiet = fields(payload["quietHoursDecision"], "quiet-hours decision", ["timezone", "sampleTime", "businessHours", "isQuietHours", "decision", "auditEvidence"])
    if quiet["isQuietHours"] is not True or "dry-run evidence" not in joined(quiet).lower(): reject("quiet-hours decision must record dry-run evidence behavior")
    alert_items = require_list(payload["representativeAlerts"], "representative alerts", len(ALERTS))
    if len(alert_items) != len(ALERTS): reject("representative alerts must match expected set")
    alerts = {fields(item, "representative alert", ["id", "severity", "metric", "input", "slo"])["id"]: item for item in alert_items}
    exact(list(alerts), ALERTS, "representative alerts")
    route_items = require_list(payload["routingDecisions"], "routing decisions", len(ALERTS))
    if len(route_items) != len(ALERTS): reject("routing decisions must match expected set")
    routes = {fields(item, "routing decision", ["alertId", "targetRole", "primarySink", "secondarySink", "quietHoursApplied", "deliveryMode", "decision"])["alertId"]: item for item in route_items}
    exact(list(routes), ALERTS, "routing decisions")
    for alert_id, item in routes.items():
        if item["deliveryMode"] != "dry_run_only" or item["quietHoursApplied"] is not True or "GitHub" not in str(item["primarySink"]): reject(f"routing decision {alert_id} must stay dry-run GitHub evidence")
        if item["targetRole"] not in ROLES: reject(f"routing decision {alert_id} target role must be in roster")
    delivery = " ".join(text_list(payload["deliveryOutput"], "delivery output", len(ALERTS))).lower()
    for alert_id in ALERTS:
        if alert_id not in delivery or "dry_run" not in delivery: reject(f"delivery output missing dry-run evidence for {alert_id}")
    validation_output = text_list(payload["validationOutput"], "validation output", len(CMDS))
    if len(validation_output) != len(CMDS): reject("validation output must match expected command set")
    for item in validation_output:
        if any(marker in item.lower() for marker in BAD_VALIDATION): reject("validation output contains non-passing marker")
    for command in CMDS:
        if f"bash scripts/{command}: PASS" not in validation_output: reject(f"validation output missing exact PASS for {command}")
    approval = str(payload["approvalGateStatus"]).lower()
    if "no live" not in approval or "remain not authorized" not in approval: reject("approval-gate status must preserve no-live boundary")
    cleanup = fields(payload["cleanup"], "cleanup", ["status", "receipt"])
    if cleanup["status"] != "complete": reject("cleanup must be complete")
    text_list(payload["residualRisk"], "residual risk", 3); nonempty(payload["nextAction"], "next action")
    require_safe(payload, "payload")
def mutate(payload, path, value):
    changed = copy.deepcopy(payload); target = changed
    for key in path[:-1]: target = target[key]
    target[path[-1]] = value; return changed
def expect_reject(name, candidate):
    try:
        if isinstance(candidate, str):
            require_safe(candidate, "document"); validate(extract(candidate))
        else: validate(candidate)
    except DrillError: return
    reject(f"negative fixture unexpectedly passed: {name}")
doc_text = Path(sys.argv[1]).read_text(encoding="utf-8")
baseline = extract(doc_text); require_safe(doc_text, "document"); validate(baseline)
expect_reject("empty content", "")
expect_reject("malformed data", START + "\n```json\n{\"version\": \n```\n" + END)
expect_reject("markers out of order", END + "\n" + START + "\n{}\n")
for field in REQ: expect_reject(f"missing {field}", mutate(baseline, (field,), [] if isinstance(baseline.get(field), list) else ""))
cases = [
    ("bad version", ("version",), 2), ("bad date", ("date",), "20260613"), ("bad permission", ("permissionLevel",), "live"), ("duplicate baseline", ("sourceBaselines",), BASELINES + [BASELINES[0]]), ("bad follow-up", ("followUpIssueUrl",), "https://github.com/"),
    ("bad sink", ("selectedDryRunSink", "backendStatus"), "live_paging"), ("bad delivery mode", ("selectedDryRunSink", "deliveryMode"), "live"), ("missing roster roles", ("escalationRoster", "roles"), ["primary_on_call"]), ("missing escalation", ("escalationWindows",), baseline["escalationWindows"][:1]), ("extra escalation", ("escalationWindows",), baseline["escalationWindows"] + [baseline["escalationWindows"][0]]), ("quiet false", ("quietHoursDecision", "isQuietHours"), False),
    ("missing alert", ("representativeAlerts",), baseline["representativeAlerts"][:-1]), ("extra alert", ("representativeAlerts",), baseline["representativeAlerts"] + [baseline["representativeAlerts"][0]]), ("missing route", ("routingDecisions",), baseline["routingDecisions"][:-1]), ("live route", ("routingDecisions", 0, "deliveryMode"), "live"), ("bad role", ("routingDecisions", 0, "targetRole"), "unknown"),
    ("missing delivery", ("deliveryOutput",), baseline["deliveryOutput"][:-1]), ("false validation", ("validationOutput",), ["NOT RUN bash scripts/validate-on-call-alert-routing-drill.sh: FAIL but PASS placeholder"] + baseline["validationOutput"][1:]), ("extra validation", ("validationOutput",), baseline["validationOutput"] + ["bash scripts/unauthorized-live-paging.sh: PASS"]), ("cleanup incomplete", ("cleanup", "status"), "pending"),
    ("live page claim", ("nextAction",), "Live page is sent through paging backend."), ("live paging backend", ("nextAction",), "Live paging backend is connected."), ("live alerting backend", ("nextAction",), "Live alerting backend is connected."), ("service claim", ("nextAction",), "Paging service is configured."), ("control-plane setting", ("nextAction",), "GitHub Project control-plane setting is changed."), ("credential use", ("nextAction",), "Credential is used for delivery."), ("private path", ("nextAction",), HOME + "private/pager"), ("secret pattern", ("nextAction",), "ASIA" + "A" * 16),
]
for name, path, value in cases: expect_reject(name, mutate(baseline, path, value))
expect_reject("private path outside payload", "Operator scratch: " + HOME + "private/pager\n" + doc_text)
expect_reject("secret outside payload", "Operator scratch: " + "".join(("gh", "p_", "A" * 20)) + "\n" + doc_text)
print("PASS Dokkaebi on-call alert routing drill validation passed")
PY
