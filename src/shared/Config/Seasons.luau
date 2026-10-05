-- Сезонные ивенты: лимитированная капсула и эксклюзивные брейнроты на время сезона.
-- Время — Unix-время в секундах (UTC). Узнать: https://www.unixtimestamp.com
-- Брейнроты сезона помечаются в Creatures полем season = "<id>" и не выпадают
-- из обычных капсул. Капсула сезона — в Capsules с тем же полем season.

local Seasons = {}

Seasons.List = {
	{
		id = "halloween",
		name = "🎃 Хэллоуин",
		startsAt = 1792022400, -- 15 октября 2026, 00:00 UTC
		endsAt = 1793923200, -- 6 ноября 2026, 00:00 UTC
		color = Color3.fromRGB(255, 140, 0),
	},
}

Seasons.ById = {}
for _, season in ipairs(Seasons.List) do
	Seasons.ById[season.id] = season
end

function Seasons.isActive(id, time)
	local season = Seasons.ById[id]
	return season ~= nil and time >= season.startsAt and time < season.endsAt
end

return Seasons
