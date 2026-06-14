#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}

DOC_PATH="${GOVERNANCE_SETTINGS_EXPORT_RECONCILIATION_PATH:-docs/policies/governance-settings-export-reconciliation-2026-06-14.md}"

[[ -f "$DOC_PATH" ]] || fail "missing file: $DOC_PATH"

for term in \
  "Governance Settings Export" \
  "Closeout Reconciliation" \
  "branch protection" \
  "repository rulesets" \
  "required checks" \
  "GitHub Project" \
  "does not authorize"; do
  grep -Fqi -- "$term" "$DOC_PATH" || fail "missing text in $DOC_PATH: $term"
done

command -v python3 >/dev/null || fail "missing command: python3"

python3 - "$DOC_PATH" <<'PY'
from __future__ import annotations

import copy
import json
import re
import sys
from pathlib import Path
from typing import Any

START = "<!-- governance-settings-export-reconciliation:begin -->"
END = "<!-- governance-settings-export-reconciliation:end -->"
REQUIRED_SOURCES = {
    "branch_protection_read",
    "repository_rulesets_read",
    "repository_policy",
    "closeout_subject",
}
REQUIRED_CHECKS = {"contract-docs", "git-governance"}
REQUIRED_MISMATCHES = {
    "branch_protection_export_missing",
    "repository_rulesets_empty",
    "github_project_settings_not_captured",
    "formal_pr_review_not_recorded",
    "workpad_comment_not_captured",
}
HOME_SEGMENT = "/" + "home" + "/"
USERS_SEGMENT = "/" + "Users" + "/"
PRIVATE_PATH_RE = re.compile(r"(" + re.escape(HOME_SEGMENT) + "|" + re.escape(USERS_SEGMENT) + r")[^\s`'\"]+")
INTERNAL_LABELS = ["".join(parts) for parts in [("o", "mo"), ("o", "mx"), ("u", "lw")]]
INTERNAL_LABEL_RE = re.compile(r"\b(" + "|".join(INTERNAL_LABELS) + r")\b", re.IGNORECASE)
SECRET_TERMS = ["cookie=", "private_key=", "secret=", "token=", "authorization: bearer"]
UNSAFE_PHRASES = [
    "branch protection mutated",
    "repository settings mutated",
    "github project control-plane mutation completed",
    "credential copied",
    "worker scaled",
    "deployment executed",
    "production write completed",
]


class GovernanceExportError(Exception):
    pass


def reject(message: str) -> None:
    raise GovernanceExportError(message)


def extract_payload(text: str) -> dict[str, Any]:
    if not text.strip():
        reject("empty governance settings export content")
    if text.count(START) != 1 or text.count(END) != 1:
        reject("missing or duplicate governance settings export block")
    block = text.split(START, 1)[1].split(END, 1)[0].strip()
    if block.startswith("```json"):
        block = block.removeprefix("```json").strip()
    if block.endswith("```"):
        block = block[: -len("```")].strip()
    try:
        payload = json.loads(block)
    except json.JSONDecodeError as exc:
        reject(f"malformed governance settings export data: {exc}")
    if not isinstance(payload, dict):
        reject("governance settings export block must be an object")
    return payload


def require_text(value: Any, label: str, terms: list[str] | None = None) -> str:
    if not isinstance(value, str) or not value.strip():
        reject(f"missing {label}")
    text = value.lower()
    for term in terms or []:
        if term.lower() not in text:
            reject(f"{label} missing {term}")
    return text


def require_list(value: Any, label: str, min_items: int = 1) -> list[Any]:
    if not isinstance(value, list) or len(value) < min_items:
        reject(f"missing {label}")
    return value


def require_dict(value: Any, label: str) -> dict[str, Any]:
    if not isinstance(value, dict) or not value:
        reject(f"missing {label}")
    return value


def flatten(value: Any) -> list[str]:
    if isinstance(value, str):
        return [value]
    if isinstance(value, list):
        return [item for child in value for item in flatten(child)]
    if isinstance(value, dict):
        return [item for child in value.values() for item in flatten(child)]
    return []


