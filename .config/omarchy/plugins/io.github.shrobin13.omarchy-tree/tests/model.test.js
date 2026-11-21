const assert = require("assert");
const fs = require("fs");
const vm = require("vm");

const source = fs.readFileSync(__dirname + "/../Model.js", "utf8")
  .replace(/^\.pragma library\s*\n/, "");
const context = {};
vm.createContext(context);
vm.runInContext(source, context);

const monitors = JSON.stringify([
  { id: 1, name: "HDMI-A-1", x: 1920, y: 0, width: 1920, height: 1080, focused: true },
  { id: 0, name: "eDP-1", x: 0, y: 0, width: 1920, height: 1080, focused: false }
]);
const workspaces = JSON.stringify([
  { id: 11, name: "11", monitor: "HDMI-A-1", monitorID: 1, windows: 1 },
  { id: 1, name: "1", monitor: "eDP-1", monitorID: 0, windows: 1 }
]);
const clients = JSON.stringify([
  { address: "0xaaa", class: "kitty", title: "Terminal", monitor: 1, workspace: { id: 11, name: "11" }, focusHistoryID: 1, focused: true },
  { address: "0xbbb", class: "chrome", title: "Browser", monitor: 0, workspace: { id: 1, name: "1" }, focusHistoryID: 2, focused: false }
]);

const model = context.buildSnapshot(monitors, workspaces, clients);
assert(model);
assert.deepStrictEqual(Array.from(model.roots, root => root.monitor), ["eDP-1", "HDMI-A-1"]);
assert.strictEqual(model.roots[0].workspaces.length, 10);
assert.strictEqual(model.roots[1].workspaces.length, 10);
assert.strictEqual(model.roots[1].workspaces[0].windows.length, 1);
assert.strictEqual(model.focusedAddress, "0xaaa");

assert.strictEqual(context.buildSnapshot("{", workspaces, clients), null);

const sequence = context.focusSequence("0xaaa", "HDMI-A-1", 11);
assert.strictEqual(sequence.length, 3);
assert.strictEqual(sequence[0].mode, "lua");
assert.strictEqual(sequence[1].mode, "legacy");
assert.strictEqual(sequence[2].mode, "fallback");

assert.strictEqual(context.focusSequence("bad-address", "HDMI-A-1", 11).length, 0);

console.log("model tests passed");
