const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");

// Load Model.js
const modelSrc = fs.readFileSync(path.join(__dirname, "../Model.js"), "utf8")
  .replace(/^\.pragma library\s*\n/, "");
// Load Tree.js
const treeSrc = fs.readFileSync(path.join(__dirname, "../Tree.js"), "utf8")
  .replace(/^\.pragma library\s*\n/, "");

const context = {};
vm.createContext(context);
vm.runInContext(modelSrc, context);
vm.runInContext(treeSrc, context);

const monFixture = fs.readFileSync(path.join(__dirname, "fixtures/monitors.json"), "utf8");
const wsFixture = fs.readFileSync(path.join(__dirname, "fixtures/workspaces.json"), "utf8");
const clFixture = fs.readFileSync(path.join(__dirname, "fixtures/clients.json"), "utf8");
const actFixture = fs.readFileSync(path.join(__dirname, "fixtures/activewindow.json"), "utf8");

const model = context.buildSnapshot(monFixture, wsFixture, clFixture, actFixture);
assert(model, "Model built");

// U12: open() -> cursor starts on the focused window
const state = context.makeState(model);
assert(state.rows.length > 0, "U12: rows generated");
const initialRow = state.rows[state.cursor];
assert(initialRow && initialRow.kind === "window", "U12: initial cursor on a window");
assert.strictEqual(initialRow.window.address, model.focusedAddress, "U12: initial cursor on focused window address");
assert.strictEqual(initialRow.window.focused, true, "U12: initial row window is focused");

// U7: j on the last row of monitor 0 lands on first row of monitor 1
// Find last selectable row of monitor 0
let lastMon0Index = -1;
for (let i = 0; i < state.rows.length; i++) {
  if (state.rows[i].monitor === "eDP-1" && state.rows[i].selectable) {
    lastMon0Index = i;
  }
}
assert(lastMon0Index >= 0, "Found last selectable row of monitor 0");
state.cursor = lastMon0Index;
context.move(state, 1);
assert.strictEqual(state.rows[state.cursor].monitor, "HDMI-A-1", "U7: j past last row of monitor 0 moves to monitor 1");

// U8: Fold a workspace, then refresh the snapshot: fold persists, cursor rests on folded header
const foldKey = "eDP-1:" + model.roots[0].workspaces[0].id + ":" + model.roots[0].workspaces[0].number;
state.folds[foldKey] = true;
const foldedRows = context.flatten(model, state.folds, "");
// Workspace 1 header should be present, but its window rows should not be in foldedRows
const ws1Header = foldedRows.find(r => r.kind === "workspace" && r.monitor === "eDP-1" && r.workspace.number === 1);
assert(ws1Header, "U8: Workspace 1 header present");
const ws1Win = foldedRows.find(r => r.kind === "window" && r.monitor === "eDP-1" && r.workspace.number === 1);
assert(!ws1Win, "U8: Folded workspace windows not present in flattened rows");

// U8b: Simplified fold key "monitor:number" also folds workspace
const simpFolds = { "eDP-1:1": true };
const simpFoldedRows = context.flatten(model, simpFolds, "");
const simpWs1Win = simpFoldedRows.find(r => r.kind === "window" && r.monitor === "eDP-1" && r.workspace.number === 1);
assert(!simpWs1Win, "U8b: Simplified fold key eDP-1:1 folds windows correctly");

// U9: Search, then j and k, then Esc restores recorded cursor
state.folds = {};
state.rows = context.flatten(model, state.folds, "");
state.cursor = context.initialCursor(state.rows, model);
const priorCursor = state.cursor;
state.recordedCursor = priorCursor;
state.search = "chrome";
state.rows = context.flatten(model, state.folds, state.search);

// Find matches
const matchedRows = state.rows.filter(r => r.matched && r.selectable);
assert(matchedRows.length > 0, "U9: Should have matched rows for 'chrome'");
state.cursor = context.firstSelectable(state);
assert(state.rows[state.cursor].matched, "U9: Cursor starts on a matched row");

// j and k only visit matched rows
context.move(state, 1);
assert(state.rows[state.cursor].matched, "U9: j steps only to a matched row");
context.move(state, -1);
assert(state.rows[state.cursor].matched, "U9: k steps only to a matched row");

// Esc clears search and restores recorded cursor
state.search = "";
state.rows = context.flatten(model, state.folds, "");
state.cursor = state.recordedCursor;
assert.strictEqual(state.cursor, priorCursor, "U9: Esc restores prior cursor");

// U10: Digit for an empty workspace: returns -1 (flash row, stay put, no dispatch)
// Find an empty workspace on HDMI-A-1 (e.g. workspace 5)
const emptyRes = context.moveToWorkspace(state, "HDMI-A-1", 5);
assert.strictEqual(emptyRes, -1, "U10: Digit for empty workspace returns -1 (no cursor move)");

// U11: Digit for populated workspace: moves cursor to header on cursor's monitor, no dispatch
const populatedRes = context.moveToWorkspace(state, "HDMI-A-1", 1);
assert(populatedRes >= 0, "U11: Digit for populated workspace moves cursor");
assert.strictEqual(state.rows[state.cursor].kind, "workspace", "U11: Cursor on workspace header");
assert.strictEqual(state.rows[state.cursor].workspace.number, 1, "U11: Cursor on workspace number 1");
assert.strictEqual(state.rows[state.cursor].monitor, "HDMI-A-1", "U11: Cursor on cursor's monitor");

// U14: prevMonitor and nextMonitor jumping (Ctrl+H / Ctrl+L)
// Prior test (U11) left cursor on HDMI-A-1
assert.strictEqual(state.rows[state.cursor].monitor, "HDMI-A-1");
context.nextMonitor(state);
assert.strictEqual(state.rows[state.cursor].monitor, "eDP-1", "U14: nextMonitor from HDMI-A-1 wraps to eDP-1");
context.prevMonitor(state);
assert.strictEqual(state.rows[state.cursor].monitor, "HDMI-A-1", "U14: prevMonitor from eDP-1 wraps back to HDMI-A-1");
context.prevMonitor(state);
assert.strictEqual(state.rows[state.cursor].monitor, "eDP-1", "U14: prevMonitor from HDMI-A-1 jumps to eDP-1");
context.nextMonitor(state);
assert.strictEqual(state.rows[state.cursor].monitor, "HDMI-A-1", "U14: nextMonitor from eDP-1 jumps to HDMI-A-1");

// U15: Vim-inspired nextMatch and prevMatch navigation
state.search = "chrome";
state.rows = context.flatten(model, state.folds, state.search);
state.cursor = context.firstSelectable(state);
const firstMatchCursor = state.cursor;
assert(state.rows[firstMatchCursor].matched, "U15: starts on first match");
assert.strictEqual(state.rows[firstMatchCursor].kind, "window", "U15: search lands on matching window");

const matchCount = state.rows.filter(r => r.matched && r.selectable && r.kind === "window").length;
assert(matchCount > 1, "U15: multiple chrome windows in fixture");
if (matchCount > 1) {
  context.nextMatch(state);
  assert.notStrictEqual(state.cursor, firstMatchCursor, "U15: nextMatch moved to next match");
  assert.strictEqual(state.rows[state.cursor].kind, "window", "U15: nextMatch lands on window row");
  assert(state.rows[state.cursor].matched, "U15: nextMatch lands on matched row");
  
  context.prevMatch(state);
  assert.strictEqual(state.cursor, firstMatchCursor, "U15: prevMatch returned to first match");
}

console.log("tree tests (U7-U12, U14, U15) passed");
