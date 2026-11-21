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

  // Card container representing the monitor window
  Rectangle {
    id: cardBg
    anchors.fill: parent
    radius: 18
    color: isCurrentMonitor
      ? Qt.rgba(255, 255, 255, 0.04)
      : Qt.rgba(255, 255, 255, 0.018)

    border.width: isCurrentMonitor ? 1.5 : 1
    border.color: isCurrentMonitor
      ? Qt.rgba(colRoot.monitorAccent.r, colRoot.monitorAccent.g, colRoot.monitorAccent.b, 0.45)
      : Qt.rgba(255, 255, 255, 0.08)

    Behavior on border.color { ColorAnimation { duration: 140 } }
    Behavior on color { ColorAnimation { duration: 140 } }

    // Header section pinned at the top
    Item {
      id: headerSection
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      height: 52

      Item {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16

        // Left: Dot + Monitor name + meta
        Column {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: 2

          Row {
            spacing: 10

            // 12x12 dot
            Item {
              width: 12
              height: 12
              anchors.verticalCenter: parent.verticalCenter

              Rectangle {
                anchors.centerIn: parent
                width: 12
                height: 12
                radius: 6
                color: (colRoot.rootData && colRoot.rootData.focused)
                  ? colRoot.monitorAccent
                  : "transparent"
                border.width: 2
                border.color: colRoot.monitorAccent
              }

              // Focused glow
              Rectangle {
                anchors.centerIn: parent
                width: 18
                height: 18
                radius: 9
                visible: colRoot.rootData && colRoot.rootData.focused
                color: "transparent"
                border.width: 1.5
                border.color: Qt.rgba(colRoot.monitorAccent.r, colRoot.monitorAccent.g, colRoot.monitorAccent.b, 0.3)
              }
            }

            Text {
              textFormat: Text.PlainText
              text: colRoot.rootData ? colRoot.rootData.monitor : ""
              font.pixelSize: 15
              font.weight: 600
              font.family: "sans-serif"
              color: Color.foreground
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          // Monitor Meta text: primary · 2560x1440 · focused
          Text {
            anchors.left: parent.left
            anchors.leftMargin: 22
            textFormat: Text.PlainText
            text: {
              if (!colRoot.rootData) return ""
              var isPri = colRoot.rootData.focused
              var res = colRoot.rootData.width + "×" + colRoot.rootData.height
              return (isPri ? "primary · " : "secondary · ") + res + (isPri ? " · focused" : "")
            }
            font.pixelSize: 11
            font.family: "sans-serif"
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.5)
          }
        }

        // Right side: Active / Jump shortcut badge
        Rectangle {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          height: 22
          width: shortcutRow.implicitWidth + 14
          radius: 11
          color: isCurrentMonitor
            ? Qt.rgba(colRoot.monitorAccent.r, colRoot.monitorAccent.g, colRoot.monitorAccent.b, 0.16)
            : Qt.rgba(255, 255, 255, 0.05)
          border.width: 1
          border.color: isCurrentMonitor
            ? Qt.rgba(colRoot.monitorAccent.r, colRoot.monitorAccent.g, colRoot.monitorAccent.b, 0.4)
            : Qt.rgba(255, 255, 255, 0.08)

          Row {
            id: shortcutRow
            anchors.centerIn: parent
            spacing: 5

            Text {
              text: isCurrentMonitor ? "active" : ("mon " + (colRoot.monitorIndex + 1))
              font.pixelSize: 11
              font.weight: 500
              font.family: "sans-serif"
              color: isCurrentMonitor
                ? colRoot.monitorAccent
                : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.55)
              anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
              width: 1
              height: 10
              color: Qt.rgba(255, 255, 255, 0.15)
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              text: colRoot.monitorIndex === 0 ? "^h" : "^l"
              font.pixelSize: 10
              font.weight: 600
              font.family: "monospace"
              color: isCurrentMonitor
                ? colRoot.monitorAccent
                : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.65)
              anchors.verticalCenter: parent.verticalCenter
            }
          }
        }
      }

      // Divider below header
      Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Qt.rgba(255, 255, 255, 0.06)
      }
    }

    // Workspaces Scrollable Area
    Flickable {
      id: workspacesFlickable
      anchors.top: headerSection.bottom
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.topMargin: 6
      anchors.bottomMargin: 8
      anchors.leftMargin: 8
      anchors.rightMargin: 8
      clip: true

      contentWidth: width
      contentHeight: workspacesColumn.height + 12
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

    // Scrollbar indicator
    Rectangle {
      id: scrollbar
      anchors.right: parent.right
      anchors.rightMargin: 4
      width: 3
      radius: 1.5
      visible: workspacesFlickable.contentHeight > workspacesFlickable.height
      y: {
        var avail = workspacesFlickable.height - height
        var maxScroll = workspacesFlickable.contentHeight - workspacesFlickable.height
        if (maxScroll <= 0) return headerSection.height + 6
        return headerSection.height + 6 + (workspacesFlickable.contentY / maxScroll) * avail
      }
      height: Math.max(24, (workspacesFlickable.height / workspacesFlickable.contentHeight) * workspacesFlickable.height)
      color: isCurrentMonitor
        ? Qt.rgba(colRoot.monitorAccent.r, colRoot.monitorAccent.g, colRoot.monitorAccent.b, 0.6)
        : Qt.rgba(255, 255, 255, 0.22)
    }
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
