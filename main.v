module main

import lib.gtk
import providers
import vars
import widgets.bar
import widgets.label
import widgets.workspaces

struct AppData {
	config Config
	store  &vars.VarStore
mut:
	refs []voidptr
}

fn content_fn(container &C.GtkWidget, monitor_name string, data voidptr) {
	cd := unsafe { &ContentData(data) }
	store := unsafe { &vars.VarStore(cd.store) }

	left_box := C.gtk_box_new(gtk.gtk_orientation_horizontal, 0)
	center_box := C.gtk_box_new(gtk.gtk_orientation_horizontal, 0)
	right_box := C.gtk_box_new(gtk.gtk_orientation_horizontal, 0)

	for w in cd.left {
		widget := make_widget(w, monitor_name, store, cd.shell)
		if widget != unsafe { nil } {
			C.gtk_box_pack_start(left_box, widget, 0, 0, 0)
		}
	}
	for w in cd.center {
		widget := make_widget(w, monitor_name, store, cd.shell)
		if widget != unsafe { nil } {
			C.gtk_box_pack_start(center_box, widget, 0, 0, 0)
		}
	}
	for w in cd.right {
		widget := make_widget(w, monitor_name, store, cd.shell)
		if widget != unsafe { nil } {
			C.gtk_box_pack_start(right_box, widget, 0, 0, 0)
		}
	}

	C.gtk_box_pack_start(container, left_box, 0, 0, 0)
	C.gtk_box_set_center_widget(container, center_box)
	C.gtk_box_pack_end(container, right_box, 0, 0, 0)
}

fn make_widget(desc WidgetDesc, monitor_name string, store &vars.VarStore, shell []string) &C.GtkWidget {
	return match desc.kind {
		'label' {
			label.make_widget(desc.text, store)
		}
		'workspaces' {
			workspaces.make_widget(desc.active_color, monitor_name, desc.on_click,
				desc.on_right_click, desc.on_middle_click, shell)
		}
		else {
			eprintln('vbar: unknown widget type: ${desc.kind}')
			unsafe { nil }
		}
	}
}

fn on_activate(app &C.GtkApplication, data voidptr) {
	mut ad := unsafe { &AppData(data) }
	default_shell := if ad.config.shell.len > 0 { ad.config.shell } else { ['sh', '-c'] }
	mut content_refs := []&ContentData{}

	for desc in ad.config.bars {
		cd := &ContentData{
			left:   desc.left
			center: desc.center
			right:  desc.right
			store:  voidptr(ad.store)
			shell:  default_shell
		}
		content_refs << cd

		mut anchors := desc.anchors.map(fn (s string) bar.Anchor {
			return match s {
				'left' { bar.Anchor.left }
				'right' { bar.Anchor.right }
				'bottom' { bar.Anchor.bottom }
				else { bar.Anchor.top }
			}
		})
		if anchors.len == 0 {
			anchors = [bar.Anchor.left, .right, .top]
		}

		event_refs := bar.create(app, bar.BarConfig{
			height:       desc.height
			anchors:      anchors
			monitors:     desc.monitors
			content:      content_fn
			content_data: voidptr(cd)
			font_family:  desc.font_family
			font_size:    desc.font_size
			bg_color:     desc.bg_color
			fg_color:     desc.fg_color
			on_scroll:    desc.on_scroll
			on_click:     desc.on_click
			shell:        default_shell
		})
		for r in event_refs {
			ad.refs << r
		}
	}
	_ = content_refs
}

fn main() {
	cfg := load_config()
	mut store := &vars.VarStore{}

	providers.start_time(store)

	for b in cfg.builtins {
		match b.kind {
			'cpu' { providers.start_cpu(store, b.interval) }
			'ram' { providers.start_ram(store, b.interval) }
			else {}
		}
	}

	default_shell := if cfg.shell.len > 0 { cfg.shell } else { ['sh', '-c'] }
	for p in cfg.polls {
		shell := if p.shell.len > 0 { p.shell } else { default_shell }
		providers.start_poll(p.name, p.command, p.interval, shell, store)
	}

	ad := &AppData{
		config: cfg
		store:  store
	}

	app := C.gtk_application_new(c'io.vbar', 0)
	C.g_signal_connect_data(app, c'activate', voidptr(on_activate), voidptr(ad), unsafe { nil }, 0)
	status := C.g_application_run(app, 0, unsafe { nil })
	C.g_object_unref(app)
	exit(status)
}
