-- Словарь строк: английский оригинал, русский из таблицы локализации, надписи в мире.

local failures = 0
local checks = 0
local function check(cond, msg)
	checks += 1
	if not cond then
		failures += 1
		print("❌ " .. msg)
	end
end

local S = shared_require("Strings")
local WorldText = shared_require("client/WorldText")
local Format = shared_require("Util/Format")

-- Тексты из словаря есть у всего, что видит игрок, включая файлы, которые нельзя менять.
local function hasText(key)
	check(S.Source[key] ~= nil and S.Source[key] ~= "", "нет текста " .. key)
end

local Monetization = shared_require("Config/Monetization")
for _, pass in ipairs(Monetization.GamePasses) do
	hasText("pass." .. pass.key .. ".name")
	hasText("pass." .. pass.key .. ".desc")
end
for _, product in ipairs(Monetization.Products) do
	hasText("product." .. product.key .. ".name")
	hasText("product." .. product.key .. ".desc")
end
for _, season in ipairs(shared_require("Config/Seasons").List) do
	hasText("season." .. season.id .. ".name")
end
for _, creature in ipairs(shared_require("Config/Creatures").List) do
	check(creature.name == S.Source[creature.nameKey], "брейнрот без имени: " .. creature.id)
	check(creature.desc == S.Source[creature.descKey], "брейнрот без описания: " .. creature.id)
end
for _, list in ipairs({
	shared_require("Config/Capsules").List,
	shared_require("Config/Rarities").List,
	shared_require("Config/Skins").List,
	shared_require("Config/Upgrades").List,
	shared_require("Config/Achievements").List,
	shared_require("Config/Daily").Wheel,
}) do
	for _, item in ipairs(list) do
		check(type(item.name) == "string" and item.name ~= "" and item.nameKey ~= nil, "нет названия у " .. tostring(item.id))
	end
end

-- Английский, параметры и вложенные сообщения.
check(S.t("factory.sold", { coins = "$5" }) == "Sold for $5", "параметр не подставлен")
local nested = S.m("creature.mutated", { mutation = S.m("mutation.golden.name"), name = S.m("creature.sei_sette.name") })
check(S.text(S.m("steal.stolen", { name = nested })) == "🦹 Stolen: Golden Sei Sette!", "вложенное сообщение")
check(S.text(S.join({ "$5", S.m("reward.skin") }, " + ")) == "$5 + 🎨 skin", "составное сообщение")
check(S.text(S.join({}, " + ")) == "", "пустая награда не пустая")
check(S.text("Vinny") == "Vinny", "обычная строка изменилась")
check(S.t("no.such.key") == "no.such.key", "нет ключа: должен показать ключ, а не упасть")
check(Format.time(3700) == "1 h 01 min", "Format.time: " .. Format.time(3700))
check(Format.percent(0.00001) == "0.001%", "Format.percent: " .. Format.percent(0.00001))

-- Надпись на табличке: сервер пишет английский и сообщение рядом.
local label = Instance.new("TextLabel")
label.Parent = workspace
local message = S.m("plot.owner_base", { name = "Vinny" })
S.apply(label, "Text", message)
check(label.Text == "Vinny's base", "S.apply: английский текст")

-- Русский игрок: таблица локализации Roblox и никакого автоперевода.
S.setLanguage("ru")
check(S.t("factory.sold", { coins = "$5" }) == "Продано за $5", "русский перевод: " .. S.t("factory.sold", { coins = "$5" }))
check(S.text(S.m("steal.stolen", { name = nested })) == "🦹 Украдено: Золотой Сей Сетте!", "русское вложенное сообщение")
check(Format.time(3700) == "1 ч 01 мин", "русский Format.time")
WorldText.start()
check(label.Text == "База Vinny", "табличка не перевелась: " .. tostring(label.Text))
S.apply(label, "Text", S.m("plot.free_base"))
check(label.Text == "Свободная база", "обновлённая табличка не перевелась: " .. tostring(label.Text))
local added = Instance.new("TextLabel")
S.apply(added, "Text", S.m("plot.free_base"))
check(added.Text == "Свободная база", "новая табличка не перевелась: " .. tostring(added.Text))

-- Язык без перевода и сбой таблицы: остаётся английский.
S.setLanguage("de")
check(S.t("factory.sold", { coins = "$5" }) == "Sold for $5", "нет перевода: должен быть английский")
__translationEntries = nil
S.setLanguage("fr")
check(S.t("factory.sold", { coins = "$5" }) == "Sold for $5", "пустая таблица: должен быть английский")

-- Таблица дошла до клиента не сразу: пустой результат не запоминается на всю сессию.
__translationEntries = {}
S.setLanguage("es")
check(S.t("plot.free_base") == "Free base", "таблица ещё пуста: должен быть английский")
__translationEntries = { { Key = "plot.free_base", Source = "Free base", Values = { es = "Base libre" } } }
check(S.t("plot.free_base") == "Free base", "таблицу не должны читать на каждом кадре")
World.advance(31)
check(S.t("plot.free_base") == "Base libre", "таблица не перечитана позже")
__translationEntries = {}
World.advance(31)
check(S.t("plot.free_base") == "Base libre", "загруженная таблица потеряна")

-- Сообщение при выгоне приходит до клиента, поэтому язык берётся у игрока на сервере.
__translationEntries = nil
check(S.forPlayer({ LocaleId = "en-us" }, "plot.free_base") == "Free base", "forPlayer: английский")
check(S.forPlayer({ LocaleId = "ru-ru" }, "plot.free_base") == "Свободная база", "forPlayer: русский")

if failures == 0 then
	print("✅ Словарь: пройдено проверок " .. checks)
else
	print("❌ Словарь: провалено проверок " .. failures)
	error("tests failed")
end
