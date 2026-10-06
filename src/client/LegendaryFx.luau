-- Шоу легендарного дропа: столб света над базой (видно со всей карты), молнии,
-- баннер на весь экран у всех, а у счастливчика — облёт камеры и вспышка.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)

local player = Players.LocalPlayer

local LegendaryFx = {}

local SHOW_TIME = 8

local function plotOf(userId)
	local plots = workspace:FindFirstChild("Plots")
	for _, plot in ipairs(plots and plots:GetChildren() or {}) do
		if plot:GetAttribute("OwnerUserId") == userId then
			return plot
		end
	end
	return nil
end

local function effectsFolder()
	local folder = workspace:FindFirstChild("ClientFx")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ClientFx"
		folder.Parent = workspace
	end
	return folder
end

local function neon(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	for key, value in pairs(props) do
		part[key] = value
	end
	part.Parent = effectsFolder()
	return part
end

-- Столб света до неба + кольцо у земли.
local function pillar(position, color)
	local beam = neon({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(500, 10, 10),
		CFrame = CFrame.new(position + Vector3.new(0, 250, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color,
		Transparency = 1,
	})
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 60
	light.Brightness = 5
	light.Parent = beam
	TweenService:Create(beam, TweenInfo.new(0.4), { Transparency = 0.25, Size = Vector3.new(500, 14, 14) }):Play()
	task.delay(SHOW_TIME - 1, function()
		TweenService:Create(beam, TweenInfo.new(1), { Transparency = 1, Size = Vector3.new(500, 2, 2) }):Play()
	end)
	Debris:AddItem(beam, SHOW_TIME + 0.5)

	local ring = neon({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.5, 4, 4),
		CFrame = CFrame.new(position + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color,
		Transparency = 0.2,
	})
	TweenService:Create(ring, TweenInfo.new(1.5, Enum.EasingStyle.Quad), { Size = Vector3.new(0.5, 120, 120), Transparency = 1 }):Play()
	Debris:AddItem(ring, 2)
end

-- Ломаная молния с неба в точку.
local function lightning(target, color)
	local from = target + Vector3.new(math.random(-40, 40), 160, math.random(-40, 40))
	local points = { from }
	for i = 1, 6 do
		local t = i / 7
		local p = from:Lerp(target, t) + Vector3.new(math.random(-8, 8), 0, math.random(-8, 8))
		table.insert(points, p)
	end
	table.insert(points, target)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local bolt = neon({
			Size = Vector3.new(0.8, 0.8, (b - a).Magnitude),
			CFrame = CFrame.lookAt((a + b) / 2, b),
			Color = color:Lerp(Color3.new(1, 1, 1), 0.6),
		})
		Debris:AddItem(bolt, 0.25)
	end
end

local function banner(screenGui, text, color)
	local label = Instance.new("TextLabel")
	label.Name = "LegendaryBanner"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.3)
	label.Size = UDim2.new(0.9, 0, 0, 90)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(900, 90)
	limit.Parent = label
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Text = text
	label.ZIndex = 60
	label.Parent = screenGui
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = label
	TweenService:Create(scale, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.spawn(function()
		local started = os.clock()
		while os.clock() - started < SHOW_TIME - 1 and label.Parent do
			label.TextColor3 = Color3.fromHSV((os.clock() * 0.8) % 1, 0.7, 1):Lerp(color, 0.4)
			task.wait(0.05)
		end
		TweenService:Create(label, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		Debris:AddItem(label, 1)
	end)
end

-- Белая вспышка + облёт камеры вокруг базы (только у того, кто выбил).
local cinematicBusy = false
local function cinematic(screenGui, center)
	if cinematicBusy then
		return
	end
	cinematicBusy = true
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 0
	flash.ZIndex = 59
	flash.Parent = screenGui
	TweenService:Create(flash, TweenInfo.new(1.2), { BackgroundTransparency = 1 }):Play()
	Debris:AddItem(flash, 1.5)

	local camera = workspace.CurrentCamera
	if not camera then
		cinematicBusy = false
		return
	end
	local previousType = camera.CameraType
	camera.CameraType = Enum.CameraType.Scriptable
	local started = os.clock()
	local duration = 4
	local connection
	connection = game:GetService("RunService").RenderStepped:Connect(function()
		local t = (os.clock() - started) / duration
		if t >= 1 then
			connection:Disconnect()
			cinematicBusy = false
			camera.CameraType = previousType == Enum.CameraType.Scriptable and Enum.CameraType.Custom or previousType
			return
		end
		local angle = t * math.pi * 1.5
		local radius = 45 - 20 * t
		local shake = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * (1 - t) * 0.8
		local eye = center + Vector3.new(math.cos(angle) * radius, 18 - 6 * t, math.sin(angle) * radius) + shake
		camera.CFrame = CFrame.lookAt(eye, center + Vector3.new(0, 4, 0))
	end)
end

function LegendaryFx.play(screenGui, info, onSfx)
	local creature = Creatures.get(info.creatureId)
	if not creature then
		return
	end
	local rarity = Rarities.get(creature.rarity)
	local mutation = Mutations.get(info.mut)
	local color = mutation.rank >= 5 and mutation.color or rarity.color
	if rarity.id == "god" and not rarity.rainbow then
		color = rarity.color
	end
	if rarity.rainbow then
		color = rarity.id == "sixseven" and Color3.fromRGB(255, 230, 0) or Color3.fromRGB(255, 120, 255)
	end

	local plot = plotOf(info.userId)
	local center = plot and plot.PrimaryPart and plot.PrimaryPart.Position or Vector3.zero
	pillar(center, color)
	task.spawn(function()
		for _ = 1, 6 do
			lightning(center, color)
			task.wait(0.5 + math.random() * 0.6)
		end
	end)

	local name = creature.name
	if mutation.id ~= "normal" then
		name = mutation.name .. " " .. name
	end
	local headline = rarity.id == "sixseven" and "🤌 SIX... SEVEN!!! 🤌" or "🌟 ЛЕГЕНДАРНЫЙ ДРОП! 🌟"
	banner(screenGui, headline .. "\n" .. info.name .. ": " .. name, color)
	if onSfx then
		onSfx("rare")
	end

	if info.userId == player.UserId then
		cinematic(screenGui, center)
	end
end

return LegendaryFx
