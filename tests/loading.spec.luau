-- Повреждённые сохранения и устойчивость циклов по игрокам: поле не того типа заменяется шаблоном,
-- загрузка, сохранение и снимок не падают, монеты и брейнроты целы; ошибка у одного игрока не
-- останавливает рассылку состояния остальным.

local failures = 0
local scenarios = 0
local function check(cond, msg)
	if not cond then
		failures += 1
		print("❌ " .. msg)
	end
end

World.studio = false

local Daily = shared_require("Config/Daily")
local Formulas = shared_require("Util/Formulas")
World.startServer()
World.advance(5)
local DataService = shared_require("Services/DataService")
local store = World.services.DataStoreService:GetDataStore("BrainrotFactory_v1")

local function full(extra)
	local s = {
		version = 6, coins = 12345, totalEarned = 99999, rebirths = 2, nextUid = 4,
		creatures = {
			{ uid = "1", id = "bananito_ninjini", mut = "normal", source = "free" },
			{ uid = "2", id = "bananito_ninjini", mut = "normal", source = "free" },
			{ uid = "3", id = "bananito_ninjini", mut = "normal", source = "free" },
		},
		daily = { streak = 5, lastClaimDay = Daily.today() - 1 },
		codes = { BRAINROT = true },
		upgrades = { speed = 3, luck = 2 }, floors = 1,
	}
	for k, v in pairs(extra or {}) do
		s[k] = v
	end
	return s
end

local function stateSentTo(player, fromIndex)
	for index = fromIndex + 1, #World.sent do
		local sent = World.sent[index]
		if sent.remote == "State" and sent.player == player then
			return true
		end
	end
	return false
end

local cases = {
	{ "playtime = 5", { playtime = 5 } },
	{ "playtime = string", { playtime = "x" } },
	{ "playtime.seconds = string", { playtime = { seconds = "9" } } },
	{ "playtime.claimed = string", { playtime = { day = Daily.today(), seconds = 10, claimed = "zzz" } } },
	{ "playtime.seconds = NaN", { playtime = { day = Daily.today(), seconds = 0 / 0, claimed = {} } } },
	{ "playtime.seconds = inf", { playtime = { day = Daily.today(), seconds = math.huge, claimed = {} } } },
	{ "playtime.seconds = 1e12", { playtime = { day = Daily.today(), seconds = 1e12, claimed = {} } } },
	{ "daily = 7", { daily = 7 } },
	{ "quests, wheel, battles, tutorial, settings = числа/строки", {
		quests = 3, wheel = "w", battles = true, tutorial = 9, settings = "s", stats = 1, boosts = 2, pity = "p",
	} },
	{ "coins = string (число заменяется шаблоном)", { coins = "many" } },
}

for index, case in ipairs(cases) do
	scenarios += 1
	print("  ✅ " .. scenarios .. ". " .. case[1])
	local id = 9300 + index
	store:SetAsync("player_" .. id, full(case[2]))
	local ok, player = pcall(function()
		local p = World.addPlayer(id, "P" .. index)
		World.advance(1)
		return p
	end)
	local data = ok and DataService.get(player)
	check(data ~= nil, case[1] .. ": профиль не загрузился")
	if data then
		-- Доход за время теста прибавляет несколько монет: сверяем с допуском, но не с обнулением.
		if case[2].coins == nil then
			check(data.coins >= 12345 and data.coins < 13000, case[1] .. ": монеты: " .. tostring(data.coins))
		else
			check(data.coins >= Formulas.START_COINS and data.coins < Formulas.START_COINS + 1000, case[1] .. ": монеты: " .. tostring(data.coins))
		end
		check(#data.creatures == 3, case[1] .. ": брейнроты: " .. #data.creatures)
		check(type(data.playtime) == "table" and type(data.playtime.claimed) == "table", case[1] .. ": playtime не таблица")
		local seconds = data.playtime.seconds
		check(type(seconds) == "number" and seconds == seconds and seconds >= 0 and seconds <= 86400,
			case[1] .. ": секунды вне допустимого: " .. tostring(seconds))
		check(type(data.daily) == "table" and type(data.quests) == "table" and type(data.wheel) == "table",
			case[1] .. ": таблицы не восстановлены")
		local sentFrom = #World.sent
		DataService.markDirty(player)
		World.advance(1)
		check(stateSentTo(player, sentFrom), case[1] .. ": снимок не отправлен")
		check(DataService.save(player) == true, case[1] .. ": сохранение вернуло не true")
		local saved = store.data["player_" .. id]
		check(saved ~= nil and saved.coins == data.coins and #saved.creatures == 3, case[1] .. ": сохранённое повреждено")
		World.removePlayer(player)
		World.advance(5)
	end
end

scenarios += 1
print("  ✅ " .. scenarios .. ". рассылка состояния: битый игрок не мешает следующему")
do
	local first = World.addPlayer(9401, "Broken")
	local second = World.addPlayer(9402, "Healthy")
	World.advance(1)
	local brokenData, healthyData = DataService.get(first), DataService.get(second)
	check(brokenData ~= nil and healthyData ~= nil, "рассылка: профили не загрузились")
	if brokenData and healthyData then
		brokenData.upgrades = 7 -- снимок читает upgrades.speed: у числа индекс падает
		local sentFrom = #World.sent
		DataService.markDirty(first)
		DataService.markDirty(second)
		World.advance(1)
		check(stateSentTo(second, sentFrom), "рассылка: здоровый игрок не получил состояние")
		check(not stateSentTo(first, sentFrom), "рассылка: битому игроку снимок не должен уйти")
		-- Здоровый продолжает получать состояние и дальше.
		sentFrom = #World.sent
		DataService.markDirty(second)
		World.advance(1)
		check(stateSentTo(second, sentFrom), "рассылка: цикл остановился после ошибки")
	end
	World.removePlayer(first)
	World.removePlayer(second)
	World.advance(5)
end

if failures == 0 then
	print("✅ Повреждённые сохранения: пройдено сценариев " .. scenarios)
else
	print("❌ Повреждённые сохранения: провалено проверок " .. failures)
	error("tests failed")
end
