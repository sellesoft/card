-- [[
--
--     Card definitions
--     These should eventually be hot-reloadable somehow, but for now 
--     I'm just going to implement them statically. 
--
--     The game is, at the moment, designed so that cards actually control
--     much of the logic. The game offers up players which play cards.
--
-- ]]

PlayerStats = {
	max_in_play = 5;
	max_big_items = 1;
}


-- player 'class' which serves as the metatable of 
-- player objects. This allows us to override the players
-- functionality by setting any of the following members
-- on the object. The original functionality can be restored
-- by simply setting the overriding member to nil.
Player = {
	-- cards in play 
	in_play = {};

	race = nil,
	class = nil,

	-- base stats which may be modified by items, race, or class
	max_in_play = 5;
	free_hands = 2;
	big_items = 0;
	max_big_items = 1;

	play_card = function(self, card)
		-- check if the card itself has any restrictions on
		-- who can play it
		if not card:can_play(self) then
			return false
		end

		if card.type == "item" then
			if card.slot == "one hand" then
				if self.free_hands ~= 0 then
					if card.big then
						if self.big_items < self.max_big_items then
							self.big_items = self.big_items + 1
							table.insert(self.in_play, card)
							return true
						end
					else
						table.insert(self.in_play, card)
						self.free_hands = self.free_hands - 1
						return true
					end
				end
			elseif card.slot == "two hands" then
				if self.free_hands == 2 then
					if card.big then
						if self.big_items == 0 then
							self:play_card(card)
							table.insert(self.in_play, card)
							return true
						end
					else
						table.insert(self.in_play, card)
						self.free_hands = 0
						return true
					end
				end
			elseif card.slot == "headgear" then
				if not self.headgear then
					self.headgear = card
					table.insert(self.in_play, card)
					return true
				end
			elseif card.slot == "armor" then
				if not self.armor then
					self.armor = card
					table.insert(self.in_play, card)
					return true
				end
			end
		end
	end;

	grant_levels = function(self, n)
		self.level = self.level + n
	end;

	on_combat_kill = function(self, game, monster)
		for card in self.in_play do
			if card.on_combat_kill then card.on_combat_kill(game, self) end
		end

		if game.active_player == self then
			self:grant_levels(monster.levels)
		end
	end;

	gather_bonus = function(self, name)
		local sum = 0
		for card in self.in_play do
			if card.bonuses then
				sum = sum + (card.bonuses[name] or 0)
			end
		end
		return sum
	end;

	die = function(self)
		-- nil everything in this object, equivalent to 
		-- setting everything back to defaults (because they 
		-- are stored on the metatable)
		for k in pairs(self) do
			self[k] = nil
		end
	end;
}

local races = {
	dwarf = {
		name = "Dwarf";
		desc = "You can carry any number of Big items. You can have 6 cards in your hand.";
		bonuses = {
			max_big_items = 1000; -- arbitrarily large number since we don't have inf
			max_in_play = 1;
		};
	};
	elf = {
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

local classes = {
	wizard = {
		name = "Wizard";
		abilities = {
			{
				name = "Flight Spell";
				desc = "You may discard up to three cards after rolling the die to Run Away; each one gives you a +1 bonus to flee.";
				phases = "runaway";
				can_use = function(game)
					if game.phase == "runaway" then return true end
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

Card = {
	name = "** unnamed card **";
	desc = "** undescribed card **";
	type = "** untyped card **";

	-- overridable function items may use 
	-- to put restrictions on what can use them
	can_play = function(self, player) return true end;
}
Card.__index = Card
Card.__call = function(self, tbl) return self:new(tbl) end

Monster = {
	-- TODO(sushi) remove and use formatting inside of 'desc' to do this instead
	good = "** missing Good Stuff text **";
	bad  = "** missing Bad Stuff text **";
	treasures = 0;

	calc_strength = function(self)
		error("encountered monster card '"..self.name.."' with unimplemented 'calc_strength' function.", 2)
	end;

	on_victory = function(self)
		error("encountered monster card '"..self.name.."' with unimplemeneted 'on_victory' function.", 2)
	end;

	add_enhancer = function(self, x)
		table.insert(self.enhancers, x)
	end;

	calc_enhancer_effect = function(self)
		local sum = 0
		for enhancer in self.enhancers do
			sum = sum + enhancer.effect
		end
		return sum
	end;

	new = function(_, tbl)
		local o = {}
		for k,v in pairs(tbl) do
			o[k] = v
		end
		o.type = "monster"
		o.enhancers = {}
		setmetatable(o, Monster)
	end
}
Monster.__index = Monster
setmetatable(Monster, Card)

MonsterEnhancer = {
	new = function(_, tbl)
		local o = {}
		for k,v in pairs(tbl) do
			o[k] = v
		end
		o.type = "enhancer"
		setmetatable(o, MonsterEnhancer)
		return o
	end
}
MonsterEnhancer.__index = MonsterEnhancer
setmetatable(MonsterEnhancer, Card)

Item = {
	value = -1;


	new = function(_, tbl)
		local o = {}
		for k,v in pairs(tbl) do
			o[k] = v
		end
		o.type = "item"
		setmetatable(o, Item)
		return o
	end
}
Item.__index = Item
setmetatable(Item, Card)

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
