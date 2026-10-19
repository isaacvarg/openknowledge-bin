#!/usr/bin/env bash
# Run by the systemd timer: check for a new OpenKnowledge release and send
# a desktop notification if there is one. Never builds or publishes.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

out="$("$ROOT/update-aur.sh" --check 2>&1)"
status=$?
echo "$out"

case $status in
  0) ;;
  10)
    ver="$(sed -n 's/^Update available: .* -> //p' <<<"$out")"
    notify-send -a openknowledge-bin -i openknowledge \
      "OpenKnowledge $ver is available" \
      "Publish it with: $ROOT/update-aur.sh --install --push"
    ;;
  *)
    notify-send -a openknowledge-bin -u low \
      "openknowledge-bin update check failed" \
      "See: journalctl --user -u openknowledge-aur-check"
    exit "$status"
    ;;
esac
