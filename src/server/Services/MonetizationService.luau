-- Game passes and one-time purchases for Robux.

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

-- The player's game passes changed: the base may have grown (see PlotService).
MonetizationService.PassesChanged = Instance.new("BindableEvent")

local PASS_CHECK_ATTEMPTS = 4
local PASS_RECHECK_INTERVAL = 60

local ownedPasses = {} -- [player] = { VIP = true, ... }
local uncheckedPasses = {} -- [player] = { VIP = true, ... }: Roblox did not answer, we will check again

function MonetizationService.passes(player)
	return ownedPasses[player] or {}
end

-- The luck the server rolls the odds with. All rolls and odds displays go through it.
function MonetizationService.luck(player, data, now, mods)
	return Formulas.luck(data, MonetizationService.passes(player), now, mods, PolicyService.paidRandomRestricted(player))
end

-- Whether bought luck went into the roll: the brainrot's mark depends on it (Formulas.isPaidRandom).
function MonetizationService.paidLuck(player, data, now)
	return Formulas.usesPaidLuck(data, MonetizationService.passes(player), now, PolicyService.paidRandomRestricted(player))
end

-- A failed request does not mean "not purchased": no answer from Roblox means nil, not false.
local function ownsPass(player, pass, attempts)
	for attempt = 1, attempts do
		local ok, result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
		if ok then
			return result
		end
		warn("[MonetizationService] Failed to check game pass", pass.key, "for", player.Name, "attempt", attempt, result)
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
	-- We add to the table instead of replacing it: while retries run, the player may have bought a game pass,
	-- and the friend bonus is also stored there.
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

-- Background check of game passes that Roblox did not answer at join. One request:
-- the next attempt will be after PASS_RECHECK_INTERVAL anyway. A game pass is only
-- added, so no answer removes what was already granted.
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

-- Grants the contents of a one-time purchase. Returns true if granted.
local function grantProduct(player, data, product)
	if product.kind == "luckBoost" then
		local now = os.time()
		data.boosts.luckUntil = math.max(data.boosts.luckUntil or 0, now) + product.minutes * 60
		data.boosts.paidLuckUntil = data.boosts.luckUntil
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
		data.boughtCoins += amount
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
		-- The client hides the buttons, but a cheater can open the purchase prompt themselves. We do not confirm the purchase:
		-- the PolicyService answer may have been a failure, then the receipt is granted on the next join.
		if product.leadsToRandom and PolicyService.paidRandomRestricted(player) then
			Remotes.Notify:FireClient(player, PolicyService.message(player, "shop.region"), Color3.fromRGB(255, 110, 110))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if not grantProduct(player, data, product) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		DataService.addReceipt(data, receiptId)
		DataService.markDirty(player)
	end

	-- We confirm the purchase to Roblox only after a successful save: if the server
	-- crashes earlier, Roblox repeats the grant on the next join. A repeated receipt is also
	-- saved: already granted does not mean already written, the previous save may have failed.
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
						Remotes.Notify:FireClient(player, PolicyService.message(player, "shop.region"), Color3.fromRGB(255, 110, 110))
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
