-- Все брейнрот-существа игры. Персонажи полностью оригинальные.
-- income — монет в секунду (до мутаций и бонусов).
-- color / size / body / acc — внешний вид: форма тела и аксессуары (см. Util/CreatureModel).

local S = require(script.Parent.Parent.Strings)

local Creatures = {}

Creatures.List = {
	-- НОРМИС
	{ id = "bananito_ninjini", rarity = "normie", income = 1, color = Color3.fromRGB(255, 225, 80), size = 2, body = "tall", acc = { "headband" } },
	{ id = "tostino_volantino", rarity = "normie", income = 2, color = Color3.fromRGB(210, 150, 90), size = 2, body = "block", acc = { "wings" } },
	{ id = "lumacone_turbo", rarity = "normie", income = 3, color = Color3.fromRGB(140, 200, 120), size = 2, body = "ball", acc = { "shell", "antenna" } },
	{ id = "calzino_perduto", rarity = "normie", income = 2, color = Color3.fromRGB(230, 120, 200), size = 2, body = "tall", acc = { "antenna" } },

	-- ЛОУ-КИ
	{ id = "frigo_gatto", rarity = "lowkey", income = 8, color = Color3.fromRGB(220, 235, 255), size = 2.4, body = "block", acc = { "ears" } },
	{ id = "pinguino_boombox", rarity = "lowkey", income = 11, color = Color3.fromRGB(40, 40, 60), size = 2.4, body = "ball", acc = { "beak", "boombox" } },
	{ id = "cactusso_dancerino", rarity = "lowkey", income = 15, color = Color3.fromRGB(60, 170, 80), size = 2.4, body = "tall", acc = { "spikes" } },
	{ id = "burgerito_chillo", rarity = "lowkey", income = 10, color = Color3.fromRGB(200, 130, 60), size = 2.4, body = "wide", acc = { "shades" } },

	-- РИЗЗ
	{ id = "squalo_sneakerino", rarity = "rizz", income = 40, color = Color3.fromRGB(80, 130, 200), size = 2.8, body = "wide", acc = { "fin", "sneakers" } },
	{ id = "croissanto_samurai", rarity = "rizz", income = 55, color = Color3.fromRGB(230, 170, 70), size = 2.8, body = "wide", acc = { "katana", "headband" } },
	{ id = "polpo_rizzini", rarity = "rizz", income = 70, color = Color3.fromRGB(240, 110, 150), size = 2.8, body = "ball", acc = { "tentacles", "shades" } },
	{ id = "lamantino_rapper", rarity = "rizz", income = 60, color = Color3.fromRGB(150, 160, 190), size = 2.8, body = "ball", acc = { "headphones", "chin" } },

	-- СИГМА
	{ id = "gelato_gigachado", rarity = "sigma", income = 200, color = Color3.fromRGB(255, 200, 220), size = 3.2, body = "tall", acc = { "chin", "shades" } },
	{ id = "tacchino_sigmone", rarity = "sigma", income = 270, color = Color3.fromRGB(150, 90, 50), size = 3.2, body = "ball", acc = { "beak", "wings" } },
	{ id = "mollusco_mewing", rarity = "sigma", income = 350, color = Color3.fromRGB(180, 140, 230), size = 3.2, body = "ball", acc = { "shell", "chin" } },
	{ id = "criceto_palestra", rarity = "sigma", income = 300, color = Color3.fromRGB(240, 190, 120), size = 3.2, body = "ball", acc = { "ears", "headband" } },

	-- АУРА
	{ id = "pizzarino_rocketto", rarity = "aura", income = 1200, color = Color3.fromRGB(255, 120, 50), size = 3.6, body = "wedge", acc = { "flame" } },
	{ id = "drago_wifi", rarity = "aura", income = 1600, color = Color3.fromRGB(60, 220, 200), size = 3.6, body = "wide", acc = { "horns", "wings", "antenna" } },
	{ id = "fenicotto_auretto", rarity = "aura", income = 2000, color = Color3.fromRGB(255, 140, 200), size = 3.6, body = "ball", acc = { "legs", "beak", "halo" } },
	{ id = "unicorno_neon", rarity = "aura", income = 1800, color = Color3.fromRGB(255, 160, 240), size = 3.6, body = "tall", acc = { "horns", "halo" } },

	-- СКИБИДИ
	{ id = "elefantino_bass", rarity = "skibidi", income = 8000, color = Color3.fromRGB(130, 130, 160), size = 4, body = "ball", acc = { "trunk", "headphones" } },
	{ id = "robottino_spaghetti", rarity = "skibidi", income = 10000, color = Color3.fromRGB(200, 200, 210), size = 4, body = "block", acc = { "antenna", "glitch" } },
	{ id = "capibara_galattica", rarity = "skibidi", income = 12000, color = Color3.fromRGB(120, 80, 200), size = 4, body = "wide", acc = { "ears", "orbit" } },
	{ id = "pinguoide_cosmo", rarity = "skibidi", income = 11000, color = Color3.fromRGB(40, 60, 120), size = 4, body = "ball", acc = { "beak", "orbit", "antenna" } },

	-- БРЕЙНРОТ БОГ
	{ id = "re_lasagnone", rarity = "god", income = 60000, color = Color3.fromRGB(230, 90, 40), size = 4.6, body = "block", acc = { "crown", "cape" } },
	{ id = "medusa_glitchina", rarity = "god", income = 75000, color = Color3.fromRGB(80, 255, 200), size = 4.6, body = "ball", acc = { "tentacles", "glitch" } },
	{ id = "orso_ohio", rarity = "god", income = 90000, color = Color3.fromRGB(110, 70, 40), size = 4.6, body = "ball", acc = { "ears", "crown", "chin" } },
	{ id = "alpaca_assoluta", rarity = "god", income = 80000, color = Color3.fromRGB(245, 235, 215), size = 4.6, body = "tall", acc = { "ears", "crown", "cape" } },

	-- SIX SEVEN (секрет)
	{ id = "sei_sette", rarity = "sixseven", income = 670000, color = Color3.fromRGB(255, 230, 0), size = 5.2, body = "tall", acc = { "hands67", "halo", "shades" } },
	{ id = "dottore_sessantasette", rarity = "sixseven", income = 676767, color = Color3.fromRGB(255, 80, 0), size = 5.2, body = "block", acc = { "hands67", "shades", "orbit" } },

	-- 🎃 ХЭЛЛОУИН (лимитированные: только из сезонной капсулы)
	{ id = "zucchino_ridente", rarity = "rizz", season = "halloween", income = 65, color = Color3.fromRGB(255, 130, 20), size = 2.8, body = "ball", acc = { "antenna", "shades" } },
	{ id = "scheletro_mewing", rarity = "sigma", season = "halloween", income = 330, color = Color3.fromRGB(235, 235, 220), size = 3.2, body = "tall", acc = { "chin", "headband" } },
	{ id = "fantasma_aurino", rarity = "aura", season = "halloween", income = 1900, color = Color3.fromRGB(220, 230, 255), size = 3.6, body = "tall", acc = { "halo", "cape" } },
	-- 🎄 НОВЫЙ ГОД (лимитированные)
	{ id = "pupazzo_rizz", rarity = "rizz", season = "newyear", income = 62, color = Color3.fromRGB(245, 250, 255), size = 2.8, body = "ball", acc = { "beak", "headband" } },
	{ id = "renna_sigmina", rarity = "sigma", season = "newyear", income = 320, color = Color3.fromRGB(150, 100, 60), size = 3.2, body = "wide", acc = { "horns", "antenna" } },
	{ id = "abete_aurella", rarity = "aura", season = "newyear", income = 1850, color = Color3.fromRGB(40, 160, 70), size = 3.6, body = "wedge", acc = { "halo", "glitch" } },
	{ id = "nonno_gelo", rarity = "skibidi", season = "newyear", income = 11800, color = Color3.fromRGB(210, 30, 40), size = 4, body = "tall", acc = { "chin", "crown", "cape" } },
	-- 💘 ДЕНЬ СВЯТОГО ВАЛЕНТИНА (лимитированные)
	{ id = "cuore_rizzone", rarity = "rizz", season = "valentine", income = 66, color = Color3.fromRGB(255, 70, 120), size = 2.8, body = "ball", acc = { "wings", "shades" } },
	{ id = "cupido_sigmino", rarity = "sigma", season = "valentine", income = 340, color = Color3.fromRGB(255, 200, 220), size = 3.2, body = "tall", acc = { "wings", "halo" } },
	{ id = "rosalina_aurina", rarity = "aura", season = "valentine", income = 1950, color = Color3.fromRGB(220, 30, 70), size = 3.6, body = "wedge", acc = { "crown", "spikes" } },
	{ id = "cioccolato_amorele", rarity = "skibidi", season = "valentine", income = 11900, color = Color3.fromRGB(110, 60, 30), size = 4, body = "block", acc = { "headband", "cape" } },

	-- ☀️ ЛЕТО (лимитированные)
	{ id = "anguria_chillino", rarity = "rizz", season = "summer", income = 64, color = Color3.fromRGB(80, 190, 80), size = 2.8, body = "wide", acc = { "shades" } },
	{ id = "granchio_spiaggino", rarity = "sigma", season = "summer", income = 310, color = Color3.fromRGB(240, 90, 50), size = 3.2, body = "wide", acc = { "tentacles", "shades" } },
	{ id = "surfero_aurino", rarity = "aura", season = "summer", income = 1850, color = Color3.fromRGB(60, 180, 255), size = 3.6, body = "ball", acc = { "fin", "headband" } },
	{ id = "sole_dj", rarity = "skibidi", season = "summer", income = 11700, color = Color3.fromRGB(255, 220, 40), size = 4, body = "ball", acc = { "halo", "headphones" } },
	{ id = "vampiro_dj", rarity = "skibidi", season = "halloween", income = 11500, color = Color3.fromRGB(120, 20, 40), size = 4, body = "ball", acc = { "headphones", "cape", "horns" } },
}

Creatures.ById = {}
Creatures.BySeason = {} -- [seasonId][rarityId] = { creature, ... }
Creatures.ByRarity = {}
for _, creature in ipairs(Creatures.List) do
	S.fill(creature, "creature." .. creature.id, "name", "desc")
	Creatures.ById[creature.id] = creature
	if creature.season then
		-- Сезонные не попадают в обычные капсулы.
		Creatures.BySeason[creature.season] = Creatures.BySeason[creature.season] or {}
		local pools = Creatures.BySeason[creature.season]
		pools[creature.rarity] = pools[creature.rarity] or {}
		table.insert(pools[creature.rarity], creature)
	else
		Creatures.ByRarity[creature.rarity] = Creatures.ByRarity[creature.rarity] or {}
		table.insert(Creatures.ByRarity[creature.rarity], creature)
	end
end

function Creatures.get(id)
	return Creatures.ById[id]
end

return Creatures
