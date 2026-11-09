-- Saving player progress (DataStore) and sending state to the client.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local S = require(Shared.Strings)
local Remotes = require(Shared.Remotes)
local Formulas = require(Shared.Util.Formulas)

local DataService = {}

local STORE_NAME = "BrainrotFactory_v1"
local AUTOSAVE_INTERVAL = 60
-- Session lock: while a player is on one server, another server cannot load
-- their progress (protection against duping on a quick rejoin). If a server crashed and did not release
-- the lock, it expires on its own after SESSION_TIMEOUT seconds.
local SESSION_TIMEOUT = 180
local SESSION_ATTEMPTS = 8
local MAX_RECEIPTS = 50

local store = nil
local storeOk, storeErr = pcall(function()
	store = DataStoreService:GetDataStore(STORE_NAME)
end)
if not storeOk then
	warn("[DataService] DataStore unavailable, progress will not be saved:", storeErr)
end

local profiles = {} -- [player] = data
local dirty = {} -- [player] = true if the state must be sent to the client
local snapshotBuilder = nil -- function(player, data) -> snapshot, set from Main
local saveExtras = {} -- functions that add "temporarily absent" brainrots to the save
local closeCallbacks = {} -- called when the server shuts down, before the final save
local beforeSave = {} -- functions(player, data): bring computed fields up to date right before a write
-- [player] = true: the player is leaving, regular saves are no longer needed. Weak keys:
-- we do not clear the flag so that a late autosave does not bring back the session lock.
local releasing = setmetatable({}, { __mode = "k" })
local pendingRelease = {} -- [userId] = true: the final save of a departed player is in progress

DataService.Loaded = Instance.new("BindableEvent")

local function defaultData()
	return {
		version = 1,
		coins = Formulas.START_COINS,
		boughtCoins = 0, -- coins bought for Robux and not yet spent on capsules (see FactoryService.craft)
		totalEarned = 0,
		level = 1,
		xp = 0,
		rebirths = 0,
		creatures = {}, -- { { uid = "1", id = "bananito_ninjini", mut = "normal", source = "free" } }
		nextUid = 1,
		upgrades = { speed = 0, luck = 0 },
		floors = 0, -- built base floors (see Formulas.Floors), not reset by rebirth
		boosts = { luckUntil = 0, paidLuckUntil = 0 }, -- paidLuckUntil: until this time the boost was purchased
		index = {}, -- [creatureId] = true: discovered brainrots (collection)
		stats = { crafted = 0, fused = 0, sold = 0, stolen = 0, lostToThieves = 0, mutants = 0, thievesSlapped = 0 },
		daily = { streak = 0, lastClaimDay = 0 },
		quests = { day = 0, list = {} },
		tutorial = { step = 1, progress = 0 },
		codes = {}, -- [CODE] = true: promo codes entered
		-- Time in the game today (UTC day), summed over all sessions: the gifts for time are counted from it.
		-- claimed: ["1"] = true by gift number (string keys, so that the DataStore keeps them).
		playtime = { day = 0, seconds = 0, claimed = {} },
		achievements = {}, -- [id] = true
		skins = {}, -- [skinId] = true: purchased skins
		settings = { music = true, sfx = true, announcements = true },
		pity = {}, -- [capsuleId] = attempts without the capsule's rarest rarity
		wheel = { lastFreeDay = 0, extraSpins = 0 },
		battles = { points = 0, wins = 0, pvpWins = 0, losses = 0, rewardDay = 0, rewardedToday = 0 },
		receipts = {}, -- recently processed purchases
		lastOnline = 0,
	}
end

-- Adds missing fields (in case we add new ones in future versions).
local function reconcile(data, template)
	for key, value in pairs(template) do
		if data[key] == nil then
			if type(value) == "table" then
				data[key] = table.clone(value)
			else
				data[key] = value
			end
		elseif type(value) == "table" and type(data[key]) == "table" and next(value) ~= nil then
			reconcile(data[key], value)
		end
	end
	return data
end

local function keyFor(player)
	return "player_" .. player.UserId
end

local function withRetries(callback)
	local lastErr
	for attempt = 1, 4 do
		local ok, result = pcall(callback)
		if ok then
			return true, result
		end
		lastErr = result
		task.wait(attempt * 1.5)
	end
	return false, lastErr
