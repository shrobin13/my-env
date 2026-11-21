# omarchy-tree — Implementation Audit

**Date:** 2026-11-21
**Auditor:** OpenCode agent
**Subject:** `io.github.shrobin13.omarchy-tree` v0.1.0, compared against `docs/IMPLEMENTATION_BRIEF.md` and `docs/WINDOW_TREE_MOCKUP.html`
**Machine:** Hyprland 0.56.2, Quickshell 0.3.2, two 1920×1080 monitors (`eDP-1` at x=0, focused `HDMI-A-1` at x=1920), 10 live clients, Lua-based Hyprland config.

---

## 1. Method

1. Unpacked all three frames embedded in `docs/WINDOW_TREE_MOCKUP.html` (main view, filtered search, folded overview) into standalone HTML and read their rendered DOM/CSS.
2. Read every file in the plugin: `manifest.json`, `Model.js`, `Tree.js`, `OmarchyTree.qml`, `hyprland/layer-rule.lua`, `README.md`, `tests/*.test.js`, `docs/PROBES.md`.
3. Ran the existing unit tests with Node.
4. Ran **live** `hyprctl` probes (monitors/workspaces/clients/activewindow/binds/dispatch), fed live JSON through `Model.js`, and compared its output with `hyprctl activewindow -j`.
5. Summoned the real overlay with `omarchy-shell -q shell toggle …`, captured the screen with `grim`, inspected the panel, then hid it.
6. Checked installed state: plugin enablement, keybind, layer rule, Lua dispatcher availability.

Screenshots and unpacked mockup frames are in `/tmp/opencode/` (`overlay.png`, `overlay_crop2.png`, `inner_main.html`, `inner_search.html`, `inner_folded.html`) for reproducibility.

---

## 2. What is verified working

| Check | Result | Evidence |
| --- | --- | --- |
| Plugin is installed and enabled | Pass | `omarchy-shell shell ping` → `ok`; `~/.config/omarchy/shell.json:116` lists the plugin id |
| Manifest overlay key | Pass | `manifest.json` uses `"entryPoints": {"overlay": "OmarchyTree.qml"}`, matching the jump-to pattern recorded in PROBES.md P8 |
| Keybind is loaded | Pass | `hyprctl binds -j` → `{"key":"V","modmask":65,"description":"Window tree"}` (65 = Super+Shift) |
| Layer rule ships and is wired in this dotfiles install | Pass | `hyprland/layer-rule.lua` matches the brief; rule present at `~/.config/hypr/bindings.lua:61-67` |
| No hard-coded hex / box-drawing characters | Pass | `grep -rn -E '#[0-9a-fA-F]{3,8}' --include='*.qml' --include='*.js' .` → no hits |
| Monitors sorted left-to-right | Pass | `Model.js:52` sorts by `x`, then `y`, then name; live order `eDP-1`, `HDMI-A-1` is correct |
| Integer `monitor` normalization | Pass | `Model.js:99-104` resolves integer IDs via `monitorById`; live integer IDs resolve correctly |
| Workspace numbers 1–10 synthesized | Pass | `Model.js:160-176` emits all ten slots with `exists:false` for missing ones; unit test asserts length 10 |
| Unit tests run | Pass | `node tests/model.test.js` → `model tests passed`; `node tests/tree.test.js` → `tree tests passed` |
| Toggle / hide commands | Pass | `omarchy-shell -q shell toggle …` and `hide …` returned without errors; panel opened and closed |
| Primary Lua focus dispatcher | Pass | `hyprctl dispatch "hl.dsp.focus({ window = \"address:<active>\" })"` → `ok` (no-op on active window) |
| Theme tokens sourced from Commons | Pass (static) | `OmarchyTree.qml` uses `Color.background/foreground/accent` and `Style.duration()` throughout |

---

## 3. Findings

Severity: **C** = breaks a core promise of the brief; **H** = significant deviation from mockup/brief; **M** = behavioural defect; **L** = polish gap.

### C1 — Focused window is never detected on the installed Hyprland (U5, U12 fail on real data)

`hyprctl clients -j` on Hyprland 0.56.2 has **no `focused` field**. Keys are `address, mapped, hidden, visible, …, focusHistoryID, …`; `.[0] | has("focused")` → `false`. Focus is conveyed by `focusHistoryID == 0` and by `hyprctl activewindow -j`.

