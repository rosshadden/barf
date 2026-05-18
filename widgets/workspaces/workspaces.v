module workspaces

import lib.gtk
import json
import net.unix
import os
import time

struct HyprWorkspace {
	id      int
	name    string
	monitor string
}

struct HyprMonitor {
	name             string
	active_workspace HyprWorkspace @[json: 'activeWorkspace']
}

struct WorkspaceState {
mut:
	label        &C.GtkWidget = unsafe { nil }
	active_id    int
	workspaces   []HyprWorkspace
	active_color string
	monitor_name string
}

pub fn make_widget(active_color string, monitor_name string) &C.GtkWidget {
	label := C.gtk_label_new(c'')
	C.gtk_widget_set_name(label, c'workspaces')

	mut state := &WorkspaceState{
		label:        label
		active_color: active_color
		monitor_name: monitor_name
	}
	poll(mut state)
	render(state)
	spawn watch(mut state)
	return label
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

fn render(state &WorkspaceState) {
	mut parts := []string{}
	for ws in state.workspaces {
		if ws.id < 0 && ws.name.contains('special:') {
			continue
		}
		if ws.id == state.active_id {
			parts << '<span foreground="${state.active_color}">[${ws.name}]</span>'
		} else {
			parts << ws.name
		}
	}
	markup := parts.join('  ')
	C.gtk_label_set_markup(state.label, markup.str)
}

fn watch(mut state WorkspaceState) {
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
			if handle_event(line, mut state) {
				C.g_idle_add(voidptr(idle_update), state)
			}
		}
	}
}

fn handle_event(line string, mut state WorkspaceState) bool {
	if line.starts_with('workspace>>') || line.starts_with('createworkspace>>')
		|| line.starts_with('destroyworkspace>>') || line.starts_with('moveworkspace>>') {
		poll(mut state)
		return true
	}
	return false
}

fn idle_update(data voidptr) int {
	state := unsafe { &WorkspaceState(data) }
	render(state)
	return 0
}
