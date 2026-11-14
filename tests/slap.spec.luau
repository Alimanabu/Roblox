-- Шлепалка (14.11, отзыв друзей: нет замаха и нет звука у бьющего). Настоящие сервер и клиент на заглушке мира:
-- 1. На каждое нажатие сервер проигрывает на Animator бьющего анимацию замаха (R15 и R6 — свои Roblox-ассеты).
-- 2. Каждый клиент играет звук в 3D на персонаже бьющего: шлепок при попадании, свист при промахе.
-- 3. Попадание по игроку, вору, брейнроту и боссу — один и тот же шлепок. Кулдаун, дальность, силу удара не трогали.
-- Локальный игрок заглушки — owner (добавлен первым): он слышит и свои удары, и удары вора.

local failures = 0
local scenarios = 0
local function check(cond, msg)
	if not cond then
		failures += 1
		print("❌ " .. msg)
	end
end

local owner = World.addPlayer(3001, "Owner")
local thief = World.addPlayer(3002, "Thief")
local S = shared_require("Strings")
World.startServer()
World.startClient()
World.advance(100) -- защита при входе кончилась

local FactoryService = shared_require("Services/FactoryService")
local PlotService = shared_require("Services/PlotService")
local StealService = shared_require("Services/StealService")
local BossService = shared_require("Services/BossService")
local MoveGuard = shared_require("Services/MoveGuardService")
local Sounds = shared_require("Config/Sounds")
local SlapFx = shared_require("client/SlapFx")
local Sfx = shared_require("client/Sfx")

local slapperName = S.t("steal.slapper")
local slappers = {
	[owner] = owner.Backpack:FindFirstChild(slapperName),
	[thief] = thief.Backpack:FindFirstChild(slapperName),
}
check(slappers[owner] and slappers[thief], "у обоих игроков есть шлепалка")
local ownerPlot = PlotService.getPlot(owner)

local function rootOf(player)
	return player.Character.HumanoidRootPart
end

-- Animator на заглушке: помнит, что загружали и сколько раз запускали.
local function addAnimator(player)
	local humanoid = player.Character.Humanoid
	local animator = Instance.new("Animator")
	local log = { loads = {}, plays = 0 }
	animator.LoadAnimation = function(_, animation)
		table.insert(log.loads, animation.AnimationId)
		return {
			Play = function()
				log.plays += 1
			end,
		}
	end
	animator.Parent = humanoid
	return log
end
local animThief = addAnimator(thief)
local animOwner = addAnimator(owner)
owner.Character.Humanoid.RigType = Enum.HumanoidRigType.R6

local function place(player, position, lookAt)
	MoveGuard.teleported(player, position)
	rootOf(player).CFrame = CFrame.lookAt(position, lookAt or (position + Vector3.new(0, 0, 1)))
	World.advance(MoveGuard.TELEPORT_GRACE + 4)
end

local FAR_A, FAR_B = Vector3.new(500, 5, 500), Vector3.new(-500, 5, -500)

-- Все звуки на персонаже игрока: список { id, sound }.
local function soundsOn(player)
	local found = {}
	for _, child in ipairs(rootOf(player):GetChildren()) do
		if child.ClassName == "Sound" then
			table.insert(found, child)
		end
	end
	return found
end

local function countWithId(player, id)
	local n = 0
	for _, sound in ipairs(soundsOn(player)) do
		if sound.SoundId == id then
			n += 1
		end
	end
	return n
end

-- Сколько звуков с таким id появилось на персонаже с прошлого раза; прочитанные убираем,
-- иначе через 6 с клиент сам удалит старые и счёт собьётся.
local function take(player, ...)
	local ids, n = { ... }, 0
	for _, sound in ipairs(soundsOn(player)) do
		if table.find(ids, sound.SoundId) then
			n += 1
		end
		sound:Destroy()
	end
	return n
end

local function slapEvents(hitter)
	local out = {}
	for _, item in ipairs(World.sent) do
		if item.remote == "SlapFx" and item.player == owner and item.args[1] == hitter then
			table.insert(out, item.args[2])
		end
	end
	return out
end

local function press(hitter)
	slappers[hitter].Activated:Fire()
	World.advance(StealService.SLAP_COOLDOWN + 0.1)
end

local function scenario(name, body)
	scenarios += 1
	local before = failures
	local ok, err = pcall(body)
	if not ok then
		failures += 1
		print("❌ " .. name .. ": " .. tostring(err))
	end
	World.advance(30)
	print(string.format("  %s %d. %s", failures == before and "✅" or "❌", scenarios, name))
end

print("— Шлепалка: замах и звук —")

