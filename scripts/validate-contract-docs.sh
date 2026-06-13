#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    printf 'FAIL missing file: %s\n' "$path" >&2
    return 1
  fi
}

require_text() {
  local path="$1"
  local needle="$2"
  if ! grep -Fq -- "$needle" "$path"; then
    printf 'FAIL missing text in %s: %s\n' "$path" "$needle" >&2
    return 1
  fi
}

require_no_text() {
  local path="$1"
  local needle="$2"
  if grep -Fq -- "$needle" "$path"; then
    printf 'FAIL forbidden text in %s: %s\n' "$path" "$needle" >&2
    return 1
  fi
}

require_file ARCHITECTURE.md
require_file WORKFLOW.md
require_file docs/contracts/manager-contract.md
require_file docs/contracts/hammer-worker-contract.md
require_file docs/policies/authority-and-safety.md
require_file docs/policies/git-governance.md
require_file docs/adapters/hermes.md
require_file docs/templates/worker-ticket.md
require_file docs/templates/worker-result-packet.md
require_file README.md
require_file .github/pull_request_template.md
require_file .github/workflows/dokkaebi-governance.yml
require_file scripts/validate-git-governance.sh
require_file scripts/validate-dokkaebi-plugin.sh
require_file scripts/validate-readiness-criteria.sh
require_file scripts/validate-dispatch-lease-recovery.sh
require_file docs/enterprise-readiness/criteria.json
require_file docs/enterprise-readiness/development-loop.md
require_file docs/reports/company-readiness-assessment.md
require_file docs/operations/worker-cli-auth.md
require_file docs/operations/dispatch-lease-recovery.md
require_file docs/examples/result-packets/accepted.md
require_file docs/examples/result-packets/rejected-missing-acceptance-evidence.md
require_file docs/examples/result-packets/rejected-missing-validation-evidence.md
require_file docs/examples/result-packets/rejected-missing-scope-control.md
require_file docs/examples/result-packets/rejected-missing-approval-status.md
require_file docs/examples/replays/accepted-manager-fire-hammer.md
require_file docs/examples/replays/rejected-missing-dispatch-readiness.md
require_file docs/examples/replays/rejected-missing-approval-evidence.md
require_file docs/examples/replays/rejected-missing-worker-route-result-metadata.md
require_file docs/examples/replays/rejected-missing-closeout-review-evidence.md

require_text ARCHITECTURE.md '# Project Dokkaebi Architecture'
require_text ARCHITECTURE.md 'Dokkaebi Manager'
require_text ARCHITECTURE.md 'Credential broker'
require_text ARCHITECTURE.md 'Trust boundaries'
require_text ARCHITECTURE.md 'Critical risks'

require_text WORKFLOW.md '# Project Dokkaebi Workflow'
require_text WORKFLOW.md '## Phase 1: Manager intake'
require_text WORKFLOW.md '## Phase 3: Approval and readiness gate'
require_text WORKFLOW.md '## Status model'
require_text WORKFLOW.md '| Reopened |'

