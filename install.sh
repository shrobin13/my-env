#!/bin/bash
# ~/.dotfiles/install.sh - Simple installer wrapper
# Makes setup as easy as: bash install.sh

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if setup.sh exists
if [ ! -f "${SCRIPT_DIR}/setup.sh" ]; then
    echo "❌ setup.sh not found in ${SCRIPT_DIR}"
    exit 1
fi

# Check if git is available
if ! command -v git &> /dev/null; then
    echo "❌ git is required but not installed"
    exit 1
fi

# Default variables
PROFILE="${HYPRLAND_PROFILE:-laptop}"
THEME="${HYPRLAND_THEME:-rose-pine}"
DRY_RUN=false
VERBOSE=false

# Parse command line arguments
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
            echo "Hyprland Platform Installer"
            echo ""
            echo "Usage: bash install.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --profile {laptop|workstation|vm}   Setup profile (default: laptop)"
            echo "  --theme {rose-pine|nord|dracula}    Theme (default: rose-pine)"
            echo "  --dry-run                           Preview changes"
            echo "  --verbose                           Verbose output"
            echo "  --help                              Show this help"
            echo ""
            echo "Examples:"
            echo "  bash install.sh                     # Default setup"
            echo "  bash install.sh --dry-run           # Preview only"
            echo "  bash install.sh --profile workstation --theme nord"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Show what we're doing
echo "╔════════════════════════════════════════════════════════════╗"
echo "║      Hyprland Platform - Automated Installation            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Profile: $PROFILE"
echo "Theme: $THEME"
echo "Dry Run: $DRY_RUN"
echo ""

# Make setup script executable
chmod +x "${SCRIPT_DIR}/setup.sh"

# Build command
cmd="bash '${SCRIPT_DIR}/setup.sh' --profile '$PROFILE' --theme '$THEME'"

if [ "$DRY_RUN" = true ]; then
    cmd="$cmd --dry-run"
fi

if [ "$VERBOSE" = true ]; then
    cmd="$cmd --verbose"
fi

# Run setup
eval "$cmd"

exit $?
