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
  headers="$(mktemp)"
  if ! curl -fsS -D "$headers" -o /dev/null \
      -H "Authorization: Bearer ${GITHUB_GRAPHQL_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      https://api.github.com/user >/tmp/dokkaebi-token-curl.out 2>/tmp/dokkaebi-token-curl.err; then
    rm -f "$headers"
    return 5
  fi
  local scopes_line
  scopes_line="$(tr -d '\r' < "$headers" | awk -F': ' 'tolower($1) == "x-oauth-scopes" {print $2; exit}')"
  rm -f "$headers"
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

status OK "repo root: $ROOT"
require_file "$SCOPE"
require_file "$POLICY"
require_file "$WORKFLOW"
require_file "$SYMPHONY_DIR/elixir/lib/symphony_elixir/cli.ex"
require_file "$SYMPHONY_DIR/elixir/mix.exs"

if [[ -e "$KILL_SWITCH" ]]; then
  if [[ -f "$KILL_SWITCH" ]]; then
    status BLOCKED "kill switch present: ${KILL_SWITCH#$ROOT/}"
  else
    status BLOCKED "kill switch path is ambiguous/non-file: ${KILL_SWITCH#$ROOT/}"
  fi
else
  status OK "kill switch absent: ${KILL_SWITCH#$ROOT/}"
fi

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
transition_policy = workflow_tracker.get('human_review_transition_policy') or {}
for required in ['trusted_provenance_verifiers', 'source_verification', 'approval_required_actions']:
    if required not in transition_policy:
        errors.append(f'tracker.human_review_transition_policy missing {required}')
if 'github_issue_close' not in (transition_policy.get('approval_required_actions') or []):
    errors.append('human_review_transition_policy must explicitly gate github_issue_close')
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
