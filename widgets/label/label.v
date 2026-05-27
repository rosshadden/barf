module label

import cmd
import lib.gtk
import lib.lua
import vars

struct LabelState {
	gtk_label  &C.GtkWidget
	text       string
	var_name   string
	store      &vars.VarStore
	gen        &vars.Generation = unsafe { nil }
	my_gen     int
	format_ref int     = lua.lua_noref
	self_ref   int     = lua.lua_noref
	lua_rt     voidptr = unsafe { nil }
}

@[heap]
struct LabelClickState {
	on_click        cmd.Command
	on_right_click  cmd.Command
	on_middle_click cmd.Command
	on_drag         cmd.Command
	drag_enabled    bool
	on_drop         cmd.Command
	gtk_label       &C.GtkWidget = unsafe { nil }
	shell           []string
	lua_rt          voidptr
}

fn render(state &LabelState) {
	mut value := ''
	if state.var_name != '' {
		value = state.store.get(state.var_name)
	}
	if state.format_ref != lua.lua_noref {
		value = cmd.call_var_format(state.lua_rt, state.self_ref, state.format_ref, value) or {
			value
		}
	}
	text := if state.text == '' {
		value
	} else if state.var_name != '' && state.text.contains('{}') {
		state.text.replace('{}', value)
	} else {
		state.text
	}
	C.gtk_label_set_text(state.gtk_label, text.str)
}

fn on_var_change(data voidptr) {
	state := unsafe { &LabelState(data) }
	if state.gen != unsafe { nil } && state.gen.value != state.my_gen {
		return
	}
	render(state)
}

fn label_on_click(widget voidptr, event &C.GdkEventButton, data voidptr) int {
	state := unsafe { &LabelClickState(data) }
	c := match event.button {
		1 { state.on_click }
		2 { state.on_middle_click }
		3 { state.on_right_click }
		else { cmd.Command{} }
	}

	if !c.is_set() {
		return 0
	}
	spawn cmd.fire(c, state.shell, state.lua_rt, [])
	return 1
}

fn label_on_drag_get(widget voidptr, context voidptr, selection_data &C.GtkSelectionData, info u32, time_ u32, data voidptr) {
	state := unsafe { &LabelClickState(data) }
	text := if state.on_drag.is_set() {
		cmd.exec(state.on_drag, state.shell, state.lua_rt, []) or { '' }
	} else {
		raw := C.gtk_label_get_text(state.gtk_label)
		if raw != unsafe { nil } {
			unsafe { cstring_to_vstring(raw) }
		} else {
			''
		}
	}
	if text.len > 0 {
		C.gtk_selection_data_set_text(selection_data, text.str, text.len)
	}
}

fn label_on_drop_received(widget voidptr, context voidptr, x int, y int, selection_data &C.GtkSelectionData, info u32, time_ u32, data voidptr) {
	state := unsafe { &LabelClickState(data) }
	if !state.on_drop.is_set() {
		return
	}
	raw := C.gtk_selection_data_get_text(selection_data)
	if raw == unsafe { nil } {
		return
	}
	text := unsafe { cstring_to_vstring(&char(raw)) }
	C.g_free(raw)
	spawn cmd.fire(state.on_drop, state.shell, state.lua_rt, [text])
}

pub fn make_widget(text string, var_name string, store &vars.VarStore, gen &vars.Generation, on_click cmd.Command, on_right_click cmd.Command, on_middle_click cmd.Command, on_drag cmd.Command, drag_enabled bool, on_drop cmd.Command, shell []string, lua_rt voidptr, format_ref int, self_ref int) &C.GtkWidget {
	lbl := C.gtk_label_new(c'')
	C.gtk_widget_set_name(lbl, c'label')
	state := &LabelState{
		gtk_label:  lbl
		text:       text
		var_name:   var_name
		store:      store
		gen:        gen
		my_gen:     gen.value
		format_ref: format_ref
		self_ref:   self_ref
		lua_rt:     lua_rt
	}
	if var_name != '' {
		store.subscribe(var_name, on_var_change, voidptr(state))
	}
	render(state)

	has_clicks := on_click.is_set() || on_right_click.is_set() || on_middle_click.is_set()
	has_dnd := drag_enabled || on_drop.is_set()
	if has_clicks || has_dnd {
		click_state := &LabelClickState{
			on_click:        on_click
			on_right_click:  on_right_click
			on_middle_click: on_middle_click
			on_drag:         on_drag
			drag_enabled:    drag_enabled
			on_drop:         on_drop
			gtk_label:       lbl
			shell:           shell
			lua_rt:          lua_rt
		}
		store.pin(voidptr(click_state))
		eb := C.gtk_event_box_new()
		C.gtk_container_add(eb, lbl)

		if has_clicks {
			C.gtk_widget_add_events(eb, gtk.gdk_button_press_mask | gtk.gdk_button_release_mask)
			C.g_signal_connect_data(eb, c'button-release-event', voidptr(label_on_click),
				voidptr(click_state), unsafe { nil }, 0)
		}

		if drag_enabled {
			C.gtk_drag_source_set(eb, gtk.gdk_button1_mask, unsafe { nil }, 0, gtk.gdk_action_copy)
			C.gtk_drag_source_add_text_targets(eb)
			C.g_signal_connect_data(eb, c'drag-data-get', voidptr(label_on_drag_get),
				voidptr(click_state), unsafe { nil }, 0)
		}

		if on_drop.is_set() {
			C.gtk_drag_dest_set(eb, gtk.gtk_dest_default_all, unsafe { nil }, 0,
				gtk.gdk_action_copy)
			C.gtk_drag_dest_add_text_targets(eb)
			C.g_signal_connect_data(eb, c'drag-data-received', voidptr(label_on_drop_received),
				voidptr(click_state), unsafe { nil }, 0)
		}

		return eb
	}
	return lbl
}
