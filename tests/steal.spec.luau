-- Кража и телепорт: настоящие StealService, PlotService и WildService на заглушке мира.
-- Читер двигает персонажа сам, как настоящий клиент: сервер видит только новую позицию.

local failures = 0
local scenarios = 0
local function check(cond, msg)
	if not cond then
		failures += 1
		print("❌ " .. msg)
	end
end

local owner = World.addPlayer(2001, "Owner")
local thief = World.addPlayer(2002, "Thief")
local S = shared_require("Strings")
World.startServer()
World.advance(100) -- защита при входе кончилась

local DataService = shared_require("Services/DataService")
local FactoryService = shared_require("Services/FactoryService")
local PlotService = shared_require("Services/PlotService")
local WildService = shared_require("Services/WildService")
local StealService = shared_require("Services/StealService")
local MoveGuard = shared_require("Services/MoveGuardService")

local slapper = thief.Backpack:FindFirstChild(S.t("steal.slapper"))
local ownerPlot = PlotService.getPlot(owner)
local thiefPlot = PlotService.getPlot(thief)

local function rootOf(player)
	return player.Character.HumanoidRootPart
end

local function moveTo(player, position)
	local root = rootOf(player)
	root.CFrame = CFrame.lookAt(position, position + Vector3.new(0, 0, 1))
end

-- Честный перенос между сценариями: сервер ставит игрока и прощает прыжок.
local function place(player, position)
	MoveGuard.teleported(player)
	moveTo(player, position)
	World.advance(MoveGuard.TELEPORT_GRACE + 4)
end

-- Идём к цели шагами, как клиент присылает позицию.
local function walk(player, target, speed)
	local dt = 0.2
	for _ = 1, 5000 do
		local from = rootOf(player).Position
		local offset = target - from
		if offset.Magnitude < 0.5 then
			return
		end
		moveTo(player, from + offset.Unit * math.min(offset.Magnitude, speed * dt))
		World.advance(dt)
	end
	error("не дошёл до цели")
end

local function give()
	local entry = FactoryService.give(owner, "bananito_ninjini", "normal")
	World.advance(0.5)
	for _, model in ipairs(ownerPlot.model.Creatures:GetChildren()) do
		if model:GetAttribute("Uid") == entry.uid then
			return entry, model
		end
	end
	error("брейнрот не появился на базе")
end

local function slap()
	slapper.Activated:Fire()
	World.advance(0.9)
end

-- Подойти, выбить ❤️ и схватить брейнрота: всё честно.
local function grab(entry, model)
	place(thief, model:GetAttribute("BaseCFrame").Position - Vector3.new(0, 0, 3))
	for _ = 1, model:GetAttribute("MaxHp") do
		slap()
	end
	check(model:GetAttribute("StunnedUntil") ~= nil, "брейнрот не оглушён")
	local prompt = model.PrimaryPart.StealPrompt
	World.prompt(prompt, thief, prompt.HoldDuration)
	check(thief:GetAttribute("CarryDeadline") ~= nil, "вор не схватил брейнрота")
end

local function ownerHas(entry)
	for _, item in ipairs(DataService.get(owner).creatures) do
		if item.uid == entry.uid then
			return true
		end
	end
	return false
end

local function stolenCount()
	return DataService.get(thief).stats.stolen or 0
end

local function scenario(name, body)
	scenarios += 1
	local before = failures
	local ok, err = pcall(body)
	if not ok then
		failures += 1
		print("❌ " .. name .. ": " .. tostring(err))
	end
	-- Между сценариями снимаем кражу и даём запасу пути восстановиться.
	World.advance(70)
	print(string.format("  %s %d. %s", failures == before and "✅" or "❌", scenarios, name))
end

local function homeOf(plot)
	return plot.cframe.Position + Vector3.new(0, 3, 0)
end

print("— Кража и телепорт —")

scenario("честный вор добегает до базы", function()
	local entry, model = give()
	grab(entry, model)
	local count = stolenCount()
	walk(thief, homeOf(thiefPlot), StealService.CARRY_SPEED)
	World.advance(0.5)
	check(stolenCount() == count + 1, "честная кража не засчитана")
	check(not ownerHas(entry), "брейнрот остался у хозяина")
end)

