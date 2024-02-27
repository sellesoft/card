package.path = package.path .. ";src/?.lua"
local game = require "game";
local raylib = require "raylib";

game:init(2);
raylib.InitWindow(800, 800, "card");
raylib.SetTargetFPS(raylib.GetMonitorRefreshRate(0));

while not raylib.WindowShouldClose() do
	game:update();
	raylib.BeginDrawing();
	raylib.ClearBackground(raylib.BLACK);
	game:draw();
	raylib.EndDrawing();
end

raylib.CloseWindow();