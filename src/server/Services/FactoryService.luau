-- Фабрика брейнрота: создание из капсул, продажа, скрещивание, авто-фабрика.

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
local fullWarned = {} -- [player] = true, чтобы не спамить «база заполнена»

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

-- paid — сколько монет за него заплачено (капсула или сумма скрещённых);
-- продать дороже 60% от этого нельзя, иначе «создал-продал» печатает деньги.
local SHOWCASE_COOLDOWN = 15 -- не чаще раза в 15 с на игрока
local lastShowcase = {} -- [player] = os.clock()

-- showcase = true — это действительно редкая находка (см. craft): запускаем шоу.
-- source: откуда брейнрот (см. Formulas.SOURCE_FREE).
local function addCreature(player, data, creatureId, mutationId, paid, lineage, showcase, source)
	-- lineage: кто владел брейнротом и в каком «поколении» (см. Formulas.lineageOf).
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

	-- Световое шоу на весь сервер: SIX SEVEN, мутация 67/Космический или «редкая находка»
	-- (самая редкая редкость своей капсулы — например Бог из Мега-тренда, но не Бог
	-- из Мирового тренда, где он выпадает почти всегда).
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

-- Выдать брейнрота напрямую (награды, тест-команды). Возвращает запись.
function FactoryService.give(player, creatureId, mutationId, source)
	local data = DataService.get(player)
	if not data or not Creatures.get(creatureId) then
		return nil
	end
	local rank = Rarities.get(Creatures.get(creatureId).rarity).rank
	return (addCreature(player, data, creatureId, mutationId or "normal", nil, nil, rank >= Rarities.get("god").rank, source or Formulas.SOURCE_FREE))
end

-- Возвращает true, если получилось создать.
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
	-- Небольшой запас на пинг.
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
	if data.coins < capsule.cost then
		return fail(S.m("common.not_enough_coins", { cost = Format.coins(capsule.cost) }))
	end

	lastCraft[player] = now
	fullWarned[player] = nil
	-- Купленные монеты капсула тратит первыми. Прочие траты их не уменьшают, пока монет хватает,
	-- поэтому ошибка возможна только в сторону «за купленные».
	local bought = math.min(data.boughtCoins, data.coins)
	data.coins -= capsule.cost
	data.boughtCoins = math.max(bought - capsule.cost, 0)
	AnalyticsService.coins(player, false, capsule.cost, "Capsule")
	data.stats.crafted += 1

	local luck = MonetizationService.luck(player, data, os.time(), mods)
	local rarityId = Formulas.rollRarity(capsule, luck, rng, mods)

	-- Гарантия: долго не везло — самая редкая редкость капсулы выпадает точно.
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
	elseif bought > 0 then
		source = Formulas.SOURCE_COINS
	end
	local entry, isNew = addCreature(player, data, creature.id, mutationId, capsule.cost, nil, showcase, source)
	Actions.fire(player, "craft", 1)
	Remotes.CraftResult:FireClient(player, {
		uid = entry.uid,
		id = creature.id,
		mut = mutationId,
		isNew = isNew,
		capsule = capsule.id,
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

-- Продаёт всех брейнротов указанной редкости без мутаций (мутантов бережём).
local function sellRarity(player, rarityId)
	local data = DataService.get(player)
	if not data or type(rarityId) ~= "string" or not Rarities.get(rarityId) then
		return
	end
	local total, count = 0, 0
	for index = #data.creatures, 1, -1 do
		local entry = data.creatures[index]
		local creature = Creatures.get(entry.id)
		if creature and creature.rarity == rarityId and entry.mut == "normal" then
			total += Formulas.sellValue(entry)
			count += 1
			table.remove(data.creatures, index)
		end
	end
	if count == 0 then
		return
	end
	data.coins += total
	AnalyticsService.coins(player, true, total, "Sell")
	data.stats.sold += count
	Actions.fire(player, "sell", count)
	Remotes.Notify:FireClient(player, S.m("factory.sold_many", { count = count, coins = Format.coins(total) }), GOOD)
	FactoryService.CreaturesChanged:Fire(player)
	DataService.markDirty(player)
end

-- Скрещивание: 3 брейнрота одной редкости -> 1 случайный брейнрот следующей редкости.
-- Забираем самых слабых, чтобы не съесть мутантов.
local function fuse(player, rarityId)
	local data = DataService.get(player)
	local nextRarity = type(rarityId) == "string" and Rarities.next(rarityId)
	if not data or not nextRarity then
		return
	end

	local candidates = {}
	for index, entry in ipairs(data.creatures) do
		local creature = Creatures.get(entry.id)
		if creature and creature.rarity == rarityId then
			table.insert(candidates, { index = index, income = Formulas.creatureBaseIncome(entry) })
		end
	end
	if #candidates < Formulas.FUSE_COUNT then
		Remotes.Notify:FireClient(player, S.m("factory.fuse_need", { count = Formulas.FUSE_COUNT }), BAD)
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
	-- Если среди скрещённых был чужой брейнрот, результат «наследует» его происхождение,
	-- иначе скрещивание отмывало бы брейнротов, спрятанных у друга на время перерождения.
	local lineage = {}
	-- Так же и с источником: платный брейнрот нельзя отмыть скрещиванием.
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
			paid = nil -- хотя бы один без цены (украден до этого правила) — без ограничения
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

	-- Авто-фабрика.
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
