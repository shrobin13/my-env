# Hyprland Platform - Automated Setup & Orchestration

Complete Arch Linux Hyprland desktop environment redesigned as a **modular, Lua-native, reproducible platform ecosystem**.

## 🎯 What This Is

Instead of scattered dotfiles, this is a **production-grade platform** that automatically:

- ✅ Installs all dependencies
- ✅ Generates configurations from templates
- ✅ Sets up services and orchestration
- ✅ Manages workspace/monitor/theme state
- ✅ Provides intelligent clipboard history
- ✅ Enables IDE-optimized workflows
- ✅ Ensures reproducibility across machines

## ⚡ Quick Start (2 minutes)

```bash
# 1. Test what will be done (no changes)
bash setup.sh --dry-run

# 2. Deploy everything automatically
bash setup.sh --profile laptop --theme rose-pine

# 3. That's it! Everything is set up
hyprctl reload
```

Or use the simple installer wrapper:

```bash
bash install.sh --profile laptop
```

## 📋 What Gets Installed

### System Components

- Hyprland compositor + utilities
- Wayland infrastructure (wl-clipboard, protocols)
- Waybar status bar
- SwayNC notification daemon
- Rofi application launcher
- Kitty terminal emulator
- Core development tools (Git, Node, Python, Rust)

### Platform Services

- **Clipboard Daemon**: 500-item history with image support
- **Monitor Manager**: Hot-plug detection + multi-monitor awareness
- **Workspace Orchestrator**: Intelligent app routing + layout persistence
- **Theme Engine**: Dynamic color compilation + live reload
- **Platform Orchestrator**: Service coordination + event handling

### Configuration Structure

```
~/.dotfiles/
├── setup.sh                 # Master setup orchestrator
├── install.sh              # Simple wrapper
├── Makefile                # Build system
├── runtime/
│   ├── gen/                # Generated configs
│   ├── cache/              # Theme/palette cache
│   └── theme-colors.conf   # Current theme
├── state/
│   ├── workspaces.json     # Workspace state
│   ├── monitors.json       # Monitor config
│   ├── clipboard-history.json
│   └── logs/               # Service logs
├── modules/                # Lua modules
│   ├── core/               # Monitor, workspace management
│   ├── theme/              # Theme engine
│   ├── workflow/           # IDE modes, focus mode
│   └── clipboard/          # Clipboard daemon
├── config/                 # Static configs
│   ├── hypr/
│   ├── waybar/
│   └── [...]
└── services/               # Systemd units
```

## 🚀 Usage

### Initial Setup

```bash
# Test first (safe, no changes)
bash setup.sh --dry-run

# Deploy with your profile and theme
bash setup.sh --profile laptop --theme rose-pine

# For workstation/developer machines
bash setup.sh --profile workstation
```

### Available Profiles

- **laptop** (default) - Battery aware, power optimized
- **workstation** - Performance focused, Docker included
- **vm** - Minimal overhead, virtual machine optimized

### Available Themes

- **rose-pine** (default) - Minimal, elegant
- **nord** - Cool professional blue
- **dracula** - Vibrant purple/pink

### After Setup

```bash
# Check status
make status

# View logs
make logs

# Rebuild configs
make build

# Validate everything
make validate

# Manage services
systemctl --user start hyprland-platform
systemctl --user enable hyprland-platform
```

## 🎮 Key Features

### 🤖 Automatic Workspace Allocation

```
kitty/neovim  → Workspace 1 (IDE)
firefox/brave → Workspace 3 (Browser)
discord/slack → Workspace 5 (Communication)
vlc/mpv       → Workspace 6 (Media)
```

### 💾 Persistent State

- Workspace layouts saved across restarts
- Monitor configuration remembered
- Clipboard history with 500 items
- Project-based dynamic workspaces

### 🎨 Live Theme Switching

