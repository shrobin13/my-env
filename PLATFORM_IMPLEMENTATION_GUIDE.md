# Platform Redesign - Implementation Guide

## Overview

This guide walks you through implementing the complete Lua-native Hyprland platform redesign. The architecture transforms your dotfiles from a static configuration into a **modular, event-driven, reproducible ecosystem**.

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│            User Shell / Keybindings                  │
└─────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────┐
│      Hyprland IPC / Event Dispatcher                 │
│  (Workspace changes, Window focus, Plugin hooks)     │
└─────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────┐
│              Lua Module System                       │
│  ┌──────────┬──────────┬──────────┬──────────┐      │
│  │ Workspace│ Monitor  │ Clipboard│ Workflow │      │
│  │ Manager  │ Manager  │  Daemon  │ Engines  │      │
│  └──────────┴──────────┴──────────┴──────────┘      │
│  ┌──────────┬──────────┬──────────┐                │
│  │  Theme   │ Tiling   │ Session  │                │
│  │  Engine  │ State    │ Manager  │                │
│  └──────────┴──────────┴──────────┘                │
└─────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────┐
│         Configuration Generation Layer              │
│  (Templates → Runtime Configs → Backends)           │
└─────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────┐
│              Persistent State Layer                  │
│  (Workspaces, Sessions, Monitors, Clipboard)        │
└─────────────────────────────────────────────────────┘
```

## Phase 1: Directory Structure Setup (30 min)

### Step 1: Create Base Directory Structure

```bash
# Navigate to your dotfiles repo
cd ~/.dotfiles

# Create core directories
mkdir -p modules/{core,theme,workflow,clipboard,system}
mkdir -p scripts/{internal,user}
mkdir -p config/hypr config/waybar config/swaync config/kitty config/rofi
mkdir -p templates themes
mkdir -p services/{user,system/udev}
mkdir -p packages profiles docs
mkdir -p runtime/{cache/themes,cache/palettes,cache/thumbnails,cache/compiled,gen}
mkdir -p state/{monitors,workspaces,sessions,cache/thumbnails,logs}
```

### Step 2: Initialize Git & .gitignore

```bash
# Create comprehensive .gitignore
cat > .gitignore << 'EOF'
# Runtime artifacts
runtime/cache/
runtime/gen/

# State files (dynamic)
state/

# Environment overrides
profile.env
.env.local

# IDE/editor
.vscode/
.idea/
*.swp
*.swo
*~

# System
.DS_Store
Thumbs.db
EOF

