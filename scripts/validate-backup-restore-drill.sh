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

DOC_PATH="${BACKUP_RESTORE_DRILL_PATH:-docs/operations/backup-restore-drill-2026-06-13.md}"

for term in \
  "local fixture replay" "backup target" "restore point" "restore steps" \
  "RPO result" "RTO result" "DR roles" "validation output" \
  "evidence retention" "approval-gate status" "cleanup" "residual risk" \
  "next action" "does not authorize"; do
  require_text "$DOC_PATH" "$term"
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

JsonValue = None | bool | int | float | str | list["JsonValue"] | dict[str, "JsonValue"]
JsonObject = dict[str, JsonValue]
JsonPath = tuple[str, ...]

START = "<!-- backup-restore-drill:begin -->"
END = "<!-- backup-restore-drill:end -->"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")

SECRET_TERMS = ["cookie=", "private_key=", "secret=", "token=", "-----begin private key-----"]
UNSAFE_PHRASES = [
    "credential used", "deployment executed", "docker route invoked", "github project control-plane mutation completed",
    "infrastructure mutated", "kubernetes cluster mutated", "production restore completed",
    "proxmox mutation completed", "remote host changed",
]


class DrillError(Exception):
    pass


def reject(message: str) -> None:
    raise DrillError(message)


def extract_payload(text: str) -> JsonObject:
    if not text.strip():
        reject("empty drill content")
    if START not in text or END not in text:
        reject("missing backup restore drill control block")
    block = text.split(START, 1)[1].split(END, 1)[0].strip()
    if block.startswith("```json"):
        block = block.removeprefix("```json").strip()
    if block.endswith("```"):
        block = block[: -len("```")].strip()
    try:
        payload = json.loads(block)
    except json.JSONDecodeError as exc:
        reject(f"malformed drill JSON: {exc}")
    if not isinstance(payload, dict):
        reject("backup restore drill control block must be an object")
    return payload


def require_nonempty(value: JsonValue, label: str) -> None:
    if value in (None, "", [], {}):
        reject(f"missing {label}")


def require_object(value: JsonValue, label: str) -> JsonObject:
    if not isinstance(value, dict):
        reject(f"missing {label}")
    return value


def require_timestamp(value: JsonValue, label: str) -> datetime:
    if not isinstance(value, str):
        reject(f"missing {label}")
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        reject(f"invalid {label}")


def require_seconds(value: JsonValue, label: str) -> int:
    if type(value) is not int or value < 0:
        reject(f"missing {label}")
    return value


def flattened_strings(value: JsonValue) -> list[str]:
    match value:
        case str():
            return [value]
        case list():
            return [text for item in value for text in flattened_strings(item)]
        case dict():
            return [text for item in value.values() for text in flattened_strings(item)]
        case _:
            return []


def require_safe_text(payload: JsonObject) -> None:
    lowered = "\n".join(flattened_strings(payload)).lower()
    for term in SECRET_TERMS:
        if term in lowered:
            reject(f"secret-bearing evidence wording: {term}")
    for phrase in UNSAFE_PHRASES:
        if phrase in lowered:
            reject(f"unsafe mutation wording: {phrase}")
    approval = str(payload.get("approvalGateStatus", "")).lower()
    if "no live" not in approval or "mutation reached" not in approval:
        reject("approvalGateStatus must state no approval-gated mutation reached")


