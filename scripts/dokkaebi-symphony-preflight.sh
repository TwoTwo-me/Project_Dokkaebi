#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW="$ROOT/dokkaebi/symphony/WORKFLOW.project-dokkaebi.md"
SCOPE="$ROOT/dokkaebi/project-scopes/project-dokkaebi.yml"
POLICY="$ROOT/dokkaebi/policies/project-dokkaebi.yml"
SYMPHONY_DIR="$ROOT/symphony-github-project-tracker"
SYMPHONY_ESCRIPT="$SYMPHONY_DIR/elixir/bin/symphony"
KILL_SWITCH="$ROOT/dokkaebi/KILL_SWITCH"
STRICT=0

if [[ "${1:-}" == "--strict" ]]; then
  STRICT=1
fi

ok=0
warn=0
block=0

status() {
  local level="$1"; shift
  printf '[%s] %s\n' "$level" "$*"
  case "$level" in
    OK) ok=$((ok + 1)) ;;
    WARN) warn=$((warn + 1)) ;;
    BLOCKED) block=$((block + 1)) ;;
  esac
}

has_write_project_scope() {
  local scopes_line="$1"
  local scope
  local trimmed
  IFS=',' read -ra scopes <<< "$scopes_line"
  for scope in "${scopes[@]}"; do
    trimmed="${scope#"${scope%%[![:space:]]*}"}"
    trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
    if [[ "$trimmed" == "project" ]]; then
      return 0
    fi
  done
  return 1
}

verify_github_graphql_token_scope() {
  if [[ -z "${GITHUB_GRAPHQL_TOKEN:-}" ]]; then
    return 3
  fi
  if ! command -v curl >/dev/null 2>&1; then
    return 4
  fi
  local headers
  local curl_config
  headers="$(mktemp)"
  curl_config="$(mktemp)"
  chmod 600 "$curl_config"
  {
    printf 'header = "Authorization: Bearer %s"\n' "$GITHUB_GRAPHQL_TOKEN"
    printf 'header = "Accept: application/vnd.github+json"\n'
    printf 'header = "X-GitHub-Api-Version: 2022-11-28"\n'
  } > "$curl_config"
  if ! curl -fsS -D "$headers" -o /dev/null \
      --config "$curl_config" \
      https://api.github.com/user >/tmp/dokkaebi-token-curl.out 2>/tmp/dokkaebi-token-curl.err; then
    rm -f "$headers" "$curl_config"
    return 5
  fi
  local scopes_line
  scopes_line="$(tr -d '\r' < "$headers" | awk -F': ' 'tolower($1) == "x-oauth-scopes" {print $2; exit}')"
  rm -f "$headers" "$curl_config"
  if [[ -z "$scopes_line" ]]; then
    return 6
  fi
  if has_write_project_scope "$scopes_line"; then
    return 0
  fi
  return 7
}

require_file() {
  local path="$1"
  if [[ -f "$path" ]]; then
    status OK "file exists: ${path#$ROOT/}"
  else
    status BLOCKED "missing file: ${path#$ROOT/}"
  fi
}

if [[ -e "$KILL_SWITCH" ]]; then
  if [[ -f "$KILL_SWITCH" ]]; then
    status BLOCKED "kill switch present: ${KILL_SWITCH#$ROOT/}"
  else
    status BLOCKED "kill switch path is ambiguous/non-file: ${KILL_SWITCH#$ROOT/}"
  fi
  printf '\nSummary: ok=%s warn=%s blocked=%s\n' "$ok" "$warn" "$block"
  exit 2
else
  status OK "kill switch absent: ${KILL_SWITCH#$ROOT/}"
fi

status OK "repo root: $ROOT"
require_file "$SCOPE"
require_file "$POLICY"
require_file "$WORKFLOW"
require_file "$SYMPHONY_DIR/elixir/lib/symphony_elixir/cli.ex"
require_file "$SYMPHONY_DIR/elixir/mix.exs"

