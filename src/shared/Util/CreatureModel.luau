-- Собирает модель брейнрота из простых деталей: тело, глаза, рот, аксессуары.
-- Перед модели смотрит в +Z. Все детали заякорены, двигать модель через PivotTo.
-- Это «временные» модели — позже их можно заменить на нормальные меши и скины.

local Config = script.Parent.Parent.Config
local Creatures = require(Config.Creatures)
local Rarities = require(Config.Rarities)
local Mutations = require(Config.Mutations)
local Skins = require(Config.Skins)

local CreatureModel = {}

local BLACK = Color3.fromRGB(20, 20, 25)
local WHITE = Color3.fromRGB(250, 250, 250)
local GOLD = Color3.fromRGB(255, 200, 40)

local function darker(color, amount)
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, s, math.max(0, v - (amount or 0.2)))
end

-- Контекст сборки: размеры тела и функция добавления деталей.
local function newBuilder(model, origin, w, h, d)
	local b = { model = model, origin = origin, w = w, h = h, d = d }

	function b.add(name, shape, size, offset, color, material, props)
		local part
		if shape == "wedge" then
			part = Instance.new("WedgePart")
		else
			part = Instance.new("Part")
			if shape == "ball" then
				part.Shape = Enum.PartType.Ball
			elseif shape == "cylinder" then
				part.Shape = Enum.PartType.Cylinder
			end
		end
		part.Name = name
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Size = size
		part.CFrame = origin * offset
		part.Color = color
		part.Material = material or Enum.Material.SmoothPlastic
		for key, value in pairs(props or {}) do
			part[key] = value
		end
		part.Parent = model
		return part
	end

	return b
end

-- Вертикальный цилиндр (у Roblox ось цилиндра — X, поворачиваем на 90°).
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)

local Accessories = {}

function Accessories.headband(b, color)
	b.add("Headband", "block", Vector3.new(b.w * 1.04, b.h * 0.1, b.d * 1.04), CFrame.new(0, b.h * 0.3, 0), Color3.fromRGB(220, 40, 50))
	b.add("Knot", "block", Vector3.new(0.15, b.h * 0.25, b.h * 0.12), CFrame.new(b.w * 0.15, b.h * 0.22, -b.d / 2 - 0.1) * CFrame.Angles(0, 0, 0.6), Color3.fromRGB(220, 40, 50))
end

function Accessories.wings(b)
	for _, side in ipairs({ -1, 1 }) do
		b.add(
			"Wing",
			"block",
			Vector3.new(0.12, b.h * 0.55, b.d * 0.6),
			CFrame.new(side * (b.w / 2 + 0.1), b.h * 0.15, -b.d * 0.1) * CFrame.Angles(0, 0, side * -0.5),
			WHITE
		)
	end
end

function Accessories.shell(b, color)
	b.add("Shell", "ball", Vector3.one * b.h * 0.85, CFrame.new(0, b.h * 0.15, -b.d * 0.45), Color3.fromRGB(170, 110, 60), Enum.Material.SmoothPlastic)
end

function Accessories.antenna(b)
	b.add("Antenna", "cylinder", Vector3.new(b.h * 0.5, 0.12, 0.12), CFrame.new(0, b.h / 2 + b.h * 0.25, 0) * UPRIGHT, BLACK)
	b.add("AntennaTip", "ball", Vector3.one * 0.4, CFrame.new(0, b.h / 2 + b.h * 0.5, 0), Color3.fromRGB(255, 60, 60), Enum.Material.Neon)
end

function Accessories.ears(b, color)
	for _, side in ipairs({ -1, 1 }) do
		b.add("Ear", "wedge", Vector3.new(b.w * 0.08, b.h * 0.3, b.d * 0.3), CFrame.new(side * b.w * 0.3, b.h / 2 + b.h * 0.12, 0) * CFrame.Angles(0, math.pi / 2, 0), color)
	end
end

function Accessories.beak(b)
	b.add("Beak", "block", Vector3.new(b.w * 0.25, b.h * 0.12, b.d * 0.3), CFrame.new(0, -b.h * 0.02, b.d / 2), Color3.fromRGB(255, 160, 30))
end

function Accessories.boombox(b)
	b.add("Boombox", "block", Vector3.new(b.w * 0.6, b.h * 0.3, 0.3), CFrame.new(0, -b.h * 0.25, b.d * 0.45), BLACK)
	for _, side in ipairs({ -1, 1 }) do
		b.add("Speaker", "cylinder", Vector3.new(0.1, b.h * 0.22, b.h * 0.22), CFrame.new(side * b.w * 0.16, -b.h * 0.25, b.d * 0.45 + 0.16) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(90, 90, 100), Enum.Material.Metal)
	end
end

