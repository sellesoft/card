#include "raylib.h"
#define RAYGUI_IMPLEMENTATION
#include "raygui.h"

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

int main(){
	// initialize lua
	
	lua_State* L = lua_open();
	luaL_openlibs(L); // load std lua libs
	
	if (luaL_loadfile(L, "src/main.lua") || lua_pcall(L, 0, 0, 0)) {
		printf("%s\n", lua_tostring(L, -1));
		return 1;
	}

	return 0;
}
