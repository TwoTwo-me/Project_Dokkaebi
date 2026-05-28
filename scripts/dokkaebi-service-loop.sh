#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KILL_SWITCH="$ROOT/dokkaebi/KILL_SWITCH"
RESTART_SECONDS="${DOKKAEBI_SERVICE_RESTART_SECONDS:-60}"
POLL_SECONDS="${DOKKAEBI_KILL_SWITCH_POLL_INTERVAL_SECONDS:-2}"

if [[ "$#" -lt 1 ]]; then
  echo "Usage: $0 <command> [args...]" >&2
  exit 64
fi

child_pid=""

kill_switch_present() {
  [[ -e "$KILL_SWITCH" ]]
}

terminate_child() {
  if [[ -n "$child_pid" ]] && kill -0 "$child_pid" 2>/dev/null; then
    kill "$child_pid" 2>/dev/null || true
    wait "$child_pid" 2>/dev/null || true
  fi
}

stop_cleanly_for_kill_switch() {
  if [[ -f "$KILL_SWITCH" ]]; then
    echo "Dokkaebi kill switch present: ${KILL_SWITCH#$ROOT/}" >&2
  else
    echo "Dokkaebi kill switch path is ambiguous/non-file: ${KILL_SWITCH#$ROOT/}" >&2
  fi
  terminate_child
  exit 0
}

trap 'terminate_child; exit 143' INT TERM HUP

while true; do
  if kill_switch_present; then
    stop_cleanly_for_kill_switch
  fi

  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] starting: $*" >&2
  "$@" &
  child_pid="$!"

  while kill -0 "$child_pid" 2>/dev/null; do
    if kill_switch_present; then
      stop_cleanly_for_kill_switch
    fi
    sleep "$POLL_SECONDS" &
    wait "$!" || true
  done

  set +e
  wait "$child_pid"
  rc="$?"
  set -e
  child_pid=""

  if kill_switch_present; then
    stop_cleanly_for_kill_switch
  fi

  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] command exited rc=$rc; restarting after ${RESTART_SECONDS}s" >&2
  sleep "$RESTART_SECONDS"
done
