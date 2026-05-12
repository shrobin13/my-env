# ==================================================

# IMPLEMENTATION GUIDE — Apply Optimizations

# ==================================================

This guide walks you through implementing the optimizations from AUDIT.md.

## ⚡ PHASE 1: QUICK WINS (1-2 hours)

### Step 1: Backup Current Config

```bash
cd ~/my-env
git add -A
git commit -m "backup: before optimization audit"
```

### Step 2: Update Animations (15 min)

```bash
# REPLACE current animations.conf with optimized version
cp hypr/animations.conf hypr/animations.conf.bak
cp hypr/animations.conf.optimized hypr/animations.conf

# Edit hyprland.conf source statement to point to new file
# (Already done if you just copied the .optimized file)
```

**What changes**:

- Wayland-optimized Bézier curves
- Timing tuned for 120Hz display
- Disabled `borderangle` GPU waste

**How to test**:

```bash
# Reload Hyprland
Super+Shift+x (exit), then re-login
# Or use: hyprctl reload

# Observe: Windows feel snappier, animations smooth
```

---

### Step 3: Optimize Blur (10 min)

```bash
cp hypr/decoration.conf hypr/decoration.conf.bak
cp hypr/decoration.conf.optimized hypr/decoration.conf
```

**What changes**:

- Blur size 6 → 3 (50% sample reduction)
- Blur passes 2 → 1 (50% GPU reduction)
- Selective blur (no Waybar blur)
- Inactive window opacity 1.0 → 0.95

**How to test**:

```bash
hyprctl reload

# Check: Open Rofi, swaync, etc. — should still look blurred
# Waybar should have crisp background (no blur but darker color)
# Overall GPU usage should drop ~20%
```

---

### Step 4: Refactor Autostart (20 min)

```bash
# Make orchestrator script executable
chmod +x hypr/scripts/startup-orchestrator.sh

# Backup and replace autostart
cp hypr/autostart.conf hypr/autostart.conf.bak
cp hypr/autostart.conf.optimized hypr/autostart.conf
```

**What changes**:

- All services orchestrated through single script
- 7-stage startup with dependencies
- Proper error handling and timeouts
- Single clipboard watcher instead of 3x

**How to test**:

```bash
# Restart Hyprland
Super+Shift+x, then re-login

# Check startup log:
tail -f ~/.cache/hyprland-startup.log

# Observe: Services start in order, fewer race conditions
# Discord starts after 5s (deferred)
# Boot should feel ~2-3s faster
```

---

### Step 5: Fix Waybar Layout (15 min)

```bash
cp waybar/config.jsonc waybar/config.jsonc.bak
cp waybar/config.jsonc.optimized waybar/config.jsonc

cp waybar/style.css waybar/style.css.bak
cp waybar/style.css.optimized waybar/style.css
```

**What changes**:

- Clock moved to center (primary focus)
- System metrics moved to right
- Semantic grouping with visual separators
- Better hover states

**How to test**:

```bash
# Restart Waybar
pkill waybar && sleep 1 && waybar &

# Check: Layout should be [Launcher Workspaces] [Clock] [Network CPU Mem Battery] [Tray Lock]
```

---

### Step 6: Enhance Keybindings (10 min)

```bash
cp hypr/keybindings.conf hypr/keybindings.conf.bak
cp hypr/keybindings.conf.optimized hypr/keybindings.conf
```

**What changes**:

- Better organized (semantic sections)
- Added Tab cycling with wrapping
- Added workspace cycling with Ctrl+arrows
- Added Alt+Tab window switcher
- Comments explain each section

**How to test**:

```bash
hyprctl reload

# Test:
# - Alt+Tab cycles windows
# - Super+Tab cycles in current workspace
# - Super+Ctrl+Left/Right cycles workspaces
```

---

### Step 7: Optimize Input (10 min)

```bash
cp hypr/input.conf hypr/input.conf.bak
cp hypr/input.conf.optimized hypr/input.conf
```

**What changes**:

- Keyboard repeat rates tuned for dev workflow
- Touchpad optimized (disable while typing)
- Mouse sensitivity & polling rate tuned
- Better documentation

**How to test**:

```bash
hyprctl reload

# Test:
# - Type in terminal — should feel responsive
# - Move mouse — should feel natural (not too fast/slow)
# - Touchpad — taps should register, no accidental clicks
```

---

## 🏗️ PHASE 2: ARCHITECTURE (2-3 hours)

### Step 8: Create Modular Config Structure

Create new directory structure:

```bash
mkdir -p hypr/_system hypr/_core hypr/_behavior hypr/_workflow hypr/_ui
```

### Create variables.conf

```bash
cat > hypr/_system/variables.conf << 'EOF'
# Centralized variables — Rose Pine theme
$base = #191724
$surface = #1f1d2e
$text = #e0def4
$love = #eb6f92
$iris = #c4a7e7
$foam = #9ccfd8

# Sizing
$border_size = 1
$gap_in = 5
$gap_out = 5
$radius = 4

# Timing
$anim_base = 5.0
$anim_fast = 3.0
$anim_slow = 7.0

# Monitors
$monitor_ext = HDMI-A-1
$monitor_int = eDP-1
EOF
```

