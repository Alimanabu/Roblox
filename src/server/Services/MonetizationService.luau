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

local ownedPasses = {} -- [player] = { VIP = true, ... }

function MonetizationService.passes(player)
	return ownedPasses[player] or {}
end

local function refreshPasses(player)
	local owned = {}
	for _, pass in ipairs(Monetization.GamePasses) do
		if pass.id ~= 0 then
			local ok, has = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
			if ok and has then
				owned[pass.key] = true
			end
		end
	end
	-- Бонус за друзей хранится в той же таблице — не теряем его при обновлении.
	owned.socialBonus = ownedPasses[player] and ownedPasses[player].socialBonus or nil
	ownedPasses[player] = owned
	DataService.markDirty(player)
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
	if DataService.hasReceipt(data, receiptId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local product = Monetization.ProductById[receiptInfo.ProductId]
	if not product or not grantProduct(player, data, product) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	DataService.addReceipt(data, receiptId)
	DataService.markDirty(player)
	-- Подтверждаем покупку Roblox только после успешного сохранения: если сервер
	-- упадёт раньше, Roblox повторит выдачу на следующем заходе.
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
