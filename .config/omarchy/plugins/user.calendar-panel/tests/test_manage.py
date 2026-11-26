#!/usr/bin/env python3
import importlib.util
import json
import os
import tempfile
import unittest

MODULE_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "manage.py"))
spec = importlib.util.spec_from_file_location("calendar_manage", MODULE_PATH)
manage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(manage)


class TestCalendarManage(unittest.TestCase):
    def test_validate_https_url(self):
        self.assertEqual(manage.validate_https_url("  https://calendar.google.com/calendar/ical/abc/basic.ics "),
                         "https://calendar.google.com/calendar/ical/abc/basic.ics")
        self.assertEqual(manage.validate_https_url(""), "")
        with self.assertRaises(ValueError):
            manage.validate_https_url("http://calendar.google.com/test.ics")
        with self.assertRaises(ValueError):
            manage.validate_https_url("https://calendar.google.com/test\nrm -rf /")
        with self.assertRaises(ValueError):
            manage.validate_https_url("javascript:alert(1)")

    def test_add_and_delete_event(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            ics_path = os.path.join(tmpdir, "events.ics")
            manage.cmd_add_event("2026-11-26", "Team Demo", "14:00", "15:30", ics_path)
            manage.cmd_add_event("2026-11-27", "All Day Offsite", "", "", ics_path)

            with open(ics_path, "r", encoding="utf-8") as f:
                content = f.read()

            self.assertIn("SUMMARY:Team Demo", content)
            self.assertIn("DTSTART:20261126T140000", content)
            self.assertIn("DTEND:20261126T153000", content)
            self.assertIn("DTSTART;VALUE=DATE:20261127", content)
            self.assertIn("DTEND;VALUE=DATE:20261128", content)

            # Extract first UID and delete it
            uid = None
            for line in content.splitlines():
                if line.startswith("UID:"):
                    uid = line[4:].strip()
                    break
            self.assertIsNotNone(uid)

            manage.cmd_delete_event(uid, ics_path)
            with open(ics_path, "r", encoding="utf-8") as f:
                after = f.read()
            self.assertNotIn("Team Demo", after)
            self.assertIn("All Day Offsite", after)

    def test_save_settings(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            cfg = os.path.join(tmpdir, "settings.json")
            with open(cfg, "w", encoding="utf-8") as f:
                json.dump({"weekStartDay": "sunday", "clock24h": False}, f)

            manage.cmd_save_settings(cfg, "https://calendar.google.com/calendar/ical/example/basic.ics")
            with open(cfg, "r", encoding="utf-8") as f:
                updated = json.load(f)
            self.assertEqual(updated["weekStartDay"], "sunday")
            self.assertEqual(updated["googleCalendarUrl"], "https://calendar.google.com/calendar/ical/example/basic.ics")


if __name__ == "__main__":
    unittest.main()
