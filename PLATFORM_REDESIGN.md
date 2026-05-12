# 🏗️ HYPRLAND PLATFORM REDESIGN — Complete Architecture

**Status**: Complete Architecture Specification
**Date**: 2026-05-13
**Target**: Production-grade, Lua-native, reproducible Hyprland ecosystem
**Scale**: Full operating environment, not just dotfiles

---

## 📋 EXECUTIVE OVERVIEW

### Current State

Collection of modular configs with bash scripts. Good foundation but lacks:

- Reproducibility
- Lua-native automation
- Theme engine
- Deployment infrastructure
- Performance optimization
- Clipboard architecture
- Monitor awareness
- Developer workflow automation

### Target State

**Professional desktop platform** with:

- Complete bootstrap system
- Lua-native orchestration
- Dynamic config generation
- Theme engine with live reload
- Advanced monitor/workspace management
- Professional clipboard system
- Integrated development workflows
- Full reproducibility guarantee

### Architecture Philosophy

```
Traditional dotfiles:          →    Modern Platform:
configs only                        configs + runtime + orchestration
shell scripts                       Lua modules + event system
manual setup                        automated bootstrap
static theme                        dynamic theme engine
per-app configuration             centralized policy layer
```

---

## 🏛️ COMPLETE DIRECTORY STRUCTURE

