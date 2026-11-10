-- Player bases: plot, factory machine and brainrots standing on pedestals.
-- For now everything is made from simple parts; later we will replace them with proper models and skins.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local S = require(Shared.Strings)
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local Formulas = require(Shared.Util.Formulas)
local Format = require(Shared.Util.Format)
local CreatureModel = require(Shared.Util.CreatureModel)

local MoveGuardService = require(script.Parent.MoveGuardService)
local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local FactoryService = require(script.Parent.FactoryService)
local ProgressionService = require(script.Parent.ProgressionService)
local EventService = require(script.Parent.EventService)

local PlotService = {}

local PLOT_COUNT = 8
local PLOT_SIZE = 90
local RING_RADIUS = 150

-- Base building: floor 1 on the ground, floor 2 above it. Each floor has 2 rows of 5 spots.
local FLOOR_HEIGHT = 14 -- how much higher floor 2 is than the ground
local PAD_X = { -24, -12, 0, 12, 24 }
local PAD_Z = { -21, -9 }
local BUILDING_CENTER_Z = -15
local BUILDING_WIDTH = 68
local BUILDING_DEPTH = 30
local RAILING_HEIGHT = 8 -- above a jump: you cannot jump over the glass with a brainrot

PlotService.PLOT_SIZE = PLOT_SIZE

local plotsFolder
local plots = {} -- { { model, owner, origin } }
local plotOf = {} -- [player] = plot

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		p[key] = value
	end
	return p
end

-- Label over a brainrot on a base: 5 x 2.8 studs (the old 180 x 100 pixels on PC seen from 20 studs), up to 60 studs away.
local INFO_SIZE = UDim2.fromScale(5, 2.8)
local INFO_DISTANCE = 60
PlotService.INFO_SIZE = INFO_SIZE
PlotService.INFO_DISTANCE = INFO_DISTANCE

local function billboard(parent, size, offset, text, color)
	local gui = Instance.new("BillboardGui")
	gui.Size = size
	gui.StudsOffset = offset
	gui.MaxDistance = 120
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.RichText = true
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	S.apply(label, "Text", text)
	label.Parent = gui
	return gui
end

