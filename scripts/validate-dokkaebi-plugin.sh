#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_ROOT="$ROOT_DIR/plugins/dokkaebi"
MARKETPLACE="$ROOT_DIR/.agents/plugins/marketplace.json"
CHECK_MARKETPLACE=1

fail() {
  printf 'FAIL %s\n' "$1" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Usage: scripts/validate-dokkaebi-plugin.sh [--plugin-root PATH] [--marketplace PATH] [--skip-marketplace]
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --plugin-root)
      [[ $# -ge 2 ]] || fail "--plugin-root requires a path"
      PLUGIN_ROOT="$2"
      shift 2
      ;;
    --marketplace)
      [[ $# -ge 2 ]] || fail "--marketplace requires a path"
      MARKETPLACE="$2"
      shift 2
      ;;
    --skip-marketplace)
      CHECK_MARKETPLACE=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      fail "unknown argument: $1"
      ;;
  esac
done

MANIFEST="$PLUGIN_ROOT/.codex-plugin/plugin.json"

require_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "missing file: $path"
}

require_text() {
  local path="$1"
  local needle="$2"
  grep -Fq -- "$needle" "$path" || fail "missing text in $path: $needle"
}

require_regex() {
  local path="$1"
  local pattern="$2"
  grep -Eq -- "$pattern" "$path" || fail "missing pattern in $path: $pattern"
}

require_jq() {
  local path="$1"
  local expression="$2"
  jq -e "$expression" "$path" >/dev/null || fail "JSON check failed in $path: $expression"
}

require_file "$MANIFEST"
require_jq "$MANIFEST" '.name == "dokkaebi"'
require_jq "$MANIFEST" '.version | type == "string" and length > 0'
require_jq "$MANIFEST" '.description | type == "string" and length > 0'
require_jq "$MANIFEST" '.skills == "./skills/"'
require_jq "$MANIFEST" '.interface.displayName | type == "string" and length > 0'
require_jq "$MANIFEST" '.interface.shortDescription | type == "string" and length > 0'

if [[ "$CHECK_MARKETPLACE" -eq 1 ]]; then
  require_file "$MARKETPLACE"
  require_jq "$MARKETPLACE" '.plugins[] | select(.name == "dokkaebi" and .source.source == "local" and .source.path == "./plugins/dokkaebi" and .policy.installation == "AVAILABLE" and .policy.authentication == "ON_INSTALL" and (.category | type == "string" and length > 0))'
fi

required_skills=(
  project-admin
  issue-intake
  manager-review
  fire-ops
  hammer-bootstrap
)

for skill in "${required_skills[@]}"; do
  require_file "$PLUGIN_ROOT/skills/$skill/SKILL.md"
  require_text "$PLUGIN_ROOT/skills/$skill/SKILL.md" '---'
  require_text "$PLUGIN_ROOT/skills/$skill/SKILL.md" 'name:'
  require_text "$PLUGIN_ROOT/skills/$skill/SKILL.md" 'description:'
done

require_regex "$PLUGIN_ROOT/skills/project-admin/SKILL.md" 'Greenfield|Brownfield'
require_text "$PLUGIN_ROOT/skills/project-admin/SKILL.md" 'createProjectV2'
require_text "$PLUGIN_ROOT/skills/project-admin/SKILL.md" 'updateProjectV2ItemFieldValue'
require_text "$PLUGIN_ROOT/skills/project-admin/SKILL.md" 'linkProjectV2ToRepository'
require_text "$PLUGIN_ROOT/skills/project-admin/SKILL.md" 'required fields'
require_text "$PLUGIN_ROOT/skills/project-admin/SKILL.md" 'GitHub Project Status'

require_text "$PLUGIN_ROOT/skills/issue-intake/SKILL.md" 'acceptance criteria'
require_text "$PLUGIN_ROOT/skills/issue-intake/SKILL.md" 'validation'
require_text "$PLUGIN_ROOT/skills/issue-intake/SKILL.md" 'permission level'
require_text "$PLUGIN_ROOT/skills/issue-intake/SKILL.md" 'result packet'
require_text "$PLUGIN_ROOT/skills/issue-intake/SKILL.md" 'admission fields'

require_text "$PLUGIN_ROOT/skills/manager-review/SKILL.md" 'GitHub Project Status'
require_text "$PLUGIN_ROOT/skills/manager-review/SKILL.md" 'workpad'
require_text "$PLUGIN_ROOT/skills/manager-review/SKILL.md" 'PR'
require_text "$PLUGIN_ROOT/skills/manager-review/SKILL.md" 'checks'
require_text "$PLUGIN_ROOT/skills/manager-review/SKILL.md" 'residual risks'

require_text "$PLUGIN_ROOT/skills/fire-ops/SKILL.md" 'project registry'
require_text "$PLUGIN_ROOT/skills/fire-ops/SKILL.md" 'observability'
require_text "$PLUGIN_ROOT/skills/fire-ops/SKILL.md" 'worker routing'
require_text "$PLUGIN_ROOT/skills/fire-ops/SKILL.md" 'admission checks'
require_text "$PLUGIN_ROOT/skills/fire-ops/SKILL.md" 'stuck-run reconciliation'

require_text "$PLUGIN_ROOT/skills/hammer-bootstrap/SKILL.md" 'local worktree'
require_text "$PLUGIN_ROOT/skills/hammer-bootstrap/SKILL.md" 'SSH'
require_text "$PLUGIN_ROOT/skills/hammer-bootstrap/SKILL.md" 'Docker'
require_text "$PLUGIN_ROOT/skills/hammer-bootstrap/SKILL.md" 'Kubernetes'
require_text "$PLUGIN_ROOT/skills/hammer-bootstrap/SKILL.md" 'rollback'

if grep -RIn -- '[[]TODO:' "$PLUGIN_ROOT" >/dev/null; then
  fail "placeholder text found in plugin files"
fi

scan_targets=("$PLUGIN_ROOT")
if [[ "$CHECK_MARKETPLACE" -eq 1 ]]; then
  scan_targets+=("$MARKETPLACE")
fi

restricted_terms=(
  "$(printf '\157\155\157')"
  "$(printf '\157\155\170')"
  "$(printf '\143\157\144\145\170/')"
)

for term in "${restricted_terms[@]}"; do
  if grep -RIn -- "$term" "${scan_targets[@]}" >/dev/null; then
    fail "restricted public token found in plugin or marketplace files"
  fi
done

printf 'PASS Dokkaebi plugin packaging checks passed\n'
