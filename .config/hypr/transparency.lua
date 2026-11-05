local FLEURY_BLUR = true -- set by setup.sh

hl.config({
	general = {
		col = {
			active_border = { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 },
			inactive_border = "rgba(595959aa)",
		},
	},
	decoration = {
		rounding = 4,
		rounding_power = 2.6,

		active_opacity = 0.93,
		inactive_opacity = 0.84,
		fullscreen_opacity = 1.0,

		-- Tables are truthy, so this returns the tuned block when FLEURY_BLUR is
		-- true and { enabled = false } when it's false. Clean on/off, no editing
		-- the block itself.
		blur = FLEURY_BLUR and {
			enabled = false,
			size = 3,
			passes = 3, -- sweet spot; 4+ costs frames for little gain
			new_optimizations = true,
			xray = false, -- true = blur only the wallpaper (faster, flatter)

			-- The important one. Without it, Hyprland skips blur behind any
			-- window you've made translucent — i.e. all of them.
			ignore_opacity = true,

			noise = 0.018, -- kills banding on near-black surfaces
			contrast = 1.15,
			brightness = 0.82, -- hold the wallpaper down so bronze stays legible
			vibrancy = 0.20,
			vibrancy_darkness = 0.35,

			popups = true,
			popups_ignorealpha = 0.2,
		} or { enabled = false },

		shadow = {
			enabled = true,
			range = 24,
			render_power = 3,
			color = "rgba(000000aa)",
			color_inactive = "rgba(00000066)",
		},
	},
})

-- Window rules ---------------------------------------------------------------
-- Evaluated top to bottom, last match wins — so the opaque rule goes last.

hl.window_rule({
	name = "fleury-terminals",
	match = { class = "^(Alacritty|kitty|foot|com.mitchellh.ghostty)$" },
	opacity = "0.88 0.80",
})

hl.window_rule({
	name = "fleury-files",
	match = { class = "^(org.gnome.Nautilus|nautilus)$" },
	opacity = "0.92 0.85",
})

hl.window_rule({
	name = "fleury-browser",
	match = { class = "^(brave-browser|Brave-browser|chromium)$" },
	opacity = "0.94 0.88",
})

-- Anything where pixels matter stays opaque.
hl.window_rule({
	name = "fleury-opaque",
	match = { class = "^(mpv|imv|org.gnome.Loupe|obs|Gimp|com.obsproject.Studio)$" },
	opacity = "1.0 1.0",
})

-- Layer rules ----------------------------------------------------------------
-- Namespaces are guesses — run hyprctl layers while the shell is up and match
-- what you actually see. Omarchy's Quickshell surfaces usually namespace as
-- quickshell:<component>.

hl.layer_rule({
	name = "fleury-shell",
	match = { namespace = "^quickshell" },
	blur = true,
	blur_popups = true,
	ignore_alpha = 0.25,
})

hl.layer_rule({
	name = "fleury-launcher",
	match = { namespace = "^(walker|rofi)$" },
	blur = true,
	ignore_alpha = 0.3,
})

hl.layer_rule({
	name = "fleury-notifications",
	match = { namespace = "^(notifications|swaync|mako)$" },
	blur = true,
	ignore_alpha = 0.3,
})
