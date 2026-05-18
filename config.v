module main

import lib.lua
import os

struct WidgetDesc {
	kind         string
	active_color string = '#89b4fa'
}

struct BarDesc {
	height      int      = 30
	font_family string   = 'monospace'
	font_size   string   = '12pt'
	bg_color    string   = '#1e1e2e'
	fg_color    string   = '#cdd6f4'
	anchors     []string = ['left', 'right', 'top']
	monitors    []string
	left        []WidgetDesc
	center      []WidgetDesc
	right       []WidgetDesc
}

struct ContentData {
	left   []WidgetDesc
	center []WidgetDesc
	right  []WidgetDesc
}

struct BarDescsAccum {
mut:
	descs []BarDesc
}

fn read_string_field(l &C.lua_State, tbl_idx int, key &char, default_ string) string {
	t := C.lua_getfield(l, tbl_idx, key)
	if t == lua.lua_tstring {
		raw := C.lua_tolstring(l, -1, unsafe { nil })
		s := unsafe { cstring_to_vstring(raw) }
		lua.lua_pop(l, 1)
		return s
	}
	lua.lua_pop(l, 1)
	return default_
}

fn read_int_field(l &C.lua_State, tbl_idx int, key &char, default_ int) int {
	t := C.lua_getfield(l, tbl_idx, key)
	if t == lua.lua_tnumber {
		v := int(C.lua_tointegerx(l, -1, unsafe { nil }))
		lua.lua_pop(l, 1)
		return v
	}
	lua.lua_pop(l, 1)
	return default_
}

fn read_string_array_field(l &C.lua_State, tbl_idx int, key &char) []string {
	mut result := []string{}
	t := C.lua_getfield(l, tbl_idx, key)
	if t != lua.lua_ttable {
		lua.lua_pop(l, 1)
		return result
	}
	arr_idx := C.lua_gettop(l)
	n := int(C.lua_rawlen(l, arr_idx))
	for i := 1; i <= n; i++ {
		C.lua_rawgeti(l, arr_idx, i64(i))
		if C.lua_type(l, -1) == lua.lua_tstring {
			raw := C.lua_tolstring(l, -1, unsafe { nil })
			result << unsafe { cstring_to_vstring(raw) }
		}
		lua.lua_pop(l, 1)
	}
	lua.lua_pop(l, 1)
	return result
}

fn read_widget_list(l &C.lua_State, tbl_idx int, key &char) []WidgetDesc {
	mut result := []WidgetDesc{}
	t := C.lua_getfield(l, tbl_idx, key)
	if t != lua.lua_ttable {
		lua.lua_pop(l, 1)
		return result
	}
	arr_idx := C.lua_gettop(l)
	n := int(C.lua_rawlen(l, arr_idx))
	for i := 1; i <= n; i++ {
		C.lua_rawgeti(l, arr_idx, i64(i))
		if C.lua_type(l, -1) == lua.lua_ttable {
			widget_tbl := C.lua_gettop(l)
			kind := read_string_field(l, widget_tbl, c'type', '')
			active_color := read_string_field(l, widget_tbl, c'active_color', '#89b4fa')
			if kind != '' {
				result << WidgetDesc{
					kind:         kind
					active_color: active_color
				}
			}
		}
		lua.lua_pop(l, 1)
	}
	lua.lua_pop(l, 1)
	return result
}

fn get_bar_descs_accum(l &C.lua_State) &BarDescsAccum {
	C.lua_getfield(l, lua.lua_registryindex, c'vbar.bar_descs')
	ptr := C.lua_touserdata(l, -1)
	lua.lua_pop(l, 1)
	return unsafe { &BarDescsAccum(ptr) }
}

fn lua_bar_fn(l &C.lua_State) int {
	if C.lua_type(l, 1) != lua.lua_ttable {
		C.luaL_error(l, c'vbar.bar: expected table argument')
		return 0
	}
	desc := BarDesc{
		height:      read_int_field(l, 1, c'height', 30)
		font_family: read_string_field(l, 1, c'font_family', 'monospace')
		font_size:   read_string_field(l, 1, c'font_size', '12pt')
		bg_color:    read_string_field(l, 1, c'bg_color', '#1e1e2e')
		fg_color:    read_string_field(l, 1, c'fg_color', '#cdd6f4')
		anchors:     read_string_array_field(l, 1, c'anchors')
		monitors:    read_string_array_field(l, 1, c'monitors')
		left:        read_widget_list(l, 1, c'left')
		center:      read_widget_list(l, 1, c'center')
		right:       read_widget_list(l, 1, c'right')
	}
	mut accum := get_bar_descs_accum(l)
	accum.descs << desc
	return 0
}

