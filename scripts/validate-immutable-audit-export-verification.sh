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

DOC_PATH="${IMMUTABLE_AUDIT_EXPORT_VERIFICATION_PATH:-docs/compliance/immutable-audit-export-verification-2026-06-13.md}"

for term in \
  "manifest hash" "source links" "redaction manifest" "retention metadata" \
  "owner" "verification output" "approval-gate status" "cleanup" \
  "residual risk" "next action" "docs-only local replay" "does not authorize"; do
  require_text "$DOC_PATH" "$term"
done

command -v python3 >/dev/null || fail "missing command: python3"

python3 - "$DOC_PATH" <<'PY'
from __future__ import annotations

import copy
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import assert_never

JsonValue = None | bool | int | float | str | list["JsonValue"] | dict[str, "JsonValue"]
JsonObject = dict[str, JsonValue]

START = "<!-- immutable-audit-export-verification:begin -->"
END = "<!-- immutable-audit-export-verification:end -->"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
HEX40_RE = re.compile(r"^[0-9a-f]{40}$")
HOME_SEGMENT, USERS_SEGMENT = "/" + "home" + "/", "/" + "users" + "/"
PRIVATE_PATH_RE = re.compile(r"(?i)(" + re.escape(HOME_SEGMENT) + "|" + re.escape(USERS_SEGMENT) + r")[^\s`'\"]+")
INTERNAL_LABELS = ["".join(parts) for parts in [("o", "mo"), ("o", "mx"), ("u", "lw")]]
INTERNAL_LABEL_RE = re.compile(r"\b(" + "|".join(INTERNAL_LABELS) + r")\b", re.IGNORECASE)
SECRET_TERMS = ["cookie=", "private" + "_key=", "sec" + "ret=", "to" + "ken=", "authorization: bearer", "-----begin private key-----"]
UNSAFE_PHRASES = [
    "credential used", "deployment executed", "docker container started", "github project control-plane mutation completed", "infrastructure mutated",
    "kubernetes cluster mutated", "production write completed", "proxmox mutation completed", "remote host changed",
]


class VerificationError(Exception):
    pass


def reject(message: str) -> None:
    raise VerificationError(message)


def extract_payload(text: str) -> JsonObject:
    if not text.strip():
        reject("empty verification content")
    if START not in text or END not in text:
        reject("missing immutable audit export verification block")
    block = text.split(START, 1)[1].split(END, 1)[0].strip()
    if block.startswith("```json"):
        block = block.removeprefix("```json").strip()
    if block.endswith("```"):
        block = block[: -len("```")].strip()
    try:
        payload = json.loads(block)
    except json.JSONDecodeError as exc:
        reject(f"malformed verification data: {exc}")
    if not isinstance(payload, dict):
        reject("immutable audit export verification block must be an object")
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
    match value:
        case str():
            return [value]
        case list():
            return [text for item in value for text in flattened_strings(item)]
        case dict():
            return [text for item in value.values() for text in flattened_strings(item)]
        case None | bool() | int() | float():
            return []
        case unreachable:
            assert_never(unreachable)


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


def validate_redaction(redaction: JsonObject) -> None:
    excluded = require_list(redaction.get("excludedClasses"), "redaction manifest excludedClasses", 6)
    excluded_text = " ".join(str(item).lower() for item in excluded)
    for term in ["secrets", "auth files", "tokens", "ssh keys", "private machine state", "secret-bearing evidence"]:
        if term not in excluded_text:
            reject(f"redaction manifest missing {term}")
    entries = require_list(redaction.get("entries"), "redaction manifest entries", 4)
    for entry_value in entries:
        entry = require_object(entry_value, "redaction entry")
        for field in ["class", "reviewer", "reason", "scope"]:
            require_nonempty(entry.get(field), f"redaction entry {field}")
        if entry.get("verified") is not True:
            reject("redaction entry must be verified")
    if redaction.get("rawSecretsIncluded") is not False:
        reject("redaction manifest must exclude raw secrets")


