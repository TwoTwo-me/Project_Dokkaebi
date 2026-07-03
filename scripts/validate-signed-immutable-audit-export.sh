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

DOC_PATH="${SIGNED_IMMUTABLE_AUDIT_EXPORT_PATH:-docs/compliance/signed-immutable-audit-export-key-management-2026-06-13.md}"

for term in \
  "signed manifest storage" "signing-key ownership" "rotation" \
  "revocation" "verification cadence" "retention enforcement" \
  "redaction review" "owner review" "cleanup" "residual risk" \
  "next action" "docs-only local sandbox" "does not authorize"; do
  require_text "$DOC_PATH" "$term"
done

command -v python3 >/dev/null || fail "missing command: python3"
command -v openssl >/dev/null || fail "missing command: openssl"

python3 - "$DOC_PATH" <<'PY'
from __future__ import annotations

import copy
import hashlib
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

JsonValue = None | bool | int | float | str | list["JsonValue"] | dict[str, "JsonValue"]
JsonObject = dict[str, JsonValue]

START = "<!-- signed-immutable-audit-export:begin -->"
END = "<!-- signed-immutable-audit-export:end -->"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
HEX40_RE = re.compile(r"^[0-9a-f]{40}$")
SIGNATURE_RE = re.compile(r"^[0-9a-f]{512}$")
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
    "object store changed",
    "production write completed",
    "proxmox mutation completed",
    "remote host changed",
    "signing service changed",
]


class SignedExportError(Exception):
    pass


def reject(message: str) -> None:
    raise SignedExportError(message)


def extract_payload(text: str) -> JsonObject:
    if not text.strip():
        reject("empty signed export content")
    if START not in text or END not in text:
        reject("missing signed immutable audit export block")
    block = text.split(START, 1)[1].split(END, 1)[0].strip()
    if block.startswith("```json"):
        block = block.removeprefix("```json").strip()
    if block.endswith("```"):
        block = block[: -len("```")].strip()
    try:
        payload = json.loads(block)
    except json.JSONDecodeError as exc:
        reject(f"malformed signed export data: {exc}")
    if not isinstance(payload, dict):
        reject("signed immutable audit export block must be an object")
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


def require_string(value: JsonValue, label: str) -> str:
    require_nonempty(value, label)
    if not isinstance(value, str):
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
            reject(f"unsafe mutation wording: {phrase}")
    if PRIVATE_PATH_RE.search(lowered):
        reject("private local path retained")
    if INTERNAL_LABEL_RE.search(lowered):
        reject("internal execution label retained")


def validate_source_links(source_links: JsonObject) -> None:
    for field in ["issues", "pullRequests", "commits", "validation", "reviewPackages", "resultPackets"]:
        require_list(source_links.get(field), f"source links {field}")
    for field in ["issues", "pullRequests"]:
        for url in require_list(source_links.get(field), f"source links {field}"):
            if not isinstance(url, str) or not url.startswith("https://github.com/"):
                reject(f"source links {field} must contain GitHub URLs")
    for commit in require_list(source_links.get("commits"), "source links commits"):
        if not isinstance(commit, str) or not HEX40_RE.fullmatch(commit):
            reject("source links commits must contain 40-character commit SHAs")


