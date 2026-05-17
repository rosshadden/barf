module main

fn apply_css() {
	css := '
window { background-color: ${config.bg_color}; }
label { color: ${config.fg_color}; font-family: ${config.font_family}; font-size: ${config.font_size}; padding: 0 8px; }
#workspaces label { }
#clock { }
'
	provider := C.gtk_css_provider_new()
	C.gtk_css_provider_load_from_data(provider, css.str, i64(css.len), unsafe { nil })
	screen := C.gdk_screen_get_default()
	C.gtk_style_context_add_provider_for_screen(screen, provider,
		gtk_style_provider_priority_application)
}

fn create_bar(app &C.GtkApplication) {
	win_widget := C.gtk_application_window_new(app)
	win := unsafe { &C.GtkWindow(win_widget) }

	C.gtk_layer_init_for_window(win)
	C.gtk_layer_set_layer(win, gtk_layer_shell_layer_top)
	C.gtk_layer_set_namespace(win, c'barv')
	C.gtk_layer_set_keyboard_mode(win, gtk_layer_shell_keyboard_mode_none)

	C.gtk_layer_set_anchor(win, gtk_layer_shell_edge_left, 1)
	C.gtk_layer_set_anchor(win, gtk_layer_shell_edge_right, 1)
	C.gtk_layer_set_anchor(win, gtk_layer_shell_edge_top, 1)
	C.gtk_layer_set_anchor(win, gtk_layer_shell_edge_bottom, 0)

	C.gtk_layer_auto_exclusive_zone_enable(win)
	C.gtk_widget_set_size_request(win_widget, -1, config.bar_height)

	apply_css()

	outer := C.gtk_box_new(gtk_orientation_horizontal, 0)

	left := C.gtk_box_new(gtk_orientation_horizontal, 0)
	center := C.gtk_box_new(gtk_orientation_horizontal, 0)
	right := C.gtk_box_new(gtk_orientation_horizontal, 0)

	ws_widget, _ := make_workspaces_widget()
	C.gtk_box_pack_start(left, ws_widget, 0, 0, 0)

	clock := make_clock_widget()
	C.gtk_box_pack_start(center, clock, 0, 0, 0)

	C.gtk_box_pack_start(outer, left, 0, 0, 0)
	C.gtk_box_set_center_widget(outer, center)
	C.gtk_box_pack_end(outer, right, 0, 0, 0)

	C.gtk_container_add(win_widget, outer)
	C.gtk_widget_show_all(win_widget)
}
