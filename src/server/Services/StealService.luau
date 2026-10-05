-- Кража брейнротов с чужих баз.
--
-- Как это работает:
--   1. Подходишь к чужому брейнроту и зажимаешь F («Украсть»). Чем реже — тем дольше.
--   2. Брейнрот у тебя над головой, ты бежишь медленнее и подсвечен красным.
--   3. Добеги до своей базы за CARRY_TIME секунд — брейнрот твой.
--   4. Хозяин может догнать и шлёпнуть Шлёпалкой — брейнрот вернётся к нему.
--   5. Хозяин может закрыть базу замком на LOCK_TIME секунд (надо стоять у кнопки).

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local StarterPack = game:GetService("StarterPack")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local Formulas = require(Shared.Util.Formulas)
local CreatureModel = require(Shared.Util.CreatureModel)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local ProgressionService = require(script.Parent.ProgressionService)
local PlotService = require(script.Parent.PlotService)
local Actions = require(script.Parent.Actions)

local StealService = {}

StealService.CARRY_TIME = 60
StealService.LOCK_TIME = 60
StealService.LOCK_COOLDOWN = 30 -- после конца замка нельзя сразу закрыть снова
StealService.JOIN_SHIELD = 90
StealService.CARRY_SPEED = 12
StealService.NORMAL_SPEED = 16
StealService.SLAP_RANGE = 9
StealService.SLAP_COOLDOWN = 0.8
StealService.SLAP_FORCE = 70

local BAD = Color3.fromRGB(255, 110, 110)
local GOOD = Color3.fromRGB(120, 255, 120)
local WARN = Color3.fromRGB(255, 170, 60)

local carries = {} -- [thief] = { owner, entry, deadline, visual, highlight, diedConn }
local lockedUntil = {} -- [owner] = время сервера
local lockKind = {} -- [owner] = "shield" (защита при входе) | "lock" (замок)
local lockReadyAt = {} -- [owner] = когда снова можно нажать замок
local lastSlap = {} -- [player] = os.clock()
local closing = false -- сервер выключается: новые кражи запрещены
local holdStart = {} -- [player] = { prompt, os.clock() }: сервер сам проверяет время удержания

local function now()
	return workspace:GetServerTimeNow()
end

local function rootOf(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function humanoidOf(player)
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function displayName(entry)
	local creature = Creatures.get(entry.id)
	local mutation = Mutations.get(entry.mut)
	if mutation.id == "normal" then
		return creature.name
	end
	return mutation.name .. " " .. creature.name
end

function StealService.isLocked(owner)
	return (lockedUntil[owner] or 0) > now()
end

function StealService.isCarrying(player)
	return carries[player] ~= nil
end

local function setLock(owner, seconds, kind)
	-- Атрибут на участке выставляет цикл ниже (база может назначиться чуть позже).
	lockedUntil[owner] = now() + seconds
	lockKind[owner] = kind
	if kind == "lock" then
		lockReadyAt[owner] = lockedUntil[owner] + StealService.LOCK_COOLDOWN
	end
end

-- Сколько брейнротов хозяина сейчас несут воры. Пока > 0, перерождаться нельзя
-- (иначе неудачная кража вернула бы брейнрота в уже «чистую» базу).
local function updateRobbed(owner)
	local count = 0
	for _, carry in pairs(carries) do
		if carry.owner == owner then
			count += 1
		end
	end
	if owner.Parent then
		owner:SetAttribute("BeingRobbed", count > 0 and count or nil)
	end
end

-- Брейнрот над головой вора.
local function makeCarryVisual(thief, entry)
	local character = thief.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return nil, nil
	end
	local creature = Creatures.get(entry.id)
	local rarity = Rarities.get(creature.rarity)
	local mutation = Mutations.get(entry.mut)

	-- Модель уменьшаем и приклеиваем к голове вора.
	local model, body = CreatureModel.build(entry.id, entry.mut, head.CFrame * CFrame.new(0, 0.6, 0), entry.skin)
	model.Name = "StolenBrainrot"
	local scale = math.min(1, 2.5 / creature.size)
	model:ScaleTo(scale)
	model:PivotTo(head.CFrame * CFrame.new(0, 0.6, 0))
	for _, piece in ipairs(model:GetDescendants()) do
		if piece:IsA("BasePart") then
			piece.Massless = true
			piece.Anchored = false
			if piece ~= body then
				local inner = Instance.new("WeldConstraint")
				inner.Part0 = body
				inner.Part1 = piece
				inner.Parent = piece
			end
		end
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = body
	weld.Parent = body
	local size = (model:GetAttribute("Height") or creature.size) * scale

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 40)
	gui.StudsOffset = Vector3.new(0, size / 2 + 1.2, 0)
	gui.Parent = body
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = rarity.color
	label.TextStrokeTransparency = 0.2
	label.Text = "🦹 " .. displayName(entry)
	label.Parent = gui

	model.Parent = character

	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(255, 40, 60)
	highlight.FillTransparency = 0.6
	highlight.OutlineColor = Color3.fromRGB(255, 40, 60)
	highlight.Parent = character

	return model, highlight
