-- 
--
-- Primary game loop and logic and such
--
-- 
local log = require("logger").register_module("game")

log "+-+-+- initializing game module -+-+-+"

log:push_indent(2)

local load_module = function(m)
	log("loading "..m.." module...")
	return require(m)
end

local ffi    = load_module "ffi"
local co     = load_module "coroutine"
local raylib = load_module "raylib"
local raygui = load_module "raygui"
local cards  = load_module "cards"
local Player = load_module "player"
local dbg    = load_module "debugger"
local reload = load_module "reload"

-- 'protected' coroutine resume
-- a co resume is always protected, but here we 
-- are wrapping it so we can get a proper traceback
-- when an error occurs inside of one.
local protected_resume = function(c, ...)
	local output = {coroutine.resume(c, ...)}
	if not output[1] then
		return false, output[2], debug.traceback(c)
	end
	return table.unpack(output)
end

-- primary game state table
local game = {}; --TODO split into server and client state

local Menu = {
	Main = 0,
	Play = 1,
};

local map_linear_range = function(in_start, in_end, out_start, out_end, x)
	local ind = in_end - in_start
	local outd = out_end - out_start
	return out_start + outd * ((x - in_start) / ind)
end



-- <<                                                                               >>
--    -----------------------------------------------------------------------------  
-- <<                                                                               >>
--
--              Game state initialization
--
-- <<                                                                               >>
--    -----------------------------------------------------------------------------  
-- <<                                                                               >>



game.
init = function(self)
	self.menu = Menu.Main;
	self.player_count = 2;
end

game.
start = function(self)
	game.update_coroutine = co.create(game.update_coroutine_definition)

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

	log("loading door and treasure decks")

	self.door_deck = cards.treasure_deck
	self.treasure_deck = cards.door_deck

	-- set of cards that have been 'played' in this phase
	self.field = {
		-- set of monsters active in combat
		monsters = {};
	}

	self.current_animation = nil
end



-- <<                                                                               >>
--    -----------------------------------------------------------------------------  
-- <<                                                                               >>
--
--              Animation
--
-- <<                                                                               >>
--    -----------------------------------------------------------------------------  
-- <<                                                                               >>



log:debug "creating animations"

-- Called by every animation when it is initialized.
-- Currently this just overrides whatever the current
-- animation is but later on I want to try queuing animations
-- and even sequencing groups of animations that play at the 
-- same time.
local register_animation = function(anim)
	game.animation = anim
end

-- Centralization of anim communication logic
local suspend_animation = function()
	co.yield(true)
end

local end_animation = function()
	co.yield(false)
end

-- defs of different kinds of animations 
local anim = {
	turn_start = {
		slide_in_time = 0.25; -- seconds
		still_time = 1;
		slide_out_time = 0.25;

		init = function(self)
			register_animation(self)

			local text = "Turn Start"
			local t = 0;
			local text_width = raylib.MeasureText(text, 20)

			return co.create(function()
				local x
				while t < self.slide_in_time do
					t = t + raylib.GetFrameTime()
					x = map_linear_range(0, self.slide_in_time, 0, (raylib.GetScreenWidth() - text_width) / 2, t)

					raylib.DrawText(text, x, 80, 20, raylib.WHITE)
					suspend_animation()
				end

				t = 0

				while t < self.still_time do
					t = t + raylib.GetFrameTime()
					raylib.DrawText(text, x, 80, 20, raylib.WHITE)
					suspend_animation()
				end

				t = 0

				while t < self.slide_out_time do
					t = t + raylib.GetFrameTime()
					x = map_linear_range(0, self.slide_out_time, (raylib.GetScreenWidth() - text_width) / 2, raylib.GetScreenWidth(), t)
					raylib.DrawText(text, x, 80, 20, raylib.WHITE)
					suspend_animation()
				end

				end_animation()
			end)
		end
	}
}



-- <<                                                                               >>
--    -----------------------------------------------------------------------------  
-- <<                                                                               >>
--
--              Game state
--
-- <<                                                                               >>
--    -----------------------------------------------------------------------------  
-- <<                                                                               >>



-- Set everytime we start the game since we need to 
-- recreate the coroutine everytime. If we don't do 
-- this trying to start a game after going back to 
-- the main menu fails.
local update_coroutine

