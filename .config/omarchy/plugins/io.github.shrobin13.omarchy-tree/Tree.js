.pragma library

function makeState(model) {
  return {
    model: model,
    rows: flatten(model, Object.create(null), ""),
    cursor: 0,
    search: "",
    recordedCursor: 0,
    folds: Object.create(null)
  };
}

function monitorKey(workspace) {
  return workspace.monitor || "";
}

function flatten(model, folds, search) {
  var rows = [];
  var query = String(search || "").toLowerCase();
  if (!model || !Array.isArray(model.roots)) return rows;
  for (var ri = 0; ri < model.roots.length; ri++) {
    var root = model.roots[ri];
    var visibleWorkspaces = 0;
    for (var wi = 0; wi < root.workspaces.length; wi++) {
      var workspace = root.workspaces[wi];
      var matchesWorkspace = query.length === 0
        || String(workspace.number).indexOf(query) >= 0
        || String(workspace.name || "").toLowerCase().indexOf(query) >= 0;
      var matchingWindows = workspace.windows.filter(function (window) {
        if (query.length === 0) return true;
        return String(window.title || "").toLowerCase().indexOf(query) >= 0
          || String(window.class || "").toLowerCase().indexOf(query) >= 0
          || matchesWorkspace;
      });
      if (query.length > 0 && !matchesWorkspace && matchingWindows.length === 0) continue;
      if (workspace.windows.length > 0) visibleWorkspaces++;
      rows.push({
        kind: "workspace",
        monitor: root.monitor,
        workspace: workspace,
        matched: query.length === 0 || matchesWorkspace || matchingWindows.length > 0
      });
      var foldKey = root.monitor + ":" + workspace.id + ":" + workspace.number;
      if (!folds[foldKey] && workspace.windows.length > 0) {
        for (var winIndex = 0; winIndex < matchingWindows.length; winIndex++) {
          rows.push({
            kind: "window",
            monitor: root.monitor,
            workspace: workspace,
            window: matchingWindows[winIndex],
            matched: true
          });
        }
      }
    }
  }
  return rows;
}

function move(state, delta) {
  if (!state.rows.length) return;
  state.cursor = Math.max(0, Math.min(state.rows.length - 1, state.cursor + delta));
}
