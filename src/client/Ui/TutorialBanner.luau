-- Подсказка обучения внизу экрана + мигание нужной кнопки меню и кнопки замка.

local Players = game:GetService("Players")

local Theme = require(script.Parent.Theme)
local create = Theme.create
local C = Theme.Colors

local player = Players.LocalPlayer

local TutorialBanner = {}
TutorialBanner.__index = TutorialBanner

function TutorialBanner.new(screenGui, hud)
	local self = setmetatable({}, TutorialBanner)
	self.hud = hud
	self.frame = create("Frame", {
		Name = "Tutorial",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -86),
		Size = UDim2.fromOffset(620, 70),
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 0.05,
		Visible = false,
		Parent = screenGui,
	}, { Theme.corner(16), Theme.stroke(C.Gold, 3) })
	self.step = Theme.label({
		Size = UDim2.new(1, -20, 0, 22),
		Position = UDim2.fromOffset(10, 4),
		Text = "",
		TextColor3 = C.Gold,
		Parent = self.frame,
	})
	self.text = Theme.label({
		Size = UDim2.new(1, -20, 0, 38),
		Position = UDim2.fromOffset(10, 28),
		Text = "",
		Parent = self.frame,
	})
	self.tutorial = nil
	self.lockHighlight = nil
	return self
end

function TutorialBanner:update(state)
	local tutorial = state.tutorial
	self.tutorial = tutorial
	self.frame.Visible = tutorial ~= nil
	if not tutorial then
		self:setLockHighlight(false)
		return
	end
	self.step.Text = string.format("📚 Обучение %d/%d", tutorial.index, tutorial.total)
	local text = tutorial.text
	if tutorial.count > 1 then
		text ..= string.format("  (%d/%d)", tutorial.progress, tutorial.count)
	end
	self.text.Text = text
	self:setLockHighlight(tutorial.highlightLock)
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

-- Вызывается каждый кадр: мигание кнопки меню.
function TutorialBanner:animate(t)
	local menuId = self.tutorial and self.tutorial.menu
	for id, button in pairs(self.hud.buttons) do
		local stroke = button:FindFirstChildOfClass("UIStroke")
		if stroke then
			if id == menuId then
				local pulse = (math.sin(t * 6) + 1) / 2
				stroke.Color = C.Gold
				stroke.Thickness = 2 + pulse * 3
				stroke.Transparency = 0
			else
				stroke.Color = Color3.new(0, 0, 0)
				stroke.Thickness = 2
				stroke.Transparency = 0.4
			end
		end
	end
end

return TutorialBanner
