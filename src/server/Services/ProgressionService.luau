-- Опыт, уровни, улучшения фабрики и перерождения.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Levels = require(Shared.Config.Levels)
local Upgrades = require(Shared.Config.Upgrades)
local Rebirths = require(Shared.Config.Rebirths)
local Capsules = require(Shared.Config.Capsules)
local Format = require(Shared.Util.Format)
local Formulas = require(Shared.Util.Formulas)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local Actions = require(script.Parent.Actions)

local ProgressionService = {}

local GOOD = Color3.fromRGB(120, 255, 120)
local BAD = Color3.fromRGB(255, 110, 110)
local GOLD = Color3.fromRGB(255, 220, 80)

ProgressionService.RebirthDone = Instance.new("BindableEvent")

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
	Remotes.Notify:FireClient(player, "⭐ Новый уровень: " .. data.level .. "!", GOLD)
	Remotes.Sfx:FireClient(player, "levelup")
	if Levels.titleFor(data.level) ~= Levels.titleFor(oldLevel) then
		Remotes.Notify:FireClient(player, "🏷️ Новый титул: " .. Levels.titleFor(data.level), GOLD)
	end
	for _, capsule in ipairs(Capsules.List) do
		if capsule.level > oldLevel and capsule.level <= data.level and data.rebirths >= capsule.rebirths then
			Remotes.Notify:FireClient(player, "🔓 Открыта капсула: " .. capsule.name, GOOD)
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
		Remotes.Notify:FireClient(player, "Это улучшение уже на максимуме!", BAD)
		return
	end
	local cost = Upgrades.cost(upgrade.id, current)
	if data.coins < cost then
		Remotes.Notify:FireClient(player, "Не хватает монет: нужно " .. Format.coins(cost), BAD)
		return
	end
	data.coins -= cost
	data.upgrades[upgrade.id] = current + 1
	Remotes.Notify:FireClient(player, "⬆️ " .. upgrade.name .. ": уровень " .. (current + 1), GOOD)
	Actions.fire(player, "upgrade", 1)
	DataService.markDirty(player)
end

local function rebirth(player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local cost = Rebirths.cost(data.rebirths)
	local levelRequired = Rebirths.levelRequired(data.rebirths)
	if player:GetAttribute("BeingRobbed") then
		Remotes.Notify:FireClient(player, "У тебя сейчас крадут брейнрота! Сначала отбей его 👋", BAD)
		return
	end
	if data.level < levelRequired then
		Remotes.Notify:FireClient(player, "Нужен " .. levelRequired .. " уровень для перерождения", BAD)
		return
	end
	if data.coins < cost then
		Remotes.Notify:FireClient(player, "Нужно " .. Format.coins(cost) .. " для перерождения", BAD)
		return
	end

	data.rebirths += 1
	data.coins = Formulas.START_COINS
	data.creatures = {}
	data.upgrades = { speed = 0, luck = 0, slots = 0 }

	local title = Rebirths.titleFor(data.rebirths)
	Remotes.Notify:FireAllClients("♻️ " .. player.DisplayName .. " переродился и стал «" .. title .. "»!", GOLD)
	ProgressionService.updateOverhead(player)
	ProgressionService.RebirthDone:Fire(player)
	DataService.markDirty(player)
end

function ProgressionService.init()
	Remotes.BuyUpgrade.OnServerEvent:Connect(buyUpgrade)
	Remotes.Rebirth.OnServerEvent:Connect(rebirth)

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
	local text = Levels.titleFor(data.level) .. " • ур. " .. data.level
	local rebirthTitle = Rebirths.titleFor(data.rebirths)
	if rebirthTitle then
		text = "[" .. rebirthTitle .. "]\n" .. text
	end
	gui.Label.Text = text
end

return ProgressionService
