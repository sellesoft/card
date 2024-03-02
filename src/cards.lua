-- 
-- 
-- Card Types and Utils
-- These should eventually be hot-reloadable somehow, but for now 
-- I'm just going to implement them statically.
--
-- The game is, at the moment, designed so that cards actually control
-- much of the logic. In fact all of the logic involving the interactions
-- of cards and players should stay contained in this file for now so 
-- that its clear where it all is.
--
--
local Player = require "player";
local log = require("logger").register_module("cards");
local cards = {};


-- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- 
--
--  @Card
--
-- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- 


-- base card type, contains defaults when 
-- deriving types don't implement basic data/functionality
local Card = {
	group = "** ungrouped card **"; -- door, treasure
	type = "** untyped card **"; -- race, class, monster, enhancer, item, goal, curse
	name = "** unnamed card **";
	desc = "** undescribed card **";
	deck_count = 1; -- how many of this card are in the deck
	
	
	-- bonuses added to value checks while a card is in play
	-- default: function(game, player, args) return 0; end;
	-----------------------------------------------
	-- added to a player's combat value
	bonus_combat = nil;

	-- added to a player's run away roll
	bonus_run_away = nil;
	-----------------------------------------------
	
	
	-- automatic triggers when while a card is in play
	-- default: function(game, player, args) return nil; end;
	-----------------------------------------------
	-- called when a player wins combat
	on_victory = nil;
	
	-- called when a player loses combat
	on_defeat = nil;
	
	-- called when a player attempts to run away from combat
	on_run_away = nil;
	-----------------------------------------------
	
	
	-- checks to see if an action can be peformed by a player
	-- default: function(game, player, args) return true; end;
	-----------------------------------------------
	-- whether or not this card can be played
	can_play = nil;

	-- whether or not this card can be discarded
	can_discard = nil;
	
	-- whether or not this card can be used while already in play
	can_use = nil;
	-----------------------------------------------
	
	
	-- actions triggered by the game or a player
	-- default: function(game, player, args) return nil; end;
	-----------------------------------------------
	-- called when a player plays this card
	play = nil;
	
	-- called when a player discards this card
	discard = nil;
	
	-- called when a player uses this card while it's in play
	use = nil;
	-----------------------------------------------
}
Card.__index = Card
-- setup __call to redirect to the 'new' function that 
-- children of this type implement. This allows us to 
-- write something like Race {...} rather than Race.new {...}
Card.__call = function(self, tbl) return self:new(tbl) end

-- removes the first card with 'name' in the 'src' table
-- returns the card that was removed
local remove_card = function(src, name)
	for idx,card in iparis(src) do
		if card.name == name then
			return table.remove(src, idx);
		end
	end
	return nil;
end

-- moves the first card with 'name' from the 'src' table to the 'dst' table
local move_card = function(src, dst, name)
	card = remove_card(src, name);
	if card then
		table.insert(dst, card);
	end
	return card ~= nil;
end


-- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- 
--
--  @Race
--
-- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- 


local Race = {
	type = "race";
	group = "door";
	
	can_play = function(game, player, args)
		return game.active_player == player;
	end
}
Race.__index = Race;
setmetatable(Race, Card);
Race.new = function(_, tbl) local o = {}; for k,v in pairs(tbl) do o[k] = v; end setmetatable(o, Race); end