end

function DataService.setSnapshotBuilder(builder)
	snapshotBuilder = builder
end

-- callback(player) -> list of brainrots that must go into the save,
-- even though they are not in data.creatures right now (for example, a thief is carrying them).
function DataService.addSaveExtra(callback)
	table.insert(saveExtras, callback)
end

-- Full progress reset (test command). Robux purchases are not touched.
function DataService.reset(player)
	local old = profiles[player]
	if not old then
		return nil
	end
	local fresh = defaultData()
	fresh.receipts = old.receipts
	fresh.session = old.session
	profiles[player] = fresh
	dirty[player] = true
	return fresh
end

-- callback(player, data) is called inside the write, so it must not yield.
function DataService.onBeforeSave(callback)
	table.insert(beforeSave, callback)
end

function DataService.onClose(callback)
	table.insert(closeCallbacks, callback)
end

function DataService.get(player)
	return profiles[player]
end

function DataService.markDirty(player)
	dirty[player] = true
end

function DataService.sendNow(player)
	local data = profiles[player]
	if data and snapshotBuilder then
		dirty[player] = nil
		Remotes.State:FireClient(player, snapshotBuilder(player, data))
	end
end

local function sessionOwnedByOther(saved)
	local session = type(saved) == "table" and saved.session
	return type(session) == "table"
		and session.jobId ~= game.JobId
		and os.time() - (session.time or 0) < SESSION_TIMEOUT
end

-- What goes into the write. Called inside UpdateAsync so that every retry takes live data:
-- a copy from the first attempt would write old coins next to an already confirmed receipt.
local function buildSave(player, data, release)
	local live = profiles[player] or data
	live.lastOnline = os.time()
	for _, callback in ipairs(beforeSave) do
		callback(player, live)
	end
	local toSave = table.clone(live)
	toSave.creatures = table.clone(live.creatures)
	for _, callback in ipairs(saveExtras) do
		for _, entry in ipairs(callback(player) or {}) do
			table.insert(toSave.creatures, entry)
		end
	end
	toSave.session = if release then nil else { jobId = game.JobId, time = os.time() }
	return toSave
end

-- release = true when the player leaves: release the session lock.
-- Returns true if the save went through. Nowhere to save: in Studio without the API that is fine,
-- and on a live server the answer is false, otherwise a purchase would be confirmed without being written.
function DataService.save(player, release)
	local data = profiles[player]
	if not data then
		return false
	end
	if not store then
		return RunService:IsStudio()
	end
	-- The player is already leaving: a regular save could bring back the session lock
	-- after the final one, and the player could not join another server.
	if releasing[player] and not release then
		return false
	end
	local stolenSession = false
	local skipped = false
	local ok, err = withRetries(function()
		return store:UpdateAsync(keyFor(player), function(saved)
			-- We check again inside: the player may have left while this save waited in the queue.
			if releasing[player] and not release then
				skipped = true
				return nil
			end
			if sessionOwnedByOther(saved) then
				-- The progress is already opened by another server: do not overwrite it.
				stolenSession = true
				return nil
			end
			return buildSave(player, data, release)
		end)
	end)
	if not ok then
		warn("[DataService] Failed to save", player.Name, err)
		return false
	elseif stolenSession then
		warn("[DataService] Session of", player.Name, "is held by another server, save skipped")
		return false
	elseif skipped then
		return false
	end
	return true
end

-- Loads progress and sets the session lock.
-- Returns ok, data (data == nil for a new player).
local function loadWithLock(player)
	local key = keyFor(player)
	for attempt = 1, SESSION_ATTEMPTS do
		local locked = false
		local loaded = nil
		local ok, err = pcall(function()
			store:UpdateAsync(key, function(saved)
				if sessionOwnedByOther(saved) then
					locked = true
					return nil
				end
				saved = type(saved) == "table" and saved or {}
				saved.session = { jobId = game.JobId, time = os.time() }
				loaded = saved
				return saved
			end)
		end)
		if ok and not locked then
			return true, loaded
		end
		if not ok then
			warn("[DataService] Load error", player.Name, err)
			if RunService:IsStudio() then
				return false, nil
			end
		end
		if not player.Parent then
			return false, nil
		end
		task.wait(if locked then 5 else attempt * 1.5)
	end
	return false, nil
