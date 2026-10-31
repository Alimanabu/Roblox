-- Все окна глазами игрока: настоящие сервер и клиент на заглушке мира (tests/world.luau).
-- Новичок и богатый игрок открывают каждое окно и нажимают каждую кнопку. Каждая надпись
-- проверяется: нет ошибок в коде, нет незаполненных {параметров}, язык тот, что у игрока.

local failures = 0
local function check(cond, msg)
	if not cond then
		failures += 1
		print("❌ " .. msg)
	end
end

-- Игроки раньше модулей: словарь узнаёт язык у игрока при загрузке.
local player = World.addPlayer(1001, "Tester")
local friend = World.addPlayer(1002, "Friend")
local S = shared_require("Strings")
local isRussian = World.locale == "ru-ru"

World.startServer()
World.startClient()
World.advance(5)

local gui = player.PlayerGui
local Remotes = shared_require("Remotes")

local function screenTexts()
	local out = {}
	for _, item in ipairs(gui:GetDescendants()) do
		if type(item.Text) == "string" and item.Text ~= "" then
			out[item.Text] = true
		end
	end
	return out
end

-- Кнопка меню с этим словом из словаря.
local function menu(key)
	local button = World.find(gui, S.t(key))
	check(button ~= nil, "нет кнопки меню " .. key)
	if button then
		World.click(button)
		World.advance(0.2)
	end
end

local MENU = {
	"hud.rewards", "hud.factory", "hud.base", "hud.upgrades", "hud.rebirth", "hud.index", "hud.achievements",
	"hud.trade", "hud.battles", "hud.skins", "hud.shop", "hud.help", "hud.admin",
}

-- В каждом окне нажимаем все кнопки по очереди (те, что ещё на экране после прошлых нажатий).
local function pressEverything(key)
	menu(key)
	local pressed = {}
	for _ = 1, 40 do
		local nextButton
		for _, button in ipairs(World.buttons(gui)) do
			local label = button.Text or ""
			local isMenu = false
			for _, menuKey in ipairs(MENU) do
				isMenu = isMenu or label == S.t(menuKey)
			end
			if not pressed[label] and label ~= "" and not isMenu and label ~= S.t("admin.reset") then
				nextButton = button
				pressed[label] = true
				break
			end
		end
		if not nextButton then
			break
		end
		World.click(nextButton)
		World.advance(0.3)
		menu(key)
	end
end

local function admin(command, arg)
	Remotes.Admin:FireServer(command, arg)
	World.advance(0.3)
end

print("— Экраны (" .. World.locale .. ") —")

-- Новичок: всё пусто.
for _, key in ipairs(MENU) do
	menu(key)
end
for _, key in ipairs(MENU) do
	pressEverything(key)
end

-- Богатый игрок: уровни, монеты, брейнроты, этажи, сезон, ивенты.
admin("coins", 1e12)
admin("levels", 60)
for _ = 1, 3 do
	admin("creature", "aura")
end
admin("creature", "god")
admin("mutant")
admin("season", "halloween")
for _, event in ipairs({ "luck_storm", "minute67", "boss" }) do
	admin("event", event)
end
admin("wild")
for _, key in ipairs(MENU) do
	pressEverything(key)
end
admin("skipTutorial")
World.advance(130)

-- Обмен и баттл со вторым игроком.
Remotes.TradeRequest:FireServer(friend.UserId)
World.advance(1)
menu("hud.trade")
Remotes.BattleChallenge:FireServer("bot")
World.advance(15)
menu("hud.battles")

check(#World.errors == 0, "ошибки в коде: " .. #World.errors)

-- Всё, что попало на экран или в сообщения.
local shown = World.texts
for _, sent in ipairs(World.sent) do
	if sent.remote == "Notify" then
		shown[S.text(sent.args[1])] = true
	end
end
local total = 0
for text in pairs(shown) do
	total += 1
	check(string.find(text, "{%a+}") == nil, "незаполненный параметр: " .. text)
	check(string.find(text, "table: 0x", 1, true) == nil, "таблица вместо текста: " .. text)
	check(string.find(text, "nil", 1, true) == nil, "nil в тексте: " .. text)
	if not isRussian then
		check(string.find(text, "[\208\209]") == nil, "русский текст у английского игрока: " .. text)
	end
end
check(total > 300, "на экран попало мало надписей: " .. total)
check(next(screenTexts()) ~= nil, "экран пуст")

-- Покрытие: сколько текстов словаря без параметров дошло до экрана (целиком или внутри надписи).
local reached, plainTotal = 0, 0
for key, text in pairs(S.Source) do
	if string.find(text, "{", 1, true) == nil then
		plainTotal += 1
		local needle = S.t(key)
		for line in pairs(shown) do
			if string.find(line, needle, 1, true) then
				reached += 1
				break
			end
		end
	end
end
print(string.format("  дошло до экрана: %d из %d текстов без параметров", reached, plainTotal))

if isRussian then
	-- Каждый текст из словаря с переводом: на экране не должен остаться английский оригинал.
	local translated = {}
	for _, entry in ipairs(__translationEntries) do
		translated[entry.Source] = entry.Values.ru
	end
	for text in pairs(shown) do
		local ru = translated[text]
		check(ru == nil or ru == text, "английский текст у русского игрока: " .. text)
	end
end

if failures == 0 then
	print("✅ Экраны: надписей проверено " .. total .. ", ошибок нет")
else
	print("❌ Экраны: провалено проверок " .. failures)
	error("tests failed")
end
