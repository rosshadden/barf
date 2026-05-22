-- Media player widget using playerctl.
-- Shows the currently playing track with artist and title.
-- @requires playerctl

local vbar = require("vbar")

vbar.setup({
	shell = { "bash", "-c" },
})

-- Use playerctl's own formatting to get a clean combined string.
-- Outputs nothing when no player is available, so the label stays blank.
local media = vbar.var("media", { interval = 2 })
function media:poll()
	return vbar.exec([[playerctl metadata --format "{{artist}} - {{title}}" 2>/dev/null || echo ""]])
end

local volume = vbar.var("volume", { interval = 1 })
function volume:poll()
	return vbar.exec([[echo "$(ponymix get-volume)%"]])
end

vbar.bar({
	center = {
		media,
	},
	right = {
		volume:format("VOL {}"),
	},
})