require_text docs/contracts/manager-contract.md '# Dokkaebi Manager Contract'
require_text docs/contracts/manager-contract.md '## Fail-closed preflight'
require_text docs/contracts/manager-contract.md '## Credential broker boundary'
require_text docs/contracts/manager-contract.md '## Symphony compatibility'
require_text docs/contracts/manager-contract.md '## Adapter conformance'
require_text docs/contracts/manager-contract.md '### Adapter conformance proof'
require_text docs/contracts/manager-contract.md '../examples/result-packets/accepted.md'
require_text docs/contracts/manager-contract.md '../examples/result-packets/rejected-missing-acceptance-evidence.md'
require_text docs/contracts/manager-contract.md '../examples/result-packets/rejected-missing-validation-evidence.md'
require_text docs/contracts/manager-contract.md '../examples/result-packets/rejected-missing-scope-control.md'
require_text docs/contracts/manager-contract.md '../examples/result-packets/rejected-missing-approval-status.md'
require_text docs/contracts/manager-contract.md '../examples/replays/accepted-manager-fire-hammer.md'
require_text docs/contracts/manager-contract.md '../examples/replays/rejected-missing-dispatch-readiness.md'
require_text docs/contracts/manager-contract.md '../examples/replays/rejected-missing-approval-evidence.md'
require_text docs/contracts/manager-contract.md '../examples/replays/rejected-missing-worker-route-result-metadata.md'
require_text docs/contracts/manager-contract.md '../examples/replays/rejected-missing-closeout-review-evidence.md'
require_text docs/contracts/manager-contract.md '../policies/authority-and-safety.md'
require_text docs/contracts/manager-contract.md '../policies/git-governance.md'
require_text docs/contracts/manager-contract.md '../operations/dispatch-lease-recovery.md'
require_text docs/contracts/manager-contract.md '../adapters/hermes.md'
require_text docs/contracts/manager-contract.md 'hammer-worker-contract.md'
require_text docs/contracts/manager-contract.md 'A Worker result packet must include:'
require_text docs/contracts/manager-contract.md 'planned result-packet or Manager-review surface'
require_text docs/contracts/manager-contract.md 'closeout evidence'
require_text docs/contracts/manager-contract.md 'acceptance-criteria evidence'
require_text docs/contracts/manager-contract.md 'scope-control statement'
require_text docs/contracts/manager-contract.md 'approval-gate status'
require_text docs/contracts/manager-contract.md 'Manager-Fire-Hammer replay suite'
require_text docs/contracts/manager-contract.md 'dispatch readiness'
require_text docs/contracts/manager-contract.md 'Worker route metadata'
require_text docs/contracts/manager-contract.md 'durable lease and restart recovery contract'
require_text docs/contracts/manager-contract.md 'no duplicate dispatch after restart'
require_no_text docs/contracts/manager-contract.md 'A Worker result packet should include:'
require_no_text docs/contracts/manager-contract.md 'result-review link. Missing approval evidence blocks dispatch.'

require_text docs/contracts/hammer-worker-contract.md '# Dokkaebi Hammer Worker Contract'
require_text docs/contracts/hammer-worker-contract.md 'local_worktree'
require_text docs/contracts/hammer-worker-contract.md 'ssh'
require_text docs/contracts/hammer-worker-contract.md 'docker'
require_text docs/contracts/hammer-worker-contract.md 'kubernetes_job'
require_text docs/contracts/hammer-worker-contract.md 'capabilities'
require_text docs/contracts/hammer-worker-contract.md 'isolation'
require_text docs/contracts/hammer-worker-contract.md 'credential_mode'
require_text docs/contracts/hammer-worker-contract.md 'cleanup'
require_text docs/contracts/hammer-worker-contract.md 'Manager PATs, OAuth tokens'
require_text docs/contracts/hammer-worker-contract.md 'isolated live smoke'

require_text docs/policies/authority-and-safety.md '# Dokkaebi Authority and Safety Policy'
require_text docs/policies/authority-and-safety.md '## Human approval required'
require_text docs/policies/authority-and-safety.md '## Approval evidence record'
require_text docs/policies/authority-and-safety.md '## Fail-closed preflight'
require_text docs/policies/authority-and-safety.md '## Credential broker boundary'
require_text docs/policies/authority-and-safety.md '## Symphony compatibility policy'
require_text docs/policies/authority-and-safety.md 'planned result-packet or Manager-review surface'
require_text docs/policies/authority-and-safety.md 'required at closeout'
require_text docs/policies/authority-and-safety.md 'control-plane writes'
require_text docs/policies/authority-and-safety.md 'approved setup authority'
require_text docs/policies/authority-and-safety.md '## Git governance boundary'
require_text docs/policies/authority-and-safety.md '[`git-governance.md`](git-governance.md)'
require_no_text docs/policies/authority-and-safety.md 'link to the resulting Worker result packet or Manager review'

require_text docs/policies/git-governance.md '# Dokkaebi Git Governance Policy'
require_text docs/policies/git-governance.md '## Enforcement surfaces'
require_text docs/policies/git-governance.md '## GitHub Flow'
require_text docs/policies/git-governance.md '`main` is the only long-lived integration branch'
require_text docs/policies/git-governance.md 'short-lived branches'
require_text docs/policies/git-governance.md 'PR merge requires explicit Human approval'
require_text docs/policies/git-governance.md '## Branch naming'
require_text docs/policies/git-governance.md '<type>/<scope-slug>'
require_no_text docs/policies/git-governance.md '<actor>/<type>/<scope-slug>'
require_text docs/policies/git-governance.md '## Commit policy'
require_text docs/policies/git-governance.md 'Commit messages must preserve the development process and decision rationale'
require_text docs/policies/git-governance.md 'Context:'
require_text docs/policies/git-governance.md 'Decision:'
require_text docs/policies/git-governance.md 'Why:'
require_text docs/policies/git-governance.md 'Validation:'
require_text docs/policies/git-governance.md 'Risks:'
require_text docs/policies/git-governance.md '## Pull request requirements'
require_text docs/policies/git-governance.md '## Submodule policy'
require_text docs/policies/git-governance.md 'Submodule commits must be created inside the submodule first'
require_text docs/policies/git-governance.md 'A root gitlink update must cite the submodule path and target commit sha'
require_text docs/policies/git-governance.md 'Public metadata hygiene'