fn lua_clock_fn(l &C.lua_State) int {
	C.lua_createtable(l, 0, 1)
	C.lua_pushstring(l, c'clock')
	C.lua_setfield(l, -2, c'type')
	return 1
}

fn lua_memory_fn(l &C.lua_State) int {
	C.lua_createtable(l, 0, 1)
	C.lua_pushstring(l, c'memory')
	C.lua_setfield(l, -2, c'type')
	return 1
}

fn lua_workspaces_fn(l &C.lua_State) int {
	nargs := C.lua_gettop(l)
	C.lua_createtable(l, 0, 2)
	C.lua_pushstring(l, c'workspaces')
	C.lua_setfield(l, -2, c'type')

	if nargs >= 1 && C.lua_type(l, 1) == lua.lua_ttable {
		t := C.lua_getfield(l, 1, c'active_color')
		if t == lua.lua_tstring {
			C.lua_setfield(l, -2, c'active_color')
		} else {
			lua.lua_pop(l, 1)
			C.lua_pushstring(l, c'#89b4fa')
			C.lua_setfield(l, -2, c'active_color')
		}
	} else {
		C.lua_pushstring(l, c'#89b4fa')
		C.lua_setfield(l, -2, c'active_color')
	}
	return 1
}

fn open_vbar_module(l &C.lua_State) int {
	C.lua_createtable(l, 0, 4)

	C.lua_pushcclosure(l, voidptr(lua_bar_fn), 0)
	C.lua_setfield(l, -2, c'bar')

	C.lua_pushcclosure(l, voidptr(lua_clock_fn), 0)
	C.lua_setfield(l, -2, c'clock')

	C.lua_pushcclosure(l, voidptr(lua_memory_fn), 0)
	C.lua_setfield(l, -2, c'memory')

	C.lua_pushcclosure(l, voidptr(lua_workspaces_fn), 0)
	C.lua_setfield(l, -2, c'workspaces')

	return 1
}

fn load_config() []BarDesc {
	xdg := os.getenv('XDG_CONFIG_HOME')
	config_dir := if xdg != '' { xdg } else { os.join_path(os.home_dir(), '.config') }
	config_path := os.join_path(config_dir, 'vbar', 'init.lua')

	if !os.exists(config_path) {
		return default_bar_descs()
	}

	l := C.luaL_newstate()
	if l == unsafe { nil } {
		eprintln('vbar: failed to create Lua state')
		return default_bar_descs()
	}
	defer {
		C.lua_close(l)
	}

	C.luaL_openlibs(l)

	mut accum := BarDescsAccum{}
	C.lua_pushlightuserdata(l, voidptr(&accum))
	C.lua_setfield(l, lua.lua_registryindex, c'vbar.bar_descs')

	C.luaL_requiref(l, c'vbar', voidptr(open_vbar_module), 0)
	lua.lua_pop(l, 1)

	load_status := C.luaL_loadfilex(l, config_path.str, unsafe { nil })
	if load_status != lua.lua_ok {
		raw := C.lua_tolstring(l, -1, unsafe { nil })
		err := unsafe { cstring_to_vstring(raw) }
		eprintln('vbar: config syntax error: ${err}')
		return default_bar_descs()
	}

	call_status := C.lua_pcallk(l, 0, lua.lua_multret, 0, 0, unsafe { nil })
	if call_status != lua.lua_ok {
		raw := C.lua_tolstring(l, -1, unsafe { nil })
		err := unsafe { cstring_to_vstring(raw) }
		eprintln('vbar: config runtime error: ${err}')
		return default_bar_descs()
	}

	return accum.descs
}

fn default_bar_descs() []BarDesc {
	return [
		BarDesc{
			left:   [WidgetDesc{
				kind: 'workspaces'
			}]
			center: [WidgetDesc{
				kind: 'clock'
			}]
		},
	]
}
