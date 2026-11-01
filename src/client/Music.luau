-- Фоновая музыка по плейлисту из Config/Music.
-- Незагруженный трек не присылает Ended, поэтому загрузку ждём с таймаутом и пропускаем его.

local SoundService = game:GetService("SoundService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local MusicConfig = require(Shared.Config.Music)

local Music = {}

local sound = nil
local enabled = true
local index = 0
local failedInRow = 0 -- сколько треков подряд не загрузилось
local warned = {} -- о каком треке уже написали в журнал

local playNext

local function skipFailed(track)
	if not warned[track] then
		warned[track] = true
		warn("[Music] Трек не загрузился, пропускаем: " .. track)
	end
	failedInRow += 1
	-- Не загрузился весь плейлист: тишина, по кругу не ходим.
	if failedInRow < #MusicConfig.Playlist then
		playNext()
	end
end

-- Каждому треку свой Sound: IsLoaded прошлого трека не примем за загрузку нового.
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
