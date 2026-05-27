module systray

import lib.gio
import lib.gtk
import os

#pkgconfig cairo
#include "systray_helper.h"

fn C.vbar_get_watcher_interface() voidptr
fn C.vbar_systray_vtable() voidptr
fn C.vbar_v_s_tuple(s &char) voidptr
fn C.vbar_v_su_tuple(s &char, u u32) voidptr
fn C.vbar_v_ss_tuple(s1 &char, s2 &char) voidptr
fn C.vbar_v_ii_tuple(x i32, y i32) voidptr
fn C.vbar_parse_icon_pixmap(pixmap_v voidptr, target_size int) voidptr
fn C.vbar_png_via_cairo(path &char, target_size int) voidptr
fn C.vbar_sni_get() voidptr
fn C.vbar_sni_set(p voidptr)

struct SystrayClickState {
	conn    voidptr
	service string
	path    string
}

struct SystrayItem {
mut:
	service    string
	obj_path   string
	button     voidptr
	click_data &SystrayClickState = unsafe { nil }
}

struct SystrayState {
mut:
	box_widget voidptr
	conn       voidptr
	items      map[string]SystrayItem
	icon_size  int
}

fn get_state() &SystrayState {
	return unsafe { &SystrayState(C.vbar_sni_get()) }
}

// parse_sni_service splits "service /path" or returns default path "/StatusNotifierItem".
fn parse_sni_service(svc_str string) (string, string) {
	idx := svc_str.index(' ') or { return svc_str, '/StatusNotifierItem' }
	return svc_str[..idx], svc_str[idx + 1..]
}

// find_icon_file searches hicolor theme directories for a non-SVG file matching name.
// Bypasses GTK's icon theme loader entirely to avoid the broken bwrap SVG loader.
fn find_icon_file(name string, icon_size int) string {
	home := os.home_dir()
	base_dirs := ['${home}/.local/share/icons', '/usr/local/share/icons', '/usr/share/icons']
	size_dirs := ['${icon_size}x${icon_size}', '48x48', '32x32', '24x24', '22x22', '256x256']
	categories := ['apps', 'status', 'devices', 'actions']
	exts := ['png', 'xpm']
	for dir in base_dirs {
		for sz in size_dirs {
			for cat in categories {
				for ext in exts {
					path := '${dir}/hicolor/${sz}/${cat}/${name}.${ext}'
					if os.exists(path) {
						return path
					}
				}
			}
		}
	}
	for ext in exts {
		path := '/usr/share/pixmaps/${name}.${ext}'
		if os.exists(path) {
			return path
		}
	}
	return ''
}

// create_icon tries IconName then IconPixmap from a GetAll reply dict.
fn create_icon(dict voidptr, icon_size int) &C.GtkWidget {
	icon_name_v := C.g_variant_lookup_value(dict, c'IconName', unsafe { nil })
	if icon_name_v != unsafe { nil } {
		raw := C.g_variant_get_string(icon_name_v, unsafe { nil })
		name := unsafe { cstring_to_vstring(raw) }
		C.g_variant_unref(icon_name_v)
		if name != '' {
			path := find_icon_file(name, icon_size)
			if path != '' {
				// Use Cairo's libpng directly — bypasses broken GDK pixbuf file loaders.
				pb := C.vbar_png_via_cairo(path.str, icon_size)
				if pb != unsafe { nil } {
					img := C.gtk_image_new_from_pixbuf(pb)
					C.g_object_unref(pb)
					return img
				}
			}
		}
	}

	pixmap_v := C.g_variant_lookup_value(dict, c'IconPixmap', unsafe { nil })
	if pixmap_v != unsafe { nil } {
		pb := C.vbar_parse_icon_pixmap(pixmap_v, icon_size)
		C.g_variant_unref(pixmap_v)
		if pb != unsafe { nil } {
			img := C.gtk_image_new_from_pixbuf(pb)
			C.g_object_unref(pb)
			return img
		}
	}
	return unsafe { nil }
}

// on_systray_button handles mouse clicks on tray item event boxes.
fn on_systray_button(widget voidptr, event voidptr, data voidptr) int {
	cs := unsafe { &SystrayClickState(data) }
	ev := unsafe { &C.GdkEventButton(event) }
	method := if ev.button == 3 { c'ContextMenu' } else { c'Activate' }
	C.g_dbus_connection_call_sync(cs.conn, cs.service.str, cs.path.str,
		c'org.kde.StatusNotifierItem', method, C.vbar_v_ii_tuple(0, 0), unsafe { nil },
		gio.g_dbus_call_flags_none, 1000, unsafe { nil }, unsafe { nil })
	return 1
}