def require_safe_text(payload: dict[str, Any]) -> None:
    original = "\n".join(flatten(payload))
    text = original.lower()
    for term in SECRET_TERMS:
        if term in text:
            reject(f"secret-bearing wording: {term}")
    for phrase in UNSAFE_PHRASES:
        if phrase in text:
            reject(f"unsafe authority wording: {phrase}")
    if PRIVATE_PATH_RE.search(original):
        reject("private local path retained")
    if INTERNAL_LABEL_RE.search(text):
        reject("internal execution label retained")


def validate_payload(payload: dict[str, Any]) -> None:
    require_text(payload.get("permissionLevel"), "permission level", ["docs-only", "read-only"])
    boundary = require_text(payload.get("approvalBoundary"), "approval boundary")
    for term in [
        "does not authorize",
        "branch protection mutation",
        "repository settings mutation",
        "github project control-plane mutation",
        "explicit human approval",
    ]:
        if term not in boundary:
            reject(f"approval boundary missing {term}")

    sources = {require_text(item.get("id"), "source id"): item for item in require_list(payload.get("exportSources"), "export sources", 4) if isinstance(item, dict)}
    if set(sources) != REQUIRED_SOURCES:
        reject("export sources mismatch")
    for item in sources.values():
        for field in ["kind", "target", "capturedResult", "authority"]:
            require_text(item.get(field), f"export source {item.get('id')} {field}")

    settings = require_dict(payload.get("settingsExport"), "settings export")
    branch = require_dict(settings.get("branchProtection"), "branch protection export")
    if branch.get("status") != "not_exported" or branch.get("httpStatus") != 404:
        reject("branch protection export must record HTTP 404 not_exported")
    require_text(branch.get("interpretation"), "branch protection interpretation", ["fail closed"])

    rulesets = require_dict(settings.get("repositoryRulesets"), "repository rulesets export")
    if rulesets.get("status") != "exported_empty" or rulesets.get("count") != 0:
        reject("repository rulesets export must record exported_empty count 0")
    require_text(rulesets.get("interpretation"), "rulesets interpretation", ["must not be claimed"])

    checks = require_dict(settings.get("requiredChecks"), "required checks")
    expected = set(str(item) for item in require_list(checks.get("expectedChecks"), "expected checks", 2))
    if expected != REQUIRED_CHECKS:
        reject("required checks mismatch")
    observed = " ".join(str(item).lower() for item in require_list(checks.get("observedOnPullRequest"), "observed checks", 2))
    for check in REQUIRED_CHECKS:
        if check not in observed or "success" not in observed:
            reject(f"observed checks missing success for {check}")
    require_text(checks.get("enforcementStatus"), "required-check enforcement status", ["not proven"])

    pr_rules = require_dict(settings.get("pullRequestReviewRules"), "pull request review rules")
    require_text(pr_rules.get("expectedRule"), "expected PR rule", ["validation", "risks", "approval"])
    require_text(pr_rules.get("observedCloseoutGap"), "PR review gap", ["not recorded"])

    project = require_dict(settings.get("githubProjectSettings"), "GitHub Project settings")
    if project.get("status") != "not_captured":
        reject("GitHub Project settings must remain not_captured")
    require_text(project.get("failClosedAction"), "GitHub Project fail-closed action", ["issue #100"])

    closeout = require_dict(payload.get("closeoutReconciliation"), "closeout reconciliation")
    subject = require_dict(closeout.get("subject"), "closeout subject")
    issue = require_dict(subject.get("issue"), "closeout issue")
    pr = require_dict(subject.get("pullRequest"), "closeout pull request")
    if issue.get("number") != 20 or issue.get("state") != "CLOSED":
        reject("issue closeout state mismatch")
    if pr.get("number") != 99 or pr.get("state") != "MERGED":
        reject("pull request closeout state mismatch")
    if pr.get("reviewDecision") != "not_recorded_in_pr_review":
        reject("PR review decision gap must be explicit")
    check_rows = require_list(closeout.get("checks"), "closeout checks", 2)
    check_map = {str(item.get("name")): item for item in check_rows if isinstance(item, dict)}
    if set(check_map) != REQUIRED_CHECKS:
        reject("closeout check names mismatch")
    for name, item in check_map.items():
        if item.get("conclusion") != "SUCCESS":
            reject(f"closeout check did not pass: {name}")
    result = require_dict(closeout.get("resultPacketEvidence"), "result packet evidence")
    require_text(result.get("status"), "result packet status", ["present"])
    fields = " ".join(str(item).lower() for item in require_list(result.get("fields"), "result packet fields", 5))
    for term in ["changed artifacts", "decision rationale", "validation", "risks", "approval gates"]:
        if term not in fields:
            reject(f"result packet fields missing {term}")
    for field in ["workpadComment", "githubProjectStatus"]:
        item = require_dict(closeout.get(field), field)
        if item.get("status") != "not_captured":
            reject(f"{field} must remain not_captured")
        require_text(item.get("failClosedAction"), f"{field} fail-closed action", ["capture"])
    require_text(closeout.get("decision"), "closeout decision", ["reconciled", "fail-closed"])

    mismatches = {require_text(item.get("id"), "mismatch id"): item for item in require_list(payload.get("mismatchReport"), "mismatch report", 5) if isinstance(item, dict)}
    if set(mismatches) != REQUIRED_MISMATCHES:
        reject("mismatch report ids mismatch")
    for item in mismatches.values():
        require_text(item.get("severity"), "mismatch severity")
        require_text(item.get("evidence"), "mismatch evidence")
        action = require_text(item.get("failClosedAction"), "mismatch fail-closed action")
        if not any(term in action for term in ["claim", "capture", "block", "require"]):
            reject("mismatch fail-closed action is not actionable")

    validation = " ".join(str(item).lower() for item in require_list(payload.get("validationOutput"), "validation output", 4))
    for term in ["governance settings export", "project governance", "enterprise readiness", "contract docs"]:
        if term not in validation:
            reject(f"validation output missing {term}")
    require_list(payload.get("residualRisk"), "residual risk", 3)
    require_text(payload.get("nextAction"), "next action", ["issue #100"])
    require_text(payload.get("followUpIssueUrl"), "follow-up issue URL", ["github.com", "/issues/100"])
    require_safe_text(payload)


