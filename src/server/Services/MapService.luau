-- Оформление карты: площадь, дорожки к базам, деревья, фонари, статуя легенды, свет.
-- Только декор — на игровую логику не влияет. Всё собрано из простых деталей.

local Lighting = game:GetService("Lighting")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CreatureModel = require(Shared.Util.CreatureModel)

local MapService = {}

-- Должно совпадать с раскладкой в PlotService.
local PLOT_COUNT = 8
local RING_RADIUS = 150
local PLOT_SIZE = 90
local PLAZA_RADIUS = 42

local folder

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		p[key] = value
	end
	p.Parent = props.Parent or folder
	return p
end

local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)

local function tree(position, scale)
	scale = scale or 1
	part({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(8 * scale, 2 * scale, 2 * scale),
		CFrame = CFrame.new(position + Vector3.new(0, 4 * scale, 0)) * UPRIGHT,
		Color = Color3.fromRGB(110, 75, 45),
		Material = Enum.Material.Wood,
	})
	for i, offset in ipairs({ Vector3.new(0, 9, 0), Vector3.new(1.5, 7.5, 1), Vector3.new(-1.5, 7.5, -1) }) do
		part({
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (i == 1 and 7 or 5) * scale,
			Position = position + offset * scale,
			Color = Color3.fromRGB(60 + i * 15, 170, 70),
			Material = Enum.Material.Grass,
			CanCollide = false,
		})
	end
end

local function lamp(position)
	part({
		Name = "LampPost",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(10, 0.6, 0.6),
		CFrame = CFrame.new(position + Vector3.new(0, 5, 0)) * UPRIGHT,
		Color = Color3.fromRGB(40, 40, 50),
		Material = Enum.Material.Metal,
	})
	local bulb = part({
		Name = "LampBulb",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.6,
		Position = position + Vector3.new(0, 10.5, 0),
		Color = Color3.fromRGB(255, 230, 150),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(255, 220, 160)
	light.Parent = bulb
end

local function bench(cframe)
	part({ Name = "BenchSeat", Size = Vector3.new(6, 0.5, 2), CFrame = cframe * CFrame.new(0, 1.5, 0), Color = Color3.fromRGB(150, 100, 60), Material = Enum.Material.Wood })
	part({ Name = "BenchBack", Size = Vector3.new(6, 2, 0.4), CFrame = cframe * CFrame.new(0, 2.5, 0.9), Color = Color3.fromRGB(150, 100, 60), Material = Enum.Material.Wood })
	for _, x in ipairs({ -2.5, 2.5 }) do
		part({ Name = "BenchLeg", Size = Vector3.new(0.4, 1.3, 1.6), CFrame = cframe * CFrame.new(x, 0.65, 0), Color = Color3.fromRGB(40, 40, 50), Material = Enum.Material.Metal })
	end
end

local function statue()
	-- Постамент + огромный SIX SEVEN «из золота».
	local base = CFrame.new(0, 0, -30)
	part({
		Name = "StatueBase",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(4, 14, 14),
		CFrame = base * CFrame.new(0, 2, 0) * UPRIGHT,
		Color = Color3.fromRGB(90, 85, 110),
		Material = Enum.Material.Marble,
	})
	local model = CreatureModel.build("sei_sette", "sixseven", base * CFrame.new(0, 4, 0) * CFrame.Angles(0, math.pi, 0))
	model.Name = "LegendStatue"
	model:ScaleTo(2.2)
	model:PivotTo(base * CFrame.new(0, 4, 0) * CFrame.Angles(0, math.pi, 0))
	for _, piece in ipairs(model:GetDescendants()) do
		if piece:IsA("BasePart") then
			piece.CanCollide = true
		end
	end
	model.Parent = folder

	local sign = part({ Name = "StatueSign", Size = Vector3.new(1, 1, 1), Position = base.Position + Vector3.new(0, 26, 0), Transparency = 1, CanCollide = false })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(320, 60)
	gui.MaxDistance = 150
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 230, 0)
	label.TextStrokeTransparency = 0.2
	label.Text = "🤌 Легенда: SIX SEVEN 🤌"
	label.Parent = gui
end

local function lighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.2
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 170)
	Lighting.EnvironmentDiffuseScale = 0.5
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.25
		atmosphere.Haze = 1
		atmosphere.Color = Color3.fromRGB(200, 210, 255)
		atmosphere.Decay = Color3.fromRGB(255, 180, 220)
		atmosphere.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("BloomEffect") then
		local bloom = Instance.new("BloomEffect")
		bloom.Intensity = 0.4
		bloom.Size = 20
		bloom.Threshold = 1.5
		bloom.Parent = Lighting
	end
end

function MapService.init()
	folder = Instance.new("Folder")
	folder.Name = "Map"
	folder.Parent = workspace

	lighting()

	-- Площадь.
	part({
		Name = "Plaza",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, PLAZA_RADIUS * 2, PLAZA_RADIUS * 2),
		CFrame = CFrame.new(0, 0.05, 0) * UPRIGHT,
		Color = Color3.fromRGB(190, 185, 200),
		Material = Enum.Material.Slate,
	})

	for i = 1, PLOT_COUNT do
		local angle = (i - 1) / PLOT_COUNT * math.pi * 2
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))

		-- Дорожка от площади к базе.
		local from = dir * (PLAZA_RADIUS - 2)
		local to = dir * (RING_RADIUS - PLOT_SIZE / 2 + 1)
		local middle = (from + to) / 2
		part({
			Name = "Path",
			Size = Vector3.new(10, 0.3, (to - from).Magnitude),
			CFrame = CFrame.lookAt(middle + Vector3.new(0, 0.1, 0), to + Vector3.new(0, 0.1, 0)),
			Color = Color3.fromRGB(215, 190, 140),
			Material = Enum.Material.Sand,
		})

		-- Фонари вдоль дорожки.
		local side = Vector3.new(-dir.Z, 0, dir.X) * 7
		lamp(dir * 70 + side)
		lamp(dir * 70 - side)

		-- Деревья между базами.
		local between = (i - 0.5) / PLOT_COUNT * math.pi * 2
		local betweenDir = Vector3.new(math.cos(between), 0, math.sin(between))
		tree(betweenDir * 100, 1.2)
		tree(betweenDir * 165, 1)
		-- Внешнее кольцо леса.
		for k = 0, 2 do
			local a = (i - 1 + k / 3) / PLOT_COUNT * math.pi * 2
			tree(Vector3.new(math.cos(a), 0, math.sin(a)) * 245, 1.4)
		end

		-- Лавочки по краю площади.
		local benchPos = Vector3.new(math.cos(between), 0, math.sin(between)) * (PLAZA_RADIUS - 5)
		bench(CFrame.lookAt(benchPos, Vector3.zero) * CFrame.Angles(0, math.pi, 0))
	end

	statue()
end

return MapService
