-- 3D-превью брейнрота внутри интерфейса (ViewportFrame).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CreatureModel = require(Shared.Util.CreatureModel)

local Viewport = {}

-- Создаёт ViewportFrame с моделью. silhouette = true — чёрный силуэт (ещё не открыт).
function Viewport.creature(props, creatureId, mutationId, silhouette, skinId)
	local frame = Instance.new("ViewportFrame")
	frame.BackgroundTransparency = 1
	frame.Ambient = Color3.fromRGB(180, 180, 180)
	frame.LightColor = Color3.fromRGB(255, 255, 255)
	frame.LightDirection = Vector3.new(-1, -1, -1)
	for key, value in pairs(props) do
		if key ~= "Parent" then
			frame[key] = value
		end
	end

	local model = CreatureModel.build(creatureId, mutationId or "normal", CFrame.new(), skinId)
	if silhouette then
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Color = Color3.new(0, 0, 0)
				part.Material = Enum.Material.SmoothPlastic
			end
		end
		frame.Ambient = Color3.new(0, 0, 0)
		frame.LightColor = Color3.new(0, 0, 0)
	end
	model.Parent = frame

	local extents = model:GetExtentsSize()
	local center = model:GetBoundingBox().Position
	local distance = math.max(extents.X, extents.Y, extents.Z) * 1.6 + 1
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(center + Vector3.new(distance * 0.35, distance * 0.25, distance), center)
	camera.Parent = frame
	frame.CurrentCamera = camera

	frame.Parent = props.Parent
	return frame
end

return Viewport
