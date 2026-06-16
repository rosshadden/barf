module combo

import cmd
import lib.gtk
import vars

@[heap]
struct ComboState {
mut:
	changing  bool
	gtk_combo &C.GtkWidget = unsafe { nil }
	items     []string
	var_name  string
	store     &vars.VarStore  = unsafe { nil }
	gen       &vars.Generation = unsafe { nil }
	my_gen    int
	onchange  cmd.Command
	shell     []string
	lua_rt    voidptr
}

fn find_item_index(items []string, value string) int {
	for i, item in items {
		if item == value {
			return i
		}
	}
	return -1
}

fn on_selection_changed(widget voidptr, data voidptr) {
	mut state := unsafe { &ComboState(data) }
	if state.changing {
		return
	}
	if state.gen != unsafe { nil } && state.gen.value != state.my_gen {
		return
	}
	idx := C.gtk_combo_box_get_active(state.gtk_combo)
	if idx < 0 || idx >= state.items.len {
		return
	}
	if !state.onchange.is_set() {
		return
	}
	selected := state.items[idx].clone()
	spawn cmd.fire(state.onchange, state.shell, state.lua_rt, [selected])
}

fn on_var_change(data voidptr) {
	mut state := unsafe { &ComboState(data) }
	if state.gen != unsafe { nil } && state.gen.value != state.my_gen {
		return
	}
	value := state.store.get(state.var_name)
	idx := find_item_index(state.items, value)
	state.changing = true
	C.gtk_combo_box_set_active(state.gtk_combo, idx)
	state.changing = false
}

pub fn make_widget(items []string, var_name string, store &vars.VarStore, gen &vars.Generation, onchange cmd.Command, shell []string, lua_rt voidptr) &C.GtkWidget {
	combo := C.gtk_combo_box_text_new()
	C.gtk_widget_set_name(combo, c'combo-box-text')
	C.gtk_widget_set_valign(combo, gtk.gtk_align_center)
	for item in items {
		C.gtk_combo_box_text_append_text(combo, item.str)
	}

	mut state := &ComboState{
		gtk_combo: combo
		items:     items
		var_name:  var_name
		store:     store
		gen:       gen
		my_gen:    gen.value
		onchange:  onchange
		shell:     shell
		lua_rt:    lua_rt
	}
	store.pin(voidptr(state))

	if var_name != '' {
		store.subscribe(var_name, on_var_change, voidptr(state))
		value := store.get(var_name)
		idx := find_item_index(items, value)
		state.changing = true
		C.gtk_combo_box_set_active(combo, idx)
		state.changing = false
	}

	C.g_signal_connect_data(combo, c'changed', voidptr(on_selection_changed), voidptr(state),
		unsafe { nil }, 0)

	return combo
}