require_text .github/pull_request_template.md '# Dokkaebi Pull Request'
require_text .github/pull_request_template.md '## Decision rationale'
require_text .github/pull_request_template.md 'Context:'
require_text .github/pull_request_template.md 'Decision:'
require_text .github/pull_request_template.md 'Why:'
require_text .github/pull_request_template.md '## Public metadata hygiene'
require_text .github/pull_request_template.md '## Git status'

require_text .github/workflows/dokkaebi-governance.yml 'name: Dokkaebi governance'
require_text .github/workflows/dokkaebi-governance.yml 'contract-docs'
require_text .github/workflows/dokkaebi-governance.yml 'git-governance'
require_text .github/workflows/dokkaebi-governance.yml 'bash scripts/validate-contract-docs.sh'
require_text .github/workflows/dokkaebi-governance.yml 'bash scripts/validate-git-governance.sh'
require_text .github/workflows/dokkaebi-governance.yml 'bash scripts/validate-dokkaebi-plugin.sh'
require_text .github/workflows/dokkaebi-governance.yml 'bash scripts/validate-readiness-criteria.sh'

require_text scripts/validate-git-governance.sh 'PASS Dokkaebi Git governance checks passed'
require_text scripts/validate-git-governance.sh 'Context:'
require_text scripts/validate-git-governance.sh 'Decision:'
require_text scripts/validate-git-governance.sh 'Why:'
require_text scripts/validate-git-governance.sh 'Validation:'
require_text scripts/validate-git-governance.sh 'Risks:'
require_text scripts/validate-dokkaebi-plugin.sh 'PASS Dokkaebi plugin packaging checks passed'
require_text scripts/validate-readiness-criteria.sh 'PASS Dokkaebi enterprise readiness criteria are present and structurally valid'
require_text scripts/validate-dispatch-lease-recovery.sh 'PASS Dokkaebi dispatch lease recovery validation passed'

require_text docs/operations/dispatch-lease-recovery.md '# Dispatch Lease And Restart Recovery'
require_text docs/operations/dispatch-lease-recovery.md 'lease store'
require_text docs/operations/dispatch-lease-recovery.md 'owner identity'
require_text docs/operations/dispatch-lease-recovery.md 'retry persistence'
require_text docs/operations/dispatch-lease-recovery.md 'recovery behavior'
require_text docs/operations/dispatch-lease-recovery.md 'no duplicate dispatch after restart'
require_text docs/operations/dispatch-lease-recovery.md 'live GitHub Project residual risks'
require_text docs/operations/dispatch-lease-recovery.md 'lease_token'
require_text docs/operations/dispatch-lease-recovery.md 'idempotency_key'
require_text docs/operations/dispatch-lease-recovery.md 'stale lease'

require_text docs/adapters/hermes.md '# Hermes Manager Adapter'
require_text docs/adapters/hermes.md '## Approval and preflight handling'
require_text docs/adapters/hermes.md '## Symphony integration expectations'
require_text docs/adapters/hermes.md '## Adapter conformance matrix'
require_text docs/adapters/hermes.md 'approved setup authority'

