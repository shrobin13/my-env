# Hyprland Platform - Quick Start Guide

cd /home/light/my-env
bash setup.sh --dry-run

```bash
bash setup.sh --profile laptop --theme rose-pine

# 3️⃣ Activate (reload everything)

hyprctl reload
systemctl --user enable hyprland-platform# Hyprland Platform - Quick Start Guide

## 🚀 Get Started in 5 Minutes

### Step 1: Clone/Setup (30 seconds)
### Step 2: Review (1 minute)
# Navigate to your dotfiles directory
cd ~/.dotfiles

# Make setup script executable
chmod +x setup.sh

# Do a dry run first to see what will happen
bash setup.sh --dry-run
### Step 3: Deploy (2-3 minutes)
### Step 2: Review (1 minute)

```bash
# Check what will be done
cat setup.log  # Review the dry run log

# Read the implementation guide if needed

cat PLATFORM_IMPLEMENTATION_GUIDE.md
```

### Step 3: Deploy (2-3 minutes)
```bash
# Run the full setup
bash setup.sh --profile laptop --theme rose-pine

# For workstation:
bash setup.sh --profile workstation --theme rose-pine


# Without package installation (if already installed):
bash setup.sh --skip-packages

```
### Step 5: Activate (30 seconds)

```bash
# Check setup log
tail -50 state/logs/setup.log

# Verify structure

ls -la runtime/gen/
ls -la state/

# Check status
```
```

### Step 5: Activate (30 seconds)

```bash

# Reload Hyprland
hyprctl reload

### ✅ Configurations Generated

```

## 📋 What Gets Set Up Automatically

### ✅ Directories Created
### ✅ Services Enabled
~/.dotfiles/
├── runtime/gen/          # Generated configs
├── state/                # Persistent state
├── modules/              # Lua modules

- `~/.config/hypr` → runtime generated
├── scripts/              # Orchestration
└── services/             # Systemd units
```

### ✅ Configurations Generated

- Hyprland main config
### View Status
- Theme color definitions
- Service definitions

### ✅ Services Enabled

- Clipboard daemon (history + search)
```bash

### ✅ Symlinks Created

- `~/.config/hypr` → runtime generated
- `~/.config/waybar` → runtime generated
### Modify Settings
- `~/.config/kitty` → runtime generated
- `~/.config/rofi` → runtime generated

## 🎮 Using After Setup

### View Status

```bash
make status              # Platform health
make logs                # View logs

### Manage Services

### Rebuild Configs

```bash
make build               # Regenerate all configs
make validate            # Check validity
make lint                # Lint Lua/shell scripts
```

### Modify Settings

```bash
# Change app routing
vim ~/.dotfiles/modules/core/workspace.lua


# Change theme
- Battery-aware optimizations
# Toggle coding mode
hyprctl dispatch exec 'lua ~/.dotfiles/modules/workflow/coding-mode.lua:activate'
```

### Manage Services

```bash

### Workstation Profile
systemctl --user start hyprland-clipboard


# View logs
journalctl --user -u hyprland-platform -n 50
journalctl --user -u hyprland-clipboard -n 50

# Enable on boot
systemctl --user enable hyprland-platform

systemctl --user enable hyprland-clipboard
- Minimal overhead
## 🔧 Profiles Explained

### Laptop Profile (Default)

- Battery-aware optimizations
- 60Hz fallback on battery
- Power saving enabled
- Suitable for: Most users

```bash
### Rose Pine (Default - Recommended)
Minimal, elegant, with rose/pine/foam accents
### Workstation Profile

- Performance optimized
- Full 120Hz always
- More aggressive animations
Cool, professional blue palette

```bash
bash setup.sh --profile workstation

```
Vibrant purple/pink palette
- Minimal overhead
- No unnecessary packages

- Basic optimizations only
Switch themes anytime:

```bash
bash setup.sh --profile vm
```

## 🎨 Theme Options

### Rose Pine (Default - Recommended)
```bash

```bash

bash setup.sh --theme rose-pine
### Restore from Backup
### Nord

Cool, professional blue palette

```bash
bash setup.sh --theme nord
```bash
### Dracula

Vibrant purple/pink palette
### Add Custom Keybinding
bash setup.sh --theme dracula
```

Switch themes anytime:

### Adjust Workspace Count

lua ~/.dotfiles/modules/theme/engine.lua --theme nord

```

## 🛠️ Common Tasks

### Backup Current Config

```bash
```bash
```

### Restore from Backup

```bash
### View Full Log
cp -r ~/.config/hypr.backup ~/.config/hypr
```

### View All Keybindings

```bash

```

### Add Custom Keybinding
### Check Service Status

echo 'bind = \$mainMod, P, exec, your-command' >> ~/.config/hypr/keybindings.conf
hyprctl reload
```

### Validate Configs
```bash

# Edit workspace allocation
vim ~/.dotfiles/modules/core/workspace.lua

# Rebuild
make build

hyprctl reload
```

### Check Clipboard History

```bash
```bash
```

## 📊 Monitoring & Debugging

### View Full Log

```bash

cat ~/.dotfiles/state/logs/setup.log
```

### Services Not Starting
```bash
# Live log tail
tail -f ~/.dotfiles/state/logs/*.log
```

### Check Service Status

```bash

systemctl --user status hyprland-platform
systemctl --user status hyprland-clipboard
```
```bash

```bash
# Full validation
make validate

# Just Lua
make lint


# Hyprland specific
### Running Dry-Run Again
```

## 🐛 Troubleshooting

### Configs Not Loading

```bash
# Check symlinks
readlink ~/.config/hypr



# Verify generated configs exist
ls -la ~/.dotfiles/runtime/gen/


# Fix: rebuild
make build
hyprctl reload
```

### Services Not Starting

```bash
# Check service logs
1. **Enable Services**
# Manual test
bash ~/.dotfiles/scripts/internal/orchestrator.sh

# Check permissions
chmod +x ~/.dotfiles/scripts/internal/*.sh
```

### Theme Not Applying

```bash
   ```bash
lua ~/.dotfiles/modules/theme/engine.lua

# Reload Waybar
4. **Explore Clipboard History**
# Full reload
hyprctl reload
```

### Running Dry-Run Again

```bash
bash setup.sh --dry-run --verbose

# Check what it would do

cat state/logs/setup.log
```

## 📚 Learn More

- **Full Guide**: `PLATFORM_IMPLEMENTATION_GUIDE.md`
- **Architecture**: `DIRECTORY_STRUCTURE.md`
- **Phase 2 Details**: `PHASE2_DELIVERABLES.md`
- **Audit Results**: `AUDIT.md`

## 🆘 Support

If something goes wrong:

1. Check the log: `cat ~/.dotfiles/state/logs/setup.log`
2. Run validation: `make validate`
3. Try dry-run: `bash setup.sh --dry-run --verbose`
4. Review implementation guide: `cat PLATFORM_IMPLEMENTATION_GUIDE.md`

## ✨ Next Steps After Setup
