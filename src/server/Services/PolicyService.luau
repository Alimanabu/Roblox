-- Региональные правила Roblox (PolicyService). В некоторых странах законы запрещают:
--   • платные случайные награды (ArePaidRandomItemsRestricted) — тогда сервер не выдаёт
--     за Robux монеты, вращения и буст удачи (монеты идут на капсулы со случайным результатом),
--     не тратит купленные вращения, а геймпасс LUCKY не влияет на шансы;
--   • обмен платными предметами (IsPaidItemTradingAllowed = false) — тогда отключаем обмен.
-- Результат пишем атрибутами на игрока, чтобы его видел и клиент (скрыть кнопки).
-- Roblox не ответил: ограничения включены, но атрибут PolicyUnknown говорит, что это не решение
-- о регионе. Спрашиваем в фоне, а игрок до ответа видит «проверяем».

local Players = game:GetService("Players")
local RobloxPolicy = game:GetService("PolicyService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local S = require(Shared.Strings)

local DataService = require(script.Parent.DataService)

local PolicyService = {}

local LOAD_ATTEMPTS = 3
local ANSWER_WAIT = 10 -- дольше всех попыток: паузы 1 + 2 с плюс сами запросы
local RECHECK_INTERVAL = 60

local unanswered = {} -- [player] = true: Roblox не ответил, спросим ещё раз

local function apply(player, info)
	player:SetAttribute("PaidRandomItemsRestricted", info.ArePaidRandomItemsRestricted == true)
	player:SetAttribute("PaidItemTradingAllowed", info.IsPaidItemTradingAllowed ~= false)
	player:SetAttribute("PolicyUnknown", nil)
	unanswered[player] = nil
end

local function load(player)
	local ok, info
	for attempt = 1, LOAD_ATTEMPTS do
		ok, info = pcall(RobloxPolicy.GetPolicyInfoForPlayerAsync, RobloxPolicy, player)
		if ok and type(info) == "table" then
			break
		end
		warn("[PolicyService] Нет ответа Roblox о правилах для", player.Name, "попытка", attempt, info)
		if attempt < LOAD_ATTEMPTS then
			task.wait(attempt)
		end
		if not player.Parent then
			return
		end
	end
	if not player.Parent then
		return
	end
	if ok and type(info) == "table" then
		apply(player, info)
	else
		-- Не удалось узнать — перестраховываемся: ограничения включены.
		player:SetAttribute("PaidRandomItemsRestricted", true)
		player:SetAttribute("PaidItemTradingAllowed", false)
		player:SetAttribute("PolicyUnknown", true)
		unanswered[player] = true
	end
end

-- Фоновая проверка: запрос один, следующая попытка всё равно через RECHECK_INTERVAL.
local function recheck(player)
	local ok, info = pcall(RobloxPolicy.GetPolicyInfoForPlayerAsync, RobloxPolicy, player)
	if ok and type(info) == "table" and unanswered[player] and player.Parent then
		apply(player, info)
		DataService.markDirty(player)
	end
end

function PolicyService.paidRandomRestricted(player)
	return player:GetAttribute("PaidRandomItemsRestricted") ~= false
end

-- Ответа Roblox пока нет: ограничения действуют, но это ещё не запрет региона.
function PolicyService.pending(player)
	return player:GetAttribute("PaidRandomItemsRestricted") == nil or player:GetAttribute("PolicyUnknown") == true
end

-- Текст отказа из-за этого игрока. Пока ответа нет, отказ не называем запретом.
function PolicyService.message(player, key, args)
	return if PolicyService.pending(player) then S.m("policy.checking") else S.m(key, args)
end

-- Чек может прийти раньше ответа Roblox (повтор при входе): его нельзя считать отказом,
-- поэтому ждём ответ. Если ответа так и нет, paidRandomRestricted остаётся true.
function PolicyService.awaitAnswer(player)
	local waited = 0
	while player.Parent and player:GetAttribute("PaidRandomItemsRestricted") == nil and waited < ANSWER_WAIT do
		task.wait(0.1)
		waited += 0.1
	end
end

function PolicyService.tradingAllowed(player)
	return player:GetAttribute("PaidItemTradingAllowed") == true
end

function PolicyService.init()
	Players.PlayerAdded:Connect(load)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		unanswered[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(RECHECK_INTERVAL)
			for player in pairs(unanswered) do
				task.spawn(recheck, player)
			end
		end
	end)
end

return PolicyService
