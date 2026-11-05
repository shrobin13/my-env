import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
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
  property bool keepAwakeActive: false
  property bool nightLightActive: false

  readonly property int unreadCount: notifications.length
  readonly property real neededWidth: unreadCount > 0
    ? Math.max(Style.bar.iconSlot + Style.space(20), Style.space(48))
    : (Style.bar.iconSlot + Style.space(8))

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property real volumeLevel: (sink && sink.audio) ? sink.audio.volume : 0.0
  readonly property bool isMuted: (sink && sink.audio) ? sink.audio.muted : false

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color dimColor: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.65)
  readonly property color subtleBg: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.055)
  readonly property color subtleBorder: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.12)
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
    stayAwakeFile.reload()
    nightlightStatusProc.running = true
  }

  function runManageCmd(args) {
    var script = Quickshell.env("HOME") + "/.config/omarchy/plugins/user.notification-center/manage.py"
    actionProc.command = ["python3", script].concat(args)
    actionProc.running = true
  }

  function clearAllNotifications() {
    runManageCmd(["clear"])
    root.notifications = []
  }

  function deleteNotification(key) {
    runManageCmd(["delete", key])
    var updated = []
    for (var i = 0; i < root.notifications.length; i++) {
      if (root.notifications[i].key !== key) updated.push(root.notifications[i])
    }
    root.notifications = updated
  }

  function triggerAction(key) {
    runManageCmd(["run-action", key])
  }

  function toggleDnd() {
    runManageCmd(["toggle-dnd"])
    root.dndActive = !root.dndActive
  }

  function toggleIdle() {
    runManageCmd(["toggle-idle"])
    stayAwakeFile.reload()
  }

  function toggleNightLight() {
    runManageCmd(["toggle-nightlight"])
    nightlightStatusProc.running = true
  }

  function triggerSnip() {
    root.close()
    runManageCmd(["snip"])
  }

  function triggerClipboard() {
    root.close()
    runManageCmd(["clipboard"])
  }

  function toggleMute() {
    if (sink && sink.audio) {
      sink.audio.muted = !sink.audio.muted
    }
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

  Process {
    id: nightlightStatusProc
    command: ["omarchy-toggle-nightlight", "--status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: function() {
        try {
          var p = JSON.parse(text)
          root.nightLightActive = !!p.enabled
        } catch(e) {}
      }
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

  FileView {
    id: stayAwakeFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/indicators/stay-awake"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      root.keepAwakeActive = true
    }
    onLoadFailed: {
      root.keepAwakeActive = false
    }
  }

  // Periodic refresh so "Xm ago" relative timestamps remain accurate
  Timer {
    interval: 30000
    running: root.opened
    repeat: true
    onTriggered: root.updateNotifications()
  }

  // Generous spacing to guarantee no collisions with neighbor icons
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
    contentWidth: panel.fittedContentWidth(Style.space(410))
    contentHeight: panel.fittedContentHeight(mainColumn.implicitHeight + Style.space(28), Style.space(680))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        anchors.margins: Style.space(16)
        contentWidth: width
        contentHeight: mainColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: mainColumn
          width: panelFlick.width
          spacing: Style.space(16)

          // ==================== SECTION 1: HEADER ====================
          RowLayout {
            width: parent.width

            // Title + Unread Count Badge
            RowLayout {
              spacing: Style.space(10)

              Text {
                textFormat: Text.PlainText
                text: strings.t("title")
                font.family: Style.font.family
                font.pixelSize: Math.max(16, Style.font.title)
                font.bold: true
                color: root.foreground
              }

              Rectangle {
                visible: root.unreadCount > 0
                width: badgeText.implicitWidth + Style.space(12)
                height: Style.space(20)
                radius: height / 2
                color: Commons.Color.accent

                Text {
                  id: badgeText
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: String(root.unreadCount)
                  font.family: Style.font.family
                  font.pixelSize: Math.max(11, Style.font.caption)
                  font.bold: true
                  color: Commons.Color.background
                }
              }
            }

            Item { Layout.fillWidth: true }

            // Right: DND Toggle Pill Button
            Rectangle {
              id: dndBtn
              width: dndRow.implicitWidth + Style.space(18)
              height: Style.space(32)
              radius: height / 2
              color: root.dndActive
                ? Commons.Color.urgent
                : (dndMouse.containsMouse ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12) : root.subtleBg)
              border.color: root.dndActive ? Commons.Color.urgent : root.subtleBorder
              border.width: 1

              Behavior on color {
                ColorAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic }
              }

              Row {
                id: dndRow
                anchors.centerIn: parent
                spacing: Style.space(7)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: root.dndActive ? "\uf1f6" : "\uf0f3"
                  font.family: Style.font.family
                  font.pixelSize: Style.space(13)
                  color: root.dndActive ? Commons.Color.background : root.foreground
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: "DND"
                  font.family: Style.font.family
                  font.pixelSize: Math.max(12, Style.font.caption)
                  font.bold: true
                  color: root.dndActive ? Commons.Color.background : root.foreground
                }
              }

              MouseArea {
                id: dndMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleDnd()
              }
            }

            // Clear All Button
            Rectangle {
              id: clearBtn
              visible: root.unreadCount > 0
              width: clearRow.implicitWidth + Style.space(16)
              height: Style.space(32)
              radius: height / 2
              color: clearMouse.containsMouse ? Qt.rgba(Commons.Color.urgent.r, Commons.Color.urgent.g, Commons.Color.urgent.b, 0.2) : root.subtleBg
              border.color: clearMouse.containsMouse ? Commons.Color.urgent : root.subtleBorder
              border.width: 1

              Behavior on color {
                ColorAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic }
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
                  color: clearMouse.containsMouse ? Commons.Color.urgent : root.dimColor
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: strings.t("clearAll")
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
                onClicked: root.clearAllNotifications()
              }
            }
          }

          // ==================== SECTION 2: USEFUL QUICK CONTROLS ====================
          Column {
            width: parent.width
            spacing: Style.space(8)

            Text {
              textFormat: Text.PlainText
              text: strings.t("quickControls")
              font.family: Style.font.family
              font.pixelSize: Math.max(12, Style.font.body)
              font.bold: true
              color: root.dimColor
            }

            GridLayout {
              width: parent.width
              columns: 4
              rowSpacing: Style.space(10)
              columnSpacing: Style.space(10)

              // 1. Keep Awake (Caffeine / Inhibit Idle)
              Rectangle {
                Layout.fillWidth: true
                height: Style.space(62)
                radius: Math.max(10, Style.cornerRadius)
                color: root.keepAwakeActive
                  ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.22)
                  : (awakeMouse.containsMouse ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1) : root.subtleBg)
                border.color: root.keepAwakeActive ? Commons.Color.accent : root.subtleBorder
                border.width: 1

                Behavior on color { ColorAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic } }

                Column {
                  anchors.centerIn: parent
                  spacing: Style.space(3)

                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    textFormat: Text.PlainText
                    text: "\udb80\udd76"
                    font.family: Style.font.family
                    font.pixelSize: Style.space(18)
                    color: root.keepAwakeActive ? Commons.Color.accent : root.foreground
                  }
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    textFormat: Text.PlainText
                    text: strings.t("keepAwake")
                    font.family: Style.font.family
                    font.pixelSize: Math.max(11, Style.font.caption)
                    font.bold: true
                    color: root.foreground
                  }
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    textFormat: Text.PlainText
                    text: root.keepAwakeActive ? strings.t("stayAwakeActive") : strings.t("stayAwakeIdle")
                    font.family: Style.font.family
                    font.pixelSize: Style.space(10)
                    color: root.keepAwakeActive ? Commons.Color.accent : root.dimColor
                  }
                }
                MouseArea {
                  id: awakeMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.toggleIdle()
                }
              }

              // 2. Screen Snip / Region Screenshot
              Rectangle {
                Layout.fillWidth: true
                height: Style.space(62)
                radius: Math.max(10, Style.cornerRadius)
                color: snipMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.2) : root.subtleBg
                border.color: snipMouse.containsMouse ? Commons.Color.accent : root.subtleBorder
                border.width: 1

                Behavior on color { ColorAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic } }

                Column {
                  anchors.centerIn: parent
                  spacing: Style.space(3)

                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    textFormat: Text.PlainText
                    text: "\udb80\udd00"
                    font.family: Style.font.family
                    font.pixelSize: Style.space(18)
                    color: Commons.Color.accent
                  }
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    textFormat: Text.PlainText
                    text: strings.t("snip")
                    font.family: Style.font.family
                    font.pixelSize: Math.max(11, Style.font.caption)
                    font.bold: true
                    color: root.foreground
                  }
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    textFormat: Text.PlainText
                    text: "Region"
                    font.family: Style.font.family
                    font.pixelSize: Style.space(10)
                    color: root.dimColor
                  }
                }
                MouseArea {
                  id: snipMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.triggerSnip()
                }
              }

              // 3. Clipboard History
              Rectangle {
                Layout.fillWidth: true
                height: Style.space(62)
                radius: Math.max(10, Style.cornerRadius)
                color: clipMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.2) : root.subtleBg
                border.color: clipMouse.containsMouse ? Commons.Color.accent : root.subtleBorder
                border.width: 1

                Behavior on color { ColorAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic } }

                Column {
                  anchors.centerIn: parent
                  spacing: Style.space(3)

                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    textFormat: Text.PlainText
                    text: "\udb80\udd4c"
                    font.family: Style.font.family
                    font.pixelSize: Style.space(18)
                    color: Commons.Color.accent
                  }
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    textFormat: Text.PlainText
                    text: strings.t("clipboard")
                    font.family: Style.font.family
                    font.pixelSize: Math.max(11, Style.font.caption)
                    font.bold: true
                    color: root.foreground
                  }
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    textFormat: Text.PlainText
                    text: "History"
                    font.family: Style.font.family
                    font.pixelSize: Style.space(10)
                    color: root.dimColor
                  }
                }
                MouseArea {
                  id: clipMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.triggerClipboard()
                }
              }

              // 4. Night Light (Hyprsunset)
              Rectangle {
                Layout.fillWidth: true
                height: Style.space(62)
                radius: Math.max(10, Style.cornerRadius)
                color: root.nightLightActive
                  ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.22)
                  : (nlMouse.containsMouse ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1) : root.subtleBg)
                border.color: root.nightLightActive ? Commons.Color.accent : root.subtleBorder
                border.width: 1

                Behavior on color { ColorAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic } }

                Column {
                  anchors.centerIn: parent
                  spacing: Style.space(3)

                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    textFormat: Text.PlainText
                    text: "\udb81\ude46"
                    font.family: Style.font.family
                    font.pixelSize: Style.space(18)
                    color: root.nightLightActive ? Commons.Color.accent : root.foreground
                  }
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    textFormat: Text.PlainText
                    text: strings.t("nightLight")
                    font.family: Style.font.family
                    font.pixelSize: Math.max(11, Style.font.caption)
                    font.bold: true
                    color: root.foreground
                  }
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    textFormat: Text.PlainText
                    text: root.nightLightActive ? strings.t("nightLightOn") : strings.t("nightLightOff")
                    font.family: Style.font.family
                    font.pixelSize: Style.space(10)
                    color: root.nightLightActive ? Commons.Color.accent : root.dimColor
                  }
                }
                MouseArea {
                  id: nlMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.toggleNightLight()
                }
              }
            }
          }

          // ==================== SECTION 3: AUDIO VOLUME CONTROL ====================
          Rectangle {
            width: parent.width
            height: Style.space(48)
            radius: Math.max(10, Style.cornerRadius)
            color: root.subtleBg
            border.color: root.subtleBorder
            border.width: 1

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.space(14)
              anchors.rightMargin: Style.space(14)
              spacing: Style.space(12)

              // Mute / Speaker Icon
              Rectangle {
                width: Style.space(28)
                height: Style.space(28)
                radius: width / 2
                color: muteMouse.containsMouse ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12) : "transparent"

                Text {
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: root.isMuted
                    ? "\udb81\udd7f"
                    : (root.volumeLevel > 0.5 ? "\udb81\udd7e" : (root.volumeLevel > 0 ? "\udb81\udd80" : "\udb81\udd7f"))
                  font.family: Style.font.family
                  font.pixelSize: Style.space(17)
                  color: root.isMuted ? Commons.Color.urgent : Commons.Color.accent
                }

                MouseArea {
                  id: muteMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.toggleMute()
                }
              }

              // Volume Slider
              PanelSlider {
                Layout.fillWidth: true
                bar: root.bar
                value: root.volumeLevel
                minimum: 0.0
                maximum: 1.0
                step: 0.02
                onMoved: function(v) {
                  if (root.sink && root.sink.audio) {
                    root.sink.audio.volume = v
                    if (root.sink.audio.muted && v > 0) root.sink.audio.muted = false
                  }
                }
              }

              // Volume Percent Label
              Text {
                textFormat: Text.PlainText
                text: root.isMuted ? strings.t("muted") : (Math.round(root.volumeLevel * 100) + "%")
                font.family: Style.font.family
                font.pixelSize: Math.max(12, Style.font.body)
                font.bold: true
                color: root.isMuted ? Commons.Color.urgent : root.foreground
                Layout.preferredWidth: Style.space(46)
                horizontalAlignment: Text.AlignRight
              }
            }
          }

          PanelSeparator {
            width: parent.width
            foreground: root.foreground
          }

          // ==================== SECTION 4: NOTIFICATIONS LIST ====================
          RowLayout {
            width: parent.width

            Text {
              textFormat: Text.PlainText
              text: strings.tn("notifications", root.unreadCount).arg(root.unreadCount)
              font.family: Style.font.family
              font.pixelSize: Math.max(13, Style.font.body)
              font.bold: true
              color: root.foreground
            }

            Item { Layout.fillWidth: true }

            Text {
              visible: root.unreadCount > 0
              textFormat: Text.PlainText
              text: strings.t("recent")
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              color: root.dimColor
            }
          }

          // Empty State Card
          Rectangle {
            visible: root.unreadCount === 0
            width: parent.width
            height: Style.space(130)
            radius: Math.max(10, Style.cornerRadius)
            color: root.subtleBg
            border.color: root.subtleBorder
            border.width: 1

            Column {
              anchors.centerIn: parent
              spacing: Style.space(8)

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                textFormat: Text.PlainText
                text: "\uf058"
                font.family: Style.font.family
                font.pixelSize: Style.space(32)
                color: Commons.Color.accent
              }

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                textFormat: Text.PlainText
                text: strings.t("noNotifications")
                font.family: Style.font.family
                font.pixelSize: Math.max(14, Style.font.body)
                font.bold: true
                color: root.foreground
              }

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                textFormat: Text.PlainText
                text: strings.t("allCaughtUp")
                font.family: Style.font.family
                font.pixelSize: Math.max(12, Style.font.caption)
                color: root.dimColor
              }
            }
          }

          // Cards Column
          Column {
            visible: root.unreadCount > 0
            width: parent.width
            spacing: Style.space(10)

            Repeater {
              model: root.notifications

              NotificationCard {
                required property var modelData
                notificationData: modelData
                onDismissed: function(key) {
                  root.deleteNotification(key)
                }
                onActionTriggered: function(key) {
                  root.triggerAction(key)
                }
              }
            }
          }
        }
      }
    }
  }
}
