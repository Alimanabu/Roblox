-- Возвращение игроков на настоящих сервере и клиенте: серия дневных наград, подарки за время в игре,
-- промокоды, напоминание при входе, таймер до следующей награды, старые сохранения без новых полей.
-- Запросы идут прямо на сервер, как у читера: клиент никому не помогает.

local failures = 0
local scenarios = 0
local function check(cond, msg)
	if not cond then
		failures += 1
		print("❌ " .. msg)
	end
end

World.studio = false

local VIEWER, STREAKER, GIFTER, CODER, OLD_PLAIN, OLD_PARTIAL, FRESH, IDLE = 7001, 7002, 7003, 7004, 7005, 7006, 7007, 7008

-- Игроки раньше модулей: словарь узнаёт язык у игрока при загрузке.
local viewer = World.addPlayer(VIEWER, "Viewer")

local S = shared_require("Strings")
local Daily = shared_require("Config/Daily")
local Codes = shared_require("Config/Codes")
local Format = shared_require("Util/Format")

World.startServer()
World.startClient()
World.advance(5)

local DataService = shared_require("Services/DataService")
local Remotes = shared_require("Remotes")
local gui = viewer.PlayerGui

local function fromPlayer(remote, player, ...)
	remote.OnServerEvent:Fire(player, ...)
end

local function scenario(name, body)
	scenarios += 1
	print("  ✅ " .. scenarios .. ". " .. name)
	body()
end

-- Рассылку всем не считаем: ивент может начаться сразу после ответа и заслонить его.
local function notifies(player, fromIndex)
	local out = {}
	for index = (fromIndex or 0) + 1, #World.sent do
		local sent = World.sent[index]
		if sent.remote == "Notify" and sent.player == player and not sent.everyone then
			table.insert(out, S.text(sent.args[1]))
		end
	end
	return out
end

