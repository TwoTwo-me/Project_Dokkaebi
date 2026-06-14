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

DOC_PATH="${RUNTIME_MULTI_TENANT_RBAC_PATH:-docs/policies/runtime-multi-tenant-rbac-2026-06-14.md}"

for term in \
  "runtime multi-tenant RBAC" \
  "dispatch admission" \
  "credential grant pre-dispatch" \
  "worker route pre-dispatch" \
  "cross-tenant denial" \
  "wildcard" \
  "broad grant" \
  "redacted audit" \
  "access-review output" \
  "approval-gate status" \
  "cleanup receipt" \
  "does not authorize"; do
  require_text "$DOC_PATH" "$term"
done

command -v python3 >/dev/null || fail "missing command: python3"

python3 - "$DOC_PATH" <<'PY'
from __future__ import annotations

import copy
import json
import re
import subprocess
import sys
from datetime import date
from pathlib import Path
from typing import Any

START = "<!-- runtime-multi-tenant-rbac:begin -->"
END = "<!-- runtime-multi-tenant-rbac:end -->"
EXPECTED_ISSUE = "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/74"
EXPECTED_SUBMODULE_PATH = "symphony-github-project-tracker"
EXPECTED_SUBMODULE_PR = "https://github.com/TwoTwo-me/symphony-github-project-tracker/pull/23"
EXPECTED_MERGE = "33896e2cc82ba936e5b765a23b33bfcefe070218"
EXPECTED_RUNTIME = "e516aeacb7d52d206a13033cd4f371a3c2d7264f"
SUPPORTING_SUBMODULE_PRS = {
    "https://github.com/TwoTwo-me/symphony-github-project-tracker/pull/21": {
        "implementationCommit": "8259438315e939309f085feec4741ec7c08da0a1",
        "mergeCommit": "a6cf3eda1422653d51305a9b6cff113c0c05a94f",
    },
    "https://github.com/TwoTwo-me/symphony-github-project-tracker/pull/22": {
        "implementationCommit": "53e2f390850f3bde9afda37719f66af8a2a54ed3",
        "mergeCommit": "3d59edbe2e567a2f96cd95aa1978657148087f83",
    },
}
REQUIRED_DISPATCH_DENIES = {
    "deny_missing_tenant",
    "deny_out_of_scope_repository",
    "deny_out_of_scope_project",
    "deny_cross_tenant_without_approval",
    "deny_role_permission_mismatch",
    "deny_permission_mismatch",
    "deny_missing_approval_evidence",
    "deny_secret_like_evidence",
    "deny_private_path_evidence",
}
REQUIRED_CREDENTIAL_DENIES = {
    "deny_missing_credential_grant",
    "deny_broker_policy_before_rbac",
    "deny_broad_credential_permissions",
    "deny_broad_repository_selection",
    "deny_prefixed_raw_graphql_mutation_without_policy",
    "deny_worker_supplied_tenant_authority",
}
REQUIRED_WORKER_DENIES = {"deny_missing_worker_route", "deny_out_of_scope_worker_route"}
REQUIRED_VALIDATION = {
    "submodule PR #21 git-governance pass",
    "submodule PR #21 make-all pass",
    "submodule PR #21 validate-pr-description pass",
    "submodule PR #22 git-governance pass",
    "submodule PR #22 make-all pass",
    "submodule PR #22 validate-pr-description pass",
    "submodule PR #23 git-governance pass",
    "submodule PR #23 make-all pass",
    "submodule PR #23 validate-pr-description pass",
    "cd symphony-github-project-tracker/elixir && mise exec -- make all",
    "cd symphony-github-project-tracker/elixir && mise exec -- mix tenant_rbac.sandbox",
    "bash scripts/validate-runtime-multi-tenant-rbac.sh",
    "bash scripts/validate-multi-tenant-rbac.sh",
    "bash scripts/validate-multi-tenant-rbac-drill.sh",
    "bash scripts/validate-readiness-criteria.sh",
    "bash scripts/validate-contract-docs.sh",
}
HOME_SEGMENT = "/" + "home" + "/"
USERS_SEGMENT = "/" + "Users" + "/"
PRIVATE_PATH_RE = re.compile(r"(" + re.escape(HOME_SEGMENT) + "|" + re.escape(USERS_SEGMENT) + r")[^\s`'\"]+", re.IGNORECASE)
INTERNAL_LABELS = ["".join(parts) for parts in [("o", "mo"), ("o", "mx"), ("u", "lw")]]
INTERNAL_LABEL_RE = re.compile(r"\b(" + "|".join(INTERNAL_LABELS) + r")\b", re.IGNORECASE)
SECRET_TERMS = ["cookie=", "private_key=", "secret=", "token=", "authorization: bearer", "-----begin private key-----"]
SECRET_PATTERNS = [
    ("github classic access key", r"\bgh[pousr]_[A-Za-z0-9_]{16,}\b"),
    ("github fine-grained access key", r"\bgithub_pat_[A-Za-z0-9_]{20,}\b"),
    ("cloud access key", r"\bA[KS]IA[A-Z0-9]{16}\b"),
]
UNSAFE_PHRASES = [
    "credential used",
    "credential mutation completed",
    "deployment executed",
    "docker container started",
    "github project control-plane mutation completed",
    "infrastructure mutated",
    "kubernetes cluster mutated",
    "production write completed",
    "remote host changed",
    "worker privilege expansion completed",
]


