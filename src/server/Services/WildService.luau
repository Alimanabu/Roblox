-- Дикие брейнроты: бродят по карте, кто первым поймал (зажал E) — того и брейнрот.
-- Редкие (Аура и выше) объявляются на весь сервер — все бегут ловить.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local Formulas = require(Shared.Util.Formulas)
local CreatureModel = require(Shared.Util.CreatureModel)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local FactoryService = require(script.Parent.FactoryService)
local PlotService = require(script.Parent.PlotService)
local Actions = require(script.Parent.Actions)

local WildService = {}

WildService.MAX_ALIVE = 4
WildService.SPAWN_EVERY = 75
WildService.LIFETIME = 180
WildService.SPEED = 7
WildService.SIZE = 3.5 -- рост дикого брейнрота в студах

-- Шансы редкостей у диких (чем реже — тем ценнее находка).
WildService.Weights = { normie = 40, lowkey = 30, rizz = 18, sigma = 8, aura = 3.5, skibidi = 0.5 }

local GOOD = Color3.fromRGB(120, 255, 120)
local BAD = Color3.fromRGB(255, 110, 110)

local rng = Random.new()
local folder
local wilds = {} -- [model] = { creature, position, target, bornAt, prompt }

local function pickRarity()
	local total = 0
	for _, weight in pairs(WildService.Weights) do
		total += weight
	end
	local roll = rng:NextNumber() * total
	for _, rarity in ipairs(Rarities.List) do
		local weight = WildService.Weights[rarity.id]
		if weight then
			roll -= weight
			if roll < 0 then
				return rarity.id
			end
		end
	end
	return "normie"
end

-- Случайная точка на карте: не на базах и не в центре площади.
local function randomSpot()
	for _ = 1, 30 do
		local angle = rng:NextNumber() * math.pi * 2
		local radius = rng:NextNumber(50, 225)
		local position = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		if not PlotService.isOnAnyPlot(position, 6) then
			return position
		end
	end
	return Vector3.new(0, 0, 60)
end

local function despawn(model)
	wilds[model] = nil
	if model.Parent then
		model:Destroy()
	end
end

local function spawnWild()
	local rarityId = pickRarity()
	local creature = Formulas.randomCreatureOf(rarityId, rng)
	local rarity = Rarities.get(rarityId)
	local position = randomSpot()

	local model = CreatureModel.build(creature.id, "normal", CFrame.new(position))
	model.Name = "Wild"
	model:ScaleTo(math.clamp(WildService.SIZE / (model:GetAttribute("Height") or 4), 0.3, 1.2))
	model:PivotTo(CFrame.new(position))

	local body = model.PrimaryPart
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "WildPrompt"
	prompt.ActionText = "Поймать"
	prompt.ObjectText = "Дикий " .. creature.name
	prompt.HoldDuration = 0.4 + rarity.rank * 0.2
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = body

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 44)
	gui.StudsOffsetWorldSpace = Vector3.new(0, WildService.SIZE + 2, 0)
	gui.MaxDistance = rarity.rank >= 5 and 400 or 120
	gui.AlwaysOnTop = rarity.rank >= 5
	gui.Parent = body
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextStrokeTransparency = 0.2
	label.TextColor3 = rarity.color
	label.Text = "🦎 Дикий " .. creature.name .. "\n[" .. rarity.name .. "]"
	label.Parent = gui

	model.Parent = folder
	wilds[model] = {
		creature = creature,
		rarity = rarity,
		position = position,
		target = randomSpot(),
		bornAt = os.clock(),
	}

	if rarity.rank >= 5 then
		Remotes.Notify:FireAllClients("🌟 На карте появился ДИКИЙ " .. creature.name .. " [" .. rarity.name .. "]! Лови!", rarity.color)
		Remotes.Sfx:FireAllClients("event")
	end
end

local function catch(player, prompt)
	local model = prompt:FindFirstAncestor("Wild")
	local wild = model and wilds[model]
	local data = DataService.get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not wild or not data or not root then
		return
	end
	if (root.Position - model:GetPivot().Position).Magnitude > prompt.MaxActivationDistance + 6 then
		return
	end
	if #data.creatures >= Formulas.slots(data, MonetizationService.passes(player)) then
		Remotes.Notify:FireClient(player, "На базе нет места для дикого брейнрота!", BAD)
		return
	end
	despawn(model)
	FactoryService.give(player, wild.creature.id, "normal")
	Actions.fire(player, "catchWild", 1)
	Remotes.Notify:FireClient(player, "🦎 Пойман дикий " .. wild.creature.name .. "!", GOOD)
	Remotes.Sfx:FireClient(player, "success")
	if wild.rarity.rank >= 5 then
		Remotes.Notify:FireAllClients("🦎 " .. player.DisplayName .. " поймал дикого " .. wild.creature.name .. "!", wild.rarity.color, true)
	end
end

function WildService.init()
	folder = Instance.new("Folder")
	folder.Name = "WildBrainrots"
	folder.Parent = workspace

	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt.Name == "WildPrompt" then
			catch(player, prompt)
		end
	end)

	-- Появление.
	task.spawn(function()
		task.wait(20)
		while true do
			local alive = 0
			for _ in pairs(wilds) do
				alive += 1
			end
			if alive < WildService.MAX_ALIVE and #Players:GetPlayers() > 0 then
				spawnWild()
			end
			task.wait(WildService.SPAWN_EVERY)
		end
	end)

	-- Бродят по карте и через какое-то время убегают.
	task.spawn(function()
		local step = 0.15
		while true do
			task.wait(step)
			local now = os.clock()
			for model, wild in pairs(wilds) do
				if not model.Parent or now - wild.bornAt > WildService.LIFETIME then
					despawn(model)
				else
					local offset = wild.target - wild.position
					if offset.Magnitude < 2 then
						wild.target = randomSpot()
					else
						wild.position += offset.Unit * math.min(offset.Magnitude, WildService.SPEED * step)
						local hop = math.abs(math.sin(now * 8)) * 0.8
						model:PivotTo(CFrame.lookAt(wild.position, wild.position + offset) * CFrame.new(0, hop, 0) * CFrame.Angles(0, math.pi, 0))
					end
				end
			end
		end
	end)
end

function WildService.forceSpawn()
	spawnWild()
end

return WildService
