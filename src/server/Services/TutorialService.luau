-- Tutorial: leads a newbie through the first steps and gives coins for them.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local S = require(Shared.Strings)
local Tutorial = require(Shared.Config.Tutorial)
local Format = require(Shared.Util.Format)
local Daily = require(Shared.Config.Daily)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local Actions = require(script.Parent.Actions)
local AnalyticsService = require(script.Parent.AnalyticsService)

local TutorialService = {}

local GOLD = Color3.fromRGB(255, 220, 80)

-- The step is done: reward, next step, message.
local function finishStep(player, data, step)
	local tutorial = data.tutorial
	data.coins += step.reward
	tutorial.step += 1
	tutorial.progress = 0
	if Tutorial.Steps[tutorial.step] then
		Remotes.Notify:FireClient(player, S.m("tutorial.step_done", { coins = Format.coins(step.reward) }), GOLD)
	else
		Remotes.Notify:FireClient(player, S.m("tutorial.finished", { coins = Format.coins(step.reward) }), GOLD)
	end
	-- Every finished step goes to the funnel on its own, even when settle closes the next one at once.
	AnalyticsService.onboardingTo(player, data, tutorial.step)
	DataService.markDirty(player)
end

-- A once-a-day step the player has already done today counts at once: the daily reward claimed on
-- steps 1-4 would otherwise leave "Claim your daily reward" pointing at a dead button until tomorrow.
function TutorialService.settle(player, data)
	local tutorial = data.tutorial
	while true do
		local step = Tutorial.Steps[tutorial.step]
		if not step or step.action ~= "daily" or data.daily.lastClaimDay ~= Daily.today() then
			return
		end
		finishStep(player, data, step)
	end
end

local function onAction(player, kind, amount)
	local data = DataService.get(player)
	if not data then
		return
	end
	local tutorial = data.tutorial
	local step = Tutorial.Steps[tutorial.step]
	if not step then
		return
	end
	if step.action == kind then
		tutorial.progress += amount
		if tutorial.progress < step.count then
			DataService.markDirty(player)
			return
		end
		finishStep(player, data, step)
	elseif kind ~= "daily" then
		return
	end
	TutorialService.settle(player, data)
end

function TutorialService.snapshot(data)
	local step = Tutorial.Steps[data.tutorial.step]
	if not step then
		return nil
	end
	return {
		index = data.tutorial.step,
		total = #Tutorial.Steps,
		text = S.m(step.textKey),
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
