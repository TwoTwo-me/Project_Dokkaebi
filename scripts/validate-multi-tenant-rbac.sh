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

DOC_PATH="${MULTI_TENANT_RBAC_PATH:-docs/policies/multi-tenant-rbac.md}"

for term in \
  "tenant boundaries" \
  "role taxonomy" \
  "permission matrix" \
  "admission checks" \
  "authorization checks" \
  "GitHub Project scope mapping" \
  "repository scope mapping" \
  "credential boundary" \
  "worker route boundary" \
  "break-glass path" \
  "access review" \
  "audit evidence" \
  "onboarding and offboarding" \
  "failure handling" \
  "remaining operational gaps" \
  "permission level" \
  "docs-only" \
  "control-plane"; do
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

START = "<!-- multi-tenant-rbac:begin -->"
END = "<!-- multi-tenant-rbac:end -->"
REQUIRED_ROLES = {
    "project_owner",
    "tenant_admin",
    "issue_approver",
    "fire_operator",
    "hammer_operator",
    "security_admin",
    "auditor",
    "break_glass_operator",
}
REQUIRED_TOP_LEVEL = [
    "permissionLevel",
    "securityBoundary",
    "tenantBoundaries",
    "roleTaxonomy",
    "permissionMatrix",
    "admissionChecks",
    "authorizationChecks",
    "scopeMappings",
    "credentialBoundary",
    "workerRouteBoundary",
    "breakGlassPath",
    "accessReview",
    "auditEvidence",
    "onboardingOffboarding",
    "failureHandling",
    "remainingOperationalGaps",
]
SENSITIVE_TERMS = [
    "credential",
    "production",
    "infrastructure",
    "worker",
    "remote host",
    "docker",
    "kubernetes",
    "deployment",
    "control-plane",
    "explicit human approval",
]
UNAUTHORIZED_PHRASES = [
    "credential mutation authorized",
    "production write authorized",
    "infrastructure mutation authorized",
    "worker privilege expansion authorized",
    "remote host mutation authorized",
    "docker mutation authorized",
    "kubernetes mutation authorized",
    "deployment authorized",
    "control-plane mutation authorized",
]


class RbacError(Exception):
    pass


def reject(message: str) -> None:
    raise RbacError(message)


def extract_payload(text: str) -> dict[str, Any]:
    if not text.strip():
        reject("empty RBAC design")
    if START not in text or END not in text:
        reject("missing multi-tenant RBAC block")
    block = text.split(START, 1)[1].split(END, 1)[0].strip()
    if block.startswith("```json"):
        block = block.removeprefix("```json").strip()
    if block.endswith("```"):
        block = block[: -len("```")].strip()
    try:
        payload = json.loads(block)
    except json.JSONDecodeError as exc:
        reject(f"malformed RBAC data: {exc}")
    if not isinstance(payload, dict):
        reject("multi-tenant RBAC block must be an object")
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


