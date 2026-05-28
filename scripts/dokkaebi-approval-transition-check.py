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
        "review_state": review_state,
        "terminal_approval_transitions": sorted([{"from": a, "to": b} for a, b in transitions], key=lambda x: (x["from"], x["to"])),
    }

    if not source or not target:
        return False, "missing source_status or target_status", details

    # Non-terminal review/fix transitions are outside this terminal approval gate.
    if target not in terminal_targets:
        return True, "non-terminal transition does not require terminal approval provenance", details

    if (source, target) not in transitions:
        return False, f"invalid terminal transition {source!r} -> {target!r}; expected one of {sorted(transitions)!r}", details

    missing = [field for field in REQUIRED_EVIDENCE_FIELDS if not str(record.get(field) or "").strip()]
    if missing:
        details["missing_fields"] = missing
        return False, "missing terminal approval evidence: " + ", ".join(missing), details

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

    linked_result = str(record.get("linked_result_packet_or_review") or "").strip()
    if linked_result.lower() in {"n/a", "none", "null", "unknown"}:
        return False, "linked_result_packet_or_review must identify durable evidence", details

    return True, "human-origin terminal approval transition accepted", details


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
