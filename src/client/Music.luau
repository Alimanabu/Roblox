-- Background music from the Config/Music playlist.
-- A track that fails to load never sends Ended, so we wait for loading with a timeout and skip it.

local SoundService = game:GetService("SoundService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local MusicConfig = require(Shared.Config.Music)

local Music = {}

local sound = nil
local enabled = true
local index = 0
local failedInRow = 0 -- how many tracks in a row failed to load
local warned = {} -- which track has already been written to the log

local playNext

local function skipFailed(track)
	if not warned[track] then
		warned[track] = true
		warn("[Music] Track failed to load, skipping: " .. track)
	end
	failedInRow += 1
	-- The whole playlist failed to load: silence, do not loop.
	if failedInRow < #MusicConfig.Playlist then
		playNext()
	end
end

-- Each track gets its own Sound: the previous track's IsLoaded is not mistaken for the new one loading.
playNext = function()
	if #MusicConfig.Playlist == 0 or not enabled then
		return
	end
	index = index % #MusicConfig.Playlist + 1
	local track = MusicConfig.Playlist[index]

	if sound then
		sound:Destroy()
	end
	local current = Instance.new("Sound")
	current.Name = "BackgroundMusic"
	current.Volume = MusicConfig.Volume
	current.SoundId = track
	current.Parent = SoundService
	current.Ended:Connect(function()
		failedInRow = 0
		playNext()
	end)
	sound = current
	current:Play()

	task.delay(MusicConfig.LoadTimeout, function()
		if sound == current and enabled and not current.IsLoaded then
			skipFailed(track)
		end
	end)
end

function Music.setEnabled(value)
	if value == enabled then
		return
	end
	enabled = value
	if enabled then
		if sound and sound.IsLoaded then
			sound:Resume()
		else
			failedInRow = 0
			playNext()
		end
	elseif sound then
		sound:Pause()
	end
end

function Music.start()
	playNext()
end

return Music
