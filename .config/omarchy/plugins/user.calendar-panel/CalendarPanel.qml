pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "CalendarModel.js" as Model

PanelWindow {
  id: panelWindow

  property bool opened: false
  property var bar: null
  property var targetScreen: null
  property var settings: ({})

  readonly property string home: Quickshell.env("HOME")
  readonly property string dataHome: Quickshell.env("XDG_DATA_HOME") || (home + "/.local/share")
  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")
  readonly property string pluginDir: home + "/.config/omarchy/plugins/user.calendar-panel"
  readonly property string manageScript: pluginDir + "/manage.py"
  readonly property string settingsFilePath: pluginDir + "/settings.json"
  readonly property string defaultLocalIcsPath: dataHome + "/omarchy/calendar/events.ics"
  readonly property string googleCachePath: stateHome + "/omarchy/calendar/google.ics"

  // Track theme colors from Commons.Color with dark-green fallbacks
  readonly property color themeBg: Commons.Color.background ? Commons.Color.background : "#0b1a14"
  readonly property color themeFg: Commons.Color.foreground ? Commons.Color.foreground : "#e6f4ec"
  readonly property color themeMuted: Commons.Color.muted ? Commons.Color.muted : "#7f9a8c"
  readonly property color themeAccent: (settings && settings.accentOverride)
    ? settings.accentOverride
    : (Commons.Color.accent ? Commons.Color.accent : "#8fe3b8")

  readonly property color colorPanelBg: Qt.rgba(themeBg.r, themeBg.g, themeBg.b, 0.95)
  readonly property color colorBorderNormal: Qt.rgba(themeAccent.r, themeAccent.g, themeAccent.b, 0.28)
  readonly property color colorBorderAccent: (settings && settings.accentOverride)
    ? settings.accentOverride
    : (Commons.Color.popups && Commons.Color.popups.border ? Commons.Color.popups.border : Qt.rgba(themeAccent.r, themeAccent.g, themeAccent.b, 0.75))
  readonly property color colorPrimaryText: themeFg
  readonly property color colorSecondaryText: Qt.rgba(themeFg.r, themeFg.g, themeFg.b, 0.68)
  readonly property color colorDimText: themeMuted
  readonly property color colorOtherMonth: Qt.rgba(themeFg.r, themeFg.g, themeFg.b, 0.42)
  readonly property color colorWeekend: Qt.tint(themeFg, Qt.rgba(themeAccent.r, themeAccent.g, themeAccent.b, 0.45))
  readonly property color colorAccentMint: themeAccent
  readonly property color colorTextOnAccent: themeBg
  readonly property color colorEventDot: "#f2b45a"
  readonly property color colorEventSecondary: "#6fa8dc"
  readonly property color colorSurface: Qt.lighter(themeBg, 1.3)
  readonly property color colorSurfaceHover: Qt.lighter(themeBg, 1.7)
  readonly property color colorButtonBorder: Qt.rgba(themeAccent.r, themeAccent.g, themeAccent.b, 0.36)
  readonly property color colorCardBg: Qt.lighter(themeBg, 1.2)
  readonly property color colorInputBg: Qt.darker(themeBg, 1.25)

  readonly property string fontFamily: Style.font.family || "JetBrains Mono, monospace"

  // State
  property date today: new Date()
  property int viewYear: today.getFullYear()
  property int viewMonth: today.getMonth() // 0-11
  property string selectedDateKey: Model.keyForDate(today)
  property var localEventsMap: ({})
  property var googleEventsMap: ({})
  readonly property var eventsMap: Model.mergeEventsMaps([localEventsMap, googleEventsMap])
  property string statusHint: ""
  property real wheelAccum: 0
  property string rightMode: "agenda" // "agenda" | "new-event" | "settings"
  property bool syncingGoogle: false

  readonly property bool hasGoogleCalendar: !!(settings && settings.googleCalendarUrl && String(settings.googleCalendarUrl).trim() !== "")
  readonly property string activeLocalIcsPath: (settings && settings.icsPath && String(settings.icsPath).trim() !== "")
    ? String(settings.icsPath).trim()
    : defaultLocalIcsPath

  // Track whether any text input is focused so letter shortcuts don't hijack typing
  readonly property bool isInputActive: titleInput.activeFocus || startInput.activeFocus || endInput.activeFocus || googleUrlInput.activeFocus

  // Timer & Focus wiring
  property int timerSeconds: 0
  property bool timerRunning: false
  property bool dndActive: false

  signal startTimerRequested(int seconds)
  signal toggleDndRequested()
  signal closeRequested()

  function resolveFocusedScreen() {
    var focused = Hyprland.focusedMonitor
    if (focused && focused.name) {
      var screens = Quickshell.screens
      for (var i = 0; i < screens.length; i++) {
        if (screens[i].name === focused.name) return screens[i]
      }
    }
    return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
  }

  function showHint(msg) {
    statusHint = String(msg || "")
    hintResetTimer.restart()
  }

  function open(preferredScreen) {
    if (preferredScreen) targetScreen = preferredScreen
    else if (!targetScreen) targetScreen = resolveFocusedScreen()

    today = new Date()
    viewYear = today.getFullYear()
    viewMonth = today.getMonth()
    selectedDateKey = Model.keyForDate(today)
    rightMode = "agenda"
    statusHint = ""
    loadEvents()
    if (hasGoogleCalendar) syncGoogleCalendar(true)
    if (bar && typeof bar.requestPopout === "function") {
      bar.requestPopout(panelWindow)
    }
    opened = true
    Qt.callLater(function() { keyHandler.forceActiveFocus() })
  }

  function close() {
    opened = false
    rightMode = "agenda"
    statusHint = ""
    if (bar && typeof bar.releasePopout === "function") {
      bar.releasePopout(panelWindow)
    }
    closeRequested()
  }

  function closeForPopoutSwitch() {
    opened = false
    rightMode = "agenda"
    statusHint = ""
  }

  function toggle(preferredScreen) {
    if (opened) close()
    else open(preferredScreen)
  }

  function goToToday() {
    today = new Date()
    viewYear = today.getFullYear()
    viewMonth = today.getMonth()
    selectedDateKey = Model.keyForDate(today)
  }

  function prevMonth() {
    var step = Model.stepMonth(viewYear, viewMonth, -1)
    viewYear = step.year
    viewMonth = step.month
  }

  function nextMonth() {
    var step = Model.stepMonth(viewYear, viewMonth, 1)
    viewYear = step.year
    viewMonth = step.month
  }

  function selectDate(key) {
    selectedDateKey = key
  }

  function openNewEventForm() {
    titleInput.text = ""
    startInput.text = ""
    endInput.text = ""
    rightMode = "new-event"
    Qt.callLater(function() { titleInput.forceActiveFocus() })
  }

  function openSettingsView() {
    googleUrlInput.text = (settings && settings.googleCalendarUrl) ? String(settings.googleCalendarUrl) : ""
    rightMode = "settings"
    Qt.callLater(function() { googleUrlInput.forceActiveFocus() })
  }

  function cancelSubMode() {
    rightMode = "agenda"
    Qt.callLater(function() { keyHandler.forceActiveFocus() })
  }

  function saveNewEvent() {
    var t = titleInput.text.trim()
    if (!t) {
      showHint("Please enter an event title")
      return
    }
    addEventProc.command = [
      "python3", manageScript, "add-event",
      selectedDateKey, t, startInput.text.trim(), endInput.text.trim(), activeLocalIcsPath
    ]
    addEventProc.running = true
  }

  function openInGoogleCalendar() {
    openGoogleProc.command = [
      "python3", manageScript, "open-google-create",
      selectedDateKey, titleInput.text.trim(), startInput.text.trim(), endInput.text.trim()
    ]
    openGoogleProc.running = true
    showHint("Opened Google Calendar in browser")
  }

  function deleteLocalEvent(uid) {
    if (!uid) return
    deleteEventProc.command = ["python3", manageScript, "delete-event", uid, activeLocalIcsPath]
    deleteEventProc.running = true
  }

  function saveGoogleSettings(urlVal) {
    var clean = String(urlVal || "").trim()
    if (clean !== "" && clean.indexOf("https://") !== 0) {
      showHint("URL must start with https://")
      return
    }
    saveSettingsProc.pendingUrl = clean
    saveSettingsProc.command = ["python3", manageScript, "save-settings", settingsFilePath, clean]
    saveSettingsProc.running = true
  }

  function syncGoogleCalendar(silent) {
    if (syncProc.running) return
    syncProc.silentMode = !!silent
    syncingGoogle = true
    syncProc.command = ["python3", manageScript, "sync-google", settingsFilePath]
    syncProc.running = true
  }

  function triggerNewEvent() {
    openNewEventForm()
  }

  function toggleFocus() {
    toggleDndRequested()
  }

  function startOrResetTimer() {
    if (timerRunning) startTimerRequested(0)
    else startTimerRequested(1500)
  }

  function loadEvents() {
    localIcsFile.reload()
    googleIcsFile.reload()
  }

  function reparseLocal() {
    var is24h = !!(settings && settings.clock24h)
    localEventsMap = Model.parseIcs(localIcsFile.text(), {
      color: colorEventDot,
      source: "local",
      is24h: is24h
    })
  }

  function reparseGoogle() {
    var is24h = !!(settings && settings.clock24h)
    googleEventsMap = Model.parseIcs(googleIcsFile.text(), {
      color: colorEventSecondary,
      source: "google",
      is24h: is24h
    })
  }

  onSettingsChanged: {
    reparseLocal()
    reparseGoogle()
  }

  FileView {
    id: localIcsFile
    path: panelWindow.activeLocalIcsPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: panelWindow.reparseLocal()
    onLoadFailed: panelWindow.localEventsMap = ({})
  }

  FileView {
    id: googleIcsFile
    path: panelWindow.googleCachePath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: panelWindow.reparseGoogle()
    onLoadFailed: panelWindow.googleEventsMap = ({})
  }

  Process {
    id: addEventProc
    stderr: StdioCollector {
      onStreamFinished: {
        if (text && text.trim()) {
          try {
            var errObj = JSON.parse(text.trim())
            if (errObj.error) panelWindow.showHint(errObj.error)
          } catch (e) {}
        }
      }
    }
    onExited: function(code) {
      if (code === 0) {
        localIcsFile.reload()
        panelWindow.rightMode = "agenda"
        panelWindow.showHint("Event saved")
        Qt.callLater(function() { keyHandler.forceActiveFocus() })
      }
    }
  }

  Process {
    id: deleteEventProc
    onExited: function(code) {
      if (code === 0) {
        localIcsFile.reload()
        panelWindow.showHint("Event removed")
      }
    }
  }

  Process {
    id: openGoogleProc
  }

  Process {
    id: saveSettingsProc
    property string pendingUrl: ""
    stderr: StdioCollector {
      onStreamFinished: {
        if (text && text.trim()) {
          try {
            var errObj = JSON.parse(text.trim())
            if (errObj.error) panelWindow.showHint(errObj.error)
          } catch (e) {}
        }
      }
    }
    onExited: function(code) {
      if (code === 0) {
        if (pendingUrl !== "") {
          panelWindow.syncGoogleCalendar(false)
        } else {
          panelWindow.googleEventsMap = ({})
          panelWindow.syncGoogleCalendar(true)
          panelWindow.showHint("Google Calendar cleared")
        }
        panelWindow.rightMode = "agenda"
        Qt.callLater(function() { keyHandler.forceActiveFocus() })
      }
    }
  }

  Process {
    id: syncProc
    property bool silentMode: false
    property string lastErr: ""
    stderr: StdioCollector {
      onStreamFinished: syncProc.lastErr = text ? text.trim() : ""
    }
    onExited: function(code) {
      panelWindow.syncingGoogle = false
      if (code === 0) {
        googleIcsFile.reload()
        if (!silentMode) panelWindow.showHint("Google Calendar synced")
      } else if (!silentMode) {
        var msg = "Failed to sync Google Calendar"
        try {
          var obj = JSON.parse(syncProc.lastErr)
          if (obj && obj.error) msg = obj.error
        } catch (e) {}
        panelWindow.showHint(msg)
      }
      syncProc.lastErr = ""
    }
  }

  // Periodic background Google Calendar refresh
  Timer {
    interval: Math.max(60000, ((panelWindow.settings && panelWindow.settings.autoSyncMinutes) ? Number(panelWindow.settings.autoSyncMinutes) : 15) * 60000)
    running: panelWindow.hasGoogleCalendar
    repeat: true
    onTriggered: panelWindow.syncGoogleCalendar(true)
  }

  Timer {
    id: hintResetTimer
    interval: 3500
    repeat: false
    onTriggered: panelWindow.statusHint = ""
  }

  // Derived properties
  readonly property string todayKey: Model.keyForDate(today)
  readonly property int weekStartDay: Model.normalizedWeekStart(settings && settings.weekStartDay ? settings.weekStartDay : 0)
  readonly property string tomorrowKey: {
    var tom = new Date(today.getTime() + 86400000)
    return Model.keyForDate(tom)
  }

  readonly property var weekdayHeaders: {
    var order = Model.weekdayOrder(weekStartDay)
    var headers = []
    for (var i = 0; i < order.length; i++) {
      headers.push(Model.WEEKDAY_NAMES_SHORT[order[i]])
    }
    return headers
  }

  readonly property var weeks: Model.monthGrid(viewYear, viewMonth, weekStartDay, todayKey, eventsMap)

  readonly property int dayNum: Model.dayOfYear(today.getFullYear(), today.getMonth(), today.getDate())
  readonly property int daysLeft: Model.daysRemaining(today.getFullYear(), today.getMonth(), today.getDate())
  readonly property real yrProgress: Model.yearProgress(today.getFullYear(), today.getMonth(), today.getDate())

  // Window properties
  screen: targetScreen || (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
  anchors { top: true; bottom: true; left: true; right: true }
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "omarchy-calendar-panel"
  WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  visible: opened || card.opacity > 0

  // Outside click dismiss scrim
  MouseArea {
    anchors.fill: parent
    onClicked: panelWindow.close()
  }

  // Keyboard handler (respects text input focus!)
  Item {
    id: keyHandler
    anchors.fill: parent
    focus: panelWindow.opened

    Keys.onEscapePressed: function(event) {
      if (panelWindow.rightMode !== "agenda") {
        panelWindow.cancelSubMode()
      } else {
        panelWindow.close()
      }
      event.accepted = true
    }
    Keys.onLeftPressed: function(event) {
      if (!panelWindow.isInputActive) {
        panelWindow.prevMonth()
        event.accepted = true
      }
    }
    Keys.onRightPressed: function(event) {
      if (!panelWindow.isInputActive) {
        panelWindow.nextMonth()
        event.accepted = true
      }
    }
    Keys.onBackPressed: function(event) {
      panelWindow.close()
      event.accepted = true
    }

    Keys.onPressed: function(event) {
      if (panelWindow.isInputActive) return
      if (event.key === Qt.Key_T) {
        panelWindow.goToToday()
        event.accepted = true
      } else if (event.key === Qt.Key_N) {
        panelWindow.openNewEventForm()
        event.accepted = true
      } else if (event.key === Qt.Key_Escape) {
        if (panelWindow.rightMode !== "agenda") panelWindow.cancelSubMode()
        else panelWindow.close()
        event.accepted = true
      }
    }
  }

  // Central Card (2px max radius)
  Rectangle {
    id: card
    anchors.horizontalCenter: parent.horizontalCenter
    y: 44
    width: Math.min(880, parent.width - 32)
    height: mainLayout.implicitHeight + 48
    radius: 2
    color: panelWindow.colorPanelBg
    border.width: 1
    border.color: panelWindow.colorBorderAccent
    clip: true

    MouseArea {
      anchors.fill: parent
      onClicked: function(mouse) { mouse.accepted = true }
    }

    Rectangle {
      anchors.fill: parent
      anchors.margins: -1
      radius: 2
      color: "transparent"
      border.width: 1
      border.color: Qt.rgba(0, 0, 0, 0.5)
      z: -1
    }

    opacity: panelWindow.opened ? 1 : 0
    transform: Translate {
      y: panelWindow.opened ? 0 : -10
      Behavior on y {
        NumberAnimation { duration: Style.duration(140); easing.type: Easing.OutCubic }
      }
    }
    Behavior on opacity {
      NumberAnimation { duration: Style.duration(140); easing.type: Easing.OutCubic }
    }

    ColumnLayout {
      id: mainLayout
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.leftMargin: 32
      anchors.rightMargin: 32
      anchors.topMargin: 28
      spacing: 18

      // ==========================================
      // 1. HEADER ROW
      // ==========================================
      RowLayout {
        Layout.fillWidth: true
        spacing: 16

        Rectangle {
          width: 44
          height: 44
          radius: 2
          color: panelWindow.colorSurface
          border.width: 1
          border.color: panelWindow.colorBorderAccent

          Canvas {
            id: calIconCanvas
            anchors.centerIn: parent
            width: 24
            height: 24
            property color iconColor: panelWindow.colorAccentMint
            onIconColorChanged: requestPaint()
            onPaint: {
              var ctx = getContext("2d")
              ctx.reset()
              ctx.strokeStyle = iconColor
              ctx.lineWidth = 1.8
              ctx.lineJoin = "miter"
              ctx.lineCap = "square"

              ctx.strokeRect(3, 5, 18, 16)
              ctx.beginPath()
              ctx.moveTo(3, 10)
              ctx.lineTo(21, 10)
              ctx.stroke()
              ctx.beginPath()
              ctx.moveTo(7, 2)
              ctx.lineTo(7, 6)
              ctx.moveTo(17, 2)
              ctx.lineTo(17, 6)
              ctx.stroke()
              ctx.fillStyle = iconColor
              ctx.fillRect(7, 13, 2, 2)
              ctx.fillRect(11, 13, 2, 2)
              ctx.fillRect(15, 13, 2, 2)
              ctx.fillRect(7, 17, 2, 2)
              ctx.fillRect(11, 17, 2, 2)
            }
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2

          Text {
            textFormat: Text.PlainText
            font.family: panelWindow.fontFamily
            font.pixelSize: 12
            font.bold: true
            font.letterSpacing: 1.68
            color: panelWindow.colorSecondaryText
            text: Model.formatHeaderAbove(panelWindow.today)
          }

          Text {
            textFormat: Text.PlainText
            font.family: panelWindow.fontFamily
            font.pixelSize: 34
            font.bold: true
            color: panelWindow.colorPrimaryText
            text: Model.formatHeaderDate(panelWindow.today)
          }
        }

        // Right navigation + Google Calendar Settings buttons (44px tall, radius 2)
        RowLayout {
          spacing: 6

          Rectangle {
            id: prevBtn
            Accessible.name: "Previous month"
            activeFocusOnTab: true
            width: 44
            height: 44
            radius: 2
            color: prevMa.containsMouse ? panelWindow.colorSurfaceHover : panelWindow.colorSurface
            border.width: activeFocus ? 2 : 1
            border.color: (activeFocus || prevMa.containsMouse) ? panelWindow.colorBorderAccent : panelWindow.colorButtonBorder

            Keys.onReturnPressed: panelWindow.prevMonth()
            Keys.onSpacePressed: panelWindow.prevMonth()

            Text {
              anchors.centerIn: parent
              font.family: panelWindow.fontFamily
              font.pixelSize: 18
              font.bold: true
              color: panelWindow.colorPrimaryText
              text: "‹"
            }
            MouseArea {
              id: prevMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: panelWindow.prevMonth()
            }
          }

          Rectangle {
            id: todayBtn
            Accessible.name: "Jump to today"
            activeFocusOnTab: true
            width: 76
            height: 44
            radius: 2
            color: todayMa.containsMouse ? panelWindow.colorSurfaceHover : panelWindow.colorSurface
            border.width: activeFocus ? 2 : 1
            border.color: (activeFocus || todayMa.containsMouse) ? panelWindow.colorBorderAccent : panelWindow.colorButtonBorder

            Keys.onReturnPressed: panelWindow.goToToday()
            Keys.onSpacePressed: panelWindow.goToToday()

            Text {
              anchors.centerIn: parent
              font.family: panelWindow.fontFamily
              font.pixelSize: 13
              font.bold: true
              color: panelWindow.colorPrimaryText
              text: "Today"
            }
            MouseArea {
              id: todayMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: panelWindow.goToToday()
            }
          }

          Rectangle {
            id: nextBtn
            Accessible.name: "Next month"
            activeFocusOnTab: true
            width: 44
            height: 44
            radius: 2
            color: nextMa.containsMouse ? panelWindow.colorSurfaceHover : panelWindow.colorSurface
            border.width: activeFocus ? 2 : 1
            border.color: (activeFocus || nextMa.containsMouse) ? panelWindow.colorBorderAccent : panelWindow.colorButtonBorder

            Keys.onReturnPressed: panelWindow.nextMonth()
            Keys.onSpacePressed: panelWindow.nextMonth()

            Text {
              anchors.centerIn: parent
              font.family: panelWindow.fontFamily
              font.pixelSize: 18
              font.bold: true
              color: panelWindow.colorPrimaryText
              text: "›"
            }
            MouseArea {
              id: nextMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: panelWindow.nextMonth()
            }
          }

          // Sync Google Calendar button (visible when Google Calendar URL is configured)
          Rectangle {
            visible: panelWindow.hasGoogleCalendar
            Accessible.name: "Sync Google Calendar"
            activeFocusOnTab: true
            width: 44
            height: 44
            radius: 2
            color: syncMa.containsMouse ? panelWindow.colorSurfaceHover : panelWindow.colorSurface
            border.width: activeFocus ? 2 : 1
            border.color: (activeFocus || syncMa.containsMouse) ? panelWindow.colorBorderAccent : panelWindow.colorButtonBorder

            Text {
              anchors.centerIn: parent
              font.family: panelWindow.fontFamily
              font.pixelSize: 15
              font.bold: true
              color: panelWindow.syncingGoogle ? panelWindow.colorAccentMint : panelWindow.colorPrimaryText
              text: panelWindow.syncingGoogle ? "…" : "↻"
            }
            MouseArea {
              id: syncMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: panelWindow.syncGoogleCalendar(false)
            }
          }

          // Calendar Settings / Google Calendar Setup button
          Rectangle {
            Accessible.name: "Calendar settings"
            activeFocusOnTab: true
            width: 44
            height: 44
            radius: 2
            color: settingsMa.containsMouse ? panelWindow.colorSurfaceHover : (panelWindow.rightMode === "settings" ? panelWindow.colorAccentMint : panelWindow.colorSurface)
            border.width: activeFocus ? 2 : 1
            border.color: (activeFocus || settingsMa.containsMouse) ? panelWindow.colorBorderAccent : panelWindow.colorButtonBorder

            Keys.onReturnPressed: panelWindow.rightMode === "settings" ? panelWindow.cancelSubMode() : panelWindow.openSettingsView()

            Text {
              anchors.centerIn: parent
              font.family: panelWindow.fontFamily
              font.pixelSize: 15
              color: panelWindow.rightMode === "settings" ? panelWindow.colorTextOnAccent : panelWindow.colorPrimaryText
              text: "⚙"
            }
            MouseArea {
              id: settingsMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (panelWindow.rightMode === "settings") panelWindow.cancelSubMode()
                else panelWindow.openSettingsView()
              }
            }
          }
        }
      }

      // ==========================================
      // 2. YEAR PROGRESS ROW
      // ==========================================
      RowLayout {
        Layout.fillWidth: true
        spacing: 14

        Text {
          textFormat: Text.PlainText
          font.family: panelWindow.fontFamily
          font.pixelSize: 13
          font.bold: true
          color: panelWindow.colorSecondaryText
          text: String(panelWindow.today.getFullYear())
        }

        Rectangle {
          Layout.fillWidth: true
          height: 6
          radius: 2
          color: panelWindow.colorSurface

          Rectangle {
            height: parent.height
            width: parent.width * panelWindow.yrProgress
            radius: 2
            color: panelWindow.colorAccentMint
          }
        }

        Text {
          textFormat: Text.PlainText
          font.family: panelWindow.fontFamily
          font.pixelSize: 12
          font.bold: true
          color: panelWindow.colorSecondaryText
          text: "Day " + panelWindow.dayNum + " · " + panelWindow.daysLeft + " left"
        }
      }

      // Status hint banner
      Rectangle {
        Layout.fillWidth: true
        height: panelWindow.statusHint !== "" ? 28 : 0
        visible: panelWindow.statusHint !== ""
        radius: 2
        color: panelWindow.colorSurface
        border.width: 1
        border.color: panelWindow.colorBorderAccent
        clip: true

        Text {
          anchors.centerIn: parent
          textFormat: Text.PlainText
          font.family: panelWindow.fontFamily
          font.pixelSize: 12
          color: panelWindow.colorAccentMint
          text: panelWindow.statusHint
        }
      }

      // ==========================================
      // 3. BODY (TWO COLUMNS, 32px GAP)
      // ==========================================
      RowLayout {
        Layout.fillWidth: true
        spacing: 32

        // ------------------------------------------
        // LEFT COLUMN (MONTH GRID)
        // ------------------------------------------
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 6

          RowLayout {
            Layout.fillWidth: true
            Text {
              textFormat: Text.PlainText
              font.family: panelWindow.fontFamily
              font.pixelSize: 16
              font.bold: true
              color: panelWindow.colorPrimaryText
              text: Model.MONTH_NAMES_FULL[panelWindow.viewMonth] + " " + panelWindow.viewYear
            }
            Item { Layout.fillWidth: true }
          }

          Item {
            Layout.fillWidth: true
            implicitWidth: monthGridCol.implicitWidth
            implicitHeight: monthGridCol.implicitHeight

            WheelHandler {
              onWheel: function(event) {
                var wheel = Util.wheelSteps(panelWindow.wheelAccum, event.angleDelta.y)
                panelWindow.wheelAccum = wheel.remainder
                if (wheel.steps > 0) panelWindow.prevMonth()
                else if (wheel.steps < 0) panelWindow.nextMonth()
              }
            }

            Column {
              id: monthGridCol
              width: parent.width
              spacing: 3

              Row {
                spacing: 4
                Rectangle {
                  width: 32
                  height: 24
                  color: "transparent"
                  Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: panelWindow.colorBorderNormal
                  }
                  Text {
                    anchors.centerIn: parent
                    font.family: panelWindow.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: panelWindow.colorDimText
                    text: "W"
                  }
                }

                Repeater {
                  model: panelWindow.weekdayHeaders
                  delegate: Item {
                    required property var modelData
                    width: 62
                    height: 24
                    Text {
                      anchors.centerIn: parent
                      font.family: panelWindow.fontFamily
                      font.pixelSize: 11
                      font.bold: true
                      font.letterSpacing: 1.0
                      color: (modelData === "SUN" || modelData === "SAT") ? panelWindow.colorWeekend : panelWindow.colorSecondaryText
                      text: modelData
                    }
                  }
                }
              }

              Repeater {
                id: weekRepeater
                model: panelWindow.weeks
                delegate: Row {
                  id: weekRow
                  required property var modelData
                  spacing: 4

                  Rectangle {
                    width: 32
                    height: 44
                    color: "transparent"
                    Rectangle {
                      anchors.right: parent.right
                      anchors.top: parent.top
                      anchors.bottom: parent.bottom
                      width: 1
                      color: panelWindow.colorBorderNormal
                    }
                    Text {
                      anchors.centerIn: parent
                      font.family: panelWindow.fontFamily
                      font.pixelSize: 12
                      font.bold: true
                      color: panelWindow.colorDimText
                      text: String(weekRow.modelData.week)
                    }
                  }

                  Repeater {
                    model: weekRow.modelData.days
                    delegate: Rectangle {
                      id: dayCell
                      required property var modelData
                      activeFocusOnTab: true
                      Accessible.name: modelData.key
                      width: 62
                      height: 44
                      radius: 2

                      readonly property bool isToday: modelData.today
                      readonly property bool isSelected: modelData.key === panelWindow.selectedDateKey
                      readonly property bool inMonth: modelData.inMonth
                      readonly property bool isWeekend: modelData.weekend
                      readonly property bool hasEvents: modelData.hasEvents

                      color: isToday
                        ? panelWindow.colorAccentMint
                        : (cellMa.containsMouse
                           ? panelWindow.colorSurfaceHover
                           : (isSelected ? panelWindow.colorSurface : "transparent"))

                      border.width: activeFocus ? 2 : (isSelected && !isToday ? 1 : 0)
                      border.color: panelWindow.colorBorderAccent

                      Keys.onReturnPressed: panelWindow.selectDate(dayCell.modelData.key)
                      Keys.onSpacePressed: panelWindow.selectDate(dayCell.modelData.key)

                      Text {
                        anchors.centerIn: parent
                        textFormat: Text.PlainText
                        font.family: panelWindow.fontFamily
                        font.pixelSize: 14
                        font.bold: dayCell.isToday || dayCell.isSelected
                        color: dayCell.isToday
                          ? panelWindow.colorTextOnAccent
                          : (!dayCell.inMonth
                             ? panelWindow.colorOtherMonth
                             : (dayCell.isWeekend ? panelWindow.colorWeekend : panelWindow.colorPrimaryText))
                        text: String(dayCell.modelData.day)
                      }

                      // Event indicator dot (radius <= 2)
                      Rectangle {
                        visible: dayCell.hasEvents
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 4
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 4
                        height: 4
                        radius: 2
                        color: dayCell.isToday ? panelWindow.colorTextOnAccent : panelWindow.colorEventDot
                      }

                      MouseArea {
                        id: cellMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panelWindow.selectDate(dayCell.modelData.key)
                      }
                    }
                  }
                }
              }
            }
          }
        }

        // ------------------------------------------
        // RIGHT COLUMN (270px AGENDA / NEW EVENT / SETTINGS)
        // ------------------------------------------
        ColumnLayout {
          Layout.preferredWidth: 270
          Layout.maximumWidth: 270
          Layout.minimumWidth: 270
          Layout.fillHeight: true
          spacing: 12

          // ==========================================
          // MODE A: AGENDA VIEW
          // ==========================================
          Flickable {
            visible: panelWindow.rightMode === "agenda"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 240
            contentWidth: width
            contentHeight: agendaColumn.implicitHeight
            clip: true

            ColumnLayout {
              id: agendaColumn
              width: parent.width
              spacing: 8

              readonly property bool isDefaultDay: panelWindow.selectedDateKey === panelWindow.todayKey
              readonly property var todayEvents: panelWindow.eventsMap[panelWindow.todayKey] || []
              readonly property var tomorrowEvents: panelWindow.eventsMap[panelWindow.tomorrowKey] || []
              readonly property var selectedEvents: panelWindow.eventsMap[panelWindow.selectedDateKey] || []

              // Selected day (not today)
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: !agendaColumn.isDefaultDay

                Text {
                  textFormat: Text.PlainText
                  font.family: panelWindow.fontFamily
                  font.pixelSize: 12
                  font.bold: true
                  font.letterSpacing: 1.2
                  color: panelWindow.colorSecondaryText
                  text: "AGENDA · " + panelWindow.selectedDateKey
                }

                Rectangle {
                  Layout.fillWidth: true
                  height: 74
                  visible: agendaColumn.selectedEvents.length === 0
                  radius: 2
                  color: panelWindow.colorCardBg
                  border.width: 1
                  border.color: panelWindow.colorButtonBorder

                  Text {
                    anchors.centerIn: parent
                    font.family: panelWindow.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                    color: panelWindow.colorSecondaryText
                    text: "No events"
                  }
                }

                Repeater {
                  model: agendaColumn.selectedEvents
                  delegate: Rectangle {
                    id: selCard
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: selCardContent.implicitHeight + 16
                    radius: 2
                    color: panelWindow.colorCardBg
                    border.width: 1
                    border.color: panelWindow.colorButtonBorder
                    clip: true

                    Rectangle {
                      anchors.left: parent.left
                      anchors.top: parent.top
                      anchors.bottom: parent.bottom
                      width: 3
                      color: selCard.modelData.color || panelWindow.colorEventDot
                    }

                    ColumnLayout {
                      id: selCardContent
                      anchors.left: parent.left
                      anchors.right: selDelBtn.visible ? selDelBtn.left : parent.right
                      anchors.leftMargin: 12
                      anchors.rightMargin: 8
                      anchors.topMargin: 8
                      anchors.bottomMargin: 8
                      spacing: 2

                      Text {
                        Layout.fillWidth: true
                        textFormat: Text.PlainText
                        font.family: panelWindow.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                        color: panelWindow.colorPrimaryText
                        text: String(selCard.modelData.title || "")
                        elide: Text.ElideRight
                      }

                      Text {
                        Layout.fillWidth: true
                        textFormat: Text.PlainText
                        font.family: panelWindow.fontFamily
                        font.pixelSize: 12
                        color: panelWindow.colorSecondaryText
                        text: String(selCard.modelData.timeRange || "")
                      }
                    }

                    Rectangle {
                      id: selDelBtn
                      visible: selCard.modelData.source === "local" && !!selCard.modelData.uid
                      anchors.right: parent.right
                      anchors.rightMargin: 6
                      anchors.verticalCenter: parent.verticalCenter
                      width: 20
                      height: 20
                      radius: 2
                      color: selDelMa.containsMouse ? panelWindow.colorSurfaceHover : "transparent"

                      Text {
                        anchors.centerIn: parent
                        font.family: panelWindow.fontFamily
                        font.pixelSize: 12
                        color: panelWindow.colorDimText
                        text: "×"
                      }
                      MouseArea {
                        id: selDelMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panelWindow.deleteLocalEvent(selCard.modelData.uid)
                      }
                    }
                  }
                }
              }

              // Default (Today + Tomorrow)
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: agendaColumn.isDefaultDay

                Text {
                  textFormat: Text.PlainText
                  font.family: panelWindow.fontFamily
                  font.pixelSize: 12
                  font.bold: true
                  font.letterSpacing: 1.2
                  color: panelWindow.colorSecondaryText
                  text: "TODAY"
                }

                Rectangle {
                  Layout.fillWidth: true
                  height: 60
                  visible: agendaColumn.todayEvents.length === 0
                  radius: 2
                  color: panelWindow.colorCardBg
                  border.width: 1
                  border.color: panelWindow.colorButtonBorder

                  Text {
                    anchors.centerIn: parent
                    font.family: panelWindow.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                    color: panelWindow.colorSecondaryText
                    text: "No events"
                  }
                }

                Repeater {
                  model: agendaColumn.todayEvents
                  delegate: Rectangle {
                    id: todayCard
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: todayCardContent.implicitHeight + 16
                    radius: 2
                    color: panelWindow.colorCardBg
                    border.width: 1
                    border.color: panelWindow.colorButtonBorder
                    clip: true

                    Rectangle {
                      anchors.left: parent.left
                      anchors.top: parent.top
                      anchors.bottom: parent.bottom
                      width: 3
                      color: todayCard.modelData.color || panelWindow.colorEventDot
                    }

                    ColumnLayout {
                      id: todayCardContent
                      anchors.left: parent.left
                      anchors.right: todayDelBtn.visible ? todayDelBtn.left : parent.right
                      anchors.leftMargin: 12
                      anchors.rightMargin: 8
                      anchors.topMargin: 8
                      anchors.bottomMargin: 8
                      spacing: 2

                      Text {
                        Layout.fillWidth: true
                        textFormat: Text.PlainText
                        font.family: panelWindow.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                        color: panelWindow.colorPrimaryText
                        text: String(todayCard.modelData.title || "")
                        elide: Text.ElideRight
                      }

                      Text {
                        Layout.fillWidth: true
                        textFormat: Text.PlainText
                        font.family: panelWindow.fontFamily
                        font.pixelSize: 12
                        color: panelWindow.colorSecondaryText
                        text: String(todayCard.modelData.timeRange || "")
                      }
                    }

                    Rectangle {
                      id: todayDelBtn
                      visible: todayCard.modelData.source === "local" && !!todayCard.modelData.uid
                      anchors.right: parent.right
                      anchors.rightMargin: 6
                      anchors.verticalCenter: parent.verticalCenter
                      width: 20
                      height: 20
                      radius: 2
                      color: todayDelMa.containsMouse ? panelWindow.colorSurfaceHover : "transparent"

                      Text {
                        anchors.centerIn: parent
                        font.family: panelWindow.fontFamily
                        font.pixelSize: 12
                        color: panelWindow.colorDimText
                        text: "×"
                      }
                      MouseArea {
                        id: todayDelMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panelWindow.deleteLocalEvent(todayCard.modelData.uid)
                      }
                    }
                  }
                }

                Item { height: 2 }

                Text {
                  textFormat: Text.PlainText
                  font.family: panelWindow.fontFamily
                  font.pixelSize: 12
                  font.bold: true
                  font.letterSpacing: 1.2
                  color: panelWindow.colorSecondaryText
                  text: "TOMORROW"
                }

                Rectangle {
                  Layout.fillWidth: true
                  height: 60
                  visible: agendaColumn.tomorrowEvents.length === 0
                  radius: 2
                  color: panelWindow.colorCardBg
                  border.width: 1
                  border.color: panelWindow.colorButtonBorder

                  Text {
                    anchors.centerIn: parent
                    font.family: panelWindow.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                    color: panelWindow.colorSecondaryText
                    text: "No events"
                  }
                }

                Repeater {
                  model: agendaColumn.tomorrowEvents
                  delegate: Rectangle {
                    id: tomCard
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: tomCardContent.implicitHeight + 16
                    radius: 2
                    color: panelWindow.colorCardBg
                    border.width: 1
                    border.color: panelWindow.colorButtonBorder
                    clip: true

                    Rectangle {
                      anchors.left: parent.left
                      anchors.top: parent.top
                      anchors.bottom: parent.bottom
                      width: 3
                      color: tomCard.modelData.color || panelWindow.colorEventSecondary
                    }

                    ColumnLayout {
                      id: tomCardContent
                      anchors.left: parent.left
                      anchors.right: tomDelBtn.visible ? tomDelBtn.left : parent.right
                      anchors.leftMargin: 12
                      anchors.rightMargin: 8
                      anchors.topMargin: 8
                      anchors.bottomMargin: 8
                      spacing: 2

                      Text {
                        Layout.fillWidth: true
                        textFormat: Text.PlainText
                        font.family: panelWindow.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                        color: panelWindow.colorPrimaryText
                        text: String(tomCard.modelData.title || "")
                        elide: Text.ElideRight
                      }

                      Text {
                        Layout.fillWidth: true
                        textFormat: Text.PlainText
                        font.family: panelWindow.fontFamily
                        font.pixelSize: 12
                        color: panelWindow.colorSecondaryText
                        text: String(tomCard.modelData.timeRange || "")
                      }
                    }

                    Rectangle {
                      id: tomDelBtn
                      visible: tomCard.modelData.source === "local" && !!tomCard.modelData.uid
                      anchors.right: parent.right
                      anchors.rightMargin: 6
                      anchors.verticalCenter: parent.verticalCenter
                      width: 20
                      height: 20
                      radius: 2
                      color: tomDelMa.containsMouse ? panelWindow.colorSurfaceHover : "transparent"

                      Text {
                        anchors.centerIn: parent
                        font.family: panelWindow.fontFamily
                        font.pixelSize: 12
                        color: panelWindow.colorDimText
                        text: "×"
                      }
                      MouseArea {
                        id: tomDelMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panelWindow.deleteLocalEvent(tomCard.modelData.uid)
                      }
                    }
                  }
                }

                // Subtle Google Calendar quick connect banner when unconfigured
                Rectangle {
                  Layout.fillWidth: true
                  height: 30
                  visible: !panelWindow.hasGoogleCalendar
                  radius: 2
                  color: connectGcalMa.containsMouse ? panelWindow.colorSurfaceHover : "transparent"
                  border.width: 1
                  border.color: panelWindow.colorBorderNormal

                  Text {
                    anchors.centerIn: parent
                    font.family: panelWindow.fontFamily
                    font.pixelSize: 11
                    color: panelWindow.colorEventSecondary
                    text: "+ Connect Google Calendar"
                  }

                  MouseArea {
                    id: connectGcalMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: panelWindow.openSettingsView()
                  }
                }
              }
            }
          }

          // ==========================================
          // MODE B: INLINE "+ NEW EVENT" FORM
          // ==========================================
          ColumnLayout {
            visible: panelWindow.rightMode === "new-event"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 240
            spacing: 10

            Text {
              textFormat: Text.PlainText
              font.family: panelWindow.fontFamily
              font.pixelSize: 12
              font.bold: true
              font.letterSpacing: 1.2
              color: panelWindow.colorAccentMint
              text: "NEW EVENT · " + panelWindow.selectedDateKey
            }

            // Title input
            Rectangle {
              Layout.fillWidth: true
              height: 34
              radius: 2
              color: panelWindow.colorInputBg
              border.width: 1
              border.color: titleInput.activeFocus ? panelWindow.colorBorderAccent : panelWindow.colorButtonBorder

              TextInput {
                id: titleInput
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: TextInput.AlignVCenter
                font.family: panelWindow.fontFamily
                font.pixelSize: 12
                color: panelWindow.colorPrimaryText
                selectionColor: panelWindow.colorAccentMint
                selectedTextColor: panelWindow.colorTextOnAccent
                clip: true
                Keys.onReturnPressed: panelWindow.saveNewEvent()
                Keys.onEscapePressed: panelWindow.cancelSubMode()

                Text {
                  anchors.fill: parent
                  verticalAlignment: Text.AlignVCenter
                  visible: !titleInput.text
                  font.family: panelWindow.fontFamily
                  font.pixelSize: 12
                  color: panelWindow.colorDimText
                  text: "Event title..."
                }
              }
            }

            // Start & End time inputs (optional)
            RowLayout {
              Layout.fillWidth: true
              spacing: 8

              Rectangle {
                Layout.fillWidth: true
                height: 32
                radius: 2
                color: panelWindow.colorInputBg
                border.width: 1
                border.color: startInput.activeFocus ? panelWindow.colorBorderAccent : panelWindow.colorButtonBorder

                TextInput {
                  id: startInput
                  anchors.fill: parent
                  anchors.leftMargin: 8
                  anchors.rightMargin: 8
                  verticalAlignment: TextInput.AlignVCenter
                  font.family: panelWindow.fontFamily
                  font.pixelSize: 12
                  color: panelWindow.colorPrimaryText
                  selectionColor: panelWindow.colorAccentMint
                  selectedTextColor: panelWindow.colorTextOnAccent
                  clip: true
                  Keys.onReturnPressed: panelWindow.saveNewEvent()
                  Keys.onEscapePressed: panelWindow.cancelSubMode()

                  Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: !startInput.text
                    font.family: panelWindow.fontFamily
                    font.pixelSize: 11
                    color: panelWindow.colorDimText
                    text: "Start (14:00)"
                  }
                }
              }

              Rectangle {
                Layout.fillWidth: true
                height: 32
                radius: 2
                color: panelWindow.colorInputBg
                border.width: 1
                border.color: endInput.activeFocus ? panelWindow.colorBorderAccent : panelWindow.colorButtonBorder

                TextInput {
                  id: endInput
                  anchors.fill: parent
                  anchors.leftMargin: 8
                  anchors.rightMargin: 8
                  verticalAlignment: TextInput.AlignVCenter
                  font.family: panelWindow.fontFamily
                  font.pixelSize: 12
                  color: panelWindow.colorPrimaryText
                  selectionColor: panelWindow.colorAccentMint
                  selectedTextColor: panelWindow.colorTextOnAccent
                  clip: true
                  Keys.onReturnPressed: panelWindow.saveNewEvent()
                  Keys.onEscapePressed: panelWindow.cancelSubMode()

                  Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: !endInput.text
                    font.family: panelWindow.fontFamily
                    font.pixelSize: 11
                    color: panelWindow.colorDimText
                    text: "End (15:00)"
                  }
                }
              }
            }

            Text {
              Layout.fillWidth: true
              textFormat: Text.PlainText
              font.family: panelWindow.fontFamily
              font.pixelSize: 10
              color: panelWindow.colorDimText
              wrapMode: Text.WordWrap
              text: "Leave times empty for All day. Saved to local .ics or open in Google Calendar."
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: 6

              Rectangle {
                Layout.fillWidth: true
                height: 32
                radius: 2
                color: saveEvMa.containsMouse ? panelWindow.colorSurfaceHover : panelWindow.colorAccentMint
                border.width: 1
                border.color: panelWindow.colorBorderAccent

                Text {
                  anchors.centerIn: parent
                  font.family: panelWindow.fontFamily
                  font.pixelSize: 12
                  font.bold: true
                  color: saveEvMa.containsMouse ? panelWindow.colorPrimaryText : panelWindow.colorTextOnAccent
                  text: "Save"
                }
                MouseArea {
                  id: saveEvMa
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: panelWindow.saveNewEvent()
                }
              }

              Rectangle {
                Layout.fillWidth: true
                height: 32
                radius: 2
                color: cancelEvMa.containsMouse ? panelWindow.colorSurfaceHover : panelWindow.colorSurface
                border.width: 1
                border.color: panelWindow.colorButtonBorder

                Text {
                  anchors.centerIn: parent
                  font.family: panelWindow.fontFamily
                  font.pixelSize: 12
                  color: panelWindow.colorPrimaryText
                  text: "Cancel"
                }
                MouseArea {
                  id: cancelEvMa
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: panelWindow.cancelSubMode()
                }
              }
            }

            // 1-click Google Calendar template button
            Rectangle {
              Layout.fillWidth: true
              height: 30
              radius: 2
              color: gcalTemplateMa.containsMouse ? panelWindow.colorSurfaceHover : panelWindow.colorCardBg
              border.width: 1
              border.color: panelWindow.colorButtonBorder

              Text {
                anchors.centerIn: parent
                font.family: panelWindow.fontFamily
                font.pixelSize: 11
                color: panelWindow.colorEventSecondary
                text: "Open in Google Calendar ↗"
              }
              MouseArea {
                id: gcalTemplateMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: panelWindow.openInGoogleCalendar()
              }
            }

            Item { Layout.fillHeight: true }
          }

          // ==========================================
          // MODE C: GOOGLE CALENDAR SETTINGS VIEW
          // ==========================================
          ColumnLayout {
            visible: panelWindow.rightMode === "settings"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 240
            spacing: 10

            Text {
              textFormat: Text.PlainText
              font.family: panelWindow.fontFamily
              font.pixelSize: 12
              font.bold: true
              font.letterSpacing: 1.2
              color: panelWindow.colorEventSecondary
              text: "GOOGLE CALENDAR SYNC"
            }

            Text {
              Layout.fillWidth: true
              textFormat: Text.PlainText
              font.family: panelWindow.fontFamily
              font.pixelSize: 10
              color: panelWindow.colorSecondaryText
              wrapMode: Text.WordWrap
              text: "Google Calendar → Settings → Integrate calendar → Secret address in iCal format:"
            }

            Rectangle {
              Layout.fillWidth: true
              height: 34
              radius: 2
              color: panelWindow.colorInputBg
              border.width: 1
              border.color: googleUrlInput.activeFocus ? panelWindow.colorBorderAccent : panelWindow.colorButtonBorder

              TextInput {
                id: googleUrlInput
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                verticalAlignment: TextInput.AlignVCenter
                font.family: panelWindow.fontFamily
                font.pixelSize: 11
                color: panelWindow.colorPrimaryText
                selectionColor: panelWindow.colorAccentMint
                selectedTextColor: panelWindow.colorTextOnAccent
                selectByMouse: true
                clip: true
                Keys.onReturnPressed: panelWindow.saveGoogleSettings(googleUrlInput.text)
                Keys.onEscapePressed: panelWindow.cancelSubMode()

                Text {
                  anchors.fill: parent
                  verticalAlignment: Text.AlignVCenter
                  visible: !googleUrlInput.text
                  font.family: panelWindow.fontFamily
                  font.pixelSize: 11
                  color: panelWindow.colorDimText
                  text: "https://calendar.google.com/..."
                }
              }
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: 6

              Rectangle {
                Layout.fillWidth: true
                height: 32
                radius: 2
                color: saveSetMa.containsMouse ? panelWindow.colorSurfaceHover : panelWindow.colorAccentMint
                border.width: 1
                border.color: panelWindow.colorBorderAccent

                Text {
                  anchors.centerIn: parent
                  font.family: panelWindow.fontFamily
                  font.pixelSize: 12
                  font.bold: true
                  color: saveSetMa.containsMouse ? panelWindow.colorPrimaryText : panelWindow.colorTextOnAccent
                  text: "Save & Sync"
                }
                MouseArea {
                  id: saveSetMa
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: panelWindow.saveGoogleSettings(googleUrlInput.text)
                }
              }

              Rectangle {
                width: 60
                height: 32
                radius: 2
                color: clearSetMa.containsMouse ? panelWindow.colorSurfaceHover : panelWindow.colorSurface
                border.width: 1
                border.color: panelWindow.colorButtonBorder

                Text {
                  anchors.centerIn: parent
                  font.family: panelWindow.fontFamily
                  font.pixelSize: 11
                  color: panelWindow.colorSecondaryText
                  text: "Clear"
                }
                MouseArea {
                  id: clearSetMa
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    googleUrlInput.text = ""
                    panelWindow.saveGoogleSettings("")
                  }
                }
              }

              Rectangle {
                width: 56
                height: 32
                radius: 2
                color: backSetMa.containsMouse ? panelWindow.colorSurfaceHover : panelWindow.colorSurface
                border.width: 1
                border.color: panelWindow.colorButtonBorder

                Text {
                  anchors.centerIn: parent
                  font.family: panelWindow.fontFamily
                  font.pixelSize: 11
                  color: panelWindow.colorPrimaryText
                  text: "Back"
                }
                MouseArea {
                  id: backSetMa
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: panelWindow.cancelSubMode()
                }
              }
            }

            Text {
              Layout.fillWidth: true
              textFormat: Text.PlainText
              font.family: panelWindow.fontFamily
              font.pixelSize: 10
              color: panelWindow.colorDimText
              wrapMode: Text.WordWrap
              text: "Local events are stored in ~/.local/share/omarchy/calendar/events.ics"
            }

            Item { Layout.fillHeight: true }
          }

          // Bottom Quick Actions: "+ Event", "Timer", "Focus"
          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
              Accessible.name: "Add event"
              activeFocusOnTab: true
              Layout.fillWidth: true
              height: 36
              radius: 2
              color: addEvMa.containsMouse ? panelWindow.colorSurfaceHover : (panelWindow.rightMode === "new-event" ? panelWindow.colorAccentMint : panelWindow.colorSurface)
              border.width: activeFocus ? 2 : 1
              border.color: (activeFocus || addEvMa.containsMouse) ? panelWindow.colorBorderAccent : panelWindow.colorButtonBorder

              Keys.onReturnPressed: panelWindow.openNewEventForm()
              Keys.onSpacePressed: panelWindow.openNewEventForm()

              Text {
                anchors.centerIn: parent
                font.family: panelWindow.fontFamily
                font.pixelSize: 12
                font.bold: true
                color: panelWindow.rightMode === "new-event" ? panelWindow.colorTextOnAccent : panelWindow.colorPrimaryText
                text: "+ Event"
              }
              MouseArea {
                id: addEvMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (panelWindow.rightMode === "new-event") panelWindow.cancelSubMode()
                  else panelWindow.openNewEventForm()
                }
              }
            }

            Rectangle {
              Accessible.name: "Toggle timer"
              activeFocusOnTab: true
              Layout.fillWidth: true
              height: 36
              radius: 2
              color: timerMa.containsMouse ? panelWindow.colorSurfaceHover : (panelWindow.timerRunning ? panelWindow.colorAccentMint : panelWindow.colorSurface)
              border.width: activeFocus ? 2 : 1
              border.color: (activeFocus || timerMa.containsMouse) ? panelWindow.colorBorderAccent : panelWindow.colorButtonBorder

              Keys.onReturnPressed: panelWindow.startOrResetTimer()
              Keys.onSpacePressed: panelWindow.startOrResetTimer()

              Text {
                anchors.centerIn: parent
                font.family: panelWindow.fontFamily
                font.pixelSize: 12
                font.bold: true
                color: panelWindow.timerRunning ? panelWindow.colorTextOnAccent : panelWindow.colorPrimaryText
                text: panelWindow.timerRunning ? Model.formatTimerSeconds(panelWindow.timerSeconds) : "Timer"
              }
              MouseArea {
                id: timerMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: panelWindow.startOrResetTimer()
              }
            }

            Rectangle {
              Accessible.name: "Toggle Do Not Disturb"
              activeFocusOnTab: true
              Layout.fillWidth: true
              height: 36
              radius: 2
              color: focusMa.containsMouse ? panelWindow.colorSurfaceHover : (panelWindow.dndActive ? panelWindow.colorAccentMint : panelWindow.colorSurface)
              border.width: activeFocus ? 2 : 1
              border.color: (activeFocus || focusMa.containsMouse) ? panelWindow.colorBorderAccent : panelWindow.colorButtonBorder

              Keys.onReturnPressed: panelWindow.toggleFocus()
              Keys.onSpacePressed: panelWindow.toggleFocus()

              Text {
                anchors.centerIn: parent
                font.family: panelWindow.fontFamily
                font.pixelSize: 12
                font.bold: true
                color: panelWindow.dndActive ? panelWindow.colorTextOnAccent : panelWindow.colorPrimaryText
                text: panelWindow.dndActive ? "DND On" : "Focus"
              }
              MouseArea {
                id: focusMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: panelWindow.toggleFocus()
              }
            }
          }
        }
      }

      // ==========================================
      // 4. FOOTER (SEPARATED BY TOP BORDER)
      // ==========================================
      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: panelWindow.colorBorderNormal
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 16

        RowLayout {
          spacing: 6
          Rectangle {
            width: 28; height: 18; radius: 2; color: panelWindow.colorSurface
            border.width: 1; border.color: panelWindow.colorButtonBorder
            Text { anchors.centerIn: parent; font.family: panelWindow.fontFamily; font.pixelSize: 10; color: panelWindow.colorDimText; text: "←/→" }
          }
          Text { font.family: panelWindow.fontFamily; font.pixelSize: 11; color: panelWindow.colorDimText; text: "month" }
        }

        RowLayout {
          spacing: 6
          Rectangle {
            width: 20; height: 18; radius: 2; color: panelWindow.colorSurface
            border.width: 1; border.color: panelWindow.colorButtonBorder
            Text { anchors.centerIn: parent; font.family: panelWindow.fontFamily; font.pixelSize: 10; color: panelWindow.colorDimText; text: "T" }
          }
          Text { font.family: panelWindow.fontFamily; font.pixelSize: 11; color: panelWindow.colorDimText; text: "today" }
        }

        RowLayout {
          spacing: 6
          Rectangle {
            width: 20; height: 18; radius: 2; color: panelWindow.colorSurface
            border.width: 1; border.color: panelWindow.colorButtonBorder
            Text { anchors.centerIn: parent; font.family: panelWindow.fontFamily; font.pixelSize: 10; color: panelWindow.colorDimText; text: "N" }
          }
          Text { font.family: panelWindow.fontFamily; font.pixelSize: 11; color: panelWindow.colorDimText; text: "new event" }
        }

        Item { Layout.fillWidth: true }

        RowLayout {
          spacing: 6
          Rectangle {
            width: 32; height: 18; radius: 2; color: panelWindow.colorSurface
            border.width: 1; border.color: panelWindow.colorButtonBorder
            Text { anchors.centerIn: parent; font.family: panelWindow.fontFamily; font.pixelSize: 10; color: panelWindow.colorDimText; text: "Esc" }
          }
          Text { font.family: panelWindow.fontFamily; font.pixelSize: 11; color: panelWindow.colorDimText; text: "close" }
        }
      }
    }
  }
}
