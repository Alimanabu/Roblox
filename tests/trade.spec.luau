-- Обмен и платные случайные награды на настоящих сервере и клиенте. Viewer видит окно обмена,
-- Partner играет там, где можно, Blocked там, где Roblox запрещает платные случайные награды.
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

local VIEWER, PARTNER, BLOCKED, OLD_BUYER, OLD_FREE = 5001, 5002, 5003, 5004, 5005
World.restricted[BLOCKED] = true

-- Игроки раньше модулей: словарь узнаёт язык у игрока при загрузке.
local viewer = World.addPlayer(VIEWER, "Viewer")
local partner = World.addPlayer(PARTNER, "Partner")
local blocked = World.addPlayer(BLOCKED, "Blocked")

local S = shared_require("Strings")
local Monetization = shared_require("Config/Monetization")
local Formulas = shared_require("Util/Formulas")
local Capsules = shared_require("Config/Capsules")
local Creatures = shared_require("Config/Creatures")
local Daily = shared_require("Config/Daily")
local Rebirths = shared_require("Config/Rebirths")
local Upgrades = shared_require("Config/Upgrades")
local Skins = shared_require("Config/Skins")
local Format = shared_require("Util/Format")

-- В конфиге id = 0 (покупки ещё не созданы), поэтому номера подставляем только в памяти теста.
for index, pass in ipairs(Monetization.GamePasses) do
	pass.id = 2000 + index
end
for index, product in ipairs(Monetization.Products) do
	product.id = 1000 + index
	Monetization.ProductById[product.id] = product
end
local COINS_SMALL = Monetization.ProductByKey.COINS_SMALL
local LUCK_BOOST = Monetization.ProductByKey.LUCK_BOOST

local marketplace = World.services.MarketplaceService
local props = rawget(marketplace, "__state").props
props.UserOwnsGamePassAsync = function()
	return false
end

World.startServer()
World.startClient()
World.advance(5)

local DataService = shared_require("Services/DataService")
local FactoryService = shared_require("Services/FactoryService")
local MonetizationService = shared_require("Services/MonetizationService")
local RewardService = shared_require("Services/RewardService")
local ProgressionService = shared_require("Services/ProgressionService")
local TradeService = shared_require("Services/TradeService")
local Remotes = shared_require("Remotes")
local gui = viewer.PlayerGui

local CAPSULE = Capsules.get("old_meme")
local BANANA = "bananito_ninjini"
local FREE, COINS, LUCK, SPIN = Formulas.SOURCE_FREE, Formulas.SOURCE_COINS, Formulas.SOURCE_LUCK, Formulas.SOURCE_SPIN

local function fromPlayer(remote, player, ...)
	remote.OnServerEvent:Fire(player, ...)
end

local function hasText(part)
	for _, item in ipairs(gui:GetDescendants()) do
		if type(item.Text) == "string" and string.find(item.Text, part, 1, true) then
			return true
		end
	end
	return false
end

local purchaseId = 0
local function receipt(player, product)
	purchaseId += 1
	return marketplace.ProcessReceipt({ PlayerId = player.UserId, PurchaseId = "trade-" .. purchaseId, ProductId = product.id })
end

