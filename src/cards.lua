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


-- base card type, contains defaults when deriving types dont implement basic data/functionality
local Card = {
	type = "card";
	uid = nil;
	group = "** ungrouped card **"; -- door, treasure
	kind = "** unkinded card **"; -- race, class, monster, enhancer, item, goal, curse
	name = "** unnamed card **";
	desc = "** undescribed card **";
	front = ""; -- TODO image path
	back = ""; -- TODO image path
	properties = {}; -- generic properties table of strings for querying
	deck_count = 1; -- how many of this card are in the deck
	
	
	-- bonuses added to value checks while a card is in play
	-- default: function(self, game, player) return 0; end;
	-----------------------------------------------
	-- added to a player's combat value
	bonus_combat = nil;

	-- added to a player's run away roll
	bonus_run_away = nil;
	-----------------------------------------------
	
	
	-- automatic triggers when while a card is in play
	-- default: function(self, game, player) return nil; end;
	-----------------------------------------------
	-- called when a player wins combat
	on_victory = nil;
	
	-- called when a player attempts to run away from combat
	on_run_away = nil;
	
	-- called when a player loses combat (after failing to run away)
	on_defeat = nil;
	-----------------------------------------------
	
	
	-- checks to see if an action can be peformed by a player
	-- default: function(self, game, player) return true; end;
	-----------------------------------------------
	-- whether or not this card can be played
	can_play = nil;

	-- whether or not this card can be discarded
	can_discard = nil;
	
	-- whether or not this card can be used while already in play
	can_use = nil;
	-----------------------------------------------
	
	
	-- actions triggered by the game or a player
	-- default: function(self, game, player) return nil; end;
	-----------------------------------------------
	-- called when a player plays this card
	play = nil;
	
	-- called when a player discards this card
	discard = nil;
	
	-- called when a player uses this card while its in play
	use = nil;
	-----------------------------------------------
}
Card.__index = Card
-- setup __call to redirect to the new function that 
-- children of this type implement. This allows us to 
-- write something like Race {...} rather than Race.new {...}
Card.__call = function(self, tbl) return self:new(tbl) end

-- returns true if the has card has the property
Card.has_property = function(self, property)
	for _,p in pairs(self.properties) do
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
	kind = "race";
	group = "door";
	
	can_play = function(game, player)
		return game.active_player == player and not player.race or (player.allow_second_race and not player.race2);
	end
}
Race.__index = Race;
setmetatable(Race, Card);
Race.new = function(_, tbl) local o = {}; for k,v in pairs(tbl) do o[k] = v; end setmetatable(o, Race); return o; end

