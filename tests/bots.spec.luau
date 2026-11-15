-- Боты-игроки внутри игры (решение лида 14.11). Настоящие сервер и клиент на заглушке мира, боты включены только здесь.
-- Бот — не Player: нет в Players, нет профиля, нет записей в DataStore и таблицах лидеров. Он ходит, ловит диких,
-- «крафтит» на свободной базе, крадёт и шлёпает по тем же правилам, что игрок (кулдаун 0,8 с, дальность 9, сила 70,
-- скорость 16, с брейнротом 12). Людей ≥ 4: боты уходят по одному и не посреди кражи.
-- Движение: тест подставляет BotService.mover, который двигает бота со скоростью Humanoid.WalkSpeed раз в тик.

local failures = 0
local scenarios = 0
local function check(cond, msg)
	if not cond then
		failures += 1
		print("❌ " .. msg)
	end
end

local Players = game:GetService("Players")

-- Что пишется в DataStore: каждое обращение к ключу (SetAsync, UpdateAsync, GetAsync) попадает в журнал.
local storeKeys = {}
do
	local props = rawget(game:GetService("DataStoreService"), "__state").props
	for _, getter in ipairs({ "GetDataStore", "GetOrderedDataStore" }) do
		local original = props[getter]
		props[getter] = function(self, name)
			local store = original(self, name)
			if not store.logged then
				store.logged = true
				for _, method in ipairs({ "SetAsync", "UpdateAsync", "GetAsync", "RemoveAsync" }) do
					local inner = store[method]
					if inner then
						store[method] = function(me, key, ...)
							table.insert(storeKeys, tostring(key))
							return inner(me, key, ...)
						end
					end
				end
			end
			return store
		end
	end
end

-- Боевой режим (не Studio): профили пишутся в DataStore (в памяти), и тест читает сохранение хозяина.
World.studio = false

local joined = 0
Players.PlayerAdded:Connect(function()
	joined += 1
end)

local owner = World.addPlayer(4001, "Owner")
local S = shared_require("Strings")
World.startServer()
World.startClient()

local DataService = shared_require("Services/DataService")
local FactoryService = shared_require("Services/FactoryService")
local PlotService = shared_require("Services/PlotService")
local WildService = shared_require("Services/WildService")
local StealService = shared_require("Services/StealService")
local MoveGuard = shared_require("Services/MoveGuardService")
local BotService = shared_require("Services/BotService")
local Actions = shared_require("Services/Actions")
local Formulas = shared_require("Util/Formulas")
local Tutorial = shared_require("Config/Tutorial")
local Config = shared_require("Config/Bots")

local TICK = BotService.TICK
local FAR = Vector3.new(600, 5, 600)

local realMover = BotService.mover -- настоящий (с путём), нужен тесту «пауза после неудачного расчёта пути»

-- Бот шагает к цели со скоростью своего Humanoid (как настоящий MoveTo), раз в тик.
BotService.mover = function(bot, target)
	local root = bot.Character.HumanoidRootPart
	local speed = bot.Character.Humanoid.WalkSpeed
	local offset = Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z)
	if speed <= 0 or offset.Magnitude < 0.05 then
		return
	end
	local at = root.Position + offset.Unit * math.min(offset.Magnitude, speed * TICK)
	root.CFrame = CFrame.lookAt(at, at + offset.Unit)
end

local updates = 0
do
	local original = BotService.update
	BotService.update = function(...)
		updates += 1
		return original(...)
	end
end

local function botCount()
	return #BotService.list()
end

local function step(seconds, each)
	local left = seconds
	while left > 1e-9 do
		local dt = math.min(0.25, left)
		World.advance(dt)
		left -= dt
		if each then
			each()
		end
	end
end

local function waitFor(cond, timeout, each)
	local waited = 0
	while waited < timeout do
		if cond() then
			return true
		end
		World.advance(0.25)
		waited += 0.25
		if each then
			each()
		end
	end
	return cond()
end

local function rootOf(player)
	return player.Character.HumanoidRootPart
end

local function place(player, position, lookAt)
	MoveGuard.teleported(player, position)
	rootOf(player).CFrame = CFrame.lookAt(position, lookAt or (position + Vector3.new(0, 0, 1)))
	World.advance(MoveGuard.TELEPORT_GRACE + 4)
end

-- Игрок, который зашёл уже после запуска сервера: заглушка не раздаёт Backpack из StarterPack сама, делаем это.
local function addHuman(userId, name)
	local player = World.addPlayer(userId, name)
	local template = game:GetService("StarterPack"):FindFirstChild(S.t("steal.slapper"))
	if template and not player.Backpack:FindFirstChild(template.Name) then
		template:Clone().Parent = player.Backpack
	end
	World.advance(0.1)
	return player
end

-- Поставить игрока без ожидания (время в тесте идёт).
local function put(player, position, lookAt)
	MoveGuard.teleported(player, position)
	rootOf(player).CFrame = CFrame.lookAt(position, lookAt or (position + Vector3.new(0, 0, 1)))
end

local function stateReport()
	local parts = {}
	for _, bot in ipairs(BotService.list()) do
		table.insert(parts, bot.DisplayName .. ":" .. bot.state .. (StealService.carryOf(bot) and "+несёт" or ""))
	end
	return table.concat(parts, ", ")
end

local function setWeights(weights)
	BotService.weights = weights
end

local function readyToSteal()
	for _, bot in ipairs(BotService.list()) do
		bot.nextStealAt = 0
	end
end

local function sentCount(remote)
	local count = 0
	for _, sent in ipairs(World.sent) do
		if sent.remote == remote then
			count += 1
		end
	end
	return count
end

-- Замахи: FireAllClients пишется по записи на каждого игрока, считаем записи для одного (Owner) = число замахов.
local function swings()
	local count = 0
	for _, sent in ipairs(World.sent) do
		if sent.remote == "SlapFx" and sent.player == owner then
			count += 1
		end
	end
	return count
end

local function knockbacksTo(player)
	local list = {}
	for _, sent in ipairs(World.sent) do
		if sent.remote == "Knockback" and sent.player == player and not sent.everyone then
			table.insert(list, sent.args)
		end
	end
	return list
end

local function creatureModel(plotOwner, entry)
	for _, model in ipairs(PlotService.getPlot(plotOwner).model.Creatures:GetChildren()) do
		if model:GetAttribute("Uid") == entry.uid then
			return model
		end
	end
	return nil
end

local function has(player, entry)
	for _, item in ipairs(DataService.get(player).creatures) do
		if item.uid == entry.uid then
			return true
		end
	end
	return false
end

-- Что лежит в сохранении игрока (DataStore в памяти): сколько записей с этим uid и сколько потерь от воров записано.
local function savedState(player, uid)
	local store = World.services.DataStoreService:GetDataStore("BrainrotFactory_v1")
	local saved = store.data["player_" .. player.UserId] -- заглушка DataStore в памяти (tests/world.luau, memoryStore)
	if type(saved) ~= "table" or type(saved.creatures) ~= "table" then
		return -1, -1
	end
	local copies = 0
	for _, item in ipairs(saved.creatures) do
		if item.uid == uid then
			copies += 1
		end
	end
	return copies, (saved.stats and saved.stats.lostToThieves) or 0
