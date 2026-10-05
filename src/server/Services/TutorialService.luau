-- Обучение: ведёт новичка по первым шагам и даёт за них монеты.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tutorial = require(Shared.Config.Tutorial)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local Actions = require(script.Parent.Actions)

local TutorialService = {}

local GOLD = Color3.fromRGB(255, 220, 80)

local function onAction(player, kind, amount)
	local data = DataService.get(player)
	if not data then
		return
	end
	local tutorial = data.tutorial
	local step = Tutorial.Steps[tutorial.step]
	if not step or step.action ~= kind then
		return
	end
	tutorial.progress += amount
	if tutorial.progress < step.count then
		DataService.markDirty(player)
		return
	end

	data.coins += step.reward
	tutorial.step += 1
	tutorial.progress = 0
	if Tutorial.Steps[tutorial.step] then
		Remotes.Notify:FireClient(player, "✅ Отлично! +" .. Format.coins(step.reward), GOLD)
	else
		Remotes.Notify:FireClient(player, "🎓 Обучение пройдено! +" .. Format.coins(step.reward) .. ". Теперь собери SIX SEVEN 🤌", GOLD)
	end
	DataService.markDirty(player)
end

function TutorialService.snapshot(data)
	local step = Tutorial.Steps[data.tutorial.step]
	if not step then
		return nil
	end
	return {
		index = data.tutorial.step,
		total = #Tutorial.Steps,
		text = step.text,
		progress = data.tutorial.progress,
		count = step.count,
		menu = step.menu,
		highlightLock = step.highlightLock == true,
	}
end

function TutorialService.init()
	Actions.connect(onAction)
end

return TutorialService
