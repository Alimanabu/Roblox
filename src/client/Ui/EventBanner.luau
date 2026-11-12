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
	self.hud = hud
	self.frame = create("Frame", {
		Name = "EventBanner",
		Size = UDim2.new(1, 0, 0, 76), -- PC: a long title in 2 lines, the info in 2 lines
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 0.15,
		LayoutOrder = 5,
		Parent = side,
	}, { Theme.corner(12) })
	self.stroke = Theme.stroke(C.Muted, 3)
	self.stroke.Parent = self.frame
	self.title = Theme.label({ Name = "EventTitle", Size = UDim2.new(1, -Theme.CLOSE - 12, 0, 30), Position = UDim2.fromOffset(6, 4), Text = "", Parent = self.frame })
	self.info = Theme.label({
		Name = "EventInfo",
		Size = UDim2.new(1, -Theme.CLOSE - 12, 0, 36), -- PC: 2 lines next to the ✕, not under it
		Position = UDim2.fromOffset(6, 36),
		Text = "",
		TextColor3 = C.Muted,
		Parent = self.frame,
	})
	Theme.closable(self.frame)
	hud:addPlate(self.frame, { self.title, self.info }, { land = 40, split = { 0, 1 }, quiet = true })
	return self
end

-- The key of the ✕: the running event, or the next one while waiting. Closing "next event" does not
-- hide the start of that event, and closing a running event does not hide the next one (lesson 7).
function EventBanner.key(now)
	local active = Events.active(now)
	if #active > 0 then
		local current = active[#active]
		return "on:" .. current.event.id .. ":" .. tostring(current.endsAt)
	end
	local nextEvent, startsAt = Events.nextEvent(now)
	return "next:" .. nextEvent.id .. ":" .. tostring(startsAt)
end

-- The two lines of the plate: the running event (active = true, left = seconds to its end) or the next one
-- (left = seconds to its start). On a touch screen the plate has one line of at most 2 rows (title hidden):
-- the name and the time, without the description (the start notification tells it). The tests check every
-- event with the longest time on every screen (tests/layout.spec.luau).
function EventBanner.lines(event, active, left, touch)
	if touch then
		return "", S.t(if active then "event.plate_now" else "event.plate_next", { event = event.name, time = Format.timer(left) })
	end
	if active then
		return event.name, event.desc .. " " .. Format.time(left)
	end
	return S.t("event.next"), S.t("event.next_in", { name = event.name, time = Format.time(left) })
end

function EventBanner:update()
	local now = workspace:GetServerTimeNow()
	Theme.show(self.frame, true, EventBanner.key(now))
	local touch = self.hud.touch == true
	self.title.Visible = not touch
	local active = Events.active(now)
	if #active > 0 then
		-- If two events run at once, we show the last one (Minute 67 matters more).
		local current = active[#active]
		local pulse = (math.sin(os.clock() * 6) + 1) / 2
		self.title.Text, self.info.Text = EventBanner.lines(current.event, true, current.endsAt - now, touch)
		self.title.TextColor3 = current.event.color
		self.stroke.Color = current.event.color:Lerp(Color3.new(1, 1, 1), pulse * 0.5)
		self.info.TextColor3 = if touch then current.event.color else C.Text
	else
		local nextEvent, startsAt = Events.nextEvent(now)
		self.title.Text, self.info.Text = EventBanner.lines(nextEvent, false, startsAt - now, touch)
		self.title.TextColor3 = C.Muted
		self.info.TextColor3 = nextEvent.color
		self.stroke.Color = C.Muted
	end
end

return EventBanner
