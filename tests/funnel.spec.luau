-- Воронки аналитики на настоящем сервере: обучение (LogOnboardingFunnelStepEvent) и основной цикл
-- (LogFunnelStepEvent). Каждый шаг уходит один раз за жизнь игрока, по возрастанию, без пропусков;
-- падение AnalyticsService игру не ломает. Все вызовы пишет заглушка в World.analytics.

local failures = 0
local checks = 0
local function check(cond, msg)
	checks += 1
	if not cond then
		failures += 1
		print("❌ " .. msg)
	end
end

World.studio = false

local ONE, TWO, THREE, FOUR, FIVE, SIX = 9101, 9102, 9103, 9104, 9105, 9106
local Funnels = shared_require("Config/Funnels")
local Tutorial = shared_require("Config/Tutorial")
local Capsules = shared_require("Config/Capsules")
local Creatures = shared_require("Config/Creatures")
local Remotes = shared_require("Remotes")

World.startServer()
local first = World.addPlayer(ONE, "Funnel1")
local DataService = shared_require("Services/DataService")
local FactoryService = shared_require("Services/FactoryService")
local Actions = shared_require("Services/Actions")

local CAPSULE = Capsules.List[1].id
local NORMIE = "bananito_ninjini"
local NORMIE_RARITY = Creatures.get(NORMIE).rarity

-- Вызовы по методу: onboarding -> { "1:Joined", ... }, loop -> { "1:FirstCapsule", ... }.
local function onboarding(player)
	local out = {}
	for _, call in ipairs(World.analytics) do
		if call.method == "LogOnboardingFunnelStepEvent" and call.args[1] == player then
			table.insert(out, call.args[2] .. ":" .. call.args[3])
		end
	end
	return out
end
local function loop(player)
	local out = {}
	for _, call in ipairs(World.analytics) do
		if call.method == "LogFunnelStepEvent" and call.args[1] == player then
			table.insert(out, call.args[4] .. ":" .. call.args[5])
		end
	end
	return out
end
local function joined(list)
	return table.concat(list, " ")
end

local function craft(player, times)
	for _ = 1, times do
		DataService.get(player).coins = 1e6
		Remotes.Craft.OnServerEvent:Fire(player, CAPSULE)
		World.advance(10) -- longer than the capsule time
	end
end

local function sellAll(player)
	for _, entry in ipairs(table.clone(DataService.get(player).creatures)) do
		Remotes.Sell.OnServerEvent:Fire(player, entry.uid)
	end
end

-- Список шагов обучения из конфига и имена воронок ---------------------------------------------

