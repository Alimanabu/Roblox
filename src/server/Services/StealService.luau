-- Stealing brainrots from other bases.
--
-- How it works:
-- 1. You walk up to someone else's brainrot and slap it with the Slapper until its hearts run out
-- (on the ground 5, on floor 1 10, on floor 2 20). The brainrot is stunned: hold F.
-- The rarer the brainrot and the higher the floor, the longer you hold F.
-- 2. The brainrot is above your head, you run slower and glow red.
-- 3. Reach your own base within CARRY_TIME seconds and the brainrot is yours.
-- 4. The owner can catch you and slap you with the Slapper: the brainrot returns to them.
-- 5. The owner can close the base with a lock for LOCK_TIME seconds (they must stand at the button).

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local StarterPack = game:GetService("StarterPack")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local S = require(Shared.Strings)
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
local BossService = require(script.Parent.BossService)
local MoveGuardService = require(script.Parent.MoveGuardService)
local PolicyService = require(script.Parent.PolicyService)

local StealService = {}

StealService.CARRY_TIME = 60
StealService.LOCK_TIME = 60
StealService.LOCK_COOLDOWN = 30 -- after the lock ends it cannot be locked again right away
StealService.JOIN_SHIELD = 90
StealService.CARRY_SPEED = 12
StealService.NORMAL_SPEED = 16
StealService.SLAP_RANGE = 9
StealService.SLAP_COOLDOWN = 0.8
StealService.SLAP_FORCE = 70
StealService.TRAP_STUN_PER_LEVEL = 1.5
StealService.STUN_TIME = 15 -- how many seconds a stunned brainrot can be grabbed
StealService.REGEN_DELAY = 5 -- after how many seconds without hits the hearts start to regenerate

local BAD = Color3.fromRGB(255, 110, 110)
local GOOD = Color3.fromRGB(120, 255, 120)
local WARN = Color3.fromRGB(255, 170, 60)

local carries = {} -- [thief] = { owner, entry, deadline, visual, highlight, diedConn }
local lockedUntil = {} -- [owner] = server time
local lockKind = {} -- [owner] = "shield" (protection on join) | "lock" (lock)
local lockReadyAt = {} -- [owner] = when the lock can be pressed again
local lastSlap = {} -- [player] = os.clock()
local closing = false -- the server is shutting down: new steals are forbidden
local holdStart = {} -- [player] = { prompt, os.clock() }: the server checks the hold time itself
local damaged = setmetatable({}, { __mode = "k" }) -- [brainrot model] = true: hearts not full
local lastHit = setmetatable({}, { __mode = "k" }) -- [brainrot model] = os.clock() of the last hit
local hitAlertAt = {} -- [owner] = os.clock(): we do not spam the owner with "you are being hit"
local hintAt = {} -- [player] = os.clock(): the "slap first" hint

-- NPC bots (BotService) are not Players: they act through the same slap and steal code, as an "actor" table
-- (IsBot = true, Character, DisplayName, SetAttribute). The list of live bots is given by BotService.
local botSource = function()
	return {}
end
function StealService.setBotSource(source)
	botSource = source
end

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
		return S.m(creature.nameKey)
	end
	return S.m("creature.mutated", { mutation = S.m(mutation.nameKey), name = S.m(creature.nameKey) })
end

function StealService.isLocked(owner)
	return (lockedUntil[owner] or 0) > now()
end

function StealService.isCarrying(player)
	return carries[player] ~= nil
end

local function setLock(owner, seconds, kind)
	-- The attribute on the plot is set by the loop below (the base may be assigned a bit later).
	lockedUntil[owner] = now() + seconds
	lockKind[owner] = kind
	if kind == "lock" then
		lockReadyAt[owner] = lockedUntil[owner] + StealService.LOCK_COOLDOWN
	end
end

-- How many of the owner's brainrots thieves are carrying now. While > 0, rebirth is not allowed
-- (otherwise a failed steal would return the brainrot to an already "clean" base).
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

