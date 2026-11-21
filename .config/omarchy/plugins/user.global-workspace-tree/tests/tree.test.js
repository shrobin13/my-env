const assert = require("assert");
const fs = require("fs");
const vm = require("vm");

const source = fs.readFileSync(__dirname + "/../Tree.js", "utf8")
  .replace(/^\.pragma library\s*\n/, "");
const context = {};
vm.createContext(context);
vm.runInContext(source, context);

function window(address, title, cls, monitor, number) {
  return { address, title: title, class: cls, monitor, workspaceNumber: number, focusHistoryID: 1 };
}

const model = {
  roots: [
    {
      monitor: "eDP-1",
      workspaces: [
        { id: 1, number: 1, name: "1", monitor: "eDP-1", windows: [window("0x1", "Alpha", "kitty", "eDP-1", 1)] },
        { id: 2, number: 2, name: "2", monitor: "eDP-1", windows: [] }
      ]
    },
    {
      monitor: "HDMI-A-1",
      workspaces: [
        { id: 11, number: 1, name: "11", monitor: "HDMI-A-1", windows: [window("0x2", "Beta", "chrome", "HDMI-A-1", 1)] }
      ]
    }
  ]
};

const state = context.makeState(model);
assert.strictEqual(state.rows.length > 0, true);
assert.strictEqual(state.rows.find(row => row.window && row.window.address === "0x2").monitor, "HDMI-A-1");

const filtered = context.flatten(model, Object.create(null), "beta");
assert.strictEqual(filtered.some(row => row.kind === "window" && row.window.address === "0x2"), true);
assert.strictEqual(filtered.some(row => row.kind === "window" && row.window.address === "0x1"), false);

console.log("tree tests passed");
