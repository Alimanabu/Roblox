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

-- A round button of the left column (menu, rewards, eye, settings). row is its place from the top.
function Hud.sideButton(props, row, onClick)
	props.Size = UDim2.fromOffset(Hud.SIDE_BUTTON, Hud.SIDE_BUTTON)
	props.Position = UDim2.new(0, 10, Hud.COLUMN_Y, row * (Hud.SIDE_BUTTON + Hud.SIDE_GAP))
	props.Color = props.Color or C.Background
	local button = Theme.button(props, onClick)
	button:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0.5, 0)
	return button
end

-- A plate of the right column or of the top strip (goal, luck, lock, event, carry, the tutorial hint).
-- labels: the text objects inside (or the plate itself when it is a button with its own text).
-- spec: land = height in points on a landscape touch screen, split = shares of the height for several labels,
-- own = the plate itself carries the text, dock = "carry" (bottom stack on portrait) or "bottom" (the hint).
-- The PC look is remembered here and restored by applyLayout.
function Hud:addPlate(frame, labels, spec)
	local plate = { frame = frame, labels = labels, spec = spec, pc = {} }
	for index, label in ipairs(labels) do
		plate.pc[index] = { Position = label.Position, Size = label.Size, TextScaled = label.TextScaled }
	end
	plate.pcSize, plate.pcPosition, plate.pcAnchor, plate.pcParent = frame.Size, frame.Position, frame.AnchorPoint, frame.Parent
	local close = frame:FindFirstChild("Close")
	if close then
		plate.close = close
		plate.pcClose = { Size = close.Size, Position = close.Position, AnchorPoint = close.AnchorPoint }
	end
	local padding = frame:FindFirstChildOfClass("UIPadding")
	plate.padding = padding
	plate.pcPadding = padding and padding.PaddingRight
	table.insert(self.plates, plate)
	return plate
end

