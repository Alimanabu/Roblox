-- Бонусы к доходу: друзья на сервере, участие в группе игры, Roblox Premium.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Social = require(Shared.Config.Social)

local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)

local SocialService = {}

local inGroup = {} -- [player] = bool
local friendCache = {} -- [player] = { [userId] = bool }
local info = {} -- [player] = { friends, group, premium, bonus }

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
	local group = inGroup[player] == true
	local bonus = friends * Social.FRIEND_BONUS
		+ (group and Social.GROUP_BONUS or 0)
		+ (premium and Social.PREMIUM_BONUS or 0)

	local old = info[player]
	info[player] = { friends = friends, group = group, premium = premium, bonus = bonus, groupEnabled = Social.GroupId ~= 0 }
	if not old or old.bonus ~= bonus then
		MonetizationService.setSocialBonus(player, bonus)
		DataService.markDirty(player)
	end
end

function SocialService.snapshot(player)
	return info[player] or { friends = 0, group = false, premium = false, bonus = 0, groupEnabled = Social.GroupId ~= 0 }
end

function SocialService.init()
	local function onJoin(player)
		if Social.GroupId ~= 0 then
			task.spawn(function()
				local ok, result = pcall(player.IsInGroup, player, Social.GroupId)
				inGroup[player] = ok and result == true
				update(player)
			end)
		end
		for _, other in ipairs(Players:GetPlayers()) do
			task.spawn(update, other)
		end
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
	-- Подстраховка: вступил в группу или купил Premium прямо в игре.
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in ipairs(Players:GetPlayers()) do
				if Social.GroupId ~= 0 and not inGroup[player] then
					local ok, result = pcall(player.IsInGroup, player, Social.GroupId)
					inGroup[player] = ok and result == true
				end
				task.spawn(update, player)
			end
		end
	end)
end

return SocialService
