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

DOC_PATH="${GOVERNANCE_SETTINGS_SANDBOX_GATE_PATH:-docs/policies/governance-settings-sandbox-gate-2026-06-14.md}"
RUNNER_PATH="scripts/run-governance-settings-sandbox-gate.sh"

for term in \
  "governance settings sandbox" \
  "branch protection" \
  "repository ruleset" \
  "required checks" \
  "pull request review" \
  "GitHub Project field/settings" \
  "workpad substitute" \
  "closeout reconciliation" \
  "approval-gate status" \
  "cleanup receipt" \
  "residual risk" \
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
from pathlib import Path
from typing import Any

START = "<!-- governance-settings-sandbox-gate:begin -->"
END = "<!-- governance-settings-sandbox-gate:end -->"
EXPECTED_ISSUE = "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/100"
RECONCILED_ISSUE = 82
RECONCILED_PR = 116
REQUIRED_CHECKS = {"contract-docs", "git-governance"}
REQUIRED_SOURCE_FILES = {
    "WORKFLOW.md",
    "docs/policies/git-governance.md",
    "docs/policies/project-governance-and-closeout-reconciliation.md",
    "docs/policies/governance-settings-sandbox-gate-2026-06-14.md",
    ".github/pull_request_template.md",
    ".github/workflows/dokkaebi-governance.yml",
    "scripts/validate-git-governance.sh",
}
REQUIRED_PROJECT_FIELDS = {
    "Status",
    "Agent",
    "Authorization",
    "Authorized By",
    "Admission",
    "Workpad",
}
REQUIRED_VALIDATION_OUTPUT = {
    "bash scripts/run-governance-settings-sandbox-gate.sh: PASS",
    "bash scripts/validate-governance-settings-sandbox-gate.sh: PASS",
    "bash scripts/validate-governance-settings-export-reconciliation.sh: PASS",
    "bash scripts/validate-project-governance-reconciliation.sh: PASS",
    "bash scripts/validate-readiness-criteria.sh: PASS",
    "bash scripts/validate-contract-docs.sh: PASS",
    "bash scripts/validate-git-governance.sh: PASS",
}
MANIFEST_FIELDS = [
    "approvalRecord",
    "sandboxTarget",
    "settingsExport",
    "closeoutReconciliation",
    "approvalGateStatus",
    "cleanup",
    "validationOutput",
    "residualRisk",
    "readinessDecision",
]
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
COMMIT_RE = re.compile(r"^[0-9a-f]{40}$")
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
    ("branch protection mutation claim", r"\bbranch protection\s+(was\s+)?(mutated|changed|updated|created|enabled|applied)\b"),
    ("repository settings mutation claim", r"\brepository settings\s+(were\s+|was\s+)?(mutated|changed|updated|created|enabled|applied)\b"),
    ("ruleset mutation claim", r"\brepository ruleset[s]?\s+(were\s+|was\s+)?(mutated|changed|updated|created|enabled|applied)\b"),
    ("project field mutation claim", r"\bgithub project\s+(field|settings|control-plane)\s+(was\s+|were\s+)?(created|updated|mutated|changed|applied)\b"),
    ("credential use claim", r"\bcredentials?\s+(were\s+|was\s+|are\s+|is\s+)?(used|loaded|copied|granted)\b"),
    ("infrastructure mutation claim", r"\binfrastructure\s+(was\s+)?(mutated|changed|updated|created|deployed)\b"),
    ("worker mutation claim", r"\bworker\s+(was\s+)?(scaled|started|mutated|changed|deployed)\b"),
    ("deployment claim", r"\b(deployment|production write)\s+(was\s+)?(performed|completed|executed)\b"),
    ("container claim", r"\b(docker|kubernetes)\s+(resource|cluster|container|job)\s+(was\s+)?(created|started|mutated)\b"),
]


class GovernanceSandboxError(Exception):
    pass


