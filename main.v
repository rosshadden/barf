module main

import cmd
import ipc
import lib.gtk
import lib.inotify
import os
import providers
import vars
import widgets.bar
import widgets.label
import widgets.systray
import widgets.workspaces

struct AppData {
mut:
	config          Config
	refs            []voidptr
	app             &C.GtkApplication = unsafe { nil }
	store           &vars.VarStore    = unsafe { nil }
	gen             &vars.Generation  = unsafe { nil }
	lua_rt          &cmd.LuaRuntime   = unsafe { nil }
	reload_timer_id u32
}

fn content_fn(container &C.GtkWidget, mon cmd.MonitorInfo, data voidptr) {
	cd := unsafe { &ContentData(data) }
	store := unsafe { &vars.VarStore(cd.store) }
	gen := unsafe { &vars.Generation(cd.gen) }

	left_box := C.gtk_box_new(gtk.gtk_orientation_horizontal, 0)
	center_box := C.gtk_box_new(gtk.gtk_orientation_horizontal, 0)
	right_box := C.gtk_box_new(gtk.gtk_orientation_horizontal, 0)

	for w in cd.left {
		widget := make_widget(w, mon, store, cd.shell, gen, cd.lua_rt)
		if widget != unsafe { nil } {
			C.gtk_box_pack_start(left_box, widget, 0, 0, 0)
		}
	}
	for w in cd.center {
		widget := make_widget(w, mon, store, cd.shell, gen, cd.lua_rt)
		if widget != unsafe { nil } {
			C.gtk_box_pack_start(center_box, widget, 0, 0, 0)
		}
	}
	for w in cd.right {
		widget := make_widget(w, mon, store, cd.shell, gen, cd.lua_rt)
		if widget != unsafe { nil } {
			C.gtk_box_pack_start(right_box, widget, 0, 0, 0)
		}
	}

	C.gtk_box_pack_start(container, left_box, 0, 0, 0)
	C.gtk_box_set_center_widget(container, center_box)
	C.gtk_box_pack_end(container, right_box, 0, 0, 0)
}

fn make_widget(desc WidgetDesc, mon cmd.MonitorInfo, store &vars.VarStore, shell []string, gen &vars.Generation, lua_rt voidptr) &C.GtkWidget {
	new_self := cmd.clone_self_with_monitor(lua_rt, desc.self_ref, mon)
	on_click := desc.on_click.with_self_ref(new_self)
	on_right_click := desc.on_right_click.with_self_ref(new_self)
	on_middle_click := desc.on_middle_click.with_self_ref(new_self)

	return match desc.kind {
		'label' {
			label.make_widget(desc.text, desc.var_name, store, gen, on_click, on_right_click,
				on_middle_click, shell, lua_rt, desc.format_ref, new_self)
		}
		'workspaces' {
			workspaces.make_widget(desc.active_color, mon.name, on_click, on_right_click,
				on_middle_click, shell, gen, lua_rt)
		}
		'systray' {
			systray.make_widget(desc.icon_size)
		}
		else {
			eprintln('vbar: unknown widget type: ${desc.kind}')
			unsafe { nil }
		}
	}
}

fn setup(mut ad AppData) {
	cfg := ad.config
	default_shell := if cfg.shell.len > 0 { cfg.shell } else { ['sh', '-c'] }

	cmd.bind_store(ad.lua_rt, voidptr(ad.store))

	for gv in global_var_descs() {
		providers.start_poll(gv.name, cmd.Command{ kind: .shell, str_val: gv.command },
			gv.interval, ['sh', '-c'], ad.store, ad.gen, voidptr(ad.lua_rt))
	}

	for p in cfg.polls {
		if p.value != '' {
			unsafe {
				mut store := ad.store
				if p.value_is_json {
					store.set_json(p.name, p.value)
				} else {
					store.set(p.name, p.value)
				}
			}
		}
		if p.command.is_set() {
			shell := if p.shell.len > 0 { p.shell } else { default_shell }
			providers.start_poll(p.name, p.command, p.interval, shell, ad.store, ad.gen,
				voidptr(ad.lua_rt))
		}
		if p.listen_shell != '' {
			shell := if p.shell.len > 0 { p.shell } else { default_shell }
			providers.start_listen(p.name, p.listen_shell, shell, p.listen_override, ad.store,
				ad.gen, voidptr(ad.lua_rt))
		}
	}

	mut content_refs := []&ContentData{}
	for desc in cfg.bars {
		cd := &ContentData{
			left:   desc.left
			center: desc.center
			right:  desc.right
			store:  voidptr(ad.store)
			gen:    voidptr(ad.gen)
			shell:  default_shell
			lua_rt: voidptr(ad.lua_rt)
		}
		content_refs << cd

		mut anchors := desc.anchors.map(fn (s string) bar.Anchor {
			return match s {
				'left' { bar.Anchor.left }
				'right' { bar.Anchor.right }
				'bottom' { bar.Anchor.bottom }
				else { bar.Anchor.top }
			}
		})
		if anchors.len == 0 {
			anchors = [bar.Anchor.left, .right, .top]
		}

		event_refs := bar.create(ad.app, bar.BarConfig{
			height:       desc.height
			self_ref:     desc.self_ref
			anchors:      anchors
			monitors:     desc.monitors
			content:      content_fn
			content_data: voidptr(cd)
			font_family:  desc.font_family
			font_size:    desc.font_size
			bg_color:     desc.bg_color
			fg_color:     desc.fg_color
			on_scroll:    desc.on_scroll
			on_click:     desc.on_click
			shell:        default_shell
			lua_rt:       voidptr(ad.lua_rt)
		})
		for r in event_refs {
			ad.refs << r
		}
	}
	_ = content_refs
}

