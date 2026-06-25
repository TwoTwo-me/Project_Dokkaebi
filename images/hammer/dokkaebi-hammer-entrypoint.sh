#!/usr/bin/env bash
set -euo pipefail

export HOME="${HOME:-/home/dokkaebi}"
export CODEX_HOME="${CODEX_HOME:-/home/dokkaebi/.codex}"
export DOKKAEBI_LITELLM_BASE_URL="${DOKKAEBI_LITELLM_BASE_URL:-http://litellm.dokkaebi-llm.svc.cluster.local:4000}"

if [ -n "${DOKKAEBI_LITELLM_VIRTUAL_KEY:-}" ] || [ -n "${LITELLM_API_KEY:-}" ] || [ -s "$CODEX_HOME/litellm_api_key" ]; then
  /usr/local/bin/setup-codex-litellm-from-dokkaebi-key.sh
fi

exec "$@"