-- Brainrot above the thief's head.
local function makeCarryVisual(thief, entry)
	local character = thief.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return nil, nil
	end
	local creature = Creatures.get(entry.id)
	local rarity = Rarities.get(creature.rarity)
	local mutation = Mutations.get(entry.mut)

	-- We shrink the model and attach it to the thief's head.
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
	S.apply(label, "Text", S.m("steal.carry_label", { name = displayName(entry) }))
	label.Parent = gui

	model.Parent = character

	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(255, 40, 60)
	highlight.FillTransparency = 0.6
	highlight.OutlineColor = Color3.fromRGB(255, 40, 60)
	highlight.Parent = character

	return model, highlight
end

-- A steal transfers the brainrot like a trade: where Roblox forbids paid random rewards,
-- a paid one can be neither given nor received. Returns the refusal text or nil.
local function paidRandomRefusal(entry, thief, owner, key)
	if not Formulas.isPaidRandom(entry) then
		return nil
	end
	for _, player in ipairs({ thief, owner }) do
		if PolicyService.paidRandomRestricted(player) then
			return PolicyService.message(player, key)
		end
	end
	return nil
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
		humanoid.JumpPower = 50
		humanoid.JumpHeight = 7.2
	end
	thief:SetAttribute("CarryDeadline", nil)

	local owner = carry.owner
	local entry = carry.entry
	local name = displayName(entry)
	updateRobbed(owner)

	-- Before crediting we check the spot again: the thief could have filled the base while running.
	-- A bot keeps no profile: only the owner's side of the steal is real (the brainrot was taken from a human).
	local isBot = thief.IsBot == true
	local thiefData = success and not isBot and DataService.get(thief)
	if not success or isBot then
		-- A bot never takes a paid random brainrot (refused at the start): nothing to re-check.
	elseif not thiefData then
		success, reason = false, S.m("steal.reason_thief_left")
	elseif success and Formulas.isFromPastLife(entry, thief.UserId, thiefData.rebirths) then
		success, reason = false, S.m("steal.reason_past_life")
	elseif success and #thiefData.creatures >= Formulas.slots(thiefData, MonetizationService.passes(thief)) then
		success, reason = false, S.m("steal.reason_no_space")
	elseif success then
		-- The restriction could have arrived while the thief was running.
		local refusal = paidRandomRefusal(entry, thief, owner, "steal.reason_random")
		if refusal then
			success, reason = false, refusal
		end
	end

	if success then
		if isBot then
			thief.stolen = (thief.stolen or 0) + 1
		else
			local newEntry = { uid = tostring(thiefData.nextUid), id = entry.id, mut = entry.mut, paid = entry.paid, source = entry.source, skin = entry.skin, lineage = Formulas.mergeLineage(
				table.clone(Formulas.lineageOf(entry, owner.UserId, 0)),
				{ [tostring(thief.UserId)] = thiefData.rebirths }
			) }
			thiefData.nextUid += 1
			table.insert(thiefData.creatures, newEntry)
			thiefData.index[entry.id] = true
			thiefData.stats.stolen = (thiefData.stats.stolen or 0) + 1
			Actions.fire(thief, "steal", 1)
			local rarity = Rarities.get(Creatures.get(entry.id).rarity)
			ProgressionService.addXp(thief, thiefData, rarity.xp)
			DataService.markDirty(thief)
			PlotService.render(thief)
			Remotes.Notify:FireClient(thief, S.m("steal.stolen", { name = name }), GOOD)
			Remotes.Sfx:FireClient(thief, "success")

			if rarity.rank >= 5 then
				Remotes.Notify:FireAllClients(
					S.m("steal.announce", { thief = thief.DisplayName, name = name, owner = owner.DisplayName }),
					rarity.color,
					true
				)
			end
		end
		local ownerData = owner.Parent and DataService.get(owner)
		if ownerData then
			ownerData.stats.lostToThieves = (ownerData.stats.lostToThieves or 0) + 1
			DataService.markDirty(owner)
			Remotes.Notify:FireClient(owner, S.m("steal.lost", { thief = thief.DisplayName, name = name }), BAD)
			Remotes.Sfx:FireClient(owner, "lose")
			-- We save the owner immediately: in their earlier saves the brainrot was still listed,
			-- and if the server crashed it would end up with two people.
			task.spawn(DataService.save, owner)
		end
		return
	end

	-- Failure: the brainrot returns to the owner.
	local ownerData = DataService.get(owner)
	if ownerData then
		table.insert(ownerData.creatures, entry)
		DataService.markDirty(owner)
		PlotService.render(owner)
		if owner.Parent then
			Remotes.Notify:FireClient(owner, S.m("steal.returned", { name = name }), GOOD)
		end
	end
	if thief.Parent and not isBot then
		Remotes.Notify:FireClient(thief, S.m("steal.failed", { reason = reason }), BAD)
	end