def reject(message: str) -> None:
    raise GovernanceSandboxError(message)


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
        reject("empty governance settings sandbox content")
    if text.count(START) != 1 or text.count(END) != 1:
        reject("missing or duplicate governance settings sandbox block")
    block = text.split(START, 1)[1].split(END, 1)[0].strip()
    if block.startswith("```json"):
        block = block.removeprefix("```json").strip()
    if block.endswith("```"):
        block = block[:-3].strip()
    try:
        payload = json.loads(block)
    except json.JSONDecodeError as exc:
        reject(f"malformed governance settings sandbox data: {exc}")
    if not isinstance(payload, dict):
        reject("governance settings sandbox block must be an object")
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
    if "PASS Dokkaebi governance settings sandbox gate runner completed" not in output:
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


def validate_approval(payload: dict[str, Any]) -> None:
    approval = fields(payload.get("approvalRecord"), "approval record", ["approvedTarget", "scope", "approvedSurfaces", "deniedTargets", "evidence"])
    scope = str(approval["scope"]).lower()
    for term in ["branch protection", "ruleset", "required checks", "pr review", "github project", "closeout"]:
        if term not in scope:
            reject(f"approval scope missing {term}")
    surfaces = joined(require_list(approval["approvedSurfaces"], "approved surfaces", 6)).lower()
    for term in ["branch protection", "ruleset", "required checks", "pull request review", "field/settings", "closeout"]:
        if term not in surfaces:
            reject(f"approved surfaces missing {term}")
    denied = joined(require_list(approval["deniedTargets"], "denied targets", 8)).lower()
    for term in ["control-plane mutation", "branch protection mutation", "repository settings mutation", "credential", "worker", "docker", "kubernetes", "deployment", "production"]:
        if term not in denied:
            reject(f"denied targets missing {term}")


