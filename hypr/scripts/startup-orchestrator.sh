#!/usr/bin/env bash
# ==================================================
# Hyprland Startup Orchestrator — Optimized Boot
# ==================================================
# Purpose: Manage autostart services with proper sequencing,
#          error handling, and startup optimization
# Location: ~/.config/hypr/scripts/startup-orchestrator.sh
# Usage: Called from hyprland.conf as: exec-once = ~/.config/hypr/scripts/startup-orchestrator.sh

set -e  # Exit on error

# ── STARTUP LOG ──
LOG_FILE="${HOME}/.cache/hyprland-startup.log"
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "Starting Hyprland service orchestration..."

# ── STAGE 1: System Foundations (CRITICAL) ──
log "Stage 1: System foundations..."

start_service() {
    local name=$1
    local cmd=$2

    log "  → Starting $name..."
    if timeout 10 bash -c "$cmd" &>/dev/null; then
        log "    ✓ $name started"
        return 0
    else
        log "    ✗ $name failed (non-blocking)"
        return 1
    fi
}

# Authentication agent (required for privileged operations)
start_service "PolicyKit Agent" "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"

# Input method (must be before UI layer)
start_service "IBus Daemon" "ibus-daemon -drx"

sleep 0.5  # Brief pause for ibus to initialize

# ── STAGE 2: Critical Services ──
log "Stage 2: Critical services..."

start_service "Hypridle" "hypridle"
start_service "SwayNC" "swaync"

# ── STAGE 3: Display & Wallpaper ──
log "Stage 3: Display & wallpaper..."

start_service "SwWW Daemon" "swww-daemon --format xrgb"
sleep 1  # GPU needs time to initialize

start_service "Waypaper Restore" "waypaper --restore"

# ── STAGE 4: UI Layer ──
log "Stage 4: UI layer..."

start_service "Waybar" "waybar"

# ── STAGE 5: Clipboard Management (Single Daemon) ──
log "Stage 5: Clipboard management..."

# Stop any existing cliphist watchers
pkill -f "wl-paste.*cliphist" 2>/dev/null || true

# Start single orchestrated clipboard daemon
(
    wl-paste --watch cliphist store &
    wl-paste --watch cliphist store --type image &
    wl-paste --watch cliphist store --type text &
    wait
) &

log "  ✓ Clipboard watchers started"

# ── STAGE 6: Hardware Integration (Parallelizable) ──
log "Stage 6: Hardware integration (parallelized)..."

{
    start_service "Network Manager" "iwgtk -i" &
    start_service "Bluetooth" "blueman-applet" &
    start_service "KDEConnect" "kdeconnect-indicator" &
    start_service "CopyQ" "copyq" &
    wait
} 2>/dev/null || true

# ── STAGE 7: User Applications (Background) ──
log "Stage 7: User applications (background)..."

# Discord: Defer by 5 seconds (heavy app, non-blocking)
(sleep 5 && start_service "Discord" "discord") &

log "✓ Hyprland startup sequence complete!"
log "Startup time: $(( $(date +%s) - ${STARTUP_TIME:-$(date +%s)} )) seconds"
