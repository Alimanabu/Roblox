-- Дискотека во время «Минуты 67»: диско-шар над площадью, лазеры, переливы света.
-- Всё только на клиенте (видно всем, потому что у всех одно и то же время ивента).

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local DiscoFx = {}

local active = false
local parts = {}
local connection
local tint

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
	part.Parent = workspace
	table.insert(parts, part)
	return part
end

local function start()
	local center = Vector3.new(0, 45, 0)
	local ball = neon({
		Name = "DiscoBall",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 12,
		Position = center,
		Material = Enum.Material.Glass,
		Reflectance = 0.8,
		Color = Color3.fromRGB(220, 220, 255),
	})
	local light = Instance.new("PointLight")
	light.Range = 60
	light.Brightness = 4
	light.Parent = ball

	local lasers = {}
	for i = 1, 8 do
		lasers[i] = neon({ Name = "Laser", Size = Vector3.new(0.6, 0.6, 140), Transparency = 0.3 })
	end

	tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "DiscoTint"
	tint.Saturation = 0.3
	tint.Parent = Lighting

	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock()
		ball.CFrame = CFrame.new(center) * CFrame.Angles(0, t * 1.5, 0)
		local hue = (t * 0.25) % 1
		light.Color = Color3.fromHSV(hue, 0.8, 1)
		tint.TintColor = Color3.fromHSV(hue, 0.25, 1)
		for i, laser in ipairs(lasers) do
			local angle = t * 0.9 + i / #lasers * math.pi * 2
			local direction = Vector3.new(math.cos(angle), -0.55 + math.sin(t * 2 + i) * 0.15, math.sin(angle)).Unit
			laser.CFrame = CFrame.lookAt(center + direction * 70, center + direction * 140)
			laser.Color = Color3.fromHSV((hue + i / #lasers) % 1, 1, 1)
		end
	end)
end

local function stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	for _, part in ipairs(parts) do
		part:Destroy()
	end
	parts = {}
	if tint then
		tint:Destroy()
		tint = nil
	end
end

function DiscoFx.isActive()
	return active
end

function DiscoFx.setActive(value)
	if value == active then
		return
	end
	active = value
	if active then
		start()
	else
		stop()
	end
end

return DiscoFx
