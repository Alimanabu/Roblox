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

local function scenario(name, body)
	scenarios += 1
	local before = failures
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
	for _, key in ipairs({ "trade.random_you", "trade.random_them", "trade.err_random" }) do
		local hasRussian = string.find(S.t(key, { name = "X" }), "[\208\209]") ~= nil
		check(hasRussian == russian, key .. ": не тот язык: " .. S.t(key, { name = "X" }))
	end
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
