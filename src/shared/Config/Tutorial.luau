-- Обучение для новичков: шаги по порядку.
-- action — какое действие засчитывает шаг (см. server/Services/Actions), count — сколько раз.
-- menu — какую кнопку меню подсветить.

local Tutorial = {}

Tutorial.Steps = {
	{ text = "Нажми 🏭 Фабрика и создай первого брейнрота!", action = "craft", count = 1, menu = "Factory", reward = 100 },
	{ text = "Брейнроты приносят монеты каждую секунду! Создай ещё 4", action = "craft", count = 4, menu = "Factory", reward = 200 },
	{ text = "Купи любое улучшение в ⬆️ Улучшения", action = "upgrade", count = 1, menu = "Upgrades", reward = 300 },
	{ text = "Воры не дремлют! Встань на голубую кнопку 🔓 Замок на своей базе", action = "lock", count = 1, highlightLock = true, reward = 300 },
	{ text = "Забери ежедневную награду в 🎁 Награды", action = "daily", count = 1, menu = "Rewards", reward = 500 },
}

return Tutorial