end

-- Returns true if the purchase with this receiptId was already granted.
function DataService.hasReceipt(data, receiptId)
	return table.find(data.receipts, receiptId) ~= nil
end

function DataService.addReceipt(data, receiptId)
	table.insert(data.receipts, receiptId)
	while #data.receipts > MAX_RECEIPTS do
		table.remove(data.receipts, 1)
	end
end

local function onPlayerAdded(player)
	-- Rejoined the same server while the previous session's final save is running: wait.
	while pendingRelease[player.UserId] do
		task.wait(0.1)
	end
	-- Nowhere to save: progress and purchases would be lost on exit. In Studio without the API that is fine.
	if not store and not RunService:IsStudio() then
		player:Kick(S.forPlayer(player, "data.store_unavailable"))
		return
	end
	local data
	if store then
		local ok, result = loadWithLock(player)
		if ok then
			data = result
		elseif RunService:IsStudio() then
			-- In Studio without API access we just play without saves.
			warn("[DataService] DataStore is unavailable in Studio (enable API Services). Playing without saves.")
			store = nil
		else
			-- We do not let the player play with an empty profile, otherwise we would overwrite real progress.
			player:Kick(S.forPlayer(player, "data.load_failed"))
			return
		end
	end

	if not player.Parent then
		-- The player left while loading: release the lock, change nothing.
		if store and data then
			pcall(function()
				store:UpdateAsync(keyFor(player), function(saved)
					if type(saved) == "table" and not sessionOwnedByOther(saved) then
						saved.session = nil
						return saved
					end
					return nil
				end)
			end)
		end
		return
	end

	-- Saves from before floors: there were at least 8 spots, so we give 1 floor right away.
	local beforeFloors = type(data) == "table" and data.coins ~= nil and data.floors == nil
	local beforeSources = type(data) == "table" and data.coins ~= nil and data.boughtCoins == nil
	data = reconcile(type(data) == "table" and data or {}, defaultData())
	if beforeFloors then
		data.floors = 1
	end
	-- Saves from before the source mark, once. Receipts hold only numbers, without the product, so
	-- "had coin purchases" is read as "has at least one receipt": this is broader, but never smaller.
	-- Later we do not touch an entry without a mark: it means "source unknown", see Formulas.isPaidRandom.
	if beforeSources then
		local hadPurchases = #data.receipts > 0
		for _, entry in ipairs(data.creatures) do
			entry.source = entry.source or (if hadPurchases then Formulas.SOURCE_COINS else Formulas.SOURCE_FREE)
		end
		if hadPurchases then
			data.boughtCoins = data.coins
			data.boosts.paidLuckUntil = data.boosts.luckUntil
		end
	end
	-- Old saves: brainrots without an "origin" are treated as the player's own.
	for _, entry in ipairs(data.creatures) do
		if entry.lineage == nil then
			entry.lineage = Formulas.lineageOf(entry, player.UserId, data.rebirths)
			entry.origin = nil
			entry.gen = nil
		end
	end
	profiles[player] = data
	DataService.Loaded:Fire(player, data)
	DataService.sendNow(player)
end

local function onPlayerRemoving(player)
	if profiles[player] then
		releasing[player] = true
		pendingRelease[player.UserId] = true
		local ok, err = pcall(DataService.save, player, true)
		if not ok then
			warn("[DataService] Final save error", player.Name, err)
		end
		pendingRelease[player.UserId] = nil
	end
	profiles[player] = nil
	dirty[player] = nil
end

function DataService.init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	-- We send changes to clients at most 5 times per second.
	task.spawn(function()
		while true do
			task.wait(0.2)
			for player in pairs(dirty) do
				DataService.sendNow(player)
			end
		end
	end)

	-- Autosave.
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in pairs(profiles) do
				task.spawn(DataService.save, player)
			end
		end
	end)

	game:BindToClose(function()
		for _, callback in ipairs(closeCallbacks) do
			pcall(callback)
		end
		if RunService:IsStudio() and not store then
			return
		end
		local pending = 0
		for player in pairs(profiles) do
			pending += 1
			-- Before saving: a receipt or an autosave at this moment would bring back the session lock.
			releasing[player] = true
			task.spawn(function()
				DataService.save(player, true)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.1)
		end
	end)
end

return DataService
