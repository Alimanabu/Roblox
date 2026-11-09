-- Daily rewards and quests.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local S = require(Shared.Strings)
local Daily = require(Shared.Config.Daily)
local Formulas = require(Shared.Util.Formulas)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local ProgressionService = require(script.Parent.ProgressionService)
local Actions = require(script.Parent.Actions)
local RewardService = require(script.Parent.RewardService)

local QuestService = {}

local GOOD = Color3.fromRGB(120, 255, 120)
local BAD = Color3.fromRGB(255, 110, 110)
local GOLD = Color3.fromRGB(255, 220, 80)

-- Today's quests are the same for a player on any server (seed = day + UserId).
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
	return RewardService.grant(player, data, { coinsMinutes = coinsMinutes, luckMinutes = luckMinutes })
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
				Remotes.Notify:FireClient(player, S.m("quest.done", { text = S.m(def.textKey) }), GOLD)
			end
			DataService.markDirty(player)
		end
	end
end

local function canClaimDaily(data)
	return data.daily.lastClaimDay ~= Daily.today()
end

-- Which day of the streak is next (1..7).
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
		Remotes.Notify:FireClient(player, S.m("quest.daily_claimed"), BAD)
		return
	end
	local day = nextStreakDay(data)
	local reward = Daily.Rewards[day]
	data.daily.streak = day
	data.daily.lastClaimDay = Daily.today()
	local text = giveReward(player, data, reward.coinsMinutes, reward.luckMinutes)
	Remotes.Notify:FireClient(player, S.m("quest.daily_reward", { day = day, reward = text }), GOLD)
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
	Remotes.Notify:FireClient(player, S.m("quest.reward", { reward = text }), GOOD)
	DataService.markDirty(player)
end

-- Data for the UI.
function QuestService.snapshot(player, data)
	ensureQuests(player, data)
	local income = Formulas.totalIncome(data, MonetizationService.passes(player))
	local quests = {}
	for index, quest in ipairs(data.quests.list) do
		local def = Daily.QuestById[quest.id]
		if def then
			table.insert(quests, {
				index = index,
				text = S.m(def.textKey),
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
			table.insert(parts, S.m("reward.luck_short", { minutes = reward.luckMinutes }))
		end
		rewards[day] = S.join(parts, "\n")
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

-- The client script needs a few seconds after joining to start listening: a reminder sent earlier would be lost.
local REMIND_DELAY = 8

-- A reminder when the player joins: the daily reward waits for them, and the streak is at stake.
local function remindDaily(player)
	task.delay(REMIND_DELAY, function()
		local data = player.Parent and DataService.get(player)
		if data and canClaimDaily(data) then
			Remotes.Notify:FireClient(player, S.m("quest.daily_ready", { day = nextStreakDay(data), total = #Daily.Rewards }), GOLD)
		end
	end)
end

function QuestService.init()
	DataService.Loaded.Event:Connect(remindDaily)
	Actions.connect(onAction)
	Remotes.ClaimDaily.OnServerEvent:Connect(claimDaily)
	Remotes.ClaimQuest.OnServerEvent:Connect(claimQuest)
end

return QuestService
