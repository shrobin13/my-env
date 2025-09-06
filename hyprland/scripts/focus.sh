#!/bin/bash
# Simple Hyprland Window Selector using Rofi

# Check dependency
if ! command -v rofi &>/dev/null; then
  echo "Error: 'rofi' is not installed."
  exit 1
fi

# Launch Rofi in window mode
rofi -show window -theme "$HOME/my-env/rofi/rose-pine.rasi"
