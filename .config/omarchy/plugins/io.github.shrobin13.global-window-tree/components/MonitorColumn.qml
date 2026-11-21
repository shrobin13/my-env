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

  readonly property bool isCurrentMonitor: colRoot.cursorRow && colRoot.cursorRow.monitor === (colRoot.rootData ? colRoot.rootData.monitor : "")
  readonly property color monitorAccent: {
    if (monitorIndex === 0) return Color.accent
    // Rotate hue by ~160 degrees (0.45 in 0..1 scale) for monitor 1+
    var c = Color.accent
    var h = (c.hsvHue + 0.45 * monitorIndex) % 1.0
    return Qt.hsva(h, Math.min(1.0, c.hsvSaturation * 1.05), c.hsvValue, 1.0)
  }

  // Header section (pinned at top)
  Item {
    id: headerSection
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 48

    // Row with dot, monitor name, and meta
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
        color: isCurrentMonitor ? Color.foreground : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.75)
        anchors.verticalCenter: parent.verticalCenter
      }

      // Small shortcut badge (^h / ^l)
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        height: 18
        width: shortcutText.implicitWidth + 10
        radius: 9
        color: isCurrentMonitor
          ? Qt.rgba(colRoot.monitorAccent.r, colRoot.monitorAccent.g, colRoot.monitorAccent.b, 0.18)
          : Qt.rgba(255, 255, 255, 0.06)

        Text {
          id: shortcutText
          anchors.centerIn: parent
          text: colRoot.monitorIndex === 0 ? "Ctrl+h" : "Ctrl+l"
          font.pixelSize: 10
          font.weight: 500
          font.family: "monospace"
          color: isCurrentMonitor
            ? colRoot.monitorAccent
            : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.45)
        }
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
      color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
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

  // Workspaces Scrollable Area
  Flickable {
    id: workspacesFlickable
    anchors.top: headerSection.bottom
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.topMargin: 2
    clip: true

    contentWidth: width
    contentHeight: workspacesColumn.height + 16
    boundsBehavior: Flickable.StopAtBounds

    Behavior on contentY {
      NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
    }

    Item {
      width: parent.width
      height: workspacesColumn.height + 8

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
          id: wsRepeater
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

  // Minimal scroll indicator on the right edge
  Rectangle {
    id: scrollbar
    anchors.right: parent.right
    anchors.rightMargin: 2
    width: 2.5
    radius: 1.25
    visible: workspacesFlickable.contentHeight > workspacesFlickable.height
    y: {
      var avail = workspacesFlickable.height - height
      var maxScroll = workspacesFlickable.contentHeight - workspacesFlickable.height
      if (maxScroll <= 0) return headerSection.height + 2
      return headerSection.height + 2 + (workspacesFlickable.contentY / maxScroll) * avail
    }
    height: Math.max(24, (workspacesFlickable.height / workspacesFlickable.contentHeight) * workspacesFlickable.height)
    color: isCurrentMonitor
      ? Qt.rgba(colRoot.monitorAccent.r, colRoot.monitorAccent.g, colRoot.monitorAccent.b, 0.5)
      : Qt.rgba(255, 255, 255, 0.2)
  }

  function scrollToCursor() {
    if (!isCurrentMonitor || !colRoot.cursorRow) return
    var cur = colRoot.cursorRow
    var wsNum = 0
    if (cur.workspace) wsNum = cur.workspace.number
    else if (cur.window) wsNum = cur.window.workspaceNumber
    if (wsNum < 1 || wsNum > wsRepeater.count) return

    var node = wsRepeater.itemAt(wsNum - 1)
    if (!node) return

    var targetY = node.y
    var targetH = 36

    if (cur.kind === "window" && cur.window && node.workspaceData && node.workspaceData.windows) {
      for (var wi = 0; wi < node.workspaceData.windows.length; wi++) {
        if (node.workspaceData.windows[wi].address === cur.window.address) {
          targetY += 36 + wi * 30
          targetH = 30
          break
        }
      }
    }

    var viewTop = workspacesFlickable.contentY
    var viewH = workspacesFlickable.height
    var viewBottom = viewTop + viewH
    var margin = 24

    if (targetY < viewTop + margin) {
      workspacesFlickable.contentY = Math.max(0, targetY - margin)
    } else if (targetY + targetH > viewBottom - margin) {
      var maxScroll = Math.max(0, workspacesFlickable.contentHeight - viewH)
      workspacesFlickable.contentY = Math.min(maxScroll, targetY + targetH - viewH + margin)
    }
  }

  onCursorRowChanged: Qt.callLater(scrollToCursor)
  Component.onCompleted: Qt.callLater(scrollToCursor)
}
