#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}

DOC_PATH="${WORKER_ROUTE_HEALTH_BOOTSTRAP_PATH:-docs/operations/worker-route-health-bootstrap-2026-06-14.md}"

[[ -f "$DOC_PATH" ]] || fail "missing file: $DOC_PATH"

for term in \
  "Worker Route Health And Bootstrap Rebuild Evidence" \
  "local worktree" \
  "SSH worker" \
  "Docker worker" \
  "Kubernetes Job" \
  "capability detection" \
  "dispatch eligibility" \
  "skip reasons" \
  "cleanup rules" \
  "Bootstrap Rebuild Check" \
  "approval-gate status" \
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
from datetime import datetime
from pathlib import Path
from typing import Any

START = "<!-- worker-route-health-bootstrap:begin -->"
END = "<!-- worker-route-health-bootstrap:end -->"
REQUIRED_PROVIDERS = ["local_worktree", "ssh_worker", "docker_worker", "kubernetes_job"]
HOME_SEGMENT = "/" + "home" + "/"
USERS_SEGMENT = "/" + "Users" + "/"
PRIVATE_PATH_RE = re.compile(r"(" + re.escape(HOME_SEGMENT) + "|" + re.escape(USERS_SEGMENT) + r")[^\s`'\"]+")
INTERNAL_LABELS = ["".join(parts) for parts in [("o", "mo"), ("o", "mx"), ("u", "lw")]]
INTERNAL_LABEL_RE = re.compile(r"\b(" + "|".join(INTERNAL_LABELS) + r")\b", re.IGNORECASE)
SECRET_TERMS = ["cookie=", "private_key=", "sec" + "ret=", "to" + "ken=", "authorization: " + "bearer"]
UNSAFE_PHRASES = [
    "production route enabled",
    "credential copied",
    "credential expanded",
    "remote filesystem mutation completed",
    "docker mutation completed",
    "kubernetes mutation completed",
    "proxmox mutation completed",
    "deployment executed",
    "infrastructure mutated",
    "github project control-plane mutation completed",
]


class RouteHealthError(Exception):
    pass


def reject(message: str) -> None:
    raise RouteHealthError(message)


def extract_payload(text: str) -> dict[str, Any]:
    if not text.strip():
        reject("empty worker route health content")
    if text.count(START) != 1 or text.count(END) != 1:
        reject("missing or duplicate worker route health block")
    block = text.split(START, 1)[1].split(END, 1)[0].strip()
    if block.startswith("```json"):
        block = block.removeprefix("```json").strip()
    if block.endswith("```"):
        block = block[: -len("```")].strip()
    try:
        payload = json.loads(block)
    except json.JSONDecodeError as exc:
        reject(f"malformed worker route health data: {exc}")
    if not isinstance(payload, dict):
        reject("worker route health block must be an object")
    return payload


def require_text(value: Any, label: str, terms: list[str] | None = None) -> str:
    if not isinstance(value, str) or not value.strip():
        reject(f"missing {label}")
    lowered = value.lower()
    for term in terms or []:
        if term.lower() not in lowered:
            reject(f"{label} missing {term}")
    return value


def require_dict(value: Any, label: str) -> dict[str, Any]:
    if not isinstance(value, dict) or not value:
        reject(f"missing {label}")
    return value


def require_list(value: Any, label: str, min_items: int = 1) -> list[Any]:
    if not isinstance(value, list) or len(value) < min_items:
        reject(f"missing {label}")
    return value


def require_date(value: Any, label: str) -> None:
    text = require_text(value, label)
    try:
        datetime.fromisoformat(text)
    except ValueError:
        reject(f"invalid {label}")


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
    lowered = original.lower()
    for term in SECRET_TERMS:
        if term in lowered:
            reject(f"secret-bearing wording: {term}")
    for phrase in UNSAFE_PHRASES:
        if phrase in lowered:
            reject(f"unsafe authority wording: {phrase}")
    if PRIVATE_PATH_RE.search(original):
        reject("private local path retained")
    if INTERNAL_LABEL_RE.search(original):
        reject("private execution label retained")