cards.
races = {
	Race { name = "Dwarf";
		desc = "You can carry any number of Big items. You can have 6 cards in your hand.";
		deck_count = 3;
		play = function(game, player, args)
			player.max_big_items = 1000; -- arbitrarily large number since we don't have inf
			player.max_in_play = 6;
		end;
		discard = function(game, player, args)
			player.max_big_items = nil;
			player.max_in_play = nil;
		end;
	};
	
	Race { name = "Elf";
		desc = "+1 to Run Away. You go up 1 Level for every monster you help someone else kill.";
		deck_count = 3;
		bonus_run_away = function(game, player, args)
			return 1;
		end;
		on_victory = function(game, player, args)
			if game.active_player ~= player then
				player:give_levels(1);
			end
		end;
	};
	
	Race { name = "Half-Breed";
		desc = "You may have two race cards, and have all of the advantages and disadvantages of each. Or you may have one race card and have all of its advantages and none of its disadvantages (for example, monsters that hate Elves will have on bonus against a Half-elf). Lose this card if you lose all your race card(s).";
		deck_count = 2;
		play = function(game, player, args)
			player.allow_second_race = true;
		end;
		discard = function(game, player, args)
			player.allow_second_race = nil;
		end;
	};
	
	Race { name = "Halfling";
		desc = "You may sell one Item each turn for double the price (other Items are at normal price). If you fail your initial Run Away roll, you may discard a card and try once more.";
		deck_count = 3;
		can_use = function(game, player, args)
			return player.run_away_attempts == 1 and (#player.in_hand > 0 or #player.in_play > 0);
		end;
		play = function(game, player, card, args)
			player.double_first_sell = true;
		end;
		discard = function(game, player, args)
			player.double_first_sell = nil;
		end;
		use = function(game, player, args)
			player.max_run_away_attempts = player.max_run_away_attempts + 1;
		end;
	};
}


-- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- 
--
--  @Class
--
-- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- 


local Class = {
	type = "class";
	group = "door";
	abilities = {};
}
Class.__index = Class;
setmetatable(Class, Card);
Class.new = function(_, tbl) local o = {}; for k,v in pairs(tbl) do o[k] = v; end setmetatable(o, Class); end

cards.
classes = {
	Class {
		name = "Wizard";
		abilities = {
			{ name = "Flight Spell";
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
			{ name = "Charm Spell";
				desc = "You may discard your whole hand (minimum 3 cards) to charm a single Monster instead of fighting it. Discard the Monster and take its Treasure, but don't gain levels. If there are other monsters in the combat, fight them normally.";
				phases = "combat";
				can_use = function(game, player)
					if game.phase == "combat" and #player.hand >= 3 then
						return true
					end
					return false
				end;
				action = function(game, player)
					player:discard_hand();
					local monster = player:choose_monster(game);
					player:draw_treasure(monster.treasure);
					game:remove_from_combat(monster);
				end;
			};
		};
	};
	
	-- TODO classes
}


-- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- 
--
--  @Monster
--
-- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- 


local Monster = {
	type = "monster";
	group = "door";

	-- TODO(sushi) remove and use formatting inside of 'desc' to do this instead
	good = "** missing Good Stuff text **";
	bad  = "** missing Bad Stuff text **";
	treasures = 0;
	levels = 1;
	enhancers = {};

	-- calc this monster's strength based on the given player
	-- this must be overridden by implementations of Monster
	calc_strength = function(self, game, player) error("encountered monster card '"..self.name.."' with unimplemented 'calc_strength' function.") end;

	-- behavior upon victory of this monster. 'player' is the primary 
	-- player that was first engaged with the monster (eg. the one that 
	-- kicked down the door or summoned it) and 'helpers' are players 
	-- that decided to help. 
	-- this must be overridden by implementations of Monster
	on_victory = function(self, game, player, helpers) error("encountered monster card '"..self.name.."' with unimplemeneted 'on_victory' function.") end;
	
	-- behavior upon encountering this monster. 'player' is any player
	-- entering the combat encounter. Returns true if the player is
	-- added as a helper to the combat encounter or false otherwise.
	-- this is optional by implementations of Monster
	on_encounter = function(self, game, player) return true; end;
}
Monster.__index = Monster;
setmetatable(Monster, Card);
Monster.new = function(_, tbl) local o = {}; for k,v in pairs(tbl) do o[k] = v; end setmetatable(o, Monster); end

-- add an enhancer card to this monster object
Monster.
add_enhancer = function(self, x)
	table.insert(self.enhancers, x);
end

-- calculate the total effect enhancers have on this monster
Monster.
calc_enhancer_effect = function(self)
	local sum = 0;
	for _,enhancer in ipairs(self.enhancers) do
		sum = sum + enhancer.effect;
	end
	return sum;
end

cards.
monsters = {
	Monster { name = "3,872 Orcs";
		good = "If this enemy is defeated, the Player gains 1 level and 3 treasures.";
		bad  = "Due to ancient grudges, the 3,872 Orcs are level 16 (+6) against Dwarves. If this enemy is victorious, the Player must roll a die. On a 1 or 2, the 3,872 Orcs stomp the Player to death. On a 3 or higher, the Player loses however many Levels the die shows.";
		treasures = 3;

		calc_strength = function(self, game, player)
			if player.race == "dwarf" then
				return 16 + self:calc_enhancer_effect();
			else
				return 10 + self:calc_enhancer_effect();
			end
		end;

		on_victory = function(self, game, player, helpers)
			local effect = function(x)
				local roll = x:roll_die();
				if roll <= 2 then
					x:full_reset();
				else
					x:lose_levels(roll);
				end
			end

			effect(player);
			for helper in helpers do
				effect(helper);
			end
		end;
	};
	
	Monster { name = "Amazon";
		good = "The Amazon does not attack female Players. Instead, she gives them 1 Treasure. If this enemy is defeated, the Player gains 1 Level and 2 Treasures.";
		bad = "If this enemy is victorious, the male Player has been defeated by a woman, therefore losing his macho munchkin pride. The Player also loses his Class(es). However, if the Player has no Class, he loses 3 Levels instead.";
		treasures = 2;
		
		calc_strength = function(self, game, player)
			return 8 + self:calc_enhancer_effect();
		end;
		
		on_victory = function(self, game, player, helpers)
			if player.class then
				player.class = nil;
				player.class2 = nil;
				player:discard_card("Super Munchkin");
			else
				player:lose_levels(3);
			end
		end;
		
		on_encounter = function(self, game, player)
			if player.gender == "female" then
				player:draw_treasures(1);
				return false;
			else
				return true;
			end
		end;
	};
	
	-- TODO monsters
}


-- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- 
--
--  @Enhancer
--
-- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- 


local Enhancer = {
	type = "enhancer";
	group = "treasure";
	combat_effect = 0;
	reward_effect = 0;
	monster_target_only = false;
}
Enhancer.__index = Enhancer;
setmetatable(Enhancer, Card);
Enhancer.new = function(_, tbl) local o = {}; for k,v in pairs(tbl) do o[k] = v; end setmetatable(o, Enhancer); return o; end

cards.
enhancers = {
	Enhancer {
		name = "Baby";
		desc = "-5 to monster. Play during combat. If the monster is defeated, draw 1 fewer Treasure.";
		combat_effect = -5;
		reward_effect = -1;
		monster_target_only = true;
	};
	
	-- TODO enhancers
}


-- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- 
--
--  @Item
--
-- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- 


local Item = {
	type = "item";
	group = "treasure";
	value = -1;
}
Item.__index = Item;
setmetatable(Item, Card);
Item.new = function(_, tbl) local o = {}; for k,v in pairs(tbl) do o[k] = v; end setmetatable(o, Item); return o; end

cards.
items = {
	Item { name = "Tuba of Charm";
		slot = "one_hand";
		big = true;
		value = 300;
		desc = "This melodious instrument captivates your foes, giving you +3 to Run Away. If you successfully escape combat, snag a face-down Treasure on your way out.";

		bonuses = { run_away = 3 };

		actions = {
			on_run_away = function(player, successful)
				if successful then
					player:draw_treasures(1);
				end
			end
		}
	};
	
	Item { name = "Huge Rock";
		slot = "two_hands";
		big = true;
		value = 0;

		bonuses = { combat = 3 };
	};
	
	Item { name = "Pointy Hat of Power";
		type = "item";
		slot = "headgear";
		value = 400;
		class = "Wizard";

		bonuses = { combat = 3 };
	};
	
	-- TODO items
};


-- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- 
--
--  @GOAL
--
-- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- 


local GOAL = {
	type = "goal";
	group = "treasure";
	
	play = function(card, game, player, args)
		player:give_level(1);
		player:discard_inhand_card();
	end;
}
GOAL.__index = GOAL;
setmetatable(GOAL, Card);
GOAL.new = function(_, tbl) local o = {}; for k,v in pairs(tbl) do o[k] = v; end setmetatable(o, GOAL); return o; end


cards.
goals = {
	-- TODO goals
};


-- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- 
--
--  @Curse
--
-- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- 


local Curse = {
	type = "curse";
	group = "treasure";
}
Curse.__index = Curse;
setmetatable(Curse, Card);
Curse.new = function(_, tbl) local o = {}; for k,v in pairs(tbl) do o[k] = v; end setmetatable(o, Curse); return o; end

cards.
curses = {
	-- TODO curses
};


-- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- 
--
--  @Player
--
-- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- 


-- plays the 'card' on the 'target' from 'self' player's hand.
-- returns false if the given card cannot be played.
Player.
play_card = function(self, game, card, target)
	if not card:can_play(game, self, target) then
		return false;
	end
	
	card:play(game, self, {target=target});
	move_card(self.in_hand, self.in_play, card.name);
end

-- returns true if the player was able to discard the card
Player.discard_card = function(self, game, src, name)
	if card.group == "door" then
		return move_card(src, game.door_discard, name);
	elseif card.group == "treasure" then
		return move_card(src, game.treasure_discard, name);
	else
		log:error("unknown card group '" .. card.group or "nil" .. "' on card '" .. name .. "'");
		return false;
	end
end
Player.discard_inplay_card = function(self, game, name) return self:discard_card(game, self.in_play, name); end
Player.discard_inhand_card = function(self, game, name) return self:discard_card(game, self.in_hand, name); end

-- called when this player kills 'monster'
Player.
on_combat_kill = function(self, game, monster)
	for card in self.in_play do
		if card.on_combat_kill then card.on_combat_kill(game, self) end
	end

	if game.active_player == self then
		self:give_levels(monster.levels);
	end
end

-- gathers the bonus called 'name' from the
-- cards in play. If the bonus found is a 
-- function it will be called with the player 
-- as an argument. Otherwise it must be 
-- a number.
Player.
gather_bonus = function(self, name)
	local sum = 0;
	for card in self.in_play do
		local bonus = card.bonuses[name];
		local bonus_type = type(bonus);
		if bonus then
			if "function" == bonus_type then
				sum = sum + bonus(self);
			elseif "number" == bonus_type then
				sum = sum + bonus;
			else
				error("encountered card with a '"..name.."' bonus that is neither a function or a number!");
			end
		end
	end
	return sum;
end


return cards;
