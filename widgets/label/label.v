module label

import cmd
import lib.gtk
import vars

struct LabelState {
	gtk_label &C.GtkWidget
	tmpl      vars.Template
	store     &vars.VarStore
	gen       &vars.Generation = unsafe { nil }
	my_gen    int
}

@[heap]
struct LabelClickState {
	on_click        cmd.Command
	on_right_click  cmd.Command
	on_middle_click cmd.Command
	shell           []string
	lua_rt          voidptr
}

fn render(state &LabelState) {
	text := state.tmpl.render(state.store)
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

pub fn make_widget(template_str string, store &vars.VarStore, gen &vars.Generation, on_click cmd.Command, on_right_click cmd.Command, on_middle_click cmd.Command, shell []string, lua_rt voidptr) &C.GtkWidget {
	lbl := C.gtk_label_new(c'')
	C.gtk_widget_set_name(lbl, c'label')
	tmpl := vars.parse_template(template_str)
	state := &LabelState{
		gtk_label: lbl
		tmpl:      tmpl
		store:     store
		gen:       gen
		my_gen:    gen.value
	}
	for name in tmpl.var_names() {
		unsafe {
			mut s := store
			s.subscribe(name, on_var_change, voidptr(state))
		}
	}
	render(state)

	has_clicks := on_click.is_set() || on_right_click.is_set() || on_middle_click.is_set()
	if has_clicks {
		click_state := &LabelClickState{
			on_click:        on_click
			on_right_click:  on_right_click
			on_middle_click: on_middle_click
			shell:           shell
			lua_rt:          lua_rt
		}
		eb := C.gtk_event_box_new()
		C.gtk_container_add(eb, lbl)
		C.gtk_widget_add_events(eb, gtk.gdk_button_press_mask)
		C.g_signal_connect_data(eb, c'button-press-event', voidptr(label_on_click),
			voidptr(click_state), unsafe { nil }, 0)
		return eb
	}
	return lbl
}
