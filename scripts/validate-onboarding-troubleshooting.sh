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

DOC_PATH="${ONBOARDING_TROUBLESHOOTING_PATH:-docs/product/onboarding-troubleshooting.md}"

for term in \
  "admin journey" \
  "approver journey" \
  "operator journey" \
  "auditor journey" \
  "worker-author journey" \
  "install walkthrough" \
  "GitHub Project setup checks" \
  "repository setup checks" \
  "approval and review actions" \
  "result-packet closeout actions" \
  "Fire failure troubleshooting" \
  "worker failure troubleshooting" \
  "GitHub failure troubleshooting" \
  "credential failure troubleshooting" \
  "validation failure troubleshooting" \
  "project-field failure troubleshooting" \
  "PR failure troubleshooting" \
  "result-packet failure troubleshooting" \
  "clear next actions" \
  "multi-project setup workflow" \
  "browser action log" \
  "desktop Greenfield" \
  "mobile Brownfield" \
  "approval boundary" \
  "permission level" \
  "docs-only"; do
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

START = "<!-- onboarding-troubleshooting:begin -->"
END = "<!-- onboarding-troubleshooting:end -->"
REQUIRED_TOP_LEVEL = [
    "permissionLevel",
    "approvalBoundary",
    "roleJourneys",
    "installWalkthrough",
    "githubProjectSetupChecks",
    "repositorySetupChecks",
    "approvalReviewActions",
    "resultPacketCloseoutActions",
    "troubleshooting",
    "completedProductizationEvidence",
    "remainingProductizationGaps",
]
REQUIRED_ROLES = {
    "admin",
    "approver",
    "operator",
    "auditor",
    "worker_author",
}
REQUIRED_TROUBLESHOOTING = {
    "fire",
    "worker",
    "github",
    "credential",
    "validation",
    "project_field",
    "pr",
    "result_packet",
}
BOUNDARY_TERMS = {
    "credential",
    "production",
    "infrastructure",
    "worker",
    "remote host",
    "docker",
    "kubernetes",
    "deployment",
    "github project control-plane",
    "explicit human approval",
}
UNAUTHORIZED_PHRASES = [
    "credential mutation authorized",
    "production write authorized",
    "infrastructure mutation authorized",
    "worker privilege expansion authorized",
    "remote host mutation authorized",
    "docker mutation authorized",
    "kubernetes mutation authorized",
    "deployment authorized",
    "github project control-plane mutation authorized",
]
PRIVATE_CONTEXT_PHRASES = [
    "private maintainer context",
    "maintainer-only",
    "tribal knowledge",
    "hidden memory",
    "ask the maintainer",
]


class OnboardingError(Exception):
    pass


def reject(message: str) -> None:
    raise OnboardingError(message)


def extract_payload(text: str) -> dict[str, Any]:
    if not text.strip():
        reject("empty onboarding guide")
    lowered = text.lower()
    for phrase in PRIVATE_CONTEXT_PHRASES:
        if phrase in lowered:
            reject("private maintainer context wording")
    if START not in text or END not in text:
        reject("missing onboarding troubleshooting block")
    block = text.split(START, 1)[1].split(END, 1)[0].strip()
    if block.startswith("```json"):
        block = block.removeprefix("```json").strip()
    if block.endswith("```"):
        block = block[: -len("```")].strip()
    try:
        payload = json.loads(block)
    except json.JSONDecodeError as exc:
        reject(f"malformed onboarding data: {exc}")
    if not isinstance(payload, dict):
        reject("onboarding troubleshooting block must be an object")
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
        return " ".join(text_join(v) for v in value)
    return str(value)


def contains_all(text: str, required: set[str], label: str) -> None:
    lowered = text.lower()
    missing = sorted(item for item in required if item not in lowered)
    if missing:
        reject(f"{label} missing {', '.join(missing)}")


