pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs.Commons
import qs.Commons as Commons
import "Model.js" as Model
import "Tree.js" as Tree
import "components"

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

  property string monitorsJson: ""
  property string workspacesJson: ""
  property string clientsJson: ""
  property string activeWindowJson: ""

  property string flashedWorkspaceKey: ""
  property string pendingAddress: ""
  property string pendingMonitor: ""
  property int pendingWorkspaceId: 0
  property bool pendingFallbackSent: false

  readonly property bool reducedMotion: Quickshell.env("OMARCHY_TREE_REDUCED_MOTION") === "1"
  readonly property bool highContrast: Quickshell.env("OMARCHY_TREE_HC") === "1"

  function open(payloadJson) {
    root.opened = true
    root.loadFailed = false
    root.searchMode = false
    root.searchText = ""
    searchBar.searchText = ""
    root.summonSerial++
    root.reload()
    Qt.callLater(function () { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
    root.searchMode = false
    root.searchText = ""
    searchBar.searchText = ""
    root.gPending = false
    root.awaitingReply = false
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open("{}")
  }

  function ping() { return "ok" }

  function reload() {
    if (monitorsProc.running || workspacesProc.running || clientsProc.running || activeWindowProc.running) {
      root.reloadPending = true
      return
    }
    root.startSnapshot()
  }

  function startSnapshot() {
    root.awaitingReply = true
    root.monitorsJson = ""
    root.workspacesJson = ""
    root.clientsJson = ""
    root.activeWindowJson = ""
    monitorsProc.running = true
  }

  function finishSnapshot() {
    root.awaitingReply = false
    if (root.monitorsJson === "" || root.workspacesJson === "" || root.clientsJson === "") {
      root.loadFailed = true
      return
    }
    var snapshot = Model.buildSnapshot(root.monitorsJson, root.workspacesJson, root.clientsJson, root.activeWindowJson)
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
    if (!root.model) return
    var state = Tree.makeState(root.model)
    state.folds = root.folded
    state.search = root.searchText
    var rows = Tree.flatten(root.model, root.folded, root.searchText)
    state.rows = rows

    var oldCursorAddress = null
    var oldCursorWsKey = null
    if (root.treeState && root.treeState.rows && root.treeState.rows[root.treeState.cursor]) {
      var oldRow = root.treeState.rows[root.treeState.cursor]
      if (oldRow.window) {
        oldCursorAddress = oldRow.window.address
        if (oldRow.workspace) oldCursorWsKey = oldRow.monitor + ":" + oldRow.workspace.number
      } else if (oldRow.workspace) {
        oldCursorWsKey = oldRow.monitor + ":" + oldRow.workspace.number
      }
    }

    var cursor = 0
    if (root.searchText.length === 0) {
      var foundOld = false
      if (oldCursorAddress) {
        for (var i = 0; i < rows.length; i++) {
          if (rows[i].window && rows[i].window.address === oldCursorAddress) {
            cursor = i
            foundOld = true
            break
          }
        }
      } else if (oldCursorWsKey) {
        for (var j = 0; j < rows.length; j++) {
          if (rows[j].kind === "workspace" && (rows[j].monitor + ":" + rows[j].workspace.number) === oldCursorWsKey) {
            cursor = j
            foundOld = true
            break
          }
        }
      }
      if (!foundOld) {
        cursor = Tree.initialCursor(rows, root.model)
      }
    } else {
      var preserved = false
      if (oldCursorAddress) {
        for (var k = 0; k < rows.length; k++) {
          if (rows[k].window && rows[k].window.address === oldCursorAddress && rows[k].matched) {
            cursor = k
            preserved = true
            break
          }
        }
      }
      if (!preserved) {
        cursor = Tree.firstSelectable(state)
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

  function move(delta) {
    if (!root.treeState) return
    Tree.move(root.treeState, delta)
    root.treeStateChanged()
  }

  function nextMatch() {
    if (!root.treeState) return
    Tree.nextMatch(root.treeState)
    root.setCursor(root.treeState.cursor)
    root.treeStateChanged()
  }

  function prevMatch() {
    if (!root.treeState) return
    Tree.prevMatch(root.treeState)
    root.setCursor(root.treeState.cursor)
    root.treeStateChanged()
  }

  function isWorkspaceFolded(monitor, ws) {
    if (!root.folded || !ws) return false
    var k1 = monitor + ":" + ws.number
    var k2 = monitor + ":" + ws.id + ":" + ws.number
    return root.folded[k1] === true || root.folded[k2] === true
  }

  function foldWorkspace(monitor, ws) {
    if (!ws) return
    var k1 = monitor + ":" + ws.number
    var k2 = monitor + ":" + ws.id + ":" + ws.number
    if (root.folded && (root.folded[k1] === true || root.folded[k2] === true)) {
      // Already folded: NO-OP per M1
      return
    }
    var nextFolds = Object.assign({}, root.folded)
    nextFolds[k1] = true
    nextFolds[k2] = true
    root.folded = nextFolds

    root.rebuildTree()
    root.moveToWorkspaceHeader(monitor, ws.number)
  }

  function unfoldWorkspace(monitor, ws) {
    if (!ws) return
    var k1 = monitor + ":" + ws.number
    var k2 = monitor + ":" + ws.id + ":" + ws.number
    var nextFolds = Object.assign({}, root.folded)
    delete nextFolds[k1]
    delete nextFolds[k2]
    root.folded = nextFolds

    root.rebuildTree()
  }

  function toggleFoldWorkspace(monitor, ws) {
    if (!ws) return
    if (root.isWorkspaceFolded(monitor, ws)) {
      root.unfoldWorkspace(monitor, ws)
    } else {
      root.foldWorkspace(monitor, ws)
    }
  }

  function moveToWorkspaceHeader(monitor, wsNumber) {
    if (!root.treeState || !root.treeState.rows) return
    var rows = root.treeState.rows
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].kind === "workspace"
          && rows[i].monitor === monitor
          && rows[i].workspace.number === wsNumber) {
        root.setCursor(i)
        return
      }
    }
  }

  function handleKeyH() {
    var row = root.currentRow()
    if (!row || !row.workspace) return
    root.foldWorkspace(row.monitor, row.workspace)
  }

  function handleKeyL() {
    var row = root.currentRow()
    if (!row || !row.workspace) return
    if (root.isWorkspaceFolded(row.monitor, row.workspace)) {
      root.unfoldWorkspace(row.monitor, row.workspace)
    } else if (row.kind === "workspace") {
      var rows = root.treeState.rows
      for (var i = root.treeState.cursor + 1; i < rows.length; i++) {
        if (rows[i].kind === "window"
            && rows[i].monitor === row.monitor
            && rows[i].workspace.number === row.workspace.number) {
          root.setCursor(i)
          return
        }
      }
    }
  }

  // Digit handling per brief §6 & C3 fix:
  // Moves the cursor to that workspace header on cursor's monitor.
  // If empty: flashes that row and stays put. Does NOT dispatch workspace switch!
  function moveToDigit(digit) {
    var row = root.currentRow()
    var monitor = row ? row.monitor : (root.model ? root.model.focusedMonitor : "")
    if (!monitor || !root.model || !root.treeState) return
    var num = digit === "0" ? 10 : Number(digit)

    // Check if workspace has windows
    var targetWs = null
    for (var mi = 0; mi < root.model.roots.length; mi++) {
      var rootData = root.model.roots[mi]
      if (rootData.monitor === monitor) {
        targetWs = rootData.workspaces[num - 1]
        break
      }
    }

    if (!targetWs || !targetWs.windows || targetWs.windows.length === 0) {
      // Empty: flash row and stay put
      root.flashWorkspace(monitor, num)
      return
    }

    // Move cursor to that workspace header
    var res = Tree.moveToWorkspace(root.treeState, monitor, num)
    if (res >= 0) {
      root.setCursor(res)
    }
  }

  Timer {
    id: flashTimer
    interval: 180
    repeat: false
    onTriggered: root.flashedWorkspaceKey = ""
  }
  function flashWorkspace(monitor, number) {
    root.flashedWorkspaceKey = monitor + ":" + number
    flashTimer.restart()
  }

  function focusCurrent() {
    var row = root.currentRow()
    if (!row) return
    var ws = row.workspace
    var win = row.window
    if (win) {
      root.focusAddress(win.address)
    } else if (ws && ws.windows && ws.windows.length > 0) {
      var sorted = ws.windows.slice().sort(function (a, b) {
        return a.focusHistoryID - b.focusHistoryID
      })
      root.focusAddress(sorted[0].address)
    }
  }

  function focusAddress(address) {
    var row = root.currentRow()
    var monitor = row ? row.monitor : ""
    var wsId = row && row.workspace ? row.workspace.id : 0
    if (row && row.window) wsId = row.window.workspaceId
    var sequence = Model.focusSequence(address, monitor, wsId)
    if (!sequence.length) return

    root.pendingAddress = String(address)
    root.pendingMonitor = monitor
    root.pendingWorkspaceId = wsId
    root.pendingFallbackSent = false

    dispatchProc.command = sequence[0].command
    dispatchProc.running = true

    // Exit and hide overlay automatically when dispatch happens
    root.close()
  }

  function focusFailed() {
    var row = root.currentRow()
    if (row && row.workspace) {
      root.flashWorkspace(row.monitor, row.workspace.number)
    }
    root.pendingAddress = ""
    root.reload()
  }

  Timer {
    id: verifyFocusTimer
    interval: 70
    repeat: false
    onTriggered: verifyProc.running = true
  }

  function enterSearch() {
    if (!root.treeState) return
    root.searchMode = true
    root.gPending = false
    if (root.searchText.length === 0) {
      root.treeState.recordedCursor = root.treeState.cursor
    }
    Qt.callLater(function () { searchBar.forceFocus() })
  }

  function submitSearch() {
    root.searchMode = false
    Qt.callLater(function () { keyCatcher.forceActiveFocus() })
  }

  // Esc in search restores recorded cursor per brief §6 & H2 fix
  function exitSearch() {
    root.searchMode = false
    root.searchText = ""
    searchBar.searchText = ""
    if (root.treeState) {
      var restored = root.treeState.recordedCursor
      root.rebuildTree()
      if (root.treeState) root.setCursor(restored)
    }
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
    function onRawEvent(event) {
      if (root.opened) refreshTimer.restart()
    }
  }

  // Snapshot processes
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
      if (exitCode === 0) activeWindowProc.running = true
      else root.finishSnapshot()
    }
  }
  Process {
    id: activeWindowProc
    command: ["hyprctl", "activewindow", "-j"]
    stdout: StdioCollector { id: activeWindowOut; waitForEnd: true }
    onExited: function (exitCode, exitStatus) {
      root.activeWindowJson = (exitCode === 0) ? activeWindowOut.text : ""
      root.finishSnapshot()
    }
  }

  // Focus dispatch processes
  Process {
    id: dispatchProc
    command: ["true"]
    onExited: verifyFocusTimer.restart()
  }
  Process {
    id: verifyProc
    command: ["hyprctl", "activewindow", "-j"]
    stdout: StdioCollector { id: verifyOut; waitForEnd: true }
    onExited: function (exitCode, exitStatus) {
      if (exitCode !== 0 || !root.pendingAddress) {
        root.focusFailed()
        return
      }
      try {
        var active = JSON.parse(verifyOut.text)
        if (active && active.address === root.pendingAddress) {
          root.pendingAddress = ""
          root.close()
          return
        }
      } catch (err) {}

      // Fallback
      if (!root.pendingFallbackSent) {
        root.pendingFallbackSent = true
        var seq = Model.focusSequence(root.pendingAddress, root.pendingMonitor, root.pendingWorkspaceId)
        fallbackProc.command = seq[seq.length - 1].command
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

  // Overlay surface
  PanelWindow {
    id: panel
    visible: root.opened
    onVisibleChanged: {
      if (panel.visible && !root.searchMode) {
        Qt.callLater(function () { keyCatcher.forceActiveFocus() })
      }
    }
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-tree"
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Scrim dimming backdrop
    Rectangle {
      anchors.fill: parent
      color: root.highContrast ? "transparent" : Qt.rgba(9 / 255, 10 / 255, 16 / 255, 0.55)
      MouseArea {
        anchors.fill: parent
        onClicked: root.close()
      }
    }

    // Centered glass panel matching mockup: 1120px wide
    Rectangle {
      id: glassPanel
      anchors.centerIn: parent
      width: Math.min(1120, parent.width - 48)
      height: Math.min(parent.height * 0.82, 780)
      radius: 24

      color: root.highContrast
        ? Color.background
        : Qt.rgba(Color.background.r * 0.9 + 0.05, Color.background.g * 0.9 + 0.05, Color.background.b * 0.9 + 0.08, 0.86)

      border.width: 1
      border.color: root.highContrast
        ? Color.foreground
        : Qt.rgba(255, 255, 255, 0.08)

      opacity: root.opened ? 1 : 0
      scale: root.reducedMotion ? 1 : (root.opened ? 1 : 0.96)
      Behavior on opacity {
        enabled: !root.reducedMotion
        NumberAnimation {
          duration: Style.duration(root.opened ? 180 : 90)
          easing.type: root.opened ? Easing.OutCubic : Easing.OutQuad
        }
      }
      Behavior on scale {
        enabled: !root.reducedMotion
        NumberAnimation {
          duration: Style.duration(root.opened ? 180 : 90)
          easing.type: Easing.OutCubic
        }
      }

      Column {
        anchors.fill: parent
        anchors.topMargin: 28
        anchors.leftMargin: 32
        anchors.rightMargin: 32
        anchors.bottomMargin: 20
        spacing: 16

        // Always-visible Search Bar capsule
        SearchBar {
          id: searchBar
          searchMode: root.searchMode
          searchText: root.searchText
          accentColor: Color.accent
          matchCount: {
            if (!root.treeState || !root.treeState.rows) return 0
            return root.treeState.rows.filter(function(r) { return r.kind === "window" && r.matched }).length
          }

          onSearchActivated: root.enterSearch()
          onSearchEscaped: root.exitSearch()
          onSearchSubmitted: root.submitSearch()
          onNextMatchRequested: root.nextMatch()
          onPrevMatchRequested: root.prevMatch()
          onSearchTextChanged: {
            root.searchText = searchBar.searchText
            root.rebuildTree()
          }
        }

        // Columns area: Side-by-side separate monitor window panes
        Item {
          id: columnsArea
          width: parent.width
          height: parent.height - searchBar.height - footer.height - 32
          clip: true

          Row {
            id: columnsRow
            anchors.fill: parent
            spacing: 20

            Repeater {
              model: root.model ? root.model.roots : []

              MonitorColumn {
                required property var modelData
                required property int index

                width: {
                  var count = root.model ? root.model.roots.length : 1
                  if (count <= 1) return columnsArea.width
                  var gap = columnsRow.spacing * (count - 1)
                  return Math.floor((columnsArea.width - gap) / count)
                }
                height: columnsArea.height

                rootData: modelData
                monitorIndex: index
                cursorRow: root.currentRow()
                folds: root.folded
                flashedKey: root.flashedWorkspaceKey
                isSearching: root.searchText.length > 0
                searchQuery: root.searchText.toLowerCase()

                onWorkspaceClicked: function(ws) {
                  root.toggleFoldWorkspace(modelData.monitor, ws)
                }
                onWindowClicked: function(addr) {
                  root.focusAddress(addr)
                }
              }
            }
          }
        }

        // Footer with keycaps and window/monitor summary
        Footer {
          id: footer
          totalWindows: root.model ? root.model.totalWindows : 0
          totalMonitors: root.model ? root.model.roots.length : 0
          matchedWindows: {
            if (!root.treeState || !root.treeState.rows) return 0
            return root.treeState.rows.filter(function(r) { return r.kind === "window" && r.matched }).length
          }
          isSearching: root.searchText.length > 0
        }
      }

      // Invisible keycatcher for tree navigation mode
      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.priority: Keys.BeforeItem

        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            if (root.searchMode || root.searchText.length > 0) {
              root.exitSearch()
            } else {
              root.close()
            }
            event.accepted = true
            return
          }

          if (event.text === "q") {
            root.close()
            event.accepted = true
            return
          }

          if (root.searchMode) return

          if (event.text === "n") {
            if (root.searchText.length > 0) {
              root.nextMatch()
            }
            event.accepted = true
          } else if (event.text === "N") {
            if (root.searchText.length > 0) {
              root.prevMatch()
            }
            event.accepted = true
          } else if (event.text === "j" || event.key === Qt.Key_Down) {
            root.move(1)
            event.accepted = true
          } else if (event.text === "k" || event.key === Qt.Key_Up) {
            root.move(-1)
            event.accepted = true
          } else if (event.text === "h" || event.key === Qt.Key_Left) {
            root.handleKeyH()
            event.accepted = true
          } else if (event.text === "l" || event.key === Qt.Key_Right) {
            root.handleKeyL()
            event.accepted = true
          } else if (event.text === "/") {
            root.enterSearch()
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.focusCurrent()
            event.accepted = true
          } else if (event.text >= "0" && event.text <= "9") {
            root.moveToDigit(event.text)
            event.accepted = true
          } else if (event.modifiers & Qt.ControlModifier) {
            if (event.key === Qt.Key_H || event.key === Qt.Key_Left || event.text === "\u0008") {
              if (root.treeState) {
                Tree.prevMonitor(root.treeState)
                root.treeStateChanged()
              }
              event.accepted = true
            } else if (event.key === Qt.Key_L || event.key === Qt.Key_Right || event.text === "\u000c") {
              if (root.treeState) {
                Tree.nextMonitor(root.treeState)
                root.treeStateChanged()
              }
              event.accepted = true
            } else if (event.key === Qt.Key_U) {
              root.move(-5)
              event.accepted = true
            } else if (event.key === Qt.Key_D) {
              root.move(5)
              event.accepted = true
            }
          } else if (event.text === "g") {
            if (root.gPending) {
              if (root.treeState) root.setCursor(Tree.firstSelectable(root.treeState))
              root.gPending = false
            } else {
              root.gPending = true
              gTimer.restart()
            }
            event.accepted = true
          } else if (event.text === "G") {
            if (root.treeState) root.setCursor(Tree.lastSelectable(root.treeState))
            event.accepted = true
          } else if (event.key === Qt.Key_Backtab) {
            if (root.treeState) {
              Tree.prevMonitor(root.treeState)
              root.treeStateChanged()
            }
            event.accepted = true
          } else if (event.key === Qt.Key_Tab) {
            if (root.treeState) {
              Tree.nextMonitor(root.treeState)
              root.treeStateChanged()
            }
            event.accepted = true
          }
        }
      }
    }
  }
}
