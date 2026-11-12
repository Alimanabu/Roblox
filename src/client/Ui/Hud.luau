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
Hud.LEVEL_WIDTH = 420 -- PC: the level line holds a long title and the rebirth title at 12+ pt
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
-- own = the plate itself carries the text, dock = "carry" (bottom of a portrait screen) or "top" (the tutorial hint, Hud:layoutHint),
-- quiet = the plate steps aside while the tutorial hint leads on a touch screen (goal, luck, event; never the carry
-- timer or the lock: Hud:placeSide).
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
		Name = "CoinsText",
		Size = UDim2.new(1, -16, 0.6, 0),
		Position = UDim2.new(0, 8, 0.03, 0),
		TextColor3 = C.Coins,
		Text = "$0",
		Parent = self.coinsFrame,
	})
	self.incomeLabel = Theme.label({
		Name = "IncomeText",
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
		Name = "LevelText",
		Size = UDim2.new(1, -16, 0.44, 0),
		Position = UDim2.new(0, 8, 0.05, 0),
		Text = S.t("common.title_level", { title = S.m("level.1.name"), level = 1 }),
		Parent = self.levelFrame,
	})
	local bar = create("Frame", {
		Name = "XpBar",
		Size = UDim2.new(1, -16, 0.38, 0),
		Position = UDim2.new(0, 8, 0.53, 0),
		BackgroundColor3 = C.Card,
		Parent = self.levelFrame,
	}, { Theme.corner(8) })
	self.xpBar = bar
	self.xpFill = create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = C.Purple,
		Parent = bar,
	}, { Theme.corner(8) })
	self.xpLabel = Theme.label({
		Name = "XpText",
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
	self.badgeList = {}
	self.menuBadge = badge(self.menuButton)
	table.insert(self.badgeList, self.menuBadge)
	-- Rewards do not pop up over the game: this button glows while something waits.
	self.giftButton = Hud.sideButton({ Name = "RewardsButton", Text = "🎁", Parent = screenGui }, 1, function()
		onMenu("Rewards")
	end)
	self.giftBadge = badge(self.giftButton)
	table.insert(self.badgeList, self.giftBadge)

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
	self.rebirthLabel = Theme.label({
		Name = "RebirthTitle",
		Text = "",
		TextColor3 = Color3.fromRGB(255, 190, 40),
		LayoutOrder = 0,
		Visible = false,
		Parent = self.menu,
	})
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
				self:fitMenu()
			end
			refresh()
			localPlayer:GetAttributeChangedSignal("IsAdmin"):Connect(refresh)
		end
		-- Red "!" dot when a section has something to claim.
		self.badges[item.id] = badge(button)
		table.insert(self.badgeList, self.badges[item.id])
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
	self.goalButton:FindFirstChildOfClass("UIPadding").PaddingRight = UDim.new(0, Theme.CLOSE + 6)
	Theme.closable(self.goalButton)
	self:addPlate(self.goalButton, { self.goalButton }, { land = 52, own = true, quiet = true })

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
		Name = "LuckText",
		Size = UDim2.new(1, -Theme.CLOSE - 14, 0, 26),
		Position = UDim2.fromOffset(8, 3),
		Text = S.t("hud.luck", { luck = "1" }),
		TextColor3 = C.Good,
		Parent = luckFrame,
	})
	self.boostLabel = Theme.label({
		Name = "BoostText",
		Size = UDim2.new(1, -Theme.CLOSE - 14, 0, 18),
		Position = UDim2.fromOffset(8, 30),
		Text = "",
		TextColor3 = C.Muted,
		Parent = luckFrame,
	})
	self.luckFrame = luckFrame
	Theme.closable(self.luckFrame)
	self:addPlate(luckFrame, { self.luckLabel, self.boostLabel }, { land = 40, quiet = true })

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

-- Touch: the drawer is as high as its visible rows (the rebirth title and the buttons, the admin one only for admins),
-- but not higher than the screen allows (then it scrolls).
function Hud:fitMenu()
	if not self.menuLimit then
		return
	end
	local rows = if self.rebirthLabel.Visible then 1 else 0
	for _, button in pairs(self.buttons) do
		if button.Visible ~= false then
			rows += 1
		end
	end
	local PT = Layout.PT
	self.menu.Size = UDim2.fromOffset(self.menuU * PT.MENU_WIDTH, self.menuU * math.min(self.menuLimit, rows * (PT.ROW + PT.GAP)))
