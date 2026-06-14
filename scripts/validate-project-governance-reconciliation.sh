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

DOC_PATH="${PROJECT_GOVERNANCE_RECONCILIATION_PATH:-docs/policies/project-governance-and-closeout-reconciliation.md}"

for term in \
  "project owner" "approver" "Fire operator" "Hammer operator" \
  "security reviewer" "auditor" "stale Human Review" \
  "mismatch handling" "issue status" "pull request" \
  "result packet" "workpad comment" "GitHub Project Status" \
  "does not authorize"; do
  require_text "$DOC_PATH" "$term"
done

command -v python3 >/dev/null || fail "missing command: python3"

python3 - "$DOC_PATH" <<'PY'
import copy
import json
import re
import sys
from pathlib import Path

START = "<!-- project-governance-reconciliation:begin -->"
END = "<!-- project-governance-reconciliation:end -->"
REQUIRED_ROLES = {
    "project_owner",
    "approver",
    "fire_operator",
    "hammer_operator",
    "security_reviewer",
    "auditor",
}
REQUIRED_SURFACES = {
    "issue_status",
    "pr_review_check_merge_state",
    "result_packet",
    "workpad_comment",
    "github_project_status",
}
HOME_SEGMENT, USERS_SEGMENT = "/" + "home" + "/", "/" + "users" + "/"
PRIVATE_PATH_RE = re.compile(r"(?i)(" + re.escape(HOME_SEGMENT) + "|" + re.escape(USERS_SEGMENT) + r")[^\s`'\"]+")
INTERNAL_LABELS = ["".join(parts) for parts in [("o", "mo"), ("o", "mx"), ("u", "lw")]]
INTERNAL_LABEL_RE = re.compile(r"\b(" + "|".join(INTERNAL_LABELS) + r")\b", re.IGNORECASE)
SECRET_TERMS = ["cookie=", "private" + "_key=", "sec" + "ret=", "to" + "ken=", "authorization: bearer"]
UNSAFE_PHRASES = [
    "branch protection mutated",
    "credential copied",
    "deployment executed",
    "github project control-plane mutation completed",
    "infrastructure mutated",
    "repository settings mutated",
    "worker scaled",
]


class GovernanceError(Exception):
    pass


def reject(message):
    raise GovernanceError(message)


def extract_payload(text):
    if not text.strip():
        reject("empty governance content")
    if START not in text or END not in text:
        reject("missing governance block")
    block = text.split(START, 1)[1].split(END, 1)[0].strip()
    if block.startswith("```json"):
        block = block.removeprefix("```json").strip()
    if block.endswith("```"):
        block = block[: -len("```")].strip()
    try:
        payload = json.loads(block)
    except json.JSONDecodeError as exc:
        reject(f"malformed governance data: {exc}")
    if not isinstance(payload, dict):
        reject("governance block must be an object")
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
            reject(f"secret-bearing wording: {term}")
    for phrase in UNSAFE_PHRASES:
        if phrase in lowered:
            reject(f"unsafe authority wording: {phrase}")
    if PRIVATE_PATH_RE.search(lowered):
        reject("private local path retained")
    if INTERNAL_LABEL_RE.search(lowered):
        reject("internal execution label retained")


def validate_role(item):
    if not isinstance(item, dict):
        reject("role must be an object")
    role_id = require_nonempty(item.get("id"), "role id")
    require_nonempty(item.get("name"), f"{role_id} name")
    require_list(item.get("owns"), f"{role_id} owns", 2)
    require_nonempty(item.get("mustNotSelfApprove"), f"{role_id} mustNotSelfApprove")
    return role_id


def validate_surface(item):
    if not isinstance(item, dict):
        reject("surface must be an object")
    surface_id = require_nonempty(item.get("id"), "surface id")
    for field in ["source", "mismatchHandling", "detectionEvidence", "failClosedBehavior"]:
        value = require_nonempty(item.get(field), f"{surface_id} {field}")
        if field == "detectionEvidence":
            require_list(value, f"{surface_id} detectionEvidence", 2)
    return surface_id


