#!/usr/bin/env bash

# ~/.dotfiles/COMMANDS.md - All Common Commands

## 🚀 QUICKEST START (Copy & Paste)

### Test Everything First

```bash
cd ~/.dotfiles
bash setup.sh --dry-run
```

### Deploy Everything

```bash
bash setup.sh --profile laptop --theme rose-pine
```

### Activate After Setup

```bash
hyprctl reload
systemctl --user start hyprland-platform
```

---

## 📋 INSTALLATION VARIANTS

### Default Setup (Laptop, Rose Pine)

```bash
bash setup.sh
```

### Workstation with Nord Theme

```bash
bash setup.sh --profile workstation --theme nord
```

### Virtual Machine Setup

```bash
bash setup.sh --profile vm --skip-packages
```

### Verbose Mode (For Debugging)

```bash
bash setup.sh --verbose
```

### Skip Package Installation

```bash
bash setup.sh --skip-packages
```

### Don't Backup Existing Configs

```bash
bash setup.sh --no-backup
```

---

## 🔍 VERIFICATION COMMANDS

### Check Setup Status

```bash
make status
```

### View Setup Log

```bash
cat ~/.dotfiles/state/logs/setup.log
```

### Validate All Configs

```bash
make validate
```

### Lint Lua Scripts

```bash
make lint
```

### Check Hyprland Syntax

```bash
hyprctl -j syntax
```

### View Service Status

```bash
systemctl --user status hyprland-platform
systemctl --user status hyprland-clipboard
```

### Check Symlinks

```bash
readlink ~/.config/hypr
readlink ~/.config/waybar
readlink ~/.config/swaync
```

---

## 🛠️ BUILD & MAINTENANCE

### Rebuild All Configs

```bash
make build
```

### Update All Packages

```bash
make update
```

### Clean Cache & Generated Files

```bash
make clean
```

### View All Available Tasks

```bash
make help
```

### View Recent Logs

```bash
make logs
```

---

## 🎨 THEME & COLOR MANAGEMENT

### Change Theme (Live Reload)

```bash
lua ~/.dotfiles/modules/theme/engine.lua --theme nord
```

### Available Themes

```bash
lua ~/.dotfiles/modules/theme/engine.lua --list
# Available: rose-pine, nord, dracula
```

### Extract Colors from Wallpaper

```bash
lua ~/.dotfiles/modules/theme/engine.lua --wallpaper ~/Pictures/wallpaper.jpg
```

### View Current Theme Colors

```bash
cat ~/.dotfiles/runtime/theme-colors.conf
```

### Edit Theme Colors

```bash
vim ~/.dotfiles/runtime/theme-colors.conf
hyprctl reload
```

---

## 🎮 WORKFLOW & KEYBINDINGS

### Activate Coding Mode (60/40 IDE Split)

```bash
hyprctl dispatch exec 'lua ~/.dotfiles/modules/workflow/coding-mode.lua:activate'
```

### View Keybindings

```bash
grep "bind" ~/.dotfiles/config/hypr/keybindings.conf | head -20
```

### Edit Keybindings

```bash
vim ~/.dotfiles/config/hypr/keybindings.conf
hyprctl reload
```

### Add Custom Keybinding

```bash
echo 'bind = $mainMod, P, exec, your-command' >> ~/.dotfiles/config/hypr/keybindings.conf
hyprctl reload
```

---

## 📋 WORKSPACE & APP MANAGEMENT

### View Current Workspace

```bash
hyprctl activeworkspace
```

### List All Workspaces

```bash
hyprctl workspaces
```

### Get App-to-Workspace Routing

```bash
cat ~/.dotfiles/modules/core/workspace.lua | grep -A 20 "app_routing"
```

### Edit Workspace Routing

```bash
vim ~/.dotfiles/modules/core/workspace.lua
make build && hyprctl reload
```

### View Workspace State

```bash
cat ~/.dotfiles/state/workspaces.json | jq '.'
```

---

## 🖥️ MONITOR MANAGEMENT

### Detect Current Monitors

```bash
hyprctl monitors
```

### Save Monitor Configuration

```bash
hyprctl monitors -j > ~/.dotfiles/state/monitors.json
```

### View Saved Monitor Config

```bash
cat ~/.dotfiles/state/monitors.json | jq '.'
```

### Get Monitor Roles

```bash
cat ~/.dotfiles/state/monitors/*/
```

---

## 📋 CLIPBOARD MANAGEMENT

