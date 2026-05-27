module main

import cmd
import lib.gtk
import lib.lua
import os
import vars

struct WidgetDesc {
	kind            string
	self_ref        int    = lua.lua_noref
	active_color    string = '#89b4fa'
	text            string
	var_name        string
	format_ref      int = lua.lua_noref
	icon_size       int = 16
	on_click        cmd.Command
	on_right_click  cmd.Command
	on_middle_click cmd.Command
}

struct BarDesc {
	height      int = 30
	self_ref    int = lua.lua_noref
	font_family string
	font_size   string
	bg_color    string
	fg_color    string
	anchors     []string = ['left', 'right', 'top']
	monitors    []string
	on_scroll   cmd.Command
	on_click    cmd.Command
	left        []WidgetDesc
	center      []WidgetDesc
	right       []WidgetDesc
}

struct PollDesc {
	name            string
	value           string
	value_is_json   bool
	command         cmd.Command
	interval        int = 1
	shell           []string
	listen_shell    string
	listen_override cmd.Command
}

struct Config {
	font_family string = 'monospace'
	font_size   string = '12pt'
	bg_color    string = '#1e1e2e'
	fg_color    string = '#cdd6f4'
	bars        []BarDesc
	polls       []PollDesc
	shell       []string
}

struct ContentData {
	left   []WidgetDesc
	center []WidgetDesc
	right  []WidgetDesc
	store  voidptr
	gen    voidptr
	shell  []string
	lua_rt voidptr
}

struct ConfigAccum {
mut:
	font_family string
	font_size   string
	bg_color    string
	fg_color    string
	shell       []string
	bar_refs    []int
	poll_refs   []int
	var_counter int
}

// --- Field reading helpers ---

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

fn read_method_command(l &C.lua_State, tbl_idx int, key &char, self_ref int) cmd.Command {
	C.lua_pushstring(l, key)
	t := C.lua_rawget(l, tbl_idx)
	if t == lua.lua_tstring {
		raw := C.lua_tolstring(l, -1, unsafe { nil })
		s := unsafe { cstring_to_vstring(raw) }
		lua.lua_pop(l, 1)
		return cmd.Command{
			kind:    .shell
			str_val: s
		}
	}
	if t == lua.lua_tfunction {
		ref := C.luaL_ref(l, lua.lua_registryindex)
		return cmd.Command{
			kind:     .lua_fn
			lua_ref:  ref
			self_ref: self_ref
		}
	}
	lua.lua_pop(l, 1)
	return cmd.Command{}
}

fn get_config_accum(l &C.lua_State) &ConfigAccum {
	C.lua_getfield(l, lua.lua_registryindex, c'vbar.config')
	ptr := C.lua_touserdata(l, -1)
	lua.lua_pop(l, 1)
	return unsafe { &ConfigAccum(ptr) }
}

// --- Metatable setup ---

fn lua_click_method(l &C.lua_State) int {
	if C.lua_type(l, 1) != lua.lua_ttable {
		return 0
	}
	t := C.lua_type(l, 2)
	if t == lua.lua_tstring || t == lua.lua_tfunction {
		C.lua_pushvalue(l, 2)
		C.lua_setfield(l, 1, c'click')
	}
	C.lua_pushvalue(l, 1)
	return 1
}

fn lua_right_click_method(l &C.lua_State) int {
	if C.lua_type(l, 1) != lua.lua_ttable {
		return 0
	}
	t := C.lua_type(l, 2)
	if t == lua.lua_tstring || t == lua.lua_tfunction {
		C.lua_pushvalue(l, 2)
		C.lua_setfield(l, 1, c'right_click')
	}
	C.lua_pushvalue(l, 1)
	return 1
}

fn lua_middle_click_method(l &C.lua_State) int {
	if C.lua_type(l, 1) != lua.lua_ttable {
		return 0
	}
	t := C.lua_type(l, 2)
	if t == lua.lua_tstring || t == lua.lua_tfunction {
		C.lua_pushvalue(l, 2)
		C.lua_setfield(l, 1, c'middle_click')
	}
	C.lua_pushvalue(l, 1)
	return 1
}

fn lua_scroll_method(l &C.lua_State) int {
	if C.lua_type(l, 1) != lua.lua_ttable {
		return 0
	}
	t := C.lua_type(l, 2)
	if t == lua.lua_tstring || t == lua.lua_tfunction {
		C.lua_pushvalue(l, 2)
		C.lua_setfield(l, 1, c'scroll')
	}
	C.lua_pushvalue(l, 1)
	return 1
}

fn setup_label_metatable(l &C.lua_State) {
	C.lua_createtable(l, 0, 4)
	mt_idx := C.lua_gettop(l)
	C.lua_pushvalue(l, mt_idx)
	C.lua_setfield(l, mt_idx, c'__index')
	C.lua_pushcclosure(l, voidptr(lua_click_method), 0)
	C.lua_setfield(l, mt_idx, c'click')
	C.lua_pushcclosure(l, voidptr(lua_right_click_method), 0)
	C.lua_setfield(l, mt_idx, c'right_click')
	C.lua_pushcclosure(l, voidptr(lua_middle_click_method), 0)
	C.lua_setfield(l, mt_idx, c'middle_click')
	C.lua_setfield(l, lua.lua_registryindex, c'vbar.label.mt')
}

