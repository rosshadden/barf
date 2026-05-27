-- Media player widget using playerctl.
-- Shows the currently playing track with artist and title.
-- @requires playerctl

local vbar = require("vbar")

vbar.setup({
	shell = { "bash", "-c" },
})

-- :listen runs a long-lived process and updates the var on each line of output.
-- playerctl --follow emits a line on every track change, so updates are instant.
-- :poll every 5s corrects any missed events (e.g. player started while vbar was loading).
-- Both can be used together when they produce the same output format.
local media = vbar.var("media")
	:set("")
	:listen([[playerctl --follow metadata --format "{{artist}} - {{title}}" 2>/dev/null]])
	:poll([[playerctl metadata --format "{{artist}} - {{title}}" 2>/dev/null || echo ""]], { interval = 5 })

local volume = vbar.var("volume")
	:set("0%")
	:poll(function()
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
