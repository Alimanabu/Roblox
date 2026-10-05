-- Редкости брейнротов.
-- Главное правило игры: ЧЕМ ПОПУЛЯРНЕЕ ТРЕНД — ТЕМ РЕЖЕ ОН ВЫПАДАЕТ.
-- Порядок в списке = от самого обычного к самому редкому.

local Rarities = {}

Rarities.List = {
	{
		id = "normie",
		name = "Нормис",
		color = Color3.fromRGB(170, 170, 170),
		xp = 1,
	},
	{
		id = "lowkey",
		name = "Лоу-ки",
		color = Color3.fromRGB(90, 200, 90),
		xp = 2,
	},
	{
		id = "rizz",
		name = "Ризз",
		color = Color3.fromRGB(60, 140, 255),
		xp = 5,
	},
	{
		id = "sigma",
		name = "Сигма",
		color = Color3.fromRGB(170, 80, 255),
		xp = 12,
	},
	{
		id = "aura",
		name = "Аура",
		color = Color3.fromRGB(255, 180, 40),
		xp = 30,
	},
	{
		id = "skibidi",
		name = "Скибиди",
		color = Color3.fromRGB(255, 70, 110),
		xp = 80,
	},
	{
		id = "god",
		name = "Брейнрот Бог",
		color = Color3.fromRGB(255, 255, 255),
		rainbow = true,
		xp = 250,
		announce = true, -- объявляем на весь сервер
	},
	{
		id = "sixseven",
		name = "SIX SEVEN 🤌",
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
