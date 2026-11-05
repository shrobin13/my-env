# 🛠️ my-config — Personal Dotfiles & Shell Config

Personal configuration for **Arch Linux · Omarchy Quattro · Zsh · Powerlevel10k**.

Designed for effortless restoration whenever you reinstall Omarchy or set up a new machine.

---

## 🚀 Quick Setup (New Machine / Fresh Omarchy Reinstall)

Clone the repository and run `install.sh`:

```bash
git clone <your-repo-url> ~/Work/my-config
cd ~/Work/my-config
./install.sh
```

### Options:
- **`./install.sh`** (default): Creates symlinks in `$HOME` pointing to this directory. Any edits you make to `~/.zshrc` or `~/.p10k.zsh` are instantly tracked in git!
- **`./install.sh --copy`**: Copies the files directly into `$HOME` instead of symlinking.

---

## 📂 Managed Configurations

| Source in `my-config` | Destination in `$HOME` | Purpose |
| :--- | :--- | :--- |
| [`.zshrc`](.zshrc) | `~/.zshrc` | Cleaned, optimized Zsh configuration (Zinit, plugins, aliases, prompt) |
| [`.p10k.zsh`](.p10k.zsh) | `~/.p10k.zsh` | Powerlevel10k theme configuration |
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

---

## 🔄 Pushing to GitHub

To store this on GitHub:

```bash
cd ~/Work/my-config
git init
git add .
git commit -m "Initial commit: clean Omarchy zsh config and download utility"
git branch -M main
git remote add origin git@github.com:<your-username>/<your-repo-name>.git
git push -u origin main
```
