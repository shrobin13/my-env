#!/bin/bash

current=$(powerprofilesctl get)

if [[ "$1" == "--toggle" ]]; then
  if [[ "$current" == "power-saver" ]]; then
    powerprofilesctl set balanced
  elif [[ "$current" == "balanced" ]]; then
    powerprofilesctl set performance
  else
    powerprofilesctl set power-saver
  fi
fi

new_current=$(powerprofilesctl get)

# Map profile to icon
if [[ "$new_current" == "power-saver" ]]; then
  icon="" # lightning bolt for power saver
elif [[ "$new_current" == "balanced" ]]; then
  icon="" # sync/refresh icon for balanced
else
  icon="" # rocket for performance
fi

echo "{\"text\": \"$icon\"}"
