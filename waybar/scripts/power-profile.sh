#!/bin/bash

# Get current profile
current=$(powerprofilesctl get)

# If triggered with --toggle, switch to next profile
if [[ "$1" == "--toggle" ]]; then
  if [[ "$current" == "power-saver" ]]; then
    powerprofilesctl set balanced
  elif [[ "$current" == "balanced" ]]; then
    powerprofilesctl set performance
  else
    powerprofilesctl set power-saver
  fi
fi

# Return current profile as JSON for Waybar
new_current=$(powerprofilesctl get)
echo "{\"text\": \"󰾆 ${new_current^}\"}" # Uppercase first letter