```
~/.dotfiles/
├── README.md
├── LICENSE
├── ARCHITECTURE.md
├── BOOTSTRAP.md
├── bootstrap.sh                    ← Entry point
├── install.sh                      ← Orchestrator
├── Makefile                        ← Common tasks
│
├── .envrc                          ← Direnv config
│
├── config/                         ← User-facing configs
│   ├── profile.yaml               ← Machine/user profile
│   ├── themes.yaml                ← Theme definitions
│   ├── monitors.yaml              ← Monitor profiles
│   └── packages.yaml              ← Package groups
│
├── deploy/                         ← Deployment orchestration
│   ├── bootstrap.sh               ← Initial setup
│   ├── install-deps.sh            ← Package installation
│   ├── link-configs.sh            ← Symlink management
│   ├── setup-services.sh          ← Systemd/init
│   ├── validate-setup.sh          ← Verification
│   ├── generate-runtime.sh        ← Runtime config generator
│   └── rollback.sh                ← Rollback system
│
├── lib/                           ← Shared utilities
│   ├── logger.sh                  ← Logging framework
│   ├── utils.sh                   ← Shell utilities
│   ├── colors.sh                  ← Terminal colors
│   ├── config.lua                 ← Lua utilities
│   └── validators.sh              ← Setup validators
│
├── runtime/                       ← Generated at runtime
│   ├── hyprland.conf              ← Generated from templates
│   ├── waybar-config.json         ← Generated theme-aware
│   ├── swaync-config.json         ← Generated theme-aware
│   ├── env.sh                     ← Sourced environment vars
│   └── cache/                     ← Build artifacts
│       ├── themes/
│       ├── palettes/
│       └── compiled/
│
├── modules/                       ← Lua-native automation
│   ├── init.lua                   ← Module loader
│   ├── core/
│   │   ├── workspace.lua          ← Workspace management
│   │   ├── monitor.lua            ← Monitor awareness
│   │   ├── layout.lua             ── Layout engine
│   │   ├── focus.lua              ← Focus controller
│   │   ├── tiling.lua             ← Tiling state
│   │   └── animations.lua         ← Animation controller
│   ├── workflow/
│   │   ├── coding-mode.lua        ← IDE/coding layout
│   │   ├── debug-mode.lua         ← Debugging layout
│   │   ├── browser-mode.lua       ← Browser workspace
│   │   ├── docs-mode.lua          ← Documentation
│   │   ├── focus-mode.lua         ← Distraction-free
│   │   ├── session.lua            ← Session persistence
│   │   └── project.lua            ← Project management
│   ├── input/
│   │   ├── keyboard.lua           ← Keyboard profiles
│   │   ├── mouse.lua              ← Mouse profiles
│   │   ├── touchpad.lua           ← Touchpad behavior
│   │   ├── gestures.lua           ← Gesture system
│   │   └── routing.lua            ← Device routing
│   ├── clipboard/
│   │   ├── daemon.lua             ← Clipboard daemon
│   │   ├── history.lua            ← History management
│   │   ├── preview.lua            ← Previews
│   │   ├── sync.lua               ← Cross-session sync
│   │   └── handlers.lua           ← MIME handlers
│   ├── theme/
│   │   ├── engine.lua             ← Theme compilation
│   │   ├── compiler.lua           ← Color palette
│   │   ├── extractors.lua         ← Wallpaper extraction
│   │   └── generators.lua         ← Config generation
│   ├── notification/
│   │   ├── routing.lua            ← Notification routing
│   │   └── styles.lua             ← Styling system
│   └── monitoring/
│       ├── perf.lua               ← Performance monitor
│       ├── health.lua             ← System health
│       └── diagnostics.lua        ← Troubleshooting
│
├── scripts/                       ← Executable utilities
│   ├── bin/
│   │   ├── hyprctl-wrapper        ← Enhanced hyprctl
│   │   ├── layout-switch          ← Layout management
│   │   ├── workspace-jump         ← Workspace nav
│   │   ├── monitor-configure      ← Monitor setup
│   │   ├── clipboard-manager      ← Clipboard CLI
│   │   ├── theme-switch           ← Theme manager
│   │   ├── session-restore        ← Session recovery
│   │   └── perf-profile           ← Performance profiling
│   └── internal/
│       ├── generate-theme.lua     ← Theme compilation
│       ├── extract-palette.sh     ← Color extraction
│       └── setup-monitors.lua     ← Monitor detection
│
├── templates/                     ← Config templates
│   ├── hyprland.conf.jinja        ← Main config template
│   ├── waybar/
│   │   ├── config.json.jinja
│   │   └── style.css.jinja
│   ├── swaync/
│   │   ├── config.json.jinja
│   │   └── style.css.jinja
│   ├── kitty/
│   │   └── kitty.conf.jinja
│   ├── rofi/
│   │   └── theme.rasi.jinja
│   └── gtk/
│       └── settings.ini.jinja
│
├── themes/                        ← Theme definitions
│   ├── rose-pine/
│   │   ├── definition.yaml        ← Color tokens
│   │   ├── wallpapers/            ← Theme-specific wallpapers
│   │   └── overrides.yaml         ← App-specific tweaks
│   ├── nord/
│   │   └── definition.yaml
│   ├── dracula/
│   │   └── definition.yaml
│   └── system/
│       └── definition.yaml        ← System palette extraction
│
├── profiles/                      ← Machine profiles
│   ├── laptop/
│   │   ├── monitors.yaml
│   │   ├── packages.yaml
│   │   ├── overrides.yaml
│   │   └── keybinds.yaml
│   ├── workstation/
│   │   ├── monitors.yaml
│   │   ├── packages.yaml
│   │   └── overrides.yaml
│   └── vm/
│       ├── monitors.yaml
│       └── packages.yaml
│
├── packages/                      ← Package groups
│   ├── core.yaml                  ← Core dependencies
│   ├── development.yaml           ← Dev tools
│   ├── optional.yaml              ← Optional packages
│   ├── fonts.yaml                 ← Font definitions
│   ├── themes.yaml                ← Theme packages
│   └── aur.yaml                   ← AUR packages
│
├── services/                      ← Systemd/runtime services
│   ├── user/
│   │   ├── hyprland-session.service
│   │   ├── hyprland-orchestrator.service
│   │   ├── theme-daemon.service
│   │   ├── clipboard-daemon.service
│   │   └── workspace-monitor.service
│   └── system/
│       ├── hyprland-bootstrap.service
│       └── hyprland-cleanup.service
│
├── assets/                        ← Static resources
│   ├── wallpapers/
│   │   ├── default/
│   │   └── themes/
│   ├── icons/
│   ├── cursors/
│   └── fonts/
│
├── state/                         ← Persistent runtime state
│   ├── .cache/
│   ├── sessions/
│   ├── workspaces.yaml
│   └── monitors.yaml
│
├── docs/                          ← Documentation
│   ├── ARCHITECTURE.md
│   ├── SETUP.md
│   ├── USAGE.md
│   ├── LUA_API.md
│   ├── THEME_ENGINE.md
│   ├── DEPLOYMENT.md
│   ├── TROUBLESHOOTING.md
│   └── DEVELOPMENT.md
│
├── tests/                         ← Test suite
│   ├── unit/
│   ├── integration/
│   └── e2e/
│
├── examples/                      ← Example configs
│   ├── coding-workflow/
│   ├── fullscreen-gaming/
│   ├── presentation-mode/
│   └── multi-monitor/
│
└── .github/
    ├── workflows/
    ├── ISSUE_TEMPLATE/
    └── PULL_REQUEST_TEMPLATE/
```