`Model.js:131` does:

```js
var focused = client.focused === true || (isObject(client.focused) && client.focused === true);
```

This is always `false`. Consequences, measured live:

```
windows = 10   windows with focused:true = 0
focusedAddress = 0x560b9fc39ba0          (fallback windows[0], focusHistoryID 9)
LIVE activewindow address = 0x560ba045fc20 (focusHistoryID 0)
```

- `focusedAddress` is the wrong window, so `rebuildTree()` (`OmarchyTree.qml:107-114`) places the cursor on the wrong row at open.
- The tree contains zero rows with `focused: true`, violating the invariant in brief §5 and unit test U5.
- The unit test masks this because its fixture (`tests/model.test.js:20-21`) invents `focused: true/false` fields that the real payload does not contain.

**Fix:** derive the focused address from `client.focusHistoryID === 0` (or from a `hyprctl activewindow -j` snapshot) and mark exactly one window focused; update the fixture to real 0.56.2 output.

### C2 — All legacy dispatch fallbacks are broken on this machine's Lua config

The brief requires focus to work on both Lua and legacy configs (§5 rule 2). On the installed Lua config, every legacy dispatcher string fails to parse:

```
$ hyprctl dispatch focuswindow "address:0x…"
error: [string "return hl.dispatch(focuswindow address:0x…"]:1: ')' expected near 'address'
$ hyprctl dispatch workspace 12
error: [string "return hl.dispatch(workspace 12)"]:1: ')' expected near '12'
$ hyprctl dispatch "hl.dsp.workspace({workspace = 12})"
error: … attempt to call a table value (field 'workspace')
```

Only `hl.dsp.focus({ window = "address:…" })` works (returns `ok`). Therefore:

- `Model.js:226` inline fallback, `Model.js:228` "legacy" mode, and `Model.js:231-236` three-step fallback cannot execute here.
- `OmarchyTree.qml:425` (`fallbackProc.command = sequence[last].command`) is dead on this config: after a failed primary dispatch, the fallback also fails and the panel flashes/opens on stale state.
- `OmarchyTree.qml:299` `switchWorkspace()` is dead as well.

Note this **contradicts PROBES.md P5/P6** ("direct `hyprctl dispatch focuswindow …` moved focus successfully"). That probe should be re-run and the record corrected; the Lua dispatcher is the only working form on the current config.

**Fix:** generate the correct Lua dispatcher form for `focusmonitor`/`workspace` (or use Lua `hl.dispatch` equivalents), keep the legacy form only for legacy configs, and verify with a post-dispatch address check as already architectured.

### C3 — Digit keys dispatch a workspace switch, contrary to brief §6

`moveToDigit()` calls `root.switchWorkspace(workspace.id)` at `OmarchyTree.qml:222`. Brief §6 states: *"A digit moves the cursor and does not dispatch. `Enter` is the only key that changes Hyprland focus."* It also labels this a default needing user confirmation before change.

Independently, dispatching `workspace <id>` is wrong on per-monitor workspaces: it acts on the **focused** monitor, not the cursor's monitor. Here HDMI-A-1's local workspace 1 has id `11`; pressing `1` while the cursor is on HDMI-A-1 but eDP-1 is focused would try to move eDP-1 to workspace 11.

This behaviour is untested (U10/U11 do not exist in the test suite). Decide with the user: remove the dispatch (brief default), or implement a correct per-monitor switch with focus restoration.

---

### H1 — The rendered UI is a flat text list, not the mockup's tree

The live screenshot (`/tmp/opencode/overlay_crop2.png`) shows a single 760×680 panel containing a plain monospaced list:

```
Window Tree
[1] eDP-1
    google-chrome  qml - Google Search - Google Chrome
[2] eDP-1
    kitty  ~/omarchy/plugins/user.global-workspace-tree
[3] eDP-1
    GitHub Desktop
[4] eDP-1  empty
...
```

The mockup's main frame (`inner_main.html:468-545`) and brief §7 call for, and the implementation lacks:

