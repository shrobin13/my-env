#!/bin/bash
#   Hyprland Rofi Window Switcher (clean version)

# Dependencies check
for dep in jq awk rofi; do
  if ! command -v "$dep" &>/dev/null; then
    echo "Error: '$dep' is required but not installed."
    exit 1
  fi
done

# Get active windows
# Format: "Window Title  [WS:3] ##<address>"
windows=$(
  hyprctl clients -j | jq -r '
  .[] | select(.mapped==true and .hidden==false) |
  "\(.title)  [WS:\(.workspace.id)] ##\(.address)"'
)

if [ -z "$windows" ]; then
  echo "No active windows."
  exit 0
fi

# Show Rofi menu
selected=$(echo "$windows" | rofi -dmenu \
  -theme "$HOME/my-env/rofi/rose-pine.rasi" \
  -i -no-show-icons -p "Active Window")

[ -z "$selected" ] && exit 0

# Extract address (after ##) and workspace ID (inside [WS:x])
addr=$(echo "$selected" | awk -F'##' '{print $2}' | xargs)
ws=$(echo "$selected" | sed -n 's/.*\[WS:\([0-9]\+\)\].*/\1/p')

if [ -z "$addr" ] || [ -z "$ws" ]; then
  echo "Error: Could not parse selection."
  exit 1
fi

# Switch workspace, then focus
hyprctl dispatch workspace "$ws"
sleep 0.05
hyprctl dispatch focuswindow "address:$addr"
