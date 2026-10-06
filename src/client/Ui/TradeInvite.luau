-- Всплывающее приглашение (обмен, аура-баттл): «Принять» / «Отклонить».
-- respondRemote получает (fromUserId, accept).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.Theme)
local create = Theme.create
local C = Theme.Colors

local TradeInvite = {}
TradeInvite.__index = TradeInvite

local TIMEOUT = 25

function TradeInvite.new(screenGui, respondRemote, yOffset)
	local self = setmetatable({}, TradeInvite)
	self.respondRemote = respondRemote or Remotes.TradeRespond
	self.frame = create("Frame", {
		Name = "TradeInvite",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -10, 1, -170 - (yOffset or 0)),
		Size = UDim2.fromOffset(320, 120),
		BackgroundColor3 = C.Panel,
		Visible = false,
		ZIndex = 20,
		Parent = screenGui,
	}, { Theme.corner(14), Theme.stroke(C.Good, 3), Theme.padding(10) })
	self.label = Theme.label({ Size = UDim2.new(1, 0, 0, 54), Text = "", ZIndex = 21, Parent = self.frame })
	self.accept = Theme.button({
		Size = UDim2.new(0.5, -4, 0, 40),
		Position = UDim2.new(0, 0, 1, -40),
		Text = "✅ Принять",
		Color = C.Good,
		ZIndex = 21,
		Parent = self.frame,
	}, function()
		self:answer(true)
	end)
	self.decline = Theme.button({
		Size = UDim2.new(0.5, -4, 0, 40),
		Position = UDim2.new(0.5, 4, 1, -40),
		Text = "❌ Нет",
		Color = C.Bad,
		ZIndex = 21,
		Parent = self.frame,
	}, function()
		self:answer(false)
	end)
	self.fromUserId = nil
	self.token = 0
	return self
end

function TradeInvite:show(fromUserId, text)
	self.fromUserId = fromUserId
	self.label.Text = text
	self.frame.Visible = true
	self.token += 1
	local token = self.token
	task.delay(TIMEOUT, function()
		if self.token == token then
			self.frame.Visible = false
		end
	end)
end

function TradeInvite:answer(accept)
	if self.fromUserId then
		self.respondRemote:FireServer(self.fromUserId, accept)
	end
	self.fromUserId = nil
	self.token += 1
	self.frame.Visible = false
end

return TradeInvite
