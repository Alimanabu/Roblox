-- Геймпассы и разовые покупки за Robux.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Monetization = require(Shared.Config.Monetization)
local Formulas = require(Shared.Util.Formulas)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)

local MonetizationService = {}

-- Геймпассы игрока изменились: база могла вырасти (см. PlotService).
MonetizationService.PassesChanged = Instance.new("BindableEvent")

local PASS_CHECK_ATTEMPTS = 4

local ownedPasses = {} -- [player] = { VIP = true, ... }

function MonetizationService.passes(player)
	return ownedPasses[player] or {}
end

-- Сбой запроса не значит «не куплено»: без повтора купленный геймпасс пропал бы до перезахода.
local function ownsPass(player, pass)
	for attempt = 1, PASS_CHECK_ATTEMPTS do
		local ok, result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
		if ok then
			return result
		end
		warn("[MonetizationService] Не удалось проверить геймпасс", pass.key, "у", player.Name, "попытка", attempt, result)
		if attempt < PASS_CHECK_ATTEMPTS then
			task.wait(attempt * 1.5)
		end
		if not player.Parent then
			return false
		end
	end
	return false
end

local function refreshPasses(player)
	-- Дополняем таблицу, а не заменяем: пока идут повторы, игрок мог купить геймпасс,
	-- а ещё в ней хранится бонус за друзей.
	local owned = ownedPasses[player] or {}
	ownedPasses[player] = owned
	for _, pass in ipairs(Monetization.GamePasses) do
		if pass.id ~= 0 and player.Parent and ownsPass(player, pass) then
			owned[pass.key] = true
		end
	end
	if player.Parent then
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
		Remotes.Notify:FireClient(player, "🍀 Буст удачи x2 активирован!", Color3.fromRGB(120, 255, 120))
		return true
	elseif product.kind == "spins" then
		data.wheel.extraSpins += product.amount
		Remotes.Notify:FireClient(player, "🎡 +" .. product.amount .. " вращения колеса!", Color3.fromRGB(120, 255, 120))
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
	local data = DataService.get(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local receiptId = tostring(receiptInfo.PurchaseId)
	if not DataService.hasReceipt(data, receiptId) then
		local product = Monetization.ProductById[receiptInfo.ProductId]
		if not product or not grantProduct(player, data, product) then
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
					Remotes.Notify:FireClient(player, "✅ Куплено: " .. pass.name, Color3.fromRGB(120, 255, 120))
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
	end)
end

return MonetizationService
