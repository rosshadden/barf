module main

#pkgconfig gtk-layer-shell-0

#include <gtk-layer-shell/gtk-layer-shell.h>

// Layer
const gtk_layer_shell_layer_background = 0
const gtk_layer_shell_layer_bottom = 1
const gtk_layer_shell_layer_top = 2
const gtk_layer_shell_layer_overlay = 3

// Edge
const gtk_layer_shell_edge_left = 0
const gtk_layer_shell_edge_right = 1
const gtk_layer_shell_edge_top = 2
const gtk_layer_shell_edge_bottom = 3

// Keyboard mode
const gtk_layer_shell_keyboard_mode_none = 0

fn C.gtk_layer_is_supported() int
fn C.gtk_layer_init_for_window(window &C.GtkWindow)
fn C.gtk_layer_set_layer(window &C.GtkWindow, layer int)
fn C.gtk_layer_set_anchor(window &C.GtkWindow, edge int, anchor_to_edge int)
fn C.gtk_layer_auto_exclusive_zone_enable(window &C.GtkWindow)
fn C.gtk_layer_set_namespace(window &C.GtkWindow, ns &char)
fn C.gtk_layer_set_margin(window &C.GtkWindow, edge int, margin_size int)
fn C.gtk_layer_set_keyboard_mode(window &C.GtkWindow, mode int)