require_text docs/templates/worker-ticket.md '# Worker Ticket Template'
require_text docs/templates/worker-ticket.md '## Goal'
require_text docs/templates/worker-ticket.md '## Acceptance criteria'
require_text docs/templates/worker-ticket.md '## Permission level'
require_text docs/templates/worker-ticket.md '## Human approval gates'
require_text docs/templates/worker-ticket.md '## Git plan'
require_text docs/templates/worker-ticket.md '## Validation requirements'
require_text docs/templates/worker-ticket.md '## Expected result packet'
require_text docs/templates/worker-ticket.md '[`worker-result-packet.md`](worker-result-packet.md)'
require_text docs/templates/worker-ticket.md '../policies/authority-and-safety.md'
require_text docs/templates/worker-ticket.md '../policies/git-governance.md'
require_text docs/templates/worker-ticket.md 'acceptance-criteria evidence'
require_text docs/templates/worker-ticket.md 'whether acceptance criteria were met'
require_text docs/templates/worker-ticket.md 'scope-control statement'
require_text docs/templates/worker-ticket.md 'approval-gate status'

require_text docs/templates/worker-result-packet.md '# Worker Result Packet Template'
require_text docs/templates/worker-result-packet.md '## Task identity'
require_text docs/templates/worker-result-packet.md '## Changed artifacts'
require_text docs/templates/worker-result-packet.md '**Commit rationale:**'
require_text docs/templates/worker-result-packet.md '## Acceptance criteria evidence'
require_text docs/templates/worker-result-packet.md '## Validation evidence'
require_text docs/templates/worker-result-packet.md '## Blockers or missing permissions'
require_text docs/templates/worker-result-packet.md '## Residual risks'
require_text docs/templates/worker-result-packet.md '## Scope control'
require_text docs/templates/worker-result-packet.md 'Human approval gates reached'
require_text docs/templates/worker-result-packet.md '## Recommended Manager/Human next action'

require_text README.md 'ARCHITECTURE.md'
require_text README.md 'WORKFLOW.md'
require_text README.md 'docs/adr/0001-hermes-first-manager-contract.md'
require_text README.md 'docs/contracts/manager-contract.md'
require_text README.md 'docs/contracts/hammer-worker-contract.md'
require_text README.md 'docs/deep-interview-project-dokkaebi.md'
require_text README.md 'docs/policies/authority-and-safety.md'
require_text README.md 'docs/policies/git-governance.md'
require_text README.md 'docs/enterprise-readiness/criteria.json'
require_text README.md 'docs/enterprise-readiness/development-loop.md'
require_text README.md 'docs/adapters/hermes.md'
require_text README.md 'docs/templates/worker-ticket.md'
require_text README.md 'docs/templates/worker-result-packet.md'
require_text README.md '## Quickstart'
require_text README.md 'tracker.projects'
require_text README.md 'kubernetes_job'

python3 - <<'PY'
from pathlib import Path
import re
import subprocess
import sys

scope = [
    Path('README.md'),
    Path('ARCHITECTURE.md'),
    Path('WORKFLOW.md'),
    Path('docs/contracts/manager-contract.md'),
    Path('docs/contracts/hammer-worker-contract.md'),
    Path('docs/policies/authority-and-safety.md'),
    Path('docs/policies/git-governance.md'),
    Path('docs/adapters/hermes.md'),
    Path('docs/templates/worker-ticket.md'),
    Path('docs/templates/worker-result-packet.md'),
]

def is_unchecked_submodule_link(target: str) -> bool:
    parts = Path(target).parts
    if not parts:
        return False
    root = parts[0]
    if Path(root, '.git').exists():
        return False
    try:
        output = subprocess.check_output(
            ['git', 'ls-files', '--stage', '--', root],
            text=True,
            stderr=subprocess.DEVNULL,
        )
    except subprocess.CalledProcessError:
        return False
    return output.startswith('160000 ')

errors = []
for path in scope:
    text = path.read_text()
    for target in re.findall(r'\[[^\]]+\]\(([^)]+)\)', text):
        if '://' in target or target.startswith('#') or target.startswith('mailto:'):
            continue
        local = target.split('#', 1)[0]
        if not local:
            continue
        resolved = path.parent / local
        if not resolved.exists() and not is_unchecked_submodule_link(str(resolved)):
            errors.append(f'missing markdown link target: {path} -> {target}')

workflow = Path('WORKFLOW.md').read_text()
ticket = Path('docs/templates/worker-ticket.md').read_text()

for term in ['Intake', 'Clarifying', 'Ready', 'Dispatchable', 'In Progress',
             'Needs Review', 'Human Review', 'Fix Requested', 'Merging', 'Done',
             'Blocked', 'Failed', 'Cancelled', 'Reopened']:
    if term not in workflow:
        errors.append(f'workflow missing status term: {term}')
    if term not in ticket:
        errors.append(f'worker ticket missing status term: {term}')