local function buildWorld()
	plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = workspace

	if not workspace:FindFirstChild("Baseplate") then
		part({
			Name = "Ground",
			Size = Vector3.new(600, 2, 600),
			Position = Vector3.new(0, -1, 0),
			Color = Color3.fromRGB(110, 200, 110),
			Material = Enum.Material.Grass,
			Parent = workspace,
		})
	end

	-- Center: a plaza with the spawn and a big sign.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "CenterSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(0, 0.5, 0)
	spawn.Color = Color3.fromRGB(255, 210, 60)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Duration = 0 -- without the force-field bubble
	spawn.Parent = workspace
	MoveGuardService.setSpawnPoint(spawn.Position)

	local sign = part({
		Name = "TitleSign",
		Size = Vector3.new(1, 1, 1),
		Position = Vector3.new(0, 18, 0),
		Transparency = 1,
		CanCollide = false,
		Parent = workspace,
	})
	billboard(sign, UDim2.fromOffset(600, 150), Vector3.zero, "🧠 BRAINROT CAPSULE FACTORY 🤌", Color3.fromRGB(255, 230, 0))

	for i = 1, PLOT_COUNT do
		local angle = (i - 1) / PLOT_COUNT * math.pi * 2
		local origin = Vector3.new(math.cos(angle) * RING_RADIUS, 0, math.sin(angle) * RING_RADIUS)
		-- The plot "looks" at the center of the map.
		local cframe = CFrame.lookAt(origin, Vector3.new(0, 0, 0))

		local model = Instance.new("Model")
		model.Name = "Plot" .. i

		local floor = part({
			Name = "Floor",
			Size = Vector3.new(PLOT_SIZE, 1, PLOT_SIZE),
			CFrame = cframe * CFrame.new(0, 0.5, 0),
			Color = Color3.fromHSV((i - 1) / PLOT_COUNT, 0.25, 0.45),
			Material = Enum.Material.SmoothPlastic,
			Parent = model,
		})
		model.PrimaryPart = floor

		-- A glowing border of its own color for each base.
		local rimColor = Color3.fromHSV((i - 1) / PLOT_COUNT, 0.7, 1)
		local half = PLOT_SIZE / 2
		for _, rim in ipairs({
			{ Vector3.new(0, 1.2, -half), Vector3.new(PLOT_SIZE, 0.4, 1) },
			{ Vector3.new(0, 1.2, half), Vector3.new(PLOT_SIZE, 0.4, 1) },
			{ Vector3.new(-half, 1.2, 0), Vector3.new(1, 0.4, PLOT_SIZE) },
			{ Vector3.new(half, 1.2, 0), Vector3.new(1, 0.4, PLOT_SIZE) },
		}) do
			part({
				Name = "Rim",
				Size = rim[2],
				CFrame = cframe * CFrame.new(rim[1]),
				Color = rimColor,
				Material = Enum.Material.Neon,
				CanCollide = false,
				Parent = model,
			})
		end

		local machine = part({
			Name = "Machine",
			Size = Vector3.new(12, 10, 8),
			CFrame = cframe * CFrame.new(0, 6, -PLOT_SIZE / 2 + 10),
			Color = Color3.fromRGB(255, 80, 160),
			Material = Enum.Material.Neon,
			Parent = model,
		})
		billboard(machine, UDim2.fromOffset(240, 60), Vector3.new(0, 8, 0), S.m("plot.machine"), Color3.new(1, 1, 1))

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "FactoryPrompt"
		S.apply(prompt, "ActionText", S.m("plot.open_factory"))
		S.apply(prompt, "ObjectText", S.m("plot.machine_object"))
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.Parent = machine

		local ownerSign = part({
			Name = "OwnerSign",
			Size = Vector3.new(1, 1, 1),
			CFrame = cframe * CFrame.new(0, 30, -PLOT_SIZE / 2 + 10),
			Transparency = 1,
			CanCollide = false,
			Parent = model,
		})
		billboard(ownerSign, UDim2.fromOffset(400, 80), Vector3.zero, S.m("plot.free_base"), Color3.fromRGB(200, 200, 200)).Name =
			"OwnerGui"

		-- Lock button: closes the base from thieves.
		local lockButton = part({
			Name = "LockButton",
			Size = Vector3.new(6, 1, 6),
			CFrame = cframe * CFrame.new(PLOT_SIZE / 2 - 8, 1, PLOT_SIZE / 2 - 8),
			Color = Color3.fromRGB(80, 200, 255),
			Material = Enum.Material.Neon,
			Parent = model,
		})
		billboard(lockButton, UDim2.fromOffset(200, 50), Vector3.new(0, 4, 0), S.m("plot.lock"), Color3.new(1, 1, 1)).Name = "LockGui"
		local lockPrompt = Instance.new("ProximityPrompt")
		lockPrompt.Name = "LockPrompt"
		S.apply(lockPrompt, "ActionText", S.m("plot.lock_action"))
		S.apply(lockPrompt, "ObjectText", S.m("plot.lock_object"))
		lockPrompt.HoldDuration = 0
		lockPrompt.MaxActivationDistance = 10
		lockPrompt.RequiresLineOfSight = false
		lockPrompt.Parent = lockButton

		-- Laser fence: visible when the base is closed.
		local barrier = Instance.new("Folder")
		barrier.Name = "Barrier"
		barrier.Parent = model
		local half = PLOT_SIZE / 2
		for _, offset in ipairs({
			{ Vector3.new(0, 4, -half), Vector3.new(PLOT_SIZE, 8, 0.5) },
			{ Vector3.new(0, 4, half), Vector3.new(PLOT_SIZE, 8, 0.5) },
			{ Vector3.new(-half, 4, 0), Vector3.new(0.5, 8, PLOT_SIZE) },
			{ Vector3.new(half, 4, 0), Vector3.new(0.5, 8, PLOT_SIZE) },
		}) do
			part({
				Name = "Wall",
				Size = offset[2],
				CFrame = cframe * CFrame.new(offset[1]),
				Color = Color3.fromRGB(255, 50, 80),
				Material = Enum.Material.ForceField,
				Transparency = 1,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				Parent = barrier,
			})
		end

		-- Build sign: floors are bought here.
		part({
			Name = "BuildPost",
			Size = Vector3.new(0.8, 6, 0.8),
			CFrame = cframe * CFrame.new(-40, 4, BUILDING_CENTER_Z),
			Color = Color3.fromRGB(110, 75, 45),
			Material = Enum.Material.Wood,
			Parent = model,
		})
		local buildSign = part({
			Name = "BuildSign",
			Size = Vector3.new(0.5, 4, 7),
			CFrame = cframe * CFrame.new(-40, 8, BUILDING_CENTER_Z),
			Color = Color3.fromRGB(255, 200, 40),
			Material = Enum.Material.SmoothPlastic,
			Parent = model,
		})
		billboard(buildSign, UDim2.fromOffset(260, 90), Vector3.new(0, 5, 0), "", Color3.fromRGB(255, 220, 80)).Name = "BuildGui"
		local buildPrompt = Instance.new("ProximityPrompt")
		buildPrompt.Name = "BuildPrompt"
		S.apply(buildPrompt, "ActionText", S.m("plot.build"))
		buildPrompt.HoldDuration = 0.6
		buildPrompt.MaxActivationDistance = 12
		buildPrompt.RequiresLineOfSight = false
		buildPrompt.Parent = buildSign

		local buildingFolder = Instance.new("Folder")
		buildingFolder.Name = "Building"
		buildingFolder.Parent = model

		local padsFolder = Instance.new("Folder")
		padsFolder.Name = "Pads"
		padsFolder.Parent = model

		local creaturesFolder = Instance.new("Folder")
		creaturesFolder.Name = "Creatures"
		creaturesFolder.Parent = model

		model.Parent = plotsFolder
		table.insert(plots, { model = model, owner = nil, cframe = cframe, color = rimColor })
	end