def validate_payload(payload: dict[str, Any]) -> None:
    for field in REQUIRED_TOP_LEVEL:
        require_nonempty(payload.get(field), field)

    permission = str(payload.get("permissionLevel", "")).lower()
    if "docs-only" not in permission:
        reject("missing permission level")

    boundary = str(payload.get("securityBoundary", "")).lower()
    for phrase in UNAUTHORIZED_PHRASES:
        if phrase in boundary:
            reject("unauthorized sensitive mutation wording")
    for term in SENSITIVE_TERMS:
        if term not in boundary:
            reject(f"security boundary missing {term}")

    tenant = require_dict(payload.get("tenantBoundaries"), "tenant boundaries")
    for field in [
        "tenantIdentity",
        "projectBinding",
        "repositoryBinding",
        "environmentBinding",
        "credentialScope",
        "workerRouteScope",
        "crossTenantRule",
    ]:
        require_nonempty(tenant.get(field), f"tenant boundaries {field}")
    tenant_text = text_join(tenant).lower()
    for term in ["tenant", "project", "repository", "credential", "worker", "cross-tenant"]:
        if term not in tenant_text:
            reject(f"tenant boundaries missing {term}")

    roles = set(str(role) for role in require_list(payload.get("roleTaxonomy"), "role taxonomy", len(REQUIRED_ROLES)))
    missing_roles = REQUIRED_ROLES - roles
    if missing_roles:
        reject("role taxonomy missing " + ", ".join(sorted(missing_roles)))

    matrix = require_dict(payload.get("permissionMatrix"), "permission matrix")
    missing_matrix_roles = REQUIRED_ROLES - set(matrix.keys())
    if missing_matrix_roles:
        reject("permission matrix missing " + ", ".join(sorted(missing_matrix_roles)))
    all_permissions: set[str] = set()
    for role in REQUIRED_ROLES:
        permissions = require_list(matrix.get(role), f"permission matrix {role}", 1)
        normalized = {str(permission).lower() for permission in permissions}
        if "*" in normalized or "all" in normalized or "admin_all" in normalized:
            reject("permission matrix grants wildcard authority")
        all_permissions |= normalized
    for permission in [
        "admit_issue_for_dispatch",
        "approve_sensitive_gate",
        "dispatch_admitted_ticket",
        "execute_worker_route",
        "approve_credential_grant",
        "review_audit_package",
        "execute_emergency_action_with_explicit_approval",
    ]:
        if permission not in all_permissions:
            reject(f"permission matrix missing {permission}")

    admission = " ".join(str(item).lower() for item in require_list(payload.get("admissionChecks"), "admission checks", 8))
    for term in ["tenant", "project", "status", "role", "acceptance criteria", "permission level", "approval", "repository", "worker route", "cross-tenant"]:
        if term not in admission:
            reject(f"admission checks missing {term}")

    authorization = " ".join(str(item).lower() for item in require_list(payload.get("authorizationChecks"), "authorization checks", 8))
    for term in ["tenant", "github project", "repository", "actor role", "permission matrix", "credential broker", "worker route", "audit evidence"]:
        if term not in authorization:
            reject(f"authorization checks missing {term}")

    scopes = require_dict(payload.get("scopeMappings"), "scope mappings")
    project_scope = " ".join(str(item).lower() for item in require_list(scopes.get("githubProject"), "GitHub Project scope mapping", 5))
    repo_scope = " ".join(str(item).lower() for item in require_list(scopes.get("repository"), "repository scope mapping", 5))
    for term in ["project id", "tenant", "status", "admission", "authorized-by", "route"]:
        if term not in project_scope:
            reject(f"GitHub Project scope mapping missing {term}")
    for term in ["owner/name", "branch", "pr checks", "submodule", "credential", "evidence"]:
        if term not in repo_scope:
            reject(f"repository scope mapping missing {term}")

    credential = require_dict(payload.get("credentialBoundary"), "credential boundary")
    credential_text = text_join(credential).lower()
    for term in ["brokered", "task-scoped", "tenant-scoped", "time-bound", "least-privilege", "expiration", "revocation", "approval evidence"]:
        if term not in credential_text:
            reject(f"credential boundary missing {term}")
    for term in ["manager pat", "oauth token", "ssh key", "cloud credential", "kubeconfig", "github app private key"]:
        if term not in credential_text:
            reject(f"credential boundary missing forbidden material {term}")

    route = require_dict(payload.get("workerRouteBoundary"), "worker route boundary")
    route_text = text_join(route).lower()
    for term in ["local_worktree", "ssh", "docker", "kubernetes_job", "approval", "result evidence"]:
        if term not in route_text:
            reject(f"worker route boundary missing {term}")

    break_glass = require_dict(payload.get("breakGlassPath"), "break-glass path")
    required_fields = " ".join(str(item).lower() for item in require_list(break_glass.get("requiredFields"), "break-glass required fields", 10))
    for term in ["incident id", "human approver", "permitted actor", "affected tenant", "expiration", "post-incident review", "audit package"]:
        if term not in required_fields:
            reject(f"break-glass path missing {term}")
    if "not allowed" not in str(break_glass.get("standingAccess", "")).lower():
        reject("break-glass path must forbid standing access")

    review = require_dict(payload.get("accessReview"), "access review")
    review_text = text_join(review).lower()
    for term in ["quarterly", "tenant admin", "security admin", "auditor", "credential grants", "worker route grants", "revoked members", "next action"]:
        if term not in review_text:
            reject(f"access review missing {term}")

    audit = " ".join(str(item).lower() for item in require_list(payload.get("auditEvidence"), "audit evidence", 8))
    for term in ["tenant", "actor role", "requested permission", "admission decision", "authorization decision", "approval-gate", "credential broker", "worker route", "residual risk"]:
        if term not in audit:
            reject(f"audit evidence missing {term}")

    lifecycle = require_dict(payload.get("onboardingOffboarding"), "onboarding/offboarding")
    onboarding = " ".join(str(item).lower() for item in require_list(lifecycle.get("onboarding"), "onboarding", 5))
    offboarding = " ".join(str(item).lower() for item in require_list(lifecycle.get("offboarding"), "offboarding", 5))
    for term in ["tenant assignment", "role assignment", "credential policy", "access review"]:
        if term not in onboarding:
            reject(f"onboarding missing {term}")
    for term in ["role removal", "credential revocation", "worker route", "project", "repository", "audit"]:
        if term not in offboarding:
            reject(f"offboarding missing {term}")

    failure = " ".join(str(item).lower() for item in require_list(payload.get("failureHandling"), "failure handling", 8))
    for term in ["tenant", "role", "permission", "admission", "authorization", "credential", "worker route", "break-glass", "access review"]:
        if term not in failure:
            reject(f"failure handling missing {term}")

    gaps = " ".join(str(item).lower() for item in require_list(payload.get("remainingOperationalGaps"), "remaining operational gaps", 3))
    for term in ["runtime enforcement", "access-review", "cross-tenant", "credential", "github project"]:
        if term not in gaps:
            reject(f"remaining operational gaps missing {term}")


