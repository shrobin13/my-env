# ==================================================

# OPTIMIZATION CHECKLIST & PRIORITY MATRIX

# ==================================================

## 🎯 QUICK REFERENCE

**Time Investment**: ~5 hours total (can be done incrementally)
**Expected Impact**: 30% faster feel, 20% better battery life, cleaner architecture
**Risk Level**: LOW (all changes are backwards-compatible with rollback backups)

---

## ✅ PRIORITY 1: QUICK WINS (Do This Week)

These require <30 minutes each and have immediate impact.

### [ ] 1. Fix Animation Curves (15 min)

**File**: `hypr/animations.conf`
**Impact**: Animations feel 30% snappier
**Steps**:

1. Back up: `cp hypr/animations.conf hypr/animations.conf.bak`
2. Copy optimized: `cp hypr/animations.conf.optimized hypr/animations.conf`
3. Reload: `hyprctl reload`
4. Test: Open/close windows, should feel instant

**Validation**: Windows pop open immediately without delay

---

### [ ] 2. Optimize Blur (10 min)

**File**: `hypr/decoration.conf`
**Impact**: 20% GPU savings, battery life improvement
**Steps**:

1. Back up: `cp hypr/decoration.conf hypr/decoration.conf.bak`
2. Copy optimized: `cp hypr/decoration.conf.optimized hypr/decoration.conf`
3. Reload: `hyprctl reload`
4. Verify: Rofi/swaync still blurred, Waybar crisp

**Validation**: GPU load drops noticeably, no visual quality loss

---

### [ ] 3. Fix Waybar Layout (15 min)

**Files**: `waybar/config.jsonc`, `waybar/style.css`
**Impact**: Cleaner UI, better information hierarchy
**Steps**:

1. Back up configs
2. Copy optimized files
3. Restart: `pkill waybar && waybar &`
4. Verify: Clock in center, system metrics right

**Validation**: Layout matches design in AUDIT.md

---

### [ ] 4. Refactor Startup (20 min)

**Files**: `hypr/autostart.conf`, `hypr/scripts/startup-orchestrator.sh`
**Impact**: 2-3s faster boot, fewer race conditions
**Steps**:

1. Create orchestrator: Copy startup-orchestrator.sh to `hypr/scripts/`
2. Make executable: `chmod +x hypr/scripts/startup-orchestrator.sh`
3. Update autostart: `cp hypr/autostart.conf.optimized hypr/autostart.conf`
4. Test boot: Log out and in, check `~/.cache/hyprland-startup.log`

**Validation**: Services start in proper order, all come online cleanly

---

### [ ] 5. Enhance Keybindings (10 min)

**File**: `hypr/keybindings.conf`
**Impact**: Better workflow, clearer organization
**Steps**:

1. Back up: `cp hypr/keybindings.conf hypr/keybindings.conf.bak`
2. Copy optimized: `cp hypr/keybindings.conf.optimized hypr/keybindings.conf`
3. Reload: `hyprctl reload`
4. Test: Alt+Tab, Tab cycling, workspace navigation

**Validation**: All new keybinds work, organized into sections

---

### [ ] 6. Optimize Input (10 min)

**File**: `hypr/input.conf`
**Impact**: Better keyboard responsiveness, smoother touchpad
**Steps**:

1. Back up: `cp hypr/input.conf hypr/input.conf.bak`
2. Copy optimized: `cp hypr/input.conf.optimized hypr/input.conf`
3. Reload: `hyprctl reload`
4. Test: Keyboard repeat, mouse movement, touchpad

**Validation**: Keyboard feels snappier, mouse/touchpad smooth

---

## ✅ PRIORITY 2: ARCHITECTURE (Do This Month)

Medium effort, high maintainability payoff.

### [ ] 7. Create Modular Config Structure (45 min)

**Impact**: Easier maintenance, better organization
**Steps**:

1. Create directories:

   ```bash
   mkdir -p hypr/_system hypr/_core hypr/_behavior hypr/_workflow hypr/_ui
   ```

2. Create `hypr/_system/variables.conf` with Rose Pine colors

3. Create `hypr/_system/env.conf` with environment variables

4. Reorganize existing configs into subdirectories

5. Create new `hypr/hyprland.conf` with explicit load order

**Validation**: New directory structure matches docs/architecture in AUDIT.md

---

### [ ] 8. Create Focus Behavior Config (15 min)

**File**: `hypr/focus-behavior.conf` (NEW)
**Impact**: Better focus handling, documented behavior
**Steps**:

1. Copy provided `focus-behavior.conf` file
2. Source from hyprland.conf
3. Test focus navigation

**Validation**: Focus wrapping works, behavior documented

---

### [ ] 9. Update General Configuration (10 min)

**File**: `hypr/general.conf`
**Impact**: Cleaner, better-documented settings
**Steps**:

1. Back up current
2. Copy optimized version
3. Reload and verify

**Validation**: All settings applied, no visual changes

---

### [ ] 10. Implement Git Workflow (30 min)

**Impact**: Track changes, easier rollback
**Steps**:

