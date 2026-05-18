module clock

import lib.gtk
import time

struct ClockState {
mut:
	label &C.GtkWidget = unsafe { nil }
}

pub fn make_widget() &C.GtkWidget {
	label := C.gtk_label_new(c'')
	C.gtk_widget_set_name(label, c'clock')
	update_label(label)
	state := &ClockState{
		label: label
	}
	C.g_timeout_add(1000, voidptr(tick), state)
	return label
}

fn update_label(label &C.GtkWidget) {
	now := time.now()
	text := '${now.hour:02}:${now.minute:02}:${now.second:02}'
	C.gtk_label_set_text(label, text.str)
}

fn tick(data voidptr) int {
	state := unsafe { &ClockState(data) }
	update_label(state.label)
	return 1
}
