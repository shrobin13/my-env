const assert = require("assert");
const M = require("../CalendarModel.js");

console.log("Running CalendarModel unit tests...");

// Test 1: Leap year check
assert.strictEqual(M.isLeapYear(2024), true, "2024 is a leap year");
assert.strictEqual(M.isLeapYear(2026), false, "2026 is not a leap year");
assert.strictEqual(M.isLeapYear(2000), true, "2000 is a leap year");
assert.strictEqual(M.isLeapYear(1900), false, "1900 is not a leap year");

assert.strictEqual(M.daysInYear(2026), 365);
assert.strictEqual(M.daysInYear(2024), 366);

// Test 2: Specific date calculations (November 26, 2026)
// Nov 26 in 2026:
// Jan: 31, Feb: 28, Mar: 31, Apr: 30, May: 31, Jun: 30, Jul: 31, Aug: 31, Sep: 30, Oct: 31 = 304 days
// 304 + 26 = 330
const day330 = M.dayOfYear(2026, 10, 26);
assert.strictEqual(day330, 330, "Day of year for 2026-11-26 must be 330");

const left35 = M.daysRemaining(2026, 10, 26);
assert.strictEqual(left35, 35, "Days remaining for 2026-11-26 must be 35");
assert.strictEqual(day330 + left35, 365, "Total days must add up to 365");

// Test 3: ISO Week number
// Nov 26, 2026 is Thursday in Week 48
const w48 = M.isoWeek(2026, 10, 26);
assert.strictEqual(w48, 48, "2026-11-26 is ISO week 48");

const headerAbove = M.formatHeaderAbove(new Date(2026, 10, 26));
assert.strictEqual(headerAbove, "THURSDAY · WEEK 48");

const headerDate = M.formatHeaderDate(new Date(2026, 10, 26));
assert.strictEqual(headerDate, "November 26");

// Test 4: Bar date formatting
const barDate = M.formatBarDate(new Date(2026, 10, 26));
assert.strictEqual(barDate, "Thu 26 Nov");

// Test 5: Month grid generation
// Case A: 5-row month (e.g. November 2026: starts Sunday, 30 days = 30 cells <= 35 -> 5 rows)
const nov2026 = M.monthGrid(2026, 10, 0, "2026-11-26", {});
assert.strictEqual(nov2026.length, 5, "November 2026 with Sunday start needs 5 rows");
assert.strictEqual(nov2026[0].days[0].day, 1, "Nov 1 is Sunday");
assert.strictEqual(nov2026[0].days[0].inMonth, true);

// Check today highlight in Nov 2026
let todayCellFound = false;
nov2026.forEach(w => {
  w.days.forEach(d => {
    if (d.today) {
      todayCellFound = true;
      assert.strictEqual(d.key, "2026-11-26");
      assert.strictEqual(d.day, 26);
    }
  });
});
assert.strictEqual(todayCellFound, true, "Today cell was flagged");

// Case B: 6-row month (e.g. May 2026: May 1 is Friday. With Sunday start, leading = 5 days. 5 + 31 = 36 cells > 35 -> 6 rows)
const may2026 = M.monthGrid(2026, 4, 0, "", {});
assert.strictEqual(may2026.length, 6, "May 2026 with Sunday start needs 6 rows (36 cells)");
assert.strictEqual(may2026[0].days[5].day, 1, "May 1 is Friday");
assert.strictEqual(may2026[0].days[5].inMonth, true);
assert.strictEqual(may2026[0].days[0].inMonth, false, "April days are other-month");

// Case C: Leap-year February (Feb 2024: 29 days, starts Thursday. Leading=4. 4+29 = 33 <= 35 -> 5 rows)
const feb2024 = M.monthGrid(2024, 1, 0, "", {});
assert.strictEqual(feb2024.length, 5, "Feb 2024 has 5 rows");
let has29 = false;
feb2024.forEach(w => w.days.forEach(d => { if (d.inMonth && d.day === 29) has29 = true; }));
assert.strictEqual(has29, true, "Feb 2024 has 29th day");

// Test 6: ICS parsing
const sampleIcs = `BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Test//EN
BEGIN:VEVENT
UID:12345
DTSTART:20261126T100000Z
DTEND:20261126T113000Z
SUMMARY:Sprint Retrospective
DESCRIPTION:Weekly retro meeting
END:VEVENT
BEGIN:VEVENT
UID:67890
DTSTART:20261127T140000Z
DTEND:20261127T150000Z
SUMMARY:Design Review
END:VEVENT
END:VCALENDAR`;

const events = M.parseIcs(sampleIcs);
assert(events["2026-11-26"], "Has event for 2026-11-26");
assert.strictEqual(events["2026-11-26"][0].title, "Sprint Retrospective");
assert(events["2026-11-27"], "Has event for 2026-11-27");
assert.strictEqual(events["2026-11-27"][0].title, "Design Review");

// Test 7: Timer formatting
assert.strictEqual(M.formatTimerSeconds(1500), "25:00");
assert.strictEqual(M.formatTimerSeconds(59), "00:59");
assert.strictEqual(M.formatTimerSeconds(0), "00:00");

