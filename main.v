module main

fn on_activate(app &C.GtkApplication, _ voidptr) {
	create_bar(app)
}

fn main() {
	app := C.gtk_application_new(c'io.barv', 0)
	C.g_signal_connect_data(app, c'activate', voidptr(on_activate), unsafe { nil }, unsafe { nil },
		0)
	status := C.g_application_run(app, 0, unsafe { nil })
	C.g_object_unref(app)
	exit(status)
}
