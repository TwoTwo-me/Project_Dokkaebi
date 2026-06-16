#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

while IFS= read -r script; do
  case "$script" in
    scripts/validate-all.sh)
      continue
      ;;
  esac
  printf 'RUN %s\n' "$script"
  bash "$script"
done < <(find scripts -maxdepth 1 -type f -name 'validate-*.sh' | sort)

printf 'PASS all repository validators completed\n'
