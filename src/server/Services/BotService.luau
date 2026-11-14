-- NPC bots: while fewer than Bots.MinHumans live players are on the server, 2-3 bots with a "[BOT]" label walk
-- around, catch wild brainrots, "craft" at a free base, steal from players and slap with the Slapper.
--
-- Rules (decision 14.11): a bot is NOT a Player. It has no profile and no DataStore entry, it never appears in a
-- leaderboard and it is not counted in any player count (Players:GetPlayers() does not return it).
-- It plays by the same rules as a newbie: walk speed 16 (12 with a brainrot), the Slapper through the same
-- StealService.slap (same cooldown, range and force), stunned brainrots, locks, the join shield and traps work on it.
-- Being kind to real people: a bot never takes a paid random brainrot or one of the rare ones announced to the server,
-- leaves players who are still in the tutorial alone, robs one owner at most once per OWNER_COOLDOWN and only one bot
-- steals at a time. A player can slap a thief bot: it drops the brainrot and the owner gets it back.
-- The behaviour is updated at most 4 times per second (TICK).

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local Tutorial = require(Shared.Config.Tutorial)
local Bots = require(Shared.Config.Bots)
local Formulas = require(Shared.Util.Formulas)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local StealService = require(script.Parent.StealService)
local WildService = require(script.Parent.WildService)

local BotService = {}

BotService.TICK = 0.25 -- seconds between behaviour updates (not more than 4 per second)
BotService.SPAWN_GAP = 2.5 -- one bot appears at a time
BotService.LEAVE_GAP = 10 -- one bot leaves at a time, and the next one not sooner than this
BotService.LEAVE_TIMEOUT = 15
BotService.STEAL_COOLDOWN = { 60, 120 } -- per bot, between two steal attempts
BotService.FIRST_STEAL_DELAY = { 30, 60 } -- a new bot does not steal right away
BotService.OWNER_COOLDOWN = 300 -- one owner is robbed by bots at most once in this time
BotService.MAX_STEAL_TIME = 45 -- approach + slapping + holding F, then the attempt is dropped
BotService.STAND_RANGE = 5.5 -- how close to the brainrot the bot stands (the slap reaches 9)
BotService.MAX_WILD_RANK = 4 -- the rarer wild ones (announced to the server) are left for players
BotService.CRAFT_TIME = 5
BotService.RETALIATE_WINDOW = 4 -- a bot slaps back once if a player hit it this recently
BotService.EXIT_RADIUS = 245
-- How likely each activity is when the bot chooses (an activity without a possible target is skipped).
BotService.weights = { steal = 2, collect = 3, craft = 2, wander = 2 }
BotService.rng = Random.new()
BotService.failures = 0 -- errors of the behaviour code (the loop survives them; the tests require 0)
BotService.lastError = nil

local WALK_ANIMATION = "rbxassetid://180426354" -- Roblox's own R6 walk
local SKIN = Color3.fromRGB(255, 204, 153)
local OUTFITS = {
	{ Color3.fromRGB(255, 80, 160), Color3.fromRGB(40, 40, 90) },
	{ Color3.fromRGB(80, 200, 255), Color3.fromRGB(60, 60, 60) },
	{ Color3.fromRGB(120, 230, 90), Color3.fromRGB(90, 60, 40) },
	{ Color3.fromRGB(255, 200, 60), Color3.fromRGB(50, 50, 110) },
}

local pathfinding = nil
pcall(function()
	pathfinding = game:GetService("PathfindingService")
end)

local folder
local bots = {} -- live bots in the order they appeared
local counter = 0
local lastSpawn = -math.huge
local lastLeave = -math.huge
local lastRobbed = setmetatable({}, { __mode = "k" }) -- [owner] = os.clock() of the last bot theft

local function rootOf(bot)
	local character = bot.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function humanoidOf(bot)
	local character = bot.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function flat(a, b)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

local function between(range)
	return BotService.rng:NextNumber(range[1], range[2])
end