local ui
ui = {
	style_value_stack = {};

	push_style_value = function(style, val)
		table.insert(ui.style_value_stack, {style=style, val=raygui.GuiGetStyle(raygui.DEFAULT, raygui[style])})
		raygui.GuiSetStyle(raygui.DEFAULT, raygui[style], val)
	end;

	pop_style_value = function()
		local elem = ui.style_value_stack[#ui.style_value_stack]
		table.remove(ui.style_value_stack, #ui.style_value_stack)
		raygui.GuiSetStyle(raygui.DEFAULT, raygui[elem.style], elem.val)
	end;

	colorint = function(x)
		return raylib.ColorToInt(x)
	end;

	main_menu = function()
		local title_height = game.window_height / 4;
		raygui.GuiSetStyle(raygui.DEFAULT, raygui.TEXT_SIZE, title_height);
		raygui.GuiLabel({10, 0, game.window_width, title_height}, "Munchkin");

		local button_width = math.max(game.window_width / 4, 60);
		local button_height = math.max(20, game.window_height / 16);
		local button_y_offset = game.window_height / 3;
		raygui.GuiSetStyle(raygui.DEFAULT, raygui.TEXT_SIZE, button_height);

		local play_button_rect = {10, button_y_offset, button_width, button_height};
		if raygui.GuiLabelButton(play_button_rect, "Play") ~= 0 then
			game:start()
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
	end;

	card_face = function(card, x, y)
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
	end;

	card_back = function(card, x, y)
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
	end;

	card_deck = function(name, cards, x, y)
		local card_count = cards and #cards or 0;
		if card_count == 0 then

		else
			ui.draw_card_back(cards[1], x, y);
			if card_count > 1 then
				ui.card_back(cards[1], x+2, y+2);
			end
			if card_count > 2 then
				ui.card_back(cards[1], x+4, y+4);
			end
		end
	end;

	static_cards = function()
		ui.card_deck("Door Deck", game.door_deck);
		ui.card_deck("Treasure Deck", game.treasure_deck);
		-- draw_card_deck("Discard Deck", game.door_deck);
	end;

	kick_door_button = function()
		local text = "Kick Door"
		local font_height =  30
		local padding = 3
		local w = 2 * padding + raylib.MeasureText(text, font_height)
		local h = font_height + padding * 2
		local x = raylib.GetScreenWidth() - w - 50
		local y = raylib.GetScreenHeight() - h - 50

		ui.push_style_value("TEXT_SIZE", font_height)

		ui.push_style_value("BACKGROUND_COLOR", ui.colorint{0,0,0,255})

		raygui.GuiSetStyle(raygui.DEFAULT, raygui.TEXT_SIZE, font_height);

		ui.pop_style_value()
		ui.pop_style_value()

		return raygui.GuiButton({x, y, w, h}, text) ~= 0
	end;
}

reload.register("ui", "src/game.lua", ui)

-- Primary game update loop as a coroutine.
-- This allows us to avoid explicitly storing 
-- state somewhere and having to go through a giant
-- if/else ladder. 
-- When the coroutine yields it returns 'true' if the game
-- is to continue properly. 
game.
update_coroutine_definition = function(self)
	local active_player;
	local win_w, win_h;


-- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- 
--
--  Helpers 
--
-- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- 


	-- Common yield wrapper so if we ever want to change how we
	-- handle this its easy.
	-- On yielding, update reports 'true' if everything went ok.
	-- Otherwise we return false and the coroutine is killed.
	--
	-- This is also used to gather state needed every update
	-- regardless of where yielding occured.
	local suspend_update = function()
		co.yield(true)
		-- on reentry gather state
		active_player = self.players[#self.players % self.turn + 1]
		win_w = raylib.GetScreenWidth()
		win_h = raylib.GetScreenHeight()
	end

	-- Suspends game updates until animations finish.
	local wait_for_animations = function()
		while self.current_animation do
			suspend_update()
		end
	end


-- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- 
--
--  Game Logic 
--
-- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- 

	
	::game_start:: -- :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: game_start
	do log:trace "-- ( game start ) --"
		-- distribute initial cards and such to each player
		
	end

	::turn_start:: -- :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: turn_start
	do log:trace "--( turn start )--"

		self.current_animation = anim.turn_start:init()
		wait_for_animations()

		while true do
			if ui.kick_door_button() then
				break
			end
			suspend_update()
		end
	end


	::kick_door:: -- :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: kick_door
	do log:trace " --( kick door )-- "
		
	end
end

game.
update = function(self)
	log:trace " --- ** update start ** ---"

	if raylib.IsKeyPressed(raylib.KEY_F5) then
		reload("ui")
	end

	game.window_width = raylib.GetScreenWidth();
	game.window_height = raylib.GetScreenHeight();
	game.card_height = game.window_height / 4;
	game.card_width = game.card_height / 1.4;

	if self.menu == Menu.Main then
		ui.main_menu();
	elseif self.menu == Menu.Play then
		-- game update
		local all_good, result, traceback = protected_resume(update_coroutine, self)
		if not all_good then
			log:error("in update_coroutine: ", result)
			print(traceback)
			return false
		else
			if not result then
				-- Game reports that it is finished, return to menu.
				self.menu = Menu.Main
			end
		end

		-- draw all static cards (not being animated)
		--draw_static_cards();
		ui.card_back({group="door"},  50, 50);
		ui.card_back({group="treasure"}, 250, 50);

		-- draw the ongoing animation on top of static cards
		if self.current_animation then
			local all_good, result, traceback = protected_resume(self.current_animation)
			if not all_good then
				log:error("in animation coroutine: ", result)
				print(traceback)
				return false
			else
				if not result then
					self.current_animation = nil
				end
			end
		end
	end

	log:trace "--- ** update end ** ---"
	return true
end

log:pop_indent(2)
log "+-+-+- finished game module -+-+-+"

return game;
