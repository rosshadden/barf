module layershell

#pkgconfig gtk-layer-shell-0

#include <gtk-layer-shell/gtk-layer-shell.h>

// Layer
pub const layer_background = 0
pub const layer_bottom = 1
pub const layer_top = 2
pub const layer_overlay = 3

// Edge
pub const edge_left = 0
pub const edge_right = 1
pub const edge_top = 2
pub const edge_bottom = 3

// Keyboard mode
pub const keyboard_mode_none = 0
pub const keyboard_mode_exclusive = 1
pub const keyboard_mode_on_demand = 2

pub fn C.gtk_layer_is_supported() int
pub fn C.gtk_layer_init_for_window(window &C.GtkWindow)
pub fn C.gtk_layer_set_layer(window &C.GtkWindow, layer int)
pub fn C.gtk_layer_set_anchor(window &C.GtkWindow, edge int, anchor_to_edge int)
pub fn C.gtk_layer_auto_exclusive_zone_enable(window &C.GtkWindow)
pub fn C.gtk_layer_set_namespace(window &C.GtkWindow, ns &char)
pub fn C.gtk_layer_set_margin(window &C.GtkWindow, edge int, margin_size int)
pub fn C.gtk_layer_set_keyboard_mode(window &C.GtkWindow, mode int)
pub fn C.gtk_layer_set_monitor(window &C.GtkWindow, monitor &C.GdkMonitor)