def validate_payload(payload: dict[str, Any]) -> None:
    for field in REQUIRED_TOP_LEVEL:
        if field == "remainingProductizationGaps":
            continue
        require_nonempty(payload.get(field), field)

    permission = str(payload.get("permissionLevel", "")).lower()
    if "docs-only" not in permission or "local validation" not in permission:
        reject("missing permission level")

    boundary = str(payload.get("approvalBoundary", "")).lower()
    for phrase in UNAUTHORIZED_PHRASES:
        if phrase in boundary:
            reject("unauthorized sensitive mutation wording")
    contains_all(boundary, BOUNDARY_TERMS, "approval boundary")

    roles = require_dict(payload.get("roleJourneys"), "role journeys")
    missing_roles = REQUIRED_ROLES - set(roles.keys())
    if missing_roles:
        reject("missing " + ", ".join(sorted(missing_roles)) + " journey")

    role_terms = {
        "admin": {"admin journey", "github project", "repository", "status", "validation", "approval boundary", "next action"},
        "approver": {"approver journey", "issue", "pull request", "result packet", "permission level", "approval", "evidence"},
        "operator": {"operator journey", "fire", "worker", "github", "credential", "validation", "project-field", "pr", "result-packet"},
        "auditor": {"auditor journey", "compliance", "audit", "acceptance criteria", "validation evidence", "approval-gate", "scope-control", "residual risk"},
        "worker_author": {"worker-author journey", "ticket", "result packet", "acceptance criteria", "validation", "permission level", "approval", "scope control"},
    }
    for role, terms in role_terms.items():
        journey = " ".join(str(item).lower() for item in require_list(roles.get(role), f"{role} journey", 5))
        contains_all(journey, terms, f"{role} journey")

    install = " ".join(str(item).lower() for item in require_list(payload.get("installWalkthrough"), "install walkthrough", 6))
    contains_all(
        install,
        {
            "git status",
            "git submodule status",
            "readme",
            "architecture",
            "workflow",
            "validate-readiness-criteria",
            "validate-contract-docs",
            "validate-git-governance",
            "tracker.projects",
            "credential broker",
        },
        "install walkthrough",
    )

    project = " ".join(str(item).lower() for item in require_list(payload.get("githubProjectSetupChecks"), "GitHub Project setup checks", 5))
    contains_all(
        project,
        {"status", "admission", "authorized-by", "approval-gate", "worker route", "result-packet", "control-plane", "blocked", "next action"},
        "GitHub Project setup checks",
    )

    repo = " ".join(str(item).lower() for item in require_list(payload.get("repositorySetupChecks"), "repository setup checks", 5))
    contains_all(
        repo,
        {"branch", "pull request", "validation", "required checks", "submodule", "result packets", "scope-control", "approval-gate"},
        "repository setup checks",
    )

    review = " ".join(str(item).lower() for item in require_list(payload.get("approvalReviewActions"), "approval and review actions", 5))
    contains_all(
        review,
        {"dispatch", "human approver", "target", "operation", "credential", "route", "cleanup", "rollback", "pr", "fix requested", "blocked"},
        "approval and review actions",
    )

    closeout = " ".join(str(item).lower() for item in require_list(payload.get("resultPacketCloseoutActions"), "result-packet closeout actions", 5))
    contains_all(
        closeout,
        {"task identity", "changed artifacts", "acceptance-criteria evidence", "validation evidence", "scope control", "approval-gate status", "cleanup", "issue state", "pull request state", "next action"},
        "result-packet closeout actions",
    )

    troubleshooting = require_dict(payload.get("troubleshooting"), "troubleshooting")
    missing_troubleshooting = REQUIRED_TROUBLESHOOTING - set(troubleshooting.keys())
    if missing_troubleshooting:
        reject("missing " + ", ".join(sorted(missing_troubleshooting)) + " failure troubleshooting")
    for name in REQUIRED_TROUBLESHOOTING:
        entry = require_dict(troubleshooting.get(name), f"{name} failure troubleshooting")
        symptoms = " ".join(str(item).lower() for item in require_list(entry.get("symptoms"), f"{name} symptoms", 2))
        actions = " ".join(str(item).lower() for item in require_list(entry.get("clearNextActions"), f"{name} clear next actions", 2))
        if name.replace("_", " ") not in text_join({name: entry}).lower():
            reject(f"{name} failure troubleshooting missing category marker")
        if not symptoms:
            reject(f"missing {name} symptoms")
        if "capture" not in actions and "record" not in actions and "block" not in actions and "request" not in actions:
            reject(f"{name} clear next actions missing action verb")

    completed = " ".join(str(item).lower() for item in require_list(payload.get("completedProductizationEvidence"), "completed productization evidence", 5))
    contains_all(
        completed,
        {
            "guided onboarding ui",
            "multi-project setup workflow",
            "greenfield",
            "brownfield",
            "browser action log",
            "desktop",
            "mobile",
            "product ui",
            "issue #84",
        },
        "completed productization evidence",
    )

    gaps_value = payload.get("remainingProductizationGaps", [])
    if gaps_value:
        gaps = " ".join(str(item).lower() for item in require_list(gaps_value, "remaining productization gaps", 3))
        contains_all(gaps, {"guided onboarding ui", "screenshots", "multi-project", "product ui"}, "remaining productization gaps")


