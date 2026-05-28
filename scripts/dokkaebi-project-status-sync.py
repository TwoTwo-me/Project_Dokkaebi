#!/usr/bin/env python3
"""Verify or repair the human-visible GitHub Project Status mirror.

Dokkaebi uses one semantic state machine. GitHub's built-in Project `Status`
field is the human-visible mirror; the configured Dokkaebi state field remains
available for tracker integrations. This script fails closed when either field's
options drift or item values disagree. With --apply, it updates the human-visible
mirror from the Dokkaebi-authoritative field.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

try:
    import yaml  # type: ignore
except Exception as exc:  # pragma: no cover - preflight catches this
    print(f"BLOCKED missing PyYAML dependency: {exc}", file=sys.stderr)
    sys.exit(2)

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SCOPE = ROOT / "dokkaebi" / "project-scopes" / "project-dokkaebi.yml"


def _run(args: list[str]) -> str:
    proc = subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or proc.stdout.strip() or f"command failed: {' '.join(args)}")
    return proc.stdout


def _load_scope(path: Path) -> dict[str, Any]:
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"ProjectScope must parse to a mapping: {path}")
    tracker = data.get("tracker")
    if not isinstance(tracker, dict):
        raise ValueError("ProjectScope missing tracker mapping")
    return tracker


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


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify or sync GitHub Project Status from Dokkaebi Status")
    parser.add_argument("--scope", default=str(DEFAULT_SCOPE), help="ProjectScope YAML path")
    parser.add_argument("--apply", action="store_true", help="Update the human-visible Status mirror to match Dokkaebi Status")
    parser.add_argument("--json", action="store_true", help="Emit JSON")
    parser.add_argument("--limit", type=int, default=500, help="Maximum project items to inspect")
    args = parser.parse_args()

    payload: dict[str, Any] = {"ok": False, "applied": args.apply, "findings": [], "updates": []}
    try:
        tracker = _load_scope(Path(args.scope))
        owner = str(tracker.get("owner") or "").strip()
        number = int(tracker.get("project_number") or 0)
        project_id = str(tracker.get("project_id") or "").strip()
        state_field = str(tracker.get("state_field") or "Dokkaebi Status").strip()
        mirror_field = str(tracker.get("human_status_mirror_field") or "Status").strip()
        if not owner or number <= 0 or not project_id:
            raise ValueError("tracker owner, project_number, and project_id are required")

        expected = _expected_states(tracker)
        fields = _project_fields(owner, number)
        dokkaebi_field = _field_by_name(fields, state_field)
        mirror = _field_by_name(fields, mirror_field)
        payload.update({
            "project": {"owner": owner, "number": number, "id": project_id},
            "stateField": state_field,
            "humanStatusMirrorField": mirror_field,
            "expectedStates": expected,
        })

        for field in [dokkaebi_field, mirror]:
            actual = _options(field)
            if actual != expected:
                payload["findings"].append({
                    "type": "field_options_mismatch",
                    "field": field.get("name"),
                    "expected": expected,
                    "actual": actual,
                })

        mirror_option_ids = _option_ids(mirror)
        items = _project_items(owner, number, args.limit)
        payload["itemsChecked"] = len(items)
        state_key = _json_key(state_field)
        mirror_key = _json_key(mirror_field)
        for item in items:
            item_id = str(item.get("id") or "")
            content = item.get("content") or {}
            dokkaebi_value = str(item.get(state_key) or "").strip()
            mirror_value = str(item.get(mirror_key) or "").strip()
            if not dokkaebi_value:
                payload["findings"].append({"type": "missing_dokkaebi_status", "itemId": item_id, "content": content})
                continue
            if dokkaebi_value not in expected:
                payload["findings"].append({"type": "unknown_dokkaebi_status", "itemId": item_id, "value": dokkaebi_value, "content": content})
                continue
            if mirror_value != dokkaebi_value:
                finding = {
                    "type": "status_mirror_mismatch",
                    "itemId": item_id,
                    "content": content,
                    "status": mirror_value,
                    "dokkaebiStatus": dokkaebi_value,
                }
                if args.apply and dokkaebi_value in mirror_option_ids:
                    _update_item(project_id, item_id, str(mirror.get("id") or ""), mirror_option_ids[dokkaebi_value])
                    payload["updates"].append(finding)
                else:
                    payload["findings"].append(finding)

        if args.apply and payload["updates"]:
            # Re-read once after mutation; any residual mismatch remains a blocker.
            payload["postApply"] = True
            payload["findings"] = []
            items = _project_items(owner, number, args.limit)
            for item in items:
                dokkaebi_value = str(item.get(state_key) or "").strip()
                mirror_value = str(item.get(mirror_key) or "").strip()
                if dokkaebi_value != mirror_value:
                    payload["findings"].append({
                        "type": "post_apply_status_mirror_mismatch",
                        "itemId": item.get("id"),
                        "status": mirror_value,
                        "dokkaebiStatus": dokkaebi_value,
                    })

        payload["ok"] = not payload["findings"]
    except Exception as exc:
        payload["findings"].append({"type": "error", "message": str(exc)})

    if args.json:
        print(json.dumps(payload, indent=2, ensure_ascii=False))
    elif payload["ok"]:
        updates = len(payload.get("updates") or [])
        print(f"PASS project Status mirrors Dokkaebi Status; updates={updates}")
    else:
        print("BLOCKED project Status mirror drift detected", file=sys.stderr)
        for finding in payload["findings"]:
            print(json.dumps(finding, ensure_ascii=False), file=sys.stderr)
    return 0 if payload["ok"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