// make_item_button fetches SNI properties and builds an EventBox with the icon inside.
fn make_item_button(conn voidptr, service string, obj_path string, icon_size int) (voidptr, &SystrayClickState) {
	reply := C.g_dbus_connection_call_sync(conn, service.str, obj_path.str,
		c'org.freedesktop.DBus.Properties', c'GetAll',
		C.vbar_v_s_tuple(c'org.kde.StatusNotifierItem'), unsafe { nil },
		gio.g_dbus_call_flags_none, 3000, unsafe { nil }, unsafe { nil })
	if reply == unsafe { nil } {
		return unsafe { nil }, unsafe { nil }
	}

	dict := C.g_variant_get_child_value(reply, 0)
	icon_img := create_icon(dict, icon_size)
	C.g_variant_unref(dict)
	C.g_variant_unref(reply)

	if icon_img == unsafe { nil } {
		return unsafe { nil }, unsafe { nil }
	}

	eb := C.gtk_event_box_new()
	C.gtk_container_add(unsafe { &C.GtkWidget(eb) }, icon_img)
	C.gtk_widget_set_name(unsafe { &C.GtkWidget(eb) }, c'systray-item')
	C.gtk_widget_add_events(unsafe { &C.GtkWidget(eb) }, gtk.gdk_button_press_mask)

	cs := &SystrayClickState{
		conn:    conn
		service: service
		path:    obj_path
	}
	C.g_signal_connect_data(eb, c'button-press-event', voidptr(on_systray_button), voidptr(cs),
		unsafe { nil }, 0)
	return eb, cs
}

// add_item records a new tray item and (if a box exists) creates its button immediately.
fn add_item(conn voidptr, service string, obj_path string) {
	state := get_state()
	if service in state.items {
		return
	}

	mut btn := unsafe { nil }
	mut cs := unsafe { &SystrayClickState(nil) }
	if state.box_widget != unsafe { nil } {
		btn, cs = make_item_button(conn, service, obj_path, state.icon_size)
		if btn != unsafe { nil } {
			C.gtk_box_pack_start(unsafe { &C.GtkWidget(state.box_widget) },
				unsafe { &C.GtkWidget(btn) }, 0, 0, 0)
			C.gtk_widget_show_all(unsafe { &C.GtkWidget(btn) })
		}
	}

	unsafe {
		mut st := state
		st.items[service] = SystrayItem{
			service:    service
			obj_path:   obj_path
			button:     btn
			click_data: cs
		}
	}
}

// remove_item removes a tray item and destroys its button.
fn remove_item(service string) {
	state := get_state()
	item := state.items[service] or { return }
	if item.button != unsafe { nil } {
		C.gtk_widget_destroy(unsafe { &C.GtkWidget(item.button) })
	}
	unsafe {
		mut st := state
		st.items.delete(service)
	}
}

// --- Exported GDBus callbacks ---

// vbar_systray_method_call handles RegisterStatusNotifierItem / RegisterStatusNotifierHost.
@[export: 'vbar_systray_method_call']
fn vbar_systray_method_call(conn voidptr, sender &char, obj_path &char, iface &char, method &char, params voidptr, invocation voidptr, data voidptr) {
	method_str := unsafe { cstring_to_vstring(method) }
	if method_str == 'RegisterStatusNotifierItem' {
		arg := C.g_variant_get_child_value(params, 0)
		raw := C.g_variant_get_string(arg, unsafe { nil })
		svc_str := unsafe { cstring_to_vstring(raw) }
		C.g_variant_unref(arg)

		sender_str := unsafe { cstring_to_vstring(sender) }
		mut service, mut path := parse_sni_service(svc_str)
		if svc_str.starts_with('/') {
			service = sender_str
			path = svc_str
		}

		// Emit StatusNotifierItemRegistered signal
		sig_params := C.vbar_v_s_tuple(service.str)
		C.g_dbus_connection_emit_signal(conn, unsafe { nil }, c'/StatusNotifierWatcher',
			c'org.kde.StatusNotifierWatcher', c'StatusNotifierItemRegistered', sig_params,
			unsafe { nil })

		add_item(conn, service, path)
	}
	C.g_dbus_method_invocation_return_value(invocation, unsafe { nil })
}

