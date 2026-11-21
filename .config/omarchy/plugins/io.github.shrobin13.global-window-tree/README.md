# Global Window Tree

[![Omarchy Plugin](https://img.shields.io/badge/Omarchy-Plugin-blue.svg)](https://omarchy.org)
[![Author](https://img.shields.io/badge/Author-Sheikh%20Robin-informational.svg)](https://github.com/shrobin13)
[![GitHub](https://img.shields.io/badge/GitHub-shrobin13-lightgrey.svg)](https://github.com/shrobin13)

**Global Window Tree** (`io.github.shrobin13.global-window-tree`) is a fast, keyboard-driven modal overlay for [Omarchy](https://omarchy.org/) Linux and Hyprland. It presents every window across all connected monitors and workspaces in an intuitive hierarchical tree (`Monitor → Workspace → Window`), enabling instant navigation, fuzzy filtering, and single-keystroke window switching.

---
![Preview of window tree](asssets/preview.png)

---

## What It Is

When running multiple monitors and many virtual workspaces on Hyprland, tracking down specific application windows or cycling through workspaces can be disruptive. Global Window Tree solves this by rendering a full-screen, semi-transparent HUD overlay that maps your entire desktop layout in real time.

Built natively for Omarchy's Quickshell environment (`omarchy-shell`), Global Window Tree queries Hyprland's IPC state directly (`hyprctl`), constructs a structured representation of every active display and client, and allows you to jump to any window or workspace without touching the mouse.

---

## What It Does

- **Full Multi-Monitor & Workspace Tree View:**
  - Displays monitors ordered left-to-right by physical geometry.
  - Represents workspaces (slots 1–10) with active status, title pills, and window counters.
  - Renders application windows with extracted desktop icons, titles, window classes, address hashes, and fullscreen badges.
  - Connected with tree spines and elbows.

- **Vim-Inspired Keyboard Navigation:**
  - `j` / `k` (or Down / Up arrows): Move the cursor smoothly across windows, workspaces, and monitors.
  - `h`: Fold (collapse) an expanded workspace or jump to its workspace header.
  - `l`: Unfold (expand) a collapsed workspace or jump directly to its first child window.
  - `1`–`0` (number row): Instantly jump cursor focus to workspaces 1 through 10 on the current monitor.
  - `Tab` / `Shift+Tab`: Jump between monitors.
  - `Enter`: Switch to and focus the selected window immediately via Hyprland IPC, then dismiss the overlay.

- **Live Search & Fuzzy Filtering:**
  - Press `/` to activate interactive search mode.
  - Filter windows dynamically across all screens by window title, application class, or workspace.
  - Use `n` / `N` to cycle forward and backward through search matches.
  - Press `Enter` to focus the matched window or `Esc` to cancel and return to normal mode.

- **Visual Design & Theming:**
  - Inherits system theme colors, borders, and typography live from `qs.Commons` (`Commons.Color` and `Style`).
  - Supports Hyprland compositor glass blur (`WlrLayershell.namespace: "global-window-tree"`).
  - Responsive smooth transitions that respect Omarchy animation settings.

- **Accessibility Modes:**
  - **Reduced Motion:** Set `GLOBAL_WINDOW_TREE_REDUCED_MOTION=1` to disable springs and transitions for instant zero-latency UI rendering.
  - **High Contrast:** Set `GLOBAL_WINDOW_TREE_HC=1` for solid opaque backgrounds, high-contrast borders, and zero blur dependency.

---

## Installation in Omarchy

### Method 1: Using the Omarchy CLI (Recommended)

Install directly from GitHub via the `omarchy plugin` manager:

```bash
# Add and clone the plugin into ~/.config/omarchy/plugins/
omarchy plugin add https://github.com/shrobin13/global-window-tree.git --enable --yes
```

### Method 2: Manual Installation

If developing locally or managing your dotfiles manually:

```bash
# Clone into the Omarchy plugins directory
git clone https://github.com/shrobin13/global-window-tree.git \
  ~/.config/omarchy/plugins/io.github.shrobin13.global-window-tree

# Force Omarchy Shell to discover new plugins
omarchy-shell shell rescanPlugins
# (Or restart the shell)
omarchy restart shell
```

Verify that the plugin is detected:

```bash
omarchy plugin list
# You should see: io.github.shrobin13.global-window-tree
```

---

## Configuration

### 1. Keybinding in Hyprland

Add a keybinding to summon/toggle the Global Window Tree overlay in `~/.config/hypr/bindings.lua`:

```lua
-- Toggle Global Window Tree overlay (e.g. Super + Shift + V or Super + Tab)
o.bind("SUPER + SHIFT + V", "Global Window Tree",
  "omarchy-shell -q shell toggle io.github.shrobin13.global-window-tree")
```

### 2. Glass Backdrop Blur (Optional)

To enable compositor blur behind the overlay window, add this layer rule to your `~/.config/hypr/bindings.lua` (or `~/.config/hypr/hyprland.lua`):

```lua
hl.layer_rule({
  name = "global-window-tree-blur",
  match = { namespace = "^global-window-tree$" },
  blur = true,
  ignore_alpha = 0.5,
  no_anim = true,
})
```

Reload Hyprland bindings to apply:

```bash
hyprctl reload
```

---

## Keymap Reference

| Key | Mode | Action |
| --- | --- | --- |
| `j` / `↓` | Normal | Move cursor down across rows (windows, workspaces, monitors) |
| `k` / `↑` | Normal | Move cursor up across rows |
| `h` / `←` | Normal | Move to workspace header if on a window, or collapse/fold workspace |
| `l` / `→` | Normal | Expand/unfold workspace or jump to its first window |
| `1` – `0` | Normal | Jump cursor to workspace 1–10 on current monitor |
| `Tab` | Normal | Jump cursor to the next monitor |
| `Shift + Tab` | Normal | Jump cursor to the previous monitor |
| `/` | Normal | Open interactive search filter input |
| `n` | Normal | Jump to next search match |
| `N` | Normal | Jump to previous search match |
| `Enter` | Normal | Focus selected window in Hyprland and close overlay |
| `q` / `Esc` | Normal | Dismiss overlay |
| `Enter` | Search | Exit search mode keeping current matched selection |
| `Esc` | Search | Clear search input and restore normal navigation |

---

## Directory Structure

```
io.github.shrobin13.global-window-tree/
├── manifest.json              # Omarchy shell plugin manifest
├── GlobalWindowTree.qml       # Main Quickshell overlay entry point
├── Model.js                   # Hyprland IPC snapshot parser & data normalizer
├── Tree.js                    # Tree state machine, row flattener, and search
├── components/
│   ├── AppIcon.qml            # Client icon loader from desktop themes
│   ├── Elbow.qml              # Shape-drawn connector elbow
│   ├── Footer.qml             # Bottom keybind hints and status bar
│   ├── MonitorColumn.qml      # Display monitor root container
│   ├── SearchBar.qml          # Live search query input widget
│   ├── Spine.qml              # Vertical tree trunk line
│   ├── WindowRow.qml          # Window client entry row
│   └── WorkspaceNode.qml      # Workspace slot header node
├── hyprland/
│   └── layer-rule.lua         # Hyprland blur and layer-shell rules
├── tests/
│   ├── model.test.js          # Unit tests for Model.js snapshot parsing
│   ├── tree.test.js           # Unit tests for Tree.js state & navigation
│   └── fixtures/              # Mock Hyprland JSON dumps
└── README.md                  # Plugin documentation
```

---

## Development & Testing

Validate manifest schema compliance:

```bash
omarchy plugin validate ~/.config/omarchy/plugins/io.github.shrobin13.global-window-tree
```

Run unit test suites:

```bash
node tests/model.test.js
node tests/tree.test.js
```

Direct shell toggle commands:

```bash
omarchy-shell -q shell toggle io.github.shrobin13.global-window-tree
omarchy-shell -q shell hide io.github.shrobin13.global-window-tree
```

---

## Author

- **Author:** Sheikh Robin
- **GitHub:** [@shrobin13](https://github.com/shrobin13)
- **License:** MIT
