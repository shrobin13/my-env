pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.UPower
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "CalendarModel.js" as Model

Item {
  id: root

  // Omarchy host properties injected by shell.qml
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null
  property var barWidgetRegistry: null
  property var pluginRegistry: null
  property var barConfig: ({})
  property bool barHidden: false

  readonly property string home: Quickshell.env("HOME")
  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")

  // Layout config exposed to child widgets (e.g. omarchy.tray reads layoutConfig.tray)
  readonly property var fallbackLayout: ({
    left: [{ id: "omarchy.menu" }, { id: "omarchy.workspaces" }],
    centerBegin: [{ id: "omarchy.indicators" }],
    center: [{ id: "omarchy.clock" }],
    centerEnd: [{ id: "omarchy.elsewhen" }, { id: "omarchy.weather" }, { id: "omarchy.system-update" }],
    right: [
      { id: "omarchy.tray" },
      { id: "omarchy.keyboard-layout" },
      { id: "omarchy.agents" },
      { id: "omarchy.bluetooth" },
      { id: "omarchy.network" },
      { id: "omarchy.audio" },
      { id: "omarchy.monitor" },
      { id: "omarchy.power" },
      { id: "user.notification-center" }
    ],
    tray: []
  })
  readonly property var layoutConfig: (barConfig && Util.isPlainObject(barConfig.layout))
    ? barConfig.layout
    : fallbackLayout

  // Bar geometry (thinner 30px pills inset 5px from top)
  readonly property bool vertical: false
  readonly property int barSize: 30
  readonly property real groupHeight: 30
  readonly property real groupRadius: 2
  readonly property real groupTopMargin: 5
  readonly property real panelAnchorBottom: groupTopMargin + groupHeight

  function barSizeFor(screenName) {
    return panelAnchorBottom
  }

  // Theme colors bound to Commons.Color with dark-green fallbacks
  readonly property color themeBg: Commons.Color.background ? Commons.Color.background : "#0b1a14"
  readonly property color themeFg: Commons.Color.foreground ? Commons.Color.foreground : "#e6f4ec"
  readonly property color themeMuted: Commons.Color.muted ? Commons.Color.muted : "#7f9a8c"
  readonly property color themeAccent: (settings && settings.accentOverride)
    ? settings.accentOverride
    : (Commons.Color.accent ? Commons.Color.accent : "#8fe3b8")

  readonly property color colorBarBg: Qt.rgba(themeBg.r, themeBg.g, themeBg.b, 0.88)
  readonly property color colorBorderNormal: Qt.rgba(themeAccent.r, themeAccent.g, themeAccent.b, 0.28)
  readonly property color colorBorderAccent: (settings && settings.accentOverride)
    ? settings.accentOverride
    : (Commons.Color.popups && Commons.Color.popups.border ? Commons.Color.popups.border : Qt.rgba(themeAccent.r, themeAccent.g, themeAccent.b, 0.72))
  readonly property color colorPrimaryText: themeFg
  readonly property color colorSecondaryText: Qt.rgba(themeFg.r, themeFg.g, themeFg.b, 0.68)
  readonly property color colorDimText: themeMuted
  readonly property color colorAccentMint: themeAccent
  readonly property color colorTextOnAccent: themeBg
  readonly property color colorEventDot: "#f2b45a"
  readonly property color colorSurface: Qt.lighter(themeBg, 1.3)
  readonly property color colorSurfaceHover: Qt.lighter(themeBg, 1.7)
  readonly property color colorButtonBorder: Qt.rgba(themeAccent.r, themeAccent.g, themeAccent.b, 0.36)

  // Host properties expected by child BarWidget / Panel / KeyboardPanel components
  property var activePopout: null
  property var popoutCard: null
  property var clickTargets: []
  property color foreground: colorPrimaryText
  property color background: colorBarBg
  property color barForeground: colorPrimaryText
  property color urgent: Commons.Color.bar && Commons.Color.bar.active ? Commons.Color.bar.active : "#a55555"
  property string fontFamily: Style.font.family || "JetBrains Mono, monospace"
  property string position: "top"
  property bool transparent: false
  property bool foregroundAnimationEnabled: true

  // Hover reveal for center indicators
  property int barHoverCount: 0
  readonly property bool barHovered: barHoverCount > 0
  property bool centerSectionRevealHeld: false
  property bool centerHoverRevealSuppressed: false

  function setCenterHoverRevealSuppressed(value) {
    centerHoverRevealSuppressed = !!value
  }

  function setBarHovered(hovered) {
    if (hovered) {
      barHoverCount += 1
      centerRevealHideTimer.stop()
      centerSectionRevealHeld = true
    } else {
      barHoverCount = Math.max(0, barHoverCount - 1)
      if (barHoverCount === 0) centerRevealHideTimer.restart()
    }
  }

  Timer {
    id: centerRevealHideTimer
    interval: 120
    onTriggered: if (!root.barHovered) root.centerSectionRevealHeld = false
  }

  // Tray drag / popout state
  readonly property bool traySectionDragActive: false
  readonly property bool traySectionPopoutOpen: {
    if (!activePopout) return false
    for (var i = 0; i < mountedSlots.length; i++) {
      var rec = mountedSlots[i]
      if (rec && rec.item === activePopout) return rec.region === "tray"
    }
    return false
  }

  // Multi-monitor slot registry
  property var mountedSlots: []

  function registerSlot(widgetId, region, window, item) {
    if (!widgetId || !item) return
    var next = mountedSlots.filter(function(r) { return r && r.item !== item })
    next.push({ widgetId: widgetId, region: region || "", window: window || null, item: item })
    mountedSlots = next
  }

  function unregisterSlot(item) {
    if (!item) return
    mountedSlots = mountedSlots.filter(function(r) { return r && r.item !== item })
  }

  function focusedScreenName() {
    return Hyprland.focusedMonitor ? String(Hyprland.focusedMonitor.name || "") : ""
  }

  function findPanelWidget(id) {
    if (id === "user.calendar-panel") return calendarPanel
    var focused = focusedScreenName()
    var fallback = null
    for (var i = 0; i < mountedSlots.length; i++) {
      var rec = mountedSlots[i]
      if (!rec || rec.widgetId !== id || !rec.item) continue
      var item = rec.item
      if (typeof item.open !== "function" || typeof item.close !== "function") continue
      var scrName = rec.window && rec.window.screen ? String(rec.window.screen.name || "") : ""
      if (focused && scrName === focused) return item
      if (!fallback) fallback = item
    }
    return fallback
  }

  function summonBarWidget(pluginId) {
    var item = findPanelWidget(pluginId)
    if (!item || typeof item.open !== "function") return false
    item.open()
    return true
  }

  function hideBarWidget(pluginId) {
    var item = findPanelWidget(pluginId)
    if (!item || typeof item.close !== "function") return false
    item.close()
    return true
  }

  function isBarWidgetOpen(pluginId) {
    var item = findPanelWidget(pluginId)
    if (!item) return false
    return item.opened === true
  }

  function moduleWidgets(name) {
    var out = []
    for (var i = 0; i < mountedSlots.length; i++) {
      var rec = mountedSlots[i]
      if (rec && rec.widgetId === name && rec.item) out.push(rec.item)
    }
    return out
  }

  // Popout coordinator & card morphing
  function popoutSectionOf(owner) {
    if (owner === calendarPanel) return "center"
    for (var i = 0; i < mountedSlots.length; i++) {
      var rec = mountedSlots[i]
      if (rec && rec.item === owner) {
        if (rec.region === "centerBegin" || rec.region === "center" || rec.region === "centerEnd") return "center"
        return rec.region
      }
    }
    return ""
  }

  function requestPopout(owner) {
    if (activePopout === owner) return
    if (activePopout) {
      if ("closeForPopoutSwitch" in activePopout) activePopout.closeForPopoutSwitch()
      else if ("close" in activePopout) activePopout.close()
    }
    activePopout = owner
  }

  function releasePopout(owner) {
    if (activePopout === owner) activePopout = null
  }

  function notePopoutCard(card) {
    popoutCard = card ? {
      screen: String(card.screen || ""),
      section: popoutSectionOf(activePopout),
      x: Number(card.x) || 0,
      y: Number(card.y) || 0,
      width: Number(card.width) || 0,
      height: Number(card.height) || 0
    } : null
  }

  function popoutCardFor(owner) {
    var card = popoutCard
    if (!card || !card.section || card.section !== popoutSectionOf(owner)) return null
    return { screen: card.screen, x: card.x, y: card.y, width: card.width, height: card.height }
  }

  function switchPanelFrom(owner, direction) {
    if (!owner) return false
    var current = null
    for (var i = 0; i < mountedSlots.length; i++) {
      if (mountedSlots[i].item === owner) { current = mountedSlots[i]; break }
    }
    if (!current) return false

    var section = popoutSectionOf(owner)
    var candidates = []
    for (var j = 0; j < mountedSlots.length; j++) {
      var rec = mountedSlots[j]
      if (!rec || !rec.item || rec.window !== current.window) continue
      if (popoutSectionOf(rec.item) !== section) continue
      if (typeof rec.item.open !== "function" || typeof rec.item.close !== "function" || rec.item.opened === undefined) continue
      if (rec.item.visible === false) continue
      candidates.push(rec.item)
    }
    if (candidates.length < 2) return false
    var idx = candidates.indexOf(owner)
    if (idx < 0) return false
    var step = direction < 0 ? -1 : 1
    var nextItem = candidates[(idx + step + candidates.length) % candidates.length]
    if (!nextItem || nextItem === owner) return false
    nextItem.open()
    return true
  }

  // Click target hit-testing for KeyboardPanel click-through between bar buttons
  function registerClickTarget(target) {
    if (!target || clickTargets.indexOf(target) !== -1) return
    var next = clickTargets.slice()
    next.push(target)
    clickTargets = next
  }

  function unregisterClickTarget(target) {
    clickTargets = clickTargets.filter(function(item) { return item !== target })
  }

  function targetWindow(target) {
    return target && target.QsWindow ? target.QsWindow.window : null
  }

  function targetBelongsToWindow(target, window) {
    return !!target && !!window && targetWindow(target) === window
  }

  // Tooltip state & helpers
  property var tooltipTarget: null
  property var pendingTooltipTarget: null
  property string tooltipText: ""
  property string pendingTooltipText: ""
  property bool tooltipShown: false
  property int tooltipRequest: 0

  function targetTooltipHovered(target) {
    return !!target && target.visible !== false && target.opacity !== 0 && target.tooltipHovered === true
  }

  function clearTooltip() {
    tooltipTimer.stop()
    if (tooltipShown) tooltipWarmTimer.restart()
    pendingTooltipTarget = null
    pendingTooltipText = ""
    tooltipTarget = null
    tooltipText = ""
    tooltipShown = false
  }

  function showTooltip(target, text) {
    var warm = tooltipShown || tooltipWarmTimer.running
    clearTooltip()
    if (!targetTooltipHovered(target) || !text) {
      tooltipRequest += 1
      return
    }
    var request = tooltipRequest + 1
    tooltipRequest = request
    pendingTooltipTarget = target
    pendingTooltipText = text

    Qt.callLater(function() {
      if (request !== tooltipRequest) return
      if (!targetTooltipHovered(pendingTooltipTarget)) {
        clearTooltip()
        return
      }
      tooltipTarget = pendingTooltipTarget
      tooltipText = pendingTooltipText
      pendingTooltipTarget = null
      pendingTooltipText = ""
      if (warm) tooltipShown = true
      else tooltipTimer.restart()
    })
  }

  function hideTooltip(target) {
    if (tooltipTarget !== target && pendingTooltipTarget !== target) return
    tooltipRequest += 1
    clearTooltip()
  }

  Timer {
    id: tooltipTimer
    interval: 400
    onTriggered: {
      if (root.targetTooltipHovered(root.tooltipTarget)) root.tooltipShown = true
      else root.clearTooltip()
    }
  }

  Timer {
    id: tooltipWarmTimer
    interval: 400
  }

  Timer {
    interval: 100
    running: root.tooltipShown
    repeat: true
    onTriggered: if (!root.targetTooltipHovered(root.tooltipTarget)) root.hideTooltip(root.tooltipTarget)
  }

  function run(command) {
    if (!command) return
    Util.execDetached(command)
  }

  function settingsFor(widgetId) {
    var sections = ["left", "centerBegin", "center", "centerEnd", "right", "tray"]
    for (var s = 0; s < sections.length; s++) {
      var arr = layoutConfig[sections[s]]
      if (Array.isArray(arr)) {
        for (var i = 0; i < arr.length; i++) {
          if (arr[i] && arr[i].id === widgetId) return arr[i]
        }
      }
    }
    return ({})
  }

  // Respect `omarchy toggle bar` (`bar-off` state flag)
  Process {
    id: barHiddenProbe
    running: true
    command: ["bash", "-c", "[[ -f $HOME/.local/state/omarchy/toggles/bar-off ]] && echo yes || echo no"]
    stdout: SplitParser { onRead: function(line) { root.barHidden = String(line).trim() === "yes" } }
  }

  FileView {
    path: root.stateHome + "/omarchy/toggles"
    watchChanges: true
    printErrors: false
    onFileChanged: barHiddenProbe.running = true
  }

  // Settings for user.calendar-panel
  property var settings: ({
    weekStartDay: "sunday",
    clock24h: false,
    icsPath: "",
    accentOverride: ""
  })

  FileView {
    id: settingsWatcher
    path: root.home + "/.config/omarchy/plugins/user.calendar-panel/settings.json"
    watchChanges: true
    printErrors: false
    onLoaded: {
      try {
        root.settings = JSON.parse(text())
      } catch (e) {}
    }
  }

  // Multi-monitor workspace block mapping (mirrors stock omarchy.workspaces)
  property var workspaceBlocks: ({})
  function readWorkspaceBlocks(text) {
    var next = {}
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var fields = lines[i].split("\t")
      if (fields.length >= 3 && fields[1] !== "") next[fields[1]] = parseInt(fields[0], 10)
    }
    root.workspaceBlocks = next
  }

  FileView {
    path: root.stateHome + "/omarchy/monitor-workspaces"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.readWorkspaceBlocks(text())
    onLoadFailed: root.readWorkspaceBlocks("")
  }

  // Refresh Hyprland workspaces/monitors/toplevels on events
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var name = event ? String(event.name) : ""
      if (name === "fullscreen") Hyprland.refreshToplevels()
      if (name === "workspacev2" || name === "moveworkspacev2" || name === "changeworkspaceid" || name === "configreloaded") {
        Hyprland.refreshMonitors()
        Hyprland.refreshWorkspaces()
      }
    }
  }

  // Timer state
  property int timerSeconds: 0
  property bool timerRunning: false

  Timer {
    id: countdownTimer
    interval: 1000
    repeat: true
    running: root.timerRunning
    onTriggered: {
      if (root.timerSeconds > 0) {
        root.timerSeconds--
      } else {
        root.timerRunning = false
        timerDoneProcess.running = true
      }
    }
  }

  Process {
    id: timerDoneProcess
    command: ["notify-send", "-a", "Omarchy Timer", "Timer Completed!", "Your countdown timer has ended."]
  }

  function startTimer(seconds) {
    if (seconds <= 0) {
      root.timerRunning = false
      root.timerSeconds = 0
    } else {
      root.timerSeconds = seconds
      root.timerRunning = true
    }
  }

  // DND state
  property bool dndActive: false

  FileView {
    id: quietFile
    path: root.stateHome + "/omarchy/notifications/quiet.json"
    watchChanges: true
    printErrors: false
    onLoaded: {
      try {
        var raw = text()
        root.dndActive = (raw && raw.trim()) ? !!JSON.parse(raw).dnd : false
      } catch (e) {
        root.dndActive = false
      }
    }
  }

  function toggleDnd() {
    var manageScript = root.home + "/.config/omarchy/plugins/user.notification-center/manage.py"
    dndProcess.command = ["python3", manageScript, "toggle-dnd"]
    dndProcess.running = true
    root.dndActive = !root.dndActive
  }

  Process {
    id: dndProcess
    command: ["true"]
  }

  // Clock
  property date currentDate: new Date()
  Timer {
    interval: 1000
    repeat: true
    running: true
    onTriggered: root.currentDate = new Date()
  }

  // Calendar Panel popup
  CalendarPanel {
    id: calendarPanel
    bar: root
    settings: root.settings
    timerSeconds: root.timerSeconds
    timerRunning: root.timerRunning
    dndActive: root.dndActive

    onStartTimerRequested: function(secs) { root.startTimer(secs) }
    onToggleDndRequested: function() { root.toggleDnd() }
  }

  function toggleCalendar(screenObj) {
    calendarPanel.toggle(screenObj || null)
  }

  function openCalendar(screenObj) {
    calendarPanel.open(screenObj || null)
  }

  function closeCalendar() {
    calendarPanel.close()
  }

  // Shell IPC
  ShellIpc {
    target: "user.calendar-panel"

    function toggle(): void { root.toggleCalendar(null) }
    function open(): void { root.openCalendar(null) }
    function close(): void { root.closeCalendar() }
    function startTimer(seconds: int): void { root.startTimer(seconds) }
    function toggleDnd(): void { root.toggleDnd() }
  }

  // Leaf slot for widgets inside omarchy.tray's drawer (separate from WidgetSlot to avoid QML inline component cycles)
  component TrayChildSlot: Item {
    id: trayChild

    required property string widgetId
    required property var hostWindow
    property var customSettings: root.settingsFor(widgetId)

    readonly property int registryRev: root.barWidgetRegistry ? root.barWidgetRegistry.revision : 0
    readonly property var regComponent: {
      var rev = registryRev
      if (!root.barWidgetRegistry || !root.barWidgetRegistry.widgets) return null
      var entry = root.barWidgetRegistry.widgets[widgetId]
      return entry ? entry.component : null
    }
    readonly property Item activeItem: childLoader.item
    readonly property bool itemOwnVisible: activeItem ? activeItem.visible : false

    visible: activeItem !== null
    implicitWidth: itemOwnVisible ? activeItem.implicitWidth : 0
    implicitHeight: itemOwnVisible ? activeItem.implicitHeight : root.groupHeight

    Loader {
      id: childLoader
      active: trayChild.regComponent !== null
      sourceComponent: trayChild.regComponent
      width: item && item.visible ? item.implicitWidth : 0
      height: item && item.visible ? item.implicitHeight : 0

      onLoaded: {
        if (!item) return
        if ("fixedEdge" in item) item.fixedEdge = "end"
        if ("bar" in item) item.bar = root
        if ("moduleName" in item) item.moduleName = trayChild.widgetId
        if ("settings" in item) item.settings = trayChild.customSettings
        root.registerSlot(trayChild.widgetId, "tray", trayChild.hostWindow, item)
      }
      Component.onDestruction: {
        if (item) root.unregisterSlot(item)
      }
    }
  }

  // Generic Widget Slot Loader Component (also mounts tray section widgets inside omarchy.tray.sectionHost)
  component WidgetSlot: Item {
    id: slot

    required property string widgetId
    required property string region
    required property var hostWindow
    property var customSettings: root.settingsFor(widgetId)
    property bool visualHidden: false

    readonly property int registryRev: root.barWidgetRegistry ? root.barWidgetRegistry.revision : 0
    readonly property var regComponent: {
      var rev = registryRev
      if (!root.barWidgetRegistry || !root.barWidgetRegistry.widgets) return null
      var entry = root.barWidgetRegistry.widgets[widgetId]
      return entry ? entry.component : null
    }
    readonly property Item activeItem: slotLoader.item
    readonly property bool itemOwnVisible: activeItem ? activeItem.visible : false

    visible: activeItem !== null
    implicitWidth: visualHidden ? 0 : (itemOwnVisible ? activeItem.implicitWidth : 0)
    implicitHeight: itemOwnVisible ? activeItem.implicitHeight : root.groupHeight

    Loader {
      id: slotLoader
      anchors.fill: slot.visualHidden ? parent : undefined
      width: !slot.visualHidden && item && item.visible ? item.implicitWidth : (slot.visualHidden ? parent.width : 0)
      height: !slot.visualHidden && item && item.visible ? item.implicitHeight : (slot.visualHidden ? parent.height : 0)
      active: slot.regComponent !== null
      sourceComponent: slot.regComponent
      opacity: slot.visualHidden ? 0 : 1

      onLoaded: {
        if (!item) return
        if ("fixedEdge" in item) item.fixedEdge = slot.region === "left" ? "start" : (slot.region === "right" ? "end" : "center")
        if ("bar" in item) item.bar = root
        if ("moduleName" in item) item.moduleName = slot.widgetId
        if ("settings" in item) item.settings = slot.customSettings
        root.registerSlot(slot.widgetId, slot.region, slot.hostWindow, item)
      }
      Component.onDestruction: {
        if (item) root.unregisterSlot(item)
      }
    }

    // Mount tray section plugins (e.g. superwhisper.panel) into omarchy.tray's sectionHost
    Loader {
      id: traySectionLoader
      readonly property Item trayHost: (slot.widgetId === "omarchy.tray" && slot.activeItem && "sectionHost" in slot.activeItem)
        ? slot.activeItem.sectionHost : null
      parent: trayHost || slot
      active: !!trayHost
      sourceComponent: Component {
        Row {
          spacing: 2
          Repeater {
            model: Array.isArray(root.layoutConfig.tray) ? root.layoutConfig.tray : []
            delegate: TrayChildSlot {
              required property var modelData
              widgetId: (typeof modelData === "string") ? modelData : String(modelData.id || "")
              hostWindow: slot.hostWindow
              customSettings: (typeof modelData === "object" && modelData) ? modelData : ({})
            }
          }
        }
      }
    }
  }

  // Top Bar Panels per Monitor Screen
  Variants {
    model: Quickshell.screens

    delegate: Component {
      PanelWindow {
        id: barWindow
        required property var modelData

        screen: modelData
        anchors {
          top: true
          left: true
          right: true
        }
        margins.top: root.barHidden ? -implicitHeight : 0
        implicitHeight: 42
        color: "transparent"
        exclusionMode: root.barHidden ? ExclusionMode.Ignore : ExclusionMode.Normal
        exclusiveZone: root.barHidden ? 0 : 36
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "omarchy-bar"

        // Monitor & Workspace calculations (matching stock omarchy.workspaces)
        readonly property var monitor: Hyprland.monitorFor(modelData)
        readonly property string monitorName: monitor ? String(monitor.name || "") : ""
        readonly property int wsSlots: 10
        readonly property int activeWsId: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : 1
        readonly property int wsBlock: {
          var b = root.workspaceBlocks[monitorName]
          if (b !== undefined) return b
          return activeWsId > 0 ? Math.floor((activeWsId - 1) / wsSlots) : 0
        }

        function blockOf(id) { return Math.floor((id - 1) / wsSlots) }
        function slotOf(id) { return (id - 1) % wsSlots + 1 }

        function workspaceById(id) {
          var values = Hyprland.workspaces.values
          for (var i = 0; i < values.length; i++) {
            if (values[i].id === id) return values[i]
          }
          return null
        }

        function workspaceIds() {
          var base = wsBlock * wsSlots
          var ids = [base + 1, base + 2, base + 3, base + 4, base + 5]
          var guests = []
          var values = Hyprland.workspaces.values
          for (var i = 0; i < values.length; i++) {
            var id = values[i].id
            if (id <= 0) continue
            if (blockOf(id) === wsBlock) {
              if (ids.indexOf(id) === -1) ids.push(id)
            } else if (values[i].monitor && values[i].monitor.name === monitorName) {
              guests.push(id)
            }
          }
          ids.sort(function(a, b) { return a - b })
          guests.sort(function(a, b) { return a - b })
          return ids.concat(guests)
        }

        function focusWorkspace(id) {
          if (blockOf(id) === wsBlock) {
            root.run("hyprctl dispatch " + Util.shellQuote("o.workspaces.focus(" + slotOf(id) + ", \"" + monitorName + "\")"))
          } else {
            root.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
          }
        }

        function cycleWorkspaceLayout() {
          var cmd = "omarchy-hyprland-workspace-layout-toggle"
          if (monitor && !monitor.focused && monitorName) {
            cmd = "hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ monitor = \"" + monitorName + "\" })") + " >/dev/null && " + cmd
          }
          root.run(cmd)
        }

        property real wsWheelAccum: 0
        function scrollWorkspaces(delta) {
          var wheel = Util.wheelSteps(wsWheelAccum, delta)
          wsWheelAccum = wheel.remainder
          if (wheel.steps === 0) return
          var ids = workspaceIds()
          var index = ids.indexOf(activeWsId)
          if (index === -1) return
          var target = ids[Util.clamp(index - wheel.steps, 0, ids.length - 1)]
          if (target !== ids[index]) focusWorkspace(target)
        }

        // Hover tracking for indicator peek
        HoverHandler {
          onHoveredChanged: root.setBarHovered(hovered)
        }
        Component.onDestruction: if (root.barHovered) root.setBarHovered(false)

        // Tooltip PopupWindow matching stock Omarchy bar
        PopupWindow {
          id: tooltipWindow
          visible: root.tooltipShown && root.tooltipTarget !== null && root.tooltipText !== "" && root.targetBelongsToWindow(root.tooltipTarget, barWindow)
          color: "transparent"
          implicitWidth: Math.ceil(tooltipBubble.implicitWidth)
          implicitHeight: Math.ceil(tooltipBubble.implicitHeight)

          anchor {
            id: tooltipAnchor
            window: barWindow
            adjustment: PopupAdjustment.Slide
            edges: Edges.Top | Edges.Left
            gravity: Edges.Bottom | Edges.Right
            rect.width: 1
            rect.height: 1
            onAnchoring: {
              var target = root.tooltipTarget
              if (!root.targetBelongsToWindow(target, barWindow)) return
              var localX = target.width / 2 - tooltipWindow.implicitWidth / 2
              var localY = target.height + 6
              var point = barWindow.contentItem.mapFromItem(target, localX, localY)
              tooltipAnchor.rect.x = Math.round(point.x)
              tooltipAnchor.rect.y = Math.round(point.y)
            }
          }

          Rectangle {
            id: tooltipBubble
            implicitWidth: tooltipLabel.implicitWidth + 18
            implicitHeight: tooltipLabel.implicitHeight + 10
            color: Commons.Color.tooltip ? Commons.Color.tooltip.background : root.colorBarBg
            border.width: 1
            border.color: Commons.Color.tooltip ? Commons.Color.tooltip.border : root.colorBorderAccent
            radius: 2

            Text {
              id: tooltipLabel
              textFormat: Text.PlainText
              anchors.centerIn: parent
              text: root.tooltipText
              color: Commons.Color.tooltip ? Commons.Color.tooltip.text : root.colorPrimaryText
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall || 11
            }
          }
        }

        Item {
          anchors.fill: parent

          // ==========================================
          // A) LEFT GROUP: MENU + CYCLE + WORKSPACES
          // ==========================================
          Rectangle {
            id: leftGroup
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.top: parent.top
            anchors.topMargin: root.groupTopMargin
            height: root.groupHeight
            width: leftRow.implicitWidth + 12
            radius: root.groupRadius
            color: root.colorBarBg
            border.width: 1
            border.color: root.colorBorderNormal

            RowLayout {
              id: leftRow
              anchors.centerIn: parent
              spacing: 4

              // 1. Omarchy Menu Button (uses live omarchy.menu widget when loaded)
              WidgetSlot {
                id: menuSlot
                widgetId: "omarchy.menu"
                region: "left"
                hostWindow: barWindow
              }

              // Fallback Menu Button if barWidgetRegistry hasn't registered omarchy.menu
              Rectangle {
                visible: !menuSlot.activeItem
                width: 22
                height: 22
                radius: 2
                color: menuMa.containsMouse ? root.colorSurfaceHover : "transparent"

                Text {
                  anchors.centerIn: parent
                  font.family: root.fontFamily
                  font.pixelSize: 13
                  font.bold: true
                  color: root.colorAccentMint
                  text: "󰣇"
                }

                MouseArea {
                  id: menuMa
                  anchors.fill: parent
                  acceptedButtons: Qt.LeftButton | Qt.RightButton
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: function(mouse) {
                    if (mouse.button === Qt.RightButton) root.run("xdg-terminal-exec")
                    else root.run("omarchy-shell shell toggle omarchy.menu '{\"menu\":\"root\"}'")
                  }
                }
              }

              // 2. Cycle Bar Style Button (Stock <-> Redesigned Bar)
              Rectangle {
                id: switchBarBtn
                Accessible.name: "Switch bar style"
                width: 22
                height: 22
                radius: 2
                color: switchBarMa.containsMouse ? root.colorSurfaceHover : "transparent"
                border.width: switchBarMa.containsMouse ? 1 : 0
                border.color: root.colorBorderAccent

                readonly property bool tooltipHovered: visible && switchBarMa.containsMouse

                Text {
                  anchors.centerIn: parent
                  font.family: root.fontFamily
                  font.pixelSize: 12
                  font.bold: true
                  color: switchBarMa.containsMouse ? root.colorAccentMint : root.colorSecondaryText
                  text: "⇄"
                }

                MouseArea {
                  id: switchBarMa
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onEntered: root.showTooltip(switchBarBtn, "Switch to stock Omarchy bar")
                  onExited: root.hideTooltip(switchBarBtn)
                  onClicked: toggleBarProc.running = true
                }
              }

              Process {
                id: toggleBarProc
                command: ["bash", "-c", "toggle-bar-style 2>/dev/null || \"$HOME/.local/bin/toggle-bar-style\" 2>/dev/null || \"$HOME/Work/my-config/bin/toggle-bar-style\""]
              }

              // Divider line
              Rectangle {
                width: 1
                height: 14
                color: root.colorBorderNormal
              }

              // 3. Workspaces Pills (multi-monitor block + guest + scroll + active layout cycle)
              Repeater {
                model: barWindow.workspaceIds()
                delegate: Rectangle {
                  id: wsPill
                  required property int modelData
                  required property int index

                  readonly property var wsObj: barWindow.workspaceById(modelData)
                  readonly property bool isActive: barWindow.activeWsId === modelData
                  readonly property bool isOccupied: wsObj !== null && !!wsObj.toplevels && !!wsObj.toplevels.values && wsObj.toplevels.values.length > 0
                  readonly property int wsSlot: barWindow.slotOf(modelData)

                  width: 22
                  height: 22
                  radius: 2
                  color: isActive ? root.colorAccentMint : (wsMa.containsMouse ? root.colorSurfaceHover : "transparent")

                  Text {
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    font.family: root.fontFamily
                    font.pixelSize: 11
                    font.bold: wsPill.isActive
                    color: wsPill.isActive
                      ? root.colorTextOnAccent
                      : (wsPill.isOccupied ? root.colorPrimaryText : root.colorDimText)
                    text: wsPill.wsSlot === barWindow.wsSlots ? "0" : String(wsPill.wsSlot)
                  }

                  MouseArea {
                    id: wsMa
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(mouse) {
                      if (mouse.button === Qt.RightButton || wsPill.isActive) {
                        if (!wsPill.isActive) barWindow.focusWorkspace(wsPill.modelData)
                        barWindow.cycleWorkspaceLayout()
                      } else {
                        barWindow.focusWorkspace(wsPill.modelData)
                      }
                    }
                    onWheel: function(wheel) {
                      barWindow.scrollWorkspaces(wheel.angleDelta.y)
                    }
                  }
                }
              }
            }
          }

          // ==========================================
          // B) CENTER GROUP: INDICATORS + CLOCK + EXTENSIONS
          // ==========================================
          Rectangle {
            id: centerGroup
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: root.groupTopMargin
            height: root.groupHeight
            width: centerRow.implicitWidth + 18
            radius: root.groupRadius
            color: root.colorBarBg
            border.width: 1
            border.color: root.colorBorderAccent

            RowLayout {
              id: centerRow
              anchors.centerIn: parent
              spacing: 8

              // Indicators (screen recording / webcam / night light / DND / reminder)
              WidgetSlot {
                widgetId: "omarchy.indicators"
                region: "centerBegin"
                hostWindow: barWindow
              }

              // Main Calendar / Clock Button (MouseArea is scoped ONLY to clockBtn so sibling widgets receive clicks!)
              Item {
                id: clockBtn
                implicitWidth: clockBtnRow.implicitWidth + 6
                implicitHeight: root.groupHeight - 4

                readonly property bool tooltipHovered: visible && clockMa.containsMouse

                RowLayout {
                  id: clockBtnRow
                  anchors.centerIn: parent
                  spacing: 7

                  // Small inline calendar icon
                  Canvas {
                    width: 13
                    height: 13
                    property color iconColor: root.colorAccentMint
                    onIconColorChanged: requestPaint()
                    onPaint: {
                      var ctx = getContext("2d")
                      ctx.reset()
                      ctx.strokeStyle = iconColor
                      ctx.lineWidth = 1.2
                      ctx.strokeRect(1, 2, 11, 9.5)
                      ctx.beginPath()
                      ctx.moveTo(1, 5)
                      ctx.lineTo(12, 5)
                      ctx.stroke()
                      ctx.beginPath()
                      ctx.moveTo(3.5, 0.5)
                      ctx.lineTo(3.5, 3)
                      ctx.moveTo(9.5, 0.5)
                      ctx.lineTo(9.5, 3)
                      ctx.stroke()
                    }
                  }

                  Text {
                    textFormat: Text.PlainText
                    font.family: root.fontFamily
                    font.pixelSize: 11
                    color: root.colorSecondaryText
                    text: Model.formatBarDate(root.currentDate)
                  }

                  Text {
                    textFormat: Text.PlainText
                    font.family: root.fontFamily
                    font.pixelSize: 11
                    color: root.colorDimText
                    text: "·"
                  }

                  Text {
                    textFormat: Text.PlainText
                    font.family: root.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: root.colorPrimaryText
                    text: Model.formatClockTime(root.currentDate, root.settings.clock24h)
                  }

                  // Live countdown timer badge if active
                  Rectangle {
                    visible: root.timerRunning
                    height: 18
                    width: timerText.implicitWidth + 8
                    radius: 2
                    color: root.colorAccentMint

                    Text {
                      id: timerText
                      anchors.centerIn: parent
                      textFormat: Text.PlainText
                      font.family: root.fontFamily
                      font.pixelSize: 10
                      font.bold: true
                      color: root.colorTextOnAccent
                      text: "⏱ " + Model.formatTimerSeconds(root.timerSeconds)
                    }
                  }
                }

                MouseArea {
                  id: clockMa
                  anchors.fill: parent
                  acceptedButtons: Qt.LeftButton | Qt.RightButton
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onEntered: root.showTooltip(clockBtn, "Calendar (Click) · Toggle 12h/24h (Right-click)")
                  onExited: root.hideTooltip(clockBtn)
                  onClicked: function(mouse) {
                    if (mouse.button === Qt.RightButton) {
                      var updated = Object.assign({}, root.settings, { clock24h: !root.settings.clock24h })
                      root.settings = updated
                    } else {
                      root.toggleCalendar(barWindow.modelData)
                    }
                  }
                }
              }

              // CenterEnd widgets (Weather, Elsewhen, SystemUpdate) - now directly clickable!
              WidgetSlot {
                widgetId: "omarchy.weather"
                region: "centerEnd"
                hostWindow: barWindow
              }

              WidgetSlot {
                widgetId: "omarchy.elsewhen"
                region: "centerEnd"
                hostWindow: barWindow
              }

              WidgetSlot {
                widgetId: "omarchy.system-update"
                region: "centerEnd"
                hostWindow: barWindow
              }
            }
          }

          // ==========================================
          // C) RIGHT GROUP: TRAY + CONTROLS + BATTERY + NOTIFICATIONS
          // ==========================================
          Rectangle {
            id: rightGroup
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.top: parent.top
            anchors.topMargin: root.groupTopMargin
            height: root.groupHeight
            width: rightRow.implicitWidth + 16
            radius: root.groupRadius
            color: root.colorBarBg
            border.width: 1
            border.color: root.colorBorderNormal

            RowLayout {
              id: rightRow
              anchors.centerIn: parent
              spacing: 6

              // 1. System Tray (includes superwhisper.panel inside drawer)
              WidgetSlot {
                widgetId: "omarchy.tray"
                region: "right"
                hostWindow: barWindow
              }

              // 2. Keyboard Layout Code (cycles layouts on click)
              WidgetSlot {
                widgetId: "omarchy.keyboard-layout"
                region: "right"
                hostWindow: barWindow
              }

              // 3. Omarchy Agents
              WidgetSlot {
                widgetId: "omarchy.agents"
                region: "right"
                hostWindow: barWindow
              }

              // 4. Bluetooth Panel Widget
              WidgetSlot {
                widgetId: "omarchy.bluetooth"
                region: "right"
                hostWindow: barWindow
              }

              // 5. Network / Wi-Fi Panel Widget
              WidgetSlot {
                widgetId: "omarchy.network"
                region: "right"
                hostWindow: barWindow
              }

              // 6. Audio / Volume Panel Widget
              WidgetSlot {
                widgetId: "omarchy.audio"
                region: "right"
                hostWindow: barWindow
              }

              // 7. Monitor Brightness Panel Widget
              WidgetSlot {
                widgetId: "omarchy.monitor"
                region: "right"
                hostWindow: barWindow
              }

              // 8. Custom 22x10 Battery Gauge + Power Panel Trigger (single unified widget, no duplicate icon)
              Item {
                id: batteryGaugeContainer
                readonly property var battDevice: UPower.displayDevice
                readonly property bool batteryPresent: !!(battDevice && battDevice.isPresent)
                readonly property real battPct: battDevice ? Number(battDevice.percentage || 0) : 0
                readonly property int battPercentInt: Math.round(battPct <= 1.0 ? battPct * 100 : battPct)
                readonly property bool charging: battDevice && battDevice.isPresent && !UPower.onBattery && battPercentInt < 100

                visible: batteryPresent || !powerSlot.activeItem
                implicitWidth: batteryPresent ? (gaugeRow.implicitWidth + 4) : 22
                implicitHeight: root.groupHeight - 4

                RowLayout {
                  id: gaugeRow
                  anchors.centerIn: parent
                  visible: batteryGaugeContainer.batteryPresent
                  spacing: 5

                  Rectangle {
                    Accessible.name: "Battery gauge"
                    width: 22
                    height: 10
                    radius: 2
                    color: "transparent"
                    border.width: 1
                    border.color: root.colorPrimaryText

                    Rectangle {
                      anchors.left: parent.left
                      anchors.leftMargin: 1
                      anchors.top: parent.top
                      anchors.topMargin: 1
                      anchors.bottom: parent.bottom
                      anchors.bottomMargin: 1
                      width: Math.max(2, (parent.width - 2) * Math.min(1.0, batteryGaugeContainer.battPercentInt / 100))
                      radius: 1
                      color: batteryGaugeContainer.battPercentInt <= 15
                        ? "#d88d91"
                        : (batteryGaugeContainer.charging ? "#f2b45a" : root.colorAccentMint)
                    }

                    Rectangle {
                      anchors.left: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      width: 2
                      height: 4
                      radius: 1
                      color: root.colorPrimaryText
                    }
                  }

                  Text {
                    textFormat: Text.PlainText
                    font.family: root.fontFamily
                    font.pixelSize: 11
                    color: root.colorPrimaryText
                    text: batteryGaugeContainer.battPercentInt + "%"
                  }
                }

                // Fallback power icon on desktops without a battery
                Text {
                  anchors.centerIn: parent
                  visible: !batteryGaugeContainer.batteryPresent
                  font.family: root.fontFamily
                  font.pixelSize: 12
                  color: root.colorPrimaryText
                  text: "⏻"
                }

                // Stack omarchy.power's interactive BarIconButton transparently over our gauge
                // so clicks, tooltips, anchorItem positioning, and clickTargets work natively
                WidgetSlot {
                  id: powerSlot
                  anchors.fill: parent
                  widgetId: "omarchy.power"
                  region: "right"
                  hostWindow: barWindow
                  visualHidden: true
                }
              }

              // 9. SwayNC Notification Center
              WidgetSlot {
                widgetId: "user.notification-center"
                region: "right"
                hostWindow: barWindow
              }
            }
          }
        }
      }
    }
  }
}
