import QtQuick
import qs.Commons

Item {
  id: footerRoot

  property int totalWindows: 0
  property int totalMonitors: 0
  property int matchedWindows: 0
  property bool isSearching: false

  width: parent.width
  height: 38

  // Hairline top border gradient
  Rectangle {
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 1
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0.0; color: "transparent" }
      GradientStop { position: 0.2; color: Qt.rgba(255, 255, 255, 0.12) }
      GradientStop { position: 0.8; color: Qt.rgba(255, 255, 255, 0.12) }
      GradientStop { position: 1.0; color: "transparent" }
    }
  }

  Row {
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: 4
    spacing: 18

    // Helper component for key hints
    component KeyHint: Row {
      property string keyText: ""
      property string labelText: ""
      spacing: 6

      Rectangle {
        height: 20
        width: keyLabel.implicitWidth + 12
        radius: 6
        color: Qt.rgba(255, 255, 255, 0.08)
        anchors.verticalCenter: parent.verticalCenter

        Text {
          id: keyLabel
          anchors.centerIn: parent
          text: keyText
          font.pixelSize: 12
          font.weight: 500
          font.family: "monospace"
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.85)
        }
      }

      Text {
        text: labelText
        font.pixelSize: 12
        font.family: "sans-serif"
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.55)
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    KeyHint { visible: !footerRoot.isSearching; keyText: "j k"; labelText: "move" }
    KeyHint { visible: !footerRoot.isSearching; keyText: "h l"; labelText: "fold" }
    KeyHint { visible: footerRoot.isSearching; keyText: "n N"; labelText: "next/prev" }
    KeyHint { keyText: "ctrl+h/l"; labelText: "monitor" }
    KeyHint { visible: !footerRoot.isSearching; keyText: "1–0"; labelText: "workspace" }
    KeyHint { keyText: "/"; labelText: footerRoot.isSearching ? "edit" : "search" }
    KeyHint { keyText: "enter"; labelText: "jump" }
    KeyHint { visible: footerRoot.isSearching; keyText: "esc"; labelText: "clear" }
    KeyHint { visible: !footerRoot.isSearching; keyText: "q"; labelText: "quit" }
  }

  // Summary on right
  Text {
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: 4
    text: footerRoot.isSearching
      ? (footerRoot.matchedWindows + " of " + footerRoot.totalWindows + " windows")
      : (footerRoot.totalWindows + " windows · " + footerRoot.totalMonitors + " monitors")
    font.pixelSize: 12
    font.family: "sans-serif"
    color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.55)
  }
}