end

-- The brainrot is already taken out of the owner's data: the thief (a player or a bot) now carries it.
local function beginCarry(thief, owner, ownerData, entry, thiefRoot, humanoid)
	local deadline = now() + StealService.CARRY_TIME
	local visual, highlight = makeCarryVisual(thief, entry)
	carries[thief] = {
		owner = owner,
		entry = entry,
		deadline = deadline,
		visual = visual,
		highlight = highlight,
		startPosition = thiefRoot.Position,
		startClock = os.clock(),
		diedConn = humanoid.Died:Connect(function()
			endCarry(thief, false, S.m("steal.reason_defeated"))
		end),
	}
	humanoid.WalkSpeed = StealService.CARRY_SPEED
	thief:SetAttribute("CarryDeadline", deadline)
	updateRobbed(owner)

	-- Owner's trap: the thief stands still while being shocked.
	local trapLevel = ownerData.upgrades.trap or 0
	if trapLevel > 0 then
		local stun = trapLevel * StealService.TRAP_STUN_PER_LEVEL
		local carry = carries[thief]
		carry.deadline += stun
		thief:SetAttribute("CarryDeadline", carry.deadline)
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		if carry.highlight then
			carry.highlight.FillColor = Color3.fromRGB(255, 240, 60)
		end
		if not thief.IsBot then
			Remotes.Notify:FireClient(thief, S.m("steal.trap_thief", { seconds = stun }), BAD)
		end
		Remotes.Notify:FireClient(owner, S.m("steal.trap_owner"), GOOD)
		task.delay(stun, function()
			if carries[thief] == carry and humanoid.Parent then
				humanoid.WalkSpeed = StealService.CARRY_SPEED
				humanoid.JumpPower = 50
				humanoid.JumpHeight = 7.2
				if carry.highlight then
					carry.highlight.FillColor = Color3.fromRGB(255, 40, 60)
				end
			end
		end)
	end

	DataService.markDirty(owner)
	PlotService.render(owner)

	local name = displayName(entry)
	if not thief.IsBot then
		Remotes.Notify:FireClient(thief, S.m("steal.carry", { name = name }), WARN)
	end
	Remotes.Notify:FireClient(owner, S.m("steal.alarm", { thief = thief.DisplayName, name = name }), BAD)
	Remotes.Sfx:FireClient(owner, "alarm")
end

