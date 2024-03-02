-- 
-- Definition of the Player type 
--
-- Each player uses this as its metatable. It contains defaults for 
-- various functionality and values.
-- 
local log = require("logger").register_module("game")


local Player = {
	in_hand = {};
	in_play = {};
	
	in_combat = nil;
	turn_owner = nil;
	
	race = nil;
	race2 = nil;
	class = nil;
	class2 = nil;
	gender = nil;
	
	-- base stats which may be modified by items, race, or class
	max_in_play = 5;
	free_hands = 2;
	big_items = 0;
	max_big_items = 1;
}
Player.__index = Player;

-- plays the 'card' on the 'target' from 'self' player's hand.
-- returns false if the given card cannot be played.
Player.
play_card = function(self, card, target)
	if card.type == "race" then
		log:error("not implemented yet");
		return false;
	elseif card.type == "class" then
		log:error("not implemented yet");
		return false;
	elseif card.type == "monster" then
		log:error("not implemented yet");
		return false;
	elseif card.type == "enhancer" then
		log:error("not implemented yet");
		return false;
	elseif card.type == "item" then
		if target ~= self then
			return false; -- can only play item cards on self
		end
		if self.in_combat and not card.can_be_played_in_combat then
			return false; -- can't play item cards in combat
		end
		if card.big and self.big_items >= self.max_big_items then
			return false;
		end
		
		if card.slot == "one_hand" then
			if self.free_hands < 1 then
				return false;
			end
			
			self.free_hands = self.free_hands - 1;
		elseif card.slot == "two_hands" then
			if self.free_hands < 2 then
				return false;
			end
			
			self.free_hands = self.free_hands - 2;
		elseif card.slot == "headgear" then
			if not self.headgear then
				return false;
			end
			
			self.headgear = card;
		elseif card.slot == "armor" then
			if self.armor then
				return false;
			end
			
			self.armor = card;
		end
		
		if card.big then
			self.big_items = self.big_items + 1;
		end
	elseif card.type == "goal" then
		log:error("not implemented yet");
		return false;
	elseif card.type == "curse" then
		log:error("not implemented yet");
		return false;
	end
	
	cards.move_card(self.in_hand, self.in_play, card);
	return true;
end

-- TODO how to access game.discard piles?
local discard_card = function(player, src, name)
	log:error("not implemented yet");
	return false;
end

-- returns true if the player was able to discard the card
Player.
discard_inplay_card = function(self, name)
	log:error("not implemented yet");
	return false;
end

-- returns true if the player was able to discard the card
Player.
discard_inhand_card = function(self, name)
	log:error("not implemented yet");
	return false;
end

Player.
grant_levels = function(self, n)
	self.level = self.level + n;
end

Player.
lose_levels = function(self, n)
	self.level = math.max(self.level - n, 1);
end

-- called when this player kills 'monster'
Player.
on_combat_kill = function(self, game, monster)
	for card in self.in_play do
		if card.on_combat_kill then card.on_combat_kill(game, self) end
	end

	if game.active_player == self then
		self:grant_levels(monster.levels);
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

-- called when this player dies.
Player.
die = function(self)
	-- nil everything in this object, equivalent to 
	-- setting everything back to defaults (because they 
	-- are stored on the metatable)
	for k in pairs(self) do
		self[k] = nil;
	end
end

return Player

