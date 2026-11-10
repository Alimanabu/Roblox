-- Windows: Factory, Base, Upgrades, Rebirth, Index, Shop.
-- Each window is redrawn only when what it shows changes.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local S = require(Shared.Strings)
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
local Daily = require(Shared.Config.Daily)
local Seasons = require(Shared.Config.Seasons)
local Formulas = require(Shared.Util.Formulas)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.Theme)
local Layout = require(script.Parent.Layout)
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

-- Confirm button: the first press asks "Sure?", the second (within 3 s) does it.
-- key is a stable button id: the "armed" state survives a window redraw.
local armed = {} -- [key] = until which os.clock() the button waits for the second press
local function confirmButton(key, props, confirmText, action)
	local normalText = props.Text
	local normalColor = props.Color or C.Accent
	local button = Theme.button(props)
	local function show()
		if armed[key] and os.clock() < armed[key] then
			button.Text = confirmText
			button.BackgroundColor3 = C.Gold
			-- A new button after a redraw must also "cool down" by the timer.
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

Panels.onRename = nil -- function(uid, currentName), set in Main.client

-- Roblox forbids paid random rewards for the player. Until there is an answer, we assume it forbids.
local function randomRestricted()
	return player:GetAttribute("PaidRandomItemsRestricted") ~= false
end

-- No answer from Roblox yet: the restrictions apply, but this is not yet a region ban.
local function policyPending()
	return player:GetAttribute("PaidRandomItemsRestricted") == nil or player:GetAttribute("PolicyUnknown") == true
end

-- How many coins can be spent on something that leads to a random reward (see Formulas.randomCoins).
local function randomCoins(state)
	return Formulas.randomCoins(state, randomRestricted())
end

-- Explanation in the window: when restricted, bought coins exist but cannot be spent at these prices.
-- We talk about the cheapest of such prices. Empty string: nothing to explain.
local function boughtCoinsText(state, costs)
	if not randomRestricted() or state.boughtCoins <= 0 then
		return ""
	end
	local earned = randomCoins(state)
	local cheapest
	for _, cost in ipairs(costs) do
		if cost > earned and cost <= state.coins and (not cheapest or cost < cheapest) then
			cheapest = cost
		end
	end
	if not cheapest then
		return ""
	end
	return if policyPending() then S.t("policy.checking") else S.t("shop.bought_coins", { coins = Format.coins(cheapest - earned) })
end

local function boughtCoinsNotice(content, text)
	if text ~= "" then
		Theme.label({
			Size = UDim2.new(1, -10, 0, 40),
			Text = text,
			TextColor3 = C.Bad,
			LayoutOrder = -1,
			Parent = content,
		})
	end
end

-- Odds window button. The label with a word is required: Roblox does not accept a lone icon.
local function oddsButton(content, panels, order)
	Theme.button({
		Size = UDim2.new(1, -10, 0, 34),
		Text = S.t("odds.open"),
		Color = C.Accent,
		LayoutOrder = order,
		Parent = content,
	}, function()
		panels:open("Odds")
	end)
end

---------------------------------------------------------------------------
-- FACTORY
---------------------------------------------------------------------------
local Factory = { title = S.t("panel.factory") }

-- Prices of the capsules the player can open right now.
local function capsuleCosts(state)
	local costs = {}
	local serverNow = workspace:GetServerTimeNow()
	for _, capsule in ipairs(Capsules.List) do
		if Formulas.capsuleInSeason(capsule, serverNow) and Formulas.capsuleUnlocked(capsule, state) then
			table.insert(costs, Formulas.capsuleCost(capsule, state))
		end
	end
	return costs
end

function Factory.signature(state)
	local parts = {
		state.level,
		state.rebirths,
		string.format("%.2f", state.luck),
		state.mods.secret,
		tostring(state.autoCraft),
		tostring(state.passes.AUTO_CRAFT),
		boughtCoinsText(state, capsuleCosts(state)),
	}
	local serverNow = workspace:GetServerTimeNow()
	for _, capsule in ipairs(Capsules.List) do
		table.insert(
			parts,
			(randomCoins(state) >= Formulas.capsuleCost(capsule, state) and "1" or "0")
				.. tostring(Formulas.isFreeCraft(capsule, state))
				.. (state.pity[capsule.id] or 0)
				.. tostring(Formulas.capsuleInSeason(capsule, serverNow))
		)
	end
	return table.concat(parts, "|")
end