fn setup_workspaces_metatable(l &C.lua_State) {
	C.lua_createtable(l, 0, 4)
	mt_idx := C.lua_gettop(l)
	C.lua_pushvalue(l, mt_idx)
	C.lua_setfield(l, mt_idx, c'__index')
	C.lua_pushcclosure(l, voidptr(lua_click_method), 0)
	C.lua_setfield(l, mt_idx, c'click')
	C.lua_pushcclosure(l, voidptr(lua_right_click_method), 0)
	C.lua_setfield(l, mt_idx, c'right_click')
	C.lua_pushcclosure(l, voidptr(lua_middle_click_method), 0)
	C.lua_setfield(l, mt_idx, c'middle_click')
	C.lua_setfield(l, lua.lua_registryindex, c'vbar.workspaces.mt')
}

fn setup_bar_metatable(l &C.lua_State) {
	C.lua_createtable(l, 0, 3)
	mt_idx := C.lua_gettop(l)
	C.lua_pushvalue(l, mt_idx)
	C.lua_setfield(l, mt_idx, c'__index')
	C.lua_pushcclosure(l, voidptr(lua_click_method), 0)
	C.lua_setfield(l, mt_idx, c'click')
	C.lua_pushcclosure(l, voidptr(lua_scroll_method), 0)
	C.lua_setfield(l, mt_idx, c'scroll')
	C.lua_setfield(l, lua.lua_registryindex, c'vbar.bar.mt')
}

fn apply_metatable(l &C.lua_State, inst_idx int, registry_key &char) {
	C.lua_getfield(l, lua.lua_registryindex, registry_key)
	C.lua_setmetatable(l, inst_idx)
}

fn lua_var_format_method(l &C.lua_State) int {
	if C.lua_type(l, 2) != lua.lua_tstring {
		return 0
	}
	raw := C.lua_tolstring(l, 2, unsafe { nil })

	C.lua_createtable(l, 0, 4)
	tbl_idx := C.lua_gettop(l)

	C.lua_pushstring(l, raw)
	C.lua_setfield(l, tbl_idx, c'text')

	C.lua_getfield(l, 1, c'name')
	if C.lua_type(l, -1) == lua.lua_tstring {
		C.lua_setfield(l, tbl_idx, c'var')
	} else {
		lua.lua_pop(l, 1)
	}

	C.lua_getfield(l, 1, c'_format')
	if C.lua_type(l, -1) == lua.lua_tfunction {
		C.lua_setfield(l, tbl_idx, c'_format')
	} else {
		lua.lua_pop(l, 1)
	}

	C.lua_pushstring(l, c'label')
	C.lua_setfield(l, tbl_idx, c'__vbar_type')

	C.lua_getfield(l, lua.lua_registryindex, c'vbar.label.mt')
	C.lua_setmetatable(l, tbl_idx)
	return 1
}

fn lua_var_newindex(l &C.lua_State) int {
	if C.lua_type(l, 2) == lua.lua_tstring {
		raw := C.lua_tolstring(l, 2, unsafe { nil })
		key := unsafe { cstring_to_vstring(raw) }
		if key == 'format' {
			C.lua_pushstring(l, c'_format')
			C.lua_pushvalue(l, 3)
			C.lua_rawset(l, 1)
			return 0
		}
	}
	C.lua_rawset(l, 1)
	return 0
}

fn setup_var_metatable(l &C.lua_State) {
	C.lua_createtable(l, 0, 7)
	mt_idx := C.lua_gettop(l)
	C.lua_pushvalue(l, mt_idx)
	C.lua_setfield(l, mt_idx, c'__index')
	C.lua_pushcclosure(l, voidptr(lua_var_set_fn), 0)
	C.lua_setfield(l, mt_idx, c'set')
	C.lua_pushcclosure(l, voidptr(lua_var_format_method), 0)
	C.lua_setfield(l, mt_idx, c'format')
	C.lua_pushcclosure(l, voidptr(lua_var_poll_fn), 0)
	C.lua_setfield(l, mt_idx, c'poll')
	C.lua_pushcclosure(l, voidptr(lua_var_listen_fn), 0)
	C.lua_setfield(l, mt_idx, c'listen')
	C.lua_pushcclosure(l, voidptr(lua_var_value_fn), 0)
	C.lua_setfield(l, mt_idx, c'value')
	C.lua_pushcclosure(l, voidptr(lua_var_newindex), 0)
	C.lua_setfield(l, mt_idx, c'__newindex')
	C.lua_setfield(l, lua.lua_registryindex, c'vbar.var.mt')
}

struct VarSetUpdate {
	name    string
	value   string
	is_json bool
	store   voidptr
}

