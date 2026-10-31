-- Покупки за Robux: настоящие MonetizationService и DataService на заглушках Roblox.
-- Время виртуальное: task.wait усыпляет поток, а runUntilIdle будит спящих по порядку,
-- поэтому паузы повторных попыток не тормозят тесты.

local failures = 0
local scenarios = 0
local function check(cond, msg)
	if not cond then
		failures += 1
		print("❌ " .. msg)
	end
end

-- Планировщик ---------------------------------------------------------------

local sleeping = {} -- { { at, thread } }
local pauses = {} -- длительности всех task.wait
local clock = 0

task = {}

function task.wait(seconds)
	seconds = seconds or 0
	table.insert(pauses, seconds)
	table.insert(sleeping, { at = clock + seconds, thread = coroutine.running() })
	coroutine.yield()
	return seconds
end

local function resume(thread, ...)
	local ok, err = coroutine.resume(thread, ...)
	if not ok then
		error(err, 0)
	end
end

function task.spawn(callback, ...)
	local thread = coroutine.create(callback)
	resume(thread, ...)
	return thread
end

local function runUntilIdle()
	while #sleeping > 0 do
		table.sort(sleeping, function(a, b)
			return a.at < b.at
		end)
		local sleeper = table.remove(sleeping, 1)
		clock = math.max(clock, sleeper.at)
		resume(sleeper.thread)
	end
end

-- Заглушки Roblox -------------------------------------------------------------

local warnings = {}
function warn(...)
	table.insert(warnings, { ... })
end

local function newSignal()
	local listeners = {}
	local signal = {}
	signal.Event = signal
	function signal:Connect(callback)
		table.insert(listeners, callback)
	end
	function signal:Fire(...)
		for _, callback in ipairs(listeners) do
			task.spawn(callback, ...)
		end
	end
	return signal
end

Instance = {
	new = function()
		return newSignal()
	end,
}

Enum = {
	ProductPurchaseDecision = { PurchaseGranted = "PurchaseGranted", NotProcessedYet = "NotProcessedYet" },
}

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, item in pairs(value) do
		copy[key] = deepCopy(item)
	end
	return copy
end

-- DataStore копирует данные при чтении и записи, как настоящий.
local store = { saved = {}, writes = 0, failing = false, beforeWrite = nil }

function store:UpdateAsync(key, transform)
	if self.failing then
		error("DataStore: сбой записи")
	end
	local hook = self.beforeWrite
	self.beforeWrite = nil
	if hook then
		hook()
	end
	local result = transform(deepCopy(self.saved[key]))
	if result ~= nil then
		self.saved[key] = deepCopy(result)
		self.writes += 1
	end
	return result
end

local Players = {
	list = {},
	PlayerAdded = newSignal(),
	PlayerRemoving = newSignal(),
}

function Players:GetPlayers()
	local players = {}
	for _, player in pairs(self.list) do
		table.insert(players, player)
	end
	return players
end

function Players:GetPlayerByUserId(userId)
	return self.list[userId]
end

local MarketplaceService = {
	PromptGamePassPurchaseFinished = newSignal(),
	owned = {}, -- ["userId:passId"] = true
	failures = {}, -- ["userId:passId"] = сколько запросов подряд упадёт
	calls = {}, -- ["userId:passId"] = сколько было запросов
}

function MarketplaceService:UserOwnsGamePassAsync(userId, passId)
	local key = userId .. ":" .. passId
	self.calls[key] = (self.calls[key] or 0) + 1
	if (self.failures[key] or 0) > 0 then
		self.failures[key] -= 1
		error("MarketplaceService: сбой запроса")
	end
	return self.owned[key] == true
end

local services = {
	Players = Players,
	MarketplaceService = MarketplaceService,
	DataStoreService = {
		GetDataStore = function()
			return store
		end,
	},
	RunService = {
		IsStudio = function()
			return false
		end,
	},
	ReplicatedStorage = {
		WaitForChild = function()
			return node("")
		end,
	},
}

