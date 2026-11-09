-- Achievements. check(data) -> true when done.
-- badgeId is the Roblox badge ID (create it in Creator Dashboard -> Badges), 0 = no badge.

local S = require(script.Parent.Parent.Strings)

local Config = script.Parent
local Creatures = require(Config.Creatures)
local Seasons = require(Config.Seasons)

-- Seasonal brainrots do not count toward "discover them all": they cannot be obtained after the season.
local REGULAR_COUNT = 0
for _, creature in ipairs(Creatures.List) do
	if not creature.season then
		REGULAR_COUNT += 1
	end
end

local function indexCount(data)
	local count = 0
	for id in pairs(data.index) do
		local creature = Creatures.get(id)
		if creature and not creature.season then
			count += 1
		end
	end
	return count
end

local function hasRarity(data, rarityId)
	for _, creature in ipairs(Creatures.ByRarity[rarityId] or {}) do
		if data.index[creature.id] then
			return true
		end
	end
	return false
end

local function stat(data, key)
	return data.stats[key] or 0
end

local Achievements = {}

Achievements.List = {
	{ id = "first", reward = { coinsMinutes = 1 }, check = function(d) return stat(d, "crafted") >= 1 end },
	{ id = "craft100", reward = { coinsMinutes = 5 }, check = function(d) return stat(d, "crafted") >= 100 end },
	{ id = "craft1000", reward = { coinsMinutes = 20, luckMinutes = 10 }, check = function(d) return stat(d, "crafted") >= 1000 end },
	{ id = "index10", reward = { coinsMinutes = 5 }, check = function(d) return indexCount(d) >= 10 end },
	{ id = "index20", reward = { coinsMinutes = 15 }, check = function(d) return indexCount(d) >= 20 end },
	{ id = "indexAll", reward = { coinsMinutes = 60, luckMinutes = 60 }, check = function(d) return indexCount(d) >= REGULAR_COUNT end },
	{ id = "aura", reward = { coinsMinutes = 5 }, check = function(d) return hasRarity(d, "aura") end },
	{ id = "god", reward = { coinsMinutes = 20 }, check = function(d) return hasRarity(d, "god") end },
	{ id = "sixseven", reward = { coinsMinutes = 67, luckMinutes = 67, skin = "sixseven" }, check = function(d) return hasRarity(d, "sixseven") end },
	{ id = "mutant", reward = { coinsMinutes = 3 }, check = function(d) return stat(d, "mutants") >= 1 end },
	{ id = "mutant25", reward = { coinsMinutes = 15 }, check = function(d) return stat(d, "mutants") >= 25 end },
	{ id = "fuse10", reward = { coinsMinutes = 8 }, check = function(d) return stat(d, "fused") >= 10 end },
	{ id = "thief", reward = { coinsMinutes = 5 }, check = function(d) return stat(d, "stolen") >= 1 end },
	{ id = "thief10", reward = { coinsMinutes = 20 }, check = function(d) return stat(d, "stolen") >= 10 end },
	{ id = "defender", reward = { coinsMinutes = 5 }, check = function(d) return stat(d, "thievesSlapped") >= 1 end },
	{ id = "defender10", reward = { coinsMinutes = 20 }, check = function(d) return stat(d, "thievesSlapped") >= 10 end },
	{ id = "wild", reward = { coinsMinutes = 3 }, check = function(d) return stat(d, "wildCaught") >= 1 end },
	{ id = "wild25", reward = { coinsMinutes = 25 }, check = function(d) return stat(d, "wildCaught") >= 25 end },
	{ id = "boss", reward = { coinsMinutes = 10 }, check = function(d) return stat(d, "bossKills") >= 1 end },
	{ id = "boss10", reward = { coinsMinutes = 40, luckMinutes = 30 }, check = function(d) return stat(d, "bossKills") >= 10 end },
	{ id = "battle", reward = { coinsMinutes = 5 }, check = function(d) return (d.battles and d.battles.wins or 0) >= 1 end },
	{ id = "battle25", reward = { coinsMinutes = 30 }, check = function(d) return (d.battles and d.battles.pvpWins or 0) >= 25 end },
	{ id = "auraLegend", reward = { coinsMinutes = 60, luckMinutes = 60 }, check = function(d) return (d.battles and d.battles.points or 0) >= 1500 end },
	{ id = "level10", reward = { coinsMinutes = 5 }, check = function(d) return d.level >= 10 end },
	{ id = "level30", reward = { coinsMinutes = 30 }, check = function(d) return d.level >= 30 end },
	{ id = "rebirth", reward = { luckMinutes = 30 }, check = function(d) return d.rebirths >= 1 end },
	{ id = "rebirth5", reward = { coinsMinutes = 60, luckMinutes = 60 }, check = function(d) return d.rebirths >= 5 end },
	{ id = "million", reward = { coinsMinutes = 5 }, check = function(d) return d.totalEarned >= 1e6 end },
	{ id = "billion", reward = { coinsMinutes = 30 }, check = function(d) return d.totalEarned >= 1e9 end },
	{ id = "trade", reward = { coinsMinutes = 5 }, check = function(d) return stat(d, "trades") >= 1 end },
	{ id = "streak7", reward = { coinsMinutes = 20 }, check = function(d) return d.daily.streak >= 7 end },
}

-- One achievement per season: "get a brainrot of this season".
for _, season in ipairs(Seasons.List) do
	table.insert(Achievements.List, {
		id = "season_" .. season.id,
		nameKey = "season." .. season.id .. ".name",
		name = S.t("season." .. season.id .. ".name"),
		desc = S.t("achievement.season.desc", { season = S.m("season." .. season.id .. ".name") }),
		reward = { coinsMinutes = 10 },
		check = function(d)
			for id in pairs(d.index) do
				local creature = Creatures.get(id)
				if creature and creature.season == season.id then
					return true
				end
			end
			return false
		end,
	})
end

for _, achievement in ipairs(Achievements.List) do
	if not achievement.nameKey then
		S.fill(achievement, "achievement." .. achievement.id, "name", "desc")
	end
	achievement.badgeId = achievement.badgeId or 0
end

return Achievements
