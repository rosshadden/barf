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

// Align (GtkAlign)
pub const gtk_align_fill = 0
pub const gtk_align_start = 1
pub const gtk_align_end = 2
pub const gtk_align_center = 3

// Style priority
pub const gtk_style_provider_priority_application = u32(600)

// Application
pub fn C.gtk_application_new(id &char, flags int) &C.GtkApplication
pub fn C.g_application_run(app &C.GtkApplication, argc int, argv voidptr) int
pub fn C.g_application_hold(app &C.GtkApplication)
pub fn C.g_application_release(app &C.GtkApplication)
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

// GdkPixbuf
pub const gdk_colorspace_rgb = 0
pub const gdk_interp_bilinear = 2

@[typedef]
pub struct C.GdkPixbuf {}

pub fn C.gdk_pixbuf_new(colorspace int, has_alpha int, bits_per_sample int, width int, height int) voidptr
pub fn C.gdk_pixbuf_new_from_data(data &u8, colorspace int, has_alpha int, bits_per_sample int, width int, height int, rowstride int, destroy_fn voidptr, destroy_fn_data voidptr) voidptr
pub fn C.gdk_pixbuf_get_pixels(pixbuf voidptr) &u8
pub fn C.gdk_pixbuf_get_rowstride(pixbuf voidptr) int
pub fn C.gdk_pixbuf_scale_simple(src voidptr, dest_width int, dest_height int, interp_type int) voidptr

// GTK icon theme
@[typedef]
pub struct C.GtkIconTheme {}

pub fn C.gtk_icon_theme_get_default() &C.GtkIconTheme
pub fn C.gtk_icon_theme_lookup_icon(icon_theme &C.GtkIconTheme, icon_name &char, size int, flags int) voidptr
pub fn C.gtk_icon_info_get_filename(icon_info voidptr) &char

pub fn C.gdk_pixbuf_new_from_file_at_size(filename &char, width int, height int, error_ voidptr) voidptr

// GTK icon size
pub const gtk_icon_size_small_toolbar = 2

// GTK image widget
pub fn C.gtk_image_new_from_icon_name(icon_name &char, size int) &C.GtkWidget
pub fn C.gtk_image_new_from_pixbuf(pixbuf voidptr) &C.GtkWidget
pub fn C.gtk_image_set_from_icon_name(image &C.GtkWidget, icon_name &char, size int)
pub fn C.gtk_image_set_from_pixbuf(image &C.GtkWidget, pixbuf voidptr)

// GTK button
pub const gtk_relief_none = 2

pub fn C.gtk_button_new() &C.GtkWidget
pub fn C.gtk_button_set_image(button &C.GtkWidget, image &C.GtkWidget)
pub fn C.gtk_button_set_relief(button &C.GtkWidget, newstyle int)

// GTK drag and drop
@[typedef]
pub struct C.GtkTargetEntry {
pub:
	target &char
	flags  u32
	info   u32
}

@[typedef]
pub struct C.GtkSelectionData {}

@[typedef]
pub struct C.GdkEventCrossing {
pub:
	@type      int
	window     voidptr
	send_event i8
	subwindow  voidptr
	time_      u32
	x          f64
	y          f64
	x_root     f64
	y_root     f64
	mode       int
	detail     int
	focus      int
	state      u32
}

pub const gdk_enter_notify_mask = 4096
pub const gdk_action_copy = 2
pub const gtk_dest_default_all = 7
pub const gdk_button1_mask = 256
pub const gdk_button_release_mask = 512

pub fn C.gtk_drag_source_set(widget &C.GtkWidget, start_button_mask int, targets &C.GtkTargetEntry, n_targets int, actions int)
pub fn C.gtk_drag_source_add_text_targets(widget &C.GtkWidget)
pub fn C.gtk_drag_dest_set(widget &C.GtkWidget, flags int, targets &C.GtkTargetEntry, n_targets int, actions int)
pub fn C.gtk_drag_dest_add_text_targets(widget &C.GtkWidget)
pub fn C.gtk_selection_data_get_text(selection_data &C.GtkSelectionData) &u8
pub fn C.gtk_selection_data_set_text(selection_data &C.GtkSelectionData, str &char, len int)
pub fn C.gtk_label_get_text(label &C.GtkWidget) &char
pub fn C.g_free(ptr voidptr)

// GtkComboBoxText
pub fn C.gtk_combo_box_text_new() &C.GtkWidget
pub fn C.gtk_combo_box_text_append_text(combo_box &C.GtkWidget, text &char)
pub fn C.gtk_combo_box_text_get_active_text(combo_box &C.GtkWidget) &char
pub fn C.gtk_combo_box_set_active(combo_box &C.GtkWidget, index int)
pub fn C.gtk_combo_box_get_active(combo_box &C.GtkWidget) int
