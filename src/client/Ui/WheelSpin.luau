-- Анимация колеса удачи: призы мелькают, замедляются и останавливаются на выигрыше.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Daily = require(Shared.Config.Daily)

local Theme = require(script.Parent.Theme)
local create = Theme.create
local C = Theme.Colors

local WheelSpin = {}
WheelSpin.__index = WheelSpin

local DURATION = 2.8

function WheelSpin.new(screenGui)
	local self = setmetatable({}, WheelSpin)
	self.frame = create("Frame", {
		Name = "WheelSpin",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(420, 150),
		BackgroundColor3 = C.Background,
		Visible = false,
		ZIndex = 30,
		Parent = screenGui,
	}, { Theme.corner(20), Theme.stroke(C.Gold, 5) })
	Theme.label({ Size = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(0, 8), Text = "🎡 КОЛЕСО УДАЧИ", TextColor3 = C.Gold, ZIndex = 31, Parent = self.frame })
	self.label = Theme.label({ Size = UDim2.new(1, -20, 0, 70), Position = UDim2.fromOffset(10, 56), Text = "", ZIndex = 31, Parent = self.frame })
	self.token = 0
	return self
end

function WheelSpin:spin(resultIndex, onTick)
	self.token += 1
	local token = self.token
	self.frame.Visible = true
	task.spawn(function()
		local count = #Daily.Wheel
		-- Сколько «щелчков» сделать: несколько полных кругов + до нужного приза.
		local steps = count * 3 + resultIndex
		local started = os.clock()
		for step = 1, steps do
			if self.token ~= token then
				return
			end
			local slot = Daily.Wheel[(step - 1) % count + 1]
			self.label.Text = slot.name
			self.label.TextColor3 = step == steps and C.Good or C.Text
			if onTick then
				onTick(step == steps)
			end
			-- Замедление к концу: паузы растут квадратично.
			local progress = step / steps
			local target = started + DURATION * progress ^ 2
			task.wait(math.max(0.02, target - os.clock()))
		end
		task.wait(1.5)
		if self.token == token then
			self.frame.Visible = false
		end
	end)
end

return WheelSpin