scenario("честный вор с обрывом связи на 3 с", function()
	local entry, model = give()
	grab(entry, model)
	local count = stolenCount()
	local home = homeOf(thiefPlot)
	local from = rootOf(thief).Position
	World.advance(3) -- сервер не получает позицию, персонаж на клиенте бежит
	moveTo(thief, from + (home - from).Unit * (StealService.CARRY_SPEED * 3))
	World.advance(0.2)
	walk(thief, home, StealService.CARRY_SPEED)
	World.advance(0.5)
	check(stolenCount() == count + 1, "обрыв связи сорвал честную кражу")
end)

scenario("телепорт домой с брейнротом: кража отклонена, брейнрот у хозяина", function()
	local entry, model = give()
	grab(entry, model)
	local count = stolenCount()
	moveTo(thief, homeOf(thiefPlot))
	World.advance(1)
	check(thief:GetAttribute("CarryDeadline") == nil, "вор всё ещё несёт брейнрота")
	check(stolenCount() == count, "телепорт засчитан как кража")
	check(ownerHas(entry), "брейнрот не вернулся хозяину")
end)

scenario("телепорт по шагам между проверками тоже считается", function()
	local entry, model = give()
	grab(entry, model)
	local count = stolenCount()
	local home = homeOf(thiefPlot)
	local from = rootOf(thief).Position
	for step = 1, 4 do
		moveTo(thief, from + (home - from) * (step / 4))
		World.advance(0.05)
	end
	World.advance(1)
	check(stolenCount() == count, "короткие прыжки засчитаны как кража")
	check(ownerHas(entry), "брейнрот не вернулся хозяину")
end)

scenario("бег на чите 40 студов/с: кража отклонена", function()
	local entry, model = give()
	grab(entry, model)
	local count = stolenCount()
	walk(thief, homeOf(thiefPlot), 40)
	World.advance(1)
	check(stolenCount() == count, "спидхак засчитан как кража")
	check(ownerHas(entry), "брейнрот не вернулся хозяину")
end)

scenario("мог ли дойти: расстояние, скорость и время", function()
	local from = Vector3.new(0, 0, 0)
	local started = World.now() - 2
	local reach = StealService.CARRY_SPEED * MoveGuard.SPEED_MARGIN * 2
	check(MoveGuard.couldWalk(from, started, Vector3.new(reach - 1, 0, 0), StealService.CARRY_SPEED), "честный путь не прошёл")
	check(not MoveGuard.couldWalk(from, started, Vector3.new(reach + 1, 0, 0), StealService.CARRY_SPEED), "слишком длинный путь прошёл")
	check(MoveGuard.couldWalk(from, started, Vector3.new(0, -500, 0), StealService.CARRY_SPEED), "падение вниз считается бегом")
end)

scenario("телепорт к чужому брейнроту: шлепок и кража отклонены, пока не хватит времени дойти", function()
	local _, model = give()
	local base = model:GetAttribute("BaseCFrame").Position
	place(thief, homeOf(thiefPlot))
	moveTo(thief, base - Vector3.new(0, 0, 3))
	World.advance(0.3)
	local hp = model:GetAttribute("Hp")
	slap()
	check(model:GetAttribute("Hp") == hp, "шлепок после телепорта прошёл")
	check(MoveGuard.canAct(thief) == false, "после телепорта игрок может действовать")

	local walkTime = (homeOf(thiefPlot) - base).Magnitude / 16
	World.advance(walkTime + 5)
	check(MoveGuard.canAct(thief), "запас не восстановился за время пути пешком")
	slap()
	check(model:GetAttribute("Hp") == hp - 1, "через время пути шлепок должен пройти")
end)

scenario("удар отбрасывает вора: это не телепорт", function()
	local entry, model = give()
	grab(entry, model)
	local from = rootOf(thief).Position
	MoveGuard.knockback(thief, 60)
	moveTo(thief, from + Vector3.new(70, 20, 0))
	World.advance(0.5)
	check(thief:GetAttribute("CarryDeadline") ~= nil, "отлёт от удара сорвал кражу")
	check(ownerHas(entry) == false, "брейнрот вернулся из-за отлёта")
end)

scenario("после удара до своей базы рукой подать: кража ждёт, пока вор мог дойти", function()
	local entry, model = give()
	grab(entry, model)
	local count = stolenCount()
	local home = homeOf(thiefPlot)
	local distance = (home - rootOf(thief).Position).Magnitude
	check(distance < MoveGuard.MAX_BUDGET + 60 * MoveGuard.KNOCKBACK_SECONDS, "базы слишком далеко для этого сценария")
	MoveGuard.knockback(thief, 60)
	moveTo(thief, home)
	World.advance(1)
	check(stolenCount() == count, "кража засчитана раньше, чем вор мог дойти")
	World.advance(distance / StealService.CARRY_SPEED)
	check(stolenCount() == count + 1, "кража не засчитана, когда вор мог дойти")
end)

