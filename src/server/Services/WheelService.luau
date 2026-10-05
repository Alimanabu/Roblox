-- Колесо удачи: 1 бесплатное вращение в день + купленные за Robux.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Daily = require(Shared.Config.Daily)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local RewardService = require(script.Parent.RewardService)

local WheelService = {}

local GOLD = Color3.fromRGB(255, 220, 80)
local BAD = Color3.fromRGB(255, 110, 110)
local SPIN_COOLDOWN = 3 -- столько длится анимация на клиенте

local rng = Random.new()
local lastSpin = {} -- [player] = os.clock()

local function roll()
	local total = 0
	for _, slot in ipairs(Daily.Wheel) do
		total += slot.weight
	end
	local pick = rng:NextNumber() * total
	for index, slot in ipairs(Daily.Wheel) do
		pick -= slot.weight
		if pick < 0 then
			return index
		end
	end
	return 1
end

local function spin(player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local now = os.clock()
	if lastSpin[player] and now - lastSpin[player] < SPIN_COOLDOWN then
		return
	end
	local today = Daily.today()
	if data.wheel.lastFreeDay ~= today then
		data.wheel.lastFreeDay = today
	elseif data.wheel.extraSpins > 0 then
		data.wheel.extraSpins -= 1
	else
		Remotes.Notify:FireClient(player, "Вращения кончились. Бесплатное будет завтра 🎡", BAD)
		return
	end
	lastSpin[player] = now

	local index = roll()
	local slot = Daily.Wheel[index]
	Remotes.WheelResult:FireClient(player, index)
	-- Награду выдаём сразу (сохранится), а сообщение — когда колесо остановится.
	local text = RewardService.grant(player, data, slot.reward)
	DataService.markDirty(player)
	task.delay(SPIN_COOLDOWN, function()
		if player.Parent then
			Remotes.Notify:FireClient(player, "🎡 Колесо: " .. slot.name .. " → " .. text, GOLD)
			Remotes.Sfx:FireClient(player, "success")
		end
	end)
end

function WheelService.snapshot(data)
	return {
		freeAvailable = data.wheel.lastFreeDay ~= Daily.today(),
		extraSpins = data.wheel.extraSpins,
	}
end

function WheelService.init()
	Remotes.SpinWheel.OnServerEvent:Connect(spin)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastSpin[player] = nil
	end)
end

return WheelService
