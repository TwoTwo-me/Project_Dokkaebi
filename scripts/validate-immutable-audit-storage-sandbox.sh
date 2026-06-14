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

DOC_PATH="${IMMUTABLE_AUDIT_STORAGE_SANDBOX_PATH:-docs/compliance/immutable-audit-storage-sandbox-2026-06-14.md}"
RUNNER_PATH="scripts/run-immutable-audit-storage-sandbox.sh"

for term in \
  "immutable audit storage sandbox gate" \
  "signed manifest storage" \
  "retained public-key metadata" \
  "object-lock-equivalent" \
  "retention enforcement" \
  "legal-hold state" \
  "deletion or extension decision" \
  "owner review" \
  "redaction review" \
  "validation output" \
  "approval-gate status" \
  "cleanup receipt" \
  "does not authorize"; do
  require_text "$DOC_PATH" "$term"
done

[[ -f "$RUNNER_PATH" ]] || fail "missing runner: $RUNNER_PATH"
command -v python3 >/dev/null || fail "missing command: python3"

python3 - "$DOC_PATH" "$RUNNER_PATH" <<'PY'
from __future__ import annotations

import copy
import hashlib
import json
import re
import subprocess
import sys
from datetime import date
from pathlib import Path
from typing import Any

START = "<!-- immutable-audit-storage-sandbox:begin -->"
END = "<!-- immutable-audit-storage-sandbox:end -->"
EXPECTED_ISSUE = "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/88"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
MANIFEST_FIELDS = [
    "storageTarget",
    "storedObjects",
    "verificationOutput",
    "retentionEnforcement",
    "validationOutput",
    "approvalGateStatus",
    "cleanup",
    "residualRisk",
    "readinessDecision",
]
VALIDATION_OUTPUT = {
    "bash scripts/run-immutable-audit-storage-sandbox.sh: PASS",
    "bash scripts/validate-immutable-audit-storage-sandbox.sh: PASS",
    "bash scripts/validate-signed-immutable-audit-export.sh: PASS",
    "bash scripts/validate-immutable-audit-export.sh: PASS",
    "bash scripts/validate-immutable-audit-export-verification.sh: PASS",
    "bash scripts/validate-compliance-package.sh: PASS",
    "bash scripts/validate-compliance-audit-review.sh: PASS",
    "bash scripts/validate-readiness-criteria.sh: PASS",
    "bash scripts/validate-contract-docs.sh: PASS",
    "bash scripts/validate-git-governance.sh: PASS",
}
DENIED_TERMS = [
    "credential",
    "infrastructure",
    "worker",
    "remote host",
    "docker",
    "kubernetes",
    "deployment",
    "production",
    "immutable storage service",
    "retention service",
    "signing service",
    "github project",
]
HOME_SEGMENT = "/" + "home" + "/"
USERS_SEGMENT = "/" + "users" + "/"
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
UNSAFE_PATTERNS = [
    ("credential use claim", r"\bcredentials?\s+(were|was|are|is)?\s*(used|loaded|granted)\b"),
    ("service mutation claim", r"\b(object store|immutable storage service|retention service|signing service)\s+(was\s+)?(created|started|changed|mutated|updated)\b"),
    ("deployment claim", r"\b(deployment|production write|infrastructure change)\s+(was\s+)?(performed|completed|executed)\b"),
    ("container claim", r"\b(docker|kubernetes)\s+(resource|cluster|container|job)\s+(was\s+)?(created|started|mutated)\b"),
    ("project settings claim", r"\bgithub project\s+(field|settings|control-plane)\s+(was\s+)?(created|updated|mutated)\b"),
]


class StorageGateError(Exception):
    pass


def reject(message: str) -> None:
    raise StorageGateError(message)


def joined(value: Any) -> str:
    if isinstance(value, dict):
        return " ".join(f"{key} {joined(val)}" for key, val in value.items())
    if isinstance(value, list):
        return " ".join(joined(item) for item in value)
    return str(value)


def require_safe(value: Any, label: str) -> None:
    text = joined(value)
    lowered = text.lower()
    for term in SECRET_TERMS:
        if term in lowered:
            reject(f"secret-bearing {label}: {term}")
    for name, pattern in UNSAFE_PATTERNS:
        if re.search(pattern, text, re.IGNORECASE):
            reject(f"unsafe mutation {label}: {name}")
    if PRIVATE_PATH_RE.search(text):
        reject(f"private local path retained in {label}")
    if INTERNAL_LABEL_RE.search(text):
        reject(f"internal execution label retained in {label}")


