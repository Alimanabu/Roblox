-- Мем-капсулы: их кидают в машину фабрики, и из них получается брейнрот.
-- weights — относительные веса редкостей (не обязаны давать в сумме 100).
-- level — с какого уровня игрока открывается капсула.
-- rebirths — сколько перерождений нужно.

local Capsules = {}

Capsules.List = {
	{
		id = "old_meme",
		name = "Старый мем",
		desc = "Мем из 2016-го. Кринж, но работает.",
		cost = 100,
		level = 1,
		color = Color3.fromRGB(150, 150, 150),
		weights = { normie = 80, lowkey = 18, rizz = 2 },
	},
	{
		id = "chat_meme",
		name = "Мем из чата",
		desc = "Кто-то скинул в чат класса.",
		cost = 750,
		level = 3,
		color = Color3.fromRGB(90, 200, 90),
		weights = { normie = 50, lowkey = 35, rizz = 13, sigma = 2 },
	},
	{
		id = "viral_meme",
		name = "Вирусный мем",
		desc = "Уже 1 млн просмотров!",
		cost = 10000,
		level = 6,
		color = Color3.fromRGB(60, 140, 255),
		weights = { lowkey = 46, rizz = 36, sigma = 15, aura = 3 },
	},
	{
		id = "trend_sound",
		name = "Трендовый звук",
		desc = "Этот звук играет в каждом втором видео.",
		cost = 150000,
		level = 10,
		color = Color3.fromRGB(170, 80, 255),
		weights = { rizz = 45, sigma = 40, aura = 13, skibidi = 2 },
	},
	{
		id = "mega_trend",
		name = "Мега-тренд",
		desc = "Про это говорят даже родители.",
		cost = 2000000,
		level = 15,
		color = Color3.fromRGB(255, 180, 40),
		weights = { sigma = 52, aura = 38, skibidi = 9.7, god = 0.3 },
	},
	{
		id = "brainrot_core",
		name = "Брейнрот-ядро",
		desc = "Чистый концентрированный брейнрот.",
		cost = 25000000,
		level = 22,
		color = Color3.fromRGB(255, 70, 110),
		weights = { aura = 58, skibidi = 39, god = 3 },
	},
	{
		id = "capsule_67",
		name = "Капсула 67",
		desc = "Шесть... семь... 🤌",
		cost = 670000000,
		level = 30,
		rebirths = 1,
		color = Color3.fromRGB(255, 230, 0),
		weights = { skibidi = 65, god = 34.33, sixseven = 0.67 },
	},
}

-- Секрет: из ЛЮБОЙ капсулы может выпасть SIX SEVEN с шансом 1 к 67 000 (умножается на удачу).
Capsules.SECRET_SIXSEVEN_CHANCE = 1 / 67000

Capsules.ById = {}
for index, capsule in ipairs(Capsules.List) do
	capsule.order = index
	capsule.rebirths = capsule.rebirths or 0
	Capsules.ById[capsule.id] = capsule
end

function Capsules.get(id)
	return Capsules.ById[id]
end

return Capsules