def validate_settings(payload: dict[str, Any]) -> None:
    target = fields(payload.get("sandboxTarget"), "sandbox target", ["kind", "target", "sourceFiles", "authority"])
    if "repository-local" not in str(target["kind"]).lower():
        reject("sandbox target must be repository-local")
    if "no live github" not in str(target["authority"]).lower():
        reject("sandbox authority must deny live GitHub mutation")
    source_files = set(str(item) for item in require_list(target["sourceFiles"], "sandbox target source files", len(REQUIRED_SOURCE_FILES)))
    if source_files != REQUIRED_SOURCE_FILES:
        reject("sandbox target source files mismatch")

    settings = fields(payload.get("settingsExport"), "settings export", ["branchProtection", "repositoryRuleset", "requiredChecks", "pullRequestReviewRules", "githubProjectSettings"])
    branch = fields(settings["branchProtection"], "branch protection export", ["status", "branch", "requiresPullRequest", "requiredApprovingReviewCount", "requiredStatusChecks", "liveMutationStatus"])
    if branch["status"] != "sandbox_exported" or branch["branch"] != "main":
        reject("branch protection export must be sandbox_exported for main")
    if branch["requiresPullRequest"] is not True or branch["requiredApprovingReviewCount"] != 1:
        reject("branch protection export must require PR and one approving review")
    if set(str(item) for item in branch["requiredStatusChecks"]) != REQUIRED_CHECKS:
        reject("branch protection checks mismatch")
    if branch["liveMutationStatus"] != "not_attempted":
        reject("branch protection live mutation must remain not_attempted")

    ruleset = fields(settings["repositoryRuleset"], "repository ruleset export", ["status", "name", "target", "enforcement", "rules", "liveMutationStatus"])
    if ruleset["status"] != "sandbox_exported" or ruleset["target"] != "refs/heads/main":
        reject("repository ruleset must target main in sandbox")
    if "approved sandbox" not in str(ruleset["enforcement"]).lower():
        reject("repository ruleset enforcement must be sandbox only")
    if ruleset["liveMutationStatus"] != "not_attempted":
        reject("repository ruleset live mutation must remain not_attempted")
    rules_text = joined(require_list(ruleset["rules"], "ruleset rules", 5)).lower()
    for term in ["pull request", "approving review", "contract-docs", "git-governance", "metadata hygiene"]:
        if term not in rules_text:
            reject(f"ruleset rules missing {term}")

    checks = fields(settings["requiredChecks"], "required checks export", ["sourceFiles", "expectedChecks", "observedOnPullRequest", "enforcementBasis"])
    if set(str(item) for item in checks["expectedChecks"]) != REQUIRED_CHECKS:
        reject("required checks mismatch")
    observed = joined(checks["observedOnPullRequest"]).lower()
    for check in REQUIRED_CHECKS:
        if check not in observed or "success" not in observed:
            reject(f"observed pull request checks missing success for {check}")
    if "sandbox" not in str(checks["enforcementBasis"]).lower():
        reject("required checks enforcement basis must be sandbox")

    review = fields(settings["pullRequestReviewRules"], "pull request review rules", ["sourceFiles", "requiredSections", "reviewRequirement", "selfApprovalBoundary"])
    sections = set(str(item) for item in require_list(review["requiredSections"], "required PR sections", 8))
    for section in ["Goal", "Non-goals", "Changed artifacts", "Decision rationale", "Validation", "Risks", "Approval gates", "Public metadata hygiene", "Git status"]:
        if section not in sections:
            reject(f"required PR sections missing {section}")
    review_requirement = str(review["reviewRequirement"]).lower()
    if "approving review" not in review_requirement or "explicit human" not in review_requirement:
        reject("PR review requirement must include approving review or explicit Human approval")
    if "tool availability" not in str(review["selfApprovalBoundary"]).lower():
        reject("self-approval boundary must reject tool availability as evidence")

    project = fields(settings["githubProjectSettings"], "GitHub Project settings", ["status", "lifecycleSourceOfTruth", "fieldSchema", "controlPlaneMutationStatus"])
    if project["status"] != "sandbox_exported":
        reject("GitHub Project settings must be sandbox_exported")
    if project["lifecycleSourceOfTruth"] != "GitHub Project Status":
        reject("GitHub Project Status must remain lifecycle source of truth")
    if project["controlPlaneMutationStatus"] != "not_attempted":
        reject("GitHub Project control-plane mutation must remain not_attempted")
    field_schema = require_list(project["fieldSchema"], "GitHub Project field schema", len(REQUIRED_PROJECT_FIELDS))
    by_name = {}
    for item in field_schema:
        row = fields(item, "project field", ["name", "type", "allowedMutators", "rollbackPath"])
        by_name[str(row["name"])] = row
    if set(by_name) != REQUIRED_PROJECT_FIELDS:
        reject("GitHub Project field schema names mismatch")
    status_options = set(str(item) for item in require_list(by_name["Status"].get("options"), "Status options", 8))
    for option in ["Intake", "Ready", "In Progress", "Needs Review", "Human Review", "Merging", "Done", "Blocked"]:
        if option not in status_options:
            reject(f"Status options missing {option}")


