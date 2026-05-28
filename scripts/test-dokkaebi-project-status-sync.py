#!/usr/bin/env python3
"""Local regression tests for Dokkaebi Project status sync.

These tests monkeypatch GitHub access and never call the network. They cover the
fail-closed invariants that make bidirectional observed sync safe enough for the
bootstrap Manager loop.
"""
from __future__ import annotations

import importlib.util
import json
import tempfile
from pathlib import Path
from types import SimpleNamespace
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "dokkaebi-project-status-sync.py"
STATES = [
    "Intake",
    "Clarifying",
    "Ready",
    "Dispatchable",
    "In Progress",
    "Human Review",
    "Fix Requested",
    "Merging",
    "Done",
    "Reopened",
    "Blocked",
    "Failed",
    "Cancelled",
]


def load_module():
    spec = importlib.util.spec_from_file_location("dokkaebi_project_status_sync", SCRIPT)
    if spec is None or spec.loader is None:
        raise AssertionError("failed to load status sync module spec")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class FakeProject:
    def __init__(self, dokkaebi_status: str, human_status: str):
        self.item = {
            "id": "PVTI_test",
            "dokkaebi Status": dokkaebi_status,
            "status": human_status,
            "content": {"type": "Issue", "number": 1, "title": "Test", "url": "https://example.invalid/1"},
        }
        self.updates: list[dict[str, str]] = []
        self.option_ids = {state: state.lower().replace(" ", "-") for state in STATES}

    def fields(self, _owner: str, _number: int) -> list[dict[str, Any]]:
        options = [{"name": state, "id": self.option_ids[state]} for state in STATES]
        return [
            {"name": "Dokkaebi Status", "id": "field-dokkaebi", "options": options},
            {"name": "Status", "id": "field-status", "options": options},
        ]

    def items(self, _owner: str, _number: int, _limit: int) -> list[dict[str, Any]]:
        return [json.loads(json.dumps(self.item))]

    def update(self, _project_id: str, item_id: str, field_id: str, option_id: str) -> None:
        if item_id != self.item["id"]:
            raise AssertionError(f"unexpected item id {item_id}")
        target = next((state for state, oid in self.option_ids.items() if oid == option_id), None)
        if target is None:
            raise AssertionError(f"unexpected option id {option_id}")
        if field_id == "field-dokkaebi":
            self.item["dokkaebi Status"] = target
            target_field = "dokkaebi"
        elif field_id == "field-status":
            self.item["status"] = target
            target_field = "status"
        else:
            raise AssertionError(f"unexpected field id {field_id}")
        self.updates.append({"target": target_field, "value": target})


class MultiFakeProject:
    def __init__(self, items: list[dict[str, str]]):
        self.items_data = [
            {
                "id": item["id"],
                "dokkaebi Status": item["dokkaebi"],
                "status": item["human"],
                "content": {"type": "Issue", "number": index + 1, "title": item["id"], "url": f"https://example.invalid/{index + 1}"},
            }
            for index, item in enumerate(items)
        ]
        self.updates: list[dict[str, str]] = []
        self.option_ids = {state: state.lower().replace(" ", "-") for state in STATES}

    def fields(self, _owner: str, _number: int) -> list[dict[str, Any]]:
        options = [{"name": state, "id": self.option_ids[state]} for state in STATES]
        return [
            {"name": "Dokkaebi Status", "id": "field-dokkaebi", "options": options},
            {"name": "Status", "id": "field-status", "options": options},
        ]

    def items(self, _owner: str, _number: int, _limit: int) -> list[dict[str, Any]]:
        return json.loads(json.dumps(self.items_data))

    def update(self, _project_id: str, item_id: str, field_id: str, option_id: str) -> None:
        item = next((candidate for candidate in self.items_data if candidate["id"] == item_id), None)
        if item is None:
            raise AssertionError(f"unexpected item id {item_id}")
        target = next((state for state, oid in self.option_ids.items() if oid == option_id), None)
        if target is None:
            raise AssertionError(f"unexpected option id {option_id}")
        if field_id == "field-dokkaebi":
            item["dokkaebi Status"] = target
            target_field = "dokkaebi"
        elif field_id == "field-status":
            item["status"] = target
            target_field = "status"
        else:
            raise AssertionError(f"unexpected field id {field_id}")
        self.updates.append({"itemId": item_id, "target": target_field, "value": target})


