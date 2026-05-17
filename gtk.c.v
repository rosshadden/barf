module main

#pkgconfig gtk+-3.0

#include <gtk/gtk.h>

// Opaque GTK types
struct C.GtkApplication {}

struct C.GtkWindow {}

struct C.GtkWidget {}

struct C.GtkCssProvider {}

struct C.GdkScreen {}

// Orientation
const gtk_orientation_horizontal = 0

// Style priority
const gtk_style_provider_priority_application = u32(600)

// Application
fn C.gtk_application_new(id &char, flags int) &C.GtkApplication
fn C.g_application_run(app &C.GtkApplication, argc int, argv voidptr) int
fn C.g_object_unref(obj voidptr)

// Signals
fn C.g_signal_connect_data(instance voidptr, signal &char, cb voidptr, data voidptr, destroy_notify voidptr, flags int) u64

// Window
fn C.gtk_application_window_new(app &C.GtkApplication) &C.GtkWidget
fn C.gtk_window_set_title(win &C.GtkWindow, title &char)
fn C.gtk_window_set_decorated(win &C.GtkWindow, setting int)

// Widget
fn C.gtk_widget_set_size_request(w &C.GtkWidget, width int, height int)
fn C.gtk_widget_show_all(widget &C.GtkWidget)
fn C.gtk_widget_set_name(widget &C.GtkWidget, name &char)
fn C.gtk_widget_set_halign(widget &C.GtkWidget, align int)
fn C.gtk_widget_set_valign(widget &C.GtkWidget, align int)

// Box
fn C.gtk_box_new(orientation int, spacing int) &C.GtkWidget
fn C.gtk_box_pack_start(box_ &C.GtkWidget, child &C.GtkWidget, expand int, fill int, padding u32)
fn C.gtk_box_pack_end(box_ &C.GtkWidget, child &C.GtkWidget, expand int, fill int, padding u32)
fn C.gtk_box_set_center_widget(box_ &C.GtkWidget, center &C.GtkWidget)

// Container
fn C.gtk_container_add(container &C.GtkWidget, widget &C.GtkWidget)

// Label
fn C.gtk_label_new(text &char) &C.GtkWidget
fn C.gtk_label_set_text(label &C.GtkWidget, text &char)
fn C.gtk_label_set_markup(label &C.GtkWidget, markup &char)

// CSS
fn C.gtk_css_provider_new() &C.GtkCssProvider
fn C.gtk_css_provider_load_from_data(provider &C.GtkCssProvider, data &char, length i64, err voidptr) int
fn C.gdk_screen_get_default() &C.GdkScreen
fn C.gtk_style_context_add_provider_for_screen(screen &C.GdkScreen, provider voidptr, priority u32)

// GLib timers and idle
fn C.g_timeout_add(interval u32, func voidptr, data voidptr) u32
fn C.g_idle_add(func voidptr, data voidptr) u32
