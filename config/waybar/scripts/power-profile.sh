#!/bin/bash

STATE_FILE="/tmp/tlp_mode"

# Default state
[[ -f "$STATE_FILE" ]] || echo "AC" >"$STATE_FILE"

current_status=$(cat "$STATE_FILE")

if [[ "$1" == "--toggle" ]]; then
  if [[ "$current_status" == "BAT" ]]; then
    sudo tlp performance >/dev/null
    new_status="AC"
  else
    sudo tlp power-saver >/dev/null
    new_status="BAT"
  fi

  echo "$new_status" >"$STATE_FILE"
  current_status="$new_status"

  # Refresh rate
  if pgrep -x Hyprland >/dev/null; then
    if [[ "$current_status" == "AC" ]]; then
      hyprctl keyword monitor eDP-1,1920x1080@120,0x0,1
    else
      hyprctl keyword monitor eDP-1,1920x1080@60,0x0,1
    fi
  fi

  pkill -RTMIN+4 waybar
fi

# UI
if [[ "$current_status" == "BAT" ]]; then
  echo '{"text": "<span foreground=\"#98c379\"></span> Saver"}'
else
  echo '{"text": "<span foreground=\"#e06c75\"></span> Performance"}'
fi
