-- Платные случайные награды на настоящих сервере и клиенте: один игрок в разрешённом регионе,
-- второй там, где Roblox их запрещает. Запрещённому никто не помогает с клиента: запросы идут
-- прямо на сервер, как у читера.

local failures = 0
local scenarios = 0
local function check(cond, msg)
	if not cond then
		failures += 1
		print("❌ " .. msg)
	end
end

local Monetization = shared_require("Config/Monetization")
local Formulas = shared_require("Util/Formulas")
local Format = shared_require("Util/Format")
local Capsules = shared_require("Config/Capsules")
local Daily = shared_require("Config/Daily")
local Rarities = shared_require("Config/Rarities")
local S = shared_require("Strings")

-- В конфиге id = 0 (покупки ещё не созданы), поэтому номера подставляем только в памяти теста.
for index, pass in ipairs(Monetization.GamePasses) do
	pass.id = 2000 + index
end
for index, product in ipairs(Monetization.Products) do
	product.id = 1000 + index
	Monetization.ProductById[product.id] = product
end
local LUCKY = Monetization.GamePassByKey.LUCKY

local ALLOWED, BLOCKED = 4001, 4002
World.restricted[BLOCKED] = true

local marketplace = World.services.MarketplaceService
local props = rawget(marketplace, "__state").props
props.UserOwnsGamePassAsync = function(_, _, passId)
	return passId == LUCKY.id
end
local prompts = {}
props.PromptGamePassPurchase = function(_, _, id)
	table.insert(prompts, id)
end
props.PromptProductPurchase = function(_, _, id)
	table.insert(prompts, id)
end

-- Сервер бросает шансы через Formulas: запоминаем удачу, с которой он это сделал.
local usedLuck = {}
local rollRarity, rollMutation = Formulas.rollRarity, Formulas.rollMutation
Formulas.rollRarity = function(capsule, luck, rng, mods)
	usedLuck.rarity = luck
	return rollRarity(capsule, luck, rng, mods)
end
Formulas.rollMutation = function(luck, rng, mods)
	usedLuck.mutation = luck
	return rollMutation(luck, rng, mods)
end

local allowed = World.addPlayer(ALLOWED, "Allowed")
local blocked = World.addPlayer(BLOCKED, "Blocked")
World.startServer()
World.startClient()
World.advance(5)

local DataService = shared_require("Services/DataService")
local FactoryService = shared_require("Services/FactoryService")
local Remotes = shared_require("Remotes")
local gui = allowed.PlayerGui

local function fromPlayer(remote, player, ...)
	remote.OnServerEvent:Fire(player, ...)
end

local function texts()
	local out = {}
	for _, item in ipairs(gui:GetDescendants()) do
		if type(item.Text) == "string" and item.Text ~= "" then
			table.insert(out, item.Text)
		end
	end
	return out
end

local function hasText(part)
	for _, text in ipairs(texts()) do
		if text:find(part, 1, true) then
			return true
		end
	end
	return false
end

local function openPanel(key)
	local button = World.find(gui, S.t(key))
	assert(button, "нет кнопки " .. key)
	World.click(button)
	World.advance(0.3)
end

-- Окна открываются и закрываются повторным нажатием: начинаем с закрытого.
local function closePanel()
	local close = World.find(gui, "✕")
	if close then
		World.click(close)
		World.advance(0.1)
	end
end

local function setClientRestricted(value)
	allowed:SetAttribute("PaidRandomItemsRestricted", value)
	DataService.sendNow(allowed)
	World.advance(0.3)
end

local function scenario(name, body)
	scenarios += 1
	local before = failures
	closePanel()
	local ok, err = pcall(body)
	if not ok then
		failures += 1
		print("❌ " .. name .. ": " .. tostring(err))
	end
	closePanel()
	print(string.format("  %s %d. %s", failures == before and "✅" or "❌", scenarios, name))
end

print("— Платные случайные награды —")

scenario("Roblox запретил: атрибут стоит только у запрещённого игрока", function()
	check(allowed:GetAttribute("PaidRandomItemsRestricted") == false, "разрешённому поставлен запрет")
	check(blocked:GetAttribute("PaidRandomItemsRestricted") == true, "запрещённому нет запрета")
end)

scenario("капсула: при запрете LUCKY не входит в бросок редкости и мутации", function()
	for _, case in ipairs({ { allowed, 1.5 }, { blocked, 1 } }) do
		local player, luck = case[1], case[2]
		local data = DataService.get(player)
		data.coins = 1000
		usedLuck = {}
		World.advance(5)
		fromPlayer(Remotes.Craft, player, "old_meme")
		check(usedLuck.rarity == luck, player.Name .. ": удача редкости " .. tostring(usedLuck.rarity))
		check(usedLuck.mutation == luck, player.Name .. ": удача мутации " .. tostring(usedLuck.mutation))
	end
end)

