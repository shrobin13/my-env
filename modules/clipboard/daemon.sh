#!/usr/bin/env bash
# ~/.dotfiles/modules/clipboard/daemon.sh
# Clipboard history daemon using wl-paste and wl-copy

set -euo pipefail

CLIPBOARD_HISTORY="${HOME}/.dotfiles/state/clipboard-history.json"
MAX_HISTORY=500
SENSITIVE_KEYWORDS=("password" "token" "secret" "api_key" "auth")

# Initialize history file
mkdir -p "$(dirname "$CLIPBOARD_HISTORY")"
touch "$CLIPBOARD_HISTORY"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> "${HOME}/.dotfiles/state/logs/clipboard.log"
}

# Check if content is sensitive
is_sensitive() {
    local content="$1"
    for keyword in "${SENSITIVE_KEYWORDS[@]}"; do
        if echo "$content" | grep -qi "$keyword"; then
            return 0
        fi
    done
    return 1
}

# Add to clipboard history
add_to_history() {
    local content="$1"
    local type="text"

    if [ -z "$content" ]; then
        return
    fi

    local is_sens="false"
    if is_sensitive "$content"; then
        is_sens="true"
    fi

    local entry="{\"content\":\"$(echo "$content" | jq -Rs .)\",\"type\":\"$type\",\"timestamp\":$(date +%s),\"sensitive\":$is_sens}"

    # Append to history (in production: use proper JSON library)
    echo "$entry" >> "$CLIPBOARD_HISTORY"

    log "Clipboard history updated (sensitive: $is_sens)"
}

# Watch clipboard for changes
watch_clipboard() {
    log "Starting clipboard daemon..."

    while true; do
        # Monitor text clipboard
        wl-paste --watch bash -c 'add_to_history "$(wl-paste)"' 2>/dev/null || true
        sleep 1
    done
}

log "Clipboard daemon initialized"
watch_clipboard