---

## 🚀 BOOTSTRAP SYSTEM

### Entry Point: `bootstrap.sh`

```bash
#!/usr/bin/env bash
# ~/.dotfiles/bootstrap.sh
# One-command installation for complete Hyprland platform

set -euo pipefail

# Detect environment
DISTRO=$(grep ^ID= /etc/os-release | cut -d= -f2 | tr -d '"')
PROFILE="${HYPRLAND_PROFILE:-laptop}"
THEME="${HYPRLAND_THEME:-rose-pine}"

# Phase 1: Validate environment
echo "🔍 Validating environment..."
bash deploy/validate-setup.sh

# Phase 2: Install dependencies
echo "📦 Installing dependencies..."
bash deploy/install-deps.sh

# Phase 3: Generate runtime configs
echo "⚙️  Generating runtime configurations..."
bash deploy/generate-runtime.sh --profile "$PROFILE" --theme "$THEME"

# Phase 4: Link configs
echo "🔗 Linking configurations..."
bash deploy/link-configs.sh --profile "$PROFILE"

# Phase 5: Setup services
echo "🛠️  Setting up services..."
bash deploy/setup-services.sh

# Phase 6: Final validation
echo "✅ Validating installation..."
bash deploy/validate-setup.sh --full

echo "🎉 Installation complete!"
echo "Log out and back in to start Hyprland"
```

### Orchestration Layer: `install.sh`

Main orchestrator that coordinates all setup phases with:

- Dependency tracking
- Rollback capability
- Partial installs
- Idempotency
- Error recovery

---

## 🧩 MODULAR CONFIG STRUCTURE

### Current: 11 separate files with duplication

### Target: Centralized templates + runtime generation

**System**:

```
templates/hyprland.conf.jinja
├── Variables section (from config/profile.yaml)
├── Core settings (from modules)
├── Keybindings (generated from lua/)
├── Window rules (generated from modules)
└── Generated at: runtime/hyprland.conf
```

**Theme System**:

```
themes/rose-pine/definition.yaml
├── Color palette (semantic tokens)
├── Typography
├── Spacing scale
├── Opacity system

Generated configs:
├── waybar/style.css (theme-aware)
├── swaync/style.css (theme-aware)
├── kitty/kitty.conf (color scheme)
├── gtk/settings.ini (GTK theme)
└── rofi/theme.rasi (launcher theme)
```

---

## 🔮 LUA-NATIVE AUTOMATION

### Core Lua Platform

All dynamic behavior moved to Lua instead of bash scripts:

#### 1. Workspace Manager (`modules/core/workspace.lua`)

```lua
local Workspace = {}

-- Smart workspace allocation
function Workspace.auto_allocate(client_class)
    -- Routes apps to appropriate workspaces based on type
    -- Returns workspace ID or creates new if needed
end

-- Persistent workspace state
function Workspace.persist()
    -- Saves current workspace layout to state file
end

function Workspace.restore()
    -- Restores previous session
end

-- Monitor-aware workspace navigation
function Workspace.nav_monitor(direction)
    -- Intelligently navigate workspaces across monitors
end

return Workspace
```