def validate_route(route: dict[str, Any], provider: str) -> None:
    if route.get("provider") != provider:
        reject(f"route provider order mismatch: expected {provider}")
    require_text(route.get("target"), f"{provider} target")
    require_text(route.get("evidenceSource"), f"{provider} evidence source", ["captured"])
    checks = require_list(route.get("capabilityDetection"), f"{provider} capability detection", 3)
    for check in checks:
        check_obj = require_dict(check, f"{provider} capability check")
        require_text(check_obj.get("check"), f"{provider} capability check name")
        require_text(check_obj.get("result"), f"{provider} capability check result")

    eligibility = require_dict(route.get("dispatchEligibility"), f"{provider} dispatch eligibility")
    status = require_text(eligibility.get("status"), f"{provider} dispatch eligibility status")
    if not status.startswith("eligible_"):
        reject(f"{provider} dispatch eligibility must be explicit and eligible")
    require_text(eligibility.get("reason"), f"{provider} dispatch eligibility reason")

    skip_reasons = require_list(route.get("skipReasons"), f"{provider} skip reasons")
    cleanup_rules = require_list(route.get("cleanupRules"), f"{provider} cleanup rules")
    if not any("skip" in str(reason).lower() for reason in skip_reasons):
        reject(f"{provider} skip reasons must name a skipped case")
    if not any("cleanup" in str(rule).lower() or "remove" in str(rule).lower() for rule in cleanup_rules):
        reject(f"{provider} cleanup rules must include cleanup or removal")


def validate_payload(payload: dict[str, Any]) -> None:
    if payload.get("version") != 1:
        reject("version must be 1")
    if payload.get("issueUrl") != "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/103":
        reject("issueUrl must point to issue #103")
    require_text(payload.get("reportId"), "report id", ["issue-103", "worker-route"])
    require_date(payload.get("evidenceDate"), "evidence date")
    require_text(payload.get("permissionLevel"), "permission level", ["development", "approved", "sandbox", "read-only"])

    approval = require_text(payload.get("approvalGateStatus"), "approval-gate status")
    for term in [
        "no production",
        "credential",
        "proxmox",
        "deployment",
        "infrastructure",
        "github project control-plane",
        "docker",
        "kubernetes",
        "remote filesystem",
        "explicit human approval",
    ]:
        if term not in approval.lower():
            reject(f"approval-gate status missing {term}")

    policy = require_dict(payload.get("preflightPolicy"), "preflight policy")
    require_text(policy.get("mode"), "preflight mode", ["read-only", "capability"])
    no_mutation = require_list(policy.get("noMutation"), "no mutation list", 5)
    for term in ["Docker", "Kubernetes", "SSH", "credentials", "production"]:
        if not any(term.lower() in str(item).lower() for item in no_mutation):
            reject(f"no mutation list missing {term}")
    require_text(policy.get("redaction"), "redaction policy", ["secrets", "private"])

    routes = require_list(payload.get("routes"), "routes", len(REQUIRED_PROVIDERS))
    providers = [route.get("provider") for route in routes if isinstance(route, dict)]
    if providers != REQUIRED_PROVIDERS:
        reject("routes must include local_worktree, ssh_worker, docker_worker, kubernetes_job in order")
    for provider, route in zip(REQUIRED_PROVIDERS, routes):
        validate_route(require_dict(route, f"{provider} route"), provider)

    bootstrap = require_dict(payload.get("bootstrapRebuild"), "bootstrap rebuild proof")
    require_text(bootstrap.get("target"), "bootstrap target", ["Project Dokkaebi", "development workspace"])
    require_list(bootstrap.get("sourceOfTruth"), "bootstrap source of truth", 4)
    checked_state = require_dict(bootstrap.get("checkedState"), "bootstrap checked state")
    root_commit = require_text(checked_state.get("rootMainCommit"), "root main commit")
    submodule_commit = require_text(checked_state.get("submoduleCommit"), "submodule commit")
    if not re.fullmatch(r"[0-9a-f]{40}", root_commit):
        reject("root main commit must be a full SHA")
    if not re.fullmatch(r"[0-9a-f]{40}", submodule_commit):
        reject("submodule commit must be a full SHA")
    rebuild_commands = require_list(bootstrap.get("rebuildCommands"), "rebuild commands", 3)
    for command in [
        "git clone https://github.com/TwoTwo-me/Project_Dokkaebi",
        "git submodule update --init --recursive",
        "bash scripts/validate-worker-route-health-bootstrap.sh",
    ]:
        if command not in rebuild_commands:
            reject(f"missing rebuild command: {command}")
    validation_evidence = require_list(bootstrap.get("validationEvidence"), "bootstrap validation evidence", 4)
    for term in ["local", "SSH", "Docker", "Kubernetes"]:
        if not any(term.lower() in str(item).lower() for item in validation_evidence):
            reject(f"bootstrap validation evidence missing {term}")

    validation_output = require_list(payload.get("validationOutput"), "validation output", 4)
    for command in [
        "bash scripts/validate-worker-route-health-bootstrap.sh: PASS",
        "bash scripts/validate-readiness-criteria.sh: PASS",
        "bash scripts/validate-contract-docs.sh: PASS",
    ]:
        if command not in validation_output:
            reject(f"validation output missing {command}")

    readiness = require_dict(payload.get("readinessUpdate"), "readiness update")
    if readiness.get("area") != "infrastructure_platform":
        reject("readiness update must target infrastructure_platform")
    if readiness.get("currentPercent") != 100:
        reject("readiness update must set infrastructure_platform to 100")
    if readiness.get("closedIssueUrl") != "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/103":
        reject("readiness update must link issue #103")
    require_list(readiness.get("evidenceAdded"), "readiness evidence added", 2)

    cleanup = require_dict(payload.get("cleanupReceipt"), "cleanup receipt")
    for field in ["docker", "kubernetes", "ssh", "local"]:
        require_text(cleanup.get(field), f"cleanup receipt {field}")
    require_list(payload.get("residualRisk"), "residual risk")
    require_text(payload.get("nextAction"), "next action")
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
    except RouteHealthError:
        return
    reject(f"negative fixture unexpectedly passed: {name}")


