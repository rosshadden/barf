module main

struct Config {
	bar_height      int    = 30
	font_family     string = 'monospace'
	font_size       string = '10pt'
	bg_color        string = '#1e1e2e'
	fg_color        string = '#cdd6f4'
	active_ws_color string = '#89b4fa'
}

const config = Config{}