scenario("скрещивание: при запрете LUCKY не входит в мутацию", function()
	for _, case in ipairs({ { allowed, 1.5 }, { blocked, 1 } }) do
		local player, luck = case[1], case[2]
		local data = DataService.get(player)
		table.clear(data.creatures)
		for _ = 1, 3 do
			FactoryService.give(player, "bananito_ninjini", "normal")
		end
		local rarity = shared_require("Config/Creatures").get("bananito_ninjini").rarity
		usedLuck = {}
		fromPlayer(Remotes.Fuse, player, rarity)
		check(usedLuck.mutation == luck, player.Name .. ": удача скрещивания " .. tostring(usedLuck.mutation))
		check(#data.creatures == 1, player.Name .. ": скрещивание не прошло")
		table.clear(data.creatures)
	end
end)

scenario("гарантия «через N»: срабатывает и при запрете, удача не меняет порог", function()
	local capsule = Capsules.get("old_meme")
	local top = Formulas.pityRarity(capsule)
	for _, player in ipairs({ allowed, blocked }) do
		local data = DataService.get(player)
		table.clear(data.creatures)
		data.coins = 1000
		data.pity[capsule.id] = Formulas.pityThreshold(capsule) - 1
		World.advance(5)
		fromPlayer(Remotes.Craft, player, capsule.id)
		local creature = shared_require("Config/Creatures").get(data.creatures[1].id)
		check(Rarities.get(creature.rarity).rank >= Rarities.get(top).rank, player.Name .. ": гарантия не сработала")
		check(data.pity[capsule.id] == 0, player.Name .. ": счётчик гарантии не сброшен")
		table.clear(data.creatures)
	end
end)

scenario("бесплатный буст удачи при запрете работает, LUCKY нет", function()
	local data = DataService.get(blocked)
	data.boosts.luckUntil = os.time() + 600
	data.coins = 1000
	usedLuck = {}
	World.advance(5)
	fromPlayer(Remotes.Craft, blocked, "old_meme")
	check(usedLuck.rarity == Formulas.LUCK_BOOST_MULT, "удача при бесплатном бусте: " .. tostring(usedLuck.rarity))
	data.boosts.luckUntil = 0
	table.clear(data.creatures)
end)

scenario("колесо: при запрете купленные вращения не тратятся, бесплатное работает", function()
	local data = DataService.get(blocked)
	data.wheel.extraSpins = 3
	data.wheel.lastFreeDay = Daily.today()
	World.advance(5)
	fromPlayer(Remotes.SpinWheel, blocked)
	check(data.wheel.extraSpins == 3, "запрет: потрачено купленное вращение")

	data.wheel.lastFreeDay = 0
	fromPlayer(Remotes.SpinWheel, blocked)
	check(data.wheel.lastFreeDay == Daily.today(), "запрет: бесплатное вращение не прошло")
	check(data.wheel.extraSpins == 3, "запрет: бесплатное вращение съело купленное")

	local free = DataService.get(allowed)
	free.wheel.extraSpins = 3
	free.wheel.lastFreeDay = Daily.today()
	World.advance(5)
	fromPlayer(Remotes.SpinWheel, allowed)
	check(free.wheel.extraSpins == 2, "разрешено: купленное вращение не потрачено")
end)

scenario("экран без запрета: цены, кнопка шансов, удача с LUCKY", function()
	World.advance(1)
	openPanel("hud.factory")
	check(hasText("x1.50"), "фабрика: удача без LUCKY")
	check(World.find(gui, S.t("odds.open")) ~= nil, "фабрика: нет кнопки шансов")
	check(hasText(S.t("odds.rounded")), "фабрика: нет оговорки об округлении")
	closePanel()
	openPanel("hud.shop")
	check(World.find(gui, "R$ 49") ~= nil, "магазин: буст удачи не продаётся")
	check(World.find(gui, S.t("shop.owned")) ~= nil, "магазин: LUCKY не куплен")
	check(hasText(S.t("product.LUCK_BOOST.name") .. " "), "магазин: нет чисел усилителей")
	table.clear(prompts)
	World.click(World.find(gui, "R$ 49"))
	check(prompts[1] == Monetization.ProductByKey.LUCK_BOOST.id, "магазин: окно покупки не открылось")
end)

scenario("экран при запрете: LUCKY и всё со случайностью недоступны", function()
	setClientRestricted(true)
	openPanel("hud.factory")
	check(hasText("x1.00"), "фабрика: удача показана с LUCKY")
	closePanel()
	openPanel("hud.shop")
	local regionButtons = 0
	for _, button in ipairs(World.buttons(gui)) do
		if button.Text == S.t("shop.region") then
			regionButtons += 1
			table.clear(prompts)
			World.click(button)
			check(#prompts == 0, "магазин: запрещённая покупка открыла окно")
		end
	end
	check(regionButtons == 5, "магазин: недоступно кнопок " .. regionButtons .. " вместо 5")
	check(World.find(gui, S.t("shop.owned")) == nil, "магазин: LUCKY показан как действующий")
	check(World.find(gui, "R$ 199") ~= nil, "магазин: VIP пропал")
	for _, price in ipairs({ "R$ 49", "R$ 29", "R$ 39", "R$ 129", "R$ 249" }) do
		check(World.find(gui, price) == nil, "магазин: при запрете продаётся " .. price)
	end
	setClientRestricted(false)
end)

scenario("награды при запрете: купленные вращения не предлагаются", function()
	local data = DataService.get(allowed)
	data.wheel.extraSpins = 2
	data.wheel.lastFreeDay = Daily.today()
	setClientRestricted(true)
	openPanel("hud.rewards")
	check(World.find(gui, S.t("rewards.spin", { count = 2 })) == nil, "награды: предложено купленное вращение")
	check(World.find(gui, S.t("rewards.spin_tomorrow")) ~= nil, "награды: нет подписи про завтра")
	setClientRestricted(false)
	check(World.find(gui, S.t("rewards.spin", { count = 2 })) ~= nil, "награды: без запрета нет вращений")
end)

scenario("окно шансов: числа совпадают с формулами для каждого усилителя", function()
	local data = DataService.get(allowed)
	data.pity = {}
	data.boosts.luckUntil = 0
	-- Без LUCKY и буста видны все столбцы.
	shared_require("Services/MonetizationService").passes(allowed).LUCKY = nil
	DataService.sendNow(allowed)
	World.advance(0.3)
	openPanel("hud.factory")
	World.click(World.find(gui, S.t("odds.open")))
	World.advance(0.3)

	local capsule = Capsules.get("old_meme")
	local lucks = { 1, Formulas.LUCKY_MULT, Formulas.LUCK_BOOST_MULT, Formulas.LUCKY_MULT * Formulas.LUCK_BOOST_MULT }
	for index, entry in ipairs(Formulas.rarityChances(capsule, 1)) do
		local values = {}
		for _, luck in ipairs(lucks) do
			table.insert(values, Format.percent(Formulas.rarityChances(capsule, luck)[index].chance))
		end
		check(hasText(table.concat(values, " → ")), "шансы " .. entry.rarity .. ": нет строки " .. table.concat(values, " → "))
	end
	for index, entry in ipairs(Formulas.mutationChances(1)) do
		local values = {}
		for _, luck in ipairs(lucks) do
			table.insert(values, Format.percent(Formulas.mutationChances(luck)[index].chance))
		end
		check(hasText(table.concat(values, " → ")), "мутации " .. entry.mutation .. ": нет строки")
	end
	check(hasText(S.t("pass.LUCKY.name") .. " → " .. S.t("product.LUCK_BOOST.name")), "шансы: нет подписи столбцов")
	check(hasText(S.t("odds.fuse", { count = Formulas.FUSE_COUNT })), "шансы: нет скрещивания")
	check(hasText(S.t("odds.pity")), "шансы: нет гарантии")
	check(not hasText(" in 67"), "шансы: остались дроби вместо процентов")
	for _, text in ipairs(texts()) do
		check(not text:find("{", 1, true), "шансы: незаполненный параметр: " .. text)
	end
end)

scenario("окно шансов на гарантированной попытке показывает гарантию", function()
	local data = DataService.get(allowed)
	local capsule = Capsules.get("old_meme")
	data.pity[capsule.id] = Formulas.pityThreshold(capsule) - 1
	DataService.sendNow(allowed)
	World.advance(0.3)
	openPanel("hud.factory")
	World.click(World.find(gui, S.t("odds.open")))
	World.advance(0.3)
	local top = Formulas.rarityChances(capsule, 1, nil, data.pity[capsule.id])[1]
	check(top.rarity == Formulas.pityRarity(capsule), "гарантия: первым идёт не редкость гарантии")
	check(hasText(Format.percent(top.chance)), "окно шансов: нет гарантированного шанса " .. Format.percent(top.chance))
	data.pity = {}
end)

scenario("окно шансов при запрете: нет столбцов платной удачи", function()
	setClientRestricted(true)
	openPanel("hud.factory")
	World.click(World.find(gui, S.t("odds.open")))
	World.advance(0.3)
	check(hasText(S.t("odds.region")), "шансы: нет объяснения запрета")
	check(not hasText(" → "), "шансы: при запрете показаны столбцы усилителей")
	setClientRestricted(false)
end)

check(#World.errors == 0, "ошибки в коде: " .. #World.errors)

if failures == 0 then
	print("✅ Случайные награды: пройдено сценариев " .. scenarios)
else
	print("❌ Случайные награды: провалено проверок " .. failures)
	error("tests failed")
end