class RuntimeRbacError(Exception):
    pass


def reject(message: str) -> None:
    raise RuntimeRbacError(message)


def extract(text: str) -> dict[str, Any]:
    if not text.strip():
        reject("empty runtime RBAC content")
    if text.count(START) != 1 or text.count(END) != 1:
        reject("missing or duplicate runtime RBAC block")
    block = text.split(START, 1)[1].split(END, 1)[0].strip()
    if block.startswith("```json"):
        block = block.removeprefix("```json").strip()
    if block.endswith("```"):
        block = block[:-3].strip()
    try:
        payload = json.loads(block)
    except json.JSONDecodeError as exc:
        reject(f"malformed runtime RBAC data: {exc}")
    if not isinstance(payload, dict):
        reject("runtime RBAC block must be an object")
    return payload


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
    for phrase in UNSAFE_PHRASES:
        if phrase in lowered:
            reject(f"unsafe mutation wording in {label}: {phrase}")
    if PRIVATE_PATH_RE.search(text):
        reject(f"private local path retained in {label}")
    if INTERNAL_LABEL_RE.search(text):
        reject(f"internal execution label retained in {label}")


def nonempty(value: Any, label: str) -> Any:
    if value in (None, "", [], {}):
        reject(f"missing {label}")
    return value


def require_list(value: Any, label: str, minimum: int = 1) -> list[Any]:
    if not isinstance(value, list) or len(value) < minimum:
        reject(f"missing {label}")
    return value


def require_dict(value: Any, label: str) -> dict[str, Any]:
    if not isinstance(value, dict) or not value:
        reject(f"missing {label}")
    return value


def scenario_set(surface: dict[str, Any], key: str, label: str) -> set[str]:
    values = {str(item) for item in require_list(surface.get(key), label)}
    if len(values) != len(require_list(surface.get(key), label)):
        reject(f"duplicate {label}")
    return values


