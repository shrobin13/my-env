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

case "$new_current" in
power-saver)
  icon=""        # lightning bolt
  color="#98c379" # green-ish
  label="Saver"
  ;;
balanced)
  icon=" "       # sync icon
  color="#61afef" # blue-ish
  label="Balanced"
  ;;
performance)
  icon=""        # rocket
  color="#e06c75" # red-ish
  label="Performance"
  ;;
*)
  icon="?"
  color="#bbbbbb"
  label="Unknown"
  ;;
esac

# JSON output with colored icon + label, and tooltip with full text
echo "{\"text\": \"<span foreground='$color'>$icon</span> <span foreground='#ddd'>$label</span>\", \"tooltip\": \"Power Profile: $new_current\"}"