#### 2. Monitor Manager (`modules/core/monitor.lua`)

```lua
local Monitor = {}

-- Hot-plug detection
function Monitor.on_connect()
    -- Auto-apply saved monitor profile
    -- Restore workspace layouts
    -- Trigger theme refresh if needed
end

function Monitor.on_disconnect()
    -- Gracefully fold workspaces
    -- Preserve window states
    -- Restore single-monitor layout
end

-- Monitor role detection
function Monitor.detect_roles()
    -- Identifies primary (main), secondary (work), tertiary (reference)
    -- Returns workspace allocation strategy
end

return Monitor
```

#### 3. Tiling State Engine (`modules/core/tiling.lua`)

```lua
local Tiling = {}

-- Advanced layout behaviors
function Tiling.rotatesplit()
    -- Rotate split orientation
end

function Tiling.consume_or_expel()
    -- Smart consume/expel logic
end

function Tiling.spring_physics()
    -- Apply spring animations to windows
end

-- Dynamic gap adjustment
function Tiling.adaptive_gaps(window_count)
    -- Adjust gaps based on layout density
end

return Tiling
```

#### 4. Workflow System (`modules/workflow/*.lua`)

```lua
-- Coding Mode: IDE-optimized layout
local CodingMode = {
    layout = "dwindle",
    gaps = {in = 5, out = 5},
    floating_class_exclude = {"kitty", "neovim"},
    workspace_rules = {
        -- Editor workspace
        [1] = {monitor = "primary", layout = "dwindle"},
        -- Terminal workspace
        [2] = {monitor = "primary", layout = "dwindle"},
        -- Browser workspace
        [3] = {monitor = "secondary", layout = "dwindle"},
        -- Reference/docs
        [4] = {monitor = "tertiary", layout = "dwindle"},
    }
}

function CodingMode.activate()
    -- Apply layout rules
    -- Restore previous session if exists
    -- Setup keybind context
end

-- Focus Mode: Distraction-free
local FocusMode = {
    hide_waybar = true,
    hide_notifications = true,
    blur_inactive = 0.5,
    gaps = {in = 0, out = 0},
}

function FocusMode.activate()
    -- Single-fullscreen window
    -- Disable all overlays
end

return CodingMode
```

#### 5. Clipboard System (`modules/clipboard/daemon.lua`)

```lua
local ClipboardDaemon = {}

-- Persistent history
function ClipboardDaemon.store(content, mime_type)
    -- Store with timestamp
    -- Preserve images with signatures
    -- Handle large payloads
end

function ClipboardDaemon.get_history(filter, limit)
    -- Fuzzy-searchable history
    -- MIME-type filtering
end

-- Cross-session sync
function ClipboardDaemon.sync_sessions()
    -- Share clipboard between sessions
    -- Conflict resolution
end

-- Smart handlers
function ClipboardDaemon.on_image(path)
    -- Extract palette from image
    -- Generate thumbnail
    -- Store with metadata
end

return ClipboardDaemon
```

#### 6. Theme Engine (`modules/theme/engine.lua`)

```lua
local ThemeEngine = {}

-- Dynamic theme compilation
function ThemeEngine.compile(theme_name, wallpaper_path)
    -- Extract palette from wallpaper (optional)
    -- Load theme definition
    -- Generate all config files
    -- Apply live reload
end

-- Live theme reload
function ThemeEngine.reload()
    -- Recompile all configs
    -- Reload without logout
    -- Smooth color transitions
end

-- Day/night mode
function ThemeEngine.set_mode(mode)
    -- "light", "dark", "auto"
    -- Compile appropriate theme variant
    -- Sync across all apps
end

return ThemeEngine
```

---

## 🎨 THEME ENGINE ARCHITECTURE

### Single Source of Truth

