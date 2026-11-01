-- Улучшения фабрики за монеты.

local S = require(script.Parent.Parent.Strings)

local Upgrades = {}

Upgrades.List = {
	{
		id = "speed",
		maxLevel = 10,
		baseCost = 100,
		costMult = 3,
	},
	{
		id = "luck",
		maxLevel = 20,
		baseCost = 500,
		costMult = 2.6,
		leadsToRandom = true, -- меняет шансы капсул (см. Formulas.randomCoins)
	},
	{
		id = "trap",
		maxLevel = 5,
		baseCost = 5000,
		costMult = 5,
	},
}

Upgrades.ById = {}
for _, upgrade in ipairs(Upgrades.List) do
	S.fill(upgrade, "upgrade." .. upgrade.id, "name", "desc")
	Upgrades.ById[upgrade.id] = upgrade
end

function Upgrades.get(id)
	return Upgrades.ById[id]
end

function Upgrades.cost(id, currentLevel)
	local upgrade = Upgrades.ById[id]
	return math.floor(upgrade.baseCost * upgrade.costMult ^ currentLevel)
end

return Upgrades
