#!/usr/bin/env bash
set -euo pipefail

# Launch Codex for a Symphony Worker without passing Manager/control-plane
# credentials into the Worker process environment. Codex still uses CODEX_HOME
# for model access; tracker, GitHub, SSH, cloud, and broker credentials must
# arrive through an approved task-scoped broker path.

ORIGINAL_CODEX_HOME="${CODEX_HOME:-${HOME:-}/.codex}"
WORKER_ENV_ROOT="$PWD/.dokkaebi-worker-env"

is_forbidden_env_name() {
  case "$1" in
    DOKKAEBI_WORKER_GH_CONFIG_DIR|GITHUB_GRAPHQL_TOKEN|GITHUB_TOKEN|GITHUB_PAT|GITHUB_OAUTH_TOKEN|GITHUB_CLIENT_SECRET|GITHUB_APP_PRIVATE_KEY|GH_TOKEN|GH_ENTERPRISE_TOKEN|GHES_TOKEN|GIT_ASKPASS|GIT_SSH|GIT_SSH_COMMAND|GIT_CONFIG|GIT_CONFIG_*|GIT_CREDENTIAL_*|GIT_HTTP_*|SSH_AUTH_SOCK|SSH_AGENT_PID|SSH_ASKPASS|SSH_ASKPASS_REQUIRE)
      return 0
      ;;
    SYMPHONY_GITHUB_*|SYMPHONY_MANAGER_SSH_KEY|HERMES_*|AWS_*|AZURE_*|GOOGLE_*|GCLOUD_*|GCP_*|DIGITALOCEAN_*|DO_*|CLOUDFLARE_*|TF_VAR_*|KUBECONFIG|KUBE*)
      return 0
      ;;
    OPENAI_API_KEY|ANTHROPIC_API_KEY|OPENROUTER_API_KEY|GEMINI_API_KEY|GOOGLE_API_KEY|DEEPSEEK_API_KEY|XAI_API_KEY|NVIDIA_API_KEY|ZAI_API_KEY|KIMI_API_KEY|MINIMAX_API_KEY|FIRECRAWL_API_KEY|TAVILY_API_KEY|BROWSERBASE_API_KEY|FAL_KEY|ELEVENLABS_API_KEY)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

scrub_forbidden_env() {
  local name
  while IFS='=' read -r name _; do
    if is_forbidden_env_name "$name"; then
      unset "$name"
    fi
  done < <(env)
}

scrub_forbidden_env

export GIT_TERMINAL_PROMPT=0
export DOKKAEBI_WORKER_SANITIZED=1
export HOME="$WORKER_ENV_ROOT/home"
export CODEX_HOME="$ORIGINAL_CODEX_HOME"
export GH_CONFIG_DIR="$WORKER_ENV_ROOT/gh"
export XDG_CONFIG_HOME="$WORKER_ENV_ROOT/xdg-config"
export XDG_CACHE_HOME="$WORKER_ENV_ROOT/xdg-cache"
mkdir -p "$HOME" "$GH_CONFIG_DIR" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"

if [[ "${1:-}" == "--check-sanitizer" ]]; then
  failures=0
  while IFS='=' read -r name _; do
    if is_forbidden_env_name "$name"; then
      printf 'FAIL forbidden worker env still present: %s\n' "$name" >&2
      failures=$((failures + 1))
    fi
  done < <(env)

  if [[ "$failures" -gt 0 ]]; then
    exit 2
  fi

  printf 'PASS sanitized worker environment\n'
  exit 0
fi

exec codex app-server "$@"