cards.cards.races = {
	Race { name = "Dwarf";
		desc = "You can carry any number of Big items. You can have 6 cards in your hand.";
		deck_count = 3;
		play = function(self, game, player)
			player.max_big_items = 1000; -- arbitrarily large number since we don't have inf
			player.max_in_play = 6;
		end;
		discard = function(self, game, player)
			player.max_big_items = nil;
			player.max_in_play = nil;
		end;
	};
	
	Race { name = "Elf";
		desc = "+1 to Run Away. You go up 1 Level for every monster you help someone else kill.";
		deck_count = 3;
		bonus_run_away = function(self, game, player)
			return 1;
		end;
		on_victory = function(self, game, player)
			if game.active_player ~= player then
				player:give_levels(1);
			end
		end;
	};
	
	Race { name = "Half-Breed";
		desc = "You may have two race cards, and have all of the advantages and disadvantages of each. Or you may have one race card and have all of its advantages and none of its disadvantages (for example, monsters that hate Elves will have no bonus against a Half-Elf). Lose this card if you lose all your race card(s).";
		deck_count = 2;
		play = function(self, game, player)
			player.allow_second_race = true;
		end;
		discard = function(self, game, player)
			player.allow_second_race = nil;
		end;
	};
	
	Race { name = "Halfling";
		desc = "You may sell one Item each turn for double the price (other Items are at normal price). If you fail your initial Run Away roll, you may discard a card and try once more.";
		deck_count = 3;
		can_use = function(self, game, player)
			return player.run_away_attempts == 1 and player:has_discardables(game);
		end;
		play = function(self, game, player, card)
			player.double_first_sell = true;
		end;
		discard = function(self, game, player)
			player.double_first_sell = nil;
		end;
		use = function(self, game, player)
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
	kind = "class";
	group = "door";
	abilities = {};
	
	can_play = function(game, player)
		return game.active_player == player and not player.class or (player.allow_second_class and not player.class2);
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
				can_use = function(self, game, player)
					if game.active_player == player then
						if game.phase == "pre_door" then
							if #game.door_discard > 0 then
								return true;
							end
						elseif game.phase == "victory_shared" then
							if #game.treasure_discard > 0 then
								return true;
							end
						end
					end
					return false;
				end;
				use = function(self, game, player)
					local drawn = {};
					if game.phase == "pre_door" then
						drawn = player:draw_cards(game.door_discard, true, 1, #game.door_discard);
					elseif game.phase == "victory_shared" then
						drawn = player:draw_cards(game.treasure_discard, true, 1, #game.treasure_discard);
					end
					
					local drawn_count = #drawn;
					if drawn_count > 0 then
						local discardables = player:get_inhand_discardables(game);
						local discards = player:select_targets(discardables, false, drawn_count, drawn_count);
						for _,discard in pairs(discards) do
							player:discard_inhand_card(game, discard);
						end
						player.phase_done = true;
					end
				end;
			};
			{
				name = "Turning";
				desc = "You may discard up to 3 cards in combat against an Undead creature. Each discard gives you a +3 bonus.";
				can_use = function(self, game, player)
					if player.in_combat and player:has_discardables(game) then
						for monster in game.field.monsters do
							if monster:has_property("undead") then
								return true;
							end
						end
					end
					return false;
				end;
				use = function(self, game, player)
					local discardables = player:get_discardables(game);
					local discards = player:select_targets(discardables, true, 1, 3);
					if #discards > 0 then
						player.turning_used = true;
						for _,discard in pairs(discards) do
							player:discard_card(game, discard);
							player.bonus_combat = player.bonus_combat + 3;
						end
					end
				end;
			};
		};
	};
	
	Class { name = "Super Munchkin";
		desc = "You may have two Class cards, and have all of the advantages and disadvantages of each. Or you may have one Class card and have all of its advantages and none of its disadvantages (for example, monsters that hate Clerics will have no bonus against a Super Cleric). Lose this card if you lose all your Class card(s).";
		deck_count = 2;
		can_play = function(self, game, player)
			return not player.allow_second_class;
		end;
		play = function(self, game, player)
			player.allow_second_class = true;
		end;
		discard = function(self, game, player)
			player.allow_second_class = nil;
		end;
	};
	
	Class { name = "Thief";
		deck_count = 3;
		abilities = {
			{
				name = "Backstabbing";
				desc = "You may discard a card to backstab another player (-2 in combat). You may do this only once per victim per combat, but if two players are fighting a monster together, you may backstab each of them.";
				can_use = function(self, game, player)
					if game.phase == "combat" and player:has_discardables(game) then
						for combatant in game.field.players do
							if not combatant.backstabbed then
								return true;
							end
						end
					end
					return false;
				end;
				use = function(self, game, player)
					local discardables = player:get_discardables(game);
					::redo_backstabbing_discard_selection::
					local discards = player:select_targets(discardables, true, 1, #game.field.players);
					local discards_count = #discards;
					if discards_count > 0 then
						local combatants = player:select_targets(game.field.players, true, discards_count, discards_count);
						if #combatants > 0 then
							for _,discard in pairs(discards) do
								player:discard_card(game, discard);
							end
							for _,combatant in pairs(combatants) do
								combatant.bonus_combat = combatant.bonus_combat - 2;
								combatant.backstabbed = true;
							end
						else
							goto redo_backstabbing_discard_selection;
						end
					end
				end;
			};
			{
				name = "Theft";
				desc = "You may discard a card to try to steal a small Item carried by another player. Roll a die; 4 or more succeeds. Otherwise, you get whacked and lose a level.";
				can_use = function(self, game, player)
					if not player.in_combat and player:has_discardables(game) then
						for _,noncombatant in pairs(game.players) do
							if noncombatant ~= player and not noncombatant.in_combat and noncombatant:find_inplay_item(function(card) return not card.big; end) then
								return true;
							end
						end
					end
					return false;
				end;
				use = function(self, game, player)
					local discardables = player:get_discardables(game);
					::redo_theft_discard_selection::
					local discards = player:select_targets(discardables, true, 1, 1);
					if #discards > 0 then
						::redo_theft_noncombatant_selection::
						local noncombatants = player:select_targets(game.players, true, 1, 1, function(player) return not player.in_combat; end);
						if #noncombatants > 0 then
							local items = player:select_targets(noncombatants[0].in_play, true, 1, 1, function(card) return card.kind == "item" and not card.big; end);
							if #items > 0 then
								player.theft_used = true;
								if player:roll_die() >= 4 then
									cards.move_card(noncombatants[0].in_play, player.in_hand, items[0]);
								else
									player:lose_levels(1);
								end
							else
								goto redo_theft_noncombatant_selection;
							end
						else
							goto redo_theft_discard_selection;
						end
					end
				end;
			};
		};
	};
	
	Class { name = "Warrior";
		deck_count = 3;
		play = function(self, game, player)
			player.wins_combat_ties = true;
		end;
		discard = function(self, game, player)
			player.wins_combat_ties = nil;
		end;
		abilities = {
			{
				name = "Berserking";
				desc = "You may discard up to 3 cards in combat; each one gives you a +1 bonus. You win ties in combat.";
				can_use = function(self, game, player)
					return player.in_combat and player:has_discardables(game);
				end;
				use = function(self, game, player)
					local discardables = player:get_discardables(game);
					local discards = player:select_targets(discardables, true, 1, 3);
					if #discards > 0 then
						player.berserking_used = true;
						for _,discard in pairs(discards) do
							player:discard_card(game, discard);
							player.bonus_combat = player.bonus_combat + 1;
						end
					end
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
				can_use = function(self, game, player)
					return game.phase == "run_away" and player.in_combat and player:has_discardables(game);
				end;
				use = function(self, game, player)
					local discardables = player:get_discardables(game);
					local discards = player:select_targets(discardables, true, 1, 3);
					if #discards > 0 then
						player.flight_spell_used = true;
						for _,discard in pairs(discards) do
							player:discard_card(game, discard);
							player.bonus_run_away = player.bonus_run_away + 1;
						end
					end
				end;
			};
			{
				name = "Charm Spell";
				desc = "You may discard your whole hand (minimum 3 cards) to charm a single Monster instead of fighting it. Discard the Monster and take its Treasure, but don't gain levels. If there are other monsters in the combat, fight them normally.";
				can_use = function(self, game, player)
					return player.in_combat and #player.in_hand >= 3;
				end;
				use = function(self, game, player)
					local monsters = player:select_targets(game.field.monsters, true, 1, 1);
					if #monsters > 0 then
						player.charm_spell_used = true;
						
						for _,card in pairs(player.in_hand) do
							player:discard_inhand_card(game, card);
						end
						
						local treasures = monster:treasures(game, player);
						player:draw_cards(game.treasure_deck, false, treasures, treasures);
						
						local monster_field_idx = cards.find_card(game.field.monsters, monster);
						cards.discard_table_card(game, game.field.monsters, monster);
						table.remove(game.field.monsters_enhancers, monster_field_idx);
					end
				end;
			};
		};
	};
}


-- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- 
--
--  @Monster
--
-- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- 


local Monster = {
	kind = "monster";
	group = "door";
	good = "** missing Good Stuff text **"; -- TODO(sushi) remove and use formatting inside of desc to do this instead
	bad  = "** missing Bad Stuff text **";  -- TODO(sushi) remove and use formatting inside of desc to do this instead
	strength = function(self, game, player) return 1; end;
	treasures = function(self, game, player) return 1; end;
	levels = function(self, game, player) return 1; end;
	
	on_victory = function(self, game, player)
		player:draw_treasures(self:treasures(game, player));
		player:gain_levels(self:levels(game, player));
	end;
}
Monster.__index = Monster;
setmetatable(Monster, Card);
Monster.new = function(_, tbl) local o = {}; for k,v in pairs(tbl) do o[k] = v; end setmetatable(o, Monster); return o; end

cards.cards.monsters = {
	Monster { name = "3,872 Orcs";
		good = "If this enemy is defeated, the Player gains 1 level and 3 treasures.";
		bad  = "Due to ancient grudges, the 3,872 Orcs are level 16 (+6) against Dwarves. If this enemy is victorious, the Player must roll a die. On a 1 or 2, the 3,872 Orcs stomp the Player to death. On a 3 or higher, the Player loses however many Levels the die shows.";
		strength = function(self, game, player)
			for _,combatant in pairs(game.field.players) do
				if combatant.race == "dwarf" then
					return 16;
				end
			end
			return 10;
		end;
		treasures = function(self, game, player)
			return 3;
		end;
		on_defeat = function(self, game, player)
			for combatant in game.field.players do
				local roll = combatant:roll_die();
				if roll <= 2 then
					combatant:full_reset();
				else
					combatant:lose_levels(roll);
				end
			end
		end;
	};
	
	Monster { name = "Amazon";
		good = "The Amazon does not attack female Players. Instead, she gives them 1 Treasure. If this enemy is defeated, the Player gains 1 Level and 2 Treasures.";
		bad = "If this enemy is victorious, the male Player has been defeated by a woman, therefore losing his macho munchkin pride. The Player also loses his Class(es). However, if the Player has no Class, he loses 3 Levels instead.";
		strength = function(self, game, player)
			return 8;
		end;
		treasures = function(self, game, player)
			return 2;
		end;
		on_play = function(self, game, player)
			if player.gender == "female" then
				player:draw_cards(game.treasure_deck, false, 1, 1);
				return false;
			else
				return true;
			end
		end;
		on_defeat = function(self, game, player)
			for combatant in game.field.players do
				if combatant.class then
					combatant.class = nil;
					combatant.class2 = nil;
					combatant:discard_first_inplay_card(game, function(card) return card.anem == "Super Munchkin"; end);
				else
					combatant:lose_levels(3);
				end
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
	kind = "enhancer";
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
	kind = "item";
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

		on_run_away = function(player)
			player:draw_cards(game.treasure_deck, false, 1, 1);
		end
	};
	
	Item { name = "Huge Rock";
		slot = "two_hands";
		big = true;
		value = 0;

		bonuses = { combat = 3 };
	};
	
	Item { name = "Pointy Hat of Power";
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
	kind = "goal";
	group = "treasure";
	desc = "";
	
	can_play = function(self, game, player)
		return player.level < 9;
	end;
	play = function(self, game, player)
		player:give_level(1);
		player:discard_inhand_card(game, self);
	end;
}
GOAL.__index = GOAL;
setmetatable(GOAL, Card);
GOAL.new = function(_, tbl) local o = {}; for k,v in pairs(tbl) do o[k] = v; end setmetatable(o, GOAL); return o; end


cards.cards.goals = {
	GOAL { name = "1,000 Gold Pieces"; };
	
	GOAL { name = "Boil an Anthill"; };
	
	GOAL { name = "Bribe GM With Food"; };
	
	GOAL { name = "Convenient Addition Error"; };
	
	GOAL { name = "Invoke Obscure Rules"; };
	
	GOAL { name = "Kill the Hireling";
		desc = "You can use this card only if a Hireling is in play (no matter who owns him). Discard the Hireling.";
		can_play = function(self, game, player)
			if player.level < 9 then
				for _,p in pairs(game.players) do
					for _,card in pairs(p.in_play) do
						if card.name == "Hireling" then
							return true;
						end
					end
				end
			end
			return false;
		end;
		play = function(self, game, player)
			::redo_hireling_player_selection::
			local players = player:select_targets(game.players, true, 1, 1);
			if #players > 0 then
				local hirelings = player:select_targets(players[0].in_play, true, 1, 1, function(card) return card.name == "Hireling"; end);
				if #hirelings > 0 then
					player:give_level(1);
					player:discard_inhand_card(game, self);
					players[0]:discard_inplay_card(game, hirelings[0]);
				else
					goto redo_hireling_player_selection;
				end
			end
		end;
	};
	
	GOAL { name = "Mutilate the Bodies";
		desc = "This card can be played only after combat, but it does not have to be your combat.";
		can_play = function(self, game, player)
			return game.phase == "run_away" or game.phase == "defeat" or game.phase == "victory_solo" or game.phase == "victory_shared";
		end;
	};
	
	GOAL { name = "Potion of General Studliness"; };
	
	GOAL { name = "Whine at the GM";
		desc = "You can't use this if you are currently the highest-Level player, or tied for highest.";
		can_play = function(self, game, player)
			return game.phase == "run_away" or game.phase == "defeat" or game.phase == "victory_solo" or game.phase == "victory_shared";
		end;
	};
};


-- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- 
--
--  @Curse
--
-- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- 


local Curse = {
	kind = "curse";
	group = "treasure";
}
Curse.__index = Curse;
setmetatable(Curse, Card);
Curse.new = function(_, tbl) local o = {}; for k,v in pairs(tbl) do o[k] = v; end setmetatable(o, Curse); return o; end

cards.cards.curses = {
	Curse { name = "Curse! Change Class";
		desc = "If you have no Class now, this curse has no effect. Otherwise, go back through the discard pile, starting with the top discard. The first Class card you come to replaces your current Class(es). If you go through the discards without finding a Class card, you just lose your own Class(es).";
		play = function(self, game, player)
			if player.class then
				
				
				class_card = card.move_last_card(src, dst, function(card) return card.kind == "class"; end);
			end
		end;
	};
	
	
	
	-- TODO curses
};


-- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- 
--
--  @Player
--
-- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- 


-- plays the card on the target from the players hand
-- returns false if the given card cannot be played
Player.play_card = function(self, game, card)
	if card:can_play(game, self) then
		card:play(game, self);
		cards.move_card(self.in_hand, self.in_play, card);
		return true;
	end
	return false;
end

-- returns true if the card was discarded
Player.discard_inplay_card = function(self, game, card)
	return cards.discard_table_card(game, self.in_play, card);
end

-- returns true if the card was discarded
Player.discard_inhand_card = function(self, game, card)
	return cards.discard_table_card(game, self.in_hand, card);
end

-- returns true if a card was discarded
Player.discard_first_inplay_card = function(self, game, filter)
	return cards.discard_first_table_card(game, self.in_play, filter);
end

-- returns true if a card was discarded
Player.discard_first_inhand_card = function(self, game, filter)
	return cards.discard_first_table_card(game, self.in_hand, filter);
end

-- returns true if the card was discarded
Player.discard_card = function(self, game, card)
	return self:discard_inplay_card(game, card) or self:discard_inhand_card(game, card);
end

-- returns true if the player has can cards they can currently discard
Player.has_discardables = function(self, game)
	for _,card in pairs(self.in_play) do
		if card:can_discard(game, self) then
			return true;
		end
	end
	for _,card in pairs(self.in_hand) do
		if card:can_discard(game, self) then
			return true;
		end
	end
	return false;
end

-- returns all cards a player can currently discard
Player.get_discardables = function(self, game)
	tbl = {};
	for _,card in pairs(self.in_play) do
		if card:can_discard(game, self) then
			table.insert(tbl, card);
		end
	end
	for _,card in pairs(self.in_hand) do
		if card:can_discard(game, self) then
			table.insert(tbl, card);
		end
	end
	return tbl;
end

-- returns in play cards a player can currently discard
Player.get_inplay_discardables = function(self, game)
	tbl = {};
	for _,card in pairs(self.in_play) do
		if card:can_discard(game, self) then
			table.insert(tbl, card);
		end
	end
	return tbl;
end

-- returns in hand cards a player can currently discard
Player.get_inhand_discardables = function(self, game)
	tbl = {};
	for _,card in pairs(self.in_hand) do
		if card:can_discard(game, self) then
			table.insert(tbl, card);
		end
	end
	return tbl;
end

-- blocks execution until the player has drawn cards from a table or cancels
Player.draw_cards = function(self, tbl, cancelable, min, max)
	-- TODO player presentation and input
	log:error("not implemented yet");
	return {};
end

-- blocks execution until the player selects things from a table or cancels
Player.select_targets = function(self, tbl, cancelable, min, max, filter)
	-- TODO player presentation and input
	log:error("not implemented yet");
	return {};
end

-- blocks execution until the die roll finishes or is skipped
Player.roll_die = function(self)
	-- TODO blocking player presentation
	return math.random(1,6);
end

-- returns the player's first in play card that passes the filter function
Player.find_first_inplay_card = function(self, filter)
	for _,card in pairs(self.in_play) do
		if filter(card) then
			return card;
		end
	end
	return nil;
end

-- returns the player's first in hand card that passes the filter function
Player.find_first_inhand_card = function(self, filter)
	for _,card in pairs(self.in_hand) do
		if filter(card) then
			return card;
		end
	end
	return nil;
end

-- returns the player's first card that passes the filter function
Player.find_first_card = function(self, filter)
	for _,card in pairs(self.in_play) do
		if filter(card) then
			return card;
		end
	end
	for _,card in pairs(self.in_hand) do
		if filter(card) then
			return card;
		end
	end
	return nil;
end


-- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- 
--
--  @cards
--
-- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- ** -- 


-- returns the index of card in the tbl
cards.find_card = function(tbl, card)
	for idx,tbl_card in ipairs(tbl) do
		if card == tbl_card then
			return idx;
		end
	end
	return nil;
end

-- returns the index of the first card in the tbl that passes the filter function
cards.find_first_card = function(tbl, filter)
	for idx,tbl_card in ipairs(tbl) do
		if filter(tbl_card) then
			return idx;
		end
	end
	return nil;
end

-- returns the index of the last card in the tbl that passes the filter function
cards.find_last_card = function(tbl, filter)
	tbl_size = #tbl;
	for idx=1, tbl_size do
		if filter(tbl[tbl_size-idx+1]) then
			return idx;
		end
	end
	return nil;
end

-- removes and returns card from the tbl
cards.remove_card = function(tbl, card)
	idx = cards.find_card(tbl, card);
	if idx then
		return table.remove(tbl, idx);
	end
	return nil;
end

-- removes and returns the first card in the tbl that passes the filter function
cards.remove_first_card = function(tbl, filter)
	idx = cards.find_first_card(tbl, filter);
	if idx then
		return table.remove(tbl, idx);
	end
	return nil;
end

-- removes and returns the last card in the tbl that passes the filter function
cards.remove_first_card = function(tbl, filter)
	idx = cards.find_last_card(tbl, filter);
	if idx then
		return table.remove(tbl, idx);
	end
	return nil;
end

-- moves and returns card from the src_tbl to the dst_tbl
cards.move_card = function(src_tbl, dst_tbl, card)
	removed_card = cards.remove_card(src_tbl, card);
	if removed_card then
		table.insert(dst_tbl, removed_card);
	end
	return removed_card;
end

-- moves and returns the first card in the src_tbl that passes the filter function to the dst_tbl
cards.move_first_card = function(src_tbl, dst_tbl, filter)
	removed_card = cards.remove_first_card(src_tbl, filter);
	if removed_card then
		table.insert(dst_tbl, removed_card);
	end
	return removed_card;
end

-- moves and returns the last card in the src_tbl that passes the filter function to the dst_tbl
cards.move_last_card = function(src_tbl, dst_tbl, filter)
	removed_card = cards.remove_first_card(src_tbl, filter);
	if removed_card then
		table.insert(dst_tbl, removed_card);
	end
	return removed_card;
end

-- returns true if the card was discarded
cards.discard_table_card = function(game, tbl, card)
	if card.group == "door" then
		return cards.move_card(tbl, game.door_discard, card);
	elseif card.group == "treasure" then
		return cards.move_card(tbl, game.treasure_discard, card);
	else
		log:error("unknown card group " .. card.group or "nil" .. " on card " .. name .. "");
		cards.remove_card(tbl, card);
		return true;
	end
end

-- returns true if a card was discarded
cards.discard_first_table_card = function(game, tbl, filter)
	card = cards.find_first_card(tbl, filter);
	return card and cards.discard_table_card(game, tbl, card);
end

-- shuffles the cards in the tbl and returns it
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

-- returns a copy of the src card with a unique id
cards.make = function(self, src)
	self.uid_counter = (self.uid_counter and self.uid_counter + 1) or 0;
	local dst = {};
	for k,v in pairs(src) do
		dst[k] = v;
	end
	dst.uid = self.uid_counter;
	return dst;
end

-- returns a fresh shuffled deck of cards with key set to value
cards.new_deck = function(self, key, value)
	deck = {};
	for _,card_tbl in pairs(self.cards) do
		for _,card in pairs(card_tbl) do
			if card[key] == value then
				for _=1,card.deck_count do
					table.insert(deck, cards:make(card));
				end
			end
		end
	end
	return cards.shuffle_cards(deck);
end


return cards;