local function startSteal(thief, prompt)
	-- Prompt -> Body -> brainrot model -> Creatures folder -> base model.
	local creaturesFolder = prompt:FindFirstAncestor("Creatures")
	local plotModel = creaturesFolder and creaturesFolder.Parent
	local owner = plotModel and PlotService.ownerOfModel(plotModel)
	local uid = prompt:GetAttribute("Uid")
	if closing or not owner or owner == thief or type(uid) ~= "string" then
		return
	end

	-- While a brainrot has hearts it cannot be grabbed: slap first.
	local creatureModel = prompt.Parent and prompt.Parent.Parent
	if not creatureModel or creatureModel:GetAttribute("StunnedUntil") == nil then
		holdStart[thief] = nil
		if not hintAt[thief] or os.clock() - hintAt[thief] > 2 then
			hintAt[thief] = os.clock()
			Remotes.Notify:FireClient(thief, S.m("steal.hit_first"), WARN)
		end
		return
	end

	-- Cheater protection: the client could have "pressed" instantly or from afar.
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
	if not MoveGuardService.canAct(thief) then
		Remotes.Notify:FireClient(thief, S.m("steal.too_fast"), BAD)
		return
	end

	if StealService.isLocked(owner) then
		Remotes.Notify:FireClient(thief, S.m("steal.base_locked"), BAD)
		return
	end
	if carries[thief] then
		Remotes.Notify:FireClient(thief, S.m("steal.already_carrying"), BAD)
		return
	end
	local thiefData = DataService.get(thief)
	local ownerData = DataService.get(owner)
	if not thiefData or not ownerData or not PlotService.getPlot(thief) then
		return
	end
	if #thiefData.creatures >= Formulas.slots(thiefData, MonetizationService.passes(thief)) then
		Remotes.Notify:FireClient(thief, S.m("steal.no_space"), BAD)
		return
	end
	local humanoid = humanoidOf(thief)
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local entry
	for index, candidate in ipairs(ownerData.creatures) do
		if candidate.uid == uid then
			local refusal = paidRandomRefusal(candidate, thief, owner, "steal.random")
			if refusal then
				Remotes.Notify:FireClient(thief, refusal, BAD)
				return
			end
			entry = table.remove(ownerData.creatures, index)
			break
		end
	end
	if not entry then
		return
	end

	beginCarry(thief, owner, ownerData, entry, thiefRoot, humanoid)
end

-- A bot steals by the same rules as a player: the brainrot must be stunned (its hearts slapped out),
-- the bot must stand next to it, the base must not be locked, and the bot carries one brainrot at a time.
-- A bot never takes a paid random brainrot. Returns true when the bot now carries it.
function StealService.botBeginSteal(bot, model)
	local plotModel = model.Parent and model.Parent.Parent
	local owner = plotModel and PlotService.ownerOfModel(plotModel)
	local uid = model:GetAttribute("Uid")
	local body = model.PrimaryPart
	local botRoot = rootOf(bot)
	local humanoid = humanoidOf(bot)
	if closing or not owner or not owner.Parent or type(uid) ~= "string" or model:GetAttribute("StunnedUntil") == nil then
		return false
	end
	local prompt = body and body:FindFirstChild("StealPrompt")
	if not prompt or not botRoot or not humanoid or humanoid.Health <= 0 then
		return false
	end
	if (botRoot.Position - body.Position).Magnitude > prompt.MaxActivationDistance + 6 then
		return false
	end
	if StealService.isLocked(owner) or carries[bot] then
		return false
	end
	local ownerData = DataService.get(owner)
	if not ownerData then
		return false
	end
	local entry
	for index, candidate in ipairs(ownerData.creatures) do
		if candidate.uid == uid then
			if Formulas.isPaidRandom(candidate) then
				return false
			end
			entry = table.remove(ownerData.creatures, index)
			break
		end
	end
	if not entry then
		return false
	end
	beginCarry(bot, owner, ownerData, entry, botRoot, humanoid)
	return true
end

-- The bot got away with the brainrot (BotService decides when it has run far enough).
function StealService.botDeliver(bot)
	if carries[bot] then
		endCarry(bot, true)
	end
end

-- The bot leaves the server (or the last human left): a brainrot it carries goes back to its owner.
function StealService.releaseBot(bot)
	if carries[bot] then
		endCarry(bot, false, S.m("steal.reason_shutdown"))
	end
	lastSlap[bot] = nil
end

-- What the bot carries now: { owner, entry, deadline } or nil.
function StealService.carryOf(thief)
	return carries[thief]
end

