-- Change the default Omarchy look'n'feel

local anim_enable = true
local anim_base = 6.0
local anim_fast = 4.5
local anim_slow = 8.0

-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
hl.config({
	general = {
		-- No gaps between windows or borders
		gaps_in = 1,
		gaps_out = 1,
		border_size = 1,

		-- Change to niri-like side-scrolling layout
		-- layout = "scrolling",
	},

	-- https://wiki.hypr.land/Configuring/Basics/Variables/#decoration
	decoration = {
		-- Use round window corners
		rounding = 2,

		-- Dim unfocused windows
		-- dim_inactive = true,
		-- dim_strength = 0.15,
		-- Background blur
		blur = {
			enabled = true,

			-- Strong but still reasonable on an Intel iGPU
			size = 10,
			passes = 3,

			-- Important for transparent Kitty windows
			ignore_opacity = true,

			-- Keep the optimized blur path
			new_optimizations = true,

			-- Better performance for floating windows
			xray = false,

			-- Blur appearance
			noise = 0.0117,
			contrast = 0.90,
			brightness = 0.82,
			vibrancy = 0.20,
			vibrancy_darkness = 0.0,

			-- Keep these off unless you specifically want them
			special = false,
			popups = false,
			input_methods = false,
		},
	},

	-- https://wiki.hypr.land/Configuring/Basics/Variables/#animations
	animations = {
		enabled = anim_enable,
	},

	-- https://wiki.hypr.land/Configuring/Basics/Variables/#layout
	layout = {
		-- Avoid overly wide single-window layouts on wide screens
		-- single_window_aspect_ratio = { 1, 1 },
	},

	-- https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
	scrolling = {
		-- See only one column per screen instead of two
		-- column_width = 0.97,
	},
})

-- https://wiki.hypr.land/Configuring/Basics/Variables/#animations

-- Apple-style bezier curves
hl.curve("appleDefault", {
	type = "bezier",
	points = {
		{ 0.25, 1 },
		{ 0.5, 1 },
	},
})

hl.curve("appleSnap", {
	type = "bezier",
	points = {
		{ 0.4, 0 },
		{ 0.2, 1 },
	},
})

hl.curve("appleWorkspace", {
	type = "bezier",
	points = {
		{ 0.33, 1 },
		{ 0.68, 1 },
	},
})

-- Window animations
hl.animation({
	leaf = "windows",
	enabled = anim_enable,
	speed = anim_base,
	bezier = "appleDefault",
})

hl.animation({
	leaf = "windowsIn",
	enabled = anim_enable,
	speed = anim_base,
	bezier = "appleDefault",
	style = "popin 90%",
})

hl.animation({
	leaf = "windowsOut",
	enabled = anim_enable,
	speed = anim_fast,
	bezier = "appleSnap",
	style = "popin 95%",
})

-- Fade animations
hl.animation({
	leaf = "fadeIn",
	enabled = anim_enable,
	speed = anim_fast,
	bezier = "appleDefault",
})

hl.animation({
	leaf = "fadeOut",
	enabled = anim_enable,
	speed = anim_fast,
	bezier = "appleDefault",
})

-- Layer animations
hl.animation({
	leaf = "layers",
	enabled = anim_enable,
	speed = anim_base,
	bezier = "appleDefault",
	style = "slide",
})

hl.animation({
	leaf = "layersIn",
	enabled = anim_enable,
	speed = anim_fast,
	bezier = "appleDefault",
	style = "slide",
})

hl.animation({
	leaf = "layersOut",
	enabled = anim_enable,
	speed = anim_slow,
	bezier = "appleSnap",
	style = "slide",
})

-- Workspace animations
hl.animation({
	leaf = "workspaces",
	enabled = anim_enable,
	speed = anim_base,
	bezier = "appleWorkspace",
	style = "slide",
})