```yaml
# themes/rose-pine/definition.yaml

name: Rose Pine
metadata:
  author: Emacs Roses
  license: MIT
  version: 1.0

semantics:
  # Semantic color tokens (not raw colors)
  background: &bg '#191724'
  surface: &surface '#1f1d2e'
  text: &text '#e0def4'
  accent: &accent '#c4a7e7'
  success: &success '#31748f'
  warning: &warning '#f6c177'
  error: &error '#eb6f92'

opacity:
  active: 1.0
  inactive: 0.95
  floating: 0.98
  overlay: 0.85

spacing:
  scale: 4px # Everything derives from this
  gaps_in: 5
  gaps_out: 5
  radius: 4

blur:
  enabled: true
  size: 3
  passes: 1
  opacity_ignore: false

shadow:
  enabled: true
  range: 3
  power: 2
  color: 'rgba(26, 26, 26, 0.8)'

# App-specific overrides
app_overrides:
  waybar:
    blur: true
    opacity: 0.75

  rofi:
    blur: true
    border_width: 2

  swaync:
    blur: true
    radius: 12
```

### Runtime Generation Strategy

```
themes/rose-pine/definition.yaml
    ↓
[ThemeEngine.compile()]
    ↓
Generated outputs:
  ├── runtime/theme-colors.lua  (Lua module)
  ├── waybar/style.css           (color vars substituted)
  ├── swaync/style.css
  ├── kitty/colors.conf
  ├── rofi/theme.rasi
  ├── gtk/settings.ini
  └── runtime/env.sh             (exported as env vars)

Live reload:
  ThemeEngine.reload()
    → Recompile
    → Trigger waybar refresh
    → Reload swaync
    → Notify running apps
```

---

## 🎛️ WAYBAR + SWAYNC REDESIGN

### Waybar New Architecture

**Config Generation** (theme-aware):

```json
// Generated from templates/waybar/config.json.jinja
{
  "modules-left": ["custom/menu", "hyprland/workspaces"],
  "modules-center": ["clock"],
  "modules-right": ["group/system", "group/media", "group/power"],
  "group/system": {
    "modules": ["network", "battery", "cpu", "memory"],
    "orientation": "horizontal",
    "drawer": {
      "transition-duration": 300,
      "transition-to-right": true
    }
  }
}
```

**Dynamic Module System**:

```lua
-- Waybar communicates with Lua modules
-- Modules report state changes via events
-- Waybar rerenders via IPC

local WaybarBridge = {}

function WaybarBridge.update_module(module_name, data)
    -- Receive updates from waybar
    -- Trigger appropriate Lua handlers
end

function WaybarBridge.notify_change(event_type, data)
    -- Notify waybar of state changes
    -- Triggers module re-render
end

return WaybarBridge
```

### SwayNC Professional Redesign

```json
{
  "widget-config": {
    // Quick controls integrated with Lua
    "buttons-grid": {
      "actions": [
        {
          "label": "  ",
          "command": "lua ~/.dotfiles/modules/workflow/focus-mode.lua activate"
        },
        {
          "label": "󰂯 ",
          "command": "lua ~/.dotfiles/modules/input/bluetooth.lua toggle"
        },
        {
          "label": " ",
          "command": "hyprctl dispatch fullscreen 1"
        }
      ]
    },
    // Clipboard integration
    "clipboard-history": {
      "max-items": 50,
      "preview-images": true,
      "search-enabled": true
    }
  }
}
```

---

## 📋 CLIPBOARD SYSTEM ARCHITECTURE

### Professional Implementation

```
Wayland Clipboard Pipeline:

App A copies          App B pastes
   ↓                      ↑
wl-copy          ClipboardDaemon      wl-paste
   ↓                      ↓                ↑
   └─→ [MIME] ───→ [Storage] ───→ [History]
                    ├─ Text
                    ├─ Images (with thumbs)
                    ├─ Files
                    └─ Metadata

Features:
✓ Persistent across sessions
✓ Image preview generation
✓ Fuzzy search history
✓ MIME-type awareness
✓ Screenshot integration
✓ Annotation (with satty)
✓ Sensitive clip cleanup
✓ Sync between sessions
```

### Implementation

