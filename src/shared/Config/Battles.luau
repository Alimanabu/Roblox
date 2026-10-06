-- Аура-баттлы: 3 сильнейших брейнрота против 3 сильнейших соперника.
-- Без ставок: проиграть свои брейнроты или монеты нельзя.

local Battles = {}

Battles.TEAM_SIZE = 3
Battles.RANDOM_SPREAD = 0.35 -- сила каждого брейнрота в раунде ±35%: бывают апсеты!
Battles.CHALLENGE_COOLDOWN = 10 -- секунд между вызовами
Battles.SAME_OPPONENT_COOLDOWN = 60 -- с одним и тем же соперником — не чаще раза в минуту
Battles.REWARDED_PER_DAY = 10 -- сколько побед в день дают монеты

Battles.WIN_POINTS = 25
Battles.LOSS_POINTS = 10 -- столько очков ауры теряется за поражение (не ниже 0)
Battles.BOT_WIN_POINTS = 5

Battles.WinReward = { coinsMinutes = 5 }
Battles.BotWinReward = { coinsMinutes = 2 }

-- Ранги по очкам ауры.
Battles.Ranks = {
	{ points = 0, name = "Без ауры" },
	{ points = 100, name = "Аура-новичок" },
	{ points = 300, name = "Аура-фармер" },
	{ points = 700, name = "Аура-мастер" },
	{ points = 1500, name = "Аура-легенда" },
	{ points = 3000, name = "Бесконечная аура ♾️" },
}

function Battles.rankFor(points)
	local name = Battles.Ranks[1].name
	for _, rank in ipairs(Battles.Ranks) do
		if points >= rank.points then
			name = rank.name
		end
	end
	return name
end

-- Сила брейнрота в баттле: корень 4-й степени из дохода, чтобы Бог был сильнее
-- Нормиса «всего» в ~14 раз, а не в 75 000. Соседние редкости отличаются в ~1.5 раза:
-- с разбросом ±35% слабый иногда побеждает (апсет). baseIncome — доход с мутацией.
function Battles.power(baseIncome)
	return math.floor(math.max(baseIncome, 0) ^ 0.25 * 100)
end

return Battles
