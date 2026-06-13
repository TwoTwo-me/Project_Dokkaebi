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

DOC_PATH="${INCIDENT_RESPONSE_RUNBOOK_PATH:-docs/operations/incident-response-runbook-2026-06-13.md}"

for term in "incident response runbook" "tabletop drill" "severity model" "incident commander" "detection" "communication surface" "mitigation sequence" "rollback or recovery decision" "alert routing decision" "postmortem template" "evidence retention" "approval-gate status" "cleanup" "residual risk" "next action" "does not authorize"; do
  require_text "$DOC_PATH" "$term"
done

command -v python3 >/dev/null || fail "missing command: python3"
python3 - "$DOC_PATH" <<'PY'
import copy
import json
import re
import sys
from datetime import date
from pathlib import Path

START = "<!-- incident-response:begin -->"
END = "<!-- incident-response:end -->"
REQ = ["version", "runbookId", "date", "permissionLevel", "sourceBaselines", "scenario", "severityModel", "incidentCommander", "detection", "communicationSurface", "mitigationSequence", "rollbackOrRecoveryDecision", "alertRoutingDecision", "postmortemTemplate", "evidenceRetention", "validationOutput", "approvalGateStatus", "cleanup", "residualRisk", "nextAction", "followUpIssueUrl"]
SEVS = {"SEV0", "SEV1", "SEV2", "SEV3"}
CMDS = ["validate-incident-response-runbook.sh", "validate-sre-operating-baseline.sh", "validate-on-call-paging-alerting.sh", "validate-readiness-criteria.sh", "validate-contract-docs.sh"]
BASELINES = ["docs/operations/sre-operating-baseline.md", "docs/operations/on-call-paging-alerting.md"]
COMMUNICATION_TERMS = {"timeline", "severity", "commander", "mitigation", "validation", "postmortem", "closeout"}
POSTMORTEM_FIELDS = ["timeline", "impact", "root cause", "contributing factors", "mitigation and recovery", "validation commands", "evidence links", "follow-up owner", "residual risk"]
POSTMORTEM_EVENTS = ["detection", "severity declaration", "commander assignment", "mitigation decision", "recovery decision", "validation", "closeout"]
BAD_VALIDATION = ("fail", "not run", "skipped", "placeholder")
HOME, USERS = "/" + "home" + "/", "/" + "users" + "/"
PRIVATE_PATH = re.compile(r"(?i)(" + re.escape(HOME) + "|" + re.escape(USERS) + r")[^\s`'\"]+")
DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
PASS = re.compile(r"\bPASS\b")
SECRET_TERMS = ["cookie=", "private" + "_key=", "sec" + "ret=", "to" + "ken=", "authorization: bearer", "-----begin " + "private key-----"]
SECRET_PATTERNS = [("github classic access key", r"\bgh[pousr]_[A-Za-z0-9_]{16,}\b"), ("github fine-grained access key", r"\bgithub_pat_[A-Za-z0-9_]{20,}\b"), ("cloud access key", r"\bA[KS]IA[A-Z0-9]{16}\b")]
UNSAFE_TERMS = ["credential used", "deployment executed", "docker container started", "github project control-plane mutation completed", "infrastructure mutated", "kubernetes cluster mutated", "production write completed", "remote host changed", "worker dispatch completed"]
UNSAFE_PATTERNS = [
    ("production deploy claim", r"(\bproduction\s+(deploy|deployment|release|rollback|write)\s+(succeeded|completed|executed|started|finished|ran)\b|\b(deploy|deployment|release|rollback)\s+(succeeded|completed|executed|started|finished|ran)\s+in\s+production\b)"),
    ("docker live command claim", r"\bdocker\s+(compose\s+)?(up|run|start|started|created|executed|completed)\b"), ("kubernetes live command claim", r"\bkubectl\s+(apply|create|delete|rollout|scale|set|patch)\b"),
    ("kubernetes mutation claim", r"\bkubernetes\s+(cluster|namespace|job|deployment)\s+(mutated|changed|updated|created|deleted|scaled)\b"), ("remote host mutation claim", r"\bremote\s+host\s+(was\s+)?(changed|updated|mutated|configured|restarted)\b"),
    ("worker dispatch claim", r"\bworker\s+dispatch\s+(was\s+)?(completed|started|executed|launched)\b"), ("project setting mutation claim", r"\bgithub\s+project\s+(setting|settings|field|fields|schema|control-plane)\s+(was\s+)?(changed|updated|mutated|created|deleted|completed)\b"),
    ("credential mutation claim", r"\bcredential\s+(used|issued|granted|exported|rotated)\b"), ("infrastructure mutation claim", r"\binfrastructure\s+(mutated|changed|updated|created|deleted)\b"),
    ("deployment proceed claim", r"\bdeploy(ment)?\s+(can|may|will)\s+proceed\b"), ("credential authorization claim", r"\bcredentials?\s+(are|is)?\s*authorized\b"), ("deployment authorization claim", r"\bdeploy(ment)?\s+(are|is)?\s*authorized\b"),
]
SECRET_RX = [(name, re.compile(pattern)) for name, pattern in SECRET_PATTERNS]
UNSAFE_RX = [(name, re.compile(pattern, re.IGNORECASE)) for name, pattern in UNSAFE_PATTERNS]
class IncidentError(Exception):
    pass

