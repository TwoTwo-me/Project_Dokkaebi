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

DOC_PATH="${MULTI_TENANT_RBAC_DRILL_PATH:-docs/policies/multi-tenant-rbac-drill-2026-06-13.md}"

for term in \
  "local replay" "admission decision output" "authorization decision output" \
  "denied cross-tenant operation evidence" "credential grant boundary evidence" \
  "worker route boundary evidence" "audit log evidence" "access-review evidence" \
  "approval-gate status" "cleanup" "residual risk" "next action" "does not authorize"; do
  require_text "$DOC_PATH" "$term"
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

START = "<!-- multi-tenant-rbac-drill:begin -->"
END = "<!-- multi-tenant-rbac-drill:end -->"
ROLE_EXPECTATIONS = {"project_owner": ("admit_issue_for_dispatch", "allow"), "tenant_admin": ("manage_tenant_membership", "allow"), "issue_approver": ("approve_sensitive_gate", "allow"), "fire_operator": ("dispatch_admitted_ticket", "allow"), "hammer_operator": ("execute_worker_route", "allow"), "security_admin": ("approve_credential_grant", "deny"), "auditor": ("review_audit_package", "allow"), "break_glass_operator": ("execute_emergency_action_with_explicit_approval", "deny")}
REQUIRED_ROLES = set(ROLE_EXPECTATIONS)
REQUIRED_TOP = ["drillId", "date", "permissionLevel", "sourcePolicy", "tenantScopes", "actorFlowResults", "admissionDecisionOutput", "authorizationDecisionOutput", "deniedCrossTenantOperationEvidence", "credentialGrantBoundaryEvidence", "workerRouteBoundaryEvidence", "auditLogEvidence", "accessReviewEvidence", "approvalGateStatus", "cleanup", "residualRisk", "nextAction", "followUpIssueUrl"]
HOME_SEGMENT, USERS_SEGMENT = "/" + "home" + "/", "/" + "users" + "/"
PRIVATE_PATH_RE = re.compile(r"(?i)(" + re.escape(HOME_SEGMENT) + "|" + re.escape(USERS_SEGMENT) + r")[^\s`'\"]+")
INTERNAL_LABELS = ["".join(parts) for parts in [("o", "mo"), ("o", "mx"), ("u", "lw")]]
INTERNAL_LABEL_RE = re.compile(r"\b(" + "|".join(INTERNAL_LABELS) + r")\b", re.IGNORECASE)
SECRET_TERMS = ["cookie=", "private" + "_key=", "sec" + "ret=", "to" + "ken=", "authorization: bearer", "-----begin private key-----"]
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


class DrillError(Exception):
    pass


def reject(message: str) -> None:
    raise DrillError(message)


def extract_payload(text: str) -> dict[str, Any]:
    if not text.strip():
        reject("empty RBAC drill content")
    if text.count(START) != 1 or text.count(END) != 1:
        reject("missing or duplicate RBAC drill block")
    start, end = text.index(START), text.index(END)
    if end < start:
        reject("RBAC drill block markers out of order")
    block = text[start + len(START) : end].strip()
    if block.startswith("```json"):
        block = block.removeprefix("```json").strip()
    if block.endswith("```"):
        block = block[: -len("```")].strip()
    try:
        payload = json.loads(block)
    except json.JSONDecodeError as exc:
        reject(f"malformed RBAC drill data: {exc}")
    if not isinstance(payload, dict):
        reject("RBAC drill block must be an object")
    return payload


def require_nonempty(value: Any, label: str) -> Any:
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


def text_join(value: Any) -> str:
    if isinstance(value, dict):
        return " ".join(f"{key} {text_join(val)}" for key, val in value.items())
    if isinstance(value, list):
        return " ".join(text_join(item) for item in value)
    return str(value)


def require_safe_text(payload: dict[str, Any]) -> None:
    lowered = text_join(payload).lower()
    for term in SECRET_TERMS:
        if term in lowered:
            reject(f"secret-bearing evidence wording: {term}")
    for phrase in UNSAFE_PHRASES:
        if phrase in lowered:
            reject(f"unsafe mutation wording: {phrase}")
    if PRIVATE_PATH_RE.search(lowered):
        reject("private local path retained")
    if INTERNAL_LABEL_RE.search(lowered):
        reject("internal execution label retained")


def validate_tenant_scopes(scopes: list[Any]) -> set[str]:
    tenant_ids: set[str] = set()
    for item in scopes:
        scope = require_dict(item, "tenant scope")
        tenant_id = str(require_nonempty(scope.get("tenantId"), "tenant scope tenantId"))
        if tenant_id in tenant_ids:
            reject("duplicate tenant scope")
        tenant_ids.add(tenant_id)
        require_list(scope.get("repositories"), "tenant scope repositories")
        require_list(scope.get("githubProjects"), "tenant scope GitHub Projects")
        require_list(scope.get("allowedWorkerRoutes"), "tenant scope worker routes")
    return tenant_ids


