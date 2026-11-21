import QtQuick
import qs.Commons

Item {
  id: wsNodeRoot

  property var workspaceData: null
  property string monitorName: ""
  property color monitorAccent: Color.accent
  property bool isFolded: false
  property bool isFlashed: false
  property bool isSelected: false
  property bool isSearching: false
  property bool isMatched: true
  property string selectedAddress: ""
  property string searchQuery: ""

  signal headerClicked()
  signal windowClicked(string address)

  width: parent ? parent.width : 480
  readonly property bool hasWindows: workspaceData && workspaceData.windows && workspaceData.windows.length > 0
  readonly property int windowCount: hasWindows ? workspaceData.windows.length : 0

  height: headerRow.height + (hasWindows && !isFolded ? (winsContainer.height + 4) : 0)

  opacity: (!isSearching || isMatched) ? (hasWindows ? 1.0 : 0.45) : 0.18
  Behavior on opacity {
    NumberAnimation { duration: 80 }
  }

  // Branch elbow from monitor spine to workspace header
  Elbow {
    x: 6
    y: 0
    width: 17
    height: 19
    radius: 11
    strokeColor: Qt.rgba(monitorAccent.r, monitorAccent.g, monitorAccent.b, hasWindows ? 0.7 : 0.25)
    strokeWidth: 2
  }

  // Workspace Header
  Rectangle {
    id: headerRow
    anchors.left: parent.left
    anchors.leftMargin: 26
    anchors.right: parent.right
    height: 36
    radius: 12

    color: isSelected
      ? Qt.rgba(255, 255, 255, 0.065)
      : "transparent"

    border.width: isSelected ? 1 : 0
    border.color: Qt.rgba(monitorAccent.r, monitorAccent.g, monitorAccent.b, 0.42)

    Row {
      anchors.fill: parent
      anchors.leftMargin: 8
      anchors.rightMargin: 12
      spacing: 10
      anchors.verticalCenter: parent.verticalCenter

      // 9x9 Dot
      Item {
        width: 9
        height: 9
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
          anchors.fill: parent
          radius: 4.5
          color: wsNodeRoot.hasWindows
            ? wsNodeRoot.monitorAccent
            : "transparent"
          border.width: wsNodeRoot.hasWindows ? 0 : 1.5
          border.color: Qt.rgba(wsNodeRoot.monitorAccent.r, wsNodeRoot.monitorAccent.g, wsNodeRoot.monitorAccent.b, 0.7)
        }

        // Glow
        Rectangle {
          anchors.centerIn: parent
          width: 15
          height: 15
          radius: 7.5
          visible: wsNodeRoot.hasWindows
          color: "transparent"
          border.width: 1
          border.color: Qt.rgba(wsNodeRoot.monitorAccent.r, wsNodeRoot.monitorAccent.g, wsNodeRoot.monitorAccent.b, 0.25)
        }
      }

      // 22x22 circled number badge
      Rectangle {
        width: 22
        height: 22
        radius: 11
        anchors.verticalCenter: parent.verticalCenter
        color: "transparent"
        border.width: 1.5
        border.color: wsNodeRoot.hasWindows
          ? Qt.rgba(wsNodeRoot.monitorAccent.r, wsNodeRoot.monitorAccent.g, wsNodeRoot.monitorAccent.b, 0.75)
          : Qt.rgba(255, 255, 255, 0.2)

        Text {
          anchors.centerIn: parent
          text: wsNodeRoot.workspaceData ? String(wsNodeRoot.workspaceData.number) : ""
          font.pixelSize: 12
          font.weight: 600
          font.family: "monospace"
          color: wsNodeRoot.hasWindows
            ? Color.foreground
            : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
        }
      }

      // Workspace label (classes preview or "empty")
      Text {
        text: wsNodeRoot.workspaceData ? wsNodeRoot.workspaceData.label : ""
        textFormat: Text.PlainText
        font.pixelSize: 13
        font.family: "monospace"
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.55)
        elide: Text.ElideRight
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 22 - 9 - 30 - 40 - (chevron.visible ? 18 : 0)
      }

      // Window count badge
      Text {
        text: String(wsNodeRoot.windowCount)
        font.pixelSize: 12
        font.family: "monospace"
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
        anchors.verticalCenter: parent.verticalCenter
      }

      // Chevron
      Canvas {
        id: chevron
        width: 12
        height: 12
        visible: wsNodeRoot.hasWindows
        anchors.verticalCenter: parent.verticalCenter

        onPaint: {
          var ctx = getContext("2d")
          ctx.reset()
          ctx.strokeStyle = Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.55)
          ctx.lineWidth = 1.4
          ctx.lineCap = "round"
          ctx.lineJoin = "round"
          ctx.beginPath()
          if (wsNodeRoot.isFolded) {
            // Right chevron >
            ctx.moveTo(4, 2.5)
            ctx.lineTo(8, 6)
            ctx.lineTo(4, 9.5)
          } else {
            // Down chevron v
            ctx.moveTo(2.5, 4)
            ctx.lineTo(6, 8)
            ctx.lineTo(9.5, 4)
          }
          ctx.stroke()
        }

        Connections {
          target: wsNodeRoot
          function onIsFoldedChanged() { chevron.requestPaint() }
        }
      }
    }

    // Row-level flash overlay (for empty workspace digit press or focus failed)
    Rectangle {
      anchors.fill: parent
      radius: 12
      color: "white"
      opacity: wsNodeRoot.isFlashed ? 0.12 : 0.0
      Behavior on opacity {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
      }
    }

    MouseArea {
      anchors.fill: parent
      onClicked: wsNodeRoot.headerClicked()
    }
  }

  // Windows block (when unfolded and populated)
  Item {
    id: winsContainer
    anchors.top: headerRow.bottom
    anchors.left: parent.left
    anchors.leftMargin: 32
    anchors.right: parent.right
    visible: wsNodeRoot.hasWindows && !wsNodeRoot.isFolded
    height: winsColumn.implicitHeight

    // Vertical spine line connecting all window rows
    Rectangle {
      x: 6
      y: 0
      width: 2
      height: Math.max(0, winsContainer.height - 14)
      color: Qt.rgba(wsNodeRoot.monitorAccent.r, wsNodeRoot.monitorAccent.g, wsNodeRoot.monitorAccent.b, 0.34)
    }

    Column {
      id: winsColumn
      anchors.left: parent.left
      anchors.right: parent.right
      spacing: 0

      Repeater {
        model: wsNodeRoot.hasWindows ? wsNodeRoot.workspaceData.windows : []

        WindowRow {
          required property var modelData
          windowData: modelData
          monitorAccent: wsNodeRoot.monitorAccent
          isSelected: wsNodeRoot.selectedAddress === modelData.address
          isMatched: !wsNodeRoot.isSearching || (wsNodeRoot.searchQuery.length === 0)
            || (modelData.title.toLowerCase().indexOf(wsNodeRoot.searchQuery) >= 0)
            || (modelData.class.toLowerCase().indexOf(wsNodeRoot.searchQuery) >= 0)
            || (String(wsNodeRoot.workspaceData.number).indexOf(wsNodeRoot.searchQuery) >= 0)
          isSearching: wsNodeRoot.isSearching
          searchQuery: wsNodeRoot.searchQuery
          onClicked: wsNodeRoot.windowClicked(modelData.address)
        }
      }
    }
  }
}
