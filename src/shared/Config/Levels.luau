-- Уровни игрока. Опыт даётся за каждый созданный брейнрот (чем реже — тем больше).
-- Уровни открывают новые капсулы и дают титулы.

local Levels = {}

Levels.MAX_LEVEL = 67

-- Сколько опыта нужно, чтобы перейти с уровня level на level + 1.
function Levels.xpToNext(level)
	return math.floor(12 * level ^ 1.5 * 1.12 ^ level)
end

-- Титулы: с какого уровня даётся.
Levels.Titles = {
	{ level = 1, name = "Нуб" },
	{ level = 3, name = "Школьник" },
	{ level = 6, name = "Мемолог" },
	{ level = 10, name = "Тиктокер" },
	{ level = 15, name = "Рилсмейкер" },
	{ level = 22, name = "Вирусный" },
	{ level = 30, name = "Легенда трендов" },
	{ level = 40, name = "Брейнрот-магнат" },
	{ level = 50, name = "Император мемов" },
	{ level = 67, name = "Король 67 🤌" },
}

function Levels.titleFor(level)
	local title = Levels.Titles[1].name
	for _, entry in ipairs(Levels.Titles) do
		if level >= entry.level then
			title = entry.name
		end
	end
	return title
end

return Levels
