-- Income bonuses: friends on the server, joining the game group, Roblox Premium.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Social = require(Shared.Config.Social)

local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)

local SocialService = {}

local inGroup = {} -- [player] = bool
local friendCache = {} -- [player] = { [userId] = bool }
local info = {} -- [player] = { friends, group, premium, bonus }
-- The group bonus is shown and given only after Roblox confirmed that the group of Social.GroupId exists
-- (SocialService.checkGroup). No id, a wrong id, a failed request: no line about the group, nothing is promised.
local groupConfirmed = false

local function hasGroupId()
	return type(Social.GroupId) == "number" and Social.GroupId > 0 and Social.GroupId % 1 == 0
end

function SocialService.groupEnabled()
	return groupConfirmed and hasGroupId()
end

-- Asks Roblox about the group. Confirmed only by an answer that is a group with a name (and, when the answer
-- carries an Id, the same Id); anything else leaves the bonus off. Yields. Returns the new state.
function SocialService.checkGroup()
	local confirmed = false
	if hasGroupId() then
		local ok, result = pcall(function()
			return game:GetService("GroupService"):GetGroupInfoAsync(Social.GroupId)
		end)
		confirmed = ok
			and type(result) == "table"
			and type(result.Name) == "string"
			and result.Name ~= ""
			and (result.Id == nil or result.Id == Social.GroupId)
	end
	groupConfirmed = confirmed
	return SocialService.groupEnabled()
end

local function isFriend(player, other)
	friendCache[player] = friendCache[player] or {}
	local cached = friendCache[player][other.UserId]
	if cached == nil then
		local ok, result = pcall(player.IsFriendsWith, player, other.UserId)
		cached = ok and result == true
		friendCache[player][other.UserId] = cached
	end
	return cached
end

local function update(player)
	local friends = 0
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and isFriend(player, other) then
			friends += 1
		end
	end
	friends = math.min(friends, Social.MAX_FRIENDS)
	local premium = player.MembershipType == Enum.MembershipType.Premium
	local groupEnabled = SocialService.groupEnabled()
	local group = groupEnabled and inGroup[player] == true
	local bonus = friends * Social.FRIEND_BONUS
		+ (group and Social.GROUP_BONUS or 0)
		+ (premium and Social.PREMIUM_BONUS or 0)

	local old = info[player]
	info[player] = { friends = friends, group = group, premium = premium, bonus = bonus, groupEnabled = groupEnabled }
	if not old or old.bonus ~= bonus then
		MonetizationService.setSocialBonus(player, bonus)
	end
	if not old or old.bonus ~= bonus or old.groupEnabled ~= groupEnabled then
		DataService.markDirty(player)
	end
end

function SocialService.snapshot(player)
	return info[player] or { friends = 0, group = false, premium = false, bonus = 0, groupEnabled = SocialService.groupEnabled() }
end

-- Asks Roblox whether the player is in the group (only when there is a confirmed group to ask about).
local function refreshGroup(player)
	if SocialService.groupEnabled() and not inGroup[player] then
		local ok, result = pcall(player.IsInGroup, player, Social.GroupId)
		inGroup[player] = ok and result == true
	end
end

-- One pass of the safeguard: joined the group or bought Premium right in the game; the group request that failed
-- at the start is asked again.
function SocialService.refresh()
	if hasGroupId() and not groupConfirmed then
		SocialService.checkGroup()
	end
	for _, player in ipairs(Players:GetPlayers()) do
		refreshGroup(player)
		task.spawn(update, player)
	end
end

function SocialService.init()
	local function onJoin(player)
		task.spawn(function()
			refreshGroup(player)
			update(player)
		end)
		for _, other in ipairs(Players:GetPlayers()) do
			task.spawn(update, other)
		end
	end
	if hasGroupId() then
		task.spawn(SocialService.refresh)
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, player in ipairs(Players:GetPlayers()) do
		onJoin(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		inGroup[player] = nil
		friendCache[player] = nil
		info[player] = nil
		task.defer(function()
			for _, other in ipairs(Players:GetPlayers()) do
				task.spawn(update, other)
			end
		end)
	end)
	task.spawn(function()
		while true do
			task.wait(60)
			SocialService.refresh()
		end
	end)
end

return SocialService
