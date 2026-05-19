-- Media player widget using playerctl.
-- Shows the currently playing track with artist and title.
-- @requires playerctl

local vbar = require("vbar")

vbar.setup({
	shell = { "bash", "-c" },
})

-- Use playerctl's own formatting to get a clean combined string.
-- Outputs nothing when no player is available, so the label stays blank.
vbar.poll("media", {
	command = [[playerctl metadata --format "{{artist}} - {{title}}" 2>/dev/null || echo ""]],
	interval = 2,
})

vbar.poll("volume", {
	shell = { "nu", "-c" },
	command = [[$"(ponymix get-volume)%(try { ponymix is-muted; ' [muted]' } catch { '' })"]],
	-- command = [[echo "$(ponymix get-volume)%"]],
	-- command = [[echo "$(ponymix get-volume)% $(ponymix is-muted && echo [muted] || echo)"]],
	-- command = [[playerctl metadata --format '{{artist}} - {{title}}' 2>/dev/null || echo '']],
	interval = 1,
})

vbar.bar({
	center = {
		vbar.label("${media}"),
	},
})
