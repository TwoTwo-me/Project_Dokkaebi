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

DOC_PATH="${SECURITY_THREAT_MODEL_PATH:-docs/policies/security-threat-model-and-prompt-injection-controls.md}"

for term in \
  "threat actors" "trust boundaries" "assets" "abuse cases" \
  "prompt-injection paths" "data exfiltration paths" \
  "credential-broker misuse paths" "worker-route escalation paths" \
  "GitHub Project control-plane risks" "mitigations" "detection evidence" \
  "fail-closed behavior" "owner review cadence" "residual risk" \
  "next action" "does not authorize"; do
  require_text "$DOC_PATH" "$term"
done

command -v python3 >/dev/null || fail "missing command: python3"

python3 - "$DOC_PATH" <<'PY'
import copy
import json
import re
import sys
from pathlib import Path

START = "<!-- security-threat-model:begin -->"
END = "<!-- security-threat-model:end -->"
REQUIRED_SURFACES = {
    "manager_prompt_injection",
    "github_project_control_plane",
    "credential_broker_misuse",
    "worker_route_escalation",
    "evidence_exfiltration",
    "human_approval_spoofing",
}
REQUIRED_FIELDS = [
    "threatActor",
    "trustBoundary",
    "asset",
    "abuseCase",
    "promptInjectionPath",
    "dataExfiltrationPath",
    "credentialBrokerMisusePath",
    "workerRouteEscalationPath",
    "githubProjectControlPlaneRisk",
    "mitigations",
    "detectionEvidence",
    "failClosedBehavior",
    "ownerReviewCadence",
    "residualRisk",
    "nextAction",
]
HOME_SEGMENT, USERS_SEGMENT = "/" + "home" + "/", "/" + "users" + "/"
PRIVATE_PATH_RE = re.compile(r"(?i)(" + re.escape(HOME_SEGMENT) + "|" + re.escape(USERS_SEGMENT) + r")[^\s`'\"]+")
INTERNAL_LABELS = ["".join(parts) for parts in [("o", "mo"), ("o", "mx"), ("u", "lw")]]
INTERNAL_LABEL_RE = re.compile(r"\b(" + "|".join(INTERNAL_LABELS) + r")\b", re.IGNORECASE)
SECRET_TERMS = ["cookie=", "private" + "_key=", "sec" + "ret=", "to" + "ken=", "authorization: bearer", "-----begin private key-----"]
UNSAFE_PHRASES = [
    "credential copied",
    "broker mutation completed",
    "deployment executed",
    "github project control-plane mutation completed",
    "infrastructure mutated",
    "production write completed",
    "worker scaled",
]


class ThreatModelError(Exception):
    pass


def reject(message):
    raise ThreatModelError(message)


def extract_payload(text):
    if not text.strip():
        reject("empty security threat model content")
    if START not in text or END not in text:
        reject("missing security threat model block")
    block = text.split(START, 1)[1].split(END, 1)[0].strip()
    if block.startswith("```json"):
        block = block.removeprefix("```json").strip()
    if block.endswith("```"):
        block = block[: -len("```")].strip()
    try:
        payload = json.loads(block)
    except json.JSONDecodeError as exc:
        reject(f"malformed security threat model data: {exc}")
    if not isinstance(payload, dict):
        reject("security threat model block must be an object")
    return payload


def require_nonempty(value, label):
    if value in (None, "", [], {}):
        reject(f"missing {label}")
    return value


def require_list(value, label, minimum=1):
    if not isinstance(value, list) or len(value) < minimum:
        reject(f"missing {label}")
    return value


def flattened_strings(value):
    if isinstance(value, str):
        return [value]
    if isinstance(value, list):
        return [text for item in value for text in flattened_strings(item)]
    if isinstance(value, dict):
        return [text for item in value.values() for text in flattened_strings(item)]
    return []


def require_safe_text(payload):
    lowered = "\n".join(flattened_strings(payload)).lower()
    for term in SECRET_TERMS:
        if term in lowered:
            reject(f"secret-bearing evidence wording: {term}")
    for phrase in UNSAFE_PHRASES:
        if phrase in lowered:
            reject(f"unsafe authority wording: {phrase}")
    if PRIVATE_PATH_RE.search(lowered):
        reject("private local path retained")
    if INTERNAL_LABEL_RE.search(lowered):
        reject("internal execution label retained")