local function onLockPrompt(player, prompt)
	local plotModel = prompt:FindFirstAncestorWhichIsA("Model")
	local owner = plotModel and PlotService.ownerOfModel(plotModel)
	if owner ~= player then
		return
	end
	-- The lock is closed only at the button: you cannot use "return home" by teleport.
	local root = rootOf(player)
	if not root or (root.Position - prompt.Parent.Position).Magnitude > prompt.MaxActivationDistance + 6 or not MoveGuardService.canAct(player) then
		return
	end
	-- Protection on join can be "extended" with the lock (this is a tutorial step), a regular lock cannot.
	if StealService.isLocked(player) and lockKind[player] == "lock" then
		Remotes.Notify:FireClient(player, S.m("steal.already_locked"), WARN)
		return
	end
	local wait = (lockReadyAt[player] or 0) - now()
	if wait > 0 then
		Remotes.Notify:FireClient(player, S.m("steal.lock_cooldown", { seconds = math.ceil(wait) }), WARN)
		return
	end
	setLock(player, StealService.LOCK_TIME, "lock")
	Actions.fire(player, "lock", 1)
	Remotes.Notify:FireClient(player, S.m("steal.locked", { seconds = StealService.LOCK_TIME }), GOOD)
	Remotes.Sfx:FireClient(player, "lock")
end

-- A Slapper hit on someone else's brainrot: minus 1 heart. At zero the brainrot is stunned and can be stolen.
-- Returns true if a brainrot was hit.
local function hitBrainrot(player, root)
	if carries[player] then
		return false
	end
	local facing = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if facing.Magnitude < 0.01 then
		return false
	end
	facing = facing.Unit

	local target, targetOwner, bestDistance
	for _, owner in ipairs(Players:GetPlayers()) do
		local plot = owner ~= player and PlotService.getPlot(owner)
		if plot and not StealService.isLocked(owner) then
			for _, model in ipairs(plot.model.Creatures:GetChildren()) do
				local base = model:GetAttribute("BaseCFrame")
				if base and (model:GetAttribute("Hp") or 0) > 0 then
					local offset = base.Position - root.Position
					local flat = Vector3.new(offset.X, 0, offset.Z)
					local distance = flat.Magnitude
					-- By height, only your own floor: you cannot reach floor 2 from the ground.
					if
						distance <= StealService.SLAP_RANGE
						and math.abs(offset.Y) < 7
						and (distance < 1 or flat.Unit:Dot(facing) > 0.2)
						and (not bestDistance or distance < bestDistance)
					then
						target, targetOwner, bestDistance = model, owner, distance
					end
				end
			end
		end
	end
	if not target then
		return false
	end

	local hp = math.max(0,(target:GetAttribute("Hp") or 1) - 1)
	target:SetAttribute("Hp", hp)
	damaged[target] = true
	lastHit[target] = os.clock()

	local prompt = target.PrimaryPart and target.PrimaryPart:FindFirstChild("StealPrompt")
	local creatureId = prompt and prompt:GetAttribute("CreatureId")
	local name = if creatureId then S.m(Creatures.get(creatureId).nameKey) else S.m("steal.brainrot")
	if hp == 0 then
		target:SetAttribute("StunnedUntil", now() + StealService.STUN_TIME)
		if not player.IsBot then
			Remotes.Notify:FireClient(player, S.m("steal.stunned_thief", { name = name }), GOOD)
		end
		Remotes.Notify:FireClient(targetOwner, S.m("steal.stunned_owner", { name = name }), BAD)
		Remotes.Sfx:FireClient(targetOwner, "alarm")
	elseif not hitAlertAt[targetOwner] or os.clock() - hitAlertAt[targetOwner] > 8 then
		hitAlertAt[targetOwner] = os.clock()
		Remotes.Notify:FireClient(targetOwner, S.m("steal.being_hit", { player = player.DisplayName, name = name, hp = hp }), WARN)
		Remotes.Sfx:FireClient(targetOwner, "alarm")
	end
	PlotService.refreshHp(target)
	return true
end

-- Brainrot hearts: the stun wears off, without hits health regenerates.
local function updateHp(t)
	local clock = os.clock()
	for model in pairs(damaged) do
		if not model.Parent then
			damaged[model] = nil
		else
			local maxHp = model:GetAttribute("MaxHp") or 1
			local stunnedUntil = model:GetAttribute("StunnedUntil")
			if stunnedUntil then
				if t > stunnedUntil then
					model:SetAttribute("StunnedUntil", nil)
					model:SetAttribute("Hp", maxHp)
					damaged[model] = nil
					PlotService.refreshHp(model)
				end
			elseif clock - (lastHit[model] or 0) > StealService.REGEN_DELAY then
				local hp = math.min(maxHp, (model:GetAttribute("Hp") or maxHp) + 1)
				model:SetAttribute("Hp", hp)
				if hp >= maxHp then
					damaged[model] = nil
				end
				PlotService.refreshHp(model)
			end
		end
	end
