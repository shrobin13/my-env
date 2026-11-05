// Model.js: Data normalization, regex helpers, state management, and section grouping for Notification Center

.pragma library

// -----------------------------------------------------------------------------
// 1. REGEX HELPERS: VERIFICATION CODES & URLS
// -----------------------------------------------------------------------------

function extractVerificationCode(summary, body) {
  var text = (summary || "") + " " + (body || "")
  if (!text.trim()) return ""

  // 1. Look for code keywords followed by 4-8 digits
  var m1 = text.match(/(?:code|otp|pin|token|verification|verify|password|auth|login|confirmation)[^0-9\n]{0,25}\b([0-9]{4,8})\b/i)
  if (m1 && m1[1]) return m1[1]

  // 2. Look for 4-8 digits followed by code keywords
  var m2 = text.match(/\b([0-9]{4,8})\b[^0-9\n]{0,25}\b(?:is your|is the)?\s*(?:code|otp|pin|token|verification|confirmation)/i)
  if (m2 && m2[1]) return m2[1]

  return ""
}

function sanitizeUrl(url) {
  if (!url || typeof url !== "string") return ""
  var trimmed = url.trim()
  if (/^https?:\/\/[^\s<>"'{}|\\^`]+(?:\.[^\s<>"'{}|\\^`]+)+(?:\/[^\s<>"'{}|\\`]*)?/i.test(trimmed)) {
    return trimmed.replace(/[.,;:!)]+$/, "")
  }
  return ""
}

function extractUrl(summary, body) {
  var text = (summary || "") + " " + (body || "")
  if (!text.trim()) return ""
  var m = text.match(/\bhttps?:\/\/[^\s<>"'{}|\\^`]+(?:\.[^\s<>"'{}|\\^`]+)+(?:\/[^\s<>"'{}|\\`]*)?/i)
  if (m && m[0]) {
    return sanitizeUrl(m[0])
  }
  return ""
}

// -----------------------------------------------------------------------------
// 2. PARSING & ACTIONS NORMALIZATION
// -----------------------------------------------------------------------------

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

function parseActions(raw) {
  var list = []
  if (!raw) return list

  var acts = raw.actions || raw.actionList
  if (acts && typeof acts.count === "number") {
    for (var m = 0; m < acts.count; m++) {
      var itm = acts.get(m)
      if (itm && (itm.id || itm.label)) {
        list.push({
          id: String(itm.id || itm.key || m),
          label: String(itm.label || itm.text || itm.id || "Action"),
          argv: itm.argv || null
        })
      }
    }
    return list
  }

  if (Array.isArray(acts)) {
    if (acts.length > 0 && typeof acts[0] === "object") {
      for (var i = 0; i < acts.length; i++) {
        if (acts[i] && (acts[i].id || acts[i].label)) {
          list.push({
            id: String(acts[i].id || acts[i].key || i),
            label: String(acts[i].label || acts[i].text || acts[i].id || "Action"),
            argv: acts[i].argv || null
          })
        }
      }
    } else if (acts.length >= 2 && typeof acts[0] === "string") {
      for (var j = 0; j < acts.length; j += 2) {
        list.push({
          id: String(acts[j]),
          label: String(acts[j + 1] || acts[j]),
          argv: null
        })
      }
    }
  }

  if (list.length === 0 && raw.execActions) {
    try {
      var ea = typeof raw.execActions === "string" ? JSON.parse(raw.execActions) : raw.execActions
      if (Array.isArray(ea)) {
        for (var k = 0; k < ea.length; k++) {
          if (ea[k] && ea[k].label) {
            list.push({
              id: "exec_" + k,
              label: String(ea[k].label),
              argv: ea[k].argv || null
            })
          }
        }
      }
    } catch(e) {}
  }

  if (list.length === 0 && raw.execArgv && raw.execArgv.length > 2) {
    list.push({
      id: "default",
      label: "Open",
      argv: raw.execArgv
    })
  }

  return list
}

function supportsReply(item) {
  if (!item) return false
  if (item.hasReply === true) return true

  var real = parseActions(item)
  for (var i = 0; i < real.length; i++) {
    var id = (real[i].id || "").toLowerCase()
    var lbl = (real[i].label || "").toLowerCase()
    if (id.indexOf("reply") >= 0 || lbl === "reply") return true
  }

  var app = (item.app || "").toLowerCase()
  var messagingApps = ["telegram", "slack", "discord", "signal", "whatsapp", "messages", "sms", "element", "matrix", "chat"]
  for (var j = 0; j < messagingApps.length; j++) {
    if (app.indexOf(messagingApps[j]) >= 0) return true
  }

  return false
}

function getCardActions(item) {
  if (!item) {
    return { direct: [], more: [], total: 0 }
  }

  var all = []
  var seenLabels = {}

  // 1. Smart Verification Code action
  var code = extractVerificationCode(item.summary, item.body)
  if (code) {
    var codeAction = { id: "smart_copy_code", label: "Copy " + code, kind: "code", value: code }
    all.push(codeAction)
    seenLabels[codeAction.label] = true
  }

  // 2. Smart URL action
  var url = extractUrl(item.summary, item.body) || item.link
  if (url) {
    var urlAction = { id: "smart_open_url", label: "Open link", kind: "url", value: url }
    all.push(urlAction)
    seenLabels[urlAction.label] = true
  }

  // 3. Real notification actions
  var realActions = parseActions(item)
  for (var i = 0; i < realActions.length; i++) {
    var act = realActions[i]
    if (!seenLabels[act.label]) {
      all.push(act)
      seenLabels[act.label] = true
    }
  }

  // Split into up to 2 direct buttons, and the rest into more menu
  var direct = []
  var more = []
  if (all.length <= 2) {
    direct = all
  } else {
    direct = all.slice(0, 2)
    more = all.slice(2)
  }

  return {
    direct: direct,
    more: more,
    total: all.length,
    code: code,
    url: url
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
  var link = String(raw.link || "")

  // Progress detection
  var progress = -1
  if (typeof raw.progress === "number") progress = raw.progress
  else if (typeof raw.value === "number") progress = raw.value
  else if (raw.hints && typeof raw.hints["value"] === "number") progress = raw.hints["value"]
  else if (raw.hints && typeof raw.hints["x-canonical-progress"] === "number") progress = raw.hints["x-canonical-progress"]

  var eta = String(raw.eta || (raw.hints && raw.hints["eta"]) || "")
  var hasReply = raw.hasReply === true || (raw.hints && raw.hints["inline-reply"] === true)

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
    execActions: raw.execActions || "",
    actions: raw.actions || raw.actionList || [],
    link: link,
    progress: progress,
    eta: eta,
    hasReply: hasReply,
    isLive: !!isLive
  }
}

function parseNotifications(liveText, historyText) {
  var liveList = parseList(liveText)
  var historyList = parseList(historyText)
  var out = []
  var seenKeys = Object.create(null)

  for (var i = 0; i < liveList.length; i++) {
    var item = normalizeItem(liveList[i], true)
    if (item && !seenKeys[item.key]) {
      seenKeys[item.key] = true
      out.push(item)
    }
  }

  for (var j = 0; j < historyList.length; j++) {
    var hItem = normalizeItem(historyList[j], false)
    if (hItem && !seenKeys[hItem.key]) {
      seenKeys[hItem.key] = true
      out.push(hItem)
    }
  }

  out.sort(function(a, b) {
    return (b.ts || 0) - (a.ts || 0)
  })

  return out
}

// -----------------------------------------------------------------------------
// 3. STATE PERSISTENCE (PINNED, SNOOZED, MUTED APPS, READ STATUS, FOCUS)
// -----------------------------------------------------------------------------

function defaultUserState() {
  return {
    pinned: {},
    snoozed: {},
    mutedApps: {},
    readKeys: {},
    focusUntil: 0
  }
}

function parseUserState(text) {
  if (!text || typeof text !== "string") return defaultUserState()
  try {
    var s = JSON.parse(text)
    if (s && typeof s === "object") {
      return {
        pinned: (s.pinned && typeof s.pinned === "object" && s.pinned !== null) ? s.pinned : {},
        snoozed: (s.snoozed && typeof s.snoozed === "object" && s.snoozed !== null) ? s.snoozed : {},
        mutedApps: (s.mutedApps && typeof s.mutedApps === "object" && s.mutedApps !== null) ? s.mutedApps : {},
        readKeys: (s.readKeys && typeof s.readKeys === "object" && s.readKeys !== null) ? s.readKeys : {},
        focusUntil: Number(s.focusUntil || 0)
      }
    }
  } catch(e) {}
  return defaultUserState()
}

function serializeUserState(state) {
  return JSON.stringify(state || defaultUserState(), null, 2)
}

function isPinned(state, key) {
  return !!(state && state.pinned && state.pinned[key])
}

function isSnoozed(state, key, nowSec) {
  if (!state || !state.snoozed || !state.snoozed[key]) return false
  var until = Number(state.snoozed[key])
  return isFinite(until) && until > (nowSec || (Date.now() / 1000))
}

function countSnoozed(items, state, nowSec) {
  nowSec = nowSec || (Date.now() / 1000)
  var count = 0
  for (var i = 0; i < items.length; i++) {
    if (isSnoozed(state, items[i].key, nowSec)) count++
  }
  return count
}

function isMuted(state, app) {
  return !!(state && state.mutedApps && state.mutedApps[app])
}

function isRead(state, key) {
  return !!(state && state.readKeys && state.readKeys[key])
}

// -----------------------------------------------------------------------------
// 4. SECTION CLASSIFICATION & GROUPING
// -----------------------------------------------------------------------------

function isSameDay(ts1, ts2) {
  var d1 = new Date(ts1 * 1000)
  var d2 = new Date(ts2 * 1000)
  return d1.getFullYear() === d2.getFullYear() &&
         d1.getMonth() === d2.getMonth() &&
         d1.getDate() === d2.getDate()
}

function classifySection(item, state) {
  var pinned = isPinned(state, item.key)
  if (pinned || item.urgency === 2) {
    return "Needs attention"
  }
  var nowSec = Date.now() / 1000
  if (isSameDay(item.ts, nowSec)) {
    return "Today"
  }
  return "Earlier"
}

function sectionWeight(section) {
  if (section === "Needs attention") return 1
  if (section === "Today") return 2
  return 3
}

// Filters list by search, chip filter, snoozed and muted states
function filterNotifications(items, state, activeFilter, searchQuery, nowSec, unreadAtOpen) {
  nowSec = nowSec || (Date.now() / 1000)
  var q = (searchQuery || "").trim().toLowerCase()
  var out = []

  for (var i = 0; i < items.length; i++) {
    var item = items[i]
    if (!item) continue

    var currentlySnoozed = isSnoozed(state, item.key, nowSec)
    var snoozeExpired = !currentlySnoozed && (state && state.snoozed && state.snoozed[item.key] && Number(state.snoozed[item.key]) <= nowSec)

    // Snoozed chip filter handling
    if (activeFilter === "Snoozed") {
      if (!currentlySnoozed) continue
    } else {
      if (currentlySnoozed) continue
      // Skip muted applications only when not looking at snoozed
      if (isMuted(state, item.app)) continue
    }

    // Search query matching
    if (q) {
      var inApp = (item.app || "").toLowerCase().indexOf(q) >= 0
      var inSum = (item.summary || "").toLowerCase().indexOf(q) >= 0
      var inBody = (item.body || "").toLowerCase().indexOf(q) >= 0
      if (!inApp && !inSum && !inBody) continue
    }

    // Determine read status: expired snooze returns as unread
    var read = snoozeExpired ? false : isRead(state, item.key)
    var pinned = isPinned(state, item.key)

    // Unread filter handling: respects unreadAtOpen snapshot so items don't vanish while open
    if (activeFilter === "Unread") {
      var wasUnreadAtOpen = unreadAtOpen && Boolean(unreadAtOpen[item.key])
      if (read && !wasUnreadAtOpen && !snoozeExpired) continue
    } else if (activeFilter === "Urgent") {
      if (item.urgency !== 2) continue
    } else if (activeFilter === "Messages") {
      if (!supportsReply(item)) continue
    } else if (activeFilter === "Pinned") {
      if (!pinned) continue
    }

    // Attach section property for ListView
    var clone = Object.assign({}, item)
    clone.sectionName = classifySection(item, state)
    clone.isRead = read
    clone.isPinned = pinned
    clone.isSnoozed = currentlySnoozed
    clone.effectiveTs = snoozeExpired ? Math.max(item.ts || 0, Number(state.snoozed[item.key])) : (item.ts || 0)
    out.push(clone)
  }

  // Sort: Section priority first, then effective timestamp descending
  out.sort(function(a, b) {
    var wA = sectionWeight(a.sectionName)
    var wB = sectionWeight(b.sectionName)
    if (wA !== wB) return wA - wB
    return (b.effectiveTs || b.ts || 0) - (a.effectiveTs || a.ts || 0)
  })

  return out
}

// Groups notifications by app if an app has 3 or more items within each section
function groupNotifications(items, expandedApps) {
  expandedApps = expandedApps || {}

  // 1. Partition by section to ensure groups never span across sections
  var sectionGroups = {}
  var sectionOrder = []
  for (var i = 0; i < items.length; i++) {
    var sec = items[i].sectionName || "Today"
    if (!sectionGroups[sec]) {
      sectionGroups[sec] = []
      sectionOrder.push(sec)
    }
    sectionGroups[sec].push(items[i])
  }

  var out = []
  for (var s = 0; s < sectionOrder.length; s++) {
    var secItems = sectionGroups[sectionOrder[s]]
    var appCounts = {}
    for (var a = 0; a < secItems.length; a++) {
      var app = secItems[a].app || "Other"
      appCounts[app] = (appCounts[app] || 0) + 1
    }

    var seenGroupLeaders = {}
    for (var j = 0; j < secItems.length; j++) {
      var it = secItems[j]
      var appName = it.app || "Other"
      var totalForApp = appCounts[appName] || 0

      if (totalForApp >= 3) {
        if (!seenGroupLeaders[appName]) {
          seenGroupLeaders[appName] = true
          var isExpanded = !!expandedApps[appName]
          var leader = Object.assign({}, it)
          leader.isGroupHeader = true
          leader.groupTotal = totalForApp
          leader.groupExtraCount = totalForApp - 1
          leader.groupExpanded = isExpanded
          out.push(leader)
        } else if (expandedApps[appName]) {
          var child = Object.assign({}, it)
          child.isGroupHeader = false
          child.isGroupChild = true
          out.push(child)
        }
      } else {
        out.push(it)
      }
    }
  }

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
