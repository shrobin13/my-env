import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "user.notification-center"
  ipcTarget: "user.notification-center"
  manageIpc: true

  property var notifications: []
  property bool dndActive: false

  readonly property int unreadCount: {
    var count = 0
    var userState = notifPanel.userState
    var nowSec = Math.floor(Date.now() / 1000)
    for (var i = 0; i < notifications.length; i++) {
      var it = notifications[i]
      if (!Model.isCleared(userState, it) && !Model.isRead(userState, it.key) && !Model.isSnoozed(userState, it.key, nowSec) && !Model.isMuted(userState, it.app) &&
          !notifPanel.committedDeletes[it.key] && !notifPanel.pendingDeletesMap[it.key]) {
        count++
      }
    }
    return count
  }

  readonly property real neededWidth: unreadCount > 0
    ? Math.max(Style.bar.iconSlot + Style.space(20), Style.space(48))
    : (Style.bar.iconSlot + Style.space(8))

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color dimColor: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.65)

  function updateNotifications() {
    try {
      root.notifications = Model.parseNotifications(liveFile.text(), historyFile.text())
    } catch (e) {
      root.notifications = []
    }
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

  function refresh() {
    liveFile.reload()
    historyFile.reload()
    quietFile.reload()
  }

  function toggleDnd() {
    var script = Quickshell.env("HOME") + "/.config/omarchy/plugins/user.notification-center/manage.py"
    Quickshell.execDetached(["python3", script, "toggle-dnd"])
  }

  function open() {
    refresh()
    controller.show()
  }

  function close() {
    controller.hide()
  }

  function toggle() {
    opened ? close() : open()
  }

  Commons.Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }

  FileView {
    id: historyFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/notifications/history.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.updateNotifications()
  }

  FileView {
    id: liveFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/notifications/live.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.updateNotifications()
  }

  FileView {
    id: quietFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/notifications/quiet.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.updateQuiet()
  }

  // Periodic refresh (30s) to reconcile snoozed expiry and time updates
  Timer {
    interval: 30000
    running: true
    repeat: true
    onTriggered: root.updateNotifications()
  }

  // Spacing to guarantee breathing room and no collisions
  implicitWidth: button.implicitWidth + Style.space(8)
  implicitHeight: button.implicitHeight

  // ---- Status Bar Button ----
  BarIconButton {
    id: button
    anchors.fill: parent
    anchors.leftMargin: Style.space(4)
    anchors.rightMargin: Style.space(4)
    bar: root.bar
    text: root.dndActive ? "\uf1f6" : "\uf0f3"
    active: root.opened
    slotSize: root.neededWidth
    fixedWidth: bar && bar.vertical ? -1 : root.neededWidth
    fixedHeight: bar && bar.vertical ? root.neededWidth : -1
    labelText: root.unreadCount > 0 ? (root.unreadCount > 99 ? "99+" : String(root.unreadCount)) : ""
    tooltipText: root.dndActive
      ? strings.t("dnd")
      : (root.unreadCount > 0
         ? strings.tn("notifications", root.unreadCount).arg(root.unreadCount)
         : strings.t("noNotifications"))

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton || buttonCode === Qt.MiddleButton) {
        root.toggleDnd()
      } else {
        root.toggle()
      }
    }
  }

  // ---- Popout Notification Center Panel ----
  KeyboardPanel {
    id: panel
    anchorItem: button
    focusTarget: keyCatcher
    owner: root
    bar: root.bar
    open: root.opened
    margin: Style.gapsOut
    contentWidth: panel.fittedContentWidth(
      Math.max(Style.space(280), Math.min(Style.space(500), panel.screenW - (2 * Style.gapsOut)))
    )
    contentHeight: panel.fittedContentHeight(Style.space(640), Style.space(720))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      clip: true
      blocked: notifPanel.isInputActive
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) { notifPanel.moveCursor(dx, dy) }
      onActivateRequested: notifPanel.activateSelected()
      onDeleteRequested: notifPanel.deleteSelected()
      onTextKey: function(text, modifiers) { notifPanel.handleTextKey(text, modifiers) }

      NotificationPanel {
        id: notifPanel
        anchors.fill: parent
        clip: true
        anchors.margins: Style.space(16)
        bar: root.bar
        panelOpened: root.opened
        dndActive: root.dndActive
        rawNotifications: root.notifications
        onCloseRequested: root.close()
      }
    }
  }
}