function Factory.build(content, state, panels)
	list(content, 10)
	boughtCoinsNotice(content, boughtCoinsText(state, capsuleCosts(state)))

	Theme.label({
		Size = UDim2.new(1, -10, 0, 28),
		Text = S.t("factory.stats", {
			luck = string.format("%.2f", state.luck),
			time = string.format("%.1f", state.craftTime),
			used = #state.creatures,
			slots = state.slots,
		}),
		TextColor3 = C.Muted,
		LayoutOrder = 0,
		Parent = content,
	})
	Theme.label({
		Size = UDim2.new(1, -10, 0, 22),
		Text = S.t("factory.hint"),
		TextColor3 = C.Muted,
		LayoutOrder = 1,
		Parent = content,
	})
	Theme.label({
		Size = UDim2.new(1, -10, 0, 20),
		Text = S.t("odds.rounded"),
		TextColor3 = C.Muted,
		LayoutOrder = 2,
		Parent = content,
	})
	oddsButton(content, panels, 3)

	local grid = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 4,
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
	local tutorialTagged = false
	for _, capsule in ipairs(Capsules.List) do
		if not Formulas.capsuleInSeason(capsule, serverNow) then
			continue -- a seasonal capsule is not shown out of season
		end
		local unlocked = Formulas.capsuleUnlocked(capsule, state)
		local box = card({
			LayoutOrder = capsule.season and 0 or capsule.order, -- seasonal capsule first
			BackgroundColor3 = unlocked and C.Card or C.CardLocked,
			Parent = grid,
		}, { Theme.stroke(capsule.color, 3), Theme.padding(8) })
		list(box, 4)

		Theme.label({ Size = UDim2.new(1, 0, 0, 28), Text = capsule.name, TextColor3 = capsule.color, LayoutOrder = 1, Parent = box })
		Theme.label({ Size = UDim2.new(1, 0, 0, 18), Text = capsule.desc, TextColor3 = C.Muted, LayoutOrder = 2, Parent = box })

		local chancesText = {}
		for _, entry in ipairs(Formulas.rarityChances(capsule, state.luck, state.mods, state.pity[capsule.id] or 0)) do
			local rarity = Rarities.get(entry.rarity)
			local name = entry.secret and S.t("factory.secret") or rarity.name
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
				Text = S.t("factory.pity_left", { rarity = pityRarity.name, left = left }),
				TextColor3 = pityRarity.color,
				LayoutOrder = 4,
				Parent = box,
			})
			local cost = Formulas.capsuleCost(capsule, state)
			local canAfford = randomCoins(state) >= cost
			local craftButton = Theme.button({
				Size = UDim2.new(1, 0, 0, 40),
				Text = if cost == 0 then S.t("factory.craft_free") else S.t("factory.craft", { cost = Format.coins(cost) }),
				Color = canAfford and C.Good or C.Bad,
				LayoutOrder = 5,
				Parent = box,
			}, function()
				Remotes.Craft:FireServer(capsule.id)
			end)
			-- The tutorial arrow points at the first ordinary capsule (TutorialBanner).
			if not tutorialTagged and not capsule.season then
				tutorialTagged = true
				craftButton:SetAttribute("TutorialTarget", "craft")
			end
			if state.passes.AUTO_CRAFT then
				local active = state.autoCraft == capsule.id
				Theme.button({
					Size = UDim2.new(1, 0, 0, 26),
					Text = active and S.t("factory.auto_on") or S.t("factory.auto"),
					Color = active and C.Gold or C.Card,
					LayoutOrder = 6,
					Parent = box,
				}, function()
					Remotes.SetAutoCraft:FireServer(not active and capsule.id or nil)
				end)
			end
		else
			local need = S.t("factory.need_level", { level = capsule.level })
			if capsule.rebirths > 0 then
				need = S.t("factory.need_rebirths", { need = need, rebirths = capsule.rebirths })
			end
			Theme.label({ Size = UDim2.new(1, 0, 0, 40), Text = need, TextColor3 = C.Muted, LayoutOrder = 5, Parent = box })
		end
	end
end

---------------------------------------------------------------------------
-- BASE
---------------------------------------------------------------------------
local Base = { title = S.t("panel.base") }

local function floorSignature(state)
	return tostring(state.floors) .. ":" .. tostring(state.floorCost and state.coins >= state.floorCost)
end

-- Floors card: what is built and the "Build" button for the next floor.
local function floorCard(content, state, order)
	local floors = state.floors or 0
	local cost = state.floorCost
	local box = card({ Size = UDim2.new(1, -10, 0, 70), LayoutOrder = order }, { Theme.padding(8), Theme.stroke(C.Gold, 2) })
	local text
	if cost then
		local nextFloor = Formulas.Floors[floors + 1]
		local perks = S.t("base.perks", { slots = Formulas.FLOOR_SLOTS * (floors + 1), hp = nextFloor.hp })
		if nextFloor.income > 1 then
			perks = S.t("base.perks_income", { perks = perks, income = nextFloor.income })
		end
		text = S.t("base.floor_now", { floor = Formulas.Floors[floors].name, slots = state.slots, next = nextFloor.name, perks = perks })
	else
		local top = Formulas.Floors[Formulas.MAX_FLOORS]
		text = S.t("base.complete", { slots = state.slots, hp = top.hp, income = top.income })
	end
	Theme.label({
		Size = UDim2.new(cost and 0.62 or 1, 0, 1, 0),
		Text = text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = box,
	})
	if cost then
		Theme.button({
			Size = UDim2.new(0.38, -8, 1, 0),
			Position = UDim2.new(0.62, 8, 0, 0),
			Text = S.t("base.build", { cost = Format.coins(cost) }),
			Color = state.coins >= cost and C.Good or C.Bad,
			Parent = box,
		}, function()
			Remotes.BuyFloor:FireServer()
		end)
	end
	box.Parent = content
end

function Base.signature(state)
	local parts = { state.slots, state.incomeMultiplier, state.social.bonus, tostring(state.pet), floorSignature(state), tostring(randomRestricted()) }
	for _, entry in ipairs(state.creatures) do
		table.insert(parts, entry.uid .. tostring(entry.nickname))
	end
	return table.concat(parts, "|")
end

