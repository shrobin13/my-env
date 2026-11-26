#!/usr/bin/env python3
"""Helper CLI for user.calendar-panel: local ICS events, settings, and Google Calendar sync."""

import json
import os
import re
import subprocess
import sys
import tempfile
import urllib.parse
import uuid
from datetime import datetime, timedelta, timezone


MAX_ICS_BYTES = 5 * 1024 * 1024  # 5 MB safety limit
MAX_URL_LEN = 2048


def default_local_ics_path() -> str:
    data_home = os.environ.get("XDG_DATA_HOME") or os.path.join(os.path.expanduser("~"), ".local", "share")
    return os.path.join(data_home, "omarchy", "calendar", "events.ics")


def default_google_cache_path() -> str:
    state_home = os.environ.get("XDG_STATE_HOME") or os.path.join(os.path.expanduser("~"), ".local", "state")
    return os.path.join(state_home, "omarchy", "calendar", "google.ics")


def atomic_write(path: str, content: str) -> None:
    parent = os.path.dirname(os.path.abspath(path))
    os.makedirs(parent, exist_ok=True)
    fd, tmp_path = tempfile.mkstemp(dir=parent, prefix=".tmp_", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(content)
        os.replace(tmp_path, path)
    except Exception:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)
        raise


def validate_https_url(url: str) -> str:
    cleaned = str(url or "").strip()
    if not cleaned:
        return ""
    if len(cleaned) > MAX_URL_LEN:
        raise ValueError("URL exceeds maximum allowed length")
    if any(ch.isspace() or ord(ch) < 32 for ch in cleaned):
        raise ValueError("URL contains invalid whitespace or control characters")
    parsed = urllib.parse.urlparse(cleaned)
    if parsed.scheme.lower() != "https" or not parsed.netloc:
        raise ValueError("Calendar URL must start with https://")
    return cleaned


def escape_ics_text(text: str) -> str:
    return (
        str(text or "")
        .replace("\\", "\\\\")
        .replace("\r\n", "\\n")
        .replace("\n", "\\n")
        .replace(";", "\\;")
        .replace(",", "\\,")
    )


def ensure_ics_skeleton(path: str) -> str:
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            content = f.read()
        if "BEGIN:VCALENDAR" in content and "END:VCALENDAR" in content:
            return content
    return (
        "BEGIN:VCALENDAR\r\n"
        "VERSION:2.0\r\n"
        "PRODID:-//Omarchy//user.calendar-panel//EN\r\n"
        "CALSCALE:GREGORIAN\r\n"
        "END:VCALENDAR\r\n"
    )


def parse_hhmm(time_str: str):
    s = str(time_str or "").strip()
    if not s:
        return None
    m = re.match(r"^(\d{1,2}):(\d{2})$", s)
    if not m:
        raise ValueError(f"Invalid time format '{s}' (expected HH:MM)")
    h, mn = int(m.group(1)), int(m.group(2))
    if h < 0 or h > 23 or mn < 0 or mn > 59:
        raise ValueError(f"Time out of range: '{s}'")
    return h, mn


