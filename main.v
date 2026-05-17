module main

import bar
import gtk

fn on_activate(app &C.GtkApplication, _ voidptr) {
	bar.create(app, bar.BarConfig{
		height:       config.bar_height
		font_family:  config.font_family
		font_size:    config.font_size
		bg_color:     config.bg_color
		fg_color:     config.fg_color
		active_color: config.active_ws_color
	})
}

fn main() {
	app := C.gtk_application_new(c'io.barv', 0)
	C.g_signal_connect_data(app, c'activate', voidptr(on_activate), unsafe { nil }, unsafe { nil },
		0)
	status := C.g_application_run(app, 0, unsafe { nil })
	C.g_object_unref(app)
	exit(status)
}