```lua
-- modules/clipboard/daemon.lua

local ClipboardDaemon = {
    history_file = os.getenv("HOME") .. "/.dotfiles/state/clipboard-history.json",
    max_size = 100 * 1024 * 1024,  -- 100MB
    max_items = 500,
    ttl_sensitive = 300,  -- 5 min for passwords
}

function ClipboardDaemon.init()
    -- Watch wl-clipboard events
    -- Load persistent history
    -- Setup signal handlers
end

function ClipboardDaemon.store_text(content)
    -- Sanitize content
    -- Add timestamp + hash
    -- Store to disk
    -- Trigger UI update
end

function ClipboardDaemon.store_image(path)
    -- Verify MIME type
    -- Generate thumbnail
    -- Extract dominant colors
    -- Store metadata
    -- Archive image
end

function ClipboardDaemon.get_history(filter)
    -- Full-text search
    -- MIME filtering
    -- Return ranked results
end

function ClipboardDaemon.cleanup_sensitive()
    -- Remove expired items
    -- Secure deletion
end

return ClipboardDaemon
```

---

## 🎯 DEVELOPER WORKFLOWS

### Coding Mode

```lua
-- Workspace Layout:
-- Monitor 1 (Primary):  [1] Editor + Terminal split
-- Monitor 2 (Secondary): [2] Browser
-- Monitor 3 (Tertiary):  [3] Documentation

CodingMode.layout_rules = {
    [1] = {
        -- Primary editor workspace
        layout = "dwindle",
        gaps = {in = 5, out = 5},
        window_rules = {
            -- Neovim: 60% left, terminal 40% right
            {class = "kitty", spawn = "neovim", split = "parent", ratio = 0.6},
        }
    },
}

-- Auto-route apps
CodingMode.app_routing = {
    -- Neovim always goes to [1]
    neovim = 1,
    -- Kitty goes to [1] with neovim, else [1]
    kitty = 1,
    -- Browser to [2]
    brave = 2,
    firefox = 2,
    -- Docs (zeal, devdocs) to [3]
    zeal = 3,
}

-- Smart keybinds in this mode
CodingMode.keybinds = {
    ["Super+Q"] = "Kill current window",
    ["Super+Alt+H"] = "Swap with left",
    ["Super+Alt+J"] = "Swap with down",
    ["Super+Alt+K"] = "Swap with up",
    ["Super+Alt+L"] = "Swap with right",
    ["Super+Y"] = "Toggle split",
    ["Super+G"] = "Toggle group",
}
```

### Debug Mode

```lua
-- Debugging Layout:
-- [1] IDE + Console (60/40 split)
-- [2] Terminal/REPL
-- [3] Browser (devtools)
-- Floating: Breakpoint inspector

DebugMode.activation_trigger = function()
    -- Detect debugger startup (gdb, java debug server, etc)
    -- Auto-apply layout
end

DebugMode.layout_rules = {
    [1] = {
        layout = "dwindle",
        split_ratio = 0.6,
        -- IDE on left, console on right
    },
    [3] = {
        -- Chrome DevTools
        class = "brave",
        rule = "devtools",
    }
}
```

### Browser Mode

```lua
BrowserMode.layout_rules = {
    -- Full-width primary workspace
    [2] = {
        layout = "dwindle",
        gaps = {in = 0, out = 0},
        floating_disable = true,
    }
}

BrowserMode.features = {
    -- Hide secondary workspaces
    hide_non_primary = true,
    -- Auto-hide waybar
    auto_hide_waybar = true,
    -- Keyboard shortcuts for tabs
    tab_navigation = true,
}
```

---

## ⚡ PERFORMANCE ENGINEERING

### Render Pipeline Optimization