function Accessories.spikes(b)
	for i = 0, 7 do
		local angle = i / 8 * math.pi * 2
		local y = (i % 2 == 0) and b.h * 0.2 or -b.h * 0.15
		b.add(
			"Spike",
			"block",
			Vector3.new(0.08, 0.08, 0.5),
			CFrame.Angles(0, angle, 0) * CFrame.new(0, y, b.d / 2 + 0.15),
			WHITE
		)
	end
end

function Accessories.fin(b)
	b.add("Fin", "wedge", Vector3.new(0.15, b.h * 0.55, b.d * 0.45), CFrame.new(0, b.h / 2 + b.h * 0.25, -b.d * 0.05), Color3.fromRGB(90, 110, 140))
end

function Accessories.sneakers(b)
	for _, side in ipairs({ -1, 1 }) do
		local x = side * b.w * 0.25
		b.add("Sneaker", "block", Vector3.new(b.w * 0.3, b.h * 0.2, b.d * 0.55), CFrame.new(x, -b.h / 2 - b.h * 0.05, b.d * 0.1), WHITE)
		b.add("Stripe", "block", Vector3.new(b.w * 0.31, b.h * 0.06, b.d * 0.2), CFrame.new(x, -b.h / 2 - b.h * 0.05, b.d * 0.1), Color3.fromRGB(230, 40, 60))
	end
end

function Accessories.katana(b)
	b.add("Katana", "block", Vector3.new(0.12, b.h * 1.5, 0.12), CFrame.new(0, b.h * 0.1, -b.d / 2 - 0.15) * CFrame.Angles(0, 0, 0.7), Color3.fromRGB(210, 210, 220), Enum.Material.Metal)
	b.add("Hilt", "block", Vector3.new(0.2, b.h * 0.35, 0.2), CFrame.new(-b.w * 0.45, b.h * 0.6, -b.d / 2 - 0.15) * CFrame.Angles(0, 0, 0.7), BLACK)
end

function Accessories.tentacles(b, color)
	for i = 0, 5 do
		local angle = i / 6 * math.pi * 2
		b.add(
			"Tentacle",
			"cylinder",
			Vector3.new(b.h * 0.55, b.w * 0.12, b.w * 0.12),
			CFrame.Angles(0, angle, 0) * CFrame.new(0, -b.h / 2 - b.h * 0.12, b.d * 0.3) * CFrame.Angles(0.4, 0, 0) * UPRIGHT,
			darker(color, 0.1)
		)
	end
end

function Accessories.shades(b)
	b.add("Shades", "block", Vector3.new(b.w * 0.8, b.h * 0.16, 0.12), CFrame.new(0, b.h * 0.15, b.d / 2 + 0.12), BLACK, Enum.Material.Glass)
end

function Accessories.chin(b, color)
	b.add("Chin", "block", Vector3.new(b.w * 0.7, b.h * 0.28, b.d * 0.45), CFrame.new(0, -b.h * 0.38, b.d * 0.3), darker(color, 0.12))
end

function Accessories.flame(b)
	local flame = b.add("Flame", "ball", Vector3.one * b.h * 0.6, CFrame.new(0, 0, -b.d / 2 - 0.4), Color3.fromRGB(255, 120, 20), Enum.Material.Neon, { Transparency = 0.2 })
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 6
	fire.Parent = flame
end

function Accessories.horns(b)
	for _, side in ipairs({ -1, 1 }) do
		b.add("Horn", "wedge", Vector3.new(0.2, b.h * 0.4, b.d * 0.2), CFrame.new(side * b.w * 0.25, b.h / 2 + b.h * 0.15, -b.d * 0.1) * CFrame.Angles(0, 0, side * -0.3), Color3.fromRGB(240, 230, 200))
	end
end

function Accessories.halo(b)
	b.add("Halo", "cylinder", Vector3.new(0.12, b.w * 0.8, b.w * 0.8), CFrame.new(0, b.h / 2 + 0.7, 0) * UPRIGHT, GOLD, Enum.Material.Neon, { Transparency = 0.25 })
end

function Accessories.legs(b)
	for _, side in ipairs({ -1, 1 }) do
		b.add("Leg", "cylinder", Vector3.new(b.h * 0.9, 0.18, 0.18), CFrame.new(side * b.w * 0.15, -b.h / 2 - b.h * 0.35, 0) * UPRIGHT, Color3.fromRGB(255, 120, 170))
	end
end

function Accessories.trunk(b, color)
	b.add("Trunk", "cylinder", Vector3.new(b.h * 0.6, b.w * 0.18, b.w * 0.18), CFrame.new(0, -b.h * 0.2, b.d / 2 + b.h * 0.1) * CFrame.Angles(-0.6, 0, 0) * UPRIGHT, darker(color, 0.1))
