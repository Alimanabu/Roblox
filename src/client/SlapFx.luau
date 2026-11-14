-- Slapper sounds in 3D: the server tells every client who swung and whether it connected, and the sound
-- plays on that character (louder near, fading with distance, so the hitter, the target and everyone
-- around hear it). The swing animation itself is played by the server (StealService.playSwing).

local ContentProvider = game:GetService("ContentProvider")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Sounds = require(Shared.Config.Sounds)
local Sfx = require(script.Parent.Sfx)

local SlapFx = {}

SlapFx.HIT_DELAY = 0.12 -- the slap lands a moment after the swing starts
SlapFx.ROLLOFF_MIN = 12 -- full volume up to here (studs)
SlapFx.ROLLOFF_MAX = 90 -- silent from here
SlapFx.PITCH_JITTER = 0.08 -- every slap sounds a little different

local rng = Random.new()

-- One sound on the character's root part. def is an entry of Config/Sounds, id overrides its id.
local function playOn(root, def, id, delay)
	task.delay(delay, function()
		if not root.Parent or not Sfx.enabled then
			return
		end
		local sound = Instance.new("Sound")
		sound.SoundId = id or def.id
		sound.Volume = def.volume or 1
		sound.PlaybackSpeed = (def.pitch or 1) * (1 + rng:NextNumber(-SlapFx.PITCH_JITTER, SlapFx.PITCH_JITTER))
		sound.RollOffMode = Enum.RollOffMode.LinearSquare
		sound.RollOffMinDistance = SlapFx.ROLLOFF_MIN
		sound.RollOffMaxDistance = SlapFx.ROLLOFF_MAX
		sound.Parent = root
		sound:Play()
		sound.Ended:Once(function()
			sound:Destroy()
		end)
		-- If a sound fails to load, Ended never comes, so we remove it ourselves.
		task.delay(6, function()
			if sound.Parent then
				sound:Destroy()
			end
		end)
	end)
end

-- A hit: the slap (one of two takes) with a thud under it. A miss: only the whoosh.
function SlapFx.play(character, hit)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	if hit then
		local take = Sounds.slapHit
		playOn(root, take, if rng:NextInteger(1, 2) == 1 then take.id else take.alt, SlapFx.HIT_DELAY)
		playOn(root, Sounds.slapThud, nil, SlapFx.HIT_DELAY)
	else
		playOn(root, Sounds.slapMiss, nil, 0)
	end
end

function SlapFx.init()
	-- Load the sounds ahead of time, otherwise the first slap would play late.
	task.spawn(function()
		local list = {}
		for _, name in ipairs({ "slapHit", "slapThud", "slapMiss" }) do
			local def = Sounds[name]
			for _, id in ipairs({ def.id, def.alt }) do
				local sound = Instance.new("Sound")
				sound.SoundId = id
				table.insert(list, sound)
			end
		end
		pcall(function()
			ContentProvider:PreloadAsync(list)
		end)
		for _, sound in ipairs(list) do
			sound:Destroy()
		end
	end)

	Remotes.SlapFx.OnClientEvent:Connect(function(who, hit)
		-- The player may have left by the time the event arrives (the remote then carries nil).
		if who then
			SlapFx.play(who.Character, hit == true)
		end
	end)
end

return SlapFx
