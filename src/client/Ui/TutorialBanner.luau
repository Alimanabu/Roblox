-- Tutorial: one short action at a time, an arrow and a glow right on the thing to tap.
-- The server counts the steps (Config/Tutorial, TutorialService); here each step is split into taps:
-- ☰ -> menu button -> the button inside the window (Craft, Buy, Claim). A big hint at the top edge
-- (18+ pt on a touch screen, Hud:layoutHint) says the same in 3-6 words; while it leads, the goal, luck and
-- event plates step aside (Hud:placeSide), the carry timer and the lock stay.
-- ✕ hides the hint and the arrow for this step: the next step shows them again.

local Players = game:GetService("Players")

local S = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Strings)
local Theme = require(script.Parent.Theme)
local create = Theme.create
local C = Theme.Colors

local player = Players.LocalPlayer

local TutorialBanner = {}
TutorialBanner.__index = TutorialBanner

-- Menu window of a step -> the attribute TutorialTarget of the button inside it (Panels) and its hint.
local INSIDE = {
	Factory = { target = "craft", key = "tutorial.do.craft" },
	Upgrades = { target = "buy", key = "tutorial.do.buy" },
	Rewards = { target = "daily", key = "tutorial.do.claim" },
}
local OPEN_KEY = {
	Factory = "tutorial.do.factory",
	Upgrades = "tutorial.do.upgrades",
	Rewards = "tutorial.do.rewards",
}
TutorialBanner.INSIDE = INSIDE

local function findTarget(root, name)
	for _, item in ipairs(root:GetDescendants()) do
		if item:GetAttribute("TutorialTarget") == name then
			return item
		end
	end
	return nil
end

-- What to do right now: hint key and the one button to point at (nil = no button, e.g. the lock in the world).
-- Pure: the tests call it with their own windows.
function TutorialBanner.target(tutorial, panels, hud)
	if tutorial.highlightLock then
		return "tutorial.do.lock", nil
	end
	local menu = tutorial.menu
	local inside = INSIDE[menu]
	if not inside then
		return nil, nil
	end
	if panels.openName == menu then
		return inside.key, findTarget(panels.window, inside.target)
	end
	if panels.openName ~= nil then
		return "tutorial.do.close", panels.closeButton
	end
	if menu == "Rewards" then
		return OPEN_KEY.Rewards, hud.giftButton -- the glowing 🎁 of the left column
	end
	if hud.menuOpen then
		return OPEN_KEY[menu], hud.buttons[menu]
	end
	return "tutorial.do.menu", hud.menuButton
end

-- Progress as big dots: done ●, now ◉, ahead ○ (short enough for the narrow landscape column).
function TutorialBanner.dots(index, total)
	return "📚 " .. string.rep("●", index - 1) .. "◉" .. string.rep("○", math.max(0, total - index))
end

function TutorialBanner.new(screenGui, hud, panels, getScale)
	local self = setmetatable({}, TutorialBanner)
	self.hud = hud
	self.panels = panels
	self.screenGui = screenGui
	self.getScale = getScale or function()
		return 1
	end
	self.frame = create("Frame", {
		Name = "Tutorial",
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 0.05,
		Visible = false,
		ZIndex = 20,
		Parent = screenGui,
	}, { Theme.corner(14), Theme.stroke(C.Gold, 3) })
	-- Places and sizes: Hud:layoutHint (screen size, touch or PC).
	self.step = Theme.label({
		Name = "Step",
		Text = "",
		TextColor3 = C.Gold,
		ZIndex = 21,
		Parent = self.frame,
	})
	self.text = Theme.label({
		Name = "Hint",
		Text = "",
		ZIndex = 21,
		Parent = self.frame,
	})
	Theme.closable(self.frame)
	hud:addPlate(self.frame, { self.step, self.text }, { dock = "top" })
	-- The arrow is drawn over everything, windows included.
	self.arrow = Theme.label({
		Name = "TutorialArrow",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(56, 56),
		Text = "👇",
		ZIndex = 60,
		Visible = false,
		Parent = screenGui,
	})
	self.tutorial = nil
	self.targetObject = nil
	self.hintKey = nil
	self.lockHighlight = nil
	return self
end

function TutorialBanner:closed()
	return self.frame:GetAttribute("Closed") == true
end

