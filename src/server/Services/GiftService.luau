-- Gifts for time in game: the longer you play in a day, the better the gifts.
-- The time is summed over all sessions of the UTC day and saved with the profile, so leaving and
-- coming back neither resets the timer nor hands out the same gift again.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local S = require(Shared.Strings)
local Daily = require(Shared.Config.Daily)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local RewardService = require(script.Parent.RewardService)

local GiftService = {}

local GOLD = Color3.fromRGB(255, 220, 80)
local BAD = Color3.fromRGB(255, 110, 110)

-- [player] = os.time() up to which the time is already counted. Weak keys: the final save of a leaving
-- player still needs its entry, and a rejoin is a new Player object.
local lastTick = setmetatable({}, { __mode = "k" })

-- Adds the time since the last call to today's total. A new UTC day starts from zero: the time
-- before midnight is not carried over, the time after it counts.
local function accrue(player, data)
	local now = os.time()
	local today = Daily.today(now)
	local playtime = data.playtime
	local from = lastTick[player] or now
	lastTick[player] = now
	if playtime.day ~= today then
		playtime.day = today
		playtime.seconds = 0
		playtime.claimed = {}
		from = math.max(from, today * 86400)
	end
	playtime.seconds += math.max(0, now - from)
end

local function claimGift(player, index)
	local data = DataService.get(player)
	local gift = type(index) == "number" and Daily.Gifts[index]
	if not data or not gift then
		return
	end
	accrue(player, data)
	local key = tostring(index)
	if data.playtime.claimed[key] then
		return
	end
	if data.playtime.seconds < gift.minutes * 60 then
		Remotes.Notify:FireClient(player, S.m("gift.not_ready"), BAD)
		return
	end
	data.playtime.claimed[key] = true
	local text = RewardService.grant(player, data, gift.reward)
	Remotes.Notify:FireClient(player, S.m("gift.claimed", { minutes = gift.minutes, reward = text }), GOLD)
	Remotes.Sfx:FireClient(player, "coins")
	DataService.markDirty(player)
end

-- start is "the moment the counting would have begun if the player had not left today":
-- the client counts the minutes as (now - start), so it needs no changes.
function GiftService.snapshot(player, data)
	accrue(player, data)
	local gifts = {}
	for index, gift in ipairs(Daily.Gifts) do
		gifts[index] = {
			minutes = gift.minutes,
			reward = RewardService.describe(player, data, gift.reward),
			claimed = data.playtime.claimed[tostring(index)] == true,
		}
	end
	return { start = workspace:GetServerTimeNow() - data.playtime.seconds, gifts = gifts }
end

function GiftService.init()
	-- The last seconds before leaving are counted by the final save itself.
	DataService.onBeforeSave(accrue)
	Remotes.ClaimGift.OnServerEvent:Connect(claimGift)
end

return GiftService
