-- Перерождения: сбрасывают монеты, брейнротов и улучшения,
-- но навсегда дают множитель дохода, удачу и крутой титул.
-- Уровень игрока и Индекс брейнротов сохраняются.

local Rebirths = {}

Rebirths.INCOME_BONUS = 0.5 -- +50% дохода за каждое перерождение
Rebirths.LUCK_BONUS = 0.1 -- +10% удачи за каждое перерождение

Rebirths.Titles = {
	"Сигма",
	"Альфа",
	"Гигачад",
	"Аура-фармер",
	"Огайо Финальный Босс",
	"Брейнрот-Император",
	"Легенда 67 🤌",
	"Мем-Божество",
	"Повелитель Брейнрота",
	"АБСОЛЮТНЫЙ 67 🤌🤌",
}

function Rebirths.cost(rebirths)
	return math.floor(50000000 * 12 ^ rebirths)
end

function Rebirths.levelRequired(rebirths)
	return 20 + rebirths * 5
end

function Rebirths.titleFor(rebirths)
	if rebirths <= 0 then
		return nil
	end
	return Rebirths.Titles[math.min(rebirths, #Rebirths.Titles)]
end

return Rebirths