function Hud.new(screenGui, onMenu, giftsReady)
	local self = setmetatable({}, Hud)
	self.giftsReady = giftsReady
	self.rewardsReady = false
	self.screenGui = screenGui
	self.plates = {}
	self.size = Layout.BASE
	self.scale = 1
	self.notifyMax = Hud.NOTIFY_MAX
	self.notifyHeight, self.notifyWidth, self.notifyFont = 36, 560, nil

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

	-- Level: under the coins on PC, next to them on a touch screen.
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

	-- Settings: left of the coins on PC, the fourth round button of the left column on touch screens.
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

	-- Left column: ☰ menu and 🎁 rewards. The eye is the third button, in its own ScreenGui (Main, Hud:setEye).
	self.menuButton = Hud.sideButton({ Name = "MenuButton", Text = "☰", Parent = screenGui }, 0, function()
		self:setMenuOpen(not self.menuOpen)
	end)
	self.menuBadge = badge(self.menuButton)
	-- Rewards do not pop up over the game: this button glows while something waits.
	self.giftButton = Hud.sideButton({ Name = "RewardsButton", Text = "🎁", Parent = screenGui }, 1, function()
		onMenu("Rewards")
	end)
	self.giftBadge = badge(self.giftButton)

	-- The menu: PC two columns under the left column; touch a drawer next to it that scrolls.
	self.menuGrid = create("UIGridLayout", {
		CellSize = UDim2.fromOffset(Layout.MENU_COLUMN, 38),
		CellPadding = UDim2.fromOffset(5, 5),
		FillDirectionMaxCells = 2,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	self.menu = create("ScrollingFrame", {
		Name = "Menu",
		Position = UDim2.new(0, Layout.MENU_X, Hud.COLUMN_Y, 3 * (Hud.SIDE_BUTTON + Hud.SIDE_GAP)),
		Size = UDim2.fromOffset(Layout.menuWidth(2), math.ceil(#MENU / 2) * 43),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
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

	-- Plates: PC and landscape a column at the right edge, portrait a grid in the top strip.
	-- StealStatus and EventBanner add theirs (LayoutOrder 1, 4, 5).
	self.side = create("Frame", {
		Name = "Side",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, Hud.COLUMN_Y, 0),
		Size = UDim2.fromOffset(Hud.PLATE_WIDTH, 360),
		BackgroundTransparency = 1,
		Parent = screenGui,
	})
	self.sideList = create("UIListLayout", {
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = self.side,
	})
	self.sideGrid = create("UIGridLayout", {
		CellSize = UDim2.fromOffset(Hud.PLATE_WIDTH, 44),
		CellPadding = UDim2.fromOffset(6, 4),
		FillDirectionMaxCells = 2,
		SortOrder = Enum.SortOrder.LayoutOrder,
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
	self:addPlate(self.goalButton, { self.goalButton }, { land = 52, own = true })

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
	self:addPlate(luckFrame, { self.luckLabel, self.boostLabel }, { land = 40 })

	-- Notifications: at the bottom, above the tutorial hint (see applyLayout for the places).
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

	self:applyLayout(Layout.BASE, false, 1)
	return self
end

-- The eye is made by Main in its own ScreenGui: here it only gets its place.
function Hud:setEye(button)
	self.eyeButton = button
	self.pcEye = { Size = button.Size, Position = button.Position }
	self:applyLayout(self.size, self.touch, self.scale)
end

-- Text of a plate in points (touch) or as drawn for PC.
local function plateText(label, touch, u, font, pc)
	if touch then
		label.TextScaled = false
		label.TextSize = font * u
		label.TextWrapped = true
		label.TextXAlignment = Enum.TextXAlignment.Left
	else
		label.TextScaled = pc.TextScaled
	end
end

-- Puts everything in place for the screen size. size: the screen in points, scale: the UIScale of the screen gui.
-- Touch: sizes in points (n * u, u = 1 / scale), the middle of the screen stays free. PC: as drawn originally.
function Hud:applyLayout(size, touch, scale)
	scale = scale or self.scale
	local u = 1 / scale
	local PT = Layout.PT
	local portrait = Layout.isPortrait(size)
	self.size, self.scale = size, scale
	local function pt(n)
		return n * u
	end

	-- Top row, the left column and the drawer.
	local round = touch and pt(PT.BUTTON) or Hud.SIDE_BUTTON
	-- The column starts at a quarter of the height on a portrait screen, under the Roblox buttons on a landscape one.
	local top = if portrait then { scale = Hud.COLUMN_Y, pt = 0 } else { scale = 0, pt = PT.ROBLOX_BAR - 48 }
	local function sideButton(button, row)
		if not button then
			return
		end
		button.Size = UDim2.fromOffset(round, round)
		if touch then
			button.Position = UDim2.new(0, pt(PT.LEFT), top.scale, pt(top.pt + row * (PT.BUTTON + PT.GAP)))
		else
			button.Position = UDim2.new(0, 10, Hud.COLUMN_Y, row * (Hud.SIDE_BUTTON + Hud.SIDE_GAP))
		end
	end
	if touch then
		-- The top left corner is the Roblox menu and chat: the HUD row starts to the right of them.
		local x0 = math.max(PT.ROBLOX_BAR, (size.X - 366) / 2)
		local width = math.min(180, (size.X - PT.LEFT - x0 - PT.GAP) / 2)
		self.coinsFrame.AnchorPoint, self.levelFrame.AnchorPoint = Vector2.new(0, 0), Vector2.new(0, 0)
		self.coinsFrame.Position = UDim2.new(0, pt(x0), 0, pt(PT.TOP))
		self.coinsFrame.Size = UDim2.fromOffset(pt(width), pt(50))
		self.levelFrame.Position = UDim2.new(0, pt(x0 + width + PT.GAP), 0, pt(PT.TOP))
		self.levelFrame.Size = UDim2.fromOffset(pt(width), pt(50))
		self.settingsButton.AnchorPoint = Vector2.new(0, 0)
		self.settingsButton.Size = UDim2.fromOffset(round, round)
		self.settingsButton.Position = UDim2.new(0, pt(PT.LEFT), top.scale, pt(top.pt + 3 * (PT.BUTTON + PT.GAP)))
	else
		self.coinsFrame.AnchorPoint = Vector2.new(0.5, 0)
		self.coinsFrame.Position = UDim2.new(0.5, 0, 0, 6)
		self.coinsFrame.Size = UDim2.fromOffset(320, 86)
		self.levelFrame.AnchorPoint = Vector2.new(0.5, 0)
		self.levelFrame.Position = UDim2.new(0.5, 0, 0, 96)
		self.levelFrame.Size = UDim2.fromOffset(320, 46)
		self.settingsButton.AnchorPoint = Vector2.new(1, 0)
		self.settingsButton.Size = UDim2.fromOffset(44, 44)
		self.settingsButton.Position = UDim2.new(0.5, -168, 0, 6)
	end
	sideButton(self.menuButton, 0)
	sideButton(self.giftButton, 1)
	sideButton(self.eyeButton, 2)

	if touch then
		local height = size.Y * (1 - top.scale) - top.pt - PT.LEFT
		self.menu.Position = UDim2.new(0, pt(PT.LEFT + PT.BUTTON + PT.GAP), top.scale, pt(top.pt))
		self.menu.Size = UDim2.fromOffset(pt(PT.MENU_WIDTH), pt(math.min(height, #MENU * (PT.ROW + PT.GAP))))
		self.menu.ScrollBarThickness = 4
		self.menuGrid.FillDirectionMaxCells = 1
		self.menuGrid.CellSize = UDim2.fromOffset(pt(PT.MENU_WIDTH - 8), pt(PT.ROW))
		self.menuGrid.CellPadding = UDim2.fromOffset(0, pt(PT.GAP))
	else
		self.menu.Position = UDim2.new(0, Layout.MENU_X, Hud.COLUMN_Y, 3 * (Hud.SIDE_BUTTON + Hud.SIDE_GAP))
		self.menu.ScrollBarThickness = 0
		self.menuGrid.FillDirectionMaxCells = 2
		self.menuGrid.CellSize = UDim2.fromOffset(Layout.MENU_COLUMN, 38)
		self.menuGrid.CellPadding = UDim2.fromOffset(5, 5)
		self.menu.Size = UDim2.fromOffset(Layout.menuWidth(2), math.ceil(#MENU / 2) * 43)
	end
	for _, button in pairs(self.buttons) do
		button.TextScaled = not touch
		if touch then
			button.TextSize = pt(PT.MENU_FONT)
			button.TextXAlignment = Enum.TextXAlignment.Left
		end
	end

	-- Plates.
	local plateWidth = math.min(190, size.X * Layout.EDGE - 10)
	local gridMode = touch and portrait
	if touch then
		if portrait then
			self.side.AnchorPoint = Vector2.new(0.5, 0)
			self.side.Position = UDim2.new(0.5, 0, 0, pt(PT.TOP + 50 + 4))
			self.side.Size = UDim2.fromOffset(pt(size.X - 16), pt(100))
			self.sideGrid.CellSize = UDim2.new(0.5, -pt(3), 0, pt(44))
			self.sideGrid.CellPadding = UDim2.fromOffset(pt(6), pt(4))
		else
			self.side.AnchorPoint = Vector2.new(1, 0)
			self.side.Position = UDim2.new(1, -pt(PT.LEFT), 0, pt(PT.ROBLOX_BAR - 48))
			self.side.Size = UDim2.fromOffset(pt(plateWidth), pt(size.Y - PT.ROBLOX_BAR))
		end
	else
		self.side.AnchorPoint = Vector2.new(1, 0)
		self.side.Position = UDim2.new(1, -10, Hud.COLUMN_Y, 0)
		self.side.Size = UDim2.fromOffset(Hud.PLATE_WIDTH, 360)
	end
	self.sideList.Parent = if gridMode then nil else self.side
	self.sideGrid.Parent = if gridMode then self.side else nil

	local hintHeight = 40
	for _, plate in ipairs(self.plates) do
		local frame, spec = plate.frame, plate.spec
		local c = pt(PT.CLOSE)
		if touch then
			if spec.dock == "bottom" then
				frame.Parent = self.screenGui
				frame.AnchorPoint = Vector2.new(0.5, 1)
				frame.Position = UDim2.new(0.5, 0, 1, -pt(6))
				frame.Size = UDim2.fromOffset(pt(math.min(size.X - 16, 460)), pt(hintHeight))
			elseif spec.dock == "carry" and portrait then
				frame.Parent = self.screenGui
				frame.AnchorPoint = Vector2.new(0.5, 1)
				frame.Position = UDim2.new(0.5, 0, 1, -pt(6 + hintHeight + 4))
				frame.Size = UDim2.fromOffset(pt(size.X - 16), pt(44))
			else
				frame.Parent = self.side
				frame.AnchorPoint = Vector2.new(0, 0)
				frame.Position = UDim2.new()
				frame.Size = UDim2.new(1, 0, 0, pt(spec.land))
			end
			if plate.close then
				plate.close.AnchorPoint = Vector2.new(1, 0.5)
				plate.close.Position = UDim2.new(1, -pt(2), 0.5, 0)
				plate.close.Size = UDim2.fromOffset(c, c)
			end
			if spec.own then
				plate.padding.PaddingRight = UDim.new(0, c + pt(6))
				plateText(frame, true, u, PT.FONT, plate.pc[1])
			else
				local count = #plate.labels
				local split = spec.split or {}
				local y = 0
				for index, label in ipairs(plate.labels) do
					local share = split[index] or 1 / count
					label.Position = UDim2.new(0, pt(6), y, pt(2))
					label.Size = UDim2.new(1, -(c + pt(10)), share, -pt(4))
					y += share
					plateText(label, true, u, PT.FONT, plate.pc[index])
				end
			end
		else
			frame.Parent = plate.pcParent
			frame.AnchorPoint, frame.Position, frame.Size = plate.pcAnchor, plate.pcPosition, plate.pcSize
			if plate.close then
				plate.close.AnchorPoint, plate.close.Position, plate.close.Size =
					plate.pcClose.AnchorPoint, plate.pcClose.Position, plate.pcClose.Size
			end
			if spec.own then
				plate.padding.PaddingRight = plate.pcPadding
				plateText(frame, false, u, PT.FONT, plate.pc[1])
			else
				for index, label in ipairs(plate.labels) do
					label.Position, label.Size = plate.pc[index].Position, plate.pc[index].Size
					plateText(label, false, u, PT.FONT, plate.pc[index])
				end
			end
		end
	end

	-- Notifications drawn for another screen are dropped: they would keep the old size.
	for _, child in ipairs(self.notifyFrame:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	-- Notifications: one line above the hint (and the carry plate on a portrait screen); two on PC.
	if touch then
		local above = 6 + hintHeight + 4 + (if portrait then 44 + 4 else 0)
		self.notifyMax = 1
		self.notifyHeight = pt(if portrait then 36 else 28)
		self.notifyWidth = pt(math.min(size.X * 0.7, 420))
		self.notifyFont = pt(13)
		self.notifyFrame.Position = UDim2.new(0.5, 0, 1, -pt(above))
		self.notifyFrame.Size = UDim2.fromOffset(self.notifyWidth, self.notifyHeight)
	else
		self.notifyMax = Hud.NOTIFY_MAX
		self.notifyHeight, self.notifyWidth, self.notifyFont = 36, 560, nil
		self.notifyFrame.Position = UDim2.new(0.5, 0, 1, -66)
		self.notifyFrame.Size = UDim2.fromOffset(560, Hud.NOTIFY_MAX * 42)
	end

	if self.eyeButton and not touch then
		self.eyeButton.Size, self.eyeButton.Position = self.pcEye.Size, self.pcEye.Position
	end

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
	if button.GetAttribute then
		Theme.show(button, good) -- a plate closed with ✕ stays closed until the eye shows the HUD again
	else
		button.Visible = good -- a bare table in the tests (tests/retention.spec.luau)
	end
	if good then
		button.Text = text
	end
	if self.luckFrame then
		Theme.show(self.luckFrame, true)
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
	for index = 1, #labels - self.notifyMax + 1 do
		labels[index]:Destroy()
	end

	local label = Theme.label({
		Size = UDim2.fromOffset(self.notifyWidth, self.notifyFont and self.notifyHeight or 36),
		Text = text,
		TextColor3 = color or C.Text,
		LayoutOrder = self.notifyCounter,
		TextTransparency = 1,
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 1,
		Parent = self.notifyFrame,
	})
	if self.notifyFont then
		-- Touch screen: a fixed readable size (13 pt), the text wraps.
		label.TextScaled = false
		label.TextSize = self.notifyFont
		label.TextWrapped = true
	else
		create("UITextSizeConstraint", { MaxTextSize = 26, Parent = label })
	end
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
