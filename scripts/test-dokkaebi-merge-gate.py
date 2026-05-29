#!/usr/bin/env python3
"""Local regression tests for Dokkaebi Merge Gate v0.

All GitHub CLI behavior is mocked. Tests create short-lived local approval
fixtures so the merge gate exercises the existing approval transition checker
without network access.
"""
from __future__ import annotations

import hashlib
import importlib.util
import json
import shutil
import tempfile
from pathlib import Path
from types import SimpleNamespace
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "dokkaebi-merge-gate.py"


def load_module():
    spec = importlib.util.spec_from_file_location("dokkaebi_merge_gate", SCRIPT)
    if spec is None or spec.loader is None:
        raise AssertionError("failed to load merge gate module spec")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def write_scope(tmp: Path) -> Path:
    path = tmp / "scope.yml"
    path.write_text(
        """
schema_version: test
id: project-dokkaebi
tracker:
  owner: Project-Dokkaebi
  project_number: 1
  project_id: PVT_test
  state_field: Dokkaebi Status
  human_status_mirror_field: Status
""".lstrip(),
        encoding="utf-8",
    )
    return path


def candidate_item(*, pr: int = 7, permission: str = "docs-only", status: str = "Merging", dokkaebi_status: str = "Merging", transition_record: str = "") -> dict[str, Any]:
    item = {
        "id": "PVTI_test",
        "status": status,
        "dokkaebiStatus": dokkaebi_status,
        "permissionLevel": permission,
        "content": {"type": "PullRequest", "number": pr, "title": "Test PR", "url": f"https://github.com/TwoTwo-me/Project_Dokkaebi/pull/{pr}"},
    }
    if transition_record:
        item["transitionRecord"] = transition_record
    return item


def pr_payload(*, state: str = "OPEN", mergeable: str = "MERGEABLE", checks: Any | None = None, files: list[str] | None = None) -> dict[str, Any]:
    if checks is None:
        checks = [{"name": "unit", "conclusion": "SUCCESS"}]
    if files is None:
        files = ["docs/runbooks/example.md"]
    return {
        "number": 7,
        "title": "Test PR",
        "url": "https://github.com/TwoTwo-me/Project_Dokkaebi/pull/7",
        "state": state,
        "mergeable": mergeable,
        "isDraft": False,
        "statusCheckRollup": checks,
        "files": [{"path": path} for path in files],
        "headRefName": "feature",
        "baseRefName": "dokkaebi/closed-loop-20260528",
    }


def make_approval_fixture(label: str) -> tuple[Path, list[Path]]:
    safe = label.replace("/", "-")
    approval_path = ROOT / "dokkaebi" / "approvals" / f"test-merge-gate-{safe}.md"
    evidence_path = ROOT / ".omx" / "evidence" / "provenance" / f"test-merge-gate-{safe}.json"
    transition_path = ROOT / ".omx" / "evidence" / "provenance" / f"test-merge-gate-transition-{safe}.json"
    approval_path.write_text("# Test Merge Gate Approval\n\nHuman approved PR merge for local regression.\n", encoding="utf-8")
    evidence = {
        "record_id": f"test-merge-gate-{safe}",
        "provenance_source": "durable_human_approval_record",
        "verified_by": "dokkaebi-human-approval-record-adapter",
        "verification_method": "approval_record_path",
        "actor": "human-reviewer",
        "actor_origin": "human",
        "approved_action": "pr_merge",
        "source_status": "Human Review",
        "target_status": "Merging",
        "approval_record_path": str(approval_path.relative_to(ROOT)),
    }
    write_json(evidence_path, evidence)
    sha = hashlib.sha256(evidence_path.read_bytes()).hexdigest()
    transition = {
        "source_status": "Human Review",
        "target_status": "Merging",
        "actor": "human-reviewer",
        "actor_origin": "human",
        "provenance_source": "durable_human_approval_record",
        "approved_action": "pr_merge",
        "linked_ticket_or_item": "PVTI_test",
        "linked_result_packet_or_review": str(approval_path.relative_to(ROOT)),
        "provenance_record_id": f"test-merge-gate-{safe}",
        "provenance_checked_by": "dokkaebi-human-approval-record-adapter",
        "provenance_verification_method": "approval_record_path",
        "provenance_evidence_file": str(evidence_path.relative_to(ROOT)),
        "provenance_evidence_sha256": sha,
    }
    write_json(transition_path, transition)
    return transition_path, [approval_path, evidence_path, transition_path]


def args(scope: Path, candidate_file: Path, transition_record: Path | None = None, *, apply: bool = False, merge: bool = False) -> SimpleNamespace:
    return SimpleNamespace(
        scope=str(scope),
        policy=str(ROOT / "dokkaebi" / "policies" / "project-dokkaebi.yml"),
        candidate_file=str(candidate_file),
        candidate_json=None,
        transition_record=str(transition_record) if transition_record else None,
        limit=200,
        apply=apply,
        merge=merge,
        json=True,
    )


