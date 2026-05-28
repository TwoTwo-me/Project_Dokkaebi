#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INTERVAL="${DOKKAEBI_STATUS_SYNC_INTERVAL_SECONDS:-10}"
MIN_GRAPHQL_REMAINING="${DOKKAEBI_STATUS_SYNC_MIN_GRAPHQL_REMAINING:-50}"
RATE_LIMIT_CUSHION_SECONDS="${DOKKAEBI_STATUS_SYNC_RATE_LIMIT_CUSHION_SECONDS:-30}"

sleep_until_graphql_budget() {
  if ! command -v gh >/dev/null 2>&1; then
    return 0
  fi

  local remaining reset now sleep_for
  if ! read -r remaining reset < <(gh api rate_limit --jq '.resources.graphql | "\(.remaining) \(.reset)"' 2>/dev/null); then
    return 0
  fi
  if [[ -z "${remaining:-}" || -z "${reset:-}" ]]; then
    return 0
  fi
  if (( remaining >= MIN_GRAPHQL_REMAINING )); then
    return 0
  fi

  now="$(date +%s)"
  sleep_for=$(( reset - now + RATE_LIMIT_CUSHION_SECONDS ))
  if (( sleep_for < RATE_LIMIT_CUSHION_SECONDS )); then
    sleep_for="$RATE_LIMIT_CUSHION_SECONDS"
  fi
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] GitHub GraphQL budget low (${remaining}<${MIN_GRAPHQL_REMAINING}); sleeping ${sleep_for}s until reset" >&2
  sleep "$sleep_for"
}

while true; do
  sleep_until_graphql_budget
  tmp_err="$(mktemp)"
  set +e
  python3 "$ROOT/scripts/dokkaebi-project-status-sync.py" \
    --direction bidirectional \
    --watch \
    --apply \
    --record-state \
    --interval-seconds "$INTERVAL" \
    "$@" 2> >(tee "$tmp_err" >&2)
  rc="$?"
  set -e

  if (( rc == 0 )); then
    rm -f "$tmp_err"
    exit 0
  fi
  if grep -qiE 'rate limit|api rate limit|graphql.*limit' "$tmp_err"; then
    rm -f "$tmp_err"
    sleep_until_graphql_budget
    continue
  fi
  rm -f "$tmp_err"
  exit "$rc"
done
