-- All game math in one place.
-- Used by both the server (for calculations) and the client (to show the numbers).
-- passes is a table { VIP = true, LUCKY = true, ... } of purchased game passes.

local S = require(script.Parent.Parent.Strings)

local Config = script.Parent.Parent.Config
local Rarities = require(Config.Rarities)
local Creatures = require(Config.Creatures)
local Mutations = require(Config.Mutations)
local Capsules = require(Config.Capsules)
local Rebirths = require(Config.Rebirths)
local Seasons = require(Config.Seasons)

local Formulas = {}

-- mods are multipliers from events (see Config/Events). If not passed: no events.
local NO_MODS = { luck = 1, income = 1, mutation = 1, speed = 1, secret = 1, mutation67 = 1 }
Formulas.NO_MODS = NO_MODS

Formulas.START_COINS = 150 -- enough for the first capsule
Formulas.BASE_CRAFT_TIME = 3
Formulas.MIN_CRAFT_TIME = 0.3
Formulas.SELL_SECONDS = 20 -- a brainrot sells for 20 seconds of its income
Formulas.FUSE_COUNT = 3 -- how many of the same rarity are needed for fusing
Formulas.OFFLINE_RATE = 0.5 -- 50% of income while the player is away
Formulas.OFFLINE_MAX_SECONDS = 3 * 60 * 60 -- the game description promises "up to 3 hours" (docs/LAUNCH.md)
Formulas.OFFLINE_MIN_SECONDS = 60 -- a shorter break (a server hop) brings nothing
Formulas.WELCOME_MIN_SECONDS = 10 * 60 -- away at least this long: the "Welcome back" window instead of a notification

-- Coins earned while away: half of the income per second, for at most OFFLINE_MAX_SECONDS.
-- income: coins per second when the player left the game, away: seconds since the last save.
function Formulas.offlineIncome(income, away)
	if type(income) ~= "number" or type(away) ~= "number" or income ~= income or away ~= away then
		return 0
	end
	if away < Formulas.OFFLINE_MIN_SECONDS or income <= 0 then
		return 0
	end
	return math.floor(income * math.min(away, Formulas.OFFLINE_MAX_SECONDS) * Formulas.OFFLINE_RATE)
end

-- Base floors. First brainrots stand right on the ground, then floors are bought.
-- The strongest brainrots stand on top: more income there and they are harder to steal.
-- hp is how many times a thief must slap a brainrot before it can be grabbed.
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

-- How many floors are built (the "Huge Base" game pass gives 1 floor right away).
function Formulas.floors(data, passes)
	local floors = math.clamp(data.floors or 0, 0, Formulas.MAX_FLOORS)
	if passes.BIG_BASE then
		floors = math.max(floors, 1)
	end
	return floors
end

-- The price of the next floor (nil: all built). With "Huge Base" floor 2 is half price.
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

-- Which floor a spot is on: spots 1..10 are on the bottom (ground or floor 1), 11..20 on floor 2.
function Formulas.floorOfPad(pad, floors)
	if pad > Formulas.FLOOR_SLOTS then
		return 2
	end
	return math.min(floors, 1)
end

-- Layout of brainrots over spots. The strongest go on top.
-- Returns a list { entry, pad, floor } (those who did not fit have no pad) and how many spots are on the bottom and on top.
-- The bottom may hold more than the limit: for example, a brainrot came back after a failed steal.
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

Formulas.LUCKY_MULT = 1.5 -- "Lucky" game pass
Formulas.LUCK_BOOST_MULT = 2 -- luck boost
Formulas.MAX_SECRET_CHANCE = 0.01 -- luck does not raise the secret above this
Formulas.MAX_MUTATION_LUCK = 4 -- luck stronger than this does not affect mutations

-- Whether the boost is active now. noPaidLuck: the bought part (the remainder after a region change) does not work,
-- the free tail after it is kept: boosts are also given for free (streak, gifts).
function Formulas.boostActive(data, now, noPaidLuck)
	if not data.boosts.luckUntil or now >= data.boosts.luckUntil then
		return false
	end
	return not noPaidLuck or not data.boosts.paidLuckUntil or now >= data.boosts.paidLuckUntil
end

-- noPaidLuck: Roblox forbids paid random rewards for the player, paid luck does not affect the odds.
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

-- Where a brainrot came from (entry.source). Where Roblox forbids paid random rewards,
-- everything except SOURCE_FREE can be neither given nor received in a trade (see TradeService).
Formulas.SOURCE_FREE = "free" -- a capsule for earned coins, a reward, a wild brainrot
Formulas.SOURCE_COINS = "coins" -- a capsule for bought coins, at least partly
Formulas.SOURCE_LUCK = "luck" -- a roll with LUCKY or a bought boost
Formulas.SOURCE_SPIN = "spin" -- a bought wheel spin