// vbar_systray_get_property services the watcher's D-Bus properties.
@[export: 'vbar_systray_get_property']
fn vbar_systray_get_property(conn voidptr, sender &char, obj_path &char, iface &char, prop &char, error_ voidptr, data voidptr) voidptr {
	prop_str := unsafe { cstring_to_vstring(prop) }
	state := get_state()
	match prop_str {
		'RegisteredStatusNotifierItems' {
			keys := state.items.keys()
			if keys.len == 0 {
				empty := &&char(unsafe { nil })
				return C.g_variant_new_strv(voidptr(empty), 0)
			}
			mut ptrs := []&char{}
			for k in keys {
				ptrs << k.str
			}
			return C.g_variant_new_strv(voidptr(ptrs.data), i64(keys.len))
		}
		'IsStatusNotifierHostRegistered' {
			return C.g_variant_new_boolean(1)
		}
		'ProtocolVersion' {
			return C.g_variant_new_int32(0)
		}
		else {}
	}

	return unsafe { nil }
}

// vbar_systray_name_owner_changed removes items whose D-Bus service disappeared.
@[export: 'vbar_systray_name_owner_changed']
fn vbar_systray_name_owner_changed(conn voidptr, sender &char, obj_path &char, iface &char, signal &char, params voidptr, data voidptr) {
	name_v := C.g_variant_get_child_value(params, 0)
	new_owner_v := C.g_variant_get_child_value(params, 2)
	name_raw := C.g_variant_get_string(name_v, unsafe { nil })
	new_owner_raw := C.g_variant_get_string(new_owner_v, unsafe { nil })
	name := unsafe { cstring_to_vstring(name_raw) }
	new_owner := unsafe { cstring_to_vstring(new_owner_raw) }
	C.g_variant_unref(name_v)
	C.g_variant_unref(new_owner_v)

	if new_owner == '' {
		remove_item(name)
	}
}

// vbar_systray_item_registered handles StatusNotifierItemRegistered from an external watcher.
@[export: 'vbar_systray_item_registered']
fn vbar_systray_item_registered(conn voidptr, sender &char, obj_path &char, iface &char, signal &char, params voidptr, data voidptr) {
	arg := C.g_variant_get_child_value(params, 0)
	raw := C.g_variant_get_string(arg, unsafe { nil })
	svc_str := unsafe { cstring_to_vstring(raw) }
	C.g_variant_unref(arg)
	service, path := parse_sni_service(svc_str)
	add_item(conn, service, path)
}

// vbar_systray_item_unregistered handles StatusNotifierItemUnregistered from an external watcher.
@[export: 'vbar_systray_item_unregistered']
fn vbar_systray_item_unregistered(conn voidptr, sender &char, obj_path &char, iface &char, signal &char, params voidptr, data voidptr) {
	arg := C.g_variant_get_child_value(params, 0)
	raw := C.g_variant_get_string(arg, unsafe { nil })
	svc_str := unsafe { cstring_to_vstring(raw) }
	C.g_variant_unref(arg)
	service, _ := parse_sni_service(svc_str)
	remove_item(service)
}

