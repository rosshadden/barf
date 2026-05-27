module workspaces

import cmd
import lib.gtk
import json
import net.unix
import os
import time
import vars

struct HyprWorkspace {
	id      int
	name    string
	monitor string
}

struct HyprMonitor {
	name             string
	active_workspace HyprWorkspace @[json: 'activeWorkspace']
}

@[heap]
struct WsClickState {
	ws_name         string
	on_click        cmd.Command
	on_right_click  cmd.Command
	on_middle_click cmd.Command
	on_drop         cmd.Command
	shell           []string
	lua_rt          voidptr
}

struct WorkspaceState {
mut:
	container       &C.GtkWidget = unsafe { nil }
	active_id       int
	workspaces      []HyprWorkspace
	active_color    string
	monitor_name    string
	on_click        cmd.Command
	on_right_click  cmd.Command
	on_middle_click cmd.Command
	on_drop         cmd.Command
	shell           []string
	lua_rt          voidptr
	refs            []&WsClickState
	gen             &vars.Generation = unsafe { nil }
	my_gen          int
}

pub fn make_widget(active_color string, monitor_name string, on_click cmd.Command, on_right_click cmd.Command, on_middle_click cmd.Command, on_drop cmd.Command, shell []string, gen &vars.Generation, lua_rt voidptr) &C.GtkWidget {
	container := C.gtk_box_new(gtk.gtk_orientation_horizontal, 4)
	C.gtk_widget_set_name(container, c'workspaces')

	mut state := &WorkspaceState{
		container:       container
		active_color:    active_color
		monitor_name:    monitor_name
		on_click:        on_click
		on_right_click:  on_right_click
		on_middle_click: on_middle_click
		on_drop:         on_drop
		shell:           shell
		lua_rt:          lua_rt
		gen:             gen
		my_gen:          gen.value
	}
	poll(mut state)
	render(mut state)
	spawn watch(mut state)
	return container
}

fn poll(mut state WorkspaceState) {
	ws_result := os.execute('hyprctl workspaces -j')
	if ws_result.exit_code == 0 {
		all_ws := json.decode([]HyprWorkspace, ws_result.output) or { [] }
		if state.monitor_name.len > 0 {
			state.workspaces = all_ws.filter(it.monitor == state.monitor_name)
		} else {
			state.workspaces = all_ws
		}
		state.workspaces.sort(a.id < b.id)
	}

	mon_result := os.execute('hyprctl monitors -j')
	if mon_result.exit_code == 0 {
		monitors := json.decode([]HyprMonitor, mon_result.output) or { [] }
		for m in monitors {
			if m.name == state.monitor_name {
				state.active_id = m.active_workspace.id
				break
			}
		}
	}
}

fn destroy_child(child &C.GtkWidget, data voidptr) {
	C.gtk_widget_destroy(child)
}

fn render(mut state WorkspaceState) {
	state.refs = []&WsClickState{}
	C.gtk_container_foreach(state.container, voidptr(destroy_child), unsafe { nil })

	has_clicks := state.on_click.is_set() || state.on_right_click.is_set()
		|| state.on_middle_click.is_set()
	has_drop := state.on_drop.is_set()

	for ws in state.workspaces {
		if ws.id < 0 && ws.name.contains('special:') {
			continue
		}

		lbl := C.gtk_label_new(c'')
		if ws.id == state.active_id {
			markup := '<span foreground="${state.active_color}">[${ws.name}]</span>'
			C.gtk_label_set_markup(lbl, markup.str)
		} else {
			C.gtk_label_set_text(lbl, ws.name.str)
		}

		if has_clicks {
			click_state := &WsClickState{
				ws_name:         ws.name
				on_click:        state.on_click
				on_right_click:  state.on_right_click
				on_middle_click: state.on_middle_click
				on_drop:         state.on_drop
				shell:           state.shell
				lua_rt:          state.lua_rt
			}
			state.refs << click_state

			eb := C.gtk_event_box_new()
			C.gtk_container_add(eb, lbl)
			C.gtk_widget_add_events(eb, gtk.gdk_button_press_mask | gtk.gdk_button_release_mask)
			C.g_signal_connect_data(eb, c'button-release-event', voidptr(ws_on_click),
				voidptr(click_state), unsafe { nil }, 0)
			C.gtk_box_pack_start(state.container, eb, 0, 0, 0)
		} else {
			C.gtk_box_pack_start(state.container, lbl, 0, 0, 0)
		}
	}

	C.gtk_widget_show_all(state.container)
}

fn watch(mut state WorkspaceState) {
	instance := os.getenv('HYPRLAND_INSTANCE_SIGNATURE')
	runtime := os.getenv('XDG_RUNTIME_DIR')
	sock_path := '${runtime}/hypr/${instance}/.socket2.sock'

	for {
		if state.gen.value != state.my_gen {
			return
		}
		mut conn := unix.connect_stream(sock_path) or {
			time.sleep(2 * time.second)
			continue
		}
		conn.set_read_timeout(time.infinite)

		mut buf := []u8{len: 4096}
		mut partial := ''
		for {
			n := conn.read(mut buf) or { break }
			if n == 0 {
				break
			}
			partial += buf[..n].bytestr()
			for {
				idx := partial.index_u8(`\n`)
				if idx < 0 {
					break
				}
				line := partial[..idx]
				partial = partial[idx + 1..]
				if handle_event(line) {
					C.g_idle_add(voidptr(idle_update), state)
				}
			}
		}
		conn.close() or {}
		time.sleep(2 * time.second)
	}
}

fn handle_event(line string) bool {
	return line.starts_with('workspace>>') || line.starts_with('createworkspace>>')
		|| line.starts_with('destroyworkspace>>') || line.starts_with('moveworkspace>>')
}

fn idle_update(data voidptr) int {
	mut state := unsafe { &WorkspaceState(data) }
	if state.gen != unsafe { nil } && state.gen.value != state.my_gen {
		return 0
	}
	poll(mut state)
	render(mut state)
	return 0
}

fn ws_on_click(widget voidptr, event &C.GdkEventButton, data voidptr) int {
	state := unsafe { &WsClickState(data) }
	c := match event.button {
		1 { state.on_click }
		2 { state.on_middle_click }
		3 { state.on_right_click }
		else { cmd.Command{} }
	}

	if !c.is_set() {
		return 0
	}
	spawn cmd.fire(c, state.shell, state.lua_rt, [state.ws_name])
	return 1
}
