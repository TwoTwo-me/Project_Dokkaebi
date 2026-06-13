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

DOC_PATH="${CREDENTIAL_LIFECYCLE_PATH:-docs/policies/credential-lifecycle-and-revocation.md}"

for term in \
  "token classes" "owners" "storage" "rotation" "revocation" \
  "audit evidence" "development and sandbox auth exception" \
  "dry-run revocation checklist" "approval-gate status" \
  "cleanup receipt" "residual risk" "next action" "does not authorize"; do
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

JsonValue = None | bool | int | float | str | list["JsonValue"] | dict[str, "JsonValue"]
JsonObject = dict[str, JsonValue]

START = "<!-- credential-lifecycle:begin -->"
END = "<!-- credential-lifecycle:end -->"
REQUIRED_CLASSES = {
    "manager_github_credential",
    "broker_grant_bundle",
    "worker_route_credential",
    "ssh_worker_access",
    "future_cloud_or_container_credential",
}
HOME_SEGMENT, USERS_SEGMENT = "/" + "home" + "/", "/" + "users" + "/"
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
UNSAFE_PHRASES = [
    "credential used",
    "credential issued",
    "credential rotated",
    "credential revoked",
    "broker mutation completed",
    "deployment executed",
    "github project control-plane mutation completed",
    "infrastructure mutated",
    "production write completed",
    "worker scaled",
]


class CredentialLifecycleError(Exception):
    pass


def reject(message: str) -> None:
    raise CredentialLifecycleError(message)


def extract_payload(text: str) -> JsonObject:
    if not text.strip():
        reject("empty credential lifecycle content")
    if START not in text or END not in text:
        reject("missing credential lifecycle block")
    block = text.split(START, 1)[1].split(END, 1)[0].strip()
    if block.startswith("```json"):
        block = block.removeprefix("```json").strip()
    if block.endswith("```"):
        block = block[: -len("```")].strip()
    try:
        payload = json.loads(block)
    except json.JSONDecodeError as exc:
        reject(f"malformed credential lifecycle data: {exc}")
    if not isinstance(payload, dict):
        reject("credential lifecycle block must be an object")
    return payload


def require_nonempty(value: JsonValue, label: str) -> JsonValue:
    if value in (None, "", [], {}):
        reject(f"missing {label}")
    return value


def require_object(value: JsonValue, label: str) -> JsonObject:
    if not isinstance(value, dict):
        reject(f"missing {label}")
    return value


def require_list(value: JsonValue, label: str, minimum: int = 1) -> list[JsonValue]:
    if not isinstance(value, list) or len(value) < minimum:
        reject(f"missing {label}")
    return value


def flattened_strings(value: JsonValue) -> list[str]:
    if isinstance(value, str):
        return [value]
    if isinstance(value, list):
        return [text for item in value for text in flattened_strings(item)]
    if isinstance(value, dict):
        return [text for item in value.values() for text in flattened_strings(item)]
    return []


def require_safe_text(payload: JsonObject) -> None:
    lowered = "\n".join(flattened_strings(payload)).lower()
    for term in SECRET_TERMS:
        if term in lowered:
            reject(f"secret-bearing evidence wording: {term}")
    for phrase in UNSAFE_PHRASES:
        if phrase in lowered:
            reject(f"unsafe credential authority wording: {phrase}")
    if PRIVATE_PATH_RE.search(lowered):
        reject("private local path retained")
    if INTERNAL_LABEL_RE.search(lowered):
        reject("internal execution label retained")


def validate_class(item: JsonObject) -> str:
    class_id = require_nonempty(item.get("id"), "credential class id")
    if not isinstance(class_id, str):
        reject("credential class id must be a string")
    for field in ["name", "owner", "storage", "rotationCadence"]:
        require_nonempty(item.get(field), f"{class_id} {field}")
    require_list(item.get("revocationTriggers"), f"{class_id} revocation triggers", 3)
    audit = require_list(item.get("auditEvidence"), f"{class_id} audit evidence", 3)
    audit_text = " ".join(str(value).lower() for value in audit)
    for term in ["owner", "scope", "expiry", "approval", "cleanup", "receipt", "revocation"]:
        if term in {"cleanup", "receipt"} and class_id != "worker_route_credential":
            continue
        if term not in audit_text and term not in str(item).lower():
            reject(f"{class_id} audit evidence missing {term}")
    if item.get("rawSecretRetained") is not False:
        reject(f"{class_id} must not retain raw secrets")
    return class_id


