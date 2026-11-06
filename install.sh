#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════╗
# ║   my-config  —  Automated Config & Dotfiles Installer                    ║
# ║   Omarchy / Arch Linux Setup                                             ║
# ╚══════════════════════════════════════════════════════════════════════════╝

set -euo pipefail

# Script directory
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.config-backups/$(date '+%Y%m%d_%H%M%S')"
MODE="symlink"
NOTIFICATION_PLUGIN="$DOTFILES_DIR/.config/omarchy/plugins/user.notification-center"
NOTIFICATION_PLUGIN_TARGET="$HOME/.config/omarchy/plugins/user.notification-center"

# Color helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info()  { echo -e "${CYAN}ℹ️  $*${NC}"; }
ok()    { echo -e "${GREEN}✔  $*${NC}"; }
warn()  { echo -e "${YELLOW}⚠️  $*${NC}"; }
error() { echo -e "${RED}❌  $*${NC}" >&2; }
bold()  { echo -e "${BOLD}$*${NC}"; }

# Parse arguments
for arg in "$@"; do
  case "$arg" in
    --copy|-c)    MODE="copy" ;;
    --symlink|-s) MODE="symlink" ;;
    --help|-h)
      echo "Usage: ./install.sh [options]"
      echo "Options:"
      echo "  -s, --symlink   Symlink config files into ~ (default: edits stay in git)"
      echo "  -c, --copy      Copy config files into ~"
      echo "  -h, --help      Show this help"
      exit 0
      ;;
    *)
      warn "Unknown option: $arg"
      ;;
  esac
done

bold "\n🚀 Installing my-config ($MODE mode) from: $DOTFILES_DIR\n"

# Ensure target directories exist
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.zfunc"
mkdir -p "$HOME/.local/state/zsh"
mkdir -p "$HOME/.config"
mkdir -p "$HOME/.config/omarchy/plugins"

backup_file() {
  local target="$1"
  if [[ -e "$target" || -L "$target" ]]; then
    # If it's already a symlink pointing to the right place, skip backup
    if [[ -L "$target" ]] && [[ "$(readlink -f "$target")" == "$(readlink -f "$2")" ]]; then
      return 0
    fi
    mkdir -p "$BACKUP_DIR"
    cp -d "$target" "$BACKUP_DIR/" 2>/dev/null || mv "$target" "$BACKUP_DIR/"
    info "Backed up existing $(basename "$target") -> $BACKUP_DIR/"
  fi
}

install_item() {
  local src="$1"
  local dest="$2"

  backup_file "$dest" "$src"
  rm -rf "$dest"

  if [[ "$MODE" == "symlink" ]]; then
    ln -sf "$src" "$dest"
    ok "Linked: $dest -> $src"
  else
    cp -a "$src" "$dest"
    ok "Copied: $src -> $dest"
  fi
}

# 1. Install files
install_item "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
install_item "$DOTFILES_DIR/.p10k.zsh" "$HOME/.p10k.zsh"
install_item "$DOTFILES_DIR/bin/download" "$HOME/.local/bin/download"
install_item "$DOTFILES_DIR/.zfunc/_download" "$HOME/.zfunc/_download"
install_item "$DOTFILES_DIR/.config/hypr" "$HOME/.config/hypr"
install_item "$NOTIFICATION_PLUGIN" "$NOTIFICATION_PLUGIN_TARGET"

# Ensure scripts have execute permissions
chmod +x "$DOTFILES_DIR/bin/download" "$HOME/.local/bin/download"
chmod +x "$NOTIFICATION_PLUGIN/manage.py" "$NOTIFICATION_PLUGIN_TARGET/manage.py"

# Enable Omarchy shell plugin if running on Omarchy
if command -v omarchy >/dev/null 2>&1; then
  info "Enabling Omarchy shell plugin user.notification-center..."
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  omarchy plugin enable user.notification-center --section right --before omarchy.power >/dev/null 2>&1 || true
fi

# 2. Check for required & recommended CLI tools
bold "\n🔍 Checking system packages...\n"

PACKAGES=(
  "zsh:Shell:zsh"
  "fzf:Fuzzy finder:fzf"
  "bat:Syntax cat:bat"
  "eza:Modern ls:eza"
  "fd:Fast find:fd"
  "rg:Ripgrep:ripgrep"
  "zoxide:Smart cd:zoxide"
  "mise:Runtime manager:mise"
  "fastfetch:System info:fastfetch"
  "yt-dlp:Media downloader:yt-dlp"
  "ffmpeg:Audio/video converter:ffmpeg"
  "vivid:LS_COLORS generator:vivid"
)

MISSING_PKGS=()

for entry in "${PACKAGES[@]}"; do
  IFS=":" read -r bin desc pkg <<< "$entry"
  if command -v "$bin" >/dev/null 2>&1; then
    echo -e "  ${GREEN}✔${NC}  ${BOLD}${bin}${NC} (${desc})"
  else
    echo -e "  ${YELLOW}⚠️${NC}  ${BOLD}${bin}${NC} (${desc}) - ${YELLOW}not installed${NC}"
    MISSING_PKGS+=("$pkg")
  fi
done

if (( ${#MISSING_PKGS[@]} > 0 )); then
  bold "\n📦 To install missing tools, run:"
  echo -e "   ${CYAN}sudo pacman -S --needed ${MISSING_PKGS[*]}${NC}\n"
else
  bold "\n🎉 All core tools are installed!"
fi

bold "\n✅ Setup complete! Reload your shell with:"
echo -e "   ${CYAN}source ~/.zshrc${NC} or restart your terminal.\n"
