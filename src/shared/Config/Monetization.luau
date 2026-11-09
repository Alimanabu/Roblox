-- Paid items for Robux.
-- id: real IDs from the Creator Dashboard (entered 08.11.2026, universe 10769617034).
-- id = 0 means "not created": the purchase is off (the button says "Soon").

local Monetization = {}

Monetization.GamePasses = {
	{ key = "VIP", id = 2075008286, name = "VIP", desc = "x2 coins forever", price = 199 },
	{ key = "LUCKY", id = 2075842305, name = "Lucky", desc = "x1.5 luck forever", price = 249, leadsToRandom = true },
	{ key = "BIG_BASE", id = 2075452305, name = "Huge Base", desc = "Floor 1 right away + Floor 2 at half price", price = 149 },
	{ key = "AUTO_CRAFT", id = 2075854237, name = "Auto Factory", desc = "The machine crafts brainrots by itself", price = 299 },
	{ key = "FAST_MACHINE", id = 2074690294, name = "Turbo Machine", desc = "The machine runs 2x faster", price = 99 },
}

-- One-time purchases. kind tells the server what to grant.
-- leadsToRandom = true: the purchase leads to a random reward or changes its odds (coins ->
-- capsules, wheel spins, luck). We do not sell these where Roblox forbids paid
-- random rewards; the server refuses (see MonetizationService). The LUCKY game pass above has
-- the same flag: the server cannot stop its sale, so there it simply has no effect.
Monetization.Products = {
	{ key = "LUCK_BOOST", id = 3729748331, name = "Luck Boost x2", desc = "x2 luck for 15 minutes", price = 49, kind = "luckBoost", minutes = 15, leadsToRandom = true },
	{ key = "COINS_SMALL", id = 3729748403, name = "Bag of Coins", desc = "10 minutes of income (min. 5K)", price = 29, kind = "coins", incomeMinutes = 10, minCoins = 5000, leadsToRandom = true },
	{ key = "SPINS_3", id = 3729748471, name = "3 Wheel Spins", desc = "Spin the lucky wheel 3 more times", price = 39, kind = "spins", amount = 3, leadsToRandom = true },
	{ key = "COINS_BIG", id = 3729748557, name = "Chest of Coins", desc = "1 hour of income (min. 50K)", price = 129, kind = "coins", incomeMinutes = 60, minCoins = 50000, leadsToRandom = true },
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
