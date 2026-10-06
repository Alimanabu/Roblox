-- Улучшения фабрики за монеты.

local Upgrades = {}

Upgrades.List = {
	{
		id = "speed",
		name = "Скорость машины",
		desc = "Машина создаёт брейнротов быстрее.",
		maxLevel = 10,
		baseCost = 100,
		costMult = 3,
	},
	{
		id = "luck",
		name = "Луч удачи",
		desc = "+8% удачи за уровень. Редкие тренды выпадают чаще.",
		maxLevel = 20,
		baseCost = 500,
		costMult = 2.6,
	},
	{
		id = "trap",
		name = "Ловушка для воров",
		desc = "Вор, схвативший брейнрота, оглушён на 1.5 с за уровень.",
		maxLevel = 5,
		baseCost = 5000,
		costMult = 5,
	},
}

Upgrades.ById = {}
for _, upgrade in ipairs(Upgrades.List) do
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
