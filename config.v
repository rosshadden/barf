module main

import lib.lua
import os

struct WidgetDesc {
	kind         string
	active_color string = '#89b4fa'
	text         string
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

struct PollDesc {
	name     string
	command  string
	interval int = 1
	shell    []string
}

struct BuiltinDesc {
	kind     string
	interval int = 2
}

struct Config {
	bars     []BarDesc
	polls    []PollDesc
	builtins []BuiltinDesc
	shell    []string
}

struct ContentData {
	left   []WidgetDesc
	center []WidgetDesc
	right  []WidgetDesc
	store  voidptr
}

struct ConfigAccum {
mut:
	bars     []BarDesc
	polls    []PollDesc
	builtins []BuiltinDesc
	shell    []string
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
			text := read_string_field(l, widget_tbl, c'text', '')
			if kind != '' {
				result << WidgetDesc{
					kind:         kind
					active_color: active_color
					text:         text
				}
			}
		}
		lua.lua_pop(l, 1)
	}
	lua.lua_pop(l, 1)
	return result
}

fn get_config_accum(l &C.lua_State) &ConfigAccum {
	C.lua_getfield(l, lua.lua_registryindex, c'vbar.config')
	ptr := C.lua_touserdata(l, -1)
	lua.lua_pop(l, 1)
	return unsafe { &ConfigAccum(ptr) }
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
	mut accum := get_config_accum(l)
	accum.bars << desc
	return 0
}

fn lua_label_fn(l &C.lua_State) int {
	if C.lua_type(l, 1) != lua.lua_tstring {
		C.luaL_error(l, c'vbar.label: expected string template')
		return 0
	}
	raw := C.lua_tolstring(l, 1, unsafe { nil })
	text := unsafe { cstring_to_vstring(raw) }
	C.lua_createtable(l, 0, 2)
	C.lua_pushstring(l, c'label')
	C.lua_setfield(l, -2, c'type')
	C.lua_pushstring(l, text.str)
	C.lua_setfield(l, -2, c'text')
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

fn lua_poll_fn(l &C.lua_State) int {
	if C.lua_type(l, 1) != lua.lua_tstring || C.lua_type(l, 2) != lua.lua_ttable {
		C.luaL_error(l, c'vbar.poll: expected (name, {command, interval})')
		return 0
	}
	raw_name := C.lua_tolstring(l, 1, unsafe { nil })
	name := unsafe { cstring_to_vstring(raw_name) }
	command := read_string_field(l, 2, c'command', '')
	interval := read_int_field(l, 2, c'interval', 1)
	shell := read_string_array_field(l, 2, c'shell')
	if name == '' || command == '' {
		C.luaL_error(l, c'vbar.poll: name and command required')
		return 0
	}
	mut accum := get_config_accum(l)
	accum.polls << PollDesc{
		name:     name
		command:  command
		interval: interval
		shell:    shell
	}
	return 0
}

fn lua_shell_fn(l &C.lua_State) int {
	if C.lua_type(l, 1) != lua.lua_ttable {
		C.luaL_error(l, c'vbar.shell: expected table (e.g. {"bash", "-c"})')
		return 0
	}
	n := int(C.lua_rawlen(l, 1))
	if n == 0 {
		C.luaL_error(l, c'vbar.shell: table must not be empty')
		return 0
	}
	mut shell := []string{}
	for i := 1; i <= n; i++ {
		C.lua_rawgeti(l, 1, i64(i))
		if C.lua_type(l, -1) == lua.lua_tstring {
			raw := C.lua_tolstring(l, -1, unsafe { nil })
			shell << unsafe { cstring_to_vstring(raw) }
		}
		lua.lua_pop(l, 1)
	}
	mut accum := get_config_accum(l)
	accum.shell = shell
	return 0
}

fn lua_cpu_fn(l &C.lua_State) int {
	interval := if C.lua_type(l, 1) == lua.lua_ttable {
		read_int_field(l, 1, c'interval', 2)
	} else {
		2
	}
	mut accum := get_config_accum(l)
	accum.builtins << BuiltinDesc{
		kind:     'cpu'
		interval: interval
	}
	return 0
}

fn lua_ram_fn(l &C.lua_State) int {
	interval := if C.lua_type(l, 1) == lua.lua_ttable {
		read_int_field(l, 1, c'interval', 2)
	} else {
		2
	}
	mut accum := get_config_accum(l)
	accum.builtins << BuiltinDesc{
		kind:     'ram'
		interval: interval
	}
	return 0
}

fn open_vbar_module(l &C.lua_State) int {
	C.lua_createtable(l, 0, 7)

	C.lua_pushcclosure(l, voidptr(lua_bar_fn), 0)
	C.lua_setfield(l, -2, c'bar')

	C.lua_pushcclosure(l, voidptr(lua_label_fn), 0)
	C.lua_setfield(l, -2, c'label')

	C.lua_pushcclosure(l, voidptr(lua_workspaces_fn), 0)
	C.lua_setfield(l, -2, c'workspaces')

	C.lua_pushcclosure(l, voidptr(lua_poll_fn), 0)
	C.lua_setfield(l, -2, c'poll')

	C.lua_pushcclosure(l, voidptr(lua_cpu_fn), 0)
	C.lua_setfield(l, -2, c'cpu')

	C.lua_pushcclosure(l, voidptr(lua_ram_fn), 0)
	C.lua_setfield(l, -2, c'ram')

	C.lua_pushcclosure(l, voidptr(lua_shell_fn), 0)
	C.lua_setfield(l, -2, c'shell')

	return 1
}

fn load_config() Config {
	xdg := os.getenv('XDG_CONFIG_HOME')
	config_dir := if xdg != '' { xdg } else { os.join_path(os.home_dir(), '.config') }
	config_path := os.join_path(config_dir, 'vbar', 'init.lua')

	if !os.exists(config_path) {
		return default_config()
	}

	l := C.luaL_newstate()
	if l == unsafe { nil } {
		eprintln('vbar: failed to create Lua state')
		return default_config()
	}
	defer {
		C.lua_close(l)
	}

	C.luaL_openlibs(l)

	mut accum := ConfigAccum{}
	C.lua_pushlightuserdata(l, voidptr(&accum))
	C.lua_setfield(l, lua.lua_registryindex, c'vbar.config')

	C.luaL_requiref(l, c'vbar', voidptr(open_vbar_module), 0)
	lua.lua_pop(l, 1)

	load_status := C.luaL_loadfilex(l, config_path.str, unsafe { nil })
	if load_status != lua.lua_ok {
		raw := C.lua_tolstring(l, -1, unsafe { nil })
		err := unsafe { cstring_to_vstring(raw) }
		eprintln('vbar: config syntax error: ${err}')
		return default_config()
	}

	call_status := C.lua_pcallk(l, 0, lua.lua_multret, 0, 0, unsafe { nil })
	if call_status != lua.lua_ok {
		raw := C.lua_tolstring(l, -1, unsafe { nil })
		err := unsafe { cstring_to_vstring(raw) }
		eprintln('vbar: config runtime error: ${err}')
		return default_config()
	}

	return Config{
		bars:     accum.bars
		polls:    accum.polls
		builtins: accum.builtins
		shell:    accum.shell
	}
}

fn default_config() Config {
	return Config{
		bars: [
			BarDesc{
				left:   [WidgetDesc{
					kind: 'workspaces'
				}]
				center: [WidgetDesc{
					kind: 'label'
					text: '\x24{time}'
				}]
			},
		]
	}
}
