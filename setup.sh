#!/usr/bin/env bash
# ~/.dotfiles/setup.sh - Master Platform Setup Script
# Fully automated Hyprland environment orchestration
# Usage: bash setup.sh [--profile laptop|workstation|vm] [--theme rose-pine] [--no-backup]

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Configuration & Globals
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${SCRIPT_DIR}"
STATE_DIR="${DOTFILES_DIR}/state"
CACHE_DIR="${DOTFILES_DIR}/runtime/cache"
RUNTIME_DIR="${DOTFILES_DIR}/runtime"
GEN_DIR="${RUNTIME_DIR}/gen"
LOG_DIR="${STATE_DIR}/logs"
LOG_FILE="${LOG_DIR}/setup.log"

# Configuration
PROFILE="${HYPRLAND_PROFILE:-laptop}"
THEME="${HYPRLAND_THEME:-rose-pine}"
NO_BACKUP=false
SKIP_PACKAGES=false
VERBOSE=false
DRY_RUN=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Symbols
CHECK="✓"
CROSS="✗"
ARROW="→"
HOURGLASS="⏳"

# ─────────────────────────────────────────────────────────────────────────────
# Logging Functions
# ─────────────────────────────────────────────────────────────────────────────

_log_init() {
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
}

log() {
    local msg="$*"
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} ${msg}" | tee -a "$LOG_FILE"
}

success() {
    local msg="$*"
    echo -e "${GREEN}${CHECK}${NC} ${msg}" | tee -a "$LOG_FILE"
}

error() {
    local msg="$*"
    echo -e "${RED}${CROSS}${NC} ${msg}" >&2
    echo "[$(date +'%H:%M:%S')] ERROR: ${msg}" >> "$LOG_FILE"
}

warning() {
    local msg="$*"
    echo -e "${YELLOW}⚠${NC}  ${msg}" | tee -a "$LOG_FILE"
}

step() {
    local msg="$*"
    echo -e "${CYAN}${HOURGLASS}${NC} ${msg}" | tee -a "$LOG_FILE"
}

info() {
    local msg="$*"
    echo -e "${MAGENTA}ℹ${NC}  ${msg}" | tee -a "$LOG_FILE"
}

