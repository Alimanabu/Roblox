-- Вся игровая математика в одном месте.
-- Используется и сервером (для расчётов), и клиентом (чтобы показывать цифры).
-- passes — таблица { VIP = true, LUCKY = true, ... } с купленными геймпассами.

local Config = script.Parent.Parent.Config
local Rarities = require(Config.Rarities)
local Creatures = require(Config.Creatures)
local Mutations = require(Config.Mutations)
local Capsules = require(Config.Capsules)
local Rebirths = require(Config.Rebirths)
local Seasons = require(Config.Seasons)

local Formulas = {}

-- mods — множители от ивентов (см. Config/Events). Если не передали — без ивентов.
local NO_MODS = { luck = 1, income = 1, mutation = 1, speed = 1, secret = 1, mutation67 = 1 }
Formulas.NO_MODS = NO_MODS

Formulas.START_COINS = 150 -- хватает на первую капсулу
Formulas.BASE_SLOTS = 8
Formulas.BIG_BASE_SLOTS = 10
Formulas.BASE_CRAFT_TIME = 3
Formulas.MIN_CRAFT_TIME = 0.3
Formulas.SELL_SECONDS = 20 -- брейнрот продаётся за 20 секунд своего дохода
Formulas.FUSE_COUNT = 3 -- сколько одинаковых по редкости нужно для скрещивания
Formulas.OFFLINE_RATE = 0.5 -- 50% дохода, пока игрока нет
Formulas.OFFLINE_MAX_SECONDS = 3 * 60 * 60

function Formulas.slots(data, passes)
	local slots = Formulas.BASE_SLOTS + (data.upgrades.slots or 0)
	if passes.BIG_BASE then
		slots += Formulas.BIG_BASE_SLOTS
	end
	return slots
end

function Formulas.craftTime(data, passes, mods)
	mods = mods or NO_MODS
	local time = Formulas.BASE_CRAFT_TIME * 0.82 ^ (data.upgrades.speed or 0)
	if passes.FAST_MACHINE then
		time /= 2
	end
	time /= mods.speed
	return math.max(Formulas.MIN_CRAFT_TIME, time)
end

function Formulas.luck(data, passes, now, mods)
	mods = mods or NO_MODS
	local luck = (1 + 0.08 * (data.upgrades.luck or 0)) * mods.luck
	luck *= 1 + Rebirths.LUCK_BONUS * data.rebirths
	if passes.LUCKY then
		luck *= 1.5
	end
	if data.boosts.luckUntil and now < data.boosts.luckUntil then
		luck *= 2
	end
	return luck
end

function Formulas.incomeMultiplier(data, passes, mods)
	mods = mods or NO_MODS
	local mult = (1 + Rebirths.INCOME_BONUS * data.rebirths) * mods.income
	if passes.VIP then
		mult *= 2
	end
	-- Бонус за друзей / группу / Premium (считает сервер, см. SocialService).
	mult *= 1 + (passes.socialBonus or 0)
	return mult
end

-- Доход одного брейнрота без глобальных множителей.
function Formulas.creatureBaseIncome(entry)
	local creature = Creatures.get(entry.id)
	if not creature then
		return 0
	end
	return creature.income * Mutations.get(entry.mut).mult
end

function Formulas.creatureIncome(entry, data, passes, mods)
	return Formulas.creatureBaseIncome(entry) * Formulas.incomeMultiplier(data, passes, mods)
end

function Formulas.totalIncome(data, passes, mods)
	local total = 0
	for _, entry in ipairs(data.creatures) do
		total += Formulas.creatureBaseIncome(entry)
	end
	return total * Formulas.incomeMultiplier(data, passes, mods)
end

Formulas.SELL_PAID_SHARE = 0.6 -- продать можно максимум за 60% от потраченного

function Formulas.sellValue(entry)
	local value = math.floor(Formulas.creatureBaseIncome(entry) * Formulas.SELL_SECONDS)
	if entry.paid then
		value = math.min(value, math.floor(entry.paid * Formulas.SELL_PAID_SHARE))
	end
	return value