print("— Имена шагов —")
check(#Funnels.ONBOARDING == #Tutorial.Steps + 1, "шагов воронки обучения " .. #Funnels.ONBOARDING .. ", нужно шагов обучения + 1")
check(Funnels.ONBOARDING[1] == "Joined", "шаг 1 воронки обучения не вход в игру")
for index, step in ipairs(Tutorial.Steps) do
	check(Funnels.ONBOARDING[index + 1] == "Step" .. index .. "_" .. step.action, "имя шага " .. (index + 1) .. " не по шагу обучения " .. index)
end
local seen = {}
for _, name in ipairs(Funnels.ONBOARDING) do
	check(#name <= 50 and #name > 0 and not seen[name] and name:match("^[%w_]+$") ~= nil, "имя шага обучения: " .. name)
	seen[name] = true
end
seen = {}
for _, step in ipairs(Funnels.LOOP) do
	check(#step.name <= 50 and not seen[step.name] and step.name:match("^[%w_]+$") ~= nil, "имя шага цикла: " .. step.name)
	seen[step.name] = true
end
check(#Funnels.LOOP == 6, "шагов основной воронки не 6")

-- Игрок 1: весь путь от входа до возвращения ----------------------------------------------------

print("— Воронка обучения и основного цикла по шагам —")
World.advance(2)
local data = DataService.get(first)
check(data ~= nil, "профиль не загрузился")
check(joined(onboarding(first)) == "1:Joined", "вход: " .. joined(onboarding(first)))
check(#loop(first) == 0, "основная воронка пошла до первого действия")

craft(first, 1)
check(joined(onboarding(first)) == "1:Joined 2:Step1_craft", "1-й крафт: " .. joined(onboarding(first)))
check(joined(loop(first)) == "1:FirstCapsule", "1-й крафт, цикл: " .. joined(loop(first)))
local sessionId = data.funnel.session
check(type(sessionId) == "string" and sessionId ~= "", "нет funnelSessionId в профиле")
for _, call in ipairs(World.analytics) do
	if call.method == "LogFunnelStepEvent" then
		check(call.args[2] == "MainLoop" and call.args[3] == sessionId, "имя воронки или funnelSessionId не те")
	end
end

craft(first, 3)
check(joined(onboarding(first)) == "1:Joined 2:Step1_craft", "3 крафта из 4: шаг 3 ушёл рано")
craft(first, 1)
check(joined(onboarding(first)) == "1:Joined 2:Step1_craft 3:Step2_craft", "4 крафта шага 2: " .. joined(onboarding(first)))
check(joined(loop(first)) == "1:FirstCapsule", "повторный крафт шлёт шаг цикла снова: " .. joined(loop(first)))

-- Продали до первого скрещивания: шаг «продажа» ждёт своей очереди, не идёт вне порядка.
data.creatures = {}
FactoryService.give(first, NORMIE, "normal")
sellAll(first)
check(data.stats.sold == 1, "брейнрот не продан")
check(data.funnel.done.sell == true, "факт продажи не записан")
check(joined(loop(first)) == "1:FirstCapsule", "продажа раньше скрещивания ушла вне порядка: " .. joined(loop(first)))

for _ = 1, 3 do
	FactoryService.give(first, NORMIE, "normal")
end
Remotes.Fuse.OnServerEvent:Fire(first, NORMIE_RARITY)
check(data.stats.fused == 1, "скрещивание не прошло")
check(joined(loop(first)) == "1:FirstCapsule 2:FirstFuse 3:FirstSale", "скрещивание тянет за собой продажу по порядку: " .. joined(loop(first)))

-- Второе скрещивание и вторая продажа ничего не шлют.
for _ = 1, 3 do
	FactoryService.give(first, NORMIE, "normal")
end
Remotes.Fuse.OnServerEvent:Fire(first, NORMIE_RARITY)
sellAll(first)
check(#loop(first) == 3, "повторные скрещивание и продажа шлют шаги: " .. joined(loop(first)))

-- Улучшение: шаг 3 обучения и шаг 4 цикла.
data.coins = 1e6
Remotes.BuyUpgrade.OnServerEvent:Fire(first, "speed")
check(data.upgrades.speed == 1, "улучшение не куплено")
check(joined(onboarding(first)) == "1:Joined 2:Step1_craft 3:Step2_craft 4:Step3_upgrade", "улучшение, обучение: " .. joined(onboarding(first)))
check(#loop(first) == 4 and loop(first)[4] == "4:FirstUpgrade", "улучшение, цикл: " .. joined(loop(first)))
Remotes.BuyUpgrade.OnServerEvent:Fire(first, "speed")
check(#loop(first) == 4 and #onboarding(first) == 4, "второе улучшение шлёт шаги снова")

-- Сохранение прогресса: первая настоящая запись в DataStore, дальше тишина.
check(DataService.save(first) == true, "сохранение не прошло")
check(#loop(first) == 5 and loop(first)[5] == "5:ProgressSaved", "сохранение, цикл: " .. joined(loop(first)))
DataService.save(first)
check(#loop(first) == 5, "второе сохранение шлёт шаг снова")

-- Обучение до конца.
Actions.fire(first, "lock", 1)
check(#onboarding(first) == 5 and onboarding(first)[5] == "5:Step4_lock", "замок, обучение: " .. joined(onboarding(first)))
Remotes.ClaimDaily.OnServerEvent:Fire(first)
check(#onboarding(first) == 6 and onboarding(first)[6] == "6:Step5_daily", "награда дня, обучение: " .. joined(onboarding(first)))
check(data.tutorial.step == #Tutorial.Steps + 1, "обучение не закончено")

-- Выход и тот же день: ничего не повторяется, «вернулся» не ставится.
local beforeLeave = #onboarding(first) + #loop(first)
World.removePlayer(first)
check(#onboarding(first) + #loop(first) == beforeLeave, "выход игрока шлёт шаги (финальное сохранение не шаг)")
World.advance(3600)
local back = World.addPlayer(ONE, "Funnel1")
World.advance(2)
check(#onboarding(first) == 6 and #onboarding(back) == 0, "повторный вход в тот же день шлёт обучение: " .. joined(onboarding(back)))
check(#loop(first) == 5 and #loop(back) == 0, "повторный вход в тот же день: ReturnedDay2 ушёл рано")
check(DataService.get(back).funnel.session == sessionId, "funnelSessionId сменился при перезаходе")

-- Следующий день по UTC: вернулся.
World.removePlayer(back)
World.advance(86400)
local nextDay = World.addPlayer(ONE, "Funnel1")
World.advance(2)
check(#loop(nextDay) == 1 and loop(nextDay)[1] == "6:ReturnedDay2", "вернулся на следующий день: " .. joined(loop(nextDay)))
check(#onboarding(nextDay) == 0, "возвращение шлёт обучение")
World.removePlayer(nextDay)
World.advance(86400 * 3)
local third = World.addPlayer(ONE, "Funnel1")
World.advance(2)
check(#loop(third) == 0, "ReturnedDay2 ушёл второй раз")
World.removePlayer(third)

-- Игрок 2: награда дня забрана заранее, шаги 4 и 5 закрываются одним действием, но уходят двумя ---------

print("— Шаги 4 и 5 обучения не склеиваются —")
local second = World.addPlayer(TWO, "Funnel2")
World.advance(2)
local data2 = DataService.get(second)
Remotes.ClaimDaily.OnServerEvent:Fire(second)
check(data2.tutorial.step == 1, "награда дня сдвинула обучение")
craft(second, 5)
data2.coins = 1e6
Remotes.BuyUpgrade.OnServerEvent:Fire(second, "speed")
check(data2.tutorial.step == 4, "перед замком не шаг 4: " .. data2.tutorial.step)
Actions.fire(second, "lock", 1)
check(data2.tutorial.step == #Tutorial.Steps + 1, "шаг 5 не закрылся сразу: " .. data2.tutorial.step)
local steps2 = onboarding(second)
check(joined(steps2) == "1:Joined 2:Step1_craft 3:Step2_craft 4:Step3_upgrade 5:Step4_lock 6:Step5_daily", "шаги 4 и 5: " .. joined(steps2))

-- Игрок 3: сохранение раньше действий, потом шаги идут по очереди ---------------------------------

print("— Сохранение раньше остальных шагов ждёт очереди —")
local third3 = World.addPlayer(THREE, "Funnel3")
World.advance(2)
local data3 = DataService.get(third3)
DataService.save(third3)
check(#loop(third3) == 0, "сохранение раньше первой капсулы ушло вне порядка: " .. joined(loop(third3)))
craft(third3, 1)
check(joined(loop(third3)) == "1:FirstCapsule", "после капсулы: " .. joined(loop(third3)))
data3.coins = 1e6
Remotes.BuyUpgrade.OnServerEvent:Fire(third3, "speed")
check(joined(loop(third3)) == "1:FirstCapsule", "улучшение до скрещивания и продажи ушло вне порядка")
data3.creatures = {}
FactoryService.give(third3, NORMIE, "normal")
sellAll(third3)
for _ = 1, 3 do
	FactoryService.give(third3, NORMIE, "normal")
end
Remotes.Fuse.OnServerEvent:Fire(third3, NORMIE_RARITY)
check(joined(loop(third3)) == "1:FirstCapsule 2:FirstFuse 3:FirstSale 4:FirstUpgrade 5:ProgressSaved", "цепочка по порядку: " .. joined(loop(third3)))

-- Игрок 6: единственное сохранение — финальное при выходе. Оно не считается шагом «прогресс сохранён»:
-- флаг не попал бы в запись, и шаг ушёл бы второй раз при следующем входе.
local leaver = World.addPlayer(SIX, "Funnel6")
World.advance(2)
local data6 = DataService.get(leaver)
craft(leaver, 1)
World.removePlayer(leaver)
check(data6.funnel.done.saved == nil, "финальное сохранение при выходе записано как шаг «прогресс сохранён»")
check(joined(loop(leaver)) == "1:FirstCapsule", "выход игрока: " .. joined(loop(leaver)))

-- Игрок 4: старое сохранение без воронки (играл до выпуска) ------------------------------------------

print("— Старое сохранение —")
World.removePlayer(third3)
local old = World.addPlayer(FOUR, "Funnel4")
World.advance(2)
local data4 = DataService.get(old)
data4.stats.crafted, data4.stats.sold, data4.stats.fused = 7, 3, 1
data4.upgrades.speed = 2
data4.tutorial.step = 3
data4.funnel = { onboarding = 0, loop = 0, done = {}, session = "" }
World.removePlayer(old)
World.advance(3600)
World.analytics = {}
local oldBack = World.addPlayer(FOUR, "Funnel4")
World.advance(2)
check(joined(onboarding(oldBack)) == "1:Joined 2:Step1_craft 3:Step2_craft", "старый игрок, обучение: " .. joined(onboarding(oldBack)))
check(joined(loop(oldBack)) == "1:FirstCapsule 2:FirstFuse 3:FirstSale 4:FirstUpgrade 5:ProgressSaved", "старый игрок, цикл: " .. joined(loop(oldBack)))
World.removePlayer(oldBack)

-- AnalyticsService упал: игра идёт дальше ---------------------------------------------------------------

print("— Падение AnalyticsService не ломает игру —")
World.analytics = {}
World.analyticsDown = true
local errorsBefore = #World.errors
local weak = World.addPlayer(FIVE, "Funnel5")
World.advance(2)
local data5 = DataService.get(weak)
check(data5 ~= nil, "при падении аналитики профиль не загрузился")
craft(weak, 5)
data5.coins = 1e6
Remotes.BuyUpgrade.OnServerEvent:Fire(weak, "speed")
Actions.fire(weak, "lock", 1)
Remotes.ClaimDaily.OnServerEvent:Fire(weak)
check(data5.stats.crafted == 5 and data5.upgrades.speed == 1, "игра не идёт при падении аналитики")
check(data5.tutorial.step == #Tutorial.Steps + 1, "обучение не идёт при падении аналитики: " .. data5.tutorial.step)
check(DataService.save(weak) == true, "сохранение не идёт при падении аналитики")
check(#World.analytics == 0, "заглушка записала вызовы при падении")
check(#World.errors == errorsBefore, "падение аналитики дало ошибки в коде: " .. (#World.errors - errorsBefore))
World.analyticsDown = false
craft(weak, 2)
Remotes.BuyUpgrade.OnServerEvent:Fire(weak, "speed")
check(#onboarding(weak) == 0 and #loop(weak) == 0, "после починки аналитики старые шаги ушли повторно")

check(#World.errors == 0, "ошибки в коде: " .. #World.errors)

if failures == 0 then
	print("✅ Воронки аналитики: пройдено проверок " .. checks)
else
	print("❌ Воронки аналитики: провалено проверок " .. failures)
	error("tests failed")
end
