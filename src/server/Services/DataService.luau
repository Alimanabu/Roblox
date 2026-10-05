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
-- Блокировка сессии: пока игрок на одном сервере, другой сервер не может загрузить
-- его прогресс (защита от дюпа при быстром перезаходе). Если сервер упал и не снял
-- блокировку, она сама истекает через SESSION_TIMEOUT секунд.
local SESSION_TIMEOUT = 180
local SESSION_ATTEMPTS = 8
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
local saveExtras = {} -- функции, которые добавляют в сохранение «временно отсутствующих» брейнротов
local closeCallbacks = {} -- вызываются при выключении сервера до финального сохранения
-- [player] = true: игрок уходит, обычные сохранения уже не нужны. Слабые ключи:
-- флаг не снимаем, чтобы запоздавший автосейв не вернул блокировку сессии.
local releasing = setmetatable({}, { __mode = "k" })
local pendingRelease = {} -- [userId] = true: идёт финальное сохранение ушедшего игрока

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
		stats = { crafted = 0, fused = 0, sold = 0, stolen = 0, lostToThieves = 0, mutants = 0, thievesSlapped = 0 },
		daily = { streak = 0, lastClaimDay = 0 },
		quests = { day = 0, list = {} },
		tutorial = { step = 1, progress = 0 },
		codes = {}, -- [КОД] = true — введённые промокоды
		achievements = {}, -- [id] = true
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

-- callback(player) -> список брейнротов, которые должны попасть в сохранение,
-- хотя сейчас их нет в data.creatures (например, их прямо сейчас несёт вор).
function DataService.addSaveExtra(callback)
	table.insert(saveExtras, callback)
end

-- Полный сброс прогресса (тест-команда). Покупки за Robux не трогаем.
function DataService.reset(player)
	local old = profiles[player]
	if not old then
		return nil
	end
	local fresh = defaultData()
	fresh.receipts = old.receipts
	fresh.session = old.session
	profiles[player] = fresh
	dirty[player] = true
	return fresh
end

function DataService.onClose(callback)
	table.insert(closeCallbacks, callback)
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

local function sessionOwnedByOther(saved)
	local session = type(saved) == "table" and saved.session
	return type(session) == "table"
		and session.jobId ~= game.JobId
		and os.time() - (session.time or 0) < SESSION_TIMEOUT
end

-- release = true, когда игрок уходит: снимаем блокировку сессии.
-- Возвращает true, если сохранение прошло (или сохранять некуда, как в Studio без API).
function DataService.save(player, release)
	local data = profiles[player]
	if not data then
		return false
	end
	if not store then
		return true
	end
	-- Игрок уже уходит: обычное сохранение могло бы вернуть блокировку сессии
	-- после финального, и игрок не смог бы зайти на другой сервер.
	if releasing[player] and not release then
		return false
	end
	data.lastOnline = os.time()

	local toSave = data
	local extras = {}
	for _, callback in ipairs(saveExtras) do
		for _, entry in ipairs(callback(player) or {}) do
			table.insert(extras, entry)
		end
	end
	if #extras > 0 then
		toSave = table.clone(data)
		toSave.creatures = table.clone(data.creatures)
		for _, entry in ipairs(extras) do
			table.insert(toSave.creatures, entry)
		end
	end

	toSave.session = if release then nil else { jobId = game.JobId, time = os.time() }

	local stolenSession = false
	local ok, err = withRetries(function()
		return store:UpdateAsync(keyFor(player), function(saved)
			-- Проверяем ещё раз внутри: игрок мог уйти, пока это сохранение ждало очереди.
			if releasing[player] and not release then
				return nil
			end
			if sessionOwnedByOther(saved) then
				-- Прогресс уже открыт другим сервером — не затираем его.
				stolenSession = true
				return nil
			end
			return toSave
		end)
	end)
	if not ok then
		warn("[DataService] Не удалось сохранить", player.Name, err)
		return false
	elseif stolenSession then
		warn("[DataService] Сессию", player.Name, "занял другой сервер, сохранение пропущено")
		return false
	end
	return true
end

-- Загружает прогресс и ставит блокировку сессии.
-- Возвращает ok, data (data == nil для нового игрока).
local function loadWithLock(player)
	local key = keyFor(player)
	for attempt = 1, SESSION_ATTEMPTS do
		local locked = false
		local loaded = nil
		local ok, err = pcall(function()
			store:UpdateAsync(key, function(saved)
				if sessionOwnedByOther(saved) then
					locked = true
					return nil
				end
				saved = type(saved) == "table" and saved or {}
				saved.session = { jobId = game.JobId, time = os.time() }
				loaded = saved
				return saved
			end)
		end)
		if ok and not locked then
			return true, loaded
		end
		if not ok then
			warn("[DataService] Ошибка загрузки", player.Name, err)
			if RunService:IsStudio() then
				return false, nil
			end
		end
		if not player.Parent then
			return false, nil
		end
		task.wait(if locked then 5 else attempt * 1.5)
	end
	return false, nil
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
	-- Перезашёл на этот же сервер, пока идёт финальное сохранение прошлого захода, — ждём.
	while pendingRelease[player.UserId] do
		task.wait(0.1)
	end
	local data
	if store then
		local ok, result = loadWithLock(player)
		if ok then
			data = result
		elseif RunService:IsStudio() then
			-- В Studio без доступа к API просто играем без сохранений.
			warn("[DataService] DataStore в Studio недоступен (включи API Services). Играем без сохранений.")
			store = nil
		else
			-- Не даём играть с пустым профилем, иначе затрём настоящий прогресс.
			player:Kick("Не получилось загрузить прогресс (возможно, ты ещё открыт на другом сервере). Перезайди через минуту!")
			return
		end
	end

	if not player.Parent then
		-- Игрок ушёл, пока грузился: снимаем блокировку, ничего не меняя.
		if store and data then
			pcall(function()
				store:UpdateAsync(keyFor(player), function(saved)
					if type(saved) == "table" and not sessionOwnedByOther(saved) then
						saved.session = nil
						return saved
					end
					return nil
				end)
			end)
		end
		return
	end

	data = reconcile(type(data) == "table" and data or {}, defaultData())
	profiles[player] = data
	DataService.Loaded:Fire(player, data)
	DataService.sendNow(player)
end

local function onPlayerRemoving(player)
	if profiles[player] then
		releasing[player] = true
		pendingRelease[player.UserId] = true
		local ok, err = pcall(DataService.save, player, true)
		if not ok then
			warn("[DataService] Ошибка финального сохранения", player.Name, err)
		end
		pendingRelease[player.UserId] = nil
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
		for _, callback in ipairs(closeCallbacks) do
			pcall(callback)
		end
		if RunService:IsStudio() and not store then
			return
		end
		local pending = 0
		for player in pairs(profiles) do
			pending += 1
			task.spawn(function()
				DataService.save(player, true)
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
