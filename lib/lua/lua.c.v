module lua

#pkgconfig lua

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include "lua_helpers.h"

pub struct C.lua_State {}

@[typedef]
pub struct C.luaL_Reg {
pub:
	name &char
	func voidptr
}

// Type constants
pub const lua_tnil = 0
pub const lua_tboolean = 1
pub const lua_tnumber = 3
pub const lua_tstring = 4
pub const lua_ttable = 5

// Special indices (wrapped from C macros — values differ between Lua versions)
fn C.vbar_lua_registryindex() int
fn C.vbar_lua_multret() int

pub const lua_registryindex = C.vbar_lua_registryindex()
pub const lua_multret = C.vbar_lua_multret()

// Return codes
pub const lua_ok = 0

// Function type
pub const lua_tfunction = 6

// Reference constants
fn C.vbar_lua_noref() int

pub const lua_noref = C.vbar_lua_noref()

// State lifecycle
pub fn C.luaL_newstate() &C.lua_State
pub fn C.lua_close(L &C.lua_State)
pub fn C.luaL_openlibs(L &C.lua_State)

// Stack manipulation
pub fn C.lua_gettop(L &C.lua_State) int
pub fn C.lua_settop(L &C.lua_State, idx int)

// Type inspection
pub fn C.lua_type(L &C.lua_State, idx int) int

// Push functions
pub fn C.lua_pushstring(L &C.lua_State, s &char) &char
pub fn C.lua_pushcclosure(L &C.lua_State, fn_ voidptr, n int)

// Get functions
pub fn C.lua_getfield(L &C.lua_State, idx int, k &char) int
pub fn C.lua_rawgeti(L &C.lua_State, idx int, n i64) int
pub fn C.lua_rawlen(L &C.lua_State, idx int) u64

// Set functions
pub fn C.lua_setfield(L &C.lua_State, idx int, k &char)

// Table construction & iteration
pub fn C.lua_createtable(L &C.lua_State, narr int, nrec int)
pub fn C.lua_next(L &C.lua_State, idx int) int

// Nil
pub fn C.lua_pushnil(L &C.lua_State)

// Userdata
pub fn C.lua_pushlightuserdata(L &C.lua_State, p voidptr)
pub fn C.lua_touserdata(L &C.lua_State, idx int) voidptr

// Boolean
pub fn C.lua_toboolean(L &C.lua_State, idx int) int

// Read functions (real functions underlying macros)
pub fn C.lua_tolstring(L &C.lua_State, idx int, len voidptr) &char
pub fn C.lua_tointegerx(L &C.lua_State, idx int, isnum voidptr) i64
pub fn C.lua_tonumberx(L &C.lua_State, idx int, isnum voidptr) f64

// Push functions (numeric)
pub fn C.lua_pushinteger(L &C.lua_State, n i64)
pub fn C.lua_pushnumber(L &C.lua_State, n f64)

// Call/load
pub fn C.lua_pcallk(L &C.lua_State, nargs int, nresults int, errfunc int, ctx i64, k voidptr) int
pub fn C.luaL_loadfilex(L &C.lua_State, filename &char, mode voidptr) int

// Module registration
pub fn C.luaL_requiref(L &C.lua_State, modname &char, openf voidptr, glb int)

// References
pub fn C.luaL_ref(L &C.lua_State, t int) int
pub fn C.luaL_unref(L &C.lua_State, t int, ref int)

// Errors
pub fn C.luaL_error(L &C.lua_State, fmt &char) int

// V helpers for Lua macros
@[inline]
pub fn lua_pop(l &C.lua_State, n int) {
	C.lua_settop(l, -n - 1)
}
