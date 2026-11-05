local monitors = {
	{
		output = "eDP-1",
		mode = "preferred",
		position = "0x0",
		scale = 1, -- 1.3 matches the physical pixel size of the MSI
	},
	{
		output = "HDMI-A-1",
		mode = "1920x1080@100.00",
		position = "auto-center-right",
		scale = 1,
	},
}

for _, mon in ipairs(monitors) do
	hl.monitor({
		output = mon.output,
		mode = mon.mode,
		position = mon.position,
		scale = mon.scale,
	})
end
