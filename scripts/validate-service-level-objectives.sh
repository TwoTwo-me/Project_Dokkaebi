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

DOC_PATH="${SERVICE_LEVEL_OBJECTIVES_PATH:-docs/operations/service-level-objectives.md}"

for term in \
  "dispatch latency" "recovery time" "review age" "availability posture" \
  "error-budget" "measurement source" "fallback evidence" "review cadence" \
  "owner actions" "External SLA Boundary" "not approved" "issue #80" \
  "docs-only" "control-plane"; do
  require_text "$DOC_PATH" "$term"
done

command -v python3 >/dev/null || fail "missing command: python3"

python3 - "$DOC_PATH" <<'PY'
from __future__ import annotations

import copy
import json
import sys
from pathlib import Path

JsonValue = None | bool | int | float | str | list["JsonValue"] | dict[str, "JsonValue"]
JsonObject = dict[str, JsonValue]
JsonPath = tuple[str, ...]

START = "<!-- service-level-objectives:begin -->"
END = "<!-- service-level-objectives:end -->"
REQUIRED_SLOS = {"dispatch_latency", "recovery_time", "review_age"}
REQUIRED_TOP = {
    "serviceScope",
    "slos",
    "availabilityPosture",
    "errorBudgetPolicy",
    "reviewCadence",
    "ownerActions",
    "externalSlaBoundary",
    "backendEvidence",
    "followUpIssue",
    "residualRisk",
    "nextAction",
    "requiredEvidence",
}
UNAUTHORIZED = [
    "credential mutation authorized",
    "production write authorized",
    "worker scaling authorized",
    "remote host mutation authorized",
    "docker mutation authorized",
    "kubernetes mutation authorized",
    "proxmox mutation authorized",
    "deployment authorized",
    "infrastructure mutation authorized",
    "alerting service mutation authorized",
    "control-plane mutation authorized",
    "external sla approved",
    "customer uptime guarantee approved",
]
FORBIDDEN_TEXT = UNAUTHORIZED + [
    "/" + "home" + "/",
    "gh" + "p_",
    "github" + "_pat_",
    "to" + "ken=",
    "cookie=",
    "private" + "_key=",
    "-----begin " + "private key-----",
    "ul" + "w-loop",
    "om" + "o:",
    "om" + "x:",
    "co" + "dex/",
]


class SloError(Exception):
    pass


def reject(message: str) -> None:
    raise SloError(message)


def extract_payload(text: str) -> JsonObject:
    if not text.strip():
        reject("empty SLO content")
    if START not in text or END not in text:
        reject("missing service-level objectives control block")
    block = text.split(START, 1)[1].split(END, 1)[0].strip()
    if block.startswith("```json"):
        block = block.removeprefix("```json").strip()
    if block.endswith("```"):
        block = block[: -len("```")].strip()
    try:
        payload = json.loads(block)
    except json.JSONDecodeError as exc:
        reject(f"malformed SLO data: {exc}")
    if not isinstance(payload, dict):
        reject("service-level objectives control block must be an object")
    return payload


def require_nonempty(value: JsonValue, label: str) -> None:
    if value in (None, "", [], {}):
        reject(f"missing {label}")


def require_object(value: JsonValue, label: str) -> JsonObject:
    if not isinstance(value, dict) or not value:
        reject(f"missing {label}")
    return value


def require_list(value: JsonValue, label: str, minimum: int = 1) -> list[JsonValue]:
    if not isinstance(value, list) or len(value) < minimum:
        reject(f"missing {label}")
    return value


def require_positive_int(value: JsonValue, label: str) -> int:
    if type(value) is not int or value <= 0:
        reject(f"missing {label}")
    return value


def text_join(value: JsonValue) -> str:
    match value:
        case str():
            return value
        case list():
            return " ".join(text_join(item) for item in value)
        case dict():
            return " ".join(text_join(item) for item in value.values())
        case _:
            return str(value)