end

-- The swing: Roblox's own free "Slash" animations (R6 and R15), played on the server so that the
-- character's Animator replicates it to everyone nearby.
StealService.SWING_ANIMATION = { R15 = "rbxassetid://522635514", R6 = "rbxassetid://129967390" }
local swingTracks = setmetatable({}, { __mode = "k" }) -- [humanoid] = AnimationTrack

local function playSwing(player)
	local humanoid = humanoidOf(player)
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local track = swingTracks[humanoid]
	if not track then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
		local animation = Instance.new("Animation")
		local rig = if humanoid.RigType == Enum.HumanoidRigType.R6 then "R6" else "R15"
		animation.AnimationId = StealService.SWING_ANIMATION[rig]
		local ok, loaded = pcall(animator.LoadAnimation, animator, animation)
		if not ok or not loaded then
			return
		end
		loaded.Priority = Enum.AnimationPriority.Action
		swingTracks[humanoid] = loaded
		track = loaded
	end
	track:Play(0.05)
end

-- A player's slap on the bots in front of them: the bot is pushed back, a thief bot drops the brainrot.
-- Slapping a bot does not count for quests or achievements ("slap"), a thief bot does ("slapThief").
local function slapBots(player, root, facing)
	local hit = false
	for _, bot in ipairs(botSource()) do
		local botRoot = rootOf(bot)
		local humanoid = humanoidOf(bot)
		if botRoot and humanoid and humanoid.Health > 0 then
			local offset = botRoot.Position - root.Position
			local flat = Vector3.new(offset.X, 0, offset.Z)
			if flat.Magnitude <= StealService.SLAP_RANGE and flat.Magnitude > 0.01 then
				if flat.Unit:Dot(Vector3.new(facing.X, 0, facing.Z).Unit) > 0.2 then
					botRoot.AssemblyLinearVelocity = flat.Unit * StealService.SLAP_FORCE + Vector3.new(0, 35, 0)
					bot.slappedBy, bot.slappedAt = player, os.clock()
					hit = true
					if carries[bot] then
						Actions.fire(player, "slapThief", 1)
						endCarry(bot, false, S.m("steal.reason_slapped", { name = player.DisplayName }))
						Remotes.Notify:FireClient(player, S.m("steal.slap_thief"), GOOD)
						Remotes.Sfx:FireClient(player, "success")
					end
				end
			end
		end
	end
	return hit
end

-- Slapper: pushes players back. If you slap a thief, they drop the brainrot.
-- On someone else's brainrot it removes a heart. A bot slaps through here too (same cooldown, range and force),
-- but it does not hit the boss and does not push other bots.
local function slap(player)
	local isBot = player.IsBot == true
	local nowClock = os.clock()
	if lastSlap[player] and nowClock - lastSlap[player] < StealService.SLAP_COOLDOWN then
		return
	end
	lastSlap[player] = nowClock

	local root = rootOf(player)
	if not root or (not isBot and not MoveGuardService.canAct(player)) then
		return
	end
	playSwing(player)
	local hit = if isBot then false else BossService.tryHit(player, root)
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
						Remotes.Knockback:FireClient(other, velocity, true) -- true: the slap sound comes from SlapFx
						MoveGuardService.knockback(other, StealService.SLAP_FORCE)
						hit = true
						if not isBot then
							Actions.fire(player, "slap", 1)
						end
						if carries[other] then
							if not isBot then
								Actions.fire(player, "slapThief", 1)
							end
							endCarry(other, false, S.m("steal.reason_slapped", { name = player.DisplayName }))
							if not isBot then
								Remotes.Notify:FireClient(player, S.m("steal.slap_thief"), GOOD)
								Remotes.Sfx:FireClient(player, "success")
							end
						end
					end
				end
			end
		end
	end
	if not isBot and slapBots(player, root, root.CFrame.LookVector) then
		hit = true
	end
	if hitBrainrot(player, root) then
		hit = true
	end
	-- Everyone's client plays the slap (hit) or the whoosh (miss) in 3D on the swinging character.
	-- A bot is not a Player: the client gets its character.
	Remotes.SlapFx:FireAllClients(if isBot then player.Character else player, hit)
