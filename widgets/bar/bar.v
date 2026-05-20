module bar

import cmd
import json
import lib.gtk
import lib.layershell
import lib.lua
import os

pub enum Anchor {
	left
	right
	top
	bottom
}

pub type ContentFn = fn (&C.GtkWidget, cmd.MonitorInfo, voidptr)

pub struct BarConfig {
pub:
	height       int       = 30
	self_ref     int       = lua.lua_noref
	anchors      []Anchor  = [Anchor.left, .right, .top]
	monitors     []string  = []
	content      ContentFn = unsafe { nil }
	content_data voidptr   = unsafe { nil }
	font_family  string    = 'monospace'
	font_size    string    = '10pt'
	bg_color     string    = '#1e1e2e'
	fg_color     string    = '#cdd6f4'
	on_scroll    cmd.Command
	on_click     cmd.Command
	shell        []string
	lua_rt       voidptr = unsafe { nil }
}

@[heap]
struct BarEventState {
	on_scroll cmd.Command
	on_click  cmd.Command
	shell     []string
	lua_rt    voidptr
}

struct HyprMon {
	id           int
	name         string
	x            int
	y            int
	width        int
	height       int
	refresh_rate f64 @[json: 'refreshRate']
	scale        f64
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

fn match_monitor(monitors []HyprMon, x int, y int) cmd.MonitorInfo {
	for m in monitors {
		if m.x == x && m.y == y {
			return cmd.MonitorInfo{
				name:         m.name
				id:           m.id
				x:            m.x
				y:            m.y
				width:        m.width
				height:       m.height
				refresh_rate: m.refresh_rate
				scale:        m.scale
			}
		}
	}
	return cmd.MonitorInfo{}
}

pub fn create(app &C.GtkApplication, cfg BarConfig) []voidptr {
	apply_css(cfg)

	display := C.gdk_display_get_default()
	n := C.gdk_display_get_n_monitors(display)
	hypr_monitors := get_hypr_monitors()

	mut refs := []voidptr{}
	for i in 0 .. n {
		gdk_mon := C.gdk_display_get_monitor(display, i)
		mut rect := C.GdkRectangle{}
		C.gdk_monitor_get_geometry(gdk_mon, &rect)
		mon := match_monitor(hypr_monitors, rect.x, rect.y)
		if cfg.monitors.len > 0 && mon.name !in cfg.monitors {
			continue
		}
		r := create_for_monitor(app, cfg, gdk_mon, mon)
		if r != unsafe { nil } {
			refs << voidptr(r)
		}
	}
	return refs
}

fn create_for_monitor(app &C.GtkApplication, cfg BarConfig, gdk_mon &C.GdkMonitor, mon cmd.MonitorInfo) &BarEventState {
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

	has_events := cfg.on_scroll.is_set() || cfg.on_click.is_set()
	mut state := &BarEventState(unsafe { nil })
	if has_events {
		event_box := C.gtk_event_box_new()
		C.gtk_container_add(win_widget, event_box)
		C.gtk_container_add(event_box, container)

		new_self := cmd.clone_self_with_monitor(cfg.lua_rt, cfg.self_ref, mon)
		state = &BarEventState{
			on_scroll: cfg.on_scroll.with_self_ref(new_self)
			on_click:  cfg.on_click.with_self_ref(new_self)
			shell:     cfg.shell
			lua_rt:    cfg.lua_rt
		}

		if cfg.on_scroll.is_set() {
			C.gtk_widget_add_events(event_box, gtk.gdk_scroll_mask)
			C.g_signal_connect_data(event_box, c'scroll-event', voidptr(bar_on_scroll),
				voidptr(state), unsafe { nil }, 0)
		}
		if cfg.on_click.is_set() {
			C.gtk_widget_add_events(event_box, gtk.gdk_button_press_mask)
			C.g_signal_connect_data(event_box, c'button-press-event', voidptr(bar_on_click),
				voidptr(state), unsafe { nil }, 0)
		}
	} else {
		C.gtk_container_add(win_widget, container)
	}

	if cfg.content != unsafe { nil } {
		cfg.content(container, mon, cfg.content_data)
	}

	C.gtk_widget_show_all(win_widget)
	return state
}

fn bar_on_scroll(widget voidptr, event &C.GdkEventScroll, data voidptr) int {
	state := unsafe { &BarEventState(data) }
	if !state.on_scroll.is_set() {
		return 0
	}
	dir := if event.direction == gtk.gdk_scroll_up {
		'up'
	} else if event.direction == gtk.gdk_scroll_down {
		'down'
	} else if event.direction == gtk.gdk_scroll_smooth {
		if event.delta_y < 0 {
			'up'
		} else if event.delta_y > 0 {
			'down'
		} else {
			return 0
		}
	} else {
		return 0
	}
	spawn cmd.fire(state.on_scroll, state.shell, state.lua_rt, [dir])
	return 1
}

fn bar_on_click(widget voidptr, event &C.GdkEventButton, data voidptr) int {
	state := unsafe { &BarEventState(data) }
	if event.button != 1 || !state.on_click.is_set() {
		return 0
	}
	spawn cmd.fire(state.on_click, state.shell, state.lua_rt, [])
	return 1
}