| Mockup / brief element | Implemented? |
| --- | --- |
| Two side-by-side monitor columns with headers + meta (`primary · 2560×1440 · focused`) | No — one flat list; monitor name repeated on every row |
| Filled vs hollow monitor dots; per-monitor accent hue rotation | No — no dots; single `Color.accent` |
| Circled number badges, workspace label (`nvim · htop`), window count | No — `[n]` text only |
| Curved `ShapePath` elbows and fading `Rectangle` gradient spines, dashed empty-workspace connectors | No — `components/` directory does not exist |
| Fold chevrons drawn as shapes / icons | No |
| 18 px app icons with monogram fallback | No — app class is text |
| Cursor dot + halo and spring-animated cursor movement | No — selection is a static background rectangle; no `CursorHalo` |
| Persistent search bar (`/ filter windows`) | No — `TextInput` only exists when `searchMode` is true |
| Footer with keycap-styled hints and `10 windows · 2 monitors` | Partly — plain-text hints, no counts |
| Load/close/fold/search motion per §7 table | Partly — only panel opacity/scale; no spring, no fold animation, no filter animation |

The brief says "match its structure, not its exact pixels" (§7). The structural mismatch is large: this is a different information design, not a pixel difference.

### H2 — Search removes rows instead of fading them; Esc does not restore the cursor (U9)

Mockup search frame keeps every row visible and applies `.dim` to non-matches (`inner_search.html:485-510`), and brief §6 says non-matching rows "fade to 18% opacity and lose color". `Tree.js:36` instead `continue`s past non-matching workspaces, so they are **removed** from `rows`. Consequently the opacity logic at `OmarchyTree.qml:540` (`0.18`) is effectively dead code — no row is ever both present and unmatched. No saturation/color change is applied.

Brief §6 also says Esc restores the recorded cursor. `Tree.js:9` declares `recordedCursor: 0` but it is never written or read anywhere (`grep -rn recordedCursor` → one hit). `exitSearch()` (`OmarchyTree.qml:344-349`) just clears the text and rebuilds, leaving the cursor where the search snapped it.

### H3 — `j`/`k` visit empty workspace rows; no monitor-root row

Brief §6: empty workspaces render as one dim row **and are skipped by `j` and `k`**; a monitor root is selectable only when all its workspaces are empty. `Tree.js:38` emits a selectable `workspace` row for all 10 slots, and `move()` / `OmarchyTree.qml:146-159` step through every row. With 2 monitors and 10 windows there are 30 rows, 20 of which are workspace headers — most of them empty. The screenshot confirms the long, mostly-empty list.

### H4 — Test suite covers only a fraction of the mandated cases

Brief §10 defines U1–U13. Present coverage:

| Case | Status |
| --- | --- |
| U1 two monitors / varied counts | Partial (2 monitors, 1 workspace, 1 window each) |
| U2 monitor order | Covered |
| U3 ten workspaces / `exists:false` | Partial (length 10 asserted, `exists` not asserted) |
| U4 integer monitor | Partial (fixture integer, no explicit assertion) |
| U5 unique addresses / one focused | **Not covered — and fails live (C1)** |
| U6 malformed / empty JSON | Partial (only `"{"`) |
| U7–U13 (cursor traversal, fold, search, digits, open, focusSequence cases) | **Not covered** |

`tests/fixtures/` (required by §8 and §9 phase 2) does not exist. `focusSequence` is checked only for length and mode names, not for the emitted commands or the four focus cases (U13). `qmllint` is not installed on this machine, so the static check in §10 could not be run at all.

### H5 — Probe record and sign-off are incomplete

`docs/PROBES.md` records P1, P3/P4, P5, P6 (two entries), P8, P9, P10. **P2 (monitors) and P7 (event stream) are not recorded**; the four questions required by §3 are not answered in prose. The manual checklist (§10) has all 12 items unchecked, and no cold/warm/cursor/Enter timing or memory numbers are recorded, though §9 phase 7 and §10 require them. Per §11, these cannot be claimed as passed.

---

### M1 — `h` on a folded workspace reopens it

Brief §6: `h` on a workspace header folds it; *already folded: no-op*. `foldOrUnfoldWorkspace()` (`OmarchyTree.qml:161-169`) toggles, so a second `h` unfolds. `l` already unfolds, so `h` should not.

### M2 — Flash highlights the whole panel, not the row

Brief §5/§6/§7: a failed digit on an empty workspace flashes **that row**; a failed focus flashes **the cursor row**. `flashWorkspace()` stores `monitor:number`, but the only consumer (`OmarchyTree.qml:590-595`) is a full-panel `Rectangle` overlay. No per-row comparison exists, and `focusFailed()` passes number `0` (`OmarchyTree.qml:250`), which can never match a real row.

