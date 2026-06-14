#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}

DOC_PATH="${DURABLE_BACKUP_RESTORE_VERIFICATION_PATH:-docs/operations/durable-backup-restore-verification-2026-06-14.md}"

[[ -f "$DOC_PATH" ]] || fail "missing file: $DOC_PATH"

for term in \
  "Durable Backup Restore Verification" \
  "project exports" \
  "lease/retry state" \
  "route-result summaries" \
  "evidence packages" \
  "Measured RPO" \
  "Measured RTO" \
  "retention checks" \
  "redaction checks" \
  "approval-gate status" \
  "Cleanup receipt" \
  "does not authorize"; do
  grep -Fqi -- "$term" "$DOC_PATH" || fail "missing text in $DOC_PATH: $term"
done

command -v python3 >/dev/null || fail "missing command: python3"

python3 - "$DOC_PATH" <<'PY'
from __future__ import annotations

import copy
import hashlib
import json
import re
import shutil
import sys
import tempfile
import time
from datetime import datetime
from pathlib import Path
from typing import Any

START = "<!-- durable-backup-restore-verification:begin -->"
END = "<!-- durable-backup-restore-verification:end -->"
REQUIRED_CLASSES = [
    "project_exports",
    "lease_retry_state",
    "route_result_summaries",
    "evidence_packages",
]
EXPECTED_CLASS_HASHES = {
    "project_exports": "6fb6eb89f275b6e99554e7295eaed007c0014d8cf1d9ce152144f846c31bd36b",
    "lease_retry_state": "1138e2cbfa9e371bc8051c9fbe6fccf1c8eb644e5ffab0edf3e8a8e4cba8d6fa",
    "route_result_summaries": "47ef9ac714774db09e3062ba8e50524fb740d1f1867aa0d568f4255e3d6b48f9",
    "evidence_packages": "b35ae715e0250ef0a5c09de533314105a804e5787152d25a21295750224ca637",
}
EXPECTED_BUNDLE_HASH = "88fd25ef392a251ee37838f7387b7825a4b5ed818cc4e95ad90e688aa4d8686e"
HOME_SEGMENT = "/" + "home" + "/"
USERS_SEGMENT = "/" + "Users" + "/"
PRIVATE_PATH_RE = re.compile(r"(" + re.escape(HOME_SEGMENT) + "|" + re.escape(USERS_SEGMENT) + r")[^\s`'\"]+")
INTERNAL_LABELS = ["".join(parts) for parts in [("o", "mo"), ("o", "mx"), ("u", "lw")]]
INTERNAL_LABEL_RE = re.compile(r"\b(" + "|".join(INTERNAL_LABELS) + r")\b", re.IGNORECASE)
SECRET_TERMS = ["cookie=", "private_key=", "sec" + "ret=", "to" + "ken=", "authorization: bearer"]
UNSAFE_PHRASES = [
    "runtime mutation completed",
    "remote host changed",
    "ssh mutation completed",
    "docker mutation completed",
    "kubernetes mutation completed",
    "proxmox mutation completed",
    "credential copied",
    "production restore completed",
    "deployment executed",
    "infrastructure mutated",
    "github project control-plane mutation completed",
]


class VerificationError(Exception):
    pass


def reject(message: str) -> None:
    raise VerificationError(message)


def canonical(value: Any) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")


