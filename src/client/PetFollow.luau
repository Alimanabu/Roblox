-- Питомцы игроков: брейнрот бегает за хозяином, подпрыгивает и смотрит туда же.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CreatureModel = require(Shared.Util.CreatureModel)

local PetFollow = {}

local PET_HEIGHT = 3.2 -- примерный рост питомца в студах
local pets = {} -- [player] = { key, model, cframe }

local folder = Instance.new("Folder")
folder.Name = "Pets"
folder.Parent = workspace

local function build(key)
	local id, mut, skin = string.match(key, "^([^|]+)|([^|]+)|(.*)$")
	if not id then
		return nil
	end
	local ok, model = pcall(CreatureModel.build, id, mut, CFrame.new(), skin ~= "" and skin or nil)
	if not ok then
		return nil
	end
	local height = model:GetAttribute("Height") or 4
	model:ScaleTo(math.clamp(PET_HEIGHT / height, 0.2, 1))
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
		end
	end
	model.Parent = folder
	return model
end

local function remove(player)
	local pet = pets[player]
	if pet then
		pet.model:Destroy()
		pets[player] = nil
	end
end

function PetFollow.start()
	Players.PlayerRemoving:Connect(remove)
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		for _, player in ipairs(Players:GetPlayers()) do
			local key = player:GetAttribute("Pet")
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local pet = pets[player]
			if not key or not root then
				remove(player)
			else
				if not pet or pet.key ~= key then
					remove(player)
					local model = build(key)
					if model then
						pet = { key = key, model = model, cframe = root.CFrame }
						pets[player] = pet
					end
				end
				if pet then
					-- Справа-сзади от хозяина, у земли, с подпрыгиванием.
					local target = root.CFrame * CFrame.new(3.5, -2.6, 3.5)
					local alpha = 1 - math.exp(-dt * 8)
					pet.cframe = pet.cframe:Lerp(target, alpha)
					local hop = math.abs(math.sin(t * 6 + player.UserId % 10)) * 0.6
					pet.model:PivotTo(pet.cframe * CFrame.new(0, hop, 0))
				end
			end
		end
	end)
end

return PetFollow