if python3 - <<'PY' "$ROOT" "$SCOPE" "$POLICY" "$WORKFLOW" >/tmp/dokkaebi-symphony-preflight-yaml.out 2>/tmp/dokkaebi-symphony-preflight-yaml.err
from pathlib import Path
import sys, yaml
root = Path(sys.argv[1])
scope = yaml.safe_load(Path(sys.argv[2]).read_text())
policy = yaml.safe_load(Path(sys.argv[3]).read_text())
workflow_text = Path(sys.argv[4]).read_text()
front = workflow_text.split('---\n', 2)[1]
workflow = yaml.safe_load(front)
errors = []
scope_tracker = scope.get('tracker') or {}
workflow_tracker = workflow.get('tracker') or {}
assert scope['id'] == policy['project_scope_id']
assert workflow_tracker['kind'] == 'github-project'
comparisons = [
    ('project_id', scope_tracker.get('project_id'), workflow_tracker.get('project_id')),
    ('state_field', scope_tracker.get('state_field'), workflow_tracker.get('state_field')),
    ('human_status_mirror_field', scope_tracker.get('human_status_mirror_field'), workflow_tracker.get('human_status_mirror_field')),
    ('status_mirror_policy', scope_tracker.get('status_mirror_policy'), workflow_tracker.get('status_mirror_policy')),
    ('priority_field', scope_tracker.get('priority_field'), workflow_tracker.get('priority_field')),
    ('active_states', scope_tracker.get('active_states'), workflow_tracker.get('active_states')),
    ('wait_states', scope_tracker.get('wait_states'), workflow_tracker.get('wait_states')),
    ('terminal_states', scope_tracker.get('terminal_states'), workflow_tracker.get('terminal_states')),
    ('blocker_check_states', scope_tracker.get('blocker_check_states'), workflow_tracker.get('blocker_check_states')),
]
for name, expected, actual in comparisons:
    if expected != actual:
        errors.append(f'tracker.{name} mismatch: scope={expected!r} workflow={actual!r}')
if sorted(scope_tracker.get('admission_labels') or []) != sorted(workflow_tracker.get('whitelist_labels') or []):
    errors.append('tracker admission/whitelist labels mismatch')
token_env = scope_tracker.get('token_env')
if workflow_tracker.get('api_key') != f'${token_env}':
    errors.append('tracker.api_key does not match ProjectScope tracker.token_env')
codex_command = ((workflow.get('codex') or {}).get('command') or '')
if 'shell_environment_policy.inherit=all' in codex_command:
    errors.append('codex.command must not use shell_environment_policy.inherit=all')
if 'dokkaebi-codex-worker-app-server.sh' not in codex_command:
    errors.append('codex.command must use the Dokkaebi worker env scrubber')
if ((workflow.get('github_auth') or {}).get('scopes') or '') != 'project':
    errors.append('github_auth.scopes must be write-capable project, not read:project')
scope_transition_policy = scope_tracker.get('human_review_transition_policy') or {}
policy_transition_policy = policy.get('human_review_transition_policy') or {}
transition_policy = workflow_tracker.get('human_review_transition_policy') or {}
for required in ['trusted_provenance_verifiers', 'source_verification', 'approval_required_actions']:
    if required not in transition_policy:
        errors.append(f'tracker.human_review_transition_policy missing {required}')
if 'github_issue_close' not in (transition_policy.get('approval_required_actions') or []):
    errors.append('human_review_transition_policy must explicitly gate github_issue_close')
for name, expected, actual in [
    ('source_verification', (scope_transition_policy.get('source_verification') or {}), (transition_policy.get('source_verification') or {})),
    ('approval_action_aliases', (scope_transition_policy.get('approval_action_aliases') or {}), (transition_policy.get('approval_action_aliases') or {})),
    ('enabled_provenance_sources', (scope_transition_policy.get('enabled_provenance_sources') or []), (transition_policy.get('enabled_provenance_sources') or [])),
]:
    if expected != actual:
        errors.append(f'tracker.human_review_transition_policy.{name} mismatch: scope={expected!r} workflow={actual!r}')
if (policy_transition_policy.get('source_verification') or {}) != (transition_policy.get('source_verification') or {}):
    errors.append('policy/workflow source_verification mismatch')
if (policy_transition_policy.get('approval_action_aliases') or {}) != (transition_policy.get('approval_action_aliases') or {}):
    errors.append('policy/workflow approval_action_aliases mismatch')
