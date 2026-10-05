-- Базы игроков: участок, машина-фабрика и брейнроты, стоящие на постаментах.
-- Пока всё сделано из простых деталей — позже заменим на нормальные модели и скины.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local Formulas = require(Shared.Util.Formulas)
local Format = require(Shared.Util.Format)
local CreatureModel = require(Shared.Util.CreatureModel)

local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local FactoryService = require(script.Parent.FactoryService)
local ProgressionService = require(script.Parent.ProgressionService)
local EventService = require(script.Parent.EventService)

local PlotService = {}

local PLOT_COUNT = 8
local PLOT_SIZE = 90
local RING_RADIUS = 150
local COLUMNS = 8
local SPACING = 9
local MAX_PADS = 48 -- 6 рядов по 8

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
	label.Text = text
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

	-- Центр: площадь со спавном и большой табличкой.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "CenterSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(0, 0.5, 0)
	spawn.Color = Color3.fromRGB(255, 230, 0)
	spawn.Material = Enum.Material.Neon
	spawn.Parent = workspace

	local sign = part({
		Name = "TitleSign",
		Size = Vector3.new(1, 1, 1),
		Position = Vector3.new(0, 18, 0),
		Transparency = 1,
		CanCollide = false,
		Parent = workspace,
	})
	billboard(sign, UDim2.fromOffset(600, 150), Vector3.zero, "🧠 BRAINROT FACTORY 🤌", Color3.fromRGB(255, 230, 0))

	for i = 1, PLOT_COUNT do
		local angle = (i - 1) / PLOT_COUNT * math.pi * 2
		local origin = Vector3.new(math.cos(angle) * RING_RADIUS, 0, math.sin(angle) * RING_RADIUS)
		-- Участок «смотрит» в центр карты.
		local cframe = CFrame.lookAt(origin, Vector3.new(0, 0, 0))

		local model = Instance.new("Model")
		model.Name = "Plot" .. i

		local floor = part({
			Name = "Floor",
			Size = Vector3.new(PLOT_SIZE, 1, PLOT_SIZE),
			CFrame = cframe * CFrame.new(0, 0.5, 0),
			Color = Color3.fromRGB(60, 60, 80),
			Material = Enum.Material.SmoothPlastic,
			Parent = model,
		})
		model.PrimaryPart = floor

		local machine = part({
			Name = "Machine",
			Size = Vector3.new(12, 10, 8),
			CFrame = cframe * CFrame.new(0, 6, -PLOT_SIZE / 2 + 10),
			Color = Color3.fromRGB(255, 80, 160),
			Material = Enum.Material.Neon,
			Parent = model,
		})
		billboard(machine, UDim2.fromOffset(240, 60), Vector3.new(0, 8, 0), "🏭 МАШИНА", Color3.new(1, 1, 1))

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "FactoryPrompt"
		prompt.ActionText = "Открыть фабрику"
		prompt.ObjectText = "Машина брейнрота"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.Parent = machine

		local ownerSign = part({
			Name = "OwnerSign",
			Size = Vector3.new(1, 1, 1),
			CFrame = cframe * CFrame.new(0, 22, -PLOT_SIZE / 2 + 10),
			Transparency = 1,
			CanCollide = false,
			Parent = model,
		})
		billboard(ownerSign, UDim2.fromOffset(400, 80), Vector3.zero, "Свободная база", Color3.fromRGB(200, 200, 200)).Name =
			"OwnerGui"

		-- Кнопка замка: закрывает базу от воров.
		local lockButton = part({
			Name = "LockButton",
			Size = Vector3.new(6, 1, 6),
			CFrame = cframe * CFrame.new(PLOT_SIZE / 2 - 8, 1, PLOT_SIZE / 2 - 8),
			Color = Color3.fromRGB(80, 200, 255),
			Material = Enum.Material.Neon,
			Parent = model,
		})
		billboard(lockButton, UDim2.fromOffset(200, 50), Vector3.new(0, 4, 0), "🔓 Замок", Color3.new(1, 1, 1)).Name = "LockGui"
		local lockPrompt = Instance.new("ProximityPrompt")
		lockPrompt.Name = "LockPrompt"
		lockPrompt.ActionText = "Закрыть базу"
		lockPrompt.ObjectText = "Замок"
		lockPrompt.HoldDuration = 0
		lockPrompt.MaxActivationDistance = 10
		lockPrompt.RequiresLineOfSight = false
		lockPrompt.Parent = lockButton

		-- Лазерный забор: виден, когда база закрыта.
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

		local padsFolder = Instance.new("Folder")
		padsFolder.Name = "Pads"
		padsFolder.Parent = model

		local creaturesFolder = Instance.new("Folder")
		creaturesFolder.Name = "Creatures"
		creaturesFolder.Parent = model

		model.Parent = plotsFolder
		table.insert(plots, { model = model, owner = nil, cframe = cframe })
	end
end

local function slotCFrame(plot, index)
	local column = (index - 1) % COLUMNS
	local row = math.floor((index - 1) / COLUMNS)
	local x = (column - (COLUMNS - 1) / 2) * SPACING
	local z = -PLOT_SIZE / 2 + 26 + row * SPACING
	return plot.cframe * CFrame.new(x, 1, z)
end

local function labelText(entry, creature, rarity, mutation, data, passes)
	local nameText = creature.name
	if mutation.id ~= "normal" then
		nameText = mutation.name .. " " .. nameText
	end
	return string.format(
		'%s\n<font color="#%s">%s</font>\n<font color="#78ff78">%s/с</font>',
		nameText,
		rarity.color:ToHex(),
		rarity.name,
		Format.coins(Formulas.creatureIncome(entry, data, passes, EventService.mods()))
	)
end