struct IpcSetRequest {
	name  string
	value string
	store voidptr
}

fn ipc_set_apply(data voidptr) int {
	req := unsafe { &IpcSetRequest(data) }
	unsafe {
		mut store := &vars.VarStore(req.store)
		store.set(req.name, req.value)
	}
	return 0
}

fn ipc_set_var(name string, value string, data voidptr) {
	req := &IpcSetRequest{
		name:  name
		value: value
		store: data
	}
	C.g_idle_add(voidptr(ipc_set_apply), voidptr(req))
}

fn do_reload(data voidptr) int {
	mut ad := unsafe { &AppData(data) }
	ad.reload_timer_id = 0
	ad.gen.value++

	mut node := C.gtk_application_get_windows(ad.app)
	mut windows := []&C.GtkWidget{}
	for node != unsafe { nil } {
		windows << unsafe { &C.GtkWidget(node.data) }
		node = node.next
	}
	for w in windows {
		C.gtk_widget_destroy(w)
	}

	unsafe {
		mut store := ad.store
		store.clear()
	}
	if ad.lua_rt != unsafe { nil } {
		unsafe {
			mut rt := ad.lua_rt
			rt.close()
		}
	}
	config, lua_state := load_config()
	ad.config = config
	if lua_state != unsafe { nil } {
		ad.lua_rt = cmd.new_runtime(lua_state)
	} else {
		ad.lua_rt = unsafe { nil }
	}
	ad.refs = []
	setup(mut ad)
	return 0
}

fn on_monitor_changed(display voidptr, monitor voidptr, data voidptr) {
	mut ad := unsafe { &AppData(data) }
	// bump gen before destroying so idle_update callbacks see stale gen and bail
	ad.gen.value++
	// destroy windows immediately to avoid wayland error
	mut node := C.gtk_application_get_windows(ad.app)
	mut windows := []&C.GtkWidget{}
	for node != unsafe { nil } {
		windows << unsafe { &C.GtkWidget(node.data) }
		node = node.next
	}
	for w in windows {
		C.gtk_widget_destroy(w)
	}
	// debounce
	if ad.reload_timer_id != 0 {
		C.g_source_remove(ad.reload_timer_id)
	}
	ad.reload_timer_id = C.g_timeout_add(200, voidptr(do_reload), data)
}

fn on_activate(app &C.GtkApplication, data voidptr) {
	mut ad := unsafe { &AppData(data) }
	unsafe {
		ad.app = app
	}
	// keep the app alive across moments when every window is destroyed
	// (e.g. monitor-removed on DPMS off), otherwise GtkApplication exits
	C.g_application_hold(app)
	setup(mut ad)

	display := C.gdk_display_get_default()
	C.g_signal_connect_data(display, c'monitor-added', voidptr(on_monitor_changed), data,
		unsafe { nil }, 0)
	C.g_signal_connect_data(display, c'monitor-removed', voidptr(on_monitor_changed), data,
		unsafe { nil }, 0)
}

fn watch_config(dir string, data voidptr) {
	fd := C.inotify_init1(inotify.in_cloexec)
	if fd < 0 {
		eprintln('vbar: inotify_init1 failed')
		return
	}
	wd := C.inotify_add_watch(fd, dir.str,
		inotify.in_close_write | inotify.in_moved_to | inotify.in_create)
	if wd < 0 {
		eprintln('vbar: inotify_add_watch failed for ${dir}')
		C.close(fd)
		return
	}

	buf := []u8{len: 4096}
	mut pending := false
	for {
		mut rs := C.fd_set{}
		C.FD_ZERO(&rs)
		C.FD_SET(fd, &rs)
		mut tv := C.timeval{
			tv_sec:  0
			tv_usec: 200000
		}
		n := C.select(fd + 1, &rs, unsafe { nil }, unsafe { nil }, &tv)
		if n > 0 && C.FD_ISSET(fd, &rs) != 0 {
			C.read(fd, buf.data, usize(buf.len))
			pending = true
		} else if n == 0 && pending {
			C.g_idle_add(voidptr(do_reload), data)
			pending = false
		}
	}
}

fn main() {
	if os.args.len < 2 {
		eprintln('usage: vbar daemon | update <name>=<value> | get <name> | state')
		exit(1)
	}
	match os.args[1] {
		'daemon' {}
		'update', 'get', 'state' {
			ipc.run_client(os.args[1..]) or {
				eprintln('vbar: ${err}')
				exit(1)
			}
			return
		}
		else {
			eprintln('vbar: unknown command: ${os.args[1]}')
			eprintln('usage: vbar daemon | update <name>=<value> | get <name> | state')
			exit(1)
		}
	}

	config, lua_state := load_config()
	mut lua_rt := unsafe { &cmd.LuaRuntime(nil) }
	if lua_state != unsafe { nil } {
		lua_rt = cmd.new_runtime(lua_state)
	}
	store := &vars.VarStore{}
	gen := &vars.Generation{}

	mut ad := &AppData{
		config: config
		store:  store
		gen:    gen
		lua_rt: lua_rt
	}

	spawn watch_config(config_dir(), voidptr(ad))
	spawn ipc.serve(store, ipc_set_var, voidptr(store))

	app := C.gtk_application_new(c'io.vbar', 0)
	C.g_signal_connect_data(app, c'activate', voidptr(on_activate), voidptr(ad), unsafe { nil }, 0)
	status := C.g_application_run(app, 0, unsafe { nil })
	C.g_object_unref(app)
	exit(status)
}
