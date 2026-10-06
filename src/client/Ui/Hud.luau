-- Основной экран: монеты, доход, уровень, меню и уведомления.

local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Util.Format)

local Theme = require(script.Parent.Theme)
local create = Theme.create
local C = Theme.Colors

local Hud = {}
Hud.__index = Hud

local MENU = {
	{ id = "Rewards", text = "🎁 Награды", color = Color3.fromRGB(255, 120, 60) },
	{ id = "Factory", text = "🏭 Фабрика", color = C.Accent },
	{ id = "Base", text = "🧠 База", color = C.Blue },
	{ id = "Upgrades", text = "⬆️ Улучшения", color = C.Good },
	{ id = "Rebirth", text = "♻️ Перерождение", color = C.Purple },
	{ id = "Index", text = "📖 Индекс", color = Color3.fromRGB(80, 180, 200) },
	{ id = "Achievements", text = "🏆 Достижения", color = Color3.fromRGB(200, 150, 40) },
	{ id = "Trade", text = "🤝 Обмен", color = Color3.fromRGB(60, 170, 140) },
	{ id = "Battles", text = "⚔️ Баттлы", color = Color3.fromRGB(200, 60, 90) },
	{ id = "Skins", text = "🎨 Скины", color = Color3.fromRGB(220, 90, 200) },
	{ id = "Shop", text = "🛒 Магазин", color = C.Gold },
	{ id = "Help", text = "❓ Как играть", color = Color3.fromRGB(120, 120, 150) },
	{ id = "Admin", text = "🛠 Тест", color = Color3.fromRGB(70, 70, 90), adminOnly = true },
}

