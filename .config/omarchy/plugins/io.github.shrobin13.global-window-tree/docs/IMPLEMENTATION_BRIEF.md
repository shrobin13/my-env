# omarchy-tree: Agent Implementation Brief

Nov 21, 2026 · @robin

## 1. Mission, scope and definition of done

omarchy-tree is an Omarchy shell plugin: a keyboard-driven overlay that shows every window on every monitor as a tree (monitor → workspace → window) and focuses the chosen window in one keystroke.

It exists because Omarchy 4.5 gives each display its own workspaces. People lose track of which app lives where, and launch-or-focus binds do not cross monitors.

**In scope for v1**

- One global tree: every monitor is a root, every workspace a branch, every window a leaf. Empty workspaces are shown, dimmed.
- Vim-native keys: `j k h l`, `gg`, `G`, `1–0`, `/`, `Enter`, `q`, `Esc`.
- Search that filters by window title, app class and workspace name.
- Correct focus across monitors and workspaces.
- Colors that follow the active Omarchy theme.
- A glass panel with backdrop blur, curved branch connectors and restrained motion.

**Non-goals**

- Per-tab tracking inside a browser (needs an extension).
- Window thumbnails, drag-and-drop between workspaces, pointer-first use.
- A standalone app, a Python daemon, or a compiled C++ module. The plugin is pure QML plus the `hyprctl` binary.

**Definition of done**

- Installs with `omarchy plugin add <git-url>`. The only manual steps are one keybind and one blur layer rule.
- `Enter` on any window, on any monitor, lands focus on that window, on its monitor and workspace.
- The panel recolors when the user switches Omarchy theme, with no restart.
- Cold open ≤ 80 ms and warm open ≤ 30 ms, measured, with 40 windows.
- Every test in section 10 passes, and the manual checklist is signed off on real hardware with two monitors.

## 2. Ground truth: what is verified and what is not

Treat the first table as settled and the second as unknown until you run the probe named in it. Never code an unverified row as fact.

**Verified from documentation**

