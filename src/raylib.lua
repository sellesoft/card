local ffi = require "ffi";
ffi.cdef [[
	typedef struct Color {
		unsigned char r;
		unsigned char g;
		unsigned char b;
		unsigned char a;
	} Color;

	void BeginDrawing();
	void ClearBackground(Color color);
	void CloseWindow();
	void DrawFPS(int posX, int posY);
	void DrawText(const char* text, int x, int y, int font_size, Color color);
	void EndDrawing();
	int  GetMonitorRefreshRate(int monitor);
	void InitWindow(int width, int height, const char* title);
	void SetTargetFPS(int fps);
	int  WindowShouldClose();
]]

raylib = raylib or {};
setmetatable(raylib, raylib);
raylib.new = ffi.new;
raylib.__index = function(self, key) return ffi.C[key]; end;

raylib.WHITE =      ffi.new("Color", 255, 255, 255, 255);
raylib.BLACK =      ffi.new("Color",   0,   0,   0, 255);
raylib.BLANK =      ffi.new("Color",   0,   0,   0,   0);
raylib.MAGENTA =    ffi.new("Color", 255,   0, 255, 255);
raylib.LIGHTGRAY =  ffi.new("Color", 200, 200, 200, 255);
raylib.GRAY =       ffi.new("Color", 130, 130, 130, 255);
raylib.DARKGRAY =   ffi.new("Color",  80,  80,  80, 255);
raylib.YELLOW =     ffi.new("Color", 253, 249,   0, 255);
raylib.GOLD =       ffi.new("Color", 255, 203,   0, 255);
raylib.ORANGE =     ffi.new("Color", 255, 161,   0, 255);
raylib.PINK =       ffi.new("Color", 255, 109, 194, 255);
raylib.RED =        ffi.new("Color", 230,  41,  55, 255);
raylib.MAROON =     ffi.new("Color", 190,  33,  55, 255);
raylib.GREEN =      ffi.new("Color",   0, 228,  48, 255);
raylib.LIME =       ffi.new("Color",   0, 158,  47, 255);
raylib.DARKGREEN =  ffi.new("Color",   0, 117,  44, 255);
raylib.SKYBLUE =    ffi.new("Color", 102, 191, 255, 255);
raylib.BLUE =       ffi.new("Color",   0, 121, 241, 255);
raylib.DARKBLUE =   ffi.new("Color",   0,  82, 172, 255);
raylib.PURPLE =     ffi.new("Color", 200, 122, 255, 255);
raylib.VIOLET =     ffi.new("Color", 135,  60, 190, 255);
raylib.DARKPURPLE = ffi.new("Color", 112,  31, 126, 255);
raylib.BEIGE =      ffi.new("Color", 211, 176, 131, 255);
raylib.BROWN =      ffi.new("Color", 127, 106,  79, 255);
raylib.DARKBROWN =  ffi.new("Color",  76,  63,  47, 255);

raylib.__newindex = function() error "raylib module is read-only" end;
return raylib;