end

local function endCarry(thief, success, reason)
	local carry = carries[thief]
	if not carry then
		return
	end
	carries[thief] = nil

	if carry.visual then
		carry.visual:Destroy()
	end
	if carry.highlight then
		carry.highlight:Destroy()
	end
	if carry.diedConn then
		carry.diedConn:Disconnect()
	end
	local humanoid = humanoidOf(thief)
	if humanoid then
		humanoid.WalkSpeed = StealService.NORMAL_SPEED
	end
	thief:SetAttribute("CarryDeadline", nil)

	local owner = carry.owner
	local entry = carry.entry
	local name = displayName(entry)
	updateRobbed(owner)

	-- Перед зачислением ещё раз проверяем место: вор мог забить базу, пока бежал.
	local thiefData = success and DataService.get(thief)
	if success and not thiefData then
		success, reason = false, "вор вышел"
	elseif success and #thiefData.creatures >= Formulas.slots(thiefData, MonetizationService.passes(thief)) then
		success, reason = false, "на твоей базе нет места"
	end

	if success then
		do
			local newEntry = { uid = tostring(thiefData.nextUid), id = entry.id, mut = entry.mut, paid = entry.paid, skin = entry.skin }
			thiefData.nextUid += 1
			table.insert(thiefData.creatures, newEntry)
			thiefData.index[entry.id] = true
			thiefData.stats.stolen = (thiefData.stats.stolen or 0) + 1
			Actions.fire(thief, "steal", 1)
			local rarity = Rarities.get(Creatures.get(entry.id).rarity)
			ProgressionService.addXp(thief, thiefData, rarity.xp)
			DataService.markDirty(thief)
			PlotService.render(thief)
			Remotes.Notify:FireClient(thief, "🦹 Украдено: " .. name .. "!", GOOD)
			Remotes.Sfx:FireClient(thief, "success")

			if rarity.rank >= 5 then
				Remotes.Notify:FireAllClients(
					"🚨 " .. thief.DisplayName .. " украл " .. name .. " у " .. owner.DisplayName .. "!",
					rarity.color,
					true
				)
			end
		end
		local ownerData = owner.Parent and DataService.get(owner)
		if ownerData then
			ownerData.stats.lostToThieves = (ownerData.stats.lostToThieves or 0) + 1
			DataService.markDirty(owner)
			Remotes.Notify:FireClient(owner, "😭 " .. thief.DisplayName .. " украл твоего " .. name .. "!", BAD)
			Remotes.Sfx:FireClient(owner, "lose")
			-- Сразу сохраняем хозяина: в его прошлых сохранениях брейнрот ещё числился,
			-- и если сервер упадёт, он оказался бы у двоих.
			task.spawn(DataService.save, owner)
		end
		return
	end

	-- Неудача: брейнрот возвращается хозяину.
	local ownerData = DataService.get(owner)
	if ownerData then
		table.insert(ownerData.creatures, entry)
		DataService.markDirty(owner)
		PlotService.render(owner)
		if owner.Parent then
			Remotes.Notify:FireClient(owner, "✅ " .. name .. " вернулся домой!", GOOD)
		end
	end
	if thief.Parent then
		Remotes.Notify:FireClient(thief, "❌ Кража не удалась: " .. reason, BAD)
	end
end