def submodule_status_sha(path: str) -> str:
    result = subprocess.run(["git", "submodule", "status", "--", path], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
    line = result.stdout.strip()
    if not line:
        reject("missing submodule status")
    return line.split()[0].lstrip("+-")


def validate_payload(payload: dict[str, Any]) -> None:
    for field in [
        "version",
        "evidenceId",
        "date",
        "issueUrl",
        "permissionLevel",
        "approvalRecord",
        "submoduleEvidence",
        "runtimeSurfaces",
        "accessReviewOutput",
        "sandboxCommand",
        "validationOutput",
        "approvalGateStatus",
        "cleanup",
        "residualRisk",
        "readinessDecision",
        "nextAction",
    ]:
        nonempty(payload.get(field), field)
    if payload["version"] != 1:
        reject("version must be 1")
    try:
        date.fromisoformat(str(payload["date"]))
    except ValueError:
        reject("date must be ISO yyyy-mm-dd")
    if payload["issueUrl"] != EXPECTED_ISSUE:
        reject("issue URL must point to issue #74")
    if payload["permissionLevel"] != "approved-local-sandbox-runtime-rbac":
        reject("permission level mismatch")

    approval = require_dict(payload["approvalRecord"], "approval record")
    for field in ["approvedTarget", "scope", "deniedTargets", "evidence"]:
        nonempty(approval.get(field), f"approval record {field}")
    denied = " ".join(str(item).lower() for item in require_list(approval["deniedTargets"], "denied targets", 8))
    for term in ["live credentials", "remote host", "docker", "kubernetes", "deployment", "production", "infrastructure", "github project"]:
        if term not in denied:
            reject(f"approval denied targets missing {term}")

    submodule = require_dict(payload["submoduleEvidence"], "submodule evidence")
    if submodule.get("path") != EXPECTED_SUBMODULE_PATH:
        reject("submodule path mismatch")
    if submodule.get("pullRequest") != EXPECTED_SUBMODULE_PR:
        reject("submodule PR mismatch")
    if submodule.get("runtimeCommit") != EXPECTED_RUNTIME:
        reject("runtime commit mismatch")
    if submodule.get("mergeCommit") != EXPECTED_MERGE:
        reject("merge commit mismatch")
    if submodule_status_sha(EXPECTED_SUBMODULE_PATH) != EXPECTED_MERGE:
        reject("submodule gitlink/status does not match runtime RBAC merge commit")
    supporting = {
        item.get("pullRequest"): item
        for item in require_list(submodule.get("supportingPullRequests"), "supporting submodule PRs", len(SUPPORTING_SUBMODULE_PRS))
        if isinstance(item, dict)
    }
    for url, expected in SUPPORTING_SUBMODULE_PRS.items():
        item = supporting.get(url)
        if not item:
            reject(f"supporting submodule PR missing {url}")
        if item.get("implementationCommit") != expected["implementationCommit"]:
            reject(f"supporting submodule implementation commit mismatch for {url}")
        if item.get("mergeCommit") != expected["mergeCommit"]:
            reject(f"supporting submodule merge commit mismatch for {url}")
    checks = set(str(item) for item in require_list(submodule.get("checks"), "submodule checks", 3))
    for check in ["git-governance pass", "make-all pass", "validate-pr-description pass"]:
        if check not in checks:
            reject(f"submodule check missing {check}")

    surfaces = {surface.get("surface"): surface for surface in require_list(payload["runtimeSurfaces"], "runtime surfaces", 3)}
    if set(surfaces) != {"dispatch admission", "credential grant pre-dispatch", "worker route pre-dispatch"}:
        reject("runtime surfaces mismatch")
    dispatch = surfaces["dispatch admission"]
    credential = surfaces["credential grant pre-dispatch"]
    worker = surfaces["worker route pre-dispatch"]
    if scenario_set(dispatch, "allowScenarios", "dispatch allow scenarios") != {"allow_least_privilege_dispatch"}:
        reject("dispatch allow scenarios mismatch")
    if scenario_set(dispatch, "denyScenarios", "dispatch deny scenarios") != REQUIRED_DISPATCH_DENIES:
        reject("dispatch deny scenarios mismatch")
    if scenario_set(credential, "allowScenarios", "credential allow scenarios") != {"allow_tenant_scoped_credential_grant"}:
        reject("credential allow scenarios mismatch")
    if scenario_set(credential, "denyScenarios", "credential deny scenarios") != REQUIRED_CREDENTIAL_DENIES:
        reject("credential deny scenarios mismatch")
    if scenario_set(worker, "allowScenarios", "worker allow scenarios") != {"allow_tenant_worker_route"}:
        reject("worker allow scenarios mismatch")
    if scenario_set(worker, "denyScenarios", "worker deny scenarios") != REQUIRED_WORKER_DENIES:
        reject("worker deny scenarios mismatch")
    for name, surface in surfaces.items():
        text = joined(surface).lower()
        for term in ["tenant", "actor role", "requested permission", "approval-gate status", "decision", "secret_material_included false"]:
            if term not in text:
                reject(f"{name} audit evidence missing {term}")

    review = require_dict(payload["accessReviewOutput"], "access-review output")
    for field in ["source", "tenantId", "roleAssignments", "repositories", "projects", "credentialGrants", "workerRouteGrants", "reviewer", "cadence", "decision", "nextAction"]:
        nonempty(review.get(field), f"access-review output {field}")
    if review.get("secretMaterialIncluded") is not False:
        reject("access-review output must exclude secret material")
    for role in ["auditor", "fire_operator", "hammer_operator", "security_admin"]:
        if role not in review["roleAssignments"]:
            reject(f"access-review role missing {role}")

    command = require_dict(payload["sandboxCommand"], "sandbox command")
    if command.get("command") != "mise exec -- mix tenant_rbac.sandbox":
        reject("sandbox command mismatch")
    validation = set(str(item) for item in require_list(payload["validationOutput"], "validation output", len(REQUIRED_VALIDATION)))
    missing_validation = REQUIRED_VALIDATION - validation
    if missing_validation:
        reject("validation output missing " + ", ".join(sorted(missing_validation)))

    approval_status = str(payload["approvalGateStatus"]).lower()
    for term in ["approved local sandbox", "no live", "mutation reached", "not authorized"]:
        if term not in approval_status:
            reject(f"approval-gate status missing {term}")
    cleanup = require_dict(payload["cleanup"], "cleanup")
    if cleanup.get("status") != "complete":
        reject("cleanup must be complete")
    nonempty(cleanup.get("receipt"), "cleanup receipt")
    residual = " ".join(str(item).lower() for item in require_list(payload["residualRisk"], "residual risk", 3))
    for term in ["identity-provider", "credential backend", "worker fleet"]:
        if term not in residual:
            reject(f"residual risk missing {term}")
    decision = require_dict(payload["readinessDecision"], "readiness decision")
    if decision.get("security_authority") != 100 or decision.get("multi_tenant_rbac") != 100:
        reject("readiness decision must set security_authority and multi_tenant_rbac to 100")
    require_safe(payload, "runtime RBAC payload")


doc_text = Path(sys.argv[1]).read_text(encoding="utf-8")
baseline = extract(doc_text)
validate_payload(baseline)


def expect_reject(name: str, candidate: dict[str, Any] | str) -> None:
    try:
        validate_payload(extract(candidate) if isinstance(candidate, str) else candidate)
    except RuntimeRbacError:
        return
    reject(f"negative fixture unexpectedly passed: {name}")


expect_reject("empty content", "")
expect_reject("malformed data", START + "\n```json\n{\"version\": \n```\n" + END)
for field in ["approvalRecord", "submoduleEvidence", "runtimeSurfaces", "accessReviewOutput", "validationOutput", "approvalGateStatus", "cleanup"]:
    mutated = copy.deepcopy(baseline)
    mutated[field] = {} if isinstance(mutated[field], dict) else []
    expect_reject(f"missing {field}", mutated)
for name, mutate in [
    ("missing dispatch deny", lambda item: item["runtimeSurfaces"][0]["denyScenarios"].remove("deny_missing_tenant")),
    ("missing credential deny", lambda item: item["runtimeSurfaces"][1]["denyScenarios"].remove("deny_broad_repository_selection")),
    ("missing worker deny", lambda item: item["runtimeSurfaces"][2]["denyScenarios"].remove("deny_out_of_scope_worker_route")),
    ("wrong submodule merge", lambda item: item["submoduleEvidence"].update({"mergeCommit": EXPECTED_RUNTIME})),
    ("missing approval status", lambda item: item.update({"approvalGateStatus": "approved"})),
    ("secret-bearing evidence", lambda item: item.update({"nextAction": "authorization: bearer example"})),
    ("private local path", lambda item: item.update({"nextAction": HOME_SEGMENT + "operator/project"})),
    ("internal execution label", lambda item: item.update({"nextAction": "run " + INTERNAL_LABELS[2] + " evidence"})),
]:
    mutated = copy.deepcopy(baseline)
    mutate(mutated)
    expect_reject(name, mutated)

print("PASS Dokkaebi runtime multi-tenant RBAC validation passed")
PY
