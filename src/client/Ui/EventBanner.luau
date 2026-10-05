-- Плашка справа: какой ивент идёт сейчас или какой будет следующим.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Events = require(Shared.Config.Events)
local Format = require(Shared.Util.Format)

local Theme = require(script.Parent.Theme)
local create = Theme.create
local C = Theme.Colors

local EventBanner = {}
EventBanner.__index = EventBanner

function EventBanner.new(screenGui)
	local self = setmetatable({}, EventBanner)
	self.frame = create("Frame", {
		Name = "EventBanner",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 126),
		Size = UDim2.fromOffset(200, 64),
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 0.15,
		Parent = screenGui,
	}, { Theme.corner(12) })
	self.stroke = Theme.stroke(C.Muted, 3)
	self.stroke.Parent = self.frame
	self.title = Theme.label({ Size = UDim2.new(1, -12, 0, 26), Position = UDim2.fromOffset(6, 4), Text = "", Parent = self.frame })
	self.info = Theme.label({
		Size = UDim2.new(1, -12, 0, 28),
		Position = UDim2.fromOffset(6, 32),
		Text = "",
		TextColor3 = C.Muted,
		Parent = self.frame,
	})
	return self
end

function EventBanner:update()
	local now = workspace:GetServerTimeNow()
	local active = Events.active(now)
	if #active > 0 then
		-- Если идут два ивента сразу, показываем последний (Минута 67 важнее).
		local current = active[#active]
		local pulse = (math.sin(os.clock() * 6) + 1) / 2
		self.title.Text = current.event.name
		self.title.TextColor3 = current.event.color
		self.info.Text = current.event.desc .. " " .. Format.time(current.endsAt - now)
		self.stroke.Color = current.event.color:Lerp(Color3.new(1, 1, 1), pulse * 0.5)
		self.info.TextColor3 = C.Text
	else
		local nextEvent, startsAt = Events.nextEvent(now)
		self.title.Text = "Следующий ивент"
		self.title.TextColor3 = C.Muted
		self.info.Text = nextEvent.name .. " через " .. Format.time(startsAt - now)
		self.info.TextColor3 = nextEvent.color
		self.stroke.Color = C.Muted
	end
end

return EventBanner