end

-- A bot swings the Slapper (BotService calls this; the cooldown is checked here, like for players).
StealService.botSlap = slap

local function createSlapper()
	local tool = Instance.new("Tool")
	S.apply(tool, "Name", S.m("steal.slapper"))
	S.apply(tool, "ToolTip", S.m("steal.slapper_tip"))
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

-- A fresh Slapper for a bot to hold (the bot swings it through StealService.botSlap).
StealService.newSlapper = createSlapper

local function watchTool(tool, player)
	tool.Activated:Connect(function()
		slap(player)
	end)
end

-- Cancel all steals (brainrots return to the owners). Called when the server shuts down,
-- so that a steal does not finish after the owner's last save (otherwise a dupe).
function StealService.cancelAll(reason)
	for thief in pairs(carries) do
		endCarry(thief, false, reason)
	end
end

function StealService.init()
	DataService.onClose(function()
		closing = true
		StealService.cancelAll(S.m("steal.reason_shutdown"))
	end)

	-- While a thief carries a brainrot, it must be included in the owner's save.
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

	-- A Slapper for every player.
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

	-- Protection on join.
	DataService.Loaded.Event:Connect(function(player)
		setLock(player, StealService.JOIN_SHIELD, "shield")
		task.delay(3, function()
			if player.Parent then
				Remotes.Notify:FireClient(player, S.m("steal.shield", { seconds = StealService.JOIN_SHIELD }), GOOD)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		-- The thief left: the brainrot returns.
		endCarry(player, false, S.m("steal.reason_thief_left"))
		-- The owner left: all steals of their brainrots are cancelled.
		for thief, carry in pairs(carries) do
			if carry.owner == player then
				endCarry(thief, false, S.m("steal.reason_owner_left"))
			end
		end
		lockedUntil[player] = nil
		lockKind[player] = nil
		lockReadyAt[player] = nil
		holdStart[player] = nil
		lastSlap[player] = nil
		hitAlertAt[player] = nil
		hintAt[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(0.2)
			local t = now()
			updateHp(t)

			-- Locks: update the fence and push strangers out.
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
								local outside = PlotService.outsideCFrame(plot, root.Position)
								MoveGuardService.teleported(other, outside.Position)
								other.Character:PivotTo(outside)
							end
						end
						-- Bots are kept out of a locked base too (they have no movement budget to update).
						for _, bot in ipairs(botSource()) do
							local root = rootOf(bot)
							if root and PlotService.isInside(plot, root.Position) then
								bot.Character:PivotTo(PlotService.outsideCFrame(plot, root.Position))
							end
						end
					end
				end
			end

			-- Steals: reached the base or time ran out.
			for thief, carry in pairs(carries) do
				local plot = PlotService.getPlot(thief)
				local root = rootOf(thief)
				if thief.IsBot then
					-- A bot is not a player: no movement budget and no base. BotService delivers it (botDeliver), the time runs out here.
					if t > carry.deadline then
						endCarry(thief, false, S.m("steal.reason_timeout"))
					end
				elseif MoveGuardService.exceeded(thief) then
					endCarry(thief, false, S.m("steal.reason_too_fast"))
				elseif
					plot
					and root
					and PlotService.isInside(plot, root.Position)
					and MoveGuardService.canAct(thief)
					and MoveGuardService.couldWalk(carry.startPosition, carry.startClock, root.Position, StealService.CARRY_SPEED)
				then
					endCarry(thief, true)
				elseif t > carry.deadline then
					endCarry(thief, false, S.m("steal.reason_timeout"))
				end
			end
		end
	end)
end

return StealService
