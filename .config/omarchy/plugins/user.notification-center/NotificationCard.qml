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
  property bool isGroupHeader: false
  property int groupExtraCount: 0
  property bool groupExpanded: false

  signal dismissed(string key)
  signal actionTriggered(string key, string actionId)
  signal replySubmitted(string key, string replyText)
  signal snoozeRequested(string key, int durationSec)
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

  // Swipe-to-dismiss states
  property real dragOffset: 0
  property real cardOpacity: 1.0
  property bool isDismissing: false

  function triggerDismiss() {
    if (isDismissing) return
    isDismissing = true
    slideOutAnim.to = dragOffset >= 0 ? root.width * 1.2 : -root.width * 1.2
    slideOutAnim.start()
  }

  NumberAnimation {
    id: slideOutAnim
    target: root
    property: "dragOffset"
    duration: Style.duration(160)
    easing.type: Easing.OutCubic
    onFinished: {
      root.dismissed(root.notificationData ? root.notificationData.key : "")
    }
  }

  NumberAnimation {
    id: returnAnim
    target: root
    property: "dragOffset"
    to: 0
    duration: Style.duration(140)
    easing.type: Easing.OutCubic
  }

  width: parent ? parent.width : Style.space(380)
  implicitHeight: cardRect.implicitHeight

  Rectangle {
    id: cardRect
    x: root.dragOffset
    opacity: root.cardOpacity * (1 - Math.min(0.6, Math.abs(root.dragOffset) / (root.width * 0.9)))
    width: parent.width
    implicitHeight: contentCol.implicitHeight + Style.space(24)
    radius: Math.max(10, Style.cornerRadius)
    color: cardMouse.containsMouse ? root.hoverBg : root.cardBg
    border.color: cardMouse.containsMouse
      ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.4)
      : (root.isPinned ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.35) : root.cardBorder)
    border.width: 1
    clip: false

    Behavior on color {
      ColorAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic }
    }
    Behavior on border.color {
      ColorAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic }
    }

    // Left urgency stripe (thicker when unread)
    Rectangle {
      width: root.isRead ? Style.space(3.5) : Style.space(5.5)
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      color: root.urgencyStripeColor
      radius: width / 2

      Behavior on width {
        NumberAnimation { duration: Style.duration(140); easing.type: Easing.OutCubic }
      }
    }

    // Horizontal swipe-to-dismiss gesture handling
    MouseArea {
      id: cardMouse
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton
      property real startX: 0
      property bool dragging: false

      onPressed: function(mouse) {
        startX = mouse.x
        dragging = false
      }

      onPositionChanged: function(mouse) {
        if (!pressed) return
        var diff = mouse.x - startX
        if (!dragging && Math.abs(diff) > Style.space(10)) {
          dragging = true
        }
        if (dragging) {
          root.dragOffset = diff
        }
      }

      onReleased: function() {
        if (dragging) {
          if (Math.abs(root.dragOffset) > Style.space(90)) {
            root.triggerDismiss()
          } else {
            returnAnim.start()
          }
          dragging = false
        }
      }
    }

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
          Layout.maximumWidth: Style.space(140)
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

        Item { Layout.fillWidth: true }

        // ==================== HOVER TOOLBAR ====================
        Row {
          id: hoverBar
          spacing: Style.space(4)
          opacity: (cardMouse.containsMouse || snoozePopup.visible) ? 1.0 : (root.isPinned ? 0.7 : 0.0)
          visible: opacity > 0

          Behavior on opacity {
            NumberAnimation { duration: Style.duration(140); easing.type: Easing.OutCubic }
          }

          // 1. Snooze Button
          Rectangle {
            width: Style.space(22)
            height: Style.space(22)
            radius: width / 2
            color: snoozeMouse.containsMouse ? Qt.rgba(foreground.r, foreground.g, foreground.b, 0.15) : "transparent"

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
              onClicked: snoozePopup.visible = !snoozePopup.visible
            }

            // Snooze Duration Popup
            Rectangle {
              id: snoozePopup
              visible: false
              z: 100
              width: Style.space(110)
              height: snoozeCol.implicitHeight + Style.space(12)
              anchors.top: parent.bottom
              anchors.topMargin: Style.space(4)
              anchors.right: parent.right
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
            color: root.isPinned
              ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.2)
              : (pinMouse.containsMouse ? Qt.rgba(foreground.r, foreground.g, foreground.b, 0.15) : "transparent")

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
            color: muteMouse.containsMouse ? Qt.rgba(foreground.r, foreground.g, foreground.b, 0.15) : "transparent"

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
          color: closeMouse.containsMouse ? Qt.rgba(Commons.Color.urgent.r, Commons.Color.urgent.g, Commons.Color.urgent.b, 0.2) : "transparent"

          Behavior on color {
            ColorAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic }
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
        textFormat: Text.PlainText
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
        textFormat: Text.PlainText
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

      // ==================== REAL ACTIONS & SMART ACTIONS ====================
      RowLayout {
        width: parent.width
        visible: !!(root.cardActions && root.cardActions.total > 0)
        spacing: Style.space(8)

        Repeater {
          model: (root.cardActions && root.cardActions.direct) || []

          Rectangle {
            id: actBtn
            height: Style.space(26)
            implicitWidth: actLabel.implicitWidth + Style.space(20)
            radius: Style.space(6)
            color: actMouse.containsMouse ? Commons.Color.accent : Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.15)
            border.color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.35)
            border.width: 1

            Behavior on color {
              ColorAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic }
            }

            Text {
              id: actLabel
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: modelData.label
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
                  Quickshell.execDetached(["wl-copy", String(modelData.value)])
                  actLabel.text = "Copied!"
                  Qt.callLater(function() { actLabel.text = modelData.label })
                } else if (modelData.kind === "url") {
                  Quickshell.execDetached(["omarchy-launch-browser", String(modelData.value)])
                  root.actionTriggered(root.notificationData ? root.notificationData.key : "", "open_url")
                } else {
                  root.actionTriggered(root.notificationData ? root.notificationData.key : "", String(modelData.id))
                }
              }
            }
          }
        }

        // More Actions Menu Button (if > 2 actions)
        Rectangle {
          visible: !!(root.cardActions && root.cardActions.more && root.cardActions.more.length > 0)
          height: Style.space(26)
          implicitWidth: moreLabel.implicitWidth + Style.space(16)
          radius: Style.space(6)
          color: moreMouse.containsMouse ? Qt.rgba(foreground.r, foreground.g, foreground.b, 0.14) : Qt.rgba(foreground.r, foreground.g, foreground.b, 0.08)
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
            onClicked: morePopup.visible = !morePopup.visible
          }

          // More Actions Dropdown Menu
          Rectangle {
            id: morePopup
            visible: false
            z: 110
            width: Style.space(130)
            height: moreCol.implicitHeight + Style.space(12)
            anchors.bottom: parent.top
            anchors.bottomMargin: Style.space(4)
            anchors.left: parent.left
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
                      root.actionTriggered(root.notificationData ? root.notificationData.key : "", String(modelData.id))
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
        width: parent.width
        height: Style.space(32)
        visible: root.canReply
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
              }
            }
            Keys.onEscapePressed: function() {
              replyInput.text = ""
              replyInput.focus = false
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