function Hud.new(screenGui, onMenu, giftsReady)
	local self = setmetatable({}, Hud)
	self.giftsReady = giftsReady

	-- Монеты сверху по центру.
	local coinsFrame = create("Frame", {
		Name = "Coins",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(320, 86),
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 0.15,
		Parent = screenGui,
	}, { Theme.corner(16), Theme.stroke(C.Coins, 3) })
	self.coinsLabel = Theme.label({
		Size = UDim2.new(1, -16, 0, 50),
		Position = UDim2.fromOffset(8, 4),
		TextColor3 = C.Coins,
		Text = "$0",
		Parent = coinsFrame,
	})
	self.incomeLabel = Theme.label({
		Size = UDim2.new(1, -16, 0, 26),
		Position = UDim2.fromOffset(8, 54),
		TextColor3 = C.Good,
		Text = "+$0/с",
		Parent = coinsFrame,
	})

	-- Уровень — узкая полоска под монетами (левый верх занимает чат Roblox).
	local levelFrame = create("Frame", {
		Name = "Level",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 98),
		Size = UDim2.fromOffset(320, 50),
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 0.15,
		Parent = screenGui,
	}, { Theme.corner(16), Theme.stroke(C.Purple, 3) })
	self.titleLabel = Theme.label({
		Size = UDim2.new(1, -16, 0, 22),
		Position = UDim2.fromOffset(8, 3),
		Text = "Нуб • ур. 1",
		Parent = levelFrame,
	})
	local bar = create("Frame", {
		Size = UDim2.new(1, -16, 0, 18),
		Position = UDim2.fromOffset(8, 27),
		BackgroundColor3 = C.Card,
		Parent = levelFrame,
	}, { Theme.corner(8) })
	self.xpFill = create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = C.Purple,
		Parent = bar,
	}, { Theme.corner(8) })
	self.xpLabel = Theme.label({
		Size = UDim2.fromScale(1, 1),
		Text = "0 / 10 XP",
		ZIndex = 2,
		Parent = bar,
	})

	-- Кнопка настроек рядом с уровнем.
	Theme.button({
		Name = "SettingsButton",
		-- Слева от монет: справа их закрывает список игроков Roblox.
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(0.5, -168, 0, 8),
		Size = UDim2.fromOffset(44, 44),
		Text = "⚙️",
		Color = C.Background,
		Parent = screenGui,
	}, function()
		onMenu("Settings")
	end)

	-- Удача сверху справа.
	local luckFrame = create("Frame", {
		Name = "Luck",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0.3, 0), -- ниже списка игроков Roblox
		Size = UDim2.fromOffset(200, 60),
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 0.15,
		Parent = screenGui,
	}, { Theme.corner(16), Theme.stroke(C.Good, 3) })
	self.luckLabel = Theme.label({
		Size = UDim2.new(1, -16, 0, 26),
		Position = UDim2.fromOffset(8, 4),
		Text = "🍀 Удача x1",
		TextColor3 = C.Good,
		Parent = luckFrame,
	})
	self.boostLabel = Theme.label({
		Size = UDim2.new(1, -16, 0, 20),
		Position = UDim2.fromOffset(8, 32),
		Text = "",
		TextColor3 = C.Muted,
		Parent = luckFrame,
	})

	-- Меню слева.
	local menu = create("Frame", {
		Name = "Menu",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.55, 0),
		Size = UDim2.fromOffset(295, math.ceil(#MENU / 2) * 43),
		BackgroundTransparency = 1,
		Parent = screenGui,
	}, {
		-- Две колонки: меню короче и меньше перекрывается чатом Roblox.
		create("UIGridLayout", {
			CellSize = UDim2.fromOffset(145, 38),
			CellPadding = UDim2.fromOffset(5, 5),
			FillDirectionMaxCells = 2,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self.badges = {}
	self.buttons = {}
	for order, item in ipairs(MENU) do
		local button = Theme.button({
			Name = item.id,
			Text = item.text,
			Color = item.color,
			LayoutOrder = order,
			Parent = menu,
		}, function()
			onMenu(item.id)
		end)
		self.buttons[item.id] = button
		if item.adminOnly then
			local localPlayer = game:GetService("Players").LocalPlayer
			local function refresh()
				button.Visible = localPlayer:GetAttribute("IsAdmin") == true
			end
			refresh()
			localPlayer:GetAttributeChangedSignal("IsAdmin"):Connect(refresh)
		end
		-- Красный кружок «!», когда в разделе есть что забрать.
		self.badges[item.id] = create("TextLabel", {
			Name = "Badge",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(24, 24),
			BackgroundColor3 = C.Bad,
			Text = "!",
			Font = Theme.Font,
			TextScaled = true,
			TextColor3 = C.Text,
			Visible = false,
			ZIndex = 3,
			Parent = button,
		}, { create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	end

	-- Уведомления.
	self.notifyFrame = create("Frame", {
		Name = "Notifications",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 156),
		Size = UDim2.fromOffset(560, 300),
		BackgroundTransparency = 1,
		Parent = screenGui,
	}, {
		create("UIListLayout", {
			Padding = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self.notifyCounter = 0

	return self
end

function Hud:update(state)
	local rewardsReady = state.rewards.canClaim or self.giftsReady(state) or state.wheel.freeAvailable
	for _, quest in ipairs(state.rewards.quests) do
		if quest.progress >= quest.target and not quest.claimed then
			rewardsReady = true
		end
	end
	self.badges.Rewards.Visible = rewardsReady

	self.coinsLabel.Text = Format.coins(state.coins)
	self.incomeLabel.Text = "+" .. Format.coins(state.income) .. "/с"
	local title = state.title .. " • ур. " .. state.level
	if state.rebirthTitle then
		title = string.format('%s • <font color="#ffbe28">♻️ %s</font>', title, state.rebirthTitle)
	end
	self.titleLabel.Text = title
	local progress = state.xpNext > 0 and math.clamp(state.xp / state.xpNext, 0, 1) or 1
	self.xpFill.Size = UDim2.fromScale(progress, 1)
	self.xpLabel.Text = Format.number(state.xp) .. " / " .. Format.number(state.xpNext) .. " XP"
	self.luckLabel.Text = string.format("🍀 Удача x%.2f", state.luck)
	if state.luckBoostLeft > 0 then
		self.boostLabel.Text = "Буст x2: " .. Format.time(state.luckBoostLeft)
		self.boostLabel.TextColor3 = C.Good
	else
		self.boostLabel.Text = state.passes.VIP and "👑 VIP: x2 монет" or ""
		self.boostLabel.TextColor3 = C.Gold
	end
end

function Hud:notify(text, color)
	self.notifyCounter += 1
	local children = self.notifyFrame:GetChildren()
	local labels = {}
	for _, child in ipairs(children) do
		if child:IsA("TextLabel") then
			table.insert(labels, child)
		end
	end
	if #labels >= 5 then
		table.sort(labels, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		labels[1]:Destroy()
	end

	local label = Theme.label({
		Size = UDim2.fromOffset(560, 36),
		Text = text,
		TextColor3 = color or C.Text,
		LayoutOrder = self.notifyCounter,
		TextTransparency = 1,
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 1,
		Parent = self.notifyFrame,
	})
	create("UITextSizeConstraint", { MaxTextSize = 26, Parent = label })
	TweenService:Create(label, TweenInfo.new(0.2), { TextTransparency = 0, BackgroundTransparency = 0.4 }):Play()
	task.delay(3.5, function()
		if label.Parent then
			local tween = TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1, BackgroundTransparency = 1 })
			tween:Play()
			tween.Completed:Wait()
			label:Destroy()
		end
	end)
end

return Hud
