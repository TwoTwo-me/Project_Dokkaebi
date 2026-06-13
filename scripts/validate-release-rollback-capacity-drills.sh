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

DOC_PATH="${RELEASE_ROLLBACK_CAPACITY_PATH:-docs/operations/release-rollback-capacity-drills.md}"

for term in \
  "staged rollout" \
  "rollback trigger" \
  "operator" \
  "evidence" \
  "communication" \
  "queue" \
  "worker" \
  "retry" \
  "review age" \
  "local validation path" \
  "drill evidence" \
  "approval boundary" \
  "does not authorize live mutation"; do
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

START = "<!-- release-rollback-capacity:begin -->"
END = "<!-- release-rollback-capacity:end -->"


class BaselineError(Exception):
    pass


def reject(message: str) -> None:
    raise BaselineError(message)


def extract_payload(text: str) -> dict[str, Any]:
    if not text.strip():
        reject("empty baseline")
    if START not in text or END not in text:
        reject("missing release rollback capacity control block")
    block = text.split(START, 1)[1].split(END, 1)[0].strip()
    if block.startswith("```json"):
        block = block.removeprefix("```json").strip()
    if block.endswith("```"):
        block = block[: -len("```")].strip()
    try:
        payload = json.loads(block)
    except json.JSONDecodeError as exc:
        reject(f"malformed release rollback capacity JSON: {exc}")
    if not isinstance(payload, dict):
        reject("release rollback capacity control block must be an object")
    return payload


def require_nonempty(value: Any, label: str) -> None:
    if value in (None, "", []):
        reject(f"missing {label}")


def validate_payload(payload: dict[str, Any]) -> None:
    if payload.get("permissionLevel") != "docs-only":
        reject("permissionLevel must remain docs-only")
    approval = str(payload.get("approvalGateStatus", "")).lower()
    if "live mutation authorized" in approval:
        reject("unauthorized live mutation wording")
    for term in ["no live", "credential", "production", "control-plane"]:
        if term not in approval:
            reject(f"approvalGateStatus missing {term}")

    release = payload.get("release")
    if not isinstance(release, dict):
        reject("release must be an object")
    require_nonempty(release.get("stagedRollout"), "staged rollout")
    if not isinstance(release.get("stagedRollout"), list) or len(release["stagedRollout"]) < 5:
        reject("staged rollout must list at least five stages")
    for field in ["operator", "evidence", "communication"]:
        require_nonempty(release.get(field), f"release {field}")

    rollback = payload.get("rollback")
    if not isinstance(rollback, dict):
        reject("rollback must be an object")
    for field in ["trigger", "operator", "evidence", "communication"]:
        require_nonempty(rollback.get(field), f"rollback {field}")

    capacity = payload.get("capacity")
    if not isinstance(capacity, dict):
        reject("capacity must be an object")
    for field in [
        "queueThreshold",
        "workerThreshold",
        "retryThreshold",
        "reviewAgeThreshold",
        "soakWindow",
        "localValidationPath",
    ]:
        require_nonempty(capacity.get(field), f"capacity {field}")

    drill = payload.get("drillEvidence")
    if not isinstance(drill, dict):
        reject("drillEvidence must be an object")
    shape = drill.get("shape")
    if not isinstance(shape, dict):
        reject("missing drill evidence shape")
    required_shape = {
        "drillId",
        "permissionLevel",
        "releaseCandidate",
        "stagedRolloutDecision",
        "rollbackTrigger",
        "rollbackDecision",
        "operator",
        "communicationSurface",
        "validationOutput",
        "approvalGateStatus",
        "residualRisk",
    }
    missing_shape = required_shape - shape.keys()
    if missing_shape:
        reject("missing drill evidence field: " + ", ".join(sorted(missing_shape)))
    for field in ["privateMemoryPolicy", "storageSurface"]:
        require_nonempty(drill.get(field), f"drillEvidence {field}")

    evidence = payload.get("requiredEvidence")
    if not isinstance(evidence, list) or len(evidence) < 5:
        reject("requiredEvidence must list at least five evidence surfaces")


doc_text = Path(sys.argv[1]).read_text(encoding="utf-8")
baseline = extract_payload(doc_text)
validate_payload(baseline)


def expect_reject(name: str, candidate: str | dict[str, Any]) -> None:
    try:
        if isinstance(candidate, str):
            validate_payload(extract_payload(candidate))
        else:
            validate_payload(candidate)
    except BaselineError:
        return
    reject(f"negative fixture unexpectedly passed: {name}")


expect_reject("empty baseline", "")
expect_reject(
    "malformed control data",
    START + "\n```json\n{\"version\": \n```\n" + END,
)

mutated = copy.deepcopy(baseline)
mutated["release"]["stagedRollout"] = []
expect_reject("missing staged rollout", mutated)

mutated = copy.deepcopy(baseline)
mutated["rollback"]["trigger"] = ""
expect_reject("missing rollback trigger", mutated)

mutated = copy.deepcopy(baseline)
mutated["release"]["operator"] = ""
expect_reject("missing operator", mutated)

mutated = copy.deepcopy(baseline)
mutated["release"]["evidence"] = []
expect_reject("missing evidence", mutated)

mutated = copy.deepcopy(baseline)
mutated["release"]["communication"] = ""
expect_reject("missing communication", mutated)

for field in ["queueThreshold", "workerThreshold", "retryThreshold", "reviewAgeThreshold"]:
    mutated = copy.deepcopy(baseline)
    mutated["capacity"][field] = ""
    expect_reject(f"missing {field}", mutated)

mutated = copy.deepcopy(baseline)
mutated["capacity"]["localValidationPath"] = ""
expect_reject("missing local validation path", mutated)

mutated = copy.deepcopy(baseline)
mutated["drillEvidence"]["shape"] = {}
expect_reject("missing drill evidence shape", mutated)

mutated = copy.deepcopy(baseline)
mutated["approvalGateStatus"] = ""
expect_reject("missing approval boundary", mutated)

mutated = copy.deepcopy(baseline)
mutated["approvalGateStatus"] = "live mutation authorized"
expect_reject("unauthorized live mutation wording", mutated)

print("PASS Dokkaebi release rollback capacity drill validation passed")
PY
