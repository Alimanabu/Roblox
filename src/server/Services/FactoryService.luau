-- Brainrot factory: crafting from capsules, selling, fusing, auto factory.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local S = require(Shared.Strings)
local Capsules = require(Shared.Config.Capsules)
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local Formulas = require(Shared.Util.Formulas)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local PolicyService = require(script.Parent.PolicyService)
local ProgressionService = require(script.Parent.ProgressionService)
local Actions = require(script.Parent.Actions)
local AnalyticsService = require(script.Parent.AnalyticsService)
local EventService = require(script.Parent.EventService)

local FactoryService = {}

local BAD = Color3.fromRGB(255, 110, 110)
local GOOD = Color3.fromRGB(120, 255, 120)

local rng = Random.new()
local lastCraft = {} -- [player] = os.clock()
local autoCraft = {} -- [player] = capsuleId
local fullWarned = {} -- [player] = true, so we do not spam "base is full"

FactoryService.CreaturesChanged = Instance.new("BindableEvent")

function FactoryService.autoCraftCapsule(player)
	return autoCraft[player]
end

local function creatureLabel(creatureId, mutationId)
	local creature = Creatures.get(creatureId)
	local mutation = Mutations.get(mutationId)
	if mutation.id == "normal" then
		return S.m(creature.nameKey)
	end
	return S.m("creature.mutated", { mutation = S.m(mutation.nameKey), name = S.m(creature.nameKey) })
end

-- paid is how many coins were paid for it (a capsule or the sum of the fused ones);
-- selling for more than 60% of it is not allowed, otherwise "craft-sell" prints money.
local SHOWCASE_COOLDOWN = 15 -- at most once per 15 s per player
local lastShowcase = {} -- [player] = os.clock()

-- showcase = true means this is a truly rare find (see craft): start the show.
-- source: where the brainrot came from (see Formulas.SOURCE_FREE).
local function addCreature(player, data, creatureId, mutationId, paid, lineage, showcase, source)
	-- lineage: who owned the brainrot and in which "generation" (see Formulas.lineageOf).
	local entry = {
		uid = tostring(data.nextUid),
		id = creatureId,
		mut = mutationId,
		paid = paid,
		source = source,
		lineage = Formulas.mergeLineage(lineage or {}, { [tostring(player.UserId)] = data.rebirths }),
	}
	data.nextUid += 1
	table.insert(data.creatures, entry)

	local isNew = not data.index[creatureId]
	data.index[creatureId] = true

	local creature = Creatures.get(creatureId)
	local rarity = Rarities.get(creature.rarity)
	local mutation = Mutations.get(mutationId)

	ProgressionService.addXp(player, data, rarity.xp * (isNew and 3 or 1))
	if rarity.rank >= Rarities.get("sigma").rank then
		Actions.fire(player, "sigmaPlus", 1)
	end
	if mutation.id ~= "normal" then
		Actions.fire(player, "mutant", 1)
	end
	if isNew then
		Actions.fire(player, "newIndex", 1)
	end

	-- Light show for the whole server: SIX SEVEN, mutation 67/Cosmic or a "rare find"
	-- (the rarest rarity of its capsule, for example God from the Mega Trend, but not God
	-- from the World Trend, where it drops almost always).
	local special = rarity.id == "sixseven" or mutation.rank >= 5 or showcase == true
	local now = os.clock()
	if special and (not lastShowcase[player] or now - lastShowcase[player] > SHOWCASE_COOLDOWN) then
		lastShowcase[player] = now
		Remotes.LegendaryDrop:FireAllClients({
			userId = player.UserId,
			name = player.DisplayName,
			creatureId = creatureId,
			mut = mutationId,
		})
	end
	if rarity.announce or mutation.rank >= 4 then
		Remotes.Notify:FireAllClients(
			S.m("factory.announce", { player = player.DisplayName, name = creatureLabel(creatureId, mutationId), rarity = S.m(rarity.nameKey) }),
			rarity.color,
			true
		)
	end

	FactoryService.CreaturesChanged:Fire(player)
	DataService.markDirty(player)
	return entry, isNew
end

-- Give a brainrot directly (rewards, test commands). Returns the entry.
function FactoryService.give(player, creatureId, mutationId, source)
	local data = DataService.get(player)
	if not data or not Creatures.get(creatureId) then
		return nil
	end
	local rank = Rarities.get(Creatures.get(creatureId).rarity).rank
	return (addCreature(player, data, creatureId, mutationId or "normal", nil, nil, rank >= Rarities.get("god").rank, source or Formulas.SOURCE_FREE))
end