doc_text = Path(sys.argv[1]).read_text(encoding="utf-8")
baseline = extract_payload(doc_text)
validate_payload(baseline)


def expect_reject(name: str, candidate: str | dict[str, Any]) -> None:
    try:
        if isinstance(candidate, str):
            validate_payload(extract_payload(candidate))
        else:
            validate_payload(candidate)
    except OnboardingError:
        return
    reject(f"negative fixture unexpectedly passed: {name}")


expect_reject("empty guide", "")
expect_reject(
    "malformed onboarding data",
    START + "\n```json\n{\"version\": \n```\n" + END,
)

for field in REQUIRED_TOP_LEVEL:
    if field == "remainingProductizationGaps":
        continue
    mutated = copy.deepcopy(baseline)
    mutated[field] = [] if isinstance(mutated.get(field), list) else ""
    expect_reject(f"missing {field}", mutated)

for role in REQUIRED_ROLES:
    mutated = copy.deepcopy(baseline)
    mutated["roleJourneys"].pop(role, None)
    expect_reject(f"missing {role} journey", mutated)

for category in REQUIRED_TROUBLESHOOTING:
    mutated = copy.deepcopy(baseline)
    mutated["troubleshooting"].pop(category, None)
    expect_reject(f"missing {category} failure troubleshooting", mutated)

mutated = copy.deepcopy(baseline)
mutated["installWalkthrough"] = ["read README only"]
expect_reject("missing install walkthrough", mutated)

mutated = copy.deepcopy(baseline)
mutated["githubProjectSetupChecks"] = ["Status exists"]
expect_reject("missing GitHub Project setup checks", mutated)

mutated = copy.deepcopy(baseline)
mutated["repositorySetupChecks"] = ["branch exists"]
expect_reject("missing repository setup checks", mutated)

mutated = copy.deepcopy(baseline)
mutated["approvalReviewActions"] = ["approve it"]
expect_reject("missing approval and review actions", mutated)

mutated = copy.deepcopy(baseline)
mutated["resultPacketCloseoutActions"] = ["close it"]
expect_reject("missing result-packet closeout actions", mutated)

mutated = copy.deepcopy(baseline)
mutated["approvalBoundary"] = "credential mutation authorized"
expect_reject("unauthorized sensitive mutation wording", mutated)

expect_reject(
    "private maintainer context wording",
    "private maintainer context\n" + START + "\n```json\n" + json.dumps(baseline) + "\n```\n" + END,
)

print("PASS Dokkaebi onboarding troubleshooting validation passed")
PY
