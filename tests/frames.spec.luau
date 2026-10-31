-- Нагрузка на телефон: 8 полных баз по 20 брейнротов (160 моделей), камера у своей базы.
-- Считаем работу за кадр: сколько моделей сдвинуто и сколько раз тронуты объекты.

local failures = 0
local function check(cond, msg)
	if not cond then
		failures += 1
		print("❌ " .. msg)
	end
end

local players = {}
for index = 1, 8 do
	players[index] = World.addPlayer(4000 + index, "Player" .. index)
end
World.startServer()
World.advance(2)

local DataService = shared_require("Services/DataService")
local FactoryService = shared_require("Services/FactoryService")
local PlotService = shared_require("Services/PlotService")

for _, player in ipairs(players) do
	DataService.get(player).floors = 2
	for _ = 1, 20 do
		FactoryService.give(player, "bananito_ninjini", "normal")
	end
end
World.advance(4)

local player = players[1]
local plot = PlotService.getPlot(player)
local total = 0
for _, other in ipairs(players) do
	total += #PlotService.getPlot(other).model.Creatures:GetChildren()
end
check(total == 160, "на картах не 160 моделей: " .. total)
workspace.CurrentCamera.CFrame = CFrame.new(plot.cframe.Position + Vector3.new(0, 20, 0))

local function measure(frames)
	World.advance(0.5)
	local pivots, calls, started = World.pivots or 0, World.calls, World.realClock()
	for _ = 1, frames do
		World.frame()
	end
	return {
		pivots = ((World.pivots or 0) - pivots) / frames,
		calls = (World.calls - calls) / frames,
		ms = (World.realClock() - started) * 1000 / frames,
	}
end

local BaseAnimator = shared_require("client/BaseAnimator")
BaseAnimator.start(workspace.Plots, player)
World.advance(0.5)

local stats = measure(300)
print(string.format("  за кадр: моделей сдвинуто %.1f, обращений к объектам %.1f, %.3f мс на заглушке", stats.pivots, stats.calls, stats.ms))
check(stats.pivots <= 34, "за кадр двигается слишком много моделей: " .. stats.pivots)
check(stats.calls <= 50, "за кадр слишком много обращений к объектам: " .. stats.calls)

-- Анимация работает: своя база двигается каждый кадр, дальняя не двигается совсем.
local mine = plot.model.Creatures:GetChildren()[1]
local before = mine:GetPivot().Position
World.frame()
World.frame()
check((mine:GetPivot().Position - before).Magnitude > 0, "своя база не анимируется")
local far = PlotService.getPlot(players[5]).model.Creatures:GetChildren()[1]
before = far:GetPivot().Position
for _ = 1, 30 do
	World.frame()
end
check((far:GetPivot().Position - before).Magnitude == 0, "дальняя база анимируется")

-- Кнопки: на своей базе красть нельзя, на чужой можно, замок на чужой базе скрывает кражу быстро.
World.advance(0.3)
check(mine.PrimaryPart.StealPrompt.Enabled == false, "кнопка кражи на своей базе")
check(far.PrimaryPart.StealPrompt.Enabled == true, "нет кнопки кражи на чужой базе")
local otherPlayer = players[5]
local lockButton = PlotService.getPlot(otherPlayer).model.LockButton
shared_require("Services/MoveGuardService").teleported(otherPlayer)
otherPlayer.Character:PivotTo(lockButton.CFrame)
World.prompt(lockButton.LockPrompt, otherPlayer, 0)
World.advance(0.2 + BaseAnimator.REFRESH_EVERY + 0.05) -- сервер ставит атрибут в своём цикле
check(far.PrimaryPart.StealPrompt.Enabled == false, "замок не скрыл кнопку кражи за REFRESH_EVERY")

-- Новый брейнрот получает кнопку сразу после обновления.
FactoryService.give(player, "bananito_ninjini", "normal")
World.advance(BaseAnimator.REFRESH_EVERY + 0.05)
for _, model in ipairs(plot.model.Creatures:GetChildren()) do
	check(model.PrimaryPart.StealPrompt.Enabled == false, "у нового брейнрота кнопка кражи на своей базе")
end

check(#World.errors == 0, "ошибки в коде: " .. #World.errors)

if failures == 0 then
	print("✅ Нагрузка: проверки пройдены")
else
	print("❌ Нагрузка: провалено проверок " .. failures)
	error("tests failed")
end
