-- Ежедневные награды и задания.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Daily = require(Shared.Config.Daily)
local Formulas = require(Shared.Util.Formulas)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local ProgressionService = require(script.Parent.ProgressionService)
local Actions = require(script.Parent.Actions)

local QuestService = {}

local GOOD = Color3.fromRGB(120, 255, 120)
local BAD = Color3.fromRGB(255, 110, 110)
local GOLD = Color3.fromRGB(255, 220, 80)

-- Задания на сегодня одинаковые для игрока на любом сервере (зерно = день + UserId).
local function ensureQuests(player, data)
	local day = Daily.today()
	if data.quests.day == day then
		return
	end
	local rng = Random.new(day * 1000003 + player.UserId % 1000003)
	local pool = table.clone(Daily.QuestPool)
	local list = {}
	for _ = 1, math.min(Daily.QUESTS_PER_DAY, #pool) do
		local quest = table.remove(pool, rng:NextInteger(1, #pool))
		table.insert(list, { id = quest.id, progress = 0, claimed = false })
	end
	data.quests = { day = day, list = list }
end

local function giveReward(player, data, coinsMinutes, luckMinutes)
	local parts = {}
	if coinsMinutes and coinsMinutes > 0 then
		local income = Formulas.totalIncome(data, MonetizationService.passes(player))
		local coins = Daily.coinsFor(income, coinsMinutes)
		data.coins += coins
		data.totalEarned += coins
		table.insert(parts, "💰 " .. Format.coins(coins))
	end
	if luckMinutes and luckMinutes > 0 then
		data.boosts.luckUntil = math.max(data.boosts.luckUntil or 0, os.time()) + luckMinutes * 60
		table.insert(parts, "🍀 x2 удачи на " .. luckMinutes .. " мин")
	end
	return table.concat(parts, " + ")
end

local function onAction(player, kind, amount)
	local data = DataService.get(player)
	if not data then
		return
	end
	ensureQuests(player, data)
	for _, quest in ipairs(data.quests.list) do
		local def = Daily.QuestById[quest.id]
		if def and def.kind == kind and not quest.claimed and quest.progress < def.target then
			quest.progress = math.min(def.target, quest.progress + (amount or 1))
			if quest.progress >= def.target then
				Remotes.Notify:FireClient(player, "📋 Задание выполнено: " .. def.text .. "! Забери награду 🎁", GOLD)
			end
			DataService.markDirty(player)
		end
	end
end

local function canClaimDaily(data)
	return data.daily.lastClaimDay ~= Daily.today()
end

-- Какой день серии будет следующим (1..7).
local function nextStreakDay(data)
	local today = Daily.today()
	if data.daily.lastClaimDay == today - 1 or data.daily.lastClaimDay == today then
		if data.daily.lastClaimDay == today then
			return data.daily.streak
		end
		return data.daily.streak % #Daily.Rewards + 1
	end
	return 1
end

local function claimDaily(player)
	local data = DataService.get(player)
	if not data then
		return
	end
	if not canClaimDaily(data) then
		Remotes.Notify:FireClient(player, "Сегодняшняя награда уже получена. Приходи завтра!", BAD)
		return
	end
	local day = nextStreakDay(data)
	local reward = Daily.Rewards[day]
	data.daily.streak = day
	data.daily.lastClaimDay = Daily.today()
	local text = giveReward(player, data, reward.coinsMinutes, reward.luckMinutes)
	Remotes.Notify:FireClient(player, "🎁 День " .. day .. ": " .. text, GOLD)
	Actions.fire(player, "daily", 1)
	Remotes.Sfx:FireClient(player, "coins")
	DataService.markDirty(player)
end

local function claimQuest(player, index)
	local data = DataService.get(player)
	if not data or type(index) ~= "number" then
		return
	end
	ensureQuests(player, data)
	local quest = data.quests.list[index]
	local def = quest and Daily.QuestById[quest.id]
	if not def or quest.claimed or quest.progress < def.target then
		return
	end
	quest.claimed = true
	local text = giveReward(player, data, def.minutes, 0)
	ProgressionService.addXp(player, data, def.minutes * 5)
	Remotes.Notify:FireClient(player, "📋 Награда за задание: " .. text, GOOD)
	DataService.markDirty(player)
end

-- Данные для интерфейса.
function QuestService.snapshot(player, data)
	ensureQuests(player, data)
	local income = Formulas.totalIncome(data, MonetizationService.passes(player))
	local quests = {}
	for index, quest in ipairs(data.quests.list) do
		local def = Daily.QuestById[quest.id]
		if def then
			table.insert(quests, {
				index = index,
				text = def.text,
				progress = quest.progress,
				target = def.target,
				claimed = quest.claimed,
				reward = Format.coins(Daily.coinsFor(income, def.minutes)),
			})
		end
	end
	local rewards = {}
	for day, reward in ipairs(Daily.Rewards) do
		local parts = {}
		if reward.coinsMinutes then
			table.insert(parts, Format.coins(Daily.coinsFor(income, reward.coinsMinutes)))
		end
		if reward.luckMinutes then
			table.insert(parts, "🍀x2 " .. reward.luckMinutes .. "м")
		end
		rewards[day] = table.concat(parts, "\n")
	end
	return {
		canClaim = canClaimDaily(data),
		nextDay = nextStreakDay(data),
		streak = data.daily.streak,
		rewards = rewards,
		quests = quests,
		secondsToReset = (Daily.today() + 1) * 86400 - os.time(),
	}
end

function QuestService.init()
	Actions.connect(onAction)
	Remotes.ClaimDaily.OnServerEvent:Connect(claimDaily)
	Remotes.ClaimQuest.OnServerEvent:Connect(claimQuest)
end

return QuestService
