-- 
-- 
-- Card definitions
-- These should eventually be hot-reloadable somehow, but for now 
-- I'm just going to implement them statically. 
--
-- The game is, at the moment, designed so that cards actually control
-- much of the logic. 
--
--

local Player = require "player"

-- base card type, contains defaults when 
-- deriving types don't implement basic data/functionality
local Card = {
	name = "** unnamed card **";
	desc = "** undescribed card **";
	type = "** untyped card **";

	-- overridable function items may use 
	-- to put restrictions on what can use them.
	-- by default a card can be played at any time.
	can_play = function(self, player) return true end;

	-- various 'bonuses' this card gives. All cards alter
	-- the behavior of the player via this table!
	bonuses = {
		-- added to a player's combat value
		combat = nil;

		-- added to a player's run away roll
		run_away = nil;
	};

	-- various callbacks queried throughout the game
	actions = {
		
	};
}
Card.__index = Card
-- setup __call to redirect to the 'new' function that 
-- children of this type implement. This allows us to 
-- write something like 
-- Race {...}
-- rather than 
-- Race.new {...}
Card.__call = function(self, tbl) return self:new(tbl) end

local Race = { type = "race" }
Race.__index = Race
setmetatable(Race, Card)

Race.
new = function(_, tbl)
	local o = {}
	for k,v in pairs(tbl) do
		o[k] = v
	end
	setmetatable(o, Race)
end

local races = {
	dwarf = Race {
		name = "Dwarf";
		desc = "You can carry any number of Big items. You can have 6 cards in your hand.";
		bonuses = {
			max_big_items = 1000; -- arbitrarily large number since we don't have inf
			max_in_play = 1;
		};
	};
	elf = Race {
		name = "Elf";
		desc = "+1 to Run Away. You go up 1 Level for every monster you help someone else kill.";
		bonuses = { run_away = 1; };
		on_combat_kill = function(game, player)
			if game.active_player ~= player then
				player:grant_levels(1)
			end
		end;
	};
}

local Class = {
	type = "class";
	abilities = {};
}
Class.__index = Class
setmetatable(Class, Card)

Class.
new = function(_, tbl)
	local o = {}
	for k,v in pairs(tbl) do
		o[k] = v
	end
	setmetatable(o, Class)
end

local classes = {
	wizard = Class {
		name = "Wizard";
		abilities = {
			{
				name = "Flight Spell";
				desc = "You may discard up to three cards after rolling the die to Run Away; each one gives you a +1 bonus to flee.";
				phases = "runaway";
				can_use = function(game)
					if game.phase == "run_away" then return true end
				end;
				bonuses = {
					run_away = function(player)
						return player:discard_up_to_n_cards(3)
					end;
				};
			};
			{
				name = "Charm Spell";
				desc = "You may discard your whole hand (minimum 3 cards) to charm a single Monster instead of fighting it. Discard the Monster and take its Treasure, but don't gain levels. If there are other monsters in the combat, fight them normally.";
				phases = "combat";
				can_use = function(game, player)
					if game.phase == "combat" and #player.hand >= 3 then
						return true
					end
					return false
				end;
				action = function(game, player)
					player:discard_hand()
					local monster = player:choose_monster(game)
					player:grant_treasure(monster.treasure)
					game:remove_from_combat(monster)
				end;
			};
		};
	};
}

local Monster = {
	type = "monster";

	-- TODO(sushi) remove and use formatting inside of 'desc' to do this instead
	good = "** missing Good Stuff text **";
	bad  = "** missing Bad Stuff text **";
	treasures = 0;

	-- calc this monster's strength based on the given player
	-- this must be overridden by implementations of Monster
	calc_strength = function(self, game, player) error("encountered monster card '"..self.name.."' with unimplemented 'calc_strength' function.") end;

	-- behavior upon victory of this monster. 'player' is the primary 
	-- player that was first engaged with the monster (eg. the one that 
	-- kicked down the door or summoned it) and 'helpers' are players 
	-- that decided to help. 
	-- this must be overridden by implementations of Monster
	on_victory = function(self, game, player, helpers) error("encountered monster card '"..self.name.."' with unimplemeneted 'on_victory' function.") end;
}
Monster.__index = Monster
setmetatable(Monster, Card)

Monster.
new = function(_, tbl)
	local o = {}
	for k,v in pairs(tbl) do
		o[k] = v
	end
	o.enhancers = {}
	setmetatable(o, Monster)
end

-- add a monster enhancer card to this 
-- monster object
Monster.
add_enhancer = function(self, x)
	table.insert(self.enhancers, x)
end

-- calculate the total effect monster enhancers 
-- have on this monster
Monster.
calc_enhancer_effect = function(self)
	local sum = 0
	for _,enhancer in ipairs(self.enhancers) do
		sum = sum + enhancer.effect
	end
	return sum
end

local MonsterEnhancer = {
	type = "enhancer";
	effect = 0;

	-- all monster enhancers can only be played
	-- during combat
	can_play = function(self, game) return game.phase == "combat" end;
}
MonsterEnhancer.__index = MonsterEnhancer
setmetatable(MonsterEnhancer, Card)

MonsterEnhancer.
new = function(_, tbl)
	local o = {}
	for k,v in pairs(tbl) do
		o[k] = v
	end
	setmetatable(o, MonsterEnhancer)
	return o
end

local Item = {
	type = "item";
	value = -1;
}
Item.__index = Item
setmetatable(Item, Card)

Item.
new = function(_, tbl)
	local o = {}
	for k,v in pairs(tbl) do
		o[k] = v
	end
	setmetatable(o, Item)
	return o
end

local door_deck = {
	Monster {
		name = "3,872 Orcs";
		good = "If this enemy is defeated, the Player gains 1 level and 3 treasures.";
		bad  = "Due to ancient grudges, the 3,872 Orcs are level 16 (+6) against Dwarves. If this enemy is victorious, the Player must roll a die. On a 1 or 2, the 3,872 Orcs stomp the Player to death. On a 3 or higher, the Player loses however many Levels the die shows.";
		treasures = 3;

		calc_strength = function(self, player)
			local sum = 10
			if player.race == "dwarf" then
				sum = sum + 6
			end
			return sum + self:calc_enhancer_effect()
		end;

		on_victory = function(self, game, player, helpers)
			local effect = function(x)
				local roll = x:roll_die()
				if roll <= 2 then
					x:die()
				else
					x:lose_levels(roll)
				end
			end

			effect(player)
			for helper in helpers do
				effect(helper)
			end
		end;
	};
	MonsterEnhancer {
		name = "Baby";
		desc = "-5 to monster. Play during combat. If the monster is defeated, draw 1 fewer Treasure.";
		can_play = function(game)
			if game.phase == "combat" then return true end
		end;
		effect = -5;
	};
	races.elf,
}

local treasure_deck = {
	Item {
		name = "Tuba of Charm";
		slot = "one hand";
		big = true;
		value = 300;
		desc = "This melodious instrument captivates your foes, giving you +3 to Run Away. If you successfully escape combat, snag a face-down Treasure on your way out.";

		bonuses = { run_away = 3 };

		actions = {
			on_run_away = function(player, successful)
				if successful then
					player:draw_treasure()
				end
			end
		}
	};
	Item {
		name = "Huge Rock";
		slot = "two hands";
		big = true;
		value = 0;

		bonuses = { combat = 3 };
	};
	Item {
		name = "Pointy Hat of Power";
		type = "item";
		slot = "headgear";
		value = 400;
		class = classes.wizard;

		bonuses = { combat = 3 };
	};
}