scenario("параметры боя не тронуты", function()
	check(StealService.SLAP_COOLDOWN == 0.8, "кулдаун " .. tostring(StealService.SLAP_COOLDOWN))
	check(StealService.SLAP_RANGE == 9, "дальность " .. tostring(StealService.SLAP_RANGE))
	check(StealService.SLAP_FORCE == 70, "сила " .. tostring(StealService.SLAP_FORCE))
end)

scenario("промах 10 из 10: замах у бьющего, свист у всех, шлепка нет", function()
	place(thief, FAR_A)
	place(owner, FAR_B)
	local plays, misses, hits = animThief.plays, 0, 0
	take(thief, Sounds.slapMiss.id)
	for i = 1, 10 do
		press(thief)
		local missCount = take(thief, Sounds.slapMiss.id)
		check(missCount == 1, "промах " .. i .. ": свистов на персонаже вора " .. missCount)
		misses += missCount
	end
	check(animThief.plays - plays == 10, "замах на 10 нажатий: " .. (animThief.plays - plays))
	check(#animThief.loads == 1 and animThief.loads[1] == StealService.SWING_ANIMATION.R15, "вор R15: анимация " .. tostring(animThief.loads[1]))
	check(misses == 10, "свистов 10, было " .. misses)
	local events = slapEvents(thief)
	check(#events == 10, "событий SlapFx 10, пришло " .. #events)
	for _, hit in ipairs(events) do
		check(hit == false, "промах помечен как попадание")
	end
end)

scenario("попадание по игроку 10 из 10, вор бьёт хозяина (3D на чужом персонаже)", function()
	local plays = animThief.plays
	local base = Vector3.new(500, 5, 500)
	place(thief, base, base + Vector3.new(0, 0, 1))
	place(owner, base + Vector3.new(0, 0, 3))
	local slaps, thuds, whooshes = 0, 0, 0
	local knocks = 0
	take(thief, Sounds.slapMiss.id)
	for _ = 1, 10 do
		press(thief)
		for _, sound in ipairs(soundsOn(thief)) do
			if sound.SoundId == Sounds.slapMiss.id then
				whooshes += 1
			elseif sound.SoundId == Sounds.slapThud.id then
				thuds += 1
			elseif sound.SoundId == Sounds.slapHit.id or sound.SoundId == Sounds.slapHit.alt then
				slaps += 1
			end
		end
		take(thief)
		place(owner, base + Vector3.new(0, 0, 3)) -- хозяина отбросило бы; ставим на место, как после приземления
	end
	check(animThief.plays - plays == 10, "замах 10, было " .. (animThief.plays - plays))
	check(slaps == 10, "шлепков 10, было " .. slaps)
	check(thuds == 10, "глухих ударов 10, было " .. thuds)
	check(whooshes == 0, "свист при попадании: " .. whooshes)
	for _, item in ipairs(World.sent) do
		if item.remote == "Knockback" and item.player == owner then
			knocks += 1
			check(item.args[2] == true, "Knockback от шлепалки без пометки silent: двойной звук у цели")
		end
	end
	check(knocks >= 10, "отбрасывание хозяина не пришло: " .. knocks)
	-- У цели не играет второй, плоский «slap» из обработчика Knockback.
	local plain = game:GetService("SoundService"):FindFirstChild("Sfx")
	check(not (plain and plain:FindFirstChild("slap")), "у цели сыграл плоский звук slap")
end)

scenario("хозяин бьёт сам (локальный игрок слышит себя), R6", function()
	local base = Vector3.new(500, 5, 500)
	place(owner, base, base + Vector3.new(0, 0, 1))
	place(thief, base + Vector3.new(0, 0, 3))
	local plays = animOwner.plays
	local slaps = 0
	take(owner)
	for _ = 1, 10 do
		press(owner)
		slaps += take(owner, Sounds.slapHit.id, Sounds.slapHit.alt)
		place(thief, base + Vector3.new(0, 0, 3))
	end
	check(animOwner.plays - plays == 10, "замах хозяина 10, было " .. (animOwner.plays - plays))
	check(#animOwner.loads == 1 and animOwner.loads[1] == StealService.SWING_ANIMATION.R6, "R6: анимация " .. tostring(animOwner.loads[1]))
	check(slaps == 10, "шлепков у бьющего 10, было " .. slaps)
	check(StealService.SWING_ANIMATION.R6 ~= StealService.SWING_ANIMATION.R15, "ассеты R6 и R15 одинаковые")
end)

scenario("звук трёхмерный на персонаже, громкость падает с расстоянием, ассеты бесплатные", function()
	local base = Vector3.new(500, 5, 500)
	place(thief, base)
	place(owner, FAR_B)
	press(thief)
	local list = soundsOn(thief)
	check(#list > 0, "нет звука на персонаже")
	for _, sound in ipairs(list) do
		check(sound.Parent == rootOf(thief), "звук не на персонаже")
		check(sound.RollOffMode == Enum.RollOffMode.LinearSquare, "громкость не падает с расстоянием")
		check(sound.RollOffMinDistance == SlapFx.ROLLOFF_MIN and sound.RollOffMaxDistance == SlapFx.ROLLOFF_MAX, "дальности звука")
		check(sound.RollOffMinDistance < sound.RollOffMaxDistance, "min < max")
		check(string.find(sound.SoundId, "^rbxassetid://%d+$") ~= nil, "не свой/бесплатный ассет: " .. sound.SoundId)
		check(sound.Volume > 0, "громкость 0")
	end
	for _, name in ipairs({ "slap", "slapHit", "slapThud", "slapMiss" }) do
		check(string.find(Sounds[name].id, "^rbxassetid://%d+$") ~= nil, name .. ": id не rbxassetid")
	end
end)

scenario("брейнрот: шлепок и минус сердце, как раньше", function()
	local entry = FactoryService.give(owner, "bananito_ninjini", "normal")
	World.advance(0.5)
	local model
	for _, item in ipairs(ownerPlot.model.Creatures:GetChildren()) do
		if item:GetAttribute("Uid") == entry.uid then
			model = item
		end
	end
	check(model ~= nil, "брейнрот не появился")
	local maxHp = model:GetAttribute("MaxHp")
	place(thief, model:GetAttribute("BaseCFrame").Position - Vector3.new(0, 0, 3))
	local slaps = 0
	take(thief)
	for i = 1, 3 do
		press(thief)
		slaps += take(thief, Sounds.slapHit.id, Sounds.slapHit.alt)
		check(model:GetAttribute("Hp") == maxHp - i, "удар " .. i .. ": сердец " .. tostring(model:GetAttribute("Hp")))
	end
	check(slaps == 3, "шлепок по брейнроту 3 из 3, было " .. slaps)
	local events = slapEvents(thief)
	check(events[#events] == true, "удар по брейнроту помечен как промах")
end)

scenario("босс: шлепок, если босс получил удар", function()
	local original = BossService.tryHit
	local calls = 0
	BossService.tryHit = function()
		calls += 1
		return true
	end
	place(thief, FAR_A)
	place(owner, FAR_B)
	take(thief)
	press(thief)
	BossService.tryHit = original
	local ids = {}
	for _, sound in ipairs(soundsOn(thief)) do
		ids[sound.SoundId] = (ids[sound.SoundId] or 0) + 1
	end
	check((ids[Sounds.slapHit.id] or 0) + (ids[Sounds.slapHit.alt] or 0) == 1, "по боссу нет шлепка")
	check((ids[Sounds.slapThud.id] or 0) == 1, "по боссу нет глухого удара")
	check((ids[Sounds.slapMiss.id] or 0) == 0, "по боссу свист вместо шлепка")
	check(calls == 1, "BossService.tryHit не вызван")
end)

scenario("кулдаун тот же: нажатие через 0.1 с без замаха и звука", function()
	place(thief, FAR_A)
	place(owner, FAR_B)
	local plays, events = animThief.plays, #slapEvents(thief)
	slappers[thief].Activated:Fire()
	World.advance(0.1)
	slappers[thief].Activated:Fire()
	World.advance(0.1)
	check(animThief.plays - plays == 1, "второе нажатие в кулдауне дало замах")
	check(#slapEvents(thief) - events == 1, "второе нажатие в кулдауне дало звук")
	World.advance(StealService.SLAP_COOLDOWN)
	slappers[thief].Activated:Fire()
	World.advance(0.1)
	check(animThief.plays - plays == 2 and #slapEvents(thief) - events == 2, "после кулдауна замаха нет")
end)

scenario("настройка «звуки выкл»: замах остаётся, звука нет", function()
	place(thief, FAR_A)
	place(owner, FAR_B)
	Sfx.enabled = false
	local before = #soundsOn(thief)
	local plays = animThief.plays
	press(thief)
	Sfx.enabled = true
	check(#soundsOn(thief) == before, "звук при выключенных звуках")
	check(animThief.plays - plays == 1, "замах пропал вместе со звуком")
end)

scenario("ушёл игрок: событие без персонажа не роняет клиент", function()
	local ok = pcall(SlapFx.play, nil, true)
	check(ok, "SlapFx.play(nil) упал")
	local ok2 = pcall(SlapFx.play, Instance.new("Model"), false)
	check(ok2, "SlapFx.play без корня упал")
end)

check(#World.errors == 0, "ошибки в коде: " .. #World.errors)

if failures == 0 then
	print("✅ Шлепалка: пройдено сценариев " .. scenarios)
else
	print("❌ Шлепалка: провалено проверок " .. failures)
	error("tests failed")
end
