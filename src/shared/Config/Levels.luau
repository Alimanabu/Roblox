-- Уровни игрока. Опыт даётся за каждый созданный брейнрот (чем реже — тем больше).
-- Уровни открывают новые капсулы и дают титулы.

local S = require(script.Parent.Parent.Strings)

local Levels = {}

Levels.MAX_LEVEL = 67

-- Сколько опыта нужно, чтобы перейти с уровня level на level + 1.
function Levels.xpToNext(level)
	return math.floor(12 * level ^ 1.5 * 1.12 ^ level)
end

-- Титулы: с какого уровня даётся.
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

-- Сообщение (см. Strings): титул покажет клиент на языке игрока.
function Levels.titleFor(level)
	return S.m(Levels.titleKeyFor(level))
end

return Levels
