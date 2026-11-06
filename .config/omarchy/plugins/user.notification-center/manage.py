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
import re

STATE_DIR = os.path.expanduser("~/.local/state/omarchy/notifications")
HISTORY_FILE = os.path.join(STATE_DIR, "history.json")
LIVE_FILE = os.path.join(STATE_DIR, "live.json")
USER_STATE_FILE = os.path.join(STATE_DIR, "user-state.json")
QUIET_FILE = os.path.join(STATE_DIR, "quiet.json")

def atomic_write_json(file_path, data):
    os.makedirs(os.path.dirname(file_path), exist_ok=True)
    dir_name = os.path.dirname(file_path)
    with tempfile.NamedTemporaryFile("w", dir=dir_name, delete=False, encoding="utf-8") as tf:
        if isinstance(data, str):
            tf.write(data)
        else:
            json.dump(data, tf, separators=(",", ":"))
        temp_name = tf.name
    os.chmod(temp_name, 0o600)
    os.replace(temp_name, file_path)

def prune_user_state(keys_to_remove):
    if not os.path.isfile(USER_STATE_FILE) or not keys_to_remove:
        return
    try:
        with open(USER_STATE_FILE, "r", encoding="utf-8") as f:
            s = json.load(f)
        if not isinstance(s, dict):
            return
        changed = False
        for field in ("pinned", "snoozed", "readKeys"):
            d = s.get(field)
            if isinstance(d, dict):
                for k in keys_to_remove:
                    if k in d:
                        del d[k]
                        changed = True
        if changed:
            atomic_write_json(USER_STATE_FILE, s)
    except Exception as e:
        print(f"error-prune-state: {e}", file=sys.stderr)

