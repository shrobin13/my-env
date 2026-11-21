# Notification Center for Omarchy

[![Omarchy Plugin](https://img.shields.io/badge/Omarchy-Bar%20Widget-blue.svg)](https://omarchy.org)
[![Author](https://img.shields.io/badge/Author-Sheikh%20Robin-informational.svg)](https://github.com/shrobin13)
[![GitHub](https://img.shields.io/badge/GitHub-shrobin13-lightgrey.svg)](https://github.com/shrobin13)

**Notification Center** (`user.notification-center`) is a feature-packed, SwayNC-inspired notification hub and quick settings control panel designed specifically for the [Omarchy](https://omarchy.org/) desktop shell (`omarchy-shell`).

---

## What It Is

Notification Center replaces basic ephemeral popups with an integrated, slide-out control drawer and status bar widget. It keeps track of notification history, allows you to manage alerts (pin, snooze, mute, group, filter), and provides one-click access to system toggles (Do Not Disturb, Focus timers, Night Light, Keep Awake, Snipping Tool, and Clipboard Manager).

Written in QML and JavaScript using Quickshell and Omarchy's UI kit (`qs.Commons`, `qs.Ui`), backed by a Python helper service (`manage.py`), it integrates cleanly with Hyprland window management and systemd timers.

---

## What It Does

### 1. Status Bar Widget
- **Unread Counter Badge:** Shows a notification bell on your Omarchy bar with a live count badge of unread notifications.
- **Do Not Disturb Indicator:** Displays a muted bell icon when DND or a focus timer is active.
- **One-Click Toggle:** Click the bar icon to slide open the full control center panel.

### 2. Quick Settings & Control Panel
- **Timed Focus / DND Presets:**
  - Toggle DND indefinitely or choose preset focus intervals: **15m**, **30m**, **1h**, **2h**.
  - Powered by user-level transient systemd timers (`systemd-run --user --unit=omarchy-focus-timer`), automatically restoring notifications when the timer elapses.
- **Keep Awake (Idle Inhibitor):** Toggle system idle suppression via `omarchy toggle idle`.
- **Night Light:** Toggle Hyprsunset color temperature via `omarchy toggle nightlight`.
- **Smart Snipping:** One-click region screen capture via `omarchy capture screenshot smart copy`.
- **Clipboard History:** Instantly summon Omarchy's clipboard drawer via `omarchy-shell shell summon omarchy.clipboard`.

### 3. Notification Management
- **Full History Stream:** Parses live and historical notification records from `~/.local/state/omarchy/notifications/`.
- **Filter Tabs:** Quickly switch between **All**, **Unread**, and **Pinned** notifications.
- **Instant Search:** Filter alerts dynamically by application name, title, or body content.
- **Application Grouping:** Collapse multiple notifications from the same application into compact stacks.
- **Pinning:** Keep important notifications permanently visible at the top of the stack.
- **Snoozing:** Temporarily dismiss notifications with timed snoozes; cards reappear automatically once the snooze countdown expires.
- **Application Muting:** Silence specific noisy desktop applications directly from their notification cards.
- **Non-Destructive Deletion & Undo:** Dismiss single cards, app stacks, or clear all notifications with an interactive Undo toast banner.

### 4. Interactive Actions & Window Switching
- **Action Buttons:** Trigger inline actions directly from notification cards (e.g. reply, open link, dismiss).
- **Auto-Focus App:** Clicking a notification card intelligently finds and focuses the originating application window in Hyprland (matching sender PID or client class) or launches it with `gtk-launch`.

### 5. Robust State Persistence & Localization
- **Atomic Persistence:** State (read status, pins, snoozes, mutes, deleted keys) is saved atomically to `~/.local/state/omarchy/notifications/user-state.json`.
- **i18n Translation:** Uses Omarchy's `Commons.Translations` with catalogs in `i18n/` (English `en.json` default).

---

## Installation in Omarchy

### Method 1: Local / Git Installation

Clone or place the plugin directory into your Omarchy plugins folder:

```bash
# Clone into ~/.config/omarchy/plugins/user.notification-center
git clone https://github.com/shrobin13/omarchy-notification-center.git \
  ~/.config/omarchy/plugins/user.notification-center

# Rescan plugins in the running Omarchy shell
omarchy-shell shell rescanPlugins
```

### Method 2: Enable via Omarchy CLI

Enable the widget in your status bar (defaults to the `right` bar section):

```bash
omarchy plugin enable user.notification-center --section right
```

Alternatively, pick your preferred section (`left`, `centerBegin`, `centerEnd`, `tray`, or `right`):

```bash
omarchy bar move user.notification-center --section right
```

---

## Configuration

### 1. Hyprland Keybinding

Add a global keyboard shortcut to toggle the notification center in `~/.config/hypr/bindings.lua`:

```lua
-- Toggle Notification Center (e.g. Super + N)
o.bind("SUPER + N", "Notification Center",
  "omarchy-shell -q shell toggle user.notification-center")
```

Reload Hyprland bindings to apply:

```bash
hyprctl reload
```

### 2. Bar Layout Customization

You can also place the widget directly in `~/.config/omarchy/shell.json`:

```json
{
  "bar": {
    "layout": {
      "right": [
        "user.notification-center",
        "omarchy.power",
        "omarchy.clock"
      ]
    }
  }
}
```

---

## CLI & Helper Commands (`manage.py`)

The companion script `manage.py` provides standalone CLI access to notification center features:

```bash
# Navigate to the plugin directory
cd ~/.config/omarchy/plugins/user.notification-center

# Send a test notification to verify integration
python3 manage.py send-test

# Toggle Do Not Disturb (DND)
python3 manage.py toggle-dnd

# Set a timed focus mode (in seconds, e.g. 1800 for 30 minutes; -1 to cancel)
python3 manage.py set-focus 1800
python3 manage.py set-focus -1

# Toggle Idle inhibitor / Night light
python3 manage.py toggle-idle
python3 manage.py toggle-nightlight

# Clear all notifications
python3 manage.py clear
```

---

## Directory Structure

```
user.notification-center/
├── manifest.json              # Plugin manifest (bar-widget entry point & schema)
├── Panel.qml                  # Bar widget pill, unread counter badge, and IPC
├── NotificationPanel.qml      # Main slide-out drawer panel with quick toggles
├── NotificationCard.qml       # Notification item card component with actions
├── Model.js                   # JavaScript state manipulation & filter functions
├── manage.py                  # Python backend (systemd timers, IPC, actions)
├── i18n/
│   └── en.json                # Localized translation catalog
├── tests/
│   ├── test_manage.py         # Unit tests for manage.py CLI & actions
│   ├── test_model.js          # Unit tests for Model.js data filters
│   └── test_model.qml         # QML test harness
└── README.md                  # Plugin documentation
```

---

## Testing & Validation

Validate against the Omarchy shell manifest specification:

```bash
omarchy plugin validate ~/.config/omarchy/plugins/user.notification-center
```

Run automated unit tests:

```bash
# Test Python manage backend
python3 ~/.config/omarchy/plugins/user.notification-center/tests/test_manage.py

# Test JavaScript data filtering & state logic
node ~/.config/omarchy/plugins/user.notification-center/tests/test_model.js
```

---

## Author

- **Author:** Sheikh Robin
- **GitHub:** [@shrobin13](https://github.com/shrobin13)
- **License:** MIT
