-- Подарки за время в игре: чем дольше играешь за один заход, тем круче подарки.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Daily = require(Shared.Config.Daily)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local RewardService = require(script.Parent.RewardService)

local GiftService = {}

local GOLD = Color3.fromRGB(255, 220, 80)
local BAD = Color3.fromRGB(255, 110, 110)

local sessionStart = {} -- [player] = workspace:GetServerTimeNow() при заходе
local claimed = {} -- [player] = { [index] = true }

local function elapsedMinutes(player)
	return (workspace:GetServerTimeNow() - (sessionStart[player] or math.huge)) / 60
end

local function claimGift(player, index)
	local data = DataService.get(player)
	local gift = type(index) == "number" and Daily.Gifts[index]
	if not data or not gift or not claimed[player] then
		return
	end
	if claimed[player][index] then
		return
	end
	if elapsedMinutes(player) < gift.minutes then
		Remotes.Notify:FireClient(player, "Этот подарок ещё не готов ⏰", BAD)
		return
	end
	claimed[player][index] = true
	local text = RewardService.grant(player, data, gift.reward)
	Remotes.Notify:FireClient(player, "🎁 Подарок за " .. gift.minutes .. " мин: " .. text, GOLD)
	Remotes.Sfx:FireClient(player, "coins")
	DataService.markDirty(player)
end

function GiftService.snapshot(player, data)
	local gifts = {}
	for index, gift in ipairs(Daily.Gifts) do
		gifts[index] = {
			minutes = gift.minutes,
			reward = RewardService.describe(player, data, gift.reward),
			claimed = claimed[player] ~= nil and claimed[player][index] == true,
		}
	end
	return { start = sessionStart[player] or workspace:GetServerTimeNow(), gifts = gifts }
end

function GiftService.init()
	local function onJoin(player)
		sessionStart[player] = workspace:GetServerTimeNow()
		claimed[player] = {}
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, player in ipairs(Players:GetPlayers()) do
		onJoin(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		sessionStart[player] = nil
		claimed[player] = nil
	end)
	Remotes.ClaimGift.OnServerEvent:Connect(claimGift)
end

return GiftService
