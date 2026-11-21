import QtQuick
import qs.Commons

Item {
  id: windowRowRoot

  property var windowData: null
  property color monitorAccent: Color.accent
  property bool isSelected: false
  property bool isMatched: true
  property bool isSearching: false
  property string searchQuery: ""

  signal clicked()

  width: parent ? parent.width : 400
  height: 30

  Accessible.name: windowData ? (windowData.title + ", " + windowData.class) : ""
  Accessible.role: Accessible.ListItem

  opacity: (!isSearching || isMatched) ? 1.0 : 0.18
  Behavior on opacity {
    NumberAnimation { duration: 80 }
  }

  // Branch elbow connector on the left
  Elbow {
    x: 6
    y: 0
    width: 15
    height: 16
    radius: 9
    strokeColor: Qt.rgba(monitorAccent.r, monitorAccent.g, monitorAccent.b, 0.34)
    strokeWidth: 1.5
  }

  // Row selection capsule and contents
  Rectangle {
    id: rowCapsule
    anchors.left: parent.left
    anchors.leftMargin: 21
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    height: 28
    radius: 10

    color: isSelected
      ? Qt.rgba(255, 255, 255, 0.065)
      : "transparent"

    border.width: isSelected ? 1 : 0
    border.color: Qt.rgba(monitorAccent.r, monitorAccent.g, monitorAccent.b, 0.42)

    Row {
      anchors.fill: parent
      anchors.leftMargin: 10
      anchors.rightMargin: 10
      spacing: 10
      anchors.verticalCenter: parent.verticalCenter

      AppIcon {
        id: appIcon
        appClass: windowData ? windowData.class : ""
        accentColor: monitorAccent
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        id: classText
        textFormat: Text.PlainText
        text: windowData ? windowData.class : ""
        color: isSelected
          ? Color.foreground
          : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.85)
        font.pixelSize: 12
        font.weight: 500
        font.family: "monospace"
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(72, implicitWidth)
      }

      Text {
        id: titleText
        text: windowData ? windowData.title : ""
        textFormat: Text.PlainText
        color: isSelected
          ? Color.foreground
          : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.55)
        font.pixelSize: 13
        font.weight: 400
        font.family: "monospace"
        elide: Text.ElideRight
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - appIcon.width - classText.width - (curDot.visible ? 28 : 10) - 20
      }

      // Active window indicator dot
      Item {
        id: curDot
        width: 14
        height: 14
        anchors.verticalCenter: parent.verticalCenter
        visible: windowData && windowData.focused === true

        Rectangle {
          anchors.centerIn: parent
          width: 7
          height: 7
          radius: 3.5
          color: monitorAccent
        }

        Rectangle {
          anchors.centerIn: parent
          width: 13
          height: 13
          radius: 6.5
          color: "transparent"
          border.width: 1
          border.color: Qt.rgba(monitorAccent.r, monitorAccent.g, monitorAccent.b, 0.4)
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      onClicked: windowRowRoot.clicked()
    }
  }
}