def validate_payload(payload: JsonObject) -> None:
    for field in [
        "version",
        "permissionLevel",
        "approvalBoundary",
        "credentialClasses",
        "developmentSandboxException",
        "dryRunRevocationChecklist",
        "auditEvidence",
        "residualRisk",
        "followUpIssueUrl",
    ]:
        require_nonempty(payload.get(field), field)
    if payload.get("permissionLevel") != "docs-only credential lifecycle and revocation dry-run":
        reject("permissionLevel must remain docs-only credential lifecycle and revocation dry-run")
    boundary = str(payload.get("approvalBoundary", "")).lower()
    for term in ["credential use", "broker mutation", "infrastructure", "worker", "production", "explicit human approval"]:
        if term not in boundary:
            reject(f"approval boundary missing {term}")

    classes = require_list(payload.get("credentialClasses"), "credential classes", len(REQUIRED_CLASSES))
    seen = {validate_class(require_object(item, "credential class")) for item in classes}
    missing = REQUIRED_CLASSES - seen
    if missing:
        reject("missing credential classes: " + ", ".join(sorted(missing)))

    exception = require_object(payload.get("developmentSandboxException"), "development sandbox exception")
    exception_text = " ".join(flattened_strings(exception)).lower()
    for term in ["narrow", "explicitly approved", "development", "sandbox", "trusted", "duration", "cleanup", "approval evidence"]:
        if term not in exception_text:
            reject(f"development sandbox exception missing {term}")
    for forbidden in ["production access", "broad worker access", "infrastructure mutation", "deployment", "control-plane mutation"]:
        if forbidden not in exception_text:
            reject(f"development sandbox exception missing forbidden scope {forbidden}")

    checklist_text = " ".join(str(item).lower() for item in require_list(payload.get("dryRunRevocationChecklist"), "dry-run revocation checklist", 6))
    for term in ["owner", "scope", "expiry", "revocation condition", "no raw secret", "simulate", "approval-gate status", "cleanup receipt", "fail closed"]:
        if term not in checklist_text:
            reject(f"dry-run checklist missing {term}")
    audit_text = " ".join(str(item).lower() for item in require_list(payload.get("auditEvidence"), "audit evidence", 8))
    for term in ["owner", "credential class", "scope", "storage", "rotation", "revocation", "approval-gate status", "cleanup receipt"]:
        if term not in audit_text:
            reject(f"audit evidence missing {term}")
    require_list(payload.get("residualRisk"), "residual risk", 3)
    follow_up = str(payload.get("followUpIssueUrl", ""))
    if not follow_up.startswith("https://github.com/"):
        reject("follow-up issue URL must be a GitHub URL")
    require_safe_text(payload)


doc_text = Path(sys.argv[1]).read_text(encoding="utf-8")
baseline = extract_payload(doc_text)
validate_payload(baseline)


def expect_reject(name: str, candidate: str | JsonObject) -> None:
    try:
        if isinstance(candidate, str):
            validate_payload(extract_payload(candidate))
        else:
            validate_payload(candidate)
    except CredentialLifecycleError:
        return
    reject(f"negative fixture unexpectedly passed: {name}")


def set_path(payload: JsonObject, path: tuple[str, ...], value: JsonValue) -> None:
    target = payload
    for key in path[:-1]:
        next_target = target[key]
        if not isinstance(next_target, dict):
            reject("negative fixture path is not an object")
        target = next_target
    target[path[-1]] = value


expect_reject("empty credential lifecycle content", "")
expect_reject("malformed credential lifecycle data", START + "\n```json\n{\"version\": \n```\n" + END)

for field in ["approvalBoundary", "credentialClasses", "developmentSandboxException", "dryRunRevocationChecklist", "auditEvidence", "residualRisk", "followUpIssueUrl"]:
    mutated = copy.deepcopy(baseline)
    mutated[field] = ""
    expect_reject(f"missing {field}", mutated)

for class_id in sorted(REQUIRED_CLASSES):
    mutated = copy.deepcopy(baseline)
    mutated["credentialClasses"] = [item for item in mutated["credentialClasses"] if item["id"] != class_id]
    expect_reject(f"missing credential class {class_id}", mutated)

for name, field in [
    ("missing owner", "owner"),
    ("missing storage", "storage"),
    ("missing rotation", "rotationCadence"),
    ("missing revocation triggers", "revocationTriggers"),
    ("missing audit evidence", "auditEvidence"),
]:
    mutated = copy.deepcopy(baseline)
    first = require_object(require_list(mutated.get("credentialClasses"), "credential classes")[0], "credential class")
    first[field] = []
    expect_reject(name, mutated)

for name, path, value in [
    ("raw secret retained", ("credentialClasses",), [{**baseline["credentialClasses"][0], "rawSecretRetained": True}]),
    ("unsafe credential authority wording", ("approvalBoundary",), "credential used and broker mutation completed"),
    ("private local path", ("dryRunRevocationChecklist",), [HOME_SEGMENT + "sam/.ssh/id_rsa retained"]),
    ("internal execution label", ("auditEvidence",), ["run " + INTERNAL_LABELS[0] + " workflow"]),
]:
    mutated = copy.deepcopy(baseline)
    set_path(mutated, path, value)
    expect_reject(name, mutated)

print("PASS Dokkaebi credential lifecycle validation passed")
PY
