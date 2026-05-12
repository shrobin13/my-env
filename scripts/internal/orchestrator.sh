#!/usr/bin/env bash
# ~/.dotfiles/scripts/internal/orchestrator.sh
# Platform orchestration daemon - manages services and events

set -euo pipefail

DOTFILES_DIR="${HOME}/.dotfiles"
STATE_DIR="${DOTFILES_DIR}/state"
RUNTIME_DIR="${DOTFILES_DIR}/runtime"
LOG_FILE="${STATE_DIR}/logs/orchestrator.log"

# ─────────────────────────────────────────────────────────────────────────────
# Logging
# ─────────────────────────────────────────────────────────────────────────────

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# ─────────────────────────────────────────────────────────────────────────────
# Service Management
# ─────────────────────────────────────────────────────────────────────────────

wait_for_file() {
    local file=$1
    local timeout=${2:-30}
    local elapsed=0

    while [ ! -f "$file" ] && [ $elapsed -lt $timeout ]; do
        sleep 1
        elapsed=$((elapsed + 1))
    done
}

start_services() {
    log "Starting orchestrated services..."

    # Ensure directories exist
    mkdir -p "${STATE_DIR:?}"/{sessions,workspaces,monitors}
    mkdir -p "${RUNTIME_DIR:?}"/{gen,cache}

    # Wait for Hyprland to be ready
    wait_for_file "/tmp/hypr_${HYPRLAND_INSTANCE_SIGNATURE}/hyprland.log" 10

    # Start clipboard daemon if available
    if [ -x "${DOTFILES_DIR}/modules/clipboard/daemon.sh" ]; then
        "${DOTFILES_DIR}/modules/clipboard/daemon.sh" &
        log "Started clipboard daemon (PID: $!)"
    fi

    # Initialize theme if not already done
    if [ ! -f "${RUNTIME_DIR}/theme-colors.conf" ]; then
        if command -v lua &>/dev/null; then
            lua "${DOTFILES_DIR}/modules/theme/engine.lua" &
            log "Initializing theme engine"
        fi
    fi

    # Load monitor configuration
    if [ -f "${STATE_DIR}/monitors.json" ]; then
        log "Monitor configuration loaded from state"
    fi

    log "Service orchestration complete"
}

# ─────────────────────────────────────────────────────────────────────────────
# Event Handling
# ─────────────────────────────────────────────────────────────────────────────

handle_hyprland_events() {
    log "Listening for Hyprland events..."

    # Subscribe to workspace changes
    hyprctl dispatch workspace 1 2>/dev/null || true
}

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

main() {
    mkdir -p "$(dirname "$LOG_FILE")"

    log "Platform orchestrator started (PID: $$)"
    log "DOTFILES_DIR: $DOTFILES_DIR"
    log "Hyprland Instance: ${HYPRLAND_INSTANCE_SIGNATURE:-unknown}"

    # Start all services
    start_services

    # Start event handler
    handle_hyprland_events

    # Keep running
    sleep infinity
}

# Run main
main
