#ifndef VBAR_LUA_HELPERS_H
#define VBAR_LUA_HELPERS_H
#include <lua.h>
#include <lauxlib.h>
static inline int barf_lua_registryindex(void) { return LUA_REGISTRYINDEX; }
static inline int barf_lua_multret(void) { return LUA_MULTRET; }
static inline int barf_lua_noref(void) { return LUA_NOREF; }
#endif
