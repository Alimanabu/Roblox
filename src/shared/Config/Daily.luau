-- Ежедневные награды (серия из 7 дней) и ежедневные задания.
-- Награды в монетах считаются в «минутах дохода», чтобы они были полезны
-- и новичку, и прокачанному игроку.

local S = require(script.Parent.Parent.Strings)

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
	{ id = "craft25", kind = "craft", target = 25, minutes = 5 },
	{ id = "craft80", kind = "craft", target = 80, minutes = 12 },
	{ id = "fuse3", kind = "fuse", target = 3, minutes = 8 },
	{ id = "sell10", kind = "sell", target = 10, minutes = 4 },
	{ id = "steal1", kind = "steal", target = 1, minutes = 15 },
	{ id = "slap3", kind = "slap", target = 3, minutes = 4 },
	{ id = "slapThief", kind = "slapThief", target = 1, minutes = 10 },
	{ id = "lock3", kind = "lock", target = 3, minutes = 4 },
	{ id = "mutant1", kind = "mutant", target = 1, minutes = 8 },
	{ id = "sigma5", kind = "sigmaPlus", target = 5, minutes = 10 },
	{ id = "index1", kind = "newIndex", target = 1, minutes = 10 },
}

-- Подарки за время в игре (считается с момента захода, сбрасывается при перезаходе).
Daily.Gifts = {
	{ minutes = 5, reward = { coinsMinutes = 2 } },
	{ minutes = 15, reward = { luckMinutes = 5 } },
	{ minutes = 30, reward = { coinsMinutes = 8 } },
	{ minutes = 60, reward = { creatureRarity = "sigma", coinsMinutes = 5 } },
	{ minutes = 90, reward = { coinsMinutes = 20, luckMinutes = 15 } },
	{ minutes = 120, reward = { creatureRarity = "aura", coinsMinutes = 10 } },
}

-- Колесо удачи: 1 бесплатное вращение в день + купленные. weight — относительный шанс.
Daily.Wheel = {
	{ weight = 30, reward = { coinsMinutes = 5 } },
	{ weight = 20, reward = { luckMinutes = 10 } },
	{ weight = 18, reward = { coinsMinutes = 15 } },
	{ weight = 14, reward = { creatureRarity = "sigma" } },
	{ weight = 9, reward = { luckMinutes = 30 } },
	{ weight = 6, reward = { creatureRarity = "aura" } },
	{ weight = 2, reward = { skin = "fire", coinsMinutes = 5 } },
	{ weight = 1, reward = { creatureRarity = "skibidi" } },
}

Daily.QuestById = {}
for _, quest in ipairs(Daily.QuestPool) do
	S.fill(quest, "quest." .. quest.id, "text")
	Daily.QuestById[quest.id] = quest
end
for index, slot in ipairs(Daily.Wheel) do
	S.fill(slot, "wheel." .. index, "name")
end

function Daily.today(time)
	return math.floor((time or os.time()) / 86400)
end

function Daily.coinsFor(income, minutes)
	return math.max(Daily.MIN_COINS_PER_MINUTE * minutes, math.floor(income * 60 * minutes))
end

return Daily