fn var_set_apply(data voidptr) int {
	update := unsafe { &VarSetUpdate(data) }
	mut store := unsafe { &vars.VarStore(update.store) }
	if update.is_json {
		store.set_json(update.name, update.value)
	} else {
		store.set(update.name, update.value)
	}
	return 0
}

fn lua_value_to_string(l &C.lua_State, idx int) string {
	t := C.lua_type(l, idx)
	if t == lua.lua_tstring {
		raw := C.lua_tolstring(l, idx, unsafe { nil })
		return unsafe { cstring_to_vstring(raw) }
	}
	if t == lua.lua_tnumber {
		i := C.lua_tointegerx(l, idx, unsafe { nil })
		n := C.lua_tonumberx(l, idx, unsafe { nil })
		return if f64(i) == n { '${i}' } else { '${n}' }
	}
	if t == lua.lua_tboolean {
		return if C.lua_toboolean(l, idx) != 0 { 'true' } else { 'false' }
	}
	return ''
}

fn json_quote_str(s string) string {
	hex_chars := '0123456789abcdef'
	mut out := '"'
	for i := 0; i < s.len; i++ {
		c := s[i]
		if c == `"` {
			out += '\\"'
		} else if c == `\\` {
			out += '\\\\'
		} else if c == `\n` {
			out += '\\n'
		} else if c == `\r` {
			out += '\\r'
		} else if c == `\t` {
			out += '\\t'
		} else if c < 0x20 {
			out += '\\u00'
			out += hex_chars[(c >> 4) & 0xF].ascii_str()
			out += hex_chars[c & 0xF].ascii_str()
		} else {
			out += c.ascii_str()
		}
	}
	out += '"'
	return out
}

fn lua_table_is_array(l &C.lua_State, abs_idx int) bool {
	n := int(C.lua_rawlen(l, abs_idx))
	if n == 0 {
		return false
	}
	mut count := 0
	C.lua_pushnil(l)
	for C.lua_next(l, abs_idx) != 0 {
		count++
		if C.lua_type(l, -2) != lua.lua_tnumber {
			lua.lua_pop(l, 2)
			return false
		}
		lua.lua_pop(l, 1)
	}
	return count == n
}

fn lua_json_key(l &C.lua_State, idx int) string {
	abs := if idx > 0 { idx } else { C.lua_gettop(l) + idx + 1 }
	t := C.lua_type(l, abs)
	if t == lua.lua_tstring {
		raw := C.lua_tolstring(l, abs, unsafe { nil })
		return json_quote_str(unsafe { cstring_to_vstring(raw) })
	}
	if t == lua.lua_tnumber {
		i := C.lua_tointegerx(l, abs, unsafe { nil })
		return '"${i}"'
	}
	return '""'
}

fn lua_value_to_json(l &C.lua_State, idx int, depth int) string {
	if depth > 16 {
		return 'null'
	}
	abs := if idx > 0 { idx } else { C.lua_gettop(l) + idx + 1 }
	t := C.lua_type(l, abs)
	if t == lua.lua_tnil {
		return 'null'
	}
	if t == lua.lua_tboolean {
		return if C.lua_toboolean(l, abs) != 0 { 'true' } else { 'false' }
	}
	if t == lua.lua_tnumber {
		i := C.lua_tointegerx(l, abs, unsafe { nil })
		n := C.lua_tonumberx(l, abs, unsafe { nil })
		return if f64(i) == n { '${i}' } else { '${n}' }
	}
	if t == lua.lua_tstring {
		raw := C.lua_tolstring(l, abs, unsafe { nil })
		return json_quote_str(unsafe { cstring_to_vstring(raw) })
	}
	if t == lua.lua_ttable {
		if lua_table_is_array(l, abs) {
			n := int(C.lua_rawlen(l, abs))
			mut parts := []string{}
			for i := 1; i <= n; i++ {
				C.lua_rawgeti(l, abs, i64(i))
				parts << lua_value_to_json(l, -1, depth + 1)
				lua.lua_pop(l, 1)
			}
			return '[' + parts.join(',') + ']'
		}
		mut parts := []string{}
		C.lua_pushnil(l)
		for C.lua_next(l, abs) != 0 {
			key := lua_json_key(l, -2)
			val := lua_value_to_json(l, -1, depth + 1)
			parts << '${key}:${val}'
			lua.lua_pop(l, 1)
		}
		return '{' + parts.join(',') + '}'
	}
	return 'null'
}

