#!/usr/bin/env bash
# Install (or with --uninstall, remove) the daily systemd user timer that
# checks for new OpenKnowledge releases.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
UNITS=(openknowledge-aur-check.service openknowledge-aur-check.timer)

if [[ "${1:-}" == "--uninstall" ]]; then
  systemctl --user disable --now openknowledge-aur-check.timer 2>/dev/null || true
  for unit in "${UNITS[@]}"; do rm -f "$UNIT_DIR/$unit"; done
  systemctl --user daemon-reload
  echo "Removed the openknowledge-aur-check timer."
  exit 0
fi

mkdir -p "$UNIT_DIR"
for unit in "${UNITS[@]}"; do
  sed "s|@ROOT@|$ROOT|g" "$ROOT/systemd/$unit" > "$UNIT_DIR/$unit"
done
systemctl --user daemon-reload
systemctl --user enable --now openknowledge-aur-check.timer
systemctl --user list-timers openknowledge-aur-check.timer
