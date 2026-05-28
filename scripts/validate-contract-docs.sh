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
require_file docs/policies/authority-and-safety.md
require_file docs/adapters/hermes.md
require_file docs/templates/worker-ticket.md
require_file docs/templates/worker-result-packet.md
require_file docs/runbooks/dokkaebi-runtime-bootstrap.md
require_file README.md
require_file scripts/dokkaebi-approval-transition-check.py
require_file scripts/dokkaebi-worker-result-review.py
require_file scripts/dokkaebi-project-status-sync.py

require_text ARCHITECTURE.md '# Project Dokkaebi Architecture'
require_text ARCHITECTURE.md 'Dokkaebi Manager'
require_text ARCHITECTURE.md 'Credential broker'
require_text ARCHITECTURE.md 'Trust boundaries'
require_text ARCHITECTURE.md 'Critical risks'
require_text ARCHITECTURE.md 'human-origin approval provenance'
require_text ARCHITECTURE.md 'Manager-authored transitions to `Merging` or `Done` are'
require_text ARCHITECTURE.md 'GitHub issue close'
require_text ARCHITECTURE.md 'Repeat dispatch'

require_text WORKFLOW.md '# Project Dokkaebi Workflow'
require_text WORKFLOW.md '## Phase 1: Manager intake'
require_text WORKFLOW.md '## Phase 3: Approval and readiness gate'
require_text WORKFLOW.md '## Status model'
require_text WORKFLOW.md '## Status transition provenance'
require_text WORKFLOW.md '| Reopened |'
require_text WORKFLOW.md 'Human Review` → `Merging`'
require_text WORKFLOW.md 'Human Review` → `Done`'
require_text WORKFLOW.md 'Unknown, untrusted, or ambiguous provenance fails closed'
require_text WORKFLOW.md 'GitHub issue closeout is also terminal closeout'
require_text WORKFLOW.md 'trusted provenance verifier'
require_text WORKFLOW.md 'human-visible GitHub Project `Status` field'
require_text WORKFLOW.md 'scripts/dokkaebi-project-status-sync.py --apply'
require_text WORKFLOW.md 'dokkaebi/KILL_SWITCH'

require_text docs/contracts/manager-contract.md '# Dokkaebi Manager Contract'
require_text docs/contracts/manager-contract.md '## Fail-closed preflight'
require_text docs/contracts/manager-contract.md '## Credential broker boundary'
require_text docs/contracts/manager-contract.md '## Symphony compatibility'
require_text docs/contracts/manager-contract.md '## Adapter conformance'
require_text docs/contracts/manager-contract.md '### GitHub Project status approval surface'
require_text docs/contracts/manager-contract.md '../policies/authority-and-safety.md'
require_text docs/contracts/manager-contract.md '../adapters/hermes.md'
require_text docs/contracts/manager-contract.md 'A Worker result packet must include:'
require_text docs/contracts/manager-contract.md 'planned result-packet or Manager-review surface'
require_text docs/contracts/manager-contract.md 'closeout evidence'
require_text docs/contracts/manager-contract.md 'acceptance-criteria evidence'
require_text docs/contracts/manager-contract.md 'scope-control statement'
require_text docs/contracts/manager-contract.md 'approval-gate status'
require_text docs/contracts/manager-contract.md 'Manager self-approval'
require_text docs/contracts/manager-contract.md 'Terminal status transitions out of `Human Review` and GitHub issue closeout'
require_text docs/contracts/manager-contract.md 'GitHub issue closeout'
require_text docs/contracts/manager-contract.md 'trusted provenance verifier'
require_text docs/contracts/manager-contract.md 'SHA-256 hash'
require_text docs/contracts/manager-contract.md 'Caller-supplied'
require_text docs/contracts/manager-contract.md 'scripts/dokkaebi-approval-transition-check.py'
require_text docs/contracts/manager-contract.md 'scripts/dokkaebi-worker-result-review.py'
require_text docs/contracts/manager-contract.md 'scripts/dokkaebi-project-status-sync.py'
require_no_text docs/contracts/manager-contract.md 'A Worker result packet should include:'
require_no_text docs/contracts/manager-contract.md 'result-review link. Missing approval evidence blocks dispatch.'

