-- Ежедневные награды (серия из 7 дней) и ежедневные задания.
-- Награды в монетах считаются в «минутах дохода», чтобы они были полезны
-- и новичку, и прокачанному игроку.

local Daily = {}

Daily.MIN_COINS_PER_MINUTE = 250 -- минимум монет за «минуту дохода»
Daily.QUESTS_PER_DAY = 3

Daily.Rewards = {
	{ coinsMinutes = 3 },
	{ coinsMinutes = 6 },
	{ luckMinutes = 10 },
	{ coinsMinutes = 12 },
	{ luckMinutes = 20 },
	{ coinsMinutes = 25 },
	{ coinsMinutes = 45, luckMinutes = 30, mega = true },
}

-- kind — какое действие считается:
--   craft, fuse, sell, steal, slap, slapThief, lock, mutant, sigmaPlus, newIndex
Daily.QuestPool = {
	{ id = "craft25", kind = "craft", target = 25, text = "Создай 25 брейнротов", minutes = 5 },
	{ id = "craft80", kind = "craft", target = 80, text = "Создай 80 брейнротов", minutes = 12 },
	{ id = "fuse3", kind = "fuse", target = 3, text = "Скрести брейнротов 3 раза", minutes = 8 },
	{ id = "sell10", kind = "sell", target = 10, text = "Продай 10 брейнротов", minutes = 4 },
	{ id = "steal1", kind = "steal", target = 1, text = "Укради 1 брейнрота", minutes = 15 },
	{ id = "slap3", kind = "slap", target = 3, text = "Шлёпни 3 игроков", minutes = 4 },
	{ id = "slapThief", kind = "slapThief", target = 1, text = "Шлёпни вора", minutes = 10 },
	{ id = "lock3", kind = "lock", target = 3, text = "Закрой базу замком 3 раза", minutes = 4 },
	{ id = "mutant1", kind = "mutant", target = 1, text = "Получи брейнрота с мутацией", minutes = 8 },
	{ id = "sigma5", kind = "sigmaPlus", target = 5, text = "Получи 5 брейнротов «Сигма» или реже", minutes = 10 },
	{ id = "index1", kind = "newIndex", target = 1, text = "Открой нового брейнрота в Индексе", minutes = 10 },
}

Daily.QuestById = {}
for _, quest in ipairs(Daily.QuestPool) do
	Daily.QuestById[quest.id] = quest
end

function Daily.today(time)
	return math.floor((time or os.time()) / 86400)
end

function Daily.coinsFor(income, minutes)
	return math.max(Daily.MIN_COINS_PER_MINUTE * minutes, math.floor(income * 60 * minutes))
end

return Daily