def validate_closeout(payload: dict[str, Any]) -> None:
    closeout = fields(payload.get("closeoutReconciliation"), "closeout reconciliation", ["subject", "settingsAppliedForReconciliation", "checks", "resultPacketEvidence", "projectStatusEvidence", "workpadEvidence", "decision"])
    subject = fields(closeout["subject"], "closeout subject", ["issue", "pullRequest"])
    issue = fields(subject["issue"], "closeout issue", ["number", "state", "closedAt", "title"])
    pr = fields(subject["pullRequest"], "closeout pull request", ["number", "state", "mergedAt", "mergeCommit", "headRef", "title"])
    if issue["number"] != RECONCILED_ISSUE or issue["state"] != "CLOSED":
        reject("reconciled issue state mismatch")
    if pr["number"] != RECONCILED_PR or pr["state"] != "MERGED":
        reject("reconciled pull request state mismatch")
    if not COMMIT_RE.fullmatch(str(pr["mergeCommit"])):
        reject("reconciled PR merge commit must be a full commit hash")
    check_rows = require_list(closeout["checks"], "closeout checks", 2)
    check_map = {str(fields(item, "closeout check", ["name", "conclusion"])["name"]): item for item in check_rows}
    if set(check_map) != REQUIRED_CHECKS:
        reject("closeout check names mismatch")
    for name, row in check_map.items():
        if row["conclusion"] != "SUCCESS":
            reject(f"closeout check did not pass: {name}")
    applied = joined(require_list(closeout["settingsAppliedForReconciliation"], "settings reconciliation list", 4)).lower()
    for term in ["required status checks", "pull request body", "linked issue", "project status", "workpad substitute"]:
        if term not in applied:
            reject(f"settings reconciliation missing {term}")
    result = fields(closeout["resultPacketEvidence"], "result packet evidence", ["status", "fields"])
    if "present" not in str(result["status"]).lower():
        reject("result packet evidence must be present")
    result_fields = joined(require_list(result["fields"], "result packet fields", 6)).lower()
    for term in ["changed artifacts", "decision rationale", "validation", "risks", "approval gates", "git status"]:
        if term not in result_fields:
            reject(f"result packet fields missing {term}")
    project_status = fields(closeout["projectStatusEvidence"], "project status evidence", ["status", "field", "reconciledValue", "basis"])
    if project_status["status"] != "approved_sandbox_exported" or project_status["field"] != "Status" or project_status["reconciledValue"] != "Done":
        reject("project status evidence must reconcile Status Done")
    workpad = fields(closeout["workpadEvidence"], "workpad evidence", ["status", "surfaces"])
    if workpad["status"] != "approved_sandbox_substitute_exported":
        reject("workpad substitute must be exported")
    require_list(workpad["surfaces"], "workpad evidence surfaces", 3)
    decision = str(closeout["decision"]).lower()
    if "reconciles" not in decision or "not attempted" not in decision:
        reject("closeout decision must reconcile and deny live mutation")


def validate_payload(payload: dict[str, Any]) -> None:
    for field in [
        "version",
        "evidenceId",
        "date",
        "issueUrl",
        "permissionLevel",
        "approvalRecord",
        "sandboxTarget",
        "settingsExport",
        "closeoutReconciliation",
        "approvalGateStatus",
        "cleanup",
        "validationOutput",
        "residualRisk",
        "readinessDecision",
        "manifestSha256",
        "runner",
        "nextAction",
    ]:
        nonempty(payload.get(field), field)
    if payload["issueUrl"] != EXPECTED_ISSUE:
        reject("issue URL mismatch")
    if payload["permissionLevel"] != "approved-local-sandbox-governance-settings-export":
        reject("permission level mismatch")
    validate_approval(payload)
    validate_settings(payload)
    validate_closeout(payload)

    gate = str(payload["approvalGateStatus"]).lower()
    for term in ["approved local sandbox", "branch protection mutation", "repository settings mutation", "control-plane mutation", "not authorized"]:
        if term not in gate:
            reject(f"approval-gate status missing {term}")
    cleanup = fields(payload["cleanup"], "cleanup", ["status", "receipt"])
    if cleanup["status"] != "complete" or "no resources remain" not in str(cleanup["receipt"]).lower():
        reject("cleanup receipt must be complete and explicit")
    validation = set(str(item) for item in require_list(payload["validationOutput"], "validation output", len(REQUIRED_VALIDATION_OUTPUT)))
    missing = REQUIRED_VALIDATION_OUTPUT - validation
    if missing:
        reject("validation output missing: " + ", ".join(sorted(missing)))
    require_list(payload["residualRisk"], "residual risk", 3)
    readiness = fields(payload["readinessDecision"], "readiness decision", ["management_governance", "basis"])
    if readiness["management_governance"] != 100:
        reject("management_governance must be 100")
    if "approved sandbox export" not in str(readiness["basis"]).lower():
        reject("readiness basis must cite approved sandbox export")
    if not SHA256_RE.fullmatch(str(payload["manifestSha256"])):
        reject("manifestSha256 must be sha256")
    if payload["manifestSha256"] != manifest_hash(payload):
        reject("manifestSha256 mismatch")
    runner = fields(payload["runner"], "runner", ["path", "command", "result"])
    if runner["path"] != "scripts/run-governance-settings-sandbox-gate.sh":
        reject("runner path mismatch")
    if runner["command"] != "bash scripts/run-governance-settings-sandbox-gate.sh":
        reject("runner command mismatch")
    if "PASS Dokkaebi governance settings sandbox gate runner completed" not in str(runner["result"]):
        reject("runner result mismatch")
    require_safe(payload, "payload")