def extract(text: str) -> dict[str, Any]:
    if not text.strip():
        reject("empty immutable audit storage sandbox content")
    if text.count(START) != 1 or text.count(END) != 1:
        reject("missing or duplicate immutable audit storage sandbox block")
    block = text.split(START, 1)[1].split(END, 1)[0].strip()
    if block.startswith("```json"):
        block = block.removeprefix("```json").strip()
    if block.endswith("```"):
        block = block[:-3].strip()
    try:
        payload = json.loads(block)
    except json.JSONDecodeError as exc:
        reject(f"malformed immutable audit storage sandbox data: {exc}")
    if not isinstance(payload, dict):
        reject("immutable audit storage sandbox block must be an object")
    return payload


def nonempty(value: Any, label: str) -> Any:
    if value in (None, "", [], {}):
        reject(f"missing {label}")
    return value


def require_list(value: Any, label: str, minimum: int = 1) -> list[Any]:
    if not isinstance(value, list) or len(value) < minimum:
        reject(f"missing {label}")
    return value


def fields(value: Any, label: str, names: list[str]) -> dict[str, Any]:
    if not isinstance(value, dict):
        reject(f"missing {label}")
    for name in names:
        nonempty(value.get(name), f"{label} {name}")
    return value


def manifest_hash(payload: dict[str, Any]) -> str:
    manifest = {field: payload[field] for field in MANIFEST_FIELDS}
    return hashlib.sha256(json.dumps(manifest, sort_keys=True).encode()).hexdigest()


def parse_runner_output(output: str) -> dict[str, Any]:
    if "PASS Dokkaebi immutable audit storage sandbox runner completed" not in output:
        reject("runner PASS line missing")
    start = output.find("{")
    if start < 0:
        reject("runner JSON missing")
    try:
        payload = json.loads(output[start:])
    except json.JSONDecodeError as exc:
        reject(f"runner JSON malformed: {exc}")
    if not isinstance(payload, dict):
        reject("runner JSON must be an object")
    return payload


def run_runner(path: Path) -> dict[str, Any]:
    completed = subprocess.run(["bash", str(path)], text=True, capture_output=True, check=False)
    if completed.returncode != 0:
        reject("runner failed: " + completed.stderr.strip())
    output = completed.stdout + completed.stderr
    require_safe(output, "runner output")
    payload = parse_runner_output(output)
    validate_payload(payload)
    return payload


def validate_storage(payload: dict[str, Any]) -> None:
    target = fields(payload.get("storageTarget"), "storage target", ["target", "backend", "objectLockEquivalent", "mutationBoundary"])
    if "local sandbox" not in str(target["target"]).lower():
        reject("storage target must be local sandbox")
    lock = fields(
        target["objectLockEquivalent"],
        "object-lock-equivalent policy",
        ["mode", "retentionUntil", "deleteBeforeRetention", "overwriteExistingObject", "legalHoldSupported", "versionedObjectKey"],
    )
    if str(lock["mode"]).lower() != "governance":
        reject("object-lock mode must be governance")
    if lock["deleteBeforeRetention"] != "block" or lock["overwriteExistingObject"] != "block":
        reject("object-lock equivalent policy must block delete and overwrite")
    if lock["legalHoldSupported"] is not True:
        reject("object-lock equivalent policy must support legal hold")
    try:
        date.fromisoformat(str(lock["retentionUntil"]))
    except ValueError:
        reject("retentionUntil must be ISO yyyy-mm-dd")


def validate_stored_objects(payload: dict[str, Any]) -> None:
    objects = fields(payload.get("storedObjects"), "stored objects", ["signedManifest", "publicKeyMetadata", "retentionPolicy"])
    signed = fields(
        objects["signedManifest"],
        "stored signed manifest",
        ["source", "packageId", "schemaVersion", "recordedSha256", "signatureVerificationOutput", "storedObjectKey", "writeOnce"],
    )
    if signed["source"] != "docs/compliance/signed-immutable-audit-export-key-management-2026-06-13.md":
        reject("stored signed manifest source mismatch")
    if not SHA256_RE.fullmatch(str(signed["recordedSha256"])):
        reject("stored signed manifest hash must be sha256")
    if signed["signatureVerificationOutput"] != "Verified OK":
        reject("stored signed manifest signature must be verified")
    if signed["writeOnce"] is not True:
        reject("stored signed manifest must be write-once")
    public = fields(
        objects["publicKeyMetadata"],
        "public key metadata",
        ["source", "keyId", "algorithm", "publicKeyFingerprintSha256", "rotationCadence", "revocationAction", "verificationCadence", "privateKeyRetained"],
    )
    if not SHA256_RE.fullmatch(str(public["publicKeyFingerprintSha256"])):
        reject("public key fingerprint must be sha256")
    if public["privateKeyRetained"] is not False:
        reject("private key must not be retained")
    policy = fields(
        objects["retentionPolicy"],
        "retention policy",
        ["duration", "owner", "storageSurface", "deletionOrExtensionDecision", "legalHoldState", "nextReviewDate", "enforcementStatus"],
    )
    if "block" not in str(policy["enforcementStatus"]).lower():
        reject("retention policy must enforce blocking behavior")