-- A random point on the map: not on a base, not in the middle of the plaza.
local function randomSpot()
	for _ = 1, 30 do
		local angle = BotService.rng:NextNumber() * math.pi * 2
		local radius = BotService.rng:NextNumber(40, 225)
		local position = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		if not PlotService.isOnAnyPlot(position, 6) then
			return position
		end
	end
	return Vector3.new(0, 0, 60)
end

-- The body: a plain R6 dummy built from parts (a Humanoid with Motor6D joints), so no avatar download is needed.
local function newPart(model, name, size, position, color)
	local item = Instance.new("Part")
	item.Name = name
	item.Size = size
	item.CFrame = CFrame.new(position)
	item.Color = color
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	item.Parent = model
	return item
end

local function joint(name, part0, part1, c0, c1)
	local motor = Instance.new("Motor6D")
	motor.Name = name
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = c0
	motor.C1 = c1
	motor.Parent = part0
end

local function buildRig(name, outfit, at)
	local shirt, pants = outfit[1], outfit[2]
	local model = Instance.new("Model")
	model.Name = "Bot_" .. name
	local root = newPart(model, "HumanoidRootPart", Vector3.new(2, 2, 1), at, shirt)
	root.Transparency = 1
	local torso = newPart(model, "Torso", Vector3.new(2, 2, 1), at, shirt)
	local head = newPart(model, "Head", Vector3.new(2, 1, 1), at + Vector3.new(0, 1.5, 0), SKIN)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = head
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	face.Parent = head
	local rightArm = newPart(model, "Right Arm", Vector3.new(1, 2, 1), at + Vector3.new(1.5, 0, 0), SKIN)
	local leftArm = newPart(model, "Left Arm", Vector3.new(1, 2, 1), at + Vector3.new(-1.5, 0, 0), SKIN)
	local rightLeg = newPart(model, "Right Leg", Vector3.new(1, 2, 1), at + Vector3.new(0.5, -2, 0), pants)
	local leftLeg = newPart(model, "Left Leg", Vector3.new(1, 2, 1), at + Vector3.new(-0.5, -2, 0), pants)

	-- The standard R6 joints (the same offsets Roblox uses for its own R6 characters).
	local turn = CFrame.Angles(-math.pi / 2, math.pi, 0)
	local quarter = math.pi / 2
	joint("RootJoint", root, torso, CFrame.new(0, 0, 0) * turn, CFrame.new(0, 0, 0) * turn)
	joint("Neck", torso, head, CFrame.new(0, 1, 0) * turn, CFrame.new(0, -0.5, 0) * turn)
	joint("Right Shoulder", torso, rightArm, CFrame.new(1, 0.5, 0) * CFrame.Angles(0, quarter, 0), CFrame.new(-0.5, 0.5, 0) * CFrame.Angles(0, quarter, 0))
	joint("Left Shoulder", torso, leftArm, CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, -quarter, 0), CFrame.new(0.5, 0.5, 0) * CFrame.Angles(0, -quarter, 0))
	joint("Right Hip", torso, rightLeg, CFrame.new(1, -1, 0) * CFrame.Angles(0, quarter, 0), CFrame.new(0.5, 1, 0) * CFrame.Angles(0, quarter, 0))
	joint("Left Hip", torso, leftLeg, CFrame.new(-1, -1, 0) * CFrame.Angles(0, -quarter, 0), CFrame.new(-0.5, 1, 0) * CFrame.Angles(0, -quarter, 0))

	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.WalkSpeed = StealService.NORMAL_SPEED
	humanoid.JumpPower = 50
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- we draw our own "[BOT]" label
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.Parent = model
	model.PrimaryPart = root
	return model, head
end

local function addLabel(head, text)
	local gui = Instance.new("BillboardGui")
	gui.Name = "BotLabel"
	gui.Size = UDim2.fromOffset(200, 36)
	gui.StudsOffset = Vector3.new(0, 2.2, 0)
	gui.MaxDistance = 120
	gui.Parent = head
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(190, 190, 255)
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = gui
end

