# 🏠 my-env — Hyprland Dotfiles

Personal dotfiles for a **Hyprland** (Wayland compositor) desktop environment on **Arch Linux**. This repository contains all the configuration files needed to replicate a fully-featured, aesthetically cohesive Hyprland rice with a **Rosé Pine** inspired color palette.

## ✨ What's Included

| Directory / File | Description |
|---|---|
| `hypr/` | Hyprland window manager configs (keybindings, animations, monitors, window rules, autostart, idle, gestures, decoration, etc.) |
| `hypr/scripts/` | Helper shell scripts (clipboard history, screen lock, OCR text copy, live wallpaper) |
| `kitty/` | Kitty terminal emulator configuration and color themes |
| `waybar/` | Waybar (status bar) config and Rosé Pine CSS styling |
| `rofi/` | Rofi (application launcher) Rosé Pine glass themes |
| `swaync/` | SwayNotificationCenter config and styling |
| `waypaper/` | Waypaper (wallpaper manager) configuration |
| `wallpapers/` | Wallpaper images |
| `.zshrc` | Zsh shell config with Oh-My-Zsh, Powerlevel10k, Zinit plugins, aliases, and custom functions (`download`, `fbrew`, `finpac`, `start_lamp`, etc.) |
| `.gtkrc-2.0` | GTK 2.0 theme settings (Rosé Pine) |
| `Extras/` | Extra config snippets (e.g., Neovim TokyoNight theme) |

## 📦 Dependencies

Install the following packages before setting up. On **Arch Linux**:

```bash
# Core Wayland / Hyprland
sudo pacman -S hyprland hyprlock hypridle waybar rofi-wayland swaync swww waypaper

# Terminal & Shell
sudo pacman -S kitty zsh

# Shell Enhancements
sudo pacman -S fzf zoxide lsd fd ripgrep vivid fastfetch

# Clipboard & Screenshot
sudo pacman -S wl-clipboard cliphist grim slurp

# Fonts
sudo pacman -S ttf-jetbrains-mono-nerd ttf-firacode-nerd

# GTK Theming
sudo pacman -S nwg-look

# Misc Utilities
sudo pacman -S copyq blueman network-manager-applet playerctl brightnessctl tesseract

# AUR packages (via yay)
yay -S waypaper
```

### Optional

```bash
# Oh-My-Zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Powerlevel10k
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"

# Homebrew / Linuxbrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# yt-dlp (for the download function)
sudo pacman -S yt-dlp

# Neovim
sudo pacman -S neovim
```

## 🛠️ Manual Setup

### 1. Clone the Repository

```bash
git clone https://github.com/shrobin13/my-env.git ~/my-env
cd ~/my-env
```

### 2. Create Symlinks

Create symbolic links from the repo to your `~/.config` directory:

```bash
# Hyprland
ln -sf ~/my-env/hypr ~/.config/hypr

# Kitty
ln -sf ~/my-env/kitty ~/.config/kitty

# Waybar
ln -sf ~/my-env/waybar ~/.config/waybar

# Rofi
ln -sf ~/my-env/rofi ~/.config/rofi

# SwayNC
ln -sf ~/my-env/swaync ~/.config/swaync

# Waypaper
ln -sf ~/my-env/waypaper ~/.config/waypaper
```

### 3. Shell Configuration

```bash
# Symlink .zshrc
ln -sf ~/my-env/.zshrc ~/.zshrc

# Symlink GTK config
ln -sf ~/my-env/.gtkrc-2.0 ~/.gtkrc-2.0

# Set Zsh as default shell (if not already)
chsh -s $(which zsh)
```

### 4. Initialize Wallpaper

```bash
# Start swww daemon
swww-daemon --format xrgb &

# Set a wallpaper
waypaper --restore
```

### 5. Log Out & Log Back In

Log out of your current session and select **Hyprland** from your display manager (or start it from TTY with `Hyprland`).

## ⌨️ Key Bindings (Highlights)

| Keybind | Action |
|---|---|
| `Super + Return` | Open terminal (Kitty) |
| `Super + Space` | App launcher (Rofi) |
| `Super + B` | Open browser (Firefox) |
| `Super + E` | File manager (Nautilus) |
| `Super + Q` | Close window |
| `Super + F` | Fullscreen |
| `Super + T` | Toggle floating |
| `Super + H/J/K/L` | Move focus (vim-style) |
| `Super + V` | Clipboard history |
| `Super + Print` | Screenshot (region select) |
| `Super + X` | Lock screen |
| `Super + Shift + X` | Exit Hyprland |

## 🔧 Custom Zsh Functions

| Function | Description |
|---|---|
| `download <url>` | Smart yt-dlp wrapper with progress UI (supports `-a` audio, `-p` playlist, `-s` subs) |
| `fbrew` | Fuzzy Homebrew package installer via fzf |
| `finpac` | Fuzzy Arch/AUR package installer via fzf + yay |
| `start_lamp` | Start Apache + MariaDB LAMP stack |
| `stop_lamp` | Stop LAMP stack |
| `status_lamp` | Check LAMP status |

## 📄 License

[MIT](LICENSE)