expect_reject("empty content", "")
expect_reject(
    "malformed route data",
    START + "\n```json\n{\"version\": \n```\n" + END,
)

mutated = copy.deepcopy(baseline)
mutated["routes"] = mutated["routes"][:-1]
expect_reject("missing provider class", mutated)

mutated = copy.deepcopy(baseline)
mutated["routes"][0]["capabilityDetection"] = []
expect_reject("missing capability detection", mutated)

mutated = copy.deepcopy(baseline)
mutated["routes"][1]["dispatchEligibility"] = {}
expect_reject("missing dispatch eligibility", mutated)

mutated = copy.deepcopy(baseline)
mutated["routes"][2]["skipReasons"] = []
expect_reject("missing skip reasons", mutated)

mutated = copy.deepcopy(baseline)
mutated["routes"][3]["cleanupRules"] = []
expect_reject("missing cleanup rules", mutated)

mutated = copy.deepcopy(baseline)
mutated["approvalGateStatus"] = ""
expect_reject("missing approval-gate status", mutated)

mutated = copy.deepcopy(baseline)
mutated["bootstrapRebuild"] = {}
expect_reject("missing bootstrap rebuild proof", mutated)

mutated = copy.deepcopy(baseline)
mutated["validationOutput"] = []
expect_reject("missing validation output", mutated)

mutated = copy.deepcopy(baseline)
mutated["cleanupReceipt"]["docker"] = ""
expect_reject("missing cleanup receipt", mutated)

mutated = copy.deepcopy(baseline)
mutated["routes"][0]["target"] = HOME_SEGMENT + "example/private"
expect_reject("private local path", mutated)

mutated = copy.deepcopy(baseline)
mutated["routes"][0]["target"] = "to" + "ken=example"
expect_reject("secret-like evidence", mutated)

mutated = copy.deepcopy(baseline)
mutated["approvalGateStatus"] = "docker mutation completed"
expect_reject("unsafe mutation wording", mutated)

print("PASS Dokkaebi worker route health bootstrap validation passed")
PY
