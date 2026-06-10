#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}

require_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "missing file: $path"
}

require_text() {
  local path="$1"
  local needle="$2"
  grep -Fq -- "$needle" "$path" || fail "missing text in $path: $needle"
}

require_file docs/policies/git-governance.md
require_file .github/pull_request_template.md
require_file .github/workflows/dokkaebi-governance.yml

require_text docs/policies/git-governance.md '## GitHub Flow'
require_text docs/policies/git-governance.md '## Branch naming'
require_text docs/policies/git-governance.md '## Commit policy'
require_text docs/policies/git-governance.md '## Pull request requirements'
require_text docs/policies/git-governance.md '## Submodule policy'

require_text .github/pull_request_template.md '## Goal'
require_text .github/pull_request_template.md '## Non-goals'
require_text .github/pull_request_template.md '## Changed artifacts'
require_text .github/pull_request_template.md '## Decision rationale'
require_text .github/pull_request_template.md 'Context:'
require_text .github/pull_request_template.md 'Decision:'
require_text .github/pull_request_template.md 'Why:'
require_text .github/pull_request_template.md '## Validation'
require_text .github/pull_request_template.md '## Risks'
require_text .github/pull_request_template.md '## Approval gates'
require_text .github/pull_request_template.md '## Public metadata hygiene'
require_text .github/pull_request_template.md '## Git status'

require_text .github/workflows/dokkaebi-governance.yml 'bash scripts/validate-contract-docs.sh'
require_text .github/workflows/dokkaebi-governance.yml 'bash scripts/validate-git-governance.sh'
require_text .github/workflows/dokkaebi-governance.yml 'pull_request:'

python3 - <<'PY'
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

BRANCH_RE = re.compile(
    r"^(feat|feature|fix|docs|test|refactor|chore|infra|experiment)/[a-z0-9]+(-[a-z0-9]+)*$"
)

REQUIRED_PR_HEADINGS = [
    "## Goal",
    "## Non-goals",
    "## Changed artifacts",
    "## Decision rationale",
    "## Validation",
    "## Risks",
    "## Approval gates",
    "## Public metadata hygiene",
    "## Git status",
]

REQUIRED_COMMIT_MARKERS = [
    "Context:",
    "Decision:",
    "Validation:",
    "Risks:",
]
CONSTRAINT_COMMIT_MARKERS = [
    "Constraint:",
    "Tested:",
    "Not-tested:",
]
CONSTRAINT_REASON_MARKERS = [
    "Decision:",
    "Rejected:",
    "Why:",
]

BANNED_SUBJECTS = {"wip", "fix stuff", "updates", "changes", "misc", "final"}
RESTRICTED_PUBLIC_METADATA_PATTERNS = [
    re.compile(r"(?<![A-Za-z0-9])" + re.escape(bytes([111, 109, 111]).decode()) + r"(?![A-Za-z0-9])"),
    re.compile(r"(?<![A-Za-z0-9])" + re.escape(bytes([111, 109, 120]).decode()) + r"(?![A-Za-z0-9])"),
    re.compile(re.escape(bytes([99, 111, 100, 101, 120, 47]).decode())),
]
PRIVATE_PATH_PATTERNS = [
    re.compile(r"(?<![A-Za-z0-9_])/(?:home|Users)/[^\s`'\"<>]+"),
    re.compile(r"[A-Za-z]:\\\\Users\\\\[^\s`'\"<>]+"),
]


def run(args: list[str]) -> str:
    return subprocess.check_output(args, text=True, stderr=subprocess.STDOUT).strip()


def section_has_content(body: str, heading: str) -> bool:
    marker = re.search(rf"^{re.escape(heading)}\s*$", body, re.MULTILINE)
    if marker is None:
        return False
    rest = body[marker.end() :]
    next_heading = re.search(r"^##\s+", rest, re.MULTILINE)
    section = rest[: next_heading.start()] if next_heading else rest
    for raw_line in section.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        if line.startswith("<!--") or line.endswith("-->"):
            continue
        if line in {"```", "```text", "N/A", "n/a"}:
            continue
        if line.startswith("- [ ]"):
            continue
        return True
    return False