fn lua_var_set_fn(l &C.lua_State) int {
	if C.lua_type(l, 1) != lua.lua_ttable {
		return 0
	}

	C.lua_getfield(l, 1, c'name')
	if C.lua_type(l, -1) != lua.lua_tstring {
		lua.lua_pop(l, 1)
		return 0
	}
	raw_name := C.lua_tolstring(l, -1, unsafe { nil })
	name := unsafe { cstring_to_vstring(raw_name) }
	lua.lua_pop(l, 1)

	val_type := C.lua_type(l, 2)
	is_json := val_type == lua.lua_ttable || val_type == lua.lua_tnumber
		|| val_type == lua.lua_tboolean
	value := if is_json {
		lua_value_to_json(l, 2, 0)
	} else {
		lua_value_to_string(l, 2)
	}

	C.lua_getfield(l, lua.lua_registryindex, c'vbar.store')
	store_ptr := C.lua_touserdata(l, -1)
	lua.lua_pop(l, 1)
	if store_ptr == unsafe { nil } {
		return 0
	}

	update := &VarSetUpdate{
		name:    name
		value:   value
		is_json: is_json
		store:   store_ptr
	}
	C.g_idle_add(voidptr(var_set_apply), voidptr(update))

	return 0
}

// --- Entity constructors ---

fn copy_table_field(l &C.lua_State, src_idx int, dst_idx int, key &char) {
	t := C.lua_getfield(l, src_idx, key)
	if t != lua.lua_tnil {
		C.lua_setfield(l, dst_idx, key)
	} else {
		lua.lua_pop(l, 1)
	}
}

fn lua_bar_fn(l &C.lua_State) int {
	C.lua_createtable(l, 0, 14)
	inst_idx := C.lua_gettop(l)

	if C.lua_type(l, 1) == lua.lua_ttable {
		for key in [c'height', c'font_family', c'font_size', c'bg_color', c'fg_color', c'anchors',
			c'monitors', c'left', c'center', c'right', c'scroll', c'click'] {
			copy_table_field(l, 1, inst_idx, key)
		}
	}

	C.lua_pushstring(l, c'bar')
	C.lua_setfield(l, inst_idx, c'__vbar_type')

	apply_metatable(l, inst_idx, c'vbar.bar.mt')

	C.lua_pushvalue(l, inst_idx)
	ref := C.luaL_ref(l, lua.lua_registryindex)
	mut accum := get_config_accum(l)
	accum.bar_refs << ref

	return 1
}

fn lua_label_fn(l &C.lua_State) int {
	C.lua_createtable(l, 0, 6)
	inst_idx := C.lua_gettop(l)

	arg_type := C.lua_type(l, 1)
	if arg_type == lua.lua_tstring {
		raw := C.lua_tolstring(l, 1, unsafe { nil })
		C.lua_pushstring(l, raw)
		C.lua_setfield(l, inst_idx, c'text')
	} else if arg_type == lua.lua_ttable {
		for key in [c'text', c'click', c'right_click', c'middle_click'] {
			copy_table_field(l, 1, inst_idx, key)
		}
	}

	C.lua_pushstring(l, c'label')
	C.lua_setfield(l, inst_idx, c'__vbar_type')

	apply_metatable(l, inst_idx, c'vbar.label.mt')

	return 1
}

fn lua_workspaces_fn(l &C.lua_State) int {
	C.lua_createtable(l, 0, 6)
	inst_idx := C.lua_gettop(l)

	if C.lua_type(l, 1) == lua.lua_ttable {
		for key in [c'active_color', c'click', c'right_click', c'middle_click'] {
			copy_table_field(l, 1, inst_idx, key)
		}
	}

	C.lua_pushstring(l, c'workspaces')
	C.lua_setfield(l, inst_idx, c'__vbar_type')

	apply_metatable(l, inst_idx, c'vbar.workspaces.mt')

	return 1
}

fn lua_systray_fn(l &C.lua_State) int {
	C.lua_createtable(l, 0, 2)
	inst_idx := C.lua_gettop(l)

	if C.lua_type(l, 1) == lua.lua_ttable {
		copy_table_field(l, 1, inst_idx, c'icon_size')
	}

	C.lua_pushstring(l, c'systray')
	C.lua_setfield(l, inst_idx, c'__vbar_type')

	return 1
}

fn lua_var_fn(l &C.lua_State) int {
	mut accum := get_config_accum(l)
	accum.var_counter++

	C.lua_createtable(l, 0, 4)
	inst_idx := C.lua_gettop(l)

	mut id := 'var_${accum.var_counter}'
	if C.lua_type(l, 1) == lua.lua_tstring {
		raw := C.lua_tolstring(l, 1, unsafe { nil })
		id = unsafe { cstring_to_vstring(raw) }
	}

	C.lua_pushstring(l, id.str)
	C.lua_setfield(l, inst_idx, c'name')

	C.lua_pushstring(l, c'var')
	C.lua_setfield(l, inst_idx, c'__vbar_type')

	apply_metatable(l, inst_idx, c'vbar.var.mt')

	C.lua_pushvalue(l, inst_idx)
	ref := C.luaL_ref(l, lua.lua_registryindex)
	accum.poll_refs << ref

	return 1
}

