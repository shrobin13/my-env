# Omarchy Tree Probe Record

Date: 2026-11-21  
Auditor / Implementer: OpenCode Agent

---

## 1. Architectural Q&A (Brief §3)

1. **How does an overlay plugin declare its entry file, get summoned, and receive keyboard input?**
   - The plugin declares `"kinds": ["overlay"]` and `"entryPoints": { "overlay": "OmarchyTree.qml" }` in `manifest.json`.
   - It is summoned via Omarchy IPC: `omarchy-shell -q shell toggle <plugin-id>` (or `summon` / `hide`).
   - The overlay is an `Item` embedding a `PanelWindow` with `WlrLayershell.layer: WlrLayer.Overlay` and `WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None`. While open, it receives exclusive keyboard events through QtQuick `Keys.onPressed`.

2. **Where do theme colors come from, and which keys exist?**
   - Theme tokens come from the Omarchy Commons module: `import qs.Commons` / `qs.Commons as Commons`.
   - Colors are accessed via `Color.background`, `Color.foreground`, `Color.accent`, and `Color.urgent`.
   - Motion and spacing values come from `Style.duration(ms)` and `Style.space()`.
   - Secondary monitor accents are derived cleanly by rotating the hue of `Color.accent` per monitor index.

3. **How does jump-to list windows and focus one, on both Lua and legacy Hyprland configs?**
   - Window lists are fetched asynchronously using `hyprctl clients -j`, `monitors -j`, `workspaces -j`, and `activewindow -j` via `Quickshell.Io.Process`.
   - Focus dispatch on modern Lua configs (Hyprland 0.56.2+) evaluates Lua dispatchers via `hyprctl dispatch 'hl.dsp.focus({ window = "address:<addr>" })'`.
   - On legacy Hyprland configs without Lua, it falls back to `hyprctl dispatch focuswindow "address:<addr>"`.
   - Post-dispatch address verification checks `hyprctl activewindow -j` and falls back to a monitor switch + focus sequence if needed.

4. **What is the namespace of the overlay window, and where does the layer rule go?**
   - The layer-shell namespace is set to `omarchy-tree` via `WlrLayershell.namespace: "omarchy-tree"`.
   - The layer rule belongs in `~/.config/hypr/bindings.lua` (or `hyprland.lua`):
     ```lua
     hl.layer_rule({
       name = "omarchy-tree-blur",
       match = { namespace = "^omarchy-tree$" },
       blur = true,
       ignore_alpha = 0.5,
       no_anim = true,
     })
     ```

---

## 2. Probe Inventory (P1–P10)

- **P1 (Versions & shell health):**
  - Hyprland: `0.56.2` (commit `efb50993780079460b0cbed1363e2166a2de1d9f`)
  - Quickshell: `0.3.2`
  - `omarchy-shell shell ping` → `ok`
  - `omarchy plugin list` → `io.github.shrobin13.omarchy-tree enabled third-party overlay`

- **P2 (Monitors):**
  - Live configuration:
    - `eDP-1`: ID 0, x=0, y=0, width=1920, height=1080, focused=false, activeWorkspace=3
    - `HDMI-A-1`: ID 1, x=1920, y=0, width=1920, height=1080, focused=true, activeWorkspace=12

- **P3 (Workspaces):**
  - Workspaces on `eDP-1`: IDs 1, 2, 3, 6
  - Workspaces on `HDMI-A-1`: IDs 11, 12, 13
  - Per-monitor local workspace numbering maps to 1–10.

- **P4 (Clients):**
  - `hyprctl clients -j`: `.monitor` is integer ID (0 or 1). Normalized to monitor name using `monitors` list.
  - Hyprland 0.56.2 has **no `focused` boolean field**; active window is determined by `focusHistoryID === 0` and `hyprctl activewindow -j`.

- **P5 & P6 (Dispatchers):**
  - Lua dispatcher `hyprctl dispatch 'hl.dsp.focus({ window = "address:<addr>" })'` returns `ok` and focuses across monitors and workspaces in a single step.
  - Legacy `hyprctl dispatch focuswindow address:...` produces Lua parse error on this compositor config.
  - `hl.dsp.focus({ monitor = "<name>" })` switches monitor focus.

- **P7 (Event Stream):**
  - Hyprland events stream from `$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock`.
  - Quickshell's `Quickshell.Hyprland` exposes the `rawEvent` signal, which is debounced to 60 ms to trigger snapshot refreshes.

- **P8 (Manifest):**
  - Overlay key is `"entryPoints": { "overlay": "OmarchyTree.qml" }`.

- **P9 (Commons & Theming):**
  - `import qs.Commons` provides `Color.background`, `Color.foreground`, `Color.accent`, `Color.urgent`, and `Style.duration()`.

- **P10 (Keybind):**
  - Live chord: `SUPER + SHIFT + V` bound to `omarchy-shell -q shell toggle io.github.shrobin13.omarchy-tree`.

---

## 3. Performance & Verification Checklist

- [x] Dual-column tree layout matching `WINDOW_TREE_MOCKUP.html`
- [x] Focus works in all four monitor/workspace combinations
- [x] Focus detection on Hyprland 0.56.2 (`focusHistoryID === 0` / `activewindow -j`)
- [x] Lua dispatcher primary with verified fallback
- [x] Digit keys move cursor without dispatching workspace switch
- [x] Row-level flash on empty workspace digit press
- [x] Persistent search bar with non-matching row dimming (0.18 opacity)
- [x] Esc restores recorded cursor in search mode
- [x] Empty workspaces skipped during `j`/`k` navigation
- [x] Fold persistence and `h`/`l` semantics (`h` on folded is no-op)
- [x] Reduced motion (`OMARCHY_TREE_REDUCED_MOTION=1`)
- [x] High contrast mode (`OMARCHY_TREE_HC=1`)
- [x] All unit tests U1–U13 passing with Node.js
