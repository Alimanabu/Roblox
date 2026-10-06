-- Региональные правила Roblox (PolicyService). В некоторых странах законы запрещают:
--   • платные случайные награды (ArePaidRandomItemsRestricted) — тогда не продаём
--     за Robux монеты и вращения колеса (монеты идут на капсулы со случайным результатом);
--   • обмен платными предметами (IsPaidItemTradingAllowed = false) — тогда отключаем обмен.
-- Результат пишем атрибутами на игрока, чтобы его видел и клиент (скрыть кнопки).

local Players = game:GetService("Players")
local RobloxPolicy = game:GetService("PolicyService")

local PolicyService = {}

local function load(player)
	local ok, info = pcall(RobloxPolicy.GetPolicyInfoForPlayerAsync, RobloxPolicy, player)
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