fn lua_var_value_fn(l &C.lua_State) int {
	if C.lua_type(l, 1) != lua.lua_ttable {
		return 0
	}
	val_type := C.lua_type(l, 2)
	if val_type == lua.lua_tstring {
		raw := C.lua_tolstring(l, 2, unsafe { nil })
		C.lua_pushstring(l, raw)
		C.lua_setfield(l, 1, c'value')
	} else if val_type == lua.lua_ttable || val_type == lua.lua_tnumber
		|| val_type == lua.lua_tboolean {
		json_val := lua_value_to_json(l, 2, 0)
		C.lua_pushstring(l, json_val.str)
		C.lua_setfield(l, 1, c'value')
		C.lua_pushinteger(l, 1)
		C.lua_setfield(l, 1, c'value_is_json')
	} else {
		return 0
	}
	C.lua_pushvalue(l, 1)
	return 1
}

fn lua_var_poll_fn(l &C.lua_State) int {
	if C.lua_type(l, 1) != lua.lua_ttable {
		return 0
	}
	arg2 := C.lua_type(l, 2)
	if arg2 == lua.lua_tstring {
		raw := C.lua_tolstring(l, 2, unsafe { nil })
		C.lua_pushstring(l, raw)
		C.lua_setfield(l, 1, c'cmd_shell')
	} else if arg2 == lua.lua_tfunction {
		C.lua_pushvalue(l, 2)
		C.lua_setfield(l, 1, c'cmd_fn')
	} else {
		return 0
	}
	if C.lua_type(l, 3) == lua.lua_ttable {
		copy_table_field(l, 3, 1, c'interval')
		copy_table_field(l, 3, 1, c'shell')
	}
	C.lua_pushvalue(l, 1)
	return 1
}

fn lua_var_listen_fn(l &C.lua_State) int {
	if C.lua_type(l, 1) != lua.lua_ttable {
		return 0
	}
	if C.lua_type(l, 2) != lua.lua_tstring {
		return 0
	}
	raw := C.lua_tolstring(l, 2, unsafe { nil })
	C.lua_pushstring(l, raw)
	C.lua_setfield(l, 1, c'listen_shell')
	arg3 := C.lua_type(l, 3)
	if arg3 == lua.lua_tstring {
		raw3 := C.lua_tolstring(l, 3, unsafe { nil })
		C.lua_pushstring(l, raw3)
		C.lua_setfield(l, 1, c'listen_override_shell')
	} else if arg3 == lua.lua_tfunction {
		C.lua_pushvalue(l, 3)
		C.lua_setfield(l, 1, c'listen_override_fn')
	}
	C.lua_pushvalue(l, 1)
	return 1
}

// --- Deferred reading (after script finishes) ---

fn read_widget_from_table(l &C.lua_State, tbl_idx int) WidgetDesc {
	kind := read_string_field(l, tbl_idx, c'__vbar_type', '')
	if kind == '' {
		return WidgetDesc{}
	}

	C.lua_pushvalue(l, tbl_idx)
	self_ref := C.luaL_ref(l, lua.lua_registryindex)

	on_click := read_method_command(l, tbl_idx, c'click', self_ref)
	on_right_click := read_method_command(l, tbl_idx, c'right_click', self_ref)
	on_middle_click := read_method_command(l, tbl_idx, c'middle_click', self_ref)

	return match kind {
		'var' {
			name := read_string_field(l, tbl_idx, c'name', '')
			t := C.lua_getfield(l, tbl_idx, c'_format')
			format_ref := if t == lua.lua_tfunction {
				C.luaL_ref(l, lua.lua_registryindex)
			} else {
				lua.lua_pop(l, 1)
				lua.lua_noref
			}
			WidgetDesc{
				kind:            'label'
				self_ref:        self_ref
				var_name:        name
				format_ref:      format_ref
				on_click:        on_click
				on_right_click:  on_right_click
				on_middle_click: on_middle_click
			}
		}
		'label' {
			text := read_string_field(l, tbl_idx, c'text', '')
			var_name := read_string_field(l, tbl_idx, c'var', '')
			t := C.lua_getfield(l, tbl_idx, c'_format')
			format_ref := if t == lua.lua_tfunction {
				C.luaL_ref(l, lua.lua_registryindex)
			} else {
				lua.lua_pop(l, 1)
				lua.lua_noref
			}
			WidgetDesc{
				kind:            'label'
				self_ref:        self_ref
				text:            text
				var_name:        var_name
				format_ref:      format_ref
				on_click:        on_click
				on_right_click:  on_right_click
				on_middle_click: on_middle_click
			}
		}
		'workspaces' {
			WidgetDesc{
				kind:            'workspaces'
				self_ref:        self_ref
				active_color:    read_string_field(l, tbl_idx, c'active_color', '#89b4fa')
				on_click:        on_click
				on_right_click:  on_right_click
				on_middle_click: on_middle_click
			}
		}
		'systray' {
			WidgetDesc{
				kind:      'systray'
				self_ref:  self_ref
				icon_size: read_int_field(l, tbl_idx, c'icon_size', 16)
			}
		}
		else {
			eprintln('vbar: unknown widget type in config: ${kind}')
			WidgetDesc{}
		}
	}
}