-- Капсула как у игрока: ждём перезарядку, на счёте ровно coins монет.
local function craft(player, coins)
	World.advance(10)
	local data = DataService.get(player)
	data.coins = coins or CAPSULE.cost
	local count = #data.creatures
	fromPlayer(Remotes.Craft, player, CAPSULE.id)
	check(#data.creatures == count + 1, player.Name .. ": капсула не открылась")
	return data.creatures[#data.creatures]
end

local function fuse(player, sources)
	local data = DataService.get(player)
	table.clear(data.creatures)
	for _, source in ipairs(sources) do
		local entry = FactoryService.give(player, BANANA, "normal", FREE)
		entry.source = source
	end
	fromPlayer(Remotes.Fuse, player, Creatures.get(BANANA).rarity)
	check(#data.creatures == 1, player.Name .. ": скрещивание не прошло")
	return data.creatures[1]
end

local function give(player, source)
	local entry = FactoryService.give(player, BANANA, "normal", FREE)
	entry.source = source
	return entry
end

local function owns(player, entry)
	for _, item in ipairs(DataService.get(player).creatures) do
		if item.uid == entry.uid then
			return true
		end
	end
	return false
end

local function reset()
	for _, player in ipairs({ viewer, partner, blocked }) do
		local data = DataService.get(player)
		table.clear(data.creatures)
		data.boughtCoins = 0
		data.boosts.luckUntil = 0
		data.boosts.paidLuckUntil = 0
		MonetizationService.passes(player).LUCKY = nil
		fromPlayer(Remotes.TradeCancel, player)
		player:SetAttribute("PaidRandomItemsRestricted", player == blocked)
	end
	World.advance(TradeService.REQUEST_COOLDOWN + 1)
end

local function openTrade(from, to)
	fromPlayer(Remotes.TradeRequest, from, to.UserId)
	fromPlayer(Remotes.TradeRespond, to, from.UserId, true)
	check(TradeService.isTrading(from) and TradeService.isTrading(to), "обмен не начался")
	World.advance(0.3)
end

local function finishTrade(a, b)
	fromPlayer(Remotes.TradeReady, a, true)
	fromPlayer(Remotes.TradeReady, b, true)
	World.advance(TradeService.CONFIRM_DELAY + 0.5)
end

local function playerById(userId)
	return World.services.Players:GetPlayerByUserId(userId)
end

local function lastNotify(player)
	for index = #World.sent, 1, -1 do
		local sent = World.sent[index]
		if sent.remote == "Notify" and sent.player == player then
			return S.text(sent.args[1])
		end
	end
	return ""
end

local function lastTradeState(player)
	for index = #World.sent, 1, -1 do
		local sent = World.sent[index]
		if sent.remote == "TradeState" and sent.player == player then
			return sent.args[1]
		end
	end
	return nil
end

local function closePanel()
	local close = World.find(gui, "✕")
	if close then
		World.click(close)
		World.advance(0.1)
	end
end

local function openPanel(key)
	closePanel()
	local button = World.find(gui, S.t(key))
	assert(button, "нет кнопки " .. key)
	World.click(button)
	World.advance(0.3)
end

-- Деньги игрока при запрете: на счету total, из них купленных bought.
local function restrictedWallet(player, total, bought)
	player:SetAttribute("PaidRandomItemsRestricted", true)
	local data = DataService.get(player)
	data.coins = total
	data.boughtCoins = bought
	DataService.sendNow(player)
	World.advance(0.3)
	return data
end

-- Все сектора колеса на время теста дают эту награду. Возвращает, чем вернуть как было.
local function spinRewards(reward)
	local saved = {}
	for index, slot in ipairs(Daily.Wheel) do
		saved[index] = slot.reward
		slot.reward = reward
	end
	return function()
		for index, slot in ipairs(Daily.Wheel) do
			slot.reward = saved[index]
		end
	end
end

local function paidSpin(player)
	local data = DataService.get(player)
	data.wheel.lastFreeDay = Daily.today()
	data.wheel.extraSpins = 1
	World.advance(5)
	fromPlayer(Remotes.SpinWheel, player)
	check(data.wheel.extraSpins == 0, "купленное вращение не прошло")
end

local function scenario(name, body)
	scenarios += 1
	local before = failures
	closePanel()
	reset()
	local ok, err = pcall(body)
	if not ok then
		failures += 1
		print("❌ " .. name .. ": " .. tostring(err))
	end
	print(string.format("  %s %d. %s", failures == before and "✅" or "❌", scenarios, name))
end

print("— Обмен и платные случайные награды (" .. World.locale .. ") —")

scenario("капсула за заработанные монеты: бесплатная", function()
	check(craft(viewer).source == FREE, "заработанные монеты: не free")
end)

scenario("капсула за купленные монеты: пометка, пока они не кончатся", function()
	local data = DataService.get(viewer)
	check(receipt(viewer, COINS_SMALL) == Enum.ProductPurchaseDecision.PurchaseGranted, "чек монет не подтверждён")
	check(data.boughtCoins == COINS_SMALL.minCoins, "купленные монеты не записаны: " .. tostring(data.boughtCoins))
	local entry = craft(viewer, COINS_SMALL.minCoins)
	check(entry.source == COINS, "купленные монеты: " .. tostring(entry.source))
	check(data.boughtCoins == COINS_SMALL.minCoins - CAPSULE.cost, "капсула не списала купленные: " .. tostring(data.boughtCoins))

	-- Купленных меньше цены капсулы: остаток доплачен заработанными, всё равно платная.
	data.boughtCoins = CAPSULE.cost - 1
	check(craft(viewer, CAPSULE.cost * 2).source == COINS, "частично купленные монеты: не coins")
	check(data.boughtCoins == 0, "купленные монеты не кончились: " .. tostring(data.boughtCoins))
	check(craft(viewer).source == FREE, "купленные кончились, а капсула платная")
end)

scenario("купленные монеты ушли на другое: капсула платная только на остаток", function()
	local data = DataService.get(viewer)
	data.boughtCoins = CAPSULE.cost * 10
	check(craft(viewer, CAPSULE.cost).source == COINS, "остаток купленных: не coins")
	check(data.boughtCoins == 0, "купленных больше, чем монет: " .. tostring(data.boughtCoins))
end)

scenario("купленный буст: пометка luck, бесплатный буст пометки не даёт", function()
	local data = DataService.get(viewer)
	RewardService.grant(viewer, data, { luckMinutes = 10 })
	check(data.boosts.luckUntil > os.time(), "бесплатный буст не включился")
	check(craft(viewer).source == FREE, "бесплатный буст пометил брейнрота")

	check(receipt(viewer, LUCK_BOOST) == Enum.ProductPurchaseDecision.PurchaseGranted, "чек буста не подтверждён")
	check(data.boosts.paidLuckUntil == data.boosts.luckUntil, "купленный буст не записан")
	check(craft(viewer).source == LUCK, "купленный буст: не luck")

	data.boosts.paidLuckUntil = os.time() - 1
	check(craft(viewer).source == FREE, "купленный буст кончился, а пометка осталась")
end)

scenario("LUCKY: пометка там, где действует; при запрете не входит в бросок и не метит", function()
	MonetizationService.passes(viewer).LUCKY = true
	MonetizationService.passes(blocked).LUCKY = true
	check(craft(viewer).source == LUCK, "LUCKY: не luck")
	check(craft(blocked).source == FREE, "при запрете LUCKY пометил брейнрота")
	-- Остаток купленного буста после смены региона в броске участвует, поэтому метит.
	DataService.get(blocked).boosts.luckUntil = os.time() + 60
	DataService.get(blocked).boosts.paidLuckUntil = os.time() + 60
	check(craft(blocked).source == LUCK, "остаток купленного буста: не luck")
end)

scenario("скрещивание наследует источник и не отмывает платных", function()
	check(fuse(viewer, { FREE, FREE, FREE }).source == FREE, "три бесплатных: не free")
	check(fuse(viewer, { FREE, COINS, FREE }).source == COINS, "один за купленные: не coins")
	check(fuse(viewer, { LUCK, FREE, FREE }).source == LUCK, "один с платной удачей: не luck")
	local data = DataService.get(viewer)
	table.clear(data.creatures)
	give(viewer, FREE)
	give(viewer, nil)
	give(viewer, FREE)
	fromPlayer(Remotes.Fuse, viewer, Creatures.get(BANANA).rarity)
	check(Formulas.isPaidRandom(data.creatures[1]), "неизвестный источник отмылся скрещиванием")
	MonetizationService.passes(viewer).LUCKY = true
	check(fuse(viewer, { FREE, FREE, FREE }).source == LUCK, "скрещивание с LUCKY: не luck")
end)

scenario("колесо: брейнрот с купленного вращения платный, с бесплатного нет", function()
	local saved = {}
	for index, slot in ipairs(Daily.Wheel) do
		saved[index] = slot.reward
		slot.reward = { creatureRarity = "sigma" }
	end
	local data = DataService.get(viewer)
	data.wheel.lastFreeDay = 0
	World.advance(5)
	fromPlayer(Remotes.SpinWheel, viewer)
	check(#data.creatures == 1 and data.creatures[1].source == FREE, "бесплатное вращение: не free")
	data.wheel.extraSpins = 1
	World.advance(5)
	fromPlayer(Remotes.SpinWheel, viewer)
	check(#data.creatures == 2 and data.creatures[2].source == SPIN, "купленное вращение: не spin")
	for index, slot in ipairs(Daily.Wheel) do
		slot.reward = saved[index]
	end
end)

scenario("награды и дикие брейнроты бесплатные", function()
	local entry = FactoryService.give(viewer, BANANA, "normal")
	check(entry.source == FREE, "выданный брейнрот: " .. tostring(entry.source))
end)

scenario("разрешённый не может отдать платного запрещённому: отказ и сообщение в окне", function()
	local entry = give(viewer, COINS)
	openTrade(viewer, blocked)
	fromPlayer(Remotes.TradeSetOffer, viewer, { entry.uid })
	World.advance(0.3)
	check(hasText(S.t("trade.random_them", { name = blocked.DisplayName })), "окно: нет объяснения отказа")
	check(hasText(S.t("trade.you_give", { count = 0 })), "окно: брейнрот попал в предложение")
	check(World.find(gui, S.t("trade.ready")) ~= nil, "окно: нет кнопки готовности")
	finishTrade(viewer, blocked)
	check(owns(viewer, entry), "платный брейнрот ушёл запрещённому")
	check(#DataService.get(blocked).creatures == 0, "запрещённый получил брейнрота")
end)

scenario("запрещённый не может отдать платного: отказ и сообщение в окне", function()
	viewer:SetAttribute("PaidRandomItemsRestricted", true)
	local entry = give(viewer, LUCK)
	openTrade(viewer, partner)
	fromPlayer(Remotes.TradeSetOffer, viewer, { entry.uid })
	World.advance(0.3)
	local text = S.t("trade.random_you")
	check(hasText(text), "окно: нет объяснения отказа")
	check(string.find(text, "{", 1, true) == nil, "незаполненный параметр: " .. text)
	finishTrade(viewer, partner)
	check(owns(viewer, entry), "запрещённый отдал платного брейнрота")
	check(#DataService.get(partner).creatures == 0, "партнёр получил брейнрота от запрещённого")
end)

scenario("сервер отвечает отказом любому читеру, а не только окну", function()
	local entry = give(blocked, SPIN)
	openTrade(viewer, blocked)
	fromPlayer(Remotes.TradeSetOffer, blocked, { entry.uid })
	World.advance(0.3)
	local state = lastTradeState(blocked)
	check(state and state.notice and state.notice.k == "trade.random_you", "запрещённому не объяснён отказ")
	check(state and #state.myOffer == 0, "предложение запрещённого принято")
	check(hasText(S.t("trade.they_give", { name = blocked.DisplayName })), "окно: нет колонки партнёра")
	finishTrade(viewer, blocked)
	check(owns(blocked, entry), "запрещённый отдал платного брейнрота через запрос")
end)

scenario("брейнрот с неизвестным источником считается платным", function()
	local entry = give(viewer, nil)
	openTrade(viewer, blocked)
	fromPlayer(Remotes.TradeSetOffer, viewer, { entry.uid })
	World.advance(0.3)
	check(hasText(S.t("trade.random_them", { name = blocked.DisplayName })), "неизвестный источник принят в обмен")
	finishTrade(viewer, blocked)
	check(owns(viewer, entry), "брейнрот с неизвестным источником ушёл запрещённому")
end)

scenario("запрещённый меняется бесплатными, отказ исчезает из окна", function()
	local paid = give(viewer, COINS)
	local mine = give(viewer, FREE)
	local theirs = give(blocked, FREE)
	openTrade(viewer, blocked)
	fromPlayer(Remotes.TradeSetOffer, viewer, { paid.uid })
	World.advance(0.3)
	check(hasText(S.t("trade.random_them", { name = blocked.DisplayName })), "окно: нет отказа")
	fromPlayer(Remotes.TradeSetOffer, viewer, { mine.uid })
	fromPlayer(Remotes.TradeSetOffer, blocked, { theirs.uid })
	World.advance(0.3)
	check(not hasText(S.t("trade.random_them", { name = blocked.DisplayName })), "окно: отказ не исчез")
	check(hasText(S.t("trade.you_give", { count = 1 })), "окно: бесплатный не принят")
	finishTrade(viewer, blocked)
	check(not owns(viewer, mine) and not owns(blocked, theirs), "бесплатный обмен не прошёл")
	check(owns(viewer, paid), "платный брейнрот ушёл вместе с бесплатным")
	local got = DataService.get(blocked).creatures
	check(#got == 1 and got[1].source == FREE, "запрещённый получил брейнрота без пометки")
end)

scenario("разрешённые меняются платными, пометка едет с брейнротом и не отмывается", function()
	local entry = give(viewer, COINS)
	openTrade(viewer, partner)
	fromPlayer(Remotes.TradeSetOffer, viewer, { entry.uid })
	finishTrade(viewer, partner)
	local got = DataService.get(partner).creatures
	check(#got == 1, "обмен разрешённых не прошёл")
	check(got[1] and got[1].source == COINS, "обмен стёр пометку: " .. tostring(got[1] and got[1].source))

	World.advance(TradeService.REQUEST_COOLDOWN + 1)
	openTrade(partner, blocked)
	fromPlayer(Remotes.TradeSetOffer, partner, { got[1].uid })
	finishTrade(partner, blocked)
	check(#DataService.get(blocked).creatures == 0, "платный брейнрот дошёл до запрещённого через друга")
end)

scenario("запрет пришёл во время отсчёта: обмен отменён, все при своих", function()
	local entry = give(viewer, COINS)
	openTrade(viewer, partner)
	fromPlayer(Remotes.TradeSetOffer, viewer, { entry.uid })
	World.advance(0.3)
	fromPlayer(Remotes.TradeReady, viewer, true)
	fromPlayer(Remotes.TradeReady, partner, true)
	partner:SetAttribute("PaidRandomItemsRestricted", true)
	World.advance(TradeService.CONFIRM_DELAY + 0.5)
	check(owns(viewer, entry), "обмен прошёл при запрете")
	check(#DataService.get(partner).creatures == 0, "запрещённый получил платного брейнрота")
	check(not TradeService.isTrading(viewer), "обмен не закрыт")
	local text = lastNotify(viewer)
	check(string.find(text, S.t("trade.err_random"), 1, true) ~= nil, "нет причины отмены: " .. text)
end)

scenario("тексты отказа на языке игрока", function()
	local russian = World.locale == "ru-ru"
	for _, key in ipairs({ "trade.random_you", "trade.random_them", "trade.err_random", "shop.bought_coins" }) do
		local hasRussian = string.find(S.t(key, { name = "X" }), "[\208\209]") ~= nil
		check(hasRussian == russian, key .. ": не тот язык: " .. S.t(key, { name = "X" }))
	end
end)

print("— Купленные монеты при запрете —")

scenario("капсула на купленные монеты при запрете: отказ сервера и объяснение в окне", function()
	local data = restrictedWallet(viewer, CAPSULE.cost, CAPSULE.cost)
	openPanel("hud.factory")
	check(hasText(S.t("shop.bought_coins")), "окно фабрики: нет объяснения")
	World.advance(10)
	data.coins = CAPSULE.cost
	World.click(World.find(gui, S.t("factory.craft", { cost = Format.coins(CAPSULE.cost) })))
	World.advance(0.3)
	check(#data.creatures == 0, "капсула открылась на купленные монеты")
	check(data.coins == CAPSULE.cost and data.boughtCoins == CAPSULE.cost, "монеты списаны при отказе")
	check(lastNotify(viewer) == S.t("shop.bought_coins"), "нет сообщения сервера: " .. lastNotify(viewer))
end)

scenario("заработанных не хватает одной монеты: отказ", function()
	local data = restrictedWallet(blocked, CAPSULE.cost + 299, 300)
	World.advance(10)
	data.coins = CAPSULE.cost + 299
	fromPlayer(Remotes.Craft, blocked, CAPSULE.id)
	check(#data.creatures == 0, "капсула открылась без заработанных")
end)

scenario("заработанных хватает: капсула бесплатная, купленные остаются", function()
	local data = restrictedWallet(blocked, CAPSULE.cost + 300, 300)
	World.advance(10)
	data.coins = CAPSULE.cost + 300
	fromPlayer(Remotes.Craft, blocked, CAPSULE.id)
	check(#data.creatures == 1 and data.creatures[1].source == FREE, "капсула на заработанные: не free")
	check(data.coins == 300, "списано не столько: " .. tostring(data.coins))
	check(data.boughtCoins == 300, "капсула съела купленные: " .. tostring(data.boughtCoins))
end)

scenario("без запрета купленные тратятся как раньше, объяснения в окне нет", function()
	local data = DataService.get(viewer)
	data.coins = CAPSULE.cost
	data.boughtCoins = CAPSULE.cost
	DataService.sendNow(viewer)
	World.advance(0.3)
	openPanel("hud.factory")
	check(not hasText(S.t("shop.bought_coins")), "окно: объяснение без запрета")
	check(craft(viewer).source == COINS, "разрешённому отказано в купленных монетах")
end)

scenario("авто-фабрика при запрете не тратит купленные монеты", function()
	MonetizationService.passes(blocked).AUTO_CRAFT = true
	local data = restrictedWallet(blocked, CAPSULE.cost * 3, CAPSULE.cost * 3)
	fromPlayer(Remotes.SetAutoCraft, blocked, CAPSULE.id)
	World.advance(20)
	fromPlayer(Remotes.SetAutoCraft, blocked, nil)
	MonetizationService.passes(blocked).AUTO_CRAFT = nil
	check(#data.creatures == 0, "авто-фабрика открыла капсулу на купленные монеты")
end)

scenario("улучшение удачи при запрете только на заработанные, с объяснением в окне", function()
	local cost = Upgrades.cost("luck", 0)
	local data = restrictedWallet(viewer, cost, cost)
	openPanel("hud.upgrades")
	check(hasText(S.t("shop.bought_coins")), "окно улучшений: нет объяснения")
	fromPlayer(Remotes.BuyUpgrade, viewer, "luck")
	check(data.upgrades.luck == 0, "удача куплена за купленные монеты")
	check(data.coins == cost, "монеты списаны при отказе")
	check(lastNotify(viewer) == S.t("shop.bought_coins"), "нет сообщения сервера: " .. lastNotify(viewer))

	data = restrictedWallet(viewer, cost + 7, 7)
	fromPlayer(Remotes.BuyUpgrade, viewer, "luck")
	check(data.upgrades.luck == 1, "удача не куплена за заработанные")
	check(data.boughtCoins == 7, "купленные потрачены: " .. tostring(data.boughtCoins))
	data.upgrades.luck = 0
end)

scenario("при запрете прямые покупки идут за купленные и прижимают счётчик", function()
	local speed = Upgrades.cost("speed", 0)
	local data = restrictedWallet(blocked, speed, speed)
	fromPlayer(Remotes.BuyUpgrade, blocked, "speed")
	check(data.upgrades.speed == 1, "скорость не куплена")
	check(data.boughtCoins == 0, "счётчик выше монет после улучшения: " .. tostring(data.boughtCoins))
	data.upgrades.speed = 0

	local floors = data.floors
	local cost = Formulas.floorCost(floors, MonetizationService.passes(blocked))
	data = restrictedWallet(blocked, cost, cost)
	ProgressionService.buyFloor(blocked)
	check(data.floors == floors + 1, "этаж не построен")
	check(data.boughtCoins == 0, "счётчик выше монет после этажа: " .. tostring(data.boughtCoins))
	data.floors = floors

	local skin
	for _, candidate in ipairs(Skins.List) do
		if candidate.price and not data.skins[candidate.id] then
			skin = candidate
			break
		end
	end
	data = restrictedWallet(blocked, skin.price, skin.price)
	fromPlayer(Remotes.BuySkin, blocked, skin.id)
	check(data.skins[skin.id] == true, "скин не куплен")
	check(data.boughtCoins == 0, "счётчик выше монет после скина: " .. tostring(data.boughtCoins))
end)

scenario("перерождение при запрете: окно объясняет, сервер отказывает", function()
	local data = DataService.get(viewer)
	data.level = Rebirths.levelRequired(data.rebirths)
	local cost = Rebirths.cost(data.rebirths)
	restrictedWallet(viewer, cost, cost)
	openPanel("hud.rebirth")
	check(hasText(S.t("shop.bought_coins")), "окно перерождения: нет объяснения")
	-- До запроса монеты могли вырасти: новый уровень приносит награды.
	local before = data.coins
	fromPlayer(Remotes.Rebirth, viewer)
	check(data.rebirths == 0, "перерождение за купленные монеты")
	check(data.coins == before, "монеты сгорели при отказе: " .. tostring(data.coins))
	check(lastNotify(viewer) == S.t("shop.bought_coins"), "нет сообщения сервера: " .. lastNotify(viewer))
end)

scenario("монеты с купленного вращения считаются купленными, с бесплатного нет", function()
	local restore = spinRewards({ coins = 400 })
	local data = DataService.get(viewer)
	paidSpin(viewer)
	check(data.boughtCoins == 400, "монеты с купленного вращения: " .. tostring(data.boughtCoins))
	data.boughtCoins = 0
	data.wheel.lastFreeDay = 0
	World.advance(5)
	fromPlayer(Remotes.SpinWheel, viewer)
	check(data.wheel.lastFreeDay == Daily.today(), "бесплатное вращение не прошло")
	check(data.boughtCoins == 0, "монеты с бесплатного вращения: " .. tostring(data.boughtCoins))
	restore()
end)

scenario("буст с купленного вращения купленный и метит брейнрота", function()
	local restore = spinRewards({ luckMinutes = 10 })
	local data = DataService.get(viewer)
	paidSpin(viewer)
	check(data.boosts.paidLuckUntil == data.boosts.luckUntil, "буст с вращения не купленный")
	check(craft(viewer).source == LUCK, "буст с вращения не метит брейнрота")
	data.boosts.luckUntil, data.boosts.paidLuckUntil = 0, 0
	data.wheel.lastFreeDay = 0
	World.advance(5)
	fromPlayer(Remotes.SpinWheel, viewer)
	check(data.boosts.luckUntil > 0 and data.boosts.paidLuckUntil == 0, "бесплатный буст с вращения стал купленным")
	restore()
end)

scenario("база полна: монеты вместо брейнрота с купленного вращения тоже купленные", function()
	local restore = spinRewards({ creatureRarity = "sigma" })
	local data = DataService.get(viewer)
	local slots = Formulas.slots(data, MonetizationService.passes(viewer))
	for _ = 1, slots do
		give(viewer, FREE)
	end
	paidSpin(viewer)
	check(#data.creatures == slots, "брейнрот выдан на полную базу")
	check(data.boughtCoins > 0, "монеты вместо брейнрота не купленные")
	restore()
end)

print("— Старые сохранения —")

local store = World.services.DataStoreService:GetDataStore("BrainrotFactory_v1")
local function oldSave(receipts, luckUntil)
	return {
		coins = 777,
		rebirths = 0,
		nextUid = 3,
		receipts = receipts,
		boosts = { luckUntil = luckUntil },
		creatures = {
			{ uid = "1", id = BANANA, mut = "normal" },
			{ uid = "2", id = BANANA, mut = "normal" },
		},
	}
end

scenario("старое сохранение с покупками: брейнроты за купленные, монеты и буст тоже", function()
	local luckUntil = os.time() + 300
	store:SetAsync("player_" .. OLD_BUYER, oldSave({ "old-1" }, luckUntil))
	local player = World.addPlayer(OLD_BUYER, "OldBuyer")
	World.advance(1)
	local data = DataService.get(player)
	for _, entry in ipairs(data.creatures) do
		check(entry.source == COINS, "старый покупатель: " .. tostring(entry.source))
	end
	check(#data.creatures == 2, "старые брейнроты потеряны")
	check(data.boughtCoins >= 777, "старые монеты не считаются купленными: " .. tostring(data.boughtCoins))
	check(data.boosts.paidLuckUntil == luckUntil, "старый буст не считается купленным")
	World.removePlayer(player)
	World.advance(1)
end)

scenario("старое сохранение без покупок: всё бесплатное", function()
	store:SetAsync("player_" .. OLD_FREE, oldSave({}, 0))
	local player = World.addPlayer(OLD_FREE, "OldFree")
	World.advance(1)
	local data = DataService.get(player)
	for _, entry in ipairs(data.creatures) do
		check(entry.source == FREE, "старый бесплатный: " .. tostring(entry.source))
	end
	check(data.boughtCoins == 0, "купленные монеты без покупок: " .. tostring(data.boughtCoins))
end)

scenario("перенос один раз: запись без пометки не становится бесплатной при перезаходе", function()
	local player = playerById(OLD_FREE)
	local data = DataService.get(player)
	data.creatures[1].source = nil
	data.boughtCoins = 123
	World.removePlayer(player)
	World.advance(1)
	player = World.addPlayer(OLD_FREE, "OldFree")
	World.advance(1)
	data = DataService.get(player)
	check(data.creatures[1].source == nil, "пометка выдумана при перезаходе: " .. tostring(data.creatures[1].source))
	check(data.creatures[2].source == FREE, "пометка потеряна при перезаходе")
	check(data.boughtCoins == 123, "купленные монеты потеряны при перезаходе: " .. tostring(data.boughtCoins))
end)

scenario("перерождение обнуляет купленные монеты", function()
	local player = playerById(OLD_FREE)
	local data = DataService.get(player)
	data.boughtCoins = 123
	data.level = Rebirths.levelRequired(data.rebirths)
	data.coins = Rebirths.cost(data.rebirths)
	fromPlayer(Remotes.Rebirth, player)
	check(data.rebirths == 1, "перерождение не прошло")
	check(data.boughtCoins == 0, "купленные монеты пережили перерождение: " .. tostring(data.boughtCoins))
end)

check(#World.errors == 0, "ошибки в коде: " .. #World.errors)

if failures == 0 then
	print("✅ Обмен: пройдено сценариев " .. scenarios)
else
	print("❌ Обмен: провалено проверок " .. failures)
	error("tests failed")
end