// Test 8: Comprehensive month navigation and 6-row / 5-row edge cases
// March 2026: March 1 is Sunday. Days = 31. With Sunday start, leading = 0, 31 cells -> 5 rows
const mar2026 = M.monthGrid(2026, 2, 0, "", {});
assert.strictEqual(mar2026.length, 5, "March 2026 starts on Sunday and needs 5 rows");
assert.strictEqual(mar2026[0].days[0].day, 1, "Mar 1 is Sunday");
assert.strictEqual(mar2026[4].days[2].day, 31, "Mar 31 is Tuesday in 5th row");

// August 2026: Aug 1 is Saturday. Days = 31. Leading = 6. 6 + 31 = 37 cells -> 6 rows!
const aug2026 = M.monthGrid(2026, 7, 0, "", {});
assert.strictEqual(aug2026.length, 6, "August 2026 starts on Saturday and needs 6 rows");
assert.strictEqual(aug2026[0].days[6].day, 1, "Aug 1 is Saturday");
assert.strictEqual(aug2026[5].days[1].day, 31, "Aug 31 is Monday in 6th row");

// Month navigation crossing year boundaries
const decToJan = M.stepMonth(2026, 11, 1);
assert.strictEqual(decToJan.year, 2027);
assert.strictEqual(decToJan.month, 0);

const janToDec = M.stepMonth(2026, 0, -1);
assert.strictEqual(janToDec.year, 2025);
assert.strictEqual(janToDec.month, 11);

// Test 9: Multiple events on a single day
const multiEventIcs = `BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
DTSTART:20261126T090000Z
DTEND:20261126T100000Z
SUMMARY:Standup
END:VEVENT
BEGIN:VEVENT
DTSTART:20261126T110000Z
DTEND:20261126T120000Z
SUMMARY:1:1 Sync
END:VEVENT
BEGIN:VEVENT
DTSTART:20261126T140000Z
DTEND:20261126T153000Z
SUMMARY:Architecture Review
END:VEVENT
END:VCALENDAR`;

const multiEvents = M.parseIcs(multiEventIcs);
assert.strictEqual(multiEvents["2026-11-26"].length, 3, "Day with several events returns all 3 events");
assert.strictEqual(multiEvents["2026-11-26"][0].title, "Standup");
assert.strictEqual(multiEvents["2026-11-26"][1].title, "1:1 Sync");
assert.strictEqual(multiEvents["2026-11-26"][2].title, "Architecture Review");

// Day with no events
assert.strictEqual(multiEvents["2026-11-28"], undefined, "Day with no events returns undefined/empty");

// Test 10: Week start on Monday vs Sunday
const nov2026Mon = M.monthGrid(2026, 10, 1, "", {});
assert.strictEqual(nov2026Mon[0].days[6].day, 1, "Nov 1 is Sunday (last column when week starts Monday)");

// Test 11: Google Calendar ICS features (all-day VALUE=DATE, multi-day, RRULE weekly, merging, sorting)
const gcalIcs = `BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:gcal-1
DTSTART;VALUE=DATE:20261126
DTEND;VALUE=DATE:20261128
SUMMARY:Two Day Summit
END:VEVENT
BEGIN:VEVENT
UID:gcal-2
DTSTART:20261126T150000
DTEND:20261126T160000
RRULE:FREQ=WEEKLY;COUNT=2
SUMMARY:Weekly Sync
END:VEVENT
END:VCALENDAR`;

const gcalEvents = M.parseIcs(gcalIcs, {
  color: "#6fa8dc",
  source: "google",
  is24h: true,
  now: new Date(2026, 10, 26),
  windowStart: new Date(2026, 10, 1),
  windowEnd: new Date(2026, 11, 31)
});
assert.strictEqual(gcalEvents["2026-11-26"].length, 2, "Nov 26 has Summit + Weekly Sync");
assert.strictEqual(gcalEvents["2026-11-27"].length, 1, "Nov 27 has second day of Summit");
assert.strictEqual(gcalEvents["2026-11-27"][0].timeRange, "All day");
assert.strictEqual(gcalEvents["2026-12-03"].length, 1, "Dec 3 has second weekly occurrence");
assert.strictEqual(gcalEvents["2026-12-03"][0].timeRange, "15:00 - 16:00");

const merged = M.mergeEventsMaps([
  { "2026-11-26": [{ title: "Early Local", sortMinutes: 540, color: "#f2b45a" }] },
  gcalEvents
]);
assert.strictEqual(merged["2026-11-26"].length, 3);
assert.strictEqual(merged["2026-11-26"][0].title, "Two Day Summit", "All-day sorts first (-1)");
assert.strictEqual(merged["2026-11-26"][1].title, "Early Local", "09:00 sorts second");
assert.strictEqual(merged["2026-11-26"][2].title, "Weekly Sync", "15:00 sorts third");

console.log("All CalendarModel unit tests passed successfully!");