def validate_payload(payload):
    for field in [
        "version",
        "permissionLevel",
        "approvalBoundary",
        "roles",
        "reconciliationSurfaces",
        "staleHumanReview",
        "validationOutput",
        "residualRisk",
        "nextAction",
        "followUpIssueUrl",
    ]:
        require_nonempty(payload.get(field), field)
    if payload["permissionLevel"] != "docs-only project governance and closeout reconciliation":
        reject("permissionLevel must remain docs-only project governance and closeout reconciliation")
    boundary = str(payload["approvalBoundary"]).lower()
    for term in ["does not authorize", "branch protection", "repository settings", "explicit human approval"]:
        if term not in boundary:
            reject(f"approval boundary missing {term}")
    roles = require_list(payload["roles"], "roles", len(REQUIRED_ROLES))
    seen_roles = {validate_role(item) for item in roles}
    if seen_roles != REQUIRED_ROLES:
        reject("role ids mismatch: " + ", ".join(sorted(REQUIRED_ROLES - seen_roles)))
    surfaces = require_list(payload["reconciliationSurfaces"], "reconciliation surfaces", len(REQUIRED_SURFACES))
    seen_surfaces = {validate_surface(item) for item in surfaces}
    if seen_surfaces != REQUIRED_SURFACES:
        reject("surface ids mismatch: " + ", ".join(sorted(REQUIRED_SURFACES - seen_surfaces)))
    stale = payload["staleHumanReview"]
    if not isinstance(stale, dict):
        reject("staleHumanReview must be an object")
    for field in ["definition", "requiredRecord", "escalationPath", "failClosedBehavior"]:
        value = require_nonempty(stale.get(field), f"staleHumanReview {field}")
        if field in {"requiredRecord", "escalationPath"}:
            require_list(value, f"staleHumanReview {field}", 3)
    validation_text = "\n".join(str(item) for item in require_list(payload["validationOutput"], "validation output", 3)).lower()
    for term in ["project governance", "enterprise readiness", "contract docs"]:
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
    except GovernanceError:
        return
    reject(f"negative fixture unexpectedly passed: {name}")


expect_reject("empty content", "")
expect_reject("malformed data", START + "\n```json\n{\"version\": \n```\n" + END)
for field in ["roles", "reconciliationSurfaces", "staleHumanReview", "validationOutput"]:
    mutated = copy.deepcopy(baseline)
    mutated[field] = [] if field != "staleHumanReview" else {}
    expect_reject(f"missing {field}", mutated)
for role_id in sorted(REQUIRED_ROLES):
    mutated = copy.deepcopy(baseline)
    mutated["roles"] = [item for item in mutated["roles"] if item["id"] != role_id]
    expect_reject(f"missing {role_id}", mutated)
for surface_id in sorted(REQUIRED_SURFACES):
    mutated = copy.deepcopy(baseline)
    mutated["reconciliationSurfaces"] = [item for item in mutated["reconciliationSurfaces"] if item["id"] != surface_id]
    expect_reject(f"missing {surface_id}", mutated)
for name, mutate in [
    ("missing stale handling", lambda item: item.update({"staleHumanReview": {}})),
    ("missing mismatch handling", lambda item: item["reconciliationSurfaces"][0].update({"mismatchHandling": ""})),
    ("unsafe authority wording", lambda item: item.update({"nextAction": "repository settings mutated"})),
    ("private local path", lambda item: item.update({"nextAction": HOME_SEGMENT + "sam/private"})),
    ("secret-bearing wording", lambda item: item.update({"nextAction": "authorization: bearer example"})),
    ("internal execution label", lambda item: item.update({"residualRisk": ["run " + INTERNAL_LABELS[0] + " workflow"]})),
]:
    mutated = copy.deepcopy(baseline)
    mutate(mutated)
    expect_reject(name, mutated)

print("PASS Dokkaebi project governance reconciliation validation passed")
PY