### M3 — Window list scrolls through 20 empty slots before reaching other monitors

Consequence of H1/H3: with two monitors, HDMI-A-1's rows begin below eDP-1's ten workspace rows, so `Tab`/`j` traversal is long and the "next monitor" jump targets an empty header rather than a window. The panel's fixed 680 px height shows roughly half the rows; no width-responsive stacked/side-by-side switch exists.

### M4 — Snapshot failure can leave `awaitingReply` stuck

`finishSnapshot()` (`OmarchyTree.qml:71-86`) returns early if any of the three JSON strings is empty, before clearing `root.awaitingReply`. If a `hyprctl` process fails, that flag stays `true` (currently unused elsewhere, but latent state drift). The `clientsProc.onExited` branches at lines 395-397 both call `finishSnapshot()`, so a failed command is not distinguished from a successful one.

### M5 — README blur guidance is dotfiles-specific

Brief §8: README must tell users exactly where to paste the layer rule and must not edit their config. The README says the "managed dotfiles configuration already includes … guidance" rather than giving the path/snippet generically. This works for this fork but not for a fresh `omarchy plugin add` user.

### L1 — No cursor spring / fold / filter animation

Only panel opacity+scale have `Behavior` animations (`OmarchyTree.qml:465-472`). The §7 motion table's cursor spring, fold height/elbow progress, filter fade and flash fade are absent or approximated. `reducedMotion`/`highContrast` env flags are implemented, but only the panel-level parts are affected.

---

## 4. Mockup vs actual UI (summary)

| Aspect | Mockup | Actual (screenshot) |
| --- | --- | --- |
| Layout | 1080 px glass panel, two 480 px monitor columns, 56 px gap | 760×680 panel, single flat column |
| Monitor identity | Header per column: dot, name, `primary · 2560×1440 · focused` | Monitor name repeated inline on every row `[n] eDP-1` |
| Workspaces | Circled number, label of app classes, count, chevron | `[n]` + monitor name; `empty` text; no count/chevron |
| Windows | Icon + app + title + cursor dot; selected row halo | App class + title text; selection = 8% background |
| Connectors | Fading spine + curved elbows + dashed empties | None |
| Search | Always-visible pill with `/ filter windows` and `esc` key | Hidden `TextInput`, appears only after `/` |
| Footer | Keycaps + `10 windows · 2 monitors` | Plain hint string |
| Color | Two monitor accents, dim/selected states, glow | One accent for all `[n]`, dim class text |

Colors do follow the current Omarchy theme (cyan accent is visible), which satisfies the static part of §7; live recolour on theme switch is not verified (see §6).

---

## 5. Workflow / definition-of-done compliance (brief §1, §9)

| Phase / requirement | Status | Note |
| --- | --- | --- |
| 1 Probe | Partial | P2 and P7 missing; P5 result contradicted by live dispatch; §3 prose answers not written |
| 2 Model + tests | Partial | Tests pass but use invented `focused` fields; no fixtures directory; real data fails U5/U12 |
| 3 Plugin skeleton | Done | Manifest, `open()/close()`, PanelWindow namespace, exclusive focus, keybind all present and load |
| 4 Static render | Not met | Structure does not match mockup; no components; theme tokens used but no connectors/icons/dots |
| 5 Interaction | Partial | Keymap mostly implemented; fold/search/cursor deviations (H2, H3, M1) |
| 6 Focus + live data | Not met | Primary Lua focus works; every fallback and digit dispatch is broken on this config (C2, C3) |
| 7 Polish + accessibility | Partial | Env flags present; motion/components/labels incomplete; no measurements |
| 8 Package + verify | Partial | `omarchy plugin add` path documented; manual checklist unticked; clean-account install not observed |
| Cold ≤80 ms / warm ≤30 ms / cursor ≤16 ms / Enter ≤40 ms | Not measured | No timestamps recorded in PROBES.md |
| Manual two-monitor checklist | Unticked | 0 of 12 items verified |

---

## 6. What could not be verified