```yaml
# config/performance.yaml

rendering:
  vfr: true # Variable Frame Rate
  vrr: true # Variable Refresh Rate
  adaptive_sync: true

  blur:
    size: 3
    passes: 1
    selective: true # Only on specific layers

  shadow:
    range: 3
    render_power: 2

  opacity:
    active: 1.0
    inactive: 0.95
    transition: 100ms # Smooth opacity changes

  animation:
    # Damage-optimized animation curves
    spring_physics: true
    bezier_optimization: true

memory:
  cache_compiled_configs: true
  lazy_load_modules: true
  cleanup_interval: 3600

startup:
  parallel_services: true
  background_services: true
  defer_heavy_apps: true

monitoring:
  gpu_profile: false # Enable with --perf-mode
  memory_tracking: false
  startup_timing: true
```

### Startup Optimization

```bash
# deploy/optimize-startup.sh

Phase 1: Parallel core services
- ibus-daemon
- hypridle
- swaync

Phase 2: Display + Wallpaper
- swww-daemon
- waypaper

Phase 3: UI Layer
- waybar

Phase 4: Automation (async)
- hyprland-orchestrator
- clipboard-daemon
- workspace-monitor
- theme-daemon

Phase 5: User apps (deferred)
- discord (start after 5s)
- browser (on-demand)
```

---

## 📍 MONITOR + WORKSPACE SYSTEM

### Monitor-Aware Architecture

```lua
-- modules/core/monitor.lua

local MonitorManager = {}

MonitorManager.roles = {
    primary = {
        index = 1,
        workspaces = {1, 2, 3},     -- Coding/main work
        purpose = "primary work",
    },
    secondary = {
        index = 2,
        workspaces = {4, 5},         -- Browser/reference
        purpose = "auxiliary",
    },
    tertiary = {
        index = 3,
        workspaces = {6},            -- Documentation/chat
        purpose = "reference",
    },
}

function MonitorManager.detect_topology()
    -- Identify physical arrangement
    -- Assign roles intelligently
    -- Return workspace allocation
end

function MonitorManager.on_connect(monitor_name)
    -- Check saved profile
    -- Apply resolution/refresh rate
    -- Restore workspace layout
    -- Update Waybar
end

function MonitorManager.on_disconnect(monitor_name)
    -- Fold workspaces to remaining monitors
    -- Preserve window states
    -- Update workspace assignment
    -- Refresh UI
end
```

### Workspace Persistence

```lua
-- Save state on logout
-- Restore state on login

SaveState:
  workspaces/
    ├── 1.json (layout, windows, positions)
    ├── 2.json
    └── ...
  monitors/
    └── topology.json (arrangement, roles)
```

---

## 🔧 DEPLOYMENT & ORCHESTRATION

### Installation Phases

```
Phase 1: Validation
  ✓ Check Arch Linux
  ✓ Verify Hyprland support
  ✓ Validate dependencies

Phase 2: Dependencies (parallel)
  ✓ Core packages (pacman)
  ✓ AUR packages (yay/paru)
  ✓ Fonts installation
  ✓ Theme setup

Phase 3: Config Generation
  ✓ Profile detection
  ✓ Template rendering
  ✓ Theme compilation
  ✓ Monitor detection

Phase 4: Installation
  ✓ Symlink configs
  ✓ Setup systemd services
  ✓ Initialize state directories
  ✓ Extract assets

Phase 5: Validation
  ✓ Config syntax check
  ✓ Dependency verification
  ✓ Service health check

Phase 6: Finalization
  ✓ Cache warm-up
  ✓ First-run setup
  ✓ Success notification
```

### Idempotent Installation

```bash
# Every deploy step is idempotent
# Safe to re-run multiple times
# Automatic rollback on failure
# Partial re-installs supported

install.sh              # Full install
install.sh --update    # Update configs only
install.sh --configs   # Regenerate configs
install.sh --packages  # Install packages only
install.sh --rollback  # Rollback to previous
```

---

## 📊 PACKAGE MANAGEMENT

### Package Groups (YAML-based)

```yaml
# packages/core.yaml
packages:
  hyprland_core:
    - hyprland
    - hypridle
    - hyprlock
    - hyprpicker
    - hyprcursor

  wayland_core:
    - wl-clipboard
    - wl-paste
    - waybar
    - swaync
    - swww
    - waypaper

  development:
    - neovim
    - kitty
    - tmux
    - git
    - nodejs
    - jdk-21

  optional:
    - discord
    - brave
    - vlc
    - blender

installation:
  core:
    - hyprland_core
    - wayland_core

  development:
    - development
    - java

  optional:
    - optional
```