class RaceFakeProject(FakeProject):
    def __init__(self, dokkaebi_status: str, human_status: str, raced_human_status: str):
        super().__init__(dokkaebi_status, human_status)
        self._items_calls = 0
        self._raced_human_status = raced_human_status

    def items(self, _owner: str, _number: int, _limit: int) -> list[dict[str, Any]]:
        self._items_calls += 1
        if self._items_calls >= 2:
            self.item["status"] = self._raced_human_status
        return [json.loads(json.dumps(self.item))]


def write_scope(tmp: Path) -> Path:
    mapping = "\n".join(f"    {state.lower().replace(' ', '_')}: {state}" for state in STATES)
    path = tmp / "scope.yml"
    path.write_text(
        f"""
schema_version: test
id: project-dokkaebi
tracker:
  owner: Project-Dokkaebi
  project_number: 1
  project_id: PVT_test
  state_field: Dokkaebi Status
  human_status_mirror_field: Status
  status_mapping:
{mapping}
  human_review_transition_policy:
    terminal_approval_transitions:
      - from: Human Review
        to: Merging
        required_origin: human
      - from: Human Review
        to: Done
        required_origin: human
    enabled_provenance_sources:
      - durable_human_approval_record
    trusted_provenance_verifiers:
      - dokkaebi-human-approval-record-adapter
    required_transition_record_fields:
      - actor
      - actor_origin
      - provenance_source
      - approved_action
""".lstrip(),
        encoding="utf-8",
    )
    return path


def args(scope: Path, state_file: Path, *, apply: bool, direction: str, record_state: bool = False):
    return SimpleNamespace(
        scope=str(scope),
        apply=apply,
        direction=direction,
        bootstrap_source="block",
        state_file=str(state_file),
        event_log=str(state_file.with_suffix(".events.jsonl")),
        record_state=record_state,
        watch=False,
        json=True,
        limit=500,
    )


def write_snapshot(path: Path, *, dokkaebi_status: str, human_status: str, project_id: str = "PVT_test") -> None:
    write_multi_snapshot(path, [{"id": "PVTI_test", "dokkaebi": dokkaebi_status, "human": human_status}], project_id=project_id)


def write_multi_snapshot(path: Path, items: list[dict[str, str]], project_id: str = "PVT_test") -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    snapshot_items = {}
    for index, item in enumerate(items):
        snapshot_items[item["id"]] = {
            "dokkaebiStatus": item["dokkaebi"],
            "humanStatus": item["human"],
            "content": {"type": "Issue", "number": index + 1, "title": item["id"], "url": f"https://example.invalid/{index + 1}"},
            "seenAt": "2026-05-28T00:00:00Z",
        }
    path.write_text(
        json.dumps(
            {
                "schema_version": "dokkaebi.project_status_sync_state.v1",
                "scopeId": "project-dokkaebi",
                "project": {"owner": "Project-Dokkaebi", "number": 1, "id": project_id},
                "stateField": "Dokkaebi Status",
                "humanStatusMirrorField": "Status",
                "createdAt": "2026-05-28T00:00:00Z",
                "updatedAt": "2026-05-28T00:00:00Z",
                "items": snapshot_items,
            },
            indent=2,
        ),
        encoding="utf-8",
    )


def run_case(name: str, fake: FakeProject, state_file: Path, run_args: SimpleNamespace) -> dict[str, Any]:
    module = load_module()
    module._project_fields = fake.fields
    module._project_items = fake.items
    module._update_item = fake.update
    payload = module._run_once(run_args)
    print(f"PASS {name}: ok={payload['ok']} updates={len(payload.get('updates') or [])} findings={len(payload.get('findings') or [])}")
    return payload


