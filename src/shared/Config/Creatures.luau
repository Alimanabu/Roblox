-- Все брейнрот-существа игры. Персонажи полностью оригинальные.
-- income — монет в секунду (до мутаций и бонусов).
-- color / size / body / acc — внешний вид: форма тела и аксессуары (см. Util/CreatureModel).

local Creatures = {}

Creatures.List = {
	-- НОРМИС
	{ id = "bananito_ninjini", name = "Бананито Ниндзини", rarity = "normie", income = 1, color = Color3.fromRGB(255, 225, 80), size = 2, body = "tall", acc = { "headband" }, desc = "Банан-ниндзя. Очень старается." },
	{ id = "tostino_volantino", name = "Тостино Волантино", rarity = "normie", income = 2, color = Color3.fromRGB(210, 150, 90), size = 2, body = "block", acc = { "wings" }, desc = "Тостер, который думает, что умеет летать." },
	{ id = "lumacone_turbo", name = "Лумаконе Турбо", rarity = "normie", income = 3, color = Color3.fromRGB(140, 200, 120), size = 2, body = "ball", acc = { "shell", "antenna" }, desc = "Улитка с турбонаддувом. Всё равно медленная." },

	-- ЛОУ-КИ
	{ id = "frigo_gatto", name = "Фриго Гатто", rarity = "lowkey", income = 8, color = Color3.fromRGB(220, 235, 255), size = 2.4, body = "block", acc = { "ears" }, desc = "Кот-холодильник. Лоу-ки самый чилловый." },
	{ id = "pinguino_boombox", name = "Пингвино Бумбоксо", rarity = "lowkey", income = 11, color = Color3.fromRGB(40, 40, 60), size = 2.4, body = "ball", acc = { "beak", "boombox" }, desc = "Носит колонку вместо живота." },
	{ id = "cactusso_dancerino", name = "Кактуссо Дансерино", rarity = "lowkey", income = 15, color = Color3.fromRGB(60, 170, 80), size = 2.4, body = "tall", acc = { "spikes" }, desc = "Танцует, но обнимать не советуем." },

	-- РИЗЗ
	{ id = "squalo_sneakerino", name = "Сквало Сникерино", rarity = "rizz", income = 40, color = Color3.fromRGB(80, 130, 200), size = 2.8, body = "wide", acc = { "fin", "sneakers" }, desc = "Акула в лимитированных кроссовках." },
	{ id = "croissanto_samurai", name = "Круассанто Самурай", rarity = "rizz", income = 55, color = Color3.fromRGB(230, 170, 70), size = 2.8, body = "wide", acc = { "katana", "headband" }, desc = "Хрустящий воин чести." },
	{ id = "polpo_rizzini", name = "Польпо Риззини", rarity = "rizz", income = 70, color = Color3.fromRGB(240, 110, 150), size = 2.8, body = "ball", acc = { "tentacles", "shades" }, desc = "Осьминог с восьмикратным риззом." },

	-- СИГМА
	{ id = "gelato_gigachado", name = "Джелато Гигачадо", rarity = "sigma", income = 200, color = Color3.fromRGB(255, 200, 220), size = 3.2, body = "tall", acc = { "chin", "shades" }, desc = "Мороженое с квадратной челюстью." },
	{ id = "tacchino_sigmone", name = "Таккино Сигмоне", rarity = "sigma", income = 270, color = Color3.fromRGB(150, 90, 50), size = 3.2, body = "ball", acc = { "beak", "wings" }, desc = "Индюк, который встаёт в 4 утра." },
	{ id = "mollusco_mewing", name = "Моллюско Мьюинг", rarity = "sigma", income = 350, color = Color3.fromRGB(180, 140, 230), size = 3.2, body = "ball", acc = { "shell", "chin" }, desc = "Держит челюсть уже 300 лет." },

	-- АУРА
	{ id = "pizzarino_rocketto", name = "Пиццарино Ракетто", rarity = "aura", income = 1200, color = Color3.fromRGB(255, 120, 50), size = 3.6, body = "wedge", acc = { "flame" }, desc = "Пицца на реактивной тяге. +1000 ауры." },
	{ id = "drago_wifi", name = "Драго Вайфайо", rarity = "aura", income = 1600, color = Color3.fromRGB(60, 220, 200), size = 3.6, body = "wide", acc = { "horns", "wings", "antenna" }, desc = "Дракон, раздающий бесплатный вайфай." },
	{ id = "fenicotto_auretto", name = "Феникотто Ауретто", rarity = "aura", income = 2000, color = Color3.fromRGB(255, 140, 200), size = 3.6, body = "ball", acc = { "legs", "beak", "halo" }, desc = "Фламинго, который фармит ауру одной ногой." },

	-- СКИБИДИ
	{ id = "elefantino_bass", name = "Элефантино Бассо", rarity = "skibidi", income = 8000, color = Color3.fromRGB(130, 130, 160), size = 4, body = "ball", acc = { "trunk", "headphones" }, desc = "Слон-диджей. Басы слышно в соседнем сервере." },
	{ id = "robottino_spaghetti", name = "Роботтино Спагетти", rarity = "skibidi", income = 10000, color = Color3.fromRGB(200, 200, 210), size = 4, body = "block", acc = { "antenna", "glitch" }, desc = "Робот из макарон. Код тоже спагетти." },
	{ id = "capibara_galattica", name = "Капибара Галаттика", rarity = "skibidi", income = 12000, color = Color3.fromRGB(120, 80, 200), size = 4, body = "wide", acc = { "ears", "orbit" }, desc = "Капибара, которая видела конец вселенной. Ей норм." },

	-- БРЕЙНРОТ БОГ
	{ id = "re_lasagnone", name = "Ре Лазаньоне", rarity = "god", income = 60000, color = Color3.fromRGB(230, 90, 40), size = 4.6, body = "block", acc = { "crown", "cape" }, desc = "Король лазаньи. Все мемы склоняются перед ним." },
	{ id = "medusa_glitchina", name = "Медуза Глитчина", rarity = "god", income = 75000, color = Color3.fromRGB(80, 255, 200), size = 4.6, body = "ball", acc = { "tentacles", "glitch" }, desc = "Медуза из сломанной текстуры." },
	{ id = "orso_ohio", name = "Орсо Огайо", rarity = "god", income = 90000, color = Color3.fromRGB(110, 70, 40), size = 4.6, body = "ball", acc = { "ears", "crown", "chin" }, desc = "Медведь-босс последнего уровня Огайо." },

	-- SIX SEVEN (секрет)
	{ id = "sei_sette", name = "Сей Сетте", rarity = "sixseven", income = 670000, color = Color3.fromRGB(255, 230, 0), size = 5.2, body = "tall", acc = { "hands67", "halo", "shades" }, desc = "Шесть... СЕМЬ! 🤌 Самый редкий брейнрот в мире." },
	{ id = "dottore_sessantasette", name = "Дотторе Сессантасетте", rarity = "sixseven", income = 676767, color = Color3.fromRGB(255, 80, 0), size = 5.2, body = "block", acc = { "hands67", "shades", "orbit" }, desc = "Доктор наук по числу 67." },
}

Creatures.ById = {}
Creatures.ByRarity = {}
for _, creature in ipairs(Creatures.List) do
	Creatures.ById[creature.id] = creature
	Creatures.ByRarity[creature.rarity] = Creatures.ByRarity[creature.rarity] or {}
	table.insert(Creatures.ByRarity[creature.rarity], creature)
end

function Creatures.get(id)
	return Creatures.ById[id]
end

return Creatures
