#!/usr/bin/env bash
# Show the temperature of every thermal zone, then wait for <Enter>.

echo -e "\n  Thermal zones and current temperatures\n"
printf "  %-24s %8s\n" "Zone (type)" "°C"
printf "  %-24s %8s\n" "─────────────" "───"

for zone in /sys/class/thermal/thermal_zone*; do
  type=$(<"$zone/type")
  raw=$(<"$zone/temp") # value is in millidegrees
  temp=$(awk "BEGIN{printf \"%.1f\", $raw/1000}")
  printf "  %-24s %8s\n" "$type" "$temp"
done

echo -e "\n  Press <Enter> to close..."
read -r _ # wait so the window doesn’t disappear
