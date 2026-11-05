-- Keep only your personal keybinding overrides here.
-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- =========================================================
-- VIM-STYLE FOCUS (Super + H/J/K/L)
-- =========================================================
hl.unbind("SUPER + H")
hl.unbind("SUPER + J")
hl.unbind("SUPER + K")
hl.unbind("SUPER + L")

hl.bind("SUPER + H", hl.dsp.focus({ direction = "l" }), { description = "Focus left" })
hl.bind("SUPER + L", hl.dsp.focus({ direction = "r" }), { description = "Focus right" })
hl.bind("SUPER + K", hl.dsp.focus({ direction = "u" }), { description = "Focus up" })
hl.bind("SUPER + J", hl.dsp.focus({ direction = "d" }), { description = "Focus down" })

-- =========================================================
-- VIM-STYLE RESIZE (Super + Shift + H/J/K/L)
-- =========================================================
hl.unbind("SUPER + SHIFT + H")
hl.unbind("SUPER + SHIFT + J")
hl.unbind("SUPER + SHIFT + K")
hl.unbind("SUPER + SHIFT + L")

hl.bind("SUPER + SHIFT + H", hl.dsp.window.resize({ x = -100, y = 0, relative = true }), { description = "Resize left", repeating = true })
hl.bind("SUPER + SHIFT + L", hl.dsp.window.resize({ x = 100, y = 0, relative = true }), { description = "Resize right", repeating = true })
hl.bind("SUPER + SHIFT + K", hl.dsp.window.resize({ x = 0, y = -100, relative = true }), { description = "Resize up", repeating = true })
hl.bind("SUPER + SHIFT + J", hl.dsp.window.resize({ x = 0, y = 100, relative = true }), { description = "Resize down", repeating = true })

-- =========================================================
-- VIM-STYLE WINDOW SWAPPING (Super + Alt + H/J/K/L)
-- =========================================================
hl.unbind("SUPER + ALT + H")
hl.unbind("SUPER + ALT + J")
hl.unbind("SUPER + ALT + K")
hl.unbind("SUPER + ALT + L")

hl.bind("SUPER + ALT + H", hl.dsp.window.swap({ direction = "l" }), { description = "Swap window left" })
hl.bind("SUPER + ALT + L", hl.dsp.window.swap({ direction = "r" }), { description = "Swap window right" })
hl.bind("SUPER + ALT + K", hl.dsp.window.swap({ direction = "u" }), { description = "Swap window up" })
hl.bind("SUPER + ALT + J", hl.dsp.window.swap({ direction = "d" }), { description = "Swap window down" })

-- =========================================================
-- SPLIT CONTROLS (Moved to Super+Y because Super+J is Vim focus)
-- =========================================================
hl.unbind("SUPER + Y")
hl.bind("SUPER + Y", hl.dsp.layout("togglesplit"), { description = "Toggle split" })

-- =========================================================
-- KEYBINDINGS MENU (Alternative shortcut because Super+K is Vim focus)
-- =========================================================
o.bind("SUPER + CTRL + ALT + K", "Show key bindings", "omarchy-menu-keybindings")