def clear_all():
    atomic_write_json(HISTORY_FILE, [])
    try:
        subprocess.run(["omarchy-shell", "notifications", "dismissAll"], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass

    # Clear keys from user state
    if os.path.isfile(USER_STATE_FILE):
        try:
            with open(USER_STATE_FILE, "r", encoding="utf-8") as f:
                s = json.load(f)
            if isinstance(s, dict):
                s["pinned"] = {}
                s["snoozed"] = {}
                s["readKeys"] = {}
                atomic_write_json(USER_STATE_FILE, s)
        except Exception:
            pass

    print("cleared")

def delete_key(key):
    if not key:
        return
    delete_keys([key])

def delete_keys(keys):
    if not keys:
        return
    key_set = set(k for k in keys if k)
    for path in (HISTORY_FILE, LIVE_FILE):
        if not os.path.isfile(path):
            continue
        try:
            with open(path, "r", encoding="utf-8") as f:
                items = json.load(f)
            if isinstance(items, list):
                filtered = [item for item in items if isinstance(item, dict) and item.get("key") not in key_set]
                if len(filtered) != len(items):
                    atomic_write_json(path, filtered)
        except Exception as e:
            print(f"error-delete-keys: {e}", file=sys.stderr)

    prune_user_state(key_set)
    print(f"deleted {len(key_set)} keys")

def set_focus(seconds):
    try:
        subprocess.run(["systemctl", "--user", "stop", "omarchy-focus-timer.timer", "omarchy-focus-timer.service"],
                       check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run(["systemctl", "--user", "reset-failed", "omarchy-focus-timer.service"],
                       check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass

    script_path = os.path.abspath(__file__)

    if seconds > 0:
        try:
            subprocess.run([
                "systemd-run", "--user", "--unit=omarchy-focus-timer",
                f"--on-active={seconds}",
                "python3", script_path, "set-focus", "-1"
            ], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.run(["omarchy-shell", "notifications", "setDnd", "on"],
                           check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            print(f"focus-set-{seconds}s")
        except Exception as e:
            print(f"error-set-focus: {e}")
            sys.exit(1)
    elif seconds == 0:
        try:
            subprocess.run(["omarchy-shell", "notifications", "setDnd", "on"],
                           check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            print("focus-on-indefinite")
        except Exception as e:
            print(f"error-focus-on: {e}")
            sys.exit(1)
    else:
        try:
            subprocess.run(["omarchy-shell", "notifications", "setDnd", "off"],
                           check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            # Reset focusUntil in user-state.json
            if os.path.isfile(USER_STATE_FILE):
                try:
                    with open(USER_STATE_FILE, "r", encoding="utf-8") as f:
                        s = json.load(f)
                    if isinstance(s, dict) and s.get("focusUntil", 0) != 0:
                        s["focusUntil"] = 0
                        s["focusPreset"] = ""
                        atomic_write_json(USER_STATE_FILE, s)
                except Exception:
                    pass
            print("focus-off")
        except Exception as e:
            print(f"error-focus-off: {e}")
            sys.exit(1)

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
        was_enabled = False
        if os.path.isfile(QUIET_FILE):
            try:
                with open(QUIET_FILE, "r", encoding="utf-8") as f:
                    was_enabled = bool(json.load(f).get("dnd", False))
            except Exception:
                pass
        res = subprocess.run(["omarchy-shell", "notifications", "toggleDnd"], capture_output=True, text=True, check=False)
        if not was_enabled and os.path.isfile(USER_STATE_FILE):
            try:
                with open(USER_STATE_FILE, "r", encoding="utf-8") as f:
                    state = json.load(f)
                if isinstance(state, dict) and state.get("focusUntil", 0):
                    state["focusUntil"] = 0
                    state["focusPreset"] = "0"
                    atomic_write_json(USER_STATE_FILE, state)
            except Exception as e:
                print(f"error-reset-focus: {e}", file=sys.stderr)
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

def desktop_launcher_id(app):
    normalized = " ".join(str(app or "").lower().split())
    if normalized in ("telegram", "telegram desktop"):
        return "org.telegram.desktop.desktop"
    return ""


def focus_notification_window(app, sender_pid=0):
    try:
        result = subprocess.run(
            ["hyprctl", "clients", "-j"],
            check=False,
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            return False
        clients = json.loads(result.stdout)
    except (OSError, json.JSONDecodeError):
        return False

    if not isinstance(clients, list):
        return False

    candidates = []
    try:
        pid = int(sender_pid or 0)
    except (TypeError, ValueError):
        pid = 0

    if pid > 0:
        candidates = [client for client in clients if client.get("pid") == pid]

    if not candidates:
        words = re.findall(r"[a-z0-9]+", str(app or "").lower())
        slug = "".join(words)
        tail = "." + ".".join(words) if len(words) > 1 else ""
        for client in clients:
            identities = [
                str(client.get("class") or "").lower(),
                str(client.get("initialClass") or "").lower(),
            ]
            for identity in identities:
                dotted = "." + re.sub(r"[^a-z0-9]+", ".", identity)
                if identity == slug or (tail and dotted.endswith(tail)):
                    candidates.append(client)
                    break

    if not candidates:
        return False

    candidates.sort(key=lambda client: int(client.get("focusHistoryID", -1)))
    address = str(candidates[-1].get("address") or "")
    if not re.fullmatch(r"0x[0-9a-f]+", address, re.IGNORECASE):
        return False

    focused = subprocess.run(
        ["hyprctl", "dispatch", f'hl.dsp.focus({{ window = "address:{address}" }})'],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if focused.returncode != 0:
        focused = subprocess.run(
            ["hyprctl", "dispatch", "focuswindow", f"address:{address}"],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    return focused.returncode == 0


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

    # 3. Focus the application window if an app name is associated
    app = (item.get("app") or item.get("source") or "").strip()
    if app and app != "notify-send" and app != "System":
        try:
            subprocess.run(["omarchy-shell", "user.notification-center", "close"], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            if focus_notification_window(app, item.get("senderPid")):
                print(f"app-focused: {app}")
                return
            focus_result = subprocess.run(
                ["omarchy-hyprland-focus-app", app],
                check=False,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            if focus_result.returncode == 0:
                print(f"app-focused: {app}")
                return
        except Exception as e:
            print(f"error-focus-app: {e}")

        launcher_id = desktop_launcher_id(app)
        if launcher_id:
            try:
                launch_result = subprocess.run(
                    ["gtk-launch", launcher_id],
                    check=False,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.PIPE,
                    text=True,
                )
                if launch_result.returncode == 0:
                    print(f"desktop-app-launched: {launcher_id}")
                    return
                print(f"error-desktop-launch: {launch_result.stderr.strip()}")
            except Exception as e:
                print(f"error-desktop-launch: {e}")

    print("no-executable-action")

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
        print("Usage: manage.py [clear | delete <key> | delete-keys <keys...> | set-focus <sec> | save-state <json> | toggle-dnd | toggle-idle | toggle-nightlight | snip | clipboard | run-action <key> [action_id] | send-test]")
        sys.exit(1)

    cmd = sys.argv[1]
    if cmd == "clear":
        clear_all()
    elif cmd == "delete":
        key = sys.argv[2] if len(sys.argv) > 2 else ""
        delete_key(key)
    elif cmd == "delete-keys":
        keys = sys.argv[2:]
        if keys[:1] == ["--"]:
            keys = keys[1:]
        delete_keys(keys)
    elif cmd == "set-focus":
        args = sys.argv[2:]
        if args[:1] == ["--"]:
            args = args[1:]
        sec = int(args[0]) if args else 0
        set_focus(sec)
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
        args = sys.argv[2:]
        if args[:1] == ["--"]:
            args = args[1:]
        key = args[0] if args else ""
        act_id = args[1] if len(args) > 1 else ""
        run_action(key, act_id)
    elif cmd == "send-test":
        send_test()
    else:
        print(f"Unknown command: {cmd}")
        sys.exit(1)

if __name__ == "__main__":
    main()
