#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
mkdir -p "$UNIT_DIR"

install -m 0644 "$ROOT/ops/systemd/dokkaebi-status-sync.service" "$UNIT_DIR/dokkaebi-status-sync.service"
install -m 0644 "$ROOT/ops/systemd/dokkaebi-symphony.service" "$UNIT_DIR/dokkaebi-symphony.service"

systemctl --user daemon-reload
systemctl --user enable --now dokkaebi-status-sync.service
systemctl --user enable --now dokkaebi-symphony.service

systemctl --user --no-pager --full status dokkaebi-status-sync.service dokkaebi-symphony.service || true
if command -v loginctl >/dev/null 2>&1; then
  loginctl show-user "$USER" -p Linger 2>/dev/null || true
fi
