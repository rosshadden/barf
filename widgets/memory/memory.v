module memory

import lib.gtk
import os

pub fn make_widget() &C.GtkWidget {
	label := C.gtk_label_new(c'')
	C.gtk_widget_set_name(label, c'memory')
	update_label(label)
	C.g_timeout_add(2000, voidptr(tick), label)
	return label
}

fn read_meminfo() (u64, u64) {
	lines := os.read_lines('/proc/meminfo') or { return 0, 0 }
	mut total := u64(0)
	mut available := u64(0)
	for line in lines {
		if line.starts_with('MemTotal:') {
			total = line.all_after(':').trim_space().all_before(' ').u64()
		} else if line.starts_with('MemAvailable:') {
			available = line.all_after(':').trim_space().all_before(' ').u64()
		}
		if total > 0 && available > 0 {
			break
		}
	}
	return total, available
}

fn update_label(label &C.GtkWidget) {
	total, available := read_meminfo()
	if total == 0 {
		C.gtk_label_set_text(label, c'RAM: ?')
		return
	}
	used_mb := (total - available) / 1024
	total_mb := total / 1024
	usage := (used_mb * 100) / total_mb
	text := 'RAM: ${usage}%'
	C.gtk_label_set_text(label, text.str)
}

fn tick(data voidptr) int {
	label := unsafe { &C.GtkWidget(data) }
	update_label(label)
	return 1
}
