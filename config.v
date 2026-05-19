module main

import lib.lua
import os

struct WidgetDesc {
	kind            string
	active_color    string = '#89b4fa'
	text            string
	on_click        string
	on_right_click  string
	on_middle_click string
}

struct BarDesc {
	height      int = 30
	font_family string
	font_size   string
	bg_color    string
	fg_color    string
	anchors     []string = ['left', 'right', 'top']
	monitors    []string
	on_scroll   string
	on_click    string
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
	font_family string = 'monospace'
	font_size   string = '12pt'
	bg_color    string = '#1e1e2e'
	fg_color    string = '#cdd6f4'
	bars        []BarDesc
	polls       []PollDesc
	builtins    []BuiltinDesc
	shell       []string
}

struct ContentData {
	left   []WidgetDesc
	center []WidgetDesc
	right  []WidgetDesc
	store  voidptr
	shell  []string
}

struct ConfigAccum {
mut:
	font_family string
	font_size   string
	bg_color    string
	fg_color    string
	bars        []BarDesc
	polls       []PollDesc
	builtins    []BuiltinDesc
	shell       []string
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
			on_click := read_string_field(l, widget_tbl, c'on_click', '')
			on_right_click := read_string_field(l, widget_tbl, c'on_right_click', '')
			on_middle_click := read_string_field(l, widget_tbl, c'on_middle_click', '')
			if kind != '' {
				result << WidgetDesc{
					kind:            kind
					active_color:    active_color
					text:            text
					on_click:        on_click
					on_right_click:  on_right_click
					on_middle_click: on_middle_click
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
		font_family: read_string_field(l, 1, c'font_family', '')
		font_size:   read_string_field(l, 1, c'font_size', '')
		bg_color:    read_string_field(l, 1, c'bg_color', '')
		fg_color:    read_string_field(l, 1, c'fg_color', '')
		anchors:     read_string_array_field(l, 1, c'anchors')
		monitors:    read_string_array_field(l, 1, c'monitors')
		on_scroll:   read_string_field(l, 1, c'on_scroll', '')
		on_click:    read_string_field(l, 1, c'on_click', '')
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
	C.lua_createtable(l, 0, 5)
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

		for field in [c'on_click', c'on_right_click', c'on_middle_click'] {
			ft := C.lua_getfield(l, 1, field)
			if ft == lua.lua_tstring {
				C.lua_setfield(l, -2, field)
			} else {
				lua.lua_pop(l, 1)
			}
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

fn lua_setup_fn(l &C.lua_State) int {
	if C.lua_type(l, 1) != lua.lua_ttable {
		C.luaL_error(l, c'vbar.setup: expected table argument')
		return 0
	}
	mut accum := get_config_accum(l)
	shell := read_string_array_field(l, 1, c'shell')
	if shell.len > 0 {
		accum.shell = shell
	}
	font_family := read_string_field(l, 1, c'font_family', '')
	if font_family != '' {
		accum.font_family = font_family
	}
	font_size := read_string_field(l, 1, c'font_size', '')
	if font_size != '' {
		accum.font_size = font_size
	}
	bg_color := read_string_field(l, 1, c'bg_color', '')
	if bg_color != '' {
		accum.bg_color = bg_color
	}
	fg_color := read_string_field(l, 1, c'fg_color', '')
	if fg_color != '' {
		accum.fg_color = fg_color
	}
	t := C.lua_getfield(l, 1, c'providers')
	if t == lua.lua_ttable {
		providers_idx := C.lua_gettop(l)
		C.lua_pushnil(l)
		for C.lua_next(l, providers_idx) != 0 {
			if C.lua_type(l, -2) == lua.lua_tstring {
				raw := C.lua_tolstring(l, -2, unsafe { nil })
				kind := unsafe { cstring_to_vstring(raw) }
				interval := if C.lua_type(l, -1) == lua.lua_ttable {
					read_int_field(l, C.lua_gettop(l), c'interval', 2)
				} else {
					2
				}
				accum.builtins << BuiltinDesc{
					kind:     kind
					interval: interval
				}
			}
			lua.lua_pop(l, 1)
		}
	}
	lua.lua_pop(l, 1)
	return 0
}

fn open_vbar_module(l &C.lua_State) int {
	C.lua_createtable(l, 0, 5)

	C.lua_pushcclosure(l, voidptr(lua_bar_fn), 0)
	C.lua_setfield(l, -2, c'bar')

	C.lua_pushcclosure(l, voidptr(lua_label_fn), 0)
	C.lua_setfield(l, -2, c'label')

	C.lua_pushcclosure(l, voidptr(lua_workspaces_fn), 0)
	C.lua_setfield(l, -2, c'workspaces')

	C.lua_pushcclosure(l, voidptr(lua_poll_fn), 0)
	C.lua_setfield(l, -2, c'poll')

	C.lua_pushcclosure(l, voidptr(lua_setup_fn), 0)
	C.lua_setfield(l, -2, c'setup')

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

	font_family := if accum.font_family != '' { accum.font_family } else { 'monospace' }
	font_size := if accum.font_size != '' { accum.font_size } else { '12pt' }
	bg_color := if accum.bg_color != '' { accum.bg_color } else { '#1e1e2e' }
	fg_color := if accum.fg_color != '' { accum.fg_color } else { '#cdd6f4' }

	mut bars := []BarDesc{cap: accum.bars.len}
	for b in accum.bars {
		bars << BarDesc{
			...b
			font_family: if b.font_family != '' { b.font_family } else { font_family }
			font_size:   if b.font_size != '' { b.font_size } else { font_size }
			bg_color:    if b.bg_color != '' { b.bg_color } else { bg_color }
			fg_color:    if b.fg_color != '' { b.fg_color } else { fg_color }
		}
	}

	return Config{
		font_family: font_family
		font_size:   font_size
		bg_color:    bg_color
		fg_color:    fg_color
		bars:        bars
		polls:       accum.polls
		builtins:    accum.builtins
		shell:       accum.shell
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
