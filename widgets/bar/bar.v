module bar

import json
import lib.gtk
import lib.layershell
import os

pub enum Anchor {
	left
	right
	top
	bottom
}

pub type ContentFn = fn (&C.GtkWidget, string, voidptr)

pub struct BarConfig {
pub:
	height       int       = 30
	anchors      []Anchor  = [Anchor.left, .right, .top]
	monitors     []string  = []
	content      ContentFn = unsafe { nil }
	content_data voidptr   = unsafe { nil }
	font_family  string    = 'monospace'
	font_size    string    = '10pt'
	bg_color     string    = '#1e1e2e'
	fg_color     string    = '#cdd6f4'
}

struct HyprMon {
	name string
	x    int
	y    int
}

fn apply_css(cfg BarConfig) {
	css := '
window { background-color: ${cfg.bg_color}; }
label { color: ${cfg.fg_color}; font-family: ${cfg.font_family}; font-size: ${cfg.font_size}; padding: 0 8px; }
'
	provider := C.gtk_css_provider_new()
	C.gtk_css_provider_load_from_data(provider, css.str, i64(css.len), unsafe { nil })
	screen := C.gdk_screen_get_default()
	C.gtk_style_context_add_provider_for_screen(screen, provider,
		gtk.gtk_style_provider_priority_application)
}

fn get_hypr_monitors() []HyprMon {
	result := os.execute('hyprctl monitors -j')
	if result.exit_code != 0 {
		return []
	}
	return json.decode([]HyprMon, result.output) or { [] }
}

fn match_monitor(monitors []HyprMon, x int, y int) string {
	for m in monitors {
		if m.x == x && m.y == y {
			return m.name
		}
	}
	return ''
}

pub fn create(app &C.GtkApplication, cfg BarConfig) {
	apply_css(cfg)

	display := C.gdk_display_get_default()
	n := C.gdk_display_get_n_monitors(display)
	hypr_monitors := get_hypr_monitors()

	for i in 0 .. n {
		gdk_mon := C.gdk_display_get_monitor(display, i)
		mut rect := C.GdkRectangle{}
		C.gdk_monitor_get_geometry(gdk_mon, &rect)
		monitor_name := match_monitor(hypr_monitors, rect.x, rect.y)
		if cfg.monitors.len > 0 && monitor_name !in cfg.monitors {
			continue
		}
		create_for_monitor(app, cfg, gdk_mon, monitor_name)
	}
}

fn create_for_monitor(app &C.GtkApplication, cfg BarConfig, gdk_mon &C.GdkMonitor, monitor_name string) {
	win_widget := C.gtk_application_window_new(app)
	win := unsafe { &C.GtkWindow(win_widget) }

	C.gtk_layer_init_for_window(win)
	C.gtk_layer_set_monitor(win, gdk_mon)
	C.gtk_layer_set_layer(win, layershell.layer_top)
	C.gtk_layer_set_namespace(win, c'vbar')
	C.gtk_layer_set_keyboard_mode(win, layershell.keyboard_mode_none)

	C.gtk_layer_set_anchor(win, layershell.edge_left, int(Anchor.left in cfg.anchors))
	C.gtk_layer_set_anchor(win, layershell.edge_right, int(Anchor.right in cfg.anchors))
	C.gtk_layer_set_anchor(win, layershell.edge_top, int(Anchor.top in cfg.anchors))
	C.gtk_layer_set_anchor(win, layershell.edge_bottom, int(Anchor.bottom in cfg.anchors))

	C.gtk_layer_auto_exclusive_zone_enable(win)
	C.gtk_widget_set_size_request(win_widget, -1, cfg.height)

	container := C.gtk_box_new(gtk.gtk_orientation_horizontal, 0)
	C.gtk_container_add(win_widget, container)

	if cfg.content != unsafe { nil } {
		cfg.content(container, monitor_name, cfg.content_data)
	}

	C.gtk_widget_show_all(win_widget)
}