end

local function give(player, id, source)
	local entry = FactoryService.give(player, id or "bananito_ninjini", "normal", source)
	World.advance(0.5)
	return entry
end

local function finishTutorial(player)
	DataService.get(player).tutorial.step = #Tutorial.Steps + 1
end

local function scenario(name, body)
	scenarios += 1
	local before = failures
	local ok, err = pcall(body)
	if not ok then
		failures += 1
		print("❌ " .. name .. ": " .. tostring(err))
	end
	print(string.format("  %s %d. %s", failures == before and "✅" or "❌", scenarios, name))
end

print("— Боты —")

local watcher, extra = nil, {}

scenario("один игрок: появляются 3 бота с подписью [BOT], не игроки", function()
	-- Появляются по одному, с паузой, и за 15 с их три.
	local appeared, last, startedAt = {}, botCount(), World.now()
	check(last == 0, "боты были до проверки: " .. last)
	check(waitFor(function()
		return botCount() == 3
	end, 15, function()
		local count = botCount()
		if count ~= last then
			check(count == last + 1, "боты появились по " .. (count - last) .. " сразу")
			table.insert(appeared, World.now() - startedAt)
			last = count
		end
	end), "при одном игроке ботов " .. botCount() .. ", нужно 3")
	for index = 2, #appeared do
		check(appeared[index] - appeared[index - 1] >= 2, string.format("боты появились без паузы (%.2f с)", appeared[index] - appeared[index - 1]))
	end
	local names, folder = {}, workspace:FindFirstChild("Bots")
	check(folder ~= nil and #folder:GetChildren() == 3, "в workspace.Bots не 3 модели")
	for _, bot in ipairs(BotService.list()) do
		local label = bot.Character.Head.BotLabel.TextLabel
		check(string.sub(label.Text, 1, 6) == "[BOT] ", "подпись без [BOT]: " .. tostring(label.Text))
		check(bot.DisplayName == label.Text, "подпись не совпадает с именем бота")
		check(not names[bot.DisplayName], "два бота с одним именем: " .. bot.DisplayName)
		names[bot.DisplayName] = true
		check(bot.UserId < 0, "UserId бота не отрицательный: " .. tostring(bot.UserId))
		check(Players:GetPlayerByUserId(bot.UserId) == nil, "бот найден среди игроков")
		check(bot.Character:FindFirstChild("Humanoid").WalkSpeed == StealService.NORMAL_SPEED, "скорость бота не как у новичка")
		check(bot.Character:FindFirstChild("HumanoidRootPart") ~= nil and bot.Character:FindFirstChild("Head") ~= nil, "у бота нет тела")
	end
	check(#Players:GetPlayers() == 1, "бот попал в Players: " .. #Players:GetPlayers())
	check(joined == 1, "PlayerAdded сработал не только для человека: " .. joined)
	World.advance(100) -- защита хозяина при входе кончилась
	place(owner, FAR)
end)

scenario("2 игрока: 3 бота; 3 игрока: бот уходит, остаётся 2", function()
	watcher = addHuman(4002, "Watcher")
	place(watcher, FAR + Vector3.new(30, 0, 0))
	World.advance(20)
	check(botCount() == 3, "при 2 игроках ботов " .. botCount())
	local third = addHuman(4003, "Third")
	table.insert(extra, third)
	put(third, FAR + Vector3.new(-30, 0, 0))
	check(waitFor(function()
		return botCount() == 2
	end, 60), "при 3 игроках ботов " .. botCount() .. ", нужно 2")
	World.advance(30)
	check(botCount() == 2, "при 3 игроках стало " .. botCount())
	World.removePlayer(third)
	extra = {}
	check(waitFor(function()
		return botCount() == 3
	end, 30), "после ухода третьего ботов " .. botCount() .. ", нужно 3")
end)

scenario("уход отменили посреди «уходит»: бот не зависает, а возвращается к делам", function()
	local third = addHuman(4020, "Third2")
	put(third, FAR + Vector3.new(-30, 0, 0))
	local leaver
	check(waitFor(function()
		for _, bot in ipairs(BotService.list()) do
			if bot.state == "leave" then
				leaver = bot
				return true
			end
		end
		return false
	end, 40), "при 3 игроках никто не пошёл к выходу: " .. stateReport())
	World.removePlayer(third) -- людей снова двое: уход отменён
	World.advance(1)
	if leaver then
		check(leaver.leaving == false, "уход не отменён")
		check(leaver.removed ~= true, "бот ушёл, хотя уход отменили")
		check(leaver.state ~= "leave", "бот остался в состоянии «уходит» после отмены: " .. tostring(leaver.state))
		step(6)
		check(leaver.state ~= "leave" and leaver.removed ~= true, "бот так и не вернулся к делам: " .. tostring(leaver.state))
	end
	check(waitFor(function()
		return botCount() == 3
	end, 30), "после отмены ботов не 3: " .. botCount())
end)

scenario("4 игрока: боты уходят по одному, с паузой, не все разом; новых нет", function()
	local a = addHuman(4004, "Fourth")
	local b = addHuman(4005, "Fifth")
	put(a, FAR + Vector3.new(0, 0, 30))
	put(b, FAR + Vector3.new(0, 0, -30))
	-- 4 живых игрока: с этой секунды отсчёт.
	check(#Players:GetPlayers() == 4, "игроков не 4")
	local timeline, last, startedAt = {}, botCount(), World.now()
	local maxLeaving = 0
	step(90, function()
		local count = botCount()
		if count ~= last then
			check(count == last - 1, "число ботов упало на " .. (last - count) .. " сразу")
			table.insert(timeline, World.now() - startedAt)
			last = count
		end
		local leaving = 0
		for _, bot in ipairs(BotService.list()) do
			if bot.leaving then
				leaving += 1
			end
		end
		maxLeaving = math.max(maxLeaving, leaving)
	end)
	check(botCount() == 0, "при 4 игроках осталось ботов: " .. botCount())
	check(#timeline == 3, "уходов записано " .. #timeline .. ", нужно 3")
	check(maxLeaving <= 1, "одновременно уходят " .. maxLeaving)
	for index = 2, #timeline do
		check(timeline[index] - timeline[index - 1] >= 8, string.format("пауза между уходами %.1f с", timeline[index] - timeline[index - 1]))
	end
	local folder = workspace:FindFirstChild("Bots")
	check(#folder:GetChildren() == 0, "в workspace.Bots остались модели: " .. #folder:GetChildren())
	-- Новых нет, пока людей четверо.
	step(40)
	check(botCount() == 0, "при 4 игроках появились боты")
	extra = { a, b }
end)

scenario("люди ушли: боты возвращаются", function()
	for _, player in ipairs(extra) do
		World.removePlayer(player)
	end
	extra = {}
	check(waitFor(function()
		return botCount() == 3
	end, 30), "после ухода людей ботов " .. botCount())
end)

scenario("обновление поведения не чаще 4 раз в секунду", function()
	local before, from = updates, World.now()
	step(20)
	local rate = (updates - before) / (World.now() - from)
	check(rate <= 4.05, string.format("обновлений в секунду: %.2f", rate))
	check(rate >= 3, string.format("боты почти не обновляются: %.2f в секунду", rate))
	check(BotService.TICK >= 0.25, "TICK меньше 0,25 с")
end)

-- Кража -----------------------------------------------------------------------------

local ownerEntry, paidEntry, rareEntry
local function belongsToBot(model)
	return model ~= nil and string.sub(model.Name, 1, 4) == "Bot_"
end

scenario("таблица целей: 12 брейнротов, которых бот может взять, и 14, которых нет", function()
	setWeights({ wander = 1 })
	local rng = Random.new(11)
	local function idOf(rarity)
		return Formulas.randomCreatureOf(rarity, rng).id
	end
	local function verdict(id, mutation, source, change)
		local entry = FactoryService.give(owner, id, mutation, source)
		World.advance(0.5)
		local model = creatureModel(owner, entry)
		if change then
			change(model, entry)
		end
		local answer = model ~= nil and BotService.canTarget(owner, model, os.clock()) == true
		local list = DataService.get(owner).creatures
		table.remove(list, table.find(list, entry))
		FactoryService.CreaturesChanged:Fire(owner)
		World.advance(0.5)
		return answer
	end
	local free = Formulas.SOURCE_FREE
	finishTutorial(owner)
	-- Можно: свободный (не платный), обычной редкости (ранги 1–4), на земле, хозяин прошёл обучение, база открыта.
	local allowed = {
		{ "обычный", idOf("normie"), "normal", free },
		{ "lowkey", idOf("lowkey"), "normal", free },
		{ "rizz", idOf("rizz"), "normal", free },
		{ "sigma", idOf("sigma"), "normal", free },
		{ "другой normie", idOf("normie"), "normal", free },
		{ "другой sigma", idOf("sigma"), "normal", free },
		{ "с мутацией cosmic", idOf("normie"), "cosmic", free },
		{ "с мутацией gold", idOf("lowkey"), "gold", free },
		{ "bananito_ninjini", "bananito_ninjini", "normal", free },
		{ "rizz с мутацией", idOf("rizz"), "cosmic", free },
		{ "ещё один lowkey", idOf("lowkey"), "normal", free },
		{ "ещё один rizz", idOf("rizz"), "normal", free },
	}
	local wronglyRefused = 0
	for _, case in ipairs(allowed) do
		if not verdict(case[2], case[3], case[4]) then
			wronglyRefused += 1
			print("   ложный отказ: " .. case[1])
		end
	end
	check(wronglyRefused == 0, "ложных отказов в таблице целей: " .. wronglyRefused)
	check(#allowed >= 10, "в таблице «можно» меньше 10 строк")
	-- Нельзя: платный источник любого вида, неизвестный источник, редкие, второй этаж, чужое состояние.
	local forbidden = {
		{ "платный (coins)", idOf("normie"), "normal", Formulas.SOURCE_COINS },
		{ "платный (luck)", idOf("normie"), "normal", Formulas.SOURCE_LUCK },
		{ "платный (spin)", idOf("normie"), "normal", Formulas.SOURCE_SPIN },
		{ "источник неизвестен (nil считается платным)", idOf("normie"), "normal", "unknown" },
		{ "aura (ранг 5)", idOf("aura"), "normal", free },
		{ "skibidi (ранг 6)", idOf("skibidi"), "normal", free },
		{ "aura с мутацией", idOf("aura"), "cosmic", free },
		{ "на втором этаже", idOf("normie"), "normal", free, function(model)
			local base = model:GetAttribute("BaseCFrame")
			model:SetAttribute("BaseCFrame", CFrame.new(base.Position.X, base.Position.Y + 14, base.Position.Z))
		end },
		{ "уже оглушён (0 ❤️)", idOf("normie"), "normal", free, function(model)
			model:SetAttribute("Hp", 0)
		end },
		{ "модель без Uid", idOf("normie"), "normal", free, function(model)
			model:SetAttribute("Uid", nil)
		end },
		{ "Uid не из данных хозяина", idOf("normie"), "normal", free, function(model)
			model:SetAttribute("Uid", "no-such-uid")
		end },
		{ "хозяин в обучении (шаг 1)", idOf("normie"), "normal", free, function()
			DataService.get(owner).tutorial.step = 1
		end },
		{ "хозяин на последнем шаге обучения", idOf("normie"), "normal", free, function()
			DataService.get(owner).tutorial.step = #Tutorial.Steps
		end },
		{ "база закрыта (замок хозяина)", idOf("normie"), "normal", free },
	}
	-- Закрытие базы делаем настоящим замком хозяина (кнопка у плиты), как игрок.
	local falseAllowed = 0
	for _, case in ipairs(forbidden) do
		if case[1] == "база закрыта (замок хозяина)" then
			local plot = PlotService.getPlot(owner)
			local button = plot.model.LockButton
			place(owner, button.Position + Vector3.new(0, 2, 3))
			World.prompt(button.LockPrompt, owner, 0)
			check(StealService.isLocked(owner), "замок хозяина не закрылся")
		end
		local answer = verdict(case[2], case[3], case[4], case[5])
		finishTutorial(owner)
		if answer then
			falseAllowed += 1
			print("   ложный пропуск: " .. case[1])
		end
	end
	check(falseAllowed == 0, "ложных пропусков в таблице целей: " .. falseAllowed)
	check(#forbidden >= 10, "в таблице «нельзя» меньше 10 строк")
	print(string.format("   таблица целей: можно %d (ложных отказов %d), нельзя %d (ложных пропусков %d)", #allowed, wronglyRefused, #forbidden, falseAllowed))
	World.advance(StealService.LOCK_TIME + StealService.LOCK_COOLDOWN) -- замок хозяина кончился
	place(owner, FAR)
	check(not StealService.isLocked(owner), "замок не кончился")
	DataService.get(owner).tutorial.step = 1 -- следующие сценарии начинаются с «хозяин в обучении»
end)

-- Шлепок бота бьёт только свою цель (ревью 14.11, п. 2): брейнрот, стоящий ближе, не страдает.
scenario("шлепок бота: только цель кражи; ответный шлепок брейнроты не трогает", function()
	setWeights({ wander = 1 })
	local rng = Random.new(5)
	local bot = BotService.list()[1]
	for _, variant in ipairs({
		{ "платный", "bananito_ninjini", Formulas.SOURCE_COINS },
		{ "редкий (aura)", Formulas.randomCreatureOf("aura", rng).id, Formulas.SOURCE_FREE },
	}) do
		World.advance(2)
		local bodyBot = bot.Character.HumanoidRootPart
		bot.Character.Humanoid.WalkSpeed = 0
		local origin = bodyBot.Position
		bodyBot.CFrame = CFrame.lookAt(origin, origin + Vector3.new(0, 0, 1))
		local targetEntry = give(owner)
		local nearEntry = give(owner, variant[2], variant[3])
		local target, near = creatureModel(owner, targetEntry), creatureModel(owner, nearEntry)
		target:SetAttribute("BaseCFrame", CFrame.new(origin.X, origin.Y, origin.Z + 6))
		near:SetAttribute("BaseCFrame", CFrame.new(origin.X, origin.Y, origin.Z + 3))
		local targetHp, nearHp = target:GetAttribute("Hp"), near:GetAttribute("Hp")
		StealService.botSlap(bot, target)
		check(target:GetAttribute("Hp") == targetHp - 1, variant[1] .. ": цель кражи не получила удар")
		check(near:GetAttribute("Hp") == nearHp, variant[1] .. ": бот ударил брейнрота, который стоял ближе (" .. tostring(near:GetAttribute("Hp")) .. " из " .. nearHp .. ")")
		-- Замах без цели (как ответный) брейнрота не бьёт вообще.
		World.advance(StealService.SLAP_COOLDOWN + 0.1)
		StealService.botSlap(bot)
		check(target:GetAttribute("Hp") == targetHp - 1 and near:GetAttribute("Hp") == nearHp, variant[1] .. ": замах без цели задел брейнрота")
		-- Ответ на шлепок игрока: брейнроты в конусе целы, игрок получает отдачу.
		World.advance(StealService.SLAP_COOLDOWN + 0.1)
		local at = origin + Vector3.new(0, 0, -2)
		put(watcher, at, origin)
		local before = #knockbacksTo(watcher)
		-- Игрок шлёпнул бота (сам удар игрока бьёт ближайший брейнрот, как у любого игрока, поэтому отмечаем удар напрямую).
		bot.slappedBy, bot.slappedAt = watcher, os.clock()
		World.advance(1.5)
		check(#knockbacksTo(watcher) == before + 1, variant[1] .. ": бот не ответил игроку")
		check(target:GetAttribute("Hp") == targetHp - 1 and near:GetAttribute("Hp") == nearHp, variant[1] .. ": ответный шлепок задел брейнрота")
		bot.retaliated = nil
		local list = DataService.get(owner).creatures
		table.remove(list, table.find(list, nearEntry))
		table.remove(list, table.find(list, targetEntry))
		FactoryService.CreaturesChanged:Fire(owner)
		World.advance(1)
		bot.Character.Humanoid.WalkSpeed = StealService.NORMAL_SPEED
		put(watcher, FAR + Vector3.new(30, 0, 0))
	end
end)

-- Список разрешений спрашивается и в момент кражи (ревью 14.11, п. 4): состояние хозяина могло измениться.
scenario("кража в момент удержания: состояние хозяина изменилось — кражи нет (1 можно, 6 нет)", function()
	setWeights({ wander = 1 })
	local bot = BotService.list()[1]
	local rng = Random.new(9)
	local aura = Formulas.randomCreatureOf("aura", rng).id
	local freeId = "bananito_ninjini"
	local function prepare()
		finishTutorial(owner)
		World.advance(1)
		local entry = give(owner, freeId)
		local model = creatureModel(owner, entry)
		model:SetAttribute("Hp", 0)
		model:SetAttribute("StunnedUntil", workspace:GetServerTimeNow() + 15)
		local body = model.PrimaryPart.Position
		bot.Character.Humanoid.WalkSpeed = 0
		bot.Character.HumanoidRootPart.CFrame = CFrame.new(body + Vector3.new(0, 0, -3))
		return entry, model
	end
	local function cleanup(entry)
		StealService.releaseBot(bot)
		local list = DataService.get(owner).creatures
		local index
		for position, item in ipairs(list) do
			if item.uid == entry.uid then
				index = position
			end
		end
		if index then
			table.remove(list, index)
		end
		FactoryService.CreaturesChanged:Fire(owner)
		World.advance(1)
	end
	-- Можно: всё разрешено, кража начинается (и брейнрот возвращается хозяину при освобождении бота).
	do
		local entry, model = prepare()
		local took = StealService.botBeginSteal(bot, model)
		check(took == true and StealService.carryOf(bot) ~= nil, "контроль: при всех разрешениях бот не начал кражу")
		check(not has(owner, entry), "контроль: брейнрот не взят в руки")
		cleanup(entry)
	end
	local cases = {
		{ "хозяин снова в обучении", function() DataService.get(owner).tutorial.step = 1 end },
		{ "брейнрот стал редким (ранг 5)", function(entry) entry.id = aura end },
		{ "брейнрот стал платным", function(entry) entry.source = Formulas.SOURCE_COINS end },
		{ "брейнрот переехал на второй этаж", function(_, model)
			local base = model:GetAttribute("BaseCFrame")
			model:SetAttribute("BaseCFrame", CFrame.new(base.Position.X, base.Position.Y + 14, base.Position.Z))
		end },
		{ "брейнрот пропал из данных хозяина", function(entry) entry.uid = "moved" end },
		{ "хозяин закрыл базу", function()
			local plot = PlotService.getPlot(owner)
			local button = plot.model.LockButton
			place(owner, button.Position + Vector3.new(0, 2, 3))
			World.prompt(button.LockPrompt, owner, 0)
		end },
	}
	local wrong = 0
	for _, case in ipairs(cases) do
		local entry, model = prepare()
		local originalUid = entry.uid
		case[2](entry, model)
		local took = StealService.botBeginSteal(bot, model)
		if took or StealService.carryOf(bot) then
			wrong += 1
			print("   ложный пропуск при краже: " .. case[1])
		end
		entry.uid = originalUid
		entry.id = freeId
		entry.source = Formulas.SOURCE_FREE
		cleanup(entry)
		if case[1] == "хозяин закрыл базу" then
			World.advance(StealService.LOCK_TIME + StealService.LOCK_COOLDOWN)
			place(owner, FAR)
		end
	end
	check(wrong == 0, "бот начал кражу при запрете: " .. wrong .. " из " .. #cases)
	bot.Character.Humanoid.WalkSpeed = StealService.NORMAL_SPEED
	DataService.get(owner).tutorial.step = 1
end)

-- ComputeAsync не каждый тик (ревью 14.11, п. 3).
scenario("недостижимая цель: расчёт пути не чаще раза в 2,5 с (за 15 с не больше 8)", function()
	setWeights({ wander = 1 })
	local bot = BotService.list()[1]
	local humanoid = bot.Character.Humanoid
	local moves, computes = 0, 0
	humanoid.MoveTo = function()
		moves += 1
	end
	local function service(success)
		return {
			CreatePath = function()
				return {
					Status = if success then Enum.PathStatus.Success else Enum.PathStatus.NoPath,
					ComputeAsync = function()
						computes += 1
					end,
					GetWaypoints = function()
						return { { Position = Vector3.new(50, 0, 50), Action = Enum.PathWaypointAction.Walk } }
					end,
				}
			end,
		}
	end
	local root = bot.Character.HumanoidRootPart
	local target = root.Position + Vector3.new(120, 0, 0)
	BotService.pathfinding = service(false)
	for _ = 1, 60 do
		realMover(bot, target)
		World.advance(0.25)
	end
	check(computes <= 8, "расчётов пути за 15 с недостижимой цели: " .. computes .. " (нужно не больше 8)")
	check(computes >= 1, "путь не считался вообще (проверка пуста)")
	check(moves >= 55, "бот перестал идти напрямую после неудачи пути: шагов " .. moves)
	-- Контроль: удачный путь не душится этой паузой (пересчёт раз в 4 с).
	computes, moves = 0, 0
	bot.waypoints, bot.pathTarget, bot.pathRetryAt = nil, nil, nil
	BotService.pathfinding = service(true)
	for _ = 1, 60 do
		realMover(bot, target)
		World.advance(0.25)
	end
	check(computes >= 3 and computes <= 5, "расчётов при удачном пути за 15 с: " .. computes)
	BotService.pathfinding = nil
	humanoid.MoveTo = nil
end)

scenario("новичок в обучении, платный и редкий брейнроты, чужие базы: бот не крадёт", function()
	-- Хозяин ещё в обучении (шаг 1): у него и у Watcher бот ничего не берёт.
	ownerEntry = give(owner)
	paidEntry = give(owner, "bananito_ninjini", Formulas.SOURCE_COINS)
	give(watcher)
	local rare = Formulas.randomCreatureOf("aura", Random.new(7))
	rareEntry = give(owner, rare.id)
	setWeights({ steal = 1 })
	readyToSteal()
	local carried = false
	step(150, function()
		for _, bot in ipairs(BotService.list()) do
			carried = carried or StealService.carryOf(bot) ~= nil or bot.state == "steal"
		end
	end)
	check(not carried, "бот пошёл красть у игрока в обучении")
	check(creatureModel(owner, ownerEntry):GetAttribute("Hp") == creatureModel(owner, ownerEntry):GetAttribute("MaxHp"), "бот бил брейнрота новичка")
	-- Теперь хозяин прошёл обучение, но у него есть только платный и редкий: их бот не трогает.
	finishTutorial(owner)
	local owned = DataService.get(owner).creatures
	local keep = {}
	for _, item in ipairs(owned) do
		if item.uid == paidEntry.uid or item.uid == rareEntry.uid then
			table.insert(keep, item)
		end
	end
	DataService.get(owner).creatures = keep
	FactoryService.CreaturesChanged:Fire(owner)
	World.advance(1)
	readyToSteal()
	step(150, function()
		for _, bot in ipairs(BotService.list()) do
			carried = carried or StealService.carryOf(bot) ~= nil or bot.state == "steal"
		end
	end)
	check(not carried, "бот пошёл красть платного или редкого брейнрота")
	check(has(owner, paidEntry) and has(owner, rareEntry), "платный или редкий пропал у хозяина")
end)

local stolenEntry, theftBot
scenario("бот ворует по правилам: удары с кулдауном 0,8 с, 5 ❤️, F, скорость 12, один вор за раз", function()
	setWeights({ steal = 1 })
	stolenEntry = give(owner)
	local model = creatureModel(owner, stolenEntry)
	check(model:GetAttribute("MaxHp") == 5, "на земле не 5 ❤️: " .. tostring(model:GetAttribute("MaxHp")))
	readyToSteal()
	local countBefore = #DataService.get(owner).creatures
	local notesBefore = #World.sent
	local hits, lastHp, lastHitAt, maxThieves = {}, model:GetAttribute("Hp"), nil, 0
	local sentBefore = swings()
	local carriedAt
	local function sample()
		local thieves = 0
		for _, bot in ipairs(BotService.list()) do
			if bot.state == "steal" or bot.state == "flee" then
				thieves += 1
			end
			if StealService.carryOf(bot) and not theftBot then
				theftBot, carriedAt = bot, World.now()
			end
		end
		maxThieves = math.max(maxThieves, thieves)
		local hp = model:GetAttribute("Hp")
		if hp < lastHp then
			table.insert(hits, World.now())
		end
		lastHp = hp
	end
	for _ = 1, 2400 do
		World.advance(0.05)
		sample()
		if theftBot then
			break
		end
	end
	check(theftBot ~= nil, "бот не украл брейнрота за 120 с")
	check(#hits == 5, "ударов по брейнроту " .. #hits .. ", нужно 5")
	for index = 2, #hits do
		check(hits[index] - hits[index - 1] >= StealService.SLAP_COOLDOWN - 0.06, string.format("удары ботом через %.2f с (кулдаун %.1f)", hits[index] - hits[index - 1], StealService.SLAP_COOLDOWN))
	end
	check(maxThieves <= 1, "воров одновременно: " .. maxThieves)
	check(swings() - sentBefore >= 5, "бот бил без события шлепка (SlapFx)")
	local carry = StealService.carryOf(theftBot)
	check(carry and carry.owner == owner and carry.entry.uid == stolenEntry.uid, "бот несёт не того")
	check(theftBot.Character.Humanoid.WalkSpeed == StealService.CARRY_SPEED, "скорость вора-бота " .. tostring(theftBot.Character.Humanoid.WalkSpeed))
	check(not has(owner, stolenEntry), "у хозяина остался украденный")
	check(owner:GetAttribute("BeingRobbed") == 1, "у хозяина нет отметки «грабят»")
	-- Сохранение посреди переноса (автосохранение, выход, сбой сервера): брейнрот в нём ровно один раз, потери не записано.
	check(DataService.save(owner) == true, "сохранение посреди переноса не прошло")
	local copiesMid, lostMid = savedState(owner, stolenEntry.uid)
	check(copiesMid == 1, "в сохранении посреди переноса записей украденного " .. copiesMid .. " (нужна 1)")
	check(lostMid == 0, "в сохранении посреди переноса записана потеря от воров: " .. lostMid)
	-- Хозяин получил тревогу с подписью [BOT].
	local alarm = false
	for _, sent in ipairs(World.sent) do
		if sent.remote == "Notify" and sent.player == owner and string.find(S.text(sent.args[1]), "[BOT]", 1, true) then
			alarm = true
		end
	end
	check(alarm, "хозяину не пришла тревога с [BOT]")
	-- Доходит до места, но брейнрот не забирает насовсем (решение лида 14.11): он возвращается хозяину в его данные.
	check(waitFor(function()
		return theftBot.escaped == 1
	end, 70), "бот не добежал до места")
	check(StealService.carryOf(theftBot) == nil, "бот всё ещё несёт")
	check(has(owner, stolenEntry), "брейнрот не вернулся хозяину после побега бота")
	check(#DataService.get(owner).creatures == countBefore, "брейнротов у хозяина до кражи " .. countBefore .. ", после побега бота " .. #DataService.get(owner).creatures)
	check((DataService.get(owner).stats.lostToThieves or 0) == 0, "потеря записана хозяину, хотя брейнрот вернулся")
	check(creatureModel(owner, stolenEntry) ~= nil, "брейнрот не появился на базе хозяина")
	local returnedNote = false
	for index = notesBefore + 1, #World.sent do
		local sent = World.sent[index]
		if sent.remote == "Notify" and sent.player == owner then
			local text = S.text(sent.args[1])
			if text == S.t("steal.bot_returned") and string.find(text, "[BOT]", 1, true) and not string.find(text, "{", 1, true) then
				returnedNote = true
			end
		end
	end
	check(returnedNote, "хозяину не пришло «" .. S.t("steal.bot_returned") .. "»")
	if World.locale == "en-us" then
		check(S.t("steal.bot_returned") == "✅ [BOT] dropped your brainrot — it's back on your base", "текст строки: " .. S.t("steal.bot_returned"))
	end
	-- Тот же экземпляр записи, без дубля: в данных хозяина ровно одна запись с этим uid, и это та самая таблица.
	local copies, same = 0, false
	for _, item in ipairs(DataService.get(owner).creatures) do
		if item.uid == stolenEntry.uid then
			copies += 1
			same = rawequal(item, stolenEntry)
		end
	end
	check(copies == 1 and same, "после побега бота у хозяина записей украденного " .. copies .. " (нужна 1, та же таблица: " .. tostring(same) .. ")")
	check(theftBot.Character.Humanoid.WalkSpeed == StealService.NORMAL_SPEED, "скорость после кражи не вернулась")
	check(owner:GetAttribute("BeingRobbed") == nil, "отметка «грабят» не снята")
end)

scenario("того же хозяина боты грабят не чаще раза в 5 минут", function()
	local second = give(owner)
	setWeights({ steal = 1 })
	readyToSteal()
	local touched = false
	local model = creatureModel(owner, second)
	step(BotService.OWNER_COOLDOWN - 70, function()
		touched = touched or model:GetAttribute("Hp") < model:GetAttribute("MaxHp") or owner:GetAttribute("BeingRobbed") ~= nil
		readyToSteal()
	end)
	check(not touched, "бот ограбил хозяина раньше срока")
	check(has(owner, second), "брейнрот пропал в паузу")
end)

scenario("игрок шлёпает вора-бота: брейнрот возвращается хозяину", function()
	setWeights({ steal = 1 })
	World.advance(60)
	readyToSteal()
	local thief
	local ok = waitFor(function()
		for _, bot in ipairs(BotService.list()) do
			if StealService.carryOf(bot) then
				thief = bot
				return true
			end
		end
		return false
	end, 200, readyToSteal)
	check(ok, "второй кражи не случилось")
	if not thief then
		return
	end
	local entry = StealService.carryOf(thief).entry
	check(not has(owner, entry), "брейнрот у хозяина, пока бот несёт")
	local slapper = watcher.Backpack:FindFirstChild(S.t("steal.slapper"))
	local rootBot = thief.Character.HumanoidRootPart
	local behind = rootBot.Position - Vector3.new(0, 0, 3)
	MoveGuard.teleported(watcher, behind)
	rootOf(watcher).CFrame = CFrame.lookAt(behind, rootBot.Position)
	local thieves = {}
	local listener = Actions.connect(function(player, kind)
		if player == watcher then
			table.insert(thieves, kind)
		end
	end)
	slapper.Activated:Fire()
	check(StealService.carryOf(thief) == nil, "бот не выронил брейнрота после шлепка")
	check(has(owner, entry), "хозяин не получил брейнрота обратно")
	check(thief.Character.Humanoid.WalkSpeed == StealService.NORMAL_SPEED, "бот остался медленным")
	check(owner:GetAttribute("BeingRobbed") == nil, "«грабят» не снято")
	check(table.find(thieves, "slapThief") ~= nil, "шлепок вора-бота не засчитан как slapThief")
	check(table.find(thieves, "slap") == nil, "шлепок по боту засчитан как slap (фарм заданий)")
	local velocity = rootBot.AssemblyLinearVelocity
	check(velocity ~= nil and math.abs(velocity.Y - 35) < 0.01, "бота не отбросило как игрока")
	check(math.abs(Vector3.new(velocity.X, 0, velocity.Z).Magnitude - StealService.SLAP_FORCE) < 0.01, "сила шлепка по боту не 70")
	setWeights({ wander = 1 })
	World.advance(30)
end)

scenario("бот отвечает шлепком один раз, с тем же кулдауном и силой", function()
	setWeights({ wander = 1 })
	World.advance(5)
	local bot = BotService.list()[1]
	local slapper = watcher.Backpack:FindFirstChild(S.t("steal.slapper"))
	local rootBot = bot.Character.HumanoidRootPart
	bot.Character.Humanoid.WalkSpeed = 0 -- стоит на месте: ответ один, а не «убежал из зоны»
	local at = rootBot.Position + Vector3.new(0, 0, 2)
	MoveGuard.teleported(watcher, at)
	rootOf(watcher).CFrame = CFrame.lookAt(at, rootBot.Position)
	local before = #knockbacksTo(watcher)
	slapper.Activated:Fire()
	World.advance(1.2)
	local got = knockbacksTo(watcher)
	check(#got == before + 1, "бот ответил " .. (#got - before) .. " раз, нужно 1")
	local velocity = got[#got] and got[#got][1]
	check(velocity ~= nil and math.abs(velocity.Y - 35) < 0.01 and math.abs(Vector3.new(velocity.X, 0, velocity.Z).Magnitude - 70) < 0.01, "ответный шлепок бота другой силы")
	World.advance(6)
	check(#knockbacksTo(watcher) == before + 1, "бот шлёпает дальше без причины: " .. (#knockbacksTo(watcher) - before))
	-- Кулдаун тот же, что у игрока: второй замах сразу после первого не проходит.
	World.advance(1)
	put(watcher, rootBot.Position + Vector3.new(0, 0, 2), rootBot.Position)
	rootBot.CFrame = CFrame.lookAt(rootBot.Position, rootOf(watcher).Position)
	local from = swings()
	StealService.botSlap(bot)
	StealService.botSlap(bot)
	check(swings() - from == 1, "два замаха бота подряд прошли без кулдауна: " .. (swings() - from))
	World.advance(StealService.SLAP_COOLDOWN - 0.05)
	StealService.botSlap(bot)
	check(swings() - from == 1, "замах бота раньше кулдауна 0,8 с прошёл")
	World.advance(0.06)
	StealService.botSlap(bot)
	check(swings() - from == 2, "замах бота после кулдауна не прошёл: " .. (swings() - from))
	from = swings()
	slapper.Activated:Fire()
	slapper.Activated:Fire()
	check(swings() - from == 1, "два замаха игрока подряд прошли без кулдауна: " .. (swings() - from))
	World.advance(StealService.SLAP_COOLDOWN - 0.05)
	slapper.Activated:Fire()
	check(swings() - from == 1, "замах игрока раньше кулдауна прошёл")
	World.advance(0.06)
	slapper.Activated:Fire()
	check(swings() - from == 2, "замах игрока после кулдауна не прошёл")
	bot.Character.Humanoid.WalkSpeed = StealService.NORMAL_SPEED
	-- Слышен: клиент играет звук на персонаже бота (в SlapFx пришла модель, а не игрок).
	World.advance(0.3)
	local sounds = 0
	for _, item in ipairs(rootBot:GetChildren()) do
		if item.ClassName == "Sound" then
			sounds += 1
		end
	end
	check(sounds >= 1, "на персонаже бота нет звука шлепка (клиент не получил модель бота)")
end)

scenario("защита при входе: нового игрока бот не трогает 90 с, потом может", function()
	DataService.get(owner).tutorial.step = 1 -- хозяин снова «в обучении»: единственная цель — Fresh
	local fresh = addHuman(4006, "Fresh")
	table.insert(extra, fresh)
	put(fresh, FAR + Vector3.new(0, 0, -60))
	-- Хозяин на паузе (только что ограблен), Watcher в обучении: единственная цель — Fresh.
	finishTutorial(fresh)
	local entry = give(fresh)
	local model = creatureModel(fresh, entry)
	setWeights({ steal = 1 })
	local early = false
	local startedAt = World.now()
	step(60, function()
		readyToSteal()
		early = early or model:GetAttribute("Hp") < model:GetAttribute("MaxHp")
	end)
	check(World.now() - startedAt < StealService.JOIN_SHIELD, "тест вышел за 90 с защиты")
	check(not early, "бот бил брейнрота под защитой при входе")
	check(has(fresh, entry), "брейнрот пропал под защитой")
	-- Защита кончилась: бот может ударить (кража требует ещё паузы владельца, поэтому смотрим на удары).
	local hit = waitFor(function()
		readyToSteal()
		return model:GetAttribute("Hp") < model:GetAttribute("MaxHp") or owner:GetAttribute("BeingRobbed") ~= nil or not has(fresh, entry)
	end, 150)
	check(hit, "после защиты бот так и не пошёл красть")
end)

scenario("хозяин закрыл базу: бот выставлен за забор и не крадёт", function()
	local fresh = extra[1]
	local plot = PlotService.getPlot(fresh)
	check(waitFor(function()
		for _, bot in ipairs(BotService.list()) do
			if bot.state == "steal" or bot.state == "flee" then
				return false
			end
		end
		return true
	end, 120), "боты не закончили прошлую кражу")
	local freshEntry = give(fresh, "bananito_ninjini")
	local freshModel = creatureModel(fresh, freshEntry)
	local button = plot.model.LockButton
	local prompt = button:FindFirstChild("LockPrompt") or button.LockPrompt
	place(fresh, button.Position + Vector3.new(0, 2, 3))
	World.prompt(prompt, fresh, 0)
	check(StealService.isLocked(fresh), "база не закрылась")
	local bot = BotService.list()[1]
	local inside = plot.cframe.Position + Vector3.new(0, 3, 0)
	bot.Character.HumanoidRootPart.CFrame = CFrame.new(inside)
	check(PlotService.isInside(plot, bot.Character.HumanoidRootPart.Position), "бот не внутри базы перед проверкой")
	World.advance(0.6)
	check(not PlotService.isInside(plot, bot.Character.HumanoidRootPart.Position), "бот остался внутри закрытой базы")
	-- Пока база закрыта, к брейнроту никто не идёт.
	setWeights({ steal = 1 })
	local touched = false
	step(30, function()
		readyToSteal()
		touched = touched or freshModel:GetAttribute("Hp") < freshModel:GetAttribute("MaxHp") or not has(fresh, freshEntry)
	end)
	check(StealService.isLocked(fresh), "база открылась раньше 30 с")
	check(not touched, "бот пошёл красть из закрытой базы")
	for _, item in ipairs(extra) do
		World.removePlayer(item)
	end
	extra = {}
	World.advance(5)
end)

scenario("дикие: бот ловит обычных, редких (Skibidi) оставляет игрокам", function()
	setWeights({ collect = 1 })
	local oldMax = WildService.MAX_ALIVE
	WildService.MAX_ALIVE = 0 -- сами дикие не появляются
	for _, item in ipairs(workspace.WildBrainrots:GetChildren()) do
		item:Destroy()
	end
	local before = 0
	for _, bot in ipairs(BotService.list()) do
		before += bot.collected
	end
	local original = WildService.Weights
	WildService.Weights = { skibidi = 1 }
	WildService.forceSpawn()
	local wilds = workspace.WildBrainrots
	check(#wilds:GetChildren() == 1, "дикий не появился")
	local rare = wilds:GetChildren()[1]
	step(60)
	check(rare.Parent == wilds, "бот поймал редкого дикого (ранг 5 и выше остаётся игрокам)")
	WildService.Weights = { normie = 1 }
	WildService.forceSpawn()
	local common
	for _, item in ipairs(wilds:GetChildren()) do
		if item ~= rare then
			common = item
		end
	end
	check(waitFor(function()
		return common.Parent == nil
	end, 60), "бот не поймал обычного дикого")
	WildService.Weights = original
	WildService.MAX_ALIVE = oldMax
	local after = 0
	for _, bot in ipairs(BotService.list()) do
		after += bot.collected
	end
	check(after == before + 1, "поймано ботами " .. (after - before) .. ", нужно 1")
	check(rare.Parent == wilds, "редкий дикий пропал")
end)

scenario("крафт: бот идёт к станку свободной базы и «собирает»", function()
	setWeights({ craft = 1 })
	local before = 0
	for _, bot in ipairs(BotService.list()) do
		before += bot.crafted
	end
	local seenAtMachine = false
	step(60, function()
		for _, bot in ipairs(BotService.list()) do
			if bot.state == "craft" and bot.job and bot.job.workUntil then
				local spot = PlotService.craftSpot(bot.job.plot)
				seenAtMachine = seenAtMachine or (Vector3.new(spot.X, 0, spot.Z) - Vector3.new(bot.Character.HumanoidRootPart.Position.X, 0, bot.Character.HumanoidRootPart.Position.Z)).Magnitude <= 3.5
				check(bot.job.plot.owner == nil, "бот «крафтит» на чужой занятой базе")
			end
		end
	end)
	local after = 0
	for _, bot in ipairs(BotService.list()) do
		after += bot.crafted
	end
	check(after > before, "никто из ботов не скрафтил")
	check(seenAtMachine, "бот не стоял у станка")
	setWeights({ wander = 1 })
end)

scenario("нет в лидерах, DataStore и счётчиках", function()
	World.advance(130) -- автосохранение и запись таблиц лидеров
	check(#storeKeys > 0, "в DataStore не писали и не читали вообще (проверка пуста)")
	local real = { ["4001"] = true, ["4002"] = true, ["4003"] = true, ["4004"] = true, ["4005"] = true, ["4006"] = true, ["4020"] = true }
	for _, key in ipairs(storeKeys) do
		local digits = string.match(key, "(%-?%d+)")
		check(digits ~= nil and real[digits] == true and not string.find(key, "-", 1, true) and not string.find(key, "Bot", 1, true), "в DataStore ключ не человека: " .. key)
	end
	for _, bot in ipairs(BotService.list()) do
		check(DataService.get(bot) == nil, "у бота есть профиль")
		check(rawget(bot, "leaderstats") == nil and bot.Character:FindFirstChild("leaderstats") == nil, "у бота есть leaderstats")
	end
	check(joined == 7, "PlayerAdded сработал " .. joined .. " раз при 7 входах людей (боты не входили)")
	check(#Players:GetPlayers() == 2, "в Players не двое людей: " .. #Players:GetPlayers())
end)

scenario("пришли ещё люди (4 игрока) посреди кражи: вор не уходит, пока не кончил", function()
	finishTutorial(owner)
	setWeights({ wander = 1 })
	World.advance(BotService.OWNER_COOLDOWN) -- пауза хозяина после прошлой кражи кончилась
	give(owner)
	setWeights({ steal = 1 })
	readyToSteal()
	local carrier
	check(waitFor(function()
		for _, bot in ipairs(BotService.list()) do
			if StealService.carryOf(bot) then
				carrier = bot
				return true
			end
		end
		return false
	end, 200, readyToSteal), "кража не началась: " .. stateReport())
	if not carrier then
		return
	end
	local escapedBefore = carrier.escaped
	-- Вор первым в списке: если бы уходящего выбирали без оглядки на кражу, ушёл бы именно он.
	table.remove(BotService.list(), table.find(BotService.list(), carrier))
	table.insert(BotService.list(), 1, carrier)
	local joiners = { addHuman(4010, "Join1"), addHuman(4011, "Join2") }
	for index, player in ipairs(joiners) do
		put(player, FAR + Vector3.new(index * 20, 0, 90))
	end
	check(#Players:GetPlayers() == 4, "игроков не 4")
	local leftEarly = nil
	local carried = waitFor(function()
		if StealService.carryOf(carrier) == nil then
			leftEarly = carrier.removed == true -- кража кончилась, потому что бот ушёл, а не потому что добежал
			return true
		end
		return false
	end, 90)
	check(carried, "вор-бот не закончил кражу за 90 с")
	check(leftEarly == false, "бот ушёл посреди кражи")
	check(carrier.escaped == escapedBefore + 1, "вор-бот не добежал: escaped = " .. tostring(carrier.escaped))
	check(waitFor(function()
		return botCount() == 0
	end, 120), "при 4 игроках после кражи остались боты: " .. botCount())
	for _, player in ipairs(joiners) do
		World.removePlayer(player)
	end
	check(waitFor(function()
		return botCount() == 3
	end, 30), "после ухода людей ботов не 3: " .. botCount())
end)

scenario("вышел последний игрок посреди кражи: ни ошибок, ни ботов", function()
	World.removePlayer(watcher)
	World.advance(5)
	finishTutorial(owner)
	owner:SetAttribute("BeingRobbed", nil)
	setWeights({ wander = 1 })
	World.advance(BotService.OWNER_COOLDOWN) -- пауза хозяина после кражи кончилась
	give(owner)
	setWeights({ steal = 1 })
	readyToSteal()
	local carrier
	local ok = waitFor(function()
		for _, bot in ipairs(BotService.list()) do
			if StealService.carryOf(bot) then
				carrier = bot
				return true
			end
		end
		return false
	end, 150, readyToSteal)
	if not ok then
		local data = DataService.get(owner)
		print("DEBUG tutorial", data.tutorial.step, "locked", tostring(StealService.isLocked(owner)), "creatures", #data.creatures)
		for _, item in ipairs(data.creatures) do
			print("DEBUG item", item.id, tostring(item.source), tostring(item.uid))
		end
		for _, model in ipairs(PlotService.getPlot(owner).model.Creatures:GetChildren()) do
			print("DEBUG model", tostring(model:GetAttribute("Uid")), tostring(model:GetAttribute("Hp")), tostring(model:GetAttribute("StunnedUntil")))
		end
	end
	check(ok, "кража перед выходом не началась: " .. stateReport())
	local entry = carrier and StealService.carryOf(carrier).entry
	World.removePlayer(owner)
	World.advance(1)
	check(botCount() == 0, "после выхода последнего игрока ботов " .. botCount())
	check(#workspace.Bots:GetChildren() == 0, "модели ботов остались")
	if carrier then
		check(StealService.carryOf(carrier) == nil, "кража не отменена")
	end
	check(entry ~= nil, "нет украденного для проверки")
	-- Хозяин вышел, пока бот нёс: брейнрот в итоговом сохранении ровно один раз, потеря от воров не записана.
	if entry then
		local copies, lost = savedState(owner, entry.uid)
		check(copies == 1, "после выхода хозяина в сохранении записей брейнрота " .. copies .. " (нужна 1)")
		check(lost == 0, "после выхода хозяина в сохранении записана потеря от воров: " .. lost)
	end
	World.advance(10)
	check(botCount() == 0, "боты вернулись на пустой сервер")
end)

scenario("зашёл новый игрок: боты снова появляются", function()
	local warned = {}
	local realWarn, realSlapper = warn, StealService.newSlapper
	warn = function(...)
		table.insert(warned, table.concat({ ... }, " "))
	end
	StealService.newSlapper = function()
		return nil
	end
	local back = addHuman(4007, "Back")
	table.insert(extra, back)
	check(waitFor(function()
		return botCount() == 3
	end, 15), "после входа ботов " .. botCount())
	warn, StealService.newSlapper = realWarn, realSlapper
	local noSlapper = 0
	for _, text in ipairs(warned) do
		if string.find(text, "[Bots] no Slapper", 1, true) then
			noSlapper += 1
		end
	end
	check(noSlapper >= 3, "бот без шлепалки не оставил предупреждения (warn): " .. noSlapper .. " из 3")
end)

scenario("ботов выключили в конфиге: ни одного", function()
	check(Config.Enabled == true, "в этом тесте боты должны быть включены")
	check(BotService.wanted(0) == 0 and BotService.wanted(4) == 0 and BotService.wanted(9) == 0, "ботов при 0 и ≥4 игроков")
	check(BotService.wanted(1) == 3 and BotService.wanted(2) == 3 and BotService.wanted(3) == 2, "число ботов по игрокам не 3/3/2")
	Config.Enabled = false
	check(BotService.wanted(1) == 0, "при Enabled = false ботов хотят")
	Config.Enabled = true
end)

check(#World.errors == 0, "ошибки в коде: " .. #World.errors)
check(BotService.failures == 0, "ошибок в поведении ботов: " .. BotService.failures .. " " .. tostring(BotService.lastError))

if failures == 0 then
	print("✅ Боты: сценариев " .. scenarios .. ", ошибок нет")
else
	print("❌ Боты: провалено проверок " .. failures)
	error("tests failed")
end
