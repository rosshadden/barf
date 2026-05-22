module gtk

#pkgconfig gtk+-3.0

#include <gtk/gtk.h>

// Opaque GTK types
pub struct C.GtkApplication {}

pub struct C.GtkWindow {}

pub struct C.GtkWidget {}

pub struct C.GtkCssProvider {}

pub struct C.GdkScreen {}

@[typedef]
pub struct C.GdkDisplay {}

@[typedef]
pub struct C.GdkMonitor {}

@[typedef]
pub struct C.GdkRectangle {
pub mut:
	x      int
	y      int
	width  int
	height int
}

// GDK event structs
@[typedef]
pub struct C.GdkEventButton {
pub:
	@type      int
	window     voidptr
	send_event i8
	time_      u32
	x          f64
	y          f64
	axes       voidptr
	state      u32
	button     u32
}

@[typedef]
pub struct C.GdkEventScroll {
pub:
	@type      int
	window     voidptr
	send_event i8
	time_      u32
	x          f64
	y          f64
	state      u32
	direction  int
	device     voidptr
	x_root     f64
	y_root     f64
	delta_x    f64
	delta_y    f64
}

// GDK event masks
pub const gdk_button_press_mask = 256
pub const gdk_scroll_mask = 2097152

// GDK scroll directions
pub const gdk_scroll_up = 0
pub const gdk_scroll_down = 1
pub const gdk_scroll_smooth = 4

// Orientation
pub const gtk_orientation_horizontal = 0

// Style priority
pub const gtk_style_provider_priority_application = u32(600)

// Application
pub fn C.gtk_application_new(id &char, flags int) &C.GtkApplication
pub fn C.g_application_run(app &C.GtkApplication, argc int, argv voidptr) int
pub fn C.g_object_unref(obj voidptr)

// Signals
pub fn C.g_signal_connect_data(instance voidptr, signal &char, cb voidptr, data voidptr, destroy_notify voidptr, flags int) u64

// Window
pub fn C.gtk_application_window_new(app &C.GtkApplication) &C.GtkWidget
pub fn C.gtk_window_set_title(win &C.GtkWindow, title &char)
pub fn C.gtk_window_set_decorated(win &C.GtkWindow, setting int)

// Widget
pub fn C.gtk_widget_set_size_request(w &C.GtkWidget, width int, height int)
pub fn C.gtk_widget_show_all(widget &C.GtkWidget)
pub fn C.gtk_widget_set_name(widget &C.GtkWidget, name &char)
pub fn C.gtk_widget_set_halign(widget &C.GtkWidget, align int)
pub fn C.gtk_widget_set_valign(widget &C.GtkWidget, align int)
pub fn C.gtk_widget_add_events(widget &C.GtkWidget, events int)
pub fn C.gtk_widget_destroy(widget &C.GtkWidget)

// EventBox
pub fn C.gtk_event_box_new() &C.GtkWidget

// Box
pub fn C.gtk_box_new(orientation int, spacing int) &C.GtkWidget
pub fn C.gtk_box_pack_start(box_ &C.GtkWidget, child &C.GtkWidget, expand int, fill int, padding u32)
pub fn C.gtk_box_pack_end(box_ &C.GtkWidget, child &C.GtkWidget, expand int, fill int, padding u32)
pub fn C.gtk_box_set_center_widget(box_ &C.GtkWidget, center &C.GtkWidget)

// Container
pub fn C.gtk_container_add(container &C.GtkWidget, widget &C.GtkWidget)
pub fn C.gtk_container_foreach(container &C.GtkWidget, callback voidptr, callback_data voidptr)

// Label
pub fn C.gtk_label_new(text &char) &C.GtkWidget
pub fn C.gtk_label_set_text(label &C.GtkWidget, text &char)
pub fn C.gtk_label_set_markup(label &C.GtkWidget, markup &char)

// CSS
pub fn C.gtk_css_provider_new() &C.GtkCssProvider
pub fn C.gtk_css_provider_load_from_data(provider &C.GtkCssProvider, data &char, length i64, err voidptr) int
pub fn C.gdk_screen_get_default() &C.GdkScreen
pub fn C.gtk_style_context_add_provider_for_screen(screen &C.GdkScreen, provider voidptr, priority u32)

// Display and monitor
pub fn C.gdk_display_get_default() &C.GdkDisplay
pub fn C.gdk_display_get_n_monitors(display &C.GdkDisplay) int
pub fn C.gdk_display_get_monitor(display &C.GdkDisplay, monitor_num int) &C.GdkMonitor
pub fn C.gdk_monitor_get_geometry(monitor &C.GdkMonitor, geometry &C.GdkRectangle)

// GList
@[typedef]
pub struct C.GList {
pub:
	data voidptr
	next &C.GList
	prev &C.GList
}

// Application windows
pub fn C.gtk_application_get_windows(app &C.GtkApplication) &C.GList

// GLib timers and idle
pub fn C.g_timeout_add(interval u32, func voidptr, data voidptr) u32
pub fn C.g_source_remove(tag u32) int
pub fn C.g_idle_add(func voidptr, data voidptr) u32
