-- Meme capsules: they are thrown into the factory machine and a brainrot comes out of them.
-- weights are relative rarity weights (they need not sum to 100).
-- level is the player level at which the capsule unlocks.
-- rebirths is how many rebirths are needed.

local S = require(script.Parent.Parent.Strings)

local Capsules = {}

Capsules.List = {
	{
		id = "old_meme",
		cost = 100,
		level = 1,
		color = Color3.fromRGB(150, 150, 150),
		weights = { normie = 80, lowkey = 18, rizz = 2 },
	},
	{
		id = "chat_meme",
		cost = 750,
		level = 3,
		color = Color3.fromRGB(90, 200, 90),
		weights = { normie = 50, lowkey = 35, rizz = 13, sigma = 2 },
	},
	{
		id = "viral_meme",
		cost = 10000,
		level = 6,
		color = Color3.fromRGB(60, 140, 255),
		weights = { lowkey = 46, rizz = 36, sigma = 15, aura = 3 },
	},
	{
		id = "trend_sound",
		cost = 150000,
		level = 10,
		color = Color3.fromRGB(170, 80, 255),
		weights = { rizz = 45, sigma = 40, aura = 13, skibidi = 2 },
	},
	{
		id = "mega_trend",
		cost = 2000000,
		level = 15,
		color = Color3.fromRGB(255, 180, 40),
		weights = { sigma = 52, aura = 38, skibidi = 9.7, god = 0.3 },
	},
	{
		id = "brainrot_core",
		cost = 25000000,
		level = 22,
		color = Color3.fromRGB(255, 70, 110),
		weights = { aura = 58, skibidi = 39, god = 3 },
	},
	{
		id = "capsule_67",
		cost = 670000000,
		level = 30,
		rebirths = 1,
		color = Color3.fromRGB(255, 230, 0),
		weights = { skibidi = 65, god = 34.33, sixseven = 0.67 },
	},
	{
		id = "halloween_capsule",
		cost = 120000,
		level = 8,
		season = "halloween",
		color = Color3.fromRGB(255, 140, 0),
		weights = { rizz = 50, sigma = 35, aura = 13, skibidi = 2 },
	},
	{
		id = "newyear_capsule",
		cost = 300000,
		level = 10,
		season = "newyear",
		color = Color3.fromRGB(80, 200, 255),
		weights = { rizz = 50, sigma = 35, aura = 13, skibidi = 2 },
	},
	{
		id = "valentine_capsule",
		cost = 400000,
		level = 10,
		season = "valentine",
		color = Color3.fromRGB(255, 100, 160),
		weights = { rizz = 50, sigma = 35, aura = 13, skibidi = 2 },
	},
	{
		id = "summer_capsule",
		cost = 1000000,
		level = 12,
		season = "summer",
		color = Color3.fromRGB(255, 210, 60),
		weights = { rizz = 50, sigma = 35, aura = 13, skibidi = 2 },
	},
	{
		id = "world_trend",
		cost = 10000000000,
		level = 40,
		rebirths = 3,
		color = Color3.fromRGB(80, 220, 255),
		weights = { god = 97, sixseven = 3 },
	},
	{
		id = "ultra_brainrot",
		cost = 1000000000000,
		level = 50,
		rebirths = 5,
		color = Color3.fromRGB(255, 80, 255),
		weights = { god = 90, sixseven = 10 },
	},
}

-- Secret: from ANY capsule SIX SEVEN can drop with a 1 in 67,000 chance (multiplied by luck).
Capsules.SECRET_SIXSEVEN_CHANCE = 1 / 67000

Capsules.ById = {}
for index, capsule in ipairs(Capsules.List) do
	S.fill(capsule, "capsule." .. capsule.id, "name", "desc")
	capsule.order = index
	capsule.rebirths = capsule.rebirths or 0
	Capsules.ById[capsule.id] = capsule
end

function Capsules.get(id)
	return Capsules.ById[id]
end

return Capsules
