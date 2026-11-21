.pragma library

function isObject(value) {
  return value !== null && typeof value === "object";
}

function finiteNumber(value, fallback) {
  var number = Number(value);
  return isFinite(number) ? number : (fallback === undefined ? 0 : fallback);
}

function isWindowAddress(value) {
  return typeof value === "string" && /^0x[0-9a-f]+$/i.test(value);
}

function localWorkspaceNumber(workspace, monitorIndex) {
  if (!isObject(workspace)) return 0;
  var name = String(workspace.name || "");
  var id = finiteNumber(workspace.id, 0);
  if (/^[1-9][0-9]*$/.test(name)) {
    var named = Number(name);
    if (named >= 1 && named <= 10) return named;
  }
  if (id > 0) {
    var modulo = ((id - 1) % 10) + 1;
    if (modulo >= 1 && modulo <= 10) return modulo;
  }
  return 0;
}

function buildSnapshot(monitorsJson, workspacesJson, clientsJson, activeWindowJson) {
  try {
    var monitors = JSON.parse(monitorsJson);
    var workspaces = JSON.parse(workspacesJson);
    var clients = JSON.parse(clientsJson);
    var activeWindow = null;
    if (activeWindowJson && typeof activeWindowJson === "string" && activeWindowJson.trim().length > 0) {
      try {
        activeWindow = JSON.parse(activeWindowJson);
      } catch (e) {}
    }

    if (!Array.isArray(monitors) || !Array.isArray(workspaces) || !Array.isArray(clients)) {
      return null;
    }

    var monitorList = monitors.map(function (monitor) {
      return {
        id: finiteNumber(monitor.id, -1),
        name: String(monitor.name || ""),
        x: finiteNumber(monitor.x, 0),
        y: finiteNumber(monitor.y, 0),
        width: finiteNumber(monitor.width, 0),
        height: finiteNumber(monitor.height, 0),
        focused: monitor.focused === true,
        activeWorkspace: isObject(monitor.activeWorkspace) ? monitor.activeWorkspace : null
      };
    }).filter(function (monitor) { return monitor.name.length > 0; })
      .sort(function (a, b) { return a.x - b.x || a.y - b.y || a.name.localeCompare(b.name); });

    var monitorById = Object.create(null);
    var monitorByName = Object.create(null);
    for (var mi = 0; mi < monitorList.length; mi++) {
      monitorById[String(monitorList[mi].id)] = monitorList[mi];
      monitorByName[monitorList[mi].name] = monitorList[mi];
    }

    var workspaceIndex = Object.create(null);
    for (var wi = 0; wi < workspaces.length; wi++) {
      var ws = workspaces[wi];
      if (!isObject(ws)) continue;
      var monitorName = String(ws.monitor || "");
      if (!monitorName && ws.monitorID !== undefined) {
        var mon = monitorById[String(ws.monitorID)];
        if (mon) monitorName = mon.name;
      }
      var targetMon = monitorByName[monitorName];
      if (!targetMon) continue;
      var monitorIdx = monitorList.indexOf(targetMon);
      var wsNum = localWorkspaceNumber(ws, monitorIdx);
      if (wsNum < 1 || wsNum > 10) continue;
      var key = monitorName + ":" + wsNum;
      workspaceIndex[key] = {
        id: finiteNumber(ws.id, 0),
        name: nameForWorkspace(ws, wsNum),
        number: wsNum,
        monitor: monitorName,
        exists: true,
        windows: [],
        active: false
      };
    }

    // Determine target focused address
    var targetFocusedAddress = "";
    if (activeWindow && isWindowAddress(activeWindow.address)) {
      targetFocusedAddress = String(activeWindow.address);
    } else {
      // Find client with focusHistoryID === 0 or lowest focusHistoryID
      var minHistory = 2147483647;
      for (var hi = 0; hi < clients.length; hi++) {
        var cl = clients[hi];
        if (!isObject(cl) || !isWindowAddress(cl.address)) continue;
        if (cl.focused === true) {
          targetFocusedAddress = String(cl.address);
          break;
        }
        var hId = finiteNumber(cl.focusHistoryID, 2147483647);
        if (hId < minHistory) {
          minHistory = hId;
          targetFocusedAddress = String(cl.address);
        }
      }
    }

    var addresses = Object.create(null);
    var windows = [];
    var totalWindowCount = 0;

    for (var ci = 0; ci < clients.length; ci++) {
      var client = clients[ci];
      if (!isObject(client) || !isWindowAddress(client.address)) continue;
      var address = String(client.address);
      if (addresses[address]) continue;
      addresses[address] = true;

      var clientMonitorName = "";
      if (typeof client.monitor === "number") {
        var clientMonitor = monitorById[String(client.monitor)];
        if (clientMonitor) clientMonitorName = clientMonitor.name;
      } else if (typeof client.monitor === "string") {
        clientMonitorName = client.monitor;
      }
      if (!clientMonitorName && isObject(client.workspace)) {
        var workspaceMonitor = String(client.workspace.monitor || "");
        if (workspaceMonitor) clientMonitorName = workspaceMonitor;
      }
      if (!clientMonitorName || !monitorByName[clientMonitorName]) continue;

      var clientWorkspace = isObject(client.workspace) ? client.workspace : {};
      var clientMonitorIndex = monitorList.indexOf(monitorByName[clientMonitorName]);
      var clientNumber = localWorkspaceNumber(clientWorkspace, clientMonitorIndex);
      if (clientNumber < 1 || clientNumber > 10) continue;

      var wsKey = clientMonitorName + ":" + clientNumber;
      var workspaceEntry = workspaceIndex[wsKey];
      if (!workspaceEntry) {
        workspaceEntry = {
          id: finiteNumber(clientWorkspace.id, 0),
          name: nameForWorkspace(clientWorkspace, clientNumber),
          number: clientNumber,
          monitor: clientMonitorName,
          exists: false,
          windows: [],
          active: false
        };
        workspaceIndex[wsKey] = workspaceEntry;
      }

      var isFocused = (address === targetFocusedAddress);

      var winItem = {
        address: address,
        class: String(client.class || ""),
        title: String(client.title || ""),
        focused: isFocused,
        focusHistoryID: finiteNumber(client.focusHistoryID, 2147483647),
        workspaceId: finiteNumber(clientWorkspace.id, workspaceEntry.id),
        workspaceNumber: clientNumber,
        monitor: clientMonitorName
      };
      workspaceEntry.windows.push(winItem);
      windows.push(winItem);
      totalWindowCount++;
    }

    // Ensure exactly one window has focused: true if windows exist
    var focusedWindow = null;
    for (var wi = 0; wi < windows.length; wi++) {
      if (windows[wi].focused) {
        focusedWindow = windows[wi];
        break;
      }
    }
    if (!focusedWindow && windows.length > 0) {
      windows[0].focused = true;
      focusedWindow = windows[0];
    }

    var roots = [];
    var focusedMonitor = "";
    for (var ri = 0; ri < monitorList.length; ri++) {
      var rootMonitor = monitorList[ri];
      var activeWorkspace = isObject(rootMonitor.activeWorkspace) ? rootMonitor.activeWorkspace : null;
      var activeNumber = activeWorkspace
        ? localWorkspaceNumber(activeWorkspace, ri)
        : 0;
      var workspaceList = [];
      for (var number = 1; number <= 10; number++) {
        var rwsKey = rootMonitor.name + ":" + number;
        var entry = workspaceIndex[rwsKey] || {
          id: activeWorkspace && activeNumber === number ? finiteNumber(activeWorkspace.id, 0) : 0,
          name: String(number),
          number: number,
          monitor: rootMonitor.name,
          exists: false,
          windows: [],
          active: activeNumber === number
        };
        entry.active = (activeNumber === number);
        entry.windows.sort(function (a, b) {
          return a.focusHistoryID - b.focusHistoryID || a.title.localeCompare(b.title);
        });

        // Compute labels preview for the mockup
        var classes = [];
        for (var k = 0; k < entry.windows.length; k++) {
          if (entry.windows[k].class) classes.push(entry.windows[k].class);
        }
        entry.label = classes.length > 0 ? classes.join(" · ") : "empty";

        workspaceList.push(entry);
      }
      if (rootMonitor.focused) focusedMonitor = rootMonitor.name;
      roots.push({
        monitor: rootMonitor.name,
        monitorId: rootMonitor.id,
        x: rootMonitor.x,
        y: rootMonitor.y,
        width: rootMonitor.width,
        height: rootMonitor.height,
        focused: rootMonitor.focused,
        workspaces: workspaceList
      });
    }

    return {
      focusedMonitor: focusedMonitor || (focusedWindow ? focusedWindow.monitor : (roots.length ? roots[0].monitor : "")),
      focusedAddress: focusedWindow ? focusedWindow.address : "",
      totalWindows: totalWindowCount,
      roots: roots
    };
  } catch (error) {
    console.warn("Omarchy Tree snapshot parse failed:", error);
    return null;
  }
}

function nameForWorkspace(workspace, number) {
  var name = isObject(workspace) ? String(workspace.name || "") : "";
  return name.length > 0 ? name : String(number);
}

function isValidAddress(address) {
  return typeof address === "string" && /^0x[0-9a-f]+$/i.test(address);
}

function focusSequence(address, monitorName, workspaceId) {
  if (!isValidAddress(address)) return [];
  var monitor = typeof monitorName === "string" ? monitorName : "";
  return [
    {
      mode: "lua",
      command: ["hyprctl", "dispatch", 'hl.dsp.focus({ window = "address:' + address + '" })']
    },
    {
      mode: "legacy",
      command: ["hyprctl", "dispatch", "focuswindow", "address:" + address]
    },
    {
      mode: "fallback",
      command: [
        "sh", "-c",
        'hyprctl dispatch "hl.dsp.focus({ monitor = \\"$1\\" })" >/dev/null 2>&1; '
        + 'hyprctl dispatch "hl.dsp.focus({ window = \\"address:$2\\" })" >/dev/null 2>&1',
        "omarchy-tree", monitor, address
      ]
    }
  ];
}
