#include "raylib.h"
#define RAYGUI_PANEL_BORDER_WIDTH 0
#define RAYGUI_IMPLEMENTATION
#include "raygui.h"

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

// callback used when lua encounters an error
// that prints a trace
static int traceback(lua_State *L) {
    lua_getfield(L, LUA_GLOBALSINDEX, "debug");
    lua_getfield(L, -1, "traceback");
    lua_pushvalue(L, 1);
    lua_pushinteger(L, 2);
    lua_call(L, 2, 1);
    return 1;
}

int main(){
	// initialize lua
	
	lua_State* L = lua_open();
	luaL_openlibs(L); // load std lua libs
	
	// push traceback function onto the stack and reference it as the error handler
	// (the last argument to lua_pcall)
	lua_pushcfunction(L, traceback); 
	if (luaL_loadfile(L, "src/main.lua") || lua_pcall(L, 0, 0, lua_gettop(L) - 1)) {
		printf("%s\n", lua_tostring(L, -1));
		return 1;
	}

	return 0;
}
