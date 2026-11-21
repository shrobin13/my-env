# Omarchy Tree

Omarchy Tree is a keyboard-driven overlay for navigating and selecting windows across monitors and workspaces.

## Install

```bash
omarchy plugin add https://github.com/shrobin13/omarchy-tree.git
omarchy plugin enable io.github.shrobin13.omarchy-tree
```

## Keybind

Add this bind to `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + SHIFT + V", "Window tree",
  "omarchy-shell -q shell toggle io.github.shrobin13.omarchy-tree")
```

## Backdrop Blur

To enable glass backdrop blur on the overlay, add the following layer rule to your `~/.config/hypr/bindings.lua` (or `hyprland.lua`):

```lua
hl.layer_rule({
  name = "omarchy-tree-blur",
  match = { namespace = "^omarchy-tree$" },
  blur = true,
  ignore_alpha = 0.5,
  no_anim = true,
})
```

The overlay is fully functional without this rule (renders with dark translucent scrim and theme background).

## Keymap

| Key | Action |
| --- | --- |
| `j` / `k` | Move cursor down / up across monitors and workspaces |
| `h` | Move to workspace header (if on window), or fold workspace |
| `l` | Unfold workspace (or move to first window if already unfolded) |
| `1`–`0` | Move cursor to workspace header on current monitor (flashes if empty) |
| `Tab` | Jump to first selectable row on the next monitor |
| `/` | Enter search filter mode |
| `Enter` | Focus selected window or workspace's active window |
| `q` / `Esc` | Close overlay (or exit search filter) |

## Accessibility & Modes

- `OMARCHY_TREE_REDUCED_MOTION=1`: Disables springs and animations for instant transitions.
- `OMARCHY_TREE_HC=1`: High contrast mode with solid theme background, bright borders, and no blur/scrim dependency.

## Troubleshooting

- Reload plugin code: `omarchy-shell shell rescanPlugins` (or `omarchy restart shell`)
- Toggle directly: `omarchy-shell -q shell toggle io.github.shrobin13.omarchy-tree`
- Hide directly: `omarchy-shell -q shell hide io.github.shrobin13.omarchy-tree`
