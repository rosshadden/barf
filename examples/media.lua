-- Media player widget using playerctl.
-- Shows the currently playing track with artist and title.
-- @requires playerctl

local vbar = require("vbar")

vbar.setup({
	shell = { "bash", "-c" },
})

-- Use playerctl's own formatting to get a clean combined string.
-- Outputs nothing when no player is available, so the label stays blank.
local media = vbar.var()
media:poll([[playerctl metadata --format "{{artist}} - {{title}}" 2>/dev/null || echo ""]], { interval = 2 })

local volume = vbar.var("0%")
volume:poll(function()
	return vbar.exec([[echo "$(ponymix get-volume)%"]])
end, { interval = 1 })

vbar.bar({
	left = {
		vbar.vars.time,
	},
	center = {
		media,
	},
	right = {
		volume:format("VOL {}"),
	},
})
