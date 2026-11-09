-- Brainrot rarities.
-- The main rule of the game: THE MORE POPULAR THE TREND, THE RARER IT DROPS.
-- Order in the list = from the most common to the rarest.

local S = require(script.Parent.Parent.Strings)

local Rarities = {}

Rarities.List = {
	{
		id = "normie",
		color = Color3.fromRGB(170, 170, 170),
		xp = 1,
	},
	{
		id = "lowkey",
		color = Color3.fromRGB(90, 200, 90),
		xp = 2,
	},
	{
		id = "rizz",
		color = Color3.fromRGB(60, 140, 255),
		xp = 5,
	},
	{
		id = "sigma",
		color = Color3.fromRGB(170, 80, 255),
		xp = 12,
	},
	{
		id = "aura",
		color = Color3.fromRGB(255, 180, 40),
		xp = 30,
	},
	{
		id = "skibidi",
		color = Color3.fromRGB(255, 70, 110),
		xp = 80,
	},
	{
		id = "god",
		color = Color3.fromRGB(255, 255, 255),
		rainbow = true,
		xp = 250,
		announce = true, -- announce to the whole server
	},
	{
		id = "sixseven",
		color = Color3.fromRGB(255, 230, 0),
		rainbow = true,
		xp = 1000,
		announce = true,
		secret = true,
	},
}

Rarities.ById = {}
for index, rarity in ipairs(Rarities.List) do
	rarity.rank = index
	S.fill(rarity, "rarity." .. rarity.id, "name")
	Rarities.ById[rarity.id] = rarity
end

function Rarities.get(id)
	return Rarities.ById[id]
end

function Rarities.next(id)
	local rarity = Rarities.ById[id]
	if not rarity then
		return nil
	end
	return Rarities.List[rarity.rank + 1]
end

return Rarities