require_text docs/policies/authority-and-safety.md '# Dokkaebi Authority and Safety Policy'
require_text docs/policies/authority-and-safety.md '## Human approval required'
require_text docs/policies/authority-and-safety.md '## Human-origin terminal approvals'
require_text docs/policies/authority-and-safety.md '## Approval evidence record'
require_text docs/policies/authority-and-safety.md '## Fail-closed preflight'
require_text docs/policies/authority-and-safety.md '## Credential broker boundary'
require_text docs/policies/authority-and-safety.md '## Symphony compatibility policy'
require_text docs/policies/authority-and-safety.md 'planned result-packet or Manager-review surface'
require_text docs/policies/authority-and-safety.md 'required at closeout'
require_text docs/policies/authority-and-safety.md 'control-plane writes'
require_text docs/policies/authority-and-safety.md 'approved setup authority'
require_text docs/policies/authority-and-safety.md 'Manager-authored terminal'
require_text docs/policies/authority-and-safety.md 'untrusted, or contradictory provenance fails closed'
require_text docs/policies/authority-and-safety.md 'caller-supplied'
require_text docs/policies/authority-and-safety.md 'GitHub issue close'
require_text docs/policies/authority-and-safety.md 'source-specific evidence file'
require_text docs/policies/authority-and-safety.md 'repeat-dispatch hazard'
require_text docs/policies/authority-and-safety.md 'human-visible GitHub Project `Status` field is a strict mirror'
require_no_text docs/policies/authority-and-safety.md 'link to the resulting Worker result packet or Manager review'

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
require_text docs/templates/worker-ticket.md '## Validation requirements'
require_text docs/templates/worker-ticket.md '## Expected result packet'
require_text docs/templates/worker-ticket.md '[`worker-result-packet.md`](worker-result-packet.md)'
require_text docs/templates/worker-ticket.md '../policies/authority-and-safety.md'
require_text docs/templates/worker-ticket.md 'acceptance-criteria evidence'
require_text docs/templates/worker-ticket.md 'whether acceptance criteria were met'
require_text docs/templates/worker-ticket.md 'scope-control statement'
require_text docs/templates/worker-ticket.md 'approval-gate status'
require_text docs/templates/worker-ticket.md 'terminal approval requires human-origin provenance'
require_text docs/templates/worker-ticket.md 'GitHub issue closeout'
require_text docs/templates/worker-ticket.md 'trusted provenance verifier'

require_text docs/templates/worker-result-packet.md '# Worker Result Packet Template'
require_text docs/templates/worker-result-packet.md 'scripts/dokkaebi-worker-result-review.py'
require_text docs/templates/worker-result-packet.md '## Task identity'
require_text docs/templates/worker-result-packet.md '## Changed artifacts'
require_text docs/templates/worker-result-packet.md '## Acceptance criteria evidence'
require_text docs/templates/worker-result-packet.md '## Validation evidence'
require_text docs/templates/worker-result-packet.md '## Blockers or missing permissions'
require_text docs/templates/worker-result-packet.md '## Residual risks'
require_text docs/templates/worker-result-packet.md '## Scope control'
require_text docs/templates/worker-result-packet.md 'Human approval gates reached'
require_text docs/templates/worker-result-packet.md 'GitHub issue close'
require_text docs/templates/worker-result-packet.md '## Recommended Manager/Human next action'

require_text docs/runbooks/dokkaebi-runtime-bootstrap.md '## 6. Human Review terminal approval gate'
require_text docs/runbooks/dokkaebi-runtime-bootstrap.md 'scripts/dokkaebi-approval-transition-check.py'
require_text docs/runbooks/dokkaebi-runtime-bootstrap.md '## 7. Worker result ingestion and Manager review'
require_text docs/runbooks/dokkaebi-runtime-bootstrap.md 'scripts/dokkaebi-worker-result-review.py'
require_text docs/runbooks/dokkaebi-runtime-bootstrap.md 'dokkaebi/KILL_SWITCH'
require_text docs/runbooks/dokkaebi-runtime-bootstrap.md 'unattended poll loop'
require_text docs/runbooks/dokkaebi-runtime-bootstrap.md 'exact `GITHUB_GRAPHQL_TOKEN`'
require_text docs/runbooks/dokkaebi-runtime-bootstrap.md 'SHA-256 hash'