scenario("удар не даёт телепорта через всю карту", function()
	local entry, model = give()
	grab(entry, model)
	local count = stolenCount()
	MoveGuard.knockback(thief, 60)
	moveTo(thief, Vector3.new(-200, 3, 0))
	World.advance(1)
	check(thief:GetAttribute("CarryDeadline") == nil, "вор всё ещё несёт брейнрота")
	check(ownerHas(entry), "брейнрот не вернулся хозяину")
	check(stolenCount() == count, "удар дал телепорт")
end)

scenario("забор замка выталкивает вора: это не телепорт", function()
	local entry, model = give()
	grab(entry, model)
	local from = rootOf(thief).Position
	MoveGuard.teleported(thief)
	moveTo(thief, from + Vector3.new(45, 0, 0))
	World.advance(0.3)
	moveTo(thief, from) -- клиент ещё шлёт старую позицию
	World.advance(0.2)
	moveTo(thief, from + Vector3.new(45, 0, 0))
	World.advance(0.3)
	check(thief:GetAttribute("CarryDeadline") ~= nil, "забор сорвал кражу")
	check(ownerHas(entry) == false, "брейнрот вернулся из-за забора")
end)

scenario("дикий брейнрот: телепорт к нему отклонён, честный подход работает", function()
	place(thief, homeOf(thiefPlot))
	WildService.forceSpawn()
	World.advance(0.1)
	local model = workspace.WildBrainrots:FindFirstChild("Wild")
	local prompt = model.PrimaryPart.WildPrompt
	local caught = DataService.get(thief).stats.wildCaught or 0
	moveTo(thief, model:GetPivot().Position)
	World.prompt(prompt, thief, 0)
	check(model.Parent ~= nil, "телепорт поймал дикого брейнрота")

	World.advance(30)
	local alive = workspace.WildBrainrots:FindFirstChild("Wild")
	check(alive ~= nil, "дикий брейнрот убежал раньше времени")
	for _ = 1, 3000 do
		local offset = alive:GetPivot().Position - rootOf(thief).Position
		if offset.Magnitude <= 8 then
			break
		end
		moveTo(thief, rootOf(thief).Position + offset.Unit * 3.2)
		World.advance(0.2)
	end
	local gap = (alive:GetPivot().Position - rootOf(thief).Position).Magnitude
	check(gap <= 8, "не догнал дикого брейнрота: " .. tostring(gap) .. " " .. tostring(alive:GetPivot().Position.X))
	World.prompt(alive.PrimaryPart.WildPrompt, thief, 0)
	check(alive.Parent == nil, "честный подход не поймал дикого брейнрота")
	check((DataService.get(thief).stats.wildCaught or 0) == caught + 1, "поимка не засчитана")
end)

scenario("замок: закрыть базу издалека нельзя", function()
	local plotModel = ownerPlot.model
	local prompt = plotModel.LockButton.LockPrompt
	place(owner, homeOf(thiefPlot))
	World.prompt(prompt, owner, 0)
	World.advance(0.3)
	check(not StealService.isLocked(owner), "база закрылась издалека")
	place(owner, plotModel.LockButton.Position + Vector3.new(0, 3, 0))
	World.prompt(prompt, owner, 0)
	World.advance(0.3)
	check(StealService.isLocked(owner), "база не закрылась у кнопки")
end)

scenario("новый персонаж появляется где угодно: это не телепорт", function()
	local old = thief.Character
	local character = Instance.new("Model")
	character.Name = "Thief"
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Parent = character
	root.CFrame = CFrame.new(homeOf(ownerPlot))
	Instance.new("Humanoid").Parent = character
	character.Parent = workspace
	thief.Character = character
	World.advance(0.5)
	check(MoveGuard.canAct(thief), "новый персонаж считается телепортом")
	thief.Character = old
	World.advance(1.5)
end)

check(#World.errors == 0, "ошибки в коде: " .. #World.errors)

if failures == 0 then
	print("✅ Кража: пройдено сценариев " .. scenarios)
else
	print("❌ Кража: провалено проверок " .. failures)
	error("tests failed")
end