def validate_actor_flows(flows: list[Any], tenant_ids: set[str]) -> set[str]:
    roles: set[str] = set(); audit_ids: set[str] = set()
    for item in flows:
        flow = require_dict(item, "actor flow")
        role = str(require_nonempty(flow.get("actorRole"), "actor role"))
        if role not in ROLE_EXPECTATIONS:
            reject(f"unknown actor role: {role}")
        roles.add(role)
        for field in ["tenant", "requestedPermission", "admissionDecision", "authorizationDecision", "auditEvidenceId"]:
            require_nonempty(flow.get(field), f"actor flow {field}")
        if flow.get("tenant") not in tenant_ids:
            reject("actor flow tenant outside tenant scopes")
        expected_permission, expected_decision = ROLE_EXPECTATIONS[role]
        if flow.get("requestedPermission") != expected_permission:
            reject(f"actor flow {role} permission mismatch")
        for field in ["admissionDecision", "authorizationDecision"]:
            decision = str(flow.get(field, "")).lower().strip()
            if not decision.startswith(expected_decision + ":"):
                reject(f"actor flow {role} {field} mismatch")
        if str(flow.get("requestedPermission")).strip() in {"*", "all", "admin_all"}:
            reject("wildcard permission requested")
        audit_id = str(flow["auditEvidenceId"])
        if audit_id in audit_ids:
            reject("duplicate actor audit evidence id")
        audit_ids.add(audit_id)
    missing = REQUIRED_ROLES - roles
    if missing:
        reject("actor flows missing " + ", ".join(sorted(missing)))
    return audit_ids


def validate_payload(payload: dict[str, Any]) -> None:
    for field in REQUIRED_TOP:
        require_nonempty(payload.get(field), field)
    if payload.get("permissionLevel") != "docs-only-local-replay":
        reject("permissionLevel must remain docs-only-local-replay")
    if payload.get("sourcePolicy") != "docs/policies/multi-tenant-rbac.md":
        reject("source policy must point to the RBAC model")
    if payload.get("followUpIssueUrl") != "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/74":
        reject("follow-up issue URL must point to issue #74")
    tenant_ids = validate_tenant_scopes(require_list(payload.get("tenantScopes"), "tenant scopes", 2))
    actor_audit_ids = validate_actor_flows(require_list(payload.get("actorFlowResults"), "actor flows", len(REQUIRED_ROLES)), tenant_ids)

    admission = " ".join(str(item).lower() for item in require_list(payload.get("admissionDecisionOutput"), "admission decision output", 4))
    authorization = " ".join(str(item).lower() for item in require_list(payload.get("authorizationDecisionOutput"), "authorization decision output", 4))
    for term in ["allow", "deny", "tenant", "project", "repository", "approval", "worker route"]:
        if term not in admission:
            reject(f"admission decision output missing {term}")
    for term in ["allow", "deny", "tenant", "role", "permission", "credential", "worker route", "cross-tenant"]:
        if term not in authorization:
            reject(f"authorization decision output missing {term}")

    cross = require_dict(payload.get("deniedCrossTenantOperationEvidence"), "denied cross-tenant operation evidence")
    for field in ["sourceTenant", "targetTenant", "requestedRepository", "requestedPermission", "decision", "reason"]:
        require_nonempty(cross.get(field), f"cross-tenant evidence {field}")
    if str(cross.get("decision")).lower() != "deny":
        reject("cross-tenant operation must be denied")

    credential = require_dict(payload.get("credentialGrantBoundaryEvidence"), "credential grant boundary evidence")
    if credential.get("secretMaterialIncluded") is not False:
        reject("credential grant boundary evidence must exclude secret material")
    credential_text = text_join(credential).lower()
    for term in ["deny", "brokered", "task-scoped", "tenant-scoped", "time-bound", "least-privilege", "expiration", "revocation", "approval evidence"]:
        if term not in credential_text:
            reject(f"credential grant boundary evidence missing {term}")

    route = require_dict(payload.get("workerRouteBoundaryEvidence"), "worker route boundary evidence")
    for field in ["local_worktree", "ssh", "docker", "kubernetes_job", "routeExpansion"]:
        require_nonempty(route.get(field), f"worker route boundary evidence {field}")
    route_text = text_join(route).lower()
    for term in ["local_worktree", "ssh", "docker", "kubernetes_job", "deny", "approval", "result evidence"]:
        if term not in route_text:
            reject(f"worker route boundary evidence missing {term}")

    audit = require_list(payload.get("auditLogEvidence"), "audit log evidence", len(actor_audit_ids))
    audit_ids: set[str] = set()
    for item in audit:
        entry = require_dict(item, "audit log entry")
        for field in ["id", "tenant", "actorRole", "requestedPermission", "admissionDecision", "authorizationDecision", "approvalGateStatus", "credentialBroker", "workerRoute", "residualRisk"]:
            require_nonempty(entry.get(field), f"audit log {field}")
        if entry["id"] in audit_ids:
            reject("duplicate audit log id")
        audit_ids.add(str(entry["id"]))
    if not actor_audit_ids.issubset(audit_ids):
        reject("audit log evidence missing actor flow audit ids")

    review = require_dict(payload.get("accessReviewEvidence"), "access-review evidence")
    for field in ["reviewId", "tenant", "reviewer", "cadence", "decision", "nextAction"]:
        require_nonempty(review.get(field), f"access-review evidence {field}")
    for field in ["roleAssignments", "highRiskGrants", "credentialGrants", "workerRouteGrants", "revokedMembers"]:
        require_list(review.get(field), f"access-review evidence {field}")
    review_text = text_join(review).lower()
    for term in ["tenant", "reviewer", "quarterly", "role", "high-risk", "credential", "worker route", "revoked", "decision", "next action"]:
        if term not in review_text:
            reject(f"access-review evidence missing {term}")

    approval = str(payload.get("approvalGateStatus")).lower()
    if "no live" not in approval or "mutation reached" not in approval or "not authorized" not in approval:
        reject("approval-gate status must state no live mutation reached")
    cleanup = require_dict(payload.get("cleanup"), "cleanup")
    if cleanup.get("status") != "complete":
        reject("cleanup must be complete")
    require_nonempty(cleanup.get("receipt"), "cleanup receipt")
    require_list(payload.get("residualRisk"), "residual risk", 3)
    require_nonempty(payload.get("nextAction"), "next action")
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
    except DrillError:
        return
    reject(f"negative fixture unexpectedly passed: {name}")