- **Theme recolour without restart** — switching the Omarchy theme edits user config, which this audit must not do. Static bindings look correct; recolor was not observed.
- **Blur with/without the layer rule** — the panel renders as a dark translucent rectangle; blur could not be visually isolated from the 0.86-alpha fill and 0.35 scrim.
- **Cross-monitor focus in all four combinations** — not exercised, to avoid disrupting the active session; C2/C3 are established from dispatcher output and source instead.
- **`q`/`Esc` never leaving keyboard stuck, hot-reload while open, dead-window Enter, monitor unplug** — require interactive/live manipulation; checklist remains unticked.
- **`qmllint` warnings** — binary is not installed on this machine.
- **Performance budgets** — no timing instrumentation was found or run.

---

## 7. Recommended fix order

1. **C1:** detect focus from `focusHistoryID`/`activewindow`; regenerate fixtures from real 0.56.2 output; add U5/U12 tests.
2. **C2:** implement Lua-correct dispatchers for all focus steps; re-run and correct PROBES.md P5/P6; add U13 with recorded commands and the post-dispatch fallback test.
3. **C3:** confirm with the user whether digits move only the cursor (brief default) or also switch workspace; if switching, target the cursor's monitor correctly.
4. **H1:** build `components/` and render two monitor columns with headers, dots, badges, counts, connectors, icons and a real cursor/halo (phase 4 exit criteria).
5. **H2:** keep non-matching rows and dim them; record and restore `recordedCursor` on Esc.
6. **H3:** make empty workspace rows non-selectable; add a selectable monitor-root row when a monitor has no windows.
7. **H4/H5:** add U6–U13, `tests/fixtures/`, missing probes P2/P7, manual checklist results and performance numbers; install `qmllint` or document why it cannot be run.
8. **M/L items:** fold semantics, row-level flash, snapshot error state, README generality, motion table.

---

## 8. Evidence appendix (commands and outputs)

```text
$ hyprctl version                      → Hyprland 0.56.2
$ quickshell --version (PROBES.md P1)  → 0.3.2
$ omarchy-shell shell ping             → ok

$ hyprctl monitors -j | jq '.[]|{id,name,x,y,focused,activeWorkspace}'
  eDP-1     id 0 x 0    focused false activeWorkspace id 3  name "3"
  HDMI-A-1  id 1 x 1920 focused true  activeWorkspace id 12 name "12"

$ hyprctl clients -j | jq '.[0] | keys[]' | grep -i focus
  focusHistoryID            # no "focused" key
$ hyprctl clients -j | jq '.[0] | has("focused")'
  false
$ hyprctl activewindow -j | jq '{address,focusHistoryID}'
  { "address": "0x560ba045fc20", "focusHistoryID": 0 }

$ node - <<'EOF'   # real data through Model.js
  ...
  focusedMonitor = HDMI-A-1
  focusedAddress = 0x560b9fc39ba0
  windows = 10   windows with focused:true = 0
LIVE activewindow address = 0x560ba045fc20 (focusHistoryID 0)
EOF

$ hyprctl dispatch 'hl.dsp.focus({ window = "address:0xdeadbeef" })'
  warning: =[C]:-1: hl.focus: window not found       # dispatcher exists
$ hyprctl dispatch "hl.dsp.focus({ window = \"address:0x560ba045fc20\" })"
  ok                                                  # working form
$ hyprctl dispatch focuswindow address:0x560ba045fc20
  error: ... ')' expected near 'address'              # legacy form broken
$ hyprctl dispatch workspace 12
  error: ... ')' expected near '12'                   # legacy form broken
$ hyprctl dispatch "hl.dsp.workspace({workspace = 12})"
  error: ... attempt to call a table value            # Lua form also unusable

$ hyprctl binds -j | jq '.[]|select(.description=="Window tree")'
  {"key":"V","modmask":65,"description":"Window tree","arg":"330"}

$ node tests/model.test.js   → model tests passed
$ node tests/tree.test.js    → tree tests passed

$ omarchy-shell -q shell toggle io.github.shrobin13.omarchy-tree
$ grim /tmp/opencode/overlay.png
$ omarchy-shell -q shell hide io.github.shrobin13.omarchy-tree
  → no errors; panel opened and closed; screenshot matches §4 "Actual" column
```

**Bottom line:** the plugin installs, loads, binds and renders a themed, keyboard-driven list, but it does not yet meet the brief's definition of done. Two defects (C1, C2) break focus correctness on the installed machine, and the UI is a flat list rather than the mockup's tree.