game = {
	JobId = "test-server",
	BindToClose = function() end,
	GetService = function(_, name)
		return assert(services[name], "нет заглушки сервиса " .. name)
	end,
}

local remote = {
	FireClient = function() end,
}
__defs["Remotes"] = function()
	return { Notify = remote, State = remote }
end

-- Запуск сервисов ---------------------------------------------------------------

local Monetization = shared_require("Config/Monetization")
local Formulas = shared_require("Util/Formulas")
local DataService = shared_require("Services/DataService")
local MonetizationService = shared_require("Services/MonetizationService")

-- В конфиге id = 0 (продукты ещё не созданы), поэтому номера подставляем только в памяти теста.
for index, pass in ipairs(Monetization.GamePasses) do
	pass.id = 2000 + index
end
for index, product in ipairs(Monetization.Products) do
	product.id = 1000 + index
	Monetization.ProductById[product.id] = product
end

local SPINS = Monetization.ProductByKey.SPINS_3
local Decision = Enum.ProductPurchaseDecision
local nextUserId = 100
local nextPurchaseId = 500

DataService.init()
MonetizationService.init()
-- Вечные циклы автосейва и рассылки состояния тесту не нужны.
table.clear(sleeping)

local function addPlayer(userId)
	if not userId then
		nextUserId += 1
		userId = nextUserId
	end
	local player = { UserId = userId, Name = "Игрок" .. userId, Parent = Players, Kick = function() end }
	Players.list[userId] = player
	Players.PlayerAdded:Fire(player)
	return player
end

local function removePlayer(player)
	Players.list[player.UserId] = nil
	Players.PlayerRemoving:Fire(player)
	player.Parent = nil
end

-- Вызов чека так, как его делает Roblox: в отдельном потоке, который может ждать.
local function receipt(userId, purchaseId, productId)
	local decision
	task.spawn(function()
		decision = MarketplaceService.ProcessReceipt({
			PlayerId = userId,
			PurchaseId = purchaseId,
			ProductId = productId,
		})
	end)
	runUntilIdle()
	return decision
end

local function newPurchaseId()
	nextPurchaseId += 1
	return "purchase-" .. nextPurchaseId
end

local function savedOf(player)
	return store.saved["player_" .. player.UserId]
end

local function isReceiptSaved(player, id)
	return table.find(savedOf(player).receipts or {}, id) ~= nil
end

local function scenario(name, body)
	scenarios += 1
	table.clear(warnings)
	table.clear(pauses)
	table.clear(sleeping)
	store.failing = false
	store.beforeWrite = nil
	local before = failures
	local ok, err = pcall(body)
	if not ok then
		failures += 1
		print("❌ " .. name .. ": ошибка: " .. tostring(err))
	end
	print(string.format("  %s %d. %s", failures == before and "✅" or "❌", scenarios, name))
end

print("— Покупки за Robux —")

scenario("первая выдача", function()
	local player = addPlayer()
	local id = newPurchaseId()
	local writes = store.writes
	check(receipt(player.UserId, id, SPINS.id) == Decision.PurchaseGranted, "первая выдача: не подтверждена")
	check(DataService.get(player).wheel.extraSpins == 3, "первая выдача: нет 3 вращений")
	check(store.writes == writes + 1, "первая выдача: нет записи в DataStore")
	local saved = savedOf(player)
	check(isReceiptSaved(player, id), "первая выдача: чек не попал в сохранение")
	check(saved.wheel.extraSpins == 3, "первая выдача: вращения не попали в сохранение")
end)

scenario("повтор чека без второй выдачи", function()
	local player = addPlayer()
	local id = newPurchaseId()
	receipt(player.UserId, id, SPINS.id)
	check(receipt(player.UserId, id, SPINS.id) == Decision.PurchaseGranted, "повтор чека: не подтверждён")
	check(DataService.get(player).wheel.extraSpins == 3, "повтор чека: выдано второй раз")
	check(savedOf(player).wheel.extraSpins == 3, "повтор чека: в сохранении выдано второй раз")
end)