end

-- Spot on the base: 1..10 on the bottom, 11..20 on floor 2.
local function padCFrame(plot, pad)
	local index = (pad - 1) % Formulas.FLOOR_SLOTS
	local x = PAD_X[index % #PAD_X + 1]
	local z = PAD_Z[math.floor(index / #PAD_X) + 1]
	local y = pad > Formulas.FLOOR_SLOTS and 1 + FLOOR_HEIGHT or 1
	return plot.cframe * CFrame.new(x, y, z)
end

-- A building part in the plot's local coordinates.
local function buildingPart(plot, name, size, offset, props)
	local p = part({
		Name = name,
		Size = size,
		CFrame = plot.cframe * offset,
		Parent = plot.model.Building,
	})
	for key, value in pairs(props or {}) do
		p[key] = value
	end
	return p
end

local function glass(plot, size, offset)
	buildingPart(plot, "Railing", size, offset, {
		Color = Color3.fromRGB(170, 220, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.7,
	})
end

local function floorSign(plot, height, text, color)
	local anchor = buildingPart(plot, "FloorSign", Vector3.one, CFrame.new(-BUILDING_WIDTH / 2, height, BUILDING_CENTER_Z - BUILDING_DEPTH / 2), {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	billboard(anchor, UDim2.fromOffset(220, 44), Vector3.zero, text, color).MaxDistance = 90
end

-- Builds the building for the needed number of floors. The next floor is shown as a "ghost".
local function buildBuilding(plot, floors)
	plot.model.Building:ClearAllChildren()
	local slab = Vector3.new(BUILDING_WIDTH, 0.4, BUILDING_DEPTH)
	local center = CFrame.new(0, 0, BUILDING_CENTER_Z)
	local tint = plot.color:Lerp(Color3.new(1, 1, 1), 0.55)

	if floors >= 1 then
		buildingPart(plot, "Floor1", slab, center * CFrame.new(0, 1, 0), { Color = tint, Material = Enum.Material.Marble })
		floorSign(plot, 3.5, S.m("plot.floor1_sign", { hp = Formulas.Floors[1].hp }), Color3.new(1, 1, 1))
	else
		buildingPart(plot, "Ghost1", slab, center * CFrame.new(0, 1, 0), {
			Color = Color3.fromRGB(255, 220, 60),
			Material = Enum.Material.ForceField,
			CanCollide = false,
			CanQuery = false,
		})
	end

	if floors < 2 then
		if floors == 1 then
			buildingPart(plot, "Ghost2", Vector3.new(BUILDING_WIDTH, 1, BUILDING_DEPTH), center * CFrame.new(0, 0.5 + FLOOR_HEIGHT, 0), {
				Color = Color3.fromRGB(255, 220, 60),
				Material = Enum.Material.ForceField,
				CanCollide = false,
				CanQuery = false,
			})
		end
		return
	end

	-- Floor 2: columns, floor, glass railings, a landing and a ramp on the right.
	local halfW, halfD = BUILDING_WIDTH / 2, BUILDING_DEPTH / 2
	for _, corner in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		buildingPart(
			plot,
			"Pillar",
			Vector3.new(1.6, FLOOR_HEIGHT, 1.6),
			center * CFrame.new(corner[1] * (halfW - 0.8), 1 + FLOOR_HEIGHT / 2, corner[2] * (halfD - 0.8)),
			{ Color = plot.color, Material = Enum.Material.Metal }
		)
	end
	local top = 1 + FLOOR_HEIGHT
	buildingPart(plot, "Floor2", Vector3.new(BUILDING_WIDTH, 1, BUILDING_DEPTH), center * CFrame.new(0, top - 0.5, 0), {
		Color = Color3.fromRGB(255, 215, 90),
		Material = Enum.Material.Marble,
	})
	-- Landing by the ramp.
	buildingPart(plot, "Landing", Vector3.new(8, 1, 8), center * CFrame.new(halfW + 4, top - 0.5, halfD - 6), {
		Color = Color3.fromRGB(255, 215, 90),
		Material = Enum.Material.Marble,
	})
	-- Ramp from the ground (at the back) up to the landing.
	local run, rise = 30, FLOOR_HEIGHT
	local angle = math.atan2(rise, run)
	local ramp = buildingPart(
		plot,
		"Ramp",
		Vector3.new(8, 1, math.sqrt(run * run + rise * rise) + 1),
		center * CFrame.new(halfW + 4, 1 + rise / 2 - 0.5, halfD - 2 + run / 2) * CFrame.Angles(angle, 0, 0),
		{ Color = tint, Material = Enum.Material.Concrete }
	)
	ramp.TopSurface = Enum.SurfaceType.Smooth

	local y = top + RAILING_HEIGHT / 2
	local h = RAILING_HEIGHT
	glass(plot, Vector3.new(BUILDING_WIDTH, h, 0.5), center * CFrame.new(0, y, -halfD))
	glass(plot, Vector3.new(BUILDING_WIDTH, h, 0.5), center * CFrame.new(0, y, halfD))
	glass(plot, Vector3.new(0.5, h, BUILDING_DEPTH), center * CFrame.new(-halfW, y, 0))
	-- Passage to the landing on the right (the last 8 studs before the back wall).
	glass(plot, Vector3.new(0.5, h, BUILDING_DEPTH - 10), center * CFrame.new(halfW, y, -5))
	glass(plot, Vector3.new(0.5, h, 2), center * CFrame.new(halfW, y, halfD - 1))
	glass(plot, Vector3.new(0.5, h, 8), center * CFrame.new(halfW + 8, y, halfD - 6))
	glass(plot, Vector3.new(8, h, 0.5), center * CFrame.new(halfW + 4, y, halfD - 10))

	floorSign(plot, top + RAILING_HEIGHT + 2, S.m("plot.floor2_sign", { hp = Formulas.Floors[2].hp, income = Formulas.Floors[2].income }), Color3.fromRGB(255, 220, 80))
end

-- The build sign and the building itself.
local function updateBuilding(plot, floors, passes)
	if plot.builtFloors ~= floors then
		plot.builtFloors = floors
		buildBuilding(plot, floors)
	end
	local cost = Formulas.floorCost(floors, passes)
	local label = plot.model.BuildSign.BuildGui.Label
	local prompt = plot.model.BuildSign.BuildPrompt
	if cost then
		local nextFloor = Formulas.Floors[floors + 1]
		local perks = S.m("plot.perks", { slots = Formulas.FLOOR_SLOTS * (floors + 1), hp = nextFloor.hp })
		if nextFloor.income > 1 then
			perks = S.m("plot.perks_income", { perks = perks, income = nextFloor.income })
		end
		local price = Format.coins(cost)
		S.apply(label, "Text", S.m("plot.build_sign", { floor = S.m(nextFloor.nameKey), price = price, perks = perks }))
		S.apply(prompt, "ObjectText", S.m("plot.build_object", { floor = S.m(nextFloor.nameKey), price = price }))
	else
		S.apply(label, "Text", S.m("plot.built"))
		S.apply(prompt, "ObjectText", "")
	end
	plot.model:SetAttribute("CanBuild", cost ~= nil)
end

local HP_FULL = Color3.fromRGB(90, 230, 110)
local HP_LOW = Color3.fromRGB(255, 70, 70)
local STUNNED = Color3.fromRGB(255, 220, 60)

-- The heart bar above a brainrot and the steal button. While hearts remain you cannot steal, you must slap.
function PlotService.refreshHp(model)
	local body = model.PrimaryPart
	local gui = body and body:FindFirstChild("InfoGui")
	local prompt = body and body:FindFirstChild("StealPrompt")
	local hp = model:GetAttribute("Hp") or 0
	local maxHp = math.max(1, model:GetAttribute("MaxHp") or 1)
	local stunned = model:GetAttribute("StunnedUntil") ~= nil
	local bar = gui and gui:FindFirstChild("HpBar")
	if bar then
		local ratio = stunned and 1 or hp / maxHp
		bar.Fill.Size = UDim2.fromScale(ratio, 1)
		bar.Fill.BackgroundColor3 = stunned and STUNNED or HP_LOW:Lerp(HP_FULL, ratio)
		S.apply(bar.Value, "Text", if stunned then S.m("plot.stunned") else S.m("plot.hp", { hp = hp, max = maxHp }))
	end
	if prompt then
		if stunned then
			S.apply(prompt, "ActionText", S.m("plot.steal"))
			prompt.HoldDuration = model:GetAttribute("StealHold") or 1
		else
			S.apply(prompt, "ActionText", S.m("plot.slap", { hp = hp }))
			prompt.HoldDuration = 0
		end
	end
end

local function setFloor(model, floor, rank)
	local info = Formulas.Floors[floor]
	model:SetAttribute("Floor", floor)
	model:SetAttribute("MaxHp", info.hp)
	model:SetAttribute("Hp", info.hp)
	model:SetAttribute("StunnedUntil", nil)
	model:SetAttribute("StealHold", (0.8 + rank * 0.4) * info.stealTime)
end

local function labelText(entry, creature, rarity, mutation, data, passes, floor)
	local nameText = S.m(creature.nameKey)
	if mutation.id ~= "normal" then
		nameText = S.m("creature.mutated", { mutation = S.m(mutation.nameKey), name = nameText })
	end
	if entry.nickname then
		-- Label with RichText: we escape it so the name does not break the markup.
		local safe = entry.nickname:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
		nameText = S.m("plot.nickname", { nickname = safe, name = nameText })
	end
	return S.m("plot.creature_label", {
		name = nameText,
		color = rarity.color:ToHex(),
		rarity = S.m(rarity.nameKey),
		income = Format.coins(Formulas.creatureIncome(entry, data, passes, EventService.mods(), floor)),
	})
end

local function buildCreature(plot, entry, standCFrame, data, passes, floor)
	local creature = Creatures.get(entry.id)
	local rarity = Rarities.get(creature.rarity)
	local mutation = Mutations.get(entry.mut)

	local model, body = CreatureModel.build(entry.id, entry.mut, standCFrame, entry.skin)
	model.Name = "Creature"
	model:SetAttribute("Uid", entry.uid)
	-- The client uses this attribute to do the "swaying" animation.
	model:SetAttribute("BaseCFrame", standCFrame)
	local size = model:GetAttribute("Height")

	-- Other players can steal a brainrot: first knock out the hearts with the Slapper, then hold F.
	-- The rarer the brainrot and the higher the floor, the longer it takes to steal.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealPrompt"
	S.apply(prompt, "ObjectText", S.m(creature.nameKey))
	prompt:SetAttribute("CreatureId", entry.id)
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt:SetAttribute("Uid", entry.uid)
	prompt.Parent = body

	-- Label over the brainrot: sized in studs, so it shrinks with distance instead of covering
	-- a phone screen with fixed 180x100 pixels; seen only near the base (INFO_DISTANCE).
	local gui = billboard(
		body,
		INFO_SIZE,
		Vector3.new(0, size / 2 + 2.2, 0),
		labelText(entry, creature, rarity, mutation, data, passes, floor)
	)
	gui.Name = "InfoGui"
	gui.MaxDistance = INFO_DISTANCE
	gui.Label.Size = UDim2.fromScale(1, 0.78)
	local bar = Instance.new("Frame")
	bar.Name = "HpBar"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.fromScale(0.5, 0.8)
	bar.Size = UDim2.fromScale(0.8, 0.18)
	bar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	bar.BackgroundTransparency = 0.2
	bar.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = bar
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.Parent = bar
	corner:Clone().Parent = fill
	local value = Instance.new("TextLabel")
	value.Name = "Value"
	value.BackgroundTransparency = 1
	value.Size = UDim2.fromScale(1, 1)
	value.Font = Enum.Font.FredokaOne
	value.TextScaled = true
	value.TextColor3 = Color3.new(1, 1, 1)
	value.TextStrokeTransparency = 0.3
	value.ZIndex = 2
	value.Parent = bar

	setFloor(model, floor, rarity.rank)
	PlotService.refreshHp(model)
	model.Parent = plot.model.Creatures
	return model
end

-- Updates the base. Important: do not recreate brainrots that did not change,
-- otherwise a thief who just held "Steal" would lose the button.
function PlotService.render(player)
	local plot = plotOf[player]
	local data = DataService.get(player)
	if not plot or not data then
		return
	end
	local passes = MonetizationService.passes(player)
	local floors = Formulas.floors(data, passes)
	updateBuilding(plot, floors, passes)

	-- The strongest brainrots stand on top (income is higher there and they are harder to steal).
	local places, lower, upper = Formulas.layout(data.creatures, floors)

	-- Pedestals: recreated only when their number changes.
	local padsFolder = plot.model.Pads
	local padsKey = lower .. ":" .. upper
	if padsFolder:GetAttribute("Layout") ~= padsKey then
		padsFolder:SetAttribute("Layout", padsKey)
		padsFolder:ClearAllChildren()
		local pads = {}
		for pad = 1, lower do
			table.insert(pads, pad)
		end
		for pad = Formulas.FLOOR_SLOTS + 1, Formulas.FLOOR_SLOTS + upper do
			table.insert(pads, pad)
		end
		for _, pad in ipairs(pads) do
			local onTop = pad > Formulas.FLOOR_SLOTS
			part({
				Name = "Pad",
				Size = Vector3.new(7, 0.6, 7),
				CFrame = padCFrame(plot, pad) * CFrame.new(0, 0.3, 0),
				Color = onTop and Color3.fromRGB(200, 160, 40) or Color3.fromRGB(90, 90, 120),
				Material = Enum.Material.SmoothPlastic,
				Parent = padsFolder,
			})
		end
	end

	local existing = {}
	for _, model in ipairs(plot.model.Creatures:GetChildren()) do
		local uid = model:GetAttribute("Uid")
		if uid then
			existing[uid] = model
		else
			model:Destroy()
		end
	end

	for _, place in ipairs(places) do
		local entry = place.entry
		local creature = Creatures.get(entry.id)
		if creature and place.pad then
			local standCFrame = padCFrame(plot, place.pad) * CFrame.new(0, 0.6, 0)
			local model = existing[entry.uid]
			existing[entry.uid] = nil
			-- The skin changed: the model must be rebuilt.
			if model and model:GetAttribute("Skin") ~= entry.skin then
				model:Destroy()
				model = nil
			end
			if model then
				if model:GetAttribute("BaseCFrame") ~= standCFrame then
					model:SetAttribute("BaseCFrame", standCFrame)
					model:PivotTo(standCFrame)
				end
				local rarity = Rarities.get(creature.rarity)
				-- Moved to another floor: it has different hearts there.
				if model:GetAttribute("Floor") ~= place.floor then
					setFloor(model, place.floor, rarity.rank)
					PlotService.refreshHp(model)
				end
				local gui = model.PrimaryPart and model.PrimaryPart:FindFirstChild("InfoGui")
				if gui then
					-- labelText returns a message (table), not a string: S.apply translates it for each client.
						S.apply(gui.Label, "Text", labelText(entry, creature, rarity, Mutations.get(entry.mut), data, passes, place.floor))
				end
			else
				buildCreature(plot, entry, standCFrame, data, passes, place.floor)
			end
		end
	end

	-- Anyone no longer in the data (sold, fused, stolen) is removed.
	for _, model in pairs(existing) do
		model:Destroy()
	end
end

function PlotService.getPlot(player)
	return plotOf[player]
end

function PlotService.ownerOfModel(model)
	for _, plot in ipairs(plots) do
		if plot.model == model then
			return plot.owner, plot
		end
	end
	return nil
end

-- Whether a point is inside the plot (with a small margin at the edges).
function PlotService.isInside(plot, position, margin)
	local localPos = plot.cframe:PointToObjectSpace(position)
	local half = PLOT_SIZE / 2 + (margin or 0)
	return math.abs(localPos.X) <= half and math.abs(localPos.Z) <= half and localPos.Y < 40
end

-- Whether a point stands on anyone's (or a free) base.
function PlotService.isOnAnyPlot(position, margin)
	for _, plot in ipairs(plots) do
		if PlotService.isInside(plot, position, margin) then
			return true
		end
	end
	return false
end

-- A point right outside the plot fence where we push strangers.
function PlotService.outsideCFrame(plot, position)
	local localPos = plot.cframe:PointToObjectSpace(position)
	local half = PLOT_SIZE / 2 + 6
	local x, z = localPos.X, localPos.Z
	if math.abs(x) > math.abs(z) then
		x = math.sign(x) * half
	else
		z = (z == 0 and 1 or math.sign(z)) * half
	end
	return plot.cframe * CFrame.new(x, 4, z)
end

function PlotService.setLockVisual(plot, locked, secondsLeft)
	for _, wall in ipairs(plot.model.Barrier:GetChildren()) do
		wall.Transparency = locked and 0.4 or 1
	end
	local label = plot.model.LockButton.LockGui.Label
	if locked then
		S.apply(label, "Text", S.m("plot.locked_seconds", { seconds = math.ceil(secondsLeft) }))
		label.TextColor3 = Color3.fromRGB(255, 120, 120)
	else
		S.apply(label, "Text", S.m("plot.lock"))
		label.TextColor3 = Color3.new(1, 1, 1)
	end
end

local function claimPlot(player)
	for _, plot in ipairs(plots) do
		if not plot.owner then
			plot.owner = player
			plotOf[player] = plot
			local gui = plot.model.OwnerSign.OwnerGui
			S.apply(gui.Label, "Text", S.m("plot.owner_base", { name = player.DisplayName }))
			gui.Label.TextColor3 = Color3.fromRGB(255, 230, 0)
			plot.model:SetAttribute("OwnerUserId", player.UserId)
			return plot
		end
	end
	return nil
end

local function releasePlot(player)
	local plot = plotOf[player]
	if not plot then
		return
	end
	plot.owner = nil
	plotOf[player] = nil
	plot.model.Creatures:ClearAllChildren()
	plot.model.Pads:ClearAllChildren()
	plot.model.Pads:SetAttribute("Layout", nil)
	plot.model.Building:ClearAllChildren()
	plot.builtFloors = nil
	S.apply(plot.model.BuildSign.BuildGui.Label, "Text", "")
	plot.model:SetAttribute("CanBuild", nil)
	plot.model:SetAttribute("OwnerUserId", nil)
	plot.model:SetAttribute("LockedUntil", nil)
	plot.model:SetAttribute("LockKind", nil)
	plot.model:SetAttribute("LockReadyAt", nil)
	PlotService.setLockVisual(plot, false, 0)
	local gui = plot.model.OwnerSign.OwnerGui
	S.apply(gui.Label, "Text", S.m("plot.free_base"))
	gui.Label.TextColor3 = Color3.fromRGB(200, 200, 200)
end

local function teleportHome(player, character)
	local plot = plotOf[player]
	if not plot then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if not root then
		return
	end
	-- Roblox puts the character on the spawn point AFTER CharacterAdded and overrides the
	-- teleport. We wait until the character appears in the world and only then move them home.
	if not character:IsDescendantOf(workspace) then
		character.AncestryChanged:Wait()
	end
	task.wait(0.2)
	if character.Parent and plotOf[player] == plot then
		local target = plot.cframe * CFrame.new(0, 5, PLOT_SIZE / 2 - 8)
		MoveGuardService.teleported(player, target.Position)
		character:PivotTo(target)
	end
end

function PlotService.init()
	buildWorld()

	local function onPlayer(player)
		claimPlot(player)
		PlotService.render(player)
		player.CharacterAdded:Connect(function(character)
			teleportHome(player, character)
		end)
		if player.Character then
			task.spawn(teleportHome, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(releasePlot)

	DataService.Loaded.Event:Connect(PlotService.render)
	FactoryService.CreaturesChanged.Event:Connect(PlotService.render)
	ProgressionService.RebirthDone.Event:Connect(PlotService.render)
	ProgressionService.FloorBuilt.Event:Connect(PlotService.render)
	MonetizationService.PassesChanged.Event:Connect(PlotService.render)

	-- Build sign: the owner buys the next floor.
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt.Name == "BuildPrompt" then
			local plotModel = prompt:FindFirstAncestorWhichIsA("Model")
			if plotModel and PlotService.ownerOfModel(plotModel) == player then
				ProgressionService.buyFloor(player)
			end
		end
	end)

	-- We redraw every few seconds: slot purchases, VIP and so on.
	task.spawn(function()
		local lastKey = {}
		while true do
			task.wait(3)
			for player in pairs(plotOf) do
				local data = DataService.get(player)
				if data then
					local passes = MonetizationService.passes(player)
					local floors = Formulas.floors(data, passes)
					local key = table.concat({
						Formulas.slots(data, passes),
						Formulas.incomeMultiplier(data, passes, EventService.mods()),
						tostring(Formulas.floorCost(floors, passes)),
					}, ":")
					if lastKey[player] ~= key then
						lastKey[player] = key
						PlotService.render(player)
					end
				end
			end
			for player in pairs(lastKey) do
				if not plotOf[player] then
					lastKey[player] = nil
				end
			end
		end
	end)
end

return PlotService