def validate_payload(payload: dict[str, Any]) -> None:
    required = [
        "version",
        "evidenceId",
        "date",
        "issueUrl",
        "permissionLevel",
        "approvalRecord",
        "runner",
        "storageTarget",
        "storedObjects",
        "verificationOutput",
        "retentionEnforcement",
        "validationOutput",
        "approvalGateStatus",
        "cleanup",
        "residualRisk",
        "readinessDecision",
        "nextAction",
        "manifestSha256",
    ]
    for field in required:
        nonempty(payload.get(field), field)
    if payload["version"] != 1:
        reject("version must be 1")
    try:
        date.fromisoformat(str(payload["date"]))
    except ValueError:
        reject("date must be ISO yyyy-mm-dd")
    if payload["issueUrl"] != EXPECTED_ISSUE:
        reject("issue URL must point to issue 88")
    if payload["permissionLevel"] != "approved-local-sandbox-immutable-audit-storage":
        reject("permission level mismatch")

    approval = fields(payload["approvalRecord"], "approval record", ["approvedTarget", "scope", "deniedTargets", "evidence"])
    approval_text = joined(approval).lower()
    for term in ["local", "sandbox", "issue #88"]:
        if term not in approval_text:
            reject(f"approval record missing {term}")
    denied = " ".join(str(item).lower() for item in require_list(approval["deniedTargets"], "denied targets", 10))
    for term in DENIED_TERMS:
        if term not in denied:
            reject(f"approval denied targets missing {term}")

    runner = fields(payload["runner"], "runner", ["path", "command", "outputContract", "result"])
    if runner["path"] != "scripts/run-immutable-audit-storage-sandbox.sh":
        reject("runner path mismatch")
    if runner["command"] != "bash scripts/run-immutable-audit-storage-sandbox.sh":
        reject("runner command mismatch")
    if "PASS Dokkaebi immutable audit storage sandbox runner completed" not in str(runner["result"]):
        reject("runner output missing pass result")

    validate_storage(payload)
    validate_stored_objects(payload)

    verification = fields(
        payload["verificationOutput"],
        "verification output",
        ["sourceValidator", "storageValidator", "verifiedFromStorageTarget", "recordedManifestHash", "retainedPublicKeyFingerprintSha256", "signatureResult", "storageIntegrityResult"],
    )
    if verification["verifiedFromStorageTarget"] is not True:
        reject("verification must come from storage target")
    if not SHA256_RE.fullmatch(str(verification["recordedManifestHash"])):
        reject("verification manifest hash must be sha256")
    if not SHA256_RE.fullmatch(str(verification["retainedPublicKeyFingerprintSha256"])):
        reject("verification public key fingerprint must be sha256")
    if verification["signatureResult"] != "Verified OK":
        reject("signature result must be verified")
    if "PASS" not in str(verification["storageIntegrityResult"]):
        reject("storage integrity result must pass")

    retention = fields(
        payload["retentionEnforcement"],
        "retention enforcement",
        ["deleteBeforeRetentionDecision", "overwriteDecision", "legalHoldState", "deletionOrExtensionDecision", "ownerReview", "redactionReview"],
    )
    if retention["deleteBeforeRetentionDecision"] != "block" or retention["overwriteDecision"] != "block":
        reject("retention enforcement must block delete and overwrite")
    fields(retention["ownerReview"], "owner review", ["packageOwner", "controlOwner", "complianceReviewer", "retentionOwner", "reviewStatus"])
    redaction = fields(retention["redactionReview"], "redaction review", ["reviewer", "status", "rawSecretsIncluded", "privateSigningKeyRetained", "excludedClasses"])
    if redaction["rawSecretsIncluded"] is not False or redaction["privateSigningKeyRetained"] is not False:
        reject("redaction review must exclude raw secrets and private signing key")
    require_list(redaction["excludedClasses"], "redaction excluded classes", 6)

    validation = [str(item) for item in require_list(payload["validationOutput"], "validation output", len(VALIDATION_OUTPUT))]
    missing_output = VALIDATION_OUTPUT - set(validation)
    if missing_output:
        reject("validation output missing exact PASS commands: " + ", ".join(sorted(missing_output)))

    approval_status = str(payload["approvalGateStatus"]).lower()
    for term in ["approved local sandbox", "no credential", "immutable storage service", "retention service", "signing service", "not authorized"]:
        if term not in approval_status:
            reject(f"approval-gate status missing {term}")
    cleanup = fields(payload["cleanup"], "cleanup", ["status", "receipt"])
    if cleanup["status"] != "complete":
        reject("cleanup status must be complete")
    if "no resources remain" not in str(cleanup["receipt"]).lower():
        reject("cleanup receipt must state no resources remain")
    residual = " ".join(str(item).lower() for item in require_list(payload["residualRisk"], "residual risk", 3))
    for term in ["immutable object storage", "retention service", "signing service"]:
        if term not in residual:
            reject(f"residual risk missing {term}")
    readiness = fields(payload["readinessDecision"], "readiness decision", ["compliance_audit", "compliance_package", "immutable_audit_export", "basis"])
    if readiness["compliance_audit"] != 100 or readiness["compliance_package"] != 100 or readiness["immutable_audit_export"] != 100:
        reject("readiness decision must score compliance and immutable export evidence at 100")
    if "human approval" not in str(payload["nextAction"]).lower():
        reject("next action must retain Human approval boundary")
    if not SHA256_RE.fullmatch(str(payload["manifestSha256"])):
        reject("manifest hash must be sha256")
    if payload["manifestSha256"] != manifest_hash(payload):
        reject("manifest hash mismatch")
    require_safe(payload, "payload")


