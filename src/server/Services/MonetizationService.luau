-- Геймпассы и разовые покупки за Robux.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local S = require(Shared.Strings)
local Monetization = require(Shared.Config.Monetization)
local Formulas = require(Shared.Util.Formulas)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local PolicyService = require(script.Parent.PolicyService)

local MonetizationService = {}

-- Геймпассы игрока изменились: база могла вырасти (см. PlotService).
MonetizationService.PassesChanged = Instance.new("BindableEvent")

local PASS_CHECK_ATTEMPTS = 4
local PASS_RECHECK_INTERVAL = 60

local ownedPasses = {} -- [player] = { VIP = true, ... }
local uncheckedPasses = {} -- [player] = { VIP = true, ... }: Roblox не ответил, проверим ещё раз

function MonetizationService.passes(player)
	return ownedPasses[player] or {}
end

-- Удача, с которой сервер бросает шансы. Все броски и показ шансов идут через неё.
function MonetizationService.luck(player, data, now, mods)
	return Formulas.luck(data, MonetizationService.passes(player), now, mods, PolicyService.paidRandomRestricted(player))
end

-- Сбой запроса не значит «не куплено»: нет ответа Roblox, значит nil, а не false.
local function ownsPass(player, pass, attempts)
	for attempt = 1, attempts do
		local ok, result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
		if ok then
			return result
		end
		warn("[MonetizationService] Не удалось проверить геймпасс", pass.key, "у", player.Name, "попытка", attempt, result)
		if attempt < attempts then
			task.wait(attempt * 1.5)
		end
		if not player.Parent then
			return nil
		end
	end
	return nil
end

local function refreshPasses(player)
	-- Дополняем таблицу, а не заменяем: пока идут повторы, игрок мог купить геймпасс,
	-- а ещё в ней хранится бонус за друзей.
	local owned = ownedPasses[player] or {}
	ownedPasses[player] = owned
	for _, pass in ipairs(Monetization.GamePasses) do
		if pass.id ~= 0 and player.Parent then
			local result = ownsPass(player, pass, PASS_CHECK_ATTEMPTS)
			if result then
				owned[pass.key] = true
			elseif result == nil and player.Parent then
				uncheckedPasses[player] = uncheckedPasses[player] or {}
				uncheckedPasses[player][pass.key] = true
			end
		end
	end
	if player.Parent then
		DataService.markDirty(player)
		MonetizationService.PassesChanged:Fire(player)
	end
end

-- Фоновая проверка геймпассов, на которые Roblox не ответил при входе. Запрос один:
-- следующая попытка всё равно будет через PASS_RECHECK_INTERVAL. Геймпасс только
-- добавляется, поэтому никакой ответ не снимает уже выданное.
local function recheckPasses(player)
	local unchecked = uncheckedPasses[player]
	if not unchecked then
		return
	end
	local changed = false
	for _, pass in ipairs(Monetization.GamePasses) do
		if unchecked[pass.key] and player.Parent then
			local result = ownsPass(player, pass, 1)
			if result ~= nil then
				unchecked[pass.key] = nil
			end
			local owned = ownedPasses[player]
			if result and owned and not owned[pass.key] then
				owned[pass.key] = true
				changed = true
			end
		end
	end
	if next(unchecked) == nil and uncheckedPasses[player] == unchecked then
		uncheckedPasses[player] = nil
	end
	if changed and player.Parent then
		DataService.markDirty(player)
		MonetizationService.PassesChanged:Fire(player)
	end
end

function MonetizationService.setSocialBonus(player, bonus)
	if not player.Parent then
		return
	end
	ownedPasses[player] = ownedPasses[player] or {}
	ownedPasses[player].socialBonus = bonus > 0 and bonus or nil
end

-- Выдаёт содержимое разовой покупки. Возвращает true, если выдали.
local function grantProduct(player, data, product)
	if product.kind == "luckBoost" then
		local now = os.time()
		data.boosts.luckUntil = math.max(data.boosts.luckUntil or 0, now) + product.minutes * 60
		Remotes.Notify:FireClient(player, S.m("shop.luck_boost_on"), Color3.fromRGB(120, 255, 120))
		return true
	elseif product.kind == "spins" then
		data.wheel.extraSpins += product.amount
		Remotes.Notify:FireClient(player, S.m("shop.spins_added", { count = product.amount }), Color3.fromRGB(120, 255, 120))
		return true
	elseif product.kind == "coins" then
		local income = Formulas.totalIncome(data, MonetizationService.passes(player))
		local amount = math.max(product.minCoins, math.floor(income * 60 * product.incomeMinutes))
		data.coins += amount
		data.totalEarned += amount
		Remotes.Notify:FireClient(player, "💰 +" .. Format.coins(amount), Color3.fromRGB(255, 220, 80))
		return true
	end
	return false
end

local function processReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local product = Monetization.ProductById[receiptInfo.ProductId]
	if product and product.leadsToRandom then
		PolicyService.awaitAnswer(player)
	end
	local data = DataService.get(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local receiptId = tostring(receiptInfo.PurchaseId)
	if not DataService.hasReceipt(data, receiptId) then
		if not product then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		-- Кнопки скрывает клиент, но окно покупки читер откроет сам. Покупку не подтверждаем:
		-- ответ PolicyService мог быть сбоем, тогда чек выдастся при следующем заходе.
		if product.leadsToRandom and PolicyService.paidRandomRestricted(player) then
			Remotes.Notify:FireClient(player, S.m("shop.region"), Color3.fromRGB(255, 110, 110))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if not grantProduct(player, data, product) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		DataService.addReceipt(data, receiptId)
		DataService.markDirty(player)
	end

	-- Подтверждаем покупку Roblox только после успешного сохранения: если сервер
	-- упадёт раньше, Roblox повторит выдачу на следующем заходе. Повторный чек тоже
	-- сохраняем: уже выдано не значит уже записано, прошлое сохранение могло не пройти.
	if not DataService.save(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.init()
	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased then
			for _, pass in ipairs(Monetization.GamePasses) do
				if pass.id == passId then
					ownedPasses[player] = ownedPasses[player] or {}
					ownedPasses[player][pass.key] = true
					if pass.leadsToRandom and PolicyService.paidRandomRestricted(player) then
						Remotes.Notify:FireClient(player, S.m("shop.region"), Color3.fromRGB(255, 110, 110))
					else
						Remotes.Notify:FireClient(player, S.m("shop.purchased", { name = S.m("pass." .. pass.key .. ".name") }), Color3.fromRGB(120, 255, 120))
					end
				end
			end
			DataService.markDirty(player)
			MonetizationService.PassesChanged:Fire(player)
		end
	end)

	Players.PlayerAdded:Connect(refreshPasses)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(refreshPasses, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		ownedPasses[player] = nil
		uncheckedPasses[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(PASS_RECHECK_INTERVAL)
			for player in pairs(uncheckedPasses) do
				task.spawn(recheckPasses, player)
			end
		end
	end)
end

return MonetizationService
