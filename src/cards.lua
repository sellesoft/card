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
cards.cards = {};


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
	front = ""; -- TODO image path
	back = ""; -- TODO image path
	properties = {}; -- generic properties table of strings for querying
	deck_count = 1; -- how many of this card are in the deck
	
	
	-- bonuses added to value checks while a card is in play
	-- default: function(self, game, player, args) return 0; end;
	-----------------------------------------------
	-- added to a player's combat value
	bonus_combat = nil;

	-- added to a player's run away roll
	bonus_run_away = nil;
	-----------------------------------------------
	
	
	-- automatic triggers when while a card is in play
	-- default: function(self, game, player, args) return nil; end;
	-----------------------------------------------
	-- called when a player wins combat
	on_victory = nil;
	
	-- called when a player loses combat
	on_defeat = nil;
	
	-- called when a player attempts to run away from combat
	on_run_away = nil;
	-----------------------------------------------
	
	
	-- checks to see if an action can be peformed by a player
	-- default: function(self, game, player, args) return true; end;
	-----------------------------------------------
	-- whether or not this card can be played
	can_play = nil;

	-- whether or not this card can be discarded
	can_discard = nil;
	
	-- whether or not this card can be used while already in play
	can_use = nil;
	-----------------------------------------------
	
	
	-- actions triggered by the game or a player
	-- default: function(self, game, player, args) return nil; end;
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

-- returns true if the 'has' card has the 'property'
Card.has_property = function(self, property)
	for p in self.properties do
		if p == property then
			return true;
		end
	end
	return false;
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
Race.new = function(_, tbl) local o = {}; for k,v in pairs(tbl) do o[k] = v; end setmetatable(o, Race); return o; end

