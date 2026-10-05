-- Босс-брейнрот: каждый час (Events.Boss) на площадь приходит огромный брейнрот.
-- Игроки шлёпают его Шлёпалкой; он раз в несколько секунд отбрасывает всех рядом.
-- Победили — награда всем по вкладу, лучшему бойцу ещё и брейнрот «Аура».

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Events = require(Shared.Config.Events)
local CreatureModel = require(Shared.Util.CreatureModel)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local RewardService = require(script.Parent.RewardService)
local Actions = require(script.Parent.Actions)

local BossService = {}

BossService.POSITION = CFrame.new(0, 0, 34) * CFrame.Angles(0, math.pi, 0)
BossService.SCALE = 3
BossService.HIT_RANGE = 10 -- от края босса
BossService.DAMAGE = 10
BossService.BASE_HP = 300
BossService.HP_PER_PLAYER = 200
BossService.SHOCKWAVE_EVERY = 5
BossService.SHOCKWAVE_RADIUS = 16 -- не достаёт до спавна в центре площади

local GOLD = Color3.fromRGB(255, 220, 80)
local RED = Color3.fromRGB(255, 80, 80)

local boss = nil -- { model, radius, hp, maxHp, damage = { [player] = n }, label, fill }
local finishedUntil = 0 -- босса уже победили: до конца этого окна ивента не появляется

-- Возвращает время конца текущего окна босса или nil.
local function bossWindowEnd()
	for _, active in ipairs(Events.active(os.time())) do
		if active.event.id == Events.Boss.id then
			return active.endsAt
		end
	end
	return nil
end

local function updateBar()
	if not boss then
		return
	end
	local ratio = math.clamp(boss.hp / boss.maxHp, 0, 1)
	boss.fill.Size = UDim2.fromScale(ratio, 1)
	boss.label.Text = string.format("👹 Орсо Огайо — %d / %d", math.ceil(boss.hp), boss.maxHp)
end

local function spawnBoss()
	local model = CreatureModel.build("orso_ohio", "cosmic", BossService.POSITION)
	model.Name = "Boss"
	model:ScaleTo(BossService.SCALE)
	model:PivotTo(BossService.POSITION)
	-- Покачивание делает клиент (плавно), сервер модель не двигает.
	model:SetAttribute("BaseCFrame", BossService.POSITION)
	for _, piece in ipairs(model:GetDescendants()) do
		if piece:IsA("BasePart") then
			piece.CanCollide = true
		end
	end
	model.Parent = workspace

	local size = model:GetExtentsSize()
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(360, 60)
	gui.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + 4, 0)
	gui.MaxDistance = 250
	gui.AlwaysOnTop = true
	gui.Parent = model.PrimaryPart

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, 0, 0, 24)
	bar.Position = UDim2.fromOffset(0, 32)
	bar.BackgroundColor3 = Color3.fromRGB(40, 20, 30)
	bar.Parent = gui
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = RED
	fill.BorderSizePixel = 0
	fill.Parent = bar
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 30)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Parent = gui

	local maxHp = BossService.BASE_HP + BossService.HP_PER_PLAYER * #Players:GetPlayers()
	boss = {
		endsAt = bossWindowEnd() or os.time(),
		model = model,
		radius = math.max(size.X, size.Z) / 2,
		hp = maxHp,
		maxHp = maxHp,
		damage = {},
		label = label,
		fill = fill,
		lastShockwave = os.clock(),
	}
	updateBar()
	Remotes.Notify:FireAllClients("👹 Босс-брейнрот пришёл на площадь! Бегите шлёпать!", RED)
	Remotes.Sfx:FireAllClients("alarm")
end

local function despawn(defeated)
	if not boss then
		return
	end
	local current = boss
	boss = nil
	current.model:Destroy()
	-- Не появляемся снова ни в этом окне, ни в «ручном» окне из панели «🛠 Тест».
	local forcedUntil = workspace:GetAttribute("ForcedEvent") == Events.Boss.id
			and (workspace:GetAttribute("ForcedEventUntil") or 0)
		or 0
	finishedUntil = math.max(current.endsAt, bossWindowEnd() or 0, forcedUntil)

	if not defeated then
		Remotes.Notify:FireAllClients("👹 Босс сбежал... В следующий раз шлёпайте сильнее!", RED)
		return
	end

	local total, best, bestDamage = 0, nil, 0
	for player, damage in pairs(current.damage) do
		if player.Parent then
			total += damage -- ушедшие игроки не уменьшают доли остальных
		end
		if damage > bestDamage and player.Parent then
			best, bestDamage = player, damage
		end
	end
	Remotes.Notify:FireAllClients(
		"🏆 Босс повержен!" .. (best and (" Лучший боец: " .. best.DisplayName) or ""),
		GOLD
	)
	for player, damage in pairs(current.damage) do
		local data = player.Parent and DataService.get(player)
		if data and total > 0 then
			local share = damage / total
			local reward = { coinsMinutes = math.floor(5 + 15 * share), luckMinutes = 10 }
			if player == best then
				reward.creatureRarity = "aura"
			end
			local text = RewardService.grant(player, data, reward)
			Remotes.Notify:FireClient(player, "👹 Награда за босса: " .. text, GOLD)
			Remotes.Sfx:FireClient(player, "success")
			Actions.fire(player, "bossKill", 1)
		end
	end
end

-- Вызывается из Шлёпалки (StealService.slap). Возвращает true, если попали по боссу.
function BossService.tryHit(player, root)
	if not boss or boss.hp <= 0 then
		return false
	end
	local center = boss.model:GetPivot().Position
	local offset = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z)
	if offset.Magnitude > boss.radius + BossService.HIT_RANGE then
		return false
	end
	boss.hp -= BossService.DAMAGE
	boss.damage[player] = (boss.damage[player] or 0) + BossService.DAMAGE
	updateBar()
	if boss.hp <= 0 then
		despawn(true)
	end
	return true
end

local function shockwave()
	local center = boss.model:GetPivot().Position
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local offset = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z)
			if offset.Magnitude < boss.radius + BossService.SHOCKWAVE_RADIUS and offset.Magnitude > 0.01 then
				Remotes.Knockback:FireClient(player, offset.Unit * 60 + Vector3.new(0, 45, 0))
			end
		end
	end
end

function BossService.init()
	-- Повторный запуск босса из панели «🛠 Тест» должен работать и после победы.
	workspace:GetAttributeChangedSignal("ForcedEventUntil"):Connect(function()
		finishedUntil = 0
	end)
	-- Кто-то зашёл, пока идёт бой — босс становится крепче.
	Players.PlayerAdded:Connect(function()
		if boss then
			boss.maxHp += BossService.HP_PER_PLAYER
			boss.hp += BossService.HP_PER_PLAYER
			updateBar()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.1)
			local windowEnd = bossWindowEnd()
			local active = windowEnd ~= nil and os.time() >= finishedUntil
			if active and not boss then
				spawnBoss()
			elseif not active and boss then
				despawn(false)
			end
			if boss then
				local t = os.clock()
				if t - boss.lastShockwave > BossService.SHOCKWAVE_EVERY then
					boss.lastShockwave = t
					shockwave()
				end
			end
		end
	end)
end

return BossService
