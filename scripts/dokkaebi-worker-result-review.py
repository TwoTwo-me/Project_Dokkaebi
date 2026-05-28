#!/usr/bin/env python3
"""Review a Dokkaebi Worker result packet and choose a safe Manager route.

This script is an ingestion/checkpoint helper for Symphony result surfaces. It
checks the packet shape, extracts coarse evidence signals, and emits a Manager
review recommendation that can route work to Human Review/Fix Requested/Blocked
without granting merge, deploy, GitHub issue close, or terminal closeout authority.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

REQUIRED_HEADINGS = [
    "Task identity",
    "Summary",
    "Changed artifacts",
    "Acceptance criteria evidence",
    "Validation evidence",
    "Blockers or missing permissions",
    "Residual risks",
    "Scope control",
    "Recommended Manager/Human next action",
]
FORBIDDEN_MANAGER_ACTIONS = [
    "merge_pr",
    "deploy_or_cutover",
    "github_issue_close",
    "issue_close_without_human_origin",
    "terminal_closeout_done",
    "human_review_to_merging_without_human_origin",
    "human_review_to_done_without_human_origin",
]


def _sections(markdown: str) -> dict[str, str]:
    matches = list(re.finditer(r"^##\s+(.+?)\s*$", markdown, re.MULTILINE))
    result: dict[str, str] = {}
    for idx, match in enumerate(matches):
        title = match.group(1).strip()
        start = match.end()
        end = matches[idx + 1].start() if idx + 1 < len(matches) else len(markdown)
        result[title] = markdown[start:end].strip()
    return result


def _clean_section_lines(text: str) -> list[str]:
    lines = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("```"):
            continue
        lines.append(line)
    return lines


def _section_has_real_none(text: str) -> bool:
    normalized = re.sub(r"[`*_<>]", "", text).lower()
    return bool(re.search(r"\b(none|n/a|no blockers|no missing permissions)\b", normalized))


def _section_contains_placeholder(text: str) -> bool:
    return "<" in text and ">" in text


def _has_failure_signal(text: str) -> bool:
    lowered = text.lower()
    return bool(re.search(r"\b(fail|failed|failing|blocked|partial|not run|skipped|missing)\b", lowered))


def _acceptance_statuses(section: str) -> list[str]:
    statuses: list[str] = []
    for line in section.splitlines():
        stripped = line.strip()
        if not stripped.startswith("|") or "---" in stripped or "Status" in stripped:
            continue
        cells = [cell.strip().strip("`*").lower() for cell in stripped.strip("|").split("|")]
        if len(cells) >= 3:
            statuses.append(cells[-1])
    return statuses


def review_packet(path: Path) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8")
    sections = _sections(text)
    missing = [heading for heading in REQUIRED_HEADINGS if heading not in sections]
    placeholder_sections = [heading for heading, body in sections.items() if heading in REQUIRED_HEADINGS and _section_contains_placeholder(body)]

    blockers = sections.get("Blockers or missing permissions", "")
    validation = sections.get("Validation evidence", "")
    acceptance = sections.get("Acceptance criteria evidence", "")
    scope = sections.get("Scope control", "")
    completion = sections.get("Task identity", "")

    statuses = _acceptance_statuses(acceptance)
    acceptance_bad = [status for status in statuses if status not in {"pass", "passed", "ok", "complete", "completed"}]
    explicit_blocker = bool(blockers.strip()) and not _section_has_real_none(blockers)
    validation_has_failure = _has_failure_signal(validation)
    completion_has_blocked = _has_failure_signal(completion)
    scope_has_gate = "Human approval gates reached" in scope and not _section_has_real_none(scope)

    findings: list[str] = []
    if missing:
        findings.append("missing required result-packet sections: " + ", ".join(missing))
    if placeholder_sections:
        findings.append("placeholder content remains in sections: " + ", ".join(sorted(placeholder_sections)))
    if acceptance_bad:
        findings.append("acceptance criteria include non-pass statuses: " + ", ".join(acceptance_bad))
    if explicit_blocker:
        findings.append("blockers or missing permissions are present")
    if validation_has_failure:
        findings.append("validation evidence contains failure/blocked/skipped signals")
    if completion_has_blocked:
        findings.append("task identity completion status indicates blocked/failed/partial")

    if missing or placeholder_sections:
        recommended_status = "Blocked"
        recommended_action = "request complete result packet evidence before Manager review"
    elif explicit_blocker or completion_has_blocked:
        recommended_status = "Blocked"
        recommended_action = "ask Human/Manager to resolve the blocker or missing permission"
    elif acceptance_bad or validation_has_failure:
        recommended_status = "Fix Requested"
        recommended_action = "return to Worker with scoped fix/validation requirements"
    else:
        recommended_status = "Human Review"
        recommended_action = "summarize evidence for Human review; do not merge, deploy, close GitHub issues, or close terminally"

    return {
        "ok": recommended_status in {"Human Review", "Fix Requested", "Blocked"},
        "packet": str(path),
        "recommended_status": recommended_status,
        "recommended_action": recommended_action,
        "allowed_manager_actions": [
            "move_to_human_review" if recommended_status == "Human Review" else "set_status_" + recommended_status.lower().replace(" ", "_"),
            "post_manager_review_summary",
            "create_followup_ticket_if_needed",
        ],
        "forbidden_manager_actions": FORBIDDEN_MANAGER_ACTIONS,
        "human_approval_required_before": [
            "merge",
            "deploy",
            "GitHub issue close",
            "terminal Done closeout",
            "Human Review -> Merging",
            "Human Review -> Done",
        ],
        "signals": {
            "missing_sections": missing,
            "placeholder_sections": sorted(placeholder_sections),
            "acceptance_statuses": statuses,
            "acceptance_bad_statuses": acceptance_bad,
            "explicit_blocker": explicit_blocker,
            "validation_has_failure_signal": validation_has_failure,
            "completion_has_blocked_signal": completion_has_blocked,
            "scope_mentions_human_gate": scope_has_gate,
        },
        "findings": findings,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Review a Dokkaebi Worker result packet")
    parser.add_argument("packet", help="Worker result packet markdown path")
    parser.add_argument("--json", action="store_true", help="Emit JSON")
    args = parser.parse_args()

    try:
        result = review_packet(Path(args.packet))
    except Exception as exc:
        result = {
            "ok": False,
            "packet": args.packet,
            "recommended_status": "Blocked",
            "recommended_action": "fix unreadable result packet before Manager review",
            "forbidden_manager_actions": FORBIDDEN_MANAGER_ACTIONS,
            "findings": [str(exc)],
        }

    if args.json:
        print(json.dumps(result, indent=2, ensure_ascii=False))
    else:
        print(f"[{result['recommended_status']}] {result['recommended_action']}")
        for finding in result.get("findings", []):
            print(f"- {finding}")
    # A readable but blocked/fix-requested review is still a successful Manager review.
    return 0 if result.get("ok") else 2


if __name__ == "__main__":
    raise SystemExit(main())
