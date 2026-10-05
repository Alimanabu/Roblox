-- Выдача наград из разных источников: задания, промокоды, подарки, достижения.
-- reward = { coinsMinutes = N, luckMinutes = N, coins = N, creatureRarity = "aura" }
-- Монеты в «минутах дохода», чтобы награда была полезна и новичку, и прокачанному.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Daily = require(Shared.Config.Daily)
local Creatures = require(Shared.Config.Creatures)
local Formulas = require(Shared.Util.Formulas)
local Format = require(Shared.Util.Format)

local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local FactoryService = require(script.Parent.FactoryService)

local RewardService = {}

-- Возвращает текст вида «💰 $1.2K + 🍀 x2 удачи на 10 мин».
function RewardService.grant(player, data, reward)
	local parts = {}
	local coins = reward.coins or 0
	if reward.coinsMinutes and reward.coinsMinutes > 0 then
		local income = Formulas.totalIncome(data, MonetizationService.passes(player))
		coins += Daily.coinsFor(income, reward.coinsMinutes)
	end
	if coins > 0 then
		data.coins += coins
		data.totalEarned += coins
		table.insert(parts, "💰 " .. Format.coins(coins))
	end
	if reward.luckMinutes and reward.luckMinutes > 0 then
		data.boosts.luckUntil = math.max(data.boosts.luckUntil or 0, os.time()) + reward.luckMinutes * 60
		table.insert(parts, "🍀 x2 удачи на " .. reward.luckMinutes .. " мин")
	end
	if reward.creatureRarity then
		local pool = Creatures.ByRarity[reward.creatureRarity]
		if pool then
			local creature = pool[math.random(1, #pool)]
			FactoryService.give(player, creature.id, "normal")
			table.insert(parts, "🧠 " .. creature.name)
		end
	end
	DataService.markDirty(player)
	return table.concat(parts, " + ")
end

-- Короткое описание награды для интерфейса (без выдачи).
function RewardService.describe(player, data, reward)
	local parts = {}
	local coins = reward.coins or 0
	if reward.coinsMinutes then
		local income = Formulas.totalIncome(data, MonetizationService.passes(player))
		coins += Daily.coinsFor(income, reward.coinsMinutes)
	end
	if coins > 0 then
		table.insert(parts, Format.coins(coins))
	end
	if reward.luckMinutes then
		table.insert(parts, "🍀x2 " .. reward.luckMinutes .. "м")
	end
	if reward.creatureRarity then
		table.insert(parts, "🧠")
	end
	return table.concat(parts, " + ")
end

return RewardService
