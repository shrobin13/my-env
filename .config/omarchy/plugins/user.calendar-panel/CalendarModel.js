// Pure JavaScript calendar & agenda math model for user.calendar-panel
// Designed to be Qt-, locale-, and Node-compatible for testing and production.

var MS_PER_DAY = 86400000;
var MAX_PARSED_EVENTS = 2000;
var MAX_RRULE_OCCURRENCES = 180;

var WEEKDAY_NAMES_FULL = [
  "SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"
];

var WEEKDAY_NAMES_SHORT = [
  "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"
];

var WEEKDAY_NAMES_TITLE = [
  "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"
];

var MONTH_NAMES_FULL = [
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December"
];

var MONTH_NAMES_SHORT = [
  "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
];

function pad2(value) {
  var n = Number(value);
  return (n < 10 ? "0" : "") + n;
}

function dateKey(year, month, day) {
  return year + "-" + pad2(Number(month) + 1) + "-" + pad2(day);
}

function keyForDate(date) {
  return dateKey(date.getFullYear(), date.getMonth(), date.getDate());
}

function isLeapYear(year) {
  var y = Number(year);
  return (y % 4 === 0 && y % 100 !== 0) || (y % 400 === 0);
}

function daysInYear(year) {
  return isLeapYear(year) ? 366 : 365;
}

function dayOfYear(year, month, day) {
  return Math.round((Date.UTC(year, month, day) - Date.UTC(year, 0, 1)) / MS_PER_DAY) + 1;
}

function daysRemaining(year, month, day) {
  var total = daysInYear(year);
  var current = dayOfYear(year, month, day);
  return Math.max(0, total - current);
}

function yearProgress(year, month, day) {
  var total = daysInYear(year);
  if (total <= 0) return 0;
  return Math.max(0, Math.min(1, (dayOfYear(year, month, day) - 1) / total));
}

function isoWeek(year, month, day) {
  var date = new Date(Date.UTC(year, month, day));
  var weekday = date.getUTCDay() || 7;
  date.setUTCDate(date.getUTCDate() + 4 - weekday);
  var yearStart = new Date(Date.UTC(date.getUTCFullYear(), 0, 1));
  return Math.ceil(((date.getTime() - yearStart.getTime()) / MS_PER_DAY + 1) / 7);
}

function stepMonth(year, month, delta) {
  var target = new Date(Date.UTC(year, Number(month) + Number(delta), 1));
  return { year: target.getUTCFullYear(), month: target.getUTCMonth() };
}

function normalizedWeekStart(value) {
  if (typeof value === "number") {
    return ((Math.round(value) % 7) + 7) % 7;
  }
  var s = String(value || "").trim().toLowerCase();
  if (s === "monday" || s === "mon" || s === "1") return 1;
  return 0; // Default to Sunday (0)
}

function weekdayOrder(weekStart) {
  var start = normalizedWeekStart(weekStart);
  var out = [];
  for (var i = 0; i < 7; i++) {
    out.push((start + i) % 7);
  }
  return out;
}

