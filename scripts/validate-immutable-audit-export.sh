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

DOC_PATH="${IMMUTABLE_AUDIT_EXPORT_PATH:-docs/compliance/immutable-audit-export.md}"

for term in \
  "manifest hash" \
  "source links" \
  "redaction manifest" \
  "retention metadata" \
  "ownership" \
  "verification steps" \
  "failure handling" \
  "approval boundary" \
  "remaining operational gaps" \
  "permission level" \
  "docs-only" \
  "no production" \
  "control-plane"; do
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

START = "<!-- immutable-audit-export:begin -->"
END = "<!-- immutable-audit-export:end -->"


class ImmutableExportError(Exception):
    pass


def reject(message: str) -> None:
    raise ImmutableExportError(message)


def extract_payload(text: str) -> dict[str, Any]:
    if not text.strip():
        reject("empty export design")
    if START not in text or END not in text:
        reject("missing immutable audit export block")
    block = text.split(START, 1)[1].split(END, 1)[0].strip()
    if block.startswith("```json"):
        block = block.removeprefix("```json").strip()
    if block.endswith("```"):
        block = block[: -len("```")].strip()
    try:
        payload = json.loads(block)
    except json.JSONDecodeError as exc:
        reject(f"malformed export data: {exc}")
    if not isinstance(payload, dict):
        reject("immutable audit export block must be an object")
    return payload


def require_nonempty(value: Any, label: str) -> None:
    if value in (None, "", [], {}):
        reject(f"missing {label}")


def validate_payload(payload: dict[str, Any]) -> None:
    permission = str(payload.get("permissionLevel", "")).lower()
    if "docs-only" not in permission:
        reject("missing permission level")

    boundary = str(payload.get("approvalBoundary", "")).lower()
    require_nonempty(boundary, "approval boundary")
    for term in ["credential", "production", "infrastructure", "control-plane", "explicit human approval"]:
        if term not in boundary:
            reject(f"approval boundary missing {term}")
    if (
        "credential mutation authorized" in boundary
        or "production write authorized" in boundary
        or "infrastructure mutation authorized" in boundary
        or "control-plane mutation authorized" in boundary
    ):
        reject("unauthorized credential, production, infrastructure, or control-plane mutation wording")

    export_package = payload.get("exportPackage")
    if not isinstance(export_package, dict):
        reject("missing export package")
    for field in ["packageIdFormat", "schemaVersion", "generatedAt", "storageAssumptions"]:
        require_nonempty(export_package.get(field), f"export package {field}")

    manifest = payload.get("manifestHash")
    if not isinstance(manifest, dict):
        reject("missing manifest hash")
    for field in ["algorithm", "canonicalization", "requiredInputs", "verificationResult"]:
        require_nonempty(manifest.get(field), f"manifest hash {field}")
    if str(manifest.get("algorithm", "")).upper() != "SHA-256":
        reject("manifest hash algorithm must be SHA-256")
    required_inputs = manifest.get("requiredInputs")
    if not isinstance(required_inputs, list) or len(required_inputs) < 6:
        reject("manifest hash requiredInputs must list audit inputs")

    source_links = payload.get("sourceLinks")
    if not isinstance(source_links, dict):
        reject("missing source links")
    for field in ["issues", "pullRequests", "commits", "validation", "reviewPackages"]:
        require_nonempty(source_links.get(field), f"source links {field}")

    redaction = payload.get("redactionManifest")
    if not isinstance(redaction, dict):
        reject("missing redaction manifest")
    excluded = redaction.get("excludedClasses")
    if not isinstance(excluded, list) or len(excluded) < 6:
        reject("redaction manifest excludedClasses must list secret classes")
    excluded_text = " ".join(str(item).lower() for item in excluded)
    for term in ["secrets", "auth files", "tokens", "private machine state", "secret-bearing evidence"]:
        if term not in excluded_text:
            reject(f"redaction manifest missing {term}")
    require_nonempty(redaction.get("entryFields"), "redaction manifest entryFields")

    retention = payload.get("retentionMetadata")
    if not isinstance(retention, dict):
        reject("missing retention metadata")
    for field in [
        "duration",
        "owner",
        "storageSurface",
        "deletionOrExtensionDecision",
        "legalHoldState",
        "nextReviewDate",
    ]:
        require_nonempty(retention.get(field), f"retention metadata {field}")

    ownership = payload.get("ownership")
    if not isinstance(ownership, dict):
        reject("missing ownership")
    for field in [
        "packageOwner",
        "controlOwner",
        "complianceReviewer",
        "retentionOwner",
        "redactionReviewer",
        "integrityVerifier",
    ]:
        require_nonempty(ownership.get(field), f"ownership {field}")

    verification = payload.get("verificationSteps")
    if not isinstance(verification, list) or len(verification) < 8:
        reject("missing verification steps")
    verification_text = " ".join(str(item).lower() for item in verification)
    for term in ["schema", "source links", "sha-256", "redaction", "retention", "approval boundary"]:
        if term not in verification_text:
            reject(f"verification steps missing {term}")

    failure = payload.get("failureHandling")
    if not isinstance(failure, list) or len(failure) < 6:
        reject("missing failure handling")
    failure_text = " ".join(str(item).lower() for item in failure)
    for term in ["source link", "hash", "redaction", "retention", "ownership", "approval"]:
        if term not in failure_text:
            reject(f"failure handling missing {term}")

    gaps = payload.get("remainingOperationalGaps")
    if not isinstance(gaps, list) or not gaps:
        reject("missing remaining operational gaps")


doc_text = Path(sys.argv[1]).read_text(encoding="utf-8")
baseline = extract_payload(doc_text)
validate_payload(baseline)


def expect_reject(name: str, candidate: str | dict[str, Any]) -> None:
    try:
        if isinstance(candidate, str):
            validate_payload(extract_payload(candidate))
        else:
            validate_payload(candidate)
    except ImmutableExportError:
        return
    reject(f"negative fixture unexpectedly passed: {name}")


expect_reject("empty export design", "")
expect_reject(
    "malformed export data",
    START + "\n```json\n{\"version\": \n```\n" + END,
)

for field in [
    "manifestHash",
    "sourceLinks",
    "redactionManifest",
    "retentionMetadata",
    "ownership",
    "verificationSteps",
    "failureHandling",
    "approvalBoundary",
    "remainingOperationalGaps",
    "permissionLevel",
]:
    mutated = copy.deepcopy(baseline)
    if field in {"verificationSteps", "failureHandling", "remainingOperationalGaps"}:
        mutated[field] = []
    else:
        mutated[field] = ""
    expect_reject(f"missing {field}", mutated)

mutated = copy.deepcopy(baseline)
mutated["approvalBoundary"] = "credential mutation authorized and production write authorized"
expect_reject("unauthorized sensitive mutation wording", mutated)

print("PASS Dokkaebi immutable audit export validation passed")
PY
