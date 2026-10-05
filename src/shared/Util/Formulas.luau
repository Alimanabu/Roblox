-- Вся игровая математика в одном месте.
-- Используется и сервером (для расчётов), и клиентом (чтобы показывать цифры).
-- passes — таблица { VIP = true, LUCKY = true, ... } с купленными геймпассами.

local Config = script.Parent.Parent.Config
local Rarities = require(Config.Rarities)
local Creatures = require(Config.Creatures)
local Mutations = require(Config.Mutations)
local Capsules = require(Config.Capsules)
local Rebirths = require(Config.Rebirths)

local Formulas = {}

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

function Formulas.craftTime(data, passes)
	local time = Formulas.BASE_CRAFT_TIME * 0.82 ^ (data.upgrades.speed or 0)
	if passes.FAST_MACHINE then
		time /= 2
	end
	return math.max(Formulas.MIN_CRAFT_TIME, time)
end

function Formulas.luck(data, passes, now)
	local luck = 1 + 0.08 * (data.upgrades.luck or 0)
	luck *= 1 + Rebirths.LUCK_BONUS * data.rebirths
	if passes.LUCKY then
		luck *= 1.5
	end
	if data.boosts.luckUntil and now < data.boosts.luckUntil then
		luck *= 2
	end
	return luck
end

function Formulas.incomeMultiplier(data, passes)
	local mult = 1 + Rebirths.INCOME_BONUS * data.rebirths
	if passes.VIP then
		mult *= 2
	end
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

function Formulas.creatureIncome(entry, data, passes)
	return Formulas.creatureBaseIncome(entry) * Formulas.incomeMultiplier(data, passes)
end

function Formulas.totalIncome(data, passes)
	local total = 0
	for _, entry in ipairs(data.creatures) do
		total += Formulas.creatureBaseIncome(entry)
	end
	return total * Formulas.incomeMultiplier(data, passes)
end

function Formulas.sellValue(entry)
	return math.floor(Formulas.creatureBaseIncome(entry) * Formulas.SELL_SECONDS)
end

-- Шансы редкостей для капсулы с учётом удачи.
-- Удача умножает веса всех редкостей, кроме самой частой в капсуле:
-- «удача x2» = редкие тренды выпадают примерно в 2 раза чаще.
-- Возвращает список { rarity = id, chance = 0..1 } от обычных к редким.
function Formulas.rarityChances(capsule, luck)
	local entries = {}
	for _, rarity in ipairs(Rarities.List) do
		local weight = capsule.weights[rarity.id]
		if weight and weight > 0 then
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

	local secretChance = math.min(Capsules.SECRET_SIXSEVEN_CHANCE * luck, 0.01)
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

function Formulas.rollRarity(capsule, luck, rng)
	local chances = Formulas.rarityChances(capsule, luck)
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

function Formulas.rollMutation(luck, rng)
	local luckFactor = math.min(luck, 4)
	-- Проверяем от самой редкой мутации к самой частой.
	for index = #Mutations.List, 2, -1 do
		local mutation = Mutations.List[index]
		if rng:NextNumber() < mutation.chance * luckFactor then
			return mutation.id
		end
	end
	return "normal"
end

function Formulas.randomCreatureOf(rarityId, rng)
	local pool = Creatures.ByRarity[rarityId]
	return pool[rng:NextInteger(1, #pool)]
end

function Formulas.capsuleUnlocked(capsule, data)
	return data.level >= capsule.level and data.rebirths >= capsule.rebirths
end

return Formulas
