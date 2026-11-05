hl.config({

	input = {
		-- Keyboard layout
		kb_layout = "us",

		-- Swap Caps Lock and Escape
		kb_options = "caps:swapescape",

		-- Change speed of keyboard repeat
		repeat_rate = 40,
		repeat_delay = 250,

		-- Start with numlock on by default
		numlock_by_default = true,

		-- Global pointer speed (applies to the touchpad and other devices)
		sensitivity = 0,

		-- Global acceleration curve (adaptive = libinput default)
		accel_profile = "adaptive",

		touchpad = {
			-- Use natural (inverse) scrolling
			natural_scroll = true,

			-- Use two-finger clicks for right-click
			-- instead of lower-right corner
			clickfinger_behavior = true,

			-- Control the speed of scrolling
			scroll_factor = 0.3,

			-- Enable the touchpad while typing
			-- disable_while_typing = false,

			-- Left-click-and-drag with three fingers
			-- drag_3fg = 1,
		},
	},
})

-- ============================================================
-- Mouse speed knob for the 2.4G mouse
-- 1.0 = current feel, 1.2 = 20% faster, 0.8 = 20% slower
-- ============================================================
local mouse_speed = 1.0

-- Base curve (generated with accel.py, then scaled to taste)
-- step = spacing between points, points = pointer multiplier at each speed
local curve_step = 0.2144477506
local curve_points = {
	0.000, 0.096, 0.193, 0.338, 0.481, 0.626, 0.784, 1.003, 1.223, 1.443,
	1.661, 1.881, 2.100, 2.320, 2.540, 2.759, 2.979, 3.199, 3.418, 3.871,
}

-- Multiply every point by the knob and build "custom <step> <points...>"
local scaled = {}
for i, p in ipairs(curve_points) do
	scaled[i] = string.format("%.3f", p * mouse_speed)
end
local mouse_profile = string.format("custom %.10f %s", curve_step, table.concat(scaled, " "))

hl.device({
	name = "2.4g-mouse",
	sensitivity = 0,
	accel_profile = mouse_profile,
})

-- Enable touchpad gestures for changing workspaces
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Gestures/

hl.gesture({
	fingers = 3,
	direction = "horizontal",
	action = "workspace",
})

hl.gesture({
	fingers = 3,
	direction = "up",
	action = "fullscreen",
})