scenario("неизвестный продукт", function()
	local player = addPlayer()
	local id = newPurchaseId()
	local writes = store.writes
	check(receipt(player.UserId, id, 999999) == Decision.NotProcessedYet, "неизвестный продукт: подтверждён")
	check(not DataService.hasReceipt(DataService.get(player), id), "неизвестный продукт: чек записан")
	check(store.writes == writes, "неизвестный продукт: лишняя запись в DataStore")
end)

scenario("игрок вышел", function()
	local player = addPlayer()
	local userId = player.UserId
	removePlayer(player)
	runUntilIdle()
	local id = newPurchaseId()
	local writes = store.writes
	check(receipt(userId, id, SPINS.id) == Decision.NotProcessedYet, "игрок вышел: покупка подтверждена без него")
	check(store.writes == writes, "игрок вышел: лишняя запись в DataStore")
	-- Roblox повторит чек на следующем заходе.
	local back = addPlayer(userId)
	check(receipt(userId, id, SPINS.id) == Decision.PurchaseGranted, "игрок вышел: не выдано после возвращения")
	check(DataService.get(back).wheel.extraSpins == 3, "игрок вышел: нет вращений после возвращения")
end)

scenario("сбой сохранения: подтверждение только после повторной записи", function()
	local player = addPlayer()
	local id = newPurchaseId()
	store.failing = true
	check(receipt(player.UserId, id, SPINS.id) == Decision.NotProcessedYet, "сбой сохранения: подтверждено без записи")
	check(receipt(player.UserId, id, SPINS.id) == Decision.NotProcessedYet, "сбой сохранения: повтор чека подтверждён без записи")
	check(not isReceiptSaved(player, id), "сбой сохранения: заглушка записала чек при сбое")

	store.failing = false
	local writes = store.writes
	check(receipt(player.UserId, id, SPINS.id) == Decision.PurchaseGranted, "сбой сохранения: не подтверждено после восстановления")
	check(store.writes == writes + 1, "сбой сохранения: повтор чека не записал данные")
	local saved = savedOf(player)
	check(isReceiptSaved(player, id), "сбой сохранения: чека нет в сохранении")
	check(saved.wheel.extraSpins == 3, "сбой сохранения: вращений нет в сохранении")
	check(DataService.get(player).wheel.extraSpins == 3, "сбой сохранения: выдано второй раз")
end)

