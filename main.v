module main

import lib.gtk
import widgets.bar
import widgets.clock
import widgets.memory
import widgets.workspaces

fn main_bar_content(container &C.GtkWidget, monitor_name string) {
	left := C.gtk_box_new(gtk.gtk_orientation_horizontal, 0)
	center := C.gtk_box_new(gtk.gtk_orientation_horizontal, 0)
	right := C.gtk_box_new(gtk.gtk_orientation_horizontal, 0)

	C.gtk_box_pack_start(left, workspaces.make_widget(config.active_ws_color, monitor_name), 0, 0,
		0)
	C.gtk_box_pack_start(center, clock.make_widget(), 0, 0, 0)

	C.gtk_box_pack_start(container, left, 0, 0, 0)
	C.gtk_box_set_center_widget(container, center)
	C.gtk_box_pack_end(container, right, 0, 0, 0)
}

fn bottom_bar_content(container &C.GtkWidget, _ string) {
	C.gtk_box_pack_start(container, memory.make_widget(), 0, 0, 0)
}

fn on_activate(app &C.GtkApplication, _ voidptr) {
	bar.create(app, bar.BarConfig{
		height:      config.bar_height
		content:     main_bar_content
		font_family: config.font_family
		font_size:   config.font_size
		bg_color:    config.bg_color
		fg_color:    config.fg_color
	})
	bar.create(app, bar.BarConfig{
		height:      config.bar_height
		anchors:     [bar.Anchor.left, .right, .bottom]
		monitors:    ['HDMI-A-1']
		content:     bottom_bar_content
		font_family: config.font_family
		font_size:   config.font_size
		bg_color:    config.bg_color
		fg_color:    config.fg_color
	})
}

fn main() {
	app := C.gtk_application_new(c'io.vbar', 0)
	C.g_signal_connect_data(app, c'activate', voidptr(on_activate), unsafe { nil }, unsafe { nil },
		0)
	status := C.g_application_run(app, 0, unsafe { nil })
	C.g_object_unref(app)
	exit(status)
}
