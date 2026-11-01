-- Вся игровая математика в одном месте.
-- Используется и сервером (для расчётов), и клиентом (чтобы показывать цифры).
-- passes — таблица { VIP = true, LUCKY = true, ... } с купленными геймпассами.

local S = require(script.Parent.Parent.Strings)

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
Formulas.BASE_CRAFT_TIME = 3
Formulas.MIN_CRAFT_TIME = 0.3
Formulas.SELL_SECONDS = 20 -- брейнрот продаётся за 20 секунд своего дохода
Formulas.FUSE_COUNT = 3 -- сколько одинаковых по редкости нужно для скрещивания
Formulas.OFFLINE_RATE = 0.5 -- 50% дохода, пока игрока нет
Formulas.OFFLINE_MAX_SECONDS = 3 * 60 * 60

-- Этажи базы. Сначала брейнроты стоят прямо на земле, потом этажи покупаются.
-- Сильнейшие брейнроты встают наверх: там больше дохода и их труднее украсть.
-- hp — сколько раз вор должен шлёпнуть брейнрота, прежде чем его можно схватить.
Formulas.FLOOR_SLOTS = 10
Formulas.Floors = {
	[0] = { slots = 5, hp = 5, income = 1, stealTime = 1 },
	{ cost = 100_000, slots = 10, hp = 10, income = 1, stealTime = 1 },
	{ cost = 100_000_000, slots = 10, hp = 20, income = 2, stealTime = 2 },
}
Formulas.MAX_FLOORS = #Formulas.Floors
for index = 0, Formulas.MAX_FLOORS do
	S.fill(Formulas.Floors[index], "floor." .. index, "name")
end

-- Сколько этажей построено (геймпасс «Огромная база» сразу даёт 1 этаж).
function Formulas.floors(data, passes)
	local floors = math.clamp(data.floors or 0, 0, Formulas.MAX_FLOORS)
	if passes.BIG_BASE then
		floors = math.max(floors, 1)
	end
	return floors
end

-- Цена следующего этажа (nil — всё построено). С «Огромной базой» 2 этаж за полцены.
function Formulas.floorCost(floors, passes)
	local floor = Formulas.Floors[floors + 1]
	if not floor then
		return nil
	end
	if passes.BIG_BASE and floors + 1 >= 2 then
		return math.floor(floor.cost / 2)
	end
	return floor.cost
end

local function slotsForFloors(floors)
	if floors == 0 then
		return Formulas.Floors[0].slots
	end
	local slots = 0
	for level = 1, floors do
		slots += Formulas.Floors[level].slots
	end
	return slots
end

function Formulas.slots(data, passes)
	return slotsForFloors(Formulas.floors(data, passes))
end

-- Какой этаж у места: места 1..10 — внизу (земля или 1 этаж), 11..20 — на 2 этаже.
function Formulas.floorOfPad(pad, floors)
	if pad > Formulas.FLOOR_SLOTS then
		return 2
	end
	return math.min(floors, 1)
end

