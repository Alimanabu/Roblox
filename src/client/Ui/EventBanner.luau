-- Plate in the right column of the HUD: which event is running now or which one is next.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local S = require(Shared.Strings)
local Events = require(Shared.Config.Events)
local Format = require(Shared.Util.Format)

local Theme = require(script.Parent.Theme)
local create = Theme.create
local C = Theme.Colors

local EventBanner = {}
EventBanner.__index = EventBanner

function EventBanner.new(hud)
	local side = hud.side
	local self = setmetatable({}, EventBanner)
	self.frame = create("Frame", {
		Name = "EventBanner",
		Size = UDim2.new(1, 0, 0, 60),
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 0.15,
		LayoutOrder = 5,
		Parent = side,
	}, { Theme.corner(12) })
	self.stroke = Theme.stroke(C.Muted, 3)
	self.stroke.Parent = self.frame
	self.title = Theme.label({ Size = UDim2.new(1, -Theme.CLOSE - 6, 0, 26), Position = UDim2.fromOffset(6, 4), Text = "", Parent = self.frame })
	self.info = Theme.label({
		Size = UDim2.new(1, -12, 0, 24),
		Position = UDim2.fromOffset(6, 32),
		Text = "",
		TextColor3 = C.Muted,
		Parent = self.frame,
	})
	Theme.closable(self.frame)
	hud:addPlate(self.frame, { self.title, self.info }, { land = 56, split = { 0.3, 0.7 } })
	return self
end

function EventBanner:update()
	Theme.show(self.frame, true)
	local now = workspace:GetServerTimeNow()
	local active = Events.active(now)
	if #active > 0 then
		-- If two events run at once, we show the last one (Minute 67 matters more).
		local current = active[#active]
		local pulse = (math.sin(os.clock() * 6) + 1) / 2
		self.title.Text = current.event.name
		self.title.TextColor3 = current.event.color
		self.info.Text = current.event.desc .. " " .. Format.time(current.endsAt - now)
		self.stroke.Color = current.event.color:Lerp(Color3.new(1, 1, 1), pulse * 0.5)
		self.info.TextColor3 = C.Text
	else
		local nextEvent, startsAt = Events.nextEvent(now)
		self.title.Text = S.t("event.next")
		self.title.TextColor3 = C.Muted
		self.info.Text = S.t("event.next_in", { name = nextEvent.name, time = Format.time(startsAt - now) })
		self.info.TextColor3 = nextEvent.color
		self.stroke.Color = C.Muted
	end
end

return EventBanner