def require_terms(value: JsonValue, terms: list[str], label: str) -> None:
    text = text_join(value).lower()
    for term in terms:
        if term not in text:
            reject(f"{label} missing {term}")


def set_path(payload: JsonObject, path: JsonPath, value: JsonValue, name: str) -> None:
    target = payload
    for key in path[:-1]:
        child = target[key]
        if not isinstance(child, dict):
            reject(f"fixture path is not an object: {name}")
        target = child
    target[path[-1]] = value


def validate_payload(payload: JsonObject) -> None:
    if payload.get("permissionLevel") != "docs-only":
        reject("permissionLevel must remain docs-only")
    for field in REQUIRED_TOP:
        require_nonempty(payload.get(field), field)

    approval = str(payload.get("approvalGateStatus", "")).lower()
    for term in ["no live", "credential", "worker", "production", "infrastructure", "control-plane"]:
        if term not in approval:
            reject(f"approvalGateStatus missing {term}")
    all_text = text_join(payload).lower()
    for phrase in UNAUTHORIZED:
        if phrase in all_text:
            reject(f"unauthorized wording: {phrase}")

    require_list(payload.get("serviceScope"), "service scope", 5)
    slos = require_list(payload.get("slos"), "SLO list")
    by_id = {str(item.get("id")): item for item in slos if isinstance(item, dict)}
    missing = REQUIRED_SLOS - set(by_id)
    if missing:
        reject("missing SLO: " + ", ".join(sorted(missing)))
    for slo_id in REQUIRED_SLOS:
        slo = by_id[slo_id]
        for field in ["target", "measurementSource", "fallbackEvidence", "errorBudget", "ownerAction"]:
            require_nonempty(slo.get(field), f"{slo_id} {field}")
        percentile = require_positive_int(slo.get("percentile"), f"{slo_id} percentile")
        threshold = require_positive_int(slo.get("thresholdSeconds"), f"{slo_id} thresholdSeconds")
        if percentile > 100 or threshold > 604800:
            reject(f"{slo_id} threshold bounds invalid")
        require_terms(slo.get("measurementSource"), ["metric"], f"{slo_id} measurement source")
        require_terms(slo.get("fallbackEvidence"), ["evidence"], f"{slo_id} fallback evidence")

    availability = require_object(payload.get("availabilityPosture"), "availability posture")
    for field in ["internalTarget", "measurementSource", "fallbackEvidence", "noExternalCommitment"]:
        require_nonempty(availability.get(field), f"availability posture {field}")
    require_terms(availability.get("noExternalCommitment"), ["no", "sla"], "availability posture noExternalCommitment")

    policy = require_object(payload.get("errorBudgetPolicy"), "error-budget policy")
    for field in ["burnCalculation", "reviewCadence", "freezeRule", "resetPolicy"]:
        require_nonempty(policy.get(field), f"error-budget policy {field}")
    require_terms(policy.get("freezeRule"), ["credential", "infrastructure", "production", "owner decision"], "error-budget freeze rule")

    cadence = require_object(payload.get("reviewCadence"), "review cadence")
    for field in ["perPullRequest", "weekly", "monthly", "incidentCloseout"]:
        require_nonempty(cadence.get(field), f"review cadence {field}")

    owners = require_object(payload.get("ownerActions"), "owner actions")
    for field in ["sreOwner", "fireOperator", "managerReviewer", "humanApprover", "complianceReviewer"]:
        require_nonempty(owners.get(field), f"owner action {field}")

    boundary = require_object(payload.get("externalSlaBoundary"), "external SLA boundary")
    if boundary.get("status") != "not_approved":
        reject("external SLA boundary must be not_approved")
    require_terms(boundary.get("approvalRequired"), ["human owner", "customer-facing", "legal"], "external SLA approval")
    require_list(boundary.get("forbiddenClaims"), "external SLA forbidden claims", 3)

    backend = require_object(payload.get("backendEvidence"), "backend evidence")
    for field in ["issue", "path", "runner", "validator", "status"]:
        require_nonempty(backend.get(field), f"backend evidence {field}")
    if backend["issue"] != "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/80":
        reject("backend evidence must point to issue #80")
    if backend["path"] != "docs/operations/central-metrics-sandbox-backend-2026-06-14.md":
        reject("backend evidence path mismatch")
    if backend["runner"] != "scripts/run-central-metrics-sandbox-backend.sh":
        reject("backend evidence runner mismatch")
    if backend["validator"] != "scripts/validate-central-metrics-sandbox-backend.sh":
        reject("backend evidence validator mismatch")
    if "approved local sandbox backend evidence" not in str(backend["status"]).lower():
        reject("backend evidence status missing captured sandbox state")

    if payload.get("followUpIssue") != "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/82":
        reject("followUpIssue must point to issue #82")
    require_list(payload.get("residualRisk"), "residual risk", 3)
    require_nonempty(payload.get("nextAction"), "next action")
    require_list(payload.get("requiredEvidence"), "required evidence", 5)