-- Returns true if it was created.
local function craft(player, capsuleId, silent)
	local data = DataService.get(player)
	local capsule = type(capsuleId) == "string" and Capsules.get(capsuleId)
	if not data or not capsule then
		return false
	end
	local passes = MonetizationService.passes(player)

	local function fail(text)
		if not silent then
			Remotes.Notify:FireClient(player, text, BAD)
		end
		return false
	end

	if not Formulas.capsuleUnlocked(capsule, data) then
		return fail(S.m("factory.capsule_locked"))
	end
	if not Formulas.capsuleInSeason(capsule, os.time()) then
		if autoCraft[player] == capsule.id then
			autoCraft[player] = nil
			DataService.markDirty(player)
			Remotes.Notify:FireClient(player, S.m("factory.season_over_auto"), BAD)
		end
		return fail(S.m("factory.season_over"))
	end
	local now = os.clock()
	-- A small margin for ping.
	local mods = EventService.mods()
	if lastCraft[player] and now - lastCraft[player] < Formulas.craftTime(data, passes, mods) * 0.9 then
		return false
	end
	if #data.creatures >= Formulas.slots(data, passes) then
		if not silent or not fullWarned[player] then
			Remotes.Notify:FireClient(player, S.m("factory.base_full"), BAD)
		end
		fullWarned[player] = true
		return false
	end
	-- The first capsule of a newbie is free (Formulas.isFreeCraft): the tutorial starts with a sure win.
	local cost = Formulas.capsuleCost(capsule, data)
	local free = cost == 0
	if data.coins < cost then
		return fail(S.m("common.not_enough_coins", { cost = Format.coins(cost) }))
	end
	local restricted = PolicyService.paidRandomRestricted(player)
	local earned = Formulas.randomCoins(data, restricted)
	if earned < cost then
		return fail(PolicyService.message(player, "shop.bought_coins", { coins = Format.coins(cost - earned) }))
	end

	lastCraft[player] = now
	fullWarned[player] = nil
	-- The capsule spends bought coins first. When restricted it is paid with earned ones (see above),
	-- and the bought ones stay on the balance.
	local bought = if restricted then 0 else math.min(data.boughtCoins, data.coins)
	data.coins -= cost
	if not restricted then
		data.boughtCoins = math.max(bought - cost, 0)
	end
	AnalyticsService.coins(player, false, cost, "Capsule")
	data.stats.crafted += 1

	local luck = MonetizationService.luck(player, data, os.time(), mods)
	local rarityId = Formulas.rollRarity(capsule, luck, rng, mods)

	-- Guarantee: after a long unlucky streak the capsule's rarest rarity drops for sure.
	local pityRarity = Formulas.pityRarity(capsule)
	local forced
	rarityId, data.pity[capsule.id], forced = Formulas.applyPity(capsule, rarityId, data.pity[capsule.id] or 0)
	if forced then
		Remotes.Notify:FireClient(player, S.m("factory.pity"), Color3.fromRGB(255, 220, 80))
	end

	local creature = Formulas.randomCreatureOf(rarityId, rng, capsule.season)
	local mutationId = Formulas.rollMutation(luck, rng, mods)

	local showcase = Rarities.get(rarityId).rank >= Rarities.get("god").rank
		and Rarities.get(rarityId).rank >= Rarities.get(pityRarity).rank
	local source = Formulas.SOURCE_FREE
	if MonetizationService.paidLuck(player, data, os.time()) then
		source = Formulas.SOURCE_LUCK
	elseif bought > 0 and not free then
		source = Formulas.SOURCE_COINS
	end
	local entry, isNew = addCreature(player, data, creature.id, mutationId, cost, nil, showcase, source)
	Actions.fire(player, "craft", 1)
	Remotes.CraftResult:FireClient(player, {
		uid = entry.uid,
		id = creature.id,
		mut = mutationId,
		isNew = isNew,
		capsule = capsule.id,
		first = free or nil, -- the free first capsule: the client plays the big reveal
	})
	return true
end

local function sell(player, uid)
	local data = DataService.get(player)
	if not data or type(uid) ~= "string" then
		return
	end
	for index, entry in ipairs(data.creatures) do
		if entry.uid == uid then
			local value = Formulas.sellValue(entry)
			table.remove(data.creatures, index)
			data.coins += value
			-- The proceeds for a paid one stay as bought coins, otherwise selling would launder them.
			if Formulas.isPaidRandom(entry) then
				data.boughtCoins += value
			end
			AnalyticsService.coins(player, true, value, "Sell")
			data.stats.sold += 1
			Actions.fire(player, "sell", 1)
			Remotes.Notify:FireClient(player, S.m("factory.sold", { coins = Format.coins(value) }), GOOD)
			FactoryService.CreaturesChanged:Fire(player)
			DataService.markDirty(player)
			return
		end
	end
end

-- Sells all brainrots of the given rarity without mutations (mutants are kept).
local function sellRarity(player, rarityId)
	local data = DataService.get(player)
	if not data or type(rarityId) ~= "string" or not Rarities.get(rarityId) then
		return
	end
	local total, bought, count = 0, 0, 0
	for index = #data.creatures, 1, -1 do
		local entry = data.creatures[index]
		local creature = Creatures.get(entry.id)
		if creature and creature.rarity == rarityId and entry.mut == "normal" then
			local value = Formulas.sellValue(entry)
			total += value
			if Formulas.isPaidRandom(entry) then
				bought += value
			end
			count += 1
			table.remove(data.creatures, index)
		end
	end
	if count == 0 then
		return
	end
	data.coins += total
	data.boughtCoins += bought
	AnalyticsService.coins(player, true, total, "Sell")
	data.stats.sold += count
	Actions.fire(player, "sell", count)
	Remotes.Notify:FireClient(player, S.m("factory.sold_many", { count = count, coins = Format.coins(total) }), GOOD)
	FactoryService.CreaturesChanged:Fire(player)
	DataService.markDirty(player)
