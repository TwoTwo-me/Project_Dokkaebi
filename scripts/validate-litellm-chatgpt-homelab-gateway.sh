#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}

require_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "missing file: $path"
}

require_text() {
  local path="$1"
  local needle="$2"
  grep -Fq -- "$needle" "$path" || fail "missing text in $path: $needle"
}

DOC="docs/operations/litellm-chatgpt-homelab-gateway.md"
SMOKE_DOC="docs/operations/litellm-chatgpt-k8s-smoke-2026-06-18.md"
SMOKE_SCRIPT="scripts/run-litellm-chatgpt-k8s-smoke.sh"

require_file "$DOC"
require_file "$SMOKE_DOC"
require_file "$SMOKE_SCRIPT"
require_text "$DOC" "optional homelab pattern"
require_text "$DOC" "It is not a Dokkaebi product requirement."
require_text "$DOC" "ChatGPT OAuth tokens must stay in the LiteLLM Gateway boundary."
require_text "$DOC" "Hammer jobs receive only a short-lived LiteLLM virtual key"
require_text "$DOC" "NetworkPolicy allows Hammer egress to the LiteLLM Gateway"
require_text "$DOC" "Practical Verification"
require_text "$DOC" "Generate a task-scoped LiteLLM virtual key"
require_text "$DOC" "Confirm LiteLLM records the request in spend/log views"
require_text "$DOC" "Block or delete the virtual key"
require_text "$DOC" 'Do not put `CHATGPT_TOKEN_DIR`, `CHATGPT_AUTH_FILE`, ChatGPT OAuth contents, or'
require_text "$DOC" "Dokkaebi should document this as an optional operating recipe, not a platform"
require_text "$DOC" "production use requires an approved enterprise credential strategy"
require_text "$DOC" "must live in the LiteLLM key/log/result-packet layer"
require_text "$DOC" "bash scripts/run-litellm-chatgpt-k8s-smoke.sh"
require_text "$DOC" "reach the OAuth device-flow gate"

require_text "$SMOKE_DOC" "chatgpt_provider_config_loaded=yes"
require_text "$SMOKE_DOC" "chatgpt_provider_requires_device_flow=yes"
require_text "$SMOKE_DOC" "virtual_key_generated=yes"
require_text "$SMOKE_DOC" "models_status=200"
require_text "$SMOKE_DOC" "no_auth_models_status=401"
require_text "$SMOKE_DOC" "gateway_provider_call=blocked_by_fake_provider_key"
require_text "$SMOKE_DOC" "virtual_key_blocked=yes"
require_text "$SMOKE_DOC" "blocked_key_models_status=401"
require_text "$SMOKE_DOC" "worker_pod_boundary_ok=yes"
require_text "$SMOKE_DOC" "PASS LiteLLM ChatGPT Kubernetes smoke completed"
require_text "$SMOKE_DOC" "successful ChatGPT subscription inference."

require_text "$SMOKE_SCRIPT" "chatgpt_provider_config_loaded=yes"
require_text "$SMOKE_SCRIPT" "chatgpt_provider_requires_device_flow=yes"
require_text "$SMOKE_SCRIPT" "worker_gateway_secret_absent=yes"
require_text "$SMOKE_SCRIPT" "blocked_key_models_status="
require_text "$SMOKE_SCRIPT" "worker_pod_boundary_ok=yes"

if grep -Eiq 'Dokkaebi (must|shall|requires?) use LiteLLM|LiteLLM is required for Dokkaebi' "$DOC"; then
  fail "LiteLLM homelab guide must not make LiteLLM mandatory for Dokkaebi"
fi

if grep -Eiq 'copy .*ChatGPT OAuth.*(Hammer|worker)|mount .*ChatGPT OAuth.*(Hammer|worker)' "$DOC" "$SMOKE_DOC"; then
  fail "LiteLLM homelab guide must not authorize copying or mounting ChatGPT OAuth into workers"
fi

printf 'PASS LiteLLM ChatGPT homelab gateway guide validation passed\n'
