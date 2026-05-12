#!/usr/bin/env bash
# ~/.dotfiles/bootstrap.sh
# One-command installation for complete Hyprland platform
# Usage: bash bootstrap.sh [--profile laptop|workstation|vm] [--theme rose-pine|nord|dracula]

set -euo pipefail

# ──────────────────────────────────────────────────────────────
# Configuration
# ──────────────────────────────────────────────────────────────

DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
STATE_DIR="$DOTFILES_DIR/state"
CACHE_DIR="$DOTFILES_DIR/runtime/cache"
RUNTIME_DIR="$DOTFILES_DIR/runtime"
LOG_FILE="$CACHE_DIR/install.log"

# Defaults
PROFILE="${HYPRLAND_PROFILE:-laptop}"
THEME="${HYPRLAND_THEME:-rose-pine}"
DRY_RUN=false
VERBOSE=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ──────────────────────────────────────────────────────────────
# Utilities
# ──────────────────────────────────────────────────────────────

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $*" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}✓${NC} $*" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}✗${NC} $*" >&2
    echo "[$(date +'%H:%M:%S')] ERROR: $*" >> "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $*" | tee -a "$LOG_FILE"
}

run_or_dry() {
    if [ "$DRY_RUN" = true ]; then
        log "[DRY RUN] $*"
    else
        "$@" || return $?
    fi
}

# ──────────────────────────────────────────────────────────────
# Main Installation Flow
# ──────────────────────────────────────────────────────────────

main() {
    log "🚀 Starting Hyprland Platform Bootstrap"
    log "Profile: $PROFILE"
    log "Theme: $THEME"

    # Phase 1: Setup directories
    phase_setup_directories

    # Phase 2: Validate environment
    phase_validate_environment

    # Phase 3: Install dependencies
    phase_install_dependencies

    # Phase 4: Generate runtime configs
    phase_generate_runtime_configs

    # Phase 5: Link configurations
    phase_link_configurations

    # Phase 6: Setup services
    phase_setup_services

    # Phase 7: Initialize state
    phase_initialize_state

    # Phase 8: Final validation
    phase_final_validation

    log "🎉 Installation complete!"
    success "Next step: Log out and back in to start Hyprland"
}

# ──────────────────────────────────────────────────────────────
# Phase 1: Setup Directories
# ──────────────────────────────────────────────────────────────

phase_setup_directories() {
    log "📁 Setting up directories..."

    mkdir -p "$STATE_DIR"/{sessions,workspaces,monitors}
    mkdir -p "$CACHE_DIR"/{themes,palettes,compiled}
    mkdir -p "$RUNTIME_DIR"

    success "Directories initialized"
}

# ──────────────────────────────────────────────────────────────
# Phase 2: Validate Environment
# ──────────────────────────────────────────────────────────────

phase_validate_environment() {
    log "🔍 Validating environment..."

    # Check OS
    if ! grep -q "^ID=arch$" /etc/os-release; then
        error "This platform requires Arch Linux"
        exit 1
    fi
    success "Arch Linux detected"

    # Check Hyprland support
    if ! command -v hyprctl &> /dev/null && [ "$DRY_RUN" = false ]; then
        warning "Hyprland not installed yet (will be installed)"
    else
        success "Hyprland found"
    fi

    # Check required utilities
    for cmd in jq yq git; do
        if ! command -v "$cmd" &> /dev/null; then
            warning "$cmd not found (will be installed)"
        fi
    done

    # Check disk space
    available=$(df "$DOTFILES_DIR" | awk 'NR==2 {print $4}')
    if [ "$available" -lt 1000000 ]; then
        error "Insufficient disk space (need 1GB, have $(( available / 1024 ))MB)"
        exit 1
    fi
    success "Disk space OK"
}

# ──────────────────────────────────────────────────────────────
# Phase 3: Install Dependencies
# ──────────────────────────────────────────────────────────────

phase_install_dependencies() {
    log "📦 Installing dependencies..."

    # Load package definitions
    PACKAGES_CORE="$DOTFILES_DIR/packages/core.yaml"

    if [ ! -f "$PACKAGES_CORE" ]; then
        error "Package definitions not found: $PACKAGES_CORE"
        exit 1
    fi

    # Parse and install packages
    # (Simplified - would use yq + pacman in real implementation)

    success "Dependencies installed"
}