doc_text = Path(sys.argv[1]).read_text(encoding="utf-8")
baseline = extract_payload(doc_text)
validate_payload(baseline)


def expect_reject(name: str, candidate: str | dict[str, Any]) -> None:
    try:
        if isinstance(candidate, str):
            validate_payload(extract_payload(candidate))
        else:
            validate_payload(candidate)
    except RbacError:
        return
    reject(f"negative fixture unexpectedly passed: {name}")


expect_reject("empty design", "")
expect_reject(
    "malformed RBAC data",
    START + "\n```json\n{\"version\": \n```\n" + END,
)

for field in REQUIRED_TOP_LEVEL:
    mutated = copy.deepcopy(baseline)
    mutated[field] = [] if isinstance(mutated.get(field), list) else ""
    expect_reject(f"missing {field}", mutated)

mutated = copy.deepcopy(baseline)
mutated["scopeMappings"]["githubProject"] = []
expect_reject("missing GitHub Project scope mapping", mutated)

mutated = copy.deepcopy(baseline)
mutated["scopeMappings"]["repository"] = []
expect_reject("missing repository scope mapping", mutated)

mutated = copy.deepcopy(baseline)
mutated["onboardingOffboarding"]["onboarding"] = []
expect_reject("missing onboarding", mutated)

mutated = copy.deepcopy(baseline)
mutated["onboardingOffboarding"]["offboarding"] = []
expect_reject("missing offboarding", mutated)

mutated = copy.deepcopy(baseline)
mutated["securityBoundary"] = baseline["securityBoundary"] + " credential mutation authorized"
expect_reject("unauthorized sensitive mutation wording", mutated)

mutated = copy.deepcopy(baseline)
mutated["permissionMatrix"]["fire_operator"] = ["*"]
expect_reject("wildcard permission", mutated)

print("PASS Dokkaebi multi-tenant RBAC validation passed")
PY
