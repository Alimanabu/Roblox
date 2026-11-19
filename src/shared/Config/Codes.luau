-- Promo codes. Case does not matter: "sixseven" = "SIXSEVEN".
-- Each player can enter a code once.
-- enabled = true: the code is given out. Any other value, or no enabled at all, keeps the code written down but
-- switched off (CodeService.active): the player gets "that code doesn't exist".
-- expires is the date until which the code works (os.time in seconds, UTC), nil = forever.
-- New codes are handy to hand out in the game description, in the group and to YouTubers.

return {
	SIXSEVEN = { enabled = true, luckMinutes = 30, text = "🤌" },
	BRAINROT = { enabled = true, coinsMinutes = 10 },
	RIZZ = { enabled = true, creatureRarity = "rizz" },
	SIGMA = { enabled = true, coinsMinutes = 5, luckMinutes = 10 },
	RELEASE = { enabled = true, coinsMinutes = 15, luckMinutes = 15 },
	-- For videos, the group and Discord: one code per place, so that it is clear where the players came from.
	DISCORD = { enabled = true, coinsMinutes = 10, luckMinutes = 10 },
	YOUTUBE = { enabled = true, coinsMinutes = 12, luckMinutes = 15 },
	SKIN67 = { enabled = true, skin = "sixseven", textKey = "code.skin67.text" },
	-- The game description says "new code at 25 likes". Written down, not given out yet: when the game page
	-- shows 25 likes, set enabled = true, publish, and put the code into the description (docs/LAUNCH.md, section 2).
	LIKES25 = { enabled = false, coinsMinutes = 15, luckMinutes = 15 },
}
