-- 
--
-- Primary game loop and logic and such
--
-- 
local cards = require "cards"
local co = require "coroutine"
local dbg = require "debugger"
local ffi = require "ffi";
local Player = require "player"
local raylib = require "raylib";
local raygui = require "raygui";

-- primary game state table
local game = {};

local Menu = {
	Main = 0,
	Play = 1,
};

local log = function(...)
	io.write("game: ", ..., "\n")
end

local map_linear_range = function(in_start, in_end, out_start, out_end, x)
	local ind = in_end - in_start
	local outd = out_end - out_start
	return out_start + outd * ((x - in_start) / ind)
end

game.
init = function(self)
	self.menu = Menu.Main;
	self.player_count = 2;
end

game.
start = function(self)
	log("initializing")

	-- turn counter
	self.turn = 0
	-- phase counter, which are discrete parts of a turn
	self.phase = 0

	log("creating ", self.player_count, " players")

	-- create each player table
	self.players = {}
	for _=1,self.player_count do
		local o = {}
		setmetatable(o, Player)
		table.insert(self.players, o)
	end

	log("creating door and treasure decks")

	self.door_deck = {}
	self.treasure_deck = {}

	-- set of cards that have been 'played' in this phase
	self.field = {
		-- set of monsters active in combat
		monsters = {};
	}

	self.current_animation = nil
end

-- defs of different kinds of animations 
local animations = {
	turn_start = {
		slide_in_time = 0.25; -- seconds
		still_time = 1;
		slide_out_time = 0.25;

		init = function(self)
			local text = "Turn Start"
			local t = 0;
			local text_width = raylib.MeasureText(text, 20)

			return co.create(function()
				local x
				while t < self.slide_in_time do
					t = t + raylib.GetFrameTime()
					x = map_linear_range(0, self.slide_in_time, 0, (raylib.GetScreenWidth() - text_width) / 2, t)

					raylib.DrawText(text, x, 80, 20, raylib.WHITE)
					co.yield()
				end

				t = 0

				while t < self.still_time do
					t = t + raylib.GetFrameTime()
					raylib.DrawText(text, x, 80, 20, raylib.WHITE)
					co.yield()
				end

				t = 0

				while t < self.slide_out_time do
					t = t + raylib.GetFrameTime()
					x = map_linear_range(0, self.slide_out_time, (raylib.GetScreenWidth() - text_width) / 2, raylib.GetScreenWidth(), t)
					raylib.DrawText(text, x, 80, 20, raylib.WHITE)
					co.yield()
				end
			end)
		end
	}
}

local wait_for_animations = function(self)
	while self.current_animation do
		co.yield()
	end
end

local update_coroutine = co.create(function(self)
	::turn_start::
	do
		-- log("--( turn start )--")
		self.current_animation = animations.turn_start:init()
		wait_for_animations(self)

		-- get the active player 
		local active_player = self.players[#self.players % self.turn + 1]
	end
	goto turn_start
end)

game.
update = function(self)
	-- log(" --- ** update start ** ---")
	--raylib.DrawFPS(0, 0);
	
	local window_width = raylib.GetScreenWidth();
	local window_height = raylib.GetScreenHeight();
	
	if self.menu == Menu.Main then
		local title_height = window_height / 4;
		raygui.GuiSetStyle(raygui.DEFAULT, raygui.TEXT_SIZE, title_height);
		raygui.GuiLabel({10, 0, window_width, title_height}, "Munchkin");
		
		local button_width = math.max(window_width / 4, 60);
		local button_height = math.max(20, window_height / 16);
		local button_y_offset = window_height / 3;
		raygui.GuiSetStyle(raygui.DEFAULT, raygui.TEXT_SIZE, button_height);
		
		local play_button_rect = {10, button_y_offset, button_width, button_height};
		if raygui.GuiLabelButton(play_button_rect, "Play") ~= 0 then
			self.menu = Menu.Play;
		end
		
		button_y_offset = button_y_offset + button_height;
		self.player_count_ptr = self.player_count_ptr or ffi.new("int[1]", 2);
		local text_width = raylib.MeasureText("Players", button_height);
		local players_spinner_rect = {10 + text_width, button_y_offset, button_width - text_width, button_height};
		raygui.GuiSetStyle(raygui.SPINNER, raygui.TEXT_PADDING, 10);
		if raygui.GuiSpinner(players_spinner_rect, "Players", self.player_count_ptr, 2, 12, false) ~= 0 then
			self.player_count = self.player_count_ptr[0];
		end
		
		button_y_offset = button_y_offset + button_height;
		local quit_button_rect = {10, button_y_offset, button_width, button_height};
		if raygui.GuiLabelButton(quit_button_rect, "Quit") ~= 0 then
			raylib.CloseWindow();
			return;
		end
	elseif self.menu == Menu.Play then
		local all_good, message = co.resume(update_coroutine, self)
		if not all_good then
			log("coroutine error: "..message)
		end
		
		if self.current_animation then
			local all_good, message = co.resume(self.current_animation)
			if not all_good then
				-- TODO(sushi) not always an error, wrap lua's coroutine logic in stuff that
				--             automatically handles coroutines ending
				log("coroutine error: "..message)
				self.current_animation = nil
			end
		end
	end
	-- log(" *** -- update end -- *** ")
end

return game;
