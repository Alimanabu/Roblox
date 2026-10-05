-- Все брейнрот-существа игры. Персонажи полностью оригинальные.
-- income — монет в секунду (до мутаций и бонусов).
-- color / size / body / acc — внешний вид: форма тела и аксессуары (см. Util/CreatureModel).

local Creatures = {}

Creatures.List = {
	-- НОРМИС
	{ id = "bananito_ninjini", name = "Бананито Ниндзини", rarity = "normie", income = 1, color = Color3.fromRGB(255, 225, 80), size = 2, body = "tall", acc = { "headband" }, desc = "Банан-ниндзя. Очень старается." },
	{ id = "tostino_volantino", name = "Тостино Волантино", rarity = "normie", income = 2, color = Color3.fromRGB(210, 150, 90), size = 2, body = "block", acc = { "wings" }, desc = "Тостер, который думает, что умеет летать." },
	{ id = "lumacone_turbo", name = "Лумаконе Турбо", rarity = "normie", income = 3, color = Color3.fromRGB(140, 200, 120), size = 2, body = "ball", acc = { "shell", "antenna" }, desc = "Улитка с турбонаддувом. Всё равно медленная." },
	{ id = "calzino_perduto", name = "Кальцино Пердуто", rarity = "normie", income = 2, color = Color3.fromRGB(230, 120, 200), size = 2, body = "tall", acc = { "antenna" }, desc = "Потерянный носок. Ищет пару с 2019 года." },

	-- ЛОУ-КИ
	{ id = "frigo_gatto", name = "Фриго Гатто", rarity = "lowkey", income = 8, color = Color3.fromRGB(220, 235, 255), size = 2.4, body = "block", acc = { "ears" }, desc = "Кот-холодильник. Лоу-ки самый чилловый." },
	{ id = "pinguino_boombox", name = "Пингвино Бумбоксо", rarity = "lowkey", income = 11, color = Color3.fromRGB(40, 40, 60), size = 2.4, body = "ball", acc = { "beak", "boombox" }, desc = "Носит колонку вместо живота." },
	{ id = "cactusso_dancerino", name = "Кактуссо Дансерино", rarity = "lowkey", income = 15, color = Color3.fromRGB(60, 170, 80), size = 2.4, body = "tall", acc = { "spikes" }, desc = "Танцует, но обнимать не советуем." },
	{ id = "burgerito_chillo", name = "Бургерито Чилло", rarity = "lowkey", income = 10, color = Color3.fromRGB(200, 130, 60), size = 2.4, body = "wide", acc = { "shades" }, desc = "Бургер на чилле. Лоу-ки самый вкусный." },

	-- РИЗЗ
	{ id = "squalo_sneakerino", name = "Сквало Сникерино", rarity = "rizz", income = 40, color = Color3.fromRGB(80, 130, 200), size = 2.8, body = "wide", acc = { "fin", "sneakers" }, desc = "Акула в лимитированных кроссовках." },
	{ id = "croissanto_samurai", name = "Круассанто Самурай", rarity = "rizz", income = 55, color = Color3.fromRGB(230, 170, 70), size = 2.8, body = "wide", acc = { "katana", "headband" }, desc = "Хрустящий воин чести." },
	{ id = "polpo_rizzini", name = "Польпо Риззини", rarity = "rizz", income = 70, color = Color3.fromRGB(240, 110, 150), size = 2.8, body = "ball", acc = { "tentacles", "shades" }, desc = "Осьминог с восьмикратным риззом." },
	{ id = "lamantino_rapper", name = "Ламантино Рэппер", rarity = "rizz", income = 60, color = Color3.fromRGB(150, 160, 190), size = 2.8, body = "ball", acc = { "headphones", "chin" }, desc = "Читает рэп так медленно, что это уже ризз." },

	-- СИГМА
	{ id = "gelato_gigachado", name = "Джелато Гигачадо", rarity = "sigma", income = 200, color = Color3.fromRGB(255, 200, 220), size = 3.2, body = "tall", acc = { "chin", "shades" }, desc = "Мороженое с квадратной челюстью." },
	{ id = "tacchino_sigmone", name = "Таккино Сигмоне", rarity = "sigma", income = 270, color = Color3.fromRGB(150, 90, 50), size = 3.2, body = "ball", acc = { "beak", "wings" }, desc = "Индюк, который встаёт в 4 утра." },
	{ id = "mollusco_mewing", name = "Моллюско Мьюинг", rarity = "sigma", income = 350, color = Color3.fromRGB(180, 140, 230), size = 3.2, body = "ball", acc = { "shell", "chin" }, desc = "Держит челюсть уже 300 лет." },
	{ id = "criceto_palestra", name = "Кричето Палестра", rarity = "sigma", income = 300, color = Color3.fromRGB(240, 190, 120), size = 3.2, body = "ball", acc = { "ears", "headband" }, desc = "Хомяк-качок. Колесо крутит только на максимальном весе." },

	-- АУРА
	{ id = "pizzarino_rocketto", name = "Пиццарино Ракетто", rarity = "aura", income = 1200, color = Color3.fromRGB(255, 120, 50), size = 3.6, body = "wedge", acc = { "flame" }, desc = "Пицца на реактивной тяге. +1000 ауры." },
	{ id = "drago_wifi", name = "Драго Вайфайо", rarity = "aura", income = 1600, color = Color3.fromRGB(60, 220, 200), size = 3.6, body = "wide", acc = { "horns", "wings", "antenna" }, desc = "Дракон, раздающий бесплатный вайфай." },
	{ id = "fenicotto_auretto", name = "Феникотто Ауретто", rarity = "aura", income = 2000, color = Color3.fromRGB(255, 140, 200), size = 3.6, body = "ball", acc = { "legs", "beak", "halo" }, desc = "Фламинго, который фармит ауру одной ногой." },
	{ id = "unicorno_neon", name = "Уникорно Неоно", rarity = "aura", income = 1800, color = Color3.fromRGB(255, 160, 240), size = 3.6, body = "tall", acc = { "horns", "halo" }, desc = "Единорог, светится даже днём. Аура: бесконечность." },

	-- СКИБИДИ
	{ id = "elefantino_bass", name = "Элефантино Бассо", rarity = "skibidi", income = 8000, color = Color3.fromRGB(130, 130, 160), size = 4, body = "ball", acc = { "trunk", "headphones" }, desc = "Слон-диджей. Басы слышно в соседнем сервере." },
	{ id = "robottino_spaghetti", name = "Роботтино Спагетти", rarity = "skibidi", income = 10000, color = Color3.fromRGB(200, 200, 210), size = 4, body = "block", acc = { "antenna", "glitch" }, desc = "Робот из макарон. Код тоже спагетти." },
	{ id = "capibara_galattica", name = "Капибара Галаттика", rarity = "skibidi", income = 12000, color = Color3.fromRGB(120, 80, 200), size = 4, body = "wide", acc = { "ears", "orbit" }, desc = "Капибара, которая видела конец вселенной. Ей норм." },
	{ id = "pinguoide_cosmo", name = "Пингуоиде Космо", rarity = "skibidi", income = 11000, color = Color3.fromRGB(40, 60, 120), size = 4, body = "ball", acc = { "beak", "orbit", "antenna" }, desc = "Пингвин-космонавт. Улетел за мемами на Марс." },

	-- БРЕЙНРОТ БОГ
	{ id = "re_lasagnone", name = "Ре Лазаньоне", rarity = "god", income = 60000, color = Color3.fromRGB(230, 90, 40), size = 4.6, body = "block", acc = { "crown", "cape" }, desc = "Король лазаньи. Все мемы склоняются перед ним." },
	{ id = "medusa_glitchina", name = "Медуза Глитчина", rarity = "god", income = 75000, color = Color3.fromRGB(80, 255, 200), size = 4.6, body = "ball", acc = { "tentacles", "glitch" }, desc = "Медуза из сломанной текстуры." },
	{ id = "orso_ohio", name = "Орсо Огайо", rarity = "god", income = 90000, color = Color3.fromRGB(110, 70, 40), size = 4.6, body = "ball", acc = { "ears", "crown", "chin" }, desc = "Медведь-босс последнего уровня Огайо." },
	{ id = "alpaca_assoluta", name = "Альпака Ассолюта", rarity = "god", income = 80000, color = Color3.fromRGB(245, 235, 215), size = 4.6, body = "tall", acc = { "ears", "crown", "cape" }, desc = "Абсолютная альпака. Плюнула — и мем стал вирусным." },

	-- SIX SEVEN (секрет)
	{ id = "sei_sette", name = "Сей Сетте", rarity = "sixseven", income = 670000, color = Color3.fromRGB(255, 230, 0), size = 5.2, body = "tall", acc = { "hands67", "halo", "shades" }, desc = "Шесть... СЕМЬ! 🤌 Самый редкий брейнрот в мире." },
	{ id = "dottore_sessantasette", name = "Дотторе Сессантасетте", rarity = "sixseven", income = 676767, color = Color3.fromRGB(255, 80, 0), size = 5.2, body = "block", acc = { "hands67", "shades", "orbit" }, desc = "Доктор наук по числу 67." },

	-- 🎃 ХЭЛЛОУИН (лимитированные: только из сезонной капсулы)
	{ id = "zucchino_ridente", name = "Цуккино Риденте", rarity = "rizz", season = "halloween", income = 65, color = Color3.fromRGB(255, 130, 20), size = 2.8, body = "ball", acc = { "antenna", "shades" }, desc = "Тыква, которая смеётся над твоими мемами." },
	{ id = "scheletro_mewing", name = "Скелетро Мьюинг", rarity = "sigma", season = "halloween", income = 330, color = Color3.fromRGB(235, 235, 220), size = 3.2, body = "tall", acc = { "chin", "headband" }, desc = "Скелет, у которого челюсть идеальная. Буквально." },
	{ id = "fantasma_aurino", name = "Фантазма Аурино", rarity = "aura", season = "halloween", income = 1900, color = Color3.fromRGB(220, 230, 255), size = 3.6, body = "tall", acc = { "halo", "cape" }, desc = "Призрак, который фармит ауру с того света." },
	-- 🎄 НОВЫЙ ГОД (лимитированные)
	{ id = "pupazzo_rizz", name = "Пупаццо Ризз", rarity = "rizz", season = "newyear", income = 62, color = Color3.fromRGB(245, 250, 255), size = 2.8, body = "ball", acc = { "beak", "headband" }, desc = "Снеговик с морковным риззом." },
	{ id = "renna_sigmina", name = "Ренна Сигмина", rarity = "sigma", season = "newyear", income = 320, color = Color3.fromRGB(150, 100, 60), size = 3.2, body = "wide", acc = { "horns", "antenna" }, desc = "Олень, который тащит сани в 4 утра." },
	{ id = "abete_aurella", name = "Абете Аурелла", rarity = "aura", season = "newyear", income = 1850, color = Color3.fromRGB(40, 160, 70), size = 3.6, body = "wedge", acc = { "halo", "glitch" }, desc = "Ёлка с гирляндой ауры." },
	{ id = "nonno_gelo", name = "Нонно Джело", rarity = "skibidi", season = "newyear", income = 11800, color = Color3.fromRGB(210, 30, 40), size = 4, body = "tall", acc = { "chin", "crown", "cape" }, desc = "Дедушка Мороз из Италии. Дарит только мемы." },
	{ id = "vampiro_dj", name = "Вампиро Диджеино", rarity = "skibidi", season = "halloween", income = 11500, color = Color3.fromRGB(120, 20, 40), size = 4, body = "ball", acc = { "headphones", "cape", "horns" }, desc = "Вампир-диджей. Играет только ночью, но громко." },
}

Creatures.ById = {}
Creatures.BySeason = {} -- [seasonId][rarityId] = { creature, ... }
Creatures.ByRarity = {}
for _, creature in ipairs(Creatures.List) do
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
