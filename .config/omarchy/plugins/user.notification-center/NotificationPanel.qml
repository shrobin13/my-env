import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: panelRoot
  implicitWidth: 0
  clip: true

  property var bar: null
  property bool panelOpened: true
  signal closeRequested()

  property var rawNotifications: []
  property bool rawNotificationsLoaded: false
  property var userState: Model.defaultUserState()
  property string activeFilter: "All"
  property string searchQuery: ""
  property var expandedApps: ({})

  // Snapshot of unread keys at the moment panel was opened
  property var unreadAtOpen: ({})

  // Track active text input focus for PanelKeyCatcher
  readonly property bool isInputActive: searchInput.activeFocus || (Window.activeFocusItem && (Window.activeFocusItem instanceof TextInput || Window.activeFocusItem.hasOwnProperty("cursorPosition")))

  // Update only while a timed focus is active; snooze expiry is reconciled on refresh.
  property int currentEpochSec: Math.floor(Date.now() / 1000)
  property int filterEpochSec: currentEpochSec

  readonly property int nextSnoozeExpiry: {
    var next = 0
    for (var key in panelRoot.userState.snoozed) {
      var expiry = Number(panelRoot.userState.snoozed[key])
      if (expiry > panelRoot.filterEpochSec && (!next || expiry < next)) next = expiry
    }
    return next
  }

  Timer {
    id: clockTickTimer
    interval: 1000
    running: panelRoot.panelOpened && panelRoot.dndActive && panelRoot.userState.focusUntil > 0
    repeat: true
    onTriggered: {
      panelRoot.currentEpochSec = Math.floor(Date.now() / 1000)
      // Reconcile focus expiry if past focusUntil
      if (panelRoot.dndActive && panelRoot.userState.focusUntil > 0 && panelRoot.currentEpochSec >= panelRoot.userState.focusUntil) {
        panelRoot.setFocusDuration(-1)
      }

    }
  }

  Timer {
    id: snoozeExpiryTimer
    running: panelRoot.panelOpened && panelRoot.nextSnoozeExpiry > 0
    interval: Math.max(1000, (panelRoot.nextSnoozeExpiry - panelRoot.filterEpochSec) * 1000)
    repeat: false
    onTriggered: {
      panelRoot.filterEpochSec = Math.floor(Date.now() / 1000)
      restart()
    }
  }

  // Pending Deletions & Undo System
  property var pendingDeletes: []
  property var pendingDeletesMap: ({})
  property var committedDeletes: ({})
  property string undoMessage: ""
  property bool undoVisible: false
  property string undoAction: ""

  // Non-destructive active notifications (filters out pending deletes)
  readonly property var activeNotifications: {
    var out = []
    for (var i = 0; i < panelRoot.rawNotifications.length; i++) {
      var it = panelRoot.rawNotifications[i]
      if (it && it.key && !panelRoot.pendingDeletesMap[it.key] && !panelRoot.committedDeletes[it.key]) {
        out.push(it)
      }
    }
    return out
  }

  // Filtered & grouped items
  readonly property var filteredList: Model.filterNotifications(
    panelRoot.activeNotifications,
    panelRoot.userState,
    panelRoot.activeFilter,
    panelRoot.searchQuery,
    panelRoot.filterEpochSec,
    panelRoot.unreadAtOpen
  )

  readonly property var displayList: Model.groupNotifications(filteredList, expandedApps)

  // Dictionary lookup for full notification objects
  property var notifDataByKey: ({})

  // Synchronize ListModel with displayList efficiently
  onDisplayListChanged: {
    var lookup = {}
    var i
    for (i = 0; i < panelRoot.displayList.length; i++) {
      var item = panelRoot.displayList[i]
      if (item && item.key) lookup[item.key] = item
    }
    panelRoot.notifDataByKey = lookup

    // 1. Remove deleted items
    for (var j = notifListModel.count - 1; j >= 0; j--) {
      var k = notifListModel.get(j).key
      if (!lookup[k]) {
        notifListModel.remove(j)
      }
    }

    // 2. Insert or update items in order
    for (i = 0; i < panelRoot.displayList.length; i++) {
      var it = panelRoot.displayList[i]
      if (!it || !it.key) continue

      var rowData = {
        key: String(it.key),
        sectionName: String(it.sectionName || "Today"),
        isRead: Boolean(it.isRead),
        isPinned: Boolean(it.isPinned),
        isSnoozed: Boolean(it.isSnoozed),
        isGroupHeader: Boolean(it.isGroupHeader),
        groupExtraCount: Number(it.groupExtraCount || 0),
        groupExpanded: Boolean(it.groupExpanded)
      }

      if (i < notifListModel.count) {
        var currentItem = notifListModel.get(i)
        if (currentItem.key === it.key) {
          // Only update if properties actually changed
          if (currentItem.isRead !== rowData.isRead ||
              currentItem.isPinned !== rowData.isPinned ||
              currentItem.isSnoozed !== rowData.isSnoozed ||
              currentItem.sectionName !== rowData.sectionName ||
              currentItem.groupExpanded !== rowData.groupExpanded ||
              currentItem.groupExtraCount !== rowData.groupExtraCount) {
            notifListModel.set(i, rowData)
          }
        } else {
          // Check if item exists further down
          var foundIdx = -1
          for (var f = i + 1; f < notifListModel.count; f++) {
            if (notifListModel.get(f).key === it.key) {
              foundIdx = f
              break
            }
          }
          if (foundIdx !== -1) {
            notifListModel.move(foundIdx, i, 1)
            notifListModel.set(i, rowData)
          } else {
            notifListModel.insert(i, rowData)
          }
        }
      } else {
        notifListModel.append(rowData)
      }
    }
  }

  // Live filter counts
  readonly property int countAll: {
    var c = 0
    for (var i = 0; i < panelRoot.activeNotifications.length; i++) {
      var it = panelRoot.activeNotifications[i]
      if (!Model.isSnoozed(panelRoot.userState, it.key, panelRoot.filterEpochSec) && !Model.isMuted(panelRoot.userState, it.app)) c++
    }
    return c
  }

  readonly property int countUnread: {
    var c = 0
    for (var i = 0; i < panelRoot.activeNotifications.length; i++) {
      var it = panelRoot.activeNotifications[i]
      var visibleUnread = !Model.isRead(panelRoot.userState, it.key) || Boolean(panelRoot.unreadAtOpen[it.key])
      if (visibleUnread && !Model.isSnoozed(panelRoot.userState, it.key, panelRoot.filterEpochSec) && !Model.isMuted(panelRoot.userState, it.app)) c++
    }
    return c
  }

  readonly property int countUrgent: {
    var c = 0
    for (var i = 0; i < panelRoot.activeNotifications.length; i++) {
      var it = panelRoot.activeNotifications[i]
      if (it.urgency === 2 && !Model.isSnoozed(panelRoot.userState, it.key, panelRoot.filterEpochSec) && !Model.isMuted(panelRoot.userState, it.app)) c++
    }
    return c
  }

  readonly property int countMessages: {
    var c = 0
    for (var i = 0; i < panelRoot.activeNotifications.length; i++) {
      var it = panelRoot.activeNotifications[i]
      if (Model.supportsReply(it) && !Model.isSnoozed(panelRoot.userState, it.key, panelRoot.filterEpochSec) && !Model.isMuted(panelRoot.userState, it.app)) c++
    }
    return c
  }

  readonly property int countPinned: {
    var c = 0
    for (var i = 0; i < panelRoot.activeNotifications.length; i++) {
      if (Model.isPinned(panelRoot.userState, panelRoot.activeNotifications[i].key)) c++
    }
    return c
  }

  readonly property int countSnoozed: Model.countSnoozed(panelRoot.activeNotifications, panelRoot.userState, panelRoot.filterEpochSec)
  readonly property int countMuted: Object.keys(panelRoot.userState.mutedApps || {}).length

  // Number of clearable (non-pinned) items currently visible
  readonly property int clearableCount: {
    var count = 0
    for (var i = 0; i < panelRoot.filteredList.length; i++) {
      if (!Model.isPinned(panelRoot.userState, panelRoot.filteredList[i].key)) count++
    }
    return count
  }

  readonly property string clearBtnLabel: {
    if (panelRoot.activeFilter === "All" && panelRoot.searchQuery === "") {
      return strings.t("clear")
    }
    return strings.t("clearCount").arg(panelRoot.clearableCount)
  }

  readonly property color foreground: Commons.Color.foreground
  readonly property color dimColor: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.65)
  readonly property color subtleBg: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.055)
  readonly property color subtleBorder: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.12)

  Commons.Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }

  // ---------------------------------------------------------------------------
  // STATE PERSISTENCE & DEBOUNCING
  // ---------------------------------------------------------------------------
  readonly property string stateFilePath: Quickshell.env("HOME") + "/.local/state/omarchy/notifications/user-state.json"
  property string lastSerializedState: ""

  FileView {
    id: userStateFile
    path: panelRoot.stateFilePath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      var txt = text()
      if (txt && txt.trim() === panelRoot.lastSerializedState.trim()) {
        return // Ignore reload triggered by our own serialization write
      }
      panelRoot.userState = Model.parseUserState(txt)
      if (panelRoot.rawNotificationsLoaded) panelRoot.pruneUserState()
    }
  }

  Timer {
    id: saveStateDebounceTimer
    interval: 150
    repeat: false
    onTriggered: {
      var jsonText = Model.serializeUserState(panelRoot.userState)
      panelRoot.lastSerializedState = jsonText
      userStateFile.setText(jsonText)
    }
  }

  function saveState() {
    saveStateDebounceTimer.restart()
  }

  function pruneUserState() {
    var present = {}
    for (var i = 0; i < panelRoot.rawNotifications.length; i++) {
      if (panelRoot.rawNotifications[i] && panelRoot.rawNotifications[i].key) present[panelRoot.rawNotifications[i].key] = true
    }
    var changed = false
    var fields = ["pinned", "snoozed", "readKeys"]
    for (var fieldIndex = 0; fieldIndex < fields.length; fieldIndex++) {
      var field = fields[fieldIndex]
      var values = panelRoot.userState[field] || {}
      for (var key in values) {
        if (!present[key]) {
          delete values[key]
          changed = true
        }
      }
      panelRoot.userState[field] = values
    }
    if (changed) panelRoot.saveState()
  }

  // ---------------------------------------------------------------------------
  // VIEWPORT READ TRACKING & SNAPSHOT
  // ---------------------------------------------------------------------------
  Timer {
    id: readTimer
    interval: 800
    running: false
    repeat: false
    onTriggered: panelRoot.markVisibleAsRead()
  }

  function markVisibleAsRead() {
    if (!panelRoot.panelOpened || notifListModel.count === 0) return
    if (!panelRoot.userState.readKeys) panelRoot.userState.readKeys = {}

    var topY = notifListView.contentY
    var bottomY = topY + notifListView.height
    var changed = false

    var startIdx = notifListView.indexAt(Style.space(20), topY + Style.space(10))
    if (startIdx === -1) startIdx = 0

    // Safely iterate through items that are actually visible
    for (var i = startIdx; i < notifListModel.count; i++) {
      var itemDelegate = notifListView.itemAtIndex(i)
      if (itemDelegate) {
        var itemTop = itemDelegate.y
        if (itemTop > bottomY) break // Scrolled below viewport
      }

      var it = notifListModel.get(i)
      if (it && it.key) {
        if (!panelRoot.userState.readKeys[it.key]) {
          panelRoot.userState.readKeys[it.key] = true
          notifListModel.setProperty(i, "isRead", true)
          changed = true
        }
      }
    }

    if (changed) {
      panelRoot.userStateChanged()
      panelRoot.saveState()
    }
  }

  onPanelOpenedChanged: {
    if (panelOpened) {
      // 1. Take snapshot of currently unread items so Unread chip doesn't vanish while open
      var unreadMap = {}
      for (var i = 0; i < panelRoot.rawNotifications.length; i++) {
        var k = panelRoot.rawNotifications[i].key
        if (k && !Model.isRead(panelRoot.userState, k)) {
          unreadMap[k] = true
        }
      }
      panelRoot.unreadAtOpen = unreadMap
      readTimer.restart()
      notifListView.currentIndex = 0
    } else {
      // Commit any pending deletions when panel closes
      panelRoot.commitPendingDeletes()
      focusMenuOverlay.visible = false
      mutedAppsOverlay.visible = false
    }
  }

  onRawNotificationsChanged: {
    panelRoot.rawNotificationsLoaded = true
    panelRoot.pruneUserState()
    var stillPresent = {}
    for (var r = 0; r < panelRoot.rawNotifications.length; r++) {
      if (panelRoot.rawNotifications[r] && panelRoot.rawNotifications[r].key) stillPresent[panelRoot.rawNotifications[r].key] = true
    }
    var committed = Object.assign({}, panelRoot.committedDeletes)
    for (var committedKey in committed) {
      if (!stillPresent[committedKey]) delete committed[committedKey]
    }
    panelRoot.committedDeletes = committed
    if (panelOpened) {
      // Add any newly arrived unread notifications to snapshot so they don't vanish immediately
      for (var i = 0; i < panelRoot.rawNotifications.length; i++) {
        var k = panelRoot.rawNotifications[i].key
        if (k && !Model.isRead(panelRoot.userState, k) && !panelRoot.unreadAtOpen[k]) {
          panelRoot.unreadAtOpen[k] = true
        }
      }
      readTimer.restart()
    }
  }

  // ---------------------------------------------------------------------------
  // CARD ACTIONS, DISMISSAL & REAL UNDO
  // ---------------------------------------------------------------------------
  function dismissItem(key) {
    if (!key) return
    var target = null
    for (var i = 0; i < panelRoot.rawNotifications.length; i++) {
      if (panelRoot.rawNotifications[i].key === key) {
        target = panelRoot.rawNotifications[i]
        break
      }
    }
    if (!target) return

    var newDeletes = panelRoot.pendingDeletes.slice()
    if (newDeletes.indexOf(key) < 0) {
      newDeletes.push(key)
    }
    panelRoot.pendingDeletes = newDeletes

    var newMap = Object.assign({}, panelRoot.pendingDeletesMap)
    newMap[key] = target
    panelRoot.pendingDeletesMap = newMap

    panelRoot.undoMessage = strings.tn("notificationsDismissed", newDeletes.length).arg(newDeletes.length)
    panelRoot.undoAction = "delete"
    panelRoot.undoVisible = true
    undoTimer.restart()
  }

  function clearVisibleNonPinned() {
    var toClear = []
    for (var i = 0; i < panelRoot.filteredList.length; i++) {
      var it = panelRoot.filteredList[i]
      if (it && it.key && !Model.isPinned(panelRoot.userState, it.key)) {
        toClear.push(it)
      }
    }

    if (toClear.length === 0) return

    var newDeletes = panelRoot.pendingDeletes.slice()
    var newMap = Object.assign({}, panelRoot.pendingDeletesMap)

    for (var j = 0; j < toClear.length; j++) {
      var item = toClear[j]
      if (newDeletes.indexOf(item.key) < 0) {
        newDeletes.push(item.key)
      }
      newMap[item.key] = item
    }

    panelRoot.pendingDeletes = newDeletes
    panelRoot.pendingDeletesMap = newMap

    panelRoot.undoMessage = strings.tn("notificationsCleared", newDeletes.length).arg(newDeletes.length)
    panelRoot.undoAction = "delete"
    panelRoot.undoVisible = true
    undoTimer.restart()
  }

  function commitPendingDeletes() {
    if (panelRoot.pendingDeletes.length === 0) {
      panelRoot.undoVisible = false
      panelRoot.undoAction = ""
      return
    }
    var keys = panelRoot.pendingDeletes.slice()
    var committed = Object.assign({}, panelRoot.committedDeletes)
    for (var i = 0; i < keys.length; i++) committed[keys[i]] = true
    panelRoot.committedDeletes = committed
    panelRoot.pendingDeletes = []
    panelRoot.pendingDeletesMap = ({})
    panelRoot.undoVisible = false
    undoTimer.stop()

    var script = Quickshell.env("HOME") + "/.config/omarchy/plugins/user.notification-center/manage.py"
    for (var offset = 0; offset < keys.length; offset += 50) {
      Quickshell.execDetached(["python3", script, "delete-keys", "--"].concat(keys.slice(offset, offset + 50)))
    }
  }

  function performUndo() {
    if (panelRoot.undoAction.indexOf("mute:") === 0) {
      panelRoot.unmuteApp(panelRoot.undoAction.slice(5))
      panelRoot.undoAction = ""
      if (panelRoot.pendingDeletes.length > 0) undoTimer.restart()
    } else {
      panelRoot.pendingDeletes = []
      panelRoot.pendingDeletesMap = ({})
      panelRoot.undoAction = ""
    }
    panelRoot.undoVisible = false
    undoTimer.stop()
  }

  Timer {
    id: undoTimer
    interval: 5000
    repeat: false
    onTriggered: panelRoot.commitPendingDeletes()
  }

  function togglePin(key) {
    if (!key) return
    var p = Object.assign({}, panelRoot.userState.pinned)
    if (p[key]) delete p[key]
    else p[key] = true
    panelRoot.userState.pinned = p
    panelRoot.userStateChanged()
    panelRoot.saveState()
  }

  function snoozeItem(key, seconds) {
    if (!key) return
    var s = Object.assign({}, panelRoot.userState.snoozed)
    s[key] = Math.floor(Date.now() / 1000) + seconds
    panelRoot.userState.snoozed = s
    panelRoot.userStateChanged()
    panelRoot.saveState()
  }

  function wakeItem(key) {
    if (!key) return
    var s = Object.assign({}, panelRoot.userState.snoozed)
    delete s[key]
    panelRoot.userState.snoozed = s
    if (panelRoot.userState.readKeys) delete panelRoot.userState.readKeys[key]
    panelRoot.userStateChanged()
    panelRoot.saveState()
  }

  function muteApp(app) {
    if (!app || app === "System") return
    var m = Object.assign({}, panelRoot.userState.mutedApps)
    m[app] = true
    panelRoot.userState.mutedApps = m
    panelRoot.userStateChanged()
    panelRoot.saveState()

    panelRoot.undoMessage = "Muted " + app
    panelRoot.undoAction = "mute:" + app
    panelRoot.undoVisible = true
    undoTimer.restart()
  }

  function unmuteApp(app) {
    if (!app) return
    var m = Object.assign({}, panelRoot.userState.mutedApps)
    delete m[app]
    panelRoot.userState.mutedApps = m
    if (Object.keys(m).length === 0) {
      mutedAppsOverlay.visible = false
    }
    panelRoot.userStateChanged()
    panelRoot.saveState()
  }

  function toggleGroup(app) {
    if (!app) return
    var ex = Object.assign({}, panelRoot.expandedApps)
    ex[app] = !ex[app]
    panelRoot.expandedApps = ex
  }

  function triggerAction(key, actionId) {
    var script = Quickshell.env("HOME") + "/.config/omarchy/plugins/user.notification-center/manage.py"
    Quickshell.execDetached(["python3", script, "run-action", "--", key, actionId])
  }

  // ---------------------------------------------------------------------------
  // FOCUS (DO NOT DISTURB) MANAGEMENT
  // ---------------------------------------------------------------------------
  property bool dndActive: false
  property bool ignoreQuietUpdates: false

  Timer {
    id: quietIgnoreTimer
    interval: 500
    repeat: false
    onTriggered: panelRoot.ignoreQuietUpdates = false
  }

  function toggleFocus() {
    if (panelRoot.dndActive) {
      panelRoot.setFocusDuration(-1)
    } else {
      panelRoot.setFocusDuration(0)
    }
  }

  function setFocusDuration(seconds) {
    focusMenuOverlay.visible = false

    var script = Quickshell.env("HOME") + "/.config/omarchy/plugins/user.notification-center/manage.py"
    if (seconds > 0) {
      panelRoot.userState.focusUntil = Math.floor(Date.now() / 1000) + seconds
      panelRoot.userState.focusPreset = String(seconds)
    } else if (seconds === 0) {
      panelRoot.userState.focusUntil = 0
      panelRoot.userState.focusPreset = "0"
    } else {
      panelRoot.userState.focusUntil = 0
      panelRoot.userState.focusPreset = ""
    }

    panelRoot.userStateChanged()
    panelRoot.saveState()

    Quickshell.execDetached(["python3", script, "set-focus", "--", String(seconds)])
  }

  function formatExpiryClock(epochSec) {
    if (!epochSec || epochSec <= 0) return ""
    var d = new Date(epochSec * 1000)
    var hrs = d.getHours()
    var mins = d.getMinutes()
    var ampm = hrs >= 12 ? "PM" : "AM"
    var h12 = hrs % 12
    if (h12 === 0) h12 = 12
    var mStr = mins < 10 ? ("0" + mins) : String(mins)
    return h12 + ":" + mStr + " " + ampm
  }

  function formatRemainingDetailed(epochSec) {
    if (!epochSec || epochSec <= 0) return ""
    var diff = epochSec - panelRoot.currentEpochSec
    if (diff <= 0) return "expired"
    var mins = Math.ceil(diff / 60)
    if (mins < 60) return mins + "m left"
    var hrs = Math.floor(mins / 60)
    var remM = mins % 60
    return remM > 0 ? (hrs + "h " + remM + "m left") : (hrs + "h left")
  }

  readonly property string focusStatusText: {
    if (!panelRoot.dndActive) return strings.t("focus")
    if (panelRoot.userState.focusUntil > 0) {
      var remaining = Math.max(0, panelRoot.userState.focusUntil - panelRoot.currentEpochSec)
      if (remaining <= 0) return strings.t("focus")
      var mins = Math.ceil(remaining / 60)
      if (mins < 60) return mins + "m"
      var hrs = Math.floor(mins / 60)
      var remMins = mins % 60
      return remMins > 0 ? (hrs + "h " + remMins + "m") : (hrs + "h")
    }
    return strings.t("focusOn")
  }

  // ---------------------------------------------------------------------------
  // ROOT-LEVEL OVERLAY POSITIONING (FOCUS MENU & MUTED APPS)
  // ---------------------------------------------------------------------------
  property real focusMenuX: 0
  property real focusMenuY: 0
  property real mutedAppsX: 0
  property real mutedAppsY: 0

  function openFocusMenu() {
    mutedAppsOverlay.visible = false
    var pt = focusBtn.mapToItem(panelRoot, 0, focusBtn.height + Style.space(6))
    var boxW = Style.space(220)
    panelRoot.focusMenuX = Math.max(Style.space(8), Math.min(panelRoot.width - boxW - Style.space(8), pt.x + focusBtn.width - boxW))
    panelRoot.focusMenuY = pt.y
    focusMenuOverlay.visible = true
  }

  function openMutedApps() {
    focusMenuOverlay.visible = false
    var pt = mutedAppsBtn.mapToItem(panelRoot, 0, mutedAppsBtn.height + Style.space(6))
    var boxW = Style.space(240)
    panelRoot.mutedAppsX = Math.max(Style.space(8), Math.min(panelRoot.width - boxW - Style.space(8), pt.x + mutedAppsBtn.width - boxW))
    panelRoot.mutedAppsY = pt.y
    mutedAppsOverlay.visible = true
  }

  // ---------------------------------------------------------------------------
  // KEYBOARD NAVIGATION (Connected from PanelKeyCatcher)
  // ---------------------------------------------------------------------------
  function moveCursor(dx, dy) {
    if (dy > 0) {
      notifListView.incrementCurrentIndex()
    } else if (dy < 0) {
      notifListView.decrementCurrentIndex()
    }
    notifListView.positionViewAtIndex(notifListView.currentIndex, ListView.Contain)
  }

  function activateSelected() {
    var cur = notifListView.itemAtIndex(notifListView.currentIndex)
    if (cur && typeof cur.runPrimaryAction === "function") {
      cur.runPrimaryAction()
    }
  }

  function deleteSelected() {
    var it = notifListModel.get(notifListView.currentIndex)
    if (it && it.key) {
      panelRoot.dismissItem(it.key)
    }
  }

  function handleTextKey(text, modifiers) {
    if (text === "/") {
      searchInput.forceActiveFocus()
    }
  }

  // ===========================================================================
  // MAIN PANEL LAYOUT
  // ===========================================================================
  ColumnLayout {
    anchors.fill: parent
    Layout.maximumWidth: panelRoot.width
    spacing: Style.space(12)

    // ==================== SECTION 1: HEADER ====================
    RowLayout {
      id: headerRow
      Layout.fillWidth: true
      Layout.maximumWidth: panelRoot.width
      spacing: Style.space(6)

      Item {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.preferredWidth: 0
        implicitWidth: 0
        implicitHeight: titleColumn.implicitHeight

        Column {
          id: titleColumn
          width: parent.width
        spacing: Style.space(2)

        Text {
          textFormat: Text.PlainText
          text: strings.t("title")
          font.family: Style.font.family
          font.pixelSize: Math.max(16, Style.font.title)
          font.bold: true
          color: panelRoot.foreground
        }

        Text {
          textFormat: Text.PlainText
          text: panelRoot.countUnread > 0 ? (panelRoot.countUnread + " " + strings.t("unread")) : strings.t("allCaughtUp")
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          color: panelRoot.dimColor
          width: parent.width
          elide: Text.ElideRight
        }
      }
      }

      // Muted Apps Button (Shown if any apps are muted)
      Rectangle {
        id: mutedAppsBtn
        visible: panelRoot.countMuted > 0
        Layout.preferredWidth: Style.space(32)
        Layout.preferredHeight: Style.space(32)
        radius: Style.space(8)
        scale: mutedBtnMouse.pressed ? 0.95 : (mutedBtnMouse.containsMouse ? 1.02 : 1.0)
        Behavior on scale { NumberAnimation { duration: Style.duration(70); easing.type: Easing.OutQuad } }

        color: mutedBtnMouse.pressed
          ? Qt.rgba(Commons.Color.urgent.r, Commons.Color.urgent.g, Commons.Color.urgent.b, 0.25)
          : (mutedBtnMouse.containsMouse ? Qt.rgba(panelRoot.foreground.r, panelRoot.foreground.g, panelRoot.foreground.b, 0.14) : Qt.rgba(panelRoot.foreground.r, panelRoot.foreground.g, panelRoot.foreground.b, 0.08))
        border.color: panelRoot.subtleBorder
        border.width: 1

        Text {
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: "\uf1f6"
          font.family: Style.font.family
          font.pixelSize: Style.space(12)
          color: Commons.Color.urgent
        }

        Rectangle {
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.topMargin: -Style.space(4)
          anchors.rightMargin: -Style.space(4)
          width: Math.max(Style.space(14), mutedBadgeText.implicitWidth + Style.space(6))
          height: width
          radius: width / 2
          color: Commons.Color.urgent
          Text {
            id: mutedBadgeText
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: String(panelRoot.countMuted)
            font.family: Style.font.family
            font.pixelSize: Style.space(9)
            font.bold: true
            color: Commons.Color.background
          }
        }

        MouseArea {
          id: mutedBtnMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: panelRoot.openMutedApps()
        }
      }

      // Focus (DND) Button
      Rectangle {
        id: focusBtn
        Layout.minimumWidth: implicitWidth
        height: Style.space(32)
        implicitWidth: focusRow.implicitWidth + Style.space(20)
        radius: Style.space(8)

        scale: (focusMouse.pressed || focusChevronMouse.pressed)
          ? 0.95
          : (focusMouse.containsMouse || focusChevronMouse.containsMouse ? 1.02 : 1.0)
        Behavior on scale { NumberAnimation { duration: Style.duration(70); easing.type: Easing.OutQuad } }

        color: (focusMouse.pressed || focusChevronMouse.pressed)
          ? (panelRoot.dndActive ? Qt.darker(Commons.Color.urgent, 1.25) : Qt.rgba(panelRoot.foreground.r, panelRoot.foreground.g, panelRoot.foreground.b, 0.22))
          : (panelRoot.dndActive
             ? Commons.Color.urgent
             : ((focusMouse.containsMouse || focusChevronMouse.containsMouse)
                ? Qt.rgba(panelRoot.foreground.r, panelRoot.foreground.g, panelRoot.foreground.b, 0.16)
                : Qt.rgba(panelRoot.foreground.r, panelRoot.foreground.g, panelRoot.foreground.b, 0.08)))

        border.color: panelRoot.dndActive
          ? Commons.Color.urgent
          : ((focusMouse.containsMouse || focusChevronMouse.containsMouse)
             ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.5)
             : Qt.rgba(panelRoot.foreground.r, panelRoot.foreground.g, panelRoot.foreground.b, 0.20))
        border.width: 1

        Behavior on color { ColorAnimation { duration: Style.duration(70); easing.type: Easing.OutQuad } }
        Behavior on border.color { ColorAnimation { duration: Style.duration(70); easing.type: Easing.OutQuad } }

        RowLayout {
          id: focusRow
          anchors.fill: parent
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(6)

          Item {
            Layout.fillHeight: true
            implicitWidth: focusMainRow.implicitWidth

            Row {
              id: focusMainRow
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(6)

              Text {
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: panelRoot.dndActive ? "\uf1f6" : "\uf0f3"
                font.family: Style.font.family
                font.pixelSize: Style.space(12)
                color: panelRoot.dndActive ? Commons.Color.background : Commons.Color.accent
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                        text: panelRoot.focusStatusText
                font.family: Style.font.family
                font.pixelSize: Math.max(12, Style.font.caption)
                font.bold: true
                color: panelRoot.dndActive ? Commons.Color.background : panelRoot.foreground
              }
            }

            MouseArea {
              id: focusMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: panelRoot.toggleFocus()
            }
          }

          // Small divider
          Rectangle {
            width: 1
            height: Style.space(14)
            color: panelRoot.dndActive ? Qt.rgba(0, 0, 0, 0.25) : Qt.rgba(panelRoot.foreground.r, panelRoot.foreground.g, panelRoot.foreground.b, 0.22)
            Layout.alignment: Qt.AlignVCenter
          }

          // Chevron button to open duration menu
          Item {
            Layout.fillHeight: true
            implicitWidth: Style.space(14)

            Text {
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: focusMenuOverlay.visible ? "\uf0d8" : "\uf0d7"
              font.family: Style.font.family
              font.pixelSize: Style.space(10)
              color: panelRoot.dndActive ? Commons.Color.background : (focusChevronMouse.containsMouse ? Commons.Color.accent : panelRoot.dimColor)
            }

            MouseArea {
              id: focusChevronMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (focusMenuOverlay.visible) focusMenuOverlay.visible = false
                else panelRoot.openFocusMenu()
              }
            }
          }
        }
      }

      // Clear All / Clear Shown Button
      Rectangle {
        id: clearBtn
        Layout.minimumWidth: implicitWidth
        visible: panelRoot.clearableCount > 0
        height: Style.space(32)
        implicitWidth: clearRow.implicitWidth + Style.space(16)
        radius: Style.space(8)

        scale: clearMouse.pressed ? 0.95 : (clearMouse.containsMouse ? 1.02 : 1.0)
        Behavior on scale { NumberAnimation { duration: Style.duration(70); easing.type: Easing.OutQuad } }

        color: clearMouse.pressed
          ? Qt.rgba(Commons.Color.urgent.r, Commons.Color.urgent.g, Commons.Color.urgent.b, 0.35)
          : (clearMouse.containsMouse
             ? Qt.rgba(Commons.Color.urgent.r, Commons.Color.urgent.g, Commons.Color.urgent.b, 0.22)
             : Qt.rgba(panelRoot.foreground.r, panelRoot.foreground.g, panelRoot.foreground.b, 0.08))
        border.color: clearMouse.containsMouse
          ? Commons.Color.urgent
          : Qt.rgba(panelRoot.foreground.r, panelRoot.foreground.g, panelRoot.foreground.b, 0.20)
        border.width: 1

        Behavior on color { ColorAnimation { duration: Style.duration(70); easing.type: Easing.OutQuad } }
        Behavior on border.color { ColorAnimation { duration: Style.duration(70); easing.type: Easing.OutQuad } }

        Row {
          id: clearRow
          anchors.centerIn: parent
          spacing: Style.space(6)

          Text {
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: "\uf2ed"
            font.family: Style.font.family
            font.pixelSize: Style.space(12)
            color: clearMouse.containsMouse ? Commons.Color.urgent : panelRoot.dimColor
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: panelRoot.clearBtnLabel
            font.family: Style.font.family
            font.pixelSize: Math.max(12, Style.font.caption)
            font.bold: true
            color: clearMouse.containsMouse ? Commons.Color.urgent : panelRoot.foreground
          }
        }

        MouseArea {
          id: clearMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: panelRoot.clearVisibleNonPinned()
        }
      }
    }

    // ==================== SECTION 2: SEARCH FIELD ====================
    Rectangle {
      Layout.fillWidth: true
      height: Style.space(34)
      radius: Style.space(8)
      color: panelRoot.subtleBg
      border.color: searchInput.activeFocus ? Commons.Color.accent : panelRoot.subtleBorder
      border.width: 1

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.space(10)
        anchors.rightMargin: Style.space(10)
        spacing: Style.space(8)

        Text {
          textFormat: Text.PlainText
          text: "\uf002"
          font.family: Style.font.family
          font.pixelSize: Style.space(12)
          color: panelRoot.dimColor
        }

        TextInput {
          id: searchInput
          Layout.fillWidth: true
          color: panelRoot.foreground
          font.family: Style.font.family
          font.pixelSize: Math.max(12, Style.font.body)
          clip: true
          onTextChanged: panelRoot.searchQuery = text
          Keys.onReturnPressed: function(event) {
            event.accepted = true
            panelRoot.forceActiveFocus()
          }
          Keys.onEnterPressed: function(event) {
            event.accepted = true
            panelRoot.forceActiveFocus()
          }

          Text {
            anchors.fill: parent
            visible: !searchInput.text && !searchInput.activeFocus
            textFormat: Text.PlainText
            text: strings.t("searchPlaceholder")
            font: searchInput.font
            color: panelRoot.dimColor
          }

          Keys.onEscapePressed: function() {
            searchInput.text = ""
            panelRoot.forceActiveFocus()
          }
        }

        // Clear Search Button
        Rectangle {
          visible: searchInput.text !== ""
          width: Style.space(18)
          height: Style.space(18)
          radius: width / 2
          color: clearSearchMouse.containsMouse ? Qt.rgba(foreground.r, foreground.g, foreground.b, 0.15) : "transparent"

          Text {
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: "\uf00d"
            font.family: Style.font.family
            font.pixelSize: Style.space(10)
            color: panelRoot.dimColor
          }

          MouseArea {
            id: clearSearchMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              searchInput.text = ""
              panelRoot.searchQuery = ""
              panelRoot.forceActiveFocus()
            }
          }
        }
      }
    }

    // ==================== SECTION 3: FILTER CHIPS ====================
    Flickable {
      Layout.fillWidth: true
      Layout.preferredWidth: 0
      implicitWidth: 0
      height: Style.space(28)
      contentWidth: chipRow.implicitWidth
      contentHeight: height
      boundsBehavior: Flickable.StopAtBounds
      clip: true
      flickableDirection: Flickable.HorizontalFlick

      Row {
        id: chipRow
        spacing: Style.space(8)

        Repeater {
          model: [
            { name: "All", count: panelRoot.countAll },
            { name: "Unread", count: panelRoot.countUnread },
            { name: "Urgent", count: panelRoot.countUrgent },
            { name: "Messages", count: panelRoot.countMessages },
            { name: "Pinned", count: panelRoot.countPinned },
            { name: "Snoozed", count: panelRoot.countSnoozed }
          ]

          Rectangle {
            height: Style.space(26)
            implicitWidth: chipInnerRow.implicitWidth + Style.space(16)
            radius: height / 2
            color: panelRoot.activeFilter === modelData.name
              ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.22)
              : (chipMouse.containsMouse ? Qt.rgba(panelRoot.foreground.r, panelRoot.foreground.g, panelRoot.foreground.b, 0.1) : panelRoot.subtleBg)
            border.color: panelRoot.activeFilter === modelData.name ? Commons.Color.accent : panelRoot.subtleBorder
            border.width: 1

            Row {
              id: chipInnerRow
              anchors.centerIn: parent
              spacing: Style.space(5)

              Text {
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: modelData.name
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                color: panelRoot.activeFilter === modelData.name ? Commons.Color.accent : panelRoot.foreground
              }

              Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: countTxt.implicitWidth + Style.space(6)
                height: Style.space(15)
                radius: height / 2
                color: panelRoot.activeFilter === modelData.name ? Commons.Color.accent : Qt.rgba(foreground.r, foreground.g, foreground.b, 0.12)

                Text {
                  id: countTxt
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: String(modelData.count)
                  font.family: Style.font.family
                  font.pixelSize: Style.space(9)
                  font.bold: true
                  color: panelRoot.activeFilter === modelData.name ? Commons.Color.background : panelRoot.foreground
                }
              }
            }

            MouseArea {
              id: chipMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                panelRoot.activeFilter = modelData.name
                panelRoot.forceActiveFocus()
              }
            }
          }
        }
      }
    }

    // ==================== SECTION 4: HIGH-PERFORMANCE LISTVIEW ====================
    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.maximumWidth: panelRoot.width

      // Empty State
      Column {
        anchors.centerIn: parent
        visible: notifListModel.count === 0
        spacing: Style.space(6)

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          textFormat: Text.PlainText
          text: strings.t("noNotifications")
          font.family: Style.font.family
          font.pixelSize: Math.max(14, Style.font.body)
          font.bold: true
          color: panelRoot.foreground
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          textFormat: Text.PlainText
          text: strings.t("allCaughtUpDesc")
          font.family: Style.font.family
          font.pixelSize: Math.max(12, Style.font.caption)
          color: panelRoot.dimColor
        }
      }

      // Synchronized ListModel
      ListModel {
        id: notifListModel
      }

      ListView {
        id: notifListView
        anchors.fill: parent
        model: notifListModel
        clip: true
        spacing: Style.space(10)
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        onMovementEnded: readTimer.restart()
        onContentYChanged: readTimer.restart()

        add: Transition {
          NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Style.duration(140); easing.type: Easing.OutCubic }
          NumberAnimation { property: "scale"; from: 0.95; to: 1.0; duration: Style.duration(140); easing.type: Easing.OutCubic }
        }
        remove: Transition {
          NumberAnimation { property: "opacity"; to: 0; duration: Style.duration(140); easing.type: Easing.OutCubic }
          NumberAnimation { property: "scale"; to: 0.95; duration: Style.duration(140); easing.type: Easing.OutCubic }
        }
        displaced: Transition {
          NumberAnimation { properties: "y"; duration: Style.duration(140); easing.type: Easing.OutCubic }
        }

        section.property: "sectionName"
        section.delegate: Item {
          width: notifListView.width
          height: Style.space(26)

          Text {
            anchors.left: parent.left
            anchors.leftMargin: Style.space(4)
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: section
            font.family: Style.font.family
            font.pixelSize: Math.max(12, Style.font.caption)
            font.bold: true
            color: section === "Needs attention" ? Commons.Color.urgent : panelRoot.dimColor
          }
        }

        delegate: NotificationCard {
          id: cardDelegate

          width: notifListView.width
          notificationData: panelRoot.notifDataByKey[model.key] || ({})
          isRead: model.isRead
          isPinned: model.isPinned
          isSnoozed: model.isSnoozed
          isGroupHeader: model.isGroupHeader
          groupExtraCount: model.groupExtraCount
          groupExpanded: model.groupExpanded
          nowSec: panelRoot.currentEpochSec
          onSelectRequested: {
            notifListView.currentIndex = index
            panelRoot.forceActiveFocus()
          }

          onDismissed: function(k) { panelRoot.dismissItem(k) }
          onActionTriggered: function(k, actId) { panelRoot.triggerAction(k, actId) }
          onSnoozeRequested: function(k, sec) { panelRoot.snoozeItem(k, sec) }
          onWakeRequested: function(k) { panelRoot.wakeItem(k) }
          onPinToggled: function(k) { panelRoot.togglePin(k) }
          onMuteAppRequested: function(app) { panelRoot.muteApp(app) }
          onGroupToggleRequested: function(app) { panelRoot.toggleGroup(app) }
        }
      }
    }

    // ==================== SECTION 5: UNDO TOAST ====================
    Rectangle {
      id: undoToast
      Layout.fillWidth: true
      height: Style.space(38)
      opacity: panelRoot.undoVisible ? 1 : 0
      visible: opacity > 0
      radius: Style.space(8)
      color: Commons.Color.popups.background
      border.color: Commons.Color.accent
      border.width: 1

      Behavior on opacity {
        NumberAnimation { duration: Style.duration(140); easing.type: Easing.OutCubic }
      }

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.space(12)
        anchors.rightMargin: Style.space(12)

        Text {
          textFormat: Text.PlainText
          text: panelRoot.undoMessage
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
          color: panelRoot.foreground
        }

        Item { Layout.fillWidth: true }

        Rectangle {
          height: Style.space(24)
          implicitWidth: undoLabel.implicitWidth + Style.space(16)
          radius: Style.space(4)
          color: undoMouse.containsMouse ? Commons.Color.accent : Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.2)

          Text {
            id: undoLabel
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: strings.t("undo")
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            color: undoMouse.containsMouse ? Commons.Color.background : Commons.Color.accent
          }

          MouseArea {
            id: undoMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: panelRoot.performUndo()
          }
        }
      }
    }
  }

  // ===========================================================================
  // ROOT-LEVEL OVERLAY 1: FOCUS DURATION MENU
  // ===========================================================================
  Item {
    id: focusMenuOverlay
    anchors.fill: parent
    z: 2000
    visible: false

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.AllButtons
      onClicked: focusMenuOverlay.visible = false
    }

    Rectangle {
      id: focusMenuBox
      x: panelRoot.focusMenuX
      y: panelRoot.focusMenuY
      width: Style.space(220)
      height: focusCol.implicitHeight + Style.space(16)
      radius: Math.max(8, Style.cornerRadius)
      color: Commons.Color.popups.background
      border.color: Commons.Color.popups.border
      border.width: 1

      Column {
        id: focusCol
        anchors.fill: parent
        anchors.margins: Style.space(8)
        spacing: Style.space(6)

        // Current Active Focus Status Card
        Rectangle {
          visible: panelRoot.dndActive
          width: parent.width
          height: Style.space(42)
          radius: Style.space(6)
          color: Qt.rgba(Commons.Color.urgent.r, Commons.Color.urgent.g, Commons.Color.urgent.b, 0.15)
          border.color: Qt.rgba(Commons.Color.urgent.r, Commons.Color.urgent.g, Commons.Color.urgent.b, 0.35)
          border.width: 1

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(8)

            Text {
              textFormat: Text.PlainText
              text: "\uf1f6"
              font.family: Style.font.family
              font.pixelSize: Style.space(14)
              color: Commons.Color.urgent
            }

            Column {
              Layout.fillWidth: true
              spacing: 1

              Text {
                textFormat: Text.PlainText
                text: panelRoot.userState.focusUntil > 0 ? strings.t("focusActive") : strings.t("focusIndefinite")
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                color: panelRoot.foreground
              }

              Text {
                textFormat: Text.PlainText
                text: panelRoot.userState.focusUntil > 0
                  ? (panelRoot.formatRemainingDetailed(panelRoot.userState.focusUntil) + " • until " + panelRoot.formatExpiryClock(panelRoot.userState.focusUntil))
                  : "Notifications muted until turned off"
                font.family: Style.font.family
                font.pixelSize: Style.font.caption - 2
                color: Commons.Color.urgent
                elide: Text.ElideRight
              }
            }
          }
        }

        // Duration Options List
        Repeater {
          model: [
            { label: strings.t("for30Mins"), sec: 1800 },
            { label: strings.t("for1Hour"), sec: 3600 },
            { label: strings.t("untilTomorrow"), sec: 86400 },
            { label: strings.t("untilTurnedOff"), sec: 0 }
          ]

          Rectangle {
            width: parent.width
            height: Style.space(28)
            radius: Style.space(5)
            scale: fOptMouse.pressed ? 0.96 : 1.0
            Behavior on scale { NumberAnimation { duration: Style.duration(60) } }

            readonly property bool isCurrentChoice: {
              if (!panelRoot.dndActive) return false
              return panelRoot.userState.focusPreset === String(modelData.sec)
            }

            color: fOptMouse.pressed
              ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.3)
              : (fOptMouse.containsMouse
                 ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.16)
                 : (isCurrentChoice ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.10) : "transparent"))

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.space(8)
              anchors.rightMargin: Style.space(8)
              spacing: Style.space(6)

              Text {
                Layout.fillWidth: true
                textFormat: Text.PlainText
                text: modelData.label
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: isCurrentChoice
                color: isCurrentChoice ? Commons.Color.accent : (fOptMouse.containsMouse ? Commons.Color.accent : panelRoot.foreground)
              }

              Text {
                visible: isCurrentChoice
                textFormat: Text.PlainText
                text: "\uf00c"
                font.family: Style.font.family
                font.pixelSize: Style.font.caption - 1
                color: Commons.Color.accent
              }
            }

            MouseArea {
              id: fOptMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: panelRoot.setFocusDuration(modelData.sec)
            }
          }
        }

        // Divider
        Rectangle {
          visible: panelRoot.dndActive
          width: parent.width
          height: 1
          color: panelRoot.subtleBorder
        }

        // Turn Off Focus Button
        Rectangle {
          visible: panelRoot.dndActive
          width: parent.width
          height: Style.space(28)
          radius: Style.space(5)
          scale: turnOffMouse.pressed ? 0.96 : 1.0
          Behavior on scale { NumberAnimation { duration: Style.duration(60) } }
          color: turnOffMouse.pressed
            ? Qt.rgba(Commons.Color.urgent.r, Commons.Color.urgent.g, Commons.Color.urgent.b, 0.3)
            : (turnOffMouse.containsMouse ? Qt.rgba(Commons.Color.urgent.r, Commons.Color.urgent.g, Commons.Color.urgent.b, 0.18) : "transparent")

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(6)

            Text {
              textFormat: Text.PlainText
              text: "\uf011"
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              color: Commons.Color.urgent
            }

            Text {
              Layout.fillWidth: true
              textFormat: Text.PlainText
              text: strings.t("turnOffFocus")
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
              color: Commons.Color.urgent
            }
          }

          MouseArea {
            id: turnOffMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: panelRoot.setFocusDuration(-1)
          }
        }
      }
    }
  }

  // ===========================================================================
  // ROOT-LEVEL OVERLAY 2: MUTED APPS POPUP
  // ===========================================================================
  Item {
    id: mutedAppsOverlay
    anchors.fill: parent
    z: 2000
    visible: false

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.AllButtons
      onClicked: mutedAppsOverlay.visible = false
    }

    Rectangle {
      id: mutedAppsBox
      x: panelRoot.mutedAppsX
      y: panelRoot.mutedAppsY
      width: Style.space(240)
      height: mutedCol.implicitHeight + Style.space(16)
      radius: Math.max(8, Style.cornerRadius)
      color: Commons.Color.popups.background
      border.color: Commons.Color.popups.border
      border.width: 1

      Column {
        id: mutedCol
        anchors.fill: parent
        anchors.margins: Style.space(8)
        spacing: Style.space(6)

        Text {
          textFormat: Text.PlainText
          text: strings.t("mutedApps")
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
          color: panelRoot.foreground
        }

        Repeater {
          model: Object.keys(panelRoot.userState.mutedApps || {})

          Rectangle {
            width: parent.width
            height: Style.space(28)
            radius: Style.space(4)
            color: Qt.rgba(panelRoot.foreground.r, panelRoot.foreground.g, panelRoot.foreground.b, 0.06)

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.space(8)
              anchors.rightMargin: Style.space(8)

              Text {
                Layout.fillWidth: true
                textFormat: Text.PlainText
                text: String(modelData)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                color: panelRoot.foreground
                elide: Text.ElideRight
              }

              Rectangle {
                height: Style.space(20)
                implicitWidth: unmuteLabel.implicitWidth + Style.space(12)
                radius: Style.space(3)
                color: unmuteMouse.containsMouse ? Commons.Color.accent : Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.18)

                Text {
                  id: unmuteLabel
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: strings.t("unmute")
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption - 1
                  font.bold: true
                  color: unmuteMouse.containsMouse ? Commons.Color.background : Commons.Color.accent
                }

                MouseArea {
                  id: unmuteMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    var appName = String(modelData)
                    panelRoot.unmuteApp(appName)
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
