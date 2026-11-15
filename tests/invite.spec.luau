-- Позвать друзей (13.11: 0 из 250 активных игроков, позвать друга из игры было нельзя). Настоящие сервер и клиент на
-- заглушке мира:
-- 1. Кнопка «Invite friends»: на сенсорном экране круглая 👥 у левого края с подписью под ней (строки меню там нет), на ПК
--    строка открытого меню. Окно приглашения
--    Roblox открывается только при точном ответе true от CanSendGameInviteAsync; любой другой ответ, ошибка запроса
--    или ошибка самого окна — одна строка внизу, без ошибок в коде.
-- 2. После первой капсулы — одна строка «Play with a friend: +N% income»; N сверяется с бонусом, который сервер
--    на самом деле даёт за одного друга (SocialService), а не с тем же числом из той же строки.

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

local SCREENS = {
	{ id = "телефон_390x844", size = Vector2.new(390, 844), touch = true },
	{ id = "телефон_844x390", size = Vector2.new(844, 390), touch = true },
	{ id = "телефон_360x780", size = Vector2.new(360, 780), touch = true },
	{ id = "телефон_800x360", size = Vector2.new(800, 360), touch = true },
	{ id = "планшет_1024x768", size = Vector2.new(1024, 768), touch = true },
	{ id = "ПК_1280x760", size = Vector2.new(1280, 760), touch = false },
	{ id = "ПК_1920x1080", size = Vector2.new(1920, 1080), touch = false },
}
local EDGE = 0.2 -- середина экрана: 60 %, по 20 % от каждого края (как в layout.spec)
local MIN_BUTTON = 44

local input = game:GetService("UserInputService")
local camera = workspace.CurrentCamera
local function setScreen(screen)
	pcall(function()
		input.TouchEnabled = screen.touch
	end)
	camera.ViewportSize = screen.size
end
setScreen(SCREENS[1])

-- Первый игрок — тот, чей клиент запущен. Друг 2003 зайдёт позже: Roblox отвечает «друзья» только про него.
local FRIEND_ID = 2003
local player = World.addPlayer(2001, "Inviter")
rawget(player, "__state").props.IsFriendsWith = function(_, userId)
	return userId == FRIEND_ID
end

local S = shared_require("Strings")
local Capsules = shared_require("Config/Capsules")

World.startServer()
World.startClient()
World.advance(5)

local DataService = shared_require("Services/DataService")
local SocialService = shared_require("Services/SocialService")
local Remotes = shared_require("Remotes")
local gui = player.PlayerGui:FindFirstChild("BrainrotFactoryUI")

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

local function notifies(who, fromIndex)
	local out = {}
	for index = (fromIndex or 0) + 1, #World.sent do
		local sent = World.sent[index]
		if sent.remote == "Notify" and sent.player == who and not sent.everyone then
			table.insert(out, S.text(sent.args[1]))
		end
	end
	return out
end

local function count(list, text)
	local n = 0
	for _, item in ipairs(list) do
		if item == text then
			n += 1
		end
	end
	return n
end

-- Самая новая строка уведомлений на экране: её номер и текст.
local function newestNotice()
	local newest
	for _, child in ipairs(findNamed(gui, "Notifications"):GetChildren()) do
		if child.ClassName == "TextLabel" and (newest == nil or child.LayoutOrder > newest.LayoutOrder) then
			newest = child
		end
	end
	return newest and newest.LayoutOrder or 0, newest and newest.Text or ""
end

local function onScreen(part)
	for _, item in ipairs(gui:GetDescendants()) do
		if type(item.Text) == "string" and string.find(item.Text, part, 1, true) then
			return true
		end
	end
	return false
end

local inviteButton = findNamed(gui, "InviteButton")
local menu = findNamed(gui, "Menu")
local inviteRow = menu and menu:FindFirstChild("Invite")
local inviteCaption = findNamed(gui, "InviteText")
local UNAVAILABLE = S.t("social.invite_unavailable") -- ответ не true/false и не пустой: не узнан
local FAILED = S.t("social.invite_failed") -- ошибка запроса, нет ответа, окно не открылось
local DENIED = S.t("social.invite_denied") -- Roblox ответил false
local Invite = shared_require("client/Invite")

