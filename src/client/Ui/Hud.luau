-- Main screen: coins, income, level, menu and notifications.
-- The middle of the screen is for the game: coins on top, the menu behind ☰ on the left,
-- small plates with ✕ in the right column, notifications at the bottom (see Layout).

local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local S = require(Shared.Strings)
local Format = require(Shared.Util.Format)

local Theme = require(script.Parent.Theme)
local Layout = require(script.Parent.Layout)
local create = Theme.create
local C = Theme.Colors

local Hud = {}
Hud.__index = Hud

Hud.SIDE_BUTTON = 72 -- round buttons of the left column
Hud.SIDE_GAP = 6
Hud.COLUMN_Y = 0.25 -- the left and right columns start at this share of the screen height
Hud.PLATE_WIDTH = 180 -- plates of the right column
Hud.NOTIFY_MAX = 2 -- notifications on screen at once
Hud.TOUCH_CELL = 120 -- width of a menu button on a touch screen

local MENU = {
	{ id = "Rewards", text = S.t("hud.rewards"), color = Color3.fromRGB(255, 120, 60) },
	{ id = "Factory", text = S.t("hud.factory"), color = C.Accent },
	{ id = "Base", text = S.t("hud.base"), color = C.Blue },
	{ id = "Upgrades", text = S.t("hud.upgrades"), color = C.Good },
	{ id = "Rebirth", text = S.t("hud.rebirth"), color = C.Purple },
	{ id = "Index", text = S.t("hud.index"), color = Color3.fromRGB(80, 180, 200) },
	{ id = "Achievements", text = S.t("hud.achievements"), color = Color3.fromRGB(200, 150, 40) },
	{ id = "Trade", text = S.t("hud.trade"), color = Color3.fromRGB(60, 170, 140) },
	{ id = "Battles", text = S.t("hud.battles"), color = Color3.fromRGB(200, 60, 90) },
	{ id = "Skins", text = S.t("hud.skins"), color = Color3.fromRGB(220, 90, 200) },
	{ id = "Shop", text = S.t("hud.shop"), color = C.Gold },
	{ id = "Help", text = S.t("hud.help"), color = Color3.fromRGB(120, 120, 150) },
	{ id = "Admin", text = S.t("hud.admin"), color = Color3.fromRGB(70, 70, 90), adminOnly = true },
}
Hud.MENU_ITEMS = #MENU

