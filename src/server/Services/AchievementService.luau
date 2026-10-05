-- Достижения: проверяем условия, выдаём награды и бейджи Roblox.

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Achievements = require(Shared.Config.Achievements)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local RewardService = require(script.Parent.RewardService)
local Actions = require(script.Parent.Actions)

local AchievementService = {}

local GOLD = Color3.fromRGB(255, 220, 80)

local function awardBadge(player, badgeId)
	if badgeId == 0 then
		return
	end
	task.spawn(function()
		local ok, has = pcall(BadgeService.UserHasBadgeAsync, BadgeService, player.UserId, badgeId)
		if ok and not has then
			pcall(BadgeService.AwardBadge, BadgeService, player.UserId, badgeId)
		end
	end)
end

function AchievementService.check(player)
	local data = DataService.get(player)
	if not data then
		return
	end
	for _, achievement in ipairs(Achievements.List) do
		if not data.achievements[achievement.id] then
			local ok, done = pcall(achievement.check, data)
			if ok and done then
				data.achievements[achievement.id] = true
				local text = RewardService.grant(player, data, achievement.reward)
				Remotes.Notify:FireClient(player, "🏆 Достижение «" .. achievement.name .. "»! " .. text, GOLD)
				Remotes.Sfx:FireClient(player, "levelup")
				awardBadge(player, achievement.badgeId)
				DataService.markDirty(player)
			end
		end
	end
end

function AchievementService.snapshot(data)
	local count = 0
	for _ in pairs(data.achievements) do
		count += 1
	end
	return { unlocked = data.achievements, count = count, total = #Achievements.List }
end

function AchievementService.init()
	-- Статистики, которых нет в других сервисах, считаем здесь.
	Actions.connect(function(player, kind, amount)
		local data = DataService.get(player)
		if not data then
			return
		end
		if kind == "mutant" then
			data.stats.mutants = (data.stats.mutants or 0) + amount
		elseif kind == "slapThief" then
			data.stats.thievesSlapped = (data.stats.thievesSlapped or 0) + amount
		end
		task.defer(AchievementService.check, player)
	end)

	-- Монеты, уровни и т.п. меняются постоянно — проверяем раз в несколько секунд.
	task.spawn(function()
		while true do
			task.wait(5)
			for _, player in ipairs(Players:GetPlayers()) do
				AchievementService.check(player)
			end
		end
	end)
end

return AchievementService