function Base.build(content, state, panels)
	list(content, 8)

	Theme.label({
		Size = UDim2.new(1, -10, 0, 28),
		Text = S.t("base.stats", { used = #state.creatures, slots = state.slots, income = Format.coins(state.income) }),
		TextColor3 = C.Coins,
		LayoutOrder = 0,
		Parent = content,
	})
	local social = state.social
	local bonusParts = {
		S.t("base.friends", { friends = social.friends, bonus = social.friends * 10 }),
		social.premium and "💎 Premium +10%" or "💎 Premium: +10%",
	}
	if social.groupEnabled then
		table.insert(bonusParts, social.group and S.t("base.group_on") or S.t("base.group_off"))
	end
	Theme.label({
		Size = UDim2.new(1, -10, 0, 22),
		Text = table.concat(bonusParts, "   "),
		TextColor3 = C.Good,
		LayoutOrder = 1,
		Parent = content,
	})
	floorCard(content, state, 2)

	if #state.creatures == 0 then
		Theme.label({
			Size = UDim2.new(1, -10, 0, 60),
			Text = S.t("base.empty"),
			TextColor3 = C.Muted,
			LayoutOrder = 3,
			Parent = content,
		})
		return
	end

	oddsButton(content, panels, 9)

	-- Groups by rarity: fuse / sell all.
	local counts, fusable = {}, {}
	for _, entry in ipairs(state.creatures) do
		local creature = Creatures.get(entry.id)
		if creature then
			counts[creature.rarity] = (counts[creature.rarity] or 0) + 1
			if not (randomRestricted() and Formulas.isPaidRandom(entry)) then
				fusable[creature.rarity] = (fusable[creature.rarity] or 0) + 1
			end
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
					Color = (fusable[rarity.id] or 0) >= Formulas.FUSE_COUNT and C.Purple or C.CardLocked,
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
				Text = S.t("base.sell_all"),
				Color = C.Bad,
				Parent = row,
			}
			if rarity.rank >= 5 then
				confirmButton("sellAll:" .. rarity.id, sellAllProps, S.t("base.confirm"), sellAll)
			else
				Theme.button(sellAllProps, sellAll)
			end
			row.Parent = content
		end
	end
	Theme.label({
		Size = UDim2.new(1, -10, 0, 20),
		Text = S.t("base.hint"),
		TextColor3 = C.Muted,
		LayoutOrder = 50,
		Parent = content,
	})

	-- List of brainrots, strongest on top (they also stand on the top floor).
	local places = Formulas.layout(state.creatures, state.floors or 0)
	for order, place in ipairs(places) do
		local entry = place.entry
		local floorInfo = place.floor and Formulas.Floors[place.floor]
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
			-- Tap the name to rename.
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
				Text = colored(rarity.name, rarity.color) .. (place.floor == 2 and colored("  " .. S.t("base.on_floor2"), C.Gold) or ""),
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = row,
			})
			Theme.label({
				Size = UDim2.new(0.21, 0, 1, 0),
				Position = UDim2.fromScale(0.42, 0),
				Text = S.t("common.per_second", { coins = "+" .. Format.coins(Formulas.creatureBaseIncome(entry) * (floorInfo and floorInfo.income or 1) * state.incomeMultiplier) }),
				TextColor3 = C.Good,
				Parent = row,
			})
			-- Pet: this brainrot will run after you.
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
				Text = S.t("base.sell", { coins = Format.coins(Formulas.sellValue(entry)) }),
				Color = C.Bad,
				Parent = row,
			}
			-- Rare ones (Aura and above) and mutants are sold only with confirmation.
			if rarity.rank >= 5 or entry.mut ~= "normal" then
				confirmButton("sell:" .. entry.uid, sellProps, S.t("base.confirm_sell"), sell)
			else
				Theme.button(sellProps, sell)
			end
			row.Parent = content
		end
	end
end

---------------------------------------------------------------------------
-- UPGRADES
---------------------------------------------------------------------------
local UpgradesPanel = { title = S.t("panel.upgrades") }

local function upgradeCoins(state, upgrade)
	return if upgrade.leadsToRandom then randomCoins(state) else state.coins
end

local function upgradeCosts(state)
	local costs = {}
	for _, upgrade in ipairs(Upgrades.List) do
		local level = state.upgrades[upgrade.id] or 0
		if upgrade.leadsToRandom and level < upgrade.maxLevel then
			table.insert(costs, Upgrades.cost(upgrade.id, level))
		end
	end
	return costs
end

function UpgradesPanel.signature(state)
	local parts = { floorSignature(state), boughtCoinsText(state, upgradeCosts(state)) }
	for _, upgrade in ipairs(Upgrades.List) do
		local level = state.upgrades[upgrade.id] or 0
		table.insert(parts, level .. ":" .. (upgradeCoins(state, upgrade) >= Upgrades.cost(upgrade.id, level) and 1 or 0))
	end
	return table.concat(parts, "|")
end

