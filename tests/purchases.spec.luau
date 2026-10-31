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
-- latency: запрос идёт по сети, поток ждёт и до записи, и после неё.
-- lostAnswers: сколько запросов подряд запишут данные, но не вернут ответ.
local store = { saved = {}, writes = 0, failing = false, beforeWrite = nil, latency = 0, lostAnswers = 0 }

function store:UpdateAsync(key, transform)
	if self.failing then
		error("DataStore: сбой записи")
	end
	if self.latency > 0 then
		task.wait(self.latency)
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
	if self.latency > 0 then
		task.wait(self.latency)
	end
	if self.lostAnswers > 0 then
		self.lostAnswers -= 1
		error("DataStore: запись прошла, ответа нет")
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

local closeCallback = nil

game = {
	JobId = "test-server",
	BindToClose = function(_, callback)
		closeCallback = callback
	end,
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
-- Вечные циклы автосейва и рассылки состояния тесту не нужны.
table.clear(sleeping)
MonetizationService.init()
-- Фоновую проверку геймпассов сценарии будят сами, по одному обороту (см. passRecheckTick).
local passLoop = table.remove(sleeping, 1)
local passLoopPause = passLoop and passLoop.at - clock
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
local function startReceipt(userId, purchaseId, productId)
	local call = {}
	task.spawn(function()
		call.decision = MarketplaceService.ProcessReceipt({
			PlayerId = userId,
			PurchaseId = purchaseId,
			ProductId = productId,
		})
	end)
	return call
end

local function receipt(userId, purchaseId, productId)
	local call = startReceipt(userId, purchaseId, productId)
	runUntilIdle()
	return call.decision
end

-- Один оборот настоящего цикла фоновой проверки. Его новый сон убираем: цикл вечный,
-- и runUntilIdle иначе не закончится.
local function passRecheckTick()
	if not passLoop then
		return
	end
	resume(passLoop.thread)
	for index, sleeper in ipairs(sleeping) do
		if sleeper.thread == passLoop.thread then
			table.remove(sleeping, index)
			break
		end
	end
	runUntilIdle()
end

-- Вторая пара сервисов со своим состоянием: нужна, когда сценарий выключает хранилище или
-- весь сервер. run.py склеивает stubs и spec в один файл, поэтому cache здесь виден.
local function withFreshServices(options, body)
	local saved = {
		list = Players.list,
		added = Players.PlayerAdded,
		removing = Players.PlayerRemoving,
		prompt = MarketplaceService.PromptGamePassPurchaseFinished,
		process = MarketplaceService.ProcessReceipt,
		getStore = services.DataStoreService.GetDataStore,
		isStudio = services.RunService.IsStudio,
		data = cache["Services/DataService"],
		money = cache["Services/MonetizationService"],
	}
	Players.list, Players.PlayerAdded, Players.PlayerRemoving = {}, newSignal(), newSignal()
	MarketplaceService.PromptGamePassPurchaseFinished = newSignal()
	services.RunService.IsStudio = function()
		return options.studio == true
	end
	if options.noStore then
		services.DataStoreService.GetDataStore = function()
			error("DataStore недоступен")
		end
	end
	cache["Services/DataService"], cache["Services/MonetizationService"] = nil, nil

	local data = shared_require("Services/DataService")
	local money = shared_require("Services/MonetizationService")
	data.init()
	money.init()
	table.clear(sleeping)
	local ok, err = pcall(body, data, money)

	Players.list, Players.PlayerAdded, Players.PlayerRemoving = saved.list, saved.added, saved.removing
	MarketplaceService.PromptGamePassPurchaseFinished = saved.prompt
	MarketplaceService.ProcessReceipt = saved.process
	services.DataStoreService.GetDataStore = saved.getStore
	services.RunService.IsStudio = saved.isStudio
	cache["Services/DataService"], cache["Services/MonetizationService"] = saved.data, saved.money
	if not ok then
		error(err, 0)
	end
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

local function countChanges(player)
	local changes = { count = 0 }
	MonetizationService.PassesChanged.Event:Connect(function(changed)
		if changed == player then
			changes.count += 1
		end
	end)
	return changes
end

local function scenario(name, body)
	scenarios += 1
	table.clear(warnings)
	table.clear(pauses)
	table.clear(sleeping)
	store.failing = false
	store.beforeWrite = nil
	store.latency = 0
	store.lostAnswers = 0
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

scenario("нет DataStore на боевом сервере: покупка не подтверждается", function()
	withFreshServices({ noStore = true, studio = false }, function(data)
		local player = addPlayer()
		runUntilIdle()
		local id = newPurchaseId()
		local writes = store.writes
		check(receipt(player.UserId, id, SPINS.id) == Decision.NotProcessedYet, "нет хранилища: подтверждено без записи")
		check(receipt(player.UserId, id, SPINS.id) == Decision.NotProcessedYet, "нет хранилища: повтор чека подтверждён без записи")
		check(data.get(player).wheel.extraSpins == 3, "нет хранилища: повтор чека выдан второй раз")
		check(store.writes == writes, "нет хранилища: запись в DataStore")
	end)
end)

scenario("нет DataStore в Studio: тестовая покупка работает", function()
	withFreshServices({ noStore = true, studio = true }, function(data)
		local player = addPlayer()
		runUntilIdle()
		check(receipt(player.UserId, newPurchaseId(), SPINS.id) == Decision.PurchaseGranted, "Studio: тестовая покупка не подтверждена")
		check(data.get(player).wheel.extraSpins == 3, "Studio: нет 3 вращений")
	end)
end)

scenario("фоновая проверка: геймпасс возвращается без перезахода", function()
	local vip = Monetization.GamePassByKey.VIP
	local lucky = Monetization.GamePassByKey.LUCKY
	local userId = nextUserId + 1
	local vipKey = userId .. ":" .. vip.id
	MarketplaceService.owned[vipKey] = true
	MarketplaceService.failures[vipKey] = 1000

	local player = addPlayer()
	runUntilIdle()
	local changes = countChanges(player)
	check(passLoopPause == 60, "фоновая проверка: цикл не раз в 60 с")
	check(MonetizationService.passes(player).VIP == nil, "фоновая проверка: VIP выдан без ответа Roblox")
	check(MarketplaceService.calls[vipKey] == 4, "фоновая проверка: при входе запросов VIP не 4")

	passRecheckTick()
	check(MarketplaceService.calls[vipKey] == 5, "фоновая проверка: Roblox молчит, а запрос не один")
	check(MonetizationService.passes(player).VIP == nil, "фоновая проверка: сбой засчитан как покупка")
	check(changes.count == 0, "фоновая проверка: PassesChanged при сбое")

	MarketplaceService.failures[vipKey] = nil
	passRecheckTick()
	check(MonetizationService.passes(player).VIP == true, "фоновая проверка: VIP не вернулся")
	check(changes.count == 1, "фоновая проверка: нет PassesChanged после успеха")
	check(MarketplaceService.calls[vipKey] == 6, "фоновая проверка: запросов VIP не 6")

	passRecheckTick()
	check(MarketplaceService.calls[vipKey] == 6, "фоновая проверка: проверенный геймпасс запрошен снова")
	check(MarketplaceService.calls[userId .. ":" .. lucky.id] == 1, "фоновая проверка: лишний запрос геймпасса с ответом")
	check(changes.count == 1, "фоновая проверка: лишний PassesChanged")
end)

scenario("фоновая проверка: сбой и ответ «нет» не снимают купленное", function()
	local vip = Monetization.GamePassByKey.VIP
	local userId = nextUserId + 1
	local vipKey = userId .. ":" .. vip.id
	MarketplaceService.failures[vipKey] = 1000

	local player = addPlayer()
	runUntilIdle()
	-- Roblox молчит, но покупка прошла прямо в игре.
	MarketplaceService.PromptGamePassPurchaseFinished:Fire(player, vip.id, true)
	local changes = countChanges(player)

	passRecheckTick()
	check(MonetizationService.passes(player).VIP == true, "снятие покупки: сбой запроса снял геймпасс")

	-- Сервис ожил, но ещё не знает о покупке.
	MarketplaceService.failures[vipKey] = nil
	passRecheckTick()
	check(MonetizationService.passes(player).VIP == true, "снятие покупки: ответ «нет» снял геймпасс")
	check(MarketplaceService.calls[vipKey] == 6, "снятие покупки: запросов VIP не 6")
	check(changes.count == 0, "снятие покупки: PassesChanged без изменений")

	passRecheckTick()
	check(MarketplaceService.calls[vipKey] == 6, "снятие покупки: геймпасс с ответом запрошен снова")
end)

scenario("фоновая проверка: игрок ушёл, запросов больше нет", function()
	local vip = Monetization.GamePassByKey.VIP
	local userId = nextUserId + 1
	local vipKey = userId .. ":" .. vip.id
	MarketplaceService.failures[vipKey] = 1000
	local player = addPlayer()
	runUntilIdle()
	check(MarketplaceService.calls[vipKey] == 4, "уход: при входе запросов VIP не 4")
	removePlayer(player)
	runUntilIdle()
	passRecheckTick()
	MarketplaceService.failures[vipKey] = nil
	check(MarketplaceService.calls[vipKey] == 4, "уход: фоновая проверка спрашивает про ушедшего")
end)

-- Сервер выключается, финальная запись ещё идёт, и в этот момент что-то снова сохраняет игрока.
local function shutdownScenario(name, interfere)
	scenario(name, function()
		withFreshServices({}, function(data)
			local player = addPlayer()
			runUntilIdle()
			store.latency = 1
			task.spawn(closeCallback)
			interfere(data, player)
			runUntilIdle()
			check(savedOf(player).session == nil, name .. ": блокировка сессии вернулась")
		end)
	end)
end

shutdownScenario("выключение сервера: автосейв не возвращает блокировку", function(data, player)
	task.spawn(data.save, player)
end)

shutdownScenario("выключение сервера: чек не возвращает блокировку", function(_, player)
	local call = startReceipt(player.UserId, newPurchaseId(), SPINS.id)
	runUntilIdle()
	check(call.decision == Decision.NotProcessedYet, "выключение: чек подтверждён на уходящем сервере")
end)

scenario("два чека подряд до конца первой записи: выдача одна", function()
	local player = addPlayer()
	runUntilIdle()
	local id = newPurchaseId()
	local writes = store.writes
	store.latency = 1

	local first = startReceipt(player.UserId, id, SPINS.id)
	local second = startReceipt(player.UserId, id, SPINS.id)
	check(first.decision == nil, "два чека: первый подтверждён до записи")
	check(second.decision == nil, "два чека: второй подтверждён до записи")
	check(store.writes == writes, "два чека: заглушка не ждёт записи")

	runUntilIdle()
	check(first.decision == Decision.PurchaseGranted, "два чека: первый не подтверждён")
	check(second.decision == Decision.PurchaseGranted, "два чека: второй не подтверждён")
	check(DataService.get(player).wheel.extraSpins == 3, "два чека: выдано не один раз")
	check(savedOf(player).wheel.extraSpins == 3, "два чека: в сохранении выдано не один раз")
	check(#savedOf(player).receipts == 1, "два чека: чек записан не один раз")
end)

scenario("запись прошла, ответа нет, чек пришёл снова: выдача одна", function()
	local player = addPlayer()
	runUntilIdle()
	local userId = player.UserId
	local id = newPurchaseId()
	local writes = store.writes
	store.lostAnswers = 4 -- все попытки withRetries
	check(receipt(userId, id, SPINS.id) == Decision.NotProcessedYet, "нет ответа: подтверждено без ответа")
	check(store.writes == writes + 4, "нет ответа: заглушка не записала данные")
	check(isReceiptSaved(player, id), "нет ответа: чека нет в сохранении")

	check(receipt(userId, id, SPINS.id) == Decision.PurchaseGranted, "нет ответа: повтор чека не подтверждён")
	check(DataService.get(player).wheel.extraSpins == 3, "нет ответа: выдано второй раз")
	check(savedOf(player).wheel.extraSpins == 3, "нет ответа: в сохранении выдано второй раз")

	-- То же, но чек приходит уже на следующем заходе: выданное читается из сохранения.
	local nextId = newPurchaseId()
	store.lostAnswers = 4
	check(receipt(userId, nextId, SPINS.id) == Decision.NotProcessedYet, "нет ответа: второй чек подтверждён без ответа")
	removePlayer(player)
	runUntilIdle()
	local back = addPlayer(userId)
	runUntilIdle()
	check(DataService.get(back).wheel.extraSpins == 6, "нет ответа: выданное не загрузилось")
	check(receipt(userId, nextId, SPINS.id) == Decision.PurchaseGranted, "нет ответа: чек после перезахода не подтверждён")
	check(DataService.get(back).wheel.extraSpins == 6, "нет ответа: выдано второй раз после перезахода")
end)

if failures == 0 then
	print("✅ Покупки: пройдено сценариев " .. scenarios)
else
	print("❌ Покупки: провалено проверок " .. failures)
	error("tests failed")
end