local function buildCreature(plot, entry, standCFrame, data, passes)
	local creature = Creatures.get(entry.id)
	local rarity = Rarities.get(creature.rarity)
	local mutation = Mutations.get(entry.mut)

	local model, body = CreatureModel.build(entry.id, entry.mut, standCFrame, entry.skin)
	model.Name = "Creature"
	model:SetAttribute("Uid", entry.uid)
	-- Клиент по этому атрибуту делает анимацию «покачивания».
	model:SetAttribute("BaseCFrame", standCFrame)
	local size = model:GetAttribute("Height")

	-- Чужие игроки могут украсть брейнрота. Чем реже — тем дольше красть.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealPrompt"
	prompt.ActionText = "Украсть"
	prompt.ObjectText = creature.name
	prompt.HoldDuration = 0.8 + rarity.rank * 0.4
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt:SetAttribute("Uid", entry.uid)
	prompt.Parent = body

	billboard(body, UDim2.fromOffset(170, 66), Vector3.new(0, size / 2 + 2, 0), labelText(entry, creature, rarity, mutation, data, passes)).Name =
		"InfoGui"
	model.Parent = plot.model.Creatures
	return model
end

-- Обновляет базу. Важно: не пересоздаём брейнротов, которые не изменились —
-- иначе у вора, который как раз зажал «Украсть», пропала бы кнопка.
function PlotService.render(player)
	local plot = plotOf[player]
	local data = DataService.get(player)
	if not plot or not data then
		return
	end
	local passes = MonetizationService.passes(player)
	local slots = Formulas.slots(data, passes)

	-- Сильнейшие брейнроты стоят в первом ряду.
	local sorted = table.clone(data.creatures)
	table.sort(sorted, function(a, b)
		local ia, ib = Formulas.creatureBaseIncome(a), Formulas.creatureBaseIncome(b)
		if ia == ib then
			return a.uid < b.uid
		end
		return ia > ib
	end)

	-- Постаменты: пересоздаём только когда меняется их количество.
	-- Мест может быть меньше, чем брейнротов (например, вернули после неудачной кражи).
	local pads = math.min(math.max(slots, #sorted), MAX_PADS)
	local padsFolder = plot.model.Pads
	if #padsFolder:GetChildren() ~= pads then
		padsFolder:ClearAllChildren()
		for index = 1, pads do
			part({
				Name = "Pad",
				Size = Vector3.new(7, 0.6, 7),
				CFrame = slotCFrame(plot, index) * CFrame.new(0, 0.3, 0),
				Color = Color3.fromRGB(90, 90, 120),
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

	for index = 1, pads do
		local entry = sorted[index]
		local creature = entry and Creatures.get(entry.id)
		if creature then
			local standCFrame = slotCFrame(plot, index) * CFrame.new(0, 0.6, 0)
			local model = existing[entry.uid]
			existing[entry.uid] = nil
			-- Сменили скин — модель надо пересобрать.
			if model and model:GetAttribute("Skin") ~= entry.skin then
				model:Destroy()
				model = nil
			end
			if model then
				if model:GetAttribute("BaseCFrame") ~= standCFrame then
					model:SetAttribute("BaseCFrame", standCFrame)
					model:PivotTo(standCFrame)
				end
				local gui = model.PrimaryPart and model.PrimaryPart:FindFirstChild("InfoGui")
				if gui then
					gui.Label.Text = labelText(entry, creature, Rarities.get(creature.rarity), Mutations.get(entry.mut), data, passes)
				end
			else
				buildCreature(plot, entry, standCFrame, data, passes)
			end
		end
	end

	-- Кого больше нет в данных (продали, скрестили, украли) — убираем.
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

-- Находится ли точка внутри участка (с небольшим запасом по краям).
function PlotService.isInside(plot, position, margin)
	local localPos = plot.cframe:PointToObjectSpace(position)
	local half = PLOT_SIZE / 2 + (margin or 0)
	return math.abs(localPos.X) <= half and math.abs(localPos.Z) <= half and localPos.Y < 40
end

-- Точка сразу за забором участка, куда выталкиваем чужаков.
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
		label.Text = string.format("🔒 %d с", math.ceil(secondsLeft))
		label.TextColor3 = Color3.fromRGB(255, 120, 120)
	else
		label.Text = "🔓 Замок"
		label.TextColor3 = Color3.new(1, 1, 1)
	end
end

local function claimPlot(player)
	for _, plot in ipairs(plots) do
		if not plot.owner then
			plot.owner = player
			plotOf[player] = plot
			local gui = plot.model.OwnerSign.OwnerGui
			gui.Label.Text = "База " .. player.DisplayName
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
	plot.model:SetAttribute("OwnerUserId", nil)
	plot.model:SetAttribute("LockedUntil", nil)
	plot.model:SetAttribute("LockKind", nil)
	plot.model:SetAttribute("LockReadyAt", nil)
	PlotService.setLockVisual(plot, false, 0)
	local gui = plot.model.OwnerSign.OwnerGui
	gui.Label.Text = "Свободная база"
	gui.Label.TextColor3 = Color3.fromRGB(200, 200, 200)
end

local function teleportHome(player, character)
	local plot = plotOf[player]
	if not plot then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if root then
		character:PivotTo(plot.cframe * CFrame.new(0, 5, PLOT_SIZE / 2 - 8))
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

	-- Перерисовываем раз в несколько секунд: покупка слотов, VIP и т.п.
	task.spawn(function()
		local lastKey = {}
		while true do
			task.wait(3)
			for player in pairs(plotOf) do
				local data = DataService.get(player)
				if data then
					local passes = MonetizationService.passes(player)
					local key = Formulas.slots(data, passes) .. ":" .. Formulas.incomeMultiplier(data, passes, EventService.mods())
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
