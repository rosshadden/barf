module main

import json
import net.unix
import os
import time

struct HyprWorkspace {
	id   int
	name string
}

struct WorkspaceState {
mut:
	label      &C.GtkWidget = unsafe { nil }
	active_id  int
	workspaces []HyprWorkspace
}

fn make_workspaces_widget() (&C.GtkWidget, &WorkspaceState) {
	label := C.gtk_label_new(c'')
	C.gtk_widget_set_name(label, c'workspaces')

	mut state := &WorkspaceState{
		label: label
	}
	poll_workspaces(mut state)
	render_workspaces(state)
	spawn watch_hyprland(mut state)
	return label, state
}

fn poll_workspaces(mut state WorkspaceState) {
	ws_result := os.execute('hyprctl workspaces -j')
	if ws_result.exit_code == 0 {
		state.workspaces = json.decode([]HyprWorkspace, ws_result.output) or { [] }
		state.workspaces.sort(a.id < b.id)
	}

	active_result := os.execute('hyprctl activeworkspace -j')
	if active_result.exit_code == 0 {
		active := json.decode(HyprWorkspace, active_result.output) or {
			HyprWorkspace{
				id:   1
				name: '1'
			}
		}
		state.active_id = active.id
	}
}

fn render_workspaces(state &WorkspaceState) {
	mut parts := []string{}
	for ws in state.workspaces {
		if ws.id < 0 {
			continue
		}
		if ws.id == state.active_id {
			parts << '<span foreground="${config.active_ws_color}">[${ws.name}]</span>'
		} else {
			parts << ws.name
		}
	}
	markup := parts.join('  ')
	C.gtk_label_set_markup(state.label, markup.str)
}

fn watch_hyprland(mut state WorkspaceState) {
	instance := os.getenv('HYPRLAND_INSTANCE_SIGNATURE')
	runtime := os.getenv('XDG_RUNTIME_DIR')
	sock_path := '${runtime}/hypr/${instance}/.socket2.sock'

	mut conn := unix.connect_stream(sock_path) or {
		eprintln('barv: hyprland socket: ${err}')
		return
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
			if handle_hypr_event(line, mut state) {
				C.g_idle_add(voidptr(workspace_idle_update), state)
			}
		}
	}
}

fn handle_hypr_event(line string, mut state WorkspaceState) bool {
	if line.starts_with('workspace>>') || line.starts_with('createworkspace>>')
		|| line.starts_with('destroyworkspace>>') || line.starts_with('moveworkspace>>') {
		poll_workspaces(mut state)
		return true
	}
	return false
}

fn workspace_idle_update(data voidptr) int {
	state := unsafe { &WorkspaceState(data) }
	render_workspaces(state)
	return 0
}
