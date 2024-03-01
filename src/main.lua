package.path = package.path .. ";src/?.lua"
local game = require "game";
local raylib = require "raylib";

local traverse = require "luatraverse"

raylib.SetTraceLogLevel(raylib.LOG_ERROR)
raylib.InitWindow(600, 600, "card");
local monitor = raylib.GetCurrentMonitor();
local monitor_width = raylib.GetMonitorWidth(monitor);
local monitor_height = raylib.GetMonitorHeight(monitor);
raylib.SetWindowSize(monitor_width/2, monitor_height/2);
raylib.SetWindowPosition(monitor_width/4, monitor_height/4);
raylib.SetTargetFPS(raylib.GetMonitorRefreshRate(monitor));
raylib.SetConfigFlags(raylib.FLAG_WINDOW_RESIZABLE)
raylib.SetExitKey(raylib.KEY_NULL);

game:init();

while not raylib.WindowShouldClose() do
	raylib.BeginDrawing();
	raylib.ClearBackground(raylib.BLACK);
	if not game:update() then
		break
	end
	raylib.EndDrawing();
end

raylib.CloseWindow();