function monthGrid(year, month, weekStart, todayKey, eventsMap) {
  var start = normalizedWeekStart(weekStart);
  var firstDayWeekday = new Date(Date.UTC(year, month, 1)).getUTCDay();
  var leading = (firstDayWeekday - start + 7) % 7;
  var daysInCurrentMonth = new Date(Date.UTC(year, month + 1, 0)).getUTCDate();

  var totalDays = leading + daysInCurrentMonth;
  // Use 5 or 6 rows depending on whether days overflow 35
  var rowCount = totalDays > 35 ? 6 : (totalDays > 28 ? 5 : 4);
  if (rowCount < 5) rowCount = 5;

  var cursor = new Date(Date.UTC(year, month, 1 - leading));
  var today = String(todayKey || "");
  var weeks = [];

  for (var w = 0; w < rowCount; w++) {
    var days = [];
    var thursday = null;
    for (var d = 0; d < 7; d++) {
      var cellYear = cursor.getUTCFullYear();
      var cellMonth = cursor.getUTCMonth();
      var cellDay = cursor.getUTCDate();
      var weekday = cursor.getUTCDay();
      var key = dateKey(cellYear, cellMonth, cellDay);

      if (weekday === 4) {
        thursday = { year: cellYear, month: cellMonth, day: cellDay };
      }

      var hasEvents = !!(eventsMap && eventsMap[key] && eventsMap[key].length > 0);

      days.push({
        key: key,
        year: cellYear,
        month: cellMonth,
        day: cellDay,
        weekday: weekday,
        inMonth: cellMonth === month && cellYear === year,
        weekend: weekday === 0 || weekday === 6,
        today: key === today,
        hasEvents: hasEvents
      });
      cursor.setUTCDate(cursor.getUTCDate() + 1);
    }

    var anchor = thursday || days[0];
    weeks.push({
      week: isoWeek(anchor.year, anchor.month, anchor.day),
      days: days
    });
  }

  return weeks;
}

function formatHeaderAbove(date) {
  var d = date || new Date();
  var dayName = WEEKDAY_NAMES_FULL[d.getDay()] || "TODAY";
  var weekNum = isoWeek(d.getFullYear(), d.getMonth(), d.getDate());
  return dayName + " · WEEK " + weekNum;
}

function formatHeaderDate(date) {
  var d = date || new Date();
  var monthName = MONTH_NAMES_FULL[d.getMonth()] || "";
  return monthName + " " + d.getDate();
}

function formatClockTime(date, is24h) {
  var d = date || new Date();
  var hours = d.getHours();
  var mins = pad2(d.getMinutes());
  if (is24h) {
    return pad2(hours) + ":" + mins;
  }
  var h = hours % 12 || 12;
  var ampm = hours >= 12 ? "PM" : "AM";
  return h + ":" + mins + " " + ampm;
}

function formatBarDate(date) {
  var d = date || new Date();
  var dayName = WEEKDAY_NAMES_TITLE[d.getDay()] || "";
  var monthName = MONTH_NAMES_SHORT[d.getMonth()] || "";
  return dayName + " " + d.getDate() + " " + monthName;
}

function formatTimerSeconds(seconds) {
  var s = Math.max(0, Math.floor(Number(seconds) || 0));
  var mins = Math.floor(s / 60);
  var remSecs = s % 60;
  return pad2(mins) + ":" + pad2(remSecs);
}

function parseIcsDate(raw) {
  if (!raw) return null;
  var str = String(raw).trim();
  var match = str.match(/^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})?(Z)?)?$/);
  if (!match) return null;

  var y = parseInt(match[1], 10);
  var m = parseInt(match[2], 10) - 1;
  var d = parseInt(match[3], 10);
  var hasTime = match[4] !== undefined;
  var h = hasTime ? parseInt(match[4], 10) : 0;
  var min = hasTime ? parseInt(match[5], 10) : 0;
  var sec = match[6] ? parseInt(match[6], 10) : 0;
  var isUtc = match[7] === "Z";

  if (isUtc) {
    return new Date(Date.UTC(y, m, d, h, min, sec));
  }
  return new Date(y, m, d, h, min, sec);
}

function parseRrule(rruleStr) {
  if (!rruleStr) return null;
  var parts = String(rruleStr).split(";");
  var rule = { freq: "", interval: 1, count: 0, until: null };
  for (var i = 0; i < parts.length; i++) {
    var kv = parts[i].split("=");
    if (kv.length !== 2) continue;
    var k = kv[0].trim().toUpperCase();
    var v = kv[1].trim();
    if (k === "FREQ") rule.freq = v.toUpperCase();
    else if (k === "INTERVAL") rule.interval = Math.max(1, Math.min(365, parseInt(v, 10) || 1));
    else if (k === "COUNT") rule.count = Math.max(0, Math.min(MAX_RRULE_OCCURRENCES, parseInt(v, 10) || 0));
    else if (k === "UNTIL") rule.until = parseIcsDate(v);
  }
  return rule.freq ? rule : null;
}

