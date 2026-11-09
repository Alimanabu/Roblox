-- Main screen: coins, income, level, menu and notifications.

local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local S = require(Shared.Strings)
local Format = require(Shared.Util.Format)

local Theme = require(script.Parent.Theme)
local create = Theme.create
local C = Theme.Colors

local Hud = {}
Hud.__index = Hud

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

function Hud.new(screenGui, onMenu, giftsReady)
	local self = setmetatable({}, Hud)
	self.giftsReady = giftsReady

	-- Coins at the top center.
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
		Text = S.t("common.per_second", { coins = "+$0" }),
		Parent = coinsFrame,
	})

	-- Level is a thin bar under the coins (the top left is taken by the Roblox chat).
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
		Text = S.t("common.title_level", { title = S.m("level.1.name"), level = 1 }),
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

	-- Session goal under the level: one line with the next thing to do, a tap opens the rewards.
	self.goalButton = Theme.button({
		Name = "Goal",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 152),
		Size = UDim2.fromOffset(360, 36),
		Text = "",
		Color = C.Background,
		Visible = false,
		Parent = screenGui,
	}, function()
		onMenu("Rewards")
	end)

	-- Settings button next to the level.
	Theme.button({
		Name = "SettingsButton",
		-- To the left of the coins: on the right the Roblox player list covers them.
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(0.5, -168, 0, 8),
		Size = UDim2.fromOffset(44, 44),
		Text = "⚙️",
		Color = C.Background,
		Parent = screenGui,
	}, function()
		onMenu("Settings")
	end)

	-- Luck at the top right.
	local luckFrame = create("Frame", {
		Name = "Luck",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0.3, 0), -- below the Roblox player list
		Size = UDim2.fromOffset(200, 60),
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 0.15,
		Parent = screenGui,
	}, { Theme.corner(16), Theme.stroke(C.Good, 3) })
	self.luckLabel = Theme.label({
		Size = UDim2.new(1, -16, 0, 26),
		Position = UDim2.fromOffset(8, 4),
		Text = S.t("hud.luck", { luck = "1" }),
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

	-- Menu on the left.
	local menu = create("Frame", {
		Name = "Menu",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.55, 0),
		Size = UDim2.fromOffset(295, math.ceil(#MENU / 2) * 43),
		BackgroundTransparency = 1,
		Parent = screenGui,
	}, {
		-- Two columns: the menu is shorter and overlaps the Roblox chat less.
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
		-- Red "!" dot when a section has something to claim.
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

	-- Notifications.
	self.notifyFrame = create("Frame", {
		Name = "Notifications",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 196), -- below the session goal
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
function Hud:refreshGoal(state)
	local ok, text = pcall(Hud.goal, state)
	self.goalButton.Visible = ok and type(text) == "string"
	if self.goalButton.Visible then
		self.goalButton.Text = text
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
	self.badges.Rewards.Visible = rewardsReady

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