-- Все warn этого теста (клиентский код пишет их через глобальный warn).
local warned = {}
local realWarn = warn
warn = function(...)
	table.insert(warned, table.concat({ ... }, " "))
	realWarn(...)
end
local function warnsSince(index, prefix)
	local n = 0
	for i = index + 1, #warned do
		if string.sub(warned[i], 1, #prefix) == prefix then
			n += 1
		end
	end
	return n
end

---------------------------------------------------------------------------
-- 1. Кнопка
---------------------------------------------------------------------------

scenario("кнопка 👥 с подписью и строка меню «Invite friends» есть; на сенсорном экране кнопка у левого края, вне середины", function()
	check(inviteButton ~= nil, "нет круглой кнопки InviteButton")
	check(inviteCaption ~= nil, "нет подписи InviteText под кнопкой 👥")
	check(inviteRow ~= nil, "в меню нет строки Invite")
	if not inviteButton or not inviteRow or not inviteCaption then
		return
	end
	check(inviteCaption.Text == S.t("hud.invite_short"), "текст подписи: " .. tostring(inviteCaption.Text))
	check(inviteRow.Text == S.t("hud.invite"), "текст строки меню: " .. tostring(inviteRow.Text))
	if World.locale == "en-us" then
		check(inviteRow.Text == "👥 Invite friends", "английский текст кнопки: " .. tostring(inviteRow.Text))
	end
	local measured = 0
	for _, screen in ipairs(SCREENS) do
		setScreen(screen)
		frames()
		if screen.touch then
			local k = gui:FindFirstChildOfClass("UIScale").Scale
			local position, size = inviteButton.Position.args, inviteButton.Size.args
			local w, h = size[2] * k, size[4] * k
			local x, y = position[1] * screen.size.X + position[2] * k, position[3] * screen.size.Y + position[4] * k
			measured += 1
			check(inviteButton.Visible == true, screen.id .. ": кнопка 👥 не видна")
			check(inviteCaption.Visible == true, screen.id .. ": подпись под кнопкой 👥 не видна")
			check(inviteRow.Visible == false, screen.id .. ": на сенсорном экране строка Invite в меню видна (там кнопка 👥, меню держит свои строки)")
			check(w >= MIN_BUTTON - 0.5 and h >= MIN_BUTTON - 0.5, string.format("%s: кнопка 👥 %.1fx%.1f pt, нужно не меньше %d", screen.id, w, h, MIN_BUTTON))
			check(x >= 0 and y >= 0 and x + w <= screen.size.X and y + h <= screen.size.Y,
				string.format("%s: кнопка 👥 за краем экрана: %.0f,%.0f %.0fx%.0f", screen.id, x, y, w, h))
			check(x + w <= screen.size.X * EDGE + 0.5,
				string.format("%s: кнопка 👥 заходит в середину: правый край %.0f pt, полоса края до %.0f pt", screen.id, x + w, screen.size.X * EDGE))
			-- Не на кнопке настроек (ряд 3) и не на глазе (ряд 2): зазор не меньше 6 pt.
			local settings = findNamed(gui, "SettingsButton")
			local sp, ss = settings.Position.args, settings.Size.args
			local settingsBottom = sp[3] * screen.size.Y + sp[4] * k + ss[4] * k
			check(y - settingsBottom >= 6 - 0.5, string.format("%s: зазор между ⚙ и 👥 %.1f pt, нужно не меньше 6", screen.id, y - settingsBottom))
			print(string.format("INVITE|%s|кнопка 👥 %.0f,%.0f %.0fx%.0f pt|правый край %.0f из полосы %.0f pt|середина свободна",
				screen.id, x, y, w, h, x + w, screen.size.X * EDGE))
		else
			check(inviteButton.Visible == false and inviteCaption.Visible == false, screen.id .. ": на ПК круглая кнопка 👥 или её подпись видна (там строка открытого меню)")
			check(menu.Visible == true and inviteRow.Visible ~= false, screen.id .. ": на ПК строка меню Invite не видна")
			print(string.format("INVITE|%s|круглой кнопки нет, строка меню «%s» видна", screen.id, inviteRow.Text))
		end
	end
	check(measured == 5, "сенсорных экранов измерено " .. measured .. ", нужно 5")
	setScreen(SCREENS[1])
	frames()
end)

-- Одно нажатие: что ответил Roblox -> открылось ли окно приглашения, появилась ли строка отказа.
local function press(button)
	local prompts, order = #World.invite.prompts, (newestNotice())
	local errors = #World.errors
	World.click(button)
	frames(2)
	local newOrder, text = newestNotice()
	return #World.invite.prompts - prompts, newOrder > order and text or "", #World.errors - errors
end

local falseRefusals = 0
scenario("должно пройти: Roblox ответил true — окно приглашения открыто (12 строк: 5 кнопок 👥, 5 подписей под ними и 2 строки меню на ПК)", function()
	World.invite.can, World.invite.throws, World.invite.promptFails, World.invite.wait = true, nil, nil, nil
	local rows = 0
	for _, screen in ipairs(SCREENS) do
		setScreen(screen)
		frames()
		for _, button in ipairs(if screen.touch then { inviteButton, inviteCaption } else { inviteRow }) do
			do
				rows += 1
				local opened, notice, errors = press(button)
				local ok = opened == 1 and notice == "" and errors == 0
				if not ok then
					falseRefusals += 1
				end
				check(ok, string.format("%s, %s: окно не открылось (окон %d, строка «%s», ошибок %d)", screen.id, button.Name, opened, notice, errors))
				print(string.format("ALLOW|должно пройти|%s|%s|ответ true|окон %d|%s", screen.id, button.Name, opened, ok and "прошло" or "ОТКАЗ"))
				check(World.invite.prompts[#World.invite.prompts] == player, "окно приглашения открыто не тому игроку")
			end
		end
	end
	check(rows == 12, "строк «должно пройти» " .. rows .. ", нужно 12")
	print(string.format("ALLOW|ложных отказов %d из %d", falseRefusals, rows))
	setScreen(SCREENS[1])
	frames()
end)

scenario("не должно пройти: любой ответ, кроме true, ошибка запроса или окна — строка по ветке отказа, свой warn, окна нет (12 строк)", function()
	-- Три разных текста: отказ Roblox (false), сбой (ошибка, нет ответа, окно не открылось), ответ, который мы не узнали.
	check(DENIED ~= FAILED and FAILED ~= UNAVAILABLE and DENIED ~= UNAVAILABLE, "тексты отказа совпадают между ветками")
	check(string.find(DENIED, "privacy", 1, true) or World.locale ~= "en-us", "в тексте отказа нет действия (настройки приватности)")
	local REFUSED = {
		{ "false", function() World.invite.can = false end, DENIED, "[Invite] denied" },
		{ "nil (нет ответа)", function() World.invite.can = nil end, FAILED, "[Invite] failed (empty answer)" },
		{ 'строка "true"', function() World.invite.can = "true" end, UNAVAILABLE, "[Invite] unavailable" },
		{ 'строка "yes"', function() World.invite.can = "yes" end, UNAVAILABLE, "[Invite] unavailable" },
		{ "число 1", function() World.invite.can = 1 end, UNAVAILABLE, "[Invite] unavailable" },
		{ "число 0", function() World.invite.can = 0 end, UNAVAILABLE, "[Invite] unavailable" },
		{ "пустая таблица", function() World.invite.can = {} end, UNAVAILABLE, "[Invite] unavailable" },
		{ "таблица { true }", function() World.invite.can = { true } end, UNAVAILABLE, "[Invite] unavailable" },
		{ "функция", function() World.invite.can = function() return true end end, UNAVAILABLE, "[Invite] unavailable" },
		{ "ошибка запроса при can = true", function() World.invite.can, World.invite.throws = true, true end, FAILED, "[Invite] failed (request error)" },
		{ "ошибка запроса при can = false", function() World.invite.can, World.invite.throws = false, true end, FAILED, "[Invite] failed (request error)" },
		{ "true, но окно приглашения упало", function() World.invite.can, World.invite.promptFails = true, true end, FAILED, "[Invite] failed (window did not open)" },
	}
	local wrong = 0
	local branches = {}
	for index, row in ipairs(REFUSED) do
		World.invite.can, World.invite.throws, World.invite.promptFails = true, nil, nil
		row[2]()
		local button = if index % 2 == 0 then inviteCaption else inviteButton
		local mark = #warned
		local opened, notice, errors = press(button)
		local inBranch, inAll = warnsSince(mark, row[4]), warnsSince(mark, "[Invite]")
		local ok = opened == 0 and notice == row[3] and errors == 0 and inBranch == 1 and inAll == 1
		if not ok then
			wrong += 1
		end
		branches[row[4]] = true
		check(ok, string.format("ответ %s: окон %d, строка «%s» (нужна «%s»), ошибок %d, warn ветки %d из %d", row[1], opened, notice, row[3], errors, inBranch, inAll))
		print(string.format("ALLOW|не должно пройти|%s|%s|окон %d|%s|warn %s", row[1], button.Name, opened, ok and "отказ по ветке" or "ПРОШЛО", row[4]))
	end
	local distinct = 0
	for _ in pairs(branches) do
		distinct += 1
	end
	check(#REFUSED >= 10, "строк «не должно пройти» меньше 10")
	check(distinct >= 3, "разных warn по веткам " .. distinct .. ", нужно не меньше 3")
	print(string.format("ALLOW|не должно пройти: прошло %d из %d; веток с отдельным warn %d", wrong, #REFUSED, distinct))
	World.invite.can, World.invite.throws, World.invite.promptFails = true, nil, nil
	-- После отказов кнопка жива: следующий ответ true открывает окно.
	local opened = press(inviteButton)
	check(opened == 1, "после отказов кнопка больше не открывает окно")
end)

scenario("если само уведомление упало, это warn, а не молчание; кнопка потом работает", function()
	World.invite.can, World.invite.throws, World.invite.promptFails = false, nil, nil
	local mark = #warned
	local ok, result = pcall(Invite.prompt, player, function()
		error("boom")
	end)
	check(ok and result == false, "Invite.prompt упал или открыл окно, когда уведомление не показалось")
	check(warnsSince(mark, "[Invite] notify failed: ") == 1, "уведомление упало без warn «notify failed»: " .. warnsSince(mark, "[Invite] notify failed: "))
	check(warnsSince(mark, "[Invite] denied") == 1, "ветка отказа не записала свой warn при упавшем уведомлении")
	World.invite.can = true
	check(press(inviteButton) == 1, "после упавшего уведомления кнопка не работает")
end)

scenario("пока Roblox отвечает, повторные нажатия не шлют новых запросов; после ответа кнопка работает снова", function()
	World.invite.wait = 2
	local asked, prompts = World.invite.asked, #World.invite.prompts
	World.click(inviteButton)
	World.click(inviteButton)
	World.click(inviteCaption)
	check(World.invite.asked - asked == 1, "запросов за три нажатия: " .. (World.invite.asked - asked))
	World.advance(3)
	check(#World.invite.prompts - prompts == 1, "окон за три нажатия: " .. (#World.invite.prompts - prompts))
	World.invite.wait = nil
	check(press(inviteButton) == 1, "после долгого ответа кнопка не работает")
end)

scenario("Roblox не отвечает: через 12 с кнопка снова работает и игрок видит текст ошибки", function()
	World.invite.can, World.invite.throws, World.invite.promptFails = true, nil, nil
	World.invite.wait = 100 -- ответ придёт через 100 с: для игрока «не вернулся»
	local asked, prompts, mark = World.invite.asked, #World.invite.prompts, #warned
	local order = newestNotice()
	World.click(inviteButton)
	World.advance(5)
	World.click(inviteButton) -- на 5-й секунде кнопка ещё занята
	check(World.invite.asked - asked == 1, "запросов за два нажатия до срока: " .. (World.invite.asked - asked))
	check(Invite.busy == true, "на 5-й секунде замок уже снят")
	World.advance(6.5) -- 11,5 с: срок ещё не вышел
	check(Invite.busy == true, "замок снят раньше 12 с")
	check(warnsSince(mark, "[Invite] failed (no answer") == 0, "текст ошибки показан раньше срока")
	World.advance(1) -- 12,5 с
	frames(2)
	local newOrder, shown = newestNotice()
	check(Invite.busy == false, "через 12 с замок не снят")
	check(newOrder > order and shown == FAILED, "через 12 с нет текста ошибки: «" .. shown .. "»")
	check(warnsSince(mark, "[Invite] failed (no answer in 12 s)") == 1, "нет warn ветки «нет ответа»: " .. warnsSince(mark, "[Invite] failed (no answer in 12 s)"))
	-- Кнопка снова работает (новый запрос отвечает сразу).
	World.invite.wait = nil
	check(press(inviteButton) == 1, "после срока кнопка не открывает окно")
	check(World.invite.prompts[#World.invite.prompts] == player, "окно открыто не тому игроку")
	check(#World.invite.prompts - prompts == 1, "окон за сценарий " .. (#World.invite.prompts - prompts))
	print(string.format("TIMEOUT|замок снят через %d с|текст «%s»|запросов %d", Invite.TIMEOUT, shown, World.invite.asked - asked))
end)

scenario("поздний ответ старого запроса ничего не открывает и не снимает замок нового", function()
	World.invite.wait = 20 -- первый запрос ответит через 20 с, после срока в 12 с
	local prompts, mark = #World.invite.prompts, #warned
	World.click(inviteButton)
	World.advance(12.5)
	check(Invite.busy == false, "замок не снят по сроку")
	World.invite.wait = 9 -- новый запрос (ответит на 21,5 с, в срок) ещё в пути, когда ответит старый (на 20 с)
	World.click(inviteCaption)
	check(Invite.busy == true, "новый запрос не взял замок")
	World.advance(8) -- 20,5 с от первого: пришёл ответ старого
	check(#World.invite.prompts == prompts, "поздний ответ старого запроса открыл окно")
	check(warnsSince(mark, "[Invite] late answer ignored") == 1, "нет warn о позднем ответе: " .. warnsSince(mark, "[Invite] late answer ignored"))
	check(Invite.busy == true, "поздний ответ снял замок нового запроса")
	World.advance(3)
	check(#World.invite.prompts - prompts == 1, "новый запрос не открыл окно: " .. (#World.invite.prompts - prompts))
	check(Invite.busy == false, "замок не снят после ответа нового запроса")
	World.invite.wait = nil
	World.advance(100) -- долгий ответ первого сценария тоже дошёл и был проигнорирован
	check(#World.invite.prompts - prompts == 1, "окон за сценарий " .. (#World.invite.prompts - prompts))
end)

---------------------------------------------------------------------------
-- 2. Строка про друга после первой капсулы
---------------------------------------------------------------------------

local capsule = Capsules.List[1].id
local function craft(who)
	Remotes.Craft.OnServerEvent:Fire(who, capsule)
end
local PERCENT = 10 -- что обещает строка сейчас; ниже сверяется с бонусом сервера за одного друга
local HINT = S.t("social.friend_hint", { bonus = PERCENT })

scenario("первая капсула: через 5 с одна строка про бонус за друга; раньше её нет; на экране она же", function()
	local data = DataService.get(player)
	check(data.stats.crafted == 0, "игрок уже крафтил (сломан сам тест)")
	local mark = #World.sent
	craft(player)
	check(data.stats.crafted == 1, "первая капсула не создана")
	World.advance(4.8)
	check(count(notifies(player, mark), HINT) == 0, "строка про друга пришла раньше конца показа первого брейнрота")
	World.advance(0.4)
	check(count(notifies(player, mark), HINT) == 1, "строк про друга после первой капсулы: " .. count(notifies(player, mark), HINT))
	frames(2)
	local _, shown = newestNotice()
	check(shown == HINT, "на экране не строка про друга: «" .. shown .. "»")
	if World.locale == "en-us" then
		check(HINT == "👥 Play with a friend: +10% income", "английский текст строки: " .. HINT)
	end
	check(string.find(HINT, "+" .. PERCENT .. "%", 1, true) ~= nil and string.find(HINT, "{", 1, true) == nil, "в строке нет числа бонуса: " .. HINT)
	print("HINT|" .. World.locale .. "|" .. HINT)
end)

scenario("следующие капсулы и перезаход строку не повторяют", function()
	local data = DataService.get(player)
	local mark = #World.sent
	for _ = 1, 4 do
		data.coins = 1e6
		World.advance(8)
		craft(player)
	end
	check(data.stats.crafted == 5, "капсул создано " .. data.stats.crafted .. ", нужно 5 (сломан сам тест)")
	World.advance(20)
	check(count(notifies(player, mark), HINT) == 0, "строка про друга повторилась на капсулах 2–5")
	check(count(notifies(player), HINT) == 1, "строк про друга за всю игру: " .. count(notifies(player), HINT))
end)

scenario("игрок вышел раньше 5 секунд: строки нет, ошибок нет", function()
	local quitter = World.addPlayer(2002, "Quitter")
	World.advance(1)
	local errors = #World.errors
	craft(quitter)
	check(DataService.get(quitter).stats.crafted == 1, "капсула второго игрока не создана (сломан сам тест)")
	World.advance(1)
	World.removePlayer(quitter)
	World.advance(20)
	check(count(notifies(quitter), HINT) == 0, "строка ушла игроку, которого уже нет")
	check(#World.errors == errors, "ошибки после выхода игрока: " .. (#World.errors - errors))
	-- Вернулся: счётчик капсул сохранён, строка не повторяется.
	quitter = World.addPlayer(2002, "Quitter")
	World.advance(1)
	local mark = #World.sent
	DataService.get(quitter).coins = 1e6
	craft(quitter)
	World.advance(20)
	check(DataService.get(quitter).stats.crafted == 2, "после перезахода счётчик капсул " .. DataService.get(quitter).stats.crafted)
	check(count(notifies(quitter, mark), HINT) == 0, "после перезахода строка про друга пришла снова")
	World.removePlayer(quitter)
	World.advance(5)
end)

scenario("число в строке — тот бонус, который сервер даёт за одного друга на сервере", function()
	check(SocialService.snapshot(player).friends == 0 and SocialService.snapshot(player).bonus == 0, "бонус есть без друга (сломан сам тест)")
	local friend = World.addPlayer(FRIEND_ID, "Friend")
	World.advance(2)
	local snapshot = SocialService.snapshot(player)
	check(snapshot.friends == 1, "друг на сервере не посчитан: " .. snapshot.friends)
	local given = math.floor(snapshot.bonus * 100 + 0.5)
	check(given == PERCENT, string.format("строка обещает +%d%%, сервер даёт +%d%%", PERCENT, given))
	-- Бонус дошёл до дохода: множитель покупок и бонусов (MonetizationService) у игрока вырос ровно на него.
	local passes = shared_require("Services/MonetizationService").passes(player)
	check(math.abs((passes.socialBonus or 0) * 100 - PERCENT) < 0.001, "бонус за друга не дошёл до дохода: " .. tostring(passes.socialBonus))
	print(string.format("HINT|строка +%d%%|сервер за 1 друга +%d%% (SocialService.snapshot.bonus)|в доходе +%.0f%% (MonetizationService.passes.socialBonus)",
		PERCENT, given, (passes.socialBonus or 0) * 100))
	World.removePlayer(friend)
	World.advance(2)
	check(SocialService.snapshot(player).bonus == 0, "друг вышел, а бонус остался")
end)

check(#World.errors == 0, "ошибки в коде: " .. #World.errors)

if failures == 0 then
	print("✅ Позвать друзей: пройдено сценариев " .. scenarios)
else
	print("❌ Позвать друзей: провалено проверок " .. failures)
	error("tests failed")
end
