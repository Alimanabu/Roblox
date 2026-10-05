-- Проигрывание звуков на клиенте.

local SoundService = game:GetService("SoundService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Sounds = require(Shared.Config.Sounds)

local Sfx = {}

local folder = Instance.new("Folder")
folder.Name = "Sfx"
folder.Parent = SoundService

local cache = {}
local function soundFor(name)
	if cache[name] then
		return cache[name]
	end
	local def = Sounds[name]
	if not def then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = def.id
	sound.Volume = def.volume or 0.6
	sound.PlaybackSpeed = def.pitch or 1
	sound.Parent = folder
	cache[name] = sound
	return sound
end

-- pitch — необязательная поправка высоты (например, выше для редких брейнротов).
function Sfx.play(name, pitch)
	local sound = soundFor(name)
	if not sound then
		return
	end
	local def = Sounds[name]
	local times = def["repeat"] or 1
	task.spawn(function()
		for _ = 1, times do
			local copy = sound:Clone()
			copy.PlaybackSpeed = (def.pitch or 1) * (pitch or 1)
			copy.Parent = folder
			copy:Play()
			copy.Ended:Once(function()
				copy:Destroy()
			end)
			task.wait(def.gap or 0)
		end
	end)
end

return Sfx