end

-- Шансы редкостей для капсулы с учётом удачи.
-- Удача умножает веса всех редкостей, кроме самой частой в капсуле:
-- «удача x2» = редкие тренды выпадают примерно в 2 раза чаще.
-- Возвращает список { rarity = id, chance = 0..1 } от обычных к редким.
function Formulas.rarityChances(capsule, luck, mods)
	mods = mods or NO_MODS
	local entries = {}
	for _, rarity in ipairs(Rarities.List) do
		local weight = capsule.weights[rarity.id]
		if weight and weight > 0 then
			if rarity.id == "sixseven" then
				weight *= mods.secret
			end
			table.insert(entries, { rarity = rarity.id, weight = weight })
		end
	end

	local total = 0
	for position, entry in ipairs(entries) do
		if position > 1 then
			entry.weight *= luck
		end
		total += entry.weight
	end

	local secretChance = math.min(Capsules.SECRET_SIXSEVEN_CHANCE * luck * mods.secret, 0.01)
	local hasSixSeven = capsule.weights.sixseven ~= nil

	local result = {}
	for _, entry in ipairs(entries) do
		local chance = entry.weight / total
		if not hasSixSeven then
			chance *= 1 - secretChance
		end
		table.insert(result, { rarity = entry.rarity, chance = chance })
	end
	if not hasSixSeven then
		table.insert(result, { rarity = "sixseven", chance = secretChance, secret = true })
	end
	return result
end

function Formulas.rollRarity(capsule, luck, rng, mods)
	local chances = Formulas.rarityChances(capsule, luck, mods)
	local roll = rng:NextNumber()
	local accumulated = 0
	for _, entry in ipairs(chances) do
		accumulated += entry.chance
		if roll < accumulated then
			return entry.rarity
		end
	end
	return chances[#chances - (chances[#chances].secret and 1 or 0)].rarity
end

-- Гарантия: самая редкая редкость капсулы (без секретов) и через сколько попыток
-- она выпадет точно. Порог = 3 средних «ожидания» без удачи.
function Formulas.pityRarity(capsule)
	local top
	for _, rarity in ipairs(Rarities.List) do
		if capsule.weights[rarity.id] then
			top = rarity.id
		end
	end
	return top
end

function Formulas.pityThreshold(capsule)
	local top = Formulas.pityRarity(capsule)
	for _, entry in ipairs(Formulas.rarityChances(capsule, 1)) do
		if entry.rarity == top and not entry.secret then
			return math.ceil(3 / entry.chance)
		end
	end
	return math.huge
end

function Formulas.rollMutation(luck, rng, mods)
	mods = mods or NO_MODS
	local luckFactor = math.min(luck, 4) * mods.mutation
	-- Проверяем от самой редкой мутации к самой частой.
	for index = #Mutations.List, 2, -1 do
		local mutation = Mutations.List[index]
		local chance = mutation.chance * luckFactor
		if mutation.id == "sixseven" then
			chance *= mods.mutation67
		end
		if rng:NextNumber() < chance then
			return mutation.id
		end
	end
	return "normal"
end

-- season — для сезонной капсулы: берём брейнротов сезона (если такой редкости нет — обычных).
function Formulas.randomCreatureOf(rarityId, rng, season)
	local seasonPools = season and Creatures.BySeason[season]
	local pool = (seasonPools and seasonPools[rarityId]) or Creatures.ByRarity[rarityId]
	return pool[rng:NextInteger(1, #pool)]
end

-- Сезонная капсула доступна только во время сезона. now — Unix-время (сервер: os.time,
-- клиент: workspace:GetServerTimeNow()).
function Formulas.capsuleInSeason(capsule, now)
	return capsule.season == nil or Seasons.isActive(capsule.season, now or os.time())
end

function Formulas.capsuleUnlocked(capsule, data)
	return data.level >= capsule.level and data.rebirths >= capsule.rebirths
end

return Formulas