### View Clipboard History

```bash
cat ~/.dotfiles/state/clipboard-history.json | jq '.'
```

### Search Clipboard History

```bash
jq '.[] | select(.content | contains("search-term"))' ~/.dotfiles/state/clipboard-history.json
```

### View Sensitive Items

```bash
jq '.[] | select(.sensitive==true)' ~/.dotfiles/state/clipboard-history.json
```

### Clear Clipboard History

```bash
echo "[]" > ~/.dotfiles/state/clipboard-history.json
```

### Check Clipboard Daemon

```bash
systemctl --user status hyprland-clipboard
journalctl --user -u hyprland-clipboard -n 50
```

---

## 🔧 SERVICE MANAGEMENT

### Start Services

```bash
systemctl --user start hyprland-platform
systemctl --user start hyprland-clipboard
```

### Stop Services

```bash
systemctl --user stop hyprland-platform
systemctl --user stop hyprland-clipboard
```

### Enable Services (Auto-start)

```bash
systemctl --user enable hyprland-platform
systemctl --user enable hyprland-clipboard
```

### Disable Services

```bash
systemctl --user disable hyprland-platform
systemctl --user disable hyprland-clipboard
```

### View Service Logs

```bash
journalctl --user -u hyprland-platform -n 100
journalctl --user -u hyprland-clipboard -n 100
```

### Live Log Monitoring

```bash
journalctl --user -u hyprland-platform -f
```

### Reload Systemd Config

```bash
systemctl --user daemon-reload
```

---

## 🔄 CONFIG CUSTOMIZATION

### Edit Hyprland Main Config

```bash
vim ~/.dotfiles/config/hypr/hyprland.conf
hyprctl reload
```

### Edit Monitor Config

```bash
vim ~/.dotfiles/config/hypr/monitors.conf
hyprctl reload
```

### Edit Input Config

```bash
vim ~/.dotfiles/config/hypr/input.conf
hyprctl reload
```

### Edit Animations

```bash
vim ~/.dotfiles/config/hypr/animations.conf
hyprctl reload
```

### Edit Decoration/Blur

```bash
vim ~/.dotfiles/config/hypr/decoration.conf
hyprctl reload
```

### Edit Window Rules

```bash
vim ~/.dotfiles/config/hypr/windowrules.conf
hyprctl reload
```

### Edit Waybar Config

```bash
vim ~/.dotfiles/config/waybar/config.jsonc
pkill waybar && sleep 1 && waybar &
```

### Edit Waybar Style

```bash
vim ~/.dotfiles/config/waybar/style.css
pkill waybar && sleep 1 && waybar &
```

---

## 🔙 BACKUP & RESTORE

### Backup Current Config

```bash
cp -r ~/.config/hypr ~/.config/hypr.backup
cp -r ~/.config/waybar ~/.config/waybar.backup
```

### Restore from Backup

```bash
rm -rf ~/.config/hypr && cp -r ~/.config/hypr.backup ~/.config/hypr
rm -rf ~/.config/waybar && cp -r ~/.config/waybar.backup ~/.config/waybar
```

### Restore from Setup Backup

```bash
ls ~/.config-backup-*/
cp -r ~/.config-backup-*/hypr.bak ~/.config/hypr
```

### Verify Symlinks After Restore

```bash
readlink ~/.config/hypr
readlink ~/.config/waybar
```

---

## 🐛 DEBUGGING & TROUBLESHOOTING

### Run Verbose Setup

```bash
bash ~/.dotfiles/setup.sh --verbose --dry-run
```

### Check Hyprland Errors

```bash
hyprctl -j errors
```

### View Full Setup Log

```bash
less ~/.dotfiles/state/logs/setup.log
```

### Manual Service Test

```bash
bash ~/.dotfiles/scripts/internal/orchestrator.sh
```

### Test Clipboard Daemon

```bash
bash ~/.dotfiles/modules/clipboard/daemon.sh
```

### Test Theme Engine

```bash
lua ~/.dotfiles/modules/theme/engine.lua
```

### Check Generated Configs Exist

```bash
ls -la ~/.dotfiles/runtime/gen/
```

### Validate Lua Scripts

```bash
for f in ~/.dotfiles/modules/**/*.lua; do luac -p "$f" && echo "✓ $f" || echo "✗ $f"; done
```

### Check Bash Script Syntax

