#ifndef VBAR_LUA_HELPERS_H
#define VBAR_LUA_HELPERS_H
#include <lua.h>
static inline int vbar_lua_registryindex(void) { return LUA_REGISTRYINDEX; }
static inline int vbar_lua_multret(void) { return LUA_MULTRET; }
#endif