def cmd_add_event(date_key: str, title: str, start_time: str = "", end_time: str = "", ics_path: str = "") -> None:
    if not re.match(r"^\d{4}-\d{2}-\d{2}$", date_key):
        raise ValueError("Invalid date format (expected YYYY-MM-DD)")
    clean_title = str(title or "").strip()[:200]
    if not clean_title:
        raise ValueError("Event title is required")

    target_path = os.path.expanduser(ics_path.strip()) if ics_path.strip() else default_local_ics_path()
    base_date = datetime.strptime(date_key, "%Y-%m-%d")
    ymd = base_date.strftime("%Y%m%d")

    start_hm = parse_hhmm(start_time)
    end_hm = parse_hhmm(end_time)

    if start_hm is None:
        # All-day event (RFC 5545 exclusive DTEND = next day)
        next_ymd = (base_date + timedelta(days=1)).strftime("%Y%m%d")
        dtstart_line = f"DTSTART;VALUE=DATE:{ymd}"
        dtend_line = f"DTEND;VALUE=DATE:{next_ymd}"
    else:
        sh, sm = start_hm
        start_dt = base_date.replace(hour=sh, minute=sm, second=0)
        if end_hm is not None:
            eh, em = end_hm
            end_dt = base_date.replace(hour=eh, minute=em, second=0)
            if end_dt <= start_dt:
                end_dt = start_dt + timedelta(hours=1)
        else:
            end_dt = start_dt + timedelta(hours=1)
        dtstart_line = f"DTSTART:{start_dt.strftime('%Y%m%dT%H%M%S')}"
        dtend_line = f"DTEND:{end_dt.strftime('%Y%m%dT%H%M%S')}"

    uid = f"{uuid.uuid4()}@omarchy.calendar"
    dtstamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")

    vevent = (
        "BEGIN:VCALENDAR\r\n"
    )
    event_block = (
        "BEGIN:VEVENT\r\n"
        f"UID:{uid}\r\n"
        f"DTSTAMP:{dtstamp}\r\n"
        f"{dtstart_line}\r\n"
        f"{dtend_line}\r\n"
        f"SUMMARY:{escape_ics_text(clean_title)}\r\n"
        "END:VEVENT\r\n"
    )

    existing = ensure_ics_skeleton(target_path)
    idx = existing.rfind("END:VCALENDAR")
    if idx == -1:
        updated = existing.rstrip() + "\r\n" + event_block + "END:VCALENDAR\r\n"
    else:
        updated = existing[:idx] + event_block + existing[idx:]

    atomic_write(target_path, updated)
    print(json.dumps({"ok": True, "uid": uid, "path": target_path}))


def cmd_delete_event(uid: str, ics_path: str = "") -> None:
    clean_uid = str(uid or "").strip()
    if not clean_uid:
        raise ValueError("UID is required")
    target_path = os.path.expanduser(ics_path.strip()) if ics_path.strip() else default_local_ics_path()
    if not os.path.exists(target_path):
        print(json.dumps({"ok": True, "deleted": False}))
        return

    with open(target_path, "r", encoding="utf-8", errors="replace") as f:
        content = f.read()

    # Unfold lines to check UID safely, rebuild keeping line structure
    pattern = re.compile(r"BEGIN:VEVENT\r?\n.*?END:VEVENT\r?\n?", re.DOTALL)
    deleted = False

    def replacer(match):
        nonlocal deleted
        block = match.group(0)
        unfolded = re.sub(r"\r?\n[ \t]", "", block)
        for line in unfolded.splitlines():
            if line.startswith("UID:") and line[4:].strip() == clean_uid:
                deleted = True
                return ""
        return block

    updated = pattern.sub(replacer, content)
    if deleted:
        atomic_write(target_path, updated)
    print(json.dumps({"ok": True, "deleted": deleted}))


def cmd_save_settings(settings_path: str, google_url: str, ics_path: str = "") -> None:
    validated_url = validate_https_url(google_url)
    data = {}
    if os.path.exists(settings_path):
        with open(settings_path, "r", encoding="utf-8") as f:
            data = json.load(f)
    data["googleCalendarUrl"] = validated_url
    if ics_path is not None and ics_path != "__KEEP__":
        data["icsPath"] = str(ics_path).strip()
    atomic_write(settings_path, json.dumps(data, indent=2) + "\n")
    print(json.dumps({"ok": True, "googleCalendarUrl": validated_url}))