-- Red "!" dot on a button.
local function badge(button)
	return create("TextLabel", {
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

-- A round button of the left column (menu, rewards, eye). row is its place from the top.
function Hud.sideButton(props, row, onClick)
	props.Size = UDim2.fromOffset(Hud.SIDE_BUTTON, Hud.SIDE_BUTTON)
	props.Position = UDim2.new(0, 10, Hud.COLUMN_Y, row * (Hud.SIDE_BUTTON + Hud.SIDE_GAP))
	props.Color = props.Color or C.Background
	local button = Theme.button(props, onClick)
	button:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0.5, 0)
	return button
end

function Hud.new(screenGui, onMenu, giftsReady)
	local self = setmetatable({}, Hud)
	self.giftsReady = giftsReady
	self.rewardsReady = false

	-- Coins at the top center, in the free middle of the Roblox top bar.
	self.coinsFrame = create("Frame", {
		Name = "Coins",
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 0.15,
		Parent = screenGui,
	}, { Theme.corner(16), Theme.stroke(C.Coins, 3) })
	self.coinsLabel = Theme.label({
		Size = UDim2.new(1, -16, 0.6, 0),
		Position = UDim2.new(0, 8, 0.03, 0),
		TextColor3 = C.Coins,
		Text = "$0",
		Parent = self.coinsFrame,
	})
	self.incomeLabel = Theme.label({
		Size = UDim2.new(1, -16, 0.32, 0),
		Position = UDim2.new(0, 8, 0.63, 0),
		TextColor3 = C.Good,
		Text = S.t("common.per_second", { coins = "+$0" }),
		Parent = self.coinsFrame,
	})

	-- Level: under the coins on PC and tablet, next to them on a phone.
	self.levelFrame = create("Frame", {
		Name = "Level",
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 0.15,
		Parent = screenGui,
	}, { Theme.corner(16), Theme.stroke(C.Purple, 3) })
	self.titleLabel = Theme.label({
		Size = UDim2.new(1, -16, 0.44, 0),
		Position = UDim2.new(0, 8, 0.05, 0),
		Text = S.t("common.title_level", { title = S.m("level.1.name"), level = 1 }),
		Parent = self.levelFrame,
	})
	local bar = create("Frame", {
		Size = UDim2.new(1, -16, 0.38, 0),
		Position = UDim2.new(0, 8, 0.53, 0),
		BackgroundColor3 = C.Card,
		Parent = self.levelFrame,
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

	-- Settings button to the left of the coins: on the right the Roblox player list covers them.
	self.settingsButton = Theme.button({
		Name = "SettingsButton",
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(44, 44),
		Text = "⚙️",
		Color = C.Background,
		Parent = screenGui,
	}, function()
		onMenu("Settings")
	end)

	-- Left column: ☰ menu and 🎁 rewards. The eye is the third button, in its own ScreenGui (Main).
	self.menuButton = Hud.sideButton({ Name = "MenuButton", Text = "☰", Parent = screenGui }, 0, function()
		self:setMenuOpen(not self.menuOpen)
	end)
	self.menuBadge = badge(self.menuButton)
	-- Rewards do not pop up over the game: this button glows while something waits.
	self.giftButton = Hud.sideButton({ Name = "RewardsButton", Text = "🎁", Parent = screenGui }, 1, function()
		onMenu("Rewards")
	end)
	self.giftBadge = badge(self.giftButton)

	-- The menu: under the left column, folded on touch screens until ☰ is tapped.
	self.menuGrid = create("UIGridLayout", {
		CellSize = UDim2.fromOffset(Layout.MENU_COLUMN, 38),
		CellPadding = UDim2.fromOffset(5, 5),
		FillDirectionMaxCells = 2,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	self.menu = create("Frame", {
		Name = "Menu",
		Position = UDim2.new(0, Layout.MENU_X, Hud.COLUMN_Y, 3 * (Hud.SIDE_BUTTON + Hud.SIDE_GAP)),
		Size = UDim2.fromOffset(Layout.menuWidth(2), math.ceil(#MENU / 2) * 43),
		BackgroundTransparency = 1,
		Parent = screenGui,
	}, { self.menuGrid })
	self.menuOpen = true
	self.badges = {}
	self.buttons = {}
	for order, item in ipairs(MENU) do
		local button = Theme.button({
			Name = item.id,
			Text = item.text,
			Color = item.color,
			LayoutOrder = order,
			Parent = self.menu,
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
		-- Red "!" dot when a section has something to claim.
		self.badges[item.id] = badge(button)
	end

	-- Right column: small plates at the edge. StealStatus and EventBanner add theirs (LayoutOrder 1, 4, 5).
	self.side = create("Frame", {
		Name = "Side",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, Hud.COLUMN_Y, 0),
		Size = UDim2.fromOffset(Hud.PLATE_WIDTH, 360),
		BackgroundTransparency = 1,
		Parent = screenGui,
	}, {
		create("UIListLayout", {
			Padding = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	-- Session goal: one plate with the next thing to do, a tap opens the rewards.
	self.goalButton = Theme.button({
		Name = "Goal",
		Size = UDim2.fromOffset(Hud.PLATE_WIDTH, 56),
		Text = "",
		Color = C.Background,
		Visible = false,
		LayoutOrder = 2,
		Parent = self.side,
	}, function()
		onMenu("Rewards")
	end)
	self.goalButton.TextWrapped = true
	self.goalButton:FindFirstChildOfClass("UIPadding").PaddingRight = UDim.new(0, Theme.CLOSE)
	Theme.closable(self.goalButton)

	-- Luck.
	local luckFrame = create("Frame", {
		Name = "Luck",
		Size = UDim2.fromOffset(Hud.PLATE_WIDTH, 52),
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 0.15,
		LayoutOrder = 3,
		Parent = self.side,
	}, { Theme.corner(16), Theme.stroke(C.Good, 3) })
	self.luckLabel = Theme.label({
		Size = UDim2.new(1, -Theme.CLOSE - 8, 0, 26),
		Position = UDim2.fromOffset(8, 3),
		Text = S.t("hud.luck", { luck = "1" }),
		TextColor3 = C.Good,
		Parent = luckFrame,
	})
	self.boostLabel = Theme.label({
		Size = UDim2.new(1, -Theme.CLOSE - 8, 0, 18),
		Position = UDim2.fromOffset(8, 30),
		Text = "",
		TextColor3 = C.Muted,
		Parent = luckFrame,
	})
	Theme.closable(luckFrame)
	self.luckFrame = luckFrame

	-- Notifications: at the bottom, above the tutorial hint, at most two at a time.
	self.notifyFrame = create("Frame", {
		Name = "Notifications",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -66),
		Size = UDim2.fromOffset(560, Hud.NOTIFY_MAX * 42),
		BackgroundTransparency = 1,
		Parent = screenGui,
	}, {
		create("UIListLayout", {
			Padding = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self.notifyCounter = 0

	self:applyLayout(Layout.BASE, false)
	return self
end

-- Puts the top bar and the menu in place for the screen size. Phone: coins and level in one row.
-- PC and tablet: coins over the level, as before. The menu folds when the device becomes a touch one.
function Hud:applyLayout(size, touch)
	if Layout.isPhone(size) then
		self.coinsFrame.AnchorPoint = Vector2.new(1, 0)
		self.coinsFrame.Position = UDim2.new(0.5, -4, 0, 6)
		self.coinsFrame.Size = UDim2.fromOffset(210, 56)
		self.levelFrame.AnchorPoint = Vector2.new(0, 0)
		self.levelFrame.Position = UDim2.new(0.5, 4, 0, 6)
		self.levelFrame.Size = UDim2.fromOffset(210, 56)
		self.settingsButton.Position = UDim2.new(0.5, -220, 0, 6)
	else
		self.coinsFrame.AnchorPoint = Vector2.new(0.5, 0)
		self.coinsFrame.Position = UDim2.new(0.5, 0, 0, 6)
		self.coinsFrame.Size = UDim2.fromOffset(320, 86)
		self.levelFrame.AnchorPoint = Vector2.new(0.5, 0)
		self.levelFrame.Position = UDim2.new(0.5, 0, 0, 96)
		self.levelFrame.Size = UDim2.fromOffset(320, 46)
		self.settingsButton.Position = UDim2.new(0.5, -168, 0, 6)
	end

	local columns = Layout.menuColumns(size, touch)
	local cell = if touch then Hud.TOUCH_CELL else Layout.MENU_COLUMN
	self.menuGrid.FillDirectionMaxCells = columns
	self.menuGrid.CellSize = UDim2.fromOffset(cell, 38)
	self.menu.Size = UDim2.fromOffset(columns * cell + (columns - 1) * 5, math.ceil(#MENU / columns) * 43)

	if self.touch ~= touch then
		self.touch = touch
		self:setMenuOpen(Layout.menuOpenAtStart(touch))
	end
end

function Hud:setMenuOpen(open)
	self.menuOpen = open
	self.menu.Visible = open
	self.menuButton.BackgroundColor3 = if open then C.Accent else C.Background
end

-- Called every frame: the rewards button glows while something waits to be claimed
-- (not while the tutorial points somewhere else: quietGlow, set by TutorialBanner).
function Hud:animate(t)
	local stroke = self.giftButton:FindFirstChildOfClass("UIStroke")
	if not stroke then
		return
	end
	if self.rewardsReady and not self.quietGlow then
		local pulse = (math.sin(t * 5) + 1) / 2
		stroke.Color = C.Gold
		stroke.Thickness = 2 + pulse * 3
		stroke.Transparency = 0
	else
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Thickness = 2
		stroke.Transparency = 0.4
	end
end

-- The session goal: what to do next, and when there is nothing left today, why to come back tomorrow.
-- Order: daily reward, finished quest, ready gift, the closest unfinished quest, the next gift,
-- tomorrow's streak day. now is the server time (the tests pass their own).
function Hud.goal(state, now)
	now = now or workspace:GetServerTimeNow()
	local r = state.rewards
	local total = #r.rewards
	if r.canClaim then
		return S.t("hud.goal_daily", { day = r.nextDay, total = total })
	end
	local best, bestShare
	for _, quest in ipairs(r.quests) do
		if not quest.claimed then
			if quest.progress >= quest.target then
				return S.t("hud.goal_quest_done")
			end
			local share = quest.progress / math.max(1, quest.target)
			if not best or share > bestShare then
				best, bestShare = quest, share
			end
		end
	end
	local minutes = (now - state.playtime.start) / 60
	local nextGift
	for _, gift in ipairs(state.playtime.gifts) do
		if not gift.claimed then
			if minutes >= gift.minutes then
				return S.t("hud.goal_gift")
			end
			nextGift = nextGift or gift -- gifts go from the shortest time to the longest
		end
	end
	if best then
		return S.t("hud.goal_quest", { quest = S.text(best.text), progress = best.progress, target = best.target })
	end
	if nextGift then
		return S.t("hud.goal_next_gift", { minutes = math.max(1, math.ceil(nextGift.minutes - minutes)) })
	end
	local tomorrow = r.streak % total + 1
	-- The day changes at midnight UTC (Daily.today). Counted here: the state comes only on changes.
	local time = Format.time(86400 - math.floor(now) % 86400)
	if tomorrow == total then
		return S.t("hud.goal_mega", { time = time, day = tomorrow })
	end
	return S.t("hud.goal_tomorrow", { time = time, day = tomorrow, total = total })
end

-- Called on every state change and once a second: the timers in the goal run without new state.
-- A broken state hides the line instead of stopping the loop that also runs the steal status and events.
-- A plate closed with ✕ stays hidden (Theme.closable).
function Hud:refreshGoal(state)
	local ok, text = pcall(Hud.goal, state)
	local good = ok and type(text) == "string"
	local button = self.goalButton
	local closed = button.GetAttribute ~= nil and button:GetAttribute("Closed") == true
	button.Visible = good and not closed
	if good then
		button.Text = text
	end
	if self.luckFrame then
		Theme.show(self.luckFrame, true) -- comes back after the eye shows the HUD again
	end
end

function Hud:update(state)
	self:refreshGoal(state)

	local rewardsReady = state.rewards.canClaim or self.giftsReady(state) or state.wheel.freeAvailable
	for _, quest in ipairs(state.rewards.quests) do
		if quest.progress >= quest.target and not quest.claimed then
			rewardsReady = true
		end
	end
	self.rewardsReady = rewardsReady
	self.badges.Rewards.Visible = rewardsReady
	self.giftBadge.Visible = rewardsReady
	self.menuBadge.Visible = rewardsReady

	self.coinsLabel.Text = Format.coins(state.coins)
	self.incomeLabel.Text = S.t("common.per_second", { coins = "+" .. Format.coins(state.income) })
	local title = S.t("common.title_level", { title = state.title, level = state.level })
	if state.rebirthTitle then
		title = string.format('%s • <font color="#ffbe28">♻️ %s</font>', title, S.text(state.rebirthTitle))
	end
	self.titleLabel.Text = title
	local progress = state.xpNext > 0 and math.clamp(state.xp / state.xpNext, 0, 1) or 1
	self.xpFill.Size = UDim2.fromScale(progress, 1)
	self.xpLabel.Text = Format.number(state.xp) .. " / " .. Format.number(state.xpNext) .. " XP"
	self.luckLabel.Text = S.t("hud.luck", { luck = string.format("%.2f", state.luck) })
	if state.luckBoostLeft > 0 then
		self.boostLabel.Text = S.t("hud.boost", { time = Format.time(state.luckBoostLeft) })
		self.boostLabel.TextColor3 = C.Good
	else
		self.boostLabel.Text = state.passes.VIP and S.t("hud.vip") or ""
		self.boostLabel.TextColor3 = C.Gold
	end
end

function Hud:notify(text, color)
	self.notifyCounter += 1
	local labels = {}
	for _, child in ipairs(self.notifyFrame:GetChildren()) do
		if child:IsA("TextLabel") then
			table.insert(labels, child)
		end
	end
	table.sort(labels, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for index = 1, #labels - Hud.NOTIFY_MAX + 1 do
		labels[index]:Destroy()
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
