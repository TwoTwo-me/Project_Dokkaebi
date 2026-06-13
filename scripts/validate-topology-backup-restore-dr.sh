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

DOC_PATH="${TOPOLOGY_BACKUP_DR_PATH:-docs/operations/topology-backup-restore-dr.md}"

for term in \
  "development" \
  "sandbox" \
  "staging" \
  "production" \
  "HA assumption" \
  "backup target" \
  "restore step" \
  "RPO" \
  "RTO" \
  "DR role" \
  "evidence retention" \
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

START = "<!-- topology-backup-dr:begin -->"
END = "<!-- topology-backup-dr:end -->"


class BaselineError(Exception):
    pass


def reject(message: str) -> None:
    raise BaselineError(message)


def extract_payload(text: str) -> dict[str, Any]:
    if not text.strip():
        reject("empty baseline")
    if START not in text or END not in text:
        reject("missing topology backup DR control block")
    block = text.split(START, 1)[1].split(END, 1)[0].strip()
    if block.startswith("```json"):
        block = block.removeprefix("```json").strip()
    if block.endswith("```"):
        block = block[: -len("```")].strip()
    try:
        payload = json.loads(block)
    except json.JSONDecodeError as exc:
        reject(f"malformed topology backup DR JSON: {exc}")
    if not isinstance(payload, dict):
        reject("topology backup DR control block must be an object")
    return payload


def require_nonempty(value: Any, label: str) -> None:
    if value in (None, "", [], {}):
        reject(f"missing {label}")


def validate_payload(payload: dict[str, Any]) -> None:
    if payload.get("permissionLevel") != "docs-only":
        reject("permissionLevel must remain docs-only")
    approval = str(payload.get("approvalGateStatus", "")).lower()
    if "live mutation authorized" in approval:
        reject("unauthorized live mutation wording")
    for term in ["no live", "credential", "production", "infrastructure", "control-plane"]:
        if term not in approval:
            reject(f"approvalGateStatus missing {term}")

    environments = payload.get("environments")
    if not isinstance(environments, dict):
        reject("environments must be an object")
    required_tiers = {"development", "sandbox", "staging", "production"}
    missing_tiers = required_tiers - environments.keys()
    if missing_tiers:
        reject("missing environment tier: " + ", ".join(sorted(missing_tiers)))
    for tier in required_tiers:
        environment = environments.get(tier)
        if not isinstance(environment, dict):
            reject(f"{tier} environment must be an object")
        for field in ["purpose", "isolation", "workerRoutes", "mutationBoundary"]:
            require_nonempty(environment.get(field), f"{tier} {field}")

    ha = payload.get("haAssumptions")
    if not isinstance(ha, dict) or len(ha) < 3:
        reject("missing HA assumption")
    for field in ["fire", "github", "workers"]:
        require_nonempty(ha.get(field), f"HA assumption {field}")

    targets = payload.get("backupTargets")
    if not isinstance(targets, list) or not targets:
        reject("missing backup target")
    for target in targets:
        if not isinstance(target, dict):
            reject("backup target must be an object")
        for field in ["id", "source", "target", "cadence", "retention", "owner", "evidence"]:
            require_nonempty(target.get(field), f"backup target {field}")

    restore = payload.get("restorePlan")
    if not isinstance(restore, dict):
        reject("restorePlan must be an object")
    steps = restore.get("steps")
    if not isinstance(steps, list) or len(steps) < 4:
        reject("missing restore step")
    for field in ["verification", "rpo", "rto"]:
        require_nonempty(restore.get(field), f"restore {field.upper() if field in {'rpo', 'rto'} else field}")

    dr = payload.get("disasterRecovery")
    if not isinstance(dr, dict):
        reject("disasterRecovery must be an object")
    roles = dr.get("roles")
    if not isinstance(roles, dict):
        reject("missing DR role")
    required_roles = {"incidentCommander", "restoreOperator", "fireOperator", "humanApprover", "managerReviewer"}
    missing_roles = required_roles - roles.keys()
    if missing_roles:
        reject("missing DR role: " + ", ".join(sorted(missing_roles)))
    for field in ["failoverDecision", "communicationSurface"]:
        require_nonempty(dr.get(field), f"disaster recovery {field}")

    retention = payload.get("evidenceRetention")
    if not isinstance(retention, dict):
        reject("missing evidence retention")
    for field in ["storageSurface", "retentionPolicy", "immutableExportGap", "redactionPolicy"]:
        require_nonempty(retention.get(field), f"evidence retention {field}")

    drill = payload.get("drillEvidence")
    if not isinstance(drill, dict):
        reject("drillEvidence must be an object")
    shape = drill.get("shape")
    if not isinstance(shape, dict):
        reject("missing drill evidence shape")
    required_shape = {
        "drillId",
        "environment",
        "permissionLevel",
        "backupTarget",
        "restorePoint",
        "rpo",
        "rto",
        "restoreSteps",
        "drRoles",
        "validationOutput",
        "evidenceRetention",
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
del mutated["environments"]["staging"]
expect_reject("missing environment tier", mutated)

mutated = copy.deepcopy(baseline)
mutated["haAssumptions"] = {}
expect_reject("missing HA assumption", mutated)

mutated = copy.deepcopy(baseline)
mutated["backupTargets"] = []
expect_reject("missing backup target", mutated)

mutated = copy.deepcopy(baseline)
mutated["restorePlan"]["steps"] = []
expect_reject("missing restore step", mutated)

mutated = copy.deepcopy(baseline)
mutated["restorePlan"]["rpo"] = ""
expect_reject("missing RPO", mutated)

mutated = copy.deepcopy(baseline)
mutated["restorePlan"]["rto"] = ""
expect_reject("missing RTO", mutated)

mutated = copy.deepcopy(baseline)
del mutated["disasterRecovery"]["roles"]["restoreOperator"]
expect_reject("missing DR role", mutated)

mutated = copy.deepcopy(baseline)
mutated["evidenceRetention"] = {}
expect_reject("missing evidence retention", mutated)

mutated = copy.deepcopy(baseline)
mutated["drillEvidence"]["shape"] = {}
expect_reject("missing drill evidence shape", mutated)

mutated = copy.deepcopy(baseline)
mutated["approvalGateStatus"] = ""
expect_reject("missing approval boundary", mutated)

mutated = copy.deepcopy(baseline)
mutated["approvalGateStatus"] = "live mutation authorized"
expect_reject("unauthorized live mutation wording", mutated)

print("PASS Dokkaebi topology backup restore DR validation passed")
PY
