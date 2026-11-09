-- Seasonal events: a limited capsule and exclusive brainrots for the season.
-- Time is Unix time in seconds (UTC). To get it: https://www.unixtimestamp.com
-- Season brainrots are marked in Creatures with the field season = "<id>" and do not drop
-- from regular capsules. The season capsule is in Capsules with the same season field.

local Seasons = {}

Seasons.List = {
	{
		id = "halloween",
		name = "🎃 Halloween",
		icon = "🎃",
		startsAt = 1792022400, -- 15 October 2026, 00:00 UTC
		endsAt = 1793923200, -- 6 November 2026, 00:00 UTC
		color = Color3.fromRGB(255, 140, 0),
	},
	{
		id = "newyear",
		name = "🎄 New Year",
		icon = "🎄",
		startsAt = 1797724800, -- 20 December 2026, 00:00 UTC
		endsAt = 1799625600, -- 11 January 2027, 00:00 UTC
		color = Color3.fromRGB(80, 200, 255),
	},
	{
		id = "valentine",
		name = "💘 Valentine's Day",
		icon = "💘",
		startsAt = 1801958400, -- 7 February 2027, 00:00 UTC
		endsAt = 1802736000, -- 16 February 2027, 00:00 UTC
		color = Color3.fromRGB(255, 100, 160),
	},
	{
		id = "summer",
		name = "☀️ Summer",
		icon = "☀️",
		startsAt = 1813449600, -- 20 June 2027, 00:00 UTC
		endsAt = 1815264000, -- 11 July 2027, 00:00 UTC
		color = Color3.fromRGB(255, 210, 60),
	},
}

Seasons.ById = {}
for _, season in ipairs(Seasons.List) do
	Seasons.ById[season.id] = season
end

function Seasons.isActive(id, time)
	-- A season turned on manually through the "Test" panel.
	if workspace and workspace:GetAttribute("ForcedSeason") == id then
		return true
	end
	local season = Seasons.ById[id]
	return season ~= nil and time >= season.startsAt and time < season.endsAt
end

return Seasons
