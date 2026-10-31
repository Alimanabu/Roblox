-- Симуляция с покупками: игрок купил VIP, 2 этаж, монеты и вращения, ушёл, вернулся. Настоящие сервисы,
-- боевой режим (не Studio), DataStore в памяти переживает выход игрока.

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

local Monetization = shared_require("Config/Monetization")
local Formulas = shared_require("Util/Formulas")

-- В конфиге id = 0 (геймпассы ещё не созданы), поэтому номера подставляем только в памяти теста.
for index, pass in ipairs(Monetization.GamePasses) do
	pass.id = 2000 + index
end
local VIP = Monetization.GamePassByKey.VIP
for index, product in ipairs(Monetization.Products) do
	product.id = 1000 + index
	Monetization.ProductById[product.id] = product
end
local COINS_SMALL = Monetization.ProductByKey.COINS_SMALL
local SPINS = Monetization.ProductByKey.SPINS_3
local Decision = Enum.ProductPurchaseDecision

local marketplace = World.services.MarketplaceService
local owned = {}
rawget(marketplace, "__state").props.UserOwnsGamePassAsync = function(_, userId, passId)
	return owned[userId .. ":" .. passId] == true
end

World.startServer()
local DataService = shared_require("Services/DataService")
local MonetizationService = shared_require("Services/MonetizationService")
local ProgressionService = shared_require("Services/ProgressionService")
local PlotService = shared_require("Services/PlotService")
local FactoryService = shared_require("Services/FactoryService")

local USER = 3001
local START_COINS = 500e6

print("— Покупки сохраняются после перезахода —")
local player = World.addPlayer(USER, "Buyer")
World.advance(2)

local data = DataService.get(player)
check(data ~= nil, "профиль не загрузился")
check(MonetizationService.passes(player).VIP == nil, "VIP есть до покупки")
check(Formulas.floors(data, MonetizationService.passes(player)) == 0, "этажи есть до покупки")
check(Formulas.slots(data, MonetizationService.passes(player)) == 5, "до покупки не 5 мест")
local multiplierBefore = Formulas.incomeMultiplier(data, MonetizationService.passes(player))

-- Покупка VIP: Roblox отвечает «куплено», дальше владение подтверждает его сервер.
owned[USER .. ":" .. VIP.id] = true
marketplace.PromptGamePassPurchaseFinished:Fire(player, VIP.id, true)
World.advance(0.5)
check(MonetizationService.passes(player).VIP == true, "VIP не выдан после покупки")

-- 1 и 2 этаж за монеты.
data.coins = START_COINS
ProgressionService.buyFloor(player)
ProgressionService.buyFloor(player)
World.advance(0.5)
check(data.floors == 2, "2 этаж не построен: " .. tostring(data.floors))
check(data.coins == START_COINS - 100e3 - 100e6, "этажи стоят не столько: " .. tostring(data.coins))

-- Разовые покупки идут так, как их присылает Roblox: чеком. Брейнротов ещё нет, дохода нет,
-- поэтому мешок монет даёт ровно свой минимум.
local function receipt(purchaseId, product)
	return marketplace.ProcessReceipt({ PlayerId = USER, PurchaseId = purchaseId, ProductId = product.id })
end
local COINS_AFTER_FLOORS = 399900000
local COINS_AFTER_RECEIPT = COINS_AFTER_FLOORS + COINS_SMALL.minCoins
check(data.coins == COINS_AFTER_FLOORS, "монеты до чека: " .. tostring(data.coins))
check(receipt("rejoin-coins", COINS_SMALL) == Decision.PurchaseGranted, "чек монет не подтверждён")
check(receipt("rejoin-spins", SPINS) == Decision.PurchaseGranted, "чек вращений не подтверждён")
check(data.coins == COINS_AFTER_RECEIPT, "монеты после чека: " .. tostring(data.coins))
check(data.wheel.extraSpins == SPINS.amount, "вращения после чека: " .. tostring(data.wheel.extraSpins))

FactoryService.give(player, "bananito_ninjini", "normal")
local coinsBefore = data.coins
local creaturesBefore = #data.creatures

World.removePlayer(player)
World.advance(5)
check(DataService.get(player) == nil, "профиль остался после выхода")

local back = World.addPlayer(USER, "Buyer")
-- Читаем сразу: с первой же секунды в игре брейнрот начнёт приносить монеты.
local loaded = DataService.get(back)
check(loaded ~= nil, "профиль не загрузился после перезахода")
check(coinsBefore == COINS_AFTER_RECEIPT, "монеты перед уходом: " .. tostring(coinsBefore))
check(loaded.coins == coinsBefore, "монеты после перезахода: " .. tostring(loaded.coins))
check(loaded.wheel.extraSpins == SPINS.amount, "вращения после перезахода: " .. tostring(loaded.wheel.extraSpins))
check(DataService.hasReceipt(loaded, "rejoin-coins"), "чек монет потерян")
check(DataService.hasReceipt(loaded, "rejoin-spins"), "чек вращений потерян")

-- Roblox повторил чеки: второй выдачи нет.
check(receipt("rejoin-coins", COINS_SMALL) == Decision.PurchaseGranted, "повтор чека монет не подтверждён")
check(receipt("rejoin-spins", SPINS) == Decision.PurchaseGranted, "повтор чека вращений не подтверждён")
check(loaded.coins == coinsBefore, "повтор чека выдал монеты второй раз: " .. tostring(loaded.coins))
check(loaded.wheel.extraSpins == SPINS.amount, "повтор чека выдал вращения второй раз: " .. tostring(loaded.wheel.extraSpins))
World.advance(2)
check(rawequal(loaded, data) == false, "профиль не прочитан заново из сохранения")
local passes = MonetizationService.passes(back)
check(passes.VIP == true, "VIP потерян после перезахода")
check(loaded.floors == 2, "2 этаж потерян после перезахода: " .. tostring(loaded.floors))
check(Formulas.floors(loaded, passes) == 2, "этажи не считаются после перезахода")
check(Formulas.slots(loaded, passes) == 20, "мест не 20: " .. tostring(Formulas.slots(loaded, passes)))
check(#loaded.creatures == creaturesBefore, "брейнроты потеряны после перезахода")
check(Formulas.incomeMultiplier(loaded, passes) == multiplierBefore * 2, "VIP не даёт x2 после перезахода")
check(Formulas.floorCost(2, passes) == nil, "после перезахода снова предлагает строить")
ProgressionService.buyFloor(back)
check(loaded.floors == 2, "этаж построен сверх максимума")
check(PlotService.getPlot(back).builtFloors == 2, "база не перестроена после перезахода")
check(#World.errors == 0, "ошибки в коде: " .. #World.errors)

if failures == 0 then
	print("✅ Перезаход: пройдено проверок " .. checks)
else
	print("❌ Перезаход: провалено проверок " .. failures)
	error("tests failed")
end
