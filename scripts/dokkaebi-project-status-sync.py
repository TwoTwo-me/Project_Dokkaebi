#!/usr/bin/env python3
"""Verify, repair, or continuously sync GitHub Project status mirrors.

Dokkaebi uses one semantic state machine. GitHub's built-in Project `Status`
field is the human-visible mirror; the configured Dokkaebi state field remains
available for Symphony/tracker integrations.

Default behavior is intentionally backward-compatible and conservative:
without --apply, this script only verifies strict equality. With --apply and no
--direction, it repairs the human-visible `Status` from `Dokkaebi Status`.

For always-on operation, use --direction bidirectional --watch --apply. The
bidirectional mode stores a local snapshot of the last synced item values. On a
later mismatch, the side that changed since the last synced snapshot becomes the
source of truth for that iteration. If both sides changed, neither side changed,
or no snapshot exists for a mismatched item, the script fails closed unless an
explicit --bootstrap-source is supplied.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
from datetime import UTC, datetime
from pathlib import Path
from typing import Any, Literal

try:
    import yaml  # type: ignore
except Exception as exc:  # pragma: no cover - preflight catches this
    print(f"BLOCKED missing PyYAML dependency: {exc}", file=sys.stderr)
    sys.exit(2)

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SCOPE = ROOT / "dokkaebi" / "project-scopes" / "project-dokkaebi.yml"
DEFAULT_STATE_DIR = ROOT / ".omx" / "state" / "project-status-sync"
DEFAULT_EVENT_LOG = DEFAULT_STATE_DIR / "events.jsonl"
KILL_SWITCH = ROOT / "dokkaebi" / "KILL_SWITCH"
Direction = Literal["verify", "dokkaebi-to-status", "status-to-dokkaebi", "bidirectional"]
BootstrapSource = Literal["block", "dokkaebi", "status"]


def _now_utc() -> str:
    return datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _run(args: list[str]) -> str:
    proc = subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or proc.stdout.strip() or f"command failed: {' '.join(args)}")
    return proc.stdout


def _load_scope(path: Path) -> tuple[dict[str, Any], dict[str, Any]]:
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"ProjectScope must parse to a mapping: {path}")
    tracker = data.get("tracker")
    if not isinstance(tracker, dict):
        raise ValueError("ProjectScope missing tracker mapping")
    return data, tracker


def _expected_states(tracker: dict[str, Any]) -> list[str]:
    mapping = tracker.get("status_mapping") or {}
    if not isinstance(mapping, dict):
        raise ValueError("tracker.status_mapping must be a mapping")
    states: list[str] = []
    for value in mapping.values():
        text = str(value or "").strip()
        if text and text not in states:
            states.append(text)
    if not states:
        raise ValueError("tracker.status_mapping does not define states")
    return states


def _json_key(field_name: str) -> str:
    return field_name[:1].lower() + field_name[1:]


def _field_by_name(fields: list[dict[str, Any]], name: str) -> dict[str, Any]:
    for field in fields:
        if field.get("name") == name:
            return field
    raise ValueError(f"Project field missing: {name}")


def _options(field: dict[str, Any]) -> list[str]:
    return [str(option.get("name") or "") for option in field.get("options") or []]


def _option_ids(field: dict[str, Any]) -> dict[str, str]:
    return {str(option.get("name") or ""): str(option.get("id") or "") for option in field.get("options") or []}


def _project_fields(owner: str, number: int) -> list[dict[str, Any]]:
    raw = _run(["gh", "project", "field-list", str(number), "--owner", owner, "--format", "json"])
    data = json.loads(raw)
    return data.get("fields") or []


def _project_items(owner: str, number: int, limit: int) -> list[dict[str, Any]]:
    raw = _run(["gh", "project", "item-list", str(number), "--owner", owner, "--format", "json", "--limit", str(limit)])
    data = json.loads(raw)
    return data.get("items") or []


def _update_item(project_id: str, item_id: str, field_id: str, option_id: str) -> None:
    _run([
        "gh", "project", "item-edit",
        "--id", item_id,
        "--project-id", project_id,
        "--field-id", field_id,
        "--single-select-option-id", option_id,
    ])


def _item_by_id(items: list[dict[str, Any]], item_id: str) -> dict[str, Any] | None:
    for item in items:
        if str(item.get("id") or "") == item_id:
            return item
    return None


def _approval_action_for_transition(target_status: str) -> str:
    normalized = target_status.strip().lower().replace(" ", "_").replace("-", "_")
    if normalized == "merging":
        return "human_review_to_merging_transition"
    if normalized == "done":
        return "human_review_to_done_transition"
    return f"status_sync_to_{normalized}"


def _terminal_transition_pairs(tracker: dict[str, Any]) -> set[tuple[str, str]]:
    policy = tracker.get("human_review_transition_policy") or {}
    pairs: set[tuple[str, str]] = set()
    transitions = policy.get("terminal_approval_transitions") if isinstance(policy, dict) else []
    for transition in transitions or []:
        if not isinstance(transition, dict):
            continue
        source = str(transition.get("from") or "").strip()
        target = str(transition.get("to") or "").strip()
        if source and target:
            pairs.add((source, target))
    return pairs


def _approval_sync_blocker(
    *,
    update: dict[str, Any],
    source_status: str,
    previous_item: dict[str, Any] | None,
    tracker: dict[str, Any],
) -> dict[str, Any] | None:
    """Block approval/terminal status sync without provenance.

    A local sync snapshot can prove which field changed; it cannot prove Human
    approval provenance. Therefore ordinary non-terminal status drift can be
    mirrored automatically, but approval-gated transitions must fail closed until
    an approval adapter supplies source-specific evidence.
    """
    target = str(update.get("targetValue") or "").strip()
    if not target:
        return None
    previous_status = source_status.strip()
    if not previous_status and previous_item:
        previous_status = str(previous_item.get("dokkaebiStatus") or previous_item.get("humanStatus") or "").strip()
    if previous_status == target:
        return None

    pairs = _terminal_transition_pairs(tracker)
    gated_targets = {to_status for _from_status, to_status in pairs}
    if (previous_status, target) not in pairs and target not in gated_targets:
        return None

    policy = tracker.get("human_review_transition_policy") or {}
    if not isinstance(policy, dict):
        policy = {}
    return {
        **update,
        "type": "approval_required_status_sync_blocked",
        "reason": "status sync would create an approval-gated transition without trusted provenance",
        "sourceStatus": previous_status,
        "targetStatus": target,
        "approvedAction": _approval_action_for_transition(target),
        "requiredOrigin": "human",
        "enabledProvenanceSources": policy.get("enabled_provenance_sources") or [],
        "trustedProvenanceVerifiers": policy.get("trusted_provenance_verifiers") or [],
        "requiredTransitionRecordFields": policy.get("required_transition_record_fields") or [],
    }


def _read_json(path: Path, default: dict[str, Any]) -> dict[str, Any]:
    if not path.is_file():
        return default
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"JSON file must contain an object: {path}")
    return data


def _write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    tmp.replace(path)


def _append_jsonl(path: Path, events: list[dict[str, Any]]) -> None:
    if not events:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        for event in events:
            handle.write(json.dumps(event, ensure_ascii=False, sort_keys=True) + "\n")


def _safe_repo_path(path_text: str, default: Path) -> Path:
    text = str(path_text or "").strip()
    if not text:
        return default
    path = Path(text).expanduser()
    if not path.is_absolute():
        path = ROOT / path
    return path.resolve()


def _default_state_file(scope_id: str) -> Path:
    safe_scope = "".join(char if char.isalnum() or char in "._-" else "-" for char in scope_id) or "project"
    return DEFAULT_STATE_DIR / f"{safe_scope}.json"


def _ensure_no_kill_switch() -> None:
    if KILL_SWITCH.exists():
        raise RuntimeError(f"kill switch present; refusing status sync mutation: {KILL_SWITCH.relative_to(ROOT)}")


def _content_summary(item: dict[str, Any]) -> dict[str, Any]:
    content = item.get("content") or {}
    if not isinstance(content, dict):
        content = {}
    return {
        "type": content.get("type"),
        "number": content.get("number"),
        "title": content.get("title"),
        "url": content.get("url"),
    }


def _snapshot_items(items: list[dict[str, Any]], state_key: str, mirror_key: str) -> dict[str, Any]:
    snapshot: dict[str, Any] = {}
    for item in items:
        item_id = str(item.get("id") or "")
        if not item_id:
            continue
        snapshot[item_id] = {
            "dokkaebiStatus": str(item.get(state_key) or "").strip(),
            "humanStatus": str(item.get(mirror_key) or "").strip(),
            "content": _content_summary(item),
            "seenAt": _now_utc(),
        }
    return snapshot


def _state_payload(
    *,
    scope_id: str,
    project: dict[str, Any],
    state_field: str,
    mirror_field: str,
    items: list[dict[str, Any]],
    state_key: str,
    mirror_key: str,
    previous: dict[str, Any] | None = None,
) -> dict[str, Any]:
    previous = previous or {}
    return {
        "schema_version": "dokkaebi.project_status_sync_state.v1",
        "scopeId": scope_id,
        "project": project,
        "stateField": state_field,
        "humanStatusMirrorField": mirror_field,
        "createdAt": previous.get("createdAt") or _now_utc(),
        "updatedAt": _now_utc(),
        "items": _snapshot_items(items, state_key, mirror_key),
    }


def _previous_state_envelope_error(
    previous_state: dict[str, Any],
    *,
    scope_id: str,
    project: dict[str, Any],
    state_field: str,
    mirror_field: str,
) -> str | None:
    if not previous_state:
        return None
    expected = {
        "schema_version": "dokkaebi.project_status_sync_state.v1",
        "scopeId": scope_id,
        "project": project,
        "stateField": state_field,
        "humanStatusMirrorField": mirror_field,
    }
    for key, expected_value in expected.items():
        if previous_state.get(key) != expected_value:
            return f"previous sync snapshot {key} mismatch"
    if not isinstance(previous_state.get("items"), dict):
        return "previous sync snapshot items must be a mapping"
    return None


def _previous_item_snapshot_error(previous_item: Any, expected_states: list[str]) -> str | None:
    if not isinstance(previous_item, dict):
        return "previous item sync snapshot is missing"
    dokkaebi_status = str(previous_item.get("dokkaebiStatus") or "").strip()
    human_status = str(previous_item.get("humanStatus") or "").strip()
    if not dokkaebi_status or not human_status:
        return "previous item sync snapshot is incomplete"
    if dokkaebi_status not in expected_states or human_status not in expected_states:
        return "previous item sync snapshot contains an unknown status"
    if dokkaebi_status != human_status:
        return "previous item sync snapshot was not a clean equal baseline"
    return None


def _concurrent_change_finding(
    *,
    owner: str,
    number: int,
    limit: int,
    item_id: str,
    state_key: str,
    mirror_key: str,
    planned_dokkaebi_value: str,
    planned_mirror_value: str,
    update: dict[str, Any],
) -> dict[str, Any] | None:
    current = _item_by_id(_project_items(owner, number, limit), item_id)
    if not current:
        return {
            **update,
            "type": "concurrent_status_sync_item_missing",
            "reason": "project item disappeared before mutation",
        }
    current_dokkaebi = _field_value(current, state_key)
    current_mirror = _field_value(current, mirror_key)
    if current_dokkaebi == planned_dokkaebi_value and current_mirror == planned_mirror_value:
        return None
    return {
        **update,
        "type": "concurrent_status_sync_change",
        "reason": "project item status changed after planning; refusing to overwrite concurrent edit",
        "planned": {"status": planned_mirror_value, "dokkaebiStatus": planned_dokkaebi_value},
        "current": {"status": current_mirror, "dokkaebiStatus": current_dokkaebi},
    }


def _field_value(item: dict[str, Any], key: str) -> str:
    return str(item.get(key) or "").strip()


def _validate_value(
    payload: dict[str, Any],
    *,
    item: dict[str, Any],
    field: str,
    value: str,
    expected: list[str],
) -> bool:
    if not value:
        payload["findings"].append({"type": f"missing_{field}", "itemId": item.get("id"), "content": _content_summary(item)})
        return False
    if value not in expected:
        payload["findings"].append({
            "type": f"unknown_{field}",
            "itemId": item.get("id"),
            "value": value,
            "expected": expected,
            "content": _content_summary(item),
        })
        return False
    return True


def _plan_mismatch_update(
    *,
    item: dict[str, Any],
    dokkaebi_value: str,
    mirror_value: str,
    direction: Direction,
    bootstrap_source: BootstrapSource,
    previous_item: dict[str, Any] | None,
) -> dict[str, Any]:
    item_id = str(item.get("id") or "")
    base = {"itemId": item_id, "content": _content_summary(item), "status": mirror_value, "dokkaebiStatus": dokkaebi_value}

    if direction in {"verify"}:
        return {**base, "type": "status_mirror_mismatch"}
    if direction == "dokkaebi-to-status":
        return {
            **base,
            "type": "planned_status_mirror_update",
            "source": "dokkaebi",
            "target": "status",
            "targetValue": dokkaebi_value,
            "reason": "configured_dokkaebi_authoritative_sync",
        }
    if direction == "status-to-dokkaebi":
        return {
            **base,
            "type": "planned_dokkaebi_status_update",
            "source": "status",
            "target": "dokkaebi",
            "targetValue": mirror_value,
            "reason": "configured_human_status_source_sync",
        }

    if previous_item:
        previous_dokkaebi = str(previous_item.get("dokkaebiStatus") or "").strip()
        previous_mirror = str(previous_item.get("humanStatus") or "").strip()
        dokkaebi_changed = dokkaebi_value != previous_dokkaebi
        mirror_changed = mirror_value != previous_mirror
        if mirror_changed and not dokkaebi_changed:
            return {
                **base,
                "type": "planned_dokkaebi_status_update",
                "source": "status",
                "target": "dokkaebi",
                "targetValue": mirror_value,
                "reason": "observed_human_status_field_change_since_last_sync",
                "previous": {"status": previous_mirror, "dokkaebiStatus": previous_dokkaebi},
            }
        if dokkaebi_changed and not mirror_changed:
            return {
                **base,
                "type": "planned_status_mirror_update",
                "source": "dokkaebi",
                "target": "status",
                "targetValue": dokkaebi_value,
                "reason": "observed_dokkaebi_status_field_change_since_last_sync",
                "previous": {"status": previous_mirror, "dokkaebiStatus": previous_dokkaebi},
            }
        if mirror_changed and dokkaebi_changed:
            return {
                **base,
                "type": "bidirectional_status_conflict",
                "reason": "both_status_fields_changed_since_last_sync",
                "previous": {"status": previous_mirror, "dokkaebiStatus": previous_dokkaebi},
            }
        return {
            **base,
            "type": "bidirectional_stale_mismatch",
            "reason": "neither_status_field_changed_since_last_sync",
            "previous": {"status": previous_mirror, "dokkaebiStatus": previous_dokkaebi},
        }

    if bootstrap_source == "dokkaebi":
        return {
            **base,
            "type": "planned_status_mirror_update",
            "source": "dokkaebi",
            "target": "status",
            "targetValue": dokkaebi_value,
            "reason": "bootstrap_source_dokkaebi_without_prior_snapshot",
        }
    if bootstrap_source == "status":
        return {
            **base,
            "type": "planned_dokkaebi_status_update",
            "source": "status",
            "target": "dokkaebi",
            "targetValue": mirror_value,
            "reason": "bootstrap_source_status_without_prior_snapshot",
        }
    return {
        **base,
        "type": "bidirectional_bootstrap_required",
        "reason": "mismatched item has no prior sync snapshot; refusing to guess source",
    }


def _run_once(args: argparse.Namespace) -> dict[str, Any]:
    scope, tracker = _load_scope(Path(args.scope))
    scope_id = str(scope.get("id") or Path(args.scope).stem)
    owner = str(tracker.get("owner") or "").strip()
    number = int(tracker.get("project_number") or 0)
    project_id = str(tracker.get("project_id") or "").strip()
    state_field = str(tracker.get("state_field") or "Dokkaebi Status").strip()
    mirror_field = str(tracker.get("human_status_mirror_field") or "Status").strip()
    if not owner or number <= 0 or not project_id:
        raise ValueError("tracker owner, project_number, and project_id are required")

    direction: Direction = args.direction
    bootstrap_source: BootstrapSource = args.bootstrap_source
    state_file = _safe_repo_path(args.state_file, _default_state_file(scope_id))
    event_log = _safe_repo_path(args.event_log, DEFAULT_EVENT_LOG)
    should_record_state = args.record_state or args.watch or (direction == "bidirectional" and args.apply)
    should_read_state = direction == "bidirectional" or should_record_state
    audit_events_enabled = should_record_state or direction == "bidirectional"
    expected = _expected_states(tracker)
    project = {"owner": owner, "number": number, "id": project_id}
    payload: dict[str, Any] = {
        "ok": False,
        "applied": args.apply,
        "direction": direction,
        "bootstrapSource": bootstrap_source,
        "watch": args.watch,
        "findings": [],
        "updates": [],
        "events": [],
        "stateFile": str(state_file.relative_to(ROOT) if state_file.is_relative_to(ROOT) else state_file),
        "eventLog": str(event_log.relative_to(ROOT) if event_log.is_relative_to(ROOT) else event_log),
        "project": project,
        "stateField": state_field,
        "humanStatusMirrorField": mirror_field,
        "expectedStates": expected,
        "checkedAt": _now_utc(),
    }

    if args.apply:
        _ensure_no_kill_switch()

    fields = _project_fields(owner, number)
    dokkaebi_field = _field_by_name(fields, state_field)
    mirror = _field_by_name(fields, mirror_field)
    for field in [dokkaebi_field, mirror]:
        actual = _options(field)
        if actual != expected:
            payload["findings"].append({
                "type": "field_options_mismatch",
                "field": field.get("name"),
                "expected": expected,
                "actual": actual,
            })

    dokkaebi_option_ids = _option_ids(dokkaebi_field)
    mirror_option_ids = _option_ids(mirror)
    items = _project_items(owner, number, args.limit)
    payload["itemsChecked"] = len(items)
    state_key = _json_key(state_field)
    mirror_key = _json_key(mirror_field)
    previous_state = _read_json(state_file, {}) if should_read_state else {}
    previous_items = previous_state.get("items") if isinstance(previous_state.get("items"), dict) else {}
    previous_state_error = _previous_state_envelope_error(
        previous_state,
        scope_id=scope_id,
        project=project,
        state_field=state_field,
        mirror_field=mirror_field,
    )
    planned_updates: list[dict[str, Any]] = []

    # Phase 1: validate all items and build an all-or-nothing update plan.
    if not payload["findings"]:
        for item in items:
            item_id = str(item.get("id") or "")
            dokkaebi_value = _field_value(item, state_key)
            mirror_value = _field_value(item, mirror_key)
            dokkaebi_ok = _validate_value(payload, item=item, field="dokkaebi_status", value=dokkaebi_value, expected=expected)
            mirror_ok = _validate_value(payload, item=item, field="human_status", value=mirror_value, expected=expected)
            if not (dokkaebi_ok and mirror_ok) or mirror_value == dokkaebi_value:
                continue

            previous_item = previous_items.get(item_id) if isinstance(previous_items, dict) else None
            if previous_item is not None and not isinstance(previous_item, dict):
                previous_item = None
            if direction == "bidirectional" and previous_state_error:
                payload["findings"].append({
                    "type": "invalid_bidirectional_state_snapshot",
                    "itemId": item_id,
                    "reason": previous_state_error,
                    "content": _content_summary(item),
                })
                continue
            if direction == "bidirectional":
                previous_item_error = _previous_item_snapshot_error(previous_item, expected)
                if previous_item_error:
                    payload["findings"].append({
                        "type": "invalid_bidirectional_item_snapshot",
                        "itemId": item_id,
                        "reason": previous_item_error,
                        "content": _content_summary(item),
                    })
                    continue
            update = _plan_mismatch_update(
                item=item,
                dokkaebi_value=dokkaebi_value,
                mirror_value=mirror_value,
                direction=direction,
                bootstrap_source=bootstrap_source,
                previous_item=previous_item,
            )
            target = update.get("target")
            target_value = str(update.get("targetValue") or "").strip()
            if target not in {"status", "dokkaebi"}:
                payload["findings"].append(update)
                continue
            approval_blocker = _approval_sync_blocker(
                update=update,
                source_status=dokkaebi_value if target == "dokkaebi" else mirror_value,
                previous_item=previous_item,
                tracker=tracker,
            )
            if approval_blocker:
                payload["findings"].append(approval_blocker)
                continue
            if not args.apply:
                payload["findings"].append(update)
                continue
            if target == "status":
                option_id = mirror_option_ids.get(target_value)
                field_id = str(mirror.get("id") or "")
            else:
                option_id = dokkaebi_option_ids.get(target_value)
                field_id = str(dokkaebi_field.get("id") or "")
            if not option_id:
                payload["findings"].append({**update, "type": "missing_target_option_id"})
                continue
            planned_updates.append({
                "itemId": item_id,
                "fieldId": field_id,
                "optionId": option_id,
                "update": update,
                "plannedDokkaebiValue": dokkaebi_value,
                "plannedMirrorValue": mirror_value,
                "event": {
                    "schema_version": "dokkaebi.project_status_sync_event.v1",
                    "observedAt": payload["checkedAt"],
                    "project": project,
                    "itemId": item_id,
                    "content": _content_summary(item),
                    "source": update.get("source"),
                    "target": target,
                    "targetValue": target_value,
                    "previous": update.get("previous"),
                    "before": {"status": mirror_value, "dokkaebiStatus": dokkaebi_value},
                    "reason": update.get("reason"),
                },
            })

    # Phase 2: only after the entire plan is clean, re-read planned items and mutate.
    if args.apply and planned_updates and not payload["findings"]:
        for plan in planned_updates:
            concurrent_change = _concurrent_change_finding(
                owner=owner,
                number=number,
                limit=args.limit,
                item_id=str(plan["itemId"]),
                state_key=state_key,
                mirror_key=mirror_key,
                planned_dokkaebi_value=str(plan["plannedDokkaebiValue"]),
                planned_mirror_value=str(plan["plannedMirrorValue"]),
                update=plan["update"],
            )
            if concurrent_change:
                payload["findings"].append(concurrent_change)
        if not payload["findings"]:
            for plan in planned_updates:
                _update_item(project_id, str(plan["itemId"]), str(plan["fieldId"]), str(plan["optionId"]))
                payload["updates"].append(plan["update"])
                if audit_events_enabled:
                    event = dict(plan["event"])
                    event["appliedAt"] = _now_utc()
                    payload["events"].append(event)

    if payload["events"]:
        # Audit first: never record a clean baseline before append-only mutation events.
        _append_jsonl(event_log, payload["events"])
        payload["eventsRecorded"] = len(payload["events"])
    else:
        payload["eventsRecorded"] = 0

    if args.apply and payload["updates"] and not payload["findings"]:
        payload["postApply"] = True
        items = _project_items(owner, number, args.limit)
        payload["itemsChecked"] = len(items)
        for item in items:
            dokkaebi_value = _field_value(item, state_key)
            mirror_value = _field_value(item, mirror_key)
            if dokkaebi_value != mirror_value:
                payload["findings"].append({
                    "type": "post_apply_status_mirror_mismatch",
                    "itemId": item.get("id"),
                    "status": mirror_value,
                    "dokkaebiStatus": dokkaebi_value,
                    "content": _content_summary(item),
                })

    payload["ok"] = not payload["findings"]
    if payload["ok"] and should_record_state:
        # Re-read after mutation so the next bidirectional iteration has the true post-apply baseline.
        if args.apply and payload["updates"]:
            items = _project_items(owner, number, args.limit)
        _write_json(
            state_file,
            _state_payload(
                scope_id=scope_id,
                project=project,
                state_field=state_field,
                mirror_field=mirror_field,
                items=items,
                state_key=state_key,
                mirror_key=mirror_key,
                previous=previous_state,
            ),
        )
        payload["stateRecorded"] = True
    else:
        payload["stateRecorded"] = False

    return payload

def _print_payload(payload: dict[str, Any], json_output: bool) -> None:
    if json_output:
        print(json.dumps(payload, indent=2, ensure_ascii=False))
    elif payload["ok"]:
        updates = len(payload.get("updates") or [])
        state = " state-recorded" if payload.get("stateRecorded") else ""
        print(f"PASS project Status and Dokkaebi Status are synced; updates={updates}{state}")
    else:
        print("BLOCKED project Status mirror drift detected", file=sys.stderr)
        for finding in payload["findings"]:
            print(json.dumps(finding, ensure_ascii=False), file=sys.stderr)


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify or sync GitHub Project Status and Dokkaebi Status")
    parser.add_argument("--scope", default=str(DEFAULT_SCOPE), help="ProjectScope YAML path")
    parser.add_argument("--apply", action="store_true", help="Apply safe inferred status updates")
    parser.add_argument(
        "--direction",
        choices=["verify", "dokkaebi-to-status", "status-to-dokkaebi", "bidirectional"],
        default=None,
        help="Sync direction. Defaults to verify without --apply, dokkaebi-to-status with --apply.",
    )
    parser.add_argument(
        "--bootstrap-source",
        choices=["block", "dokkaebi", "status"],
        default="block",
        help="Source to trust for a mismatched item with no prior bidirectional snapshot.",
    )
    parser.add_argument("--state-file", help="Bidirectional snapshot file; defaults under .omx/state/project-status-sync")
    parser.add_argument("--event-log", help="Applied sync event JSONL path; defaults under .omx/state/project-status-sync")
    parser.add_argument("--record-state", action="store_true", help="Record current synced values as the next bidirectional baseline")
    parser.add_argument("--watch", action="store_true", help="Run continuously until blocked or interrupted")
    parser.add_argument("--interval-seconds", type=float, default=10.0, help="Watch interval in seconds")
    parser.add_argument("--max-iterations", type=int, default=0, help="Testing aid: stop watch after N iterations; 0 means forever")
    parser.add_argument("--json", action="store_true", help="Emit JSON")
    parser.add_argument("--limit", type=int, default=500, help="Maximum project items to inspect")
    args = parser.parse_args()

    if args.direction is None:
        args.direction = "dokkaebi-to-status" if args.apply else "verify"
    if args.state_file is None:
        args.state_file = ""
    if args.event_log is None:
        args.event_log = ""
    if args.watch and not args.apply:
        print("BLOCKED --watch requires --apply so drift does not accumulate silently", file=sys.stderr)
        return 2
    if args.watch and args.direction != "bidirectional":
        print("BLOCKED --watch requires --direction bidirectional", file=sys.stderr)
        return 2

    if not args.watch:
        try:
            payload = _run_once(args)
        except Exception as exc:
            payload = {"ok": False, "applied": args.apply, "findings": [{"type": "error", "message": str(exc)}], "updates": [], "events": []}
        _print_payload(payload, args.json)
        return 0 if payload.get("ok") else 2

    iterations = 0
    last_payload: dict[str, Any] = {}
    while True:
        iterations += 1
        try:
            last_payload = _run_once(args)
        except Exception as exc:
            last_payload = {"ok": False, "applied": args.apply, "findings": [{"type": "error", "message": str(exc)}], "updates": [], "events": [], "iteration": iterations}
        last_payload["iteration"] = iterations
        if not last_payload.get("ok"):
            _print_payload(last_payload, args.json)
            return 2
        if args.json:
            print(json.dumps(last_payload, indent=2, ensure_ascii=False), flush=True)
        elif last_payload.get("updates"):
            print(f"[{_now_utc()}] synced updates={len(last_payload['updates'])}", flush=True)
        if args.max_iterations and iterations >= args.max_iterations:
            return 0
        time.sleep(max(args.interval_seconds, 0.1))


if __name__ == "__main__":
    raise SystemExit(main())
