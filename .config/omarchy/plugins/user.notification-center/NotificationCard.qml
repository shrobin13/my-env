import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: root

  required property var notificationData
  signal dismissed(string key)
  signal actionTriggered(string key)

  readonly property color foreground: Commons.Color.foreground
  readonly property color dimColor: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.7)
  readonly property color cardBg: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.055)
  readonly property color cardBorder: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.12)
  readonly property color hoverBg: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.09)

  readonly property string resolvedIcon: {
    var raw = String(notificationData.appIcon || "")
    if (!raw) return ""
    return raw.charAt(0) === "/" ? ("file://" + raw) : Quickshell.iconPath(raw, true)
  }

  readonly property color urgencyStripeColor: {
    if (notificationData.urgency === 2) return Commons.Color.urgent
    if (notificationData.isLive) return Commons.Color.accent
    return Qt.rgba(foreground.r, foreground.g, foreground.b, 0.2)
  }

  width: parent ? parent.width : Style.space(380)
  implicitHeight: contentCol.implicitHeight + Style.space(20)

  Rectangle {
    id: cardRect
    anchors.fill: parent
    radius: Math.max(10, Style.cornerRadius)
    color: cardMouse.containsMouse ? root.hoverBg : root.cardBg
    border.color: cardMouse.containsMouse ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.4) : root.cardBorder
    border.width: 1
    clip: true

    Behavior on color {
      ColorAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic }
    }
    Behavior on border.color {
      ColorAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic }
    }

    // Urgency accent stripe on left edge
    Rectangle {
      width: Style.space(4)
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      color: root.urgencyStripeColor
      radius: 2
    }

    MouseArea {
      id: cardMouse
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.NoButton
    }

    Column {
      id: contentCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.leftMargin: Style.space(16)
      anchors.rightMargin: Style.space(14)
      anchors.topMargin: Style.space(10)
      spacing: Style.space(6)

      // Top row: App Icon + App Name + Dot + Timestamp + Close Button
      RowLayout {
        width: parent.width
        spacing: Style.space(8)

        // App Icon or Glyph Pill
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
            color: root.notificationData.urgency === 2 ? Commons.Color.urgent : Commons.Color.accent
          }
        }

        // App Name
        Text {
          textFormat: Text.PlainText
          text: root.notificationData.app
          font.family: Style.font.family
          font.pixelSize: Math.max(12, Style.font.body)
          font.bold: true
          color: root.foreground
          elide: Text.ElideRight
          Layout.maximumWidth: Style.space(180)
        }

        // Dot separator
        Text {
          textFormat: Text.PlainText
          text: "•"
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          color: root.dimColor
        }

        // Relative timestamp
        Text {
          textFormat: Text.PlainText
          text: Model.formatRelativeTime(root.notificationData.ts)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          color: root.dimColor
        }

        Item {
          Layout.fillWidth: true
        }

        // Close (X) button
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
            onClicked: root.dismissed(root.notificationData.key)
          }
        }
      }

      // Notification Summary (Headline)
      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: root.notificationData.summary
        font.family: Style.font.family
        font.pixelSize: Math.max(13, Style.font.body)
        font.bold: true
        color: root.foreground
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
      }

      // Notification Body
      Text {
        width: parent.width
        visible: root.notificationData.body !== ""
        textFormat: Text.PlainText
        text: root.notificationData.body
        font.family: Style.font.family
        font.pixelSize: Math.max(12, Style.font.caption + 1)
        color: root.dimColor
        wrapMode: Text.Wrap
        maximumLineCount: 4
        elide: Text.ElideRight
        lineHeight: 1.2
      }

      // Action Button (if present)
      Rectangle {
        id: actionBtn
        visible: root.notificationData.hasAction
        width: Math.min(parent.width, actionText.implicitWidth + Style.space(20))
        height: Style.space(26)
        radius: Style.space(5)
        color: actionMouse.containsMouse ? Commons.Color.accent : Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.15)
        border.color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.35)
        border.width: 1

        Behavior on color {
          ColorAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic }
        }

        Text {
          id: actionText
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: "Open / Action"
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
          color: actionMouse.containsMouse ? Commons.Color.background : Commons.Color.accent
        }

        MouseArea {
          id: actionMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.actionTriggered(root.notificationData.key)
        }
      }
    }
  }
}