function advanceDateByRrule(date, rule) {
  var next = new Date(date.getTime());
  if (rule.freq === "DAILY") next.setDate(next.getDate() + rule.interval);
  else if (rule.freq === "WEEKLY") next.setDate(next.getDate() + 7 * rule.interval);
  else if (rule.freq === "MONTHLY") next.setMonth(next.getMonth() + rule.interval);
  else if (rule.freq === "YEARLY") next.setFullYear(next.getFullYear() + rule.interval);
  else return null;
  return next;
}

function unescapeIcsText(val) {
  return String(val || "")
    .replace(/\\n/gi, " ")
    .replace(/\\,/g, ",")
    .replace(/\\;/g, ";")
    .replace(/\\\\/g, "\\")
    .replace(/\s+/g, " ")
    .trim();
}

function parseIcs(icsText, options) {
  var eventsMap = {};
  if (!icsText || typeof icsText !== "string") return eventsMap;

  var opts = options || {};
  var defaultColor = opts.color || "#f2b45a";
  var source = opts.source || "local";
  var is24h = !!opts.is24h;
  var now = opts.now || new Date();
  var windowStart = opts.windowStart || new Date(now.getFullYear(), now.getMonth() - 2, 1);
  var windowEnd = opts.windowEnd || new Date(now.getFullYear() + 1, now.getMonth(), 28);

  // Unfold folded lines (RFC 5545 CRLF followed by space or tab)
  var clean = icsText.replace(/\r\n[ \t]/g, "").replace(/\n[ \t]/g, "");
  var lines = clean.split(/\r?\n/);
  var inEvent = false;
  var current = {};
  var totalAdded = 0;

  function pushOccurrence(occStart, durationMs, ev) {
    if (totalAdded >= MAX_PARSED_EVENTS) return;
    var daySpan = 1;
    if (ev.isAllDay && durationMs > MS_PER_DAY) {
      daySpan = Math.min(31, Math.round(durationMs / MS_PER_DAY));
    }

    var occEnd = durationMs > 0 ? new Date(occStart.getTime() + durationMs) : null;
    var timeRange = "";
    var sortMinutes = -1;
    if (ev.isAllDay) {
      timeRange = "All day";
      sortMinutes = -1;
    } else if (occEnd) {
      timeRange = formatClockTime(occStart, is24h) + " - " + formatClockTime(occEnd, is24h);
      sortMinutes = occStart.getHours() * 60 + occStart.getMinutes();
    } else {
      timeRange = formatClockTime(occStart, is24h);
      sortMinutes = occStart.getHours() * 60 + occStart.getMinutes();
    }

    for (var dOff = 0; dOff < daySpan; dOff++) {
      var dCursor = new Date(occStart.getFullYear(), occStart.getMonth(), occStart.getDate() + dOff);
      var k = dateKey(dCursor.getFullYear(), dCursor.getMonth(), dCursor.getDate());
      if (!eventsMap[k]) eventsMap[k] = [];
      eventsMap[k].push({
        uid: String(ev.uid || "").slice(0, 128),
        title: String(ev.summary || "").slice(0, 200),
        timeRange: timeRange,
        sortMinutes: sortMinutes,
        color: defaultColor,
        source: source,
        isAllDay: !!ev.isAllDay,
        description: String(ev.description || "").slice(0, 500)
      });
      totalAdded++;
      if (totalAdded >= MAX_PARSED_EVENTS) break;
    }
  }

  for (var i = 0; i < lines.length; i++) {
    if (totalAdded >= MAX_PARSED_EVENTS) break;
    var line = lines[i].trim();
    if (line === "BEGIN:VEVENT") {
      inEvent = true;
      current = {};
    } else if (line === "END:VEVENT") {
      inEvent = false;
      if (current.summary && current.dtStart) {
        var startDate = parseIcsDate(current.dtStart);
        if (startDate) {
          var endDate = current.dtEnd ? parseIcsDate(current.dtEnd) : null;
          var durationMs = endDate ? Math.max(0, endDate.getTime() - startDate.getTime()) : 0;
          var rule = parseRrule(current.rrule);

          if (!rule) {
            pushOccurrence(startDate, durationMs, current);
          } else {
            var occ = new Date(startDate.getTime());
            var count = 0;
            while (occ && count < MAX_RRULE_OCCURRENCES) {
              if (rule.count > 0 && count >= rule.count) break;
              if (rule.until && occ.getTime() > rule.until.getTime()) break;
              if (occ.getTime() > windowEnd.getTime()) break;
              if (occ.getTime() >= windowStart.getTime()) {
                pushOccurrence(occ, durationMs, current);
              }
              count++;
              occ = advanceDateByRrule(occ, rule);
            }
          }
        }
      }
    } else if (inEvent) {
      var colonIdx = line.indexOf(":");
      if (colonIdx > 0) {
        var propHeader = line.substring(0, colonIdx);
        var val = line.substring(colonIdx + 1);
        var propParts = propHeader.split(";");
        var propName = propParts[0].toUpperCase();

        if (propName === "SUMMARY") {
          current.summary = unescapeIcsText(val);
        } else if (propName === "UID") {
          current.uid = val.trim();
        } else if (propName === "DTSTART") {
          current.dtStart = val;
          if (/^\d{8}$/.test(val.trim()) || propHeader.toUpperCase().indexOf("VALUE=DATE") !== -1) {
            current.isAllDay = true;
          }
        } else if (propName === "DTEND") {
          current.dtEnd = val;
        } else if (propName === "RRULE") {
          current.rrule = val;
        } else if (propName === "DESCRIPTION") {
          current.description = unescapeIcsText(val);
        }
      }
    }
  }

  return eventsMap;
}