def cmd_sync_google(settings_path: str) -> None:
    if not os.path.exists(settings_path):
        raise ValueError("settings.json not found")
    with open(settings_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    url = validate_https_url(data.get("googleCalendarUrl", ""))
    if not url:
        cache_path = default_google_cache_path()
        if os.path.exists(cache_path):
            os.unlink(cache_path)
        print(json.dumps({"ok": True, "cleared": True}))
        return

    res = subprocess.run(
        ["curl", "-fsSL", "--proto", "=https", "--max-time", "15", "--max-filesize", str(MAX_ICS_BYTES), url],
        capture_output=True,
        text=True,
        timeout=20,
    )
    if res.returncode != 0:
        err = (res.stderr or "curl failed").strip()
        raise RuntimeError(f"Sync failed: {err}")

    body = res.stdout or ""
    if len(body.encode("utf-8")) > MAX_ICS_BYTES:
        raise ValueError("Downloaded calendar exceeds 5 MB limit")
    if "BEGIN:VCALENDAR" not in body:
        raise ValueError("URL did not return a valid iCalendar (.ics) feed")

    cache_path = default_google_cache_path()
    atomic_write(cache_path, body)
    print(json.dumps({"ok": True, "path": cache_path, "bytes": len(body)}))


def cmd_open_google_create(date_key: str, title: str = "", start_time: str = "", end_time: str = "") -> None:
    if not re.match(r"^\d{4}-\d{2}-\d{2}$", date_key):
        raise ValueError("Invalid date format")
    base_date = datetime.strptime(date_key, "%Y-%m-%d")
    start_hm = parse_hhmm(start_time)
    end_hm = parse_hhmm(end_time)

    if start_hm is None:
        d1 = base_date.strftime("%Y%m%d")
        d2 = (base_date + timedelta(days=1)).strftime("%Y%m%d")
        dates_param = f"{d1}/{d2}"
    else:
        sh, sm = start_hm
        start_dt = base_date.replace(hour=sh, minute=sm, second=0)
        if end_hm is not None:
            eh, em = end_hm
            end_dt = base_date.replace(hour=eh, minute=em, second=0)
            if end_dt <= start_dt:
                end_dt = start_dt + timedelta(hours=1)
        else:
            end_dt = start_dt + timedelta(hours=1)
        dates_param = f"{start_dt.strftime('%Y%m%dT%H%M%S')}/{end_dt.strftime('%Y%m%dT%H%M%S')}"

    params = {"action": "TEMPLATE", "dates": dates_param}
    if title.strip():
        params["text"] = title.strip()[:200]
    url = "https://calendar.google.com/calendar/render?" + urllib.parse.urlencode(params)
    subprocess.Popen(["xdg-open", url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print(json.dumps({"ok": True, "url": url}))


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: manage.py <add-event|delete-event|save-settings|sync-google|open-google-create> ...", file=sys.stderr)
        return 1

    cmd = sys.argv[1]
    try:
        if cmd == "add-event":
            date_key = sys.argv[2]
            title = sys.argv[3]
            start_time = sys.argv[4] if len(sys.argv) > 4 else ""
            end_time = sys.argv[5] if len(sys.argv) > 5 else ""
            ics_path = sys.argv[6] if len(sys.argv) > 6 else ""
            cmd_add_event(date_key, title, start_time, end_time, ics_path)
        elif cmd == "delete-event":
            uid = sys.argv[2]
            ics_path = sys.argv[3] if len(sys.argv) > 3 else ""
            cmd_delete_event(uid, ics_path)
        elif cmd == "save-settings":
            settings_path = sys.argv[2]
            google_url = sys.argv[3] if len(sys.argv) > 3 else ""
            ics_path = sys.argv[4] if len(sys.argv) > 4 else "__KEEP__"
            cmd_save_settings(settings_path, google_url, ics_path)
        elif cmd == "sync-google":
            settings_path = sys.argv[2]
            cmd_sync_google(settings_path)
        elif cmd == "open-google-create":
            date_key = sys.argv[2]
            title = sys.argv[3] if len(sys.argv) > 3 else ""
            start_time = sys.argv[4] if len(sys.argv) > 4 else ""
            end_time = sys.argv[5] if len(sys.argv) > 5 else ""
            cmd_open_google_create(date_key, title, start_time, end_time)
        else:
            raise ValueError(f"Unknown command: {cmd}")
        return 0
    except Exception as exc:
        print(json.dumps({"ok": False, "error": str(exc)}), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
