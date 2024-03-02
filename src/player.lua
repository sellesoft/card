-- 
-- Definition of the Player type 
--
-- Each player uses this as its metatable. It contains defaults for 
-- various functionality and values.
-- 
local Player = {
	type = "player";
	in_hand = {};
	in_play = {};
	
	level = 1;
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
	allow_second_race = nil;
	allow_second_class = nil;
	double_first_sell = nil;
	max_run_away_attempts = 1;
	wins_combat_ties = nil;
	
	-- per phase values
	phase_done = nil;
	
	-- per turn values
	in_combat = nil;
	run_away_attempts = 0;
	backstabbed = nil;
	bonus_combat = 0;
	bonus_run_away = 0;
	turning_used = nil;
	theft_used = nil;
	berserking_used = nil;
	flight_spell_used = nil;
	charm_spell_used = nil;
}
Player.__index = Player;

Player.give_levels = function(self, n)
	self.level = self.level + n;
end

Player.lose_levels = function(self, n)
	self.level = math.max(self.level - n, 1);
end

Player.phase_reset = function(self) 
	self.phase_done = nil;
end

Player.turn_reset = function(self)
	self.in_combat = nil;
	self.run_away_attempts = 0;
	self.backstabbed = nil;
	self.bonus_combat = 0;
	self.bonus_run_away = 0;
	self.turning_used = nil;
	self.theft_used = nil;
	self.berserking_used = nil;
	self.flight_spell_used = nil;
	self.charm_spell_used = nil;
end

-- called when this player dies.
Player.full_reset = function(self)
	-- nil everything in this object, equivalent to 
	-- setting everything back to defaults (because they 
	-- are stored on the metatable)
	for k in pairs(self) do
		self[k] = nil;
	end
end

return Player;