local function lastNotify(player)
	local list = notifies(player)
	return list[#list] or ""
end

local function text(key, params)
	return S.text(S.m(key, params))
end

local function hasText(part)
	for _, item in ipairs(gui:GetDescendants()) do
		if type(item.Text) == "string" and string.find(item.Text, part, 1, true) then
			return true
		end
	end
	return false
end

-- Часть строки до подстановки: проверка не зависит от языка окна.
local function prefixOf(key, param)
	local marker = "@@@"
	return (S.t(key, { [param] = marker }):gsub(marker .. ".*", ""))
end

local function closePanel()
	local close = World.find(gui, "✕")
	if close then
		World.click(close)
		World.advance(0.1)
	end
end

local function openRewards()
	closePanel()
	local button = World.find(gui, S.t("hud.rewards"))
	assert(button, "нет кнопки наград")
	World.click(button)
	World.advance(0.3)
end

local function join(userId, name)
	local player = World.addPlayer(userId, name)
	World.advance(1)
	return player
end

local function leave(player)
	World.removePlayer(player)
	World.advance(5)
end

local MIN = Daily.MIN_COINS_PER_MINUTE -- у нового игрока дохода нет: «минута дохода» стоит минимум
local DAY = 86400
local REMIND = 8

---------------------------------------------------------------------------
-- Напоминание при входе и окно наград (игрок с клиентом)
---------------------------------------------------------------------------
scenario("при входе: напоминание о награде дня 1 через несколько секунд, не сразу", function()
	local player = World.addPlayer(FRESH, "Fresh")
	World.advance(1)
	check(DataService.get(player) ~= nil, "профиль не загрузился")
	local ready = text("quest.daily_ready", { day = 1, total = #Daily.Rewards })
	for _, line in ipairs(notifies(player)) do
		check(line ~= ready, "напоминание пришло сразу, клиент ещё не слушал")
	end
	World.advance(REMIND + 1)
	local found = false
	for _, line in ipairs(notifies(player)) do
		found = found or line == ready
	end
	check(found, "нет напоминания о награде дня 1")
	leave(player)
end)

scenario("окно наград до получения: кнопка «получить день 1», подарки считаются за сегодня", function()
	openRewards()
	check(hasText(S.t("rewards.claim_day", { day = 1 })), "нет кнопки получения награды дня 1")
	check(hasText(prefixOf("rewards.gifts", "minutes")), "заголовок подарков за время не найден")
	check(not hasText(prefixOf("rewards.come_back", "time")), "таймер следующей награды показан до получения")
end)

scenario("после получения: на кнопке таймер до следующей награды, не «приходи завтра» без времени", function()
	local data = DataService.get(viewer)
	local before = data.coins
	fromPlayer(Remotes.ClaimDaily, viewer)
	World.advance(0.5)
	check(data.coins == before + Daily.Rewards[1].coinsMinutes * MIN, "награда дня 1: " .. (data.coins - before))
	openRewards()
	check(hasText(prefixOf("rewards.come_back", "time")), "нет таймера до следующей награды")
	local secondsLeft = (Daily.today() + 1) * DAY - os.time()
	check(hasText(Format.time(secondsLeft)) or hasText(Format.time(secondsLeft + 1)), "время до сброса неверное: " .. Format.time(secondsLeft))
	closePanel()
end)

---------------------------------------------------------------------------
-- Серия дней
---------------------------------------------------------------------------
local streaker = join(STREAKER, "Streaker")
local streakData = DataService.get(streaker)

local function claimToday(player)
	local data = DataService.get(player)
	local coins = data.coins
	fromPlayer(Remotes.ClaimDaily, player)
	return data.coins - coins
end

-- Следующий день: игрок уходит, проходят сутки, возвращается. Профиль читается заново из сохранения.
local function nextDay(player, userId, name, days)
	leave(player)
	World.skip((days or 1) * DAY)
	World.advance(1)
	return join(userId, name)
end

scenario("серия: день 1, второй вызов в тот же день ничего не даёт", function()
	check(claimToday(streaker) == Daily.Rewards[1].coinsMinutes * MIN, "день 1: не те монеты")
	check(streakData.daily.streak == 1, "серия после дня 1: " .. streakData.daily.streak)
	check(claimToday(streaker) == 0, "повторная награда в тот же день")
	check(streakData.daily.streak == 1, "серия выросла в тот же день: " .. streakData.daily.streak)
	check(lastNotify(streaker) == text("quest.daily_claimed"), "нет понятного ответа на повтор: " .. lastNotify(streaker))
end)

scenario("серия: день 2 и день 3 подряд растят серию, награды по таблице", function()
	streaker = nextDay(streaker, STREAKER, "Streaker")
	streakData = DataService.get(streaker)
	check(streakData.daily.streak == 1, "серия потеряна при выходе: " .. streakData.daily.streak)
	check(claimToday(streaker) == Daily.Rewards[2].coinsMinutes * MIN, "день 2: не те монеты")
	check(streakData.daily.streak == 2, "серия после дня 2: " .. streakData.daily.streak)
	streaker = nextDay(streaker, STREAKER, "Streaker")
	streakData = DataService.get(streaker)
	local luckBefore = streakData.boosts.luckUntil
	check(claimToday(streaker) == 0, "день 3 дал монеты вместо удачи")
	check(streakData.daily.streak == 3, "серия после дня 3: " .. streakData.daily.streak)
	check(streakData.boosts.luckUntil >= os.time() + Daily.Rewards[3].luckMinutes * 60 - 5 and streakData.boosts.luckUntil > luckBefore, "день 3: нет удачи")
end)

scenario("серия: пропущенный день сбрасывает на день 1", function()
	streaker = nextDay(streaker, STREAKER, "Streaker", 2)
	streakData = DataService.get(streaker)
	check(streakData.daily.streak == 3, "серия изменилась до получения: " .. streakData.daily.streak)
	local before = streakData.coins
	fromPlayer(Remotes.ClaimDaily, streaker)
	check(streakData.daily.streak == 1, "серия не сброшена после пропуска: " .. streakData.daily.streak)
	check(streakData.coins - before == Daily.Rewards[1].coinsMinutes * MIN, "после пропуска награда не дня 1")
	local dayOne = (text("quest.daily_reward", { day = 1, reward = "@@@" }):gsub("@@@.*", ""))
	check(lastNotify(streaker):find(dayOne, 1, true) == 1, "ответ не называет день 1: " .. lastNotify(streaker))
end)

scenario("серия: 7 дней подряд, день 7 — большая награда, день 8 снова день 1", function()
	for day = 2, 7 do
		streaker = nextDay(streaker, STREAKER, "Streaker")
		streakData = DataService.get(streaker)
		local gained = claimToday(streaker)
		check(streakData.daily.streak == day, "серия на дне " .. day .. ": " .. streakData.daily.streak)
		if Daily.Rewards[day].coinsMinutes then
			check(gained == Daily.Rewards[day].coinsMinutes * MIN, "день " .. day .. ": не те монеты " .. gained)
		end
	end
	check(Daily.Rewards[7].mega == true and streakData.boosts.luckUntil > os.time(), "день 7 без удачи")
	streaker = nextDay(streaker, STREAKER, "Streaker")
	streakData = DataService.get(streaker)
	claimToday(streaker)
	check(streakData.daily.streak == 1, "после дня 7 серия не началась заново: " .. streakData.daily.streak)
end)

scenario("напоминание: в тот же день после награды не приходит, на следующий день называет день серии", function()
	local mark = #World.sent
	streaker = nextDay(streaker, STREAKER, "Streaker", 0)
	World.advance(REMIND + 1)
	local ready = text("quest.daily_ready", { day = 2, total = #Daily.Rewards })
	for _, line in ipairs(notifies(streaker, mark)) do
		check(line ~= ready, "напоминание после получения награды")
	end
	mark = #World.sent
	streaker = nextDay(streaker, STREAKER, "Streaker")
	World.advance(REMIND + 1)
	local found = false
	for _, line in ipairs(notifies(streaker, mark)) do
		found = found or line == ready
	end
	check(found, "нет напоминания о награде дня 2 на следующий день")
end)

---------------------------------------------------------------------------
-- Подарки за время в игре
---------------------------------------------------------------------------
local gifter = join(GIFTER, "Gifter")
local giftData = DataService.get(gifter)
local GIFT1, GIFT2 = Daily.Gifts[1], Daily.Gifts[2]

local function claimGift(player, index)
	local data = DataService.get(player)
	local coins = data.coins
	fromPlayer(Remotes.ClaimGift, player, index)
	return data.coins - coins
end

scenario("подарок за время: до порога отказ, после порога один раз", function()
	World.advance(GIFT1.minutes * 60 - 30)
	check(claimGift(gifter, 1) == 0, "подарок выдан до порога")
	check(lastNotify(gifter) == text("gift.not_ready"), "нет понятного ответа до порога: " .. lastNotify(gifter))
	check(giftData.playtime.claimed["1"] == nil, "подарок помечен полученным до порога")
	World.advance(40)
	check(claimGift(gifter, 1) == GIFT1.reward.coinsMinutes * MIN, "подарок после порога не тот")
	check(giftData.playtime.claimed["1"] == true, "подарок не помечен полученным")
	check(claimGift(gifter, 1) == 0, "подарок выдан второй раз за порог")
	check(claimGift(gifter, 99) == 0 and claimGift(gifter, "x") == 0, "подарок с чужим номером")
end)

scenario("подарок: выход и возврат в тот же день не обнуляют время и не отдают подарок снова", function()
	local secondsBefore = giftData.playtime.seconds
	check(secondsBefore >= GIFT1.minutes * 60, "время за сегодня не накопилось: " .. secondsBefore)
	leave(gifter)
	gifter = join(GIFTER, "Gifter")
	giftData = DataService.get(gifter)
	check(giftData.playtime.day == Daily.today(), "день игры потерян при перезаходе")
	check(giftData.playtime.seconds >= secondsBefore, "время за сегодня потеряно при перезаходе: " .. giftData.playtime.seconds)
	check(giftData.playtime.claimed["1"] == true, "получение подарка потеряно при перезаходе")
	check(claimGift(gifter, 1) == 0, "перезаход отдал подарок второй раз")
end)

scenario("подарок: время до выхода засчитывается, даже если игрок ничего не нажимал", function()
	local idle = join(IDLE, "Idle")
	World.advance(280)
	leave(idle)
	idle = join(IDLE, "Idle")
	local seconds = DataService.get(idle).playtime.seconds
	check(seconds >= 270 and seconds <= 300, "время до выхода потеряно или раздуто: " .. seconds)
	leave(idle)
end)

scenario("подарок: время двух заходов за день складывается", function()
	check(claimGift(gifter, 2) == 0, "второй подарок выдан раньше порога")
	check(giftData.boosts.luckUntil < os.time(), "удача выдана раньше порога")
	local need = GIFT2.minutes * 60 - giftData.playtime.seconds
	World.advance(need + 5)
	claimGift(gifter, 2)
	check(giftData.playtime.claimed["2"] == true, "второй подарок не выдан после накопленного времени")
	check(giftData.boosts.luckUntil > os.time(), "второй подарок без удачи")
end)

scenario("подарок: на следующий день время и подарки начинаются заново", function()
	leave(gifter)
	World.skip(DAY)
	gifter = join(GIFTER, "Gifter")
	giftData = DataService.get(gifter)
	check(giftData.playtime.seconds < 60, "время нового дня не с нуля: " .. giftData.playtime.seconds)
	World.advance(GIFT1.minutes * 60 + 5)
	check(claimGift(gifter, 1) == GIFT1.reward.coinsMinutes * MIN, "на новый день подарок не вернулся")
	check(giftData.playtime.day == Daily.today(), "день игры не обновился")
end)

scenario("подарок: сохранение держит номера строками (DataStore не принимает дырявый массив)", function()
	local store = World.services.DataStoreService:GetDataStore("BrainrotFactory_v1")
	DataService.save(gifter)
	local saved = store.data["player_" .. GIFTER]
	check(saved and saved.playtime and saved.playtime.claimed["1"] == true, "полученный подарок не записан в сохранение")
	for key in pairs(saved.playtime.claimed) do
		check(type(key) == "string", "номер подарка в сохранении не строка: " .. type(key))
	end
end)

---------------------------------------------------------------------------
-- Промокоды
---------------------------------------------------------------------------
local coder = join(CODER, "Coder")
local codeData = DataService.get(coder)

-- Ответ сервера на код: первое сообщение сразу после запроса (позже могут прийти чужие, про защиту базы и т.п.).
local codeReply = ""
local function redeem(player, code)
	local data = DataService.get(player)
	local coins = data.coins
	local mark = #World.sent
	fromPlayer(Remotes.RedeemCode, player, code)
	codeReply = notifies(player, mark)[1] or ""
	World.advance(3) -- пауза между попытками
	return data.coins - coins
end

scenario("код: неверный даёт понятное сообщение и ничего не выдаёт", function()
	check(redeem(coder, "NOPE123") == 0, "неверный код выдал награду")
	check(codeReply == text("code.invalid"), "сообщение о неверном коде: " .. codeReply)
	check(next(codeData.codes) == nil, "неверный код записан как использованный")
	check(redeem(coder, "") == 0 and codeReply == text("code.invalid"), "пустой код")
end)

scenario("код: верный (любой регистр, пробелы) выдаётся один раз на игрока", function()
	check(redeem(coder, "  brainrot ") == Codes.BRAINROT.coinsMinutes * MIN, "награда за код не та")
	check(codeData.codes.BRAINROT == true, "код не записан как использованный")
	check(redeem(coder, "BRAINROT") == 0, "код принят второй раз")
	check(codeReply == text("code.used"), "сообщение о повторе: " .. codeReply)
end)

scenario("код: новые коды для роликов и Discord работают, каждый один раз", function()
	for _, code in ipairs({ "DISCORD", "YOUTUBE" }) do
		check(Codes[code] ~= nil, "нет кода " .. code)
		local reward = Codes[code]
		check(redeem(coder, code) == reward.coinsMinutes * MIN, "награда за код " .. code .. " не та")
		check(redeem(coder, code) == 0, "код " .. code .. " принят второй раз")
	end
end)

scenario("код: просроченный не принимается", function()
	Codes.OLDCODE = { coinsMinutes = 1, expires = os.time() - 1 }
	check(redeem(coder, "OLDCODE") == 0, "просроченный код принят")
	check(codeReply == text("code.invalid"), "сообщение о просроченном коде: " .. codeReply)
	Codes.OLDCODE = nil
end)

scenario("код: использованный остаётся использованным после перезахода, другой игрок свой код вводит", function()
	leave(coder)
	coder = join(CODER, "Coder")
	codeData = DataService.get(coder)
	check(redeem(coder, "BRAINROT") == 0, "после перезахода код принят снова")
	check(codeReply == text("code.used"), "сообщение о повторе после перезахода: " .. codeReply)
	local other = join(OLD_PLAIN + 100, "Other")
	check(redeem(other, "BRAINROT") == Codes.BRAINROT.coinsMinutes * MIN, "другому игроку код не выдан")
	leave(other)
end)

---------------------------------------------------------------------------
-- Старые сохранения без новых полей
---------------------------------------------------------------------------
local store = World.services.DataStoreService:GetDataStore("BrainrotFactory_v1")

scenario("старое сохранение без playtime: загружается без ошибок, серия и коды целы", function()
	store:SetAsync("player_" .. OLD_PLAIN, {
		coins = 777,
		rebirths = 0,
		nextUid = 1,
		creatures = {},
		daily = { streak = 3, lastClaimDay = Daily.today() - 1 },
		codes = { BRAINROT = true },
	})
	local player = join(OLD_PLAIN, "OldPlain")
	local data = DataService.get(player)
	check(data ~= nil and data.coins == 777, "старое сохранение не загрузилось")
	check(type(data.playtime) == "table" and data.playtime.seconds ~= nil and type(data.playtime.claimed) == "table", "нет полей времени в игре")
	check(data.daily.streak == 3 and data.codes.BRAINROT == true, "серия или коды потеряны")
	check(redeem(player, "BRAINROT") == 0, "старый использованный код принят снова")
	World.advance(GIFT1.minutes * 60)
	check(claimGift(player, 1) == GIFT1.reward.coinsMinutes * MIN, "подарок за время не выдан старому игроку")
	check(claimToday(player) == Daily.Rewards[4].coinsMinutes * MIN, "серия старого игрока не продолжилась (день 4)")
	check(data.daily.streak == 4, "серия после дня 4: " .. data.daily.streak)
	leave(player)
end)

scenario("сохранение с неполным playtime (нет списка полученных): дополняется, время продолжается", function()
	store:SetAsync("player_" .. OLD_PARTIAL, {
		coins = 10,
		nextUid = 1,
		creatures = {},
		playtime = { day = Daily.today(), seconds = GIFT1.minutes * 60 - 60 },
	})
	local player = join(OLD_PARTIAL, "OldPartial")
	local data = DataService.get(player)
	check(type(data.playtime.claimed) == "table", "список полученных не добавлен")
	check(claimGift(player, 1) == 0, "подарок выдан раньше порога")
	World.advance(65)
	check(claimGift(player, 1) == GIFT1.reward.coinsMinutes * MIN, "накопленное до выхода время не засчитано")
	leave(player)
end)

---------------------------------------------------------------------------
-- Цель сессии под уровнем: что делать дальше и зачем вернуться завтра.
-- Строку считает клиент (Hud.goal) из того же состояния, что сервер шлёт игроку.
---------------------------------------------------------------------------
local Hud = shared_require("client/Ui/Hud")
local ClientState = shared_require("client/State")
local Actions = shared_require("Services/Actions")
local GOALER = 7009

local function stateOf(player)
	DataService.sendNow(player)
	for index = #World.sent, 1, -1 do
		local sent = World.sent[index]
		if sent.remote == "State" and sent.player == player then
			return sent.args[1]
		end
	end
	error("сервер не прислал состояние")
end

local function goalOf(player)
	return Hud.goal(stateOf(player))
end

local TOTAL = #Daily.Rewards

local function goalButton()
	for _, item in ipairs(gui:GetDescendants()) do
		if item.Name == "Goal" then
			return item
		end
	end
	return nil
end

scenario("цель на экране: строка видна, совпадает с расчётом, нажатие открывает награды", function()
	closePanel()
	World.advance(1.2)
	local button = goalButton()
	check(button ~= nil, "нет строки цели на экране")
	if not button then
		return
	end
	check(button.Visible == true, "строка цели скрыта")
	check(button.Text == Hud.goal(ClientState.current), "на экране не та цель: " .. tostring(button.Text))
	check(not string.find(button.Text, "{", 1, true), "незаполненный параметр в цели: " .. button.Text)
	World.click(button)
	World.advance(0.3)
	check(hasText(S.t("rewards.hint")), "нажатие на цель не открыло награды")
	closePanel()
end)

local goaler = join(GOALER, "Goaler")
local goalData = DataService.get(goaler)

-- Первое невыполненное задание игрока (по порядку в списке) и его описание.
local function openQuest(data)
	for index, quest in ipairs(data.quests.list) do
		if not quest.claimed then
			return index, quest, Daily.QuestById[quest.id]
		end
	end
	return nil
end

local function questGoal(def, progress)
	return S.t("hud.goal_quest", { quest = text(def.textKey), progress = progress, target = def.target })
end

scenario("цель: новичок видит награду дня 1; после получения она не предлагается и второй раз не выдаётся", function()
	check(goalOf(goaler) == S.t("hud.goal_daily", { day = 1, total = TOTAL }), "нет цели «награда дня 1»: " .. goalOf(goaler))
	check(claimToday(goaler) > 0, "награда дня 1 не выдана")
	local after = goalOf(goaler)
	check(after ~= S.t("hud.goal_daily", { day = 1, total = TOTAL }), "после получения цель всё ещё «награда дня»")
	check(claimToday(goaler) == 0, "награда дня выдана дважды за день")
	check(goalOf(goaler) == after, "повторный запрос награды поменял цель")
end)

scenario("цель: ближайшее задание с прогрессом; прогресс в цели переживает выход и возврат в тот же день", function()
	local index, quest, def = openQuest(goalData)
	check(index ~= nil and def ~= nil, "у игрока нет заданий")
	check(goalOf(goaler) == questGoal(def, 0), "цель не первое задание 0/" .. def.target .. ": " .. goalOf(goaler))
	local step = math.max(1, def.target - 1)
	Actions.fire(goaler, def.kind, step)
	check(quest.progress == step, "прогресс задания не вырос: " .. quest.progress)
	check(goalOf(goaler) == questGoal(def, step), "цель не показывает прогресс " .. step .. ": " .. goalOf(goaler))
	leave(goaler)
	goaler = join(GOALER, "Goaler")
	goalData = DataService.get(goaler)
	check(goalData.quests.list[index].progress == step, "прогресс задания потерян после выхода")
	check(goalOf(goaler) == questGoal(def, step), "после возврата цель не та: " .. goalOf(goaler))
end)

scenario("цель: выполненное задание просит забрать награду; после получения цель — следующее задание", function()
	local index, quest, def = openQuest(goalData)
	Actions.fire(goaler, def.kind, def.target)
	check(goalOf(goaler) == S.t("hud.goal_quest_done"), "нет цели «забери награду за задание»: " .. goalOf(goaler))
	fromPlayer(Remotes.ClaimQuest, goaler, index)
	check(quest.claimed, "награда за задание не выдана")
	-- Следующее — ближайшее к завершению из оставшихся (одно действие может двигать два задания).
	local best, bestShare
	for _, other in ipairs(goalData.quests.list) do
		local otherDef = Daily.QuestById[other.id]
		local share = other.progress / otherDef.target
		if not other.claimed and (not best or share > bestShare) then
			best, bestShare = other, share
		end
	end
	check(best ~= nil and best ~= quest, "полученное задание снова в цели")
	check(goalOf(goaler) == questGoal(Daily.QuestById[best.id], best.progress), "цель не следующее задание: " .. goalOf(goaler))
end)

scenario("цель: подарок за время готов → забрать; всё сделано → «вернись через …: день серии 2/7»", function()
	-- Отсчёт подарков проверен выше; здесь ставим 2 часа игры, чтобы открылись все.
	goalData.playtime.seconds = Daily.Gifts[#Daily.Gifts].minutes * 60 + 60
	check(goalOf(goaler) == S.t("hud.goal_gift"), "нет цели «забери подарок»: " .. goalOf(goaler))
	for index = 1, #Daily.Gifts do
		claimGift(goaler, index)
		check(goalData.playtime.claimed[tostring(index)] == true, "подарок " .. index .. " не выдан")
	end
	check(goalOf(goaler) ~= S.t("hud.goal_gift"), "после всех подарков цель всё ещё «подарок»")
	local index, _, def = openQuest(goalData)
	while index do
		Actions.fire(goaler, def.kind, def.target)
		fromPlayer(Remotes.ClaimQuest, goaler, index)
		index, _, def = openQuest(goalData)
	end
	local state = stateOf(goaler)
	local now = workspace:GetServerTimeNow()
	local left = (Daily.today() + 1) * DAY - now
	check(Hud.goal(state, now) == S.t("hud.goal_tomorrow", { time = Format.time(left), day = 2, total = TOTAL }),
		"нет цели «вернись завтра, день 2»: " .. Hud.goal(state, now))
	-- Таймер идёт без нового состояния от сервера.
	check(Hud.goal(state, now + 120) == S.t("hud.goal_tomorrow", { time = Format.time(left - 120), day = 2, total = TOTAL }),
		"таймер цели стоит без нового состояния")
end)

scenario("цель: назавтра «награда дня 2», после пропуска дня снова «день 1»", function()
	goaler = nextDay(goaler, GOALER, "Goaler")
	goalData = DataService.get(goaler)
	check(goalOf(goaler) == S.t("hud.goal_daily", { day = 2, total = TOTAL }), "назавтра нет цели «день 2»: " .. goalOf(goaler))
	check(claimToday(goaler) > 0 and goalData.daily.streak == 2, "день 2 не засчитан: серия " .. goalData.daily.streak)
	goaler = nextDay(goaler, GOALER, "Goaler", 2)
	goalData = DataService.get(goaler)
	check(goalOf(goaler) == S.t("hud.goal_daily", { day = 1, total = TOTAL }), "после пропуска дня цель не «день 1»: " .. goalOf(goaler))
	check(claimToday(goaler) > 0 and goalData.daily.streak == 1, "после пропуска дня серия не 1: " .. goalData.daily.streak)
	check(claimToday(goaler) == 0, "после пропуска дня награда выдана дважды")
	leave(goaler)
end)

scenario("цель: после дня 6 зовёт за мега-наградой дня 7, после дня 7 — снова день 1", function()
	local state = stateOf(viewer)
	state.rewards.canClaim = false
	for _, quest in ipairs(state.rewards.quests) do
		quest.claimed = true
	end
	local now = workspace:GetServerTimeNow()
	-- Задания сделаны, остался последний подарок: цель — сколько минут до него.
	local gifts = state.playtime.gifts
	for index, gift in ipairs(gifts) do
		gift.claimed = index < #gifts
	end
	state.playtime.start = now - 10 * 60
	local wait = gifts[#gifts].minutes - 10
	check(Hud.goal(state, now) == S.t("hud.goal_next_gift", { minutes = wait }), "нет цели «следующий подарок через " .. wait .. " мин»: " .. Hud.goal(state, now))
	gifts[#gifts].claimed = true
	local time = Format.time((Daily.today() + 1) * DAY - now)
	state.rewards.streak = TOTAL - 1
	check(Hud.goal(state, now) == S.t("hud.goal_mega", { time = time, day = TOTAL }), "нет цели «мега-награда»: " .. Hud.goal(state, now))
	state.rewards.streak = TOTAL
	check(Hud.goal(state, now) == S.t("hud.goal_tomorrow", { time = time, day = 1, total = TOTAL }), "после дня 7 цель не «день 1»")
	-- Ни одна цель не длиннее 60 знаков при самом длинном задании: строка на экране одна.
	local longest = 0
	for _, def in ipairs(Daily.QuestPool) do
		longest = math.max(longest, utf8.len(questGoal(def, def.target - 1)) or 0)
	end
	for _, line in ipairs({
		S.t("hud.goal_daily", { day = TOTAL, total = TOTAL }), S.t("hud.goal_quest_done"), S.t("hud.goal_gift"),
		S.t("hud.goal_next_gift", { minutes = 120 }), S.t("hud.goal_mega", { time = Format.time(DAY - 1), day = TOTAL }),
		S.t("hud.goal_tomorrow", { time = Format.time(DAY - 1), day = TOTAL, total = TOTAL }),
	}) do
		longest = math.max(longest, utf8.len(line) or 0)
	end
	check(longest <= 60, "цель длиннее 60 знаков: " .. longest)
end)

scenario("цель: битое или пустое состояние прячет строку и не роняет цикл клиента", function()
	local fake = { goalButton = { Text = "old", Visible = true } }
	local cases = { [2] = {}, [3] = { rewards = {} }, [4] = { rewards = { quests = 5 }, playtime = {} } } -- [1] = nil
	for index = 1, 4 do
		local broken = cases[index]
		local ok = pcall(Hud.refreshGoal, fake, broken)
		check(ok, "битое состояние уронило refreshGoal")
		check(fake.goalButton.Visible == false, "при битом состоянии строка цели видна")
	end
	fake.goalButton.Visible = true
	Hud.refreshGoal(fake, ClientState.current)
	check(fake.goalButton.Visible == true and fake.goalButton.Text == Hud.goal(ClientState.current), "после исправного состояния строка не вернулась")
end)

check(#World.errors == 0, "ошибки в коде: " .. #World.errors)

if failures == 0 then
	print("✅ Возвращение игроков: пройдено сценариев " .. scenarios)
else
	print("❌ Возвращение игроков: провалено проверок " .. failures)
	error("tests failed")
end
