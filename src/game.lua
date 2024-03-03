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
-- local dbg    = load_module "debugger"
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

local map_linear_range_clamped = function(in_start, in_end, out_start, out_end, x)
	return math.max(out_start, math.min(out_end, map_linear_range(in_start, in_end, out_start, out_end, x)))
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
	self.type = "game";
	self.menu = Menu.Main;
	self.data = {}
	self.settings = {};
	self.settings.player_count = 2;
end

game.
start = function(self)
	math.randomseed(os.time());
	game.update_coroutine = co.create(game.update_coroutine_definition)

	-- turn counter
	self.turn = 0
	-- phase counter, which are discrete parts of a turn
	self.phase = ""; -- pre_door -> loot_room | (combat -> run_away | defeat | victory_solo | victory_shared) -> charity

	-- create each player table
	self.players = {}
	for _=1,self.settings.player_count do
		local o = {}
		setmetatable(o, Player)
		o.in_hand = {};
		o.in_play = {};
		table.insert(self.players, o)
	end
	self.active_player = math.random(self.settings.player_count);
	log("created ", #self.players, " players");

	-- TODO(sushi) distrubute players properly when
	--             we actually have networking
	self.client_player = self.players[1]
	
	-- create door, treasure, and discard decks
	self.door_deck = cards:new_deck("group", "door");
	self.door_discard = {};
	self.treasure_deck = cards:new_deck("group", "treasure");
	self.treasure_discard = {};
	log("created door deck with ", #self.door_deck, " cards");
	log("created treasure deck with ", #self.treasure_deck, " cards");
	
	-- set of cards that have been 'played' in this phase
	self.field = {
		-- set of monsters and their enhancers active in combat
		monsters = {};
		monster_enhancers = {};
		
		-- set of players and their enhancers active in combat
		players = {};
		player_enhancers = {};
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



local ui
ui = {
	x  = 0; -- trackers for position so that we can easily communicate 
	y  = 0; -- between groups where we are 
	ex = 0; -- width and height EXTENTS
	ey = 0; -- aka where the current group rect ends

	mx = 0; -- mouse position
	my = 0;

	-- helpers for moving the cursor
	dx  = function(n) ui.x = ui.x + n end;
	dy  = function(n) ui.y = ui.y + n end;
	dxy = function(x,y) ui.x,ui.y = ui.x + x, ui.y + y end;

	group_stack = {};

	push_group = function(w, h)
		table.insert(ui.group_stack, {ui.x, ui.y, ui.ex, ui.ey})
		ui.ex = ui.x + w
		ui.ey = ui.y + h
	end;

	pop_group = function()
		local g = ui.group_stack[#ui.group_stack]
		table.remove(ui.group_stack, #ui.group_stack)
		ui.x,ui.y,ui.ex,ui.ey = g[1],g[2],g[3],g[4]
	end;

	-- prevent allocating two new tables in 
	-- every scoped_group
	scoped_group_result = { x = 0; y = 0; returns = nil; };

	scoped_group = function(w, h, f)
		-- save on stack instead 
		local x,y,ex,ey = ui.x,ui.y,ui.ex,ui.ey
		ui.ex, ui.ey = ui.x + w, ui.y + h
		ui.scoped_group_result.returns = {f(ui.ex-ui.x,ui.ey-ui.y)}
		ui.scoped_group_result.x = ui.x
		ui.scoped_group_result.y = ui.y
		ui.x,ui.y,ui.ex,ui.ey = x,y,ex,ey
		return ui.scoped_group_result
	end;

	-- returns a rect at the current position with given width and height
	rect = function(w,h)
		return {ui.x, ui.y, w, h}
	end;

	-- TODO(sushi) get style stack stuff to work properly 
	--             or honestly just wrap calls to raygui shit
	--             this looks so ugly right now

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

	set_bg_col = function(color)
		raygui.GuiSetStyle(raygui.DEFAULT, raygui.BACKGROUND_COLOR, color)
	end;

	set_text_height = function(h)
		raygui.GuiSetStyle(raygui.DEFAULT, raygui.TEXT_SIZE, h)
	end;

	set_raystyle = function(control, prop, val)
		raygui.GuiSetStyle(raygui[string.upper(control)], raygui[string.upper(prop)], val)
	end;

	-- arbitrary state used by various elements of ui
	state = {};

	lmouse_pressed  = function() return raylib.IsMouseButtonPressed(raylib.MOUSE_BUTTON_LEFT) end;
	lmouse_released = function() return raylib.IsMouseButtonReleased(raylib.MOUSE_BUTTON_LEFT) end;
	lmouse_down     = function() return raylib.IsMouseButtonDown(raylib.MOUSE_BUTTON_LEFT) end;

	rmouse_pressed  = function() return raylib.IsMouseButtonPressed(raylib.MOUSE_BUTTON_RIGHT) end;
	rmouse_released = function() return raylib.IsMouseButtonReleased(raylib.MOUSE_BUTTON_RIGHT) end;
	rmouse_down     = function() return raylib.IsMouseButtonDown(raylib.MOUSE_BUTTON_RIGHT) end;
}

reload.register("ui", "src/game.lua", ui)

ui.style = {}

-- central location for things related to styling the ui
-- NOTE(sushi) all style is wrapped in a function because 
--             it allows it to be reloaded by the reload module
--             later on constants should be pulled out
ui.
update_style = function()
	ui.x,ui.y,ui.ex,ui.ey = 0,0,0,0

	local style = ui.style
	style.card = {}
	style.card.h = game.window_height / 4
	style.card.w = style.card.h / 1.4
	style.card.border = math.max(1, math.floor(style.card.w / 32));

	style.card.colors = {
		door_face     = ui.colorint { 255, 241, 228, 255 };
		door_back     = ui.colorint { 211, 182, 160, 255 };
		treasure_face = ui.colorint { 250, 205, 150, 255 };
		treasure_back = ui.colorint { 149, 108,  72, 255 };
		border        = ui.colorint(raylib.DARKBROWN);
	}

	style.main_menu = {}
	style.main_menu.padding = 3

	style.field = {
		deck_spacing = 4;
		deck_group_padding = 3;
		bg_color = ui.colorint { 100, 125, 100, 255 };
		slide_time = 0.1;
	}
end

ui.
main_menu = function()
	local style = ui.style.main_menu
	ui.dxy(style.padding, style.padding)
	ui.scoped_group(game.window_width - 2*style.padding, game.window_height - 2*style.padding,
	function(w, h)

		local button_w = math.max(w / 4, 60)
		local button_h = math.max(h / 16, 20)
		local title_h = h / 4;
		local text_w = raylib.MeasureText("Players", button_h)

		game.player_count_ptr = game.player_count_ptr or ffi.new("int[1]", 2)

		ui.dx(10)

		ui.set_text_height(title_h)
		raygui.GuiLabel(ui.rect(w, title_h), "Munchkin");

		ui.dy(h/3)

		ui.set_text_height(button_h)
		if raygui.GuiLabelButton(ui.rect(button_w, button_h), "Play") ~= 0 then
			game:start()
			game.menu = Menu.Play
		end

		ui.dx(text_w)
		ui.dy(button_h)

		ui.set_raystyle("spinner", "text_padding", 10)
		if raygui.GuiSpinner(ui.rect(button_w-text_w, button_h), "Players", game.player_count_ptr, 2, 12, false) ~= 0 then
			game.settings.player_count = game.player_count_ptr[0]
		end

		ui.dx(-text_w)
		ui.dy(button_h)

		if raygui.GuiLabelButton(ui.rect(button_w, button_h), "Quit") ~= 0 then
			raylib.CloseWindow()
		end
	end)
end;

ui.
card_face = function(card, x, y)
	-- border
	local card_border = ui.style.card.border
	local border_color = raylib.ColorToInt(raylib.DARKBROWN);
	raygui.GuiSetStyle(raygui.DEFAULT, raygui.BACKGROUND_COLOR, border_color);
	raygui.GuiPanel(ui.rect(ui.style.card.w, ui.style.card.h), nil);

	-- background
	if card.group == "door" then
		ui.set_bg_col(ui.style.colors.door_face)
		raygui.GuiPanel({x + card_border, y + card_border, game.card_width - 2*card_border, ui.style.card.h - 2*card_border}, nil);
	elseif card.group == "treasure" then
		ui.set_bg_col(ui.style.colors.treasure_face)
		raygui.GuiPanel({x + card_border, y + card_border, ui.style.card.w - 2*card_border, ui.style.card.h - 2*card_border}, nil);
	end

	-- TODO other
end;

ui.
card_back = function(card, x, y)
	-- border
	local card_border = math.max(1, math.floor(ui.style.card.w / 32));
	local border_color = ui.style.card.colors.border;
	raygui.GuiSetStyle(raygui.DEFAULT, raygui.BACKGROUND_COLOR, border_color);
	raygui.GuiPanel({ui.x+x, ui.y+y, ui.style.card.w, ui.style.card.h}, nil);

	local rect = {
		ui.x + x + card_border,
		ui.y + y + card_border,
		ui.style.card.w - 2 * card_border,
		ui.style.card.h - 2 * card_border,
	}

	-- background
	if card.group == "door" then
		ui.set_bg_col(ui.style.card.colors.door_back)
		raygui.GuiPanel(rect, nil);
	elseif card.group == "treasure" then
		ui.set_bg_col(ui.style.card.colors.treasure_back)
		raygui.GuiPanel(rect, nil);
	end
end;

ui.
card_deck = function(name, cards, x, y)
	local card_count = cards and #cards or 0;
	if card_count == 0 then

	else
		ui.card_back(cards[1], x, y);
		if card_count > 1 then
			ui.card_back(cards[1], x+2, y+2);
		end
		if card_count > 2 then
			ui.card_back(cards[1], x+4, y+4);
		end
	end
end;

ui.
static_cards = function()
	ui.card_deck("Door Deck", game.door_deck);
	ui.card_deck("Treasure Deck", game.treasure_deck);
	-- draw_card_deck("Door Discard Deck", game.door_discard);
	-- draw_card_deck("Treasure Discard Deck", game.treasure_discard);
end;

-- draws the decks in the upperleft corner of the group
-- returns "door" or "treasure" if one of the decks
-- were clicked or nil if no input was recieved 
ui.decks = function()
	local style = ui.style

	local w = style.card.w * 2 + style.field.deck_spacing + 2 * style.field.deck_group_padding
	local h = style.card.h * 0.8

	ui.state.decks = ui.state.decks or {}
	local state = ui.state.decks

	local bg_h = h * 0.8

	ui.set_bg_col(style.field.bg_color)
	raygui.GuiPanel(ui.rect(w, bg_h), nil)

	local yinset = style.card.h * 0.2

	-- inset cards a bit into the top
	ui.dy(-yinset)

	ui.dx(style.field.deck_group_padding)

	state.door_timer = state.door_timer or 0
	state.treasure_timer = state.treasure_timer or 0

	local clicked

	local timer_delta = function(rect, timer, id)
		if ui.mx > rect[1] and ui.mx < rect[3] and
		   ui.my > rect[2] and ui.my < rect[4] then
		    if not clicked then
				if ui.lmouse_pressed() then
					clicked = id
				end
			end
			timer = timer + raygui.GetFrameTime()
		else
			timer = timer - raygui.GetFrameTime()
		end

		return math.max(0, math.min(style.field.slide_time, timer))
	end

	local door_y = map_linear_range_clamped(0, style.field.slide_time, 0, yinset, state.door_timer)
	local dr = {ui.x, door_y, ui.x+style.card.w, ui.y+style.card.h}
	state.door_timer = timer_delta(dr, state.door_timer, "door")
	ui.card_back({group="door"}, 0, door_y)

	ui.dx(style.card.w + style.field.deck_spacing)

	local treasure_y = map_linear_range_clamped(0, style.field.slide_time, 0, yinset, state.treasure_timer)
	local tr = {ui.x, treasure_y, ui.x+style.card.w, ui.y+style.card.h}
	state.treasure_timer = timer_delta(tr, state.treasure_timer, "treasure")
	ui.card_back({group="treasure"}, 0, treasure_y)

	return clicked, w, h
end

-- draws the 'field' which are cards that are in play 
-- and the decks
ui.
field = function(w, h)
	local style = ui.style

	-- background
	ui.set_bg_col(ui.colorint { 0, 30, 60, 255 })
	raygui.GuiPanel(ui.rect(w, h), nil)

	-- decks group 
	-- top-left cutoff and such
	local clicked, decks_w, decks_h = ui.decks()

	ui.x = 0
	ui.y = decks_h

	-- draw monsters
	
	raygui.GuiPanel(ui.rect(10,10), nil)
end;

ui.client_hand = function(w, h)
	local style = ui.style
	local player = game.client_player
	local n_cards = #player.in_hand

	local card_spacing = math.min(style.card.w + 2, w / n_cards)

	ui.dx(w-ui.style.card.w)

	for i=1,n_cards do
		ui.card_back({group="door"}, 0,0)
		ui.dx(-card_spacing)
	end
end

ui.game_start = function()

end

ui.pre_door = function()
	ui.scoped_group(game.window_width, game.window_height,
	function(w, h)
		local font_height = 30

		local text = "Kick Door"

		local button_padding = 3
		local button_w = 2 * button_padding + raylib.MeasureText(text, font_height)
		local button_h = font_height + button_padding * 2

		local shelf_padding = 3
		local shelf_h = ui.style.card.h * 0.8 + 2 * shelf_padding
		local shelf_w = w

		ui.scoped_group(shelf_w, h - shelf_h, ui.field)
		ui.y = game.window_height - ui.style.card.h
		ui.client_hand(game.window_width, game.window_height)
	end)
end;

-- make a protected call to ui to prevent
-- stopping the entire game if we hit an error
-- to better support reloading.
-- this should be used where needed, not on
-- every ui call
ui.protected = function(f, ...)
	local errhnd = function(msg)
		log:error("in protected ui: \n\t", msg)
		print(debug.traceback())
	end;

	local result = {xpcall(f, errhnd, ...)}
	if not result[1] then
		return
	end
	return table.unpack(result, 2)
end

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
		
		cards.shuffle_cards(game.treasure_deck)
		cards.shuffle_cards(game.door_deck)

		for i=1,game.settings.player_count do
			local player = game.players[i]
			for _=1,4 do
				table.insert(player.in_hand, table.remove(game.door_deck, #game.door_deck))
				table.insert(player.in_hand, table.remove(game.treasure_deck, #game.treasure_deck))
			end
			log:debug("gave player ", i, " ", #player.in_hand, " cards")
		end
	end

	::pre_door:: -- :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: pre_door
	do log:trace "--( pre door )--"
		while true do
			if ui.protected(ui.pre_door) then
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

	ui.mx = raylib.GetMouseX()
	ui.my = raylib.GetMouseY()

	ui.update_style()

	if self.menu == Menu.Main then
		ui.main_menu();
	elseif self.menu == Menu.Play then
		-- game update
		local all_good, result, traceback = protected_resume(game.update_coroutine, self)
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
