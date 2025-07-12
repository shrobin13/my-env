#!/usr/bin/env bash
# ------------------------------------------------------------------
# launch-waybar.sh – Start (or restart) Waybar cleanly under Hyprland
# ------------------------------------------------------------------

set -euo pipefail

# 1. Kill any existing Waybar instances (quietly)
pkill -x waybar 2>/dev/null || true

# 2. Wait until every Waybar process is really gone
while pgrep -x waybar >/dev/null; do
  sleep 0.1
done

# 3. Optional per‑session env vars (uncomment / tweak as you like)
# export GTK_THEME="Catppuccin-Mocha-Standard-Teal-Dark"
# export XCURSOR_SIZE=24
# export GDK_BACKEND=wayland  # force Wayland for Electron/GTK apps if needed

# 4. Paths (modify if you move the files)
CONFIG="$HOME/.config/waybar/config"
STYLE="$HOME/.config/waybar/style.css"
LOGFILE="/tmp/waybar.log"

# 5. Launch Waybar, send stdout/stderr to a log you can check with `tail -f`
waybar -c "$CONFIG" -s "$STYLE" >"$LOGFILE" 2>&1 &

# 6. Optionally notify you on reload (needs libnotify / mako / dunst)
if command -v notify-send >/dev/null; then
  notify-send -t 1500 "Waybar" "Started at $(date +'%H:%M:%S')"
fi
