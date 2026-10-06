-- Окна: Фабрика, База, Улучшения, Перерождение, Индекс, Магазин.
-- Каждое окно перерисовывается только когда меняется то, что в нём показано.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Capsules = require(Shared.Config.Capsules)
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local Upgrades = require(Shared.Config.Upgrades)
local Rebirths = require(Shared.Config.Rebirths)
local Monetization = require(Shared.Config.Monetization)
local Achievements = require(Shared.Config.Achievements)
local Skins = require(Shared.Config.Skins)
local Battles = require(Shared.Config.Battles)
local Seasons = require(Shared.Config.Seasons)
local Formulas = require(Shared.Util.Formulas)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.Theme)
local Viewport = require(script.Parent.Viewport)
local create = Theme.create
local C = Theme.Colors

local player = Players.LocalPlayer

local Panels = {}
Panels.__index = Panels

local function hex(color)
	return "#" .. color:ToHex()
end

local function colored(text, color)
	return string.format('<font color="%s">%s</font>', hex(color), text)
end

local function card(props, children)
	local defaults = { BackgroundColor3 = C.Card, BorderSizePixel = 0 }
	for key, value in pairs(props) do
		defaults[key] = value
	end
	local frame = create("Frame", defaults, children)
	Theme.corner(12).Parent = frame
	return frame
end

