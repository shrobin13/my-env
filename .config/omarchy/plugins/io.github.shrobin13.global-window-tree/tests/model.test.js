const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const source = fs.readFileSync(path.join(__dirname, "../Model.js"), "utf8")
  .replace(/^\.pragma library\s*\n/, "");
const context = {};
vm.createContext(context);
vm.runInContext(source, context);

// Fixtures
const monFixture = fs.readFileSync(path.join(__dirname, "fixtures/monitors.json"), "utf8");
const wsFixture = fs.readFileSync(path.join(__dirname, "fixtures/workspaces.json"), "utf8");
const clFixture = fs.readFileSync(path.join(__dirname, "fixtures/clients.json"), "utf8");
const actFixture = fs.readFileSync(path.join(__dirname, "fixtures/activewindow.json"), "utf8");

// U1: Two monitors, three workspaces, varied window counts
const modelLive = context.buildSnapshot(monFixture, wsFixture, clFixture, actFixture);
assert(modelLive, "modelLive should parse successfully");
assert.strictEqual(modelLive.roots.length, 2, "U1: must have 2 monitor roots");
assert(modelLive.totalWindows > 0, "U1: totalWindows should be positive");

// U2: Monitors listed in opposite order of x -> roots sorted left to right
const reversedMonitors = JSON.stringify([
  { id: 1, name: "HDMI-A-1", x: 1920, y: 0, width: 1920, height: 1080, focused: true },
  { id: 0, name: "eDP-1", x: 0, y: 0, width: 1920, height: 1080, focused: false }
]);
const modelU2 = context.buildSnapshot(reversedMonitors, wsFixture, clFixture, actFixture);
assert.deepStrictEqual([...modelU2.roots.map(r => String(r.monitor))], ["eDP-1", "HDMI-A-1"], "U2: roots must be sorted left to right");

// U3: Numbers 1 to 10 exist for every monitor; missing ones have exists: false
for (const root of modelLive.roots) {
  assert.strictEqual(root.workspaces.length, 10, "U3: every root must have 10 workspace slots");
  for (let n = 1; n <= 10; n++) {
    const ws = root.workspaces[n - 1];
    assert.strictEqual(ws.number, n, "U3: workspace slot must have number " + n);
    if (ws.windows.length === 0 && !ws.active && !ws.exists) {
      assert.strictEqual(ws.exists, false, "U3: missing empty workspace must have exists: false");
    }
  }
}

// U4: clients -j gives monitor as integer ID -> normalized to monitor name
const clientsWithIntegerMonitor = JSON.stringify([
  { address: "0x111", class: "kitty", title: "term", monitor: 1, workspace: { id: 11, name: "11" }, focusHistoryID: 0 }
]);
const modelU4 = context.buildSnapshot(reversedMonitors, wsFixture, clientsWithIntegerMonitor, "");
const hdmiRoot = modelU4.roots.find(r => r.monitor === "HDMI-A-1");
assert(hdmiRoot, "HDMI-A-1 root exists");
const ws11 = hdmiRoot.workspaces.find(w => w.number === 1);
assert.strictEqual(ws11.windows.length, 1, "U4: window with integer monitor 1 mapped to HDMI-A-1");
assert.strictEqual(ws11.windows[0].monitor, "HDMI-A-1", "U4: monitor normalized to string name");

// U5: Unique addresses and exactly one window is focused
const addresses = new Set();
let focusedCount = 0;
for (const root of modelLive.roots) {
  for (const ws of root.workspaces) {
    for (const win of ws.windows) {
      assert(!addresses.has(win.address), "U5: window address must be unique: " + win.address);
      addresses.add(win.address);
      if (win.focused) focusedCount++;
    }
  }
}
assert.strictEqual(focusedCount, 1, "U5: exactly one window must have focused: true");
assert.strictEqual(modelLive.focusedAddress, JSON.parse(actFixture).address, "U5: focusedAddress matches live active window");

// U6: Malformed or empty JSON
assert.strictEqual(context.buildSnapshot("{", wsFixture, clFixture, actFixture), null, "U6: malformed monitors returns null");
assert.strictEqual(context.buildSnapshot(monFixture, "invalid", clFixture, actFixture), null, "U6: malformed workspaces returns null");
assert.strictEqual(context.buildSnapshot("", wsFixture, clFixture, actFixture), null, "U6: empty string returns null");

// U13: focusSequence generates Lua primary, legacy fallback, and monitor-switch fallback
const seq = context.focusSequence("0x560ba045fc20", "HDMI-A-1", 12);
assert.strictEqual(seq.length, 3, "U13: sequence has 3 steps");
assert.strictEqual(seq[0].mode, "lua");
assert(seq[0].command.join(" ").includes('hl.dsp.focus({ window = "address:0x560ba045fc20" })'), "U13: lua command syntax");
assert.strictEqual(seq[1].mode, "legacy");
assert.strictEqual(seq[1].command.join(" "), "hyprctl dispatch focuswindow address:0x560ba045fc20", "U13: legacy command syntax");
assert.strictEqual(seq[2].mode, "fallback");
assert(seq[2].command.join(" ").includes("hl.dsp.focus({ monitor ="), "U13: fallback monitor focus");

console.log("model tests (U1-U6, U13) passed");
