# Omarchy Tree

Omarchy Tree is a keyboard-driven overlay for selecting windows across monitors and workspaces.

## Install

```bash
omarchy plugin add https://github.com/shrobin13/omarchy-tree.git
omarchy plugin enable io.github.shrobin13.omarchy-tree
```

## Keybind

Add this to `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + SHIFT + V", "Window tree",
  "omarchy-shell -q shell toggle io.github.shrobin13.omarchy-tree")
```

The exact Lua bind shape may differ under your installed Omarchy version; the live probe found `Super+Shift+V` free and confirmed plugin toggling before finalizing.

## Blur

Paste `hyprland/layer-rule.lua` into your Hyprland Lua configuration. The overlay remains usable without this rule.