def validate_document(text: str) -> JsonObject:
    lowered = text.lower()
    for phrase in FORBIDDEN_TEXT:
        if phrase in lowered:
            reject(f"forbidden document text: {phrase}")
    payload = extract_payload(text)
    validate_payload(payload)
    return payload


doc_text = Path(sys.argv[1]).read_text(encoding="utf-8")
baseline = validate_document(doc_text)


def expect_reject(name: str, candidate: str | JsonObject) -> None:
    try:
        if isinstance(candidate, str):
            validate_document(candidate)
        else:
            validate_payload(candidate)
    except SloError:
        return
    reject(f"negative fixture unexpectedly passed: {name}")


expect_reject("empty content", "")
expect_reject("malformed SLO data", START + "\n```json\n{\"version\": \n```\n" + END)

for name, path in [(f"missing {field}", (field,)) for field in REQUIRED_TOP]:
    mutated = copy.deepcopy(baseline)
    set_path(mutated, path, "", name)
    expect_reject(name, mutated)

for slo_id in sorted(REQUIRED_SLOS):
    mutated = copy.deepcopy(baseline)
    mutated["slos"] = [item for item in mutated["slos"] if isinstance(item, dict) and item.get("id") != slo_id]
    expect_reject(f"missing {slo_id}", mutated)

mutation_cases: list[tuple[str, JsonPath, JsonValue]] = [
    ("missing measurement source", ("slos", "0", "measurementSource"), ""),
    ("missing fallback evidence", ("slos", "0", "fallbackEvidence"), ""),
    ("boolean threshold", ("slos", "0", "thresholdSeconds"), True),
    ("invalid percentile", ("slos", "0", "percentile"), 101),
    ("external SLA approved", ("externalSlaBoundary", "status"), "approved"),
    ("unauthorized production claim", ("externalSlaBoundary", "approvalRequired"), "external SLA approved"),
    ("bad backend evidence issue", ("backendEvidence", "issue"), "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/82"),
    ("bad follow-up issue", ("followUpIssue",), "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/80"),
]
for name, path, value in mutation_cases:
    mutated = copy.deepcopy(baseline)
    if path[0] == "slos":
        mutated["slos"][int(path[1])][path[2]] = value
    else:
        set_path(mutated, path, value, name)
    expect_reject(name, mutated)

body_cases = [
    ("body private path", "/" + "home" + "/private/path"),
    ("body token", "gh" + "p_exampletoken"),
    ("body external SLA approval", "External SLA approved"),
    ("body Docker authority", "Docker mutation authorized"),
]
for name, suffix in body_cases:
    expect_reject(name, doc_text + "\n" + suffix + "\n")

print("PASS Dokkaebi service-level objectives validation passed")
PY
