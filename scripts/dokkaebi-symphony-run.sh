#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW="${DOKKAEBI_SYMPHONY_WORKFLOW:-$ROOT/dokkaebi/symphony/WORKFLOW.project-dokkaebi.md}"
SYMPHONY_DIR="$ROOT/symphony-github-project-tracker"
SYMPHONY_ESCRIPT="$SYMPHONY_DIR/elixir/bin/symphony"
LOGS_ROOT="${DOKKAEBI_SYMPHONY_LOGS_ROOT:-$ROOT/.omx/symphony/logs}"
PORT="${DOKKAEBI_SYMPHONY_PORT:-4000}"
ACK_FLAG="--i-understand-that-this-will-be-running-without-the-usual-guardrails"

"$ROOT/scripts/dokkaebi-symphony-preflight.sh" --strict

if [[ ! -x "$SYMPHONY_ESCRIPT" ]]; then
  if [[ "${DOKKAEBI_BUILD_SYMPHONY:-0}" == "1" ]]; then
    if command -v mix >/dev/null 2>&1; then
      (cd "$SYMPHONY_DIR/elixir" && mix setup && mix escript.build)
    elif command -v mise >/dev/null 2>&1; then
      (cd "$SYMPHONY_DIR/elixir" && mise exec -- mix setup && mise exec -- mix escript.build)
    else
      echo "DOKKAEBI_BUILD_SYMPHONY=1 was set, but neither mix nor mise is available" >&2
      exit 2
    fi
  else
    cat >&2 <<MSG
Symphony escript is not built at: $SYMPHONY_ESCRIPT

Build it first with one of:
  cd symphony-github-project-tracker/elixir && mix setup && mix escript.build
  cd symphony-github-project-tracker/elixir && mise exec -- mix setup && mise exec -- mix escript.build

Or set DOKKAEBI_BUILD_SYMPHONY=1 if system Elixir/mix is already installed.
MSG
    exit 2
  fi
fi

mkdir -p "$LOGS_ROOT"
if command -v escript >/dev/null 2>&1; then
  exec "$SYMPHONY_ESCRIPT" "$ACK_FLAG" --logs-root "$LOGS_ROOT" --port "$PORT" "$WORKFLOW"
elif command -v mise >/dev/null 2>&1; then
  cd "$SYMPHONY_DIR/elixir"
  exec mise exec -- "$SYMPHONY_ESCRIPT" "$ACK_FLAG" --logs-root "$LOGS_ROOT" --port "$PORT" "$WORKFLOW"
else
  echo "escript not found on PATH and mise is unavailable; cannot run Symphony escript" >&2
  exit 2
fi