```bash
bash -n ~/.dotfiles/setup.sh && echo "✓ Valid"
bash -n ~/.dotfiles/install.sh && echo "✓ Valid"
```

---

## 📊 STATUS & INFO

### Full Platform Status

```bash
make status
```

### Check Disk Usage

```bash
du -sh ~/.dotfiles/
du -sh ~/.dotfiles/runtime/
du -sh ~/.dotfiles/state/
```

### List Generated Configs

```bash
find ~/.dotfiles/runtime/gen -type f
```

### List State Files

```bash
find ~/.dotfiles/state -type f
```

### View Directory Tree

```bash
tree ~/.dotfiles/ -L 2
```

### Count Lines of Code

```bash
find ~/.dotfiles -name "*.lua" -o -name "*.sh" -o -name "*.json" | xargs wc -l | tail -1
```

---

## 📚 DOCUMENTATION

### Quick Start Guide

```bash
less QUICK_START.md
```

### Implementation Guide

```bash
less PLATFORM_IMPLEMENTATION_GUIDE.md
```

### Directory Structure

```bash
less DIRECTORY_STRUCTURE.md
```

### Phase 2 Deliverables

```bash
less PHASE2_DELIVERABLES.md
```

### All Documentation

```bash
ls ~/.dotfiles/*.md
```

### View This Cheat Sheet

```bash
less ~/.dotfiles/COMMANDS.md
```

---

## 🎯 COMMON WORKFLOWS

### Complete Fresh Install

```bash
cd ~/.dotfiles
bash setup.sh --dry-run
bash setup.sh --profile laptop
make status
hyprctl reload
systemctl --user enable hyprland-platform
systemctl --user start hyprland-platform
```

### Switch Theme

```bash
lua ~/.dotfiles/modules/theme/engine.lua --theme nord
```

### Reconfigure Keybindings

```bash
vim ~/.dotfiles/config/hypr/keybindings.conf
hyprctl reload
```

### Add App to Workspace

```bash
vim ~/.dotfiles/modules/core/workspace.lua
# Add: appname = workspace_number
make build && hyprctl reload
```

### Debug Setup Issues

```bash
bash setup.sh --dry-run --verbose > /tmp/setup-debug.log
cat /tmp/setup-debug.log | less
```

### Share Your Setup

```bash
cd ~/.dotfiles
git init
git add .
git commit -m "My Hyprland setup"
git remote add origin https://github.com/yourusername/hyprland-setup
git push -u origin main
```

### Backup to Git

```bash
cd ~/.dotfiles
git status
git add -A
git commit -m "Update setup configurations"
git push
```

---

## 🚀 ONE-LINERS

### Everything in one line (test only)

```bash
cd ~/.dotfiles && bash setup.sh --dry-run && make validate
```

### Full deployment one-liner

```bash
cd ~/.dotfiles && bash setup.sh --profile laptop && hyprctl reload && systemctl --user enable hyprland-platform
```

### Quick status check

```bash
echo "Setup Log:" && tail -5 ~/.dotfiles/state/logs/setup.log && echo "" && echo "Platform Status:" && make status
```

### Clean and rebuild everything

```bash
make clean && make build && make validate
```

### Reload all services

```bash
hyprctl reload && pkill waybar && sleep 1 && waybar &
```

### Full diagnosis

```bash
make validate && make lint && hyprctl -j syntax && echo "✓ All checks passed"
```

---

## 📌 IMPORTANT PATHS

```
~/.dotfiles/                        # Main directory
~/.dotfiles/setup.sh                # Master setup script
~/.dotfiles/install.sh              # Simple wrapper
~/.dotfiles/Makefile                # Build system
~/.dotfiles/runtime/gen/            # Generated configs
~/.dotfiles/state/                  # Runtime state
~/.dotfiles/modules/                # Lua modules
~/.dotfiles/config/                 # Static configs
~/.dotfiles/state/logs/setup.log    # Setup log
```

---

## 💡 QUICK TIPS

1. **Always test first**: Use `--dry-run` before deploying
2. **Check logs**: If something wrong, read the logs first
3. **Use verbose**: Add `--verbose` for debugging
4. **Backup often**: Automatic backups are created by setup
5. **Validate configs**: Run `make validate` before reloading
6. **Version control**: Use git to track your changes
7. **Read docs**: Check QUICK_START.md for learning
8. **Services**: Enable them for auto-start: `systemctl --user enable hyprland-platform`

---

**Need help?** Check QUICK_START.md or run `make help`
