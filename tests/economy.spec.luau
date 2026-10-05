-- Проверки баланса и формул.
local Rarities = shared_require("Config/Rarities")
local Creatures = shared_require("Config/Creatures")
local Capsules = shared_require("Config/Capsules")
local Levels = shared_require("Config/Levels")
local Format = shared_require("Util/Format")
local Formulas = shared_require("Util/Formulas")

local failures = 0
local function check(cond, msg)
	if not cond then
		failures += 1
		print("❌ " .. msg)
	end
end

-- 1. У каждой редкости есть брейнроты, и доход растёт с редкостью.
local prevMax = 0
for _, rarity in ipairs(Rarities.List) do
	local pool = Creatures.ByRarity[rarity.id]
	check(pool and #pool > 0, "нет брейнротов редкости " .. rarity.id)
	local minIncome = math.huge
	local maxIncome = 0
	for _, c in ipairs(pool or {}) do
		minIncome = math.min(minIncome, c.income)
		maxIncome = math.max(maxIncome, c.income)
		check(Rarities.get(c.rarity) ~= nil, "неизвестная редкость у " .. c.id)
	end
	check(minIncome > prevMax, "доход " .. rarity.id .. " не выше предыдущей редкости")
	prevMax = maxIncome
end

-- 2. Шансы каждой капсулы дают в сумме 1, при любой удаче.
for _, capsule in ipairs(Capsules.List) do
	for _, luck in ipairs({ 1, 1.5, 3, 10 }) do
		local sum = 0
		for _, entry in ipairs(Formulas.rarityChances(capsule, luck)) do
			sum += entry.chance
			check(entry.chance >= 0, "отрицательный шанс")
		end
		check(math.abs(sum - 1) < 1e-9, capsule.id .. " шансы в сумме " .. sum)
	end
	-- Удача должна повышать шанс самой редкой редкости капсулы.
	local a = Formulas.rarityChances(capsule, 1)
	local b = Formulas.rarityChances(capsule, 2)
	local lastNonSecret = #a - (a[#a].secret and 1 or 0)
	check(b[lastNonSecret].chance > a[lastNonSecret].chance, capsule.id .. ": удача не помогает")
end

-- 3. Чем популярнее тренд, тем реже: в капсуле шанс редкостей убывает (без удачи).
for _, capsule in ipairs(Capsules.List) do
	local chances = Formulas.rarityChances(capsule, 1)
	for i = 2, #chances do
		check(chances[i].chance < chances[i - 1].chance, capsule.id .. ": редкость " .. chances[i].rarity .. " не реже предыдущей")
	end
end

-- 4. Статистика бросков совпадает с шансами.
local rng = Random.new(67)
local capsule = Capsules.get("viral_meme")
local counts = {}
local N = 200000
for _ = 1, N do
	local r = Formulas.rollRarity(capsule, 1, rng)
	counts[r] = (counts[r] or 0) + 1
end
for _, entry in ipairs(Formulas.rarityChances(capsule, 1)) do
	local observed = (counts[entry.rarity] or 0) / N
	check(math.abs(observed - entry.chance) < 0.01, "бросок " .. entry.rarity .. ": " .. observed .. " vs " .. entry.chance)
end

-- 5. Форматирование чисел.
check(Format.number(999) == "999", "999 -> " .. Format.number(999))
check(Format.number(1500) == "1.5K", "1500 -> " .. Format.number(1500))
check(Format.number(1000) == "1K", "1000 -> " .. Format.number(1000))
check(Format.number(2340000) == "2.34M", "2340000 -> " .. Format.number(2340000))
check(Format.number(67000000) == "67M", "67M -> " .. Format.number(67000000))
check(Format.coins(25) == "$25", "coins 25")

-- 5b. «Создал и сразу продал» никогда не окупается, даже с огромной удачей.
local erng = Random.new(5)
for _, capsule in ipairs(Capsules.List) do
	for _, luck in ipairs({ 1, 5, 30 }) do
		local total = 0
		for _ = 1, 3000 do
			local r = Formulas.rollRarity(capsule, luck, erng)
			local c = Formulas.randomCreatureOf(r, erng)
			total += Formulas.sellValue({ id = c.id, mut = Formulas.rollMutation(luck, erng), paid = capsule.cost })
		end
		check(total / 3000 < capsule.cost, capsule.id .. ": продажа выгоднее покупки при удаче " .. luck)
	end
end

-- 5c. Достижения: проверки не падают и не выполнены у нового игрока.
local Achievements = shared_require("Config/Achievements")
local fresh = {
	coins = 0, totalEarned = 0, level = 1, rebirths = 0, creatures = {}, index = {},
	stats = { crafted = 0 }, daily = { streak = 0 },
}
local ids = {}
for _, achievement in ipairs(Achievements.List) do
	check(not ids[achievement.id], "повтор id достижения " .. achievement.id)
	ids[achievement.id] = true
	local ok, done = pcall(achievement.check, fresh)
	check(ok, "достижение " .. achievement.id .. " падает: " .. tostring(done))
	check(ok and not done, "достижение " .. achievement.id .. " выполнено у нового игрока")
end

-- 5d. Промокоды записаны заглавными (сервер приводит ввод к верхнему регистру).
for code in pairs(shared_require("Config/Codes")) do
	check(code == string.upper(code), "промокод не заглавными: " .. code)
end

-- 5e. Скины: материалы существуют, награды-скины ссылаются на настоящие скины.
local Skins = shared_require("Config/Skins")
local MATERIALS = { Neon = true, Glass = true, SmoothPlastic = true, Foil = true, ForceField = true }
for _, skin in ipairs(Skins.List) do
	check(MATERIALS[skin.material], "скин " .. skin.id .. ": неизвестный материал " .. tostring(skin.material))
end
for code, reward in pairs(shared_require("Config/Codes")) do
	check(reward.skin == nil or Skins.get(reward.skin) ~= nil, "код " .. code .. " выдаёт несуществующий скин")
end
for _, achievement in ipairs(Achievements.List) do
	check(achievement.reward.skin == nil or Skins.get(achievement.reward.skin) ~= nil, "достижение выдаёт несуществующий скин")
end

-- 5e2. Колесо: призы ссылаются на настоящие скины и редкости.
local DailyCfg = shared_require("Config/Daily")
for _, slot in ipairs(DailyCfg.Wheel) do
	check(slot.reward.skin == nil or Skins.get(slot.reward.skin) ~= nil, "колесо: нет скина " .. tostring(slot.reward.skin))
	check(slot.reward.creatureRarity == nil or Creatures.ByRarity[slot.reward.creatureRarity] ~= nil, "колесо: нет редкости")
end
for _, gift in ipairs(DailyCfg.Gifts) do
	check(gift.reward.creatureRarity == nil or Creatures.ByRarity[gift.reward.creatureRarity] ~= nil, "подарок: нет редкости")
end

-- 5g. Сезоны: сезонные брейнроты не попадают в обычные пулы, у сезонной капсулы
-- для каждой редкости есть свои брейнроты.
local Seasons = shared_require("Config/Seasons")
for _, creature in ipairs(Creatures.List) do
	if creature.season then
		check(Seasons.ById[creature.season] ~= nil, creature.id .. ": неизвестный сезон")
		for _, other in ipairs(Creatures.ByRarity[creature.rarity] or {}) do
			check(other ~= creature, creature.id .. " попал в обычный пул")
		end
	end
end
for _, capsule in ipairs(Capsules.List) do
	if capsule.season then
		for rarityId in pairs(capsule.weights) do
			local pools = Creatures.BySeason[capsule.season]
			check(pools and pools[rarityId], capsule.id .. ": нет сезонных брейнротов редкости " .. rarityId)
		end
		local season = Seasons.ById[capsule.season]
		check(Formulas.capsuleInSeason(capsule, season.startsAt + 10), "сезонная капсула должна работать в сезон")
		check(not Formulas.capsuleInSeason(capsule, season.endsAt + 10), "сезонная капсула не должна работать после сезона")
	end
end

-- 5f. Гарантия: разумные пороги у каждой капсулы.
for _, capsule in ipairs(Capsules.List) do
	local threshold = Formulas.pityThreshold(capsule)
	check(threshold >= 10 and threshold < 5000, capsule.id .. ": странный порог гарантии " .. threshold)
	print(string.format("  гарантия %-15s %-12s через %d", capsule.id, Formulas.pityRarity(capsule), threshold))
end

-- 6. Ивенты.
local Events = shared_require("Config/Events")
local hour = 1000 * 3600 -- начало какого-то часа (UTC)
check(#Events.active(hour + 5 * 60) == 0, "в 5-ю минуту не должно быть ивентов")
local m67 = Events.modifiers(hour + 6 * 60 + 30)
check(m67.secret == 6.7 and m67.mutation67 == 6.7, "Минута 67 не работает")
check(Events.modifiers(hour + 8 * 60).secret == 1, "Минута 67 должна закончиться в 8:00")
check(#Events.active(hour + 60) == 1, "в начале часа должен идти случайный ивент")
check(#Events.active(hour + 3 * 60) == 0, "случайный ивент длится 3 минуты")
local nextEvent, startsAt = Events.nextEvent(hour + 4 * 60)
check(nextEvent.id == "minute67" and startsAt == hour + 6 * 60, "следующий ивент после 4:00 — Минута 67")
local _, startsAt2 = Events.nextEvent(hour + 9 * 60)
check(startsAt2 == hour + 15 * 60, "после Минуты 67 следующий ивент в :15")
local bossNext = Events.nextEvent(hour + 20 * 60)
check(bossNext.id == "boss", "в :20 следующим должен быть босс в :30")
local bossActive = false
for _, active in ipairs(Events.active(hour + 31 * 60)) do
	bossActive = bossActive or active.event.id == "boss"
end
check(bossActive, "в :31 босс должен быть активен")
local seen = {}
for cycle = 0, 40 do
	for _, active in ipairs(Events.active(cycle * Events.CYCLE + 1)) do
		seen[active.event.id] = true
	end
end
for _, event in ipairs(Events.Random) do
	check(seen[event.id], "ивент " .. event.id .. " никогда не выпадает")
end
local Mutations = shared_require("Config/Mutations")
local plain, boosted = 0, 0
local mrng = Random.new(1)
for _ = 1, 100000 do
	if Formulas.rollMutation(1, mrng) ~= "normal" then
		plain += 1
	end
	if Formulas.rollMutation(1, mrng, { luck = 1, income = 1, mutation = 3, speed = 1, secret = 1, mutation67 = 1 }) ~= "normal" then
		boosted += 1
	end
end
check(boosted > plain * 2.5, "Мутаген-туман должен утраивать мутации")

-- 7. Симуляция: игрок крафтит лучшую доступную капсулу и покупает апгрейды.
--    Проверяем, что игра проходима и темп разумный.
local Upgrades = shared_require("Config/Upgrades")
local Rebirths = shared_require("Config/Rebirths")
local data = {
	coins = Formulas.START_COINS, level = 1, xp = 0, rebirths = 0, creatures = {},
	upgrades = { speed = 0, luck = 0, slots = 0 }, boosts = { luckUntil = 0 }, index = {},
}
local passes = {}
local t = 0
local nextCraft = 0
local milestones = {}
local function mark(name)
	if not milestones[name] then
		milestones[name] = t
	end
end
local sim = Random.new(7)
while t < 6 * 3600 do
	t += 1
	data.coins += Formulas.totalIncome(data, passes)

	-- Апгрейды, если дешевле 30% монет.
	for _, upgrade in ipairs(Upgrades.List) do
		local lvl = data.upgrades[upgrade.id] or 0
		if lvl < upgrade.maxLevel and Upgrades.cost(upgrade.id, lvl) < data.coins * 0.3 then
			data.coins -= Upgrades.cost(upgrade.id, lvl)
			data.upgrades[upgrade.id] = lvl + 1
		end
	end

	local saving = data.level >= Rebirths.levelRequired(data.rebirths)
	if t >= nextCraft and not saving then
		local best
		for _, c in ipairs(Capsules.List) do
			if not c.season and Formulas.capsuleUnlocked(c, data) and data.coins >= c.cost then
				best = c
			end
		end
		if best then
			-- База полна — продаём самого слабого.
			if #data.creatures >= Formulas.slots(data, passes) then
				table.sort(data.creatures, function(a, b)
					return Formulas.creatureBaseIncome(a) < Formulas.creatureBaseIncome(b)
				end)
				data.coins += Formulas.sellValue(table.remove(data.creatures, 1))
			end
			data.coins -= best.cost
			local luck = Formulas.luck(data, passes, 0)
			local rarity = Formulas.rollRarity(best, luck, sim)
			local c = Formulas.randomCreatureOf(rarity, sim)
			table.insert(data.creatures, { id = c.id, mut = Formulas.rollMutation(luck, sim), paid = best.cost })
			local xp = Rarities.get(rarity).xp * (data.index[c.id] and 1 or 3)
			data.index[c.id] = true
			data.xp += xp
			while data.level < Levels.MAX_LEVEL and data.xp >= Levels.xpToNext(data.level) do
				data.xp -= Levels.xpToNext(data.level)
				data.level += 1
			end
			mark("капсула " .. best.name)
			mark("уровень " .. data.level)
			mark("редкость " .. Rarities.get(rarity).name)
			nextCraft = t + Formulas.craftTime(data, passes)
		end
	end
	if data.level >= Rebirths.levelRequired(data.rebirths) and data.coins >= Rebirths.cost(data.rebirths) then
		data.rebirths += 1
		data.coins = Formulas.START_COINS
		data.creatures = {}
		data.upgrades = { speed = 0, luck = 0, slots = 0 }
		mark("перерождение " .. data.rebirths)
	end
end

local sortedMarks = {}
for name, time in pairs(milestones) do
	table.insert(sortedMarks, { name = name, time = time })
end
table.sort(sortedMarks, function(a, b)
	return a.time < b.time
end)
print("— Симуляция 6 часов игры без доната —")
for _, m in ipairs(sortedMarks) do
	print(string.format("  %6.1f мин  %s", m.time / 60, m.name))
end
print(string.format("  Итог: ур. %d, перерождений %d, доход %s/с, монет %s", data.level, data.rebirths, Format.coins(Formulas.totalIncome(data, passes)), Format.coins(data.coins)))

if failures == 0 then
	print("✅ Все проверки пройдены")
else
	print("❌ Провалено проверок: " .. failures)
	error("tests failed")
end