def reject(message):
    raise IncidentError(message)

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
        reject("empty incident response content")
    if text.count(START) != 1 or text.count(END) != 1:
        reject("missing or duplicate incident response block")
    start, end = text.index(START), text.index(END)
    if end < start:
        reject("incident response block markers out of order")
    block = text[start + len(START):end].strip()
    if block.startswith("```json"):
        block = block.removeprefix("```json").strip()
    if block.endswith("```"):
        block = block[:-3].strip()
    try:
        payload = json.loads(block)
    except json.JSONDecodeError as exc:
        reject(f"malformed incident response data: {exc}")
    if not isinstance(payload, dict):
        reject("incident response block must be an object")
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
    if payload["permissionLevel"] != "docs-only-tabletop":
        reject("permissionLevel must remain docs-only-tabletop")
    if payload["followUpIssueUrl"] != "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/78":
        reject("follow-up issue URL must point to issue 78")
    if text_list(payload["sourceBaselines"], "source baselines", 2) != BASELINES:
        reject("source baselines must include SRE and on-call baselines")
    scenario = fields(payload["scenario"], "scenario", ["severity", "trigger", "scope", "customerImpact"])
    if scenario["severity"] not in SEVS:
        reject("scenario severity must use severity model")
    severities = {fields(item, "severity model item", ["severity", "trigger", "target"])["severity"] for item in require_list(payload["severityModel"], "severity model", 4)}
    if SEVS - severities:
        reject("severity model missing required severity")
    commander = fields(payload["incidentCommander"], "incident commander", ["role", "duties"])
    text_list(commander["duties"], "incident commander duties", 4)
    fields(payload["detection"], "detection", ["source", "signal", "validation"])
    communication = nonempty(payload["communicationSurface"], "communication surface").lower()
    if re.search(r"\b(no|without|missing|not captured)\b.{0,80}\b(timeline|severity|commander|mitigation|validation|postmortem|closeout)\b", communication) or re.search(r"\b(timeline|severity|commander|mitigation|validation|postmortem|closeout)\b.{0,80}\b(absent|lacks?|missing|without|not captured)\b", communication):
        reject("communication surface negates timeline evidence")
    missing_communication = sorted(COMMUNICATION_TERMS - set(re.findall(r"[a-z-]+", communication)))
    if missing_communication:
        reject("communication surface missing timeline evidence: " + ", ".join(missing_communication))
    text_list(payload["mitigationSequence"], "mitigation sequence", 5)
    fields(payload["rollbackOrRecoveryDecision"], "rollback or recovery decision", ["decision", "operator", "evidence"])
    fields(payload["alertRoutingDecision"], "alert routing decision", ["status", "route", "pagingBackend", "nextEscalation"])
    postmortem = fields(payload["postmortemTemplate"], "postmortem template", ["requiredFields", "minimumTimelineEvents"])
    postmortem_fields = text_list(postmortem["requiredFields"], "postmortem required fields", len(POSTMORTEM_FIELDS))
    missing_fields = sorted(set(POSTMORTEM_FIELDS) - set(postmortem_fields))
    if missing_fields:
        reject("postmortem required fields missing: " + ", ".join(missing_fields))
    if postmortem_fields != POSTMORTEM_FIELDS:
        reject("postmortem required fields include unexpected values")
    postmortem_events = text_list(postmortem["minimumTimelineEvents"], "postmortem timeline events", len(POSTMORTEM_EVENTS))
    missing_events = sorted(set(POSTMORTEM_EVENTS) - set(postmortem_events))
    if missing_events:
        reject("postmortem timeline missing: " + ", ".join(missing_events))
    if postmortem_events != POSTMORTEM_EVENTS:
        reject("postmortem timeline includes unexpected values")
    fields(payload["evidenceRetention"], "evidence retention", ["surface", "redaction", "retentionOwner"])
    validation_output = text_list(payload["validationOutput"], "validation output", len(CMDS))
    for item in validation_output:
        if any(marker in item.lower() for marker in BAD_VALIDATION):
            reject("validation output contains non-passing marker")
    for command in CMDS:
        expected = f"bash scripts/{command}: PASS"
        if expected not in validation_output:
            reject(f"validation output missing exact PASS for {command}")
    approval = str(payload["approvalGateStatus"]).lower()
    if "no live approval-gated mutation reached" not in approval or "remain not authorized" not in approval:
        reject("approval-gate status must state no live approval-gated mutation reached and remain not authorized")
    if re.search(r"\b(can|may|will)\s+proceed\b", approval) or "authorized and" in approval or re.search(r"\b(deploy(ment)?|release|rollback|credentials?)\s+(is|are)?\s*authorized\b", approval):
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
def expect_reject(name, candidate, expected):
    try:
        validate_doc(candidate) if isinstance(candidate, str) else validate(candidate)
    except IncidentError as exc:
        if expected not in str(exc):
            reject(f"negative fixture {name} failed for wrong reason: {exc}")
        return
    reject(f"negative fixture unexpectedly passed: {name}")
