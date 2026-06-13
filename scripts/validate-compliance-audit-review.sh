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

DOC_PATH="${COMPLIANCE_AUDIT_REVIEW_PATH:-docs/compliance/audit-review-2026-06-13.md}"

for term in \
  "completed change" \
  "reviewer" \
  "control coverage" \
  "evidence links" \
  "exceptions" \
  "retention decision" \
  "redaction decision" \
  "integrity check" \
  "approval-gate status" \
  "residual risk" \
  "next action" \
  "docs-only" \
  "no credential" \
  "no production"; do
  require_text "$DOC_PATH" "$term"
done

command -v python3 >/dev/null || fail "missing command: python3"

python3 - "$DOC_PATH" <<'PY'
from __future__ import annotations

import copy
import json
import re
import sys
from pathlib import Path
from typing import Any

START = "<!-- compliance-audit-review:begin -->"
END = "<!-- compliance-audit-review:end -->"
HEX40 = re.compile(r"^[0-9a-f]{40}$")


class AuditReviewError(Exception):
    pass


def reject(message: str) -> None:
    raise AuditReviewError(message)


def extract_payload(text: str) -> dict[str, Any]:
    if not text.strip():
        reject("empty review content")
    if START not in text or END not in text:
        reject("missing compliance audit review block")
    block = text.split(START, 1)[1].split(END, 1)[0].strip()
    if block.startswith("```json"):
        block = block.removeprefix("```json").strip()
    if block.endswith("```"):
        block = block[: -len("```")].strip()
    try:
        payload = json.loads(block)
    except json.JSONDecodeError as exc:
        reject(f"malformed review data: {exc}")
    if not isinstance(payload, dict):
        reject("compliance audit review block must be an object")
    return payload


def require_nonempty(value: Any, label: str) -> None:
    if value in (None, "", [], {}):
        reject(f"missing {label}")


def require_url(value: Any, label: str) -> None:
    require_nonempty(value, label)
    if not isinstance(value, str) or not value.startswith("https://github.com/"):
        reject(f"{label} must be a GitHub URL")


def validate_payload(payload: dict[str, Any]) -> None:
    require_nonempty(payload.get("packageId"), "package ID")
    require_nonempty(payload.get("reviewDate"), "review date")
    require_nonempty(payload.get("reviewer"), "reviewer")
    if "docs-only" not in str(payload.get("permissionLevel", "")).lower():
        reject("permissionLevel must remain docs-only")

    completed = payload.get("completedChange")
    if not isinstance(completed, dict):
        reject("missing completed-change reference")
    for field in ["title", "pullRequestUrl", "implementationCommit", "mergeCommit"]:
        require_nonempty(completed.get(field), f"completed change {field}")
    require_url(completed.get("pullRequestUrl"), "completed change pullRequestUrl")
    for field in ["implementationCommit", "mergeCommit"]:
        value = str(completed.get(field, ""))
        if not HEX40.match(value):
            reject(f"completed change {field} must be a 40-character commit SHA")
    issue_urls = completed.get("closedIssueUrls")
    if not isinstance(issue_urls, list) or len(issue_urls) < 2:
        reject("completed change closedIssueUrls must list closed issues")
    for index, url in enumerate(issue_urls, start=1):
        require_url(url, f"closed issue URL {index}")

    approval = str(payload.get("approvalGateStatus", "")).lower()
    require_nonempty(approval, "approval-gate status")
    for term in ["no credential", "worker", "infrastructure", "production", "control-plane"]:
        if term not in approval:
            reject(f"approval-gate status missing {term}")
    if "credential mutation authorized" in approval or "production write authorized" in approval:
        reject("unauthorized credential or production mutation wording")

    coverage = payload.get("controlCoverage")
    if not isinstance(coverage, dict):
        reject("missing control coverage")
    required_controls = {
        "approval",
        "access",
        "changeManagement",
        "logging",
        "incident",
        "credential",
    }
    missing_controls = required_controls - coverage.keys()
    if missing_controls:
        reject("missing control coverage: " + ", ".join(sorted(missing_controls)))
    for control_id in required_controls:
        control = coverage.get(control_id)
        if not isinstance(control, dict):
            reject(f"{control_id} coverage must be an object")
        for field in ["status", "evidence", "exception"]:
            require_nonempty(control.get(field), f"{control_id} coverage {field}")

    links = payload.get("evidenceLinks")
    if not isinstance(links, list) or len(links) < 4:
        reject("missing evidence links")
    for index, url in enumerate(links, start=1):
        require_url(url, f"evidence link {index}")

    exceptions = payload.get("exceptions")
    if not isinstance(exceptions, list) or not exceptions:
        reject("missing exceptions")

    for field in [
        "retentionDecision",
        "redactionDecision",
        "integrityCheck",
        "residualRisk",
        "nextAction",
    ]:
        require_nonempty(payload.get(field), field)

    redaction = str(payload.get("redactionDecision", "")).lower()
    if "raw secret included" in redaction or "secret-bearing evidence allowed" in redaction:
        reject("unauthorized secret-bearing evidence wording")

    chain = payload.get("reviewChain")
    if not isinstance(chain, list) or len(chain) < 7:
        reject("reviewChain must include request, approval, change, validation, review, merge, and closeout")
    required_steps = ["request", "approval", "change", "validation", "review", "merge", "closeout"]
    chain_text = " ".join(str(item).lower() for item in chain)
    for step in required_steps:
        if step not in chain_text:
            reject(f"reviewChain missing {step}")


doc_text = Path(sys.argv[1]).read_text(encoding="utf-8")
baseline = extract_payload(doc_text)
validate_payload(baseline)


def expect_reject(name: str, candidate: str | dict[str, Any]) -> None:
    try:
        if isinstance(candidate, str):
            validate_payload(extract_payload(candidate))
        else:
            validate_payload(candidate)
    except AuditReviewError:
        return
    reject(f"negative fixture unexpectedly passed: {name}")


expect_reject("empty review content", "")
expect_reject(
    "malformed review data",
    START + "\n```json\n{\"version\": \n```\n" + END,
)

for field in [
    "reviewer",
    "controlCoverage",
    "evidenceLinks",
    "exceptions",
    "retentionDecision",
    "redactionDecision",
    "integrityCheck",
    "approvalGateStatus",
    "residualRisk",
    "nextAction",
]:
    mutated = copy.deepcopy(baseline)
    if field == "controlCoverage":
        mutated[field] = {}
    elif field in {"evidenceLinks", "exceptions"}:
        mutated[field] = []
    else:
        mutated[field] = ""
    expect_reject(f"missing {field}", mutated)

mutated = copy.deepcopy(baseline)
mutated["completedChange"] = {}
expect_reject("missing completed-change reference", mutated)

mutated = copy.deepcopy(baseline)
mutated["approvalGateStatus"] = "credential mutation authorized and production write authorized"
expect_reject("unauthorized credential or production mutation wording", mutated)

mutated = copy.deepcopy(baseline)
mutated["redactionDecision"] = "secret-bearing evidence allowed"
expect_reject("unauthorized secret-bearing evidence wording", mutated)

print("PASS Dokkaebi compliance audit review validation passed")
PY
