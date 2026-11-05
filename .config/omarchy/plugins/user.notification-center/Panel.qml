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
    var userState = notifPanel ? notifPanel.userState : Model.defaultUserState()
    for (var i = 0; i < notifications.length; i++) {
      var it = notifications[i]
      if (!Model.isRead(userState, it.key) && !Model.isSnoozed(userState, it.key)) {
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
  readonly property real iconSize: Math.max(10, Math.min(24, Number(setting("iconSize", 18))))

  function updateNotifications() {
    var liveText = liveFile.text()
    var historyText = historyFile.text()
    root.notifications = Model.parseNotifications(liveText, historyText)
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
    actionProc.command = ["omarchy-shell", "notifications", "toggleDnd"]
    actionProc.running = true
    root.dndActive = !root.dndActive
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

  Process {
    id: actionProc
    onExited: function(exitCode) {
      root.refresh()
    }
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

  // Periodic refresh
  Timer {
    interval: 30000
    running: root.opened
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
    fixedWidth: root.neededWidth
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
    owner: root
    bar: root.bar
    open: root.opened
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(Style.space(640), Style.space(720))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      NotificationPanel {
        id: notifPanel
        anchors.fill: parent
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
