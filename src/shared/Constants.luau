--!strict

return table.freeze({
	MIN_PLAYERS = 2,
	HIDING_DURATION = 15,
	SEEKING_DURATION = 90,
	INTERMISSION_DURATION = 10,
	SEEKER_RATIO = 0.25, -- 25% of players become seekers
	UNFREEZE_TOUCH_DURATION = 2, -- seconds of contact needed to unfreeze
	SEEKER_WALKSPEED = 18,
	HIDER_WALKSPEED = 16,
	FROZEN_WALKSPEED = 0,
})