contract = Path('docs/contracts/manager-contract.md').read_text()
architecture = Path('ARCHITECTURE.md').read_text()
result = Path('docs/templates/worker-result-packet.md').read_text()
for doc_name, doc_text in [
    ('manager contract', contract),
    ('architecture result flow', architecture),
    ('workflow result packet', workflow),
    ('worker ticket expected result packet', ticket),
]:
    for term in ['acceptance-criteria evidence', 'validation commands',
                 'scope-control', 'approval-gate status',
                 'whether acceptance criteria were met']:
        if term not in doc_text:
            errors.append(f'{doc_name} result packet minimum missing: {term}')
for heading in ['## Acceptance criteria evidence', '## Validation evidence',
                '## Scope control', 'Human approval gates reached']:
    if heading not in result:
        errors.append(f'result packet template missing: {heading}')

def markdown_section(text: str, heading: str) -> str | None:
    marker = re.search(rf'^{re.escape(heading)}\s*$', text, re.MULTILINE)
    if marker is None:
        return None
    rest = text[marker.end():]
    next_heading = re.search(r'^##\s+', rest, re.MULTILINE)
    return rest[: next_heading.start()] if next_heading else rest


def validate_result_packet_fixture(path: Path) -> list[str]:
    text = path.read_text()
    found: list[str] = []
    for heading in [
        '## Task identity',
        '## Changed artifacts',
        '## Acceptance criteria evidence',
        '## Validation evidence',
        '## Blockers or missing permissions',
        '## Residual risks',
        '## Scope control',
        '## Recommended Manager/Human next action',
    ]:
        if heading not in text:
            found.append(f'missing required section: {heading}')

    acceptance = markdown_section(text, '## Acceptance criteria evidence')
    if acceptance is not None:
        if '| Criterion | Evidence | Status |' not in acceptance:
            found.append('missing acceptance evidence table')
        if re.search(r'\|\s*(pass|fail|blocked)\s*\|', acceptance, re.IGNORECASE) is None:
            found.append('missing acceptance status')

    validation = markdown_section(text, '## Validation evidence')
    if validation is not None:
        if '```text' not in validation:
            found.append('missing validation command block')
        if 'PASS ' not in validation and 'FAIL ' not in validation:
            found.append('missing validation command outcome')

    scope = markdown_section(text, '## Scope control')
    if scope is not None:
        if '**Stayed within ticket scope:**' not in scope:
            found.append('missing scope-control statement')
        if '**Scope deviations:**' not in scope:
            found.append('missing scope deviation statement')
        if '**Human approval gates reached:**' not in scope:
            found.append('missing approval-gate status')

    return found


def validate_replay_fixture(path: Path) -> list[str]:
    text = path.read_text()
    found: list[str] = []
    required_sections = [
        '## Replay identity',
        '## Manager intake',
        '## Approval gate state',
        '## Fire dispatch readiness',
        '## Hammer work result',
        '## Manager review and closeout',
        '## Replay decision',
    ]
    for heading in required_sections:
        if heading not in text:
            found.append(f'missing required section: {heading}')

    replay_identity = markdown_section(text, '## Replay identity')
    if replay_identity is not None:
        for field in ['**Replay ID:**', '**Contract version:**', '**Source ticket:**',
                      '**Expected replay result:**']:
            if field not in replay_identity:
                found.append(f'missing replay identity field: {field}')

    manager_intake = markdown_section(text, '## Manager intake')
    if manager_intake is not None:
        for field in ['**Source request preserved:** yes', '**Goal:**',
                      '**Acceptance criteria:**', '**Permission level:**',
                      '**Result packet surface:**']:
            if field not in manager_intake:
                found.append(f'missing manager intake field: {field}')

    approval = markdown_section(text, '## Approval gate state')
    if approval is not None:
        for field in ['**Approval evidence:**', '**PR merge approval:**',
                      '**Credential/infrastructure/deployment gates:**',
                      '**Worker authority:**']:
            if field not in approval:
                found.append(f'missing approval gate field: {field}')

    dispatch = markdown_section(text, '## Fire dispatch readiness')
    if dispatch is not None:
        for field in ['**Semantic status:** Dispatchable',
                      '**Project source of truth:** GitHub Project Status',
                      '**Ticket link:**', '**Route metadata:**',
                      '**Admission check:**']:
            if field not in dispatch:
                found.append(f'missing dispatch readiness field: {field}')

    hammer = markdown_section(text, '## Hammer work result')
    if hammer is not None:
        for field in ['**Worker route metadata:**', '**Result packet:**',
                      '**Acceptance criteria evidence:**',
                      '**Validation evidence:**', '**Scope control:**',
                      '**Approval-gate status:**']:
            if field not in hammer:
                found.append(f'missing hammer result field: {field}')

    closeout = markdown_section(text, '## Manager review and closeout')
    if closeout is not None:
        for field in ['**Review decision:**', '**Closeout evidence:**',
                      '**Residual risk:**', '**Next state:**']:
            if field not in closeout:
                found.append(f'missing manager closeout field: {field}')

    replay_decision = markdown_section(text, '## Replay decision')
    if replay_decision is not None:
        for field in ['**Expected replay result:**', '**Reason:**']:
            if field not in replay_decision:
                found.append(f'missing replay decision field: {field}')

    return found