### Declarative Package Installation

```bash
# install.sh orchestrates this

for profile in $(get_profiles); do
    for group in $(get_package_groups "$profile"); do
        install_packages "$group"
    done
done

# Automatic retry on failure
# Parallel installation where possible
# Dependency resolution
```

---

## 📝 CONFIGURATION GENERATION

### Template System

```jinja
{# templates/hyprland.conf.jinja #}

# Generated Hyprland Config
# Theme: {{ theme.name }}
# Profile: {{ profile.name }}
# Generated: {{ now }}

# Variables
$mainMod = {{ profile.main_mod }}
$terminal = {{ profile.terminal }}

# General settings
general {
    gaps_in = {{ theme.spacing.gaps_in }}
    gaps_out = {{ theme.spacing.gaps_out }}
    border_size = {{ theme.spacing.border_size }}
    col.active_border = {{ theme.accent }}
    col.inactive_border = {{ theme.muted }}
}

# Animations
animations {
    enabled = true
    bezier = responsive, 0.16, 1, 0.3, 1
    animation = windows, 1, 5, responsive
}

# Keybindings (generated from Lua)
{%- for binding in keybindings %}
bind = {{ binding.mod }}, {{ binding.key }}, {{ binding.action }}
{%- endfor %}

# Monitor configuration (auto-detected)
{%- for monitor in monitors %}
monitor = {{ monitor.name }}, {{ monitor.resolution }}, {{ monitor.position }}, {{ monitor.scale }}
{%- endfor %}

# Window rules (from modules)
{%- for rule in window_rules %}
windowrule = {{ rule.action }}, {{ rule.class }}
{%- endfor %}
```

---

## 🎓 DEVELOPMENT WORKFLOW

### Project Session Management

```lua
-- Auto-detect project
-- Restore previous layout
-- Setup dev environment

function ProjectSession.detect()
    -- Check for .git, package.json, build.gradle, etc.
    -- Identify project type (Laravel, Java, Web, etc.)
end

function ProjectSession.load()
    -- Apply appropriate Lua workflow module
    -- Restore previous workspace layout
    -- Pre-open common files
end

function ProjectSession.save()
    -- Persist current layout
    -- Save open files list
    -- Save position/sizes
end

-- Usage:
ProjectSession.detect()  -- Called on workspace focus
ProjectSession.load()
ProjectSession.save()    -- Called on workspace change
```

---

## 📈 ROADMAP

### Phase 1: Foundation (Week 1)

- [x] Archive structure
- [x] Bootstrap system
- [x] Package management
- [x] Config templates
- [ ] Basic Lua integration

### Phase 2: Lua Automation (Week 2)

- [ ] Workspace manager
- [ ] Monitor manager
- [ ] Theme engine
- [ ] Clipboard system
- [ ] Basic workflows

### Phase 3: Advanced Features (Week 3)

- [ ] Focus mode
- [ ] Project sessions
- [ ] Performance monitoring
- [ ] Live config reload
- [ ] Advanced gestures

### Phase 4: Polish (Week 4)

- [ ] Documentation
- [ ] Testing
- [ ] Performance optimization
- [ ] UI polish
- [ ] User experience refinement

---

## 🎯 SUCCESS CRITERIA

✅ **Reproducibility**: Identical setup across machines
✅ **Lua-native**: 80% logic in Lua, not bash
✅ **Performance**: <3s boot, 100 FPS animations
✅ **Maintainability**: Clear module structure
✅ **Developer workflow**: Optimized for coding
✅ **Professional**: Polished, coherent aesthetics
✅ **Reliable**: No race conditions, graceful failures

---

This architecture transforms Hyprland from "well-organized dotfiles" to a **professional desktop platform** with proper engineering, automation, and reproducibility.

Implementation begins with bootstrap system and scales progressively to full Lua automation.