```bash
# Change theme without logout
lua ~/.dotfiles/modules/theme/engine.lua --theme nord

# Adjust colors in one place
vim ~/.dotfiles/runtime/theme-colors.conf
```

### 🛠️ IDE-Optimized Layouts

```bash
# Activate coding mode (60/40 editor+terminal split)
hyprctl dispatch exec 'lua ~/.dotfiles/modules/workflow/coding-mode.lua:activate'
```

### 📋 Clipboard Management

- Text + image history
- Sensitive content auto-expiry
- Fuzzy searchable
- Image thumbnails with palette extraction

### 🔌 Multi-Monitor Support

- Hot-plug detection
- Per-monitor profiles (res, refresh rate, scale)
- Intelligent workspace distribution
- Workspace folding on disconnect

## 🔧 Customization

### Change App Routing

```bash
# Edit workspace assignments
vim ~/.dotfiles/modules/core/workspace.lua

# Rebuild and reload
make build && hyprctl reload
```

### Add Custom Keybindings

```bash
# Edit keybindings
vim ~/.dotfiles/config/hypr/keybindings.conf

# Reload
hyprctl reload
```

### Create Workflow Modes

```bash
# Copy and extend coding-mode.lua
cp ~/.dotfiles/modules/workflow/coding-mode.lua \
   ~/.dotfiles/modules/workflow/debugging-mode.lua

# Edit and activate
lua ~/.dotfiles/modules/workflow/debugging-mode.lua:activate
```

## 🛡️ Safety Features

### ✅ Dry-Run Mode

```bash
bash setup.sh --dry-run  # Preview without making changes
```

### ✅ Automatic Backups

```bash
# Existing configs backed up to ~/.config-backup-TIMESTAMP/
bash setup.sh --no-backup  # Skip backups if needed
```

### ✅ Validation & Verification

```bash
make validate  # Check all configs
make lint      # Validate Lua scripts
make test      # Run test suite
```

### ✅ Idempotent Installation

```bash
# Safe to run multiple times
bash setup.sh
bash setup.sh  # Runs again, updates only what changed
```

## 🐛 Troubleshooting

### Setup not completing

```bash
# Check detailed log
cat ~/.dotfiles/state/logs/setup.log

# Verbose mode
bash setup.sh --verbose --dry-run
```

### Configs not loading

```bash
# Verify symlinks
readlink ~/.config/hypr

# Rebuild
make build && hyprctl reload

# Check Hyprland syntax
hyprctl -j syntax
```

### Services not running

```bash
# Check service status
systemctl --user status hyprland-platform

# View logs
journalctl --user -u hyprland-platform -n 50

# Manual start for debugging
bash ~/.dotfiles/scripts/internal/orchestrator.sh
```

### Theme not applying

```bash
# Regenerate theme
lua ~/.dotfiles/modules/theme/engine.lua

# Reload UI
pkill waybar && sleep 1 && waybar &
hyprctl reload
```

## 📚 Documentation

All documentation is in the repository:

- **README.md** (this file) - Overview
- **QUICK_START.md** - 5-minute guide
- **PLATFORM_IMPLEMENTATION_GUIDE.md** - Detailed phases
- **DIRECTORY_STRUCTURE.md** - Architecture reference
- **PLATFORM_REDESIGN.md** - Design specifications
- **PHASE2_DELIVERABLES.md** - Implementation details
- **AUDIT.md** - Performance analysis (30+ pages)

## 🎯 Next Steps

1. **Run Quick Test**

   ```bash
   bash setup.sh --dry-run
   ```

2. **Deploy**

   ```bash
   bash setup.sh --profile laptop --theme rose-pine
   ```

3. **Activate**

   ```bash
   hyprctl reload
   systemctl --user start hyprland-platform
   ```

4. **Customize**

   ```bash
   # Edit workflow, keybindings, theme, apps
   ```

5. **Share**
   ```bash
   # Version control and share your setup
   ```

## 📄 License

[MIT](LICENSE)
