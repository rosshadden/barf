module label

import lib.gtk
import vars

struct LabelState {
	gtk_label &C.GtkWidget
	tmpl      vars.Template
	store     &vars.VarStore
}

fn render(state &LabelState) {
	text := state.tmpl.render(state.store)
	C.gtk_label_set_text(state.gtk_label, text.str)
}

fn on_var_change(data voidptr) {
	state := unsafe { &LabelState(data) }
	render(state)
}

pub fn make_widget(template_str string, store &vars.VarStore) &C.GtkWidget {
	lbl := C.gtk_label_new(c'')
	C.gtk_widget_set_name(lbl, c'label')
	tmpl := vars.parse_template(template_str)
	state := &LabelState{
		gtk_label: lbl
		tmpl:      tmpl
		store:     store
	}
	for name in tmpl.var_names() {
		unsafe {
			mut s := store
			s.subscribe(name, on_var_change, voidptr(state))
		}
	}
	render(state)
	return lbl
}