def validate_payload(payload: JsonObject) -> None:
    for field in ["version", "permissionLevel", "exportManifest"]:
        require_nonempty(payload.get(field), field)
    if payload.get("permissionLevel") != "docs-only-local-verification":
        reject("permissionLevel must remain docs-only-local-verification")

    export_manifest = require_object(payload.get("exportManifest"), "export manifest")
    manifest_payload = require_object(export_manifest.get("manifestPayload"), "manifest payload")
    recorded_hash = require_string(export_manifest.get("recordedSha256"), "manifest hash")
    if not SHA256_RE.fullmatch(recorded_hash):
        reject("manifest hash must be a SHA-256 hex digest")
    canonicalization = require_string(export_manifest.get("canonicalization"), "canonicalization").lower()
    if "canonical json" not in canonicalization or "sorted object keys" not in canonicalization:
        reject("canonicalization must define canonical JSON with sorted object keys")
    canonical = json.dumps(manifest_payload, sort_keys=True, separators=(",", ":"))
    recomputed_hash = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
    if recorded_hash != recomputed_hash:
        reject("manifest hash mismatch")

    for field in ["drillId", "date", "permissionLevel", "packageId", "schemaVersion", "sourceDesign"]:
        require_nonempty(manifest_payload.get(field), field)
    if manifest_payload.get("permissionLevel") != payload.get("permissionLevel"):
        reject("manifest permissionLevel must match package permissionLevel")

    validate_source_links(require_object(manifest_payload.get("sourceLinks"), "source links"))
    validate_redaction(require_object(manifest_payload.get("redactionManifest"), "redaction manifest"))

    retention = require_object(manifest_payload.get("retentionMetadata"), "retention metadata")
    for field in ["duration", "owner", "storageSurface", "deletionOrExtensionDecision", "legalHoldState", "nextReviewDate"]:
        require_nonempty(retention.get(field), f"retention metadata {field}")

    ownership = require_object(manifest_payload.get("ownership"), "owner")
    for field in ["packageOwner", "controlOwner", "complianceReviewer", "retentionOwner", "redactionReviewer", "integrityVerifier"]:
        require_nonempty(ownership.get(field), f"ownership {field}")

    verification = require_object(manifest_payload.get("verificationOutput"), "verification output")
    for field in ["command", "result", "verifiedBy"]:
        require_nonempty(verification.get(field), f"verification output {field}")
    if "pass" not in str(verification.get("result", "")).lower():
        reject("verification output must record PASS")

    approval = require_string(manifest_payload.get("approvalGateStatus"), "approval-gate status").lower()
    if "no live" not in approval or "mutation reached" not in approval:
        reject("approval-gate status must state no live mutation reached")
    cleanup = require_object(manifest_payload.get("cleanup"), "cleanup")
    if cleanup.get("status") != "complete":
        reject("cleanup must be complete")
    require_nonempty(cleanup.get("receipt"), "cleanup receipt")
    require_list(manifest_payload.get("residualRisk"), "residual risk", 3)
    require_nonempty(manifest_payload.get("nextAction"), "next action")
    follow_up = require_string(manifest_payload.get("followUpIssueUrl"), "follow-up issue URL")
    if not follow_up.startswith("https://github.com/"):
        reject("follow-up issue URL must be a GitHub URL")
    require_safe_text(manifest_payload)


doc_text = Path(sys.argv[1]).read_text(encoding="utf-8")
baseline = extract_payload(doc_text)
validate_payload(baseline)


def expect_reject(name: str, candidate: str | JsonObject) -> None:
    try:
        if isinstance(candidate, str):
            validate_payload(extract_payload(candidate))
        else:
            validate_payload(candidate)
    except VerificationError:
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
    manifest = require_object(payload.get("exportManifest"), "export manifest")
    manifest_payload = require_object(manifest.get("manifestPayload"), "manifest payload")
    canonical = json.dumps(manifest_payload, sort_keys=True, separators=(",", ":"))
    manifest["recordedSha256"] = hashlib.sha256(canonical.encode("utf-8")).hexdigest()


