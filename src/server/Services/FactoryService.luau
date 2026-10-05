-- Фабрика брейнрота: создание из капсул, продажа, скрещивание, авто-фабрика.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
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
local QuestService = require(script.Parent.QuestService)

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
		return creature.name
	end
	return mutation.name .. " " .. creature.name
end

local function addCreature(player, data, creatureId, mutationId)
	local entry = { uid = tostring(data.nextUid), id = creatureId, mut = mutationId }
	data.nextUid += 1
	table.insert(data.creatures, entry)

	local isNew = not data.index[creatureId]
	data.index[creatureId] = true

	local creature = Creatures.get(creatureId)
	local rarity = Rarities.get(creature.rarity)
	local mutation = Mutations.get(mutationId)

	ProgressionService.addXp(player, data, rarity.xp * (isNew and 3 or 1))
	if rarity.rank >= Rarities.get("sigma").rank then
		QuestService.progress(player, "sigmaPlus", 1)
	end
	if mutation.id ~= "normal" then
		QuestService.progress(player, "mutant", 1)
	end
	if isNew then
		QuestService.progress(player, "newIndex", 1)
	end

	if rarity.announce or mutation.rank >= 4 then
		Remotes.Notify:FireAllClients(
			"🚨 " .. player.DisplayName .. " создал " .. creatureLabel(creatureId, mutationId) .. " [" .. rarity.name .. "]!",
			rarity.color
		)
	end

	FactoryService.CreaturesChanged:Fire(player)
	DataService.markDirty(player)
	return entry, isNew
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
		return fail("Эта капсула ещё закрыта!")
	end
	local now = os.clock()
	-- Небольшой запас на пинг.
	if lastCraft[player] and now - lastCraft[player] < Formulas.craftTime(data, passes) * 0.9 then
		return false
	end
	if #data.creatures >= Formulas.slots(data, passes) then
		if not silent or not fullWarned[player] then
			Remotes.Notify:FireClient(player, "База заполнена! Продай или скрести брейнротов, или расширь базу.", BAD)
		end
		fullWarned[player] = true
		return false
	end
	if data.coins < capsule.cost then
		return fail("Не хватает монет: нужно " .. Format.coins(capsule.cost))
	end

	lastCraft[player] = now
	fullWarned[player] = nil
	data.coins -= capsule.cost
	data.stats.crafted += 1

	local luck = Formulas.luck(data, passes, os.time())
	local rarityId = Formulas.rollRarity(capsule, luck, rng)
	local creature = Formulas.randomCreatureOf(rarityId, rng)
	local mutationId = Formulas.rollMutation(luck, rng)

	local entry, isNew = addCreature(player, data, creature.id, mutationId)
	QuestService.progress(player, "craft", 1)
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
			data.stats.sold += 1
			QuestService.progress(player, "sell", 1)
			Remotes.Notify:FireClient(player, "Продано за " .. Format.coins(value), GOOD)
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
	data.stats.sold += count
	QuestService.progress(player, "sell", count)
	Remotes.Notify:FireClient(player, "Продано " .. count .. " шт. за " .. Format.coins(total), GOOD)
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
		Remotes.Notify:FireClient(player, "Нужно " .. Formulas.FUSE_COUNT .. " брейнрота одной редкости", BAD)
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
	for _, index in ipairs(toRemove) do
		table.remove(data.creatures, index)
	end

	local passes = MonetizationService.passes(player)
	local luck = Formulas.luck(data, passes, os.time())
	local creature = Formulas.randomCreatureOf(nextRarity.id, rng)
	local mutationId = Formulas.rollMutation(luck, rng)
	data.stats.fused += 1
	QuestService.progress(player, "fuse", 1)

	local entry, isNew = addCreature(player, data, creature.id, mutationId)
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
		Remotes.Notify:FireClient(player, "Нужен геймпасс «Авто-фабрика»", BAD)
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
					if os.clock() - last >= Formulas.craftTime(data, passes) then
						craft(player, capsuleId, true)
					end
				end
			end
		end
	end)
end

return FactoryService
