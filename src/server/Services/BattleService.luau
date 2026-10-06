-- Аура-баттлы: 3 сильнейших брейнрота против 3 сильнейших соперника (или бота).
-- Каждый раунд — пара брейнротов, сила = Battles.power(доход) ± случайность.
-- Без ставок: брейнроты и монеты не теряются, за победы — очки ауры и монеты.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Battles = require(Shared.Config.Battles)
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local Daily = require(Shared.Config.Daily)
local Formulas = require(Shared.Util.Formulas)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local RewardService = require(script.Parent.RewardService)
local Actions = require(script.Parent.Actions)

local BattleService = {}

local GOOD = Color3.fromRGB(120, 255, 120)
local BAD = Color3.fromRGB(255, 110, 110)
local INFO = Color3.fromRGB(120, 200, 255)
local INVITE_TIMEOUT = 30

local rng = Random.new()
local lastChallenge = {} -- [player] = os.clock()
local lastPair = {} -- ["minId:maxId"] = os.clock()
local invites = {} -- [target] = { [fromUserId] = os.clock() }

-- Команда: до TEAM_SIZE сильнейших брейнротов игрока.
local function teamOf(data)
	local sorted = table.clone(data.creatures)
	table.sort(sorted, function(a, b)
		return Formulas.creatureBaseIncome(a) > Formulas.creatureBaseIncome(b)
	end)
	local team = {}
	for i = 1, math.min(Battles.TEAM_SIZE, #sorted) do
		table.insert(team, { id = sorted[i].id, mut = sorted[i].mut, skin = sorted[i].skin })
	end
	return team
end

-- Бот подбирает брейнротов примерно той же редкости (иногда на одну выше или ниже).
local function botTeam(playerTeam)
	local team = {}
	for _, member in ipairs(playerTeam) do
		local rank = Rarities.get(Creatures.get(member.id).rarity).rank
		rank = math.clamp(rank + rng:NextInteger(-1, 1), 1, #Rarities.List - 1)
		local pool = Creatures.ByRarity[Rarities.List[rank].id]
		local creature = pool[rng:NextInteger(1, #pool)]
		table.insert(team, { id = creature.id, mut = "normal" })
	end
	return team
end

local function roll(member)
	if not member then
		return 0
	end
	local base = Battles.power(Formulas.creatureBaseIncome(member))
	return math.floor(base * rng:NextNumber(1 - Battles.RANDOM_SPREAD, 1 + Battles.RANDOM_SPREAD))
end

-- Результат со стороны первого участника.
local function fight(teamA, teamB)
	local rounds, winsA, winsB = {}, 0, 0
	for i = 1, Battles.TEAM_SIZE do
		local a, b = teamA[i], teamB[i]
		local powerA, powerB = roll(a), roll(b)
		if powerA == powerB then
			powerA += rng:NextInteger(0, 1) == 0 and 1 or -1
		end
		local aWins = powerA > powerB
		if aWins then
			winsA += 1
		else
			winsB += 1
		end
		table.insert(rounds, { a = a, b = b, powerA = powerA, powerB = powerB, aWins = aWins })
	end
	return rounds, winsA > winsB
end

local function flip(rounds)
	local flipped = {}
	for _, round in ipairs(rounds) do
		table.insert(flipped, { a = round.b, b = round.a, powerA = round.powerB, powerB = round.powerA, aWins = not round.aWins })
	end
	return flipped
end

-- Начисляет очки и награду; возвращает текст награды.
local function settle(player, data, won, vsBot)
	local battles = data.battles
	local today = Daily.today()
	if battles.rewardDay ~= today then
		battles.rewardDay = today
		battles.rewardedToday = 0
	end
	local rewardText = ""
	if won then
		battles.wins += 1
		if battles.rewardedToday < Battles.REWARDED_PER_DAY then
			-- И монеты, и очки за бота — только в пределах дневного лимита (иначе накрутка).
			battles.rewardedToday += 1
			battles.points += vsBot and Battles.BOT_WIN_POINTS or Battles.WIN_POINTS
			rewardText = RewardService.grant(player, data, vsBot and Battles.BotWinReward or Battles.WinReward)
		else
			if not vsBot then
				battles.points += Battles.WIN_POINTS
			end
			rewardText = "лимит наград на сегодня"
		end
		Actions.fire(player, "battleWin", 1)
	else
		battles.losses += 1
		if not vsBot then
			battles.points = math.max(0, battles.points - Battles.LOSS_POINTS)
		end
	end
	DataService.markDirty(player)
	return rewardText
end

local function send(player, opponentName, rounds, won, rewardText, data)
	Remotes.BattleResult:FireClient(player, {
		opponentName = opponentName,
		rounds = rounds,
		won = won,
		reward = rewardText,
		points = data.battles.points,
		rank = Battles.rankFor(data.battles.points),
	})
end

local function canFight(player, data)
	if not data or #data.creatures == 0 then
		Remotes.Notify:FireClient(player, "Нужен хотя бы один брейнрот на базе", BAD)
		return false
	end
	return true
end

local function runPvp(a, b)
	local dataA, dataB = DataService.get(a), DataService.get(b)
	if not dataA or not dataB or #dataA.creatures == 0 or #dataB.creatures == 0 then
		return
	end
	local rounds, aWon = fight(teamOf(dataA), teamOf(dataB))
	local rewardA = settle(a, dataA, aWon, false)
	local rewardB = settle(b, dataB, not aWon, false)
	send(a, b.DisplayName, rounds, aWon, rewardA, dataA)
	send(b, a.DisplayName, flip(rounds), not aWon, rewardB, dataB)
	local winner = aWon and a or b
	local loser = aWon and b or a
	Remotes.Notify:FireAllClients("⚔️ " .. winner.DisplayName .. " победил " .. loser.DisplayName .. " в аура-баттле!", INFO, true)
end

local function challenge(player, target)
	local data = DataService.get(player)
	if not canFight(player, data) then
		return
	end
	local now = os.clock()
	if lastChallenge[player] and now - lastChallenge[player] < Battles.CHALLENGE_COOLDOWN then
		Remotes.Notify:FireClient(player, "Отдышись пару секунд 😮‍💨", BAD)
		return
	end

	if target == "bot" then
		lastChallenge[player] = now
		local team = teamOf(data)
		local rounds, won = fight(team, botTeam(team))
		local rewardText = settle(player, data, won, true)
		send(player, "🤖 Тренер Брейнрот", rounds, won, rewardText, data)
		return
	end

	local other = type(target) == "number" and Players:GetPlayerByUserId(target)
	if not other or other == player then
		return
	end
	local key = math.min(player.UserId, other.UserId) .. ":" .. math.max(player.UserId, other.UserId)
	if lastPair[key] and now - lastPair[key] < Battles.SAME_OPPONENT_COOLDOWN then
		Remotes.Notify:FireClient(player, "С этим игроком можно снова сразиться через минуту", BAD)
		return
	end
	lastChallenge[player] = now
	invites[other] = invites[other] or {}
	invites[other][player.UserId] = now
	Remotes.BattleInvite:FireClient(other, player.UserId, player.DisplayName)
	Remotes.Notify:FireClient(player, "⚔️ Вызов отправлен: " .. other.DisplayName, INFO)
end

local function respond(player, fromUserId, accept)
	local from = type(fromUserId) == "number" and Players:GetPlayerByUserId(fromUserId)
	local sentAt = invites[player] and invites[player][fromUserId]
	if invites[player] then
		invites[player][fromUserId] = nil
	end
	if not from or not sentAt or os.clock() - sentAt > INVITE_TIMEOUT then
		return
	end
	if accept ~= true then
		Remotes.Notify:FireClient(from, player.DisplayName .. " не принял вызов", BAD)
		return
	end
	if not canFight(player, DataService.get(player)) then
		return
	end
	local key = math.min(player.UserId, from.UserId) .. ":" .. math.max(player.UserId, from.UserId)
	lastPair[key] = os.clock()
	runPvp(from, player)
end

function BattleService.snapshot(data)
	return {
		points = data.battles.points,
		wins = data.battles.wins,
		losses = data.battles.losses,
		rank = Battles.rankFor(data.battles.points),
		team = teamOf(data),
		rewardsLeft = data.battles.rewardDay == Daily.today()
				and math.max(0, Battles.REWARDED_PER_DAY - data.battles.rewardedToday)
			or Battles.REWARDED_PER_DAY,
	}
end

function BattleService.init()
	Remotes.BattleChallenge.OnServerEvent:Connect(challenge)
	Remotes.BattleRespond.OnServerEvent:Connect(respond)
	Players.PlayerRemoving:Connect(function(player)
		lastChallenge[player] = nil
		invites[player] = nil
	end)
end

return BattleService
