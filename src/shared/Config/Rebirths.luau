-- Перерождения: сбрасывают монеты, брейнротов и улучшения,
-- но навсегда дают множитель дохода, удачу и крутой титул.
-- Уровень игрока и Индекс брейнротов сохраняются.

local S = require(script.Parent.Parent.Strings)

local Rebirths = {}

Rebirths.INCOME_BONUS = 0.5 -- +50% дохода за каждое перерождение
Rebirths.LUCK_BONUS = 0.1 -- +10% удачи за каждое перерождение

Rebirths.TITLE_COUNT = 10 -- rebirth.1.title … rebirth.10.title в Strings

function Rebirths.cost(rebirths)
	return math.floor(50000000 * 12 ^ rebirths)
end

function Rebirths.levelRequired(rebirths)
	return 20 + rebirths * 5
end

-- Сообщение (см. Strings): титул покажет клиент на языке игрока.
function Rebirths.titleFor(rebirths)
	if rebirths <= 0 then
		return nil
	end
	return S.m("rebirth." .. math.min(rebirths, Rebirths.TITLE_COUNT) .. ".title")
end

return Rebirths