def metadata_errors(label: str, value: str) -> list[str]:
    lowered = value.lower()
    found: list[str] = []
    for pattern in RESTRICTED_PUBLIC_METADATA_PATTERNS:
        if pattern.search(lowered):
            found.append(f"{label} contains restricted public metadata")
            break
    for pattern in PRIVATE_PATH_PATTERNS:
        if pattern.search(value):
            found.append(f"{label} contains a private local path")
            break
    return found


def commit_has_required_evidence(message: str) -> bool:
    has_context_style = (
        all(marker in message for marker in REQUIRED_COMMIT_MARKERS[:3])
        and ("Risk:" in message or "Risks:" in message)
    )
    has_constraint_style = (
        all(marker in message for marker in CONSTRAINT_COMMIT_MARKERS)
        and any(marker in message for marker in CONSTRAINT_REASON_MARKERS)
    )
    return has_context_style or has_constraint_style


errors: list[str] = []

branch = os.environ.get("HEAD_REF") or os.environ.get("GITHUB_HEAD_REF") or os.environ.get("BRANCH_NAME")
if not branch:
    try:
        branch = run(["git", "branch", "--show-current"])
    except subprocess.CalledProcessError:
        branch = ""
if branch and branch != "main" and not BRANCH_RE.match(branch):
    errors.append(
        "branch name must match <type>/<scope-slug>: "
        + branch
    )
if branch and branch != "main":
    errors.extend(metadata_errors("branch name", branch))

event_path = os.environ.get("GITHUB_EVENT_PATH")
event: dict[str, object] = {}
if event_path and Path(event_path).exists():
    event = json.loads(Path(event_path).read_text(encoding="utf-8"))

pull_request = event.get("pull_request") if isinstance(event.get("pull_request"), dict) else None
if pull_request is not None:
    body = str(pull_request.get("body") or "")
    title = str(pull_request.get("title") or "")
    errors.extend(metadata_errors("pull request title", title))
    errors.extend(metadata_errors("pull request body", body))
    for heading in REQUIRED_PR_HEADINGS:
        if not section_has_content(body, heading):
            errors.append(f"pull request body must fill section: {heading}")

    if "Context:" not in body or "Decision:" not in body or "Why:" not in body:
        errors.append("pull request body must include Context:, Decision:, and Why: under Decision rationale")

    base_sha = os.environ.get("BASE_SHA") or str(pull_request.get("base", {}).get("sha", ""))
    head_sha = os.environ.get("HEAD_SHA") or str(pull_request.get("head", {}).get("sha", ""))
    if base_sha and head_sha:
        try:
            merge_base = run(["git", "merge-base", base_sha, head_sha])
        except subprocess.CalledProcessError:
            merge_base = base_sha

        try:
            changed_paths = run(["git", "diff", "--name-only", f"{merge_base}..{head_sha}"]).splitlines()
        except subprocess.CalledProcessError as exc:
            errors.append("could not inspect changed paths: " + exc.output.strip())
            changed_paths = []

        if "symphony-github-project-tracker" in changed_paths:
            for needle in [
                "git submodule status",
                "git -C symphony-github-project-tracker status --short --branch",
            ]:
                if needle not in body:
                    errors.append(f"submodule PR body must include: {needle}")

        try:
            commits = run(["git", "rev-list", "--reverse", "--no-merges", f"{merge_base}..{head_sha}"]).splitlines()
        except subprocess.CalledProcessError as exc:
            errors.append("could not inspect commit list: " + exc.output.strip())
            commits = []

        for sha in commits:
            message = run(["git", "show", "-s", "--format=%B", sha])
            subject = message.splitlines()[0].strip() if message.splitlines() else ""
            if not subject:
                errors.append(f"{sha}: commit subject is empty")
                continue
            if subject.lower() in BANNED_SUBJECTS:
                errors.append(f"{sha}: banned vague commit subject: {subject}")
            if len(subject) > 72:
                errors.append(f"{sha}: commit subject exceeds 72 chars")
            errors.extend(metadata_errors(f"{sha}: commit message", message))
            if not commit_has_required_evidence(message):
                errors.append(
                    f"{sha}: commit message must include either Context/Decision/Validation/Risk(s) or Constraint/(Decision|Rejected|Why)/Tested/Not-tested evidence"
                )

if errors:
    for error in errors:
        print("FAIL " + error, file=sys.stderr)
    sys.exit(1)

print("PASS Dokkaebi Git governance checks passed")
PY