def validate_payload(payload: JsonObject) -> None:
    for field in ["drillId", "date", "environment", "permissionLevel"]:
        require_nonempty(payload.get(field), field)
    if payload.get("permissionLevel") != "local-validation-only":
        reject("permissionLevel must remain local-validation-only")

    local_target = require_object(payload.get("localTarget"), "local target")
    for field in ["type", "productionData", "cleanupRequired"]:
        require_nonempty(local_target.get(field), f"local target {field}")
    if local_target.get("productionData") != "none":
        reject("local target must not contain production data")
    if local_target.get("cleanupRequired") is not True:
        reject("local target cleanup must be required")

    backup = require_object(payload.get("backupTarget"), "backup target")
    for field in ["id", "source", "target", "secretsIncluded"]:
        require_nonempty(backup.get(field), f"backup target {field}")
    if backup.get("secretsIncluded") is not False:
        reject("backup target must not include secrets")

    restore = require_object(payload.get("restorePoint"), "restore point")
    for field in ["id", "sourceEnvironment", "requestedRpo"]:
        require_nonempty(restore.get(field), f"restore point {field}")

    manifests = require_object(payload.get("fixtureManifests"), "fixture manifests")
    for field in ["sourceSha256", "restoredSha256", "comparison"]:
        require_nonempty(manifests.get(field), f"fixture manifest {field}")
    source_hash = manifests["sourceSha256"]
    restored_hash = manifests["restoredSha256"]
    if not isinstance(source_hash, str) or not SHA256_RE.fullmatch(source_hash):
        reject("fixture manifest sourceSha256 must be a SHA-256 hex digest")
    if not isinstance(restored_hash, str) or not SHA256_RE.fullmatch(restored_hash):
        reject("fixture manifest restoredSha256 must be a SHA-256 hex digest")
    if source_hash != restored_hash or manifests.get("comparison") != "matched":
        reject("fixture manifest hashes must match")

    measurement = require_object(payload.get("measurement"), "measurement")
    restore_point_at = require_timestamp(measurement.get("restorePointTimestamp"), "measurement restorePointTimestamp")
    started_at = require_timestamp(measurement.get("restoreStartedAt"), "measurement restoreStartedAt")
    completed_at = require_timestamp(measurement.get("restoreCompletedAt"), "measurement restoreCompletedAt")
    if restore_point_at > started_at:
        reject("measurement restore point timestamp must not be after restore start")
    if started_at > completed_at:
        reject("measurement restore timestamps must be ordered")
    for field in ["rpoObservedSeconds", "rpoTargetSeconds", "rtoObservedSeconds", "rtoTargetSeconds"]:
        require_seconds(measurement.get(field), f"measurement {field}")
    require_nonempty(measurement.get("measuredBy"), "measurement measuredBy")
    if measurement["rpoObservedSeconds"] > measurement["rpoTargetSeconds"]:
        reject("measurement RPO observed seconds must not exceed target seconds")
    if measurement["rtoObservedSeconds"] > measurement["rtoTargetSeconds"]:
        reject("measurement RTO observed seconds must not exceed target seconds")

    steps = payload.get("restoreSteps")
    if not isinstance(steps, list) or len(steps) < 5:
        reject("missing restore steps")
    for step in steps:
        if not isinstance(step, dict):
            reject("restore step must be an object")
        for field in ["name", "operator", "evidence"]:
            require_nonempty(step.get(field), f"restore step {field}")

    for field in ["rpo", "rto"]:
        metric = require_object(payload.get(field), f"{field.upper()} result")
        for item in ["target", "result", "observedSeconds", "targetSeconds", "met"]:
            require_nonempty(metric.get(item), f"{field.upper()} {item}")
        observed = require_seconds(metric.get("observedSeconds"), f"{field.upper()} observedSeconds")
        target = require_seconds(metric.get("targetSeconds"), f"{field.upper()} targetSeconds")
        if metric.get("met") is not True:
            reject(f"{field.upper()} result must meet the target")
        if observed > target:
            reject(f"{field.upper()} observed seconds must not exceed target seconds")
        if observed != measurement[f"{field}ObservedSeconds"] or target != measurement[f"{field}TargetSeconds"]:
            reject(f"{field.upper()} result seconds must match measurement")
        result = metric.get("result")
        if not isinstance(result, str) or f"{observed} seconds" not in result:
            reject(f"{field.upper()} result must include measured seconds")

    roles = require_object(payload.get("drRoles"), "DR roles")
    required_roles = {"incidentCommander", "restoreOperator", "fireOperator", "humanApprover", "managerReviewer"}
    missing_roles = required_roles - roles.keys()
    if missing_roles:
        reject("missing DR role: " + ", ".join(sorted(missing_roles)))

    require_nonempty(payload.get("validationOutput"), "validation output")
    retention = require_object(payload.get("evidenceRetention"), "evidence retention")
    for field in ["storageSurface", "redactionPolicy"]:
        require_nonempty(retention.get(field), f"evidence retention {field}")
    require_nonempty(payload.get("approvalGateStatus"), "approval-gate status")

    cleanup = require_object(payload.get("cleanup"), "cleanup")
    for field in ["status", "receipt"]:
        require_nonempty(cleanup.get(field), f"cleanup {field}")
    if cleanup.get("status") != "complete":
        reject("cleanup must be complete")

    require_nonempty(payload.get("residualRisk"), "residual risk")
    require_nonempty(payload.get("nextAction"), "next action")
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
    except DrillError:
        return
    reject(f"negative fixture unexpectedly passed: {name}")


