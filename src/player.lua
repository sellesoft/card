-- 
-- Definition of the Player type 
--
-- Each player uses this as its metatable. It contains defaults for 
-- various functionality and values.
-- 
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

Player.
give_levels = function(self, n)
	self.level = self.level + n;
end

Player.
lose_levels = function(self, n)
	self.level = math.max(self.level - n, 1);
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

return Player;