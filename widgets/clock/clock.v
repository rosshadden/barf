module clock

import lib.gtk
import time

pub fn make_widget() &C.GtkWidget {
	label := C.gtk_label_new(c'')
	C.gtk_widget_set_name(label, c'clock')
	update_label(label)
	C.g_timeout_add(1000, voidptr(tick), label)
	return label
}

fn update_label(label &C.GtkWidget) {
	now := time.now()
	text := '${now.hour:02}:${now.minute:02}:${now.second:02}'
	C.gtk_label_set_text(label, text.str)
}

fn tick(data voidptr) int {
	label := unsafe { &C.GtkWidget(data) }
	update_label(label)
	return 1
}