-- Раскладка брейнротов по местам. Сильнейшие — наверх.
-- Возвращает список { entry, pad, floor } (кто не влез — без pad) и сколько мест внизу и наверху.
-- Внизу мест может быть больше лимита: например, брейнрот вернулся после неудачной кражи.
function Formulas.layout(creatures, floors)
	local sorted = table.clone(creatures)
	table.sort(sorted, function(a, b)
		local ia, ib = Formulas.creatureBaseIncome(a), Formulas.creatureBaseIncome(b)
		if ia == ib then
			return tostring(a.uid) < tostring(b.uid)
		end
		return ia > ib
	end)
	local upper = floors >= 2 and Formulas.FLOOR_SLOTS or 0
	local onTop = math.min(#sorted, upper)
	local lowerSlots = floors == 0 and Formulas.Floors[0].slots or Formulas.FLOOR_SLOTS
	local lower = math.min(math.max(lowerSlots, #sorted - onTop), Formulas.FLOOR_SLOTS)

	local places = {}
	for index, entry in ipairs(sorted) do
		local pad
		if index <= onTop then
			pad = Formulas.FLOOR_SLOTS + index
		elseif index - onTop <= lower then
			pad = index - onTop
		end
		table.insert(places, { entry = entry, pad = pad, floor = pad and Formulas.floorOfPad(pad, floors) or nil })
	end
	return places, lower, upper
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

Formulas.LUCKY_MULT = 1.5 -- геймпасс «Счастливчик»
Formulas.LUCK_BOOST_MULT = 2 -- буст удачи
Formulas.MAX_SECRET_CHANCE = 0.01 -- выше удача секрет не поднимает
Formulas.MAX_MUTATION_LUCK = 4 -- удача сильнее этой на мутации не влияет

-- Действует ли буст сейчас. noPaidLuck: купленная часть (остаток после смены региона) не действует,
-- бесплатный хвост после неё сохраняется: буст дают и бесплатно (серия, подарки).
function Formulas.boostActive(data, now, noPaidLuck)
	if not data.boosts.luckUntil or now >= data.boosts.luckUntil then
		return false
	end
	return not noPaidLuck or not data.boosts.paidLuckUntil or now >= data.boosts.paidLuckUntil
end

-- noPaidLuck: Roblox запрещает игроку платные случайные награды, платная удача на шансы не влияет.
function Formulas.luck(data, passes, now, mods, noPaidLuck)
	mods = mods or NO_MODS
	local luck = (1 + 0.08 * (data.upgrades.luck or 0)) * mods.luck
	luck *= 1 + Rebirths.LUCK_BONUS * data.rebirths
	if passes.LUCKY and not noPaidLuck then
		luck *= Formulas.LUCKY_MULT
	end
	if Formulas.boostActive(data, now, noPaidLuck) then
		luck *= Formulas.LUCK_BOOST_MULT
	end
	return luck
end

-- Откуда брейнрот (entry.source). Там, где Roblox запрещает платные случайные награды,
-- всё кроме SOURCE_FREE нельзя ни отдать, ни получить в обмене (см. TradeService).
Formulas.SOURCE_FREE = "free" -- капсула за заработанные монеты, награда, дикий брейнрот
Formulas.SOURCE_COINS = "coins" -- капсула за купленные монеты, хотя бы частично
Formulas.SOURCE_LUCK = "luck" -- бросок с LUCKY или купленным бустом
Formulas.SOURCE_SPIN = "spin" -- купленное вращение колеса

-- Нет пометки: источник неизвестен, считаем платным.
function Formulas.isPaidRandom(entry)
	return entry.source ~= Formulas.SOURCE_FREE
end

-- Сколько монет можно потратить на то, что ведёт к случайной награде. Там, где Roblox запрещает
-- платные случайные награды, монеты за Robux на это не идут. Подходит и данным, и снимку клиента.
function Formulas.randomCoins(data, restricted)
	if restricted then
		return math.max(data.coins - data.boughtCoins, 0)
	end
	return data.coins
end

-- Вошла ли в бросок купленная удача. Буст, полученный бесплатно, сюда не считается.
function Formulas.usesPaidLuck(data, passes, now, noPaidLuck)
	if noPaidLuck then
		return false
	end
	if passes.LUCKY then
		return true
	end
	return data.boosts.paidLuckUntil ~= nil and now < data.boosts.paidLuckUntil
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

-- floor — этаж, на котором стоит брейнрот (наверху доход больше).
function Formulas.creatureIncome(entry, data, passes, mods, floor)
	local floorMult = floor and Formulas.Floors[floor].income or 1
	return Formulas.creatureBaseIncome(entry) * floorMult * Formulas.incomeMultiplier(data, passes, mods)
end

function Formulas.totalIncome(data, passes, mods)
	local total = 0
	local places = Formulas.layout(data.creatures, Formulas.floors(data, passes))
	for _, place in ipairs(places) do
		local floorMult = place.floor and Formulas.Floors[place.floor].income or 1
		total += Formulas.creatureBaseIncome(place.entry) * floorMult
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

-- Гарантированная попытка: всё, что ниже редкости гарантии, превращается в неё.
local function withGuarantee(chances, top)
	local rank = Rarities.get(top).rank
	local result = {}
	local guaranteed
	for _, entry in ipairs(chances) do
		if Rarities.get(entry.rarity).rank > rank then
			table.insert(result, entry)
		elseif guaranteed then
			guaranteed.chance += entry.chance
		else
			guaranteed = { rarity = top, chance = entry.chance }
			table.insert(result, guaranteed)
		end
	end
	return result
end

-- Шансы редкостей для капсулы с учётом удачи.
-- Удача умножает веса всех редкостей, кроме самой частой в капсуле:
-- «удача x2» = редкие тренды выпадают примерно в 2 раза чаще.
-- Возвращает список { rarity = id, chance = 0..1 } от обычных к редким, в сумме ровно 1.
-- pity — попыток без самой редкой редкости капсулы: на гарантированной попытке шансы другие.
function Formulas.rarityChances(capsule, luck, mods, pity)
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

	local secretChance = math.min(Capsules.SECRET_SIXSEVEN_CHANCE * luck * mods.secret, Formulas.MAX_SECRET_CHANCE)
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
	if pity and pity + 1 >= Formulas.pityThreshold(capsule) then
		return withGuarantee(result, Formulas.pityRarity(capsule))
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

-- Попытка засчитана: какая редкость выпала в итоге, новый счётчик гарантии и сработала ли она.
function Formulas.applyPity(capsule, rarityId, pity)
	local top = Rarities.get(Formulas.pityRarity(capsule)).rank
	local count = pity + 1
	local forced = count >= Formulas.pityThreshold(capsule) and Rarities.get(rarityId).rank < top
	if forced then
		rarityId = Formulas.pityRarity(capsule)
	end
	if Rarities.get(rarityId).rank >= top then
		count = 0
	end
	return rarityId, count, forced
end

-- Шанс одной проверки мутации: проверка идёт, только если все более редкие не выпали.
local function mutationRoll(mutation, luck, mods)
	local chance = mutation.chance * math.min(luck, Formulas.MAX_MUTATION_LUCK) * mods.mutation
	if mutation.id == "sixseven" then
		chance *= mods.mutation67
	end
	return math.min(chance, 1)
end

function Formulas.rollMutation(luck, rng, mods)
	mods = mods or NO_MODS
	-- Проверяем от самой редкой мутации к самой частой.
	for index = #Mutations.List, 2, -1 do
		local mutation = Mutations.List[index]
		if rng:NextNumber() < mutationRoll(mutation, luck, mods) then
			return mutation.id
		end
	end
	return "normal"
end

-- Настоящие шансы исходов rollMutation: { mutation = id, chance = 0..1 }, в сумме ровно 1.
function Formulas.mutationChances(luck, mods)
	mods = mods or NO_MODS
	local left = 1
	local result = {}
	for index = #Mutations.List, 2, -1 do
		local mutation = Mutations.List[index]
		local chance = left * mutationRoll(mutation, luck, mods)
		left -= chance
		table.insert(result, 1, { mutation = mutation.id, chance = chance })
	end
	table.insert(result, 1, { mutation = "normal", chance = left })
	return result
end

-- season — для сезонной капсулы: берём брейнротов сезона (если такой редкости нет — обычных).
function Formulas.creaturePool(rarityId, season)
	local seasonPools = season and Creatures.BySeason[season]
	return (seasonPools and seasonPools[rarityId]) or Creatures.ByRarity[rarityId]
end

function Formulas.randomCreatureOf(rarityId, rng, season)
	local pool = Formulas.creaturePool(rarityId, season)
	return pool[rng:NextInteger(1, #pool)]
end

-- Сезонная капсула доступна только во время сезона. now — Unix-время (сервер: os.time,
-- клиент: workspace:GetServerTimeNow()).
function Formulas.capsuleInSeason(capsule, now)
	return capsule.season == nil or Seasons.isActive(capsule.season, now or os.time())
end

-- «Родословная» брейнрота: { ["UserId"] = самое раннее поколение (номер перерождения),
-- в котором этот игрок им владел }. Нельзя вернуть себе брейнрота «из прошлой жизни»
-- (обменом, кражей или через скрещивание у друга).
function Formulas.lineageOf(entry, fallbackUserId, fallbackGen)
	if entry.lineage then
		return entry.lineage
	end
	-- Старый формат (origin/gen) или совсем старые записи.
	return { [tostring(entry.origin or fallbackUserId)] = entry.gen or fallbackGen or 0 }
end

function Formulas.mergeLineage(target, lineage)
	for userId, gen in pairs(lineage) do
		target[userId] = math.min(target[userId] or math.huge, gen)
	end
	return target
end

function Formulas.isFromPastLife(entry, userId, rebirths)
	local gen = entry.lineage and entry.lineage[tostring(userId)]
	if gen == nil and entry.origin == userId then
		gen = entry.gen or 0
	end
	return gen ~= nil and rebirths > gen
end

function Formulas.capsuleUnlocked(capsule, data)
	return data.level >= capsule.level and data.rebirths >= capsule.rebirths
end

return Formulas