// init_dbus connects to the session bus, tries to own StatusNotifierWatcher,
// falls back to host-only mode if another watcher is running.
fn init_dbus(icon_size int) {
	conn := C.g_bus_get_sync(gio.g_bus_type_session, unsafe { nil }, unsafe { nil })
	if conn == unsafe { nil } {
		eprintln('vbar systray: cannot connect to session bus')
		return
	}

	state := &SystrayState{
		conn:      conn
		icon_size: icon_size
	}
	C.vbar_sni_set(voidptr(state))

	// Try to own org.kde.StatusNotifierWatcher
	reply := C.g_dbus_connection_call_sync(conn, c'org.freedesktop.DBus', c'/org/freedesktop/DBus',
		c'org.freedesktop.DBus', c'RequestName', C.vbar_v_su_tuple(c'org.kde.StatusNotifierWatcher',
		u32(0)), unsafe { nil }, gio.g_dbus_call_flags_none, 5000, unsafe { nil }, unsafe { nil })

	if reply == unsafe { nil } {
		eprintln('vbar systray: RequestName failed')
		return
	}

	result_v := C.g_variant_get_child_value(reply, 0)
	result := C.g_variant_get_uint32(result_v)
	C.g_variant_unref(result_v)
	C.g_variant_unref(reply)

	if result == 1 || result == 4 {
		// We own the name — register the watcher object
		iface := C.vbar_get_watcher_interface()
		vtable := C.vbar_systray_vtable()
		C.g_dbus_connection_register_object(conn, c'/StatusNotifierWatcher', iface, vtable,
			voidptr(state), unsafe { nil }, unsafe { nil })

		// Watch for service disappearances
		C.g_dbus_connection_signal_subscribe(conn, unsafe { nil }, c'org.freedesktop.DBus',
			c'NameOwnerChanged', c'/org/freedesktop/DBus', unsafe { nil },
			gio.g_dbus_signal_flags_none, voidptr(vbar_systray_name_owner_changed), voidptr(state),
			unsafe { nil })
	} else {
		// Another watcher is running — connect as host
		C.g_dbus_connection_signal_subscribe(conn, unsafe { nil },
			c'org.kde.StatusNotifierWatcher', c'StatusNotifierItemRegistered',
			c'/StatusNotifierWatcher', unsafe { nil }, gio.g_dbus_signal_flags_none,
			voidptr(vbar_systray_item_registered), voidptr(state), unsafe { nil })

		C.g_dbus_connection_signal_subscribe(conn, unsafe { nil },
			c'org.kde.StatusNotifierWatcher', c'StatusNotifierItemUnregistered',
			c'/StatusNotifierWatcher', unsafe { nil }, gio.g_dbus_signal_flags_none,
			voidptr(vbar_systray_item_unregistered), voidptr(state), unsafe { nil })

		// Register ourselves as a host
		unique_name := C.g_dbus_connection_get_unique_name(conn)
		C.g_dbus_connection_call_sync(conn, c'org.kde.StatusNotifierWatcher',
			c'/StatusNotifierWatcher', c'org.kde.StatusNotifierWatcher',
			c'RegisterStatusNotifierHost', C.vbar_v_s_tuple(unique_name), unsafe { nil },
			gio.g_dbus_call_flags_none, 1000, unsafe { nil }, unsafe { nil })

		// Fetch already-registered items
		items_reply := C.g_dbus_connection_call_sync(conn, c'org.kde.StatusNotifierWatcher',
			c'/StatusNotifierWatcher', c'org.freedesktop.DBus.Properties', c'Get', C.vbar_v_ss_tuple(c'org.kde.StatusNotifierWatcher',
			c'RegisteredStatusNotifierItems'), unsafe { nil }, gio.g_dbus_call_flags_none, 2000,
			unsafe { nil }, unsafe { nil })

		if items_reply != unsafe { nil } {
			outer := C.g_variant_get_child_value(items_reply, 0)
			inner := C.g_variant_get_child_value(outer, 0)
			n := C.g_variant_n_children(inner)
			for i in 0 .. usize(n) {
				item_v := C.g_variant_get_child_value(inner, i)
				raw := C.g_variant_get_string(item_v, unsafe { nil })
				svc_str := unsafe { cstring_to_vstring(raw) }
				C.g_variant_unref(item_v)
				service, path := parse_sni_service(svc_str)
				add_item(conn, service, path)
			}
			C.g_variant_unref(inner)
			C.g_variant_unref(outer)
			C.g_variant_unref(items_reply)
		}
	}
}

// make_widget creates the systray horizontal box, initialising D-Bus on first call.
pub fn make_widget(icon_size int) &C.GtkWidget {
	if C.vbar_sni_get() == unsafe { nil } {
		init_dbus(icon_size)
	}

	box := C.gtk_box_new(gtk.gtk_orientation_horizontal, 0)
	C.gtk_widget_set_name(unsafe { &C.GtkWidget(box) }, c'systray')

	state := get_state()
	if state == unsafe { nil } {
		return unsafe { &C.GtkWidget(box) }
	}

	nil_cs := unsafe { &SystrayClickState(nil) }
	unsafe {
		mut st := state
		st.box_widget = box
		st.icon_size = icon_size
		// Invalidate stale button pointers from the previous GTK window (reload case)
		for svc in st.items.keys() {
			mut it := st.items[svc]
			it.button = nil
			it.click_data = nil_cs
			st.items[svc] = it
		}
	}
	// Recreate buttons for all known items (covers both first call and reload)
	for svc, _ in state.items {
		item := state.items[svc] or { continue }
		btn, cs := make_item_button(state.conn, svc, item.obj_path, state.icon_size)
		unsafe {
			mut st := state
			mut it := st.items[svc]
			it.button = btn
			it.click_data = cs
			st.items[svc] = it
		}
		if btn != unsafe { nil } {
			C.gtk_box_pack_start(unsafe { &C.GtkWidget(box) }, unsafe { &C.GtkWidget(btn) }, 0, 0,
				0)
			C.gtk_widget_show_all(unsafe { &C.GtkWidget(btn) })
		}
	}

	return unsafe { &C.GtkWidget(box) }
}