end

-- The eye is made by Main in its own ScreenGui: here it only gets its place.
function Hud:setEye(button)
	self.eyeButton = button
	self.pcEye = { Size = button.Size, Position = button.Position }
	self:applyLayout(self.size, self.touch, self.scale)
end

-- Safety net: if the engine reports that a fixed-size text does not fit (TextFits), the label shrinks it
-- (TextScaled between Layout.PT.MIN_FIT points and its own size) instead of cutting the tail, and says so once in
-- Output with its name and text. The tests keep every phrase within 2 lines with a width margin
-- (tests/layout.spec.luau); this covers a font that renders wider than measured.
function Hud.guardFit(label)
	if label:GetAttribute("FitGuard") then
		return
	end
	label:SetAttribute("FitGuard", true)
	label:GetPropertyChangedSignal("TextFits"):Connect(function()
		if label.TextFits == false and label:GetAttribute("FixedFont") then
			local limit = label:FindFirstChild("FitLimit") or create("UITextSizeConstraint", { Name = "FitLimit", Parent = label })
			limit.MaxTextSize = math.max(1, math.floor(label.TextSize))
			limit.MinTextSize = math.min(limit.MaxTextSize, label:GetAttribute("FitMin") or Layout.PT.MIN_FIT)
			label.TextScaled = true
			if not label:GetAttribute("FitWarned") then
				label:SetAttribute("FitWarned", true)
				warn(string.format("[Hud] text does not fit, shrinking to %.0f..%.0f: %s \"%s\"", limit.MinTextSize, limit.MaxTextSize,
					label.Name, label.Text))
			end
		end
	end)
end

-- A fixed text size on a touch screen, under the safety net; on PC the drawn look (TextScaled) comes back.
function Hud.fixFont(label, touch, u, font)
	Hud.guardFit(label)
	local limit = label:FindFirstChild("FitLimit")
	if limit then
		limit:Destroy()
	end
	label:SetAttribute("FixedFont", touch or nil)
	label:SetAttribute("FitMin", if touch then Layout.PT.MIN_FIT * u else nil)
	if touch then
		label.TextScaled = false
		label.TextSize = font * u
	end
end

-- Text of a plate in points (touch) or as drawn for PC.
local function plateText(label, touch, u, font, pc)
	Hud.fixFont(label, touch, u, font)
	if touch then
		label.TextWrapped = true
		label.TextXAlignment = Enum.TextXAlignment.Left
	else
		label.TextScaled = pc.TextScaled
	end
end

-- Height of the tutorial hint in points on a touch screen (frame of Hud:layoutHint).
function Hud.hintPoints(portrait)
	local PT = Layout.PT
	local lines = if portrait then Layout.HINT_LINES.portrait else Layout.HINT_LINES.landscape
	return PT.CLOSE + 4 + lines * PT.HINT * Layout.LINE + 6
end

-- The tutorial hint, at the top edge with big text (Layout.PT.HINT points on a touch screen).
-- Portrait: the strip under the coins, full width. Landscape: the top of the right column; the plates
-- move under it while the tutorial runs (Hud:placeSide). PC: under the level, in the middle.
-- Row 1: progress dots and ✕; below: the hint, wrapped, the whole width.
function Hud:layoutHint(plate, size, touch, portrait, u)
	local PT = Layout.PT
	local frame, close = plate.frame, plate.close
	local step, text = plate.labels[1], plate.labels[2]
	local k = if touch then u else 1
	local width, lines, font, stepFont, c
	if touch and portrait then
		frame.AnchorPoint = Vector2.new(0.5, 0)
		frame.Position = UDim2.new(0.5, 0, 0, k * (PT.TOP + PT.TOP_ROW + 4))
		width, lines = size.X - 16, Layout.HINT_LINES.portrait
	elseif touch then
		frame.AnchorPoint = Vector2.new(1, 0)
		frame.Position = UDim2.new(1, -k * PT.LEFT, 0, k * (PT.ROBLOX_BAR - 48))
		width, lines = math.min(190, size.X * Layout.EDGE - 10), Layout.HINT_LINES.landscape
	else
		frame.AnchorPoint = Vector2.new(0.5, 0)
		frame.Position = UDim2.new(0.5, 0, 0, Layout.HINT_PC.Y)
		width, lines = Layout.HINT_PC.WIDTH, Layout.HINT_LINES.pc
	end
	if touch then
		font, stepFont, c = PT.HINT, PT.HINT_STEP, PT.CLOSE
	else
		font, stepFont, c = Layout.HINT_PC.FONT, Layout.HINT_PC.STEP, Theme.CLOSE
	end
	frame.Parent = self.screenGui
	local height = if touch then Hud.hintPoints(portrait) else c + 4 + lines * font * Layout.LINE + 6
	frame.Size = UDim2.fromOffset(k * width, k * height)
	if close then
		close.AnchorPoint = Vector2.new(1, 0)
		close.Position = UDim2.new(1, -k * 2, 0, k * 2)
		close.Size = UDim2.fromOffset(k * c, k * c)
	end
	step.Position = UDim2.fromOffset(k * 8, k * 2)
	step.Size = UDim2.new(1, -k * (c + 14), 0, k * c)
	step.TextScaled = false
	step.TextSize = k * stepFont
	step.TextXAlignment = Enum.TextXAlignment.Left
	text.Position = UDim2.fromOffset(k * 6, k * (c + 4))
	text.Size = UDim2.new(1, -k * 12, 0, k * lines * font * Layout.LINE)
	text.TextScaled = false
	text.TextWrapped = true
	text.TextSize = k * font
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Top
end