accepted_packet = Path('docs/examples/result-packets/accepted.md')
accepted_errors = validate_result_packet_fixture(accepted_packet)
if accepted_errors:
    errors.append(
        f'{accepted_packet} should pass result-packet validation: '
        + '; '.join(accepted_errors)
    )

rejected_packets = {
    Path('docs/examples/result-packets/rejected-missing-acceptance-evidence.md'):
        'missing required section: ## Acceptance criteria evidence',
    Path('docs/examples/result-packets/rejected-missing-validation-evidence.md'):
        'missing required section: ## Validation evidence',
    Path('docs/examples/result-packets/rejected-missing-scope-control.md'):
        'missing required section: ## Scope control',
    Path('docs/examples/result-packets/rejected-missing-approval-status.md'):
        'missing approval-gate status',
}
for packet, expected_error in rejected_packets.items():
    fixture_errors = validate_result_packet_fixture(packet)
    if expected_error not in fixture_errors:
        errors.append(
            f'{packet} did not fail for expected reason: {expected_error}; '
            + 'actual: '
            + ('; '.join(fixture_errors) if fixture_errors else 'no validation errors')
        )

accepted_replay = Path('docs/examples/replays/accepted-manager-fire-hammer.md')
accepted_replay_errors = validate_replay_fixture(accepted_replay)
if accepted_replay_errors:
    errors.append(
        f'{accepted_replay} should pass replay validation: '
        + '; '.join(accepted_replay_errors)
    )

rejected_replays = {
    Path('docs/examples/replays/rejected-missing-dispatch-readiness.md'):
        'missing required section: ## Fire dispatch readiness',
    Path('docs/examples/replays/rejected-missing-approval-evidence.md'):
        'missing approval gate field: **Approval evidence:**',
    Path('docs/examples/replays/rejected-missing-worker-route-result-metadata.md'):
        'missing hammer result field: **Worker route metadata:**',
    Path('docs/examples/replays/rejected-missing-closeout-review-evidence.md'):
        'missing required section: ## Manager review and closeout',
}
for replay, expected_error in rejected_replays.items():
    fixture_errors = validate_replay_fixture(replay)
    if expected_error not in fixture_errors:
        errors.append(
            f'{replay} did not fail for expected reason: {expected_error}; '
            + 'actual: '
            + ('; '.join(fixture_errors) if fixture_errors else 'no validation errors')
        )

for path in [Path('ARCHITECTURE.md'), Path('WORKFLOW.md'), Path('docs/templates/worker-ticket.md')]:
    if 'later policy' in path.read_text() or 'later approved policy' in path.read_text():
        errors.append(f'approval exception wording should say later ADR: {path}')

for path in [Path('docs/contracts/manager-contract.md'), Path('docs/policies/authority-and-safety.md')]:
    text = path.read_text()
    if 'should issue' in text:
        errors.append(f'credential broker requirement is weak in {path}')
    if 'should include' in text:
        errors.append(f'result packet requirement is weak in {path}')

if errors:
    for error in errors:
        print('FAIL ' + error, file=sys.stderr)
    sys.exit(1)
PY

bash scripts/validate-readiness-criteria.sh >/dev/null
bash scripts/validate-dispatch-lease-recovery.sh >/dev/null

printf 'PASS Dokkaebi contract docs are present, linked, and structurally aligned\n'
