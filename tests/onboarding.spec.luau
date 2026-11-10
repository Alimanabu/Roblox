-- Удержание новичка (отзыв игрока 10.11: «не поняла, как играть»), настоящие сервер и клиент на заглушке мира:
-- 1. Доход за время отсутствия: формула (0 ч → 0, 1 ч → N, 10 ч → потолок) и выдача при входе.
-- 2. Окно «С возвращением, +$N»: приходит после перерыва 10+ минут, закрывается одним касанием, без Robux и таймеров;
--    короткий перерыв — уведомление; новичку и игроку без брейнротов — ничего. Событие аналитики OfflineIncomeReturn.
-- 3. Первая капсула бесплатная, её показ большой; вторая платная; бесплатный брейнрот не печатает монеты продажей.

local failures = 0
local scenarios = 0
local function check(cond, msg)
	if not cond then
		failures += 1
		print("❌ " .. msg)
	end
end
local function scenario(name, body)
	scenarios += 1
	print("  ✅ " .. scenarios .. ". " .. name)
	body()
end

World.studio = false
local HOUR = 3600

-- Первый игрок — тот, чей клиент запущен (новичок на телефоне 390×844).
local input = game:GetService("UserInputService")
local camera = workspace.CurrentCamera
pcall(function()
	input.TouchEnabled = true
end)
camera.ViewportSize = Vector2.new(390, 844)
local newbie = World.addPlayer(9001, "Newbie")

local S = shared_require("Strings")
local Format = shared_require("Util/Format")
local Formulas = shared_require("Util/Formulas")
local Capsules = shared_require("Config/Capsules")

World.startServer()
World.startClient()
World.advance(5)

local DataService = shared_require("Services/DataService")
local MonetizationService = shared_require("Services/MonetizationService")
local FactoryService = shared_require("Services/FactoryService")
local Remotes = shared_require("Remotes")
local gui = newbie.PlayerGui:FindFirstChild("BrainrotFactoryUI")

local function frames(count)
	for _ = 1, count or 12 do
		World.frame()
	end
	World.advance(0.3)
end

local function findNamed(root, name)
	for _, item in ipairs(root:GetDescendants()) do
		if item.Name == name then
			return item
		end
	end
	return nil
end

local function sentTo(player, remote, fromIndex)
	local out = {}
	for index = (fromIndex or 0) + 1, #World.sent do
		local sent = World.sent[index]
		if sent.remote == remote and sent.player == player and not sent.everyone then
			table.insert(out, sent.args)
		end
	end
	return out
end

local function customEvents(player, name)
	local count = 0
	for _, call in ipairs(World.analytics) do
		if call.method == "LogCustomEvent" and call.args[1] == player and call.args[2] == name then
			count += call.args[3] or 1
		end
	end
	return count
end

-- Сколько монет записано в аналитику экономики с меткой Offline (сбрасывается при выходе игрока): второй источник,
-- не баланс (баланс в игре растёт и от обычного дохода каждую секунду).
local function offlineLogged(player)
	local total = 0
	for _, call in ipairs(World.analytics) do
		if call.method == "LogEconomyEvent" and call.args[1] == player and call.args[6] == "Offline" then
			total += call.args[4]
		end
	end
	return total
end

-- 1. Формула -----------------------------------------------------------------------------------

scenario("формула дохода за отсутствие: 0 ч → 0, 1 ч → N, 10 ч → потолок 3 ч", function()
	check(type(Formulas.offlineIncome) == "function", "нет Formulas.offlineIncome")
	if type(Formulas.offlineIncome) ~= "function" then
		return
	end
	local income = 10 -- монет в секунду
	-- Числа посчитаны руками: доход × секунды × 0,5, не больше 3 часов.
	check(Formulas.offlineIncome(income, 0) == 0, "0 ч дали " .. Formulas.offlineIncome(income, 0))
	check(Formulas.offlineIncome(income, 59) == 0, "59 с (смена сервера) дали " .. Formulas.offlineIncome(income, 59))
	check(Formulas.offlineIncome(income, HOUR) == 18000, "1 ч дал " .. Formulas.offlineIncome(income, HOUR) .. ", нужно 18000")
	check(Formulas.offlineIncome(income, 3 * HOUR) == 54000, "3 ч дали " .. Formulas.offlineIncome(income, 3 * HOUR))
	check(Formulas.offlineIncome(income, 10 * HOUR) == 54000, "10 ч дали " .. Formulas.offlineIncome(income, 10 * HOUR) .. ", потолок 54000")
	check(Formulas.offlineIncome(income, 30 * 24 * HOUR) == 54000, "30 дней дали больше потолка")
	check(Formulas.offlineIncome(0, HOUR) == 0, "без брейнротов доход есть")
	check(Formulas.offlineIncome(income, -HOUR) == 0, "часы назад дали доход")
	check(Formulas.offlineIncome(0 / 0, HOUR) == 0 and Formulas.offlineIncome(income, 0 / 0) == 0, "NaN дал доход")
	check(Formulas.offlineIncome(nil, HOUR) == 0, "пустой доход уронил формулу")
end)

