-- Опыт, уровни, улучшения фабрики и перерождения.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local S = require(Shared.Strings)
local Levels = require(Shared.Config.Levels)
local Upgrades = require(Shared.Config.Upgrades)
local Rebirths = require(Shared.Config.Rebirths)
local Capsules = require(Shared.Config.Capsules)
local Format = require(Shared.Util.Format)
local Formulas = require(Shared.Util.Formulas)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local PolicyService = require(script.Parent.PolicyService)
local Actions = require(script.Parent.Actions)
local AnalyticsService = require(script.Parent.AnalyticsService)

local ProgressionService = {}

local GOOD = Color3.fromRGB(120, 255, 120)
local BAD = Color3.fromRGB(255, 110, 110)
local GOLD = Color3.fromRGB(255, 220, 80)

ProgressionService.RebirthDone = Instance.new("BindableEvent")
ProgressionService.FloorBuilt = Instance.new("BindableEvent")

function ProgressionService.addXp(player, data, amount)
	if data.level >= Levels.MAX_LEVEL then
		return
	end
	data.xp += amount
	local oldLevel = data.level
	while data.level < Levels.MAX_LEVEL and data.xp >= Levels.xpToNext(data.level) do
		data.xp -= Levels.xpToNext(data.level)
		data.level += 1
	end
	if data.level >= Levels.MAX_LEVEL then
		data.xp = 0
	end
	if data.level == oldLevel then
		return
	end

	ProgressionService.updateOverhead(player)
	Remotes.Notify:FireClient(player, S.m("progress.level_up", { level = data.level }), GOLD)
	Remotes.Sfx:FireClient(player, "levelup")
	if Levels.titleKeyFor(data.level) ~= Levels.titleKeyFor(oldLevel) then
		Remotes.Notify:FireClient(player, S.m("progress.new_title", { title = Levels.titleFor(data.level) }), GOLD)
	end
	for _, capsule in ipairs(Capsules.List) do
		if capsule.level > oldLevel and capsule.level <= data.level and data.rebirths >= capsule.rebirths then
			Remotes.Notify:FireClient(player, S.m("progress.capsule_unlocked", { name = S.m(capsule.nameKey) }), GOOD)
		end
	end
end

local function buyUpgrade(player, upgradeId)
	local data = DataService.get(player)
	local upgrade = type(upgradeId) == "string" and Upgrades.get(upgradeId)
	if not data or not upgrade then
		return
	end
	local current = data.upgrades[upgrade.id] or 0
	if current >= upgrade.maxLevel then
		Remotes.Notify:FireClient(player, S.m("progress.upgrade_maxed"), BAD)
		return
	end
	local cost = Upgrades.cost(upgrade.id, current)
	if data.coins < cost then
		Remotes.Notify:FireClient(player, S.m("common.not_enough_coins", { cost = Format.coins(cost) }), BAD)
		return
	end
	if upgrade.leadsToRandom and Formulas.randomCoins(data, PolicyService.paidRandomRestricted(player)) < cost then
		Remotes.Notify:FireClient(player, S.m("shop.bought_coins"), BAD)
		return
	end
	data.coins -= cost
	data.boughtCoins = math.min(data.boughtCoins, data.coins)
	AnalyticsService.coins(player, false, cost, "Upgrade")
	data.upgrades[upgrade.id] = current + 1
	Remotes.Notify:FireClient(player, S.m("progress.upgrade_level", { name = S.m(upgrade.nameKey), level = current + 1 }), GOOD)
	Actions.fire(player, "upgrade", 1)
	DataService.markDirty(player)
end

