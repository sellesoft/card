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

	-- base stats which may be modified by items, race, or class
	max_in_play = 5;
	free_hands = 2;
	big_items = 0;
	max_big_items = 1;

	play_card = function(self, card)
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

		table.insert(self.in_play, card)
	end;

	equip_item = function(self, item)
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
					return false
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
			}
		};
	};
}



local door_deck = {
	{
		name = "3,872 Orcs";
		type = "monster";
		good = "If this enemy is defeated, the Player gains 1 level and 3 treasures.";
		bad  = "Due to ancient grudges, the 3,872 Orcs are level 16 (+6) against Dwarves. If this enemy is victorious, the Player must roll a die. On a 1 or 2, the 3,872 Orcs stomp the Player to death. On a 3 or higher, the Player loses however many Levels the die shows.";
		treasures = 3;

		-- calculates this monsters strength against the given player
		calc_strength = function(player)
			if player.race == "dwarf" then
				return 16
			end

			return 10
		end;

		on_defeat = function(game, player)
			
		end;

		battle = function(engaged_players)
			local strenth = 16

			local sum = 0

			for player in engaged_players do
				sum = sum + player:calc_combat_strength()

			end
		end;
	}
}

local treasure_deck = {
	{
		name = "Tuba of Charm";
		type = "item";
		slot = "one hand";
		big = true;
		value = 300;
		desc = "This melodious instrument captivates your foes, giving you +3 to Run Away. If you successfully escape combat, snag a face-down Treasure on your way out.";

		bonuses = {
			run_away = 3;
		};

		actions = {
			on_run_away = function(player, successful)
				if successful then
					player:draw_treasure()
				end
			end
		}
	};
	{
		name = "Huge Rock";
		type = "item";
		slot = "two hands";
		big = true;
		value = 0;

		bonuses = { combat = 3 };
	};
	{
		name = "Pointy Hat of Power";
		type = "item";
		slot = "headgear";
		value = 400;

		class = "wizard"
	}
}
