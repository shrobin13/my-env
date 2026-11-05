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

  function setFocusDuration(seconds) {
    focusMenu.visible = false
    if (seconds > 0) {
      root.userState.focusUntil = Math.floor(Date.now() / 1000) + seconds
      actionProc.command = ["omarchy-shell", "notifications", "setDnd", "on"]
    } else {
      root.userState.focusUntil = 0
      actionProc.command = ["omarchy-shell", "notifications", "toggleDnd"]
    }
    actionProc.running = true
    root.saveState()
  }

  Process {
    id: actionProc
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

  ColumnLayout {
    anchors.fill: parent
    spacing: Style.space(12)

    // ==================== SECTION 1: HEADER ====================
    RowLayout {
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

      // Focus (DND) Button with Duration Menu
      Rectangle {
        id: focusBtn
        height: Style.space(32)
        implicitWidth: focusRow.implicitWidth + Style.space(18)
        radius: height / 2
        color: root.userState.focusUntil > 0
          ? Commons.Color.urgent
          : (focusMouse.containsMouse ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12) : root.subtleBg)
        border.color: root.userState.focusUntil > 0 ? Commons.Color.urgent : root.subtleBorder
        border.width: 1

        Row {
          id: focusRow
          anchors.centerIn: parent
          spacing: Style.space(6)

          Text {
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: root.userState.focusUntil > 0 ? "\uf1f6" : "\uf0f3"
            font.family: Style.font.family
            font.pixelSize: Style.space(12)
            color: root.userState.focusUntil > 0 ? Commons.Color.background : root.foreground
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: "Focus"
            font.family: Style.font.family
            font.pixelSize: Math.max(12, Style.font.caption)
            font.bold: true
            color: root.userState.focusUntil > 0 ? Commons.Color.background : root.foreground
          }
        }

        MouseArea {
          id: focusMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: focusMenu.visible = !focusMenu.visible
        }

        // Focus Menu
        Rectangle {
          id: focusMenu
          visible: false
          z: 200
          width: Style.space(140)
          height: focusCol.implicitHeight + Style.space(12)
          anchors.top: parent.bottom
          anchors.topMargin: Style.space(4)
          anchors.right: parent.right
          radius: Math.max(8, Style.cornerRadius)
          color: Commons.Color.popups.background
          border.color: Commons.Color.popups.border
          border.width: 1

          Column {
            id: focusCol
            anchors.fill: parent
            anchors.margins: Style.space(6)
            spacing: Style.space(4)

            Repeater {
              model: [
                { label: "For 30 minutes", sec: 1800 },
                { label: "For 1 hour", sec: 3600 },
                { label: "Until tomorrow", sec: 86400 },
                { label: "Until turned off", sec: 0 }
              ]
              Rectangle {
                width: parent.width
                height: Style.space(26)
                radius: Style.space(4)
                color: fOptMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.2) : "transparent"

                Text {
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: modelData.label
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  color: fOptMouse.containsMouse ? Commons.Color.accent : root.foreground
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
          }
        }
      }

      // Clear All Button (skips pinned items)
      Rectangle {
        id: clearAllBtn
        visible: root.countAll > 0
        height: Style.space(32)
        implicitWidth: clearRow.implicitWidth + Style.space(16)
        radius: height / 2
        color: clearAllMouse.containsMouse ? Qt.rgba(Commons.Color.urgent.r, Commons.Color.urgent.g, Commons.Color.urgent.b, 0.18) : root.subtleBg
        border.color: clearAllMouse.containsMouse ? Commons.Color.urgent : root.subtleBorder
        border.width: 1

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
