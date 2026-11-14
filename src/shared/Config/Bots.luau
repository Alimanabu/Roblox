-- NPC bots (server/Services/BotService.luau): when the server is nearly empty a few bots walk around so a new
-- player is not alone. They are NOT Players: no profile, no DataStore, no leaderboard, not counted in any player count.
-- Enabled = false turns them off completely (the tests of other features run without bots).

return {
	Enabled = true,
	MinHumans = 4, -- from this many live players on the server there are no bots
	MaxBots = 3, -- with 1-2 players there are 3 bots, with 3 players 2 bots (MaxBots - 1)
	-- The label over the bot's head is always "[BOT] <name>": a bot is never passed off as a person.
	Tag = "[BOT]",
	Names = { "Pixel", "Nugget", "Zippy", "Mango", "Turbo", "Waffle", "Bongo", "Pickle" },
}