local function startSteal(thief, prompt)
	-- Prompt -> Body -> модель брейнрота -> папка Creatures -> модель базы.
	local creaturesFolder = prompt:FindFirstAncestor("Creatures")
	local plotModel = creaturesFolder and creaturesFolder.Parent
	local owner = plotModel and PlotService.ownerOfModel(plotModel)
	local uid = prompt:GetAttribute("Uid")
	if closing or not owner or owner == thief or type(uid) ~= "string" then
		return
	end

	-- Защита от читеров: клиент мог «нажать» мгновенно или издалека.
	local hold = holdStart[thief]
	holdStart[thief] = nil
	local thiefRoot = rootOf(thief)
	local body = prompt.Parent
	if not hold or hold[1] ~= prompt or os.clock() - hold[2] < prompt.HoldDuration - 0.3 then
		return
	end
	if not thiefRoot or not body or (thiefRoot.Position - body.Position).Magnitude > prompt.MaxActivationDistance + 6 then
		return
	end

	if StealService.isLocked(owner) then
		Remotes.Notify:FireClient(thief, "🔒 База закрыта!", BAD)
		return
	end
	if carries[thief] then
		Remotes.Notify:FireClient(thief, "Ты уже несёшь брейнрота!", BAD)
		return
	end
	local thiefData = DataService.get(thief)
	local ownerData = DataService.get(owner)
	if not thiefData or not ownerData or not PlotService.getPlot(thief) then
		return
	end
	if #thiefData.creatures >= Formulas.slots(thiefData, MonetizationService.passes(thief)) then
		Remotes.Notify:FireClient(thief, "У тебя на базе нет места!", BAD)
		return
	end
	local humanoid = humanoidOf(thief)
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local entry
	for index, candidate in ipairs(ownerData.creatures) do
		if candidate.uid == uid then
			entry = table.remove(ownerData.creatures, index)
			break
		end
	end
	if not entry then
		return
	end

	local deadline = now() + StealService.CARRY_TIME
	local visual, highlight = makeCarryVisual(thief, entry)
	carries[thief] = {
		owner = owner,
		entry = entry,
		deadline = deadline,
		visual = visual,
		highlight = highlight,
		diedConn = humanoid.Died:Connect(function()
			endCarry(thief, false, "тебя победили")
		end),
	}
	humanoid.WalkSpeed = StealService.CARRY_SPEED
	thief:SetAttribute("CarryDeadline", deadline)
	updateRobbed(owner)

	DataService.markDirty(owner)
	PlotService.render(owner)

	local name = displayName(entry)
	Remotes.Notify:FireClient(thief, "🏃 Неси " .. name .. " на свою базу!", WARN)
	Remotes.Notify:FireClient(owner, "⚠️ " .. thief.DisplayName .. " крадёт " .. name .. "! Догони и шлёпни!", BAD)
	Remotes.Sfx:FireClient(owner, "alarm")
end

local function onLockPrompt(player, prompt)
	local plotModel = prompt:FindFirstAncestorWhichIsA("Model")
	local owner = plotModel and PlotService.ownerOfModel(plotModel)
	if owner ~= player then
		return
	end
	-- Защиту при входе можно «продлить» замком (это шаг обучения), обычный замок — нет.
	if StealService.isLocked(player) and lockKind[player] == "lock" then
		Remotes.Notify:FireClient(player, "База уже закрыта", WARN)
		return
	end
	local wait = (lockReadyAt[player] or 0) - now()
	if wait > 0 then
		Remotes.Notify:FireClient(player, "⏳ Замок перезаряжается: ещё " .. math.ceil(wait) .. " с", WARN)
		return
	end
	setLock(player, StealService.LOCK_TIME, "lock")
	Actions.fire(player, "lock", 1)
	Remotes.Notify:FireClient(player, "🔒 База закрыта на " .. StealService.LOCK_TIME .. " секунд", GOOD)
	Remotes.Sfx:FireClient(player, "lock")
end

-- Шлёпалка: отталкивает игроков. Если шлёпнуть вора — он роняет брейнрота.
local function slap(player)
	local nowClock = os.clock()
	if lastSlap[player] and nowClock - lastSlap[player] < StealService.SLAP_COOLDOWN then
		return
	end
	lastSlap[player] = nowClock

	local root = rootOf(player)
	if not root then
		return
	end
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local otherRoot = rootOf(other)
			local humanoid = humanoidOf(other)
			if otherRoot and humanoid and humanoid.Health > 0 then
				local offset = otherRoot.Position - root.Position
				local flat = Vector3.new(offset.X, 0, offset.Z)
				if flat.Magnitude <= StealService.SLAP_RANGE and flat.Magnitude > 0.01 then
					local facing = root.CFrame.LookVector
					if flat.Unit:Dot(Vector3.new(facing.X, 0, facing.Z).Unit) > 0.2 then
						local velocity = flat.Unit * StealService.SLAP_FORCE + Vector3.new(0, 35, 0)
						Remotes.Knockback:FireClient(other, velocity)
						Actions.fire(player, "slap", 1)
						if carries[other] then
							Actions.fire(player, "slapThief", 1)
							endCarry(other, false, player.DisplayName .. " тебя шлёпнул!")
							Remotes.Notify:FireClient(player, "👋 Шлёп! Вор уронил брейнрота!", GOOD)
							Remotes.Sfx:FireClient(player, "success")
						end
					end
				end
			end
		end
	end
end