def run_case_with_module(name: str, module: Any, fake: FakeProject, run_args: SimpleNamespace) -> dict[str, Any]:
    module._project_fields = fake.fields
    module._project_items = fake.items
    module._update_item = fake.update
    payload = module._run_once(run_args)
    print(f"PASS {name}: ok={payload['ok']} updates={len(payload.get('updates') or [])} findings={len(payload.get('findings') or [])}")
    return payload


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="dokkaebi-status-sync-test-") as raw:
        tmp = Path(raw)
        scope = write_scope(tmp)

        # Legacy one-shot --apply remains a remote repair only; it must not write
        # the local bidirectional snapshot unless the user opts into observed sync.
        legacy_state = tmp / "legacy-state.json"
        legacy_fake = FakeProject("Ready", "Intake")
        legacy = run_case(
            "legacy apply no state write",
            legacy_fake,
            legacy_state,
            args(scope, legacy_state, apply=True, direction="dokkaebi-to-status"),
        )
        assert legacy["ok"] is True
        assert legacy_fake.updates == [{"target": "status", "value": "Ready"}]
        assert legacy["stateRecorded"] is False
        assert not legacy_state.exists()

        corrupt_state = tmp / "corrupt-legacy-state.json"
        corrupt_state.write_text("{not-json", encoding="utf-8")
        corrupt_fake = FakeProject("Ready", "Intake")
        corrupt_legacy = run_case(
            "legacy apply ignores corrupt state file",
            corrupt_fake,
            corrupt_state,
            args(scope, corrupt_state, apply=True, direction="dokkaebi-to-status"),
        )
        assert corrupt_legacy["ok"] is True
        assert corrupt_fake.updates == [{"target": "status", "value": "Ready"}]
        assert corrupt_legacy["stateRecorded"] is False

        # Bidirectional source inference requires a clean equal baseline.
        dirty_state = tmp / "dirty-state.json"
        write_snapshot(dirty_state, dokkaebi_status="Ready", human_status="Intake")
        dirty_fake = FakeProject("Ready", "Dispatchable")
        dirty = run_case(
            "dirty snapshot blocks",
            dirty_fake,
            dirty_state,
            args(scope, dirty_state, apply=True, direction="bidirectional"),
        )
        assert dirty["ok"] is False
        assert dirty["findings"][0]["type"] == "invalid_bidirectional_item_snapshot"
        assert dirty_fake.updates == []

        for terminal_target in ["Done", "Merging"]:
            # Status -> Dokkaebi terminal/approval transition blocks without
            # trusted provenance even when a clean snapshot proves the
            # human-visible field changed.
            terminal_state = tmp / f"terminal-{terminal_target}-state.json"
            write_snapshot(terminal_state, dokkaebi_status="Human Review", human_status="Human Review")
            terminal_fake = FakeProject("Human Review", terminal_target)
            terminal = run_case(
                f"terminal status-to-dokkaebi {terminal_target} blocks",
                terminal_fake,
                terminal_state,
                args(scope, terminal_state, apply=True, direction="bidirectional"),
            )
            assert terminal["ok"] is False
            assert terminal["findings"][0]["type"] == "approval_required_status_sync_blocked"
            assert terminal_fake.updates == []

            terminal_dokkaebi_state = tmp / f"terminal-dokkaebi-{terminal_target}-state.json"
            write_snapshot(terminal_dokkaebi_state, dokkaebi_status="Human Review", human_status="Human Review")
            terminal_dokkaebi_fake = FakeProject(terminal_target, "Human Review")
            terminal_dokkaebi = run_case(
                f"terminal dokkaebi-to-status observed {terminal_target} drift blocks",
                terminal_dokkaebi_fake,
                terminal_dokkaebi_state,
                args(scope, terminal_dokkaebi_state, apply=True, direction="bidirectional"),
            )
            assert terminal_dokkaebi["ok"] is False
            assert terminal_dokkaebi["findings"][0]["type"] == "approval_required_status_sync_blocked"
            assert terminal_dokkaebi_fake.updates == []

            one_shot_dokkaebi_state = tmp / f"one-shot-dokkaebi-{terminal_target}-state.json"
            one_shot_dokkaebi_fake = FakeProject(terminal_target, "Human Review")
            one_shot_dokkaebi = run_case(
                f"one-shot terminal dokkaebi-to-status {terminal_target} blocks",
                one_shot_dokkaebi_fake,
                one_shot_dokkaebi_state,
                args(scope, one_shot_dokkaebi_state, apply=True, direction="dokkaebi-to-status"),
            )
            assert one_shot_dokkaebi["ok"] is False
            assert one_shot_dokkaebi["findings"][0]["type"] == "approval_required_status_sync_blocked"
            assert one_shot_dokkaebi_fake.updates == []

            one_shot_status_state = tmp / f"one-shot-status-{terminal_target}-state.json"
            one_shot_status_fake = FakeProject("Human Review", terminal_target)
            one_shot_status = run_case(
                f"one-shot terminal status-to-dokkaebi {terminal_target} blocks",
                one_shot_status_fake,
                one_shot_status_state,
                args(scope, one_shot_status_state, apply=True, direction="status-to-dokkaebi"),
            )
            assert one_shot_status["ok"] is False
            assert one_shot_status["findings"][0]["type"] == "approval_required_status_sync_blocked"
            assert one_shot_status_fake.updates == []

        # Ordinary non-terminal Status -> Dokkaebi drift still auto-syncs.
        nonterminal_state = tmp / "nonterminal-state.json"
        write_snapshot(nonterminal_state, dokkaebi_status="Ready", human_status="Ready")
        nonterminal_fake = FakeProject("Ready", "Dispatchable")
        nonterminal = run_case(
            "nonterminal status-to-dokkaebi applies",
            nonterminal_fake,
            nonterminal_state,
            args(scope, nonterminal_state, apply=True, direction="bidirectional"),
        )
        assert nonterminal["ok"] is True
        assert nonterminal_fake.updates == [{"target": "dokkaebi", "value": "Dispatchable"}]

        audit_state = tmp / "audit-state.json"
        write_snapshot(audit_state, dokkaebi_status="Ready", human_status="Ready")
        audit_fake = FakeProject("Ready", "Dispatchable")
        audit_module = load_module()
        audit_order: list[str] = []
        original_append = audit_module._append_jsonl
        original_write = audit_module._write_json

        def append_spy(path: Path, events: list[dict[str, Any]]) -> None:
            audit_order.append("append")
            original_append(path, events)

        def write_spy(path: Path, data: dict[str, Any]) -> None:
            audit_order.append("write")
            original_write(path, data)

        audit_module._append_jsonl = append_spy
        audit_module._write_json = write_spy
        audit = run_case_with_module(
            "event append happens before state snapshot",
            audit_module,
            audit_fake,
            args(scope, audit_state, apply=True, direction="bidirectional", record_state=True),
        )
        assert audit["ok"] is True
        assert audit["eventsRecorded"] == 1
        assert audit["stateRecorded"] is True
        assert audit_order == ["append", "write"]
        event_lines = audit_state.with_suffix(".events.jsonl").read_text(encoding="utf-8").strip().splitlines()
        assert len(event_lines) == 1
        assert json.loads(event_lines[0])["target"] == "dokkaebi"

        # Snapshot envelope must match the active scope/project/fields.
        envelope_state = tmp / "envelope-state.json"
        write_snapshot(envelope_state, dokkaebi_status="Ready", human_status="Ready", project_id="PVT_other")
        envelope_fake = FakeProject("Ready", "Dispatchable")
        envelope = run_case(
            "snapshot envelope mismatch blocks",
            envelope_fake,
            envelope_state,
            args(scope, envelope_state, apply=True, direction="bidirectional"),
        )
        assert envelope["ok"] is False
        assert envelope["findings"][0]["type"] == "invalid_bidirectional_state_snapshot"
        assert envelope_fake.updates == []

        race_state = tmp / "race-state.json"
        write_snapshot(race_state, dokkaebi_status="Ready", human_status="Ready")
        race_fake = RaceFakeProject("Dispatchable", "Ready", "Clarifying")
        race = run_case(
            "re-read race guard blocks concurrent status edit",
            race_fake,
            race_state,
            args(scope, race_state, apply=True, direction="bidirectional"),
        )
        assert race["ok"] is False
        assert race["findings"][0]["type"] == "concurrent_status_sync_change"
        assert race_fake.updates == []

        # Planning is all-or-nothing: a later blocker prevents an earlier safe
        # item from being remotely mutated.
        partial_state = tmp / "partial-state.json"
        write_multi_snapshot(
            partial_state,
            [
                {"id": "one", "dokkaebi": "Ready", "human": "Ready"},
                {"id": "two", "dokkaebi": "Human Review", "human": "Human Review"},
            ],
        )
        partial_fake = MultiFakeProject(
            [
                {"id": "one", "dokkaebi": "Ready", "human": "Dispatchable"},
                {"id": "two", "dokkaebi": "Human Review", "human": "Done"},
            ]
        )
        partial = run_case(
            "two phase blocks all updates when later item blocks",
            partial_fake,
            partial_state,
            args(scope, partial_state, apply=True, direction="bidirectional"),
        )
        assert partial["ok"] is False
        assert partial["findings"][0]["type"] == "approval_required_status_sync_blocked"
        assert partial_fake.updates == []

    print("PASS Dokkaebi project status sync regression tests")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
