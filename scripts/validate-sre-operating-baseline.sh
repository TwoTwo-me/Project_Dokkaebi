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

DOC_PATH="${SRE_BASELINE_PATH:-docs/operations/sre-operating-baseline.md}"

for term in \
  "dispatch latency" \
  "recovery time" \
  "review age" \
  "error budget" \
  "SEV0" \
  "incident commander" \
  "communication" \
  "mitigation" \
  "postmortem" \
  "on-call" \
  "paging" \
  "owner decision" \
  "intentionally deferred"; do
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

START = "<!-- sre-baseline:begin -->"
END = "<!-- sre-baseline:end -->"
REQUIRED_SLOS = {"dispatch_latency", "recovery_time", "review_age"}
REQUIRED_SEVERITIES = {"SEV0", "SEV1", "SEV2", "SEV3"}


class BaselineError(Exception):
    pass


def reject(message: str) -> None:
    raise BaselineError(message)


def extract_payload(text: str) -> dict[str, Any]:
    if not text.strip():
        reject("empty baseline")
    if START not in text or END not in text:
        reject("missing SRE baseline control block")
    block = text.split(START, 1)[1].split(END, 1)[0]
    block = block.strip()
    if block.startswith("```json"):
        block = block.removeprefix("```json").strip()
    if block.endswith("```"):
        block = block[: -len("```")].strip()
    try:
        payload = json.loads(block)
    except json.JSONDecodeError as exc:
        reject(f"malformed SRE baseline JSON: {exc}")
    if not isinstance(payload, dict):
        reject("SRE baseline control block must be an object")
    return payload


def require_nonempty(value: Any, label: str) -> None:
    if value in (None, "", []):
        reject(f"missing {label}")


def validate_payload(payload: dict[str, Any]) -> None:
    if payload.get("permissionLevel") != "docs-only":
        reject("permissionLevel must remain docs-only")
    approval = str(payload.get("approvalGateStatus", "")).lower()
    for term in ["no live", "credential", "production", "control-plane"]:
        if term not in approval:
            reject(f"approvalGateStatus missing {term}")

    slos = payload.get("slos")
    if not isinstance(slos, list):
        reject("slos must be a list")
    by_id = {item.get("id"): item for item in slos if isinstance(item, dict)}
    missing_slos = REQUIRED_SLOS - by_id.keys()
    if missing_slos:
        reject("missing SLO: " + ", ".join(sorted(missing_slos)))
    for slo_id in REQUIRED_SLOS:
        slo = by_id[slo_id]
        for field in ["target", "measurement", "errorBudget"]:
            require_nonempty(slo.get(field), f"{slo_id} {field}")

    incident = payload.get("incidentRunbook")
    if not isinstance(incident, dict):
        reject("incidentRunbook must be an object")
    severities = set(incident.get("severityLevels", []))
    if REQUIRED_SEVERITIES - severities:
        reject("missing severity levels")
    for field in ["commander", "communication", "mitigation", "postmortem"]:
        require_nonempty(incident.get(field), f"incident {field}")

    on_call = payload.get("onCallPaging")
    if not isinstance(on_call, dict):
        reject("onCallPaging must be an object")
    status = on_call.get("status")
    if status not in {"implemented", "intentionally_deferred"}:
        reject("on-call decision must be implemented or intentionally_deferred")
    for field in ["ownerDecision", "currentPath", "pagingPath"]:
        require_nonempty(on_call.get(field), f"on-call {field}")
    if status == "intentionally_deferred" and "deferred" not in on_call["ownerDecision"].lower():
        reject("deferred on-call decision must explain the deferral")

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
    "malformed JSON",
    START + "\n```json\n{\"version\": \n```\n" + END,
)

for missing in sorted(REQUIRED_SLOS):
    mutated = copy.deepcopy(baseline)
    mutated["slos"] = [item for item in mutated["slos"] if item["id"] != missing]
    expect_reject(f"missing {missing}", mutated)

for field in ["commander", "communication", "mitigation", "postmortem"]:
    mutated = copy.deepcopy(baseline)
    mutated["incidentRunbook"][field] = ""
    expect_reject(f"missing incident {field}", mutated)

mutated = copy.deepcopy(baseline)
mutated["onCallPaging"]["status"] = "unknown"
expect_reject("unresolved on-call decision", mutated)

mutated = copy.deepcopy(baseline)
mutated["onCallPaging"]["ownerDecision"] = ""
expect_reject("missing owner decision", mutated)

print("PASS Dokkaebi SRE operating baseline validation passed")
PY
