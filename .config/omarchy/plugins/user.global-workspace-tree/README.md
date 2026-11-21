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

## Accessibility

- Set `OMARCHY_TREE_REDUCED_MOTION=1` to disable panel motion.
- Set `OMARCHY_TREE_HC=1` to use a solid, high-contrast panel without scrim.

## Troubleshooting

- Reload plugin code: `omarchy-shell shell rescanPlugins`
- Toggle directly: `omarchy-shell -q shell toggle io.github.shrobin13.omarchy-tree`
- Hide directly: `omarchy-shell -q shell hide io.github.shrobin13.omarchy-tree`
- If window titles or workspaces look stale, reopen the panel; it rebuilds through `hyprctl`.