local function createSlapper()
	local tool = Instance.new("Tool")
	tool.Name = "Шлёпалка"
	tool.ToolTip = "Шлёпни вора — он уронит брейнрота!"
	tool.CanBeDropped = false
	tool.RequiresHandle = true

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.6, 4, 0.6)
	handle.Color = Color3.fromRGB(255, 80, 160)
	handle.Material = Enum.Material.Neon
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local hand = Instance.new("Part")
	hand.Name = "Palm"
	hand.Size = Vector3.new(1.8, 1.8, 0.4)
	hand.Color = Color3.fromRGB(255, 200, 160)
	hand.CanCollide = false
	hand.Massless = true
	hand.CFrame = handle.CFrame * CFrame.new(0, 2.4, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = hand
	weld.Parent = hand
	hand.Parent = tool

	tool.GripPos = Vector3.new(0, -1.2, 0)
	return tool
end

local function watchTool(tool, player)
	tool.Activated:Connect(function()
		slap(player)
	end)
end

-- Отменить все кражи (брейнроты возвращаются хозяевам). Вызывается при выключении сервера,
-- чтобы кража не завершилась уже после последнего сохранения хозяина (иначе дюп).
function StealService.cancelAll(reason)
	for thief in pairs(carries) do
		endCarry(thief, false, reason)
	end
end

function StealService.init()
	DataService.onClose(function()
		closing = true
		StealService.cancelAll("сервер выключается")
	end)

	-- Пока вор несёт брейнрота, он должен попадать в сохранение хозяина.
	DataService.addSaveExtra(function(owner)
		local extras = {}
		for _, carry in pairs(carries) do
			if carry.owner == owner then
				table.insert(extras, carry.entry)
			end
		end
		return extras
	end)

	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt, player)
		if prompt.Name == "StealPrompt" then
			holdStart[player] = { prompt, os.clock() }
		end
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt.Name == "StealPrompt" then
			startSteal(player, prompt)
		elseif prompt.Name == "LockPrompt" then
			onLockPrompt(player, prompt)
		end
	end)

	-- Шлёпалка у каждого игрока.
	local template = createSlapper()
	template.Parent = StarterPack
	local function giveTool(player)
		player.CharacterAdded:Connect(function()
			local backpack = player:WaitForChild("Backpack")
			local tool = backpack:WaitForChild(template.Name, 5)
			if tool then
				watchTool(tool, player)
			end
		end)
		if player.Character then
			local backpack = player:FindFirstChildOfClass("Backpack")
			if backpack and not backpack:FindFirstChild(template.Name) and not player.Character:FindFirstChild(template.Name) then
				local tool = template:Clone()
				tool.Parent = backpack
				watchTool(tool, player)
			end
		end
	end
	Players.PlayerAdded:Connect(giveTool)
	for _, player in ipairs(Players:GetPlayers()) do
		giveTool(player)
	end

	-- Защита при входе.
	DataService.Loaded.Event:Connect(function(player)
		setLock(player, StealService.JOIN_SHIELD, "shield")
		task.delay(3, function()
			if player.Parent then
				Remotes.Notify:FireClient(player, "🛡️ Твоя база защищена " .. StealService.JOIN_SHIELD .. " секунд", GOOD)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		-- Вор вышел — брейнрот возвращается.
		endCarry(player, false, "вор вышел")
		-- Хозяин вышел — все кражи его брейнротов отменяются.
		for thief, carry in pairs(carries) do
			if carry.owner == player then
				endCarry(thief, false, "хозяин ушёл из игры")
			end
		end
		lockedUntil[player] = nil
		lockKind[player] = nil
		lockReadyAt[player] = nil
		holdStart[player] = nil
		lastSlap[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(0.2)
			local t = now()

			-- Замки: обновляем забор и выталкиваем чужаков.
			for _, owner in ipairs(Players:GetPlayers()) do
				local plot = PlotService.getPlot(owner)
				if plot then
					if plot.model:GetAttribute("LockedUntil") ~= lockedUntil[owner] then
						plot.model:SetAttribute("LockedUntil", lockedUntil[owner])
						plot.model:SetAttribute("LockKind", lockKind[owner])
						plot.model:SetAttribute("LockReadyAt", lockReadyAt[owner])
					end
					local locked = (lockedUntil[owner] or 0) > t
					PlotService.setLockVisual(plot, locked, (lockedUntil[owner] or 0) - t)
					if locked then
						for _, other in ipairs(Players:GetPlayers()) do
							local root = other ~= owner and rootOf(other)
							if root and PlotService.isInside(plot, root.Position) then
								other.Character:PivotTo(PlotService.outsideCFrame(plot, root.Position))
							end
						end
					end
				end
			end

			-- Кражи: добежал до базы или время вышло.
			for thief, carry in pairs(carries) do
				local plot = PlotService.getPlot(thief)
				local root = rootOf(thief)
				if plot and root and PlotService.isInside(plot, root.Position) then
					endCarry(thief, true)
				elseif t > carry.deadline then
					endCarry(thief, false, "время вышло")
				end
			end
		end
	end)
end

return StealService
