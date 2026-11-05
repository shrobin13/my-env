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

  // Undo system
  property var undoItems: []
  property string undoMessage: ""
  property bool undoVisible: false

  readonly property color foreground: Commons.Color.foreground
  readonly property color dimColor: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.65)
  readonly property color subtleBg: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.055)
  readonly property color subtleBorder: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.12)

  // Live filtered and grouped items
  readonly property var filteredList: Model.filterNotifications(rawNotifications, userState, activeFilter, searchQuery)
  readonly property var displayList: Model.groupNotifications(filteredList, expandedApps)

  // Live filter counts
  readonly property int countAll: {
    var c = 0
    for (var i = 0; i < rawNotifications.length; i++) {
      var it = rawNotifications[i]
      if (!Model.isSnoozed(userState, it.key) && !Model.isMuted(userState, it.app)) c++
    }
    return c
  }

  readonly property int countUnread: {
    var c = 0
    for (var i = 0; i < rawNotifications.length; i++) {
      var it = rawNotifications[i]
      if (!Model.isRead(userState, it.key) && !Model.isSnoozed(userState, it.key) && !Model.isMuted(userState, it.app)) c++
    }
    return c
  }

  readonly property int countUrgent: {
    var c = 0
    for (var i = 0; i < rawNotifications.length; i++) {
      var it = rawNotifications[i]
      if (it.urgency === 2 && !Model.isSnoozed(userState, it.key) && !Model.isMuted(userState, it.app)) c++
    }
    return c
  }

  readonly property int countMessages: {
    var c = 0
    for (var i = 0; i < rawNotifications.length; i++) {
      var it = rawNotifications[i]
      if (Model.supportsReply(it) && !Model.isSnoozed(userState, it.key) && !Model.isMuted(userState, it.app)) c++
    }
    return c
  }

  readonly property int countPinned: {
    var c = 0
    for (var i = 0; i < rawNotifications.length; i++) {
      if (Model.isPinned(userState, rawNotifications[i].key)) c++
    }
    return c
  }

  // ---------------------------------------------------------------------------
  // STATE PERSISTENCE
  // ---------------------------------------------------------------------------
  readonly property string stateFilePath: Quickshell.env("HOME") + "/.local/state/omarchy/notifications/user-state.json"

  FileView {
    id: userStateFile
    path: root.stateFilePath
    watchChanges: true
    printErrors: false
    onLoaded: {
      root.userState = Model.parseUserState(text())
    }
  }

  function saveState() {
    var jsonText = Model.serializeUserState(root.userState)
    var script = Quickshell.env("HOME") + "/.config/omarchy/plugins/user.notification-center/manage.py"
    stateSaveProc.command = ["python3", script, "save-state", jsonText]
    stateSaveProc.running = true
  }

  Process {
    id: stateSaveProc
  }

  // 1-second read timer: marks cards as read after panel has been open for 1s
  Timer {
    id: readTimer
    interval: 1000
    running: root.panelOpened
    repeat: false
    onTriggered: {
      var changed = false
      for (var i = 0; i < root.displayList.length; i++) {
        var k = root.displayList[i].key
        if (k && !root.userState.readKeys[k]) {
          root.userState.readKeys[k] = true
          changed = true
        }
      }
      if (changed) {
        root.userStateChanged()
        root.saveState()
      }
    }
  }

  // ---------------------------------------------------------------------------
  // CARD ACTIONS & DISMISSAL
  // ---------------------------------------------------------------------------
  function dismissItem(key) {
    var target = null
    var updated = []
    for (var i = 0; i < root.rawNotifications.length; i++) {
      if (root.rawNotifications[i].key === key) {
        target = root.rawNotifications[i]
      } else {
        updated.push(root.rawNotifications[i])
      }
    }
    if (target) {
      root.rawNotifications = updated
      // Store in undo
      root.undoItems = [target]
      root.undoMessage = "Notification dismissed"
      root.undoVisible = true
      undoTimer.restart()

      // Inform backend
      actionProc.command = ["python3", Quickshell.env("HOME") + "/.config/omarchy/plugins/user.notification-center/manage.py", "delete", key]
      actionProc.running = true
    }
  }

  function clearAllNonPinned() {
    var toKeep = []
    var toClear = []
    for (var i = 0; i < root.rawNotifications.length; i++) {
      var it = root.rawNotifications[i]
      if (Model.isPinned(root.userState, it.key)) {
        toKeep.push(it)
      } else {
        toClear.push(it)
      }
    }

    if (toClear.length > 0) {
      root.undoItems = toClear
      root.undoMessage = "Cleared " + toClear.length + " notifications"
      root.undoVisible = true
      undoTimer.restart()

      root.rawNotifications = toKeep
      actionProc.command = ["python3", Quickshell.env("HOME") + "/.config/omarchy/plugins/user.notification-center/manage.py", "clear"]
      actionProc.running = true
    }
  }

  function performUndo() {
    if (root.undoItems.length > 0) {
      var merged = root.undoItems.concat(root.rawNotifications)
      root.rawNotifications = merged
      root.undoItems = []
      root.undoVisible = false
    }
  }

  function togglePin(key) {
    var p = Object.assign({}, root.userState.pinned)
    if (p[key]) delete p[key]
    else p[key] = true
    root.userState.pinned = p
    root.userStateChanged()
    root.saveState()
  }

  function snoozeItem(key, seconds) {
    var s = Object.assign({}, root.userState.snoozed)
    s[key] = Math.floor(Date.now() / 1000) + seconds
    root.userState.snoozed = s
    root.userStateChanged()
    root.saveState()
  }

  function muteApp(app) {
    var m = Object.assign({}, root.userState.mutedApps)
    m[app] = true
    root.userState.mutedApps = m
    root.userStateChanged()
    root.saveState()
  }

  function toggleGroup(app) {
    var ex = Object.assign({}, root.expandedApps)
    ex[app] = !ex[app]
    root.expandedApps = ex
  }

  function triggerAction(key, actionId) {
    actionProc.command = ["python3", Quickshell.env("HOME") + "/.config/omarchy/plugins/user.notification-center/manage.py", "run-action", key, actionId]
    actionProc.running = true
  }

  function submitReply(key, text) {
    actionProc.command = ["python3", Quickshell.env("HOME") + "/.config/omarchy/plugins/user.notification-center/manage.py", "reply", key, text]
    actionProc.running = true
  }

  property bool dndActive: false
  property int currentEpochSec: Math.floor(Date.now() / 1000)

  Timer {
    id: clockTickTimer
    interval: 1000
    running: root.panelOpened
    repeat: true
    onTriggered: {
      root.currentEpochSec = Math.floor(Date.now() / 1000)
      if (root.dndActive && root.userState.focusUntil > 0 && root.currentEpochSec >= root.userState.focusUntil) {
        root.setFocusDuration(-1)
      }
    }
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
      var remaining = Math.max(0, root.userState.focusUntil - currentEpochSec)
      if (remaining <= 0) return "Focus: Expired"
      var mins = Math.ceil(remaining / 60)
      if (mins < 60) {
        return "Focus: " + mins + "m"
      }
      var hrs = Math.floor(mins / 60)
      var remMins = mins % 60
      return remMins > 0 ? ("Focus: " + hrs + "h " + remMins + "m") : ("Focus: " + hrs + "h")
    }
    return "Focus: On"
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
    focusMenu.visible = false
    var script = Quickshell.env("HOME") + "/.config/omarchy/plugins/user.notification-center/manage.py"
    if (seconds > 0) {
      root.userState.focusUntil = Math.floor(Date.now() / 1000) + seconds
      root.dndActive = true
      Quickshell.execDetached(["omarchy-shell", "notifications", "setDnd", "on"])
    } else if (seconds === 0) {
      root.userState.focusUntil = 0
      root.dndActive = true
      Quickshell.execDetached(["omarchy-shell", "notifications", "setDnd", "on"])
    } else {
      // Turn off
      root.userState.focusUntil = 0
      root.dndActive = false
      Quickshell.execDetached(["omarchy-shell", "notifications", "setDnd", "off"])
    }
    var jsonText = Model.serializeUserState(root.userState)
    Quickshell.execDetached(["python3", script, "save-state", jsonText])
  }

  Process {
    id: actionProc
    onExited: function(exitCode) {
      quietFile.reload()
    }
  }

  Timer {
    id: undoTimer
    interval: 5000
    repeat: false
    onTriggered: {
      root.undoVisible = false
      root.undoItems = []
    }
  }

  // ---------------------------------------------------------------------------
  // LAYOUT & KEYBOARD CONTROLS
  // ---------------------------------------------------------------------------
  focus: true
  Keys.onUpPressed: notifListView.decrementCurrentIndex()
  Keys.onDownPressed: notifListView.incrementCurrentIndex()
  Keys.onDeletePressed: {
    if (notifListView.currentItem && notifListView.currentItem.notificationData) {
      root.dismissItem(notifListView.currentItem.notificationData.key)
    }
  }
  Keys.onReturnPressed: {
    if (notifListView.currentItem && notifListView.currentItem.notificationData) {
      var d = notifListView.currentItem.notificationData
      var acts = Model.getCardActions(d)
      if (acts.direct.length > 0) {
        root.triggerAction(d.key, acts.direct[0].id)
      }
    }
  }
  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Slash && !searchInput.activeFocus) {
      searchInput.forceActiveFocus()
      event.accepted = true
    } else if (event.key === Qt.Key_Escape) {
      if (searchInput.text !== "") {
        searchInput.text = ""
        event.accepted = true
      } else {
        root.closeRequested()
        event.accepted = true
      }
    }
  }

  // Background click catcher to dismiss focusMenu if clicking outside
  MouseArea {
    id: focusMenuDismissArea
    anchors.fill: parent
    z: 490
    visible: focusMenu.visible
    hoverEnabled: true
    acceptedButtons: Qt.AllButtons
    onClicked: focusMenu.visible = false
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: Style.space(12)

    // ==================== SECTION 1: HEADER ====================
    RowLayout {
      id: headerRow
      Layout.fillWidth: true
      z: 500

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

      // Focus (DND) Button with Duration Menu
      Rectangle {
        id: focusBtn
        height: Style.space(32)
        implicitWidth: focusRow.implicitWidth + Style.space(20)
        radius: Style.space(8)

        scale: (focusMouse.pressed || focusChevronMouse.pressed)
          ? 0.95
          : (focusMouse.containsMouse || focusChevronMouse.containsMouse ? 1.02 : 1.0)
        Behavior on scale {
          NumberAnimation { duration: Style.duration(70); easing.type: Easing.OutQuad }
        }

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

        Behavior on color {
          ColorAnimation { duration: Style.duration(70); easing.type: Easing.OutQuad }
        }
        Behavior on border.color {
          ColorAnimation { duration: Style.duration(70); easing.type: Easing.OutQuad }
        }

        RowLayout {
          id: focusRow
          anchors.fill: parent
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(8)
          spacing: Style.space(6)

          // Clickable main body: Click to toggle Focus ON / OFF directly
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

          // Small divider line
          Rectangle {
            width: 1
            height: Style.space(14)
            color: root.dndActive ? Qt.rgba(0, 0, 0, 0.25) : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.22)
            Layout.alignment: Qt.AlignVCenter
          }

          // Dropdown chevron button: Click to open duration menu
          Item {
            Layout.fillHeight: true
            implicitWidth: Style.space(14)

            Text {
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: focusMenu.visible ? "\uf0d8" : "\uf0d7"
              font.family: Style.font.family
              font.pixelSize: Style.space(10)
              color: root.dndActive ? Commons.Color.background : (focusChevronMouse.containsMouse ? Commons.Color.accent : root.dimColor)
            }

            MouseArea {
              id: focusChevronMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: focusMenu.visible = !focusMenu.visible
            }
          }
        }

        // Focus Duration Menu Dropdown
        Rectangle {
          id: focusMenu
          visible: false
          z: 1000
          width: Style.space(210)
          height: focusCol.implicitHeight + Style.space(16)
          anchors.top: parent.bottom
          anchors.topMargin: Style.space(6)
          anchors.right: parent.right
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

            // Options List
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

            // Divider before Turn Off button
            Rectangle {
              visible: root.dndActive
              width: parent.width
              height: 1
              color: root.subtleBorder
            }

            // Turn Off Button
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

      // Clear All Button (skips pinned items)
      Rectangle {
        id: clearAllBtn
        visible: root.countAll > 0
        height: Style.space(32)
        implicitWidth: clearRow.implicitWidth + Style.space(16)
        radius: Style.space(8)

        scale: clearAllMouse.pressed ? 0.95 : (clearAllMouse.containsMouse ? 1.02 : 1.0)
        Behavior on scale {
          NumberAnimation { duration: Style.duration(70); easing.type: Easing.OutQuad }
        }

        color: clearAllMouse.pressed
          ? Qt.rgba(Commons.Color.urgent.r, Commons.Color.urgent.g, Commons.Color.urgent.b, 0.35)
          : (clearAllMouse.containsMouse
             ? Qt.rgba(Commons.Color.urgent.r, Commons.Color.urgent.g, Commons.Color.urgent.b, 0.22)
             : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08))
        border.color: clearAllMouse.containsMouse
          ? Commons.Color.urgent
          : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.20)
        border.width: 1

        Behavior on color {
          ColorAnimation { duration: Style.duration(70); easing.type: Easing.OutQuad }
        }
        Behavior on border.color {
          ColorAnimation { duration: Style.duration(70); easing.type: Easing.OutQuad }
        }

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
            color: clearAllMouse.containsMouse ? Commons.Color.urgent : root.dimColor
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: "Clear all"
            font.family: Style.font.family
            font.pixelSize: Math.max(12, Style.font.caption)
            font.bold: true
            color: clearAllMouse.containsMouse ? Commons.Color.urgent : root.foreground
          }
        }

        MouseArea {
          id: clearAllMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.clearAllNonPinned()
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
          onTextEdited: root.searchQuery = text

          Text {
            anchors.fill: parent
            visible: !searchInput.text && !searchInput.activeFocus
            textFormat: Text.PlainText
            text: "Search notifications (/)..."
            font: searchInput.font
            color: root.dimColor
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
            }
          }
        }
      }
    }

    // ==================== SECTION 3: FILTER CHIPS ====================
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(8)

      Repeater {
        model: [
          { name: "All", count: root.countAll },
          { name: "Unread", count: root.countUnread },
          { name: "Urgent", count: root.countUrgent },
          { name: "Messages", count: root.countMessages },
          { name: "Pinned", count: root.countPinned }
        ]

        Rectangle {
          height: Style.space(26)
          implicitWidth: chipRow.implicitWidth + Style.space(14)
          radius: height / 2
          color: root.activeFilter === modelData.name
            ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.22)
            : (chipMouse.containsMouse ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1) : root.subtleBg)
          border.color: root.activeFilter === modelData.name ? Commons.Color.accent : root.subtleBorder
          border.width: 1

          Row {
            id: chipRow
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
            onClicked: root.activeFilter = modelData.name
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
        visible: root.displayList.length === 0
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

      // Smooth ListView
      ListView {
        id: notifListView
        anchors.fill: parent
        model: root.displayList
        clip: true
        spacing: Style.space(10)
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

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
          required property var modelData
          required property int index

          width: notifListView.width
          notificationData: modelData
          isRead: Boolean(modelData && modelData.isRead)
          isPinned: Boolean(modelData && modelData.isPinned)
          isGroupHeader: Boolean(modelData && modelData.isGroupHeader)
          groupExtraCount: (modelData && modelData.groupExtraCount) || 0
          groupExpanded: Boolean(modelData && modelData.groupExpanded)

          onDismissed: function(key) { root.dismissItem(key) }
          onActionTriggered: function(key, actId) { root.triggerAction(key, actId) }
          onReplySubmitted: function(key, text) { root.submitReply(key, text) }
          onSnoozeRequested: function(key, sec) { root.snoozeItem(key, sec) }
          onPinToggled: function(key) { root.togglePin(key) }
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
}
