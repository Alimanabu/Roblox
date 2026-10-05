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

-- 6. Симуляция: игрок крафтит лучшую доступную капсулу и покупает апгрейды.
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
		local lvl = data.upgrades[upgrade.id]
		if lvl < upgrade.maxLevel and Upgrades.cost(upgrade.id, lvl) < data.coins * 0.3 then
			data.coins -= Upgrades.cost(upgrade.id, lvl)
			data.upgrades[upgrade.id] = lvl + 1
		end
	end

	local saving = data.level >= Rebirths.levelRequired(data.rebirths)
	if t >= nextCraft and not saving then
		local best
		for _, c in ipairs(Capsules.List) do
			if Formulas.capsuleUnlocked(c, data) and data.coins >= c.cost then
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
			table.insert(data.creatures, { id = c.id, mut = Formulas.rollMutation(luck, sim) })
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