function UpgradesPanel.build(content, state)
	list(content, 10)
	boughtCoinsNotice(content, boughtCoinsText(state, upgradeCosts(state)))
	floorCard(content, state, 0)
	-- The tutorial arrow points at the cheapest upgrade that is not maxed (TutorialBanner).
	local cheapest, cheapestCost
	for _, upgrade in ipairs(Upgrades.List) do
		local level = state.upgrades[upgrade.id] or 0
		local cost = Upgrades.cost(upgrade.id, level)
		if level < upgrade.maxLevel and (not cheapest or cost < cheapestCost) then
			cheapest, cheapestCost = upgrade, cost
		end
	end
	for order, upgrade in ipairs(Upgrades.List) do
		local level = state.upgrades[upgrade.id] or 0
		local maxed = level >= upgrade.maxLevel
		local cost = Upgrades.cost(upgrade.id, level)
		local row = card({ Size = UDim2.new(1, -10, 0, 80), LayoutOrder = order }, { Theme.padding(8) })
		Theme.label({
			Size = UDim2.new(0.65, 0, 0.5, 0),
			Text = upgrade.name .. "  " .. colored(S.t("upgrades.level", { level = level, max = upgrade.maxLevel }), C.Muted),
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
		local buyButton = Theme.button({
			Size = UDim2.new(0.35, -8, 1, 0),
			Position = UDim2.new(0.65, 8, 0, 0),
			Text = maxed and S.t("upgrades.max") or Format.coins(cost),
			Color = maxed and C.CardLocked or (upgradeCoins(state, upgrade) >= cost and C.Good or C.Bad),
			Parent = row,
		}, function()
			Remotes.BuyUpgrade:FireServer(upgrade.id)
		end)
		if upgrade == cheapest then
			buyButton:SetAttribute("TutorialTarget", "buy")
		end
		row.Parent = content
	end
end

---------------------------------------------------------------------------
-- REBIRTH
---------------------------------------------------------------------------
local Rebirth = { title = S.t("hud.rebirth") }

function Rebirth.signature(state)
	local cost = Rebirths.cost(state.rebirths)
	return table.concat({ state.rebirths, state.level, randomCoins(state) >= cost and 1 or 0, boughtCoinsText(state, { cost }) }, "|")
end

function Rebirth.build(content, state)
	list(content, 10)
	local cost = Rebirths.cost(state.rebirths)
	boughtCoinsNotice(content, boughtCoinsText(state, { cost }))
	local levelRequired = Rebirths.levelRequired(state.rebirths)
	local nextTitle = Rebirths.titleFor(state.rebirths + 1)
	local levelOk = state.level >= levelRequired
	local coinsOk = randomCoins(state) >= cost

	local lines = {
		S.t("rebirth.count", { count = colored(tostring(state.rebirths), C.Gold) }),
		S.t("rebirth.next_title", { title = colored(S.t("rebirth.quoted", { title = nextTitle }), C.Gold) }),
		"",
		colored(S.t("rebirth.gain"), C.Good),
		S.t("rebirth.bonus", { income = math.floor(Rebirths.INCOME_BONUS * 100), luck = math.floor(Rebirths.LUCK_BONUS * 100) }),
		"",
		colored(S.t("rebirth.lose"), C.Bad),
		S.t("rebirth.lose_list"),
		colored(S.t("rebirth.keep"), C.Muted),
		"",
		(levelOk and "✅" or "❌") .. " " .. S.t("rebirth.level_req", { need = levelRequired, level = state.level }),
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
		Text = S.t("rebirth.button"),
		Color = (levelOk and coinsOk) and C.Purple or C.CardLocked,
		LayoutOrder = 2,
		Parent = content,
	}, S.t("rebirth.confirm"), function()
		Remotes.Rebirth:FireServer()
	end)
end

---------------------------------------------------------------------------
-- INDEX (collection)
---------------------------------------------------------------------------
local Index = { title = S.t("panel.index") }

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
		Text = S.t("index.count", { found = found, total = #Creatures.List }),
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
-- SHOP
---------------------------------------------------------------------------
local Shop = { title = S.t("hud.shop") }

function Shop.signature(state)
	local parts = {}
	for key in pairs(state.passes) do
		table.insert(parts, key)
	end
	table.sort(parts)
	table.insert(parts, tostring(player:GetAttribute("PaidRandomItemsRestricted")))
	table.insert(parts, tostring(policyPending()))
	table.insert(parts, string.format("%.2f", state.luck))
	table.insert(parts, tostring(state.luckBoostLeft > 0))
	table.insert(parts, state.level)
	table.insert(parts, state.rebirths)
	table.insert(parts, state.mods.secret)
	return table.concat(parts, "|")
end

-- How boosters change the chance of the rarest rarity of the best open capsule: numbers before purchase.
local function luckExample(content, state, order)
	local capsule
	for _, candidate in ipairs(Capsules.List) do
		if not candidate.season and Formulas.capsuleUnlocked(candidate, state) then
			capsule = candidate
		end
	end
	local top = Formulas.pityRarity(capsule)
	local function odds(luck)
		for _, entry in ipairs(Formulas.rarityChances(capsule, luck, state.mods)) do
			if entry.rarity == top then
				return Format.percent(entry.chance)
			end
		end
		return Format.percent(0)
	end
	Theme.label({
		Size = UDim2.new(1, -10, 0, 22),
		Text = S.t("odds.example", {
			capsule = capsule.name,
			rarity = Rarities.get(top).name,
			now = odds(state.luck),
			pass = S.t("pass.LUCKY.name"),
			lucky = odds(state.passes.LUCKY and state.luck or state.luck * Formulas.LUCKY_MULT),
			product = S.t("product.LUCK_BOOST.name"),
			boost = odds(state.luckBoostLeft > 0 and state.luck or state.luck * Formulas.LUCK_BOOST_MULT),
		}),
		TextColor3 = C.Muted,
		LayoutOrder = order,
		Parent = content,
	})
end

function Shop.build(content, state, panels)
	list(content, 8)
	if not randomRestricted() then
		luckExample(content, state, -2)
		oddsButton(content, panels, -1)
	end
	Theme.label({ Size = UDim2.new(1, -10, 0, 30), Text = S.t("shop.passes"), TextColor3 = C.Gold, LayoutOrder = 0, Parent = content })

	local order = 1
	local function row(kind, item, owned, onBuy, blocked)
		order += 1
		local box = card({ Size = UDim2.new(1, -10, 0, 64), LayoutOrder = order }, { Theme.padding(8) })
		Theme.label({ Size = UDim2.new(0.65, 0, 0.55, 0), Text = S.t(kind .. "." .. item.key .. ".name"), TextXAlignment = Enum.TextXAlignment.Left, Parent = box })
		Theme.label({
			Size = UDim2.new(0.65, 0, 0.4, 0),
			Position = UDim2.fromScale(0, 0.6),
			Text = S.t(kind .. "." .. item.key .. ".desc"),
			TextColor3 = C.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = box,
		})
		local text, color
		if blocked then
			text, color = S.t(if policyPending() then "shop.checking" else "shop.region"), C.CardLocked
		elseif owned then
			text, color = S.t("shop.owned"), C.CardLocked
		elseif item.id == 0 then
			text, color = S.t("shop.soon"), C.CardLocked
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
			if not owned and not blocked and item.id ~= 0 then
				onBuy()
			end
		end)
		box.Parent = content
	end

	-- Where Roblox forbids paid random rewards, we do not sell what leads to them.
	local restricted = randomRestricted()
	for _, pass in ipairs(Monetization.GamePasses) do
		row("pass", pass, state.passes[pass.key], function()
			MarketplaceService:PromptGamePassPurchase(player, pass.id)
		end, pass.leadsToRandom and restricted)
	end

	order += 1
	Theme.label({ Size = UDim2.new(1, -10, 0, 30), Text = S.t("shop.boosts"), TextColor3 = C.Gold, LayoutOrder = order, Parent = content })
	for _, product in ipairs(Monetization.Products) do
		row("product", product, false, function()
			MarketplaceService:PromptProductPurchase(player, product.id)
		end, product.leadsToRandom and restricted)
	end
end

---------------------------------------------------------------------------
-- ODDS: everything Roblox requires to disclose before purchase
---------------------------------------------------------------------------
local OddsPanel = { title = S.t("panel.odds") }

function OddsPanel.signature(state)
	local parts = {
		string.format("%.2f", state.luck),
		tostring(state.luckBoostLeft > 0),
		tostring(state.passes.LUCKY),
		tostring(randomRestricted()),
		tostring(policyPending()),
		state.mods.secret,
		state.mods.mutation,
		state.mods.mutation67,
	}
	local serverNow = workspace:GetServerTimeNow()
	for _, capsule in ipairs(Capsules.List) do
		table.insert(parts, (state.pity[capsule.id] or 0) .. tostring(Formulas.capsuleInSeason(capsule, serverNow)))
	end
	return table.concat(parts, "|")
end

-- Luck now and with the boosters the player does not have yet. Where paid luck is forbidden,
-- only "now": there is nothing to offer for purchase.
local function luckColumns(state)
	local columns = { { name = S.t("odds.now"), luck = state.luck } }
	if randomRestricted() then
		return columns
	end
	local canAddLucky = not state.passes.LUCKY
	local canAddBoost = state.luckBoostLeft <= 0
	if canAddLucky then
		table.insert(columns, { name = S.t("pass.LUCKY.name"), luck = state.luck * Formulas.LUCKY_MULT })
	end
	if canAddBoost then
		table.insert(columns, { name = S.t("product.LUCK_BOOST.name"), luck = state.luck * Formulas.LUCK_BOOST_MULT })
	end
	if canAddLucky and canAddBoost then
		table.insert(columns, { name = S.t("odds.both"), luck = state.luck * Formulas.LUCKY_MULT * Formulas.LUCK_BOOST_MULT })
	end
	return columns
end

local function creatureNames(pool)
	local names = {}
	for _, creature in ipairs(pool) do
		table.insert(names, creature.name)
	end
	return table.concat(names, ", ")
end

function OddsPanel.build(content, state)
	list(content, 8)
	local order = 0
	local function add(text, color)
		order += 1
		Theme.label({
			Size = UDim2.new(1, -10, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = text,
			TextScaled = false,
			TextSize = 14,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = color,
			LayoutOrder = order,
			Parent = content,
		})
	end

	local columns = luckColumns(state)
	add(S.t("odds.intro", { luck = string.format("%.2f", state.luck) }), C.Coins)
	add(S.t("odds.rule", { secret = Format.percent(Formulas.MAX_SECRET_CHANCE), mutation = Formulas.MAX_MUTATION_LUCK }), C.Muted)
	if randomRestricted() then
		add(S.t(if policyPending() then "policy.checking" else "odds.region"), C.Bad)
	else
		local names = {}
		for _, column in ipairs(columns) do
			table.insert(names, column.name)
		end
		add(S.t("odds.columns", { columns = table.concat(names, " → ") }), C.Muted)
	end
	add(S.t("odds.rounded"), C.Muted)

	-- One row per outcome: the chance in each luck column.
	local function odds(chanceIn)
		local values = {}
		for _, column in ipairs(columns) do
			table.insert(values, Format.percent(chanceIn(column.luck)))
		end
		return table.concat(values, " → ")
	end

	local serverNow = workspace:GetServerTimeNow()
	for _, capsule in ipairs(Capsules.List) do
		if Formulas.capsuleInSeason(capsule, serverNow) then
			local pity = state.pity[capsule.id] or 0
			local lines = { colored(capsule.name, capsule.color) }
			for index, entry in ipairs(Formulas.rarityChances(capsule, state.luck, state.mods, pity)) do
				local rarity = Rarities.get(entry.rarity)
				local count = #Formulas.creaturePool(entry.rarity, capsule.season)
				local chances = odds(function(luck)
					return Formulas.rarityChances(capsule, luck, state.mods, pity)[index].chance
				end)
				local name = entry.secret and S.t("factory.secret") or rarity.name
				local pool = S.t("odds.pool", { count = count, each = Format.percent(entry.chance / count) })
				table.insert(lines, colored(name, rarity.color) .. ": " .. chances .. " (" .. pool .. ")")
			end
			add(table.concat(lines, "\n"))
		end
	end

	local mutationLines = { S.t("odds.mutations") }
	for index, entry in ipairs(Formulas.mutationChances(state.luck, state.mods)) do
		local mutation = Mutations.get(entry.mutation)
		local chances = odds(function(luck)
			return Formulas.mutationChances(luck, state.mods)[index].chance
		end)
		table.insert(mutationLines, (entry.mutation == "normal" and S.t("odds.no_mutation") or mutation.name) .. ": " .. chances)
	end
	add(table.concat(mutationLines, "\n"))

	add(S.t("odds.fuse", { count = Formulas.FUSE_COUNT }))
	add(S.t("odds.pity"))

	local poolLines = { S.t("odds.pool_title") }
	for _, rarity in ipairs(Rarities.List) do
		table.insert(poolLines, colored(rarity.name, rarity.color) .. ": " .. creatureNames(Formulas.creaturePool(rarity.id)))
	end
	for _, capsule in ipairs(Capsules.List) do
		if capsule.season and Formulas.capsuleInSeason(capsule, serverNow) then
			table.insert(poolLines, colored(capsule.name, capsule.color))
			for _, rarity in ipairs(Rarities.List) do
				local pool = Formulas.creaturePool(rarity.id, capsule.season)
				if capsule.weights[rarity.id] then
					table.insert(poolLines, colored(rarity.name, rarity.color) .. ": " .. creatureNames(pool))
				end
			end
		end
	end
	add(table.concat(poolLines, "\n"))
end

---------------------------------------------------------------------------
-- REWARDS: daily streak and quests
---------------------------------------------------------------------------
local Rewards = { title = S.t("panel.rewards") }
local codeDraft = "" -- the promo code text is not lost when the window is redrawn

-- How many minutes the player has been in the game this session.
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
		math.floor(r.secondsToReset / 60), -- the timer to the next reward is redrawn every minute
		r.nextDay,
		r.streak,
		S.text(r.rewards[1]),
		math.floor(playMinutes(state)),
		tostring(state.wheel.freeAvailable),
		state.wheel.extraSpins,
		tostring(randomRestricted()),
		tostring(policyPending()),
	}
	for _, gift in ipairs(state.playtime.gifts) do
		table.insert(parts, tostring(gift.claimed))
	end
	for _, quest in ipairs(r.quests) do
		table.insert(parts, quest.index .. ":" .. quest.progress .. tostring(quest.claimed))
	end
	return table.concat(parts, "|")
end

function Rewards.build(content, state)
	local r = state.rewards
	list(content, 10)
	Theme.label({
		Size = UDim2.new(1, -10, 0, 28),
		Text = S.t("rewards.hint"),
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
		Theme.label({ Size = UDim2.new(1, 0, 0, 22), Text = (done and "✅ " or "") .. S.t("rewards.day", { day = day }), Parent = cell })
		Theme.label({
			Size = UDim2.new(1, 0, 1, -24),
			Position = UDim2.fromOffset(0, 24),
			Text = S.text(text),
			TextColor3 = day == 7 and C.Gold or C.Muted,
			Parent = cell,
		})
	end

	-- Lucky wheel. We show the odds BEFORE the spin: spins are sold for Robux,
	-- and Roblox requires disclosing the odds of paid random rewards.
	local wheelTotal = 0
	for _, slot in ipairs(Daily.Wheel) do
		wheelTotal += slot.weight
	end
	local oddsParts = {}
	for _, slot in ipairs(Daily.Wheel) do
		table.insert(oddsParts, slot.name .. " " .. Format.percent(slot.weight / wheelTotal))
	end
	Theme.label({
		Size = UDim2.new(1, -10, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = S.t("rewards.wheel_odds", { odds = table.concat(oddsParts, " • ") }),
		TextScaled = false,
		TextSize = 14,
		TextWrapped = true,
		TextColor3 = C.Muted,
		LayoutOrder = 49,
		Parent = content,
	})
	local wheel = state.wheel
	local wheelRow = create("Frame", {
		Size = UDim2.new(1, -10, 0, 48),
		BackgroundTransparency = 1,
		LayoutOrder = 50,
		Parent = content,
	})
	-- Where paid random rewards are forbidden, the server will not spend bought spins.
	local spinsBlocked = randomRestricted()
	local paidSpins = wheel.extraSpins > 0 and not spinsBlocked
	local canSpin = wheel.freeAvailable or paidSpins
	Theme.button({
		Size = UDim2.new(0.6, -6, 1, 0),
		Text = wheel.freeAvailable and S.t("rewards.spin_free")
			or (paidSpins and S.t("rewards.spin", { count = wheel.extraSpins }) or S.t("rewards.spin_tomorrow")),
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
		Text = spinsBlocked and S.t("rewards.spins_blocked")
			or (spinsProduct.id ~= 0 and S.t("rewards.spins_buy", { price = spinsProduct.price }) or S.t("rewards.spins_soon")),
		Color = (spinsProduct.id ~= 0 and not spinsBlocked) and C.Purple or C.CardLocked,
		Parent = wheelRow,
	}, function()
		if spinsProduct.id ~= 0 and not spinsBlocked then
			MarketplaceService:PromptProductPurchase(player, spinsProduct.id)
		end
	end)

	-- Gifts for time in game.
	local minutes = playMinutes(state)
	Theme.label({
		Size = UDim2.new(1, -10, 0, 28),
		Text = S.t("rewards.gifts", { minutes = math.floor(minutes) }),
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
			text, color = S.t("rewards.gift_done", { minutes = gift.minutes }), C.CardLocked
		elseif ready then
			text, color = S.t("rewards.gift_claim", { reward = gift.reward }), C.Good
		else
			text, color = S.t("rewards.gift_wait", { minutes = math.ceil(gift.minutes - minutes), reward = gift.reward }), C.Card
		end
		Theme.button({ Text = text, Color = color, LayoutOrder = index, Parent = giftGrid }, function()
			Remotes.ClaimGift:FireServer(index)
		end)
	end

	-- Promo codes.
	local codeRow = create("Frame", {
		Size = UDim2.new(1, -10, 0, 44),
		BackgroundTransparency = 1,
		LayoutOrder = 90,
		Parent = content,
	})
	local codeBox = create("TextBox", {
		Size = UDim2.new(0.65, -8, 1, 0),
		BackgroundColor3 = C.Card,
		PlaceholderText = S.t("rewards.code_placeholder"),
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
		Text = S.t("rewards.code_enter"),
		Color = C.Purple,
		Parent = codeRow,
	}, function()
		Remotes.RedeemCode:FireServer(codeBox.Text)
		codeBox.Text = ""
		codeDraft = ""
	end)

	local claimButton = Theme.button({
		Size = UDim2.new(0.5, 0, 0, 48),
		Text = r.canClaim and S.t("rewards.claim_day", { day = r.nextDay })
			or S.t("rewards.come_back", { time = Format.time(r.secondsToReset) }),
		Color = r.canClaim and C.Good or C.CardLocked,
		LayoutOrder = 2,
		Parent = content,
	}, function()
		Remotes.ClaimDaily:FireServer()
	end)
	claimButton:SetAttribute("TutorialTarget", "daily")

	Theme.label({
		Size = UDim2.new(1, -10, 0, 28),
		Text = S.t("rewards.quests", { time = Format.time(r.secondsToReset) }),
		TextColor3 = C.Coins,
		LayoutOrder = 3,
		Parent = content,
	})
	for order, quest in ipairs(r.quests) do
		local done = quest.progress >= quest.target
		local box = card({ Size = UDim2.new(1, -10, 0, 70), LayoutOrder = 10 + order }, { Theme.padding(8) })
		Theme.label({
			Size = UDim2.new(0.65, 0, 0.5, 0),
			Text = S.text(quest.text),
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
			text, color = S.t("rewards.received"), C.CardLocked
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
-- HOW TO PLAY
---------------------------------------------------------------------------
local Help = { title = S.t("hud.help") }

local HELP_SECTIONS = {
	{ S.t("hud.factory"), S.t("help.1.body") },
	{ S.t("hud.base"), S.t("help.2.body") },
	{ S.t("help.3.title"), S.t("help.3.body") },
	{ S.t("help.4.title"), S.t("help.4.body") },
	{ S.t("help.5.title"), S.t("help.5.body") },
	{ S.t("help.6.title"), S.t("help.6.body") },
	{ S.t("help.7.title"), S.t("help.7.body") },
	{ S.t("help.8.title"), S.t("help.8.body") },
	{ S.t("help.9.title"), S.t("help.9.body") },
	{ S.t("help.10.title"), S.t("help.10.body") },
	{ S.t("help.11.title"), S.t("help.11.body") },
	{ S.t("help.12.title"), S.t("help.12.body") },
	{ S.t("hud.rebirth"), S.t("help.13.body") },
	{ S.t("hud.rewards"), S.t("help.14.body") },
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
-- TRADE
---------------------------------------------------------------------------
local Trade = { title = S.t("panel.trade") }
Panels.trade = nil -- trade state from the server (nil: no trade)

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

local function column(content, x, top, title)
	local frame = create("Frame", {
		Size = UDim2.new(0.5, -6, 0, 300 - top),
		Position = UDim2.new(x, x > 0 and 6 or 0, 0, top),
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
			Text = S.t("trade.hint"),
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
					Text = S.t("trade.offer"),
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
				Text = S.t("trade.nobody"),
				LayoutOrder = 1,
				Parent = content,
			})
		end
		return
	end

	-- A trade is in progress.
	local selected = {}
	for _, uid in ipairs(trade.myOffer) do
		selected[uid] = true
	end
	-- The server refused: we explain above the lists, the buttons stay in place and are visible without scrolling.
	local top = 0
	if trade.notice then
		top = 44
		Theme.label({ Size = UDim2.new(1, 0, 0, 40), Text = S.text(trade.notice), TextColor3 = C.Bad, Parent = content })
	end
	local mine = column(content, 0, top, S.t("trade.you_give", { count = #trade.myOffer }))
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

	local theirs = column(content, 0.5, top, S.t("trade.they_give", { name = trade.partnerName }))
	for order, entry in ipairs(trade.theirOffer) do
		offerRow(theirs, order, entry, false, nil)
	end

	local status
	if trade.confirmAt then
		status = S.t("trade.countdown", { seconds = math.max(0, math.ceil(trade.confirmAt - workspace:GetServerTimeNow())) })
	else
		status = (trade.myReady and S.t("trade.you_ready") or S.t("trade.you_not_ready"))
			.. "  •  "
			.. S.t(if trade.theirReady then "trade.they_ready" else "trade.they_not_ready", { name = trade.partnerName })
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
		Text = trade.myReady and S.t("trade.unready") or S.t("trade.ready"),
		Color = trade.myReady and C.Gold or C.Good,
		Parent = content,
	}, function()
		Remotes.TradeReady:FireServer(not trade.myReady)
	end)
	Theme.button({
		Size = UDim2.new(0.5, -6, 0, 44),
		Position = UDim2.new(0.5, 6, 0, 340),
		Text = S.t("trade.leave"),
		Color = C.Bad,
		Parent = content,
	}, function()
		Remotes.TradeCancel:FireServer()
	end)
end

---------------------------------------------------------------------------
-- SETTINGS
---------------------------------------------------------------------------
local SettingsPanel = { title = S.t("panel.settings") }

local SETTINGS = {
	{ key = "music", name = S.t("settings.music") },
	{ key = "sfx", name = S.t("settings.sfx") },
	{ key = "announcements", name = S.t("settings.announcements") },
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
			Text = on and S.t("settings.on") or S.t("settings.off"),
			Color = on and C.Good or C.Bad,
			Parent = row,
		}, function()
			Remotes.SetSetting:FireServer(setting.key, not on)
		end)
		row.Parent = content
	end
end

---------------------------------------------------------------------------
-- SKINS
---------------------------------------------------------------------------
local SkinsPanel = { title = S.t("panel.skins") }
local selectedSkin = nil -- selected skin; nil = "remove skin"

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
		Text = S.t("skins.hint"),
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
			text, color = isSelected and S.t("skins.selected") or S.t("skins.select"), isSelected and C.Gold or C.Good
		elseif skin.price then
			text, color = Format.coins(skin.price), state.coins >= skin.price and C.Good or C.Bad
		else
			text, color = S.t("skins.secret"), C.CardLocked
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
		Text = selectedSkin == nil and S.t("skins.remove_mode") or S.t("skins.remove_select"),
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
			Text = selectedSkin and S.t("skins.put_on") or S.t("skins.remove"),
			Color = selectedSkin and C.Purple or C.Bad,
			Parent = row,
		}, function()
			Remotes.ApplySkin:FireServer(entry.uid, selectedSkin)
		end)
		row.Parent = content
	end
end

---------------------------------------------------------------------------
-- AURA BATTLES
---------------------------------------------------------------------------
local BattlesPanel = { title = S.t("help.10.title") }

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
		Text = S.t("battles.stats", { rank = b.rank, points = b.points, wins = b.wins, losses = b.losses }),
		TextColor3 = C.Gold,
		LayoutOrder = 0,
		Parent = content,
	})
	Theme.label({
		Size = UDim2.new(1, -10, 0, 22),
		Text = S.t("battles.hint", { left = b.rewardsLeft }),
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
		Theme.label({ Size = UDim2.new(1, 0, 1, 0), Text = S.t("battles.no_team"), TextColor3 = C.Muted, Parent = teamRow })
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
		Text = S.t("battles.train"),
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
				Text = S.t("battles.challenge"),
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
-- ACHIEVEMENTS
---------------------------------------------------------------------------
local AchievementsPanel = { title = S.t("hud.achievements") }

function AchievementsPanel.signature(state)
	return tostring(state.achievements.count)
end

function AchievementsPanel.build(content, state)
	list(content, 6)
	Theme.label({
		Size = UDim2.new(1, -10, 0, 28),
		Text = S.t("achievements.count", { count = state.achievements.count, total = state.achievements.total }),
		TextColor3 = C.Coins,
		LayoutOrder = 0,
		Parent = content,
	})
	-- Earned ones first, then the rest (in list order).
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
-- TEST (admins / Studio only)
---------------------------------------------------------------------------
local Admin = { title = S.t("panel.admin") }

local ADMIN_BUTTONS = {
	{ "💰 +1K", "coins", 1000 },
	{ "💰 +1M", "coins", 1000000 },
	{ "💰 +1B", "coins", 1000000000 },
	{ S.t("admin.level1"), "levels", 1 },
	{ S.t("admin.level10"), "levels", 10 },
	{ S.t("rarity.sigma.name"), "creature", "sigma" },
	{ S.t("rarity.aura.name"), "creature", "aura" },
	{ S.t("rarity.skibidi.name"), "creature", "skibidi" },
	{ S.t("rarity.god.name"), "creature", "god" },
	{ "SIX SEVEN", "creature", "sixseven" },
	{ S.t("admin.mutant"), "mutant" },
	{ S.t("event.luck_storm.name"), "event", "luck_storm" },
	{ S.t("event.money_rain.name"), "event", "money_rain" },
	{ S.t("admin.mutagen"), "event", "mutant_fog" },
	{ S.t("admin.turbo"), "event", "turbo" },
	{ S.t("admin.minute67"), "event", "minute67" },
	{ S.t("help.11.title"), "event", "boss" },
	{ S.t("admin.wild_button"), "wild" },
	{ S.t("admin.season_halloween"), "season", "halloween" },
	{ S.t("admin.season_newyear"), "season", "newyear" },
	{ S.t("admin.season_valentine"), "season", "valentine" },
	{ S.t("admin.season_summer"), "season", "summer" },
	{ S.t("admin.season_off_button"), "season", "" },
	{ S.t("admin.skip_tutorial"), "skipTutorial" },
	{ S.t("admin.reset_daily"), "resetDaily" },
	{ S.t("admin.remove_floors"), "removeFloors" },
	{ S.t("admin.reset"), "reset" },
}

function Admin.signature()
	return "admin"
end

function Admin.build(content)
	list(content, 8)
	Theme.label({
		Size = UDim2.new(1, -10, 0, 24),
		Text = S.t("admin.hint"),
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
	Odds = OddsPanel,
}

Panels.PC_CLOSE = Vector2.new(44, 40) -- the ✕ of a window on PC, in units of the UIScale

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
	self.closeButton = Theme.button({
		Name = "CloseWindow",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(Panels.PC_CLOSE.X, Panels.PC_CLOSE.Y),
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

-- The window stays in units of the UIScale (Main.updateScale), its ✕ does not: on a touch screen it is at least
-- Layout.PT.CLOSE points (36), otherwise a phone (scale 0.5) shrinks it to 22x20. The list moves down under it.
function Panels:applyLayout(touch, scale)
	local close = Panels.PC_CLOSE
	if touch then
		local side = math.max(close.X, Layout.PT.CLOSE / scale)
		close = Vector2.new(side, side)
	end
	self.closeButton.Size = UDim2.fromOffset(close.X, close.Y)
	self.titleLabel.Size = UDim2.new(1, -(close.X + 36), 0, 44)
	local top = math.max(60, 10 + close.Y + 6)
	self.content.Position = UDim2.fromOffset(10, top)
	self.content.Size = UDim2.new(1, -20, 1, -(top + 10))
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

-- Redraw the window even if the player state did not change (for example, a trade).
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