doc_text = Path(sys.argv[1]).read_text(encoding="utf-8")
baseline = extract_payload(doc_text)
validate_payload(baseline)


def expect_reject(name: str, candidate: str | dict[str, Any]) -> None:
    try:
        if isinstance(candidate, str):
            validate_payload(extract_payload(candidate))
        else:
            validate_payload(candidate)
    except GovernanceExportError:
        return
    reject(f"negative fixture unexpectedly passed: {name}")


expect_reject("empty doc", "")
expect_reject("malformed json", START + "\n```json\n{\"version\": \n```\n" + END)

for field in ["exportSources", "settingsExport", "closeoutReconciliation", "mismatchReport", "approvalBoundary"]:
    mutated = copy.deepcopy(baseline)
    mutated[field] = [] if field in {"exportSources", "mismatchReport"} else {}
    expect_reject(f"missing {field}", mutated)

mutated = copy.deepcopy(baseline)
mutated["settingsExport"]["branchProtection"]["status"] = "enforced"
expect_reject("false branch protection claim", mutated)

mutated = copy.deepcopy(baseline)
mutated["settingsExport"]["repositoryRulesets"]["count"] = 1
expect_reject("false ruleset claim", mutated)

mutated = copy.deepcopy(baseline)
mutated["closeoutReconciliation"]["checks"][0]["conclusion"] = "FAILURE"
expect_reject("failed check accepted", mutated)

mutated = copy.deepcopy(baseline)
mutated["mismatchReport"] = mutated["mismatchReport"][:2]
expect_reject("missing mismatch report entries", mutated)

mutated = copy.deepcopy(baseline)
mutated["nextAction"] = "repository settings mutated"
expect_reject("unsafe mutation wording", mutated)

mutated = copy.deepcopy(baseline)
mutated["nextAction"] = HOME_SEGMENT + "sam/private"
expect_reject("private path", mutated)

print("PASS Dokkaebi governance settings export reconciliation validation passed")
PY