-- 2. Выдача при входе и окно -----------------------------------------------------------------------

local RETURNER = 9002
local function joinWithCreatures(name)
	local player = World.addPlayer(RETURNER, name)
	World.advance(2)
	local data = DataService.get(player)
	if #data.creatures == 0 then
		FactoryService.give(player, "bananito_ninjini", "normal")
		FactoryService.give(player, "bananito_ninjini", "normal")
	end
	World.advance(1)
	return player, data
end

-- Выход: сохранение пишет lastOnline. Прыжок времени: игрока на сервере нет.
local function leaveFor(player, seconds)
	World.removePlayer(player)
	World.advance(1)
	World.skip(seconds)
end

local function rejoin(name)
	local mark = #World.sent
	local player = World.addPlayer(RETURNER, name)
	World.advance(0.5)
	local data = DataService.get(player)
	local coins = data.coins
	local income = Formulas.totalIncome(data, MonetizationService.passes(player))
	local away = os.time() - data.lastOnline
	World.advance(4) -- доход через 1 с после загрузки, окно ещё через 2 с
	return player, data, mark, coins, income, away
end

scenario("вход на 2-й день: +$N и окно «С возвращением» с той же суммой, событие аналитики", function()
	local first = joinWithCreatures("Returner")
	leaveFor(first, 24 * HOUR)
	local player, _, mark, _, income, away = rejoin("Returner")
	check(income > 0, "у игрока нет дохода: тест ничего не проверит")
	check(away >= 24 * HOUR, "отсутствие посчитано " .. away .. " с")
	local expected = math.floor(income * 3 * HOUR * 0.5) -- больше 3 ч: потолок, посчитано в тесте
	local windows = sentTo(player, "WelcomeBack", mark)
	check(#windows == 1, "окно «С возвращением» пришло " .. #windows .. " раз")
	check(windows[1] and windows[1][1] == expected, "в окне сумма " .. tostring(windows[1] and windows[1][1]) .. ", нужно " .. expected)
	for _, args in ipairs(sentTo(player, "Notify", mark)) do
		check(not string.find(S.text(args[1]), "💤", 1, true), "после суток пришло и окно, и уведомление")
	end
	World.removePlayer(player) -- выход сбрасывает аналитику
	World.advance(1)
	check(offlineLogged(player) == expected, string.format("на баланс записано %d, нужно %d", offlineLogged(player), expected))
	check(customEvents(player, "OfflineIncomeReturn") == 1, "событие OfflineIncomeReturn: " .. customEvents(player, "OfflineIncomeReturn"))
end)

scenario("1 час: доход за час и окно; 5 минут: уведомление без окна; 30 секунд: ничего", function()
	World.skip(HOUR)
	local player, _, mark, _, income, away = rejoin("Returner")
	World.removePlayer(player)
	World.advance(1)
	local got = offlineLogged(player)
	check(away >= HOUR and away < HOUR + 10, "отсутствие посчитано " .. away)
	check(got >= math.floor(income * away * 0.5) and got <= math.floor(income * (away + 2) * 0.5),
		string.format("за %d с пришло %d, нужно %d", away, got, math.floor(income * away * 0.5)))
	check(#sentTo(player, "WelcomeBack", mark) == 1, "после часа нет окна")
	World.skip(5 * 60)
	player, _, mark = rejoin("Returner")
	World.removePlayer(player)
	World.advance(1)
	check(offlineLogged(player) > 0, "после 5 минут дохода нет")
	check(#sentTo(player, "WelcomeBack", mark) == 0, "после 5 минут окно (нужно уведомление)")
	local notified = false
	for _, args in ipairs(sentTo(player, "Notify", mark)) do
		notified = notified or string.find(S.text(args[1]), "💤", 1, true) ~= nil
	end
	check(notified, "после 5 минут нет уведомления о доходе")
	check(customEvents(player, "OfflineIncomeReturn") == 0, "5 минут дали событие возвращения (оно только при окне, от 10 минут)")
	World.skip(30)
	player, _, mark = rejoin("Returner")
	World.removePlayer(player)
	World.advance(1)
	check(offlineLogged(player) == 0 and #sentTo(player, "WelcomeBack", mark) == 0, "смена сервера через 30 с дала доход или окно")
	check(customEvents(player, "OfflineIncomeReturn") == 0, "смена сервера дала событие возвращения")
end)

scenario("граница 10 минут: 9 мин 59 с — ни окна, ни события; ровно 10 мин — окно и одно событие", function()
	local IncomeService = shared_require("Services/IncomeService")
	for _, case in ipairs({ { id = 9005, away = 10 * 60 - 1, events = 0, windows = 0 }, { id = 9006, away = 10 * 60, events = 1, windows = 1 } }) do
		local player = World.addPlayer(case.id, "Edge" .. case.id)
		World.advance(3) -- первый вход: дохода за отсутствие нет
		local data = DataService.get(player)
		FactoryService.give(player, "bananito_ninjini", "normal")
		World.advance(0.5)
		local mark = #World.sent
		data.lastOnline = os.time() - case.away -- отсутствие ровно case.away секунд
		local amount = IncomeService.giveOfflineIncome(player)
		World.advance(3)
		check(amount > 0, case.away .. " с: дохода за отсутствие нет")
		local windows = #sentTo(player, "WelcomeBack", mark)
		World.removePlayer(player) -- выход сбрасывает события аналитики
		World.advance(1)
		local events = customEvents(player, "OfflineIncomeReturn")
		check(windows == case.windows, string.format("%d с: окон %d, нужно %d", case.away, windows, case.windows))
		check(events == case.events, string.format("%d с: событий OfflineIncomeReturn %d, нужно %d", case.away, events, case.events))
		print(string.format("EDGE|%d с|окон %d|событий %d|монет %d", case.away, windows, events, amount))
	end
end)

scenario("новичок (первый вход) и игрок без брейнротов: окна нет", function()
	local fresh = World.addPlayer(9003, "Fresh")
	local mark = #World.sent
	World.advance(5)
	check(#sentTo(fresh, "WelcomeBack", mark) == 0, "новичку пришло окно «С возвращением»")
	World.removePlayer(fresh)
	World.advance(1)
	local empty = World.addPlayer(9004, "Empty")
	World.advance(2)
	World.removePlayer(empty)
	World.advance(1)
	World.skip(24 * HOUR)
	local mark3 = #World.sent
	local again = World.addPlayer(9004, "Empty")
	World.advance(5)
	local d = DataService.get(again)
	check(#d.creatures == 0, "у пустого игрока появились брейнроты")
	check(#sentTo(again, "WelcomeBack", mark3) == 0, "игроку без брейнротов пришло окно с +$0")
	World.removePlayer(again)
	World.advance(1)
end)

-- 3. Окно на клиенте ------------------------------------------------------------------------------

scenario("окно на телефоне: сумма на языке игрока, кнопка ≥ 44 pt, текст ≥ 18 pt, закрывается одним касанием", function()
	local window = gui and findNamed(gui, "WelcomeBack")
	check(window ~= nil, "нет окна WelcomeBack")
	if not window then
		return
	end
	check(window.Visible == false, "окно видно до возвращения")
	local scale = gui:FindFirstChildOfClass("UIScale").Scale
	local text, ok, card = findNamed(window, "Text"), findNamed(window, "Ok"), findNamed(window, "Card")
	for _, tap in ipairs({ window, card, ok }) do
		Remotes.WelcomeBack:FireClient(newbie, 12345)
		frames(2)
		check(window.Visible == true, "окно не открылось")
		check(text.Text == S.t("welcome.text", { coins = "+" .. Format.coins(12345) }), "в окне не та сумма: " .. text.Text)
		World.click(tap)
		frames(2)
		check(window.Visible == false, "одно касание по " .. tap.Name .. " не закрыло окно")
	end
	check(ok.Size.args[2] * scale >= 44 - 0.01 and ok.Size.args[4] * scale >= 44 - 0.01,
		string.format("кнопка окна %.1fx%.1f pt, нужно 44", ok.Size.args[2] * scale, ok.Size.args[4] * scale))
	check(text.TextSize * scale >= 18 - 0.01, string.format("текст окна %.1f pt", text.TextSize * scale))
	check(card.Size.args[2] * scale <= 390, "карточка шире экрана")
	-- Ни Robux, ни таймера: в окне только заголовок, сумма и одна кнопка.
	local texts = {}
	for _, item in ipairs(window:GetDescendants()) do
		if type(item.Text) == "string" and item.Text ~= "" then
			table.insert(texts, item.Text)
		end
	end
	check(#texts == 3, "в окне надписей " .. #texts .. ": " .. table.concat(texts, " | "))
	for _, line in ipairs(texts) do
		check(not string.find(line, "R%$") and not string.find(line, "%d+:%d%d"), "в окне Robux или таймер: " .. line)
	end
	Remotes.WelcomeBack:FireClient(newbie, 0)
	Remotes.WelcomeBack:FireClient(newbie, "x")
	frames(2)
	check(window.Visible == false, "окно открылось на сумму 0 или мусор")
end)

-- 4. Первая капсула ---------------------------------------------------------------------------------

local function factoryButton()
	for _, item in ipairs(gui:GetDescendants()) do
		if item:GetAttribute("TutorialTarget") == "craft" then
			return item
		end
	end
	return nil
end

scenario("первая капсула бесплатная, показ большой; вторая платная; бесплатного не продать дороже 0", function()
	local data = DataService.get(newbie)
	check(data.stats.crafted == 0 and #data.creatures == 0, "новичок уже крафтил (сломан сам тест)")
	local basic = Capsules.List[1]
	local coins = data.coins
	-- Кнопка в окне фабрики говорит «бесплатно».
	local menuOpen = findNamed(gui, "MenuButton")
	World.click(menuOpen)
	frames()
	World.click(findNamed(findNamed(gui, "Menu"), "Factory"))
	frames()
	local button = factoryButton()
	check(button ~= nil and button.Text == S.t("factory.craft_free"), "на кнопке не «бесплатно»: " .. tostring(button and button.Text))
	local mark = #World.sent
	local Tutorial = shared_require("Config/Tutorial")
	World.click(button) -- сервер отвечает сразу: доход по секундам ещё не капнул
	check(data.coins - coins == Tutorial.Steps[1].reward,
		string.format("после первой капсулы баланс %+d, нужно +%d (награда шага 1, капсула 0)", data.coins - coins, Tutorial.Steps[1].reward))
	World.advance(1)
	frames()
	check(#data.creatures == 1 and data.creatures[1].paid == 0, "первый брейнрот без цены 0")
	local results = sentTo(newbie, "CraftResult", mark)
	check(#results == 1 and results[1][1].first == true, "результат первой капсулы без пометки first")
	local reveal = findNamed(gui, "Reveal")
	check(reveal.Visible == true and reveal:GetAttribute("Big") == true, "первый брейнрот без большого показа")
	local badges = {}
	for _, item in ipairs(reveal:GetDescendants()) do
		if type(item.Text) == "string" and string.find(item.Text, S.t("reveal.first"), 1, true) then
			table.insert(badges, item)
		end
	end
	check(#badges == 1, "нет надписи «Твой первый брейнрот»")
	-- Продажа бесплатного: 0 монет (иначе «крафт-продажа» печатает деньги).
	check(Formulas.sellValue(data.creatures[1]) == 0, "бесплатный брейнрот продаётся за " .. Formulas.sellValue(data.creatures[1]))
	-- Вторая платная.
	World.advance(6)
	frames()
	button = factoryButton()
	check(button ~= nil and button.Text == S.t("factory.craft", { cost = Format.coins(basic.cost) }), "на второй кнопке не цена: " .. tostring(button and button.Text))
	mark = #World.sent
	local before = data.coins
	World.click(button)
	check(before - data.coins == basic.cost, string.format("вторая капсула стоила %d, нужно %d", before - data.coins, basic.cost))
	results = sentTo(newbie, "CraftResult", mark)
	check(#results == 1 and results[1][1].first == nil, "вторая капсула снова «первая»")
	check(Formulas.isFreeCraft(basic, data) == false, "после двух капсул первая снова бесплатна")
end)

scenario("бесплатна только первая обычная капсула и только до первого крафта", function()
	local fake = { stats = { crafted = 0 } }
	check(Formulas.capsuleCost(Capsules.List[1], fake) == 0, "первая капсула новичка не бесплатна")
	check(Formulas.capsuleCost(Capsules.List[2], fake) == Capsules.List[2].cost, "вторая по списку капсула бесплатна")
	fake.stats.crafted = 1
	check(Formulas.capsuleCost(Capsules.List[1], fake) == Capsules.List[1].cost, "после крафта капсула бесплатна")
	check(Formulas.capsuleCost(Capsules.List[1], {}) == Capsules.List[1].cost, "профиль без stats: бесплатно")
end)

check(#World.errors == 0, "ошибки в коде: " .. #World.errors)
for _, err in ipairs(World.errors) do
	print("   " .. tostring(err))
end

if failures == 0 then
	print("✅ Новичок и возвращение: пройдено сценариев " .. scenarios)
else
	print("❌ Новичок и возвращение: провалено проверок " .. failures)
	error("tests failed")
end