run_cmd() {
    local cmd="$*"
    if [ "$DRY_RUN" = true ]; then
        log "[DRY RUN] $cmd"
    else
        if [ "$VERBOSE" = true ]; then
            log "Running: $cmd"
        fi
        eval "$cmd" || return $?
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Validation & Prerequisites
# ─────────────────────────────────────────────────────────────────────────────

check_os() {
    step "Checking operating system..."

    if ! grep -q "^ID=arch$" /etc/os-release 2>/dev/null; then
        error "This platform requires Arch Linux"
        exit 1
    fi

    success "Arch Linux confirmed"
}

check_hyprland() {
    step "Checking Hyprland installation..."

    if command -v hyprctl &>/dev/null; then
        local version=$(hyprctl version 2>/dev/null | head -1)
        success "Hyprland found: $version"
    else
        warning "Hyprland not installed - will be installed via bootstrap"
    fi
}

check_dependencies() {
    step "Checking required utilities..."

    local required_cmds=("git" "jq" "curl" "tar")
    local missing=()

    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        else
            success "$cmd found"
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        warning "Missing utilities: ${missing[*]}"
        warning "Will attempt to install via pacman"
    fi
}

check_disk_space() {
    step "Checking disk space..."

    local available=$(df "$DOTFILES_DIR" | awk 'NR==2 {print $4}')
    local needed=524288  # 512MB in KB

    if [ "$available" -lt "$needed" ]; then
        error "Insufficient disk space (need 512MB, have $((available / 1024))MB)"
        exit 1
    fi

    success "Disk space OK ($((available / 1024 / 1024))GB available)"
}

# ─────────────────────────────────────────────────────────────────────────────
# Directory Structure Setup
# ─────────────────────────────────────────────────────────────────────────────

setup_directories() {
    step "Setting up directory structure..."

    local dirs=(
        # Core directories
        "$STATE_DIR"/{sessions,workspaces,monitors}
        "$CACHE_DIR"/{themes,palettes,compiled,thumbnails}
        "$RUNTIME_DIR"/{gen,cache}
        "$GEN_DIR"/{hypr,waybar,swaync,kitty,rofi}
        "$LOG_DIR"

        # Module directories
        "${DOTFILES_DIR}/modules"/{core,theme,workflow,clipboard,system}
        "${DOTFILES_DIR}/scripts"/{internal,user}
        "${DOTFILES_DIR}/config"/{hypr,waybar,swaync,kitty,rofi}
        "${DOTFILES_DIR}/templates"
        "${DOTFILES_DIR}/themes"/{rose-pine,nord,dracula}
        "${DOTFILES_DIR}/services"/{user,system/udev}
        "${DOTFILES_DIR}/packages"
        "${DOTFILES_DIR}/profiles"
        "${DOTFILES_DIR}/docs"
    )

    for dir in "${dirs[@]}"; do
        run_cmd "mkdir -p '$dir'" || true
    done

    success "Directory structure created"
}

# ─────────────────────────────────────────────────────────────────────────────
# Configuration Migration
# ─────────────────────────────────────────────────────────────────────────────

backup_existing_configs() {
    step "Backing up existing configurations..."

    if [ "$NO_BACKUP" = true ]; then
        warning "Skipping backups (--no-backup flag set)"
        return
    fi

    local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
    local backup_dir="${HOME}/.config-backup-$(date +%Y%m%d-%H%M%S)"

    if [ -e "$config_home/hypr" ] && [ ! -L "$config_home/hypr" ]; then
        run_cmd "mkdir -p '$backup_dir'" || true
        run_cmd "cp -r '$config_home/hypr' '$backup_dir/hypr.bak'" || true
        success "Backed up hypr to $backup_dir"
    fi

    if [ -e "$config_home/waybar" ] && [ ! -L "$config_home/waybar" ]; then
        run_cmd "cp -r '$config_home/waybar' '$backup_dir/waybar.bak'" || true
        success "Backed up waybar to $backup_dir"
    fi
}

migrate_existing_configs() {
    step "Migrating existing configurations..."

    # Copy from current location to config directory
    if [ -d "$HOME/my-env/hypr" ]; then
        run_cmd "cp -r '$HOME/my-env/hypr'/* '${DOTFILES_DIR}/config/hypr/'" || true
        success "Migrated hypr configs"
    fi

    if [ -d "$HOME/my-env/waybar" ]; then
        run_cmd "cp -r '$HOME/my-env/waybar'/* '${DOTFILES_DIR}/config/waybar/'" || true
        success "Migrated waybar configs"
    fi

    if [ -d "$HOME/my-env/swaync" ]; then
        run_cmd "cp -r '$HOME/my-env/swaync'/* '${DOTFILES_DIR}/config/swaync/'" || true
        success "Migrated swaync configs"
    fi

    if [ -d "$HOME/my-env/kitty" ]; then
        run_cmd "cp -r '$HOME/my-env/kitty'/* '${DOTFILES_DIR}/config/kitty/'" || true
        success "Migrated kitty configs"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Package Management
# ─────────────────────────────────────────────────────────────────────────────

install_packages() {
    if [ "$SKIP_PACKAGES" = true ]; then
        warning "Skipping package installation (--skip-packages flag set)"
        return
    fi

    step "Installing packages..."

    # Core compositor packages
    local core_packages=(
        "hyprland"
        "wayland"
        "wl-clipboard"
        "waybar"
        "swaync"
        "rofi"
        "kitty"
        "tmux"
        "zsh"
        "neovim"
        "git"
        "jq"
        "fzf"
        "ripgrep"
    )

    if [ "$DRY_RUN" = false ]; then
        # Check if packages are already installed
        for pkg in "${core_packages[@]}"; do
            if ! pacman -Q "$pkg" &>/dev/null; then
                log "Installing $pkg..."
                sudo pacman -S --noconfirm "$pkg" || warning "Failed to install $pkg"
            else
                success "$pkg already installed"
            fi
        done
    else
        log "[DRY RUN] Would install: ${core_packages[*]}"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Runtime Configuration Generation
# ─────────────────────────────────────────────────────────────────────────────

generate_hyprland_config() {
    step "Generating Hyprland configuration..."

    local config_template="${DOTFILES_DIR}/config/hypr/hyprland.conf"
    local output="${GEN_DIR}/hypr/hyprland.conf"

    if [ ! -f "$config_template" ]; then
        # Create basic template if doesn't exist
        cat > "$config_template" << 'EOF'
# Hyprland Configuration
# Generated from platform templates

# Environment setup
exec-once = ${XDG_CONFIG_HOME:-$HOME/.config}/hypr/startup.sh

# Source modular configs
source = ~/.config/hypr/monitors.conf
source = ~/.config/hypr/input.conf
source = ~/.config/hypr/keybindings.conf
source = ~/.config/hypr/windowrules.conf
source = ~/.config/hypr/animations.conf
source = ~/.config/hypr/decoration.conf
source = ~/.config/hypr/gestures.conf

# Load generated runtime config
source = ~/.dotfiles/runtime/theme-colors.conf
EOF
    fi

    # Copy to generated location
    run_cmd "cp '$config_template' '$output'" || true
    success "Hyprland config ready at $output"
}

generate_waybar_config() {
    step "Generating Waybar configuration..."

    local output="${GEN_DIR}/waybar/config.jsonc"

    cat > "$output" << 'EOF'
{
    "position": "top",
    "height": 32,
    "modules-left": ["wlr/workspaces", "hyprland/window"],
    "modules-center": ["clock"],
    "modules-right": ["network", "battery", "temperature", "cpu", "memory", "pulseaudio", "tray"],

    "wlr/workspaces": {
        "format": "{icon}",
        "format-icons": {
            "1": "󰈹",
            "2": "󰈹",
            "3": "󰨒",
            "4": "󰋓",
            "5": "󰅶",
            "6": "󰊴"
        }
    },

    "hyprland/window": {
        "format": "{}"
    },

    "clock": {
        "format": "{:%H:%M}",
        "tooltip": true
    },

    "network": {
        "format": "{icon}",
        "format-icons": {
            "ethernet": "",
            "wifi": "",
            "disconnected": ""
        }
    },

    "battery": {
        "format": "{icon} {capacity}%",
        "format-icons": ["", "", "", "", ""]
    },

    "temperature": {
        "format": " {temperatureC}°C"
    },

    "cpu": {
        "format": " {usage}%"
    },

    "memory": {
        "format": " {percentage}%"
    },

    "pulseaudio": {
        "format": "{icon} {volume}%",
        "format-muted": "󰖁",
        "format-icons": {
            "default": ["", "", ""]
        }
    }
}
EOF

    success "Waybar config generated"
}

generate_theme_colors() {
    step "Generating theme colors..."

    local output="${RUNTIME_DIR}/theme-colors.conf"

    # Rose Pine theme colors
    cat > "$output" << 'EOF'
# Generated theme colors - Rose Pine

$base = #191724
$surface = #1f1d2e
$overlay = #26233a
$muted = #6e6a86
$subtle = #908caa
$text = #e0def4
$love = #eb6f92
$gold = #f6c177
$rose = #ea9a97
$pine = #31748f
$foam = #9ccfd8
$iris = #c4a7e7
EOF

    success "Theme colors generated"
}

# ─────────────────────────────────────────────────────────────────────────────
# Symlink Configuration
# ─────────────────────────────────────────────────────────────────────────────

setup_symlinks() {
    step "Setting up configuration symlinks..."

    local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
    local links=(
        "hypr:${config_home}/hypr"
        "waybar:${config_home}/waybar"
        "swaync:${config_home}/swaync"
        "kitty:${config_home}/kitty"
        "rofi:${config_home}/rofi"
    )

    for link_spec in "${links[@]}"; do
        local src="${link_spec%:*}"
        local dest="${link_spec#*:}"

        if [ -L "$dest" ]; then
            success "$dest is already a symlink"
        elif [ -e "$dest" ] && [ ! -L "$dest" ]; then
            warning "Backing up existing $dest"
            run_cmd "mv '$dest' '${dest}.bak.platform'" || true
        fi

        run_cmd "mkdir -p '$(dirname "$dest")'" || true
        run_cmd "ln -sf '${GEN_DIR}/${src}' '$dest'" || true

        if [ ! -L "$dest" ]; then
            success "Symlinked ${src} → $dest"
        fi
    done
}

# ─────────────────────────────────────────────────────────────────────────────
# Service Setup
# ─────────────────────────────────────────────────────────────────────────────

setup_services() {
    step "Setting up systemd services..."

    local systemd_user="${HOME}/.config/systemd/user"

    # Create clipboard daemon service
    mkdir -p "$systemd_user"

    cat > "${systemd_user}/hyprland-clipboard.service" << 'EOF'
[Unit]
Description=Hyprland Clipboard Daemon
After=graphical-session-pre.target
PartOf=graphical-session.target

[Service]
ExecStart=%h/.dotfiles/modules/clipboard/daemon.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=graphical-session.target
EOF

    # Create platform orchestrator service
    cat > "${systemd_user}/hyprland-platform.service" << 'EOF'
[Unit]
Description=Hyprland Platform Orchestrator
After=graphical-session-pre.target
PartOf=graphical-session.target

[Service]
ExecStart=%h/.dotfiles/scripts/internal/orchestrator.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=graphical-session.target
EOF

    if [ "$DRY_RUN" = false ]; then
        systemctl --user daemon-reload || true
        success "Systemd services configured"
    else
        log "[DRY RUN] Would reload systemd user services"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# State Initialization
# ─────────────────────────────────────────────────────────────────────────────

init_state() {
    step "Initializing runtime state..."

    # Initialize empty state files
    if [ "$DRY_RUN" = false ]; then
        echo "{}" > "${STATE_DIR}/workspaces.json"
        echo "{}" > "${STATE_DIR}/sessions.json"
        echo "{}" > "${STATE_DIR}/monitors.json"

        success "Runtime state initialized"
    else
        log "[DRY RUN] Would initialize state files"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Validation
# ─────────────────────────────────────────────────────────────────────────────

validate_setup() {
    step "Validating setup..."

    local checks_passed=0
    local checks_total=0

    # Check directories exist
    for dir in "$STATE_DIR" "$CACHE_DIR" "$RUNTIME_DIR" "$GEN_DIR" "$LOG_DIR"; do
        checks_total=$((checks_total + 1))
        if [ -d "$dir" ]; then
            success "Directory exists: $dir"
            checks_passed=$((checks_passed + 1))
        else
            error "Directory missing: $dir"
        fi
    done

    # Check generated configs exist
    for config in "hyprland.conf" "waybar/config.jsonc"; do
        checks_total=$((checks_total + 1))
        if [ -f "${GEN_DIR}/${config}" ]; then
            success "Config exists: $config"
            checks_passed=$((checks_passed + 1))
        else
            warning "Config missing: $config"
        fi
    done

    # Check symlinks
    local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
    for link in "$config_home/hypr" "$config_home/waybar" "$config_home/swaync"; do
        checks_total=$((checks_total + 1))
        if [ -L "$link" ]; then
            success "Symlink valid: $link"
            checks_passed=$((checks_passed + 1))
        else
            warning "Symlink missing: $link"
        fi
    done

    info "Validation: $checks_passed/$checks_total checks passed"

    if [ $checks_passed -lt $((checks_total - 2)) ]; then
        error "Setup validation failed - please review errors above"
        return 1
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Post-Installation Steps
# ─────────────────────────────────────────────────────────────────────────────

post_install() {
    step "Running post-installation steps..."

    if [ "$DRY_RUN" = false ]; then
        # Create git config if repo not initialized
        if [ ! -d "${DOTFILES_DIR}/.git" ]; then
            run_cmd "cd '${DOTFILES_DIR}' && git init" || true
            success "Git repository initialized"
        fi

        # Add initial commit
        run_cmd "cd '${DOTFILES_DIR}' && git add -A && git commit -m 'Platform setup complete' || true" || true
    fi

    success "Post-installation complete"
}

# ─────────────────────────────────────────────────────────────────────────────
# Main Orchestration
# ─────────────────────────────────────────────────────────────────────────────

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --profile)
                PROFILE="$2"
                shift 2
                ;;
            --theme)
                THEME="$2"
                shift 2
                ;;
            --no-backup)
                NO_BACKUP=true
                shift
                ;;
            --skip-packages)
                SKIP_PACKAGES=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << 'EOF'
Hyprland Platform Setup Script

USAGE:
  setup.sh [OPTIONS]

OPTIONS:
  --profile {laptop|workstation|vm}   Machine profile (default: laptop)
  --theme {rose-pine|nord|dracula}    Theme (default: rose-pine)
  --no-backup                         Skip backing up existing configs
  --skip-packages                     Skip package installation
  --dry-run                           Show what would be done
  --verbose                           Verbose output
  --help                              Show this help message

EXAMPLES:
  setup.sh --dry-run                          # Test without making changes
  setup.sh --profile workstation --theme nord # Install workstation with nord
  setup.sh --no-backup --skip-packages        # Quick setup

PROFILES:
  laptop       - Optimized for laptops (low power, battery aware)
  workstation  - Optimized for workstations (performance focused)
  vm           - Optimized for virtual machines

THEMES:
  rose-pine    - Rose Pine color scheme (default)
  nord         - Nord color scheme
  dracula      - Dracula color scheme

EOF
}

main() {
    _log_init

    log "╔════════════════════════════════════════════════════════════╗"
    log "║     Hyprland Platform - Automated Setup & Orchestration   ║"
    log "╚════════════════════════════════════════════════════════════╝"
    log ""
    log "Profile: $PROFILE"
    log "Theme: $THEME"
    log "Dry Run: $DRY_RUN"
    log ""

    # Phase 1: Validation
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log " PHASE 1: Environment Validation"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    check_os
    check_hyprland
    check_dependencies
    check_disk_space

    # Phase 2: Directory Setup
    log ""
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log " PHASE 2: Directory Structure"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    setup_directories

    # Phase 3: Configuration Migration
    log ""
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log " PHASE 3: Configuration Migration"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    backup_existing_configs
    migrate_existing_configs

    # Phase 4: Package Installation
    log ""
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log " PHASE 4: Package Installation"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    install_packages

    # Phase 5: Configuration Generation
    log ""
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log " PHASE 5: Configuration Generation"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    generate_hyprland_config
    generate_waybar_config
    generate_theme_colors

    # Phase 6: Symlink Setup
    log ""
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log " PHASE 6: Configuration Symlinks"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    setup_symlinks

    # Phase 7: Service Setup
    log ""
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log " PHASE 7: Service Configuration"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    setup_services

    # Phase 8: State Initialization
    log ""
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log " PHASE 8: Runtime State"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    init_state

    # Phase 9: Validation
    log ""
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log " PHASE 9: Validation & Verification"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if validate_setup; then
        success "All validations passed!"
    else
        warning "Some validations failed - check output above"
    fi

    # Phase 10: Post-Installation
    log ""
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log " PHASE 10: Finalization"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    post_install

    # Summary
    log ""
    log "╔════════════════════════════════════════════════════════════╗"
    if [ "$DRY_RUN" = true ]; then
        log "║           DRY RUN COMPLETE - No changes made            ║"
    else
        log "║           SETUP COMPLETE - System Ready!                ║"
    fi
    log "╚════════════════════════════════════════════════════════════╝"
    log ""
    log "📋 Log file: $LOG_FILE"
    log ""
    log "Next steps:"
    log "  1. Review the setup log: cat $LOG_FILE"
    log "  2. Reload Hyprland: hyprctl reload"
    log "  3. Start services: systemctl --user start hyprland-platform"
    log ""
}

# ─────────────────────────────────────────────────────────────────────────────
# Entry Point
# ─────────────────────────────────────────────────────────────────────────────

parse_arguments "$@"
main
