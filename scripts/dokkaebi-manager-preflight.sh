#!/usr/bin/env bash
set -u

ok=0
warn=0
block=0
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KILL_SWITCH="$ROOT/dokkaebi/KILL_SWITCH"

status() {
  local level="$1"; shift
  printf '[%s] %s\n' "$level" "$*"
  case "$level" in
    OK) ok=$((ok + 1)) ;;
    WARN) warn=$((warn + 1)) ;;
    BLOCKED) block=$((block + 1)) ;;
  esac
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

has_write_project_scope() {
  local scopes_line="$1"
  local scope
  local trimmed
  # `gh auth status` emits a human line such as:
  #   Token scopes: 'gist', 'project', 'read:org', 'repo'
  # Keep the gate exact: quoted `project` is accepted, `read:project` is not.
  scopes_line="${scopes_line#*Token scopes:}"
  IFS=',' read -ra scopes <<< "$scopes_line"
  for scope in "${scopes[@]}"; do
    trimmed="${scope#"${scope%%[![:space:]]*}"}"
    trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
    trimmed="${trimmed//\'/}"
    trimmed="${trimmed//\"/}"
    if [[ "$trimmed" == "project" ]]; then
      return 0
    fi
  done
  return 1
}

if command -v hermes >/dev/null 2>&1; then
  status OK "Hermes command available: $(command -v hermes)"
  hermes status 2>&1 \
    | sed -E 's/(sk-[A-Za-z0-9_-]+)/sk-***REDACTED***/g; s/(gh[opsu]_[A-Za-z0-9_]+)/gh***REDACTED***/g; s/(eyJ[A-Za-z0-9._-]+)/<jwt-redacted>/g' \
    | sed -n '1,80p'
else
  status WARN "Hermes command not found; use Codex/OMX bootstrap Manager fallback"
fi

if command -v codex >/dev/null 2>&1; then
  status OK "Codex command available: $(codex --version 2>&1)"
else
  status BLOCKED "Codex command not found"
fi

CODEX_AUTH_PATH="${CODEX_HOME:-$HOME/.codex}/auth.json"
if [[ -f "$CODEX_AUTH_PATH" ]]; then
  status OK "Codex auth store exists at $CODEX_AUTH_PATH"
elif [[ "${DOKKAEBI_WORKER_SANITIZED:-}" == "1" ]]; then
  status WARN "Codex auth store is intentionally hidden from sanitized Worker HOME"
else
  status BLOCKED "Codex auth store missing; run codex login"
fi

if command -v gh >/dev/null 2>&1 && gh auth status -h github.com >/tmp/dokkaebi-manager-gh-auth.out 2>&1; then
  scopes_line="$(grep -E "Token scopes:" /tmp/dokkaebi-manager-gh-auth.out || true)"
  if has_write_project_scope "$scopes_line"; then
    status OK "gh token includes write-capable project scope"
    if python3 "$ROOT/scripts/dokkaebi-project-status-sync.py" --json >/tmp/dokkaebi-project-status-sync.out 2>/tmp/dokkaebi-project-status-sync.err; then
      status OK "GitHub Project Status mirrors Dokkaebi Status"
    else
      status BLOCKED "GitHub Project Status mirror drift detected; run scripts/dokkaebi-project-status-sync.py --apply --json"
    fi
  else
    status BLOCKED "gh token lacks write-capable project scope; read:project is insufficient for status mutation. Run: gh auth refresh -h github.com -s project"
  fi
elif [[ "${DOKKAEBI_WORKER_SANITIZED:-}" == "1" ]]; then
  status WARN "gh auth is intentionally unavailable in sanitized Worker context"
elif [[ -n "${GITHUB_GRAPHQL_TOKEN:-}" ]]; then
  status BLOCKED "GITHUB_GRAPHQL_TOKEN is set, but write-capable project scope cannot be verified without gh auth; use gh auth refresh -h github.com -s project or a brokered token verifier"
else
  status BLOCKED "gh auth status failed"
fi

printf '\nSummary: ok=%s warn=%s blocked=%s\n' "$ok" "$warn" "$block"
[[ "$block" -eq 0 ]]
