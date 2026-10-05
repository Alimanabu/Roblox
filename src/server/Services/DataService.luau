-- Сохранение прогресса игроков (DataStore) и отправка состояния клиенту.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Formulas = require(Shared.Util.Formulas)

local DataService = {}

local STORE_NAME = "BrainrotFactory_v1"
local AUTOSAVE_INTERVAL = 60
local MAX_RECEIPTS = 50

local store = nil
local storeOk, storeErr = pcall(function()
	store = DataStoreService:GetDataStore(STORE_NAME)
end)
if not storeOk then
	warn("[DataService] DataStore недоступен, прогресс не будет сохраняться:", storeErr)
end

local profiles = {} -- [player] = data
local dirty = {} -- [player] = true, если состояние надо отправить клиенту
local snapshotBuilder = nil -- function(player, data) -> snapshot, задаётся из Main

DataService.Loaded = Instance.new("BindableEvent")

local function defaultData()
	return {
		version = 1,
		coins = Formulas.START_COINS,
		totalEarned = 0,
		level = 1,
		xp = 0,
		rebirths = 0,
		creatures = {}, -- { { uid = "1", id = "bananito_ninjini", mut = "normal" } }
		nextUid = 1,
		upgrades = { speed = 0, luck = 0, slots = 0 },
		boosts = { luckUntil = 0 },
		index = {}, -- [creatureId] = true — открытые брейнроты (коллекция)
		stats = { crafted = 0, fused = 0, sold = 0 },
		receipts = {}, -- последние обработанные покупки
		lastOnline = 0,
	}
end

-- Добавляет недостающие поля (если мы добавим новые в будущих версиях).
local function reconcile(data, template)
	for key, value in pairs(template) do
		if data[key] == nil then
			if type(value) == "table" then
				data[key] = table.clone(value)
			else
				data[key] = value
			end
		elseif type(value) == "table" and type(data[key]) == "table" and next(value) ~= nil then
			reconcile(data[key], value)
		end
	end
	return data
end

local function keyFor(player)
	return "player_" .. player.UserId
end

local function withRetries(callback)
	local lastErr
	for attempt = 1, 4 do
		local ok, result = pcall(callback)
		if ok then
			return true, result
		end
		lastErr = result
		task.wait(attempt * 1.5)
	end
	return false, lastErr
end

function DataService.setSnapshotBuilder(builder)
	snapshotBuilder = builder
end

function DataService.get(player)
	return profiles[player]
end

function DataService.markDirty(player)
	dirty[player] = true
end

function DataService.sendNow(player)
	local data = profiles[player]
	if data and snapshotBuilder then
		dirty[player] = nil
		Remotes.State:FireClient(player, snapshotBuilder(player, data))
	end
end

function DataService.save(player)
	local data = profiles[player]
	if not data or not store then
		return
	end
	data.lastOnline = os.time()
	local ok, err = withRetries(function()
		return store:UpdateAsync(keyFor(player), function()
			return data
		end)
	end)
	if not ok then
		warn("[DataService] Не удалось сохранить", player.Name, err)
	end
end

-- Возвращает true, если покупка с этим receiptId уже была выдана.
function DataService.hasReceipt(data, receiptId)
	return table.find(data.receipts, receiptId) ~= nil
end

function DataService.addReceipt(data, receiptId)
	table.insert(data.receipts, receiptId)
	while #data.receipts > MAX_RECEIPTS do
		table.remove(data.receipts, 1)
	end
end

local function onPlayerAdded(player)
	local data
	if store then
		local ok, result = withRetries(function()
			return store:GetAsync(keyFor(player))
		end)
		if ok then
			data = result
		elseif RunService:IsStudio() then
			-- В Studio без доступа к API просто играем без сохранений.
			warn("[DataService] DataStore в Studio недоступен (включи API Services). Играем без сохранений.")
			store = nil
		else
			-- Не даём играть с пустым профилем, иначе затрём настоящий прогресс.
			player:Kick("Не получилось загрузить прогресс. Перезайди, пожалуйста!")
			return
		end
	end

	if not player.Parent then
		return
	end

	data = reconcile(type(data) == "table" and data or {}, defaultData())
	profiles[player] = data
	DataService.Loaded:Fire(player, data)
	DataService.sendNow(player)
end

local function onPlayerRemoving(player)
	if profiles[player] then
		DataService.save(player)
	end
	profiles[player] = nil
	dirty[player] = nil
end

function DataService.init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	-- Отправляем изменения клиентам не чаще 5 раз в секунду.
	task.spawn(function()
		while true do
			task.wait(0.2)
			for player in pairs(dirty) do
				DataService.sendNow(player)
			end
		end
	end)

	-- Автосейв.
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in pairs(profiles) do
				task.spawn(DataService.save, player)
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() and not store then
			return
		end
		local pending = 0
		for player in pairs(profiles) do
			pending += 1
			task.spawn(function()
				DataService.save(player)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.1)
		end
	end)
end

return DataService
