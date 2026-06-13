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
DOC_PATH="${CENTRAL_METRICS_REPLAY_PATH:-docs/operations/central-metrics-replay-2026-06-13.md}"
for term in "local central metrics replay" "representative metrics" "ingestion output" "storage/query output" "parsed dashboard view" "alert-rule evaluation" "retention/cardinality checks" "approval-gate status" "cleanup" "residual risk" "next action" "does not authorize"; do
  require_text "$DOC_PATH" "$term"
done
command -v python3 >/dev/null || fail "missing command: python3"
python3 - "$DOC_PATH" <<'PY'
import copy, json, re, sys
from datetime import date
from pathlib import Path
START = "<!-- central-metrics-replay:begin -->"
END = "<!-- central-metrics-replay:end -->"
REQ = ["version", "replayId", "date", "permissionLevel", "sourceDesigns", "representativeMetrics", "ingestionOutput", "storageQueryOutput", "dashboardView", "alertEvaluation", "retentionCardinalityChecks", "validationOutput", "approvalGateStatus", "cleanup", "residualRisk", "nextAction", "followUpIssueUrl"]
DESIGNS = ["docs/operations/central-metrics-backend.md", "docs/operations/service-level-objectives.md", "docs/operations/on-call-paging-alerting.md"]
GROUPS = ["dispatch", "recovery", "review_age", "worker_capacity", "approval", "validation", "compliance", "runtime_health", "audit_export"]
PANELS = {"dispatch latency", "recovery time", "review age", "worker capacity", "validation rate", "approval blocks", "compliance evidence completeness", "immutable audit-export verification"}
ALERTS = {"dispatch latency burn": "412s below 900s", "recovery time burn": "890s below 1800s", "stale human review age": "reminder", "worker route capacity unavailable": "2 available", "validation failure spike": "0 failures", "approval-boundary violation": "blocked", "missing compliance evidence": "audit export verified"}
QUERIES = {"dispatch_latency": ("dokkaebi_dispatch_latency_seconds", "412", "900"), "recovery_time": ("dokkaebi_recovery_time_seconds", "890", "1800"), "review_age": ("dokkaebi_review_age_seconds", "172800", "reminder"), "availability_posture": ("dokkaebi_runtime_poll_success_total", "3", "control-loop"), "audit_export": ("dokkaebi_audit_export_verified_total", "1", "evidence")}
ALLOWED_LABELS = {"project", "repository", "environment", "route_class", "provider", "adapter", "issue_number", "permission_level", "approval_gate_status", "validator_name", "failure_class", "control_class", "evidence_package_id"}
DISALLOWED_LABELS = {"raw issue or pr body", "raw prompt content", "token", "cookie", "ssh key", "auth file path", "private machine path", "unbounded exception message", "worker command text", "github project control-plane payload"}
CMDS = ["validate-central-metrics-replay.sh", "validate-central-metrics-backend.sh", "validate-service-level-objectives.sh", "validate-on-call-paging-alerting.sh", "validate-readiness-criteria.sh", "validate-contract-docs.sh"]
HOME, USERS = "/" + "home" + "/", "/" + "users" + "/"
PRIVATE_PATH = re.compile(r"(?i)(" + re.escape(HOME) + "|" + re.escape(USERS) + r")[^\s`'\"]+")
DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
SECRET_TERMS = ["cookie=", "private" + "_key=", "sec" + "ret=", "to" + "ken=", "authorization: bearer", "-----begin " + "private key-----"]
SECRET_PATTERNS = [("github classic access key", r"\bgh[pousr]_[A-Za-z0-9_]{16,}\b"), ("github fine-grained access key", r"\bgithub_pat_[A-Za-z0-9_]{20,}\b"), ("cloud access key", r"\bA[KS]IA[A-Z0-9]{16}\b")]
UNSAFE_TERMS = ["credential used", "deployment executed", "docker container started", "github project control-plane mutation completed", "infrastructure mutated", "kubernetes cluster mutated", "production write completed", "remote host changed", "worker dispatch completed", "metrics service mutated", "alerting service mutated"]
UNSAFE_PATTERNS = [
    ("production deploy claim", r"(\bproduction\s+(deploy|deployment|release|rollback|write)\s+(succeeded|completed|executed|started|finished|ran)\b|\b(deploy|deployment|release|rollback)\s+(succeeded|completed|executed|started|finished|ran)\s+in\s+production\b)"),
    ("docker live command claim", r"\bdocker\s+(compose\s+)?(up|run|start|started|created|executed|completed)\b"), ("kubernetes live command claim", r"\bkubectl\s+(apply|create|delete|rollout|scale|set|patch)\b"),
    ("service mutation claim", r"\b(metrics|alerting)\s+service\s+((was|is)\s+)?(mutated|changed|updated|created|deleted|started|configured)\b"), ("live backend claim", r"(?<!no\s)\blive[-\s]?backend\s+((was|is)\s+)?(started|created|configured|connected|mutated|updated|deployed)\b"), ("remote host mutation claim", r"\bremote\s+host\s+((was|is)\s+)?(changed|updated|mutated|configured|restarted)\b"),
    ("worker dispatch claim", r"\bworker\s+dispatch\s+(was\s+)?(completed|started|executed|launched)\b"), ("project setting mutation claim", r"\bgithub\s+project\s+(setting|settings|field|fields|schema|control-plane)\s+(was\s+)?(changed|updated|mutated|created|deleted|completed)\b"),
    ("credential use claim", r"(?<!no\s)\bcredentials?\s+((was|were|is|are)\s+)?used\b"), ("credential authorization claim", r"\bcredentials?\s+(are|is)?\s*authorized\b"), ("deployment authorization claim", r"\bdeploy(ment)?\s+(are|is)?\s*authorized\b"), ("service authorization claim", r"\b(metrics|alerting)\s+service\s+(are|is)?\s*authorized\b"), ("deployment proceed claim", r"\bdeploy(ment)?\s+(can|may|will)\s+proceed\b"),
]
SECRET_RX = [(name, re.compile(pattern)) for name, pattern in SECRET_PATTERNS]
UNSAFE_RX = [(name, re.compile(pattern, re.IGNORECASE)) for name, pattern in UNSAFE_PATTERNS]
BAD_VALIDATION = ("fail", "not run", "skipped", "placeholder")
class ReplayError(Exception):
    pass
