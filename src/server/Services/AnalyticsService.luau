-- Аналитика Roblox (Creator Dashboard → Analytics): воронка обучения, экономика,
-- ключевые действия игроков. Все вызовы в pcall — аналитика не должна ломать игру.

local Analytics = game:GetService("AnalyticsService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tutorial = require(Shared.Config.Tutorial)

local DataService = require(script.Parent.DataService)
local Actions = require(script.Parent.Actions)

local AnalyticsService = {}

local function safe(method, ...)
	local ok, err = pcall(method, Analytics, ...)
	if not ok then
		-- В Studio часть методов может быть недоступна — это нормально.
		return false, err
	end
	return true
end

-- Воронка обучения: шаг 1 = зашёл в игру, дальше шаги из Config/Tutorial.
function AnalyticsService.onboardingStep(player, step)
	local previous = Tutorial.Steps[step - 1]
	local name = step == 1 and "Зашёл в игру" or (previous and ("Шаг " .. (step - 1) .. ": " .. previous.text) or "Обучение пройдено")
	safe(Analytics.LogOnboardingFunnelStepEvent, player, step, name)
end

-- Монеты и события копим и отправляем раз в минуту пачкой: так не упрёмся в лимиты
-- Roblox (авто-фабрика крафтит до 3 раз в секунду).
local FLUSH_INTERVAL = 60
local coinFlows = {} -- [player] = { ["Source:Sell"] = amount, ["Sink:Capsule"] = amount }
local counters = {} -- [player] = { [eventName] = count }

-- isSource = true — монеты пришли (продажа, доход), false — потрачены (капсулы, улучшения).
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
		-- Шаг обучения мог смениться после этого действия.
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
