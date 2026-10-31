-- Проверка скорости: позицию персонажа присылает клиент, поэтому читер может «телепортироваться».
-- Сервер следит, сколько игрок прошёл и за какое время. У каждого есть запас пути по горизонтали:
-- он растёт со скоростью бега и тратится на каждый студ. Подъём считается отдельно, иначе прыжки
-- съедали бы путь. Запас ушёл в минус — игрок не мог дойти сюда сам, и пока запас не вернётся
-- (столько, сколько занял бы путь пешком), кража, шлепок и поимка отклоняются.

local Players = game:GetService("Players")

local MoveGuardService = {}

MoveGuardService.SAMPLE_EVERY = 0.2
MoveGuardService.SPEED_MARGIN = 1.35 -- запас к скорости: прыжки, склоны, неровная отправка позиции
MoveGuardService.LAG_SECONDS = 3 -- запас пути = 3 с бега (48 студов при 16, 36 при 12): столько обрыва связи прощаем
MoveGuardService.MIN_LAG_SPEED = 12 -- оглушённый вор стоит на месте, но запас у него не сгорает
MoveGuardService.CLIMB_RATE = 15 -- студов вверх в секунду: прыжки подряд дают 12 (7,2 за 0,6 с), пандус 6,8
MoveGuardService.MAX_CLIMB = 10 -- меньше высоты 2 этажа (14): за один раз туда не попасть
MoveGuardService.DROP_BELOW = -30 -- ниже этого запаса кража срывается: это уже не сбой связи
MoveGuardService.TELEPORT_GRACE = 1 -- секунд после переноса сервером: клиент ещё шлёт старую позицию,
-- в это время путь считаем от ближайшей из точек «откуда» и «куда»: другие места не бесплатны
MoveGuardService.KNOCKBACK_SECONDS = 1.5 -- сколько длится отлёт от удара

-- Запас живёт дольше персонажа: сброс и смерть не должны возвращать его.
local tracks = {} -- [player] = { root, position, time, budget, climb, graceUntil, serverFrom, serverTo, free, freeUntil }
local spawnPoint = Vector3.zero -- сюда Roblox ставит нового персонажа

local function rootOf(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function horizontal(from, to)
	local dx, dz = to.X - from.X, to.Z - from.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- Падение не считаем: вниз можно лететь быстрее бега.
local function climb(from, to)
	return math.max(0, to.Y - from.Y)
end

function MoveGuardService.maxBudget(speed)
	return MoveGuardService.LAG_SECONDS * math.max(speed, MoveGuardService.MIN_LAG_SPEED)
end

function MoveGuardService.setSpawnPoint(position)
	spawnPoint = position
end

-- Сколько стоит дойти до position: сразу после переноса сервером — от ближайшей известной точки.
local function pathTo(track, position, now)
	local moved, up = horizontal(track.position, position), climb(track.position, position)
	if now < track.graceUntil then
		for _, point in ipairs({ track.serverFrom, track.serverTo }) do
			moved = math.min(moved, horizontal(point, position))
			up = math.min(up, climb(point, position))
		end
	end
	return moved, up
end

local function observe(player)
	local root = rootOf(player)
	local track = tracks[player]
	if not root or not root:IsDescendantOf(workspace) then
		return track
	end
	local now = os.clock()
	if not track then
		track = { time = now, budget = MoveGuardService.maxBudget(16), climb = MoveGuardService.MAX_CLIMB, graceUntil = 0, free = 0, freeUntil = 0 }
		tracks[player] = track
	end
	if track.root ~= root then
		-- Новый персонаж начинает путь с точки спавна, дальше его ведёт сервер.
		track.root, track.position, track.graceUntil = root, spawnPoint, 0
	end

	local moved, up = pathTo(track, root.Position, now)
	local elapsed = now - track.time
	track.position, track.time = root.Position, now
	if now < track.freeUntil then
		local forgiven = math.min(track.free, moved)
		track.free -= forgiven
		moved -= forgiven
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local speed = humanoid and humanoid.WalkSpeed or 16
	local cap = MoveGuardService.maxBudget(speed)
	track.budget = math.min(cap, track.budget + speed * MoveGuardService.SPEED_MARGIN * elapsed) - moved
	track.climb = math.min(MoveGuardService.MAX_CLIMB, track.climb + MoveGuardService.CLIMB_RATE * elapsed) - up
	return track
end

-- false: игрок оказался там, куда не мог дойти. Проверять перед каждым действием на сервере.
function MoveGuardService.canAct(player)
	local track = observe(player)
	return track == nil or (track.budget >= 0 and track.climb >= 0)
end

-- true: запас ушёл далеко в минус, это не сбой связи. Несущий брейнрота его роняет.
function MoveGuardService.exceeded(player)
	local track = observe(player)
	return track ~= nil and (track.budget < MoveGuardService.DROP_BELOW or track.climb < MoveGuardService.DROP_BELOW)
end

-- Мог ли игрок со скоростью speed пройти от from до to, начав в момент since (os.clock()).
function MoveGuardService.couldWalk(from, since, to, speed)
	return horizontal(from, to) <= speed * MoveGuardService.SPEED_MARGIN * (os.clock() - since)
end

-- Сервер сам переносит персонажа в target (телепорт домой, забор замка). Вызывать до переноса.
function MoveGuardService.teleported(player, target)
	local track = observe(player)
	if track then
		track.serverFrom, track.serverTo = track.position, target
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
