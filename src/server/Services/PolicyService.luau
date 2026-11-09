-- Roblox regional rules (PolicyService). In some countries laws forbid:
-- - paid random rewards (ArePaidRandomItemsRestricted): then the server does not give out for Robux
-- coins, spins and luck boost (coins go to capsules with a random result),
-- does not spend bought spins, and the LUCKY game pass does not affect the odds;
-- - trading paid items (IsPaidItemTradingAllowed = false): then we turn trading off.
-- We write the result as attributes on the player so the client sees it too (to hide buttons).
-- Roblox did not answer: the restrictions are on, but the attribute PolicyUnknown says this is not a decision
-- about the region. We ask in the background, and until the answer the player sees "checking".

local Players = game:GetService("Players")
local RobloxPolicy = game:GetService("PolicyService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local S = require(Shared.Strings)

local DataService = require(script.Parent.DataService)

local PolicyService = {}

local LOAD_ATTEMPTS = 3
local ANSWER_WAIT = 10 -- longer than all the attempts: pauses 1 + 2 s plus the requests themselves
local RECHECK_INTERVAL = 60

local unanswered = {} -- [player] = true: Roblox did not answer, we will ask again

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
		warn("[PolicyService] No answer from Roblox about policies for", player.Name, "attempt", attempt, info)
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
		-- Could not find out: playing safe, the restrictions are on.
		player:SetAttribute("PaidRandomItemsRestricted", true)
		player:SetAttribute("PaidItemTradingAllowed", false)
		player:SetAttribute("PolicyUnknown", true)
		unanswered[player] = true
	end
end

-- Background check: one request, the next attempt will be after RECHECK_INTERVAL anyway.
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

-- No answer from Roblox yet: the restrictions apply, but this is not yet a region ban.
function PolicyService.pending(player)
	return player:GetAttribute("PaidRandomItemsRestricted") == nil or player:GetAttribute("PolicyUnknown") == true
end

-- Refusal text because of this player. Until there is an answer, we do not call the refusal a ban.
function PolicyService.message(player, key, args)
	return if PolicyService.pending(player) then S.m("policy.checking") else S.m(key, args)
end

-- A receipt may arrive before the Roblox answer (a repeat on join): it must not be treated as a refusal,
-- so we wait for the answer. If there is still none, paidRandomRestricted stays true.
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