def set_path(payload: JsonObject, path: JsonPath, value: JsonValue, name: str) -> None:
    target = payload
    for key in path[:-1]:
        next_target = target[key]
        if not isinstance(next_target, dict):
            reject(f"negative fixture path is not an object: {name}")
        target = next_target
    target[path[-1]] = value


expect_reject("empty drill content", "")
expect_reject("malformed drill data", START + "\n```json\n{\"version\": \n```\n" + END)

required_top_fields = [
    ("drill ID", "drillId"), ("environment", "environment"), ("local target", "localTarget"), ("backup target", "backupTarget"),
    ("restore point", "restorePoint"), ("fixture manifests", "fixtureManifests"), ("measurement", "measurement"), ("restore steps", "restoreSteps"),
    ("RPO result", "rpo"), ("RTO result", "rto"), ("DR roles", "drRoles"), ("validation output", "validationOutput"),
    ("evidence retention", "evidenceRetention"), ("approval-gate status", "approvalGateStatus"), ("cleanup", "cleanup"),
    ("residual risk", "residualRisk"), ("next action", "nextAction"),
]
field_cases: list[tuple[str, JsonPath]] = [(f"missing {label}", (field,)) for label, field in required_top_fields]
for name, path in field_cases:
    mutated = copy.deepcopy(baseline)
    set_path(mutated, path, "", name)
    expect_reject(name, mutated)

mutation_cases: list[tuple[str, JsonPath, JsonValue]] = [
    ("secret-bearing backup", ("backupTarget", "secretsIncluded"), True),
    ("mismatched restored manifest hash", ("fixtureManifests", "restoredSha256"), "0" * 64),
    ("restore point after restore start", ("measurement", "restorePointTimestamp"), "2026-06-13T18:00:00Z"),
    ("unmeasured RPO result", ("rpo", "result"), "not measured"),
    ("measurement RPO exceeds target", ("measurement", "rpoObservedSeconds"), 90000),
    ("RPO result exceeds target", ("rpo", "observedSeconds"), 90000),
    ("RTO exceeds target", ("rto", "observedSeconds"), 20000),
    ("measurement RTO exceeds target", ("measurement", "rtoObservedSeconds"), 20000),
    ("inverted measurement timestamps", ("measurement", "restoreStartedAt"), "2026-06-13T17:30:00Z"),
    ("measurement and RPO mismatch", ("measurement", "rpoObservedSeconds"), 1),
    ("measurement and RTO mismatch", ("measurement", "rtoObservedSeconds"), 121),
    ("measurement and RPO target mismatch", ("measurement", "rpoTargetSeconds"), 86401),
    ("measurement and RTO target mismatch", ("measurement", "rtoTargetSeconds"), 14401),
    ("boolean RPO seconds", ("measurement", "rpoTargetSeconds"), True),
    ("unsafe mutation wording", ("approvalGateStatus",), "production restore completed"),
]
for name, path, value in mutation_cases:
    mutated = copy.deepcopy(baseline)
    set_path(mutated, path, value, name)
    expect_reject(name, mutated)

mutated = copy.deepcopy(baseline)
mutated["validationOutput"].append("token=example")
expect_reject("secret-bearing evidence wording", mutated)

print("PASS Dokkaebi backup restore drill validation passed")
PY
