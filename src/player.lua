-- 
-- Definition of the Player type 
--
-- Each player uses this as its metatable. It contains defaults for 
-- various functionality and values.
-- 

local Player = {
	-- cards in play 
	in_play = {};

	race = nil;
	class = nil;

	-- base stats which may be modified by items, race, or class
	max_in_play = 5;
	free_hands = 2;
	big_items = 0;
	max_big_items = 1;
}
Player.__index = Player

-- central function for putting cards 'in play'. 
-- returns false if the given card cannot be played.
Player.
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
end

-- central, currently useless, level granting function
-- incase we ever decide it needs to perform more 
-- logic generically.
Player.
grant_levels = function(self, n)
	self.level = self.level + n
end

-- called when this player kills 'monster'
Player.
on_combat_kill = function(self, game, monster)
	for card in self.in_play do
		if card.on_combat_kill then card.on_combat_kill(game, self) end
	end

	if game.active_player == self then
		self:grant_levels(monster.levels)
	end
end

-- gathers the bonus called 'name' from the
-- cards in play. If the bonus found is a 
-- function it will be called with the player 
-- as an argument. Otherwise it must be 
-- a number.
Player.
gather_bonus = function(self, name)
	local sum = 0
	for card in self.in_play do
		local bonus = card.bonuses[name]
		local bonus_type = type(bonus)
		if bonus then
			if "function" == bonus_type then
				sum = sum + bonus(self)
			elseif "number" == bonus_type then
				sum = sum + bonus
			else
				error("encountered card with a '"..name.."' bonus that is neither a function or a number!")
			end
		end
	end
	return sum
end

-- called when this player dies.
Player.
die = function(self)
	-- nil everything in this object, equivalent to 
	-- setting everything back to defaults (because they 
	-- are stored on the metatable)
	for k in pairs(self) do
		self[k] = nil
	end
end

return Player