fn read_widget_list_from_refs(l &C.lua_State, tbl_idx int, key &char) []WidgetDesc {
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
			desc := read_widget_from_table(l, widget_tbl)
			if desc.kind != '' {
				result << desc
			}
		}
		lua.lua_pop(l, 1)
	}
	lua.lua_pop(l, 1)
	return result
}

fn read_bar_from_ref(l &C.lua_State, ref int) BarDesc {
	C.lua_rawgeti(l, lua.lua_registryindex, i64(ref))
	tbl_idx := C.lua_gettop(l)

	C.lua_pushvalue(l, tbl_idx)
	self_ref := C.luaL_ref(l, lua.lua_registryindex)

	desc := BarDesc{
		height:      read_int_field(l, tbl_idx, c'height', 30)
		self_ref:    self_ref
		font_family: read_string_field(l, tbl_idx, c'font_family', '')
		font_size:   read_string_field(l, tbl_idx, c'font_size', '')
		bg_color:    read_string_field(l, tbl_idx, c'bg_color', '')
		fg_color:    read_string_field(l, tbl_idx, c'fg_color', '')
		anchors:     read_string_array_field(l, tbl_idx, c'anchors')
		monitors:    read_string_array_field(l, tbl_idx, c'monitors')
		on_scroll:   read_method_command(l, tbl_idx, c'scroll', self_ref)
		on_click:    read_method_command(l, tbl_idx, c'click', self_ref)
		left:        read_widget_list_from_refs(l, tbl_idx, c'left')
		center:      read_widget_list_from_refs(l, tbl_idx, c'center')
		right:       read_widget_list_from_refs(l, tbl_idx, c'right')
	}

	lua.lua_pop(l, 1)
	return desc
}

fn read_var_from_ref(l &C.lua_State, ref int) PollDesc {
	C.lua_rawgeti(l, lua.lua_registryindex, i64(ref))
	tbl_idx := C.lua_gettop(l)

	name := read_string_field(l, tbl_idx, c'name', '')
	value := read_string_field(l, tbl_idx, c'value', '')
	value_is_json := read_int_field(l, tbl_idx, c'value_is_json', 0) != 0
	interval := read_int_field(l, tbl_idx, c'interval', 1)
	shell := read_string_array_field(l, tbl_idx, c'shell')
	listen_shell := read_string_field(l, tbl_idx, c'listen_shell', '')

	C.lua_pushvalue(l, tbl_idx)
	self_ref := C.luaL_ref(l, lua.lua_registryindex)

	mut command := cmd.Command{}
	t_fn := C.lua_getfield(l, tbl_idx, c'cmd_fn')
	if t_fn == lua.lua_tfunction {
		fn_ref := C.luaL_ref(l, lua.lua_registryindex)
		command = cmd.Command{
			kind:     .lua_fn
			lua_ref:  fn_ref
			self_ref: self_ref
		}
	} else {
		lua.lua_pop(l, 1)
		t_sh := C.lua_getfield(l, tbl_idx, c'cmd_shell')
		if t_sh == lua.lua_tstring {
			raw := C.lua_tolstring(l, -1, unsafe { nil })
			s := unsafe { cstring_to_vstring(raw) }
			lua.lua_pop(l, 1)
			command = cmd.Command{
				kind:    .shell
				str_val: s
			}
		} else {
			lua.lua_pop(l, 1)
		}
	}

	mut listen_override := cmd.Command{}
	t_ov_fn := C.lua_getfield(l, tbl_idx, c'listen_override_fn')
	if t_ov_fn == lua.lua_tfunction {
		fn_ref := C.luaL_ref(l, lua.lua_registryindex)
		listen_override = cmd.Command{
			kind:     .lua_fn
			lua_ref:  fn_ref
			self_ref: self_ref
		}
	} else {
		lua.lua_pop(l, 1)
		t_ov_sh := C.lua_getfield(l, tbl_idx, c'listen_override_shell')
		if t_ov_sh == lua.lua_tstring {
			raw := C.lua_tolstring(l, -1, unsafe { nil })
			s := unsafe { cstring_to_vstring(raw) }
			lua.lua_pop(l, 1)
			listen_override = cmd.Command{
				kind:    .shell
				str_val: s
			}
		} else {
			lua.lua_pop(l, 1)
		}
	}

	lua.lua_pop(l, 1)

	return PollDesc{
		name:            name
		value:           value
		value_is_json:   value_is_json
		command:         command
		interval:        interval
		shell:           shell
		listen_shell:    listen_shell
		listen_override: listen_override
	}
}

// --- Utility Lua functions (unchanged) ---