| Fact | Source |
| --- | --- |
| Omarchy 4.5 gives each display independent workspaces; `Super+1–0` acts on the focused monitor | [Linux Journal, Omarchy 4.5](https://linuxjournal.com/content/omarchy-45-brings-floating-workspaces-native-apple-silicon-installation-and-more-flexible) |
| The Omarchy shell is Quickshell. Plugins are QML, live in `~/.config/omarchy/plugins/<plugin-id>/`, and declare `manifest.json` with `kinds` (one is `overlay`) | [Omarchy shell reference](https://github.com/omacom/omarchy/blob/quattro/docs/omarchy-shell.md), [plugins README](https://github.com/omacom/omarchy/blob/quattro/shell/plugins/README.md) |
| Overlay entry points are QML `Item`s exposing `open(payloadJson)` and `close()`. IPC: `summon`, `hide`, `toggle <id> <payloadJson>`, `rescanPlugins` | Omarchy shell reference |
| Theme access: `import qs.Commons as Commons`, then `Commons.Color.background / foreground / accent / urgent` and `Commons.Style.duration(ms)` | Omarchy shell reference |
| A close precedent exists: an overlay plugin with `keepLoaded: true`, layer-shell namespace `omarchy-jump-to`, window list from `hyprctl clients -j`, Lua dispatch with a legacy fallback, keybind in `bindings.lua` | [omarchy-jump-to](https://github.com/Matt-aaz/omarchy-jump-to) |
| `Quickshell.Hyprland` exposes `monitors`, `workspaces`, `toplevels`, `dispatch(string)`, a `rawEvent` signal, `usingLua`, and `refresh*()` because many changes send no event. Dispatcher syntax differs under Lua | [Quickshell Hyprland docs](https://quickshell.org/docs/v0.3.2/types/Quickshell.Hyprland/Hyprland) |
| `HyprlandToplevel` has no focus method, so focusing goes through a dispatcher | [HyprlandToplevel docs](https://quickshell.org/docs/v0.3.2/types/Quickshell.Hyprland/HyprlandToplevel) |
| `FloatingWindow` is an ordinary app window with no anchor or centering property. Use `PanelWindow` with `WlrKeyboardFocus.Exclusive` for a modal overlay | [FloatingWindow](https://quickshell.org/docs/v0.3.2/types/Quickshell/FloatingWindow), [WlrKeyboardFocus](https://quickshell.org/docs/v0.3.2/types/Quickshell.Wayland/WlrKeyboardFocus) |
| Qt `SpringAnimation` has `spring` (useful 0–5), `damping` (useful 0–1), `mass`, `epsilon`, `modulus`. It has no `stiffness` | [Qt docs mirror](https://stuff.mit.edu/afs/athena/software/texmaker_v5.0.2/qt57/doc/qtquick/qml-qtquick-springanimation.html) |
| Backdrop blur comes from a Hyprland Lua layer rule: `hl.layer_rule({ match = { namespace = … }, blur = true, ignore_alpha = 0.5, no_anim = true })` | [Noctalia Hyprland guide](https://docs.noctalia.dev/noctalia/compositor-settings/hyprland/) |
| `Super+Tab` defaults to next workspace; `Super+~` is the AI console in 4.5. The manual may predate 4.5 | [Omarchy manual](https://learn.omacom.io/2/the-omarchy-manual/53/hotkeys), Linux Journal |

**Unverified: probe before relying on it**

| Open item | Why it matters | Probe |
| --- | --- | --- |
| Manifest key that names an overlay's entry file | The plugin will not load without it | P8 |
| Whether `import Quickshell.Hyprland` works inside a plugin | Decides the data path | P9 |
| Type of `monitor` in `hyprctl clients -j` (integer ID or name) | Wrong type breaks the tree and the dispatch | P4 |
| Whether `focuswindow` alone crosses monitors, or the three-step order is required | The original spec asserted the order without evidence | P5 |
| How 4.5 maps per-monitor workspace numbers to Hyprland workspace IDs | `workspace <id>` may target the wrong place | P3, P5 |
| Exact Lua dispatch strings accepted by `hyprctl dispatch` and by `Hyprland.dispatch()` | Dispatch must work on Lua and legacy configs | P6 |
| IPC socket roles and event names (including `v2` variants) | Only matters if you react to individual events | P7 |
| Plugin docs were read from the 4.0 `quattro` branch, not 4.5 | The API may have changed | P1, P8 |
| Where Omarchy 4.5 expects the layer rule to live | Without it the glass does not blur | P9, P10 |
| A free keybind | `Super+Tab` and likely `Super+~` are taken | P10 |
| Colors available for a second monitor accent | Only four palette keys are documented | P9 |
| Circled digits ①–⑩ in the mono font | Glyph fallback can break column alignment | Visual check |
| Memory and latency budgets | Numbers in the old spec were never measured | Section 10 |

Record every probe result in `docs/PROBES.md` with the command, the output and the date. Update this table when a row is settled.

## 3. Read and probe before you write code

Do this section first and do not skip it. The design is sound but the Omarchy and Hyprland integration points are version-sensitive, and the unverified table in section 2 is only closed by running these probes on a real machine with two monitors.

**Required reading, in order**

1. [Omarchy shell reference](https://github.com/omacom/omarchy/blob/quattro/docs/omarchy-shell.md) and the [plugins README](https://github.com/omacom/omarchy/blob/quattro/shell/plugins/README.md): manifest, plugin kinds, IPC, `Commons`.
2. The full source of [omarchy-jump-to](https://github.com/Matt-aaz/omarchy-jump-to): `manifest.json`, `JumpTo.qml`, `Model.js`. It is the nearest working example, so copy its patterns for loading, focus, icons and keybinding.
3. Quickshell docs for `Quickshell.Hyprland`, `PanelWindow`, `WlrLayershell` and `WlrKeyboardFocus`, plus the `Quickshell.Io` process types. Confirm the exact type names in the docs.
4. Qt Quick references for `Shape`, `ShapePath`, `PathQuad`, `SpringAnimation`, `Behavior`, and keyboard focus handling with `Keys`.
5. Hyprland wiki pages for IPC, dispatchers and layer rules, plus the [unofficial Lua API reference](https://alejandrominaya.github.io/hyprland-lua-docs/) for the `hl.*` calls. If a wiki page will not load, use the `hyprctl` output itself as the source of truth.
6. The [Omarchy hotkeys manual](https://learn.omacom.io/2/the-omarchy-manual/53/hotkeys).

When you finish reading you must be able to answer, in writing, in `docs/PROBES.md`:

- How does an overlay plugin declare its entry file, get summoned, and receive keyboard input?
- Where do theme colors come from, and which keys exist?
- How does jump-to list windows and focus one, on both Lua and legacy Hyprland configs?
- What is the namespace of the overlay window, and where does the layer rule go?

**Probes to run on the target machine**

Adjust paths if Omarchy 4.5 moved them. Save command, output and date for each.

```bash
# P1  versions and shell health
hyprctl version
quickshell --version
omarchy-shell shell ping
omarchy plugin list

# P2  monitors (note id, name, x, y, focused, activeWorkspace)
hyprctl monitors -j | jq '.[] | {id,name,x,y,width,height,focused,activeWorkspace}'

# P3  workspaces: switch workspaces on each monitor with Super+1..0, then record how
#     the local number (1-10) relates to the Hyprland id and name
hyprctl workspaces -j | jq '.[] | {id,name,monitor,monitorID,windows}'

# P4  clients: record the TYPE of .monitor (integer id or name string)
hyprctl clients -j | jq '.[] | {address,class,title,monitor,workspace,focusHistoryID}'

# P5  focus experiment, with a window on the OTHER monitor
ADDR=0x...   # take it from P4
hyprctl dispatch focuswindow address:$ADDR
hyprctl activewindow -j | jq '{address,monitor,workspace}'
# repeat from a different starting point with focusmonitor -> workspace -> focuswindow
# record which sequences land on the right window, monitor and workspace

# P6  Lua dispatch candidate (unofficial docs; confirm or correct)
hyprctl dispatch 'hl.dsp.focus({ window = "address:'$ADDR'" })'

# P7  events: commands go to .socket.sock, events stream from .socket2.sock
socat -u UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock -
# open, move and close windows, switch workspaces and monitors; record exact event names

# P8  clone jump-to and read manifest.json (note the overlay entry key), JumpTo.qml, Model.js

# P9  find the installed shell source; read Commons Color.qml and Style.qml; check whether a
#     first-party plugin imports Quickshell.Hyprland; find where layer rules for shell surfaces live
find / -path '*Commons*' -name 'Color.qml' 2>/dev/null
grep -rn 'Quickshell.Hyprland' <shell-source-dir>
grep -rn 'layer_rule' ~/.config/hypr <omarchy-default-dir> 2>/dev/null

# P10  keybind inventory: find a free chord
hyprctl binds -j | jq '.[] | select(.key=="Tab" or .key=="grave")'
grep -n -i -E 'tab|grave' ~/.config/hypr/bindings.lua
```

If a probe contradicts this brief, the probe wins. Update sections 2 and 5 and tell the user before building on the new fact.

## 4. Architecture

omarchy-tree is one pure-QML overlay plugin. It reads Hyprland state, draws the tree and sends one focus request. There is no daemon, no Python and no compiled module.

&#91;embedded content: architecture · 3 layers, 12 boxes\]

Read it top to bottom. The Omarchy shell summons and themes the plugin. The plugin turns Hyprland snapshots into a tree and a window. Hyprland supplies the data, the focus action and the blur.

**Components**

- **Model.js** holds pure functions: Hyprland JSON in, tree out. Keep it free of QML imports so it can be unit-tested with plain Node.
- **TreeState** owns the cursor, the fold state and the search filter, and exposes one flattened list of selectable rows.
- **Views** is a layer-shell `PanelWindow` with namespace `omarchy-tree`, exclusive keyboard focus, `Shape`-drawn connectors and colors from `Commons`.
- **Focus request** sends the dispatch described in section 5, then closes the panel.

**Decisions and why**

1. **Plugin, not a standalone app.** It inherits theming, summon IPC, hot reload (`rescanPlugins`) and one-command install.
2. **No daemon.** On any event, debounce briefly and refetch a full snapshot. Quickshell documents that many changes send no event, so incremental patching drifts.
3. **Data through `hyprctl -j`** run from a Quickshell process, as jump-to does, because `focusHistoryID` appears only in that payload. Use `Quickshell.Hyprland` only for the event signal, and only if probe P9 shows it imports inside a plugin.
4. **`keepLoaded: true`** keeps the window alive between summons so warm opens are fast.
5. **Blur is the compositor's job.** QML cannot blur what sits behind its window, so the glass depends on the layer rule in section 8.
6. **No C++.** The load is tens of windows and a few animated paths. A compiled module would add a Qt-on-Arch rebuild step and break install-from-Git. If a measured problem ever demands native code, write a separate helper binary that prints JSON.

**One use, end to end**

1. The keybind runs `omarchy-shell -q shell toggle <plugin-id>`.
2. `open()` fetches a snapshot, builds the tree and puts the cursor on the currently focused window.
3. The user moves, folds, searches or presses a workspace digit.
4. `Enter` sends one focus request and the panel closes.

## 5. Hyprland integration: snapshot, tree and focus

Every refresh fetches a full snapshot and rebuilds the tree from scratch. The model is a pure function, so it is easy to test and cannot drift.

**Snapshot sources**

- `hyprctl monitors -j`, `workspaces -j` and `clients -j`, run through a Quickshell process and parsed in `Model.js`.
- Refresh on `open()`, and on any Hyprland event while the panel is open, debounced to about 60 ms.
- If JSON is malformed or a command fails, keep the previous model, log the error and show nothing new.

**Model output (`Model.js` returns this shape)**

```json
{
  "focusedMonitor": "DP-1",
  "roots": [
    {
      "monitor": "DP-1", "x": 0, "y": 0, "width": 2560, "height": 1440, "focused": true,
      "workspaces": [
        {
          "id": 1, "number": 1, "exists": true, "active": true,
          "windows": [
            { "address": "0x...", "class": "Alacritty", "title": "~/omarchy/config",
              "focused": false, "focusHistoryID": 3 }
          ]
        }
      ]
    }
  ]
}
```

**Invariants the UI relies on**

- `roots` are ordered left to right by monitor `x`.
- `workspaces` are ordered by local number, 1 to 10, and every number is present for every monitor. Rows Hyprland does not list are synthesized with `exists: false` and `windows: []`. Confirm in probe P3 whether Hyprland lists empty workspaces at all.
- Every `address` is unique, and exactly one window in the whole tree has `focused: true`.
- `id` is what you dispatch with. `number` is what the user sees. If P3 shows they are always equal, drop `number`.
- `clients -j` may give `monitor` as an integer. Normalize it to a monitor name through the monitors list (probe P4).

**Focus dispatch**

The original draft claimed that `focusmonitor`, then `workspace`, then `focuswindow` was non-negotiable. That is unproven. Treat both of these as hypotheses and let probe P5 decide:

- **H1:** `focuswindow address:<addr>` alone moves focus to the right monitor and workspace.
- **H2:** the three-step sequence is required on the per-monitor workspace setup.

Implementation rules:

1. Keep the winning sequence in one small function, `focusSequence(window)`, driven by a constant that records the P5 result.
2. Use the Lua dispatcher form first and fall back to the legacy form, as jump-to does. Check `Hyprland.usingLua` if the import works, otherwise try Lua and fall back on error.
3. After dispatching, read `hyprctl activewindow -j`. If the address does not match, run the full three-step sequence once. If it still fails, refetch the snapshot, keep the panel open and flash the cursor row.
4. A digit on an empty workspace flashes the header and dispatches nothing. Switching to an empty workspace is already handled by `Super+N`.

**Edge cases**

- A monitor is unplugged or added: the next snapshot rebuilds the roots. Never keep addresses from an older snapshot.
- A window dies between render and `Enter`: the post-dispatch check catches it, as above.
- A browser window shows only its active tab title. That is expected and a stated non-goal.

## 6. UI behaviour

The cursor sits on rows the way Vim's cursor sits on a closed fold line. Workspace headers are selectable, which fixes a contradiction in the earlier draft where folding a workspace left the cursor with nowhere to be.

**Cursor model**

- Selectable rows, in order: for each monitor left to right, for each workspace that has windows, its header, then its windows if the workspace is unfolded.
- Empty workspaces render as one dim row and are skipped by `j` and `k`. A monitor root is selectable only when every workspace on it is empty.
- The cursor always belongs to a monitor. That monitor is the target of digit keys.
- On `open()` the cursor starts on the currently focused window.

**Keymap**

| Key | On a window | On a workspace header |
| --- | --- | --- |
| `j` / `k` | Move down / up across all monitors | same |
| `h` | Move to its workspace header | Fold it. Already folded: no-op |
| `l` | No-op | Unfold it. Already unfolded: move to its first window |
| `gg` / `G` | First / last selectable row | same |
| `1`–`0` | Move the cursor to that workspace's header on the cursor's monitor. If it is empty, flash its row and stay put | same |
| `Tab` | Move to the next monitor's first selectable row | same |
| `Ctrl+d` / `Ctrl+u` | Half-page down / up | same |
| `Enter` | Focus this window | Focus that workspace's most recently used window (lowest `focusHistoryID`) |
| `/` | Enter search | same |
| `q`, `Esc` | Close the panel | same |

A digit moves the cursor and does not dispatch. `Enter` is the only key that changes Hyprland focus. This is a default decision, not a verified requirement; ask the user before changing it.

**Search**

- `/` records the current cursor and moves keyboard focus into the search field. Match case-insensitively against window title, app class and workspace number.
- Non-matching rows fade to 18% opacity and lose color. The cursor snaps to the first match, and `j` and `k` walk matches only.
- `Enter` focuses the highlighted match. `Esc` restores the recorded cursor and the full tree.
- In tree mode the search field must not hold keyboard focus, or `j` and `k` will be typed into it.

**Fold state**

- Stored per Hyprland workspace id, in memory only, and lost on restart.
- Default is unfolded. It survives snapshot refreshes, so a window opening elsewhere never re-expands what the user folded.

**Input and mouse**

- The window takes exclusive keyboard focus while open, and releases it on close.
- A click on a row behaves like moving the cursor there and pressing `Enter`. Keyboard use is the canonical path.

## 7. Design guidelines

The look is a quiet glass panel with a living tree: thin curved connectors, one cursor, two accents, no icon noise. The visual reference is the [mockup canvas](https://claude.ai/artifact/QhGogJt5gtGxPMb8D5J2or) (private until its owner shares it). Match its structure, not its exact pixels.

**Theming**

- Import `qs.Commons as Commons` and take colors from `Commons.Color` (`background`, `foreground`, `accent`, `urgent`) and spacing, fonts and durations from `Commons.Style`. Never hard-code hex in components, so the panel follows theme switches.
- Derived tokens: dim text is `foreground` at about 55%; selection fill is `foreground` at 6–8%; panel fill is `background` at 80–86% alpha.
- Search matches use `accent`. The documented palette has no second accent, so derive monitor accents by rotating the hue of `accent` per monitor index (monitor 0 uses `accent` itself). If probe P9 finds a richer palette, prefer its named colors.
- Color is never the only signal. Focused monitor is a filled dot, an inactive one a hollow dot, and monitors keep their left-to-right order.

**Layout and type**

- Monitors render as side-by-side columns in physical left-to-right order. With more than three monitors, or a panel too narrow for the columns, stack them in one column. Traversal order is identical either way.
- Cap the panel height at about 70% of the screen and scroll vertically inside it.
- Use one monospace family from `Commons.Style` everywhere in the tree, so rows align. The mockup uses a sans face for a few header lines. Treat that as a mockup shortcut and follow this rule.
- Sizes: monitor name 15 px / 600, workspace header 13 px / 500, window title 13 px / 400, app class 11 px dim, search field 14 px, footer hints 11 px dim.
- Spacing scale 4 / 8 / 12 / 16 / 24 / 32 / 48. Panel padding 32, window row 28, workspace header 32, monitor header 56, indent 24, panel radius 24.

**Glyphs and connectors**

- Draw numerals, dots and fold chevrons as shapes. Do not rely on circled Unicode digits or box-drawing characters, because font fallback can break column alignment.
- Branch elbows are `Shape` paths (`PathQuad` or `PathCubic`) with a solid stroke at partial alpha, 1.5 px wide, radius about 6 px.
- A fading spine is a thin `Rectangle` with a vertical `gradient`, because a `ShapePath` stroke cannot take a gradient. Fade from about 60% to 8% down the branch.
- Empty-workspace connectors are dashed (`strokeStyle: ShapePath.DashLine`, short dash pattern) at about 12% alpha. Confirm the dash properties in the Qt docs.
- App icons are 18 px with a 4 px corner mask. When an icon is missing, draw a two-letter monogram circle.

**Glass and blur**

- The panel is a translucent rounded rectangle. Backdrop blur comes only from the Hyprland layer rule on the window's namespace, with `ignore_alpha` near 0.5 and `no_anim = true`.
- Draw the shadow with a Qt Quick effect available in the installed Qt. CSS-style shadow strings do not exist in QML.
- Dim the rest of the screen with a plain translucent scrim. Do not attempt to blur it in QML.

**Motion**

| Event | What moves | Time | Easing |
| --- | --- | --- | --- |
| Open | scale 0.96 to 1, opacity 0 to 1 | 180 ms | `OutCubic` |
| Close | scale to 0.97, opacity to 0 | 90 ms | `OutQuad` |
| Cursor move | cursor `y` | spring | `SpringAnimation` |
| Fold / unfold | height and elbow draw progress | 140 ms | `OutCubic` |
| Search filter | non-match opacity and saturation | 80 ms | linear |
| Empty-workspace flash | 6% white overlay fades | 180 ms | `OutCubic` |

Take every duration from `Commons.Style.duration()` so global animation settings apply. Only the cursor uses a spring, and only one spring property animates per element. Qt's `SpringAnimation` has `spring` (0–5 useful) and `damping` (0–1 useful), not stiffness. Start at `spring: 3`, `damping: 0.25`, and tune by eye. Those numbers are a starting point, not verified values.

**Accessibility modes**

- `OMARCHY_TREE_REDUCED_MOTION=1` turns off springs and makes every transition instant.
- `OMARCHY_TREE_HC=1` replaces glass with a solid background, full-contrast hairlines and no shadow.
- Expose each row to assistive tech with title, class, workspace number and monitor name.

## 8. Repo layout, manifest and packaging

Ship one Git repository that installs as a single Omarchy plugin. Do not write an install script that edits the user's Hyprland config.

**Repository layout**

```text
omarchy-tree/
  README.md              install, keybind, layer rule, troubleshooting
  LICENSE                MIT
  manifest.json          plugin manifest (kind: overlay)
  OmarchyTree.qml        entry Item: open(), close(), PanelWindow
  Model.js               pure: snapshot JSON in, tree out (Tree.js: cursor, fold, filter)
  TreeState.qml          thin QML wrapper over Tree.js
  components/            Panel, SearchBar, MonitorRoot, WorkspaceNode,
                         WindowRow, Elbow, Spine, CursorHalo, Footer
  hyprland/
    layer-rule.lua       blur rule to paste into the user's config
  docs/
    PROBES.md            probe results from section 3
  tests/
    model.test.js        unit tests, run with plain Node
    fixtures/            monitors.json, workspaces.json, clients.json
```

**Manifest (draft)**

```json
{
  "schemaVersion": 1,
  "id": "io.github.<owner>.omarchy-tree",
  "name": "Omarchy Tree",
  "version": "0.1.0",
  "author": "<owner>",
  "description": "Global monitor, workspace and window tree switcher",
  "kinds": ["overlay"],
  "keepLoaded": true,
  "entryPoints": { "<overlay-key>": "OmarchyTree.qml" }
}
```

`<overlay-key>` is unknown. The documented example only shows `barWidget` for bar widgets. Copy the exact key from omarchy-jump-to's `manifest.json` (probe P8) and record it in `docs/PROBES.md`.

**Install and development loop**

1. Develop with the repository symlinked into `~/.config/omarchy/plugins/<plugin-id>/`.
2. After each change run `omarchy-shell shell rescanPlugins` to hot-reload.
3. Summon with `omarchy-shell -q shell toggle <plugin-id>`. Hide with `hide <plugin-id>`.
4. Users install with `omarchy plugin add <git-url>`, then enable it with `omarchy plugin enable <plugin-id>`.

**Window namespace and layer rule**

Set the panel's layer-shell namespace to `omarchy-tree` through the `WlrLayershell` namespace property (confirm the property name in the Quickshell docs). Then ship this rule, adapted from the [Noctalia example](https://docs.noctalia.dev/noctalia/compositor-settings/hyprland/), in `hyprland/layer-rule.lua`:

```lua
hl.layer_rule({
  name = "omarchy-tree-blur",
  match = { namespace = "^omarchy-tree$" },
  blur = true,
  ignore_alpha = 0.5,
  no_anim = true,
})
```

Probe P9 decides where the rule belongs on Omarchy 4.5. The README must tell users exactly where to paste it, and the panel must still work, without blur, if they do not.

**Keybind**

Bind with `o.bind(...)` in `~/.config/hypr/bindings.lua`, running `omarchy-shell -q shell toggle <plugin-id>`. Copy the exact call shape from omarchy-jump-to rather than inventing it. Choose the chord after probe P10. Do not use `Super+Tab`, which is next workspace, and check `Super+~`, which the 4.5 release assigns to the AI console.

## 9. Implementation workflow

Build in eight phases, in order. Do not start a phase until the previous phase's exit criteria are met and you have reported them. Commit at the end of every phase.

1. **Probe.** Run section 3 in full.
   - Exit: probes P1 to P10 are recorded in `docs/PROBES.md`, the unverified table in section 2 is updated, the overlay manifest key is known, and the focus sequence (H1 or H2) is chosen.
2. **Model and tests.** Write `Model.js` and its tests first, using real `hyprctl -j` output from the target machine as fixtures. Remove or replace private window titles in the fixtures.
   - Exit: `node tests/model.test.js` passes. Fixtures cover two monitors, an empty workspace, a window on the second monitor, and monitors listed in the opposite order to their position.
3. **Plugin skeleton.** Write the manifest, the entry `Item` with `open()` and `close()`, the `PanelWindow` with namespace and exclusive keyboard focus, and the keybind.
   - Exit: the keybind toggles the panel, `Esc` closes it, and `rescanPlugins` hot-reloads edits. The panel may show raw text for now.
4. **Static render.** Build the components, theme tokens, connectors, icons and dimmed empty workspaces from the real model.
   - Exit: with real data the structure matches the mockup, colors change when the Omarchy theme changes, and nothing uses a hard-coded hex value.
5. **Interaction.** Add `TreeState`, the keymap, folding, search and cursor motion.
   - Exit: every UI test in section 10 passes, and no key reaches the search field in tree mode.
6. **Focus and live data.** Implement `focusSequence`, the post-dispatch check, debounced refresh and the error flash.
   - Exit: `Enter` lands correctly in all four cases on real hardware: same monitor and workspace, same monitor other workspace, other monitor same workspace number, and other monitor other workspace.
7. **Polish and accessibility.** Add motion, the blur layer rule, reduced-motion and high-contrast modes, and assistive-tech labels.
   - Exit: the measurements in section 10 meet their budgets, or the stated fallback is applied and recorded.
8. **Package and verify.** Write the README, then install on a clean user account with `omarchy plugin add`.
   - Exit: the fresh-install walkthrough works with only the keybind and layer rule added by hand, and the manual checklist in section 10 is signed off.

**How to run each phase**

- Read the relevant sections of this brief and the matching source files before writing code.
- Make the smallest change that meets the exit criteria, then run its tests.
- Finish with a short report: what changed, what you verified and how, what you could not verify, and any surprise that contradicts this brief.

## 10. Testing procedures

Test in three layers: pure-logic unit tests in Node, static checks, and a manual checklist on a real two-monitor machine. Keep all logic that can be pure (tree building, cursor traversal, fold, filter, focus command lists) in plain JS files such as `Model.js` and `Tree.js`, with the QML as a thin shell over them. Then it can be tested without a compositor.

**Unit tests (Node, `tests/`)**

| ID | Case | Expected result |
| --- | --- | --- |
| U1 | Two monitors, three workspaces, varied window counts | Tree depth and counts are correct |
| U2 | Monitors listed in the opposite order to their `x` | Roots are sorted left to right by `x` |
| U3 | Hyprland lists only some workspaces | Numbers 1 to 10 exist for every monitor; missing ones have `exists: false` |
| U4 | `clients -j` gives `monitor` as an integer | Normalized to the monitor name |
| U5 | Any snapshot | Addresses are unique and exactly one window is focused |
| U6 | Malformed or empty JSON | Previous model is kept, no exception escapes |
| U7 | `j` on the last row of monitor 0 | Cursor lands on the first row of monitor 1 |
| U8 | Fold a workspace, then refresh the snapshot | Fold persists; the cursor rests on the folded header |
| U9 | Search, then `j` and `k`, then `Esc` | Only matches are visited; the prior cursor is restored |
| U10 | Digit for an empty workspace | Row flashes, cursor stays, no dispatch is recorded |
| U11 | Digit for a populated workspace | Cursor moves to that header on the cursor's monitor, no dispatch |
| U12 | `open()` | Cursor starts on the focused window |
| U13 | `focusSequence` for the four focus cases, Lua and legacy | The recorded command list matches the P5 result |

The dispatch layer takes an injectable runner, so tests record commands instead of running them.

**Static checks**

- Run `qmllint` on every QML file and fix its warnings, or note why one is acceptable.
- Grep the source for hex color literals and for box-drawing characters. There must be none in component code.
- Reload with `omarchy-shell shell rescanPlugins` and confirm the plugin loads with no errors in the shell log.

**Manual checklist (two monitors, real hardware)**

- [ ] Focus works in all four cases from phase 6, including a window on the non-focused monitor.
- [ ] Unplug a monitor with the panel closed, then open it. The tree rebuilds and `Enter` never targets a stale address.
- [ ] Close a window while the panel is open, then press `Enter` on its row. The panel stays open and flashes the row.
- [ ] Switch the Omarchy theme. The panel recolors on the next open, with no restart.
- [ ] Blur is visible with the layer rule. Without it the panel is still readable and usable.
- [ ] In tree mode, `j` and `k` never appear in the search field.
- [ ] A window opening on another workspace does not re-expand a folded workspace.
- [ ] Hot-reloading the plugin while it is open never leaves the keyboard stuck. `Esc` always closes the panel.
- [ ] Pressing the keybind twice closes the panel.
- [ ] Browser rows show the current tab title and update on the next open.
- [ ] `OMARCHY_TREE_REDUCED_MOTION=1` removes all animation. `OMARCHY_TREE_HC=1` gives a solid, high-contrast panel.
- [ ] The monitor columns keep physical left-to-right order after swapping the monitors' arrangement.

**Performance measurements**

Measure with 40 windows spread over two monitors and ten workspaces each. Record the method and the numbers in `docs/PROBES.md`.

| Metric | Target |
| --- | --- |
| Open, first summon after login | ≤ 80 ms |
| Open, already loaded | ≤ 30 ms |
| Cursor move | ≤ 16 ms per frame |
| `Enter` to focus landed | ≤ 40 ms |

Use timestamps taken in QML at summon and at the first rendered frame, and a frame-timing tool such as `QSG_RENDER_TIMING=1` for the cursor. Also record the shell process's memory before and after opening the panel. The earlier draft's 60 MB figure was never measured, so report the real increase and do not treat it as a pass or fail. If a target is missed, drop the cursor trail and the shadow first, then report.

**Done means**

- Every unit test and static check passes.
- Every checklist item is ticked on real hardware, or has a written reason it cannot be.
- The report lists anything you could not verify. Do not claim a pass you did not observe.

## 11. Rules for the implementing agent

**Do**

- Read sections 2 and 3 before touching code, and let probe results override this brief.
- Copy proven patterns from omarchy-jump-to for plugin loading, window listing, focus and icons.
- Keep to scope. There is no daemon, no Python and no C++ in this project.
- Keep logic pure and tested. Keep QML thin.
- Take every color, duration and font from `Commons`.
- Make `Esc` and `q` always close the panel, so exclusive keyboard focus can never get stuck.
- Change only files in the plugin repository. Never edit the user's Hyprland or Omarchy config yourself. Give them the snippet and the path.
- Scrub private window titles from any fixture before committing it.

**Do not**

- Do not invent API names, manifest keys, dispatcher strings or palette keys. If you cannot confirm one in the docs, the source or a probe, mark it `TODO(verify)` and report it.
- Do not run commands that could end the user's session, such as `pkill` on the shell or compositor, or `hyprctl dispatch exit`.
- Do not install system packages without telling the user first.
- Do not claim a test passed, or a behaviour works, unless you observed it.

**When something is unclear**

1. Check the documentation and the jump-to source.
2. Run a probe on the machine and record it in `docs/PROBES.md`.
3. If it is still open, take the safest default, mark `TODO(verify)`, and carry on.
4. Report it at the end of the phase.

**Ask the user before deciding these**

- Whether a digit key only moves the cursor (the default in section 6) or also changes Hyprland focus.
- Side-by-side monitor columns (the default) or a single stacked column.
- The summon chord, the plugin id and the repository owner.
- Anything irreversible or outside the repository.

**Report at the end of each phase**

- What changed, in two or three lines.
- How you verified it, with the command or the observation.
- What you could not verify.
- Anything that contradicts this brief, with the evidence.

## 12. References and glossary

All links below were opened while preparing this brief on 2026-11-21. The Omarchy plugin docs come from the `quattro` (4.0) branch, so re-check them against 4.5.

**Sources**

- [Omarchy shell reference](https://github.com/omacom/omarchy/blob/quattro/docs/omarchy-shell.md)
- [Omarchy shell plugins README](https://github.com/omacom/omarchy/blob/quattro/shell/plugins/README.md)
- [Omarchy bar plugin README](https://github.com/omacom/omarchy/blob/quattro/shell/plugins/bar/README.md)
- [omarchy-jump-to, a working overlay plugin](https://github.com/Matt-aaz/omarchy-jump-to)
- [Omarchy 4.0 overview (Linuxiac)](https://linuxiac.com/arch-based-omarchy-4-0-quattro-is-here-with-its-biggest-desktop-overhaul-yet/)
- [Omarchy 4.5 (Linux Journal)](https://linuxjournal.com/content/omarchy-45-brings-floating-workspaces-native-apple-silicon-installation-and-more-flexible)
- [Omarchy manual: hotkeys](https://learn.omacom.io/2/the-omarchy-manual/53/hotkeys)
- [Quickshell.Hyprland](https://quickshell.org/docs/v0.3.2/types/Quickshell.Hyprland/Hyprland) and [HyprlandToplevel](https://quickshell.org/docs/v0.3.2/types/Quickshell.Hyprland/HyprlandToplevel)
- [Quickshell FloatingWindow](https://quickshell.org/docs/v0.3.2/types/Quickshell/FloatingWindow) and [WlrKeyboardFocus](https://quickshell.org/docs/v0.3.2/types/Quickshell.Wayland/WlrKeyboardFocus)
- [Qt SpringAnimation (mirror of older Qt docs)](https://stuff.mit.edu/afs/athena/software/texmaker_v5.0.2/qt57/doc/qtquick/qml-qtquick-springanimation.html)
- [Noctalia Hyprland layer rules](https://docs.noctalia.dev/noctalia/compositor-settings/hyprland/)
- [Hyprland Lua API reference (unofficial)](https://alejandrominaya.github.io/hyprland-lua-docs/)

**Not read successfully, so not relied on:** the Hyprland IPC wiki page and the Qt 6 SpringAnimation page. Socket roles and event names come from memory and must be probed (P7).

**Glossary**

| Term | Meaning here |
| --- | --- |
| Root | One monitor, the top level of the tree |
| Workspace | One of a monitor's workspaces, numbered 1 to 10 locally |
| Window row | A single client window, the leaf of the tree |
| Snapshot | The result of `hyprctl monitors, workspaces, clients -j` at one moment |
| Overlay plugin | An Omarchy plugin of kind `overlay`, summoned over the screen |
| Layer-shell | The Wayland protocol that lets a window sit above normal windows as a panel or overlay |
| Namespace | The layer-shell name Hyprland layer rules match against |
| Commons | The Omarchy shell's shared theme and style module (`qs.Commons`) |
| Dispatcher | A Hyprland action such as focusing a window, sent through `hyprctl dispatch` |
| Probe | A command run on the target machine to settle an unverified fact |