-- The walking animation is only decoration: if anything about it fails the bot still works.
local function addWalkAnimation(humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = WALK_ANIMATION
	local track = animator:LoadAnimation(animation)
	humanoid.Running:Connect(function(speed)
		if speed > 0.5 then
			if not track.IsPlaying then
				track:Play()
			end
		else
			track:Stop()
		end
	end)
end

local function spawnBot(now)
	counter += 1
	local name = Bots.Names[(counter - 1) % #Bots.Names + 1]
	local at = Vector3.new(BotService.rng:NextNumber(-8, 8), 5, BotService.rng:NextNumber(-8, 8))
	local model, head = buildRig(name, OUTFITS[(counter - 1) % #OUTFITS + 1], at)
	local bot = {
		IsBot = true, -- StealService treats it as an actor, not as a Player
		Name = "Bot_" .. name,
		DisplayName = Bots.Tag .. " " .. name,
		UserId = -(1000 + counter), -- negative: never equal to a real UserId
		Character = model,
		Parent = folder,
		attrs = {},
		state = "idle",
		since = now,
		idleUntil = now + BotService.rng:NextNumber(1, 3),
		nextStealAt = now + between(BotService.FIRST_STEAL_DELAY),
		stash = 0, -- what it caught, crafted and stole (a bot keeps no inventory anywhere, this is only a counter)
		collected = 0,
		crafted = 0,
		stolen = 0,
		leaving = false,
	}
	function bot:SetAttribute(key, value)
		self.attrs[key] = value
	end
	addLabel(head, bot.DisplayName)
	model.Parent = folder
	pcall(function()
		-- The server drives the bot: no player may own its physics.
		rootOf(bot):SetNetworkOwner(nil)
	end)
	pcall(addWalkAnimation, humanoidOf(bot))
	pcall(function()
		local tool = StealService.newSlapper()
		tool.Parent = model
	end)
	table.insert(bots, bot)
	lastSpawn = now
	return bot
end

local function removeBot(bot, now)
	StealService.releaseBot(bot)
	local index = table.find(bots, bot)
	if index then
		table.remove(bots, index)
	end
	if bot.Character then
		bot.Character:Destroy()
	end
	bot.removed = true
	lastLeave = now
end

-- Movement -------------------------------------------------------------------------

-- The default mover: follow a computed path on long trips, otherwise walk straight. The tests replace it.
BotService.mover = function(bot, target)
	local root, humanoid = rootOf(bot), humanoidOf(bot)
	if not root or not humanoid then
		return
	end
	if not pathfinding or flat(root.Position, target) < 14 then
		bot.waypoints = nil
		humanoid:MoveTo(target)
		return
	end
	local now = os.clock()
	if not bot.waypoints or not bot.pathTarget or (bot.pathTarget - target).Magnitude > 8 or now - bot.pathAt > 4 then
		bot.pathTarget, bot.pathAt, bot.waypoints, bot.waypointIndex = target, now, nil, 2
		local ok, path = pcall(pathfinding.CreatePath, pathfinding, { AgentRadius = 2.2, AgentHeight = 5.5, AgentCanJump = true })
		if ok and path then
			local computed = pcall(path.ComputeAsync, path, root.Position, target)
			if computed and path.Status == Enum.PathStatus.Success then
				bot.waypoints = path:GetWaypoints()
			end
		end
	end
	local waypoints = bot.waypoints
	if waypoints then
		local waypoint = waypoints[bot.waypointIndex]
		while waypoint and flat(root.Position, waypoint.Position) < 3.5 do
			bot.waypointIndex += 1
			waypoint = waypoints[bot.waypointIndex]
		end
		if waypoint then
			if waypoint.Action == Enum.PathWaypointAction.Jump then
				humanoid.Jump = true
			end
			humanoid:MoveTo(waypoint.Position)
			return
		end
	end
	humanoid:MoveTo(target)
end

local function face(bot, position)
	local root = rootOf(bot)
	if root and flat(root.Position, position) > 0.1 then
		root.CFrame = CFrame.lookAt(root.Position, Vector3.new(position.X, root.Position.Y, position.Z))
	end
end

-- Targets ------------------------------------------------------------------------------

local function tutorialDone(data)
	return data.tutorial ~= nil and data.tutorial.step > #Tutorial.Steps
end

-- The brainrots of a player a bot may go after. Allow-list: every condition must hold.
local function stealable(owner, model, data, plot)
	local uid = model:GetAttribute("Uid")
	local base = model:GetAttribute("BaseCFrame")
	if type(uid) ~= "string" or not base or (model:GetAttribute("Hp") or 0) <= 0 then
		return false
	end
	-- Only the ground level: a bot on the ground cannot reach the second floor.
	if base.Position.Y - plot.cframe.Position.Y >= 7 then
		return false
	end
	for _, entry in ipairs(data.creatures) do
		if entry.uid == uid then
			local creature = Creatures.get(entry.id)
			return creature ~= nil and not Formulas.isPaidRandom(entry) and Rarities.get(creature.rarity).rank < 5
		end
	end
	return false
end

-- May a bot go after this brainrot of this owner right now? An allow-list: every condition must hold, anything
-- not recognised means no. (tests/bots.spec.luau runs a table of 12 allowed and 14 refused cases against it.)
function BotService.canTarget(owner, model, now)
	local data = DataService.get(owner)
	local plot = PlotService.getPlot(owner)
	local robbedAt = lastRobbed[owner]
	return data ~= nil
		and plot ~= nil
		and owner.Parent ~= nil
		and tutorialDone(data)
		and not StealService.isLocked(owner)
		and not (robbedAt and now - robbedAt < BotService.OWNER_COOLDOWN)
		and stealable(owner, model, data, plot)
end

local function findStealTarget(bot, now)
	local root = rootOf(bot)
	local best, bestOwner, bestDistance
	for _, owner in ipairs(Players:GetPlayers()) do
		local plot = PlotService.getPlot(owner)
		if plot then
			for _, model in ipairs(plot.model.Creatures:GetChildren()) do
				if BotService.canTarget(owner, model, now) then
					local distance = flat(root.Position, model:GetAttribute("BaseCFrame").Position)
					if not bestDistance or distance < bestDistance then
						best, bestOwner, bestDistance = model, owner, distance
					end
				end
			end
		end
	end
	return best, bestOwner
end

local function someoneStealing()
	for _, bot in ipairs(bots) do
		if bot.state == "steal" or bot.state == "flee" then
			return true
		end
	end
	return false
end

-- Behaviour ---------------------------------------------------------------------------

local function setState(bot, state, now)
	bot.state, bot.since, bot.job = state, now, nil
end

local function toIdle(bot, now, pause)
	setState(bot, "idle", now)
	bot.idleUntil = now + (pause or BotService.rng:NextNumber(2, 5))
end

local function choose(bot, now)
	local root = rootOf(bot)
	local options = {}
	local function add(kind, job)
		local weight = BotService.weights[kind] or 0
		if weight > 0 then
			table.insert(options, { kind = kind, weight = weight, job = job })
		end
	end
	if now >= bot.nextStealAt and not someoneStealing() then
		local model, owner = findStealTarget(bot, now)
		if model then
			add("steal", { model = model, owner = owner, phase = "approach", startedAt = now })
		end
	end
	local wild, hold = WildService.nearestFor(root.Position, BotService.MAX_WILD_RANK)
	if wild then
		add("collect", { model = wild, hold = hold })
	end
	local free = PlotService.freePlots()
	if #free > 0 then
		add("craft", { plot = free[BotService.rng:NextInteger(1, #free)] })
	end
	add("wander", { spot = randomSpot() })

	local total = 0
	for _, option in ipairs(options) do
		total += option.weight
	end
	if total == 0 then
		toIdle(bot, now)
		return
	end
	local roll = BotService.rng:NextNumber() * total
	local picked = options[#options]
	for _, option in ipairs(options) do
		roll -= option.weight
		if roll < 0 then
			picked = option
			break
		end
	end
	setState(bot, picked.kind, now)
	bot.job = picked.job
end

local function stepIdle(bot, now)
	if bot.leaving then
		setState(bot, "leave", now)
	elseif now >= bot.idleUntil then
		choose(bot, now)
	end
end

local function stepWander(bot, now, root)
	local job = bot.job
	if flat(root.Position, job.spot) < 4 or now - bot.since > 15 then
		toIdle(bot, now)
	else
		BotService.mover(bot, job.spot)
	end
end

local function stepCollect(bot, now, root)
	local job = bot.job
	local model = job.model
	if not model.Parent or now - bot.since > 30 then
		toIdle(bot, now)
		return
	end
	local position = model:GetPivot().Position
	if flat(root.Position, position) > 5 then
		job.holdUntil = nil
		BotService.mover(bot, position)
		return
	end
	job.holdUntil = job.holdUntil or now + job.hold
	if now >= job.holdUntil then
		if WildService.catchByBot(model) then
			bot.collected += 1
			bot.stash += 1
		end
		toIdle(bot, now)
	end
end

local function stepCraft(bot, now, root)
	local job = bot.job
	if job.plot.owner ~= nil or now - bot.since > 40 then
		toIdle(bot, now) -- somebody took this base: leave it
		return
	end
	local spot = PlotService.craftSpot(job.plot)
	if flat(root.Position, spot) > 3.5 then
		job.workUntil = nil
		BotService.mover(bot, spot)
		return
	end
	face(bot, (job.plot.cframe * CFrame.new(0, 0, -PlotService.PLOT_SIZE / 2 + 10)).Position) -- the machine
	job.workUntil = job.workUntil or now + BotService.CRAFT_TIME
	if now >= job.workUntil then
		bot.crafted += 1
		bot.stash += 1
		toIdle(bot, now)
	end
end

local function giveUpSteal(bot, now)
	bot.nextStealAt = now + between(BotService.STEAL_COOLDOWN)
	toIdle(bot, now)
end

-- A place far from the base the bot robbed, off every base.
local function fleeSpot(owner)
	local plot = PlotService.getPlot(owner)
	local from = plot and plot.cframe.Position or Vector3.zero
	local spot = randomSpot()
	for _ = 1, 20 do
		if flat(spot, from) >= 60 then
			break
		end
		spot = randomSpot()
	end
	return spot
end

local function stepSteal(bot, now, root)
	local job = bot.job
	local model, owner = job.model, job.owner
	local body = model.Parent and model.PrimaryPart
	if not body or not owner.Parent or StealService.isLocked(owner) or now - job.startedAt > BotService.MAX_STEAL_TIME then
		giveUpSteal(bot, now)
		return
	end
	if job.phase == "approach" then
		if flat(root.Position, body.Position) > BotService.STAND_RANGE then
			BotService.mover(bot, body.Position)
			return
		end
		job.phase = "slap"
	end
	face(bot, body.Position)
	if job.phase == "slap" then
		if model:GetAttribute("StunnedUntil") == nil then
			StealService.botSlap(bot) -- the cooldown is checked there, like for a player
			return
		end
		job.phase, job.holdUntil = "hold", now + (model:GetAttribute("StealHold") or 1)
	end
	if model:GetAttribute("StunnedUntil") == nil then
		job.phase = "slap" -- the hearts came back
		return
	end
	if now < job.holdUntil then
		return
	end
	if StealService.botBeginSteal(bot, model) then
		lastRobbed[owner] = now
		setState(bot, "flee", now)
		bot.fleeTo = fleeSpot(owner)
	else
		giveUpSteal(bot, now)
	end
end

local function stepFlee(bot, now, root)
	if not StealService.carryOf(bot) then
		-- Slapped by a player (the brainrot went back) or the time ran out.
		giveUpSteal(bot, now)
		return
	end
	if flat(root.Position, bot.fleeTo) < 4 then
		StealService.botDeliver(bot)
		bot.stash += 1
		giveUpSteal(bot, now)
	else
		BotService.mover(bot, bot.fleeTo)
	end
end

local function stepLeave(bot, now, root)
	if not bot.leaving then
		toIdle(bot, now)
		return
	end
	local job = bot.job
	if not job then
		local away = Vector3.new(root.Position.X, 0, root.Position.Z)
		away = if away.Magnitude < 1 then Vector3.new(1, 0, 0) else away.Unit
		job = { exit = away * BotService.EXIT_RADIUS }
		bot.job = job
	end
	if flat(root.Position, job.exit) < 6 or now - bot.since > BotService.LEAVE_TIMEOUT then
		removeBot(bot, now)
	else
		BotService.mover(bot, job.exit)
	end
end

-- A player slapped the bot: it slaps back once (same cooldown and range as anyone), then goes on with its business.
local function retaliate(bot, now, root)
	local who = bot.slappedBy
	if not who or bot.retaliated == bot.slappedAt or now - bot.slappedAt > BotService.RETALIATE_WINDOW then
		return
	end
	local victim = who.Parent and rootOf(who)
	if victim and flat(root.Position, victim.Position) <= StealService.SLAP_RANGE - 1 then
		face(bot, victim.Position)
		StealService.botSlap(bot)
		bot.retaliated = bot.slappedAt
	end
end

-- A bot may leave only when it is not in the middle of a steal.
local function freeToLeave(bot)
	return bot.state ~= "steal" and bot.state ~= "flee" and StealService.carryOf(bot) == nil
end

local STEPS = {
	idle = stepIdle,
	wander = stepWander,
	collect = stepCollect,
	craft = stepCraft,
	steal = stepSteal,
	flee = stepFlee,
	leave = stepLeave,
}

local function think(bot, now)
	local root, humanoid = rootOf(bot), humanoidOf(bot)
	if not root or not humanoid or humanoid.Health <= 0 then
		removeBot(bot, now)
		return
	end
	if root.Position.Y < -50 then
		root.CFrame = CFrame.new(0, 5, 0)
	end
	if bot.leaving and bot.state ~= "leave" and freeToLeave(bot) then
		setState(bot, "leave", now)
	end
	if bot.state ~= "steal" and bot.state ~= "flee" then
		retaliate(bot, now, root)
	end
	STEPS[bot.state](bot, now, root)
end

-- Population ---------------------------------------------------------------------------

-- How many bots there should be for this many live players.
function BotService.wanted(humans)
	if not Bots.Enabled or humans <= 0 or humans >= Bots.MinHumans then
		return 0
	end
	return if humans <= 2 then Bots.MaxBots else Bots.MaxBots - 1
end

local function manage(humans, now)
	local want = BotService.wanted(humans)
	if humans <= 0 or not Bots.Enabled then
		for index = #bots, 1, -1 do
			removeBot(bots[index], now) -- nobody left to play with: all bots go at once
		end
		return
	end
	local active, leavingBot = 0, nil
	for _, bot in ipairs(bots) do
		if bot.leaving then
			leavingBot = bot
		else
			active += 1
		end
	end
	if active < want then
		if leavingBot then
			leavingBot.leaving = false -- people left again: the bot that was leaving stays
		elseif now - lastSpawn >= BotService.SPAWN_GAP then
			spawnBot(now)
		end
	elseif active > want and not leavingBot and now - lastLeave >= BotService.LEAVE_GAP then
		for _, bot in ipairs(bots) do
			if freeToLeave(bot) then
				bot.leaving = true
				break
			end
		end
	end
end

-- The bots that are alive now (StealService asks for them: slaps and locks reach bots too).
function BotService.list()
	return bots
end

-- One update of everything: the loop below calls it TICK seconds apart.
function BotService.update()
	local now = os.clock()
	manage(#Players:GetPlayers(), now)
	for _, bot in ipairs(table.clone(bots)) do
		if not bot.removed then
			local ok, err = pcall(think, bot, now)
			if not ok then
				BotService.failures += 1
				BotService.lastError = tostring(err)
				warn("[Bots]", err)
			end
		end
	end
end

function BotService.init()
	folder = Instance.new("Folder")
	folder.Name = "Bots"
	folder.Parent = workspace
	StealService.setBotSource(BotService.list)
	if not Bots.Enabled then
		return
	end
	task.spawn(function()
		while true do
			task.wait(BotService.TICK)
			local ok, err = pcall(BotService.update)
			if not ok then
				BotService.failures += 1
				BotService.lastError = tostring(err)
				warn("[Bots]", err)
			end
		end
	end)
end

return BotService
