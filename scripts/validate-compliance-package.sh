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

DOC_PATH="${COMPLIANCE_PACKAGE_PATH:-docs/compliance/control-map-and-evidence-package.md}"

for term in \
  "approval control" \
  "access control" \
  "change management control" \
  "logging control" \
  "incident control" \
  "credential control" \
  "retention" \
  "redaction" \
  "integrity" \
  "ownership" \
  "export design" \
  "package contents" \
  "sample evidence chain" \
  "approval boundary" \
  "secret-bearing evidence"; do
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

START = "<!-- compliance-package:begin -->"
END = "<!-- compliance-package:end -->"


class ComplianceError(Exception):
    pass


def reject(message: str) -> None:
    raise ComplianceError(message)


def extract_payload(text: str) -> dict[str, Any]:
    if not text.strip():
        reject("empty baseline")
    if START not in text or END not in text:
        reject("missing compliance package control block")
    block = text.split(START, 1)[1].split(END, 1)[0].strip()
    if block.startswith("```json"):
        block = block.removeprefix("```json").strip()
    if block.endswith("```"):
        block = block[: -len("```")].strip()
    try:
        payload = json.loads(block)
    except json.JSONDecodeError as exc:
        reject(f"malformed compliance package JSON: {exc}")
    if not isinstance(payload, dict):
        reject("compliance package control block must be an object")
    return payload


def require_nonempty(value: Any, label: str) -> None:
    if value in (None, "", [], {}):
        reject(f"missing {label}")


def validate_payload(payload: dict[str, Any]) -> None:
    if payload.get("permissionLevel") != "docs-only":
        reject("permissionLevel must remain docs-only")
    approval = str(payload.get("approvalGateStatus", "")).lower()
    if "credential mutation authorized" in approval:
        reject("unauthorized credential mutation wording")
    for term in ["no credential", "worker", "infrastructure", "production", "control-plane"]:
        if term not in approval:
            reject(f"approvalGateStatus missing {term}")

    controls = payload.get("controls")
    if not isinstance(controls, dict):
        reject("controls must be an object")
    required_controls = {
        "approval",
        "access",
        "changeManagement",
        "logging",
        "incident",
        "credential",
    }
    missing_controls = required_controls - controls.keys()
    if missing_controls:
        reject("missing control: " + ", ".join(sorted(missing_controls)))
    for control_id in required_controls:
        control = controls.get(control_id)
        if not isinstance(control, dict):
            reject(f"{control_id} control must be an object")
        for field in ["controlObjective", "evidenceSources", "owner", "reviewCadence"]:
            require_nonempty(control.get(field), f"{control_id} control {field}")

    export = payload.get("exportDesign")
    if not isinstance(export, dict):
        reject("missing export design")
    for field in ["retention", "redaction", "integrity", "ownership", "storageSurface", "immutableExportGap"]:
        require_nonempty(export.get(field), f"export design {field}")
    redaction = str(export.get("redaction", "")).lower()
    if "secret-bearing evidence allowed" in redaction or "raw secret included" in redaction:
        reject("secret-bearing evidence wording")

    contents = payload.get("packageContents")
    if not isinstance(contents, list) or len(contents) < 8:
        reject("missing package contents")

    chain = payload.get("sampleEvidenceChain")
    if not isinstance(chain, list) or len(chain) < 6:
        reject("missing sample evidence chain")

    boundary = str(payload.get("approvalBoundary", ""))
    require_nonempty(boundary, "approval boundary")
    boundary_lower = boundary.lower()
    for term in ["docs-only", "explicit human approval", "credential", "production"]:
        if term not in boundary_lower:
            reject(f"approval boundary missing {term}")

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
    except ComplianceError:
        return
    reject(f"negative fixture unexpectedly passed: {name}")


expect_reject("empty baseline", "")
expect_reject(
    "malformed control data",
    START + "\n```json\n{\"version\": \n```\n" + END,
)

for control_id in [
    "approval",
    "access",
    "changeManagement",
    "logging",
    "incident",
    "credential",
]:
    mutated = copy.deepcopy(baseline)
    del mutated["controls"][control_id]
    expect_reject(f"missing {control_id} control", mutated)

for field in ["retention", "redaction", "integrity", "ownership"]:
    mutated = copy.deepcopy(baseline)
    mutated["exportDesign"][field] = ""
    expect_reject(f"missing {field}", mutated)

mutated = copy.deepcopy(baseline)
mutated["exportDesign"] = {}
expect_reject("missing export design", mutated)

mutated = copy.deepcopy(baseline)
mutated["packageContents"] = []
expect_reject("missing package contents", mutated)

mutated = copy.deepcopy(baseline)
mutated["sampleEvidenceChain"] = []
expect_reject("missing sample evidence chain", mutated)

mutated = copy.deepcopy(baseline)
mutated["approvalBoundary"] = ""
expect_reject("missing approval boundary", mutated)

mutated = copy.deepcopy(baseline)
mutated["exportDesign"]["redaction"] = "secret-bearing evidence allowed"
expect_reject("secret-bearing evidence wording", mutated)

print("PASS Dokkaebi compliance package validation passed")
PY