-- Постройка следующего этажа базы. Этажи остаются навсегда, даже после перерождения.
function ProgressionService.buyFloor(player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local passes = MonetizationService.passes(player)
	local floors = Formulas.floors(data, passes)
	local cost = Formulas.floorCost(floors, passes)
	if not cost then
		Remotes.Notify:FireClient(player, S.m("progress.floors_done"), BAD)
		return
	end
	if data.coins < cost then
		Remotes.Notify:FireClient(player, S.m("common.not_enough_coins", { cost = Format.coins(cost) }), BAD)
		return
	end
	data.coins -= cost
	data.boughtCoins = math.min(data.boughtCoins, data.coins)
	data.floors = floors + 1
	AnalyticsService.coins(player, false, cost, "Floor")
	local floor = Formulas.Floors[data.floors]
	Remotes.Notify:FireClient(player, S.m("progress.floor_built", { floor = S.m(floor.nameKey), slots = Formulas.slots(data, passes) }), GOOD)
	Remotes.Sfx:FireClient(player, "levelup")
	if data.floors >= Formulas.MAX_FLOORS then
		Remotes.Notify:FireAllClients(S.m("progress.floor_announce", { name = player.DisplayName, floor = S.m(floor.nameKey) }), GOLD, true)
	end
	Actions.fire(player, "floor", data.floors)
	DataService.markDirty(player)
	ProgressionService.FloorBuilt:Fire(player)
end

local function rebirth(player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local cost = Rebirths.cost(data.rebirths)
	local levelRequired = Rebirths.levelRequired(data.rebirths)
	if player:GetAttribute("BeingRobbed") then
		Remotes.Notify:FireClient(player, S.m("progress.being_robbed"), BAD)
		return
	end
	if data.level < levelRequired then
		Remotes.Notify:FireClient(player, S.m("progress.rebirth_level", { level = levelRequired }), BAD)
		return
	end
	if data.coins < cost then
		Remotes.Notify:FireClient(player, S.m("progress.rebirth_coins", { cost = Format.coins(cost) }), BAD)
		return
	end
	-- Перерождение даёт бонус удачи, поэтому при запрете оплачивается только заработанным.
	if Formulas.randomCoins(data, PolicyService.paidRandomRestricted(player)) < cost then
		Remotes.Notify:FireClient(player, S.m("shop.bought_coins"), BAD)
		return
	end

	data.rebirths += 1
	AnalyticsService.coins(player, false, data.coins, "Rebirth")
	AnalyticsService.event(player, "Rebirth", 1)
	data.coins = Formulas.START_COINS
	data.boughtCoins = 0
	data.creatures = {}
	data.upgrades = { speed = 0, luck = 0 }

	local title = Rebirths.titleFor(data.rebirths)
	Remotes.Notify:FireAllClients(S.m("progress.rebirth_announce", { name = player.DisplayName, title = title }), GOLD, true)
	ProgressionService.updateOverhead(player)
	ProgressionService.RebirthDone:Fire(player)
	DataService.markDirty(player)
end

function ProgressionService.init()
	Remotes.BuyUpgrade.OnServerEvent:Connect(buyUpgrade)
	Remotes.Rebirth.OnServerEvent:Connect(rebirth)
	Remotes.BuyFloor.OnServerEvent:Connect(ProgressionService.buyFloor)

	-- Титул над головой.
	local function watchCharacter(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			ProgressionService.updateOverhead(player)
		end)
	end
	Players.PlayerAdded:Connect(watchCharacter)
	for _, player in ipairs(Players:GetPlayers()) do
		watchCharacter(player)
	end
	DataService.Loaded.Event:Connect(function(player)
		ProgressionService.updateOverhead(player)
	end)
end

function ProgressionService.updateOverhead(player)
	local data = DataService.get(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not data or not head then
		return
	end
	local gui = head:FindFirstChild("TitleGui")
	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Name = "TitleGui"
		gui.Size = UDim2.fromOffset(220, 50)
		gui.StudsOffset = Vector3.new(0, 2.6, 0)
		gui.AlwaysOnTop = false
		gui.MaxDistance = 80
		gui.Parent = head

		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextStrokeTransparency = 0.3
		label.TextColor3 = GOLD
		label.Parent = gui
	end
	local text = S.m("common.title_level", { title = Levels.titleFor(data.level), level = data.level })
	local rebirthTitle = Rebirths.titleFor(data.rebirths)
	if rebirthTitle then
		text = S.m("progress.overhead", { rebirth = rebirthTitle, title = text })
	end
	S.apply(gui.Label, "Text", text)
end

return ProgressionService