def run_case(name: str, module: Any, run_args: SimpleNamespace, pr: dict[str, Any]) -> tuple[dict[str, Any], list[list[str]]]:
    calls: list[list[str]] = []

    def fake_run(command: list[str]) -> str:
        calls.append(command)
        if command[:3] == ["gh", "pr", "view"]:
            return json.dumps(pr)
        if command[:3] == ["gh", "pr", "merge"]:
            return ""
        raise AssertionError(f"unexpected gh command: {command}")

    module._run = fake_run
    payload = module._run_once(run_args)
    print(f"PASS {name}: ok={payload['ok']} candidates={payload.get('candidatesFound')} actions={len(payload.get('actions') or [])}")
    return payload, calls


def main() -> int:
    created: list[Path] = []
    try:
        transition, fixture_paths = make_approval_fixture("ready")
        created.extend(fixture_paths)
        with tempfile.TemporaryDirectory(prefix="dokkaebi-merge-gate-test-") as raw:
            tmp = Path(raw)
            scope = write_scope(tmp)

            ready_candidates = tmp / "ready-candidates.json"
            write_json(ready_candidates, {"items": [candidate_item(transition_record=str(transition.relative_to(ROOT)))]})
            module = load_module()
            ready, ready_calls = run_case("dry-run ready plan", module, args(scope, ready_candidates), pr_payload())
            assert ready["ok"] is True
            assert ready["mode"] == "dry-run"
            assert ready["candidates"][0]["state"] == "ready"
            assert ready["candidates"][0]["plannedTerminalState"] == "Done"
            assert ready["actions"][0]["type"] == "merge_gate_ready_plan"
            assert not any(call[:3] == ["gh", "pr", "merge"] for call in ready_calls)

            apply_module = load_module()
            apply_payload, apply_calls = run_case("apply without merge does not merge", apply_module, args(scope, ready_candidates, apply=True), pr_payload())
            assert apply_payload["ok"] is True
            assert apply_payload["mode"] == "apply"
            assert not any(call[:3] == ["gh", "pr", "merge"] for call in apply_calls)

            merge_module = load_module()
            merge_payload, merge_calls = run_case("double-gated merge flag invokes merge", merge_module, args(scope, ready_candidates, apply=True, merge=True), pr_payload())
            assert merge_payload["ok"] is True
            assert any(call[:3] == ["gh", "pr", "merge"] for call in merge_calls)

            missing_approval_candidates = tmp / "missing-approval.json"
            write_json(missing_approval_candidates, {"items": [candidate_item()]})
            missing_module = load_module()
            missing, missing_calls = run_case("missing approval blocks", missing_module, args(scope, missing_approval_candidates), pr_payload())
            assert missing["ok"] is False
            assert missing["candidates"][0]["state"] == "blocked"
            assert "approval blocked" in missing["candidates"][0]["reasons"][0]
            assert not any(call[:3] == ["gh", "pr", "merge"] for call in missing_calls)

            provider_candidates = tmp / "provider.json"
            write_json(provider_candidates, {"items": [candidate_item(permission="provider-change", transition_record=str(transition.relative_to(ROOT)))]})
            provider_module = load_module()
            provider, _ = run_case("provider change remains manual", provider_module, args(scope, provider_candidates), pr_payload(files=["ops/systemd/example.service"]))
            assert provider["ok"] is False
            assert provider["candidates"][0]["permission"]["ok"] is False
            assert provider["candidates"][0]["recommendedStatus"] == "Blocked"

            unavailable_checks_module = load_module()
            unavailable, _ = run_case("unavailable checks block", unavailable_checks_module, args(scope, ready_candidates), pr_payload(checks=[]))
            assert unavailable["ok"] is False
            assert unavailable["candidates"][0]["checks"]["reason"] == "status checks unavailable"
            assert unavailable["candidates"][0]["recommendedStatus"] == "Blocked"

            failing_checks_module = load_module()
            failing, _ = run_case("failing checks request fix", failing_checks_module, args(scope, ready_candidates), pr_payload(checks=[{"name": "unit", "conclusion": "FAILURE"}]))
            assert failing["ok"] is False
            assert failing["candidates"][0]["recommendedStatus"] == "Fix Requested"

            non_candidate = tmp / "non-candidate.json"
            write_json(non_candidate, {"items": [candidate_item(status="Human Review", dokkaebi_status="Merging")]})
            non_module = load_module()
            non, non_calls = run_case("only dual merging PRs are candidates", non_module, args(scope, non_candidate), pr_payload())
            assert non["ok"] is True
            assert non["candidatesFound"] == 0
            assert non_calls == []
    finally:
        for path in reversed(created):
            try:
                path.unlink()
            except FileNotFoundError:
                pass
        # Remove empty test-created provenance directory if possible; leave real
        # repository state untouched if other files are present.
        provenance_dir = ROOT / ".omx" / "evidence" / "provenance"
        try:
            provenance_dir.rmdir()
            (ROOT / ".omx" / "evidence").rmdir()
        except OSError:
            pass

    print("PASS Dokkaebi merge gate regression tests")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