def mutate(payload: dict[str, Any], path: tuple[Any, ...], value: Any, *, refresh: bool = True) -> dict[str, Any]:
    changed = copy.deepcopy(payload)
    target: Any = changed
    for key in path[:-1]:
        target = target[key]
    target[path[-1]] = value
    if refresh and "manifestSha256" in changed and all(field in changed for field in MANIFEST_FIELDS):
        changed["manifestSha256"] = manifest_hash(changed)
    return changed


def expect_reject(name: str, candidate: str | dict[str, Any]) -> None:
    try:
        if isinstance(candidate, str):
            validate_payload(extract(candidate))
        else:
            validate_payload(candidate)
    except StorageGateError:
        return
    reject(f"negative fixture unexpectedly passed: {name}")


doc_text = Path(sys.argv[1]).read_text(encoding="utf-8")
require_safe(doc_text, "document")
baseline = extract(doc_text)
validate_payload(baseline)
runner_payload = run_runner(Path(sys.argv[2]))
if baseline["manifestSha256"] != runner_payload["manifestSha256"]:
    reject("document manifest hash must match runner manifest hash")

expect_reject("empty content", "")
expect_reject("malformed data", START + "\n```json\n{\"version\": \n```\n" + END)
for field in ["approvalRecord", "runner", "storageTarget", "storedObjects", "verificationOutput", "retentionEnforcement", "cleanup", "residualRisk"]:
    expect_reject(f"missing {field}", mutate(baseline, (field,), ""))
expect_reject("wrong issue", mutate(baseline, ("issueUrl",), "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/1"))
expect_reject("missing object lock", mutate(baseline, ("storageTarget", "objectLockEquivalent"), {}))
expect_reject("mutable delete", mutate(baseline, ("storageTarget", "objectLockEquivalent", "deleteBeforeRetention"), "allow"))
expect_reject("missing signed manifest", mutate(baseline, ("storedObjects", "signedManifest"), {}))
expect_reject("bad signed hash", mutate(baseline, ("storedObjects", "signedManifest", "recordedSha256"), "not-a-hash"))
expect_reject("missing public key metadata", mutate(baseline, ("storedObjects", "publicKeyMetadata"), {}))
expect_reject("private key retained", mutate(baseline, ("storedObjects", "publicKeyMetadata", "privateKeyRetained"), True))
expect_reject("not verified from storage", mutate(baseline, ("verificationOutput", "verifiedFromStorageTarget"), False))
expect_reject("signature not verified", mutate(baseline, ("verificationOutput", "signatureResult"), "failed"))
expect_reject("retention delete allowed", mutate(baseline, ("retentionEnforcement", "deleteBeforeRetentionDecision"), "allow"))
expect_reject("missing owner review", mutate(baseline, ("retentionEnforcement", "ownerReview"), {}))
expect_reject("missing redaction review", mutate(baseline, ("retentionEnforcement", "redactionReview"), {}))
expect_reject("secret-like evidence", mutate(baseline, ("nextAction",), "gh" + "p_" + "A" * 20))
expect_reject("private path", mutate(baseline, ("cleanup", "receipt"), HOME_SEGMENT + "private/export"))
expect_reject("unsafe service mutation", mutate(baseline, ("nextAction",), "immutable storage service was created"))
bad_hash = mutate(baseline, ("manifestSha256",), "0" * 64, refresh=False)
expect_reject("mismatched runner manifest output", bad_hash)

print("PASS Dokkaebi immutable audit storage sandbox validation passed")
PY
