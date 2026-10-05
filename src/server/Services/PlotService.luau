-- Базы игроков: участок, машина-фабрика и брейнроты, стоящие на постаментах.
-- Пока всё сделано из простых деталей — позже заменим на нормальные модели и скины.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local Formulas = require(Shared.Util.Formulas)
local Format = require(Shared.Util.Format)

local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local FactoryService = require(script.Parent.FactoryService)
local ProgressionService = require(script.Parent.ProgressionService)

local PlotService = {}

local PLOT_COUNT = 8
local PLOT_SIZE = 90
local RING_RADIUS = 150
local COLUMNS = 8
local SPACING = 9

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

function PlotService.render(player)
	local plot = plotOf[player]
	local data = DataService.get(player)
	if not plot or not data then
		return
	end
	local folder = plot.model.Creatures
	folder:ClearAllChildren()

	local passes = MonetizationService.passes(player)
	local slots = Formulas.slots(data, passes)

	-- Сильнейшие брейнроты стоят в первом ряду.
	local sorted = table.clone(data.creatures)
	table.sort(sorted, function(a, b)
		return Formulas.creatureBaseIncome(a) > Formulas.creatureBaseIncome(b)
	end)

	for index = 1, slots do
		local base = slotCFrame(plot, index)
		part({
			Name = "Pad",
			Size = Vector3.new(7, 0.6, 7),
			CFrame = base * CFrame.new(0, 0.3, 0),
			Color = Color3.fromRGB(90, 90, 120),
			Material = Enum.Material.SmoothPlastic,
			Parent = folder,
		})

		local entry = sorted[index]
		local creature = entry and Creatures.get(entry.id)
		if creature then
			local rarity = Rarities.get(creature.rarity)
			local mutation = Mutations.get(entry.mut)
			local size = creature.size
			local body = part({
				Name = "Creature",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(size, size, size),
				CFrame = base * CFrame.new(0, 0.6 + size / 2 + 0.3, 0),
				Color = mutation.color or creature.color,
				Material = mutation.id == "normal" and Enum.Material.SmoothPlastic or Enum.Material.Neon,
				CanCollide = false,
				Parent = folder,
			})
			-- Клиент по этому атрибуту делает анимацию «покачивания».
			body:SetAttribute("BaseCFrame", body.CFrame)
			body:SetAttribute("Rainbow", rarity.rainbow == true)

			local nameText = creature.name
			if mutation.id ~= "normal" then
				nameText = mutation.name .. " " .. nameText
			end
			local rarityHex = rarity.color:ToHex()
			billboard(
				body,
				UDim2.fromOffset(170, 66),
				Vector3.new(0, size / 2 + 1.8, 0),
				string.format(
					'%s\n<font color="#%s">%s</font>\n<font color="#78ff78">%s/с</font>',
					nameText,
					rarityHex,
					rarity.name,
					Format.coins(Formulas.creatureIncome(entry, data, passes))
				)
			)
		end
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
	plot.model:SetAttribute("OwnerUserId", nil)
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
					local key = Formulas.slots(data, passes) .. ":" .. Formulas.incomeMultiplier(data, passes)
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