def reject(message):
    raise ReplayError(message)
def joined(value):
    if isinstance(value, dict):
        return " ".join(f"{key} {joined(val)}" for key, val in value.items())
    if isinstance(value, list):
        return " ".join(joined(item) for item in value)
    return str(value)
def require_safe(value, label):
    text = joined(value)
    lowered = text.lower()
    for term in SECRET_TERMS:
        if term in lowered:
            reject(f"secret-bearing {label} wording: {term}")
    for name, pattern in SECRET_RX:
        if pattern.search(text):
            reject(f"secret-like {label} pattern: {name}")
    for term in UNSAFE_TERMS:
        if term in lowered:
            reject(f"unsafe mutation {label} wording: {term}")
    for name, pattern in UNSAFE_RX:
        if pattern.search(text):
            reject(f"unsafe mutation {label} pattern: {name}")
    if PRIVATE_PATH.search(lowered):
        reject(f"private local path retained in {label}")
def extract(text):
    if not text.strip():
        reject("empty central metrics replay content")
    if text.count(START) != 1 or text.count(END) != 1:
        reject("missing or duplicate central metrics replay block")
    start, end = text.index(START), text.index(END)
    if end < start:
        reject("central metrics replay block markers out of order")
    block = text[start + len(START):end].strip()
    if block.startswith("```json"):
        block = block.removeprefix("```json").strip()
    if block.endswith("```"):
        block = block[:-3].strip()
    try:
        payload = json.loads(block)
    except json.JSONDecodeError as exc:
        reject(f"malformed central metrics replay data: {exc}")
    if not isinstance(payload, dict):
        reject("central metrics replay block must be an object")
    return payload
