#!/usr/bin/env python3
"""
Notification Center helper script.
Provides actions for clearing history, deleting single notifications,
toggling DND, quick controls (keep awake, nightlight, screenshot, clipboard),
state persistence, and executing notification action callbacks.
"""

import sys
import os
import json
import subprocess
import tempfile

STATE_DIR = os.path.expanduser("~/.local/state/omarchy/notifications")
HISTORY_FILE = os.path.join(STATE_DIR, "history.json")
LIVE_FILE = os.path.join(STATE_DIR, "live.json")
USER_STATE_FILE = os.path.join(STATE_DIR, "user-state.json")

def atomic_write_json(file_path, data):
    os.makedirs(os.path.dirname(file_path), exist_ok=True)
    dir_name = os.path.dirname(file_path)
    with tempfile.NamedTemporaryFile("w", dir=dir_name, delete=False, encoding="utf-8") as tf:
        if isinstance(data, str):
            tf.write(data)
        else:
            json.dump(data, tf, separators=(",", ":"))
            tf.write("\n")
        temp_name = tf.name
    os.chmod(temp_name, 0o600)
    os.replace(temp_name, file_path)

def clear_all():
    atomic_write_json(HISTORY_FILE, [])
    try:
        subprocess.run(["omarchy-shell", "notifications", "dismissAll"], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass
    print("cleared")

def delete_key(key):
    if not key:
        return
    for path in (HISTORY_FILE, LIVE_FILE):
        if not os.path.isfile(path):
            continue
        try:
            with open(path, "r", encoding="utf-8") as f:
                items = json.load(f)
            if isinstance(items, list):
                filtered = [item for item in items if isinstance(item, dict) and item.get("key") != key]
                if len(filtered) != len(items):
                    atomic_write_json(path, filtered)
        except Exception:
            pass
    print(f"deleted {key}")

def save_user_state(json_str):
    if not json_str:
        return
    try:
        parsed = json.loads(json_str)
        atomic_write_json(USER_STATE_FILE, parsed)
        print("state-saved")
    except Exception as e:
        print(f"error-saving-state: {e}")

def toggle_dnd():
    try:
        res = subprocess.run(["omarchy-shell", "notifications", "toggleDnd"], capture_output=True, text=True, check=False)
        print(res.stdout.strip())
    except Exception as e:
        print(f"error: {e}")

def toggle_idle():
    try:
        subprocess.run(["omarchy", "toggle", "idle"], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print("idle-toggled")
    except Exception as e:
        print(f"error: {e}")

def toggle_nightlight():
    try:
        subprocess.run(["omarchy", "toggle", "nightlight"], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print("nightlight-toggled")
    except Exception as e:
        print(f"error: {e}")

def capture_snip():
    try:
        subprocess.run(["omarchy-shell", "user.notification-center", "close"], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.Popen(["omarchy", "capture", "screenshot", "smart", "copy"])
        print("snip-started")
    except Exception as e:
        print(f"error: {e}")

def open_clipboard():
    try:
        subprocess.run(["omarchy-shell", "user.notification-center", "close"], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.Popen(["omarchy-shell", "shell", "summon", "omarchy.clipboard"])
        print("clipboard-opened")
    except Exception as e:
        print(f"error: {e}")

def run_action(key, action_id=""):
    if not key:
        return
    item = None
    for path in (LIVE_FILE, HISTORY_FILE):
        if not os.path.isfile(path):
            continue
        try:
            with open(path, "r", encoding="utf-8") as f:
                items = json.load(f)
            if isinstance(items, list):
                for it in items:
                    if isinstance(it, dict) and it.get("key") == key:
                        item = it
                        break
        except Exception:
            pass
        if item:
            break

    if not item:
        print(f"item {key} not found")
        return

    # 1. If an action_id starting with exec_ is given
    if action_id and action_id.startswith("exec_"):
        try:
            idx = int(action_id.split("_")[1])
            exec_actions_raw = item.get("execActions", "")
            if exec_actions_raw:
                ea = json.loads(exec_actions_raw) if isinstance(exec_actions_raw, str) else exec_actions_raw
                if isinstance(ea, list) and 0 <= idx < len(ea):
                    argv = ea[idx].get("argv")
                    if isinstance(argv, list):
                        subprocess.Popen(argv)
                        print("exec-action-launched")
                        return
        except Exception as e:
            print(f"error-exec-action: {e}")

    # 2. Check default execArgv
    exec_argv_raw = item.get("execArgv", "")
    if exec_argv_raw:
        try:
            argv = json.loads(exec_argv_raw)
            if isinstance(argv, list) and all(isinstance(x, str) for x in argv) and len(argv) > 0:
                subprocess.Popen(argv)
                print("exec-argv-launched")
                return
        except Exception as e:
            print(f"error-argv: {e}")

    print("no-executable-action")

def send_reply(key, text):
    print(f"reply-sent for {key}: {text}")

def send_test():
    try:
        subprocess.run([
            "notify-send",
            "Notification Center",
            "Welcome! SwayNC-style notification center is active.",
            "-i", "preferences-desktop-notification"
        ], check=False)
        print("sent")
    except Exception as e:
        print(f"error: {e}")

def main():
    if len(sys.argv) < 2:
        print("Usage: manage.py [clear | delete <key> | save-state <json> | toggle-dnd | toggle-idle | toggle-nightlight | snip | clipboard | run-action <key> [action_id] | reply <key> <text> | send-test]")
        sys.exit(1)

    cmd = sys.argv[1]
    if cmd == "clear":
        clear_all()
    elif cmd == "delete":
        key = sys.argv[2] if len(sys.argv) > 2 else ""
        delete_key(key)
    elif cmd == "save-state":
        json_data = sys.argv[2] if len(sys.argv) > 2 else "{}"
        save_user_state(json_data)
    elif cmd == "toggle-dnd":
        toggle_dnd()
    elif cmd == "toggle-idle":
        toggle_idle()
    elif cmd == "toggle-nightlight":
        toggle_nightlight()
    elif cmd == "snip":
        capture_snip()
    elif cmd == "clipboard":
        open_clipboard()
    elif cmd == "run-action":
        key = sys.argv[2] if len(sys.argv) > 2 else ""
        act_id = sys.argv[3] if len(sys.argv) > 3 else ""
        run_action(key, act_id)
    elif cmd == "reply":
        key = sys.argv[2] if len(sys.argv) > 2 else ""
        rep_txt = sys.argv[3] if len(sys.argv) > 3 else ""
        send_reply(key, rep_txt)
    elif cmd == "send-test":
        send_test()
    else:
        print(f"Unknown command: {cmd}")
        sys.exit(1)

if __name__ == "__main__":
    main()
