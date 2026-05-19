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
	kind    CommandKind
	str_val string
	lua_ref int
}

pub fn (c Command) is_set() bool {
	return c.kind != .none
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

fn call_lua(rt_ptr voidptr, ref int, args []string) ?string {
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
	for a in args {
		C.lua_pushstring(rt.l, a.str)
	}
	status := C.lua_pcallk(rt.l, args.len, 1, 0, 0, unsafe { nil })
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
			call_lua(rt_ptr, c.lua_ref, args) or {}
		}
	}
}

pub fn exec(c Command, shell []string, rt_ptr voidptr) string {
	match c.kind {
		.none {
			return ''
		}
		.shell {
			if shell.len == 0 || c.str_val == '' {
				return ''
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
			return ''
		}
		.lua_fn {
			return call_lua(rt_ptr, c.lua_ref, []) or { '' }
		}
	}
}
