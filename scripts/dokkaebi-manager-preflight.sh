#!/usr/bin/env bash
set -u

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
  if [[ "$scopes_line" == *"project"* || "$scopes_line" == *"read:project"* ]]; then
    status OK "gh token includes project scope"
  else
    status BLOCKED "gh token lacks project scope; run: gh auth refresh -h github.com -s project"
  fi
elif [[ "${DOKKAEBI_WORKER_SANITIZED:-}" == "1" ]]; then
  status WARN "gh auth is intentionally unavailable in sanitized Worker context"
else
  status BLOCKED "gh auth status failed"
fi

printf '\nSummary: ok=%s warn=%s blocked=%s\n' "$ok" "$warn" "$block"
[[ "$block" -eq 0 ]]
