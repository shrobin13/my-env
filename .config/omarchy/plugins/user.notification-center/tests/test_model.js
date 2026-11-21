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

// Test new notification arriving after clear does not show old history dumped by daemon
const staleDaemonHistoryDump = [
  { key: "new_arrival", app: "Telegram", summary: "New message", ts: 100 },
  { key: "old_history_1", app: "Slack", summary: "Old message", ts: 20 },
  { key: "old_history_2", app: "Terminal", summary: "Finished", ts: 0, closed_ts: 15 },
  { key: "old_history_3", app: "System", summary: "Update", closed_ts: 10 }
]
const clearedAt25 = context.defaultUserState()
clearedAt25.clearedBefore = 25
clearedAt25.deletedKeys["old_history_1"] = true
clearedAt25.deletedKeys["old_history_2"] = true
clearedAt25.deletedKeys["old_history_3"] = true

const parsed = staleDaemonHistoryDump.map(item => context.normalizeItem(item, false))
const visible = context.filterNotifications(parsed, clearedAt25, "All", "", 120, {})
assert.strictEqual(visible.length, 1)
assert.strictEqual(visible[0].key, "new_arrival")

console.log("ok")
