-- Скины брейнротов: только внешний вид, на доход не влияют.
-- Покупаются за монеты (price) или выдаются кодами/наградами (price = nil).
-- Скин надевается на конкретного брейнрота и остаётся с ним при краже и обмене.

local Skins = {}

Skins.List = {
	{ id = "fire", name = "🔥 Огненный", price = 50000, color = Color3.fromRGB(255, 90, 20), material = "Neon", effect = "fire" },
	{ id = "ice", name = "🧊 Ледяной", price = 50000, color = Color3.fromRGB(170, 230, 255), material = "Glass", transparency = 0.2, effect = "snow" },
	{ id = "toxic", name = "☢️ Токсичный", price = 500000, color = Color3.fromRGB(110, 255, 60), material = "Neon", effect = "smoke" },
	{ id = "shadow", name = "🌑 Теневой", price = 500000, color = Color3.fromRGB(25, 20, 30), material = "SmoothPlastic", eyes = Color3.fromRGB(255, 30, 30) },
	{ id = "gold", name = "👑 Чистое золото", price = 5000000, color = Color3.fromRGB(255, 200, 40), material = "Foil", allParts = true },
	{ id = "galaxy", name = "🌌 Галактика", price = 50000000, color = Color3.fromRGB(120, 60, 255), material = "ForceField", effect = "stars" },
	{ id = "rainbow", name = "🌈 Радужный", price = 670000000, color = Color3.fromRGB(255, 255, 255), material = "Neon", rainbow = true },
	{ id = "sixseven", name = "🤌 Скин 67", price = nil, color = Color3.fromRGB(255, 230, 0), material = "Neon", effect = "stars", eyes = Color3.fromRGB(255, 120, 0) },
}

Skins.ById = {}
for index, skin in ipairs(Skins.List) do
	skin.order = index
	Skins.ById[skin.id] = skin
end

function Skins.get(id)
	return id and Skins.ById[id] or nil
end

return Skins
