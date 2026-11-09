-- Speed check: the client sends the character position, so a cheater can "teleport".
-- The server tracks how far the player went and in what time. Each has a horizontal path budget:
-- it grows at running speed and is spent on every stud. Climbing is counted separately, otherwise jumps
-- would eat the path. If the budget goes negative, the player could not have walked here, and until the budget recovers
-- (as much as the walk would take), stealing, slapping and catching are rejected.

local Players = game:GetService("Players")

local MoveGuardService = {}

MoveGuardService.SAMPLE_EVERY = 0.2
MoveGuardService.SPEED_MARGIN = 1.35 -- margin on speed: jumps, slopes, uneven position sending
MoveGuardService.LAG_SECONDS = 3 -- path budget = 3 s of running (48 studs at 16, 36 at 12): this much connection loss is forgiven
MoveGuardService.MIN_LAG_SPEED = 12 -- a stunned thief stands still, but his budget does not burn
MoveGuardService.CLIMB_RATE = 15 -- studs up per second: consecutive jumps give 12 (7.2 in 0.6 s), a ramp 6.8
MoveGuardService.MAX_CLIMB = 10 -- less than the height of floor 2 (14): cannot get there in one go
MoveGuardService.DROP_BELOW = -30 -- below this budget the steal fails: this is no longer a connection glitch
MoveGuardService.TELEPORT_GRACE = 1 -- seconds after a server-side move: the client still sends the old position,
-- during this time the path is counted from the nearest of the "from" and "to" points: other places are not free
MoveGuardService.KNOCKBACK_SECONDS = 1.5 -- how long the knockback from a hit lasts

-- The budget outlives the character: reset and death must not bring it back.
local tracks = {} -- [player] = { root, position, time, budget, climb, graceUntil, serverFrom, serverTo, free, freeUntil }
local spawnPoint = Vector3.zero -- Roblox puts a new character here

local function rootOf(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function horizontal(from, to)
	local dx, dz = to.X - from.X, to.Z - from.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- We do not count falling: you can fall faster than running.
local function climb(from, to)
	return math.max(0, to.Y - from.Y)
end

function MoveGuardService.maxBudget(speed)
	return MoveGuardService.LAG_SECONDS * math.max(speed, MoveGuardService.MIN_LAG_SPEED)
end

function MoveGuardService.setSpawnPoint(position)
	spawnPoint = position
end

-- How much it costs to reach position: right after a server move, from the nearest known point.
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
		-- A new character starts its path from the spawn point, after that the server leads it.
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

-- false: the player ended up where they could not have walked. Check before every action on the server.
function MoveGuardService.canAct(player)
	local track = observe(player)
	return track == nil or (track.budget >= 0 and track.climb >= 0)
end

-- true: the budget went far negative, this is not a connection glitch. The carrier drops the brainrot.
function MoveGuardService.exceeded(player)
	local track = observe(player)
	return track ~= nil and (track.budget < MoveGuardService.DROP_BELOW or track.climb < MoveGuardService.DROP_BELOW)
end

-- Could a player with speed speed walk from from to to, starting at time since (os.clock()).
function MoveGuardService.couldWalk(from, since, to, speed)
	return horizontal(from, to) <= speed * MoveGuardService.SPEED_MARGIN * (os.clock() - since)
end

-- The server itself moves the character to target (teleport home, lock pickup). Call before the move.
function MoveGuardService.teleported(player, target)
	local track = observe(player)
	if track then
		track.serverFrom, track.serverTo = track.position, target
		track.graceUntil = os.clock() + MoveGuardService.TELEPORT_GRACE
	end
end

-- The server pushed the player with a hit: this path is free, but no more than the hit could give.
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