function mergeEventsMaps(mapList) {
  var merged = {};
  if (!Array.isArray(mapList)) return merged;

  for (var m = 0; m < mapList.length; m++) {
    var src = mapList[m];
    if (!src) continue;
    for (var key in src) {
      var list = src[key];
      if (!Array.isArray(list)) continue;
      if (!merged[key]) merged[key] = [];
      for (var i = 0; i < list.length; i++) {
        merged[key].push(list[i]);
      }
    }
  }

  for (var k in merged) {
    merged[k].sort(function(a, b) {
      return (a.sortMinutes || 0) - (b.sortMinutes || 0);
    });
  }
  return merged;
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    pad2: pad2,
    dateKey: dateKey,
    keyForDate: keyForDate,
    isLeapYear: isLeapYear,
    daysInYear: daysInYear,
    dayOfYear: dayOfYear,
    daysRemaining: daysRemaining,
    yearProgress: yearProgress,
    isoWeek: isoWeek,
    stepMonth: stepMonth,
    normalizedWeekStart: normalizedWeekStart,
    weekdayOrder: weekdayOrder,
    monthGrid: monthGrid,
    formatHeaderAbove: formatHeaderAbove,
    formatHeaderDate: formatHeaderDate,
    formatClockTime: formatClockTime,
    formatBarDate: formatBarDate,
    formatTimerSeconds: formatTimerSeconds,
    parseIcsDate: parseIcsDate,
    parseIcs: parseIcs,
    mergeEventsMaps: mergeEventsMaps,
    WEEKDAY_NAMES_FULL: WEEKDAY_NAMES_FULL,
    WEEKDAY_NAMES_SHORT: WEEKDAY_NAMES_SHORT,
    MONTH_NAMES_FULL: MONTH_NAMES_FULL,
    MONTH_NAMES_SHORT: MONTH_NAMES_SHORT
  };
}
