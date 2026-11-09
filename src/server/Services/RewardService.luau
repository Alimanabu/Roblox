-- Granting rewards from different sources: quests, promo codes, gifts, achievements.
-- reward = { coinsMinutes = N, luckMinutes = N, coins = N, creatureRarity = "aura" }
-- Coins in "minutes of income", so the reward is useful to both a newbie and a veteran.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local S = require(Shared.Strings)
local Daily = require(Shared.Config.Daily)
local Creatures = require(Shared.Config.Creatures)
local Formulas = require(Shared.Util.Formulas)
local Format = require(Shared.Util.Format)

local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local FactoryService = require(script.Parent.FactoryService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local RewardService = {}

-- Returns a message like "$1.2K + x2 luck for 10 min" (see Strings).
-- source is set if the reward was received for Robux (see Formulas.SOURCE_SPIN): then the brainrot,
-- the coins and the boost all count as purchased.
function RewardService.grant(player, data, reward, source)
	local parts = {}
	local coins = reward.coins or 0
	if reward.coinsMinutes and reward.coinsMinutes > 0 then
		local income = Formulas.totalIncome(data, MonetizationService.passes(player))
		coins += Daily.coinsFor(income, reward.coinsMinutes)
	end
	if coins > 0 then
		AnalyticsService.coins(player, true, coins, "Reward")
		data.coins += coins
		data.totalEarned += coins
		if source then
			data.boughtCoins += coins
		end
		table.insert(parts, "💰 " .. Format.coins(coins))
	end
	if reward.luckMinutes and reward.luckMinutes > 0 then
		data.boosts.luckUntil = math.max(data.boosts.luckUntil or 0, os.time()) + reward.luckMinutes * 60
		if source then
			data.boosts.paidLuckUntil = data.boosts.luckUntil
		end
		table.insert(parts, S.m("reward.luck", { minutes = reward.luckMinutes }))
	end
	if reward.skin and not data.skins[reward.skin] then
		data.skins[reward.skin] = true
		table.insert(parts, S.m("reward.skin"))
	end
	if reward.creatureRarity then
		local pool = Creatures.ByRarity[reward.creatureRarity]
		local passes = MonetizationService.passes(player)
		if pool and #data.creatures >= Formulas.slots(data, passes) then
			-- The base is full: money instead of a brainrot, 10 minutes of its income (at least 10 minutes of the player's income).
			local creature = pool[1]
			local coins = math.max(creature.income * 600, Daily.coinsFor(Formulas.totalIncome(data, passes), 10))
			data.coins += coins
			data.totalEarned += coins
			if source then
				data.boughtCoins += coins
			end
			table.insert(parts, S.m("reward.coins_base_full", { coins = Format.coins(coins) }))
		elseif pool then
			local creature = pool[math.random(1, #pool)]
			FactoryService.give(player, creature.id, "normal", source)
			table.insert(parts, S.m("reward.creature", { name = S.m(creature.nameKey) }))
		end
	end
	DataService.markDirty(player)
	return S.join(parts, " + ")
end

-- Short description of the reward for the UI (without granting).
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
		table.insert(parts, S.m("reward.luck_short", { minutes = reward.luckMinutes }))
	end
	if reward.creatureRarity then
		table.insert(parts, "🧠")
	end
	return S.join(parts, " + ")
end

return RewardService