end

function Accessories.headphones(b)
	b.add("Band", "block", Vector3.new(b.w * 1.1, 0.15, 0.25), CFrame.new(0, b.h / 2 + 0.1, 0), BLACK)
	for _, side in ipairs({ -1, 1 }) do
		b.add("Cup", "cylinder", Vector3.new(0.3, b.h * 0.35, b.h * 0.35), CFrame.new(side * (b.w / 2 + 0.1), b.h * 0.1, 0), Color3.fromRGB(255, 60, 140), Enum.Material.Neon)
	end
end

function Accessories.glitch(b)
	-- Детерминированный «глитч»: одинаковый у всех копий этого брейнрота.
	local rng = Random.new(67)
	for _ = 1, 7 do
		local offset = Vector3.new(rng:NextNumber(-0.6, 0.6) * b.w, rng:NextNumber(-0.5, 0.6) * b.h, rng:NextNumber(-0.6, 0.6) * b.d)
		local size = rng:NextNumber(0.2, 0.5)
		b.add("Glitch", "block", Vector3.one * size, CFrame.new(offset), Color3.fromHSV(rng:NextNumber(), 0.9, 1), Enum.Material.Neon)
	end
end

function Accessories.orbit(b)
	b.add("Orbit", "cylinder", Vector3.new(0.08, b.w * 1.7, b.w * 1.7), CFrame.Angles(0.4, 0, 0.2) * UPRIGHT, Color3.fromRGB(170, 120, 255), Enum.Material.Neon, { Transparency = 0.4 })
	b.add("Moon", "ball", Vector3.one * 0.5, CFrame.Angles(0.4, 0, 0.2) * CFrame.new(b.w * 0.85, 0, 0), WHITE, Enum.Material.Neon)
end

function Accessories.crown(b)
	b.add("Crown", "cylinder", Vector3.new(b.h * 0.2, b.w * 0.55, b.w * 0.55), CFrame.new(0, b.h / 2 + b.h * 0.1, 0) * UPRIGHT, GOLD, Enum.Material.Foil)
	for i = 0, 4 do
		local angle = i / 5 * math.pi * 2
		b.add("CrownSpike", "wedge", Vector3.new(0.12, b.h * 0.18, 0.3), CFrame.new(0, b.h / 2 + b.h * 0.27, 0) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, b.w * 0.22), GOLD, Enum.Material.Foil)
	end
end

function Accessories.cape(b)
	b.add("Cape", "block", Vector3.new(b.w * 0.9, b.h * 1.0, 0.1), CFrame.new(0, -b.h * 0.05, -b.d / 2 - 0.1) * CFrame.Angles(-0.12, 0, 0), Color3.fromRGB(200, 20, 40), Enum.Material.Fabric)
end

function Accessories.hands67(b)
	-- Руки в жесте «6-7»: одна выше, другая ниже. Клиент их покачивает.
	for index, side in ipairs({ -1, 1 }) do
		local hand = b.add(
			"Hand67",
			"block",
			Vector3.new(b.w * 0.28, b.h * 0.12, b.w * 0.32),
			CFrame.new(side * (b.w / 2 + b.w * 0.2), index == 1 and b.h * 0.05 or -b.h * 0.15, b.d * 0.2),
			Color3.fromRGB(255, 205, 160)
		)
		hand:SetAttribute("Side", index)
	end
end

local function bodySize(shape, s)
	if shape == "block" then
		return s, s * 0.85, s * 0.85
	elseif shape == "tall" then
		return s * 0.8, s * 1.3, s * 0.8
	elseif shape == "wide" then
		return s * 1.3, s * 0.75, s
	elseif shape == "wedge" then
		return s * 1.1, s * 0.5, s * 1.2
	end
	return s, s, s
end

local function applySkin(model, body, skin)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			local isFace = part.Name == "Eye" or part.Name == "Pupil" or part.Name == "Mouth"
			if part == body or (skin.allParts and not isFace) then
				part.Color = skin.color
				part.Material = Enum.Material[skin.material]
				part.Transparency = skin.transparency or 0
			end
			if skin.eyes and part.Name == "Pupil" then
				part.Color = skin.eyes
				part.Material = Enum.Material.Neon
			end
		end
	end
	if skin.effect == "fire" then
		local fire = Instance.new("Fire")
		fire.Size = 4
		fire.Heat = 8
		fire.Parent = body
	elseif skin.effect == "smoke" then
		local smoke = Instance.new("Smoke")
		smoke.Color = Color3.fromRGB(110, 255, 60)
		smoke.Opacity = 0.15
		smoke.RiseVelocity = 2
		smoke.Parent = body
	elseif skin.effect == "snow" or skin.effect == "stars" then
		local particles = Instance.new("ParticleEmitter")
		particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		particles.Color = ColorSequence.new(skin.effect == "snow" and Color3.new(1, 1, 1) or skin.color)
		particles.Rate = 6
		particles.Lifetime = NumberRange.new(1.2, 2)
		particles.Speed = NumberRange.new(0.5, 1.5)
		particles.SpreadAngle = Vector2.new(180, 180)
		particles.Size = NumberSequence.new(0.3, 0)
		particles.LightEmission = 1
		particles.Parent = body
	end
