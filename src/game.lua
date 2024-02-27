-- 
--
-- Primary game loop and logic and such
--
-- 
local cards = require "cards"
local raylib = require "raylib";
local raygui = require "raygui";
local Player = require "player"
local dbg = require "debugger"
local co = require "coroutine"

local log = function(...)
	io.write("game: ", ..., "\n")
end

-- primary game state table
local game = {}

local map_linear_range = function(in_start, in_end, out_start, out_end, x)
	local ind = in_end - in_start
	local outd = out_end - out_start
	return out_start + outd * ((x - in_start) / ind)
end

game.
init = function(self, n_players)
	log("initializing")

	-- turn counter
	self.turn = 0
	-- phase counter, which are discrete parts of a turn
	self.phase = 0

	log("creating ", n_players, " players")

	-- create each player table
	self.players = {}
	for _=1,n_players do
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
			local time = 0;
			local text_width = raylib.MeasureText(text, 20)

			local out = co.create(function()
				dbg()
				local x
				while true do
					log("animation")
					time = time + raylib.GetFrameTime()
					x = map_linear_range(0, self.slide_in_time, 0, (text_width - raylib.GetRenderWidth) / 2, time)

					raylib.DrawText(text, x, 0, 11, raylib.WHITE)
					co.yield()
				end
			end)
			dbg()
			return out
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
		log("--( turn start )--")
		self.current_animation = animations.turn_start:init()
		dbg()
		wait_for_animations(self)

		-- get the active player 
		local active_player = self.players[#self.players % self.turn + 1]
	end

	goto turn_start
end)

game.
update = function(self)
	-- log(" --- ** update start ** ---")

	local all_good, message = co.resume(update_coroutine, self)

	if not all_good then
		log("coroutine error: "..message)
	end

	-- log(" *** -- update end -- *** ")
end

game.
draw = function(self)
	raylib.DrawFPS(0, 0);

	if self.current_animation then
		local not_done = co.resume(self.current_animation)
		if not not_done then
			self.current_animation = nil
		end
	end
end

return game;