expect_reject("empty RBAC drill content", "")
expect_reject("malformed RBAC drill data", START + "\n```json\n{\"version\": \n```\n" + END)
expect_reject("markers out of order", END + "\n" + START + "\n{}\n")
expect_reject("duplicate drill blocks", doc_text + "\n" + START + "\n{}\n" + END)

for field in REQUIRED_TOP:
    mutated = copy.deepcopy(baseline)
    mutated[field] = [] if isinstance(mutated.get(field), list) else ""
    expect_reject(f"missing {field}", mutated)

mutated = copy.deepcopy(baseline)
mutated["tenantScopes"] = [{"tenantId": "tenant-alpha"}]
expect_reject("incomplete tenant scope", mutated)

for role in sorted(REQUIRED_ROLES):
    mutated = copy.deepcopy(baseline)
    mutated["actorFlowResults"] = [flow for flow in mutated["actorFlowResults"] if flow.get("actorRole") != role]
    expect_reject(f"missing actor flow {role}", mutated)

mutation_cases = [
    ("cross-tenant allowed", ("deniedCrossTenantOperationEvidence", "decision"), "allow"),
    ("credential secret material included", ("credentialGrantBoundaryEvidence", "secretMaterialIncluded"), True),
    ("actor tenant outside scope", ("actorFlowResults", 0, "tenant"), "tenant-gamma"),
    ("actor role permission mismatch", ("actorFlowResults", 0, "requestedPermission"), "review_audit_package"),
    ("mixed actor decision", ("actorFlowResults", 0, "admissionDecision"), "deny: inconsistent actor flow"),
    ("missing audit id", ("auditLogEvidence", 0, "id"), ""),
    ("duplicate audit id", ("auditLogEvidence", 1, "id"), "audit-rbac-001"),
    ("bare follow-up URL", ("followUpIssueUrl",), "https://github.com/"),
    ("wildcard permission", ("actorFlowResults", 0, "requestedPermission"), "*"),
    ("worker route missing docker", ("workerRouteBoundaryEvidence", "docker"), ""),
    ("audit missing authorization", ("auditLogEvidence", 0, "authorizationDecision"), ""),
    ("access review missing revoked", ("accessReviewEvidence", "revokedMembers"), []),
    ("cleanup incomplete", ("cleanup", "status"), "pending"),
    ("unsafe wording", ("nextAction",), "production write completed"),
    ("private path", ("nextAction",), HOME_SEGMENT + "private/export"),
    ("internal label", ("nextAction",), "".join(("o", "mo"))),
    ("secret wording", ("nextAction",), "".join(("to", "ken=", "example"))),
]
for name, path, value in mutation_cases:
    mutated = copy.deepcopy(baseline)
    target: Any = mutated
    for key in path[:-1]:
        target = target[key]
    target[path[-1]] = value
    expect_reject(name, mutated)

print("PASS Dokkaebi multi-tenant RBAC drill validation passed")
PY
