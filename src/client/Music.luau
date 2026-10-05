-- Фоновая музыка по плейлисту из Config/Music.

local SoundService = game:GetService("SoundService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local MusicConfig = require(Shared.Config.Music)

local Music = {}

local sound = Instance.new("Sound")
sound.Name = "BackgroundMusic"
sound.Volume = MusicConfig.Volume
sound.Parent = SoundService

local enabled = true
local index = 0

local function playNext()
	if #MusicConfig.Playlist == 0 or not enabled then
		return
	end
	index = index % #MusicConfig.Playlist + 1
	sound.SoundId = MusicConfig.Playlist[index]
	sound:Play()
end

sound.Ended:Connect(playNext)

function Music.setEnabled(value)
	if value == enabled then
		return
	end
	enabled = value
	if enabled then
		if sound.SoundId == "" then
			playNext()
		else
			sound:Resume()
		end
	else
		sound:Pause()
	end
end

function Music.start()
	playNext()
end

return Music
