-- Media player widget using playerctl.
-- Shows the currently playing track with artist and title.
-- Requires: playerctl

local vbar = require("vbar")

-- Use playerctl's own formatting to get a clean combined string.
-- Outputs nothing when no player is available, so the label stays blank.
vbar.poll("media", {
	command = "playerctl metadata --format '{{artist}} - {{title}}' 2>/dev/null || echo ''",
	interval = 2,
})

vbar.bar({
	left = {
		vbar.workspaces(),
	},
	center = {
		vbar.label("${media}"),
	},
})
