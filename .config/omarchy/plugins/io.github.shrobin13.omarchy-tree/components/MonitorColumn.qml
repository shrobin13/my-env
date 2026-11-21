import QtQuick
import qs.Commons

Item {
  id: colRoot

  property var rootData: null
  property int monitorIndex: 0
  property var cursorRow: null
  property var folds: ({})
  property string flashedKey: ""
  property bool isSearching: false
  property string searchQuery: ""

  signal workspaceClicked(var workspace)
  signal windowClicked(string address)

  width: 480
  height: headerSection.height + workspacesColumn.height + 16

  readonly property color monitorAccent: {
    if (monitorIndex === 0) return Color.accent
    // Rotate hue by ~160 degrees (0.45 in 0..1 scale) for monitor 1+
    var c = Color.accent
    var h = (c.hsvHue + 0.45 * monitorIndex) % 1.0
    return Qt.hsva(h, Math.min(1.0, c.hsvSaturation * 1.05), c.hsvValue, 1.0)
  }

  // Monitor Header section
  Item {
    id: headerSection
    width: parent.width
    height: 48

    // Row with dot and monitor name
    Row {
      id: titleRow
      anchors.top: parent.top
      anchors.left: parent.left
      spacing: 12
      height: 28

      // 14x14 dot
      Item {
        width: 14
        height: 14
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
          id: dotRect
          anchors.centerIn: parent
          width: 14
          height: 14
          radius: 7
          color: (colRoot.rootData && colRoot.rootData.focused)
            ? colRoot.monitorAccent
            : "transparent"
          border.width: 2
          border.color: colRoot.monitorAccent
        }

        // Focused glow
        Rectangle {
          anchors.centerIn: parent
          width: 22
          height: 22
          radius: 11
          visible: colRoot.rootData && colRoot.rootData.focused
          color: "transparent"
          border.width: 2
          border.color: Qt.rgba(colRoot.monitorAccent.r, colRoot.monitorAccent.g, colRoot.monitorAccent.b, 0.25)
        }
      }

      Text {
        textFormat: Text.PlainText
        text: colRoot.rootData ? colRoot.rootData.monitor : ""
        font.pixelSize: 16
        font.weight: 600
        font.family: "sans-serif"
        color: Color.foreground
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    // Monitor Meta text: primary · 2560x1440 · focused
    Text {
      id: metaText
      anchors.top: titleRow.bottom
      anchors.topMargin: 2
      anchors.left: parent.left
      anchors.leftMargin: 26
      textFormat: Text.PlainText
      text: {
        if (!colRoot.rootData) return ""
        var isPri = colRoot.rootData.focused
        var res = colRoot.rootData.width + "×" + colRoot.rootData.height
        return (isPri ? "primary · " : "secondary · ") + res + (isPri ? " · focused" : "")
      }
      font.pixelSize: 12
      font.family: "sans-serif"
      color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.55)
    }

    // Spine connector line directly under the monitor header
    Rectangle {
      x: 6
      anchors.top: titleRow.bottom
      anchors.bottom: parent.bottom
      width: 2
      color: Qt.rgba(colRoot.monitorAccent.r, colRoot.monitorAccent.g, colRoot.monitorAccent.b, 0.7)
    }
  }

  // Workspaces area
  Item {
    id: workspacesArea
    anchors.top: headerSection.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: workspacesColumn.height

    // Main fading vertical spine along the left side
    Spine {
      x: 6
      y: 0
      height: Math.max(0, workspacesColumn.height - 24)
      topColor: Qt.rgba(colRoot.monitorAccent.r, colRoot.monitorAccent.g, colRoot.monitorAccent.b, 0.7)
      bottomColor: Qt.rgba(colRoot.monitorAccent.r, colRoot.monitorAccent.g, colRoot.monitorAccent.b, 0.1)
    }

    Column {
      id: workspacesColumn
      anchors.left: parent.left
      anchors.right: parent.right
      spacing: 6

      Repeater {
        model: colRoot.rootData ? colRoot.rootData.workspaces : []

        WorkspaceNode {
          required property var modelData
          required property int index

          workspaceData: modelData
          monitorName: colRoot.rootData ? colRoot.rootData.monitor : ""
          monitorAccent: colRoot.monitorAccent

          readonly property string foldKey1: (colRoot.rootData ? colRoot.rootData.monitor : "") + ":" + modelData.number
          readonly property string foldKey2: (colRoot.rootData ? colRoot.rootData.monitor : "") + ":" + modelData.id + ":" + modelData.number
          isFolded: Boolean(colRoot.folds && (colRoot.folds[foldKey1] === true || colRoot.folds[foldKey2] === true))

          readonly property string wsKey: (colRoot.rootData ? colRoot.rootData.monitor : "") + ":" + modelData.number
          isFlashed: colRoot.flashedKey === wsKey

          isSelected: colRoot.cursorRow
            && colRoot.cursorRow.kind === "workspace"
            && colRoot.cursorRow.monitor === (colRoot.rootData ? colRoot.rootData.monitor : "")
            && colRoot.cursorRow.workspace.number === modelData.number

          selectedAddress: (colRoot.cursorRow && colRoot.cursorRow.kind === "window" && colRoot.cursorRow.window)
            ? colRoot.cursorRow.window.address
            : ""

          isSearching: colRoot.isSearching
          searchQuery: colRoot.searchQuery

          isMatched: !colRoot.isSearching || (colRoot.searchQuery.length === 0)
            || (String(modelData.number).indexOf(colRoot.searchQuery) >= 0)
            || (modelData.windows.some(function(w) {
                 return w.title.toLowerCase().indexOf(colRoot.searchQuery) >= 0
                   || w.class.toLowerCase().indexOf(colRoot.searchQuery) >= 0
               }))

          onHeaderClicked: colRoot.workspaceClicked(modelData)
          onWindowClicked: function(addr) { colRoot.windowClicked(addr) }
        }
      }
    }
  }
}