if (policy_transition_policy.get('enabled_provenance_sources') or []) != (transition_policy.get('enabled_provenance_sources') or []):
    errors.append('policy/workflow enabled_provenance_sources mismatch')
for name in ['human_status_mirror_field', 'status_mirror_policy']:
    if policy_transition_policy.get(name) != scope_tracker.get(name) or policy_transition_policy.get(name) != workflow_tracker.get(name):
        errors.append(f'policy/scope/workflow {name} mismatch')
for name in ['status_sync']:
    if (scope_tracker.get(name) or {}) != (workflow_tracker.get(name) or {}):
        errors.append(f'tracker.{name} mismatch: scope={scope_tracker.get(name)!r} workflow={workflow_tracker.get(name)!r}')
    if (policy_transition_policy.get(name) or {}) != (scope_tracker.get(name) or {}):
        errors.append(f'policy/scope {name} mismatch: policy={policy_transition_policy.get(name)!r} scope={scope_tracker.get(name)!r}')
status_sync = scope_tracker.get('status_sync') or {}
if status_sync.get('mode') != 'bidirectional_observed':
    errors.append('tracker.status_sync.mode must be bidirectional_observed')
if status_sync.get('manager_preflight_auto_apply') is not True:
    errors.append('tracker.status_sync.manager_preflight_auto_apply must be true')
if status_sync.get('bootstrap_source') != 'block':
    errors.append('tracker.status_sync.bootstrap_source must fail closed with block')
if status_sync.get('terminal_approval_sync') != 'block_without_trusted_provenance':
    errors.append('tracker.status_sync.terminal_approval_sync must block without trusted provenance')
if status_sync.get('race_guard') != 'reread_before_mutation':
    errors.append('tracker.status_sync.race_guard must reread before mutation')
if status_sync.get('mutation_plan') != 'all_or_nothing_after_clean_validation':
    errors.append('tracker.status_sync.mutation_plan must be all_or_nothing_after_clean_validation')
if status_sync.get('audit_order') != 'append_event_before_state_snapshot':
    errors.append('tracker.status_sync.audit_order must append events before state snapshots')
if 'dokkaebi-project-status-sync.py --direction bidirectional --watch --apply --record-state' not in str(status_sync.get('watch_command') or ''):
    errors.append('tracker.status_sync.watch_command must run bidirectional apply watch with record-state')
wrapper = root / 'scripts' / 'dokkaebi-codex-worker-app-server.sh'
if not (wrapper.is_file() and wrapper.stat().st_mode & 0o111):
    errors.append('worker env scrubber is missing or not executable')
if 'DOKKAEBI_WORKER_REF' not in (workflow.get('hooks') or {}).get('after_create', ''):
    errors.append('after_create hook does not support explicit DOKKAEBI_WORKER_REF checkout')
if errors:
    raise AssertionError('; '.join(errors))
print(scope['id'], workflow_tracker.get('project_id'), workflow_tracker.get('state_field'))
PY
then
  status OK "YAML/front matter parses and ProjectScope/workflow wiring matches: $(cat /tmp/dokkaebi-symphony-preflight-yaml.out)"
else
  status BLOCKED "YAML/front matter validation failed: $(cat /tmp/dokkaebi-symphony-preflight-yaml.err)"
fi

if [[ -x "$SYMPHONY_ESCRIPT" ]]; then
  status OK "existing Symphony escript is built: ${SYMPHONY_ESCRIPT#$ROOT/}"
else
  status WARN "existing Symphony escript is not built yet: ${SYMPHONY_ESCRIPT#$ROOT/}"
fi

if command -v mix >/dev/null 2>&1; then
  status OK "Elixir mix available: $(command -v mix)"
elif command -v mise >/dev/null 2>&1 && (cd "$SYMPHONY_DIR/elixir" && mise exec -- mix --version >/tmp/dokkaebi-mix-version.out 2>&1); then
  status OK "Elixir mix available through mise: $(head -1 /tmp/dokkaebi-mix-version.out)"
else
  status WARN "Elixir mix not found; local escript build cannot run without installing Elixir/mise or using Docker/CI"
fi

if command -v mise >/dev/null 2>&1; then
  status OK "mise available: $(command -v mise)"