def mutate(payload: dict[str, Any], path: tuple[Any, ...], value: Any, *, refresh: bool = True) -> dict[str, Any]:
    changed = copy.deepcopy(payload)
    target: Any = changed
    for key in path[:-1]:
        target = target[key]
    target[path[-1]] = value
    if refresh and all(field in changed for field in MANIFEST_FIELDS):
        changed["manifestSha256"] = manifest_hash(changed)
    return changed


def expect_reject(name: str, candidate: str | dict[str, Any]) -> None:
    try:
        validate_payload(extract(candidate) if isinstance(candidate, str) else candidate)
    except GovernanceSandboxError:
        return
    reject(f"negative fixture unexpectedly passed: {name}")


doc_text = Path(sys.argv[1]).read_text(encoding="utf-8")
runner_path = Path(sys.argv[2])
baseline = extract(doc_text)
validate_payload(baseline)
runner_payload = run_runner(runner_path)
if baseline != runner_payload:
    reject("runner output does not match checked-in evidence payload")

expect_reject("empty content", "")
expect_reject("malformed data", START + "\n```json\n{\"version\": \n```\n" + END)
for field in ["approvalRecord", "sandboxTarget", "settingsExport", "closeoutReconciliation", "cleanup", "validationOutput", "residualRisk", "readinessDecision", "runner"]:
    expect_reject(f"missing {field}", mutate(baseline, (field,), {} if field != "validationOutput" else []))
for path, name in [
    (("approvalRecord", "approvedTarget"), "missing approved target"),
    (("sandboxTarget", "sourceFiles"), "missing sandbox source files"),
    (("settingsExport", "branchProtection"), "missing branch protection export"),
    (("settingsExport", "repositoryRuleset"), "missing repository ruleset export"),
    (("settingsExport", "requiredChecks"), "missing required checks"),
    (("settingsExport", "pullRequestReviewRules"), "missing PR review rules"),
    (("settingsExport", "githubProjectSettings"), "missing Project settings"),
    (("closeoutReconciliation", "workpadEvidence"), "missing workpad substitute"),
    (("cleanup", "receipt"), "missing cleanup receipt"),
    (("readinessDecision", "management_governance"), "readiness not complete"),
    (("issueUrl",), "wrong issue"),
    (("permissionLevel",), "bad permission level"),
]:
    value: Any = "" if name not in {"readiness not complete", "wrong issue", "bad permission level"} else 99
    if name == "wrong issue":
        value = "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/999"
    if name == "bad permission level":
        value = "live-settings-admin"
    expect_reject(name, mutate(baseline, path, value))
expect_reject("private path", mutate(baseline, ("nextAction",), HOME_SEGMENT + "sam/private"))
expect_reject("secret-like evidence", mutate(baseline, ("nextAction",), "authorization: bearer example"))
expect_reject("unsafe mutation claim", mutate(baseline, ("nextAction",), "repository settings mutated"))
expect_reject("internal execution label", mutate(baseline, ("nextAction",), "run " + INTERNAL_LABELS[0] + " workflow"))
expect_reject("failed validation output", mutate(baseline, ("validationOutput", 1), "bash scripts/validate-governance-settings-sandbox-gate.sh: FAIL"))
expect_reject("mismatched manifest hash", mutate(baseline, ("manifestSha256",), "0" * 64, refresh=False))
expect_reject("mismatched runner result", mutate(baseline, ("runner", "result"), "PASS wrong runner"))

print("PASS Dokkaebi governance settings sandbox gate validation passed")
PY
