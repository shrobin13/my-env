# Omarchy Tree Probe Record

Date: 2026-11-21

## P1-P10

- P1: Hyprland `0.56.2`; Quickshell `0.3.2`; `omarchy-shell shell ping` returned `ok`; plugin list loaded successfully.
- P3/P4: Live two-monitor setup has eDP-1 IDs 1-6 and HDMI-A-1 IDs 11-13. Client `monitor` is an integer ID.
- P5: A direct `hyprctl dispatch focuswindow address:<addr>` moved focus from the second monitor to another monitor and restored it successfully. H1 is the winning primary sequence.
- P6: Lua candidate `hl.dsp.focus({ window = "address:<addr>" })` returned `ok`.
- P6: The Lua workspace call `hl.dsp.workspace({ workspace = <id> })` was rejected; digit switching uses legacy `hyprctl dispatch workspace <id>`.
- P8: Jump-to manifest declares `"kinds": ["overlay"]` and `"entryPoints": {"overlay": "JumpTo.qml"}`. The same shape is used here.
- P9: `Quickshell.Hyprland` and `WlrKeyboardFocus.Exclusive` are present in the installed shell source. The overlay namespace is set through `WlrLayershell.namespace`.
- P10: `Super+Shift+V` has no live bind. Live inventory also showed `Super+Shift+L`, `Super+Shift+T` and `Super+T` conflicts.

## Live monitor snapshot

```text
eDP-1: monitor ID 0, workspace IDs 1,2,3,6
HDMI-A-1: monitor ID 1, workspace IDs 11,12,13
```