fn lua_format_value(l &C.lua_State, idx int, depth int) string {
	if depth > 8 {
		return '...'
	}
	abs := if idx > 0 { idx } else { C.lua_gettop(l) + idx + 1 }
	t := C.lua_type(l, abs)
	if t == lua.lua_tnil {
		return 'nil'
	}
	if t == lua.lua_tboolean {
		return if C.lua_toboolean(l, abs) != 0 { 'true' } else { 'false' }
	}
	if t == lua.lua_tnumber {
		i := C.lua_tointegerx(l, abs, unsafe { nil })
		n := C.lua_tonumberx(l, abs, unsafe { nil })
		return if f64(i) == n { '${i}' } else { '${n}' }
	}
	if t == lua.lua_tstring {
		raw := C.lua_tolstring(l, abs, unsafe { nil })
		s := unsafe { cstring_to_vstring(raw) }
		return if depth == 0 { s } else { '"${s}"' }
	}
	if t == lua.lua_tfunction {
		return 'function'
	}
	if t == lua.lua_ttable {
		mut parts := []string{}
		prefix := '\t'.repeat(depth + 1)
		C.lua_pushnil(l)
		for C.lua_next(l, abs) != 0 {
			key := lua_format_key(l, -2)
			val := lua_format_value(l, -1, depth + 1)
			parts << '${prefix}${key} = ${val}'
			lua.lua_pop(l, 1)
		}
		if parts.len == 0 {
			return '{}'
		}
		close := '\t'.repeat(depth)
		return '{\n' + parts.join('\n') + '\n${close}}'
	}
	return '?'
}

fn lua_format_key(l &C.lua_State, idx int) string {
	abs := if idx > 0 { idx } else { C.lua_gettop(l) + idx + 1 }
	t := C.lua_type(l, abs)
	if t == lua.lua_tstring {
		raw := C.lua_tolstring(l, abs, unsafe { nil })
		return unsafe { cstring_to_vstring(raw) }
	}
	if t == lua.lua_tnumber {
		i := C.lua_tointegerx(l, abs, unsafe { nil })
		return '[${i}]'
	}
	return '[?]'
}

fn lua_debug_fn(l &C.lua_State) int {
	nargs := C.lua_gettop(l)
	mut parts := []string{}
	for i := 1; i <= nargs; i++ {
		parts << lua_format_value(l, i, 0)
	}
	body := parts.join('\t')
	mut p := os.new_process('notify-send')
	p.set_args(['vbar', body])
	p.wait()
	p.close()
	return 0
}

fn lua_exec_fn(l &C.lua_State) int {
	if C.lua_type(l, 1) != lua.lua_tstring {
		C.luaL_error(l, c'vbar.exec: expected string command')
		return 0
	}
	raw_cmd := C.lua_tolstring(l, 1, unsafe { nil })
	command := unsafe { cstring_to_vstring(raw_cmd) }

	mut shell := []string{}
	t := C.lua_getfield(l, lua.lua_registryindex, c'vbar.shell')
	if t == lua.lua_ttable {
		shell_idx := C.lua_gettop(l)
		n := int(C.lua_rawlen(l, shell_idx))
		for i := 1; i <= n; i++ {
			C.lua_rawgeti(l, shell_idx, i64(i))
			if C.lua_type(l, -1) == lua.lua_tstring {
				raw := C.lua_tolstring(l, -1, unsafe { nil })
				shell << unsafe { cstring_to_vstring(raw) }
			}
			lua.lua_pop(l, 1)
		}
	}
	lua.lua_pop(l, 1)

	if shell.len == 0 {
		shell = ['sh', '-c']
	}

	mut p := os.new_process(shell[0])
	mut args := []string{}
	for a in shell[1..] {
		args << a
	}
	args << command
	p.set_args(args)
	p.set_redirect_stdio()
	p.wait()
	output := p.stdout_slurp().trim_space()
	code := p.code
	p.close()

	C.lua_pushstring(l, output.str)
	C.lua_pushinteger(l, i64(code))
	return 2
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
		C.lua_getfield(l, 1, c'shell')
		C.lua_setfield(l, lua.lua_registryindex, c'vbar.shell')
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
	return 0
}

const string_mod_snippet = 'getmetatable("").__mod = function(a, b) if not b then return a elseif type(b) == "table" then return string.format(a, table.unpack(b)) else return string.format(a, b) end end'

fn install_string_mod(l &C.lua_State) {
	if C.luaL_loadstring(l, string_mod_snippet.str) != lua.lua_ok {
		lua.lua_pop(l, 1)
		return
	}
	if C.lua_pcallk(l, 0, 0, 0, 0, unsafe { nil }) != lua.lua_ok {
		lua.lua_pop(l, 1)
	}
}

// --- Global vars ---

struct GlobalVarDesc {
	name     string
	command  string
	interval int
}

fn global_var_descs() []GlobalVarDesc {
	return [
		GlobalVarDesc{
			name:     'vbar.time'
			command:  'date +%H:%M:%S'
			interval: 1
		},
		GlobalVarDesc{
			name:     'vbar.date'
			command:  'date +%Y-%m-%d'
			interval: 3600
		},
		GlobalVarDesc{
			name:     'vbar.battery'
			command:  'cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo N/A'
			interval: 10
		},
		GlobalVarDesc{
			name:     'vbar.cpu'
			command:  'grep "cpu " /proc/stat | awk \'{u=$2+$4;t=$2+$3+$4+$5;print int(u/t*100)"%"}\''
			interval: 2
		},
		GlobalVarDesc{
			name:     'vbar.mem'
			command:  'free -m | awk \'/Mem:/{print int($3/$2*100)"%"}\''
			interval: 2
		},
	]
}