-- Picks the current tap target and writes the hint. Called on state changes and every frame
-- (opening the menu or a window changes the target without new state).
function TutorialBanner:refresh()
	local tutorial = self.tutorial
	-- ✕ hides the hint only for the step it was pressed on: the next step shows it again.
	Theme.show(self.frame, tutorial ~= nil, tutorial and tutorial.index)
	-- While the tutorial leads, nothing else glows and the quiet plates step aside: one goal at a time.
	local leading = tutorial ~= nil and not self:closed()
	self.hud.quietGlow = leading
	if self.hud.tutorialFocus ~= leading then
		self.hud:setTutorialFocus(leading)
	end
	if not tutorial or self:closed() then
		self:setTarget(nil)
		self:setLockHighlight(false)
		return
	end
	local key, target = TutorialBanner.target(tutorial, self.panels, self.hud)
	self.hintKey = key
	self.step.Text = TutorialBanner.dots(tutorial.index, tutorial.total)
	local text = key and S.t(key) or S.text(tutorial.text)
	if tutorial.count > 1 then
		text ..= string.format("  (%d/%d)", tutorial.progress, tutorial.count)
	end
	if self.text.Text ~= text then
		self.text.Text = text
	end
	self:setTarget(target)
	self:setLockHighlight(tutorial.highlightLock)
end

function TutorialBanner:update(state)
	self.tutorial = state.tutorial
	self:refresh()
end

local function resetStroke(button)
	local stroke = button and button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Thickness = 2
		stroke.Transparency = 0.4
	end
end

function TutorialBanner:setTarget(target)
	if self.targetObject == target then
		return
	end
	if self.targetObject then
		resetStroke(self.targetObject)
		self.targetObject:SetAttribute("TutorialFocus", nil)
	end
	self.targetObject = target
	self.scrolled = false
	if target then
		target:SetAttribute("TutorialFocus", true) -- the one thing to tap now (the tests count them)
	end
end

-- A button deep in a window may be below the visible part: scroll the window to it once.
function TutorialBanner:scrollTo(target)
	if type(target.AbsolutePosition) ~= "userdata" then
		return -- not drawn yet
	end
	local scroll = target:FindFirstAncestorWhichIsA("ScrollingFrame")
	if not scroll then
		return
	end
	local top = target.AbsolutePosition.Y - scroll.AbsolutePosition.Y
	local bottom = top + target.AbsoluteSize.Y
	if top < 0 or bottom > scroll.AbsoluteSize.Y then
		local scale = self.getScale()
		scroll.CanvasPosition = Vector2.new(0, math.max(0, scroll.CanvasPosition.Y + (top - 60 * scale) / scale))
	end
end

-- Called every frame: the target glows, the arrow bobs right above it.
function TutorialBanner:animate(t)
	-- Every 6th frame is enough to follow a tap on ☰ or a window that opened.
	self.frameCount = (self.frameCount or 0) + 1
	if self.tutorial and self.frameCount % 6 == 0 then
		self:refresh()
	end
	local target = self.targetObject
	if not target or not target.Parent or self:closed() then
		self.arrow.Visible = false
		return
	end
	local pulse = (math.sin(t * 6) + 1) / 2
	local stroke = target:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = C.Gold
		stroke.Thickness = 2 + pulse * 3
		stroke.Transparency = 0
	end
	if not self.scrolled then
		self.scrolled = true
		self:scrollTo(target)
	end
	-- The arrow sits in screen pixels: the target's place divided by the UI scale (Main.updateScale).
	local position, size = target.AbsolutePosition, target.AbsoluteSize
	if type(position) ~= "userdata" or type(size) ~= "userdata" then
		self.arrow.Visible = false
		return
	end
	local origin = self.screenGui.AbsolutePosition
	local scale = self.getScale()
	local x = (position.X + size.X / 2 - origin.X) / scale
	local top = (position.Y - origin.Y) / scale
	local bob = math.sin(t * 5) * 6
	if top < 70 then
		-- No room above: the arrow points up from below.
		self.arrow.Text = "👆"
		self.arrow.AnchorPoint = Vector2.new(0.5, 0)
		self.arrow.Position = UDim2.fromOffset(x, top + size.Y / scale + 4 + bob)
	else
		self.arrow.Text = "👇"
		self.arrow.AnchorPoint = Vector2.new(0.5, 1)
		self.arrow.Position = UDim2.fromOffset(x, top - 4 + bob)
	end
	self.arrow.Visible = target.Visible ~= false
end

function TutorialBanner:setLockHighlight(enabled)
	if not enabled then
		if self.lockHighlight then
			self.lockHighlight:Destroy()
			self.lockHighlight = nil
		end
		return
	end
	if self.lockHighlight and self.lockHighlight.Parent then
		return
	end
	local plots = workspace:FindFirstChild("Plots")
	for _, plot in ipairs(plots and plots:GetChildren() or {}) do
		if plot:GetAttribute("OwnerUserId") == player.UserId and plot:FindFirstChild("LockButton") then
			local highlight = Instance.new("Highlight")
			highlight.FillColor = C.Gold
			highlight.OutlineColor = C.Gold
			highlight.FillTransparency = 0.3
			highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			highlight.Parent = plot.LockButton
			self.lockHighlight = highlight
		end
	end
end

return TutorialBanner
