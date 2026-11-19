-- Promo codes.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local S = require(Shared.Strings)
local Codes = require(Shared.Config.Codes)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local RewardService = require(script.Parent.RewardService)

local CodeService = {}

local GOOD = Color3.fromRGB(120, 255, 120)
local BAD = Color3.fromRGB(255, 110, 110)
local ATTEMPT_COOLDOWN = 2

local lastAttempt = {} -- [player] = os.clock()

-- A code is given out only when its entry is a table with enabled exactly true and, when it has a date, a number
-- that has not passed. Everything else (no entry, enabled missing or of another kind, a broken date) is refused.
function CodeService.active(reward, now)
	if type(reward) ~= "table" or reward.enabled ~= true then
		return false
	end
	if reward.expires ~= nil and (type(reward.expires) ~= "number" or now > reward.expires) then
		return false
	end
	return true
end

local function redeem(player, text)
	if type(text) ~= "string" or #text > 40 then
		return
	end
	local now = os.clock()
	if lastAttempt[player] and now - lastAttempt[player] < ATTEMPT_COOLDOWN then
		Remotes.Notify:FireClient(player, S.m("common.wait"), BAD)
		return
	end
	lastAttempt[player] = now

	local data = DataService.get(player)
	if not data then
		return
	end
	local code = string.upper((text:gsub("%s", "")))
	local reward = Codes[code]
	if not CodeService.active(reward, os.time()) then
		Remotes.Notify:FireClient(player, S.m("code.invalid"), BAD)
		return
	end
	if data.codes[code] then
		Remotes.Notify:FireClient(player, S.m("code.used"), BAD)
		return
	end
	data.codes[code] = true
	local result = RewardService.grant(player, data, reward)
	Remotes.Notify:FireClient(player, S.m("code.redeemed", { code = code, reward = result, text = if reward.textKey then S.m(reward.textKey) else reward.text or "" }), GOOD)
	Remotes.Sfx:FireClient(player, "coins")
	DataService.markDirty(player)
end

function CodeService.init()
	Remotes.RedeemCode.OnServerEvent:Connect(redeem)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastAttempt[player] = nil
	end)
end

return CodeService