-- While the tutorial hint leads on a touch screen it takes the place of the plates at the top.
-- The goal, luck and event plates step aside one by one (spec.quiet): one thing to read for a newbie.
-- The carry timer and the lock never hide (a newbie can be robbed, step 4 is the lock): the column moves
-- under the hint on a landscape screen, the row goes to the bottom (above the carry plate) on a portrait one.
-- ✕ on the hint ends the focus and puts everything back.
function Hud:setTutorialFocus(on)
	self.tutorialFocus = on
	self:placeSide(self.size, self.touch == true, self.scale)
end

-- Places the plate column (or the portrait row) and the notifications; switches the quiet plates.
function Hud:placeSide(size, touch, scale)
	local u = 1 / scale
	local function pt(n)
		return n * u
	end
	local PT = Layout.PT
	local portrait = Layout.isPortrait(size)
	local focus = touch and self.tutorialFocus == true
	local plateWidth = math.min(190, size.X * Layout.EDGE - PT.LEFT)
	local gridMode = touch and portrait
	if touch then
		if portrait and focus then
			self.side.AnchorPoint = Vector2.new(0.5, 1)
			self.side.Position = UDim2.new(0.5, 0, 1, -pt(6 + 44 + 4))
			self.side.Size = UDim2.fromOffset(pt(size.X - 16), pt(44))
		elseif portrait then
			self.side.AnchorPoint = Vector2.new(0.5, 0)
			self.side.Position = UDim2.new(0.5, 0, 0, pt(PT.TOP + PT.TOP_ROW + 4))
			self.side.Size = UDim2.fromOffset(pt(size.X - 16), pt(100))
		else
			local top = PT.ROBLOX_BAR - 48 + (if focus then Hud.hintPoints(false) + PT.GAP else 0)
			self.side.AnchorPoint = Vector2.new(1, 0)
			self.side.Position = UDim2.new(1, -pt(PT.LEFT), 0, pt(top))
			self.side.Size = UDim2.fromOffset(pt(plateWidth), pt(size.Y - top - PT.LEFT))
		end
		if portrait then
			self.sideGrid.CellSize = UDim2.new(0.5, -pt(3), 0, pt(44))
			self.sideGrid.CellPadding = UDim2.fromOffset(pt(6), pt(4))
		end
		-- Notifications: one line at the bottom, above the carry plate and the plate row on a portrait screen.
		local above = 6 + (if portrait then 44 + 4 else 0) + (if portrait and focus then 44 + 4 else 0)
		self.notifyFrame.Position = UDim2.new(0.5, 0, 1, -pt(above))
	else
		self.side.AnchorPoint = Vector2.new(1, 0)
		self.side.Position = UDim2.new(1, -10, Hud.COLUMN_Y, 0)
		self.side.Size = UDim2.fromOffset(Hud.PLATE_WIDTH, 360)
		self.notifyFrame.Position = UDim2.new(0.5, 0, 1, -66)
	end
	self.sideList.Parent = if gridMode then nil else self.side
	self.sideGrid.Parent = if gridMode then self.side else nil
	for _, plate in ipairs(self.plates) do
		if plate.spec.quiet then
			Theme.quiet(plate.frame, focus)
		end
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
		-- The level line takes 2 lines of 12 pt: it gets more of the row than the coins (a short number).
		local levelWidth = math.min(200, math.floor((width * 2) * 0.58))
		local coinsWidth = math.min(180, width * 2 - levelWidth)
		local row = PT.TOP_ROW
		self.coinsFrame.Position = UDim2.new(0, pt(x0), 0, pt(PT.TOP))
		self.coinsFrame.Size = UDim2.fromOffset(pt(coinsWidth), pt(row))
		self.levelFrame.Position = UDim2.new(0, pt(x0 + coinsWidth + PT.GAP), 0, pt(PT.TOP))
		self.levelFrame.Size = UDim2.fromOffset(pt(levelWidth), pt(row))
		self.titleLabel.Position = UDim2.new(0, pt(4), 0, pt(2))
		self.titleLabel.Size = UDim2.new(1, -pt(8), 0, pt(PT.FONT * Layout.LINE * 2 + 1))
		self.titleLabel.TextScaled = false
		self.titleLabel.TextWrapped = true
		self.titleLabel.TextSize = pt(PT.FONT)
		self.xpBar.Position = UDim2.new(0, pt(4), 0, pt(row - 4 - 16))
		self.xpBar.Size = UDim2.new(1, -pt(8), 0, pt(16))
		for _, badgeLabel in ipairs(self.badgeList) do
			badgeLabel.Size = UDim2.fromOffset(pt(20), pt(20))
		end
		self.settingsButton.AnchorPoint = Vector2.new(0, 0)
		self.settingsButton.Size = UDim2.fromOffset(round, round)
		self.settingsButton.Position = UDim2.new(0, pt(PT.LEFT), top.scale, pt(top.pt + 3 * (PT.BUTTON + PT.GAP)))
	else
		self.coinsFrame.AnchorPoint = Vector2.new(0.5, 0)
		self.coinsFrame.Position = UDim2.new(0.5, 0, 0, 6)
		self.coinsFrame.Size = UDim2.fromOffset(320, 86)
		self.levelFrame.AnchorPoint = Vector2.new(0.5, 0)
		self.levelFrame.Position = UDim2.new(0.5, 0, 0, 96)
		self.levelFrame.Size = UDim2.fromOffset(Hud.LEVEL_WIDTH, 46)
		self.titleLabel.Position, self.titleLabel.Size = UDim2.new(0, 8, 0.05, 0), UDim2.new(1, -16, 0.44, 0)
		self.titleLabel.TextScaled, self.titleLabel.TextWrapped = true, false
		self.xpBar.Position, self.xpBar.Size = UDim2.new(0, 8, 0.53, 0), UDim2.new(1, -16, 0.38, 0)
		for _, badgeLabel in ipairs(self.badgeList) do
			badgeLabel.Size = UDim2.fromOffset(24, 24)
		end
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
		self.menuLimit, self.menuU = height, u
		self:fitMenu()
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
		self.menuLimit = nil
	end
	plateText(self.rebirthLabel, touch, u, PT.MENU_FONT, { TextScaled = true })
	if not touch then
		self.rebirthLabel.Visible = false
	end
	for _, button in pairs(self.buttons) do
		Hud.fixFont(button, touch, u, PT.MENU_FONT)
		button.TextScaled = not touch
		if touch then
			button.TextXAlignment = Enum.TextXAlignment.Left
		end
	end

	-- Plates.
	self:placeSide(size, touch, scale)

	for _, plate in ipairs(self.plates) do
		local frame, spec = plate.frame, plate.spec
		local c = pt(PT.CLOSE)
		if spec.dock == "top" then
			self:layoutHint(plate, size, touch, portrait, u)
		elseif touch then
			if spec.dock == "carry" and portrait then
				frame.Parent = self.screenGui
				frame.AnchorPoint = Vector2.new(0.5, 1)
				frame.Position = UDim2.new(0.5, 0, 1, -pt(6))
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
				plate.padding.PaddingRight = UDim.new(0, c + pt(4))
				plateText(frame, true, u, PT.FONT, plate.pc[1])
			else
				local count = #plate.labels
				local split = spec.split or {}
				local y = 0
				for index, label in ipairs(plate.labels) do
					local share = split[index] or 1 / count
					label.Position = UDim2.new(0, pt(4), y, pt(2))
					label.Size = UDim2.new(1, -(c + pt(8)), share, -pt(4))
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

	-- Notifications: one at a time at the bottom on a touch screen (the place: Hud:placeSide); two on PC.
	if touch then
		self.notifyMax = 1
		-- 2 lines of 13 pt (a finished quest names the whole quest); a portrait screen gives it the whole width at the bottom.
		self.notifyHeight = pt(36)
		self.notifyWidth = pt(if portrait then size.X - 16 else math.min(size.X * 0.7, 420))
		self.notifyFont = pt(13)
		self.notifyFrame.Size = UDim2.fromOffset(self.notifyWidth, self.notifyHeight)
	else
		self.notifyMax = Hud.NOTIFY_MAX
		self.notifyHeight, self.notifyWidth, self.notifyFont = 36, 560, nil
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
		return S.t("hud.goal_daily", { day = r.nextDay, total = total }), "daily"
	end
	local best, bestShare
	for _, quest in ipairs(r.quests) do
		if not quest.claimed then
			if quest.progress >= quest.target then
				return S.t("hud.goal_quest_done"), "quest_done"
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
				return S.t("hud.goal_gift"), "gift"
			end
			nextGift = nextGift or gift -- gifts go from the shortest time to the longest
		end
	end
	if best then
		return S.t("hud.goal_quest", { quest = S.text(best.short or best.text), progress = best.progress, target = best.target }), "quest"
	end
	if nextGift then
		return S.t("hud.goal_next_gift", { minutes = math.max(1, math.ceil(nextGift.minutes - minutes)) }), "next_gift"
	end
	local tomorrow = r.streak % total + 1
	-- The day changes at midnight UTC (Daily.today). Counted here: the state comes only on changes.
	local time = Format.hoursOrMinutes(86400 - math.floor(now) % 86400)
	if tomorrow == total then
		return S.t("hud.goal_mega", { time = time, day = tomorrow }), "tomorrow"
	end
	return S.t("hud.goal_tomorrow", { time = time, day = tomorrow, total = total }), "tomorrow"
