import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: cardRoot

  property var notificationData: ({})
  property bool isRead: false
  property bool isPinned: false
  property bool isSnoozed: false
  property bool isGroupHeader: false
  property int groupExtraCount: 0
  property bool groupExpanded: false
  property int nowSec: 0

  signal dismissed(string key)
  signal selectRequested()
  signal actionTriggered(string key, string actionId)
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

  readonly property string resolvedIcon: {
    if (!notificationData) return ""
    var raw = String(notificationData.appIcon || "")
    if (!raw) return ""
    return raw.charAt(0) === "/" ? ("file://" + raw) : Quickshell.iconPath(raw, true)
  }

  readonly property color urgencyStripeColor: {
    if (notificationData && notificationData.urgency === 2) return Commons.Color.urgent
    if (!cardRoot.isRead) return Commons.Color.accent
    return Qt.rgba(foreground.r, foreground.g, foreground.b, 0.2)
  }

  // Delegate z-stacking: popups must appear above adjacent cards
  z: (snoozePopup.visible || morePopup.visible) ? 100 : (cardHover.hovered ? 10 : 0)

  // Reset animations when delegate is reused or notification data changes
  onNotificationDataChanged: {
    cardRect.x = 0
    cardRoot.isDismissing = false
    snoozePopup.visible = false
    morePopup.visible = false
  }

  function closePopups() {
    snoozePopup.visible = false
    morePopup.visible = false
  }

  function openSnooze() {
    morePopup.visible = false
    var p = snoozeBtn.mapToItem(cardRect, 0, 0)
    snoozePopup.x = snoozeBtn.width - snoozePopup.width
    snoozePopup.y = snoozeBtn.height + Style.space(4)
    if (p.y + snoozeBtn.height + Style.space(4) + snoozePopup.height > cardRect.height + Style.space(40)) {
      snoozePopup.y = -snoozePopup.height - Style.space(4)
    }
    snoozePopup.visible = !snoozePopup.visible
  }

  function openMore() {
    snoozePopup.visible = false
    var p = moreBtn.mapToItem(cardRect, 0, 0)
    morePopup.x = 0
    morePopup.y = moreBtn.height + Style.space(4)
    if (p.y + moreBtn.height + Style.space(4) + morePopup.height > cardRect.height + Style.space(40)) {
      morePopup.y = -morePopup.height - Style.space(4)
    }
    morePopup.visible = !morePopup.visible
  }

  // Primary action execution helper
  function runPrimaryAction() {
    if (cardRoot.isSnoozed) {
      cardRoot.wakeRequested(cardRoot.notificationData ? cardRoot.notificationData.key : "")
      return true
    }

    if (cardActions && cardActions.direct && cardActions.direct.length > 0) {
      var act = cardActions.direct[0]
      if (act.kind === "code") {
        executeCodeCopy(String(act.value))
        return true
      } else if (act.kind === "url") {
        return executeUrlOpen(String(act.value))
      } else if (act.kind === "app") {
        cardRoot.actionTriggered(cardRoot.notificationData ? cardRoot.notificationData.key : "", "default_open_app")
        return true
      } else {
        cardRoot.actionTriggered(cardRoot.notificationData ? cardRoot.notificationData.key : "", String(act.id))
        return true
      }
    }

    // Default action fallback (execArgv or app focus)
    if (cardRoot.notificationData && (cardRoot.notificationData.execArgv || cardRoot.notificationData.app)) {
      cardRoot.actionTriggered(cardRoot.notificationData.key, "default")
      return true
    }
    return false
  }

  function executeCodeCopy(codeVal) {
    if (!codeVal) return
    Quickshell.execDetached(["wl-copy", "--sensitive", "--", codeVal])
    // Auto-clear clipboard safely after 30s only if it still matches the code
    Quickshell.execDetached(["sh", "-c", 'sleep 30 && [ "$(wl-paste 2>/dev/null)" = "$1" ] && wl-copy --clear', "_", codeVal])
  }

  function executeUrlOpen(urlVal) {
    var safeUrl = Model.sanitizeUrl(urlVal)
    if (safeUrl) {
      Quickshell.execDetached(["omarchy-launch-browser", safeUrl])
      return true
    }
    return false
  }

  // Dismiss animations
  property bool isDismissing: false

  function triggerDismiss(direction) {
    if (isDismissing) return
    isDismissing = true
    closePopups()
    var targetOffset = (direction === undefined ? 1 : direction) * (cardRoot.width * 1.25)
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
      cardRoot.dismissed(cardRoot.notificationData ? cardRoot.notificationData.key : "")
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

  // Swipe Action Background (Revealed under card when dragged)
  Rectangle {
    anchors.fill: cardRect
    radius: cardRect.radius
    color: Qt.rgba(Commons.Color.urgent.r, Commons.Color.urgent.g, Commons.Color.urgent.b, 0.25)
    border.color: Commons.Color.urgent
    border.width: 1
    visible: Math.abs(cardRect.x) > Style.space(10)

    Row {
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: cardRect.x > 0 ? parent.left : undefined
      anchors.right: cardRect.x < 0 ? parent.right : undefined
      anchors.leftMargin: Style.space(16)
      anchors.rightMargin: Style.space(16)
      spacing: Style.space(6)

      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: "\uf2ed"
        font.family: Style.font.family
        font.pixelSize: Style.space(14)
        color: Commons.Color.urgent
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: "Dismiss"
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
        color: Commons.Color.urgent
      }
    }
  }

  // Card Outer Container
  Rectangle {
    id: cardRect
    x: 0
    width: parent.width
    implicitHeight: contentCol.implicitHeight + Style.space(24)
    radius: Math.max(10, Style.cornerRadius)
    opacity: 1.0 - Math.min(0.65, Math.abs(x) / (cardRoot.width * 0.9))

    // Card background & keyboard selection highlight
    color: cardHover.hovered ? cardRoot.hoverBg : cardRoot.cardBg
    border.color: cardRoot.ListView.isCurrentItem
      ? Commons.Color.accent
      : (cardHover.hovered
         ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.45)
         : (cardRoot.isPinned ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.35) : cardRoot.cardBorder))
    border.width: cardRoot.ListView.isCurrentItem ? 2 : 1
    clip: false

    Behavior on color {
      ColorAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic }
    }
    Behavior on border.color {
      ColorAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic }
    }

    HoverHandler {
      id: cardHover
      cursorShape: Qt.ArrowCursor
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
          var vel = Math.abs(dragHandler.lastVelocityX)
          if (dist > Style.space(90) || vel > 600) {
            cardRoot.triggerDismiss(cardRect.x >= 0 ? 1 : -1)
          } else {
            returnAnim.start()
          }
        }
      }
      onCentroidChanged: {
        if (active) lastVelocityX = centroid.velocity.x
      }
      property real lastVelocityX: 0
    }

    // Left urgency stripe (thicker when unread)
    Rectangle {
      id: urgencyStripe
      width: cardRoot.isRead ? Style.space(3.5) : Style.space(5.5)
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.topMargin: cardRect.radius
      anchors.bottomMargin: cardRect.radius
      color: cardRoot.urgencyStripeColor
      radius: width / 2

      Behavior on width {
        NumberAnimation { duration: Style.duration(140); easing.type: Easing.OutCubic }
      }
    }

    // Click handler on card body to select item and activate on click
    MouseArea {
      anchors.fill: parent
      z: -1
      acceptedButtons: Qt.LeftButton
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        cardRoot.selectRequested()
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
            source: cardRoot.resolvedIcon
            visible: status === Image.Ready && cardRoot.resolvedIcon !== ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
          }

          Text {
            anchors.centerIn: parent
            visible: !appImg.visible
            textFormat: Text.PlainText
            text: Model.iconGlyphFor(cardRoot.notificationData)
            font.family: Style.font.family
            font.pixelSize: Style.space(13)
            color: (cardRoot.notificationData && cardRoot.notificationData.urgency === 2) ? Commons.Color.urgent : Commons.Color.accent
          }
        }

        // App Name
        Text {
          textFormat: Text.PlainText
          text: cardRoot.notificationData ? (cardRoot.notificationData.app || "") : ""
          font.family: Style.font.family
          font.pixelSize: Math.max(12, Style.font.body)
          font.bold: true
          color: cardRoot.foreground
          elide: Text.ElideRight
          Layout.maximumWidth: Style.space(130)
        }

        // Unread 6px Accent Dot
        Rectangle {
          visible: !cardRoot.isRead
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
          color: cardRoot.dimColor
        }

        // Relative Timestamp
        Text {
          textFormat: Text.PlainText
          text: cardRoot.notificationData ? Model.formatRelativeTime(cardRoot.notificationData.ts, cardRoot.nowSec) : ""
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          color: cardRoot.dimColor
        }

        // Visual Pin Indicator
        Text {
          visible: cardRoot.isPinned
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
            z: 1000
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
              color: snoozeMouse.containsMouse ? Commons.Color.accent : cardRoot.dimColor
            }

            MouseArea {
              id: snoozeMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: cardRoot.openSnooze()
            }

            // Snooze Duration Popup
            Rectangle {
              id: snoozePopup
              visible: false
              z: 1000
              width: Style.space(110)
              height: snoozeCol.implicitHeight + Style.space(12)
              radius: Math.max(8, Style.cornerRadius)
              color: Commons.Color.popups.background
              border.color: Commons.Color.popups.border
              border.width: 1

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
                      color: itemMouse.containsMouse ? Commons.Color.accent : cardRoot.foreground
                    }

                    MouseArea {
                      id: itemMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        snoozePopup.visible = false
                        cardRoot.snoozeRequested(cardRoot.notificationData ? cardRoot.notificationData.key : "", modelData.sec)
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
              : (cardRoot.isPinned
                 ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.2)
                 : (pinMouse.containsMouse ? Qt.rgba(foreground.r, foreground.g, foreground.b, 0.15) : "transparent"))

            Text {
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: "\uf08d"
              font.family: Style.font.family
              font.pixelSize: Style.space(12)
              color: cardRoot.isPinned ? Commons.Color.accent : (pinMouse.containsMouse ? cardRoot.foreground : cardRoot.dimColor)
            }

            MouseArea {
              id: pinMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: cardRoot.pinToggled(cardRoot.notificationData ? cardRoot.notificationData.key : "")
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
              color: muteMouse.containsMouse ? Commons.Color.urgent : cardRoot.dimColor
            }

            MouseArea {
              id: muteMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: cardRoot.muteAppRequested(cardRoot.notificationData ? cardRoot.notificationData.app : "")
            }
          }
        }

        // Close (X) Button
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
            color: closeMouse.containsMouse ? Commons.Color.urgent : cardRoot.dimColor
          }

          MouseArea {
            id: closeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: cardRoot.triggerDismiss()
          }
        }
      }

      // ==================== HEADLINE & BODY (SAFE PLAIN TEXT) ====================
      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: cardRoot.notificationData ? (cardRoot.notificationData.summary || "") : ""
        font.family: Style.font.family
        font.pixelSize: Math.max(13, Style.font.body)
        font.bold: true
        color: cardRoot.foreground
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
      }

      Text {
        width: parent.width
        visible: !!(cardRoot.notificationData && cardRoot.notificationData.body)
        textFormat: Text.PlainText
        text: cardRoot.notificationData ? (cardRoot.notificationData.body || "") : ""
        font.family: Style.font.family
        font.pixelSize: Math.max(12, Style.font.caption + 1)
        color: cardRoot.dimColor
        wrapMode: Text.Wrap
        maximumLineCount: 4
        elide: Text.ElideRight
        lineHeight: 1.2
      }

      // ==================== PROGRESS BAR ====================
      Column {
        width: parent.width
        visible: cardRoot.hasProgress
        spacing: Style.space(4)

        Rectangle {
          width: parent.width
          height: Style.space(4)
          radius: 2
          color: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.12)
          clip: true

          Rectangle {
            width: parent.width * Math.min(1.0, Math.max(0.0, (cardRoot.notificationData && typeof cardRoot.notificationData.progress === "number" ? cardRoot.notificationData.progress : 0) / 100))
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
            text: (cardRoot.notificationData && typeof cardRoot.notificationData.progress === "number" ? Math.round(cardRoot.notificationData.progress) : 0) + "%"
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            color: Commons.Color.accent
          }
          Item { Layout.fillWidth: true }
          Text {
            textFormat: Text.PlainText
            text: (cardRoot.notificationData && cardRoot.notificationData.eta) || ""
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            color: cardRoot.dimColor
          }
        }
      }

      // ==================== ACTIONS ROW ====================
      RowLayout {
        width: parent.width
        visible: cardRoot.isSnoozed || !!(cardRoot.cardActions && cardRoot.cardActions.total > 0)
        spacing: Style.space(8)

        // Wake Now Button (Visible when snoozed)
        Rectangle {
          visible: cardRoot.isSnoozed
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
            onClicked: cardRoot.wakeRequested(cardRoot.notificationData ? cardRoot.notificationData.key : "")
          }
        }

        // Direct Action Buttons (up to 2)
        Repeater {
          model: (!cardRoot.isSnoozed && cardRoot.cardActions && cardRoot.cardActions.direct) || []

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
                  cardRoot.executeCodeCopy(String(modelData.value))
                  actBtn.copied = true
                  copyResetTimer.restart()
                } else if (modelData.kind === "url") {
                  cardRoot.executeUrlOpen(String(modelData.value))
                } else if (modelData.kind === "app") {
                  cardRoot.actionTriggered(cardRoot.notificationData ? cardRoot.notificationData.key : "", "default_open_app")
                } else {
                  cardRoot.actionTriggered(cardRoot.notificationData ? cardRoot.notificationData.key : "", String(modelData.id))
                }
              }
            }
          }
        }

        // More Actions Menu Button (if > 2 actions)
        Rectangle {
          id: moreBtn
          z: 1000
          visible: !cardRoot.isSnoozed && !!(cardRoot.cardActions && cardRoot.cardActions.more && cardRoot.cardActions.more.length > 0)
          height: Style.space(26)
          implicitWidth: moreLabel.implicitWidth + Style.space(16)
          radius: Style.space(6)
          scale: moreMouse.pressed ? 0.95 : (moreMouse.containsMouse ? 1.02 : 1.0)
          Behavior on scale { NumberAnimation { duration: Style.duration(70); easing.type: Easing.OutQuad } }
          color: moreMouse.pressed
            ? Qt.rgba(foreground.r, foreground.g, foreground.b, 0.22)
            : (moreMouse.containsMouse ? Qt.rgba(foreground.r, foreground.g, foreground.b, 0.14) : Qt.rgba(foreground.r, foreground.g, foreground.b, 0.08))
          border.color: cardRoot.cardBorder
          border.width: 1

          Text {
            id: moreLabel
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: "More (" + (cardRoot.cardActions && cardRoot.cardActions.more ? cardRoot.cardActions.more.length : 0) + ")"
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            color: cardRoot.foreground
          }

          MouseArea {
            id: moreMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: cardRoot.openMore()
          }

          // More Actions Dropdown Menu
          Rectangle {
            id: morePopup
            visible: false
            z: 1000
            width: Style.space(130)
            height: moreCol.implicitHeight + Style.space(12)
            radius: Math.max(8, Style.cornerRadius)
            color: Commons.Color.popups.background
            border.color: Commons.Color.popups.border
            border.width: 1

            Column {
              id: moreCol
              anchors.fill: parent
              anchors.margins: Style.space(6)
              spacing: Style.space(4)

              Repeater {
                model: (cardRoot.cardActions && cardRoot.cardActions.more) || []
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
                    color: extraActMouse.containsMouse ? Commons.Color.accent : cardRoot.foreground
                  }

                  MouseArea {
                    id: extraActMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      morePopup.visible = false
                      if (modelData.kind === "code") {
                        cardRoot.executeCodeCopy(String(modelData.value))
                      } else if (modelData.kind === "url") {
                        cardRoot.executeUrlOpen(String(modelData.value))
                      } else if (modelData.kind === "app") {
                        cardRoot.actionTriggered(cardRoot.notificationData ? cardRoot.notificationData.key : "", "default_open_app")
                      } else {
                        cardRoot.actionTriggered(cardRoot.notificationData ? cardRoot.notificationData.key : "", String(modelData.id))
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

      // ==================== APP GROUP COLLAPSE / EXPAND BADGE ====================
      Rectangle {
        visible: cardRoot.isGroupHeader && cardRoot.groupExtraCount > 0
        width: parent.width
        height: Style.space(24)
        radius: Style.space(5)
        color: groupMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.18) : Qt.rgba(foreground.r, foreground.g, foreground.b, 0.05)
        border.color: cardRoot.cardBorder
        border.width: 1

        Row {
          anchors.centerIn: parent
          spacing: Style.space(6)

          Text {
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: cardRoot.groupExpanded ? "\uf106" : "\uf107"
            font.family: Style.font.family
            font.pixelSize: Style.space(12)
            color: Commons.Color.accent
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: cardRoot.groupExpanded ? "Collapse group" : ("+" + cardRoot.groupExtraCount + " more from " + (cardRoot.notificationData && cardRoot.notificationData.app ? cardRoot.notificationData.app : ""))
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            color: cardRoot.foreground
          }
        }

        MouseArea {
          id: groupMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: cardRoot.groupToggleRequested(cardRoot.notificationData ? cardRoot.notificationData.app : "")
        }
      }
    }
  }
}