-- No mark: source unknown, we treat it as paid.
function Formulas.isPaidRandom(entry)
	return entry.source ~= Formulas.SOURCE_FREE
end

-- How many coins can be spent on something that leads to a random reward. Where Roblox forbids
-- paid random rewards, Robux coins do not go to it. Fits both the data and the client snapshot.
function Formulas.randomCoins(data, restricted)
	if restricted then
		return math.max(data.coins - data.boughtCoins, 0)
	end
	return data.coins
end

-- Whether bought luck went into the roll. A boost received for free does not count here.
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
	-- Bonus for friends / group / Premium (computed by the server, see SocialService).
	mult *= 1 + (passes.socialBonus or 0)
	return mult
end

-- Income of one brainrot without global multipliers.
function Formulas.creatureBaseIncome(entry)
	local creature = Creatures.get(entry.id)
	if not creature then
		return 0
	end
	return creature.income * Mutations.get(entry.mut).mult
end

-- floor is the floor the brainrot stands on (more income on top).
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

Formulas.SELL_PAID_SHARE = 0.6 -- can be sold for at most 60% of what was spent

function Formulas.sellValue(entry)
	local value = math.floor(Formulas.creatureBaseIncome(entry) * Formulas.SELL_SECONDS)
	if entry.paid then
		value = math.min(value, math.floor(entry.paid * Formulas.SELL_PAID_SHARE))
	end
	return value
end

-- Guaranteed attempt: everything below the guarantee rarity turns into it.
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

-- Rarity odds for a capsule taking luck into account.
-- Luck multiplies the weights of all rarities except the most common in the capsule:
-- "luck x2" = rare trends drop about 2 times more often.
-- Returns a list { rarity = id, chance = 0..1 } from common to rare, summing to exactly 1.
-- pity is attempts without the capsule's rarest rarity: on the guaranteed attempt the odds are different.
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

-- Guarantee: the capsule's rarest rarity (without secrets) and after how many attempts
-- it drops for sure. Threshold = 3 average "expectations" without luck.
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

-- An attempt counted: which rarity finally dropped, the new guarantee counter and whether it triggered.
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

-- The chance of one mutation check: the check runs only if all rarer ones did not drop.
local function mutationRoll(mutation, luck, mods)
	local chance = mutation.chance * math.min(luck, Formulas.MAX_MUTATION_LUCK) * mods.mutation
	if mutation.id == "sixseven" then
		chance *= mods.mutation67
	end
	return math.min(chance, 1)
end

function Formulas.rollMutation(luck, rng, mods)
	mods = mods or NO_MODS
	-- We check from the rarest mutation to the most common.
	for index = #Mutations.List, 2, -1 do
		local mutation = Mutations.List[index]
		if rng:NextNumber() < mutationRoll(mutation, luck, mods) then
			return mutation.id
		end
	end
	return "normal"
end

-- The real odds of rollMutation outcomes: { mutation = id, chance = 0..1 }, summing to exactly 1.
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

-- season is for a seasonal capsule: we take the season's brainrots (if there is none of that rarity, regular ones).
function Formulas.creaturePool(rarityId, season)
	local seasonPools = season and Creatures.BySeason[season]
	return (seasonPools and seasonPools[rarityId]) or Creatures.ByRarity[rarityId]
end

function Formulas.randomCreatureOf(rarityId, rng, season)
	local pool = Formulas.creaturePool(rarityId, season)
	return pool[rng:NextInteger(1, #pool)]
end

-- A seasonal capsule is available only during the season. now is Unix time (server: os.time,
-- client: workspace:GetServerTimeNow()).
function Formulas.capsuleInSeason(capsule, now)
	return capsule.season == nil or Seasons.isActive(capsule.season, now or os.time())
end

-- A brainrot's "lineage": { ["UserId"] = the earliest generation (rebirth number)
-- in which this player owned it }. You cannot get a brainrot back from a "past life"
-- (by trade, steal or fusing at a friend's).
function Formulas.lineageOf(entry, fallbackUserId, fallbackGen)
	if entry.lineage then
		return entry.lineage
	end
	-- Old format (origin/gen) or very old entries.
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

-- The very first capsule of a player is free: the first ordinary capsule, before anything was crafted.
-- Once per life (stats.crafted only grows), a free brainrot sells for 0 (its paid price is 0).
function Formulas.isFreeCraft(capsule, data)
	return capsule == Capsules.List[1] and data.stats ~= nil and data.stats.crafted == 0
end

function Formulas.capsuleCost(capsule, data)
	return if Formulas.isFreeCraft(capsule, data) then 0 else capsule.cost
end

function Formulas.capsuleUnlocked(capsule, data)
	return data.level >= capsule.level and data.rebirths >= capsule.rebirths
end

return Formulas