def validate_public_key(public_key: str, expected_fingerprint: str) -> None:
    if "BEGIN PUBLIC KEY" not in public_key or "BEGIN PRIVATE KEY" in public_key:
        reject("public key must be retained without private key material")
    with tempfile.TemporaryDirectory() as tmp:
        public_path = Path(tmp) / "public.pem"
        public_der_path = Path(tmp) / "public.der"
        public_path.write_text(public_key + "\n", encoding="utf-8")
        subprocess.run(
            ["openssl", "pkey", "-pubin", "-in", str(public_path), "-outform", "DER", "-out", str(public_der_path)],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        actual = hashlib.sha256(public_der_path.read_bytes()).hexdigest()
    if actual != expected_fingerprint:
        reject("public key fingerprint mismatch")


def verify_signature(public_key: str, signature_hex: str, canonical_payload: str) -> None:
    with tempfile.TemporaryDirectory() as tmp:
        public_path = Path(tmp) / "public.pem"
        signature_path = Path(tmp) / "signature.bin"
        payload_path = Path(tmp) / "payload.json"
        public_path.write_text(public_key + "\n", encoding="utf-8")
        signature_path.write_bytes(bytes.fromhex(signature_hex))
        payload_path.write_text(canonical_payload, encoding="utf-8")
        result = subprocess.run(
            [
                "openssl",
                "dgst",
                "-sha256",
                "-verify",
                str(public_path),
                "-signature",
                str(signature_path),
                str(payload_path),
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=False,
        )
    if result.returncode != 0 or "Verified OK" not in result.stdout:
        reject("signature verification failed")


def validate_payload(payload: JsonObject) -> None:
    for field in ["version", "permissionLevel", "signedExportManifest"]:
        require_nonempty(payload.get(field), field)
    if payload.get("permissionLevel") != "docs-only-local-sandbox-signed-verification":
        reject("permissionLevel must remain docs-only-local-sandbox-signed-verification")

    manifest = require_object(payload.get("signedExportManifest"), "signed export manifest")
    public_key = require_string(manifest.get("publicKeyPem"), "public key")
    signed_payload = require_object(manifest.get("signedPayload"), "signed payload")
    recorded_hash = require_string(manifest.get("recordedSha256"), "manifest hash")
    signature_hex = require_string(manifest.get("signatureHex"), "signature")
    if not SHA256_RE.fullmatch(recorded_hash):
        reject("manifest hash must be a SHA-256 hex digest")
    if not SIGNATURE_RE.fullmatch(signature_hex):
        reject("signature must be a 2048-bit RSA signature hex digest")
    canonicalization = require_string(manifest.get("canonicalization"), "canonicalization").lower()
    if "canonical json" not in canonicalization or "sorted object keys" not in canonicalization:
        reject("canonicalization must define canonical JSON with sorted object keys")
    algorithm = require_string(manifest.get("signatureAlgorithm"), "signature algorithm").lower()
    if "rsa-2048" not in algorithm or "sha-256" not in algorithm:
        reject("signature algorithm must be RSA-2048 with SHA-256")

    canonical = json.dumps(signed_payload, sort_keys=True, separators=(",", ":"))
    recomputed_hash = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
    if recorded_hash != recomputed_hash:
        reject("manifest hash mismatch")

    for field in ["drillId", "date", "permissionLevel", "packageId", "schemaVersion", "sourceDesign", "verificationReplay"]:
        require_nonempty(signed_payload.get(field), field)
    if signed_payload.get("permissionLevel") != payload.get("permissionLevel"):
        reject("signed payload permissionLevel must match package permissionLevel")

    validate_source_links(require_object(signed_payload.get("sourceLinks"), "source links"))

    storage = require_object(signed_payload.get("signedManifestStorage"), "signed manifest storage")
    for field in ["storageSurface", "signedManifestLocation", "objectLockStatus", "storageOwner", "writeBoundary"]:
        require_nonempty(storage.get(field), f"signed manifest storage {field}")

    key = require_object(signed_payload.get("signingKeyManagement"), "signing-key ownership")
    for field in [
        "keyId",
        "algorithm",
        "publicKeyFingerprintSha256",
        "signingKeyOwner",
        "signingKeyCustodian",
        "privateKeyHandling",
        "rotationCadence",
        "revocationAction",
        "verificationCadence",
    ]:
        require_nonempty(key.get(field), f"signing-key management {field}")
    fingerprint = require_string(key.get("publicKeyFingerprintSha256"), "public key fingerprint")
    if not SHA256_RE.fullmatch(fingerprint):
        reject("public key fingerprint must be SHA-256 hex")
    require_list(key.get("revocationTriggers"), "revocation triggers", 4)
    if "no private key material is retained" not in str(key.get("privateKeyHandling", "")).lower():
        reject("private key handling must state no private key material is retained")
    validate_public_key(public_key, fingerprint)
    verify_signature(public_key, signature_hex, canonical)

    redaction = require_object(signed_payload.get("redactionReview"), "redaction review")
    if redaction.get("status") != "passed" or redaction.get("rawSecretsIncluded") is not False:
        reject("redaction review must pass without raw secrets")
    if redaction.get("privateSigningKeyRetained") is not False:
        reject("private signing key must not be retained")
    excluded_text = " ".join(str(item).lower() for item in require_list(redaction.get("excludedClasses"), "redaction exclusions", 8))
    for term in ["secrets", "auth files", "tokens", "ssh keys", "private signing key material"]:
        if term not in excluded_text:
            reject(f"redaction review missing {term}")

    retention = require_object(signed_payload.get("retentionEnforcement"), "retention enforcement")
    for field in ["duration", "owner", "storageSurface", "deletionOrExtensionDecision", "legalHoldState", "nextReviewDate", "enforcementStatus"]:
        require_nonempty(retention.get(field), f"retention enforcement {field}")

    owner = require_object(signed_payload.get("ownerReview"), "owner review")
    for field in ["packageOwner", "controlOwner", "complianceReviewer", "retentionOwner", "redactionReviewer", "integrityVerifier", "reviewStatus"]:
        require_nonempty(owner.get(field), f"owner review {field}")

    verification = require_object(signed_payload.get("verificationOutput"), "verification output")
    for field in ["command", "result", "verifiedBy", "opensslVersion"]:
        require_nonempty(verification.get(field), f"verification output {field}")
    if "pass" not in str(verification.get("result", "")).lower():
        reject("verification output must record PASS")

    approval = require_string(signed_payload.get("approvalGateStatus"), "approval-gate status").lower()
    if "no live" not in approval or "mutation reached" not in approval:
        reject("approval-gate status must state no live mutation reached")
    cleanup = require_object(signed_payload.get("cleanup"), "cleanup")
    if cleanup.get("status") != "complete":
        reject("cleanup must be complete")
    require_nonempty(cleanup.get("receipt"), "cleanup receipt")
    require_list(signed_payload.get("residualRisk"), "residual risk", 4)
    require_nonempty(signed_payload.get("nextAction"), "next action")
    follow_up = require_string(signed_payload.get("followUpIssueUrl"), "follow-up issue URL")
    if not follow_up.startswith("https://github.com/"):
        reject("follow-up issue URL must be a GitHub URL")
    require_safe_text(signed_payload)


doc_text = Path(sys.argv[1]).read_text(encoding="utf-8")
baseline = extract_payload(doc_text)
validate_payload(baseline)


def expect_reject(name: str, candidate: str | JsonObject) -> None:
    try:
        if isinstance(candidate, str):
            validate_payload(extract_payload(candidate))
        else:
            validate_payload(candidate)
    except SignedExportError:
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


def refresh_recorded_hash(payload: JsonObject) -> None:
    manifest = require_object(payload.get("signedExportManifest"), "signed export manifest")
    signed_payload = require_object(manifest.get("signedPayload"), "signed payload")
    canonical = json.dumps(signed_payload, sort_keys=True, separators=(",", ":"))
    manifest["recordedSha256"] = hashlib.sha256(canonical.encode("utf-8")).hexdigest()


expect_reject("empty signed export content", "")
expect_reject("malformed signed export data", START + "\n```json\n{\"version\": \n```\n" + END)

for name, path in [
    ("missing manifest hash", ("signedExportManifest", "recordedSha256")),
    ("missing signature", ("signedExportManifest", "signatureHex")),
    ("missing public key", ("signedExportManifest", "publicKeyPem")),
    ("missing signed manifest storage", ("signedExportManifest", "signedPayload", "signedManifestStorage")),
    ("missing signing-key ownership", ("signedExportManifest", "signedPayload", "signingKeyManagement")),
    ("missing rotation", ("signedExportManifest", "signedPayload", "signingKeyManagement", "rotationCadence")),
    ("missing revocation", ("signedExportManifest", "signedPayload", "signingKeyManagement", "revocationTriggers")),
    ("missing verification cadence", ("signedExportManifest", "signedPayload", "signingKeyManagement", "verificationCadence")),
    ("missing retention enforcement", ("signedExportManifest", "signedPayload", "retentionEnforcement")),
    ("missing redaction review", ("signedExportManifest", "signedPayload", "redactionReview")),
    ("missing owner review", ("signedExportManifest", "signedPayload", "ownerReview")),
    ("missing cleanup", ("signedExportManifest", "signedPayload", "cleanup")),
    ("missing residual risk", ("signedExportManifest", "signedPayload", "residualRisk")),
    ("missing next action", ("signedExportManifest", "signedPayload", "nextAction")),
]:
    mutated = copy.deepcopy(baseline)
    set_path(mutated, path, "")
    expect_reject(name, mutated)

for name, path, value in [
    ("mismatched manifest hash", ("signedExportManifest", "recordedSha256"), "0" * 64),
    ("mismatched signature", ("signedExportManifest", "signatureHex"), "0" * 512),
]:
    mutated = copy.deepcopy(baseline)
    set_path(mutated, path, value)
    expect_reject(name, mutated)

for name, path, value in [
    ("private key material retained", ("signedExportManifest", "publicKeyPem"), "-----BEGIN " + "PRIVATE KEY-----\nnot-retained\n-----END " + "PRIVATE KEY-----"),
    ("redaction review failed", ("signedExportManifest", "signedPayload", "redactionReview", "status"), "failed"),
    ("private signing key retained", ("signedExportManifest", "signedPayload", "redactionReview", "privateSigningKeyRetained"), True),
    ("approval mutation changes hash", ("signedExportManifest", "signedPayload", "approvalGateStatus"), "credential used and production write completed"),
    ("cleanup mutation changes hash", ("signedExportManifest", "signedPayload", "cleanup", "receipt"), HOME_SEGMENT + "sam/.ssh/id_rsa retained"),
    ("unsafe storage mutation changes hash", ("signedExportManifest", "signedPayload", "signedManifestStorage", "writeBoundary"), "object store changed"),
    ("internal execution label rejected", ("signedExportManifest", "signedPayload", "nextAction"), "run " + INTERNAL_LABELS[0] + " workflow"),
]:
    mutated = copy.deepcopy(baseline)
    set_path(mutated, path, value)
    refresh_recorded_hash(mutated)
    expect_reject(name, mutated)

print("PASS Dokkaebi signed immutable audit export validation passed")
PY