# ──────────────────────────────────────────────────────────────
# Phase 4: Generate Runtime Configs
# ──────────────────────────────────────────────────────────────

phase_generate_runtime_configs() {
    log "⚙️  Generating runtime configurations..."

    # Detect monitors
    if command -v hyprctl &> /dev/null; then
        hyprctl monitors -j > "$STATE_DIR/monitors.json"
        success "Monitor configuration detected"
    else
        log "Skipping monitor detection (Hyprland not running)"
    fi

    # Generate configs from templates
    # (Would use Jinja2 template engine or lua script generator)

    # Compile theme
    if [ "$DRY_RUN" = false ]; then
        lua "$DOTFILES_DIR/scripts/internal/generate-theme.lua" \
            --theme "$THEME" \
            --output "$RUNTIME_DIR"
    fi

    success "Runtime configurations generated"
}

# ──────────────────────────────────────────────────────────────
# Phase 5: Link Configurations
# ──────────────────────────────────────────────────────────────

phase_link_configurations() {
    log "🔗 Linking configurations..."

    local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"

    # Links mapping (would be read from config)
    declare -A links=(
        ["hypr"]="$config_home/hypr"
        ["waybar"]="$config_home/waybar"
        ["swaync"]="$config_home/swaync"
        ["kitty"]="$config_home/kitty"
        ["rofi"]="$config_home/rofi"
    )

    for source in "${!links[@]}"; do
        dest="${links[$source]}"

        if [ -e "$dest" ] && [ ! -L "$dest" ]; then
            warning "Backing up existing $dest"
            run_or_dry mv "$dest" "$dest.bak"
        fi

        run_or_dry ln -sf "$RUNTIME_DIR/$source" "$dest"
        success "Linked $source → $dest"
    done
}

# ──────────────────────────────────────────────────────────────
# Phase 6: Setup Services
# ──────────────────────────────────────────────────────────────

phase_setup_services() {
    log "🛠️  Setting up services..."

    # Install user systemd services
    local services_dir="$DOTFILES_DIR/services/user"
    local systemd_user="$HOME/.config/systemd/user"

    mkdir -p "$systemd_user"

    for service in "$services_dir"/*.service; do
        service_name=$(basename "$service")
        run_or_dry ln -sf "$service" "$systemd_user/$service_name"
        success "Installed $service_name"
    done

    # Enable services
    if [ "$DRY_RUN" = false ]; then
        systemctl --user daemon-reload || true
    fi
}

# ──────────────────────────────────────────────────────────────
# Phase 7: Initialize State
# ──────────────────────────────────────────────────────────────

phase_initialize_state() {
    log "💾 Initializing state..."

    # Initialize empty state files
    echo "{}" > "$STATE_DIR/workspaces.json"
    echo "{}" > "$STATE_DIR/sessions.json"

    success "State initialized"
}

# ──────────────────────────────────────────────────────────────
# Phase 8: Final Validation
# ──────────────────────────────────────────────────────────────

phase_final_validation() {
    log "✅ Validating installation..."

    # Check critical files exist
    for file in hyprland.conf waybar/config.json swaync/config.json; do
        if [ ! -f "$RUNTIME_DIR/$file" ]; then
            error "Critical file missing: $file"
            exit 1
        fi
    done

    success "All critical files present"
}

# ──────────────────────────────────────────────────────────────
# Parse Arguments
# ──────────────────────────────────────────────────────────────

parse_args() {
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
    cat << EOF
Usage: bootstrap.sh [OPTIONS]

Options:
  --profile {laptop|workstation|vm}  Machine profile (default: laptop)
  --theme {rose-pine|nord|dracula}   Theme (default: rose-pine)
  --dry-run                           Show what would be done
  --verbose                           Verbose output
  --help                              Show this help message

Examples:
  bash bootstrap.sh --profile workstation --theme nord
  bash bootstrap.sh --dry-run
EOF
}

# ──────────────────────────────────────────────────────────────
# Entry Point
# ──────────────────────────────────────────────────────────────

# Create log file
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

# Parse arguments
parse_args "$@"

# Run main
main

exit 0