require_text README.md 'ARCHITECTURE.md'
require_text README.md 'WORKFLOW.md'
require_text README.md 'docs/adr/0001-hermes-first-manager-contract.md'
require_text README.md 'docs/contracts/manager-contract.md'
require_text README.md 'docs/deep-interview-project-dokkaebi.md'
require_text README.md 'docs/policies/authority-and-safety.md'
require_text README.md 'docs/adapters/hermes.md'
require_text README.md 'docs/templates/worker-ticket.md'
require_text README.md 'docs/templates/worker-result-packet.md'
require_text README.md 'human-origin'

python3 - <<'PY'
from pathlib import Path
import re
import sys

scope = [
    Path('README.md'),
    Path('ARCHITECTURE.md'),
    Path('WORKFLOW.md'),
    Path('docs/contracts/manager-contract.md'),
    Path('docs/policies/authority-and-safety.md'),
    Path('docs/adapters/hermes.md'),
    Path('docs/templates/worker-ticket.md'),
    Path('docs/templates/worker-result-packet.md'),
    Path('docs/runbooks/dokkaebi-runtime-bootstrap.md'),
]

errors = []
for path in scope:
    text = path.read_text()
    for target in re.findall(r'\[[^\]]+\]\(([^)]+)\)', text):
        if '://' in target or target.startswith('#') or target.startswith('mailto:'):
            continue
        local = target.split('#', 1)[0]
        if not local:
            continue
        if not (path.parent / local).exists():
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
policy_yaml = Path('dokkaebi/policies/project-dokkaebi.yml').read_text()
scope_yaml = Path('dokkaebi/project-scopes/project-dokkaebi.yml').read_text()
workflow_contract = Path('dokkaebi/symphony/WORKFLOW.project-dokkaebi.md').read_text()
approval_checker = Path('scripts/dokkaebi-approval-transition-check.py')
if not approval_checker.exists():
    errors.append('approval transition checker script missing')
elif not (approval_checker.stat().st_mode & 0o111):
    errors.append('approval transition checker script is not executable')
result_reviewer = Path('scripts/dokkaebi-worker-result-review.py')
if not result_reviewer.exists():
    errors.append('worker result review script missing')
elif not (result_reviewer.stat().st_mode & 0o111):
    errors.append('worker result review script is not executable')
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

for path in [Path('ARCHITECTURE.md'), Path('WORKFLOW.md'), Path('docs/templates/worker-ticket.md')]:
    if 'later policy' in path.read_text() or 'later approved policy' in path.read_text():
        errors.append(f'approval exception wording should say later ADR: {path}')

for path in [Path('docs/contracts/manager-contract.md'), Path('docs/policies/authority-and-safety.md')]:
    text = path.read_text()
    if 'should issue' in text:
        errors.append(f'credential broker requirement is weak in {path}')
    if 'should include' in text:
        errors.append(f'result packet requirement is weak in {path}')

for doc_name, doc_text in [
    ('policy yaml', policy_yaml),
    ('project scope yaml', scope_yaml),
    ('symphony workflow', workflow_contract),
]:
    for term in [
        'human_review_transition_policy',
        'Human Review',
        'human_status_mirror_field',
        'status_mirror_policy',
        'Merging',
        'Done',
        'required_origin: human',
        'manager_self_approval: forbidden',
        'unknown_or_ambiguous_provenance: fail_closed',
        'trusted_provenance_verifiers',
        'source_verification',
        'enabled_provenance_sources',
        'durable_human_approval_record',
        'github_issue_close',
        'approval_action_aliases',
        'repo.pr.merge',
        'deploy_or_cutover',
    ]:
        if term not in doc_text:
            errors.append(f'{doc_name} missing human-origin transition invariant: {term}')

for doc_name, doc_text in [
    ('policy yaml', policy_yaml),
    ('symphony workflow', workflow_contract),
]:
    for term in [
        'approved_action',
        'provenance_record_id',
        'provenance_checked_by',
        'provenance_verification_method',
        'provenance_evidence_file',
        'provenance_evidence_sha256',
    ]:
        if term not in doc_text:
            errors.append(f'{doc_name} missing provenance evidence field: {term}')

if 'scopes: project' not in workflow_contract:
    errors.append('symphony workflow must require write-capable github_auth scope: project')
if 'read:project' in workflow_contract:
    errors.append('symphony workflow must not request read-only read:project for mutating runtime')

if errors:
    for error in errors:
        print('FAIL ' + error, file=sys.stderr)
    sys.exit(1)
PY

printf 'PASS Dokkaebi contract docs are present, linked, and structurally aligned\n'