def sha256(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def fixture_payloads() -> dict[str, Any]:
    return {
        "project_exports": {
            "githubProject": {
                "id": "sandbox-project-export",
                "fields": ["Status", "Agent", "Permission Level"],
                "items": [{"issue": 86, "status": "Ready for local verification"}],
            },
            "repository": {"name": "Project_Dokkaebi", "defaultBranch": "main"},
        },
        "lease_retry_state": {
            "leases": [{"workId": "issue-86", "leaseToken": "sanitized-lease-token", "state": "completed"}],
            "retries": [{"workId": "issue-86", "retryCount": 0, "nextRetryAt": None}],
        },
        "route_result_summaries": {
            "routes": [
                {"provider": "local_worktree", "selected": True, "skipReason": None},
                {"provider": "ssh_worker", "selected": False, "skipReason": "not used for local verification"},
            ],
            "resultPackets": [
                {"workId": "issue-86", "status": "passed", "validation": "durable backup restore verification"}
            ],
        },
        "evidence_packages": {
            "packages": [
                {
                    "id": "issue-86-evidence",
                    "contains": ["validation output", "approval gate status", "cleanup receipt"],
                    "secretsIncluded": False,
                }
            ],
            "retentionDays": 30,
        },
    }


def extract_payload(text: str) -> dict[str, Any]:
    if not text.strip():
        reject("empty durable backup verification content")
    if text.count(START) != 1 or text.count(END) != 1:
        reject("missing or duplicate durable backup verification block")
    block = text.split(START, 1)[1].split(END, 1)[0].strip()
    if block.startswith("```json"):
        block = block.removeprefix("```json").strip()
    if block.endswith("```"):
        block = block[: -len("```")].strip()
    try:
        payload = json.loads(block)
    except json.JSONDecodeError as exc:
        reject(f"malformed durable backup verification data: {exc}")
    if not isinstance(payload, dict):
        reject("durable backup verification block must be an object")
    return payload


def require_text(value: Any, label: str, terms: list[str] | None = None) -> str:
    if not isinstance(value, str) or not value.strip():
        reject(f"missing {label}")
    lowered = value.lower()
    for term in terms or []:
        if term.lower() not in lowered:
            reject(f"{label} missing {term}")
    return value


def require_int(value: Any, label: str) -> int:
    if type(value) is not int or value < 0:
        reject(f"missing {label}")
    return value


def require_bool(value: Any, label: str) -> bool:
    if type(value) is not bool:
        reject(f"missing {label}")
    return value


def require_dict(value: Any, label: str) -> dict[str, Any]:
    if not isinstance(value, dict) or not value:
        reject(f"missing {label}")
    return value


def require_list(value: Any, label: str, min_items: int = 1) -> list[Any]:
    if not isinstance(value, list) or len(value) < min_items:
        reject(f"missing {label}")
    return value


def require_timestamp(value: Any, label: str) -> datetime:
    text = require_text(value, label)
    try:
        return datetime.fromisoformat(text.replace("Z", "+00:00"))
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
    if INTERNAL_LABEL_RE.search(lowered):
        reject("private execution label retained")


def validate_payload(payload: dict[str, Any]) -> None:
    if payload.get("version") != 1:
        reject("version must be 1")
    if payload.get("issueUrl") != "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/86":
        reject("issueUrl must point to issue #86")
    require_text(payload.get("verificationId"), "verification id", ["issue-86"])
    require_text(payload.get("date"), "date")
    require_text(payload.get("permissionLevel"), "permission level", ["docs", "local", "validation"])

    boundary = require_text(payload.get("approvalBoundary"), "approval boundary")
    for term in [
        "repository-local temporary fixture",
        "backup staging",
        "restore replay",
        "hash comparison",
        "does not authorize",
        "runtime",
        "remote host",
        "ssh",
        "docker",
        "kubernetes",
        "proxmox",
        "credential",
        "production",
        "deployment",
        "infrastructure",
        "github project control-plane mutation",
        "explicit human approval",
    ]:
        if term not in boundary.lower():
            reject(f"approval boundary missing {term}")

    classes = require_list(payload.get("backupClasses"), "backup classes", 4)
    class_ids = [item.get("id") for item in classes if isinstance(item, dict)]
    if class_ids != REQUIRED_CLASSES:
        reject("backup classes must appear in required order")
    for item in classes:
        class_id = item["id"]
        require_text(item.get("description"), f"{class_id} description")
        expected_hash = EXPECTED_CLASS_HASHES[class_id]
        if item.get("sourceSha256") != expected_hash:
            reject(f"{class_id} source hash mismatch")
        if item.get("restoredSha256") != expected_hash:
            reject(f"{class_id} restored hash mismatch")
        if require_bool(item.get("restoreVerified"), f"{class_id} restoreVerified") is not True:
            reject(f"{class_id} restore must be verified")
        if require_int(item.get("retentionDays"), f"{class_id} retentionDays") < 30:
            reject(f"{class_id} retention must be at least 30 days")
        require_text(item.get("redactionCheck"), f"{class_id} redaction check")

    run = require_dict(payload.get("verificationRun"), "verification run")
    if run.get("command") != "bash scripts/validate-durable-backup-restore-verification.sh":
        reject("verification command mismatch")
    if require_bool(run.get("localExecutable"), "localExecutable") is not True:
        reject("verification run must be local executable")
    require_text(run.get("fixtureRoot"), "fixture root", ["temporary", "removed"])
    if run.get("backupBundleSha256") != EXPECTED_BUNDLE_HASH:
        reject("backup bundle hash mismatch")
    restore_point = require_timestamp(run.get("restorePointTimestamp"), "restore point timestamp")
    started = require_timestamp(run.get("restoreStartedAt"), "restore started timestamp")
    completed = require_timestamp(run.get("restoreCompletedAt"), "restore completed timestamp")
    if restore_point > started or started > completed:
        reject("restore timestamps must be ordered")
    rpo_observed = require_int(run.get("rpoObservedSeconds"), "rpo observed seconds")
    rpo_target = require_int(run.get("rpoTargetSeconds"), "rpo target seconds")
    rto_observed = require_int(run.get("rtoObservedSeconds"), "rto observed seconds")
    rto_target = require_int(run.get("rtoTargetSeconds"), "rto target seconds")
    if rpo_observed > rpo_target:
        reject("RPO observed seconds must not exceed target")
    if rto_observed > rto_target:
        reject("RTO observed seconds must not exceed target")
    output = " ".join(str(item).lower() for item in require_list(run.get("output"), "verification output", 7))
    for term in REQUIRED_CLASSES + ["retention policy checks passed", "redaction checks passed", "cleanup receipt"]:
        if term not in output:
            reject(f"verification output missing {term}")

    retention = require_list(payload.get("retentionPolicyChecks"), "retention policy checks", 4)
    retention_ids = [item.get("backupClass") for item in retention if isinstance(item, dict)]
    if retention_ids != REQUIRED_CLASSES:
        reject("retention checks must cover every backup class")
    for item in retention:
        if require_int(item.get("minimumRetentionDays"), "minimum retention days") < 30:
            reject("minimum retention must be at least 30 days")
        if require_int(item.get("actualRetentionDays"), "actual retention days") < item["minimumRetentionDays"]:
            reject("actual retention must satisfy minimum retention")
        if item.get("status") != "passed":
            reject("retention check must pass")

    redaction = require_dict(payload.get("redactionChecks"), "redaction checks")
    for field in [
        "rawSensitiveValuesIncluded",
        "authenticationMaterialIncluded",
        "privateMachineStateIncluded",
        "privateLocalPathsIncluded",
    ]:
        if redaction.get(field) is not False:
            reject(f"redaction check must keep {field} false")
    require_list(redaction.get("redactionManifest"), "redaction manifest", 4)

    approval = require_text(payload.get("approvalGateStatus"), "approval-gate status")
    for term in [
        "repository-local temporary fixture",
        "no runtime",
        "remote host",
        "docker",
        "kubernetes",
        "proxmox",
        "credential",
        "production",
        "deployment",
        "infrastructure",
        "github project control-plane mutation",
        "mutation reached",
    ]:
        if term not in approval.lower():
            reject(f"approval-gate status missing {term}")

    cleanup = require_dict(payload.get("cleanupReceipt"), "cleanup receipt")
    if cleanup.get("status") != "complete":
        reject("cleanup receipt must be complete")
    require_text(cleanup.get("receipt"), "cleanup receipt text", ["removed"])
    require_text(cleanup.get("retainedEvidence"), "retained evidence", ["checked-in"])

    residual = " ".join(str(item).lower() for item in require_list(payload.get("residualRisk"), "residual risk", 3))
    for term in ["no production", "explicit human approval", "issue #103"]:
        if term not in residual:
            reject(f"residual risk missing {term}")
    require_text(payload.get("nextAction"), "next action", ["issue #103"])
    require_safe_text(payload)


def run_local_verification() -> None:
    fixtures = fixture_payloads()
    actual_hashes = {name: sha256(canonical(value)) for name, value in fixtures.items()}
    if actual_hashes != EXPECTED_CLASS_HASHES:
        reject("fixture class hashes do not match expected hashes")
    if sha256(canonical(fixtures)) != EXPECTED_BUNDLE_HASH:
        reject("fixture bundle hash does not match expected hash")

    root_path: Path | None = None
    started = time.monotonic()
    try:
        root_path = Path(tempfile.mkdtemp(prefix="dokkaebi-durable-backup-"))
        source = root_path / "source"
        backup = root_path / "backup"
        restore = root_path / "restore"
        for directory in [source, backup, restore]:
            directory.mkdir(parents=True, exist_ok=False)

        for name, value in fixtures.items():
            (source / f"{name}.json").write_bytes(canonical(value))
            shutil.copy2(source / f"{name}.json", backup / f"{name}.json")
            shutil.copy2(backup / f"{name}.json", restore / f"{name}.json")

        for name, expected in EXPECTED_CLASS_HASHES.items():
            source_hash = sha256((source / f"{name}.json").read_bytes())
            backup_hash = sha256((backup / f"{name}.json").read_bytes())
            restored_hash = sha256((restore / f"{name}.json").read_bytes())
            if len({source_hash, backup_hash, restored_hash, expected}) != 1:
                reject(f"local restore hash mismatch for {name}")

        elapsed_seconds = int(time.monotonic() - started)
        if elapsed_seconds > 14400:
            reject("local verification exceeded RTO target")
    finally:
        if root_path is not None:
            shutil.rmtree(root_path, ignore_errors=True)
            if root_path.exists():
                reject("temporary verification fixture was not removed")


def expect_reject(label: str, candidate: dict[str, Any] | str) -> None:
    try:
        if isinstance(candidate, str):
            validate_payload(extract_payload(candidate))
        else:
            validate_payload(candidate)
    except VerificationError:
        return
    reject(f"negative fixture unexpectedly passed: {label}")


doc = Path(sys.argv[1])
payload = extract_payload(doc.read_text(encoding="utf-8"))
validate_payload(payload)
run_local_verification()

expect_reject("empty doc", "")
expect_reject("malformed json", START + "\n```json\n{\"version\": \n```\n" + END)

for field in [
    "backupClasses",
    "verificationRun",
    "retentionPolicyChecks",
    "redactionChecks",
    "approvalBoundary",
    "approvalGateStatus",
    "cleanupReceipt",
    "residualRisk",
]:
    mutated = copy.deepcopy(payload)
    mutated[field] = []
    expect_reject(f"missing {field}", mutated)

mutated = copy.deepcopy(payload)
mutated["backupClasses"] = mutated["backupClasses"][:-1]
expect_reject("missing backup class", mutated)

mutated = copy.deepcopy(payload)
mutated["backupClasses"][0]["restoredSha256"] = "0" * 64
expect_reject("mismatched restored hash", mutated)

mutated = copy.deepcopy(payload)
mutated["backupClasses"][1]["retentionDays"] = 7
expect_reject("insufficient class retention", mutated)

mutated = copy.deepcopy(payload)
mutated["verificationRun"]["rpoObservedSeconds"] = 90000
expect_reject("failed RPO", mutated)

mutated = copy.deepcopy(payload)
mutated["verificationRun"]["rtoObservedSeconds"] = 20000
expect_reject("failed RTO", mutated)

mutated = copy.deepcopy(payload)
mutated["retentionPolicyChecks"][0]["status"] = "failed"
expect_reject("failed retention check", mutated)

mutated = copy.deepcopy(payload)
mutated["redactionChecks"]["authenticationMaterialIncluded"] = True
expect_reject("failed redaction check", mutated)

mutated = copy.deepcopy(payload)
mutated["cleanupReceipt"]["status"] = "pending"
expect_reject("missing cleanup", mutated)

mutated = copy.deepcopy(payload)
mutated["approvalGateStatus"] = "production restore completed"
expect_reject("unsafe authority wording", mutated)

mutated = copy.deepcopy(payload)
mutated["nextAction"] = HOME_SEGMENT + "sam/private"
expect_reject("private local path", mutated)

mutated = copy.deepcopy(payload)
mutated["verificationRun"]["output"].append("to" + "ken=example")
expect_reject("secret-bearing evidence", mutated)

print("PASS Dokkaebi durable backup restore verification passed")
PY
