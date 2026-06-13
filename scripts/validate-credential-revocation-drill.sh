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

DOC_PATH="${CREDENTIAL_REVOCATION_DRILL_PATH:-docs/policies/credential-revocation-access-review-drill-2026-06-13.md}"

for term in \
  "owner approval" "grant scope" "expiration" "revocation trigger" \
  "denial output" "sandbox revocation output" "access-review output" \
  "audit evidence" "approval-gate status" "cleanup receipt" \
  "residual risk" "next action" "does not authorize"; do
  require_text "$DOC_PATH" "$term"
done

command -v python3 >/dev/null || fail "missing command: python3"

python3 - "$DOC_PATH" <<'PY'
import copy
import json
import re
import sys
from pathlib import Path

START = "<!-- credential-revocation-drill:begin -->"
END = "<!-- credential-revocation-drill:end -->"
REQUIRED_DENIALS = {
    "missing_owner",
    "missing_scope",
    "missing_expiration",
    "missing_revocation_trigger",
    "missing_audit_evidence",
    "missing_cleanup",
    "missing_approval_gate_status",
}
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
    "live credential revoked",
    "credential copied",
    "broker mutation completed",
    "deployment executed",
    "github project control-plane mutation completed",
    "infrastructure mutated",
    "production write completed",
    "worker scaled",
]


class DrillError(Exception):
    pass


def reject(message):
    raise DrillError(message)


def extract_payload(text):
    if not text.strip():
        reject("empty credential revocation drill content")
    if START not in text or END not in text:
        reject("missing credential revocation drill block")
    block = text.split(START, 1)[1].split(END, 1)[0].strip()
    if block.startswith("```json"):
        block = block.removeprefix("```json").strip()
    if block.endswith("```"):
        block = block[: -len("```")].strip()
    try:
        payload = json.loads(block)
    except json.JSONDecodeError as exc:
        reject(f"malformed credential revocation drill data: {exc}")
    if not isinstance(payload, dict):
        reject("credential revocation drill block must be an object")
    return payload


def require_nonempty(value, label):
    if value in (None, "", [], {}):
        reject(f"missing {label}")
    return value


def require_object(value, label):
    if not isinstance(value, dict):
        reject(f"missing {label}")
    return value


def require_list(value, label, minimum=1):
    if not isinstance(value, list) or len(value) < minimum:
        reject(f"missing {label}")
    return value


def flattened_strings(value):
    if isinstance(value, str):
        return [value]
    if isinstance(value, list):
        return [text for item in value for text in flattened_strings(item)]
    if isinstance(value, dict):
        return [text for item in value.values() for text in flattened_strings(item)]
    return []


def require_safe_text(payload):
    lowered = "\n".join(flattened_strings(payload)).lower()
    for term in SECRET_TERMS:
        if term in lowered:
            reject(f"secret-bearing evidence wording: {term}")
    for phrase in UNSAFE_PHRASES:
        if phrase in lowered:
            reject(f"unsafe credential authority wording: {phrase}")
    if PRIVATE_PATH_RE.search(lowered):
        reject("private local path retained")
    if INTERNAL_LABEL_RE.search(lowered):
        reject("internal execution label retained")


