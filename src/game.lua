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
local game = {}; --TODO split into server and client state

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

local draw_main_menu = function()
	local title_height = game.window_height / 4;
	raygui.GuiSetStyle(raygui.DEFAULT, raygui.TEXT_SIZE, title_height);
	raygui.GuiLabel({10, 0, game.window_width, title_height}, "Munchkin");
	
	local button_width = math.max(game.window_width / 4, 60);
	local button_height = math.max(20, game.window_height / 16);
	local button_y_offset = game.window_height / 3;
	raygui.GuiSetStyle(raygui.DEFAULT, raygui.TEXT_SIZE, button_height);
	
	local play_button_rect = {10, button_y_offset, button_width, button_height};
	if raygui.GuiLabelButton(play_button_rect, "Play") ~= 0 then
		game.menu = Menu.Play;
	end
	
	button_y_offset = button_y_offset + button_height;
	game.player_count_ptr = game.player_count_ptr or ffi.new("int[1]", 2);
	local text_width = raylib.MeasureText("Players", button_height);
	local players_spinner_rect = {10 + text_width, button_y_offset, button_width - text_width, button_height};
	raygui.GuiSetStyle(raygui.SPINNER, raygui.TEXT_PADDING, 10);
	if raygui.GuiSpinner(players_spinner_rect, "Players", game.player_count_ptr, 2, 12, false) ~= 0 then
		game.player_count = game.player_count_ptr[0];
	end
	
	button_y_offset = button_y_offset + button_height;
	local quit_button_rect = {10, button_y_offset, button_width, button_height};
	if raygui.GuiLabelButton(quit_button_rect, "Quit") ~= 0 then
		raylib.CloseWindow();
	end
end

--TODO replace this with an image
local draw_card_face = function(card, x, y)
	-- border
	local card_border = math.max(1, math.floor(game.card_width / 32));
	local border_color = raylib.ColorToInt(raylib.DARKBROWN);
	raygui.GuiSetStyle(raygui.DEFAULT, raygui.BACKGROUND_COLOR, border_color);
	raygui.GuiPanel({x, y, game.card_width, game.card_height}, nil);
	
	-- background
	if card.group == "door" then
		raygui.GuiSetStyle(raygui.DEFAULT, raygui.BACKGROUND_COLOR, raylib.ColorToInt({255, 241, 228, 255}));
		raygui.GuiPanel({x + card_border, y + card_border, game.card_width - 2*card_border, game.card_height - 2*card_border}, nil);
	elseif card.group == "treasure" then
		raygui.GuiSetStyle(raygui.DEFAULT, raygui.BACKGROUND_COLOR, raylib.ColorToInt({250, 205, 150, 255}));
		raygui.GuiPanel({x + card_border, y + card_border, game.card_width - 2*card_border, game.card_height - 2*card_border}, nil);
	end
	
	-- TODO other
end


--TODO replace this with an image
local draw_card_back = function(card, x, y)
	-- border
	local card_border = math.max(1, math.floor(game.card_width / 32));
	local border_color = raylib.ColorToInt(raylib.DARKBROWN);
	raygui.GuiSetStyle(raygui.DEFAULT, raygui.BACKGROUND_COLOR, border_color);
	raygui.GuiPanel({x, y, game.card_width, game.card_height}, nil);
	
	-- background
	if card.group == "door" then
		raygui.GuiSetStyle(raygui.DEFAULT, raygui.BACKGROUND_COLOR, raylib.ColorToInt({211, 182, 160, 255}));
		raygui.GuiPanel({x + card_border, y + card_border, game.card_width - 2*card_border, game.card_height - 2*card_border}, nil);
	elseif card.group == "treasure" then
		raygui.GuiSetStyle(raygui.DEFAULT, raygui.BACKGROUND_COLOR, raylib.ColorToInt({149, 108, 72, 255}));
		raygui.GuiPanel({x + card_border, y + card_border, game.card_width - 2*card_border, game.card_height - 2*card_border}, nil);
	end
end

local draw_card_deck = function(name, cards, x, y)
	local card_count = cards and #cards or 0;
	if card_count == 0 then
		
	else
		draw_card_back(cards[1], x, y);
		if card_count > 1 then
			draw_card_back(cards[1], x+2, y+2);
		end
		if card_count > 2 then
			draw_card_back(cards[1], x+4, y+4);
		end
	end
end

local draw_static_cards = function()
	draw_card_deck("Door Deck", game.door_deck);
	draw_card_deck("Treasure Deck", game.treasure_deck);
	-- draw_card_deck("Discard Deck", game.door_deck);
end

game.
update = function(self)
	-- log(" --- ** update start ** ---")
	game.window_width = raylib.GetScreenWidth();
	game.window_height = raylib.GetScreenHeight();
	game.card_height = game.window_height / 4;
	game.card_width = game.card_height / 1.4;
	
	if self.menu == Menu.Main then
		draw_main_menu();
	elseif self.menu == Menu.Play then
		-- game update
		local all_good, message = co.resume(update_coroutine, self)
		if not all_good then
			log("coroutine error: "..message)
		end
		
		-- draw all static cards (not being animated)
		--draw_static_cards();
		draw_card_back({group="door"},  50, 50);
		draw_card_back({group="treasure"}, 250, 50);
		
		-- draw the ongoing animation on top of static cards
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