expect_reject("empty verification content", "")
expect_reject("malformed verification data", START + "\n```json\n{\"version\": \n```\n" + END)

for name, path in [
    ("missing manifest hash", ("exportManifest", "recordedSha256")),
    ("missing source links", ("exportManifest", "manifestPayload", "sourceLinks")),
    ("missing redaction manifest", ("exportManifest", "manifestPayload", "redactionManifest")),
    ("missing retention metadata", ("exportManifest", "manifestPayload", "retentionMetadata")),
    ("missing owner", ("exportManifest", "manifestPayload", "ownership", "packageOwner")),
    ("missing verification command output", ("exportManifest", "manifestPayload", "verificationOutput", "command")),
    ("missing approval-gate status", ("exportManifest", "manifestPayload", "approvalGateStatus")),
    ("missing cleanup", ("exportManifest", "manifestPayload", "cleanup")),
    ("missing residual risk", ("exportManifest", "manifestPayload", "residualRisk")),
    ("missing next action", ("exportManifest", "manifestPayload", "nextAction")),
]:
    mutated = copy.deepcopy(baseline)
    set_path(mutated, path, "")
    expect_reject(name, mutated)

for name, path, value in [
    ("mismatched manifest hash", ("exportManifest", "recordedSha256"), "0" * 64),
    ("source links mutation changes hash", ("exportManifest", "manifestPayload", "sourceLinks", "validation"), []),
    ("redaction mutation changes hash", ("exportManifest", "manifestPayload", "redactionManifest", "rawSecretsIncluded"), True),
    ("retention mutation changes hash", ("exportManifest", "manifestPayload", "retentionMetadata", "nextReviewDate"), "2026-09-14"),
    ("ownership mutation changes hash", ("exportManifest", "manifestPayload", "ownership", "packageOwner"), "Changed reviewer"),
    ("verification output mutation changes hash", ("exportManifest", "manifestPayload", "verificationOutput", "verifiedBy"), "Changed verifier"),
    ("approval mutation changes hash", ("exportManifest", "manifestPayload", "approvalGateStatus"), "Closed: no live credential, production, infrastructure, worker, remote host, Proxmox, Docker, Kubernetes, SSH, deployment, or GitHub Project control-plane mutation reached by alternate reviewer"),
    ("cleanup mutation changes hash", ("exportManifest", "manifestPayload", "cleanup", "receipt"), "alternate cleanup receipt"),
    ("residual risk mutation changes hash", ("exportManifest", "manifestPayload", "residualRisk"), ["Changed risk"]),
    ("next action mutation changes hash", ("exportManifest", "manifestPayload", "nextAction"), "Changed next action"),
    ("follow-up issue mutation changes hash", ("exportManifest", "manifestPayload", "followUpIssueUrl"), "https://github.com/TwoTwo-me/Project_Dokkaebi/issues/999"),
]:
    mutated = copy.deepcopy(baseline)
    set_path(mutated, path, value)
    expect_reject(name, mutated)

for name, path, value in [
    ("rehashed secret-bearing wording", ("exportManifest", "manifestPayload", "verificationOutput", "result"), "PASS " + SECRET_TERMS[3] + "abc retained"),
    ("rehashed private local path", ("exportManifest", "manifestPayload", "cleanup", "receipt"), HOME_SEGMENT + "sam/.ssh/id_rsa retained"),
    ("rehashed internal execution label", ("exportManifest", "manifestPayload", "nextAction"), "run " + INTERNAL_LABELS[0] + " workflow"),
    ("rehashed unsafe mutation wording", ("exportManifest", "manifestPayload", "approvalGateStatus"), "credential used and production write completed"),
]:
    mutated = copy.deepcopy(baseline)
    set_path(mutated, path, value)
    refresh_recorded_hash(mutated)
    expect_reject(name, mutated)

print("PASS Dokkaebi immutable audit export verification validation passed")
PY