def run():
    doc_text = Path(sys.argv[1]).read_text(encoding="utf-8")
    baseline = validate_doc(doc_text)
    expect_reject("empty content", "", "empty incident response content")
    expect_reject("malformed data", START + "\n```json\n{\"version\": \n```\n" + END, "malformed incident response data")
    expect_reject("markers out of order", END + "\n" + START + "\n{}\n", "markers out of order")
    for field in REQ:
        expect_reject(f"missing {field}", mutate(baseline, (field,), [] if isinstance(baseline.get(field), list) else ""), f"missing {field}")
    cases = [
        ("bad version", ("version",), 2, "version must be 1"), ("bad date", ("date",), "20260613", "date must be ISO"), ("duplicate baseline", ("sourceBaselines",), BASELINES + [BASELINES[0]], "source baselines"), ("bad severity", ("scenario", "severity"), "LOW", "scenario severity"), ("missing sev", ("severityModel", 0, "severity"), "OTHER", "severity model missing"),
        ("missing commander duty", ("incidentCommander", "duties"), [""], "incident commander duties"), ("generic communication", ("communicationSurface",), "GitHub issue surface only.", "communication surface missing timeline evidence"), ("negated communication", ("communicationSurface",), "No timeline, severity, commander, mitigation, validation, postmortem, or closeout evidence exists.", "communication surface negates"), ("absent communication", ("communicationSurface",), "Timeline, severity, commander, mitigation, validation, postmortem, and closeout evidence are absent.", "communication surface negates"), ("not captured communication", ("communicationSurface",), "Not captured: timeline, severity, commander, mitigation, validation, postmortem, and closeout evidence.", "communication surface negates"), ("missing mitigation", ("mitigationSequence",), [""], "mitigation sequence"), ("missing alert route", ("alertRoutingDecision", "route"), "", "missing alert routing decision route"),
        ("missing postmortem fields", ("postmortemTemplate", "requiredFields"), [""], "postmortem required fields"), ("extra postmortem fields", ("postmortemTemplate", "requiredFields"), POSTMORTEM_FIELDS + ["extra"], "unexpected"), ("duplicate postmortem fields", ("postmortemTemplate", "requiredFields"), POSTMORTEM_FIELDS + ["timeline"], "unexpected"), ("generic postmortem fields", ("postmortemTemplate", "requiredFields"), ["one", "two", "three", "four", "five", "six", "seven"], "missing postmortem required fields"), ("extra postmortem timeline", ("postmortemTemplate", "minimumTimelineEvents"), POSTMORTEM_EVENTS + ["extra"], "unexpected"), ("duplicate postmortem timeline", ("postmortemTemplate", "minimumTimelineEvents"), POSTMORTEM_EVENTS + ["detection"], "unexpected"), ("generic postmortem timeline", ("postmortemTemplate", "minimumTimelineEvents"), ["one", "two", "three", "four", "five", "six"], "postmortem timeline"),
        ("missing validation", ("validationOutput",), ["bash scripts/validate-incident-response-runbook.sh: PASS"], "validation output"), ("false validation", ("validationOutput",), ["NOT RUN bash scripts/validate-incident-response-runbook.sh: FAIL but PASS placeholder"] + baseline["validationOutput"][1:], "validation output contains non-passing marker"), ("cleanup incomplete", ("cleanup", "status"), "pending", "cleanup must be complete"), ("bad follow-up", ("followUpIssueUrl",), "https://github.com/", "follow-up issue URL"),
        ("unsafe wording", ("nextAction",), "Deployment completed in production.", "unsafe mutation"), ("unsafe production deployment wording", ("nextAction",), "Production deployment succeeded.", "production deploy claim"), ("unsafe rollback wording", ("nextAction",), "Rollback completed in production.", "production deploy claim"), ("unsafe project field", ("nextAction",), "GitHub Project field was updated.", "unsafe mutation"),
        ("approval authorizes action", ("approvalGateStatus",), "no live approval-gated mutation reached; credentials are authorized and deployment may proceed; remain not authorized is historical text", "approval-gate status must not authorize later action"), ("approval authorizes deployment", ("approvalGateStatus",), "No live approval-gated mutation reached; deployment is authorized after this tabletop; remain not authorized for credentials.", "approval-gate status must not authorize later action"),
        ("private path", ("nextAction",), HOME + "private/incident", "private local path"), ("secret pattern", ("nextAction",), "ASIA" + "A" * 16, "secret-like"),
    ]
    for name, path, value, expected in cases:
        expect_reject(name, mutate(baseline, path, value), expected)
    expect_reject("private path outside payload", "Operator scratch: " + HOME + "private/incident\n" + doc_text, "private local path")
    expect_reject("secret outside payload", "Operator scratch: " + "".join(("gh", "p_", "A" * 20)) + "\n" + doc_text, "secret-like")
try:
    run()
except IncidentError as exc:
    print(f"FAIL {exc}", file=sys.stderr)
    sys.exit(1)
print("PASS Dokkaebi incident response runbook validation passed")
PY
