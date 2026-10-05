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
local Formulas = require(Shared.Util.Formulas)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.Theme)
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

local function creatureName(entry)
	local creature = Creatures.get(entry.id)
	local mutation = Mutations.get(entry.mut)
	if mutation.id == "normal" then
		return creature.name
	end
	return colored(mutation.name, mutation.color) .. " " .. creature.name
end

---------------------------------------------------------------------------
-- ФАБРИКА
---------------------------------------------------------------------------
local Factory = { title = "🏭 Фабрика брейнрота" }

function Factory.signature(state)
	local parts = { state.level, state.rebirths, string.format("%.2f", state.luck), tostring(state.autoCraft), tostring(state.passes.AUTO_CRAFT) }
	for _, capsule in ipairs(Capsules.List) do
		table.insert(parts, state.coins >= capsule.cost and "1" or "0")
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
			CellSize = UDim2.fromOffset(196, 300),
			CellPadding = UDim2.fromOffset(10, 10),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	for _, capsule in ipairs(Capsules.List) do
		local unlocked = Formulas.capsuleUnlocked(capsule, state)
		local box = card({
			LayoutOrder = capsule.order,
			BackgroundColor3 = unlocked and C.Card or C.CardLocked,
			Parent = grid,
		}, { Theme.stroke(capsule.color, 3), Theme.padding(8) })
		list(box, 4)

		Theme.label({ Size = UDim2.new(1, 0, 0, 28), Text = capsule.name, TextColor3 = capsule.color, LayoutOrder = 1, Parent = box })
		Theme.label({ Size = UDim2.new(1, 0, 0, 18), Text = capsule.desc, TextColor3 = C.Muted, LayoutOrder = 2, Parent = box })

		local chancesText = {}
		for _, entry in ipairs(Formulas.rarityChances(capsule, state.luck)) do
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
			local canAfford = state.coins >= capsule.cost
			Theme.button({
				Size = UDim2.new(1, 0, 0, 40),
				Text = "Создать " .. Format.coins(capsule.cost),
				Color = canAfford and C.Good or C.Bad,
				LayoutOrder = 4,
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
					LayoutOrder = 5,
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
			Theme.label({ Size = UDim2.new(1, 0, 0, 40), Text = need, TextColor3 = C.Muted, LayoutOrder = 4, Parent = box })
		end
	end
end

---------------------------------------------------------------------------
-- БАЗА
---------------------------------------------------------------------------
local Base = { title = "🧠 Моя база" }

function Base.signature(state)
	local parts = { state.slots, state.incomeMultiplier }
	for _, entry in ipairs(state.creatures) do
		table.insert(parts, entry.uid)
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
			Theme.button({
				Size = UDim2.new(0.3, -4, 1, 0),
				Position = UDim2.new(0.7, 4, 0, 0),
				Text = "💰 Продать всех",
				Color = C.Bad,
				Parent = row,
			}, function()
				Remotes.SellRarity:FireServer(rarity.id)
			end)
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
				Size = UDim2.new(0.5, 0, 0.6, 0),
				Text = creatureName(entry),
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = row,
			})
			Theme.label({
				Size = UDim2.new(0.5, 0, 0.4, 0),
				Position = UDim2.fromScale(0, 0.6),
				Text = colored(rarity.name, rarity.color),
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = row,
			})
			Theme.label({
				Size = UDim2.new(0.25, 0, 1, 0),
				Position = UDim2.fromScale(0.5, 0),
				Text = "+" .. Format.coins(Formulas.creatureBaseIncome(entry) * state.incomeMultiplier) .. "/с",
				TextColor3 = C.Good,
				Parent = row,
			})
			Theme.button({
				Size = UDim2.new(0.25, -4, 1, 0),
				Position = UDim2.new(0.75, 4, 0, 0),
				Text = "Продать " .. Format.coins(Formulas.sellValue(entry)),
				Color = C.Bad,
				Parent = row,
			}, function()
				Remotes.Sell:FireServer(entry.uid)
			end)
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
	Theme.button({
		Size = UDim2.new(0.6, 0, 0, 56),
		Text = "♻️ ПЕРЕРОДИТЬСЯ",
		Color = (levelOk and coinsOk) and C.Purple or C.CardLocked,
		LayoutOrder = 2,
		Parent = content,
	}, function()
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
			CellSize = UDim2.fromOffset(150, 120),
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
		create("Frame", {
			Size = UDim2.fromOffset(34, 34),
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			BackgroundColor3 = known and creature.color or Color3.fromRGB(20, 20, 20),
			Parent = box,
		}, { create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		Theme.label({
			Size = UDim2.new(1, 0, 0, 40),
			Position = UDim2.fromOffset(0, 38),
			Text = known and creature.name or "???",
			Parent = box,
		})
		Theme.label({
			Size = UDim2.new(1, 0, 0, 20),
			Position = UDim2.fromOffset(0, 80),
			Text = (rarity.secret and not known) and "???" or rarity.name,
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

function Rewards.signature(state)
	local r = state.rewards
	local parts = { tostring(r.canClaim), r.nextDay, r.streak, r.rewards[1] }
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

local DEFINITIONS = {
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
	definition.build(self.content, self.state)
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

function Panels:update(state)
	self.state = state
	if self.openName then
		self:rebuild()
	end
end

return Panels