def validate_payload(payload):
    required_fields = [
        "version",
        "permissionLevel",
        "approvalBoundary",
        "sandboxTarget",
        "ownerApproval",
        "grant",
        "revocationTrigger",
        "denialOutput",
        "revocationOutput",
        "accessReviewOutput",
        "auditEvidence",
        "failClosedCases",
        "validationOutput",
        "cleanup",
        "residualRisk",
        "nextAction",
        "followUpIssueUrl",
    ]
    for field in required_fields:
        require_nonempty(payload.get(field), field)
    if payload.get("permissionLevel") != "approved local sandbox credential revocation and access-review drill":
        reject("permissionLevel must remain approved local sandbox credential revocation and access-review drill")
    boundary = str(payload["approvalBoundary"]).lower()
    for term in ["does not authorize", "credential use", "broker mutation", "production", "explicit human approval"]:
        if term not in boundary:
            reject(f"approval boundary missing {term}")
    sandbox = require_object(payload["sandboxTarget"], "sandbox target")
    if sandbox.get("type") != "approved local sandbox" or sandbox.get("liveSystemsTouched") is not False:
        reject("sandbox target must be approved local sandbox and touch no live systems")
    approval = require_object(payload["ownerApproval"], "owner approval")
    for field in ["owner", "approvalSource", "scope", "expiration", "revocationTrigger", "approvalGateStatus"]:
        require_nonempty(approval.get(field), f"owner approval {field}")
    grant = require_object(payload["grant"], "grant")
    for field in ["safeGrantId", "credentialClass", "scope", "expiration", "storage"]:
        require_nonempty(grant.get(field), f"grant {field}")
    if grant.get("rawSecretRetained") is not False:
        reject("grant must not retain raw secrets")
    revocation = require_object(payload["revocationOutput"], "revocation output")
    for field in ["brokerResponse", "decision", "evidenceId"]:
        require_nonempty(revocation.get(field), f"revocation output {field}")
    if revocation.get("activeAfterRevocation") is not False:
        reject("sandbox grant must be inactive after revocation")
    access_review = require_object(payload["accessReviewOutput"], "access-review output")
    if access_review.get("activeGrantCount") != 0:
        reject("access-review output must show zero active grants")
    for field in ["reviewedActors", "deniedActor", "deniedReason", "evidence"]:
        require_nonempty(access_review.get(field), f"access-review output {field}")
    denial_cases = {require_object(item, "denial output").get("case") for item in require_list(payload["denialOutput"], "denial output", len(REQUIRED_DENIALS))}
    if denial_cases != REQUIRED_DENIALS:
        reject("denial output cases mismatch: " + ", ".join(sorted(REQUIRED_DENIALS - denial_cases)))
    for item in payload["denialOutput"]:
        item_obj = require_object(item, "denial output")
        if item_obj.get("outcome") != "denied" or not item_obj.get("reason"):
            reject("each denial output must fail closed with a reason")
    fail_closed = set(require_list(payload["failClosedCases"], "fail-closed cases", len(REQUIRED_DENIALS)))
    if fail_closed != REQUIRED_DENIALS:
        reject("fail-closed cases mismatch")
    audit_text = " ".join(str(item).lower() for item in require_list(payload["auditEvidence"], "audit evidence", 10))
    for term in ["owner approval", "grant scope", "expiration", "revocation trigger", "denial output", "access-review output", "approval-gate status", "cleanup receipt", "next action"]:
        if term not in audit_text:
            reject(f"audit evidence missing {term}")
    validation_text = "\n".join(str(item) for item in require_list(payload["validationOutput"], "validation output", 5))
    for command in ["credential revocation drill", "credential lifecycle", "multi-tenant RBAC", "enterprise readiness", "contract docs"]:
        if command not in validation_text:
            reject(f"validation output missing {command}")
    cleanup = require_object(payload["cleanup"], "cleanup")
    if cleanup.get("credentialMaterialRetained") is not False or not cleanup.get("receipt"):
        reject("cleanup must prove no credential material retained")
    require_list(payload["residualRisk"], "residual risk", 2)
    if not str(payload["followUpIssueUrl"]).startswith("https://github.com/"):
        reject("follow-up issue URL must be a GitHub URL")
    require_safe_text(payload)


doc_text = Path(sys.argv[1]).read_text(encoding="utf-8")
baseline = extract_payload(doc_text)
validate_payload(baseline)


def expect_reject(name, candidate):
    try:
        validate_payload(extract_payload(candidate) if isinstance(candidate, str) else candidate)
    except DrillError:
        return
    reject(f"negative fixture unexpectedly passed: {name}")


expect_reject("empty content", "")
expect_reject("malformed data", START + "\n```json\n{\"version\": \n```\n" + END)
for field in ["ownerApproval", "grant", "denialOutput", "revocationOutput", "accessReviewOutput", "cleanup"]:
    mutated = copy.deepcopy(baseline)
    mutated[field] = ""
    expect_reject(f"missing {field}", mutated)
for name, mutate in [
    ("raw secret retained", lambda item: item["grant"].update({"rawSecretRetained": True})),
    ("active grant remains", lambda item: item["accessReviewOutput"].update({"activeGrantCount": 1})),
    ("missing denial case", lambda item: item.update({"denialOutput": item["denialOutput"][1:]})),
    ("unsafe authority wording", lambda item: item.update({"revocationOutput": {"brokerResponse": "live credential revoked", "decision": "broker mutation completed", "activeAfterRevocation": False, "evidenceId": "bad"}})),
    ("private local path", lambda item: item.update({"nextAction": HOME_SEGMENT + "sam/.ssh/id_rsa retained"})),
    ("internal execution label", lambda item: item.update({"auditEvidence": ["run " + INTERNAL_LABELS[0] + " workflow"]})),
]:
    mutated = copy.deepcopy(baseline)
    mutate(mutated)
    expect_reject(name, mutated)

print("PASS Dokkaebi credential revocation drill validation passed")
PY
