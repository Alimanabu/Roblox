-- Roblox analytics (Creator Hub -> Analytics): tutorial and main loop funnels, economy,
-- key player actions. All calls are in pcall: analytics must not break the game.

local Analytics = game:GetService("AnalyticsService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Funnels = require(Shared.Config.Funnels)

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

-- Tutorial funnel: step 1 = joined the game, then one step per finished step of Config/Tutorial.
-- Sends the steps funnel.onboarding + 1 .. target in order, each once per player for life:
-- the last sent step lives in the profile, so a rejoin or a second call never repeats a step
-- and a jump over several steps (the daily reward was already claimed) still sends every one of them.
function AnalyticsService.onboardingTo(player, data, target)
	local funnel = data.funnel
	if funnel.admin then
		return
	end
	target = math.min(target, #Funnels.ONBOARDING)
	while funnel.onboarding < target do
		local step = funnel.onboarding + 1
		funnel.onboarding = step
		safe(Analytics.LogOnboardingFunnelStepEvent, player, step, Funnels.ONBOARDING[step])
	end
end

-- Main loop funnel: a step goes out once per life and only after all the previous ones.
-- The fact "done" may come earlier than its turn (sold before the first fuse): it waits in the profile.
local function loopFlush(player, data)
	local funnel = data.funnel
	if funnel.admin then
		return
	end
	while funnel.loop < #Funnels.LOOP do
		local step = Funnels.LOOP[funnel.loop + 1]
		if not funnel.done[step.key] then
			return
		end
		funnel.loop += 1
		if funnel.session == "" then
			funnel.session = player.UserId .. "-" .. os.time()
		end
		safe(Analytics.LogFunnelStepEvent, player, Funnels.LOOP_NAME, funnel.session, funnel.loop, step.name)
	end
end

function AnalyticsService.loopFact(player, data, key)
	if data.funnel.done[key] then
		return
	end
	data.funnel.done[key] = true
	loopFlush(player, data)
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

-- Action of the Actions bus -> fact of the main funnel.
local LOOP_ACTIONS = { craft = "capsule", fuse = "fuse", sell = "sell", upgrade = "upgrade" }

local SECONDS_PER_DAY = 86400

function AnalyticsService.init()
	DataService.Loaded.Event:Connect(function(player)
		local data = DataService.get(player)
		if not data then
			return
		end
		AnalyticsService.onboardingTo(player, data, data.tutorial.step)
		-- Facts the player already has in the save (it was played before the funnels appeared) count at once.
		local done = data.funnel.done
		local stats = data.stats
		done.capsule = done.capsule or stats.crafted > 0 or nil
		done.fuse = done.fuse or stats.fused > 0 or nil
		done.sell = done.sell or stats.sold > 0 or nil
		done.upgrade = done.upgrade or data.upgrades.speed + data.upgrades.luck > 0 or nil
		-- lastOnline is written by a real save: it exists only if the previous visit saved something.
		local last = data.lastOnline or 0
		done.saved = done.saved or last > 0 or nil
		-- "Returned on day 2" = the first visit day + exactly 1 calendar day (UTC), and nothing was played on
		-- this day before (a session that crossed midnight is not a return). Later returns do not count.
		local today = math.floor(os.time() / SECONDS_PER_DAY)
		if data.funnel.firstDay == 0 then
			-- An old save has no first day: the day of its last save is the closest thing we know.
			data.funnel.firstDay = if last > 0 then math.floor(last / SECONDS_PER_DAY) else today
		end
		if today == data.funnel.firstDay + 1 and math.floor(last / SECONDS_PER_DAY) < today then
			done.returned = true
		end
		loopFlush(player, data)
	end)
	DataService.onSaved(function(player, data)
		AnalyticsService.loopFact(player, data, "saved")
	end)
	Actions.connect(function(player, kind, amount)
		if TRACKED[kind] then
			AnalyticsService.event(player, TRACKED[kind], amount)
		end
		local fact = LOOP_ACTIONS[kind]
		local data = fact and amount > 0 and DataService.get(player)
		if data then
			AnalyticsService.loopFact(player, data, fact)
		end
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
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