end

-- The key of the luck plate's ✕: the luck value and whether a boost runs (not the boost timer itself).
function Hud.luckKey(state)
	local boost = type(state.luckBoostLeft) == "number" and state.luckBoostLeft > 0
	return string.format("%.2f|%s", tonumber(state.luck) or 0, tostring(boost))
end

-- Called on every state change and once a second: the timers in the goal run without new state.
-- A broken state hides the line instead of stopping the loop that also runs the steal status and events.
-- A plate closed with ✕ stays hidden (Theme.closable).
function Hud:refreshGoal(state)
	local ok, text, kind = pcall(Hud.goal, state)
	local good = ok and type(text) == "string"
	local button = self.goalButton
	if button.GetAttribute then
		-- ✕ holds only for this kind of goal: "quest done" or tomorrow's reward shows the plate again (lesson 7).
		Theme.show(self.goalButton, good, kind)
	else
		button.Visible = good -- a bare table in the tests (tests/retention.spec.luau)
	end
	if good then
		button.Text = text
	end
	if self.luckFrame then
		-- ✕ holds while the luck stays the same: a new luck boost or a luck upgrade shows the plate again.
		Theme.show(self.luckFrame, true, Hud.luckKey(state))
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
	-- The rebirth title: on a touch screen the first line of the ☰ menu (lead's decision 13.11), on PC in the level line.
	local rebirthText = if state.rebirthTitle then "♻️ " .. S.text(state.rebirthTitle) else ""
	self.rebirthLabel.Text = rebirthText
	local titleShown = self.touch == true and rebirthText ~= ""
	if self.rebirthLabel.Visible ~= titleShown then
		self.rebirthLabel.Visible = titleShown
		self:fitMenu() -- one more row: the last button must not slide out of the drawer
	end
	if state.rebirthTitle and not self.touch then
		title = string.format('%s • <font color="#ffbe28">♻️ %s</font>', title, S.text(state.rebirthTitle))
	end
	self.titleLabel.Text = title
	local progress = state.xpNext > 0 and math.clamp(state.xp / state.xpNext, 0, 1) or 1
	self.xpFill.Size = UDim2.fromScale(progress, 1)
	self.xpLabel.Text = Format.number(state.xp) .. " / " .. Format.number(state.xpNext) .. " XP"
	self.luckLabel.Text = S.t("hud.luck", { luck = string.format("%.2f", state.luck) })
	if state.luckBoostLeft > 0 then
		self.boostLabel.Text = S.t("hud.boost", { time = Format.timer(state.luckBoostLeft) })
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
