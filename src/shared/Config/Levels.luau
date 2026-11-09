-- Player levels. XP is given for every brainrot created (the rarer, the more).
-- Levels unlock new capsules and give titles.

local S = require(script.Parent.Parent.Strings)

local Levels = {}

Levels.MAX_LEVEL = 67

-- How much XP is needed to go from level level to level + 1.
function Levels.xpToNext(level)
	return math.floor(12 * level ^ 1.5 * 1.12 ^ level)
end

-- Titles: the level from which each is given.
Levels.Titles = {
	{ level = 1 },
	{ level = 3 },
	{ level = 6 },
	{ level = 10 },
	{ level = 15 },
	{ level = 22 },
	{ level = 30 },
	{ level = 40 },
	{ level = 50 },
	{ level = 67 },
}

function Levels.titleKeyFor(level)
	local reached = Levels.Titles[1].level
	for _, entry in ipairs(Levels.Titles) do
		if level >= entry.level then
			reached = entry.level
		end
	end
	return "level." .. reached .. ".name"
end

-- Message (see Strings): the client shows the title in the player's language.
function Levels.titleFor(level)
	return S.m(Levels.titleKeyFor(level))
end

return Levels
