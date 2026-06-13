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

DOC_PATH="${RUNTIME_QUALITY_GATES_PATH:-docs/enterprise-readiness/runtime-quality-gate-matrix.md}"

for term in \
  "orchestration" "credential" "GitHub adapter" "worker provider" "UI" \
  "required tests" "accepted risk" "approval-gate status" \
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

START = "<!-- runtime-quality-gates:begin -->"
END = "<!-- runtime-quality-gates:end -->"
REQUIRED_SURFACES = {"orchestration", "credential", "github_adapter", "worker_provider", "ui"}
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
    "deployment executed",
    "docker container started",
    "github project control-plane mutation completed",
    "infrastructure mutated",
    "kubernetes cluster mutated",
    "production write completed",
    "remote host changed",
    "worker scaled",
]


class QualityGateError(Exception):
    pass


def reject(message: str) -> None:
    raise QualityGateError(message)


def extract_payload(text: str) -> JsonObject:
    if not text.strip():
        reject("empty quality gate matrix")
    if START not in text or END not in text:
        reject("missing runtime quality gate block")
    block = text.split(START, 1)[1].split(END, 1)[0].strip()
    if block.startswith("```json"):
        block = block.removeprefix("```json").strip()
    if block.endswith("```"):
        block = block[: -len("```")].strip()
    try:
        payload = json.loads(block)
    except json.JSONDecodeError as exc:
        reject(f"malformed quality gate data: {exc}")
    if not isinstance(payload, dict):
        reject("runtime quality gate block must be an object")
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
            reject(f"unsafe authority wording: {phrase}")
    if PRIVATE_PATH_RE.search(lowered):
        reject("private local path retained")
    if INTERNAL_LABEL_RE.search(lowered):
        reject("internal execution label retained")


def validate_commands(commands: list[JsonValue], label: str) -> None:
    for command in commands:
        if not isinstance(command, str) or not command.startswith("bash scripts/"):
            reject(f"{label} must contain repository validation commands")


def validate_surface(surface: JsonObject) -> str:
    surface_id = require_nonempty(surface.get("id"), "surface id")
    if not isinstance(surface_id, str):
        reject("surface id must be a string")
    for field in ["name", "riskLevel", "owner", "nextAction"]:
        require_nonempty(surface.get(field), f"{surface_id} {field}")
    risk_level = str(surface.get("riskLevel", "")).lower()
    if risk_level not in {"critical", "high", "medium"}:
        reject(f"{surface_id} riskLevel must be critical, high, or medium")
    require_list(surface.get("riskClasses"), f"{surface_id} risk classes", 3)
    required_tests = require_list(surface.get("requiredTests"), f"{surface_id} required tests", 2)
    merge_commands = require_list(surface.get("mergeGateCommands"), f"{surface_id} merge gate commands", 2)
    require_list(surface.get("evidenceArtifacts"), f"{surface_id} evidence artifacts", 2)
    require_list(surface.get("acceptedRisk"), f"{surface_id} accepted risk", 1)
    validate_commands(required_tests, f"{surface_id} required tests")
    validate_commands(merge_commands, f"{surface_id} merge gate commands")
    return surface_id


def validate_payload(payload: JsonObject) -> None:
    for field in ["version", "permissionLevel", "approvalBoundary", "globalGates", "surfaces", "followUpIssueUrl"]:
        require_nonempty(payload.get(field), field)
    if payload.get("permissionLevel") != "docs-only quality gate matrix":
        reject("permissionLevel must remain docs-only quality gate matrix")
    boundary = str(payload.get("approvalBoundary", "")).lower()
    for term in ["credential", "infrastructure", "worker", "deployment", "production", "explicit human approval"]:
        if term not in boundary:
            reject(f"approval boundary missing {term}")

    global_gates = require_object(payload.get("globalGates"), "global gates")
    default_commands = require_list(global_gates.get("defaultCommands"), "default commands", 3)
    validate_commands(default_commands, "default commands")
    default_text = " ".join(str(item) for item in default_commands)
    for command in [
        "bash scripts/validate-readiness-criteria.sh",
        "bash scripts/validate-contract-docs.sh",
        "bash scripts/validate-git-governance.sh",
    ]:
        if command not in default_text:
            reject(f"default commands missing {command}")
    pr_evidence = " ".join(str(item).lower() for item in require_list(global_gates.get("prEvidence"), "PR evidence", 5))
    for term in ["targeted validation", "approval-gate status", "cleanup receipt", "accepted residual risk"]:
        if term not in pr_evidence:
            reject(f"PR evidence missing {term}")
    failure_text = " ".join(str(item).lower() for item in require_list(global_gates.get("failureHandling"), "failure handling", 4))
    for term in ["required tests", "accepted risk", "approval-gate status", "cleanup receipt", "authority wording"]:
        if term not in failure_text:
            reject(f"failure handling missing {term}")

    surfaces = require_list(payload.get("surfaces"), "surfaces", len(REQUIRED_SURFACES))
    seen = {validate_surface(require_object(surface, "surface")) for surface in surfaces}
    missing = REQUIRED_SURFACES - seen
    if missing:
        reject("missing required surfaces: " + ", ".join(sorted(missing)))
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
    except QualityGateError:
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


expect_reject("empty quality gate matrix", "")
expect_reject("malformed quality gate data", START + "\n```json\n{\"version\": \n```\n" + END)

for field in ["approvalBoundary", "globalGates", "surfaces", "followUpIssueUrl"]:
    mutated = copy.deepcopy(baseline)
    mutated[field] = ""
    expect_reject(f"missing {field}", mutated)

for surface_id in sorted(REQUIRED_SURFACES):
    mutated = copy.deepcopy(baseline)
    mutated["surfaces"] = [surface for surface in mutated["surfaces"] if surface["id"] != surface_id]
    expect_reject(f"missing surface {surface_id}", mutated)

for name, path in [
    ("missing required tests", ("surfaces", "0", "requiredTests")),
    ("missing merge gate commands", ("surfaces", "0", "mergeGateCommands")),
    ("missing accepted risk", ("surfaces", "0", "acceptedRisk")),
    ("missing evidence artifacts", ("surfaces", "0", "evidenceArtifacts")),
    ("missing next action", ("surfaces", "0", "nextAction")),
]:
    mutated = copy.deepcopy(baseline)
    surfaces = require_list(mutated.get("surfaces"), "surfaces")
    if not isinstance(surfaces[0], dict):
        reject("negative fixture surface is not an object")
    surfaces[0][path[-1]] = []
    expect_reject(name, mutated)

for name, path, value in [
    ("unsafe authority wording", ("approvalBoundary",), "credential used and production write completed"),
    ("private local path", ("globalGates", "prEvidence"), [HOME_SEGMENT + "sam/project/output"]),
    ("internal execution label", ("globalGates", "prEvidence"), ["run " + INTERNAL_LABELS[0] + " workflow"]),
    ("invalid command", ("globalGates", "defaultCommands"), ["echo no validation"]),
]:
    mutated = copy.deepcopy(baseline)
    set_path(mutated, path, value)
    expect_reject(name, mutated)

print("PASS Dokkaebi runtime quality gate matrix validation passed")
PY
