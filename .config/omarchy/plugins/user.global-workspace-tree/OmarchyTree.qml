pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs.Commons
import "Model.js" as Model
import "Tree.js" as Tree

Item {
  id: root

  property bool opened: false
  property var model: null
  property var treeState: null
  property var folded: ({})
  property string searchText: ""
  property bool searchMode: false
  property bool gPending: false
  property bool loadFailed: false
  property int summonSerial: 0
  property bool reloadPending: false
  property bool awaitingReply: false

  function open(payloadJson) {
    root.opened = true
    root.loadFailed = false
    root.searchMode = false
    root.searchText = ""
    root.summonSerial++
    root.reload()
    Qt.callLater(function () { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
    root.searchMode = false
    root.searchText = ""
    root.gPending = false
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open("{}")
  }

  function ping() { return "ok" }

  function reload() {
    if (monitorsProc.running || workspacesProc.running || clientsProc.running) {
      root.reloadPending = true
      return
    }
    root.startSnapshot()
  }

  property string monitorsJson: ""
  property string workspacesJson: ""
  property string clientsJson: ""

  function startSnapshot() {
    root.awaitingReply = true
    root.monitorsJson = ""
    root.workspacesJson = ""
    root.clientsJson = ""
    monitorsProc.running = true
  }

  function finishSnapshot() {
    if (root.monitorsJson === "" || root.workspacesJson === "" || root.clientsJson === "") return
    var snapshot = Model.buildSnapshot(root.monitorsJson, root.workspacesJson, root.clientsJson)
    root.awaitingReply = false
    if (snapshot) {
      root.model = snapshot
      root.rebuildTree()
      root.loadFailed = false
    } else {
      root.loadFailed = true
    }
    if (root.reloadPending) {
      root.reloadPending = false
      root.startSnapshot()
    }
  }

  function rebuildTree() {
    var state = Tree.makeState(root.model)
    var oldCursorRow = null
    if (root.treeState && root.treeState.rows[root.treeState.cursor]) {
      var oldRow = root.treeState.rows[root.treeState.cursor]
      oldCursorRow = oldRow.window ? oldRow.window.address : (oldRow.workspace ? oldRow.workspace.monitor + ":" + oldRow.workspace.number : null)
    }
    var rows = Tree.flatten(root.model, root.folded, root.searchText)
    state.rows = rows
    state.folds = root.folded
    var cursor = 0
    if (root.searchText.length === 0) {
      if (oldCursorRow) {
        for (var oi = 0; oi < rows.length; oi++) {
          var candidate = rows[oi]
          var key = candidate.window ? candidate.window.address : (candidate.workspace ? candidate.workspace.monitor + ":" + candidate.workspace.number : null)
          if (key === oldCursorRow) { cursor = oi; break }
        }
      }
      if (!oldCursorRow && root.model && root.model.focusedAddress) {
        for (var fi = 0; fi < rows.length; fi++) {
          if (rows[fi].window && rows[fi].window.address === root.model.focusedAddress) {
            cursor = fi
            break
          }
        }
      }
    } else {
      for (var si = 0; si < rows.length; si++) {
        if (rows[si].matched) { cursor = si; break }
      }
    }
    state.cursor = cursor
    root.treeState = state
  }

  function currentRow() {
    if (!root.treeState || !root.treeState.rows) return null
    return root.treeState.rows[root.treeState.cursor] || null
  }

  function setCursor(next) {
    if (!root.treeState) return
    var state = root.treeState
    state.cursor = next
    root.treeState = state
  }

  function setCursorRow(row) {
    if (!root.treeState || !root.treeState.rows) return
    for (var i = 0; i < root.treeState.rows.length; i++) {
      if (root.treeState.rows[i] === row) {
        root.setCursor(i)
        return
      }
    }
  }

  function move(delta) {
    if (!root.treeState) return
    var rows = root.treeState.rows
    if (!rows.length) return
    var next = root.treeState.cursor + delta
    next = Math.max(0, Math.min(rows.length - 1, next))
    if (root.searchText.length > 0) {
      var direction = delta > 0 ? 1 : -1
      for (var i = next; i >= 0 && i < rows.length; i += direction) {
        if (rows[i].matched) { next = i; break }
      }
    }
    root.setCursor(next)
  }

  function foldOrUnfoldWorkspace() {
    var row = root.currentRow()
    if (!row || !row.workspace) return
    var workspace = row.workspace
    var foldKey = row.monitor + ":" + workspace.id + ":" + workspace.number
    if (root.folded[foldKey]) delete root.folded[foldKey]
    else root.folded[foldKey] = true
    root.rebuildTree()
  }

  function moveToWorkspaceHeader() {
    var row = root.currentRow()
    if (!row || !root.treeState) return
    var workspace = row.workspace
    if (!workspace) return
    var rows = root.treeState.rows
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].kind === "workspace"
          && rows[i].monitor === row.monitor
          && rows[i].workspace.number === workspace.number) {
        root.setCursor(i)
        return
      }
    }
  }

  function unfoldWorkspace() {
    var row = root.currentRow()
    if (!row || row.kind !== "workspace" || !root.treeState) return
    var workspace = row.workspace
    var foldKey = row.monitor + ":" + workspace.id + ":" + workspace.number
    if (root.folded[foldKey]) {
      delete root.folded[foldKey]
      root.rebuildTree()
      return
    }
    var rows = root.treeState.rows
    for (var i = root.treeState.cursor + 1; i < rows.length; i++) {
      if (rows[i].kind === "window"
          && rows[i].monitor === row.monitor
          && rows[i].workspace.number === workspace.number) {
        root.setCursor(i)
        return
      }
    }
  }

  function moveToDigit(digit) {
    var row = root.currentRow()
    var monitor = row ? row.monitor : (root.model && root.model.focusedMonitor)
    if (!monitor || !root.model) return
    for (var mi = 0; mi < root.model.roots.length; mi++) {
      var rootData = root.model.roots[mi]
      if (rootData.monitor !== monitor) continue
      var number = digit === "0" ? 10 : Number(digit)
      var workspace = rootData.workspaces[number - 1]
      if (!workspace) return
      if (!workspace.windows.length) {
        flashWorkspace(rootData.monitor, number)
        return
      }
      if (workspace.id > 0) root.switchWorkspace(workspace.id)
      var rows = root.treeState.rows
      for (var ri = 0; ri < rows.length; ri++) {
        if (rows[ri].kind === "workspace"
            && rows[ri].monitor === monitor
            && rows[ri].workspace.number === number) {
          root.treeState.cursor = ri
          root.setCursor(ri)
          return
        }
      }
      return
    }
  }

  property var flash: null
  Timer {
    id: flashTimer
    interval: 180
    repeat: false
    onTriggered: root.flash = null
  }
  function flashWorkspace(monitor, number) {
    root.flash = monitor + ":" + number
    flashTimer.restart()
  }

  function focusFailed() {
    root.flashWorkspace(root.pendingMonitor, 0)
    root.pendingAddress = ""
    root.reload()
  }

  function focusCurrent() {
    var row = root.currentRow()
    if (!row) return
    var workspace = row.workspace
    var window = row.window
    if (window) root.focusAddress(window.address)
    else if (workspace && workspace.windows.length > 0) {
      var ordered = workspace.windows.slice().sort(function (a, b) {
        return a.focusHistoryID - b.focusHistoryID
      })
      root.focusAddress(ordered[0].address)
    }
  }

  function focusAddress(address) {
    var row = root.currentRow()
    var monitor = row ? row.monitor : ""
    var workspaceId = row && row.workspace ? row.workspace.id : 0
    if (row && row.window) workspaceId = row.window.workspaceId
    var sequence = Model.focusSequence(address, monitor, workspaceId)
    if (!sequence.length) return
    root.pendingAddress = String(address)
    root.pendingMonitor = monitor
    root.pendingWorkspaceId = workspaceId
    root.pendingFallbackSent = false
    dispatchProc.command = sequence[0].command
    dispatchProc.running = true
  }

  property string pendingAddress: ""
  property string pendingMonitor: ""
  property int pendingWorkspaceId: 0
  property bool pendingFallbackSent: false

  Timer {
    id: verifyFocusTimer
    interval: 80
    repeat: false
    onTriggered: activeWindowProc.running = true
  }

  function switchWorkspace(workspaceId) {
    workspaceProc.command = ["hyprctl", "dispatch", "workspace", String(workspaceId)]
    workspaceProc.running = true
  }

  function moveFirst() {
    if (!root.treeState || !root.treeState.rows.length) return
    root.setCursor(0)
  }

  function moveLast() {
    if (!root.treeState || !root.treeState.rows.length) return
    root.setCursor(root.treeState.rows.length - 1)
  }

  function movePage(delta) {
    if (!root.treeState || !root.treeState.rows.length) return
    var count = root.treeState.rows.length
    var page = Math.max(1, Math.round(count / 2))
    root.move(delta * page)
  }

  function moveToNextMonitor() {
    var row = root.currentRow()
    if (!row || !root.model) return
    var monitorNames = []
    for (var i = 0; i < root.model.roots.length; i++) {
      monitorNames.push(root.model.roots[i].monitor)
    }
    var currentIndex = monitorNames.indexOf(row.monitor)
    var nextMonitor = monitorNames[(currentIndex + 1) % monitorNames.length]
    var rows = root.treeState.rows
    for (var ri = 0; ri < rows.length; ri++) {
      if (rows[ri].monitor === nextMonitor) {
        root.setCursor(ri)
        return
      }
    }
  }

  function enterSearch() {
    root.searchMode = true
    root.gPending = false
    Qt.callLater(function () { searchInput.forceActiveFocus() })
  }

  function exitSearch() {
    root.searchMode = false
    root.searchText = ""
    root.rebuildTree()
    Qt.callLater(function () { keyCatcher.forceActiveFocus() })
  }

  Timer {
    id: gTimer
    interval: 500
    repeat: false
    onTriggered: root.gPending = false
  }

  Timer {
    id: refreshTimer
    interval: 60
    repeat: false
    onTriggered: root.reload()
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) { if (root.opened) refreshTimer.restart() }
  }

  Process {
    id: monitorsProc
    command: ["hyprctl", "monitors", "-j"]
    stdout: StdioCollector { id: monitorsOut; waitForEnd: true }
    onExited: function (exitCode, exitStatus) {
      root.monitorsJson = monitorsOut.text
      if (exitCode === 0) workspacesProc.running = true
      else root.finishSnapshot()
    }
  }
  Process {
    id: workspacesProc
    command: ["hyprctl", "workspaces", "-j"]
    stdout: StdioCollector { id: workspacesOut; waitForEnd: true }
    onExited: function (exitCode, exitStatus) {
      root.workspacesJson = workspacesOut.text
      if (exitCode === 0) clientsProc.running = true
      else root.finishSnapshot()
    }
  }
  Process {
    id: clientsProc
    command: ["hyprctl", "clients", "-j"]
    stdout: StdioCollector { id: clientsOut; waitForEnd: true }
    onExited: function (exitCode, exitStatus) {
      root.clientsJson = clientsOut.text
      if (exitCode === 0) root.finishSnapshot()
      else root.finishSnapshot()
    }
  }
  Process {
    id: dispatchProc
    command: ["true"]
    onExited: verifyFocusTimer.restart()
  }
  Process {
    id: activeWindowProc
    command: ["hyprctl", "activewindow", "-j"]
    stdout: StdioCollector { id: activeWindowOut; waitForEnd: true }
    onExited: function (exitCode, exitStatus) {
      if (exitCode !== 0 || !root.pendingAddress) {
        root.focusFailed()
        return
      }
      try {
        var active = JSON.parse(activeWindowOut.text)
        if (active && active.address === root.pendingAddress) {
          root.pendingAddress = ""
          root.close()
          return
        }
      } catch (error) {}
      if (!root.pendingFallbackSent) {
        root.pendingFallbackSent = true
        var sequence = Model.focusSequence(root.pendingAddress, root.pendingMonitor, root.pendingWorkspaceId)
        fallbackProc.command = sequence[sequence.length - 1].command
        fallbackProc.running = true
      } else {
        root.focusFailed()
      }
    }
  }
  Process {
    id: fallbackProc
    command: ["true"]
    onExited: verifyFocusTimer.restart()
  }
  Process {
    id: workspaceProc
    command: ["true"]
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-tree"
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, 0.35)
    }

    Rectangle {
      anchors.centerIn: parent
      width: 760
      height: 680
      radius: 24
      color: Color.background
      opacity: 0.86
      border.width: 1
      border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12)

      Column {
        anchors.fill: parent
        anchors.margins: 32
        spacing: 16

        Text {
          textFormat: Text.PlainText
          text: "Window Tree"
          color: Color.foreground
          font.pixelSize: 15
          font.weight: 600
          font.family: "monospace"
        }

        TextInput {
          id: searchInput
          visible: root.searchMode
          width: parent.width
          text: root.searchText
          color: Color.foreground
          font.pixelSize: 14
          font.family: "monospace"
          onTextChanged: {
            root.searchText = text
            root.rebuildTree()
          }
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
              root.exitSearch()
              event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              root.focusCurrent()
              event.accepted = true
            }
          }
        }

        Flickable {
          width: parent.width
          height: parent.height - (root.searchMode ? 100 : 48)
          clip: true
          contentHeight: treeColumn.height

          Column {
            id: treeColumn
            width: parent.width
            spacing: 4

            Repeater {
              model: root.treeState ? root.treeState.rows : []

              Rectangle {
                required property var modelData
                width: treeColumn.width
                height: modelData.kind === "window" ? 28 : 32
                radius: 8
                color: root.treeState && root.treeState.rows[root.treeState.cursor] === modelData
                  ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08)
                  : "transparent"
                opacity: root.searchText.length === 0 || modelData.matched ? 1.0 : 0.18

                Row {
                  anchors.fill: parent
                  anchors.leftMargin: modelData.kind === "window" ? 24 : 8
                  spacing: 8

                  Text {
                    textFormat: Text.PlainText
                    text: modelData.kind === "workspace"
                      ? ("[" + modelData.workspace.number + "]")
                      : ("  " + modelData.window.class)
                    color: modelData.kind === "workspace" ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.55)
                    font.pixelSize: modelData.kind === "workspace" ? 13 : 11
                    font.family: "monospace"
                  }
                  Text {
                    textFormat: Text.PlainText
                    text: modelData.kind === "workspace"
                      ? (modelData.monitor + "  " + (modelData.workspace.windows.length === 0 ? "empty" : ""))
                      : modelData.window.title
                    color: Color.foreground
                    font.pixelSize: modelData.kind === "workspace" ? 13 : 13
                    font.family: "monospace"
                    elide: Text.ElideRight
                    width: 620
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  onClicked: {
                    root.setCursorRow(modelData)
                    root.focusCurrent()
                  }
                }
              }
            }
          }
        }

        Text {
          textFormat: Text.PlainText
          text: "j/k move  h/l fold  / search  Enter focus  q/Esc close"
          color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.55)
          font.pixelSize: 11
          font.family: "monospace"
        }
      }

      Rectangle {
        anchors.fill: parent
        visible: root.flash !== null
        color: Qt.rgba(1, 1, 1, 0.06)
        radius: 24
      }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape || event.text === "q") {
            if (root.searchMode) {
              root.searchMode = false
              root.searchText = ""
              root.rebuildTree()
            } else {
              root.close()
            }
            event.accepted = true
            return
          }
          if (root.searchMode) return
          if (event.text === "j") { root.move(1); event.accepted = true }
          else if (event.text === "k") { root.move(-1); event.accepted = true }
          else if (event.text === "h") {
            if (root.currentRow() && root.currentRow().kind === "window") root.moveToWorkspaceHeader()
            else if (root.currentRow() && root.currentRow().kind === "workspace") root.foldOrUnfoldWorkspace()
            event.accepted = true
          }
          else if (event.text === "l") { root.unfoldWorkspace(); event.accepted = true }
          else if (event.text === "/") { root.enterSearch(); event.accepted = true }
          else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.focusCurrent(); event.accepted = true }
          else if (event.text >= "0" && event.text <= "9") { root.moveToDigit(event.text); event.accepted = true }
          else if (event.key === Qt.Key_U && event.modifiers & Qt.ControlModifier) { root.movePage(-1); event.accepted = true }
          else if (event.key === Qt.Key_D && event.modifiers & Qt.ControlModifier) { root.movePage(1); event.accepted = true }
          else if (event.text === "g") {
            if (root.gPending) { root.moveFirst(); root.gPending = false }
            else { root.gPending = true; gTimer.restart() }
            event.accepted = true
          } else if (event.text === "G") { root.moveLast(); event.accepted = true }
          else if (event.key === Qt.Key_Tab) { root.moveToNextMonitor(); event.accepted = true }
        }
      }
    }
  }
}
