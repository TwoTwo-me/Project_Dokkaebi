#!/usr/bin/env python3
"""Validate Dokkaebi Human Review terminal approval transitions.

This is a local, fail-closed contract gate. It validates a proposed status
transition record against `dokkaebi/policies/project-dokkaebi.yml` without
calling GitHub. Runtime integrations should feed it actor/provenance data from
GitHub Project status history, durable approval records, or a future approved
approval broker.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
from typing import Any

try:
    import yaml  # type: ignore
except Exception as exc:  # pragma: no cover - environment preflight catches this
    print(f"BLOCKED missing PyYAML dependency: {exc}", file=sys.stderr)
    sys.exit(2)

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_POLICY = ROOT / "dokkaebi" / "policies" / "project-dokkaebi.yml"
REQUIRED_EVIDENCE_FIELDS = [
    "actor",
    "actor_origin",
    "provenance_source",
    "approved_action",
    "linked_ticket_or_item",
    "linked_result_packet_or_review",
    "provenance_record_id",
    "provenance_checked_by",
    "provenance_verification_method",
    "provenance_evidence_file",
    "provenance_evidence_sha256",
]
DEFAULT_TRUSTED_VERIFIERS = {
    "dokkaebi-github-project-status-adapter",
    "dokkaebi-human-approval-record-adapter",
    "dokkaebi-approval-broker",
}


def _load_record(args: argparse.Namespace) -> dict[str, Any]:
    if args.record_json:
        raw = args.record_json
    elif args.record:
        raw = Path(args.record).read_text(encoding="utf-8")
    else:
        raw = sys.stdin.read()
    try:
        record = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ValueError(f"transition record is not valid JSON: {exc}") from exc
    if not isinstance(record, dict):
        raise ValueError("transition record must be a JSON object")
    return record


def _load_policy(path: Path) -> dict[str, Any]:
    try:
        policy = yaml.safe_load(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise ValueError(f"policy file missing: {path}") from exc
    if not isinstance(policy, dict):
        raise ValueError(f"policy file must parse to a mapping: {path}")
    transition_policy = policy.get("human_review_transition_policy")
    if not isinstance(transition_policy, dict):
        raise ValueError("policy missing human_review_transition_policy")
    return transition_policy


def _terminal_transitions(policy: dict[str, Any]) -> set[tuple[str, str]]:
    transitions = policy.get("terminal_approval_transitions") or []
    result: set[tuple[str, str]] = set()
    for item in transitions:
        if not isinstance(item, dict):
            continue
        source = str(item.get("from") or "").strip()
        target = str(item.get("to") or "").strip()
        if source and target:
            result.add((source, target))
    if not result:
        raise ValueError("policy has no terminal_approval_transitions")
    return result


def _safe_evidence_path(value: str) -> Path:
    path = Path(value)
    if path.is_absolute() or ".." in path.parts:
        raise ValueError("provenance_evidence_file must be a repository-relative path")
    resolved = (ROOT / path).resolve()
    if not resolved.is_relative_to(ROOT):
        raise ValueError("provenance_evidence_file must stay inside the repository")
    if not resolved.is_file():
        raise ValueError(f"provenance_evidence_file is missing: {value}")
    return resolved


def _verify_source_specific_evidence(record: dict[str, Any], details: dict[str, Any]) -> tuple[bool, str]:
    evidence_file = str(record.get("provenance_evidence_file") or "").strip()
    expected_sha = str(record.get("provenance_evidence_sha256") or "").strip().lower()
    path = _safe_evidence_path(evidence_file)
    raw = path.read_bytes()
    actual_sha = hashlib.sha256(raw).hexdigest()
    details["provenance_evidence_sha256_actual"] = actual_sha
    if actual_sha != expected_sha:
        return False, "provenance_evidence_sha256 does not match the evidence file"

    text = raw.decode("utf-8")
    evidence: dict[str, Any] = {}
    if path.suffix == ".json":
        loaded = json.loads(text)
        if not isinstance(loaded, dict):
            return False, "provenance evidence JSON must be an object"
        evidence = loaded
    else:
        # Markdown approval records are allowed only when they visibly bind the
        # action, actor, and record id. This keeps bootstrap records checkable
        # without making free-form prose the preferred adapter output.
        for needle in [
            str(record.get("provenance_record_id") or ""),
            str(record.get("actor") or ""),
            str(record.get("approved_action") or ""),
        ]:
            if needle and needle not in text:
                return False, f"provenance markdown evidence missing {needle!r}"
        return True, "source-specific markdown provenance verified"

    expected_pairs = {
        "record_id": record.get("provenance_record_id"),
        "provenance_source": record.get("provenance_source"),
        "verified_by": record.get("provenance_checked_by"),
        "verification_method": record.get("provenance_verification_method"),
        "actor": record.get("actor"),
        "actor_origin": record.get("actor_origin"),
        "approved_action": record.get("approved_action"),
    }
    for key, expected in expected_pairs.items():
        actual = evidence.get(key)
        if str(actual or "").strip() != str(expected or "").strip():
            return False, f"provenance evidence {key} mismatch"

    for key in ["source_status", "target_status"]:
        if key in evidence and str(evidence.get(key) or "").strip() != str(record.get(key) or "").strip():
            return False, f"provenance evidence {key} mismatch"

    return True, "source-specific JSON provenance verified"


def validate(record: dict[str, Any], policy: dict[str, Any]) -> tuple[bool, str, dict[str, Any]]:
    source = str(record.get("source_status") or record.get("from") or "").strip()
    target = str(record.get("target_status") or record.get("to") or "").strip()
    actor = str(record.get("actor") or "").strip()
    actor_origin = str(record.get("actor_origin") or "").strip().lower()
    provenance_source = str(record.get("provenance_source") or "").strip()

    transitions = _terminal_transitions(policy)
    review_state = str(policy.get("review_state") or "Human Review").strip()
    terminal_targets = {target for _, target in transitions}
    accepted_sources = set(policy.get("accepted_provenance_sources") or [])
    accepted_sources.update(policy.get("provenance_sources") or [])
    trusted_verifiers = set(policy.get("trusted_provenance_verifiers") or [])
    if not trusted_verifiers:
        trusted_verifiers = DEFAULT_TRUSTED_VERIFIERS
    source_verification = policy.get("source_verification") or {}
    allowed_actions = set(policy.get("approval_required_actions") or [])
    approved_action = str(record.get("approved_action") or "").strip()
    provenance_record_id = str(record.get("provenance_record_id") or "").strip()
    provenance_checked_by = str(record.get("provenance_checked_by") or "").strip()
    verification_method = str(record.get("provenance_verification_method") or "").strip()
    evidence_file = str(record.get("provenance_evidence_file") or "").strip()
    evidence_sha = str(record.get("provenance_evidence_sha256") or "").strip()
    is_terminal_target = target in terminal_targets
    is_gated_action = bool(approved_action and approved_action in allowed_actions)

    details = {
        "source_status": source,
        "target_status": target,
        "actor": actor,
        "actor_origin": actor_origin,
        "provenance_source": provenance_source,
        "approved_action": approved_action,
        "provenance_record_id": provenance_record_id,
        "provenance_checked_by": provenance_checked_by,
        "provenance_verification_method": verification_method,
        "provenance_evidence_file": evidence_file,
        "provenance_evidence_sha256": evidence_sha,
        "is_gated_action": is_gated_action,
        "review_state": review_state,
        "terminal_approval_transitions": sorted([{"from": a, "to": b} for a, b in transitions], key=lambda x: (x["from"], x["to"])),
    }

    if not source or not target:
        return False, "missing source_status or target_status", details

    # Non-terminal review/fix transitions are outside this gate only when they do
    # not carry an approval-required action such as github_issue_close.
    if not is_terminal_target and not is_gated_action:
        return True, "non-terminal transition does not require terminal approval provenance", details

    if is_terminal_target and (source, target) not in transitions:
        return False, f"invalid terminal transition {source!r} -> {target!r}; expected one of {sorted(transitions)!r}", details

    missing = [field for field in REQUIRED_EVIDENCE_FIELDS if not str(record.get(field) or "").strip()]
    if missing:
        details["missing_fields"] = missing
        return False, "missing gated approval evidence: " + ", ".join(missing), details

    if not actor:
        return False, "terminal approval actor identity is missing", details

    if actor_origin in {"manager", "worker", "symphony", "automation"}:
        return False, "manager/automation self-approval is forbidden", details

    if actor_origin in {"unknown", ""}:
        return False, "terminal approval provenance is ambiguous", details

    if actor_origin != "human":
        return False, f"terminal approval actor_origin must be human, got {actor_origin!r}", details

    if accepted_sources and provenance_source not in accepted_sources:
        return False, f"unaccepted provenance_source {provenance_source!r}; expected one of {sorted(accepted_sources)!r}", details

    if allowed_actions and approved_action not in allowed_actions:
        return False, f"unaccepted approved_action {approved_action!r}; expected one of {sorted(allowed_actions)!r}", details

    if provenance_checked_by not in trusted_verifiers:
        return False, f"untrusted provenance_checked_by {provenance_checked_by!r}; expected one of {sorted(trusted_verifiers)!r}", details

    expected_method = ""
    if isinstance(source_verification, dict):
        expected_method = str(source_verification.get(provenance_source) or "").strip()
    if expected_method and verification_method != expected_method:
        return False, f"provenance_verification_method for {provenance_source!r} must be {expected_method!r}", details

    if provenance_record_id.lower() in {"n/a", "none", "null", "unknown"}:
        return False, "provenance_record_id must identify source-specific durable evidence", details

    verified, evidence_reason = _verify_source_specific_evidence(record, details)
    if not verified:
        return False, evidence_reason, details
    details["provenance_evidence_verification"] = evidence_reason

    linked_result = str(record.get("linked_result_packet_or_review") or "").strip()
    if linked_result.lower() in {"n/a", "none", "null", "unknown"}:
        return False, "linked_result_packet_or_review must identify durable evidence", details

    return True, "human-origin gated approval accepted", details


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate Dokkaebi terminal approval transition records")
    parser.add_argument("--policy", default=str(DEFAULT_POLICY), help="Project policy YAML path")
    parser.add_argument("--record", help="JSON transition record path; defaults to stdin")
    parser.add_argument("--record-json", help="JSON transition record string")
    parser.add_argument("--json", action="store_true", help="Emit machine-readable JSON")
    args = parser.parse_args()

    try:
        record = _load_record(args)
        policy = _load_policy(Path(args.policy))
        ok, reason, details = validate(record, policy)
    except ValueError as exc:
        ok, reason, details = False, str(exc), {}

    payload = {
        "ok": ok,
        "status": "OK" if ok else "BLOCKED",
        "reason": reason,
        "details": details,
    }
    if args.json:
        print(json.dumps(payload, indent=2, ensure_ascii=False))
    else:
        print(f"[{payload['status']}] {reason}")
    return 0 if ok else 2


if __name__ == "__main__":
    raise SystemExit(main())
