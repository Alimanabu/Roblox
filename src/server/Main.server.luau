-- Точка входа сервера Brainrot Factory.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Formulas = require(Shared.Util.Formulas)
local Levels = require(Shared.Config.Levels)
local Rebirths = require(Shared.Config.Rebirths)
require(Shared.Remotes) -- создаёт RemoteEvent'ы

local Services = script.Parent.Services
local DataService = require(Services.DataService)
local MonetizationService = require(Services.MonetizationService)
local ProgressionService = require(Services.ProgressionService)
local FactoryService = require(Services.FactoryService)
local IncomeService = require(Services.IncomeService)
local PlotService = require(Services.PlotService)
local StealService = require(Services.StealService)
local QuestService = require(Services.QuestService)
local EventService = require(Services.EventService)
local LeaderboardService = require(Services.LeaderboardService)
local TutorialService = require(Services.TutorialService)
local AdminService = require(Services.AdminService)
local CodeService = require(Services.CodeService)
local GiftService = require(Services.GiftService)
local AchievementService = require(Services.AchievementService)

-- Что видит клиент: всё нужное для интерфейса, уже посчитанное сервером.
DataService.setSnapshotBuilder(function(player, data)
	local passes = MonetizationService.passes(player)
	local now = os.time()
	local mods = EventService.mods()
	return {
		coins = data.coins,
		totalEarned = data.totalEarned,
		income = Formulas.totalIncome(data, passes, mods),
		incomeMultiplier = Formulas.incomeMultiplier(data, passes, mods),
		mods = mods,
		level = data.level,
		xp = data.xp,
		xpNext = Levels.xpToNext(data.level),
		title = Levels.titleFor(data.level),
		rebirths = data.rebirths,
		rebirthTitle = Rebirths.titleFor(data.rebirths),
		creatures = data.creatures,
		slots = Formulas.slots(data, passes),
		craftTime = Formulas.craftTime(data, passes, mods),
		luck = Formulas.luck(data, passes, now, mods),
		luckBoostLeft = math.max(0, (data.boosts.luckUntil or 0) - now),
		upgrades = data.upgrades,
		index = data.index,
		stats = data.stats,
		passes = passes,
		autoCraft = FactoryService.autoCraftCapsule(player),
		rewards = QuestService.snapshot(player, data),
		tutorial = TutorialService.snapshot(data),
		playtime = GiftService.snapshot(player, data),
		achievements = AchievementService.snapshot(data),
	}
end)

DataService.init()
EventService.init()
MonetizationService.init()
ProgressionService.init()
FactoryService.init()
IncomeService.init()
PlotService.init()
StealService.init()
QuestService.init()
LeaderboardService.init()
TutorialService.init()
AdminService.init()
CodeService.init()
GiftService.init()
AchievementService.init()

print("🧠 Brainrot Factory запущена! 🤌")
