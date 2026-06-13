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
require_file docs/enterprise-readiness/criteria.json
require_file docs/enterprise-readiness/development-loop.md
require_file docs/reports/company-readiness-assessment.md
require_file docs/operations/worker-cli-auth.md

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
require_text docs/contracts/manager-contract.md '../policies/authority-and-safety.md'
require_text docs/contracts/manager-contract.md '../policies/git-governance.md'
require_text docs/contracts/manager-contract.md '../adapters/hermes.md'
require_text docs/contracts/manager-contract.md 'hammer-worker-contract.md'
require_text docs/contracts/manager-contract.md 'A Worker result packet must include:'
require_text docs/contracts/manager-contract.md 'planned result-packet or Manager-review surface'
require_text docs/contracts/manager-contract.md 'closeout evidence'
require_text docs/contracts/manager-contract.md 'acceptance-criteria evidence'
require_text docs/contracts/manager-contract.md 'scope-control statement'
require_text docs/contracts/manager-contract.md 'approval-gate status'
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

printf 'PASS Dokkaebi contract docs are present, linked, and structurally aligned\n'
