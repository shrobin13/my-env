import QtTest
import "../Model.js" as Model

TestCase {
  name: "NotificationModel"

  function test_deletedItemsAreFiltered() {
    var items = [
      { key: "old", app: "notify-send", summary: "Old", body: "", urgency: 1, ts: 2 },
      { key: "new", app: "notify-send", summary: "New", body: "", urgency: 1, ts: 1 }
    ]
    var state = Model.defaultUserState()
    state.deletedKeys.old = true
    state.clearedBefore = 5

    var result = Model.filterNotifications(items, state, "All", "", 10, {})

    compare(result.length, 1)
    compare(result[0].key, "new")
  }

  function test_deletedItemsAreExcludedFromUnreadCount() {
    var items = [
      { key: "old", app: "notify-send" },
      { key: "new", app: "notify-send" }
    ]
    var state = Model.defaultUserState()
    state.deletedKeys.old = true

    compare(Model.computeUnreadCount(items, state, 10), 1)
  }

  function test_replayedOldItemsAreFilteredByClearCutoff() {
    var state = Model.defaultUserState()
    state.clearedBefore = 5
    var result = Model.filterNotifications(
      [{ key: "replayed", app: "notify-send", summary: "Old", body: "", urgency: 1, ts: 5 }],
      state, "All", "", 10, {}
    )
    compare(result.length, 0)
  }
}