git add .
git commit -m "Initial platform structure"
```

## Phase 2: Move & Reorganize Existing Configs (45 min)

### Step 1: Copy Current Configs

```bash
# Copy your existing configs to new structure
cp -r ~/my-env/hypr/* ~/.dotfiles/config/hypr/
cp -r ~/my-env/waybar/* ~/.dotfiles/config/waybar/
cp -r ~/my-env/swaync/* ~/.dotfiles/config/swaync/
cp -r ~/my-env/kitty/* ~/.dotfiles/config/kitty/
cp -r ~/my-env/rofi/* ~/.dotfiles/config/rofi/
```

### Step 2: Validate Configs

```bash
# Run validation
make validate

# Fix any syntax errors
hyprctl -j syntax
```

### Step 3: Test Bootstrap (Dry Run)

```bash
# Dry run shows what would be done
bash bootstrap.sh --dry-run --profile laptop

# Check output for any issues
```

## Phase 3: Deploy Lua Modules (90 min)

### Step 1: Create Module Loader

```bash
# This is the entry point for all Lua modules
cat > ~/.dotfiles/modules/system/init.lua << 'EOF'
-- ~/.dotfiles/modules/system/init.lua
-- Platform initialization

local Platform = {}

-- Module registry
Platform.modules = {
    workspace = require("modules.core.workspace"),
    monitor = require("modules.core.monitor"),
    theme = require("modules.theme.engine"),
    coding = require("modules.workflow.coding-mode"),
    clipboard = require("modules.clipboard.daemon"),
}

-- Initialize all modules
function Platform.init()
    print("Initializing Hyprland platform...")

    -- Load theme
    Platform.modules.theme.compile("rose-pine")

    -- Initialize clipboard daemon
    Platform.modules.clipboard.init()

    -- Setup monitors
    Platform.modules.monitor.detect_roles()

    print("Platform initialized successfully")
end

-- Shutdown
function Platform.shutdown()
    print("Shutting down platform...")
    Platform.modules.clipboard.save_history()
end

-- IPC dispatcher
function Platform.dispatch(event_type, event_data)
    if event_type == "workspace_changed" then
        Platform.modules.workspace.on_change(event_data)
    elseif event_type == "monitor_connected" then
        Platform.modules.monitor.on_connect(event_data.name)
    elseif event_type == "monitor_disconnected" then
        Platform.modules.monitor.on_disconnect(event_data.name)
    end
end

return Platform
EOF
```

### Step 2: Create IPC Event Handler

```bash
# Create the event dispatcher script
cat > ~/.dotfiles/scripts/internal/ipc-dispatcher.lua << 'EOF'
#!/usr/bin/env lua
-- Listen to Hyprland IPC events and dispatch to platform

local platform = require("modules.system.init")

-- Connect to Hyprland socket
local socket_path = os.getenv("XDG_RUNTIME_DIR") .. "/hypr/" ..
    os.getenv("HYPRLAND_INSTANCE_SIGNATURE") .. "/.socket2.sock"

-- Read events
while true do
    -- (Simplified - would use proper socket I/O)
    -- Parse event and dispatch
    local event = io.read()
    if event then
        platform.dispatch(event)
    end
end
EOF

chmod +x ~/.dotfiles/scripts/internal/ipc-dispatcher.lua
```

### Step 3: Test Modules

```bash
# Quick test
lua -e "require('modules.system.init').init()"

# Check for errors
```

## Phase 4: Generate Runtime Configs (30 min)

### Step 1: Build Configuration

```bash
# Generate all runtime configs from templates
make build

# Verify outputs
ls -la runtime/gen/
ls -la runtime/theme-colors.lua
```

### Step 2: Link Configs

```bash
# Create symlinks to generated configs
ln -sf ~/.dotfiles/runtime/gen/hyprland ~/.config/hypr
ln -sf ~/.dotfiles/runtime/gen/waybar ~/.config/waybar
ln -sf ~/.dotfiles/runtime/gen/swaync ~/.config/swaync
# ... etc
```

## Phase 5: Setup Services (30 min)

### Step 1: Create User Services

```bash
mkdir -p ~/.config/systemd/user

# Clipboard daemon service
cat > ~/.config/systemd/user/clipboard-daemon.service << 'EOF'
[Unit]
Description=Hyprland Clipboard Daemon
After=graphical-session-pre.target
PartOf=graphical-session.target

[Service]
ExecStart=lua %h/.dotfiles/modules/clipboard/daemon.lua
Restart=on-failure

[Install]
WantedBy=graphical-session.target
EOF

# Theme engine service
cat > ~/.config/systemd/user/theme-engine.service << 'EOF'
[Unit]
Description=Hyprland Theme Engine
After=graphical-session-pre.target
PartOf=graphical-session.target

[Service]
ExecStart=lua %h/.dotfiles/scripts/internal/config-generator.lua
Restart=on-failure

[Install]
WantedBy=graphical-session.target
EOF
```

### Step 2: Enable Services

```bash
systemctl --user daemon-reload
systemctl --user enable clipboard-daemon.service
systemctl --user enable theme-engine.service
```

## Phase 6: Test & Validate (30 min)

### Step 1: Dry Run Validation

```bash
# Full validation suite
make validate
make lint
make test

# Check status
make status
```

### Step 2: Manual Testing

```bash
# Source environment
source ~/.dotfiles/.env

# Test bootstrap
bash ~/.dotfiles/bootstrap.sh --dry-run

# Test module loading
lua ~/.dotfiles/modules/system/init.lua

# Test service startup
systemctl --user start clipboard-daemon.service
systemctl --user start theme-engine.service
```

## Phase 7: Integration with Hyprland (Variable)

### Step 1: Update Hyprland Config

Add to your `~/.config/hypr/hyprland.conf`:

```conf
# Load runtime-generated config
source = ~/.dotfiles/runtime/gen/hyprland.conf

# IPC/Event handling - uncomment when ready
# exec-once = lua ~/.dotfiles/scripts/internal/ipc-dispatcher.lua

# Initialize platform
exec-once = lua ~/.dotfiles/modules/system/init.lua

# Keybinding to toggle coding mode
bind = $mainMod, F12, exec, lua ~/.dotfiles/modules/workflow/coding-mode.lua:activate
```

### Step 2: Test Reload

```bash
# Reload Hyprland
hyprctl reload

# Check for errors
hyprctl -j errors
```

## Quick Reference - What Each Phase Delivers

| Phase | Deliverable                      | Time | Value                |
| ----- | -------------------------------- | ---- | -------------------- |
| 1     | Directory structure + .gitignore | 30m  | Foundation           |
| 2     | Reorganized existing configs     | 45m  | Baseline             |
| 3     | Lua module system                | 90m  | Runtime intelligence |
| 4     | Generated configs + templates    | 30m  | Dynamic setup        |
| 5     | Systemd services                 | 30m  | Persistence          |
| 6     | Validation suite                 | 30m  | Confidence           |
| 7     | Hyprland integration             | ∞    | Full functionality   |

**Total: ~4 hours to basic working state**

## File Checklist - What Should Exist After Each Phase

### After Phase 1 ✓

- [ ] Directory structure created
- [ ] .gitignore configured
- [ ] Git repository initialized

### After Phase 2 ✓

- [ ] All existing configs copied
- [ ] Configs validated with `make validate`
- [ ] Bootstrap test passes with `--dry-run`

### After Phase 3 ✓

- [ ] All `.lua` modules loaded without errors
- [ ] IPC dispatcher created
- [ ] Platform init script works

### After Phase 4 ✓

- [ ] `make build` generates runtime configs
- [ ] `runtime/gen/` populated
- [ ] `runtime/theme-colors.lua` exists and is valid

### After Phase 5 ✓

- [ ] Services installed in `~/.config/systemd/user/`
- [ ] Services enabled
- [ ] `systemctl --user status` shows all active

### After Phase 6 ✓

- [ ] `make validate` passes
- [ ] `make lint` passes all Lua files
- [ ] `make status` shows healthy state

### After Phase 7 ✓

- [ ] Hyprland reloads without errors
- [ ] All keybindings functional
- [ ] Lua modules respond to Hyprland events

## Troubleshooting

### Configs not loading

```bash
# Check path resolution
echo $XDG_CONFIG_HOME
ls -la ~/.config/hypr

# Verify symlinks
readlink ~/.config/hypr
```

### Modules not found

```bash
# Check Lua path
lua -e "print(package.path)"

# Add dotfiles to path
export LUA_PATH="$HOME/.dotfiles/modules/?.lua;$LUA_PATH"
```

### Services not starting

```bash
# Check service logs
journalctl --user -u clipboard-daemon.service -n 50

# Manual test
lua ~/.dotfiles/modules/clipboard/daemon.lua
```

## Next Steps After Implementation

Once Phase 7 is complete:

1. **Advanced Workflows** - Implement debug-mode, presentation-mode
2. **Performance Optimization** - Profile startup time, memory usage
3. **IDE Integration** - Workspace auto-detection for VS Code, Neovim
4. **Deployment Automation** - CI/CD for config changes
5. **Multi-Machine Sync** - Replicate across machines
6. **Documentation** - API docs, workflow guides, architecture deep-dive

## Support Resources

- **Architecture**: See [ARCHITECTURE.md](ARCHITECTURE.md)
- **API Reference**: See [API.md](API.md)
- **Lua Modules**: See [MODULES.md](MODULES.md)
- **Troubleshooting**: See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **Issues**: File issues in GitHub with `[Platform]` prefix

---

**Ready to begin?** Start with Phase 1:

```bash
cd ~/.dotfiles
make help
```
