#!/usr/bin/env bash
set -euo pipefail

CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
CONFIG_FILE="$CODEX_HOME_DIR/config.toml"
PROFILE_FILE="$CODEX_HOME_DIR/litellm.config.toml"
CATALOG_FILE="$CODEX_HOME_DIR/litellm-model-catalog.json"
API_KEY_FILE="$CODEX_HOME_DIR/litellm_api_key"
DEFAULT_MODEL="${CODEX_LITELLM_MODEL:-${DOKKAEBI_LITELLM_MODEL:-chatgpt/gpt-5.5}}"
REASONING_EFFORT="${CODEX_REASONING_EFFORT:-medium}"
LITELLM_BASE_URL="${CODEX_LITELLM_BASE_URL:-${DOKKAEBI_LITELLM_BASE_URL:-http://litellm.dokkaebi-llm.svc.cluster.local:4000}}"
CODEX_BIN="${CODEX_BIN:-}"

case "$LITELLM_BASE_URL" in
  */v1) ;;
  */v1/) LITELLM_BASE_URL="${LITELLM_BASE_URL%/}" ;;
  *) LITELLM_BASE_URL="${LITELLM_BASE_URL%/}/v1" ;;
esac

if [ -z "$CODEX_BIN" ]; then
  if command -v codex >/dev/null 2>&1; then
    CODEX_BIN="$(command -v codex)"
  elif [ -x "$HOME/.local/bin/codex" ]; then
    CODEX_BIN="$HOME/.local/bin/codex"
  else
    printf 'Install Codex first, or set CODEX_BIN to the codex executable.\n' >&2
    exit 2
  fi
fi

mkdir -p "$CODEX_HOME_DIR"
chmod 700 "$CODEX_HOME_DIR"

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
key_source="existing"
if [ -n "${DOKKAEBI_LITELLM_VIRTUAL_KEY:-}" ]; then
  key_source="dokkaebi"
elif [ -n "${LITELLM_API_KEY:-}" ]; then
  key_source="litellm"
elif [ ! -s "$API_KEY_FILE" ]; then
  printf 'Set DOKKAEBI_LITELLM_VIRTUAL_KEY or LITELLM_API_KEY before running this script.\n' >&2
  exit 2
fi

for file in "$CONFIG_FILE" "$PROFILE_FILE" "$CATALOG_FILE" "$API_KEY_FILE"; do
  if [ -e "$file" ]; then
    cp "$file" "$file.bak-$timestamp"
  fi
done

auth_status="absent"
if [ "${CODEX_LITELLM_DISABLE_AUTH_JSON:-1}" != "0" ] && [ -e "$CODEX_HOME_DIR/auth.json" ]; then
  mv "$CODEX_HOME_DIR/auth.json" "$CODEX_HOME_DIR/auth.json.disabled-$timestamp"
  auth_status="disabled"
elif [ -e "$CODEX_HOME_DIR/auth.json" ]; then
  auth_status="kept"
fi

case "$key_source" in
  dokkaebi) printf '%s\n' "$DOKKAEBI_LITELLM_VIRTUAL_KEY" > "$API_KEY_FILE" ;;
  litellm) printf '%s\n' "$LITELLM_API_KEY" > "$API_KEY_FILE" ;;
  existing) ;;
esac
chmod 600 "$API_KEY_FILE"

DEFAULT_CATALOG_HOME="$(mktemp -d "$CODEX_HOME_DIR/.default-models.XXXXXX")"
trap 'rm -rf "$DEFAULT_CATALOG_HOME"' EXIT
DEFAULT_CATALOG_FILE="$DEFAULT_CATALOG_HOME/models.json"
"$CODEX_BIN" debug models --bundled > "$DEFAULT_CATALOG_FILE"

python3 - "$DEFAULT_CATALOG_FILE" "$CATALOG_FILE" <<'PY'
import copy
import json
import sys

default_catalog_path = sys.argv[1]
out_path = sys.argv[2]
with open(default_catalog_path, encoding="utf-8") as f:
    default_catalog = json.load(f)

default_models = {
    model["slug"]: model
    for model in default_catalog.get("models", [])
    if isinstance(model, dict) and "slug" in model
}

model_map = [
    ("gpt-5.5", "chatgpt/gpt-5.5", 0),
    ("gpt-5.4", "chatgpt/gpt-5.4", 2),
    ("gpt-5.4-mini", "chatgpt/gpt-5.4-mini", 4),
    ("gpt-5.3-codex", "chatgpt/gpt-5.3-codex-spark", 6),
]
slug_map = {source: target for source, target, _ in model_map}
slug_map.update(
    {
        "gpt-5.3-codex-spark": "chatgpt/gpt-5.3-codex-spark",
        "gpt-5.2": "chatgpt/gpt-5.3-codex-spark",
    }
)

models = []
for source_slug, target_slug, priority in model_map:
    if source_slug not in default_models:
        raise SystemExit(f"default Codex model metadata not found: {source_slug}")
    model = copy.deepcopy(default_models[source_slug])
    model["slug"] = target_slug
    model["priority"] = priority
    model["visibility"] = "list"
    model["supported_in_api"] = True
    if target_slug == "chatgpt/gpt-5.5":
        model["default_reasoning_level"] = "xhigh"
    if target_slug == "chatgpt/gpt-5.3-codex-spark":
        model["display_name"] = "GPT-5.3 Codex Spark"
        model["description"] = "Codex Spark model routed through LiteLLM."
    upgrade = model.get("upgrade")
    if isinstance(upgrade, dict) and upgrade.get("model") in slug_map:
        upgrade["model"] = slug_map[upgrade["model"]]
    models.append(model)

with open(out_path, "w", encoding="utf-8") as f:
    json.dump({"models": models}, f, ensure_ascii=False, indent=2)
    f.write("\n")
PY
chmod 600 "$CATALOG_FILE"

cat > "$CONFIG_FILE" <<TOML
model = "$DEFAULT_MODEL"
model_provider = "litellm"
model_reasoning_effort = "$REASONING_EFFORT"
model_catalog_json = "$CATALOG_FILE"

[model_providers.litellm]
name = "LiteLLM"
base_url = "$LITELLM_BASE_URL"
wire_api = "responses"

[model_providers.litellm.auth]
command = "cat"
args = ["$API_KEY_FILE"]
timeout_ms = 5000
refresh_interval_ms = 0
TOML
chmod 600 "$CONFIG_FILE"

cat > "$PROFILE_FILE" <<TOML
model = "$DEFAULT_MODEL"
model_provider = "litellm"
model_reasoning_effort = "$REASONING_EFFORT"
model_catalog_json = "$CATALOG_FILE"
TOML
chmod 600 "$PROFILE_FILE"

python3 -m json.tool "$CATALOG_FILE" >/dev/null
printf 'Configured Codex LiteLLM defaults in %s\n' "$CODEX_HOME_DIR"
printf 'Codex LiteLLM base URL: %s\n' "$LITELLM_BASE_URL"
printf 'Codex OAuth auth.json status: %s\n' "$auth_status"