local function list(parent, padding)
	return create("UIListLayout", {
		Padding = UDim.new(0, padding or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = parent,
	})
end

-- Кнопка с подтверждением: первое нажатие спрашивает «Точно?», второе (за 3 с) выполняет.
-- key — стабильный id кнопки: «взведённое» состояние переживает перерисовку окна.
local armed = {} -- [key] = до какого os.clock() кнопка ждёт второго нажатия
local function confirmButton(key, props, confirmText, action)
	local normalText = props.Text
	local normalColor = props.Color or C.Accent
	local button = Theme.button(props)
	local function show()
		if armed[key] and os.clock() < armed[key] then
			button.Text = confirmText
			button.BackgroundColor3 = C.Gold
			-- Новая кнопка после перерисовки тоже должна «остыть» по таймеру.
			task.delay(armed[key] - os.clock() + 0.05, function()
				if button.Parent and not (armed[key] and os.clock() < armed[key]) then
					button.Text = normalText
					button.BackgroundColor3 = normalColor
				end
			end)
		else
			button.Text = normalText
			button.BackgroundColor3 = normalColor
		end
	end
	show()
	button.Activated:Connect(function()
		if armed[key] and os.clock() < armed[key] then
			armed[key] = nil
			action()
			show()
			return
		end
		armed[key] = os.clock() + 3
		show()
		task.delay(3.05, function()
			if button.Parent then
				show()
			end
		end)
	end)
	return button
end

local function escape(text)
	return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function creatureName(entry)
	local creature = Creatures.get(entry.id)
	local mutation = Mutations.get(entry.mut)
	local name = creature.name
	if mutation.id ~= "normal" then
		name = colored(mutation.name, mutation.color) .. " " .. name
	end
	if entry.nickname then
		name = colored("«" .. escape(entry.nickname) .. "»", C.Gold) .. " " .. name
	end
	return name
end

Panels.onRename = nil -- function(uid, currentName) — задаётся в Main.client

---------------------------------------------------------------------------
-- ФАБРИКА
---------------------------------------------------------------------------
local Factory = { title = "🏭 Фабрика брейнрота" }

function Factory.signature(state)
	local parts = {
		state.level,
		state.rebirths,
		string.format("%.2f", state.luck),
		state.mods.secret,
		tostring(state.autoCraft),
		tostring(state.passes.AUTO_CRAFT),
	}
	local serverNow = workspace:GetServerTimeNow()
	for _, capsule in ipairs(Capsules.List) do
		table.insert(
			parts,
			(state.coins >= capsule.cost and "1" or "0")
				.. (state.pity[capsule.id] or 0)
				.. tostring(Formulas.capsuleInSeason(capsule, serverNow))
		)
	end
	return table.concat(parts, "|")
end

function Factory.build(content, state)
	list(content, 10)

	Theme.label({
		Size = UDim2.new(1, -10, 0, 28),
		Text = string.format(
			"🍀 Удача x%.2f  •  ⏱ Машина: %.1f с  •  Места: %d/%d",
			state.luck,
			state.craftTime,
			#state.creatures,
			state.slots
		),
		TextColor3 = C.Muted,
		LayoutOrder = 0,
		Parent = content,
	})
	Theme.label({
		Size = UDim2.new(1, -10, 0, 22),
		Text = "Чем популярнее тренд — тем реже он выпадает. Удача повышает шанс редких!",
		TextColor3 = C.Muted,
		LayoutOrder = 1,
		Parent = content,
	})

	local grid = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = content,
	}, {
		create("UIGridLayout", {
			CellSize = UDim2.fromOffset(196, 320),
			CellPadding = UDim2.fromOffset(10, 10),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local serverNow = workspace:GetServerTimeNow()
	for _, capsule in ipairs(Capsules.List) do
		if not Formulas.capsuleInSeason(capsule, serverNow) then
			continue -- сезонная капсула вне сезона не показывается
		end
		local unlocked = Formulas.capsuleUnlocked(capsule, state)
		local box = card({
			LayoutOrder = capsule.season and 0 or capsule.order, -- сезонная капсула первой
			BackgroundColor3 = unlocked and C.Card or C.CardLocked,
			Parent = grid,
		}, { Theme.stroke(capsule.color, 3), Theme.padding(8) })
		list(box, 4)

		Theme.label({ Size = UDim2.new(1, 0, 0, 28), Text = capsule.name, TextColor3 = capsule.color, LayoutOrder = 1, Parent = box })
		Theme.label({ Size = UDim2.new(1, 0, 0, 18), Text = capsule.desc, TextColor3 = C.Muted, LayoutOrder = 2, Parent = box })

		local chancesText = {}
		for _, entry in ipairs(Formulas.rarityChances(capsule, state.luck, state.mods)) do
			local rarity = Rarities.get(entry.rarity)
			local name = entry.secret and "??? секрет" or rarity.name
			table.insert(chancesText, colored(name, rarity.color) .. "  " .. Format.percent(entry.chance))
		end
		Theme.label({
			Size = UDim2.new(1, 0, 0, 150),
			Text = table.concat(chancesText, "\n"),
			TextScaled = false,
			TextSize = 16,
			TextYAlignment = Enum.TextYAlignment.Top,
			LayoutOrder = 3,
			Parent = box,
		})

		if unlocked then
			local pityRarity = Rarities.get(Formulas.pityRarity(capsule))
			local left = Formulas.pityThreshold(capsule) - (state.pity[capsule.id] or 0)
			Theme.label({
				Size = UDim2.new(1, 0, 0, 16),
				Text = "🎯 " .. pityRarity.name .. " точно через " .. left,
				TextColor3 = pityRarity.color,
				LayoutOrder = 4,
				Parent = box,
			})
			local canAfford = state.coins >= capsule.cost
			Theme.button({
				Size = UDim2.new(1, 0, 0, 40),
				Text = "Создать " .. Format.coins(capsule.cost),
				Color = canAfford and C.Good or C.Bad,
				LayoutOrder = 5,
				Parent = box,
			}, function()
				Remotes.Craft:FireServer(capsule.id)
			end)
			if state.passes.AUTO_CRAFT then
				local active = state.autoCraft == capsule.id
				Theme.button({
					Size = UDim2.new(1, 0, 0, 26),
					Text = active and "🤖 Авто: ВКЛ" or "🤖 Авто",
					Color = active and C.Gold or C.Card,
					LayoutOrder = 6,
					Parent = box,
				}, function()
					Remotes.SetAutoCraft:FireServer(not active and capsule.id or nil)
				end)
			end
		else
			local need = "🔒 Уровень " .. capsule.level
			if capsule.rebirths > 0 then
				need ..= " + " .. capsule.rebirths .. " перерожд."
			end
			Theme.label({ Size = UDim2.new(1, 0, 0, 40), Text = need, TextColor3 = C.Muted, LayoutOrder = 5, Parent = box })
		end
	end
end

---------------------------------------------------------------------------
-- БАЗА
---------------------------------------------------------------------------
local Base = { title = "🧠 Моя база" }

function Base.signature(state)
	local parts = { state.slots, state.incomeMultiplier, state.social.bonus, tostring(state.pet) }
	for _, entry in ipairs(state.creatures) do
		table.insert(parts, entry.uid .. tostring(entry.nickname))
	end
	return table.concat(parts, "|")
end

function Base.build(content, state)
	list(content, 8)

	Theme.label({
		Size = UDim2.new(1, -10, 0, 28),
		Text = string.format("Места: %d/%d  •  Доход: %s/с", #state.creatures, state.slots, Format.coins(state.income)),
		TextColor3 = C.Coins,
		LayoutOrder = 0,
		Parent = content,
	})
	local social = state.social
	local bonusParts = {
		string.format("👥 Друзья на сервере: %d/4 (+%d%%)", social.friends, social.friends * 10),
		social.premium and "💎 Premium +10%" or "💎 Premium: +10%",
	}
	if social.groupEnabled then
		table.insert(bonusParts, social.group and "⭐ Группа +10%" or "⭐ Вступи в группу: +10%")
	end
	Theme.label({
		Size = UDim2.new(1, -10, 0, 22),
		Text = table.concat(bonusParts, "   "),
		TextColor3 = C.Good,
		LayoutOrder = 1,
		Parent = content,
	})

	if #state.creatures == 0 then
		Theme.label({
			Size = UDim2.new(1, -10, 0, 60),
			Text = "Тут пусто! Иди на 🏭 Фабрику и создай первого брейнрота.",
			TextColor3 = C.Muted,
			LayoutOrder = 1,
			Parent = content,
		})
		return
	end

	-- Группы по редкостям: скрестить / продать всех.
	local counts = {}
	for _, entry in ipairs(state.creatures) do
		local creature = Creatures.get(entry.id)
		if creature then
			counts[creature.rarity] = (counts[creature.rarity] or 0) + 1
		end
	end
	for _, rarity in ipairs(Rarities.List) do
		local count = counts[rarity.id]
		if count then
			local row = card({ Size = UDim2.new(1, -10, 0, 44), LayoutOrder = 10 + rarity.rank }, { Theme.padding(6) })
			Theme.label({
				Size = UDim2.new(0.4, 0, 1, 0),
				Text = colored(rarity.name, rarity.color) .. " × " .. count,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = row,
			})
			local nextRarity = Rarities.next(rarity.id)
			if nextRarity then
				Theme.button({
					Size = UDim2.new(0.3, -4, 1, 0),
					Position = UDim2.fromScale(0.4, 0),
					Text = "🧬 3 → " .. nextRarity.name,
					Color = count >= Formulas.FUSE_COUNT and C.Purple or C.CardLocked,
					Parent = row,
				}, function()
					Remotes.Fuse:FireServer(rarity.id)
				end)
			end
			local sellAll = function()
				Remotes.SellRarity:FireServer(rarity.id)
			end
			local sellAllProps = {
				Size = UDim2.new(0.3, -4, 1, 0),
				Position = UDim2.new(0.7, 4, 0, 0),
				Text = "💰 Продать всех",
				Color = C.Bad,
				Parent = row,
			}
			if rarity.rank >= 5 then
				confirmButton("sellAll:" .. rarity.id, sellAllProps, "Точно? Нажми ещё", sellAll)
			else
				Theme.button(sellAllProps, sellAll)
			end
			row.Parent = content
		end
	end
	Theme.label({
		Size = UDim2.new(1, -10, 0, 20),
		Text = "Скрещивание берёт самых слабых. «Продать всех» не трогает мутантов.",
		TextColor3 = C.Muted,
		LayoutOrder = 50,
		Parent = content,
	})

	-- Список брейнротов, сильные сверху.
	local sorted = table.clone(state.creatures)
	table.sort(sorted, function(a, b)
		return Formulas.creatureBaseIncome(a) > Formulas.creatureBaseIncome(b)
	end)
	for order, entry in ipairs(sorted) do
		local creature = Creatures.get(entry.id)
		if creature then
			local rarity = Rarities.get(creature.rarity)
			local row = card({ Size = UDim2.new(1, -10, 0, 50), LayoutOrder = 100 + order }, {
				Theme.padding(6),
				Theme.stroke(rarity.color, 2),
			})
			Theme.label({
				Size = UDim2.new(0.42, 0, 0.6, 0),
				Text = creatureName(entry) .. " ✏️",
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = row,
			})
			-- Нажми на имя — можно переименовать.
			local renameHit = create("TextButton", {
				Size = UDim2.new(0.42, 0, 1, 0),
				BackgroundTransparency = 1,
				Text = "",
				ZIndex = 3,
				Parent = row,
			})
			renameHit.Activated:Connect(function()
				if Panels.onRename then
					Panels.onRename(entry.uid, entry.nickname)
				end
			end)
			Theme.label({
				Size = UDim2.new(0.42, 0, 0.4, 0),
				Position = UDim2.fromScale(0, 0.6),
				Text = colored(rarity.name, rarity.color),
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = row,
			})
			Theme.label({
				Size = UDim2.new(0.21, 0, 1, 0),
				Position = UDim2.fromScale(0.42, 0),
				Text = "+" .. Format.coins(Formulas.creatureBaseIncome(entry) * state.incomeMultiplier) .. "/с",
				TextColor3 = C.Good,
				Parent = row,
			})
			-- Питомец: этот брейнрот будет бегать за тобой.
			local isPet = state.pet == entry.uid
			Theme.button({
				Size = UDim2.new(0.11, -4, 1, 0),
				Position = UDim2.new(0.63, 2, 0, 0),
				Text = isPet and "🐾✅" or "🐾",
				Color = isPet and C.Gold or C.Card,
				Parent = row,
			}, function()
				Remotes.SetPet:FireServer(not isPet and entry.uid or nil)
			end)
			local sell = function()
				Remotes.Sell:FireServer(entry.uid)
			end
			local sellProps = {
				Size = UDim2.new(0.26, -4, 1, 0),
				Position = UDim2.new(0.74, 4, 0, 0),
				Text = "Продать " .. Format.coins(Formulas.sellValue(entry)),
				Color = C.Bad,
				Parent = row,
			}
			-- Редких (Аура и выше) и мутантов продаём только с подтверждением.
			if rarity.rank >= 5 or entry.mut ~= "normal" then
				confirmButton("sell:" .. entry.uid, sellProps, "Точно продать?", sell)
			else
				Theme.button(sellProps, sell)
			end
			row.Parent = content
		end
	end
end

---------------------------------------------------------------------------
-- УЛУЧШЕНИЯ
---------------------------------------------------------------------------
local UpgradesPanel = { title = "⬆️ Улучшения фабрики" }

function UpgradesPanel.signature(state)
	local parts = {}
	for _, upgrade in ipairs(Upgrades.List) do
		local level = state.upgrades[upgrade.id] or 0
		table.insert(parts, level .. ":" .. (state.coins >= Upgrades.cost(upgrade.id, level) and 1 or 0))
	end
	return table.concat(parts, "|")
end

function UpgradesPanel.build(content, state)
	list(content, 10)
	for order, upgrade in ipairs(Upgrades.List) do
		local level = state.upgrades[upgrade.id] or 0
		local maxed = level >= upgrade.maxLevel
		local cost = Upgrades.cost(upgrade.id, level)
		local row = card({ Size = UDim2.new(1, -10, 0, 80), LayoutOrder = order }, { Theme.padding(8) })
		Theme.label({
			Size = UDim2.new(0.65, 0, 0.5, 0),
			Text = upgrade.name .. "  " .. colored("ур. " .. level .. "/" .. upgrade.maxLevel, C.Muted),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		Theme.label({
			Size = UDim2.new(0.65, 0, 0.4, 0),
			Position = UDim2.fromScale(0, 0.55),
			Text = upgrade.desc,
			TextColor3 = C.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		Theme.button({
			Size = UDim2.new(0.35, -8, 1, 0),
			Position = UDim2.new(0.65, 8, 0, 0),
			Text = maxed and "МАКС" or Format.coins(cost),
			Color = maxed and C.CardLocked or (state.coins >= cost and C.Good or C.Bad),
			Parent = row,
		}, function()
			Remotes.BuyUpgrade:FireServer(upgrade.id)
		end)
		row.Parent = content
	end
end

---------------------------------------------------------------------------
-- ПЕРЕРОЖДЕНИЕ
---------------------------------------------------------------------------
local Rebirth = { title = "♻️ Перерождение" }

function Rebirth.signature(state)
	local cost = Rebirths.cost(state.rebirths)
	return table.concat({ state.rebirths, state.level, state.coins >= cost and 1 or 0 }, "|")
end

function Rebirth.build(content, state)
	list(content, 10)
	local cost = Rebirths.cost(state.rebirths)
	local levelRequired = Rebirths.levelRequired(state.rebirths)
	local nextTitle = Rebirths.titleFor(state.rebirths + 1)
	local levelOk = state.level >= levelRequired
	local coinsOk = state.coins >= cost

	local lines = {
		"Сейчас перерождений: " .. colored(tostring(state.rebirths), C.Gold),
		"Следующий титул: " .. colored("«" .. nextTitle .. "»", C.Gold),
		"",
		colored("Ты получишь навсегда:", C.Good),
		"+" .. math.floor(Rebirths.INCOME_BONUS * 100) .. "% дохода  •  +" .. math.floor(Rebirths.LUCK_BONUS * 100) .. "% удачи",
		"",
		colored("Ты потеряешь:", C.Bad),
		"монеты, брейнротов на базе и улучшения",
		colored("(уровень и Индекс остаются)", C.Muted),
		"",
		(levelOk and "✅" or "❌") .. " Уровень " .. levelRequired .. " (у тебя " .. state.level .. ")",
		(coinsOk and "✅" or "❌") .. " " .. Format.coins(cost),
	}
	Theme.label({
		Size = UDim2.new(1, -10, 0, 290),
		Text = table.concat(lines, "\n"),
		TextScaled = false,
		TextSize = 20,
		LayoutOrder = 1,
		Parent = content,
	})
	confirmButton("rebirth", {
		Size = UDim2.new(0.6, 0, 0, 56),
		Text = "♻️ ПЕРЕРОДИТЬСЯ",
		Color = (levelOk and coinsOk) and C.Purple or C.CardLocked,
		LayoutOrder = 2,
		Parent = content,
	}, "⚠️ Точно? Нажми ещё раз", function()
		Remotes.Rebirth:FireServer()
	end)
end

---------------------------------------------------------------------------
-- ИНДЕКС (коллекция)
---------------------------------------------------------------------------
local Index = { title = "📖 Индекс брейнротов" }

function Index.signature(state)
	local count = 0
	for _ in pairs(state.index) do
		count += 1
	end
	return tostring(count)
end

function Index.build(content, state)
	list(content, 10)
	local found = 0
	for _ in pairs(state.index) do
		found += 1
	end
	Theme.label({
		Size = UDim2.new(1, -10, 0, 28),
		Text = "Открыто: " .. found .. " / " .. #Creatures.List .. "  (новый брейнрот = x3 опыта)",
		TextColor3 = C.Coins,
		LayoutOrder = 0,
		Parent = content,
	})
	local grid = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = content,
	}, {
		create("UIGridLayout", {
			CellSize = UDim2.fromOffset(150, 160),
			CellPadding = UDim2.fromOffset(8, 8),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for order, creature in ipairs(Creatures.List) do
		local rarity = Rarities.get(creature.rarity)
		local known = state.index[creature.id] == true
		local box = card({
			LayoutOrder = order,
			BackgroundColor3 = known and C.Card or C.CardLocked,
			Parent = grid,
		}, { Theme.stroke(rarity.color, known and 3 or 1), Theme.padding(6) })
		Viewport.creature({
			Size = UDim2.fromOffset(84, 76),
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Parent = box,
		}, creature.id, "normal", not known)
		Theme.label({
			Size = UDim2.new(1, 0, 0, 40),
			Position = UDim2.fromOffset(0, 78),
			Text = known and creature.name or "???",
			Parent = box,
		})
		Theme.label({
			Size = UDim2.new(1, 0, 0, 20),
			Position = UDim2.fromOffset(0, 120),
			Text = ((rarity.secret and not known) and "???" or rarity.name) .. (creature.season and (" " .. Seasons.ById[creature.season].icon) or ""),
			TextColor3 = rarity.color,
			Parent = box,
		})
	end
end

---------------------------------------------------------------------------
-- МАГАЗИН
---------------------------------------------------------------------------
local Shop = { title = "🛒 Магазин" }

function Shop.signature(state)
	local parts = {}
	for key in pairs(state.passes) do
		table.insert(parts, key)
	end
	table.sort(parts)
	return table.concat(parts, "|")
end

function Shop.build(content, state)
	list(content, 8)
	Theme.label({ Size = UDim2.new(1, -10, 0, 30), Text = "Геймпассы (навсегда)", TextColor3 = C.Gold, LayoutOrder = 0, Parent = content })

	local order = 1
	local function row(item, owned, onBuy)
		order += 1
		local box = card({ Size = UDim2.new(1, -10, 0, 64), LayoutOrder = order }, { Theme.padding(8) })
		Theme.label({ Size = UDim2.new(0.65, 0, 0.55, 0), Text = item.name, TextXAlignment = Enum.TextXAlignment.Left, Parent = box })
		Theme.label({
			Size = UDim2.new(0.65, 0, 0.4, 0),
			Position = UDim2.fromScale(0, 0.6),
			Text = item.desc,
			TextColor3 = C.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = box,
		})
		local text, color
		if owned then
			text, color = "✅ Куплено", C.CardLocked
		elseif item.id == 0 then
			text, color = "Скоро", C.CardLocked
		else
			text, color = "R$ " .. item.price, C.Good
		end
		Theme.button({
			Size = UDim2.new(0.35, -8, 1, 0),
			Position = UDim2.new(0.65, 8, 0, 0),
			Text = text,
			Color = color,
			Parent = box,
		}, function()
			if not owned and item.id ~= 0 then
				onBuy()
			end
		end)
		box.Parent = content
	end

	for _, pass in ipairs(Monetization.GamePasses) do
		row(pass, state.passes[pass.key], function()
			MarketplaceService:PromptGamePassPurchase(player, pass.id)
		end)
	end

	order += 1
	Theme.label({ Size = UDim2.new(1, -10, 0, 30), Text = "Бусты", TextColor3 = C.Gold, LayoutOrder = order, Parent = content })
	for _, product in ipairs(Monetization.Products) do
		row(product, false, function()
			MarketplaceService:PromptProductPurchase(player, product.id)
		end)
	end
end

---------------------------------------------------------------------------
-- НАГРАДЫ: ежедневная серия и задания
---------------------------------------------------------------------------
local Rewards = { title = "🎁 Награды и задания" }
local codeDraft = "" -- текст промокода не теряется, когда окно перерисовывается

-- Сколько минут игрок уже в игре за этот заход.
local function playMinutes(state)
	return (workspace:GetServerTimeNow() - state.playtime.start) / 60
end

function Panels.giftsReady(state)
	local minutes = playMinutes(state)
	for _, gift in ipairs(state.playtime.gifts) do
		if not gift.claimed and minutes >= gift.minutes then
			return true
		end
	end
	return false
end

function Rewards.signature(state)
	local r = state.rewards
	local parts = {
		tostring(r.canClaim),
		r.nextDay,
		r.streak,
		r.rewards[1],
		math.floor(playMinutes(state)),
		tostring(state.wheel.freeAvailable),
		state.wheel.extraSpins,
	}
	for _, gift in ipairs(state.playtime.gifts) do
		table.insert(parts, tostring(gift.claimed))
	end
	for _, quest in ipairs(r.quests) do
		table.insert(parts, quest.text .. quest.progress .. tostring(quest.claimed))
	end
	return table.concat(parts, "|")
end

function Rewards.build(content, state)
	local r = state.rewards
	list(content, 10)
	Theme.label({
		Size = UDim2.new(1, -10, 0, 28),
		Text = "Заходи каждый день — на 7-й день мега-награда!",
		TextColor3 = C.Coins,
		LayoutOrder = 0,
		Parent = content,
	})

	local row = create("Frame", {
		Size = UDim2.new(1, -10, 0, 96),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = content,
	}, {
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for day, text in ipairs(r.rewards) do
		local done = day < r.nextDay or (day == r.nextDay and not r.canClaim)
		local current = day == r.nextDay and r.canClaim
		local cell = card({
			Size = UDim2.fromOffset(84, 96),
			LayoutOrder = day,
			BackgroundColor3 = done and C.CardLocked or C.Card,
			Parent = row,
		}, { Theme.stroke(current and C.Gold or (day == 7 and C.Accent or C.Card), current and 4 or 2), Theme.padding(4) })
		Theme.label({ Size = UDim2.new(1, 0, 0, 22), Text = (done and "✅ " or "") .. "День " .. day, Parent = cell })
		Theme.label({
			Size = UDim2.new(1, 0, 1, -24),
			Position = UDim2.fromOffset(0, 24),
			Text = text,
			TextColor3 = day == 7 and C.Gold or C.Muted,
			Parent = cell,
		})
	end

	-- Колесо удачи.
	local wheel = state.wheel
	local wheelRow = create("Frame", {
		Size = UDim2.new(1, -10, 0, 48),
		BackgroundTransparency = 1,
		LayoutOrder = 50,
		Parent = content,
	})
	local canSpin = wheel.freeAvailable or wheel.extraSpins > 0
	Theme.button({
		Size = UDim2.new(0.6, -6, 1, 0),
		Text = wheel.freeAvailable and "🎡 Крутить колесо (бесплатно!)"
			or (wheel.extraSpins > 0 and ("🎡 Крутить колесо (" .. wheel.extraSpins .. ")") or "🎡 Бесплатное вращение завтра"),
		Color = canSpin and C.Gold or C.CardLocked,
		Parent = wheelRow,
	}, function()
		if canSpin then
			Remotes.SpinWheel:FireServer()
		end
	end)
	local spinsProduct = Monetization.ProductByKey.SPINS_3
	Theme.button({
		Size = UDim2.new(0.4, 0, 1, 0),
		Position = UDim2.new(0.6, 6, 0, 0),
		Text = spinsProduct.id ~= 0 and ("+3 вращения R$ " .. spinsProduct.price) or "+3 вращения (скоро)",
		Color = spinsProduct.id ~= 0 and C.Purple or C.CardLocked,
		Parent = wheelRow,
	}, function()
		if spinsProduct.id ~= 0 then
			MarketplaceService:PromptProductPurchase(player, spinsProduct.id)
		end
	end)

	-- Подарки за время в игре.
	local minutes = playMinutes(state)
	Theme.label({
		Size = UDim2.new(1, -10, 0, 28),
		Text = "⏰ Подарки за игру (ты играешь " .. math.floor(minutes) .. " мин)",
		TextColor3 = C.Coins,
		LayoutOrder = 60,
		Parent = content,
	})
	local giftGrid = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 61,
		Parent = content,
	}, {
		create("UIGridLayout", {
			CellSize = UDim2.fromOffset(200, 64),
			CellPadding = UDim2.fromOffset(8, 8),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for index, gift in ipairs(state.playtime.gifts) do
		local ready = minutes >= gift.minutes
		local text, color
		if gift.claimed then
			text, color = "✅ " .. gift.minutes .. " мин", C.CardLocked
		elseif ready then
			text, color = "🎁 Забрать!\n" .. gift.reward, C.Good
		else
			text, color = "⏰ через " .. math.ceil(gift.minutes - minutes) .. " мин\n" .. gift.reward, C.Card
		end
		Theme.button({ Text = text, Color = color, LayoutOrder = index, Parent = giftGrid }, function()
			Remotes.ClaimGift:FireServer(index)
		end)
	end

	-- Промокоды.
	local codeRow = create("Frame", {
		Size = UDim2.new(1, -10, 0, 44),
		BackgroundTransparency = 1,
		LayoutOrder = 90,
		Parent = content,
	})
	local codeBox = create("TextBox", {
		Size = UDim2.new(0.65, -8, 1, 0),
		BackgroundColor3 = C.Card,
		PlaceholderText = "🎟️ Промокод (например, SIXSEVEN)",
		PlaceholderColor3 = C.Muted,
		Text = codeDraft,
		Font = Theme.Font,
		TextScaled = true,
		TextColor3 = C.Text,
		ClearTextOnFocus = false,
		Parent = codeRow,
	}, { Theme.corner(10), Theme.padding(6) })
	codeBox:GetPropertyChangedSignal("Text"):Connect(function()
		codeDraft = codeBox.Text
	end)
	Theme.button({
		Size = UDim2.new(0.35, 0, 1, 0),
		Position = UDim2.fromScale(0.65, 0),
		Text = "Ввести код",
		Color = C.Purple,
		Parent = codeRow,
	}, function()
		Remotes.RedeemCode:FireServer(codeBox.Text)
		codeBox.Text = ""
		codeDraft = ""
	end)

	Theme.button({
		Size = UDim2.new(0.5, 0, 0, 48),
		Text = r.canClaim and ("🎁 Забрать день " .. r.nextDay) or "✅ Приходи завтра",
		Color = r.canClaim and C.Good or C.CardLocked,
		LayoutOrder = 2,
		Parent = content,
	}, function()
		Remotes.ClaimDaily:FireServer()
	end)

	Theme.label({
		Size = UDim2.new(1, -10, 0, 28),
		Text = "📋 Задания на сегодня (новые через " .. Format.time(r.secondsToReset) .. ")",
		TextColor3 = C.Coins,
		LayoutOrder = 3,
		Parent = content,
	})
	for order, quest in ipairs(r.quests) do
		local done = quest.progress >= quest.target
		local box = card({ Size = UDim2.new(1, -10, 0, 70), LayoutOrder = 10 + order }, { Theme.padding(8) })
		Theme.label({
			Size = UDim2.new(0.65, 0, 0.5, 0),
			Text = quest.text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = box,
		})
		local bar = create("Frame", {
			Size = UDim2.new(0.62, 0, 0.35, 0),
			Position = UDim2.fromScale(0, 0.6),
			BackgroundColor3 = C.CardLocked,
			Parent = box,
		}, { Theme.corner(6) })
		create("Frame", {
			Size = UDim2.fromScale(math.clamp(quest.progress / quest.target, 0, 1), 1),
			BackgroundColor3 = done and C.Good or C.Blue,
			Parent = bar,
		}, { Theme.corner(6) })
		Theme.label({ Size = UDim2.fromScale(1, 1), Text = quest.progress .. " / " .. quest.target, ZIndex = 2, Parent = bar })

		local text, color
		if quest.claimed then
			text, color = "✅ Получено", C.CardLocked
		elseif done then
			text, color = "🎁 " .. quest.reward, C.Good
		else
			text, color = quest.reward, C.CardLocked
		end
		Theme.button({
			Size = UDim2.new(0.35, -8, 1, 0),
			Position = UDim2.new(0.65, 8, 0, 0),
			Text = text,
			Color = color,
			Parent = box,
		}, function()
			Remotes.ClaimQuest:FireServer(quest.index)
		end)
		box.Parent = content
	end
end

---------------------------------------------------------------------------
-- КАК ИГРАТЬ
---------------------------------------------------------------------------
local Help = { title = "❓ Как играть" }

local HELP_SECTIONS = {
	{ "🏭 Фабрика", "Покупай мем-капсулы и создавай брейнротов. Чем популярнее тренд, тем реже он выпадает: Нормис → Лоу-ки → Ризз → Сигма → Аура → Скибиди → Брейнрот Бог → SIX SEVEN 🤌" },
	{ "🧠 База", "Брейнроты стоят на твоей базе и приносят монеты каждую секунду. Когда места кончатся, продай слабых или скрести 3 одинаковой редкости в 1 редкий." },
	{ "✨ Мутации", "Иногда брейнрот выходит Золотым (x2), Алмазным (x3), Радужным (x5) или с Мутацией 67 (x6.7 дохода)!" },
	{ "🦎 Дикие брейнроты", "По карте бегают дикие брейнроты. Подойди и зажми E — кто первый поймал, того и брейнрот! Иногда появляются редкие — об этом узнает весь сервер." },
	{ "✏️ Имена", "В 🧠 Базе нажми на имя брейнрота и придумай ему своё — его увидят все над твоей базой." },
	{ "🐾 Питомец", "В 🧠 Базе нажми 🐾 у любого брейнрота — он будет бегать за тобой по всей карте. Пусть все видят твою легендарку!" },
	{ "🦹 Кража", "Подойди к чужому брейнроту и зажми F. Беги на свою базу за 60 секунд! Если тебя шлёпнут, брейнрот вернётся хозяину." },
	{ "🔒 Защита", "Встань на голубую кнопку замка на своей базе: она закроется на 60 секунд. Вора можно шлёпнуть Шлёпалкой (клавиша 1)." },
	{ "⚔️ Аура-баттлы", "Вызови игрока или потренируйся с ботом: 3 твоих сильнейших брейнрота против 3 его. Сила зависит от дохода, но бывают апсеты! Ничего не теряешь, за победы — очки ауры, ранги и монеты." },
	{ "👹 Босс", "Каждый час в :30 на площадь приходит огромный босс-брейнрот. Шлёпайте его всем сервером! Кто ударил больше всех, получит Ауру." },
	{ "🎉 Ивенты", "Каждые 15 минут идёт ивент: удача, деньги, мутации или турбо. А каждый час в 6-7 минуту наступает МИНУТА 67: шанс SIX SEVEN x6.7!" },
	{ "♻️ Перерождение", "Сбрасывает монеты и брейнротов, но навсегда даёт +50% дохода, +10% удачи и крутой титул." },
	{ "🎁 Награды", "Заходи каждый день за наградой, на 7-й день мега-награда. Выполняй 3 задания в день." },
}

function Help.signature()
	return "help"
end

function Help.build(content)
	list(content, 8)
	for order, section in ipairs(HELP_SECTIONS) do
		local box = card({ Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order }, { Theme.padding(10) })
		Theme.label({
			Size = UDim2.new(1, 0, 0, 26),
			Text = section[1],
			TextColor3 = C.Gold,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = box,
		})
		Theme.label({
			Size = UDim2.new(1, 0, 0, 0),
			Position = UDim2.fromOffset(0, 28),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = section[2],
			TextScaled = false,
			TextSize = 18,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = box,
		})
		box.Parent = content
	end
end

---------------------------------------------------------------------------
-- ОБМЕН
---------------------------------------------------------------------------
local Trade = { title = "🤝 Обмен брейнротами" }
Panels.trade = nil -- состояние обмена с сервера (nil — обмена нет)

function Trade.signature(state)
	local parts = { #Players:GetPlayers() }
	local trade = Panels.trade
	if trade then
		table.insert(parts, trade.partnerUserId)
		table.insert(parts, table.concat(trade.myOffer, ","))
		for _, entry in ipairs(trade.theirOffer) do
			table.insert(parts, entry.id .. entry.mut)
		end
		table.insert(parts, tostring(trade.myReady) .. tostring(trade.theirReady) .. tostring(trade.confirmAt))
	end
	for _, entry in ipairs(state.creatures) do
		table.insert(parts, entry.uid)
	end
	return table.concat(parts, "|")
end

local function offerRow(parent, order, entry, selected, onClick)
	local creature = Creatures.get(entry.id)
	if not creature then
		return
	end
	local rarity = Rarities.get(creature.rarity)
	local button = Theme.button({
		Size = UDim2.new(1, -6, 0, 40),
		Text = (selected and "✅ " or "") .. creatureName(entry) .. "  " .. colored(rarity.name, rarity.color),
		Color = selected and C.Purple or C.Card,
		LayoutOrder = order,
		Parent = parent,
	}, onClick)
	button.AutoButtonColor = onClick ~= nil
end

local function column(content, x, title)
	local frame = create("Frame", {
		Size = UDim2.new(0.5, -6, 0, 300),
		Position = UDim2.new(x, x > 0 and 6 or 0, 0, 0),
		BackgroundTransparency = 1,
		Parent = content,
	})
	Theme.label({ Size = UDim2.new(1, 0, 0, 26), Text = title, TextColor3 = C.Coins, Parent = frame })
	local scroll = create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 1, -30),
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = frame,
	}, { Theme.corner(10) })
	list(scroll, 4)
	return scroll
end

function Trade.build(content, state)
	local trade = Panels.trade
	if not trade then
		list(content, 8)
		Theme.label({
			Size = UDim2.new(1, -10, 0, 50),
			Text = "Выбери игрока и предложи обмен. Каждый кладёт до 6 брейнротов, потом оба жмут «Готов».",
			TextColor3 = C.Muted,
			LayoutOrder = 0,
			Parent = content,
		})
		local others = 0
		for order, other in ipairs(Players:GetPlayers()) do
			if other ~= player then
				others += 1
				local row = card({ Size = UDim2.new(1, -10, 0, 50), LayoutOrder = order }, { Theme.padding(6) })
				Theme.label({
					Size = UDim2.new(0.6, 0, 1, 0),
					Text = other.DisplayName,
					TextXAlignment = Enum.TextXAlignment.Left,
					Parent = row,
				})
				Theme.button({
					Size = UDim2.new(0.4, -6, 1, 0),
					Position = UDim2.new(0.6, 6, 0, 0),
					Text = "🤝 Предложить",
					Color = C.Good,
					Parent = row,
				}, function()
					Remotes.TradeRequest:FireServer(other.UserId)
				end)
				row.Parent = content
			end
		end
		if others == 0 then
			Theme.label({
				Size = UDim2.new(1, -10, 0, 40),
				Text = "На сервере больше никого нет 😢",
				LayoutOrder = 1,
				Parent = content,
			})
		end
		return
	end

	-- Идёт обмен.
	local selected = {}
	for _, uid in ipairs(trade.myOffer) do
		selected[uid] = true
	end
	local mine = column(content, 0, "Ты отдаёшь (" .. #trade.myOffer .. "/6)")
	local sorted = table.clone(state.creatures)
	table.sort(sorted, function(a, b)
		return Formulas.creatureBaseIncome(a) > Formulas.creatureBaseIncome(b)
	end)
	for order, entry in ipairs(sorted) do
		offerRow(mine, order, entry, selected[entry.uid], function()
			local offer = table.clone(trade.myOffer)
			local index = table.find(offer, entry.uid)
			if index then
				table.remove(offer, index)
			elseif #offer < 6 then
				table.insert(offer, entry.uid)
			end
			Remotes.TradeSetOffer:FireServer(offer)
		end)
	end

	local theirs = column(content, 0.5, trade.partnerName .. " отдаёт")
	for order, entry in ipairs(trade.theirOffer) do
		offerRow(theirs, order, entry, false, nil)
	end

	local status
	if trade.confirmAt then
		status = "⏳ Обмен через " .. math.max(0, math.ceil(trade.confirmAt - workspace:GetServerTimeNow())) .. " с..."
	else
		status = (trade.myReady and "✅ Ты готов" or "Ты не готов")
			.. "  •  "
			.. (trade.theirReady and ("✅ " .. trade.partnerName .. " готов") or (trade.partnerName .. " не готов"))
	end
	Theme.label({
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.fromOffset(0, 308),
		Text = status,
		TextColor3 = trade.confirmAt and C.Good or C.Muted,
		Parent = content,
	})
	Theme.button({
		Size = UDim2.new(0.5, -6, 0, 44),
		Position = UDim2.fromOffset(0, 340),
		Text = trade.myReady and "❌ Не готов" or "✅ Готов",
		Color = trade.myReady and C.Gold or C.Good,
		Parent = content,
	}, function()
		Remotes.TradeReady:FireServer(not trade.myReady)
	end)
	Theme.button({
		Size = UDim2.new(0.5, -6, 0, 44),
		Position = UDim2.new(0.5, 6, 0, 340),
		Text = "🚪 Выйти из обмена",
		Color = C.Bad,
		Parent = content,
	}, function()
		Remotes.TradeCancel:FireServer()
	end)
end

---------------------------------------------------------------------------
-- НАСТРОЙКИ
---------------------------------------------------------------------------
local SettingsPanel = { title = "⚙️ Настройки" }

local SETTINGS = {
	{ key = "music", name = "🎵 Музыка" },
	{ key = "sfx", name = "🔊 Звуки" },
	{ key = "announcements", name = "📢 Объявления сервера (кто что выбил/украл)" },
}

function SettingsPanel.signature(state)
	local parts = {}
	for _, setting in ipairs(SETTINGS) do
		table.insert(parts, tostring(state.settings[setting.key]))
	end
	return table.concat(parts, "|")
end

function SettingsPanel.build(content, state)
	list(content, 8)
	for order, setting in ipairs(SETTINGS) do
		local on = state.settings[setting.key] ~= false
		local row = card({ Size = UDim2.new(1, -10, 0, 54), LayoutOrder = order }, { Theme.padding(8) })
		Theme.label({
			Size = UDim2.new(0.7, 0, 1, 0),
			Text = setting.name,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		Theme.button({
			Size = UDim2.new(0.3, -8, 1, 0),
			Position = UDim2.new(0.7, 8, 0, 0),
			Text = on and "ВКЛ" or "ВЫКЛ",
			Color = on and C.Good or C.Bad,
			Parent = row,
		}, function()
			Remotes.SetSetting:FireServer(setting.key, not on)
		end)
		row.Parent = content
	end
end

---------------------------------------------------------------------------
-- СКИНЫ
---------------------------------------------------------------------------
local SkinsPanel = { title = "🎨 Скины брейнротов" }
local selectedSkin = nil -- выбранный скин; nil = «снять скин»

function SkinsPanel.signature(state)
	local parts = { tostring(selectedSkin) }
	for _, skin in ipairs(Skins.List) do
		table.insert(parts, tostring(state.skins[skin.id]) .. (skin.price and state.coins >= skin.price and "1" or "0"))
	end
	for _, entry in ipairs(state.creatures) do
		table.insert(parts, entry.uid .. tostring(entry.skin))
	end
	return table.concat(parts, "|")
end

function SkinsPanel.build(content, state, panels)
	list(content, 8)
	Theme.label({
		Size = UDim2.new(1, -10, 0, 24),
		Text = "Скины только для красоты. Выбери скин, потом нажми «Надеть» у брейнрота.",
		TextColor3 = C.Muted,
		LayoutOrder = 0,
		Parent = content,
	})
	local grid = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = content,
	}, {
		create("UIGridLayout", {
			CellSize = UDim2.fromOffset(150, 150),
			CellPadding = UDim2.fromOffset(8, 8),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for _, skin in ipairs(Skins.List) do
		local owned = state.skins[skin.id] == true
		local isSelected = selectedSkin == skin.id
		local box = card({
			LayoutOrder = skin.order,
			BackgroundColor3 = isSelected and C.Purple or C.Card,
			Parent = grid,
		}, { Theme.stroke(owned and skin.color or C.CardLocked, isSelected and 4 or 2), Theme.padding(6) })
		Viewport.creature({
			Size = UDim2.new(1, 0, 0, 62),
			Parent = box,
		}, "bananito_ninjini", "normal", false, skin.id)
		Theme.label({ Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 64), Text = skin.name, Parent = box })
		local text, color
		if owned then
			text, color = isSelected and "✅ Выбран" or "Выбрать", isSelected and C.Gold or C.Good
		elseif skin.price then
			text, color = Format.coins(skin.price), state.coins >= skin.price and C.Good or C.Bad
		else
			text, color = "🔒 Секрет", C.CardLocked
		end
		Theme.button({
			Size = UDim2.new(1, 0, 0, 36),
			Position = UDim2.new(0, 0, 1, -36),
			Text = text,
			Color = color,
			Parent = box,
		}, function()
			if owned then
				selectedSkin = skin.id
				panels:refresh()
			elseif skin.price then
				Remotes.BuySkin:FireServer(skin.id)
			end
		end)
	end

	Theme.button({
		Size = UDim2.new(0.5, 0, 0, 36),
		Text = selectedSkin == nil and "✅ Режим «снять скин»" or "Снять скины (выбрать)",
		Color = selectedSkin == nil and C.Gold or C.Card,
		LayoutOrder = 2,
		Parent = content,
	}, function()
		selectedSkin = nil
		panels:refresh()
	end)

	local sorted = table.clone(state.creatures)
	table.sort(sorted, function(a, b)
		return Formulas.creatureBaseIncome(a) > Formulas.creatureBaseIncome(b)
	end)
	for order, entry in ipairs(sorted) do
		local skin = Skins.get(entry.skin)
		local row = card({ Size = UDim2.new(1, -10, 0, 44), LayoutOrder = 10 + order }, { Theme.padding(6) })
		Theme.label({
			Size = UDim2.new(0.65, 0, 1, 0),
			Text = creatureName(entry) .. (skin and ("  " .. skin.name) or ""),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		Theme.button({
			Size = UDim2.new(0.35, -6, 1, 0),
			Position = UDim2.new(0.65, 6, 0, 0),
			Text = selectedSkin and "🎨 Надеть" or "Снять",
			Color = selectedSkin and C.Purple or C.Bad,
			Parent = row,
		}, function()
			Remotes.ApplySkin:FireServer(entry.uid, selectedSkin)
		end)
		row.Parent = content
	end
end

---------------------------------------------------------------------------
-- АУРА-БАТТЛЫ
---------------------------------------------------------------------------
local BattlesPanel = { title = "⚔️ Аура-баттлы" }

function BattlesPanel.signature(state)
	local b = state.battles
	local parts = { b.points, b.wins, b.losses, b.rewardsLeft, #Players:GetPlayers() }
	for _, member in ipairs(b.team) do
		table.insert(parts, member.id .. member.mut .. tostring(member.skin))
	end
	return table.concat(parts, "|")
end

function BattlesPanel.build(content, state)
	local b = state.battles
	list(content, 8)
	Theme.label({
		Size = UDim2.new(1, -10, 0, 30),
		Text = "✨ " .. b.rank .. " • очки ауры: " .. b.points .. " • побед " .. b.wins .. " / поражений " .. b.losses,
		TextColor3 = C.Gold,
		LayoutOrder = 0,
		Parent = content,
	})
	Theme.label({
		Size = UDim2.new(1, -10, 0, 22),
		Text = "Сражаются 3 твоих сильнейших брейнрота. Ничего не теряешь! Наград за победы сегодня: " .. b.rewardsLeft,
		TextColor3 = C.Muted,
		LayoutOrder = 1,
		Parent = content,
	})

	local teamRow = create("Frame", {
		Size = UDim2.new(1, -10, 0, 110),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = content,
	}, {
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 10),
		}),
	})
	if #b.team == 0 then
		Theme.label({ Size = UDim2.new(1, 0, 1, 0), Text = "Сначала создай брейнротов на 🏭 Фабрике", TextColor3 = C.Muted, Parent = teamRow })
	end
	for _, member in ipairs(b.team) do
		local creature = Creatures.get(member.id)
		local box = card({ Size = UDim2.fromOffset(150, 110), Parent = teamRow }, { Theme.padding(4) })
		Viewport.creature({ Size = UDim2.new(1, 0, 0, 74), Parent = box }, member.id, member.mut, false, member.skin)
		Theme.label({
			Size = UDim2.new(1, 0, 0, 26),
			Position = UDim2.fromOffset(0, 76),
			Text = "✨ " .. Battles.power(Formulas.creatureBaseIncome(member)),
			TextColor3 = creature and Rarities.get(creature.rarity).color or C.Text,
			Parent = box,
		})
	end

	Theme.button({
		Size = UDim2.new(0.6, 0, 0, 46),
		Text = "🤖 Тренировка с ботом",
		Color = C.Blue,
		LayoutOrder = 3,
		Parent = content,
	}, function()
		Remotes.BattleChallenge:FireServer("bot")
	end)

	for order, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local row = card({ Size = UDim2.new(1, -10, 0, 50), LayoutOrder = 10 + order }, { Theme.padding(6) })
			Theme.label({ Size = UDim2.new(0.6, 0, 1, 0), Text = other.DisplayName, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
			Theme.button({
				Size = UDim2.new(0.4, -6, 1, 0),
				Position = UDim2.new(0.6, 6, 0, 0),
				Text = "⚔️ Вызвать",
				Color = C.Accent,
				Parent = row,
			}, function()
				Remotes.BattleChallenge:FireServer(other.UserId)
			end)
			row.Parent = content
		end
	end
end

---------------------------------------------------------------------------
-- ДОСТИЖЕНИЯ
---------------------------------------------------------------------------
local AchievementsPanel = { title = "🏆 Достижения" }

function AchievementsPanel.signature(state)
	return tostring(state.achievements.count)
end

function AchievementsPanel.build(content, state)
	list(content, 6)
	Theme.label({
		Size = UDim2.new(1, -10, 0, 28),
		Text = "Получено: " .. state.achievements.count .. " / " .. state.achievements.total,
		TextColor3 = C.Coins,
		LayoutOrder = 0,
		Parent = content,
	})
	-- Сначала полученные, потом остальные (в порядке списка).
	for order, achievement in ipairs(Achievements.List) do
		local done = state.achievements.unlocked[achievement.id] == true
		local row = card({
			Size = UDim2.new(1, -10, 0, 54),
			LayoutOrder = (done and 0 or 1000) + order,
			BackgroundColor3 = done and C.Card or C.CardLocked,
		}, { Theme.padding(6), Theme.stroke(done and C.Gold or C.CardLocked, 2) })
		Theme.label({
			Size = UDim2.new(1, 0, 0.55, 0),
			Text = (done and "🏆 " or "🔒 ") .. achievement.name,
			TextColor3 = done and C.Gold or C.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		Theme.label({
			Size = UDim2.new(1, 0, 0.42, 0),
			Position = UDim2.fromScale(0, 0.58),
			Text = achievement.desc,
			TextColor3 = C.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		row.Parent = content
	end
end

---------------------------------------------------------------------------
-- ТЕСТ (только админы / Studio)
---------------------------------------------------------------------------
local Admin = { title = "🛠 Тест-команды" }

local ADMIN_BUTTONS = {
	{ "💰 +1K", "coins", 1000 },
	{ "💰 +1M", "coins", 1000000 },
	{ "💰 +1B", "coins", 1000000000 },
	{ "⭐ +1 уровень", "levels", 1 },
	{ "⭐ +10 уровней", "levels", 10 },
	{ "Сигма", "creature", "sigma" },
	{ "Аура", "creature", "aura" },
	{ "Скибиди", "creature", "skibidi" },
	{ "Брейнрот Бог", "creature", "god" },
	{ "SIX SEVEN", "creature", "sixseven" },
	{ "Мутант 67", "mutant" },
	{ "🍀 Шторм удачи", "event", "luck_storm" },
	{ "💰 Денежный дождь", "event", "money_rain" },
	{ "🧬 Мутаген", "event", "mutant_fog" },
	{ "⚡ Турбо", "event", "turbo" },
	{ "🤌 Минута 67", "event", "minute67" },
	{ "👹 Босс", "event", "boss" },
	{ "🦎 Дикий брейнрот", "wild" },
	{ "🎃 Сезон Хэллоуин", "season", "halloween" },
	{ "🎄 Сезон Новый год", "season", "newyear" },
	{ "💘 Сезон Валентин", "season", "valentine" },
	{ "☀️ Сезон Лето", "season", "summer" },
	{ "Выключить сезон", "season", "" },
	{ "📚 Пропустить обучение", "skipTutorial" },
	{ "🎁 Сбросить награды дня", "resetDaily" },
	{ "⚠️ СБРОС ПРОГРЕССА", "reset" },
}

function Admin.signature()
	return "admin"
end

function Admin.build(content)
	list(content, 8)
	Theme.label({
		Size = UDim2.new(1, -10, 0, 24),
		Text = "Только для проверки игры. Видно в Studio и админам из Config/Admins.",
		TextColor3 = C.Muted,
		LayoutOrder = 0,
		Parent = content,
	})
	local grid = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = content,
	}, {
		create("UIGridLayout", {
			CellSize = UDim2.fromOffset(200, 44),
			CellPadding = UDim2.fromOffset(8, 8),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for order, def in ipairs(ADMIN_BUTTONS) do
		Theme.button({
			Text = def[1],
			Color = def[2] == "reset" and C.Bad or C.Card,
			LayoutOrder = order,
			Parent = grid,
		}, function()
			Remotes.Admin:FireServer(def[2], def[3])
		end)
	end
end

---------------------------------------------------------------------------

local DEFINITIONS = {
	Battles = BattlesPanel,
	Settings = SettingsPanel,
	Skins = SkinsPanel,
	Trade = Trade,
	Achievements = AchievementsPanel,
	Admin = Admin,
	Help = Help,
	Rewards = Rewards,
	Factory = Factory,
	Base = Base,
	Upgrades = UpgradesPanel,
	Rebirth = Rebirth,
	Index = Index,
	Shop = Shop,
}

function Panels.new(screenGui)
	local self = setmetatable({}, Panels)
	self.openName = nil
	self.lastSignature = nil
	self.state = nil

	self.window = create("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(700, 470),
		BackgroundColor3 = C.Panel,
		Visible = false,
		Parent = screenGui,
	}, { Theme.corner(18), Theme.stroke(C.Accent, 4) })

	self.titleLabel = Theme.label({
		Size = UDim2.new(1, -80, 0, 44),
		Position = UDim2.fromOffset(16, 8),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = self.window,
	})
	Theme.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(44, 40),
		Text = "✕",
		Color = C.Bad,
		Parent = self.window,
	}, function()
		self:close()
	end)

	self.content = create("ScrollingFrame", {
		Position = UDim2.fromOffset(10, 60),
		Size = UDim2.new(1, -20, 1, -70),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = self.window,
	})

	return self
end

function Panels:rebuild()
	local definition = DEFINITIONS[self.openName]
	if not definition or not self.state then
		return
	end
	local signature = definition.signature(self.state)
	if signature == self.lastSignature then
		return
	end
	self.lastSignature = signature
	local scroll = self.content.CanvasPosition
	self.content:ClearAllChildren()
	definition.build(self.content, self.state, self)
	self.content.CanvasPosition = scroll
end

function Panels:open(name, keepOpen)
	if self.openName == name then
		if keepOpen then
			return
		end
		self:close()
		return
	end
	local definition = DEFINITIONS[name]
	if not definition then
		return
	end
	self.openName = name
	self.lastSignature = nil
	self.titleLabel.Text = definition.title
	self.window.Visible = true
	self.content.CanvasPosition = Vector2.zero
	self:rebuild()
end

function Panels:close()
	self.openName = nil
	self.window.Visible = false
	self.content:ClearAllChildren()
end

-- Перерисовать окно, даже если состояние игрока не менялось (например, обмен).
function Panels:refresh()
	self.lastSignature = nil
	if self.openName then
		self:rebuild()
	end
end

function Panels:update(state)
	self.state = state
	if self.openName then
		self:rebuild()
	end
end

return Panels
