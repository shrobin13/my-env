const fs = require("fs")
const vm = require("vm")
const assert = require("assert")

const source = fs.readFileSync(require("path").join(__dirname, "..", "Model.js"), "utf8")
  .replace(/^\s*\.pragma library\s*$/m, "")
const context = {}
vm.createContext(context)
vm.runInContext(source, context)

const items = [
  { key: "old", app: "notify-send", summary: "Old", body: "", urgency: 1, ts: 2 },
  { key: "new", app: "notify-send", summary: "New", body: "", urgency: 1, ts: 1 }
]
const state = context.defaultUserState()
state.deletedKeys.old = true

const filtered = context.filterNotifications(items, state, "All", "", 10, {})
assert.strictEqual(JSON.stringify(filtered.map((item) => item.key)), JSON.stringify(["new"]))
assert.strictEqual(context.computeUnreadCount(items, state, 10), 1)

const replayed = [{ key: "replayed", app: "notify-send", summary: "Old", body: "", urgency: 1, ts: 5 }]
const clearedState = context.defaultUserState()
clearedState.clearedBefore = 5
assert.strictEqual(context.filterNotifications(replayed, clearedState, "All", "", 10, {}).length, 0)
console.log("ok")
