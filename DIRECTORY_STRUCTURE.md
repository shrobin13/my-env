# Directory Structure - Modular Hyprland Platform

```
~/.dotfiles/                          # Root of entire configuration
│
├── bootstrap.sh                       # One-command installer
├── Makefile                          # Build tasks
├── README.md                         # Platform documentation
│
├── packages/
│   ├── core.yaml                     # Pacman package groups
│   ├── aur.yaml                      # AUR packages
│   └── pip-requirements.txt          # Python packages
│
├── modules/                          # Core Lua modules
│   ├── core/
│   │   ├── monitor.lua               # Multi-monitor management
│   │   ├── workspace.lua             # Workspace orchestration
│   │   ├── window.lua                # Window management
│   │   └── focus.lua                 # Focus routing
│   │
│   ├── theme/
│   │   ├── engine.lua                # Theme compilation
│   │   ├── colors.lua                # Semantic color tokens
│   │   └── palette-extractor.lua     # Wallpaper → palette
│   │
│   ├── workflow/
│   │   ├── coding-mode.lua           # IDE-optimized layout
│   │   ├── debug-mode.lua            # Debugger layout
│   │   ├── presentation-mode.lua     # Fullscreen mode
│   │   └── focus-mode.lua            # Distraction-free mode
│   │
│   ├── clipboard/
│   │   ├── daemon.lua                # Clipboard history
│   │   ├── on-change.lua             # Change handler
│   │   └── picker.lua                # Rofi-based picker
│   │
│   └── system/
│       ├── init.lua                  # Module loader
│       ├── logger.lua                # Logging utilities
│       └── ipc.lua                   # IPC dispatcher
│
├── config/                           # Static configuration files
│   ├── hyprland.conf                 # Main Hyprland config
│   ├── hypr/                         # Modular includes
│   │   ├── monitor.conf
│   │   ├── animation.conf
│   │   ├── decoration.conf
│   │   ├── input.conf
│   │   ├── keybindings.conf
│   │   ├── windowrules.conf
│   │   └── [10+ more...]
│   │
│   ├── waybar/
│   │   ├── config.jsonc              # Waybar modules
│   │   ├── style.css                 # Waybar theming
│   │   └── scripts/
│   │       ├── power-profile.sh
│   │       ├── show-temps.sh
│   │       └── [workspace indicator]
│   │
│   ├── swaync/
│   │   ├── config.json               # Notification daemon
│   │   └── style.css
│   │
│   ├── kitty/
│   │   ├── kitty.conf
│   │   ├── current-theme.conf
│   │   └── colors.conf
│   │
│   └── rofi/
│       ├── config.rasi
│       └── themes/
│           ├── rose-pine.rasi
│           └── nord.rasi
│
├── templates/                        # Runtime configuration templates
│   ├── hyprland.template.conf        # Jinja2/Lua template
│   ├── waybar.config.template        # Dynamic module config
│   ├── monitors.template.conf        # Per-monitor settings
│   └── workspaces.template.yaml      # Workspace definitions
│
├── themes/                           # Theme definitions
│   ├── rose-pine/
│   │   ├── definition.yaml           # Color definitions
│   │   ├── light.yaml
│   │   ├── dark.yaml
│   │   └── wallpapers/
│   │
│   ├── nord/
│   │   ├── definition.yaml
│   │   └── wallpapers/
│   │
│   └── dracula/
│       ├── definition.yaml
│       └── wallpapers/
│
├── scripts/
│   ├── internal/                     # Internal orchestration
│   │   ├── generate-theme.lua        # Theme compilation script
│   │   ├── start-services.sh         # Service startup order
│   │   ├── monitor-detect.lua        # Monitor topology detection
│   │   └── init-runtime.sh           # Runtime initialization
│   │
│   └── user/                         # User-facing scripts
│       ├── hyprland-update.sh        # Update management
│       ├── theme-switch.sh           # Theme switcher
│       ├── session-save.sh           # Save current session
│       ├── session-restore.sh        # Restore saved session
│       └── status.sh                 # Platform health check
│
├── services/
│   ├── user/                         # User systemd services
│   │   ├── hyprland-orchestrator.service
│   │   ├── clipboard-daemon.service
│   │   ├── waybar.service
│   │   └── swaync.service
│   │
│   └── system/
│       ├── hyprland-setup.service    # One-time setup
│       └── udev/
│           └── monitor-hotplug.rules
│
├── runtime/                          # Generated at runtime (gitignored)
│   ├── cache/
│   │   ├── themes/                   # Compiled theme configs
│   │   ├── palettes/                 # Extracted palettes
│   │   ├── thumbnails/               # Image thumbnails
│   │   └── compiled/                 # Compiled configs
│   │
│   ├── gen/                          # Generated configs
│   │   ├── hyprland.conf
│   │   ├── waybar/
│   │   ├── swaync/
│   │   └── [other generated files]
│   │
│   ├── theme-colors.lua              # Current theme colors
│   ├── current-wallpaper             # Path to current wallpaper
│   └── config-hash                   # Config change detection
│
├── state/                            # Persistent state (gitignored)
│   ├── monitors.json                 # Monitor topology
│   ├── workspaces.json               # Workspace state
│   ├── clipboard-history.json        # Clipboard history
│   │
│   ├── monitors/
│   │   ├── DP-1.json                 # Per-monitor profiles
│   │   └── HDMI-1.json
│   │
│   ├── workspaces/
│   │   ├── 1.json                    # Per-workspace layout
│   │   ├── 2.json
│   │   └── [1-10].json
│   │
│   ├── sessions/
│   │   ├── coding-mode.json          # Saved workflow sessions
│   │   ├── debug-mode.json
│   │   └── default.json
│   │
│   ├── cache/
│   │   ├── thumbnails/               # Clipboard image thumbnails
│   │   └── palettes/                 # Extracted color palettes
│   │
│   └── logs/
│       ├── orchestrator.log
│       ├── theme-engine.log
│       └── clipboard-daemon.log
│
├── profiles/
│   ├── laptop.yaml                   # Profile configs
│   ├── workstation.yaml
│   └── vm.yaml
│
├── docs/
│   ├── INSTALLATION.md
│   ├── ARCHITECTURE.md
│   ├── MODULES.md
│   ├── THEMING.md
│   ├── WORKFLOWS.md
│   ├── TROUBLESHOOTING.md
│   └── API.md
│
├── .gitignore                        # Ignore state, runtime, cache
├── .editorconfig
├── .github/
│   ├── workflows/
│   │   ├── syntax-check.yml
│   │   └── lint.yml
│   └── ISSUE_TEMPLATE.md
│
└── CONTRIBUTING.md

# Symlink targets (created by bootstrap)
~/.config/
├── hypr → ~/.dotfiles/runtime/gen/hypr/
├── waybar → ~/.dotfiles/runtime/gen/waybar/
├── swaync → ~/.dotfiles/runtime/gen/swaync/
├── kitty → ~/.dotfiles/runtime/gen/kitty/
└── rofi → ~/.dotfiles/runtime/gen/rofi/

# XDG directories used
~/.local/share/
├── hyprland/                         # Runtime data
├── clipboard/                        # Clipboard images
└── themes/                           # Downloaded themes

~/.cache/
└── hyprland/                         # Cache directory

# Environment files (loaded by services)
~/.dotfiles/.env                      # Platform env vars
~/.dotfiles/profile.env               # Machine-specific overrides
```

## Design Principles

**Modularity**

- Each component is independent and can be updated/tested separately
- Lua modules provide runtime composition
- Config templates allow dynamic generation

**Reproducibility**

- All state is persistent and versionable
- Bootstrap script creates identical setup on any Arch Linux machine
- Package versions pinned in YAML

**Maintainability**

- Single source of truth for theme (colors.lua)
- Centralized service orchestration
- Clear separation of concerns (config/modules/scripts)

**Performance**

- Config generation happens at startup, not runtime
- Compiled theme caches avoid re-parsing
- Lazy loading of unused Lua modules
- Efficient monitor/workspace caching

**Developer Experience**

- Hot-reload capabilities (theme, keybindings, config)
- Built-in session persistence
- Integrated logging and diagnostics
- Clear error messages and rollback paths
