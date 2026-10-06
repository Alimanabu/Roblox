-- Платные штуки за Robux.
-- ВАЖНО: id = 0 значит «ещё не создано». Создай геймпассы и продукты в
-- Creator Dashboard и впиши сюда их настоящие ID.

local Monetization = {}

Monetization.GamePasses = {
	{ key = "VIP", id = 0, name = "VIP", desc = "x2 монет навсегда", price = 199 },
	{ key = "LUCKY", id = 0, name = "Счастливчик", desc = "x1.5 удачи навсегда", price = 249 },
	{ key = "BIG_BASE", id = 0, name = "Огромная база", desc = "+10 мест на базе", price = 149 },
	{ key = "AUTO_CRAFT", id = 0, name = "Авто-фабрика", desc = "Машина сама создаёт брейнротов", price = 299 },
	{ key = "FAST_MACHINE", id = 0, name = "Турбо-машина", desc = "Машина работает в 2 раза быстрее", price = 99 },
}

-- Разовые покупки. kind говорит серверу, что выдать.
-- leadsToRandom = true — покупка ведёт к случайной награде (монеты → капсулы, вращения
-- колеса). Таких не продаём там, где Roblox запрещает платные случайные награды.
Monetization.Products = {
	{ key = "LUCK_BOOST", id = 0, name = "Буст удачи x2", desc = "x2 удачи на 15 минут", price = 49, kind = "luckBoost", minutes = 15 },
	{ key = "COINS_SMALL", id = 0, name = "Мешок монет", desc = "10 минут дохода (мин. 5K)", price = 29, kind = "coins", incomeMinutes = 10, minCoins = 5000, leadsToRandom = true },
	{ key = "SPINS_3", id = 0, name = "3 вращения колеса", desc = "Крути колесо удачи ещё 3 раза", price = 39, kind = "spins", amount = 3, leadsToRandom = true },
	{ key = "COINS_BIG", id = 0, name = "Сундук монет", desc = "1 час дохода (мин. 50K)", price = 129, kind = "coins", incomeMinutes = 60, minCoins = 50000, leadsToRandom = true },
}

Monetization.GamePassByKey = {}
for _, pass in ipairs(Monetization.GamePasses) do
	Monetization.GamePassByKey[pass.key] = pass
end

Monetization.ProductById = {}
Monetization.ProductByKey = {}
for _, product in ipairs(Monetization.Products) do
	Monetization.ProductByKey[product.key] = product
	if product.id ~= 0 then
		Monetization.ProductById[product.id] = product
	end
end

return Monetization
