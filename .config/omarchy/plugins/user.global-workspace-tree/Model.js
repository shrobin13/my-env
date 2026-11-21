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
  return finiteNumber(monitorIndex, 0) >= 0 ? 0 : 0;
}

function buildSnapshot(monitorsJson, workspacesJson, clientsJson) {
  try {
    var monitors = JSON.parse(monitorsJson);
    var workspaces = JSON.parse(workspacesJson);
    var clients = JSON.parse(clientsJson);
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
      var workspace = workspaces[wi];
      if (!isObject(workspace)) continue;
      var monitorName = String(workspace.monitor || "");
      if (!monitorName && workspace.monitorID !== undefined) {
        var monitor = monitorById[String(workspace.monitorID)];
        if (monitor) monitorName = monitor.name;
      }
      var monitor = monitorByName[monitorName];
      if (!monitor) continue;
      var monitorIndex = monitorList.indexOf(monitor);
      var number = localWorkspaceNumber(workspace, monitorIndex);
      if (number < 1 || number > 10) continue;
      var key = monitorName + ":" + number;
      workspaceIndex[key] = {
        id: finiteNumber(workspace.id, 0),
        name: nameForWorkspace(workspace, number),
        number: number,
        monitor: monitorName,
        exists: true,
        windows: [],
        active: false
      };
    }

    var activeAddress = "";
    var addresses = Object.create(null);
    var focusedCount = 0;
    var windows = [];
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
      if (!clientMonitorName) continue;
      if (!monitorByName[clientMonitorName]) continue;

      var clientWorkspace = isObject(client.workspace) ? client.workspace : {};
      var clientMonitorIndex = monitorList.indexOf(monitorByName[clientMonitorName]);
      var clientNumber = localWorkspaceNumber(clientWorkspace, clientMonitorIndex);
      if (clientNumber < 1 || clientNumber > 10) continue;

      var key = clientMonitorName + ":" + clientNumber;
      var workspaceEntry = workspaceIndex[key];
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
        workspaceIndex[key] = workspaceEntry;
      }
      var focused = client.focused === true || (isObject(client.focused) && client.focused === true);
      if (focused) {
        focusedCount++;
        activeAddress = address;
      }
      var window = {
        address: address,
        class: String(client.class || ""),
        title: String(client.title || ""),
        focused: focused,
        focusHistoryID: finiteNumber(client.focusHistoryID, 2147483647),
        workspaceId: finiteNumber(clientWorkspace.id, workspaceEntry.id),
        workspaceNumber: clientNumber,
        monitor: clientMonitorName
      };
      workspaceEntry.windows.push(window);
      windows.push(window);
    }

    var roots = [];
    var focusedMonitor = "";
    for (var ri = 0; ri < monitorList.length; ri++) {
      var rootMonitor = monitorList[ri];
      var activeWorkspace = isObject(rootMonitor.activeWorkspace) ? rootMonitor.activeWorkspace : null;
      var rootMonitorIndex = ri;
      var activeNumber = activeWorkspace
        ? localWorkspaceNumber(activeWorkspace, rootMonitorIndex)
        : 0;
      var workspaceList = [];
      for (var number = 1; number <= 10; number++) {
        var workspaceKey = rootMonitor.name + ":" + number;
        var entry = workspaceIndex[workspaceKey] || {
          id: activeWorkspace && activeNumber === number ? finiteNumber(activeWorkspace.id, 0) : 0,
          name: String(number),
          number: number,
          monitor: rootMonitor.name,
          exists: false,
          windows: [],
          active: activeNumber === number
        };
        entry.active = activeNumber === number;
        entry.windows.sort(function (a, b) {
          return a.focusHistoryID - b.focusHistoryID || a.title.localeCompare(b.title);
        });
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

    var focusedWindow = null;
    for (var fi = 0; fi < windows.length; fi++) {
      if (windows[fi].focused) {
        focusedWindow = windows[fi];
        break;
      }
    }
    if (!focusedWindow && windows.length > 0) focusedWindow = windows[0];

    return {
      focusedMonitor: focusedMonitor || (focusedWindow ? focusedWindow.monitor : ""),
      focusedAddress: focusedWindow ? focusedWindow.address : activeAddress,
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
  var workspace = finiteNumber(workspaceId, 0);
  var direct = [
    { mode: "lua", command: ["sh", "-c",
      'out=$(hyprctl dispatch "hl.dsp.focus({ window = \\"address:$1\\" })" 2>&1); '
      + '[ "$out" = ok ] || hyprctl dispatch focuswindow "address:$1" >/dev/null 2>&1',
      "omarchy-tree", address] },
    { mode: "legacy", command: ["hyprctl", "dispatch", "focuswindow", "address:" + address] }
  ];
  if (!monitor || workspace <= 0) return direct;
  return direct.concat([
    { mode: "fallback", command: ["sh", "-c",
      'hyprctl dispatch focusmonitor "$1" >/dev/null 2>&1 && '
      + 'hyprctl dispatch workspace "$2" >/dev/null 2>&1 && '
      + 'hyprctl dispatch focuswindow "address:$3" >/dev/null 2>&1',
      "omarchy-tree", monitor, String(workspace), address] }
  ]);
}
