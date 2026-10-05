-- Плашки внизу экрана: «неси брейнрота домой» и состояние замка своей базы.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Util.Format)

local Theme = require(script.Parent.Theme)
local create = Theme.create
local C = Theme.Colors

local StealStatus = {}
StealStatus.__index = StealStatus

function StealStatus.new(screenGui)
	local self = setmetatable({}, StealStatus)

	self.carry = create("Frame", {
		Name = "CarryStatus",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.fromOffset(460, 54),
		BackgroundColor3 = C.Bad,
		Visible = false,
		Parent = screenGui,
	}, { Theme.corner(14), Theme.stroke(Color3.new(1, 1, 1), 3) })
	self.carryLabel = Theme.label({
		Size = UDim2.new(1, -16, 1, -8),
		Position = UDim2.fromOffset(8, 4),
		Text = "",
		Parent = self.carry,
	})

	self.lock = create("Frame", {
		Name = "LockStatus",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 78),
		Size = UDim2.fromOffset(200, 40),
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 0.15,
		Parent = screenGui,
	}, { Theme.corner(12) })
	self.lockStroke = Theme.stroke(C.Blue, 3)
	self.lockStroke.Parent = self.lock
	self.lockLabel = Theme.label({
		Size = UDim2.new(1, -12, 1, -8),
		Position = UDim2.fromOffset(6, 4),
		Text = "",
		Parent = self.lock,
	})
	return self
end

function StealStatus:update(player, plots)
	local serverNow = workspace:GetServerTimeNow()

	local deadline = player:GetAttribute("CarryDeadline")
	if deadline then
		self.carry.Visible = true
		self.carryLabel.Text = "🏃 Неси брейнрота на свою базу! " .. Format.time(deadline - serverNow)
	else
		self.carry.Visible = false
	end

	local myPlot
	if plots then
		for _, plot in ipairs(plots:GetChildren()) do
			if plot:GetAttribute("OwnerUserId") == player.UserId then
				myPlot = plot
				break
			end
		end
	end
	if not myPlot then
		self.lock.Visible = false
		return
	end
	self.lock.Visible = true
	local left = (myPlot:GetAttribute("LockedUntil") or 0) - serverNow
	if left > 0 then
		self.lockLabel.Text = "🔒 База закрыта " .. Format.time(left)
		self.lockLabel.TextColor3 = C.Good
		self.lockStroke.Color = C.Good
	else
		self.lockLabel.Text = "🔓 База открыта!"
		self.lockLabel.TextColor3 = C.Bad
		self.lockStroke.Color = C.Bad
	end
end

return StealStatus