cards.cards.races = {
	Race { name = "Dwarf";
		desc = "You can carry any number of Big items. You can have 6 cards in your hand.";
		deck_count = 3;
		play = function(self, game, player, args)
			player.max_big_items = 1000; -- arbitrarily large number since we don't have inf
			player.max_in_play = 6;
		end;
		discard = function(self, game, player, args)
			player.max_big_items = nil;
			player.max_in_play = nil;
		end;
	};
	
	Race { name = "Elf";
		desc = "+1 to Run Away. You go up 1 Level for every monster you help someone else kill.";
		deck_count = 3;
		bonus_run_away = function(self, game, player, args)
			return 1;
		end;
		on_victory = function(self, game, player, args)
			if game.active_player ~= player then
				player:give_levels(1);
			end
		end;
	};
	
	Race { name = "Half-Breed";
		desc = "You may have two race cards, and have all of the advantages and disadvantages of each. Or you may have one race card and have all of its advantages and none of its disadvantages (for example, monsters that hate Elves will have on bonus against a Half-elf). Lose this card if you lose all your race card(s).";
		deck_count = 2;
		play = function(self, game, player, args)
			player.allow_second_race = true;
		end;
		discard = function(self, game, player, args)
			player.allow_second_race = nil;
		end;
	};
	
	Race { name = "Halfling";
		desc = "You may sell one Item each turn for double the price (other Items are at normal price). If you fail your initial Run Away roll, you may discard a card and try once more.";
		deck_count = 3;
		can_use = function(self, game, player, args)
			return player.run_away_attempts == 1 and (#player.in_hand > 0 or #player.in_play > 0);
		end;
		play = function(self, game, player, card, args)
			player.double_first_sell = true;
		end;
		discard = function(self, game, player, args)
			player.double_first_sell = nil;
		end;
		use = function(self, game, player, args)
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
	
	can_play = function(game, player, args)
		return game.active_player == player;
	end
}
Class.__index = Class;
setmetatable(Class, Card);
Class.new = function(_, tbl) local o = {}; for k,v in pairs(tbl) do o[k] = v; end setmetatable(o, Class); return o; end

cards.cards.classes = {
	Class { name = "Cleric";
		deck_count = 3;
		abilities = {
			{
				name = "Resurrection";
				desc = "When it is time for you to draw cards face-up, you may instead take some or all from the top of the appropriate discard pile. You must then discard one card from your hand for each card drawn.";
				can_use = function(self, game, player, args)
					return game.active_player == player and game.phase == "draw_cards_faceup";
				end;
				use = function(self, game, player, args)
					-- TODO how to present options to the player?
					log:error("not implemented yet");
				end;
			};
			{
				name = "Turning";
				desc = "You may discard up to 3 cards in combat against an Undead creature. Each discard gives you a +3 bonus.";
				can_use = function(self, game, player, args)
					if player.in_combat then
						for monster in game.field.monsters do
							if monster:has_property("undead") then
								return true;
							end
						end
					end
					return false;
				end;
				use = function(self, game, player, args)
					-- TODO how to present options to the player?
					log:error("not implemented yet");
				end;
			};
		};
	};
	
	Class { name = "Wizard";
		deck_count = 3;
		abilities = {
			{
				name = "Flight Spell";
				desc = "You may discard up to three cards after rolling the die to Run Away; each one gives you a +1 bonus to flee.";
				can_use = function(self, game, player, args)
					return game.phase == "run_away";
				end;
				use = function(self, game, player, args)
					
				end;
			};
			{
				name = "Charm Spell";
				desc = "You may discard your whole hand (minimum 3 cards) to charm a single Monster instead of fighting it. Discard the Monster and take its Treasure, but don't gain levels. If there are other monsters in the combat, fight them normally.";
				can_use = function(self, game, player, args)
					return player.in_combat and #player.in_hand >= 3;
				end;
				use = function(self, game, player, args)
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
	good = "** missing Good Stuff text **"; -- TODO(sushi) remove and use formatting inside of 'desc' to do this instead
	bad  = "** missing Bad Stuff text **";  -- TODO(sushi) remove and use formatting inside of 'desc' to do this instead
	strength = 1;
	treasures = 1;
	levels = 1;
	
	on_victory = function(self, game, player, args)
		player:draw_treasures(self:treasures(game, player, args));
		player:gain_levels(self:levels(game, player, args));
	end;
}
Monster.__index = Monster;
setmetatable(Monster, Card);
Monster.new = function(_, tbl) local o = {}; for k,v in pairs(tbl) do o[k] = v; end setmetatable(o, Monster); return o; end

cards.cards.monsters = {
	Monster { name = "3,872 Orcs";
		good = "If this enemy is defeated, the Player gains 1 level and 3 treasures.";
		bad  = "Due to ancient grudges, the 3,872 Orcs are level 16 (+6) against Dwarves. If this enemy is victorious, the Player must roll a die. On a 1 or 2, the 3,872 Orcs stomp the Player to death. On a 3 or higher, the Player loses however many Levels the die shows.";
		strength = function(self, game, player, args)
			if player.race == "dwarf" then
				return 16;
			end
			for helper in args.helpers do
				if helper.race == "dwarf" then
					return 16;
				end
			end
			return 10;
		end;
		treasures = 3;
		on_defeat = function(self, game, player, args)
			local effect = function(x)
				local roll = x:roll_die();
				if roll <= 2 then
					x:full_reset();
				else
					x:lose_levels(roll);
				end
			end

			effect(player);
			for helper in args.helpers do
				effect(helper);
			end
		end;
	};
	
	Monster { name = "Amazon";
		good = "The Amazon does not attack female Players. Instead, she gives them 1 Treasure. If this enemy is defeated, the Player gains 1 Level and 2 Treasures.";
		bad = "If this enemy is victorious, the male Player has been defeated by a woman, therefore losing his macho munchkin pride. The Player also loses his Class(es). However, if the Player has no Class, he loses 3 Levels instead.";
		treasures = 2;
		
		strength = function(self, game, player)
			return 8;
		end;
		
		on_victory = function(self, game, player, args)
			if player.class then
				player.class = nil;
				player.class2 = nil;
				player:discard_card("Super Munchkin");
			else
				player:lose_levels(3);
			end
		end;
		
		on_encounter = function(self, game, player, args)
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

cards.cards.enhancers = {
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

cards.cards.items = {
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


cards.cards.goals = {
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

cards.cards.curses = {
	-- TODO curses
};


-- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- 
--
--  @Player
--
-- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- 


-- plays the 'card' on the 'target' from 'self' player's hand.
-- returns false if the given card cannot be played.
Player.play_card = function(self, game, card, target)
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
Player.on_combat_kill = function(self, game, monster)
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
Player.gather_bonus = function(self, name)
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


-- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- 
--
--  @cards
--
-- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- 


-- returns the index of the first card with 'name' in the 'tbl' table
cards.find_card = function(tbl, name)
	for idx,card in iparis(tbl) do
		if card.name == name then
			return idx;
		end
	end
	return nil;
end

-- removes the first card with 'name' in the 'tbl' table
-- returns the card that was removed
cards.remove_card = function(tbl, name)
	idx = cards.find_card(tbl, name);
	if idx then
		return table.remove(tbl, idx);
	end
	return nil;
end

-- moves the first card with 'name' from the 'src_tbl' table to the 'dst_tbl' table
cards.move_card = function(src_tbl, dst_tbl, name)
	card = cards.remove_card(src_tbl, name);
	if card then
		table.insert(dst_tbl, card);
	end
	return card ~= nil;
end

-- shuffles the cards in the 'tbl' table and returns it
cards.shuffle_cards = function(tbl)
	tbl_size = #tbl;
	if tbl_size > 1 then
		for i=1, tbl_size-1 do
			local j = math.random(i, tbl_size-i+1);
			local t = tbl[j];
			tbl[j] = tbl[i];
			tbl[i] = t;
		end
	end
	return tbl;
end

-- returns a fresh shuffled deck of cards with 'key' set to 'value'
cards.new_deck = function(self, key, value)
	deck = {};
	for _,card_tbl in pairs(self.cards) do
		for _,card in pairs(card_tbl) do
			if card[key] == value then
				for _=1,card.deck_count do
					table.insert(deck, card);
				end
			end
		end
	end
	return cards.shuffle_cards(deck);
end


return cards;