end

-- Fusing: 3 brainrots of one rarity -> 1 random brainrot of the next rarity.
-- We take the weakest ones so as not to consume mutants.
local function fuse(player, rarityId)
	local data = DataService.get(player)
	local nextRarity = type(rarityId) == "string" and Rarities.next(rarityId)
	if not data or not nextRarity then
		return
	end

	-- Fusing gives a new random reward: when paid brainrots are restricted we do not take them.
	local restricted = PolicyService.paidRandomRestricted(player)
	local candidates, skippedPaid = {}, 0
	for index, entry in ipairs(data.creatures) do
		local creature = Creatures.get(entry.id)
		if creature and creature.rarity == rarityId then
			if restricted and Formulas.isPaidRandom(entry) then
				skippedPaid += 1
			else
				table.insert(candidates, { index = index, income = Formulas.creatureBaseIncome(entry) })
			end
		end
	end
	if #candidates < Formulas.FUSE_COUNT then
		local args = { count = Formulas.FUSE_COUNT }
		local paidInTheWay = #candidates + skippedPaid >= Formulas.FUSE_COUNT
		Remotes.Notify:FireClient(player, if paidInTheWay then PolicyService.message(player, "factory.fuse_paid", args) else S.m("factory.fuse_need", args), BAD)
		return
	end

	table.sort(candidates, function(a, b)
		return a.income < b.income
	end)
	local toRemove = {}
	for i = 1, Formulas.FUSE_COUNT do
		table.insert(toRemove, candidates[i].index)
	end
	table.sort(toRemove, function(a, b)
		return a > b
	end)
	local paid = 0
	-- If a fused brainrot belonged to someone else, the result "inherits" its origin,
	-- otherwise fusing would launder brainrots hidden at a friend's place during a rebirth.
	local lineage = {}
	-- Same with the source: a paid brainrot cannot be laundered by fusing.
	local source = Formulas.SOURCE_FREE
	for _, index in ipairs(toRemove) do
		local removed = table.remove(data.creatures, index)
		Formulas.mergeLineage(lineage, Formulas.lineageOf(removed, player.UserId, data.rebirths))
		if Formulas.isPaidRandom(removed) then
			source = removed.source
		end
		if paid and removed.paid then
			paid += removed.paid
		else
			paid = nil -- at least one has no price (stolen before this rule): no limit
		end
	end

	local mods = EventService.mods()
	local luck = MonetizationService.luck(player, data, os.time(), mods)
	local creature = Formulas.randomCreatureOf(nextRarity.id, rng)
	local mutationId = Formulas.rollMutation(luck, rng, mods)
	data.stats.fused += 1
	Actions.fire(player, "fuse", 1)
	if MonetizationService.paidLuck(player, data, os.time()) then
		source = Formulas.SOURCE_LUCK
	end

	local entry, isNew = addCreature(player, data, creature.id, mutationId, paid, lineage, nextRarity.rank >= Rarities.get("god").rank, source)
	Remotes.CraftResult:FireClient(player, {
		uid = entry.uid,
		id = creature.id,
		mut = mutationId,
		isNew = isNew,
		fused = true,
	})
end

local function setAutoCraft(player, capsuleId)
	if capsuleId == nil then
		autoCraft[player] = nil
		DataService.markDirty(player)
		return
	end
	if not MonetizationService.passes(player).AUTO_CRAFT then
		Remotes.Notify:FireClient(player, S.m("factory.need_auto", { pass = S.m("pass.AUTO_CRAFT.name") }), BAD)
		return
	end
	if type(capsuleId) == "string" and Capsules.get(capsuleId) then
		autoCraft[player] = capsuleId
		fullWarned[player] = nil
		DataService.markDirty(player)
	end
end

function FactoryService.init()
	Remotes.Craft.OnServerEvent:Connect(function(player, capsuleId)
		craft(player, capsuleId, false)
	end)
	Remotes.Sell.OnServerEvent:Connect(sell)
	Remotes.SellRarity.OnServerEvent:Connect(sellRarity)
	Remotes.Fuse.OnServerEvent:Connect(fuse)
	Remotes.SetAutoCraft.OnServerEvent:Connect(setAutoCraft)

	Players.PlayerRemoving:Connect(function(player)
		lastCraft[player] = nil
		lastShowcase[player] = nil
		autoCraft[player] = nil
		fullWarned[player] = nil
	end)

	-- Auto factory.
	task.spawn(function()
		while true do
			task.wait(0.1)
			for player, capsuleId in pairs(autoCraft) do
				local data = DataService.get(player)
				if data then
					local passes = MonetizationService.passes(player)
					local last = lastCraft[player] or 0
					if os.clock() - last >= Formulas.craftTime(data, passes, EventService.mods()) then
						craft(player, capsuleId, true)
					end
				end
			end
		end
	end)
end

return FactoryService
