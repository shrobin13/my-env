// Model.js: Data normalization, time formatting, and icon resolution for Notification Center

.pragma library

function parseList(text) {
  if (!text || typeof text !== "string") return []
  var trimmed = text.trim()
  if (!trimmed || trimmed === "[]") return []
  try {
    var parsed = JSON.parse(trimmed)
    return Array.isArray(parsed) ? parsed : []
  } catch (e) {
    return []
  }
}

function normalizeItem(raw, isLive) {
  if (!raw || typeof raw !== "object") return null
  var key = String(raw.key || "").trim()
  if (!key) return null

  var summary = String(raw.summary || "").slice(0, 500)
  var body = String(raw.body || raw.rawBody || "").slice(0, 2000)
  var app = String(raw.app || raw.source || "System").slice(0, 100)
  var appIcon = String(raw.appIcon || "").slice(0, 256)
  var glyph = String(raw.glyph || "").slice(0, 32)
  var urgency = typeof raw.urgency === "number" ? raw.urgency : 1
  var ts = typeof raw.ts === "number" ? raw.ts : (Date.now() / 1000)
  var execArgv = String(raw.execArgv || "")

  return {
    key: key,
    summary: summary,
    body: body,
    app: app,
    appIcon: appIcon,
    glyph: glyph,
    urgency: urgency,
    ts: ts,
    execArgv: execArgv,
    isLive: !!isLive,
    hasAction: execArgv.length > 2
  }
}

function parseNotifications(liveText, historyText) {
  var liveList = parseList(liveText)
  var historyList = parseList(historyText)
  var out = []
  var seenKeys = Object.create(null)

  // Live notifications first (active/unclosed)
  for (var i = 0; i < liveList.length; i++) {
    var item = normalizeItem(liveList[i], true)
    if (item && !seenKeys[item.key]) {
      seenKeys[item.key] = true
      out.push(item)
    }
  }

  // Then closed notifications from history
  for (var j = 0; j < historyList.length; j++) {
    var hItem = normalizeItem(historyList[j], false)
    if (hItem && !seenKeys[hItem.key]) {
      seenKeys[hItem.key] = true
      out.push(hItem)
    }
  }

  // Sort newest first by timestamp
  out.sort(function(a, b) {
    return (b.ts || 0) - (a.ts || 0)
  })

  return out
}

function formatRelativeTime(ts) {
  if (!ts) return ""
  var now = Date.now() / 1000
  var diff = Math.max(0, Math.floor(now - ts))
  if (diff < 45) return "Just now"
  if (diff < 3600) return Math.floor(diff / 60) + "m ago"
  if (diff < 86400) return Math.floor(diff / 3600) + "h ago"
  return Math.floor(diff / 86400) + "d ago"
}

function iconGlyphFor(item) {
  if (!item) return "\uf0f3"
  if (item.glyph && item.glyph.length > 0) return item.glyph

  var name = (item.app + " " + item.appIcon + " " + item.summary).toLowerCase()
  if (name.indexOf("chrome") >= 0 || name.indexOf("chromium") >= 0 || name.indexOf("browser") >= 0) return "\udb80\udeaf"
  if (name.indexOf("kitty") >= 0 || name.indexOf("foot") >= 0 || name.indexOf("terminal") >= 0 || name.indexOf("alacritty") >= 0) return "\ue795"
  if (name.indexOf("code") >= 0 || name.indexOf("vsc") >= 0) return "\udb82\ude1e"
  if (name.indexOf("git") >= 0) return "\uf09b"
  if (name.indexOf("wifi") >= 0 || name.indexOf("network") >= 0) return "\udb81\udda9"
  if (name.indexOf("bluetooth") >= 0) return "\udb80\udcb0"
  if (name.indexOf("audio") >= 0 || name.indexOf("volume") >= 0 || name.indexOf("sound") >= 0) return "\udb81\udd7e"
  if (name.indexOf("music") >= 0 || name.indexOf("spotify") >= 0) return "\udb81\udf5a"
  if (name.indexOf("update") >= 0) return "\uf021"
  if (name.indexOf("fingerprint") >= 0) return "\udb80\ude37"
  if (name.indexOf("keybinding") >= 0 || name.indexOf("keyboard") >= 0) return "\uf11c"
  if (name.indexOf("agent") >= 0) return "\udb81\udea9"

  return "\uf0f3"
}
