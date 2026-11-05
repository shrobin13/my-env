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
  id: root

  property var bar: null
  property bool panelOpened: true
  signal closeRequested()

  property var rawNotifications: []
  property var userState: Model.defaultUserState()
  property string activeFilter: "All"
  property string searchQuery: ""
  property var expandedApps: ({})

  // Snapshot of unread keys at the moment panel was opened
  property var unreadAtOpen: ({})

  // 1-second clock tick for countdowns, snooze expiry & time formatting
  property int currentEpochSec: Math.floor(Date.now() / 1000)

  Timer {
    id: clockTickTimer
    interval: 1000
    running: root.panelOpened
    repeat: true
    onTriggered: {
      root.currentEpochSec = Math.floor(Date.now() / 1000)
      // Reconcile focus expiry if past focusUntil
      if (root.dndActive && root.userState.focusUntil > 0 && root.currentEpochSec >= root.userState.focusUntil) {
        root.setFocusDuration(-1)
      }
    }
  }

  // Pending Deletions & Undo System
  property var pendingDeletes: []
  property var pendingDeletesMap: ({})
  property string undoMessage: ""
  property bool undoVisible: false

  // Non-destructive active notifications (filters out pending deletes without breaking parent binding)
  readonly property var activeNotifications: {
    var out = []
    for (var i = 0; i < root.rawNotifications.length; i++) {
      var it = root.rawNotifications[i]
      if (it && it.key && !root.pendingDeletesMap[it.key]) {
        out.push(it)
      }
    }
    return out
  }

  // Filtered & grouped items
  readonly property var filteredList: Model.filterNotifications(
    root.activeNotifications,
    root.userState,
    root.activeFilter,
    root.searchQuery,
    root.currentEpochSec,
    root.unreadAtOpen
  )

  readonly property var displayList: Model.groupNotifications(filteredList, expandedApps)

  // Dictionary lookup for full notification objects
  property var notifDataByKey: ({})

  // Synchronize ListModel with displayList for smooth item animations
  onDisplayListChanged: {
    var lookup = {}
    var i
    for (i = 0; i < root.displayList.length; i++) {
      var item = root.displayList[i]
      if (item && item.key) lookup[item.key] = item
    }
    root.notifDataByKey = lookup

    // 1. Remove deleted items
    for (var j = notifListModel.count - 1; j >= 0; j--) {
      var k = notifListModel.get(j).key
      if (!lookup[k]) {
        notifListModel.remove(j)
      }
    }

    // 2. Insert or update items in order
    for (i = 0; i < root.displayList.length; i++) {
      var it = root.displayList[i]
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
        var currentK = notifListModel.get(i).key
        if (currentK === it.key) {
          notifListModel.set(i, rowData)
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
    for (var i = 0; i < root.activeNotifications.length; i++) {
      var it = root.activeNotifications[i]
      if (!Model.isSnoozed(root.userState, it.key, root.currentEpochSec) && !Model.isMuted(root.userState, it.app)) c++
    }
    return c
  }

  readonly property int countUnread: {
    var c = 0
    for (var i = 0; i < root.activeNotifications.length; i++) {
      var it = root.activeNotifications[i]
      if (!Model.isRead(root.userState, it.key) && !Model.isSnoozed(root.userState, it.key, root.currentEpochSec) && !Model.isMuted(root.userState, it.app)) c++
    }
    return c
  }

  readonly property int countUrgent: {
    var c = 0
    for (var i = 0; i < root.activeNotifications.length; i++) {
      var it = root.activeNotifications[i]
      if (it.urgency === 2 && !Model.isSnoozed(root.userState, it.key, root.currentEpochSec) && !Model.isMuted(root.userState, it.app)) c++
    }
    return c
  }

  readonly property int countMessages: {
    var c = 0
    for (var i = 0; i < root.activeNotifications.length; i++) {
      var it = root.activeNotifications[i]
      if (Model.supportsReply(it) && !Model.isSnoozed(root.userState, it.key, root.currentEpochSec) && !Model.isMuted(root.userState, it.app)) c++
    }
    return c
  }

  readonly property int countPinned: {
    var c = 0
    for (var i = 0; i < root.activeNotifications.length; i++) {
      if (Model.isPinned(root.userState, root.activeNotifications[i].key)) c++
    }
    return c
  }

  readonly property int countSnoozed: Model.countSnoozed(root.activeNotifications, root.userState, root.currentEpochSec)
  readonly property int countMuted: Object.keys(root.userState.mutedApps || {}).length

  // Number of clearable (non-pinned) items currently visible
  readonly property int clearableCount: {
    var count = 0
    for (var i = 0; i < root.filteredList.length; i++) {
      if (!Model.isPinned(root.userState, root.filteredList[i].key)) count++
    }
    return count
  }

  readonly property string clearBtnLabel: {
    if (root.activeFilter === "All" && root.searchQuery === "") {
      return "Clear all"
    }
    return "Clear " + root.clearableCount + " shown"
  }

  readonly property color foreground: Commons.Color.foreground
  readonly property color dimColor: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.65)
  readonly property color subtleBg: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.055)
  readonly property color subtleBorder: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.12)

  // ---------------------------------------------------------------------------
  // STATE PERSISTENCE & DEBOUNCING
  // ---------------------------------------------------------------------------
  readonly property string stateFilePath: Quickshell.env("HOME") + "/.local/state/omarchy/notifications/user-state.json"
  property string lastSerializedState: ""

  FileView {
    id: userStateFile
    path: root.stateFilePath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      var txt = text()
      if (txt && txt.trim() === root.lastSerializedState.trim()) {
        return // Ignore reload triggered by our own serialization write
      }
      root.userState = Model.parseUserState(txt)
    }
  }

  Timer {
    id: saveStateDebounceTimer
    interval: 150
    repeat: false
    onTriggered: {
      var jsonText = Model.serializeUserState(root.userState)
      root.lastSerializedState = jsonText
      var script = Quickshell.env("HOME") + "/.config/omarchy/plugins/user.notification-center/manage.py"
      Quickshell.execDetached(["python3", script, "save-state", jsonText])
    }
  }

  function saveState() {
    saveStateDebounceTimer.restart()
  }

  // ---------------------------------------------------------------------------
  // VIEWPORT READ TRACKING & SNAPSHOT
  // ---------------------------------------------------------------------------
  Timer {
    id: readTimer
    interval: 1000
    running: root.panelOpened
    repeat: false
    onTriggered: root.markVisibleAsRead()
  }

  function markVisibleAsRead() {
    if (!root.panelOpened || notifListModel.count === 0) return
    if (!root.userState.readKeys) root.userState.readKeys = {}

    var topY = notifListView.contentY
    var bottomY = topY + notifListView.height
    var changed = false

    var startIdx = notifListView.indexAt(Style.space(20), topY + Style.space(10))
    var endIdx = notifListView.indexAt(Style.space(20), bottomY - Style.space(10))

    if (startIdx === -1) startIdx = 0
    if (endIdx === -1) endIdx = Math.min(notifListModel.count - 1, startIdx + 8)

    for (var i = startIdx; i <= endIdx; i++) {
      var it = notifListModel.get(i)
      if (it && it.key) {
        if (!root.userState.readKeys[it.key]) {
          root.userState.readKeys[it.key] = true
          notifListModel.setProperty(i, "isRead", true)
          changed = true
        }
      }
    }

    if (changed) {
      root.userStateChanged()
      root.saveState()
    }
  }

  onPanelOpenedChanged: {
    if (panelOpened) {
      // 1. Take snapshot of currently unread items so Unread chip doesn't vanish while open
      var unreadMap = {}
      for (var i = 0; i < root.rawNotifications.length; i++) {
        var k = root.rawNotifications[i].key
        if (k && !Model.isRead(root.userState, k)) {
          unreadMap[k] = true
        }
      }
      root.unreadAtOpen = unreadMap
      readTimer.restart()
      notifListView.currentIndex = 0
      root.forceActiveFocus()
    } else {
      // Commit any pending deletions when panel closes
      root.commitPendingDeletes()
      focusMenuOverlay.visible = false
      mutedAppsOverlay.visible = false
    }
  }

  onRawNotificationsChanged: {
    if (panelOpened) {
      readTimer.restart()
    }
  }

  // ---------------------------------------------------------------------------
  // CARD ACTIONS, DISMISSAL & REAL UNDO
  // ---------------------------------------------------------------------------
  function dismissItem(key) {
    if (!key) return
    var target = null
    for (var i = 0; i < root.rawNotifications.length; i++) {
      if (root.rawNotifications[i].key === key) {
        target = root.rawNotifications[i]
        break
      }
    }
    if (!target) return

    var newDeletes = root.pendingDeletes.slice()
    if (newDeletes.indexOf(key) < 0) {
      newDeletes.push(key)
    }
    root.pendingDeletes = newDeletes

    var newMap = Object.assign({}, root.pendingDeletesMap)
    newMap[key] = target
    root.pendingDeletesMap = newMap

    root.undoMessage = newDeletes.length === 1 ? "1 notification dismissed" : (newDeletes.length + " notifications dismissed")
    root.undoVisible = true
    undoTimer.restart()
  }

  function clearVisibleNonPinned() {
    var toClear = []
    for (var i = 0; i < root.filteredList.length; i++) {
      var it = root.filteredList[i]
      if (it && it.key && !Model.isPinned(root.userState, it.key)) {
        toClear.push(it)
      }
    }

    if (toClear.length === 0) return

    var newDeletes = root.pendingDeletes.slice()
    var newMap = Object.assign({}, root.pendingDeletesMap)

    for (var j = 0; j < toClear.length; j++) {
      var item = toClear[j]
      if (newDeletes.indexOf(item.key) < 0) {
        newDeletes.push(item.key)
      }
      newMap[item.key] = item
    }

    root.pendingDeletes = newDeletes
    root.pendingDeletesMap = newMap

    root.undoMessage = newDeletes.length === 1 ? "1 notification cleared" : (newDeletes.length + " notifications cleared")
    root.undoVisible = true
    undoTimer.restart()
  }

  function commitPendingDeletes() {
    if (root.pendingDeletes.length === 0) return
    var keys = root.pendingDeletes.slice()
    root.pendingDeletes = []
    root.pendingDeletesMap = ({})
    root.undoVisible = false
    undoTimer.stop()

    var script = Quickshell.env("HOME") + "/.config/omarchy/plugins/user.notification-center/manage.py"
    Quickshell.execDetached(["python3", script, "delete-keys"].concat(keys))
  }

  function performUndo() {
    root.pendingDeletes = []
    root.pendingDeletesMap = ({})
    root.undoVisible = false
    undoTimer.stop()
  }

  Timer {
    id: undoTimer
    interval: 5000
    repeat: false
    onTriggered: root.commitPendingDeletes()
  }

  function togglePin(key) {
    if (!key) return
    var p = Object.assign({}, root.userState.pinned)
    if (p[key]) delete p[key]
    else p[key] = true
    root.userState.pinned = p
    root.userStateChanged()
    root.saveState()
  }

  function snoozeItem(key, seconds) {
    if (!key) return
    var s = Object.assign({}, root.userState.snoozed)
    s[key] = Math.floor(Date.now() / 1000) + seconds
    root.userState.snoozed = s
    root.userStateChanged()
    root.saveState()
  }

  function wakeItem(key) {
    if (!key) return
    var s = Object.assign({}, root.userState.snoozed)
    delete s[key]
    root.userState.snoozed = s
    // Mark as unread so user reviews it
    if (root.userState.readKeys) delete root.userState.readKeys[key]
    root.userStateChanged()
    root.saveState()
  }

  function muteApp(app) {
    if (!app) return
    var m = Object.assign({}, root.userState.mutedApps)
    m[app] = true
    root.userState.mutedApps = m
    root.userStateChanged()
    root.saveState()

    root.undoMessage = "Muted " + app
    root.undoVisible = true
    undoTimer.restart()
  }

  function unmuteApp(app) {
    if (!app) return
    var m = Object.assign({}, root.userState.mutedApps)
    delete m[app]
    root.userState.mutedApps = m
    root.userStateChanged()
    root.saveState()
  }

  function toggleGroup(app) {
    if (!app) return
    var ex = Object.assign({}, root.expandedApps)
    ex[app] = !ex[app]
    root.expandedApps = ex
  }

  function triggerAction(key, actionId) {
    var script = Quickshell.env("HOME") + "/.config/omarchy/plugins/user.notification-center/manage.py"
    Quickshell.execDetached(["python3", script, "run-action", key, actionId])
  }

  function submitReply(key, text) {
    var script = Quickshell.env("HOME") + "/.config/omarchy/plugins/user.notification-center/manage.py"
    Quickshell.execDetached(["python3", script, "reply", key, text])
    root.forceActiveFocus()
  }

  // ---------------------------------------------------------------------------
  // FOCUS (DO NOT DISTURB) & SYSTEMD TIMER MANAGEMENT
  // ---------------------------------------------------------------------------
  property bool dndActive: false
  property bool ignoreQuietUpdates: false

  Timer {
    id: quietIgnoreTimer
    interval: 500
    repeat: false
    onTriggered: root.ignoreQuietUpdates = false
  }

  FileView {
    id: quietFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/notifications/quiet.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.updateQuiet()
  }

  function updateQuiet() {
    if (root.ignoreQuietUpdates) return
    try {
      var raw = quietFile.text()
      if (raw && raw.trim()) {
        var parsed = JSON.parse(raw)
        root.dndActive = !!parsed.dnd
      } else {
        root.dndActive = false
      }
    } catch (e) {
      root.dndActive = false
    }
  }

  function toggleFocus() {
    if (root.dndActive) {
      root.setFocusDuration(-1)
    } else {
      root.setFocusDuration(0)
    }
  }

  function setFocusDuration(seconds) {
    focusMenuOverlay.visible = false
    root.ignoreQuietUpdates = true
    quietIgnoreTimer.restart()

    var script = Quickshell.env("HOME") + "/.config/omarchy/plugins/user.notification-center/manage.py"
    if (seconds > 0) {
      root.userState.focusUntil = Math.floor(Date.now() / 1000) + seconds
      root.dndActive = true
    } else if (seconds === 0) {
      root.userState.focusUntil = 0
      root.dndActive = true
    } else {
      root.userState.focusUntil = 0
      root.dndActive = false
    }

    root.userStateChanged()
    root.saveState()

    // Enforce expiry in backend via systemd transient timer
    Quickshell.execDetached(["python3", script, "set-focus", String(seconds)])
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
    var diff = epochSec - root.currentEpochSec
    if (diff <= 0) return "expired"
    var mins = Math.ceil(diff / 60)
    if (mins < 60) return mins + "m left"
    var hrs = Math.floor(mins / 60)
    var remM = mins % 60
    return remM > 0 ? (hrs + "h " + remM + "m left") : (hrs + "h left")
  }

  readonly property string focusStatusText: {
    if (!root.dndActive) return "Focus"
    if (root.userState.focusUntil > 0) {
      var remaining = Math.max(0, root.userState.focusUntil - root.currentEpochSec)
      if (remaining <= 0) return "Focus: Expired"
      var mins = Math.ceil(remaining / 60)
      if (mins < 60) return "Focus: " + mins + "m"
      var hrs = Math.floor(mins / 60)
      var remMins = mins % 60
      return remMins > 0 ? ("Focus: " + hrs + "h " + remMins + "m") : ("Focus: " + hrs + "h")
    }
    return "Focus: On"
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
    var pt = focusBtn.mapToItem(root, 0, focusBtn.height + Style.space(6))
    var boxW = Style.space(220)
    root.focusMenuX = Math.max(Style.space(8), Math.min(root.width - boxW - Style.space(8), pt.x + focusBtn.width - boxW))
    root.focusMenuY = pt.y
    focusMenuOverlay.visible = true
  }

  function openMutedApps() {
    focusMenuOverlay.visible = false
    var pt = mutedAppsBtn.mapToItem(root, 0, mutedAppsBtn.height + Style.space(6))
    var boxW = Style.space(240)
    root.mutedAppsX = Math.max(Style.space(8), Math.min(root.width - boxW - Style.space(8), pt.x + mutedAppsBtn.width - boxW))
    root.mutedAppsY = pt.y
    mutedAppsOverlay.visible = true
  }

  // ---------------------------------------------------------------------------
  // KEYBOARD NAVIGATION & SHORTCUTS
  // ---------------------------------------------------------------------------
  focus: true

  Keys.onUpPressed: {
    notifListView.decrementCurrentIndex()
    notifListView.positionViewAtIndex(notifListView.currentIndex, ListView.Contain)
  }
  Keys.onDownPressed: {
    notifListView.incrementCurrentIndex()
    notifListView.positionViewAtIndex(notifListView.currentIndex, ListView.Contain)
  }
  Keys.onDeletePressed: {
    if (notifListView.currentItem && notifListView.currentItem.notificationData) {
      root.dismissItem(notifListView.currentItem.notificationData.key)
    }
  }

  function handleEnterAction() {
    if (notifListView.currentItem && typeof notifListView.currentItem.runPrimaryAction === "function") {
      notifListView.currentItem.runPrimaryAction()
    }
  }

  Keys.onReturnPressed: handleEnterAction()
  Keys.onEnterPressed: handleEnterAction()

  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Slash) {
      // Guard: do not hijack slash if typing inside any TextInput / TextField (e.g. inline reply)
      var af = Window.activeFocusItem
      if (af && (af instanceof TextInput || af.hasOwnProperty("cursorPosition"))) {
        return
      }
      searchInput.forceActiveFocus()
      event.accepted = true
    } else if (event.key === Qt.Key_Escape) {
      if (focusMenuOverlay.visible) {
        focusMenuOverlay.visible = false
        event.accepted = true
      } else if (mutedAppsOverlay.visible) {
        mutedAppsOverlay.visible = false
        event.accepted = true
      } else if (searchInput.text !== "") {
        searchInput.text = ""
        root.forceActiveFocus()
        event.accepted = true
      } else {
        root.closeRequested()
        event.accepted = true
      }
    }
  }

  // ===========================================================================
  // MAIN PANEL LAYOUT
  // ===========================================================================
  ColumnLayout {
    anchors.fill: parent
    spacing: Style.space(12)

    // ==================== SECTION 1: HEADER ====================
    RowLayout {
      id: headerRow
      Layout.fillWidth: true

      Column {
        spacing: Style.space(2)

        Text {
          textFormat: Text.PlainText
          text: "Notifications"
          font.family: Style.font.family
          font.pixelSize: Math.max(16, Style.font.title)
          font.bold: true
          color: root.foreground
        }

        Text {
          textFormat: Text.PlainText
          text: root.countUnread > 0 ? (root.countUnread + " unread") : "All caught up"
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          color: root.dimColor
        }
      }

      Item { Layout.fillWidth: true }

      // Muted Apps Button (Shown if any apps are muted)
      Rectangle {
        id: mutedAppsBtn
        visible: root.countMuted > 0
        height: Style.space(32)
        implicitWidth: mutedRow.implicitWidth + Style.space(16)
        radius: Style.space(8)
        scale: mutedBtnMouse.pressed ? 0.95 : (mutedBtnMouse.containsMouse ? 1.02 : 1.0)
        Behavior on scale { NumberAnimation { duration: Style.duration(70); easing.type: Easing.OutQuad } }

        color: mutedBtnMouse.pressed
          ? Qt.rgba(Commons.Color.urgent.r, Commons.Color.urgent.g, Commons.Color.urgent.b, 0.25)
          : (mutedBtnMouse.containsMouse ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.14) : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08))
        border.color: root.subtleBorder
        border.width: 1

        Row {
          id: mutedRow
          anchors.centerIn: parent
          spacing: Style.space(5)

          Text {
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: "\uf1f6"
            font.family: Style.font.family
            font.pixelSize: Style.space(11)
            color: Commons.Color.urgent
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: "Muted (" + root.countMuted + ")"
            font.family: Style.font.family
            font.pixelSize: Math.max(11, Style.font.caption)
            font.bold: true
            color: root.foreground
          }
        }

        MouseArea {
          id: mutedBtnMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.openMutedApps()
        }
      }

      // Focus (DND) Button
      Rectangle {
        id: focusBtn
        height: Style.space(32)
        implicitWidth: focusRow.implicitWidth + Style.space(20)
        radius: Style.space(8)

        scale: (focusMouse.pressed || focusChevronMouse.pressed)
          ? 0.95
          : (focusMouse.containsMouse || focusChevronMouse.containsMouse ? 1.02 : 1.0)
        Behavior on scale { NumberAnimation { duration: Style.duration(70); easing.type: Easing.OutQuad } }

        color: (focusMouse.pressed || focusChevronMouse.pressed)
          ? (root.dndActive ? Qt.darker(Commons.Color.urgent, 1.25) : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.22))
          : (root.dndActive
             ? Commons.Color.urgent
             : ((focusMouse.containsMouse || focusChevronMouse.containsMouse)
                ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.16)
                : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)))

        border.color: root.dndActive
          ? Commons.Color.urgent
          : ((focusMouse.containsMouse || focusChevronMouse.containsMouse)
             ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.5)
             : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.20))
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
                text: root.dndActive ? "\uf1f6" : "\uf0f3"
                font.family: Style.font.family
                font.pixelSize: Style.space(12)
                color: root.dndActive ? Commons.Color.background : Commons.Color.accent
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: root.focusStatusText
                font.family: Style.font.family
                font.pixelSize: Math.max(12, Style.font.caption)
                font.bold: true
                color: root.dndActive ? Commons.Color.background : root.foreground
              }
            }

            MouseArea {
              id: focusMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.toggleFocus()
            }
          }

          // Small divider
          Rectangle {
            width: 1
            height: Style.space(14)
            color: root.dndActive ? Qt.rgba(0, 0, 0, 0.25) : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.22)
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
              color: root.dndActive ? Commons.Color.background : (focusChevronMouse.containsMouse ? Commons.Color.accent : root.dimColor)
            }

            MouseArea {
              id: focusChevronMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (focusMenuOverlay.visible) focusMenuOverlay.visible = false
                else root.openFocusMenu()
              }
            }
          }
        }
      }

      // Clear All / Clear Shown Button
      Rectangle {
        id: clearBtn
        visible: root.clearableCount > 0
        height: Style.space(32)
        implicitWidth: clearRow.implicitWidth + Style.space(16)
        radius: Style.space(8)

        scale: clearMouse.pressed ? 0.95 : (clearMouse.containsMouse ? 1.02 : 1.0)
        Behavior on scale { NumberAnimation { duration: Style.duration(70); easing.type: Easing.OutQuad } }

        color: clearMouse.pressed
          ? Qt.rgba(Commons.Color.urgent.r, Commons.Color.urgent.g, Commons.Color.urgent.b, 0.35)
          : (clearMouse.containsMouse
             ? Qt.rgba(Commons.Color.urgent.r, Commons.Color.urgent.g, Commons.Color.urgent.b, 0.22)
             : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08))
        border.color: clearMouse.containsMouse
          ? Commons.Color.urgent
          : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.20)
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
            color: clearMouse.containsMouse ? Commons.Color.urgent : root.dimColor
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: root.clearBtnLabel
            font.family: Style.font.family
            font.pixelSize: Math.max(12, Style.font.caption)
            font.bold: true
            color: clearMouse.containsMouse ? Commons.Color.urgent : root.foreground
          }
        }

        MouseArea {
          id: clearMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.clearVisibleNonPinned()
        }
      }
    }

    // ==================== SECTION 2: SEARCH FIELD ====================
    Rectangle {
      Layout.fillWidth: true
      height: Style.space(34)
      radius: Style.space(8)
      color: root.subtleBg
      border.color: searchInput.activeFocus ? Commons.Color.accent : root.subtleBorder
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
          color: root.dimColor
        }

        TextInput {
          id: searchInput
          Layout.fillWidth: true
          color: root.foreground
          font.family: Style.font.family
          font.pixelSize: Math.max(12, Style.font.body)
          clip: true
          onTextChanged: root.searchQuery = text

          Text {
            anchors.fill: parent
            visible: !searchInput.text && !searchInput.activeFocus
            textFormat: Text.PlainText
            text: "Search notifications (/)..."
            font: searchInput.font
            color: root.dimColor
          }

          Keys.onEscapePressed: function() {
            searchInput.text = ""
            root.forceActiveFocus()
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
            color: root.dimColor
          }

          MouseArea {
            id: clearSearchMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              searchInput.text = ""
              root.searchQuery = ""
              root.forceActiveFocus()
            }
          }
        }
      }
    }

    // ==================== SECTION 3: FILTER CHIPS ====================
    Flickable {
      Layout.fillWidth: true
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
            { name: "All", count: root.countAll },
            { name: "Unread", count: root.countUnread },
            { name: "Urgent", count: root.countUrgent },
            { name: "Messages", count: root.countMessages },
            { name: "Pinned", count: root.countPinned },
            { name: "Snoozed", count: root.countSnoozed }
          ]

          Rectangle {
            height: Style.space(26)
            implicitWidth: chipInnerRow.implicitWidth + Style.space(16)
            radius: height / 2
            color: root.activeFilter === modelData.name
              ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.22)
              : (chipMouse.containsMouse ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1) : root.subtleBg)
            border.color: root.activeFilter === modelData.name ? Commons.Color.accent : root.subtleBorder
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
                color: root.activeFilter === modelData.name ? Commons.Color.accent : root.foreground
              }

              Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: countTxt.implicitWidth + Style.space(6)
                height: Style.space(15)
                radius: height / 2
                color: root.activeFilter === modelData.name ? Commons.Color.accent : Qt.rgba(foreground.r, foreground.g, foreground.b, 0.12)

                Text {
                  id: countTxt
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: String(modelData.count)
                  font.family: Style.font.family
                  font.pixelSize: Style.space(9)
                  font.bold: true
                  color: root.activeFilter === modelData.name ? Commons.Color.background : root.foreground
                }
              }
            }

            MouseArea {
              id: chipMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.activeFilter = modelData.name
                root.forceActiveFocus()
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

      // Empty State
      Column {
        anchors.centerIn: parent
        visible: notifListModel.count === 0
        spacing: Style.space(6)

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          textFormat: Text.PlainText
          text: "No notifications"
          font.family: Style.font.family
          font.pixelSize: Math.max(14, Style.font.body)
          font.bold: true
          color: root.foreground
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          textFormat: Text.PlainText
          text: "All caught up for now."
          font.family: Style.font.family
          font.pixelSize: Math.max(12, Style.font.caption)
          color: root.dimColor
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
            color: section === "Needs attention" ? Commons.Color.urgent : root.dimColor
          }
        }

        delegate: NotificationCard {
          id: cardDelegate
          required property string key
          required property string sectionName
          required property bool isRead
          required property bool isPinned
          required property bool isSnoozed
          required property bool isGroupHeader
          required property int groupExtraCount
          required property bool groupExpanded
          required property int index

          width: notifListView.width
          notificationData: root.notifDataByKey[key] || ({})
          isRead: cardDelegate.isRead
          isPinned: cardDelegate.isPinned
          isSnoozed: cardDelegate.isSnoozed
          isGroupHeader: cardDelegate.isGroupHeader
          groupExtraCount: cardDelegate.groupExtraCount
          groupExpanded: cardDelegate.groupExpanded

          onDismissed: function(k) { root.dismissItem(k) }
          onActionTriggered: function(k, actId) { root.triggerAction(k, actId) }
          onReplySubmitted: function(k, text) { root.submitReply(k, text) }
          onSnoozeRequested: function(k, sec) { root.snoozeItem(k, sec) }
          onWakeRequested: function(k) { root.wakeItem(k) }
          onPinToggled: function(k) { root.togglePin(k) }
          onMuteAppRequested: function(app) { root.muteApp(app) }
          onGroupToggleRequested: function(app) { root.toggleGroup(app) }
        }
      }
    }

    // ==================== SECTION 5: UNDO TOAST ====================
    Rectangle {
      id: undoToast
      Layout.fillWidth: true
      height: Style.space(38)
      visible: root.undoVisible
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
          text: root.undoMessage
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
          color: root.foreground
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
            text: "Undo"
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
            onClicked: root.performUndo()
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
      x: root.focusMenuX
      y: root.focusMenuY
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
          visible: root.dndActive
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
                text: root.userState.focusUntil > 0 ? "Focus Mode Active" : "Focus On Indefinitely"
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                color: root.foreground
              }

              Text {
                textFormat: Text.PlainText
                text: root.userState.focusUntil > 0
                  ? (root.formatRemainingDetailed(root.userState.focusUntil) + " • until " + root.formatExpiryClock(root.userState.focusUntil))
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
            { label: "For 30 minutes", sec: 1800 },
            { label: "For 1 hour", sec: 3600 },
            { label: "Until tomorrow", sec: 86400 },
            { label: "Until turned off", sec: 0 }
          ]

          Rectangle {
            width: parent.width
            height: Style.space(28)
            radius: Style.space(5)
            scale: fOptMouse.pressed ? 0.96 : 1.0
            Behavior on scale { NumberAnimation { duration: Style.duration(60) } }

            readonly property bool isCurrentChoice: {
              if (!root.dndActive) return false
              if (modelData.sec === 0) return root.userState.focusUntil === 0
              if (root.userState.focusUntil > 0) {
                var diff = root.userState.focusUntil - root.currentEpochSec
                return Math.abs(diff - modelData.sec) <= 300
              }
              return false
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
                color: isCurrentChoice ? Commons.Color.accent : (fOptMouse.containsMouse ? Commons.Color.accent : root.foreground)
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
              onClicked: root.setFocusDuration(modelData.sec)
            }
          }
        }

        // Divider
        Rectangle {
          visible: root.dndActive
          width: parent.width
          height: 1
          color: root.subtleBorder
        }

        // Turn Off Focus Button
        Rectangle {
          visible: root.dndActive
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
              text: "Turn off Focus"
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
            onClicked: root.setFocusDuration(-1)
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
      x: root.mutedAppsX
      y: root.mutedAppsY
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
          text: "Muted Applications"
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
          color: root.foreground
        }

        Repeater {
          model: Object.keys(root.userState.mutedApps || {})

          Rectangle {
            width: parent.width
            height: Style.space(28)
            radius: Style.space(4)
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)

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
                color: root.foreground
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
                  text: "Unmute"
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
                    root.unmuteApp(String(modelData))
                    if (Object.keys(root.userState.mutedApps || {}).length === 0) {
                      mutedAppsOverlay.visible = false
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
}
