-- Mutations: drop randomly when a brainrot is created and multiply income.
-- chance is the chance as a fraction (0.06 = 6%). Checked from the rarest to the most common.

local S = require(script.Parent.Parent.Strings)

local Mutations = {}

Mutations.List = {
	{ id = "normal", name = "", mult = 1, chance = 0 },
	{ id = "golden", mult = 2, chance = 0.06, color = Color3.fromRGB(255, 200, 40) },
	{ id = "diamond", mult = 3, chance = 0.015, color = Color3.fromRGB(120, 230, 255) },
	{ id = "rainbow", mult = 5, chance = 0.004, color = Color3.fromRGB(255, 120, 255) },
	{ id = "sixseven", mult = 6.7, chance = 0.00067, color = Color3.fromRGB(255, 230, 0) },
	{ id = "cosmic", mult = 10, chance = 0.0002, color = Color3.fromRGB(140, 80, 255) },
}

Mutations.ById = {}
for index, mutation in ipairs(Mutations.List) do
	mutation.rank = index
	if mutation.id ~= "normal" then
		S.fill(mutation, "mutation." .. mutation.id, "name")
	end
	Mutations.ById[mutation.id] = mutation
end

function Mutations.get(id)
	return Mutations.ById[id] or Mutations.ById.normal
end

return Mutations
