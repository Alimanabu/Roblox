-- Проверка скорости: позицию персонажа присылает клиент, поэтому читер может «телепортироваться».
-- Сервер следит, сколько игрок прошёл и за какое время. У каждого есть запас пути: он растёт
-- со скоростью бега и тратится на каждый студ. Запас ушёл в минус — игрок не мог дойти сюда сам,
-- и пока запас не вернётся (столько, сколько занял бы путь пешком), кража, шлепок и поимка отклоняются.

local Players = game:GetService("Players")

local MoveGuardService = {}

MoveGuardService.SAMPLE_EVERY = 0.2
MoveGuardService.SPEED_MARGIN = 1.35 -- запас к скорости: прыжки, склоны, неровная отправка позиции
MoveGuardService.MAX_BUDGET = 50 -- студов: столько можно накопить, это ~4 с обрыва связи на бегу
MoveGuardService.TELEPORT_GRACE = 1 -- секунд после переноса сервером: клиент ещё шлёт старую позицию
MoveGuardService.KNOCKBACK_SECONDS = 1.5 -- сколько длится отлёт от удара

local tracks = {} -- [player] = { root, position, time, budget, graceUntil, free, freeUntil }

local function rootOf(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

-- Падение не считаем: вниз можно лететь быстрее бега.
local function distance(from, to)
	local dx, dz = to.X - from.X, to.Z - from.Z
	local up = math.max(0, to.Y - from.Y)
	return math.sqrt(dx * dx + dz * dz + up * up)
end

local function observe(player)
	local root = rootOf(player)
	if not root then
		tracks[player] = nil
		return nil
	end
	local now = os.clock()
	local track = tracks[player]
	if not track or track.root ~= root then
		-- Новый персонаж появляется, где решит сервер: с него ничего не спрашиваем.
		track = { root = root, position = root.Position, time = now, budget = MoveGuardService.MAX_BUDGET, graceUntil = now + MoveGuardService.TELEPORT_GRACE, free = 0, freeUntil = 0 }
		tracks[player] = track
		return track
	end

	local moved = distance(track.position, root.Position)
	local elapsed = now - track.time
	track.position, track.time = root.Position, now
	if now < track.graceUntil then
		return track
	end
	if now < track.freeUntil then
		local forgiven = math.min(track.free, moved)
		track.free -= forgiven
		moved -= forgiven
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local speed = humanoid and humanoid.WalkSpeed or 16
	track.budget = math.min(MoveGuardService.MAX_BUDGET, track.budget + speed * MoveGuardService.SPEED_MARGIN * elapsed) - moved
	return track
end

-- false: игрок оказался там, куда не мог дойти. Проверять перед каждым действием на сервере.
function MoveGuardService.canAct(player)
	local track = observe(player)
	return track == nil or track.budget >= 0
end

-- Мог ли игрок со скоростью speed пройти от from до to, начав в момент since (os.clock()).
function MoveGuardService.couldWalk(from, since, to, speed)
	return distance(from, to) <= speed * MoveGuardService.SPEED_MARGIN * (os.clock() - since)
end

-- Сервер сам перенёс персонажа (телепорт домой, забор замка).
function MoveGuardService.teleported(player)
	local track = observe(player)
	if track then
		track.graceUntil = os.clock() + MoveGuardService.TELEPORT_GRACE
	end
end

-- Сервер толкнул игрока ударом: этот путь бесплатный, но не больше, чем мог дать удар.
function MoveGuardService.knockback(player, speed)
	local track = observe(player)
	if track then
		track.free = speed * MoveGuardService.KNOCKBACK_SECONDS
		track.freeUntil = os.clock() + MoveGuardService.KNOCKBACK_SECONDS
	end
end

function MoveGuardService.init()
	Players.PlayerRemoving:Connect(function(player)
		tracks[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(MoveGuardService.SAMPLE_EVERY)
			for _, player in ipairs(Players:GetPlayers()) do
				observe(player)
			end
		end
	end)
end

return MoveGuardService