else
  status WARN "mise not found; use system Elixir, Docker, or install mise before following upstream local setup"
fi

if command -v docker >/dev/null 2>&1; then
  status OK "Docker available: $(docker --version 2>/dev/null || true)"
else
  status WARN "Docker not found; Docker Compose manager/worker fleet cannot run in this environment yet"
fi

workflow_project_id="$(python3 - <<'PY' "$WORKFLOW" 2>/dev/null || true
from pathlib import Path
import sys, yaml
text = Path(sys.argv[1]).read_text()
front = text.split('---\n', 2)[1]
print((yaml.safe_load(front).get('tracker') or {}).get('project_id') or '')
PY
)"
if [[ -n "$workflow_project_id" && "$workflow_project_id" != *"$"* ]]; then
  status OK "workflow tracker.project_id is concrete: $workflow_project_id"
else
  status BLOCKED "GitHub Project id is missing; fill tracker.project_id in the workflow"
fi

if [[ -n "${DOKKAEBI_WORKER_REF:-}" ]]; then
  case "$DOKKAEBI_WORKER_REF" in
    -*|*..*|*[!A-Za-z0-9._/@-]*)
      status BLOCKED "DOKKAEBI_WORKER_REF is unsafe; use a branch, SHA, refs/heads/*, or refs/pull/*/head"
      ;;
    *)
      status OK "DOKKAEBI_WORKER_REF is syntactically safe: $DOKKAEBI_WORKER_REF"
      ;;
  esac
fi

if GITHUB_GRAPHQL_TOKEN=sentinel GH_TOKEN=sentinel GITHUB_TOKEN=sentinel SSH_AUTH_SOCK=/tmp/dokkaebi-test-sock GIT_SSH_COMMAND='ssh -i ~/.ssh/id_rsa' SSH_ASKPASS=/tmp/askpass GIT_CONFIG_GLOBAL=/tmp/gitconfig DOKKAEBI_WORKER_GH_CONFIG_DIR="$HOME/.config/gh" AWS_SECRET_ACCESS_KEY=sentinel OPENAI_API_KEY=sentinel SYMPHONY_GITHUB_APP_ID=sentinel "$ROOT/scripts/dokkaebi-codex-worker-app-server.sh" --check-sanitizer >/tmp/dokkaebi-worker-env-sanitizer.out 2>/tmp/dokkaebi-worker-env-sanitizer.err; then
  status OK "$(cat /tmp/dokkaebi-worker-env-sanitizer.out)"
else
  status BLOCKED "worker env sanitizer failed: $(cat /tmp/dokkaebi-worker-env-sanitizer.err)"
fi

if [[ "${DOKKAEBI_WORKER_SANITIZED:-}" == "1" ]]; then
  status WARN "project mutation auth is intentionally unavailable in sanitized Worker context"
else
  if verify_github_graphql_token_scope; then
    status OK "GITHUB_GRAPHQL_TOKEN is the verified write-capable project runtime token"
  else
    token_rc=$?
    case "$token_rc" in
      3) status BLOCKED "GITHUB_GRAPHQL_TOKEN is missing; scripts/dokkaebi-symphony-run.sh can derive it from gh auth, or export a broker-verified token" ;;
      4) status BLOCKED "curl is missing; cannot verify the exact GITHUB_GRAPHQL_TOKEN used by Symphony" ;;
      5) status BLOCKED "GITHUB_GRAPHQL_TOKEN failed GitHub API verification" ;;
      6) status BLOCKED "GitHub API did not return OAuth scopes for GITHUB_GRAPHQL_TOKEN; use a classic OAuth/PAT token with project scope or a broker verifier" ;;
      7) status BLOCKED "GITHUB_GRAPHQL_TOKEN lacks write-capable project scope; read:project is insufficient for status mutation" ;;
      *) status BLOCKED "GITHUB_GRAPHQL_TOKEN scope verification failed with rc=$token_rc" ;;
    esac
  fi
fi

printf '\nSummary: ok=%s warn=%s blocked=%s\n' "$ok" "$warn" "$block"

if [[ "$STRICT" == "1" && "$block" -gt 0 ]]; then
  exit 2
fi
exit 0
