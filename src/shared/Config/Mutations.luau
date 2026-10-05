-- Мутации: случайно выпадают при создании брейнрота и умножают доход.
-- chance — шанс в долях (0.06 = 6%). Проверяются от самой редкой к самой частой.

local Mutations = {}

Mutations.List = {
	{ id = "normal", name = "", mult = 1, chance = 0 },
	{ id = "golden", name = "Золотой", mult = 2, chance = 0.06, color = Color3.fromRGB(255, 200, 40) },
	{ id = "diamond", name = "Алмазный", mult = 3, chance = 0.015, color = Color3.fromRGB(120, 230, 255) },
	{ id = "rainbow", name = "Радужный", mult = 5, chance = 0.004, color = Color3.fromRGB(255, 120, 255) },
	{ id = "sixseven", name = "Мутация 67", mult = 6.7, chance = 0.00067, color = Color3.fromRGB(255, 230, 0) },
	{ id = "cosmic", name = "Космический", mult = 10, chance = 0.0002, color = Color3.fromRGB(140, 80, 255) },
}

Mutations.ById = {}
for index, mutation in ipairs(Mutations.List) do
	mutation.rank = index
	Mutations.ById[mutation.id] = mutation
end

function Mutations.get(id)
	return Mutations.ById[id] or Mutations.ById.normal
end

return Mutations
