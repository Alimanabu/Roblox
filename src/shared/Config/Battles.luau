-- Aura battles: the 3 strongest brainrots against the opponent's 3 strongest.
-- No bets: you cannot lose your brainrots or coins.

local S = require(script.Parent.Parent.Strings)

local Battles = {}

Battles.TEAM_SIZE = 3
Battles.RANDOM_SPREAD = 0.35 -- each brainrot's strength in a round +/-35%: upsets happen!
Battles.CHALLENGE_COOLDOWN = 10 -- seconds between challenges
Battles.SAME_OPPONENT_COOLDOWN = 60 -- with the same opponent, at most once a minute
Battles.REWARDED_PER_DAY = 10 -- how many wins per day give coins

Battles.WIN_POINTS = 25
Battles.LOSS_POINTS = 10 -- this many aura points are lost for a defeat (not below 0)
Battles.BOT_WIN_POINTS = 5

Battles.WinReward = { coinsMinutes = 5 }
Battles.BotWinReward = { coinsMinutes = 2 }

-- Ranks by aura points.
Battles.Ranks = {
	{ points = 0 },
	{ points = 100 },
	{ points = 300 },
	{ points = 700 },
	{ points = 1500 },
	{ points = 3000 },
}

-- Message (see Strings): the client shows the rank name in the player's language.
function Battles.rankFor(points)
	local reached = Battles.Ranks[1].points
	for _, rank in ipairs(Battles.Ranks) do
		if points >= rank.points then
			reached = rank.points
		end
	end
	return S.m("battle.rank." .. reached)
end

-- A brainrot's battle strength: the 4th root of income, so that God is stronger than
-- Normis only by ~14 times, not 75,000. Neighboring rarities differ by ~1.5 times:
-- with a +/-35% spread the weak one sometimes wins (an upset). baseIncome is the income with the mutation.
function Battles.power(baseIncome)
	return math.floor(math.max(baseIncome, 0) ^ 0.25 * 100)
end

return Battles
