# 🛠️ my-env — Personal Dotfiles & Shell Config

Personal configuration for **Arch Linux · Omarchy Quattro · Zsh · Powerlevel10k**.

Designed for effortless restoration whenever you reinstall Omarchy or set up a new machine.

---

## 🚀 Quick Setup (New Machine / Fresh Omarchy Reinstall)

Clone the repository and run `install.sh`:

```bash
git clone https://github.com/shrobin13/my-env.git ~/Work/my-config
cd ~/Work/my-config
./install.sh
```

### Options:
- **`./install.sh`** (default): Creates symlinks in `$HOME` pointing to this directory. Any edits you make to `~/.zshrc` or `~/.p10k.zsh` are instantly tracked in git!
- **`./install.sh --copy`**: Copies the files directly into `$HOME` instead of symlinking.

---

## 📂 Managed Configurations

| Source in repository | Destination in `$HOME` | Purpose |
| :--- | :--- | :--- |
| [`.zshrc`](.zshrc) | `~/.zshrc` | Cleaned, optimized Zsh configuration (Zinit, plugins, aliases, prompt) |
| [`.p10k.zsh`](.p10k.zsh) | `~/.p10k.zsh` | Powerlevel10k theme configuration |
| [`.config/hypr/`](.config/hypr/) | `~/.config/hypr/` | Omarchy Hyprland Lua config (bindings, monitors, look & feel, inputs) |
| [`.config/omarchy/plugins/user.calendar-panel/`](.config/omarchy/plugins/user.calendar-panel/) | `~/.config/omarchy/plugins/user.calendar-panel/` | Floating status bar & calendar popup panel with month grid, agenda, timer, and focus |
| [`.config/omarchy/plugins/user.notification-center/`](.config/omarchy/plugins/user.notification-center/) | `~/.config/omarchy/plugins/user.notification-center/` | SwayNC-inspired Notification Center & Quick Controls shell plugin |
| [`.config/omarchy/plugins/io.github.shrobin13.global-window-tree/`](.config/omarchy/plugins/io.github.shrobin13.global-window-tree/) | `~/.config/omarchy/plugins/io.github.shrobin13.global-window-tree/` | Keyboard-driven cross-monitor window tree overlay |
| [`bin/download`](bin/download) | `~/.local/bin/download` | High-performance `yt-dlp` frontend CLI utility |
| [`bin/toggle-bar-style`](bin/toggle-bar-style) | `~/.local/bin/toggle-bar-style` | Instant bar style switcher (toggles between stock Omarchy and custom Calendar Panel bar) |
| [`.zfunc/_download`](.zfunc/_download) | `~/.zfunc/_download` | Autoloaded Zsh completions for `download` |

---

## 📦 Recommended Packages

`install.sh` checks for these utilities automatically. To install all of them on Arch:

```bash
sudo pacman -S --needed zsh fzf bat eza fd ripgrep zoxide mise fastfetch yt-dlp ffmpeg vivid
```

- **`vivid`**: Generates `one-dark` `LS_COLORS` for colored completions.
- **`eza`**: Modern replacement for `ls` used for tab-completion previews.
- **`bat`**: Syntax highlighting for file previews and `cat`.
- **`yt-dlp` & `ffmpeg`**: Core engines for the `download` utility.
- **`mise`**: Runtime and tool version manager.

---

## 📅 Shell Plugin: `user.calendar-panel`

A redesign of the Omarchy top bar and calendar popup panel following the dark green monospace aesthetic.

### Features
- **Top Bar**: Three floating groups inset ~10px from edges and ~5px from the top (thinner 30px height, crisp 2px max radius):
  - **Left Group**: Omarchy menu launcher button and workspace pills 1–5 with active accent fill, occupied, and dim empty states (scroll switches workspaces).
  - **Center Group**: Accent border `#5fbf93`, system indicators (`omarchy.indicators`), calendar icon, formatted date ("Thu 26 Nov"), bold time ("5:36 PM"), live countdown timer badge, click-to-toggle calendar panel, and status modules (`omarchy.elsewhen`, `omarchy.weather`, `omarchy.system-update`).
  - **Right Group**: System tray (`omarchy.tray` with Superwhisper), keyboard layout (`omarchy.keyboard-layout`), Omarchy agents (`omarchy.agents`), Bluetooth (`omarchy.bluetooth`), Wi-Fi (`omarchy.network`), Pipewire audio (`omarchy.audio`), monitor brightness (`omarchy.monitor`), 22x10 outlined battery gauge with proportional fill + percentage, Power menu (`omarchy.power`), and SwayNC Notification Center (`user.notification-center`). All with full interactive popup panels.
- **Calendar Panel**: 880px wide popup centered under the clock (2px max radius):
  - Header with calendar icon, "THURSDAY · WEEK 48", big date "November 26", navigation (`‹`, `Today`, `›`), sync (`↻`), and settings (`⚙`).
  - Dynamic year progress bar with live day-of-year and remaining days counter (`Day 330 · 35 left`).
  - Left column: 5 or 6-row month grid with ISO week numbers, weekend highlights, other-month dimming, today accent pill, and event dots.
  - Right column: Today / Tomorrow agenda view (or selected date agenda), event cards with colored left bars, inline **`+ Event`** creator (saves locally to `~/.local/share/omarchy/calendar/events.ics` or opens pre-filled Google Calendar event in browser), inline **Google Calendar iCal sync (`⚙`)**, and quick actions (`+ Event`, `Timer`, `Focus`).
  - Keyboard accessible: `←`/`→` month, `T` today, `N` new event, `Esc` close, click-outside dismissal.

### Keybindings & Bar Cycling
- **`SUPER + ALT + C`**: Toggle calendar panel (`omarchy-shell -q user.calendar-panel toggle`).
- **`SUPER + ALT + B`**: Cycle bar style between custom Calendar Panel bar and stock Omarchy bar (`toggle-bar-style`).
- **Left Panel Button (`⇄`)**: Click the small cycle button next to the menu icon on the left panel to instantly switch between the custom bar and the stock bar.

### Settings (`settings.json`)
Located at `~/.config/omarchy/plugins/user.calendar-panel/settings.json`:
```json
{
  "weekStartDay": "sunday",
  "clock24h": false,
  "icsPath": "",
  "googleCalendarUrl": "",
  "autoSyncMinutes": 15,
  "accentOverride": ""
}
```
To sync Google Calendar directly from the UI, click **`⚙`** in the panel header (or **`+ Connect Google Calendar`**) and paste your Google Calendar *Secret address in iCal format*.

### Enabling and Reloading
- **Enable as active bar**:
  ```bash
  omarchy plugin enable user.calendar-panel
  ```
- **Disable (return to stock bar)**:
  ```bash
  omarchy plugin disable user.calendar-panel
  ```
- **Reload shell**:
  ```bash
  omarchy restart shell
  # or force plugin rescan:
  omarchy-shell shell rescanPlugins
  ```