end

-- Возвращает Model. cframe — где стоит центр «пола» под брейнротом.
-- skinId — необязательный скин (Config/Skins).
function CreatureModel.build(creatureId, mutationId, cframe, skinId)
	local creature = Creatures.get(creatureId)
	local rarity = Rarities.get(creature.rarity)
	local mutation = Mutations.get(mutationId)

	local model = Instance.new("Model")
	model.Name = creature.id

	local shape = creature.body or "ball"
	local w, h, d = bodySize(shape, creature.size)
	local origin = cframe * CFrame.new(0, h / 2 + 0.3, 0)
	local b = newBuilder(model, origin, w, h, d)

	local color = mutation.color or creature.color
	local material = Enum.Material.SmoothPlastic
	local bodyProps = nil
	if mutation.id == "golden" then
		material = Enum.Material.Foil
	elseif mutation.id == "diamond" then
		material = Enum.Material.Glass
		bodyProps = { Transparency = 0.15, Reflectance = 0.3 }
	elseif mutation.id == "rainbow" or mutation.id == "sixseven" then
		material = Enum.Material.Neon
	end

	local body
	if shape == "tall" then
		body = b.add("Body", "cylinder", Vector3.new(h, w, d), UPRIGHT, color, material, bodyProps)
	elseif shape == "ball" then
		body = b.add("Body", "ball", Vector3.new(w, h, d), CFrame.new(), color, material, bodyProps)
	elseif shape == "wedge" then
		body = b.add("Body", "wedge", Vector3.new(w, h, d), CFrame.Angles(0, math.pi, 0), color, material, bodyProps)
	else
		body = b.add("Body", "block", Vector3.new(w, h, d), CFrame.new(), color, material, bodyProps)
	end
	body.CastShadow = true
	model.PrimaryPart = body

	-- Лицо.
	local eye = math.max(0.35, math.min(w, h) * 0.24)
	local faceZ = d / 2 * (shape == "ball" and 0.82 or 1) + 0.02
	for _, side in ipairs({ -1, 1 }) do
		b.add("Eye", "ball", Vector3.one * eye, CFrame.new(side * w * 0.2, h * 0.15, faceZ), WHITE)
		b.add("Pupil", "ball", Vector3.one * eye * 0.5, CFrame.new(side * w * 0.2, h * 0.15, faceZ + eye * 0.32), BLACK)
	end
	b.add("Mouth", "block", Vector3.new(w * 0.3, math.max(0.08, h * 0.05), 0.08), CFrame.new(0, -h * 0.1, faceZ), BLACK)

	for _, name in ipairs(creature.acc or {}) do
		local build = Accessories[name]
		if build then
			build(b, creature.color)
		end
	end

	-- Свечение и частицы для редких.
	if rarity.rank >= 5 then
		local light = Instance.new("PointLight")
		light.Color = rarity.rainbow and Color3.new(1, 1, 1) or rarity.color
		light.Range = 6 + rarity.rank
		light.Brightness = rarity.rank >= 7 and 3 or 1.5
		light.Parent = body
	end
	if rarity.rank >= 6 or mutation.rank >= 4 then
		local particles = Instance.new("ParticleEmitter")
		particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		particles.Color = ColorSequence.new(rarity.rainbow and Color3.fromRGB(255, 255, 120) or rarity.color)
		particles.Rate = rarity.rank >= 7 and 12 or 5
		particles.Lifetime = NumberRange.new(1, 1.6)
		particles.Speed = NumberRange.new(1, 2)
		particles.SpreadAngle = Vector2.new(180, 180)
		particles.Size = NumberSequence.new(0.4, 0)
		particles.LightEmission = 1
		particles.Parent = body
	end
	if mutation.id == "sixseven" then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Color3.fromRGB(255, 230, 0)
		sparkles.Parent = body
	end

	local skin = Skins.get(skinId)
	if skin then
		applySkin(model, body, skin)
	end

	model.WorldPivot = cframe
	model:SetAttribute("Rainbow", rarity.rainbow == true or mutation.id == "rainbow" or (skin ~= nil and skin.rainbow == true))
	model:SetAttribute("Skin", skinId)
	model:SetAttribute("Height", h + 0.3)
	return model, body
end

return CreatureModel
