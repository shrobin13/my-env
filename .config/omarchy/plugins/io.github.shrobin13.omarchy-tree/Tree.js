.pragma library

function makeState(model) {
  var state = {
    model: model,
    cursor: 0,
    search: "",
    recordedCursor: 0,
    folds: Object.create(null),
    rows: []
  };
  state.rows = flatten(model, state.folds, "");
  // Start cursor on focused window or first selectable
  state.cursor = initialCursor(state.rows, model);
  return state;
}

function initialCursor(rows, model) {
  if (!rows || !rows.length) return 0;
  if (model && model.focusedAddress) {
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].kind === "window" && rows[i].window && rows[i].window.address === model.focusedAddress) {
        return i;
      }
    }
  }
  for (var j = 0; j < rows.length; j++) {
    if (rows[j].selectable) return j;
  }
  return 0;
}

function flatten(model, folds, search) {
  var rows = [];
  var query = String(search || "").trim().toLowerCase();
  if (!model || !Array.isArray(model.roots)) return rows;

  for (var ri = 0; ri < model.roots.length; ri++) {
    var root = model.roots[ri];

    // Check if monitor has any windows at all
    var monitorHasWindows = false;
    for (var checkWi = 0; checkWi < root.workspaces.length; checkWi++) {
      if (root.workspaces[checkWi].windows.length > 0) {
        monitorHasWindows = true;
        break;
      }
    }

    for (var wi = 0; wi < root.workspaces.length; wi++) {
      var workspace = root.workspaces[wi];
      var wsNumberStr = String(workspace.number);
      var wsNameStr = String(workspace.name || "").toLowerCase();

      var matchesWsDirectly = query.length === 0
        || wsNumberStr.indexOf(query) >= 0
        || wsNameStr.indexOf(query) >= 0;

      var hasMatchingWindow = false;
      var windowMatches = [];
      for (var wIndex = 0; wIndex < workspace.windows.length; wIndex++) {
        var win = workspace.windows[wIndex];
        var titleStr = String(win.title || "").toLowerCase();
        var classStr = String(win.class || "").toLowerCase();
        var winMatched = query.length === 0
          || matchesWsDirectly
          || titleStr.indexOf(query) >= 0
          || classStr.indexOf(query) >= 0;

        if (winMatched) hasMatchingWindow = true;
        windowMatches.push(winMatched);
      }

      var wsMatched = query.length === 0 || matchesWsDirectly || hasMatchingWindow;
      var hasWindows = workspace.windows.length > 0;
      var isSelectable = hasWindows || (!monitorHasWindows && workspace.number === 1);

      rows.push({
        kind: "workspace",
        monitor: root.monitor,
        workspace: workspace,
        matched: wsMatched,
        selectable: isSelectable,
        empty: !hasWindows
      });

      var foldKey1 = root.monitor + ":" + workspace.number;
      var foldKey2 = root.monitor + ":" + workspace.id + ":" + workspace.number;
      var isFolded = Boolean(folds && (folds[foldKey1] === true || folds[foldKey2] === true));

      if (!isFolded && hasWindows) {
        for (var winI = 0; winI < workspace.windows.length; winI++) {
          rows.push({
            kind: "window",
            monitor: root.monitor,
            workspace: workspace,
            window: workspace.windows[winI],
            matched: windowMatches[winI] === true,
            selectable: true,
            empty: false
          });
        }
      }
    }
  }
  return rows;
}

function isRowNavigable(row, searchActive) {
  if (!row || !row.selectable) return false;
  if (searchActive && !row.matched) return false;
  return true;
}

function move(state, delta) {
  if (!state || !state.rows || !state.rows.length) return;
  var rows = state.rows;
  var searchActive = typeof state.search === "string" && state.search.trim().length > 0;
  var direction = delta > 0 ? 1 : -1;
  var steps = Math.abs(delta);
  var current = state.cursor;

  for (var s = 0; s < steps; s++) {
    var candidate = current + direction;
    var found = -1;
    while (candidate >= 0 && candidate < rows.length) {
      if (isRowNavigable(rows[candidate], searchActive)) {
        found = candidate;
        break;
      }
      candidate += direction;
    }
    if (found !== -1) {
      current = found;
    } else {
      break;
    }
  }
  state.cursor = current;
}

function firstSelectable(state) {
  if (!state || !state.rows || !state.rows.length) return 0;
  var searchActive = typeof state.search === "string" && state.search.trim().length > 0;
  for (var i = 0; i < state.rows.length; i++) {
    if (isRowNavigable(state.rows[i], searchActive)) return i;
  }
  return 0;
}

function lastSelectable(state) {
  if (!state || !state.rows || !state.rows.length) return 0;
  var searchActive = typeof state.search === "string" && state.search.trim().length > 0;
  for (var i = state.rows.length - 1; i >= 0; i--) {
    if (isRowNavigable(state.rows[i], searchActive)) return i;
  }
  return 0;
}

function moveToWorkspace(state, monitor, number) {
  if (!state || !state.rows) return -1;
  var num = Number(number);
  for (var i = 0; i < state.rows.length; i++) {
    var row = state.rows[i];
    if (row.kind === "workspace" && row.monitor === monitor && row.workspace.number === num) {
      if (row.selectable) {
        state.cursor = i;
        return i;
      }
      return -1; // Found but empty / not selectable
    }
  }
  return -1;
}

function nextMonitor(state) {
  if (!state || !state.rows || !state.model || !state.model.roots) return;
  var currentRow = state.rows[state.cursor];
  var currentMonitor = currentRow ? currentRow.monitor : "";
  var roots = state.model.roots;
  var currentMonitorIdx = -1;
  for (var m = 0; m < roots.length; m++) {
    if (roots[m].monitor === currentMonitor) {
      currentMonitorIdx = m;
      break;
    }
  }
  var nextIdx = (currentMonitorIdx + 1) % roots.length;
  var targetMonitor = roots[nextIdx].monitor;

  var searchActive = typeof state.search === "string" && state.search.trim().length > 0;
  for (var i = 0; i < state.rows.length; i++) {
    var row = state.rows[i];
    if (row.monitor === targetMonitor && isRowNavigable(row, searchActive)) {
      state.cursor = i;
      return;
    }
  }
}
