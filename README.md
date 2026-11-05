# 🛠️ my-env — Personal Dotfiles & Shell Config

Personal configuration for **Arch Linux · Omarchy Quattro · Zsh · Powerlevel10k**.

Designed for effortless restoration whenever you reinstall Omarchy or set up a new machine.

---

## 🚀 Quick Setup (New Machine / Fresh Omarchy Reinstall)

Clone the repository and run `install.sh`:

```bash
git clone https://github.com/shrobin13/my-env.git ~/Work/my-config
cd ~/Work/my-config
./install.sh
```

### Options:
- **`./install.sh`** (default): Creates symlinks in `$HOME` pointing to this directory. Any edits you make to `~/.zshrc` or `~/.p10k.zsh` are instantly tracked in git!
- **`./install.sh --copy`**: Copies the files directly into `$HOME` instead of symlinking.

---

## 📂 Managed Configurations

| Source in repository | Destination in `$HOME` | Purpose |
| :--- | :--- | :--- |
| [`.zshrc`](.zshrc) | `~/.zshrc` | Cleaned, optimized Zsh configuration (Zinit, plugins, aliases, prompt) |
| [`.p10k.zsh`](.p10k.zsh) | `~/.p10k.zsh` | Powerlevel10k theme configuration |
| [`.config/hypr/`](.config/hypr/) | `~/.config/hypr/` | Omarchy Hyprland Lua config (bindings, monitors, look & feel, inputs) |
| [`bin/download`](bin/download) | `~/.local/bin/download` | High-performance `yt-dlp` frontend CLI utility |
| [`.zfunc/_download`](.zfunc/_download) | `~/.zfunc/_download` | Autoloaded Zsh completions for `download` |

---

## 📦 Recommended Packages

`install.sh` checks for these utilities automatically. To install all of them on Arch:

```bash
sudo pacman -S --needed zsh fzf bat eza fd ripgrep zoxide mise fastfetch yt-dlp ffmpeg vivid
```

- **`vivid`**: Generates `one-dark` `LS_COLORS` for colored completions.
- **`eza`**: Modern replacement for `ls` used for tab-completion previews.
- **`bat`**: Syntax highlighting for file previews and `cat`.
- **`yt-dlp` & `ffmpeg`**: Core engines for the `download` utility.
- **`mise`**: Runtime and tool version manager.
