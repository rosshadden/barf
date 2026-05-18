module main

import lib.gtk
import widgets.bar
import widgets.clock
import widgets.memory
import widgets.workspaces

fn content_fn(container &C.GtkWidget, monitor_name string, data voidptr) {
	cd := unsafe { &ContentData(data) }

	left_box := C.gtk_box_new(gtk.gtk_orientation_horizontal, 0)
	center_box := C.gtk_box_new(gtk.gtk_orientation_horizontal, 0)
	right_box := C.gtk_box_new(gtk.gtk_orientation_horizontal, 0)

	for w in cd.left {
		widget := make_widget(w, monitor_name)
		if widget != unsafe { nil } {
			C.gtk_box_pack_start(left_box, widget, 0, 0, 0)
		}
	}
	for w in cd.center {
		widget := make_widget(w, monitor_name)
		if widget != unsafe { nil } {
			C.gtk_box_pack_start(center_box, widget, 0, 0, 0)
		}
	}
	for w in cd.right {
		widget := make_widget(w, monitor_name)
		if widget != unsafe { nil } {
			C.gtk_box_pack_start(right_box, widget, 0, 0, 0)
		}
	}

	C.gtk_box_pack_start(container, left_box, 0, 0, 0)
	C.gtk_box_set_center_widget(container, center_box)
	C.gtk_box_pack_end(container, right_box, 0, 0, 0)
}

fn make_widget(desc WidgetDesc, monitor_name string) &C.GtkWidget {
	return match desc.kind {
		'clock' {
			clock.make_widget()
		}
		'memory' {
			memory.make_widget()
		}
		'workspaces' {
			workspaces.make_widget(desc.active_color, monitor_name)
		}
		else {
			eprintln('vbar: unknown widget type: ${desc.kind}')
			unsafe { nil }
		}
	}
}

fn on_activate(app &C.GtkApplication, data voidptr) {
	descs := unsafe { &[]BarDesc(data) }
	mut content_refs := []&ContentData{}

	for desc in descs {
		cd := &ContentData{
			left:   desc.left
			center: desc.center
			right:  desc.right
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

		bar.create(app, bar.BarConfig{
			height:       desc.height
			anchors:      anchors
			monitors:     desc.monitors
			content:      content_fn
			content_data: voidptr(cd)
			font_family:  desc.font_family
			font_size:    desc.font_size
			bg_color:     desc.bg_color
			fg_color:     desc.fg_color
		})
	}
	_ = content_refs
}

fn main() {
	descs := load_config()

	app := C.gtk_application_new(c'io.vbar', 0)
	C.g_signal_connect_data(app, c'activate', voidptr(on_activate), voidptr(&descs),
		unsafe { nil }, 0)
	status := C.g_application_run(app, 0, unsafe { nil })
	C.g_object_unref(app)
	exit(status)
}