### Reorganize Configs

```bash
# Copy configs to new structure
cp hypr/_core/general.conf.optimized hypr/_core/general.conf
cp hypr/_behavior/animations.conf.optimized hypr/_behavior/animations.conf
cp hypr/_behavior/focus-behavior.conf hypr/_behavior/
cp hypr/_workflow/keybindings.conf.optimized hypr/_workflow/keybindings.conf
# ... etc for others
```

### Update Main Config

Edit `hypr/hyprland.conf`:

```conf
$base_path = ~/.config/hypr

# 1. SYSTEM LAYER
source = $base_path/_system/variables.conf
source = $base_path/_system/env.conf

# 2. CORE LAYER
source = $base_path/_core/general.conf
source = $base_path/_core/input.conf
source = $base_path/_core/decoration.conf

# 3. BEHAVIOR LAYER
source = $base_path/_behavior/animations.conf
source = $base_path/_behavior/focus-behavior.conf

# ... etc
```

---

## 🎯 PHASE 3: ADVANCED (Weekend project)

### Step 9: Implement Input Profiles

Create `hypr/scripts/input-profile.sh`:

```bash
#!/usr/bin/env bash
profile=$1
case $profile in
  precision)
    hyprctl keyword device:epic-mouse-v1:sensitivity -0.8
    hyprctl keyword device:epic-mouse-v1:accel_profile flat
    ;;
  default)
    hyprctl keyword device:epic-mouse-v1:sensitivity -0.5
    ;;
esac
```

Make it executable:

```bash
chmod +x hypr/scripts/input-profile.sh
```

Add keybindings:

```conf
bind = $mainMod SHIFT, p, exec, ~/.config/hypr/scripts/input-profile.sh precision
```

### Step 10: Expand Gestures

Update `hypr/gestures.conf`:

```conf
gesture = 3, horizontal, workspace
gesture = 3, up, fullscreen
gesture = 2, horizontal, swapwindow      # NEW
gesture = 4, vertical, resizewindow      # NEW
gesture = 3, down, special:magic         # NEW
```

---

## ✅ VALIDATION CHECKLIST

After implementation, verify:

- [ ] Boot time reduced by ~2-3 seconds (time to login screen → usable desktop)
- [ ] Animations feel snappier (windows open/close more responsive)
- [ ] GPU usage lower at idle (monitor with `gpu-z` or `nvtop`)
- [ ] Waybar layout cleaner (grouped modules visible)
- [ ] Keybindings work (test Tab cycling, workspace navigation)
- [ ] Startup services all online (check `~/.cache/hyprland-startup.log`)
- [ ] No startup race conditions (monitor swaync, waybar, etc. all load properly)
- [ ] Blur still visible on Rofi/swaync but not Waybar

---

## 🐛 TROUBLESHOOTING

### Issue: Services not starting

**Solution**: Check log:

```bash
cat ~/.cache/hyprland-startup.log
```

If a service failed, timeout may be too short — edit orchestrator.sh timeout.

### Issue: Animations feel jerky

**Solution**: Revert to original animations.conf, check GPU:

```bash
# Check GPU usage
nvidia-smi watch -n 1   # NVIDIA
```

### Issue: Waybar not showing

**Solution**:

```bash
pkill waybar
waybar &
# Check for errors
```

### Issue: Input feels wrong

**Solution**: Check device name:

```bash
hyprctl devices

# Edit input.conf with correct device name
```

---

## 📊 PERFORMANCE BENCHMARKING

Before/after comparison:

```bash
# Boot time
time hyprctl dispatch exit
# (Then time from login to fully usable)

# GPU usage
nvidia-smi dmon                    # Every 10ms update
# Monitor at idle, then with Rofi open

# Memory usage
ps aux | grep -E "waybar|swaync|hypridle" | awk '{print $6}'

# Frame pacing
glxgears -info  # Check frames/sec
```

---

## 🔄 GIT WORKFLOW (If using version control)

```bash
# Create feature branch
git checkout -b feat/optimization-audit

# Commit changes by phase
git add hypr/animations.conf
git commit -m "feat: optimize animations for 120Hz"

git add hypr/decoration.conf
git commit -m "feat: reduce blur GPU cost by 50%"

git add hypr/scripts/startup-orchestrator.sh
git commit -m "feat: orchestrate startup with proper sequencing"

# Continue for each phase...

# Merge back when satisfied
git checkout main
git merge feat/optimization-audit
```

---

## 📝 NEXT STEPS

1. **Immediate** (today): Implement Phase 1 (Quick Wins)
2. **Soon** (this week): Complete Phase 2 (Architecture)
3. **Optional** (next week): Phase 3 (Advanced features)

The environment should feel noticeably snappier and more professional after Phase 1.

---

**Questions?** Check AUDIT.md for detailed technical explanations of each recommendation.
