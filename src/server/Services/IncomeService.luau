-- Passive income: brainrots on the base bring coins every second.
-- Plus income "while you were away" when joining the game.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local S = require(Shared.Strings)
local Formulas = require(Shared.Util.Formulas)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local EventService = require(script.Parent.EventService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local IncomeService = {}

-- Custom event in Creator Hub -> Analytics: a return after a real break (the same 10+ minutes as the window)
-- that brought offline income; a server hop does not count. Not a funnel step.
IncomeService.RETURN_EVENT = "OfflineIncomeReturn"

-- Income while away (Formulas.offlineIncome). Away 10+ minutes: the "Welcome back" window with the sum,
-- closed with one tap (client/Ui/WelcomeBack); a shorter break: a notification. No Robux, no timers.
function IncomeService.giveOfflineIncome(player)
	local data = DataService.get(player)
	if not data or (data.lastOnline or 0) <= 0 then
		return 0
	end
	local away = os.time() - data.lastOnline
	local amount = Formulas.offlineIncome(Formulas.totalIncome(data, MonetizationService.passes(player)), away)
	if amount <= 0 then
		return 0
	end
	local welcome = away >= Formulas.WELCOME_MIN_SECONDS
	data.coins += amount
	AnalyticsService.coins(player, true, amount, "Offline")
	if welcome then
		AnalyticsService.event(player, IncomeService.RETURN_EVENT, 1)
	end
	data.totalEarned += amount
	DataService.markDirty(player)
	task.delay(2, function()
		if not player.Parent then
			return
		end
		if welcome then
			Remotes.WelcomeBack:FireClient(player, amount)
		else
			Remotes.Notify:FireClient(
				player,
				S.m("income.offline", { coins = Format.coins(amount) }),
				Color3.fromRGB(255, 220, 80)
			)
		end
	end)
	return amount
end

function IncomeService.init()
	DataService.Loaded.Event:Connect(function(player)
		-- We let game passes load so that VIP is counted too.
		task.delay(1, IncomeService.giveOfflineIncome, player)
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			local mods = EventService.mods()
			for _, player in ipairs(Players:GetPlayers()) do
				local data = DataService.get(player)
				if data and #data.creatures > 0 then
					local income = Formulas.totalIncome(data, MonetizationService.passes(player), mods)
					data.coins += income
					AnalyticsService.coins(player, true, income, "Income")
					data.totalEarned += income
					DataService.markDirty(player)
				end
			end
		end
	end)
end

return IncomeService
