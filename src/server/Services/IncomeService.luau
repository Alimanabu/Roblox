-- Пассивный доход: брейнроты на базе приносят монеты каждую секунду.
-- Плюс доход «пока тебя не было» при входе в игру.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Formulas = require(Shared.Util.Formulas)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)

local IncomeService = {}

local function giveOfflineIncome(player)
	local data = DataService.get(player)
	if not data or (data.lastOnline or 0) <= 0 then
		return
	end
	local seconds = math.min(os.time() - data.lastOnline, Formulas.OFFLINE_MAX_SECONDS)
	if seconds < 60 then
		return
	end
	local income = Formulas.totalIncome(data, MonetizationService.passes(player))
	local amount = math.floor(income * seconds * Formulas.OFFLINE_RATE)
	if amount <= 0 then
		return
	end
	data.coins += amount
	data.totalEarned += amount
	DataService.markDirty(player)
	task.delay(2, function()
		if player.Parent then
			Remotes.Notify:FireClient(
				player,
				"💤 Пока тебя не было, брейнроты заработали " .. Format.coins(amount),
				Color3.fromRGB(255, 220, 80)
			)
		end
	end)
end

function IncomeService.init()
	DataService.Loaded.Event:Connect(function(player)
		-- Даём геймпассам прогрузиться, чтобы VIP тоже учитывался.
		task.delay(1, giveOfflineIncome, player)
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				local data = DataService.get(player)
				if data and #data.creatures > 0 then
					local income = Formulas.totalIncome(data, MonetizationService.passes(player))
					data.coins += income
					data.totalEarned += income
					DataService.markDirty(player)
				end
			end
		end
	end)
end

return IncomeService
