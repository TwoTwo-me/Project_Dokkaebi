#!/usr/bin/env python3
"""Plan and gate Dokkaebi PR merge candidates.

Merge Gate v0 is intentionally fail-closed. It finds GitHub Project items whose
human-visible `Status` and Manager `Dokkaebi Status` are both `Merging`, checks
that the linked content is an open PR with passing/available merge evidence, and
requires an explicit human-origin approval transition record before planning the
terminal `Done` state.

Default mode is dry-run JSON only. `--apply` may perform conservative live
annotations in later use, but this v0 never merges a PR unless both `--apply` and
`--merge` are present. Tests mock all gh calls; no network is required for local
validation.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import subprocess
import sys
from datetime import UTC, datetime
from pathlib import Path
from typing import Any, Iterable

try:
    import yaml  # type: ignore
except Exception as exc:  # pragma: no cover - environment preflight catches this
    print(f"BLOCKED missing PyYAML dependency: {exc}", file=sys.stderr)
    sys.exit(2)

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SCOPE = ROOT / "dokkaebi" / "project-scopes" / "project-dokkaebi.yml"
DEFAULT_POLICY = ROOT / "dokkaebi" / "policies" / "project-dokkaebi.yml"
APPROVAL_CHECKER = ROOT / "scripts" / "dokkaebi-approval-transition-check.py"
KILL_SWITCH = ROOT / "dokkaebi" / "KILL_SWITCH"
ELIGIBLE_PERMISSION_LEVELS = {"docs-only", "local-code"}
HUMAN_MANUAL_PERMISSION_LEVELS = {"provider-change", "merge-deploy", "credentialed"}
PASSING_CONCLUSIONS = {"SUCCESS", "SKIPPED", "NEUTRAL"}
PENDING_CONCLUSIONS = {"PENDING", "QUEUED", "IN_PROGRESS", "REQUESTED", "WAITING"}
FAILING_CONCLUSIONS = {"FAILURE", "TIMED_OUT", "CANCELLED", "ACTION_REQUIRED", "STALE", "ERROR"}


def _now_utc() -> str:
    return datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _run(args: list[str]) -> str:
    proc = subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or proc.stdout.strip() or f"command failed: {' '.join(args)}")
    return proc.stdout


def _load_yaml(path: Path) -> dict[str, Any]:
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"YAML file must parse to a mapping: {path}")
    return data


def _load_scope(path: Path) -> tuple[dict[str, Any], dict[str, Any]]:
    scope = _load_yaml(path)
    tracker = scope.get("tracker")
    if not isinstance(tracker, dict):
        raise ValueError("ProjectScope missing tracker mapping")
    return scope, tracker


def _json_key(field_name: str) -> str:
    return field_name[:1].lower() + field_name[1:]


def _field_keys(name: str) -> list[str]:
    camel = _json_key(name)
    compact = "".join(part[:1].upper() + part[1:] for part in name.split())
    lower_compact = compact[:1].lower() + compact[1:] if compact else ""
    return [key for key in [name, camel, lower_compact] if key]


def _field_value(item: dict[str, Any], *names: str) -> str:
    for name in names:
        for key in _field_keys(name):
            if key in item and item.get(key) is not None:
                return str(item.get(key) or "").strip()
    fields = item.get("fieldValues") or item.get("fields")
    if isinstance(fields, dict):
        for name in names:
            for key in _field_keys(name):
                if key in fields and fields.get(key) is not None:
                    return str(fields.get(key) or "").strip()
    return ""


def _content(item: dict[str, Any]) -> dict[str, Any]:
    content = item.get("content")
    return content if isinstance(content, dict) else {}


def _content_type(content: dict[str, Any]) -> str:
    return str(content.get("type") or content.get("__typename") or "").strip().lower()


def _candidate_pr_number(item: dict[str, Any]) -> int | None:
    content = _content(item)
    if _content_type(content) not in {"pullrequest", "pull request", "pr"}:
        return None
    number = content.get("number") or item.get("number")
    try:
        parsed = int(str(number))
    except (TypeError, ValueError):
        return None
    return parsed if parsed > 0 else None


def _content_summary(item: dict[str, Any]) -> dict[str, Any]:
    content = _content(item)
    return {
        "type": content.get("type") or content.get("__typename"),
        "number": content.get("number"),
        "title": content.get("title"),
        "url": content.get("url"),
    }


def _read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def _load_candidate_items(args: argparse.Namespace, tracker: dict[str, Any]) -> list[dict[str, Any]]:
    if args.candidate_json:
        data = json.loads(args.candidate_json)
    elif args.candidate_file:
        data = _read_json(Path(args.candidate_file))
    else:
        owner = str(tracker.get("owner") or "").strip()
        number = int(tracker.get("project_number") or 0)
        if not owner or number <= 0:
            raise ValueError("tracker owner and project_number are required for GitHub Project discovery")
        raw = _run(["gh", "project", "item-list", str(number), "--owner", owner, "--format", "json", "--limit", str(args.limit)])
        data = json.loads(raw)
    if isinstance(data, dict):
        items = data.get("items") or data.get("candidates")
    else:
        items = data
    if not isinstance(items, list):
        raise ValueError("candidate input must be a JSON list or object with items[]")
    return [item for item in items if isinstance(item, dict)]


def _discover_candidates(items: Iterable[dict[str, Any]], *, state_field: str, mirror_field: str) -> list[dict[str, Any]]:
    candidates: list[dict[str, Any]] = []
    for item in items:
        status = _field_value(item, mirror_field)
        dokkaebi_status = _field_value(item, state_field)
        pr_number = _candidate_pr_number(item)
        if pr_number is None:
            continue
        if status == "Merging" and dokkaebi_status == "Merging":
            candidates.append({
                "item": item,
                "itemId": str(item.get("id") or ""),
                "prNumber": pr_number,
                "status": status,
                "dokkaebiStatus": dokkaebi_status,
                "permissionLevel": _field_value(item, "Permission Level", "permissionLevel") or "unknown",
                "transitionRecord": _field_value(item, "Transition Record", "transitionRecord", "Approval Record"),
                "content": _content_summary(item),
            })
    return candidates


def _approval_module() -> Any:
    spec = importlib.util.spec_from_file_location("dokkaebi_approval_transition_check", APPROVAL_CHECKER)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"failed to load approval checker: {APPROVAL_CHECKER}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _approval_record_path(candidate: dict[str, Any], args: argparse.Namespace) -> Path | None:
    raw = args.transition_record or candidate.get("transitionRecord") or ""
    if not raw:
        return None
    path = Path(str(raw))
    if not path.is_absolute():
        path = ROOT / path
    return path.resolve()


def _validate_approval(candidate: dict[str, Any], args: argparse.Namespace, policy_path: Path) -> dict[str, Any]:
    record_path = _approval_record_path(candidate, args)
    if record_path is None:
        return {"ok": False, "status": "blocked", "reason": "missing human-origin transition record path"}
    try:
        record = _read_json(record_path)
        if not isinstance(record, dict):
            raise ValueError("transition record must be a JSON object")
        module = _approval_module()
        policy = module._load_policy(policy_path)  # reuse existing local checker boundary
        ok, reason, details = module.validate(record, policy)
    except Exception as exc:
        return {"ok": False, "status": "blocked", "reason": str(exc), "record": _display_path(record_path)}
    return {"ok": bool(ok), "status": "accepted" if ok else "blocked", "reason": reason, "record": _display_path(record_path), "details": details}


def _display_path(path: Path) -> str:
    try:
        return str(path.resolve().relative_to(ROOT))
    except ValueError:
        return str(path)


def _pr_view(number: int) -> dict[str, Any]:
    raw = _run([
        "gh", "pr", "view", str(number),
        "--json", "number,title,url,state,mergeable,isDraft,statusCheckRollup,files,headRefName,baseRefName",
    ])
    data = json.loads(raw)
    if not isinstance(data, dict):
        raise RuntimeError("gh pr view did not return a JSON object")
    return data


def _mergeable_ok(value: Any) -> tuple[bool, str]:
    text = str(value or "").strip().upper()
    if text in {"MERGEABLE", "CLEAN", "TRUE"}:
        return True, "mergeable"
    if text in {"CONFLICTING", "DIRTY", "FALSE"}:
        return False, f"PR mergeable={text.lower()}"
    return False, "PR mergeability is unavailable"


def _check_conclusion(check: dict[str, Any]) -> str:
    for key in ["conclusion", "state", "status"]:
        value = check.get(key)
        if value:
            return str(value).strip().upper()
    return "UNKNOWN"


def _checks_ok(rollup: Any) -> tuple[bool, str, list[dict[str, str]]]:
    if not isinstance(rollup, list) or not rollup:
        return False, "status checks unavailable", []
    observed: list[dict[str, str]] = []
    failures: list[str] = []
    pending: list[str] = []
    unknown: list[str] = []
    for check in rollup:
        if not isinstance(check, dict):
            unknown.append("non_object_check")
            continue
        name = str(check.get("name") or check.get("context") or check.get("workflowName") or check.get("__typename") or "unnamed")
        conclusion = _check_conclusion(check)
        observed.append({"name": name, "conclusion": conclusion})
        if conclusion in PASSING_CONCLUSIONS:
            continue
        if conclusion in PENDING_CONCLUSIONS:
            pending.append(name)
        elif conclusion in FAILING_CONCLUSIONS:
            failures.append(name)
        else:
            unknown.append(name)
    if failures:
        return False, "failing status checks: " + ", ".join(failures), observed
    if pending:
        return False, "pending status checks: " + ", ".join(pending), observed
    if unknown:
        return False, "unknown status check conclusions: " + ", ".join(unknown), observed
    return True, "all reported status checks passed", observed


def _files_permission_level(files: Any) -> str:
    if not isinstance(files, list):
        return "unknown"
    paths = [str(entry.get("path") or "") for entry in files if isinstance(entry, dict)]
    if not paths:
        return "unknown"
    docs_prefixes = ("docs/", "dokkaebi/approvals/")
    docs_names = {"README.md", "ARCHITECTURE.md", "WORKFLOW.md"}
    if all(path in docs_names or path.startswith(docs_prefixes) for path in paths):
        return "docs-only"
    provider_prefixes = ("ops/", "terraform/", "infra/", ".github/workflows/")
    if any(path.startswith(provider_prefixes) for path in paths):
        return "provider-change"
    return "local-code"


def _permission_ok(candidate_level: str, inferred_level: str) -> tuple[bool, str]:
    configured = candidate_level.strip() or "unknown"
    normalized = configured.lower()
    inferred = inferred_level.lower()
    if normalized in HUMAN_MANUAL_PERMISSION_LEVELS or inferred in HUMAN_MANUAL_PERMISSION_LEVELS:
        return False, f"permission level remains human/manual in v0: item={configured}, inferred={inferred_level}"
    if normalized in ELIGIBLE_PERMISSION_LEVELS or (normalized == "unknown" and inferred in ELIGIBLE_PERMISSION_LEVELS):
        return True, f"eligible permission level: item={configured}, inferred={inferred_level}"
    return False, f"permission level is not eligible for Merge Gate v0: item={configured}, inferred={inferred_level}"


def _evaluate_candidate(candidate: dict[str, Any], args: argparse.Namespace, policy_path: Path) -> dict[str, Any]:
    pr_number = int(candidate["prNumber"])
    result: dict[str, Any] = {
        "itemId": candidate.get("itemId"),
        "content": candidate.get("content"),
        "prNumber": pr_number,
        "status": candidate.get("status"),
        "dokkaebiStatus": candidate.get("dokkaebiStatus"),
        "permissionLevel": candidate.get("permissionLevel"),
        "state": "blocked",
        "recommendedStatus": "Blocked",
        "plannedTerminalState": None,
        "reasons": [],
    }

    approval = _validate_approval(candidate, args, policy_path)
    result["approval"] = approval
    if not approval["ok"]:
        result["reasons"].append(f"approval blocked: {approval['reason']}")

    try:
        pr = _pr_view(pr_number)
    except Exception as exc:
        result["reasons"].append(f"PR metadata unavailable: {exc}")
        result["recommendedStatus"] = "Blocked"
        return result
    result["pr"] = {
        "number": pr.get("number"),
        "title": pr.get("title"),
        "url": pr.get("url"),
        "state": pr.get("state"),
        "mergeable": pr.get("mergeable"),
        "isDraft": pr.get("isDraft"),
        "headRefName": pr.get("headRefName"),
        "baseRefName": pr.get("baseRefName"),
    }

    if str(pr.get("state") or "").upper() != "OPEN":
        result["reasons"].append("PR is not open")
    if bool(pr.get("isDraft")):
        result["reasons"].append("PR is draft")
    mergeable_ok, mergeable_reason = _mergeable_ok(pr.get("mergeable"))
    result["mergeability"] = {"ok": mergeable_ok, "reason": mergeable_reason}
    if not mergeable_ok:
        result["reasons"].append(mergeable_reason)

    checks_ok, checks_reason, checks = _checks_ok(pr.get("statusCheckRollup"))
    result["checks"] = {"ok": checks_ok, "reason": checks_reason, "items": checks}
    if not checks_ok:
        result["reasons"].append(checks_reason)
        result["recommendedStatus"] = "Fix Requested" if "failing" in checks_reason else "Blocked"

    inferred_level = _files_permission_level(pr.get("files"))
    permission_ok, permission_reason = _permission_ok(str(candidate.get("permissionLevel") or ""), inferred_level)
    result["permission"] = {"ok": permission_ok, "reason": permission_reason, "inferredFromFiles": inferred_level}
    if not permission_ok:
        result["reasons"].append(permission_reason)
        result["recommendedStatus"] = "Blocked"

    if not result["reasons"]:
        result["state"] = "ready"
        result["recommendedStatus"] = "Done"
        result["plannedTerminalState"] = "Done"
        result["plan"] = {
            "dryRun": not args.apply,
            "wouldMerge": bool(args.apply and args.merge),
            "mergeRequires": ["--apply", "--merge"],
            "postGateProjectStatus": "Done",
        }
    else:
        result["state"] = "blocked" if result["recommendedStatus"] == "Blocked" else "needs_review"
    return result


def _merge_pr(number: int) -> None:
    _run(["gh", "pr", "merge", str(number), "--merge", "--delete-branch=false"])


def _run_once(args: argparse.Namespace) -> dict[str, Any]:
    scope_path = Path(args.scope)
    policy_path = Path(args.policy)
    scope, tracker = _load_scope(scope_path)
    state_field = str(tracker.get("state_field") or "Dokkaebi Status").strip()
    mirror_field = str(tracker.get("human_status_mirror_field") or "Status").strip()
    payload: dict[str, Any] = {
        "ok": False,
        "schema_version": "dokkaebi.merge_gate_plan.v0",
        "mode": "apply" if args.apply else "dry-run",
        "mergeEnabled": bool(args.apply and args.merge),
        "checkedAt": _now_utc(),
        "scopeId": scope.get("id") or scope_path.stem,
        "stateField": state_field,
        "humanStatusMirrorField": mirror_field,
        "candidateSelector": {"status": "Merging", "dokkaebiStatus": "Merging", "contentType": "PullRequest"},
        "candidates": [],
        "actions": [],
        "findings": [],
    }

    if args.apply and KILL_SWITCH.exists():
        payload["findings"].append({"type": "kill_switch_present", "reason": f"refusing apply while {KILL_SWITCH.relative_to(ROOT)} exists"})
        return payload
    if args.merge and not args.apply:
        payload["findings"].append({"type": "merge_requires_apply", "reason": "--merge requires --apply"})
        return payload

    items = _load_candidate_items(args, tracker)
    candidates = _discover_candidates(items, state_field=state_field, mirror_field=mirror_field)
    payload["itemsChecked"] = len(items)
    payload["candidatesFound"] = len(candidates)

    for candidate in candidates:
        evaluation = _evaluate_candidate(candidate, args, policy_path)
        payload["candidates"].append(evaluation)
        if evaluation["state"] == "ready" and args.apply and args.merge:
            _merge_pr(int(evaluation["prNumber"]))
            payload["actions"].append({"type": "pr_merged", "prNumber": evaluation["prNumber"]})
        elif evaluation["state"] == "ready":
            payload["actions"].append({
                "type": "merge_gate_ready_plan",
                "prNumber": evaluation["prNumber"],
                "terminalState": "Done",
                "wouldMerge": False,
                "reason": "actual merge requires explicit --apply --merge",
            })

    blocked = [candidate for candidate in payload["candidates"] if candidate.get("state") != "ready"]
    payload["ok"] = not blocked and not payload["findings"]
    if blocked:
        payload["findings"].append({"type": "blocked_candidates", "count": len(blocked)})
    return payload


def main() -> int:
    parser = argparse.ArgumentParser(description="Plan or apply the local Dokkaebi Merge Gate v0")
    parser.add_argument("--scope", default=str(DEFAULT_SCOPE), help="ProjectScope YAML path")
    parser.add_argument("--policy", default=str(DEFAULT_POLICY), help="Dokkaebi policy YAML path")
    parser.add_argument("--candidate-file", help="JSON list/object of candidate Project items; avoids live GitHub discovery")
    parser.add_argument("--candidate-json", help="JSON list/object of candidate Project items; avoids live GitHub discovery")
    parser.add_argument("--transition-record", help="Human-origin transition record JSON path for bootstrap candidate validation")
    parser.add_argument("--limit", type=int, default=200, help="Project item discovery limit when using gh")
    parser.add_argument("--apply", action="store_true", help="Apply conservative v0 actions; default is dry-run only")
    parser.add_argument("--merge", action="store_true", help="Actually run gh pr merge; requires --apply and every gate to pass")
    parser.add_argument("--json", action="store_true", help="Emit JSON; retained for symmetry (JSON is always emitted)")
    args = parser.parse_args()

    try:
        payload = _run_once(args)
    except Exception as exc:
        payload = {"ok": False, "schema_version": "dokkaebi.merge_gate_plan.v0", "mode": "apply" if args.apply else "dry-run", "error": str(exc)}
    print(json.dumps(payload, indent=2, ensure_ascii=False, sort_keys=True))
    return 0 if payload.get("ok") else 2


if __name__ == "__main__":
    raise SystemExit(main())
