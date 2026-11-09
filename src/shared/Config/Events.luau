-- Server-wide events. Time is taken in UTC, so events run simultaneously
-- on all servers: you can call friends, "Minute 67 in 2 minutes!".

local S = require(script.Parent.Parent.Strings)

local Events = {}

Events.CYCLE = 15 * 60 -- a random event starts every 15 minutes...
Events.DURATION = 3 * 60 -- ...and lasts 3 minutes

Events.Random = {
	{ id = "luck_storm", luck = 2, color = Color3.fromRGB(120, 255, 120) },
	{ id = "money_rain", income = 2, color = Color3.fromRGB(255, 220, 80) },
	{ id = "mutant_fog", mutation = 3, color = Color3.fromRGB(200, 120, 255) },
	{ id = "turbo", speed = 2, color = Color3.fromRGB(80, 200, 255) },
}

-- Every hour from minute 6:00 to 7:59: "6-7".
Events.SixSeven = {
	id = "minute67",
	secret = 6.7,
	mutation67 = 6.7,
	color = Color3.fromRGB(255, 230, 0),
	startMinute = 6,
	endMinute = 8, -- exclusive
}

-- Every hour from :30 to :33 a boss comes to the plaza (see server/Services/BossService).
Events.Boss = {
	id = "boss",
	color = Color3.fromRGB(255, 70, 70),
	startMinute = 30,
	endMinute = 33,
}

-- Events that run every hour at the same time.
Events.Hourly = { Events.SixSeven, Events.Boss }

for _, event in ipairs(Events.Random) do
	S.fill(event, "event." .. event.id, "name", "desc")
end
for _, event in ipairs(Events.Hourly) do
	S.fill(event, "event." .. event.id, "name", "desc")
end

function Events.byId(id)
	for _, event in ipairs(Events.Hourly) do
		if event.id == id then
			return event
		end
	end
	for _, event in ipairs(Events.Random) do
		if event.id == id then
			return event
		end
	end
	return nil
end

local function randomEventFor(cycleIndex)
	-- We shuffle the order so that events do not cycle in a predictable way.
	local index = (cycleIndex * 7919 + 13) % #Events.Random + 1
	return Events.Random[index]
end

-- List of active events: { { event, endsAt } }.
function Events.active(time)
	local result = {}
	local cycleIndex = math.floor(time / Events.CYCLE)
	local cycleStart = cycleIndex * Events.CYCLE
	if time - cycleStart < Events.DURATION then
		table.insert(result, { event = randomEventFor(cycleIndex), endsAt = cycleStart + Events.DURATION })
	end

	local hourStart = math.floor(time / 3600) * 3600
	local minute = (time - hourStart) / 60
	for _, hourly in ipairs(Events.Hourly) do
		if minute >= hourly.startMinute and minute < hourly.endMinute then
			table.insert(result, { event = hourly, endsAt = hourStart + hourly.endMinute * 60 })
		end
	end

	-- An event started manually through the "Test" panel (attributes on workspace).
	local forcedId = workspace and workspace:GetAttribute("ForcedEvent")
	local forcedUntil = workspace and workspace:GetAttribute("ForcedEventUntil")
	if forcedId and forcedUntil and time < forcedUntil then
		local forced = Events.byId(forcedId)
		local already = false
		for _, active in ipairs(result) do
			already = already or active.event == forced
		end
		if forced and not already then
			table.insert(result, { event = forced, endsAt = forcedUntil })
		end
	end
	return result
end

-- The nearest event that has not started yet: event, startsAt.
function Events.nextEvent(time)
	local cycleIndex = math.floor(time / Events.CYCLE) + 1
	local nextRandom = cycleIndex * Events.CYCLE

	local bestEvent, bestTime = randomEventFor(cycleIndex), nextRandom
	local hourStart = math.floor(time / 3600) * 3600
	for _, hourly in ipairs(Events.Hourly) do
		local startsAt = hourStart + hourly.startMinute * 60
		if startsAt <= time then
			startsAt += 3600
		end
		-- When times coincide we show the hourly event (it matters more).
		if startsAt <= bestTime then
			bestEvent, bestTime = hourly, startsAt
		end
	end
	return bestEvent, bestTime
end

-- Multipliers from all active events.
function Events.modifiers(time)
	local mods = { luck = 1, income = 1, mutation = 1, speed = 1, secret = 1, mutation67 = 1 }
	for _, active in ipairs(Events.active(time)) do
		for key in pairs(mods) do
			local value = active.event[key]
			if type(value) == "number" then
				mods[key] *= value
			end
		end
	end
	return mods
end

return Events
