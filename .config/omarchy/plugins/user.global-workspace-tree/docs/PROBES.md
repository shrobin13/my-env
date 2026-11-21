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

## Accessibility and theme

- Omarchy's live palette is available through `Color.background`, `Color.foreground`, `Color.accent` and `Color.urgent`.
- Motion durations use `Style.duration(ms)` so animation preferences apply.
- Reduced-motion and high-contrast modes use `OMARCHY_TREE_REDUCED_MOTION=1` and `OMARCHY_TREE_HC=1`.

## Manual verification status

- [ ] Focus in all four monitor/workspace combinations
- [ ] Monitor unplug/replug snapshot rebuild
- [ ] Dead-window Enter behavior
- [ ] Theme-switch recoloring without restart
- [ ] Layer-rule blur and no-blur fallback
- [ ] Search keyboard isolation
- [ ] Fold persistence after live refresh
- [ ] Hot reload while open
- [ ] Keybind toggle twice
- [ ] Reduced-motion mode
- [ ] High-contrast mode
- [ ] Cold/warm open and cursor timing

## P5 follow-up

- Direct Lua focus returned `ok`.
- The plugin now verifies `hyprctl activewindow -j` after dispatch.
- If the address mismatches, it runs `focusmonitor`, `workspace`, then `focuswindow address:<addr>` once before retaining the panel open and refreshing state.

## Live monitor snapshot

```text
eDP-1: monitor ID 0, workspace IDs 1,2,3,6
HDMI-A-1: monitor ID 1, workspace IDs 11,12,13
```
