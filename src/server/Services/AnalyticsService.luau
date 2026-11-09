-- Roblox analytics (Creator Dashboard -> Analytics): tutorial funnel, economy,
-- key player actions. All calls are in pcall: analytics must not break the game.

local Analytics = game:GetService("AnalyticsService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tutorial = require(Shared.Config.Tutorial)

local DataService = require(script.Parent.DataService)
local Actions = require(script.Parent.Actions)

local AnalyticsService = {}

local function safe(method, ...)
	local ok, err = pcall(method, Analytics, ...)
	if not ok then
		-- In Studio some methods may be unavailable, which is normal.
		return false, err
	end
	return true
end

-- Tutorial funnel: step 1 = joined the game, then the steps from Config/Tutorial.
function AnalyticsService.onboardingStep(player, step)
	-- Roblox accepts step names no longer than 50 characters, so we keep them short.
	local previous = Tutorial.Steps[step - 1]
	local name = step == 1 and "Joined" or (previous and ("Step" .. (step - 1) .. "_" .. previous.action) or "TutorialDone")
	safe(Analytics.LogOnboardingFunnelStepEvent, player, step, name)
end

-- We accumulate coins and events and send them once a minute in a batch, so we do not hit the limits of
-- Roblox (the auto factory crafts up to 3 times per second).
local FLUSH_INTERVAL = 60
local coinFlows = {} -- [player] = { ["Source:Sell"] = amount, ["Sink:Capsule"] = amount }
local counters = {} -- [player] = { [eventName] = count }

-- isSource = true: coins arrived (sale, income), false: spent (capsules, upgrades).
function AnalyticsService.coins(player, isSource, amount, kind)
	if amount <= 0 then
		return
	end
	coinFlows[player] = coinFlows[player] or {}
	local key = (isSource and "Source:" or "Sink:") .. kind
	coinFlows[player][key] = (coinFlows[player][key] or 0) + amount
end

function AnalyticsService.event(player, name, value)
	counters[player] = counters[player] or {}
	counters[player][name] = (counters[player][name] or 0) + (value or 1)
end

local function flush(player)
	local data = DataService.get(player)
	for key, amount in pairs(coinFlows[player] or {}) do
		local flow, kind = string.match(key, "^(%a+):(.+)$")
		safe(
			Analytics.LogEconomyEvent,
			player,
			flow == "Source" and Enum.AnalyticsEconomyFlowType.Source or Enum.AnalyticsEconomyFlowType.Sink,
			"Coins",
			math.floor(math.min(amount, 2 ^ 50)),
			math.floor(math.min(data and data.coins or 0, 2 ^ 50)),
			kind
		)
	end
	for name, value in pairs(counters[player] or {}) do
		safe(Analytics.LogCustomEvent, player, name, value)
	end
	coinFlows[player] = nil
	counters[player] = nil
end

local TRACKED = {
	craft = "Craft",
	fuse = "Fuse",
	steal = "Steal",
	slapThief = "SlapThief",
	trade = "Trade",
	lock = "Lock",
	upgrade = "Upgrade",
	daily = "DailyReward",
}

function AnalyticsService.init()
	local lastStep = {}
	DataService.Loaded.Event:Connect(function(player)
		local data = DataService.get(player)
		if not data then
			return
		end
		lastStep[player] = data.tutorial.step
		if data.tutorial.step == 1 and data.stats.crafted == 0 then
			AnalyticsService.onboardingStep(player, 1)
		end
	end)
	Actions.connect(function(player, kind, amount)
		if TRACKED[kind] then
			AnalyticsService.event(player, TRACKED[kind], amount)
		end
		-- The tutorial step may have changed after this action.
		task.defer(function()
			local data = DataService.get(player)
			if data and lastStep[player] ~= data.tutorial.step then
				if data.tutorial.step <= #Tutorial.Steps + 1 then
					AnalyticsService.onboardingStep(player, data.tutorial.step)
				end
				lastStep[player] = data.tutorial.step
			end
		end)
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastStep[player] = nil
		flush(player)
	end)
	task.spawn(function()
		while true do
			task.wait(FLUSH_INTERVAL)
			for player in pairs(coinFlows) do
				flush(player)
			end
			for player in pairs(counters) do
				flush(player)
			end
		end
	end)
end

return AnalyticsService
