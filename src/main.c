#include "raylib.h"

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

void init_window(int width, int height, const char* title) { InitWindow(width, height, title); }
void close_window() { CloseWindow(); }
void set_target_fps(int fps) { SetTargetFPS(fps); }
int  window_should_close() { return WindowShouldClose(); }
void begin_drawing() { BeginDrawing(); }
void clear_background(Color color) { ClearBackground(color); }
void draw_text(const char* text, int x, int y, int font_size, Color color) { DrawText(text, x, y, font_size, color); }
void end_drawing() { EndDrawing(); }

int main() {
	// initialize lua
	
	lua_State* L = lua_open();
	luaL_openlibs(L); // load std lua libs
	
	if (luaL_loadfile(L, "src/test.lua") || lua_pcall(L, 0, 0, 0)) {
		printf("%s\n", lua_tostring(L, -1));
		return 1;
	}

	return 0;
}