def nonempty(value, label):
    if value in (None, "", [], {}):
        reject(f"missing {label}")
    return value
def require_list(value, label, minimum=1):
    if not isinstance(value, list) or len(value) < minimum:
        reject(f"missing {label}")
    return value
def text_list(value, label, minimum=1):
    values = [str(item).strip() for item in require_list(value, label, minimum)]
    if any(not item for item in values):
        reject(f"missing {label} item")
    return values
def fields(value, label, names):
    if not isinstance(value, dict) or not value:
        reject(f"missing {label}")
    for name in names:
        nonempty(value.get(name), f"{label} {name}")
    return value
def require_exact(items, expected, label):
    if len(items) != len(expected) or set(items) != set(expected):
        reject(f"{label} must match expected set")
def validate(payload):
    for field in REQ:
        nonempty(payload.get(field), field)
    if payload["version"] != 1:
        reject("version must be 1")
    if not DATE.fullmatch(str(payload["date"])):
        reject("date must be ISO yyyy-mm-dd")
    try:
        date.fromisoformat(str(payload["date"]))
    except ValueError:
        reject("date must be ISO yyyy-mm-dd")
    if payload["permissionLevel"] != "docs-only-local-replay":
        reject("permissionLevel must remain docs-only-local-replay")
    if payload["sourceDesigns"] != DESIGNS:
        reject("source designs must match central metrics, SLO, and on-call baselines")
    if payload["followUpIssueUrl"] != "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/80":
        reject("follow-up issue URL must point to issue 80")
    metrics = require_list(payload["representativeMetrics"], "representative metrics", len(GROUPS))
    groups = []
    metric_names = []
    for metric in metrics:
        item = fields(metric, "representative metric", ["group", "metricName", "type", "labels", "sample", "evidence"])
        groups.append(str(item["group"]))
        name = str(item["metricName"])
        metric_names.append(name)
        if not name.startswith("dokkaebi_"):
            reject("metric name must use dokkaebi_ prefix")
        if item["type"] not in {"counter", "histogram", "gauge"}:
            reject("metric type must be counter, histogram, or gauge")
        labels = [label.lower() for label in text_list(item["labels"], "metric labels", 3)]
        if any(label not in ALLOWED_LABELS for label in labels):
            reject("metric labels must be bounded allowed labels")
        if not isinstance(item["sample"], (int, float)) or item["sample"] < 0:
            reject("metric sample must be non-negative number")
    require_exact(groups, GROUPS, "representative metric groups")
    ingestion = fields(payload["ingestionOutput"], "ingestion output", ["format", "parser", "acceptedSamples", "rejectedSamples", "expositionLines"])
    if ingestion["acceptedSamples"] != len(GROUPS) or ingestion["rejectedSamples"] != 0:
        reject("ingestion output sample counts invalid")
    exposition_lines = text_list(ingestion["expositionLines"], "exposition lines", len(GROUPS))
    exposition = " ".join(exposition_lines)
    for line in exposition_lines:
        match = re.search(r"\{([^}]*)\}", line); keys = [] if match is None else [part.split("=", 1)[0].strip().lower() for part in match.group(1).split(",") if part.strip()]
        if not keys or any(key not in ALLOWED_LABELS for key in keys): reject("exposition labels must be bounded allowed labels")
    for name in metric_names:
        if name not in exposition:
            reject(f"ingestion output missing metric {name}")
    storage = fields(payload["storageQueryOutput"], "storage/query output", ["backend", "queries"])
    queries = {fields(q, "query output", ["name", "expression", "result", "slo"])["name"]: q for q in require_list(storage["queries"], "queries", len(QUERIES))}
    require_exact(list(queries), set(QUERIES), "query names")
    for name, (metric, result, slo) in QUERIES.items():
        q = queries[name]
        text = f"{q['expression']} {q['result']} {q['slo']}".lower()
        if metric not in text or result.lower() not in text or slo.lower() not in text:
            reject(f"query output {name} is not bound to expected metric, result, and SLO")
    dashboard = fields(payload["dashboardView"], "parsed dashboard view", ["surface", "panels"])
    require_exact(text_list(dashboard["panels"], "dashboard panels", len(PANELS)), PANELS, "dashboard panels")
    alerts = fields(payload["alertEvaluation"], "alert-rule evaluation", ["mode", "rules"])
    rules = {str(fields(rule, "alert rule", ["name", "status", "evidence"])["name"]).lower(): rule for rule in require_list(alerts["rules"], "alert rules", len(ALERTS))}
    require_exact(list(rules), set(ALERTS), "alert rules")
    for name, evidence in ALERTS.items():
        rule = rules[name]
        if rule["status"] not in {"not_firing", "evaluated"} or evidence not in str(rule["evidence"]).lower():
            reject(f"alert rule {name} is not bound to expected evidence")
    checks = fields(payload["retentionCardinalityChecks"], "retention/cardinality checks", ["retention", "allowedLabels", "disallowedLabels", "cardinalityLimit", "redaction"])
    require_exact([item.lower() for item in text_list(checks["allowedLabels"], "allowed labels", len(ALLOWED_LABELS))], ALLOWED_LABELS, "allowed labels")
    require_exact([item.lower() for item in text_list(checks["disallowedLabels"], "disallowed labels", len(DISALLOWED_LABELS))], DISALLOWED_LABELS, "disallowed labels")
    cardinality = str(checks["cardinalityLimit"]).lower()
    if "unbounded" in cardinality or "accepted" in cardinality:
        reject("cardinality limit must fail closed on unbounded labels")
    validation_output = text_list(payload["validationOutput"], "validation output", len(CMDS))
    for item in validation_output:
        if any(marker in item.lower() for marker in BAD_VALIDATION):
            reject("validation output contains non-passing marker")
    for command in CMDS:
        if f"bash scripts/{command}: PASS" not in validation_output:
            reject(f"validation output missing exact PASS for {command}")
    approval = str(payload["approvalGateStatus"]).lower()
    if "no live approval-gated mutation reached" not in approval or "remain not authorized" not in approval:
        reject("approval-gate status must preserve no-live boundary")
    if re.search(r"\b(can|may|will)\s+proceed\b", approval) or "authorized and" in approval or re.search(r"\b(deploy(ment)?|metrics service|alerting service|credentials?)\s+(is|are)?\s*authorized\b", approval):
        reject("approval-gate status must not authorize later action")
    cleanup = fields(payload["cleanup"], "cleanup", ["status", "receipt"])
    if cleanup["status"] != "complete":
        reject("cleanup must be complete")
    text_list(payload["residualRisk"], "residual risk", 3)
    nonempty(payload["nextAction"], "next action")
    require_safe(payload, "payload")
