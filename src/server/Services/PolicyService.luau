-- Региональные правила Roblox (PolicyService). В некоторых странах законы запрещают:
--   • платные случайные награды (ArePaidRandomItemsRestricted) — тогда сервер не выдаёт
--     за Robux монеты, вращения и буст удачи (монеты идут на капсулы со случайным результатом),
--     не тратит купленные вращения, а геймпасс LUCKY не влияет на шансы;
--   • обмен платными предметами (IsPaidItemTradingAllowed = false) — тогда отключаем обмен.
-- Результат пишем атрибутами на игрока, чтобы его видел и клиент (скрыть кнопки).

local Players = game:GetService("Players")
local RobloxPolicy = game:GetService("PolicyService")

local PolicyService = {}

local LOAD_ATTEMPTS = 3
local ANSWER_WAIT = 10 -- дольше всех попыток: паузы 1 + 2 с плюс сами запросы

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
		player:SetAttribute("PaidRandomItemsRestricted", info.ArePaidRandomItemsRestricted == true)
		player:SetAttribute("PaidItemTradingAllowed", info.IsPaidItemTradingAllowed ~= false)
	else
		-- Не удалось узнать — перестраховываемся: ограничения включены.
		player:SetAttribute("PaidRandomItemsRestricted", true)
		player:SetAttribute("PaidItemTradingAllowed", false)
	end
end

function PolicyService.paidRandomRestricted(player)
	return player:GetAttribute("PaidRandomItemsRestricted") ~= false
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
end

return PolicyService