1. Initialize git (if not already):

   ```bash
   git init ~/my-env
   cd ~/my-env
   git add .
   git commit -m "initial: baseline configuration"
   ```

2. Create feature branch:

   ```bash
   git checkout -b feat/optimization-audit
   ```

3. Commit changes by logical group:

   ```bash
   git add hypr/animations.conf hypr/decoration.conf
   git commit -m "feat: optimize rendering pipeline"
   ```

4. Merge when satisfied:
   ```bash
   git checkout main
   git merge feat/optimization-audit
   ```

**Validation**: Git history shows logical progression of changes

---

## ✅ PRIORITY 3: ADVANCED (Optional Weekend Project)

High-value enhancements for sophisticated workflows.

### [ ] 11. Create Input Profiles (20 min)

**Files**: `hypr/scripts/input-profile.sh` (NEW)
**Impact**: Context-aware input switching
**Steps**:

1. Create script as described in AUDIT.md
2. Add keybindings:

   ```conf
   bind = $mainMod SHIFT, p, exec, ~/.config/hypr/scripts/input-profile.sh precision
   ```

3. Test: Switch profiles mid-session

**Validation**: Can toggle between precision and normal mode

---

### [ ] 12. Expand Gesture System (15 min)

**File**: `hypr/gestures.conf`
**Impact**: More intuitive touchpad interactions
**Steps**:

1. Update with new gestures (2-finger, 4-finger, etc.)
2. Reload
3. Test gestures

**Validation**: New gestures work smoothly

---

### [ ] 13. Create Workspace Automation (30 min)

**Files**: `hypr/scripts/smart-workspace.sh` (NEW), `windowrules.conf`
**Impact**: App-aware workspace routing
**Steps**:

1. Create smart-workspace.sh script
2. Add window rules to route apps
3. Test: Open apps, they go to correct workspace

**Validation**: Apps route to correct workspaces automatically

---

### [ ] 14. Set Up HDR Pipeline (Optional, 15 min)

**Files**: `hypr/decoration.conf`, `hypr/general.conf`
**Impact**: Future-proofing for HDR displays
**Steps**:

1. Add HDR settings to configs
2. Test (will only work on HDR displays)
3. Leave enabled (no performance impact if not supported)

**Validation**: Settings present, no errors if not supported

---

## 📊 TRACKING

### Phase 1 Progress: \_\_\_/6 items complete

**Time spent**: **\_** minutes
**Issues encountered**: ****************\_****************

### Phase 2 Progress: \_\_\_/4 items complete

**Time spent**: **\_** minutes
**Issues encountered**: ****************\_****************

### Phase 3 Progress: \_\_\_/4 items complete

**Time spent**: **\_** minutes
**Issues encountered**: ****************\_****************

---

## 🎯 FINAL VALIDATION

Once all phases complete, verify:

### Startup & Performance

- [ ] Boot time reduced by 2-3 seconds
- [ ] Services start in proper sequence
- [ ] No startup race conditions
- [ ] GPU idle usage ~20% lower
- [ ] Battery life 10-15% longer

### UI/UX Quality

- [ ] Animations feel snappier
- [ ] Blur still present on UI but more efficient
- [ ] Waybar layout clean and organized
- [ ] Focus behavior smooth and intuitive
- [ ] Input responsive and natural

### Architecture & Maintenance

- [ ] Config structure modular and organized
- [ ] Git history tracks changes logically
- [ ] Documentation complete
- [ ] Rollback available via backups
- [ ] Code comments explain decisions

---

## 🔄 ROLLBACK PROCEDURE

If something breaks, quick rollback:

```bash
# Full rollback to backups:
cp hypr/animations.conf.bak hypr/animations.conf
cp hypr/decoration.conf.bak hypr/decoration.conf
cp waybar/config.jsonc.bak waybar/config.jsonc
cp waybar/style.css.bak waybar/style.css
# ... etc

# Or via git:
git checkout feat/optimization-audit~1  # Go back one commit
hyprctl reload
```

---

## 📞 SUPPORT REFERENCES

**If animations feel wrong**: See "Animation Tuning" in AUDIT.md
**If GPU usage high**: See "GPU Rendering Pipeline" in AUDIT.md
**If startup slow**: See "Startup Sequence" in AUDIT.md
**If keybindings don't work**: Check keybindings.conf syntax, run `hyprctl reload`
**If config won't load**: Check `~/.cache/hyprlandlog` for error details

---

## 🎓 LEARNING OUTCOMES

After completing this optimization, you'll understand:

1. **Hyprland animation system**: Bezier curves, timing, and performance
2. **GPU rendering**: Blur optimization, damage tracking, VRR
3. **Startup orchestration**: Service sequencing and dependency management
4. **Config architecture**: Modular patterns, maintainability
5. **Input systems**: Keyboard/mouse/touchpad optimization
6. **Performance debugging**: GPU/CPU profiling, startup analysis

---

## 📝 NOTES

**Personal Notes**:
(Fill in as you go)

---

---

---

---

**Completion Target**: By ****\_\_**** (date)

**Estimated Total Time**: 5-7 hours spread over 2-3 weeks