def validate_doc(text):
    require_safe(text, "document")
    payload = extract(text)
    validate(payload)
    return payload
def mutate(payload, path, value):
    changed = copy.deepcopy(payload)
    target = changed
    for key in path[:-1]:
        target = target[key]
    target[path[-1]] = value
    return changed
def expect_reject(name, candidate):
    try:
        validate_doc(candidate) if isinstance(candidate, str) else validate(candidate)
    except ReplayError:
        return
    reject(f"negative fixture unexpectedly passed: {name}")
def run():
    doc_text = Path(sys.argv[1]).read_text(encoding="utf-8")
    baseline = validate_doc(doc_text)
    expect_reject("empty content", "")
    expect_reject("malformed data", START + "\n```json\n{\"version\": \n```\n" + END)
    expect_reject("markers out of order", END + "\n" + START + "\n{}\n")
    for field in REQ:
        expect_reject(f"missing {field}", mutate(baseline, (field,), [] if isinstance(baseline.get(field), list) else ""))
    cases = [
        ("bad version", ("version",), 2), ("bad date", ("date",), "20260613"), ("bad permission", ("permissionLevel",), "sandbox"), ("duplicate source", ("sourceDesigns",), DESIGNS + [DESIGNS[0]]), ("bad follow-up", ("followUpIssueUrl",), "https://github.com/"),
        ("missing group", ("representativeMetrics",), baseline["representativeMetrics"][:-1]), ("extra group", ("representativeMetrics",), baseline["representativeMetrics"] + [baseline["representativeMetrics"][0]]), ("bad metric prefix", ("representativeMetrics", 0, "metricName"), "dispatch_latency_seconds"), ("bad metric label", ("representativeMetrics", 0, "labels"), ["project", "raw prompt content", "environment"]), ("bad sample", ("representativeMetrics", 0, "sample"), -1),
        ("bad ingestion count", ("ingestionOutput", "acceptedSamples"), 1), ("bad rejected count", ("ingestionOutput", "rejectedSamples"), 1), ("missing ingestion metric", ("ingestionOutput", "expositionLines"), baseline["ingestionOutput"]["expositionLines"][:-1]), ("bad ingestion label", ("ingestionOutput", "expositionLines", 0), "dokkaebi_dispatch_latency_seconds_bucket{project=\"sandbox\",raw_prompt_content=\"body\"} 412"), ("missing query", ("storageQueryOutput", "queries"), baseline["storageQueryOutput"]["queries"][:-1]), ("bad query expression", ("storageQueryOutput", "queries", 0, "expression"), "not_a_metric_query()"), ("bad query result", ("storageQueryOutput", "queries", 0, "result"), "fabricated-success"),
        ("missing dashboard", ("dashboardView", "panels"), ["dispatch latency"]), ("missing alert", ("alertEvaluation", "rules"), baseline["alertEvaluation"]["rules"][:-1]), ("fabricated alert", ("alertEvaluation", "rules", 0, "evidence"), "fabricated-success"), ("missing allowed label", ("retentionCardinalityChecks", "allowedLabels"), ["project"]), ("missing disallowed label", ("retentionCardinalityChecks", "disallowedLabels"), ["token"]), ("bad cardinality limit", ("retentionCardinalityChecks", "cardinalityLimit"), "unbounded arbitrary strings accepted"), ("false validation", ("validationOutput",), ["NOT RUN bash scripts/validate-central-metrics-replay.sh: FAIL but PASS placeholder"] + baseline["validationOutput"][1:]),
        ("cleanup incomplete", ("cleanup", "status"), "pending"), ("unsafe deploy", ("nextAction",), "Production deployment succeeded."), ("unsafe service", ("nextAction",), "Metrics service was configured."), ("unsafe live backend", ("nextAction",), "Live backend is started for metrics."), ("unsafe credential use", ("nextAction",), "Credential is used to query a metrics backend."), ("approval authorizes service", ("approvalGateStatus",), "No live approval-gated mutation reached; metrics service is authorized after replay; remain not authorized for credentials."), ("private path", ("nextAction",), HOME + "private/metrics"), ("secret pattern", ("nextAction",), "ASIA" + "A" * 16),
    ]
    for name, path, value in cases:
        expect_reject(name, mutate(baseline, path, value))
    expect_reject("private path outside payload", "Operator scratch: " + HOME + "private/metrics\n" + doc_text)
    expect_reject("secret outside payload", "Operator scratch: " + "".join(("gh", "p_", "A" * 20)) + "\n" + doc_text)
try:
    run()
except ReplayError as exc:
    print(f"FAIL {exc}", file=sys.stderr)
    sys.exit(1)
print("PASS Dokkaebi central metrics replay validation passed")
PY