scenario("сбой запроса геймпасса: успешный повтор", function()
	local vip = Monetization.GamePassByKey.VIP
	local lucky = Monetization.GamePassByKey.LUCKY
	local userId = nextUserId + 1
	MarketplaceService.owned[userId .. ":" .. vip.id] = true
	MarketplaceService.owned[userId .. ":" .. lucky.id] = true
	MarketplaceService.failures[userId .. ":" .. vip.id] = 1

	local player = addPlayer()
	runUntilIdle()
	check(MonetizationService.passes(player).VIP == true, "сбой геймпасса: VIP не вернулся после повтора")
	check(MonetizationService.passes(player).LUCKY == true, "сбой геймпасса: второй геймпасс потерян")
	check(MarketplaceService.calls[userId .. ":" .. vip.id] == 2, "сбой геймпасса: запросов VIP не 2")
	check(#pauses >= 1 and pauses[1] > 0, "сбой геймпасса: нет паузы перед повтором")
	check(#warnings >= 1, "сбой геймпасса: нет предупреждения в журнале")
end)

-- Дополнительно к шести сценариям задания.

scenario("геймпасс «Огромная база»: перестройка сразу после выдачи", function()
	local pass = Monetization.GamePassByKey.BIG_BASE
	local player = addPlayer()
	runUntilIdle()
	local builtFloors = nil
	local count = 0
	MonetizationService.PassesChanged.Event:Connect(function(changed)
		if changed == player then
			count += 1
			builtFloors = Formulas.floors(DataService.get(player), MonetizationService.passes(player))
		end
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Fire(player, pass.id, false)
	check(count == 0, "Огромная база: перестройка без покупки")
	MarketplaceService.PromptGamePassPurchaseFinished:Fire(player, pass.id, true)
	check(count == 1, "Огромная база: нет перестройки сразу после выдачи")
	check(builtFloors == 1, "Огромная база: при перестройке не виден 1 этаж")
	check(
		string.find(__plotServiceSource, "MonetizationService.PassesChanged.Event:Connect(PlotService.render)", 1, true) ~= nil,
		"Огромная база: PlotService не подписан на PassesChanged"
	)
end)

scenario("игрок ушёл во время сохранения: без записи нет подтверждения", function()
	local player = addPlayer()
	local userId = player.UserId
	local id = newPurchaseId()
	-- Сохранение чека уже в очереди, а финальное сохранение при выходе падает.
	store.beforeWrite = function()
		store.failing = true
		removePlayer(player)
	end
	local decision = receipt(userId, id, SPINS.id)
	store.failing = false
	check(decision == Decision.NotProcessedYet, "выход при сохранении: подтверждено без записи")
	check(not isReceiptSaved(player, id), "выход при сохранении: чек неожиданно записан")

	local back = addPlayer(userId)
	check(receipt(userId, id, SPINS.id) == Decision.PurchaseGranted, "выход при сохранении: не выдано после возвращения")
	check(DataService.get(back).wheel.extraSpins == 3, "выход при сохранении: нет вращений после возвращения")
end)

scenario("сбой запроса геймпасса: Roblox не отвечает, покупка в паузе не теряется", function()
	local vip = Monetization.GamePassByKey.VIP
	local fast = Monetization.GamePassByKey.FAST_MACHINE
	local userId = nextUserId + 1
	MarketplaceService.owned[userId .. ":" .. vip.id] = true
	MarketplaceService.failures[userId .. ":" .. vip.id] = 1000

	local player = addPlayer()
	-- Запрос VIP уже упал и ждёт паузу: в этот момент игрок покупает другой геймпасс.
	MarketplaceService.PromptGamePassPurchaseFinished:Fire(player, fast.id, true)
	MonetizationService.setSocialBonus(player, 0.1)
	runUntilIdle()
	MarketplaceService.failures[userId .. ":" .. vip.id] = nil

	check(MonetizationService.passes(player).FAST_MACHINE == true, "долгий сбой: покупка потеряна при обновлении")
	check(MonetizationService.passes(player).socialBonus == 0.1, "долгий сбой: бонус за друзей потерян при обновлении")
	check(MonetizationService.passes(player).VIP == nil, "долгий сбой: VIP выдан без подтверждения")
	check(MarketplaceService.calls[userId .. ":" .. vip.id] == 4, "долгий сбой: запросов VIP не 4")
	check(#warnings >= 1, "долгий сбой: нет предупреждения в журнале")
end)

scenario("игрок ушёл во время паузы: повторов больше нет", function()
	local vip = Monetization.GamePassByKey.VIP
	local userId = nextUserId + 1
	MarketplaceService.failures[userId .. ":" .. vip.id] = 1000
	local player = addPlayer()
	removePlayer(player)
	runUntilIdle()
	MarketplaceService.failures[userId .. ":" .. vip.id] = nil
	check(MarketplaceService.calls[userId .. ":" .. vip.id] == 1, "уход в паузе: запросы продолжились")
end)

if failures == 0 then
	print("✅ Покупки: пройдено сценариев " .. scenarios)
else
	print("❌ Покупки: провалено проверок " .. failures)
	error("tests failed")
end
