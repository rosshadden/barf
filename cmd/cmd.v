module cmd

import lib.lua
import os
import sync

pub enum CommandKind {
	none
	shell
	lua_fn
}

pub struct Command {
pub:
	kind     CommandKind
	str_val  string
	lua_ref  int
	self_ref int = lua.lua_noref
}

pub fn (c Command) is_set() bool {
	return c.kind != .none
}

pub fn (c Command) with_self_ref(new_self_ref int) Command {
	if c.kind == .none || new_self_ref == lua.lua_noref {
		return c
	}
	return Command{
		...c
		self_ref: new_self_ref
	}
}

pub struct MonitorInfo {
pub:
	name         string
	id           int
	x            int
	y            int
	width        int
	height       int
	refresh_rate f64
	scale        f64
}

@[heap]
pub struct LuaRuntime {
pub mut:
	l      &C.lua_State = unsafe { nil }
	closed bool
	mtx    sync.Mutex
}

pub fn new_runtime(l &C.lua_State) &LuaRuntime {
	return &LuaRuntime{
		l: l
	}
}

pub fn (mut rt LuaRuntime) close() {
	rt.mtx.@lock()
	defer {
		rt.mtx.unlock()
	}
	if rt.l != unsafe { nil } {
		C.lua_close(rt.l)
		rt.l = unsafe { nil }
	}
	rt.closed = true
}

fn call_lua(rt_ptr voidptr, ref int, self_ref int, args []string) ?string {
	if rt_ptr == unsafe { nil } {
		return none
	}
	mut rt := unsafe { &LuaRuntime(rt_ptr) }
	rt.mtx.@lock()
	defer {
		rt.mtx.unlock()
	}
	if rt.closed || rt.l == unsafe { nil } {
		return none
	}
	C.lua_rawgeti(rt.l, lua.lua_registryindex, i64(ref))
	mut nargs := args.len
	if self_ref != lua.lua_noref {
		C.lua_rawgeti(rt.l, lua.lua_registryindex, i64(self_ref))
		nargs++
	}
	for a in args {
		C.lua_pushstring(rt.l, a.str)
	}
	status := C.lua_pcallk(rt.l, nargs, 1, 0, 0, unsafe { nil })
	if status != lua.lua_ok {
		raw := C.lua_tolstring(rt.l, -1, unsafe { nil })
		err := unsafe { cstring_to_vstring(raw) }
		lua.lua_pop(rt.l, 1)
		eprintln('vbar: lua command error: ${err}')
		return none
	}
	if C.lua_type(rt.l, -1) == lua.lua_tstring {
		raw := C.lua_tolstring(rt.l, -1, unsafe { nil })
		result := unsafe { cstring_to_vstring(raw) }
		lua.lua_pop(rt.l, 1)
		return result
	}
	lua.lua_pop(rt.l, 1)
	return none
}

pub fn fire(c Command, shell []string, rt_ptr voidptr, args []string) {
	match c.kind {
		.none {
			return
		}
		.shell {
			if shell.len == 0 || c.str_val == '' {
				return
			}
			mut resolved := c.str_val
			if args.len > 0 {
				resolved = resolved.replace('{}', args[0])
			}
			mut p := os.new_process(shell[0])
			mut pargs := []string{}
			for a in shell[1..] {
				pargs << a
			}
			pargs << resolved
			p.set_args(pargs)
			p.wait()
			p.close()
		}
		.lua_fn {
			call_lua(rt_ptr, c.lua_ref, c.self_ref, args) or {}
		}
	}
}

pub fn exec(c Command, shell []string, rt_ptr voidptr) ?string {
	match c.kind {
		.none {
			return none
		}
		.shell {
			if shell.len == 0 || c.str_val == '' {
				return none
			}
			mut p := os.new_process(shell[0])
			mut args := []string{}
			for a in shell[1..] {
				args << a
			}
			args << c.str_val
			p.set_args(args)
			p.set_redirect_stdio()
			p.wait()
			output := p.stdout_slurp()
			code := p.code
			p.close()
			if code == 0 {
				return output.trim_space()
			}
			return none
		}
		.lua_fn {
			return call_lua(rt_ptr, c.lua_ref, c.self_ref, [])
		}
	}
}

fn push_monitor_table(l &C.lua_State, mon MonitorInfo) {
	C.lua_createtable(l, 0, 8)
	idx := C.lua_gettop(l)
	C.lua_pushstring(l, mon.name.str)
	C.lua_setfield(l, idx, c'name')
	C.lua_pushinteger(l, i64(mon.id))
	C.lua_setfield(l, idx, c'id')
	C.lua_pushinteger(l, i64(mon.x))
	C.lua_setfield(l, idx, c'x')
	C.lua_pushinteger(l, i64(mon.y))
	C.lua_setfield(l, idx, c'y')
	C.lua_pushinteger(l, i64(mon.width))
	C.lua_setfield(l, idx, c'width')
	C.lua_pushinteger(l, i64(mon.height))
	C.lua_setfield(l, idx, c'height')
	C.lua_pushnumber(l, mon.refresh_rate)
	C.lua_setfield(l, idx, c'refresh_rate')
	C.lua_pushnumber(l, mon.scale)
	C.lua_setfield(l, idx, c'scale')
}

pub fn clone_self_with_monitor(rt_ptr voidptr, orig_self_ref int, mon MonitorInfo) int {
	if rt_ptr == unsafe { nil } {
		return lua.lua_noref
	}
	mut rt := unsafe { &LuaRuntime(rt_ptr) }
	rt.mtx.@lock()
	defer {
		rt.mtx.unlock()
	}
	if rt.closed || rt.l == unsafe { nil } {
		return lua.lua_noref
	}

	C.lua_createtable(rt.l, 0, 1)
	new_idx := C.lua_gettop(rt.l)

	push_monitor_table(rt.l, mon)
	C.lua_setfield(rt.l, new_idx, c'monitor')

	if orig_self_ref != lua.lua_noref {
		C.lua_createtable(rt.l, 0, 1)
		C.lua_rawgeti(rt.l, lua.lua_registryindex, i64(orig_self_ref))
		C.lua_setfield(rt.l, -2, c'__index')
		C.lua_setmetatable(rt.l, new_idx)
	}

	return C.luaL_ref(rt.l, lua.lua_registryindex)
}

pub fn bind_store(rt &LuaRuntime, store voidptr) {
	if rt == unsafe { nil } {
		return
	}
	mut r := unsafe { rt }
	r.mtx.@lock()
	defer {
		r.mtx.unlock()
	}
	if r.closed || r.l == unsafe { nil } {
		return
	}
	C.lua_pushlightuserdata(r.l, store)
	C.lua_setfield(r.l, lua.lua_registryindex, c'vbar.store')
}