// --- Module registration ---

fn open_vbar_module(l &C.lua_State) int {
	C.lua_createtable(l, 0, 8)
	mod_idx := C.lua_gettop(l)

	setup_bar_metatable(l)
	setup_label_metatable(l)
	setup_workspaces_metatable(l)
	setup_var_metatable(l)

	C.lua_pushcclosure(l, voidptr(lua_bar_fn), 0)
	C.lua_setfield(l, mod_idx, c'bar')

	C.lua_pushcclosure(l, voidptr(lua_label_fn), 0)
	C.lua_setfield(l, mod_idx, c'label')

	C.lua_pushcclosure(l, voidptr(lua_workspaces_fn), 0)
	C.lua_setfield(l, mod_idx, c'workspaces')

	C.lua_pushcclosure(l, voidptr(lua_systray_fn), 0)
	C.lua_setfield(l, mod_idx, c'systray')

	C.lua_pushcclosure(l, voidptr(lua_var_fn), 0)
	C.lua_setfield(l, mod_idx, c'var')

	C.lua_pushcclosure(l, voidptr(lua_setup_fn), 0)
	C.lua_setfield(l, mod_idx, c'setup')

	C.lua_pushcclosure(l, voidptr(lua_exec_fn), 0)
	C.lua_setfield(l, mod_idx, c'exec')

	C.lua_pushcclosure(l, voidptr(lua_debug_fn), 0)
	C.lua_setfield(l, mod_idx, c'debug')

	descs := global_var_descs()
	C.lua_createtable(l, 0, descs.len)
	vars_tbl_idx := C.lua_gettop(l)
	for gv in descs {
		C.lua_createtable(l, 0, 3)
		v_idx := C.lua_gettop(l)
		C.lua_pushstring(l, gv.name.str)
		C.lua_setfield(l, v_idx, c'name')
		C.lua_pushstring(l, c'var')
		C.lua_setfield(l, v_idx, c'__vbar_type')
		apply_metatable(l, v_idx, c'vbar.var.mt')
		lua_key := gv.name.all_after('vbar.')
		C.lua_setfield(l, vars_tbl_idx, lua_key.str)
	}
	C.lua_setfield(l, mod_idx, c'vars')

	return 1
}

// --- Config loading ---

fn config_dir() string {
	xdg := os.getenv('XDG_CONFIG_HOME')
	base := if xdg != '' { xdg } else { os.join_path(os.home_dir(), '.config') }
	return os.join_path(base, 'vbar')
}

fn load_config() (Config, &C.lua_State) {
	config_path := os.join_path(config_dir(), 'init.lua')

	if !os.exists(config_path) {
		return default_config(), unsafe { nil }
	}

	l := C.luaL_newstate()
	if l == unsafe { nil } {
		eprintln('vbar: failed to create Lua state')
		return default_config(), unsafe { nil }
	}

	C.luaL_openlibs(l)
	install_string_mod(l)

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
		C.lua_close(l)
		return default_config(), unsafe { nil }
	}

	call_status := C.lua_pcallk(l, 0, lua.lua_multret, 0, 0, unsafe { nil })
	if call_status != lua.lua_ok {
		raw := C.lua_tolstring(l, -1, unsafe { nil })
		err := unsafe { cstring_to_vstring(raw) }
		eprintln('vbar: config runtime error: ${err}')
		C.lua_close(l)
		return default_config(), unsafe { nil }
	}

	font_family := if accum.font_family != '' { accum.font_family } else { 'monospace' }
	font_size := if accum.font_size != '' { accum.font_size } else { '12pt' }
	bg_color := if accum.bg_color != '' { accum.bg_color } else { '#1e1e2e' }
	fg_color := if accum.fg_color != '' { accum.fg_color } else { '#cdd6f4' }

	mut bars := []BarDesc{cap: accum.bar_refs.len}
	for ref in accum.bar_refs {
		b := read_bar_from_ref(l, ref)
		bars << BarDesc{
			...b
			font_family: if b.font_family != '' { b.font_family } else { font_family }
			font_size:   if b.font_size != '' { b.font_size } else { font_size }
			bg_color:    if b.bg_color != '' { b.bg_color } else { bg_color }
			fg_color:    if b.fg_color != '' { b.fg_color } else { fg_color }
		}
	}

	mut polls := []PollDesc{cap: accum.poll_refs.len}
	for ref in accum.poll_refs {
		polls << read_var_from_ref(l, ref)
	}

	return Config{
		font_family: font_family
		font_size:   font_size
		bg_color:    bg_color
		fg_color:    fg_color
		bars:        bars
		polls:       polls
		shell:       accum.shell
	}, l
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
					text: 'vbar'
				}]
			},
		]
	}
}
