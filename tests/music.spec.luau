-- Плейлист: трек, который не загрузился, не останавливает музыку.

local failures = 0
local checks = 0
local function check(cond, msg)
	checks += 1
	if not cond then
		failures += 1
		print("❌ " .. msg)
	end
end

local Config = shared_require("Config/Music")
local SoundService = game:GetService("SoundService")
local PLAYLIST = Config.Playlist
local TIMEOUT = 15
check(Config.LoadTimeout == TIMEOUT, "таймаут загрузки: " .. tostring(Config.LoadTimeout))
check(#PLAYLIST == 7, "тест рассчитан на 7 треков, в плейлисте " .. #PLAYLIST)

local warnings = {}
warn = function(text)
	table.insert(warnings, text)
end

local function sounds()
	local found = {}
	for _, child in ipairs(SoundService:GetChildren()) do
		if child.Name == "BackgroundMusic" then
			table.insert(found, child)
		end
	end
	return found
end

local function current()
	local found = sounds()
	return found[#found]
end

local function playing()
	local sound = current()
	return sound and sound.SoundId
end

local function expect(track, msg)
	check(playing() == track, msg .. ": играет " .. tostring(playing()) .. ", ожидали " .. tostring(track))
end

-- Свой экземпляр проигрывателя на сценарий: состояние модуля живёт в его файле.
local function scenario(name, playlist, body)
	if body == nil then
		playlist, body = PLAYLIST, playlist
	end
	for _, sound in ipairs(sounds()) do
		sound:Destroy()
	end
	table.clear(warnings)
	Config.Playlist = playlist
	local Music = __defs["client/Music"]()
	local before = failures
	body(Music)
	Music.setEnabled(false)
	World.advance(TIMEOUT + 1)
	Config.Playlist = PLAYLIST
	if failures > before then
		print("   в сценарии: " .. name)
	end
end

scenario("обычный круг: загруженные треки идут по порядку и по кругу", function(Music)
	Music.start()
	for lap = 1, 2 do
		for _, track in ipairs(PLAYLIST) do
			expect(track, "круг " .. lap)
			current().IsLoaded = true
			World.advance(TIMEOUT * 2)
			expect(track, "загруженный трек пропущен")
			current().Ended:Fire()
		end
	end
	check(#warnings == 0, "лишние записи в журнале: " .. #warnings)
end)

scenario("первый трек не загрузился: пропуск, плейлист идёт дальше", function(Music)
	Music.start()
	expect(PLAYLIST[1], "старт")
	World.advance(TIMEOUT - 1)
	expect(PLAYLIST[1], "пропустили раньше таймаута")
	World.advance(2)
	expect(PLAYLIST[2], "незагруженный трек не пропущен")
	current().IsLoaded = true
	World.advance(TIMEOUT + 1)
	expect(PLAYLIST[2], "следующий трек загружен, но пропущен")
	current().Ended:Fire()
	expect(PLAYLIST[3], "после загруженного трека плейлист остановился")
	check(#warnings == 1, "записей в журнале: " .. #warnings)
	check(warnings[1] ~= nil and string.find(warnings[1], PLAYLIST[1], 1, true) ~= nil, "в журнале нет адреса трека")
	check(#sounds() == 1, "прошлый Sound не убран: " .. #sounds())
end)

scenario("плохой трек посреди плейлиста, таймер прошлого трека его не трогает", function(Music)
	Music.start()
	current().IsLoaded = true
	World.advance(TIMEOUT - 5)
	current().Ended:Fire() -- трек короче таймаута: его таймер ещё идёт
	expect(PLAYLIST[2], "после первого трека")
	World.advance(6)
	expect(PLAYLIST[2], "таймер прошлого трека пропустил новый")
	World.advance(TIMEOUT - 5)
	expect(PLAYLIST[3], "плохой трек посреди плейлиста не пропущен")
end)

scenario("трек грузится долго, но укладывается в таймаут", function(Music)
	Music.start()
	World.advance(TIMEOUT - 1)
	current().IsLoaded = true
	World.advance(TIMEOUT * 2)
	expect(PLAYLIST[1], "медленный трек пропущен")
	check(#warnings == 0, "лишние записи в журнале: " .. #warnings)
end)

scenario("не загрузились все 7: тишина без ошибок, запись один раз на трек", function(Music)
	local errors = #World.errors
	Music.start()
	for number, track in ipairs(PLAYLIST) do
		expect(track, "трек " .. number)
		World.advance(TIMEOUT + 1)
	end
	expect(PLAYLIST[#PLAYLIST], "после круга плейлист должен остановиться")
	World.advance(TIMEOUT * 10)
	expect(PLAYLIST[#PLAYLIST], "после круга плейлист пошёл заново")
	check(#warnings == #PLAYLIST, "записей в журнале: " .. #warnings)
	check(#World.errors == errors, "ошибки в потоках: " .. (#World.errors - errors))

	-- Выключил и включил: ещё один круг, журнал не повторяется.
	Music.setEnabled(false)
	Music.setEnabled(true)
	expect(PLAYLIST[1], "повторный круг")
	World.advance((TIMEOUT + 1) * #PLAYLIST)
	expect(PLAYLIST[#PLAYLIST], "повторный круг должен остановиться")
	World.advance(TIMEOUT * 10)
	expect(PLAYLIST[#PLAYLIST], "повторный круг пошёл заново")
	check(#warnings == #PLAYLIST, "запись о треке повторилась: " .. #warnings)
end)

scenario("музыка выключена, пока трек грузится: пропуска нет, при включении играет другой", function(Music)
	Music.start()
	Music.setEnabled(false)
	World.advance(TIMEOUT * 3)
	expect(PLAYLIST[1], "выключенная музыка листает плейлист")
	check(#warnings == 0, "лишние записи в журнале: " .. #warnings)
	Music.setEnabled(true)
	expect(PLAYLIST[2], "включили, а незагруженный трек остался")
end)

scenario("музыка выключена, загруженный трек продолжается с того же места", function(Music)
	Music.start()
	local sound = current()
	sound.IsLoaded = true
	Music.setEnabled(false)
	Music.setEnabled(true)
	check(current() == sound, "загруженный трек начат заново")
end)

scenario("музыка выключена до старта: при включении первый трек", function(Music)
	Music.setEnabled(false)
	Music.start()
	check(playing() == nil, "выключенная музыка заиграла")
	Music.setEnabled(true)
	expect(PLAYLIST[1], "включили до старта")
end)

scenario("плохой трек не копится: круг за кругом хороший играет", { "rbxassetid://1", "rbxassetid://2" }, function(Music)
	Music.start()
	for lap = 1, 3 do
		World.advance(TIMEOUT + 1)
		expect("rbxassetid://2", "круг " .. lap)
		current().IsLoaded = true
		current().Ended:Fire()
		expect("rbxassetid://1", "после хорошего трека, круг " .. lap)
	end
	check(#warnings == 1, "запись о треке повторилась: " .. #warnings)
end)

scenario("единственный трек не загрузился", { "rbxassetid://1" }, function(Music)
	Music.start()
	World.advance(TIMEOUT * 5)
	expect("rbxassetid://1", "единственный трек")
	check(#warnings == 1, "записей в журнале: " .. #warnings)
end)

scenario("пустой плейлист", {}, function(Music)
	local errors = #World.errors
	Music.start()
	World.advance(TIMEOUT * 2)
	check(playing() == nil, "пустой плейлист что-то играет")
	check(#warnings == 0 and #World.errors == errors, "пустой плейлист дал запись или ошибку")
end)

if failures == 0 then
	print("✅ Музыка: пройдено проверок " .. checks)
else
	print("❌ Музыка: провалено проверок " .. failures .. " из " .. checks)
	error("tests failed")
end