def validate_surface(item):
    if not isinstance(item, dict):
        reject("surface must be an object")
    surface_id = require_nonempty(item.get("id"), "surface id")
    for field in REQUIRED_FIELDS:
        value = require_nonempty(item.get(field), f"{surface_id} {field}")
        if field in {"mitigations", "detectionEvidence"}:
            require_list(value, f"{surface_id} {field}", 2)
    return surface_id


def validate_payload(payload):
    for field in [
        "version",
        "permissionLevel",
        "approvalBoundary",
        "threatActors",
        "trustBoundaries",
        "assets",
        "surfaces",
        "validationOutput",
        "residualRisk",
        "nextAction",
        "followUpIssueUrl",
    ]:
        require_nonempty(payload.get(field), field)
    if payload["permissionLevel"] != "docs-only security threat model and prompt-injection controls":
        reject("permissionLevel must remain docs-only security threat model and prompt-injection controls")
    boundary = str(payload["approvalBoundary"]).lower()
    for term in ["does not authorize", "runtime", "credential", "production", "explicit human approval"]:
        if term not in boundary:
            reject(f"approval boundary missing {term}")
    require_list(payload["threatActors"], "threat actors", 5)
    require_list(payload["trustBoundaries"], "trust boundaries", 5)
    require_list(payload["assets"], "assets", 5)
    surfaces = require_list(payload["surfaces"], "surfaces", len(REQUIRED_SURFACES))
    seen = {validate_surface(item) for item in surfaces}
    if seen != REQUIRED_SURFACES:
        reject("surface ids mismatch: " + ", ".join(sorted(REQUIRED_SURFACES - seen)))
    surface_text = "\n".join(flattened_strings(surfaces)).lower()
    for term in ["prompt", "exfiltration", "credential", "worker route", "github project", "fail"]:
        if term not in surface_text:
            reject(f"surface coverage missing {term}")
    validation_text = "\n".join(str(item) for item in require_list(payload["validationOutput"], "validation output", 3))
    for term in ["security threat model", "enterprise readiness", "contract docs"]:
        if term not in validation_text:
            reject(f"validation output missing {term}")
    require_list(payload["residualRisk"], "residual risk", 2)
    if not str(payload["followUpIssueUrl"]).startswith("https://github.com/"):
        reject("follow-up issue URL must be a GitHub URL")
    require_safe_text(payload)


doc_text = Path(sys.argv[1]).read_text(encoding="utf-8")
baseline = extract_payload(doc_text)
validate_payload(baseline)


def expect_reject(name, candidate):
    try:
        validate_payload(extract_payload(candidate) if isinstance(candidate, str) else candidate)
    except ThreatModelError:
        return
    reject(f"negative fixture unexpectedly passed: {name}")


expect_reject("empty content", "")
expect_reject("malformed data", START + "\n```json\n{\"version\": \n```\n" + END)
for field in ["threatActors", "trustBoundaries", "assets", "surfaces", "validationOutput"]:
    mutated = copy.deepcopy(baseline)
    mutated[field] = []
    expect_reject(f"missing {field}", mutated)
for surface_id in sorted(REQUIRED_SURFACES):
    mutated = copy.deepcopy(baseline)
    mutated["surfaces"] = [item for item in mutated["surfaces"] if item["id"] != surface_id]
    expect_reject(f"missing {surface_id}", mutated)
for name, mutate in [
    ("missing prompt-injection control", lambda item: item["surfaces"][0].update({"promptInjectionPath": ""})),
    ("missing credential boundary", lambda item: item["surfaces"][2].update({"credentialBrokerMisusePath": ""})),
    ("unsafe authority wording", lambda item: item.update({"nextAction": "broker mutation completed"})),
    ("private local path", lambda item: item.update({"nextAction": HOME_SEGMENT + "sam/private"})),
    ("secret-bearing wording", lambda item: item.update({"nextAction": "authorization: bearer example"})),
    ("internal execution label", lambda item: item.update({"assets": ["run " + INTERNAL_LABELS[0] + " workflow"]})),
]:
    mutated = copy.deepcopy(baseline)
    mutate(mutated)
    expect_reject(name, mutated)

print("PASS Dokkaebi security threat model validation passed")
PY
