local ffi = require "ffi"
ffi.cdef [[

	typedef struct Color {
		unsigned char r;        
		unsigned char g;        
		unsigned char b;        
		unsigned char a;        
	} Color;

	void init_window(int width, int height, const char* title);
	void close_window();
	void set_target_fps(int fps);
	int  window_should_close();
	void begin_drawing();
	void clear_background(Color color);
	void draw_text(const char* text, int x, int y, int font_size, Color color);
	void end_drawing();
]]
local ray = ffi.C

ray.init_window(800, 800, "card")

ray.set_target_fps(60)

while true do
	ray.begin_drawing()

	ray.clear_background({0,0,0,255})

	ray.draw_text("Hello!", 190, 200, 20, {255,255,255,255})

	ray.end_drawing()
end

ray.close_window()
