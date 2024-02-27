-- [[
--
--    Primary game loop and logic and such
--
-- ]]

local log = function(...)
	io.write("game: ", ..., "\n")
end

local cards = require "cards"
local raylib = require "raylib";

-- primary game state table
local game = {}

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
		table.insert(self.players, {
			level = 1;
			cards = {};
		})
	end

	log("creating door and treasure decks")

	self.door_deck = {}
	self.treasure_deck = {}

	-- set of cards that have been 'played' in this phase
	self.field = {
		-- set of monsters active in combat
		monsters = {};
	}
end

game.
update = function(self)

end

game.
draw = function(self)
	raylib.DrawFPS(0, 0);
end

return game;