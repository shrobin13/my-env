import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: root

  property var notificationData: ({})
  property bool isRead: false
  property bool isPinned: false
  property bool isSnoozed: false
  property bool isGroupHeader: false
  property int groupExtraCount: 0
  property bool groupExpanded: false

  signal dismissed(string key)
  signal actionTriggered(string key, string actionId)
  signal replySubmitted(string key, string replyText)
  signal snoozeRequested(string key, int durationSec)
  signal wakeRequested(string key)
  signal pinToggled(string key)
  signal muteAppRequested(string appName)
  signal groupToggleRequested(string appName)

  readonly property color foreground: Commons.Color.foreground
  readonly property color dimColor: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.65)
  readonly property color cardBg: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.055)
  readonly property color cardBorder: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.12)
  readonly property color hoverBg: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.09)

  readonly property var cardActions: Model.getCardActions(notificationData)
  readonly property bool hasProgress: !!(notificationData && typeof notificationData.progress === "number" && notificationData.progress >= 0 && notificationData.progress <= 100)
  readonly property bool canReply: Model.supportsReply(notificationData)

  readonly property string resolvedIcon: {
    if (!notificationData) return ""
    var raw = String(notificationData.appIcon || "")
    if (!raw) return ""
    return raw.charAt(0) === "/" ? ("file://" + raw) : Quickshell.iconPath(raw, true)
  }

  readonly property color urgencyStripeColor: {
    if (notificationData && notificationData.urgency === 2) return Commons.Color.urgent
    if (!root.isRead) return Commons.Color.accent
    return Qt.rgba(foreground.r, foreground.g, foreground.b, 0.2)
  }

  // Delegate z-stacking: popups must appear above adjacent cards
  z: (snoozePopup.visible || morePopup.visible) ? 100 : (cardHover.hovered ? 10 : 0)

  // Primary action execution helper for Keyboard Enter
  function runPrimaryAction() {
    if (root.isSnoozed) {
      root.wakeRequested(root.notificationData ? root.notificationData.key : "")
      return true
    }

    if (cardActions && cardActions.direct && cardActions.direct.length > 0) {
      var act = cardActions.direct[0]
      if (act.kind === "code") {
        executeCodeCopy(String(act.value))
        return true
      } else if (act.kind === "url") {
        return executeUrlOpen(String(act.value))
      } else {
        root.actionTriggered(root.notificationData ? root.notificationData.key : "", String(act.id))
        return true
      }
    }

    // Default action fallback
    if (root.notificationData && (root.notificationData.execArgv || (root.notificationData.actions && root.notificationData.actions.length > 0))) {
      root.actionTriggered(root.notificationData.key, "default")
      return true
    }
    return false
  }

  function executeCodeCopy(codeVal) {
    if (!codeVal) return
    Quickshell.execDetached(["wl-copy", "--sensitive", codeVal])
    // Auto-clear clipboard after 30s only if it still matches the code
    var clearScript = 'sleep 30 && [ "$(wl-paste 2>/dev/null)" = "' + codeVal.replace(/"/g, '\\"') + '" ] && wl-copy --clear'
    Quickshell.execDetached(["sh", "-c", clearScript])
  }

  function executeUrlOpen(urlVal) {
    var safeUrl = Model.sanitizeUrl(urlVal)
    if (safeUrl) {
      Quickshell.execDetached(["omarchy-launch-browser", safeUrl])
      root.actionTriggered(root.notificationData ? root.notificationData.key : "", "open_url")
      return true
    }
    return false
  }

  // Dismiss animations
  property bool isDismissing: false

  function triggerDismiss(direction) {
    if (isDismissing) return
    isDismissing = true
    var targetOffset = (direction === undefined ? 1 : direction) * (root.width * 1.25)
    slideOutAnim.to = targetOffset
    slideOutAnim.start()
  }

  NumberAnimation {
    id: slideOutAnim
    target: cardRect
    property: "x"
    duration: Style.duration(160)
    easing.type: Easing.OutCubic
    onFinished: {
      root.dismissed(root.notificationData ? root.notificationData.key : "")
    }
  }

  NumberAnimation {
    id: returnAnim
    target: cardRect
    property: "x"
    to: 0
    duration: Style.duration(140)
    easing.type: Easing.OutCubic
  }

  width: parent ? parent.width : Style.space(380)
  implicitHeight: cardRect.implicitHeight

  // Card Outer Container
  Rectangle {
    id: cardRect
    x: 0
    width: parent.width
    implicitHeight: contentCol.implicitHeight + Style.space(24)
    radius: Math.max(10, Style.cornerRadius)
    opacity: 1.0 - Math.min(0.65, Math.abs(x) / (root.width * 0.9))

    // Card background & keyboard selection highlight
    color: cardHover.hovered ? root.hoverBg : root.cardBg
    border.color: ListView.isCurrentItem
      ? Commons.Color.accent
      : (cardHover.hovered
         ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.45)
         : (root.isPinned ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.35) : root.cardBorder))
    border.width: ListView.isCurrentItem ? 2 : 1
    clip: false

    Behavior on color {
      ColorAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic }
    }
    Behavior on border.color {
      ColorAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic }
    }

    // HoverHandler: handles hover state without child MouseAreas breaking it
    HoverHandler {
      id: cardHover
      cursorShape: Qt.ArrowCursor
      onHoveredChanged: {
        if (!hovered && !snoozePopup.visible && !morePopup.visible) {
          // Keep popups closed when mouse leaves
        }
      }
    }

    // DragHandler: horizontal swipe-to-dismiss gesture (xAxis only, vertical flick scrolls ListView freely)
    DragHandler {
      id: dragHandler
      target: cardRect
      xAxis.enabled: true
      yAxis.enabled: false
      cursorShape: Qt.ArrowCursor
      onActiveChanged: {
        if (!active) {
          var dist = Math.abs(cardRect.x)
          var vel = Math.abs(dragHandler.velocity.x)
          if (dist > Style.space(90) || vel > 600) {
            root.triggerDismiss(cardRect.x >= 0 ? 1 : -1)
          } else {
            returnAnim.start()
          }
        }
      }
    }

    // Left urgency stripe (thicker when unread, inset by cardRect.radius so it stays inside rounded corners)
    Rectangle {
      id: urgencyStripe
      width: root.isRead ? Style.space(3.5) : Style.space(5.5)
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.topMargin: cardRect.radius
      anchors.bottomMargin: cardRect.radius
      color: root.urgencyStripeColor
      radius: width / 2

      Behavior on width {
        NumberAnimation { duration: Style.duration(140); easing.type: Easing.OutCubic }
      }
    }

    // Click handler on card body to select item in ListView
    MouseArea {
      anchors.fill: parent
      z: -1
      acceptedButtons: Qt.LeftButton
      onClicked: {
        if (ListView.view) {
          ListView.view.currentIndex = root.ListView.view ? root.ListView.view.model.indexOf ? root.ListView.view.model.indexOf(root.notificationData) : index : index
        }
        root.forceActiveFocus()
      }
    }

    // Card Content Column
    Column {
      id: contentCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.leftMargin: Style.space(16)
      anchors.rightMargin: Style.space(14)
      anchors.topMargin: Style.space(12)
      spacing: Style.space(8)

      // ==================== TOP ROW: APP, BADGE, TIME & TOOLBAR ====================
      RowLayout {
        width: parent.width
        spacing: Style.space(8)

        // App Icon
        Rectangle {
          width: Style.space(22)
          height: Style.space(22)
          radius: Style.space(5)
          color: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.08)
          Layout.alignment: Qt.AlignVCenter

          Image {
            id: appImg
            anchors.fill: parent
            anchors.margins: Style.space(2)
            source: root.resolvedIcon
            visible: status === Image.Ready && root.resolvedIcon !== ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
          }

          Text {
            anchors.centerIn: parent
            visible: !appImg.visible
            textFormat: Text.PlainText
            text: Model.iconGlyphFor(root.notificationData)
            font.family: Style.font.family
            font.pixelSize: Style.space(13)
            color: (root.notificationData && root.notificationData.urgency === 2) ? Commons.Color.urgent : Commons.Color.accent
          }
        }

        // App Name
        Text {
          textFormat: Text.PlainText
          text: root.notificationData ? (root.notificationData.app || "") : ""
          font.family: Style.font.family
          font.pixelSize: Math.max(12, Style.font.body)
          font.bold: true
          color: root.foreground
          elide: Text.ElideRight
          Layout.maximumWidth: Style.space(130)
        }

        // Unread 6px Accent Dot
        Rectangle {
          visible: !root.isRead
          width: Style.space(6)
          height: Style.space(6)
          radius: width / 2
          color: Commons.Color.accent
          Layout.alignment: Qt.AlignVCenter
        }

        // Dot Separator
        Text {
          textFormat: Text.PlainText
          text: "•"
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          color: root.dimColor
        }

        // Relative Timestamp
        Text {
          textFormat: Text.PlainText
          text: root.notificationData ? Model.formatRelativeTime(root.notificationData.ts) : ""
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          color: root.dimColor
        }

        // Visual Pin Indicator (Always visible when pinned so user knows without hovering)
        Text {
          visible: root.isPinned
          textFormat: Text.PlainText
          text: "\uf08d"
          font.family: Style.font.family
          font.pixelSize: Style.space(11)
          color: Commons.Color.accent
          opacity: 0.7
          Layout.alignment: Qt.AlignVCenter
        }

        Item { Layout.fillWidth: true }

        // ==================== HOVER TOOLBAR ====================
        Row {
          id: hoverBar
          spacing: Style.space(4)
          opacity: (cardHover.hovered || snoozePopup.visible || morePopup.visible) ? 1.0 : 0.0
          visible: opacity > 0

          Behavior on opacity {
            NumberAnimation { duration: Style.duration(140); easing.type: Easing.OutCubic }
          }

          // 1. Snooze Button
          Rectangle {
            id: snoozeBtn
            width: Style.space(22)
            height: Style.space(22)
            radius: width / 2
            scale: snoozeMouse.pressed ? 0.92 : (snoozeMouse.containsMouse ? 1.06 : 1.0)
            Behavior on scale { NumberAnimation { duration: Style.duration(70); easing.type: Easing.OutQuad } }
            color: snoozeMouse.pressed
              ? Qt.rgba(foreground.r, foreground.g, foreground.b, 0.25)
              : (snoozeMouse.containsMouse ? Qt.rgba(foreground.r, foreground.g, foreground.b, 0.15) : "transparent")

            Text {
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: "\uf017"
              font.family: Style.font.family
              font.pixelSize: Style.space(12)
              color: snoozeMouse.containsMouse ? Commons.Color.accent : root.dimColor
            }

            MouseArea {
              id: snoozeMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                morePopup.visible = false
                snoozePopup.visible = !snoozePopup.visible
              }
            }

            // Snooze Duration Popup
            Rectangle {
              id: snoozePopup
              visible: false
              z: 200
              width: Style.space(110)
              height: snoozeCol.implicitHeight + Style.space(12)
              // Flip upward if near bottom of viewport
              anchors.top: flipSnoozeUp ? undefined : parent.bottom
              anchors.bottom: flipSnoozeUp ? parent.top : undefined
              anchors.topMargin: flipSnoozeUp ? 0 : Style.space(4)
              anchors.bottomMargin: flipSnoozeUp ? Style.space(4) : 0
              anchors.right: parent.right
              radius: Math.max(8, Style.cornerRadius)
              color: Commons.Color.popups.background
              border.color: Commons.Color.popups.border
              border.width: 1

              readonly property bool flipSnoozeUp: {
                var pt = snoozeBtn.mapToItem(null, 0, 0)
                return pt.y > 440
              }

              Column {
                id: snoozeCol
                anchors.fill: parent
                anchors.margins: Style.space(6)
                spacing: Style.space(4)

                Repeater {
                  model: [
                    { label: "10 mins", sec: 600 },
                    { label: "1 hour", sec: 3600 },
                    { label: "Tomorrow", sec: 86400 }
                  ]
                  Rectangle {
                    width: parent.width
                    height: Style.space(24)
                    radius: Style.space(4)
                    color: itemMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.18) : "transparent"

                    Text {
                      anchors.centerIn: parent
                      textFormat: Text.PlainText
                      text: modelData.label
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      color: itemMouse.containsMouse ? Commons.Color.accent : root.foreground
                    }

                    MouseArea {
                      id: itemMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        snoozePopup.visible = false
                        root.snoozeRequested(root.notificationData ? root.notificationData.key : "", modelData.sec)
                      }
                    }
                  }
                }
              }
            }
          }

          // 2. Pin Button
          Rectangle {
            width: Style.space(22)
            height: Style.space(22)
            radius: width / 2
            scale: pinMouse.pressed ? 0.92 : (pinMouse.containsMouse ? 1.06 : 1.0)
            Behavior on scale { NumberAnimation { duration: Style.duration(70); easing.type: Easing.OutQuad } }
            color: pinMouse.pressed
              ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.35)
              : (root.isPinned
                 ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.2)
                 : (pinMouse.containsMouse ? Qt.rgba(foreground.r, foreground.g, foreground.b, 0.15) : "transparent"))

            Text {
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: "\uf08d"
              font.family: Style.font.family
              font.pixelSize: Style.space(12)
              color: root.isPinned ? Commons.Color.accent : (pinMouse.containsMouse ? root.foreground : root.dimColor)
            }

            MouseArea {
              id: pinMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.pinToggled(root.notificationData ? root.notificationData.key : "")
            }
          }

          // 3. Mute App Button
          Rectangle {
            width: Style.space(22)
            height: Style.space(22)
            radius: width / 2
            scale: muteMouse.pressed ? 0.92 : (muteMouse.containsMouse ? 1.06 : 1.0)
            Behavior on scale { NumberAnimation { duration: Style.duration(70); easing.type: Easing.OutQuad } }
            color: muteMouse.pressed
              ? Qt.rgba(Commons.Color.urgent.r, Commons.Color.urgent.g, Commons.Color.urgent.b, 0.3)
              : (muteMouse.containsMouse ? Qt.rgba(foreground.r, foreground.g, foreground.b, 0.15) : "transparent")

            Text {
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: "\uf1f6"
              font.family: Style.font.family
              font.pixelSize: Style.space(12)
              color: muteMouse.containsMouse ? Commons.Color.urgent : root.dimColor
            }

            MouseArea {
              id: muteMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.muteAppRequested(root.notificationData ? root.notificationData.app : "")
            }
          }
        }

        // Close (X) Button (Unmoved at far top-right)
        Rectangle {
          id: closeBtn
          width: Style.space(22)
          height: Style.space(22)
          radius: width / 2
          scale: closeMouse.pressed ? 0.90 : (closeMouse.containsMouse ? 1.08 : 1.0)
          Behavior on scale { NumberAnimation { duration: Style.duration(70); easing.type: Easing.OutQuad } }
          color: closeMouse.pressed
            ? Qt.rgba(Commons.Color.urgent.r, Commons.Color.urgent.g, Commons.Color.urgent.b, 0.35)
            : (closeMouse.containsMouse ? Qt.rgba(Commons.Color.urgent.r, Commons.Color.urgent.g, Commons.Color.urgent.b, 0.2) : "transparent")

          Behavior on color {
            ColorAnimation { duration: Style.duration(70); easing.type: Easing.OutQuad }
          }

          Text {
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: "\uf00d"
            font.family: Style.font.family
            font.pixelSize: Style.space(12)
            color: closeMouse.containsMouse ? Commons.Color.urgent : root.dimColor
          }

          MouseArea {
            id: closeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.triggerDismiss()
          }
        }
      }

      // ==================== HEADLINE & BODY ====================
      Text {
        width: parent.width
        textFormat: Text.StyledText
        text: root.notificationData ? (root.notificationData.summary || "") : ""
        font.family: Style.font.family
        font.pixelSize: Math.max(13, Style.font.body)
        font.bold: true
        color: root.foreground
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
      }

      Text {
        width: parent.width
        visible: root.notificationData ? (root.notificationData.body !== "") : false
        textFormat: Text.StyledText
        text: root.notificationData ? (root.notificationData.body || "") : ""
        font.family: Style.font.family
        font.pixelSize: Math.max(12, Style.font.caption + 1)
        color: root.dimColor
        wrapMode: Text.Wrap
        maximumLineCount: 4
        elide: Text.ElideRight
        lineHeight: 1.2
      }

      // ==================== PROGRESS BAR ====================
      Column {
        width: parent.width
        visible: root.hasProgress
        spacing: Style.space(4)

        Rectangle {
          width: parent.width
          height: Style.space(4)
          radius: 2
          color: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.12)
          clip: true

          Rectangle {
            width: parent.width * Math.min(1.0, Math.max(0.0, (root.notificationData && typeof root.notificationData.progress === "number" ? root.notificationData.progress : 0) / 100))
            height: parent.height
            radius: 2
            color: Commons.Color.accent

            Behavior on width {
              NumberAnimation { duration: Style.duration(160); easing.type: Easing.OutCubic }
            }
          }
        }

        RowLayout {
          width: parent.width
          Text {
            textFormat: Text.PlainText
            text: (root.notificationData && typeof root.notificationData.progress === "number" ? Math.round(root.notificationData.progress) : 0) + "%"
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            color: Commons.Color.accent
          }
          Item { Layout.fillWidth: true }
          Text {
            textFormat: Text.PlainText
            text: (root.notificationData && root.notificationData.eta) || ""
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            color: root.dimColor
          }
        }
      }

      // ==================== ACTIONS ROW ====================
      RowLayout {
        width: parent.width
        visible: root.isSnoozed || !!(root.cardActions && root.cardActions.total > 0)
        spacing: Style.space(8)

        // Wake Now Button (Visible when snoozed)
        Rectangle {
          visible: root.isSnoozed
          height: Style.space(26)
          implicitWidth: wakeLabel.implicitWidth + Style.space(20)
          radius: Style.space(6)
          scale: wakeMouse.pressed ? 0.95 : (wakeMouse.containsMouse ? 1.02 : 1.0)
          Behavior on scale { NumberAnimation { duration: Style.duration(70); easing.type: Easing.OutQuad } }

          color: wakeMouse.pressed
            ? Qt.darker(Commons.Color.accent, 1.25)
            : (wakeMouse.containsMouse ? Commons.Color.accent : Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.18))
          border.color: Commons.Color.accent
          border.width: 1

          Text {
            id: wakeLabel
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: "Wake now"
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            color: wakeMouse.containsMouse ? Commons.Color.background : Commons.Color.accent
          }

          MouseArea {
            id: wakeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.wakeRequested(root.notificationData ? root.notificationData.key : "")
          }
        }

        // Direct Action Buttons (up to 2)
        Repeater {
          model: (!root.isSnoozed && root.cardActions && root.cardActions.direct) || []

          Rectangle {
            id: actBtn
            property bool copied: false

            Timer {
              id: copyResetTimer
              interval: 1200
              repeat: false
              onTriggered: actBtn.copied = false
            }

            height: Style.space(26)
            implicitWidth: actLabel.implicitWidth + Style.space(20)
            radius: Style.space(6)
            scale: actMouse.pressed ? 0.95 : (actMouse.containsMouse ? 1.02 : 1.0)
            Behavior on scale { NumberAnimation { duration: Style.duration(70); easing.type: Easing.OutQuad } }

            color: actMouse.pressed
              ? Qt.darker(Commons.Color.accent, 1.25)
              : (actMouse.containsMouse ? Commons.Color.accent : Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.15))
            border.color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.35)
            border.width: 1

            Behavior on color {
              ColorAnimation { duration: Style.duration(70); easing.type: Easing.OutQuad }
            }

            Text {
              id: actLabel
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: actBtn.copied ? "Copied" : modelData.label
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
              color: actMouse.containsMouse ? Commons.Color.background : Commons.Color.accent
            }

            MouseArea {
              id: actMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (modelData.kind === "code") {
                  root.executeCodeCopy(String(modelData.value))
                  actBtn.copied = true
                  copyResetTimer.restart()
                } else if (modelData.kind === "url") {
                  root.executeUrlOpen(String(modelData.value))
                } else {
                  root.actionTriggered(root.notificationData ? root.notificationData.key : "", String(modelData.id))
                }
              }
            }
          }
        }

        // More Actions Menu Button (if > 2 actions)
        Rectangle {
          id: moreBtn
          visible: !root.isSnoozed && !!(root.cardActions && root.cardActions.more && root.cardActions.more.length > 0)
          height: Style.space(26)
          implicitWidth: moreLabel.implicitWidth + Style.space(16)
          radius: Style.space(6)
          scale: moreMouse.pressed ? 0.95 : (moreMouse.containsMouse ? 1.02 : 1.0)
          Behavior on scale { NumberAnimation { duration: Style.duration(70); easing.type: Easing.OutQuad } }
          color: moreMouse.pressed
            ? Qt.rgba(foreground.r, foreground.g, foreground.b, 0.22)
            : (moreMouse.containsMouse ? Qt.rgba(foreground.r, foreground.g, foreground.b, 0.14) : Qt.rgba(foreground.r, foreground.g, foreground.b, 0.08))
          border.color: root.cardBorder
          border.width: 1

          Text {
            id: moreLabel
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: "More (" + (root.cardActions && root.cardActions.more ? root.cardActions.more.length : 0) + ")"
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            color: root.foreground
          }

          MouseArea {
            id: moreMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              snoozePopup.visible = false
              morePopup.visible = !morePopup.visible
            }
          }

          // More Actions Dropdown Menu
          Rectangle {
            id: morePopup
            visible: false
            z: 210
            width: Style.space(130)
            height: moreCol.implicitHeight + Style.space(12)
            // Flip upward if near bottom of viewport
            anchors.top: flipMoreUp ? undefined : parent.bottom
            anchors.bottom: flipMoreUp ? parent.top : undefined
            anchors.topMargin: flipMoreUp ? 0 : Style.space(4)
            anchors.bottomMargin: flipMoreUp ? Style.space(4) : 0
            anchors.left: parent.left
            radius: Math.max(8, Style.cornerRadius)
            color: Commons.Color.popups.background
            border.color: Commons.Color.popups.border
            border.width: 1

            readonly property bool flipMoreUp: {
              var pt = moreBtn.mapToItem(null, 0, 0)
              return pt.y > 440
            }

            Column {
              id: moreCol
              anchors.fill: parent
              anchors.margins: Style.space(6)
              spacing: Style.space(4)

              Repeater {
                model: (root.cardActions && root.cardActions.more) || []
                Rectangle {
                  width: parent.width
                  height: Style.space(24)
                  radius: Style.space(4)
                  color: extraActMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.2) : "transparent"

                  Text {
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: modelData.label
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    color: extraActMouse.containsMouse ? Commons.Color.accent : root.foreground
                  }

                  MouseArea {
                    id: extraActMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      morePopup.visible = false
                      if (modelData.kind === "code") {
                        root.executeCodeCopy(String(modelData.value))
                      } else if (modelData.kind === "url") {
                        root.executeUrlOpen(String(modelData.value))
                      } else {
                        root.actionTriggered(root.notificationData ? root.notificationData.key : "", String(modelData.id))
                      }
                    }
                  }
                }
              }
            }
          }
        }

        Item { Layout.fillWidth: true }
      }

      // ==================== INLINE REPLY FIELD ====================
      Rectangle {
        id: replyBox
        width: parent.width
        height: Style.space(32)
        visible: root.canReply && !root.isSnoozed
        radius: Style.space(6)
        color: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.08)
        border.color: replyInput.activeFocus ? Commons.Color.accent : root.cardBorder
        border.width: 1

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(6)
          spacing: Style.space(6)

          TextInput {
            id: replyInput
            Layout.fillWidth: true
            color: root.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            clip: true

            Text {
              anchors.fill: parent
              visible: !replyInput.text && !replyInput.activeFocus
              textFormat: Text.PlainText
              text: "Reply to " + (root.notificationData && root.notificationData.app ? root.notificationData.app : "message") + "..."
              font: replyInput.font
              color: root.dimColor
            }

            Keys.onReturnPressed: function() {
              if (replyInput.text.trim()) {
                root.replySubmitted(root.notificationData ? root.notificationData.key : "", replyInput.text.trim())
                replyInput.text = ""
                replyInput.focus = false
                root.forceActiveFocus()
              }
            }
            Keys.onEscapePressed: function() {
              replyInput.text = ""
              replyInput.focus = false
              root.forceActiveFocus()
            }
          }

          // Send Button
          Rectangle {
            width: Style.space(22)
            height: Style.space(22)
            radius: width / 2
            color: sendMouse.containsMouse ? Commons.Color.accent : "transparent"

            Text {
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: "\uf1d8"
              font.family: Style.font.family
              font.pixelSize: Style.space(11)
              color: sendMouse.containsMouse ? Commons.Color.background : Commons.Color.accent
            }

            MouseArea {
              id: sendMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (replyInput.text.trim()) {
                  root.replySubmitted(root.notificationData ? root.notificationData.key : "", replyInput.text.trim())
                  replyInput.text = ""
                  replyInput.focus = false
                  root.forceActiveFocus()
                }
              }
            }
          }
        }
      }

      // ==================== APP GROUP COLLAPSE / EXPAND BADGE ====================
      Rectangle {
        visible: root.isGroupHeader && root.groupExtraCount > 0
        width: parent.width
        height: Style.space(24)
        radius: Style.space(5)
        color: groupMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.18) : Qt.rgba(foreground.r, foreground.g, foreground.b, 0.05)
        border.color: root.cardBorder
        border.width: 1

        Row {
          anchors.centerIn: parent
          spacing: Style.space(6)

          Text {
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: root.groupExpanded ? "\uf106" : "\uf107"
            font.family: Style.font.family
            font.pixelSize: Style.space(12)
            color: Commons.Color.accent
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: root.groupExpanded ? "Collapse group" : ("+" + root.groupExtraCount + " more from " + (root.notificationData && root.notificationData.app ? root.notificationData.app : ""))
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            color: root.foreground
          }
        }

        MouseArea {
          id: groupMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.groupToggleRequested(root.notificationData ? root.notificationData.app : "")
        }
      }
    }
  }
}
