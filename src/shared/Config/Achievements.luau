-- Достижения. check(data) -> true, когда выполнено.
-- badgeId — ID бейджа Roblox (создай в Creator Dashboard → Badges), 0 = без бейджа.

local Config = script.Parent
local Creatures = require(Config.Creatures)

-- Сезонные брейнроты в счёт «открой всех» не входят: после сезона их не достать.
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
	{ id = "first", name = "Первый брейнрот", desc = "Создай первого брейнрота", reward = { coinsMinutes = 1 }, check = function(d) return stat(d, "crafted") >= 1 end },
	{ id = "craft100", name = "Мем-завод", desc = "Создай 100 брейнротов", reward = { coinsMinutes = 5 }, check = function(d) return stat(d, "crafted") >= 100 end },
	{ id = "craft1000", name = "Фабрика тысячи мемов", desc = "Создай 1000 брейнротов", reward = { coinsMinutes = 20, luckMinutes = 10 }, check = function(d) return stat(d, "crafted") >= 1000 end },
	{ id = "index10", name = "Коллекционер", desc = "Открой 10 брейнротов в Индексе", reward = { coinsMinutes = 5 }, check = function(d) return indexCount(d) >= 10 end },
	{ id = "index20", name = "Знаток трендов", desc = "Открой 20 брейнротов в Индексе", reward = { coinsMinutes = 15 }, check = function(d) return indexCount(d) >= 20 end },
	{ id = "indexAll", name = "Ходячий Индекс", desc = "Открой ВСЕХ брейнротов", reward = { coinsMinutes = 60, luckMinutes = 60 }, check = function(d) return indexCount(d) >= REGULAR_COUNT end },
	{ id = "aura", name = "Аура-фармер", desc = "Получи брейнрота «Аура»", reward = { coinsMinutes = 5 }, check = function(d) return hasRarity(d, "aura") end },
	{ id = "god", name = "Встреча с Богом", desc = "Получи Брейнрот Бога", reward = { coinsMinutes = 20 }, check = function(d) return hasRarity(d, "god") end },
	{ id = "sixseven", name = "SIX... SEVEN!!! 🤌", desc = "Получи SIX SEVEN (+ Скин 67)", reward = { coinsMinutes = 67, luckMinutes = 67, skin = "sixseven" }, check = function(d) return hasRarity(d, "sixseven") end },
	{ id = "mutant", name = "Мутант", desc = "Получи брейнрота с мутацией", reward = { coinsMinutes = 3 }, check = function(d) return stat(d, "mutants") >= 1 end },
	{ id = "mutant25", name = "Лаборатория мутантов", desc = "Получи 25 мутантов", reward = { coinsMinutes = 15 }, check = function(d) return stat(d, "mutants") >= 25 end },
	{ id = "fuse10", name = "Генетик", desc = "Скрести брейнротов 10 раз", reward = { coinsMinutes = 8 }, check = function(d) return stat(d, "fused") >= 10 end },
	{ id = "thief", name = "Первая кража", desc = "Укради брейнрота", reward = { coinsMinutes = 5 }, check = function(d) return stat(d, "stolen") >= 1 end },
	{ id = "thief10", name = "Мастер-вор", desc = "Укради 10 брейнротов", reward = { coinsMinutes = 20 }, check = function(d) return stat(d, "stolen") >= 10 end },
	{ id = "defender", name = "Защитник базы", desc = "Шлёпни вора", reward = { coinsMinutes = 5 }, check = function(d) return stat(d, "thievesSlapped") >= 1 end },
	{ id = "defender10", name = "Охранник 80 уровня", desc = "Шлёпни 10 воров", reward = { coinsMinutes = 20 }, check = function(d) return stat(d, "thievesSlapped") >= 10 end },
	{ id = "boss", name = "Охотник на боссов", desc = "Победи босса-брейнрота", reward = { coinsMinutes = 10 }, check = function(d) return stat(d, "bossKills") >= 1 end },
	{ id = "boss10", name = "Гроза Огайо", desc = "Победи 10 боссов", reward = { coinsMinutes = 40, luckMinutes = 30 }, check = function(d) return stat(d, "bossKills") >= 10 end },
	{ id = "battle", name = "Первая аура-победа", desc = "Победи в аура-баттле", reward = { coinsMinutes = 5 }, check = function(d) return (d.battles and d.battles.wins or 0) >= 1 end },
	{ id = "battle25", name = "Аура-чемпион", desc = "Победи в 25 аура-баттлах", reward = { coinsMinutes = 30 }, check = function(d) return (d.battles and d.battles.wins or 0) >= 25 end },
	{ id = "auraLegend", name = "Аура-легенда", desc = "Набери 1500 очков ауры", reward = { coinsMinutes = 60, luckMinutes = 60 }, check = function(d) return (d.battles and d.battles.points or 0) >= 1500 end },
	{ id = "level10", name = "Тиктокер", desc = "Дойди до 10 уровня", reward = { coinsMinutes = 5 }, check = function(d) return d.level >= 10 end },
	{ id = "level30", name = "Легенда трендов", desc = "Дойди до 30 уровня", reward = { coinsMinutes = 30 }, check = function(d) return d.level >= 30 end },
	{ id = "rebirth", name = "Новая жизнь", desc = "Переродись", reward = { luckMinutes = 30 }, check = function(d) return d.rebirths >= 1 end },
	{ id = "rebirth5", name = "Огайо Финальный Босс", desc = "Переродись 5 раз", reward = { coinsMinutes = 60, luckMinutes = 60 }, check = function(d) return d.rebirths >= 5 end },
	{ id = "million", name = "Миллионер", desc = "Заработай $1M за всё время", reward = { coinsMinutes = 5 }, check = function(d) return d.totalEarned >= 1e6 end },
	{ id = "billion", name = "Миллиардер", desc = "Заработай $1B за всё время", reward = { coinsMinutes = 30 }, check = function(d) return d.totalEarned >= 1e9 end },
	{ id = "trade", name = "Деловой партнёр", desc = "Соверши обмен", reward = { coinsMinutes = 5 }, check = function(d) return stat(d, "trades") >= 1 end },
	{ id = "halloween", name = "Хэллоуин 2026 🎃", desc = "Получи хэллоуинского брейнрота", reward = { coinsMinutes = 10 }, check = function(d)
		for id in pairs(d.index) do
			local creature = Creatures.get(id)
			if creature and creature.season == "halloween" then
				return true
			end
		end
		return false
	end },
	{ id = "newyear", name = "Новый год 2027 🎄", desc = "Получи новогоднего брейнрота", reward = { coinsMinutes = 10 }, check = function(d)
		for id in pairs(d.index) do
			local creature = Creatures.get(id)
			if creature and creature.season == "newyear" then
				return true
			end
		end
		return false
	end },
	{ id = "streak7", name = "Верный фанат", desc = "Забери награду 7-го дня", reward = { coinsMinutes = 20 }, check = function(d) return d.daily.streak >= 7 end },
}

for _, achievement in ipairs(Achievements.List) do
	achievement.badgeId = achievement.badgeId or 0
end

return Achievements
