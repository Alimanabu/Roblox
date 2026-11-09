-- Promo codes. Case does not matter: "sixseven" = "SIXSEVEN".
-- Each player can enter a code once.
-- expires is the date until which the code works (os.time in seconds, UTC), nil = forever.
-- New codes are handy to hand out in the game description, in the group and to YouTubers.

return {
	SIXSEVEN = { luckMinutes = 30, text = "🤌" },
	BRAINROT = { coinsMinutes = 10 },
	RIZZ = { creatureRarity = "rizz" },
	SIGMA = { coinsMinutes = 5, luckMinutes = 10 },
	RELEASE = { coinsMinutes = 15, luckMinutes = 15 },
	SKIN67 = { skin = "sixseven", textKey = "code.skin67.text" },
}
