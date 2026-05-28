#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INTERVAL="${DOKKAEBI_STATUS_SYNC_INTERVAL_SECONDS:-10}"
exec python3 "$ROOT/scripts/dokkaebi-project-status-sync.py" \
  --direction bidirectional \
  --watch \
  --apply \
  --record-state \
  --interval-seconds "$INTERVAL" \
  "$@"
