-- Trading brainrots between players.
--
-- 1. Player A invites B, B accepts.
-- 2. Each puts up to MAX_OFFER brainrots into the trade.
-- 3. Both press "Ready" -> CONFIRM_DELAY seconds of countdown.
-- Any change to an offer clears "Ready" for both (protection against a swap).
-- 4. The server re-checks everything and swaps the brainrots in one step, then saves both.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local S = require(Shared.Strings)
local Formulas = require(Shared.Util.Formulas)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local PlotService = require(script.Parent.PlotService)
local Actions = require(script.Parent.Actions)
local PolicyService = require(script.Parent.PolicyService)

local TradeService = {}

TradeService.MAX_OFFER = 6
TradeService.CONFIRM_DELAY = 3
TradeService.INVITE_TIMEOUT = 30
TradeService.REQUEST_COOLDOWN = 5

local GOOD = Color3.fromRGB(120, 255, 120)
local BAD = Color3.fromRGB(255, 110, 110)
local INFO = Color3.fromRGB(120, 200, 255)

local trades = {} -- [player] = trade (the same table for both participants)
local invites = {} -- [target] = { [fromUserId] = os.clock() }
local lastRequest = {} -- [player] = os.clock()

local function partnerOf(trade, player)
	return trade.a == player and trade.b or trade.a
end

local function findEntry(data, uid)
	for index, entry in ipairs(data.creatures) do
		if entry.uid == uid then
			return entry, index
		end
	end
	return nil
end

-- Where Roblox forbids paid random rewards, their result can be neither given nor received.
-- Returns a message for the giver or nil.
local function paidRandomRefusal(entries, giver, receiver)
	local giverRestricted = PolicyService.paidRandomRestricted(giver)
	if not giverRestricted and not PolicyService.paidRandomRestricted(receiver) then
		return nil
	end
	for _, entry in ipairs(entries) do
		if Formulas.isPaidRandom(entry) then
			return if giverRestricted
				then PolicyService.message(giver, "trade.random_you")
				else PolicyService.message(receiver, "trade.random_them", { name = receiver.DisplayName })
		end
	end
	return nil
end

-- What the player sees in the trade window.
local function stateFor(trade, player)
	local partner = partnerOf(trade, player)
	local partnerData = DataService.get(partner)
	local theirOffer = {}
	for _, uid in ipairs(trade.offers[partner]) do
		local entry = partnerData and findEntry(partnerData, uid)
		if entry then
			table.insert(theirOffer, { id = entry.id, mut = entry.mut, skin = entry.skin })
		end
	end
	return {
		partnerName = partner.DisplayName,
		partnerUserId = partner.UserId,
		myOffer = table.clone(trade.offers[player]),
		theirOffer = theirOffer,
		myReady = trade.ready[player] == true,
		theirReady = trade.ready[partner] == true,
		confirmAt = trade.confirmAt,
		notice = trade.notices[player],
	}
end

local function sendState(trade)
	for _, player in ipairs({ trade.a, trade.b }) do
		if player.Parent then
			Remotes.TradeState:FireClient(player, stateFor(trade, player))
		end
	end
end

local function endTrade(trade, message, color)
	for _, player in ipairs({ trade.a, trade.b }) do
		if trades[player] == trade then
			trades[player] = nil
		end
		if player.Parent then
			Remotes.TradeState:FireClient(player, nil)
			if message then
				Remotes.Notify:FireClient(player, message, color or INFO)
			end
		end
	end
	trade.closed = true
end

local function resetReady(trade)
	trade.ready = {}
	trade.confirmAt = nil
	trade.token += 1
end

local function request(player, targetUserId)
	local target = type(targetUserId) == "number" and Players:GetPlayerByUserId(targetUserId)
	if not target or target == player then
		return
	end
	-- In some countries trading paid items is forbidden (Roblox rules).
	if not PolicyService.tradingAllowed(player) then
		Remotes.Notify:FireClient(player, PolicyService.message(player, "trade.region_you"), BAD)
		return
	end
	if not PolicyService.tradingAllowed(target) then
		Remotes.Notify:FireClient(player, PolicyService.message(target, "trade.region_them"), BAD)
		return
	end
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < TradeService.REQUEST_COOLDOWN then
		Remotes.Notify:FireClient(player, S.m("trade.invite_cooldown"), BAD)
		return
	end
	if trades[player] or trades[target] then
		Remotes.Notify:FireClient(player, S.m("trade.busy"), BAD)
		return
	end
	lastRequest[player] = now
	invites[target] = invites[target] or {}
	invites[target][player.UserId] = now
	Remotes.TradeInvite:FireClient(target, player.UserId, player.DisplayName)
	Remotes.Notify:FireClient(player, S.m("trade.invite_sent", { name = target.DisplayName }), INFO)
end

local function respond(player, fromUserId, accept)
	local from = type(fromUserId) == "number" and Players:GetPlayerByUserId(fromUserId)
	local sentAt = invites[player] and invites[player][fromUserId]
	if invites[player] then
		invites[player][fromUserId] = nil
	end
	if not from or not sentAt or os.clock() - sentAt > TradeService.INVITE_TIMEOUT then
		return
	end
	if accept ~= true then
		Remotes.Notify:FireClient(from, S.m("trade.declined", { name = player.DisplayName }), BAD)
		return
	end
	if not PolicyService.tradingAllowed(player) or not PolicyService.tradingAllowed(from) then
		return
	end
	if trades[player] or trades[from] then
		Remotes.Notify:FireClient(player, S.m("trade.busy"), BAD)
		return
	end
	if not DataService.get(player) or not DataService.get(from) then
		return
	end
	local trade = {
		a = from,
		b = player,
		offers = { [from] = {}, [player] = {} },
		ready = {},
		confirmAt = nil,
		token = 0,
		notices = {}, -- [player] = why the server refused, shown in the trade window
	}
	trades[from] = trade
	trades[player] = trade
	sendState(trade)
end

local function setOffer(player, uids)
	local trade = trades[player]
	local data = DataService.get(player)
	if not trade or not data or type(uids) ~= "table" or #uids > TradeService.MAX_OFFER then
		return
	end
	local clean, seen, entries = {}, {}, {}
	for _, uid in ipairs(uids) do
		local entry = type(uid) == "string" and not seen[uid] and findEntry(data, uid)
		if not entry then
			return
		end
		seen[uid] = true
		table.insert(clean, uid)
		table.insert(entries, entry)
	end
	-- The offer stays as it was: readiness is not cleared, we only explain the refusal.
	local refusal = paidRandomRefusal(entries, player, partnerOf(trade, player))
	trade.notices[player] = refusal
	if refusal then
		sendState(trade)
		return
	end
	trade.offers[player] = clean
	resetReady(trade)
	sendState(trade)
end

-- Checks and performs the trade. Returns an error text or nil.
local function execute(trade)
	local a, b = trade.a, trade.b
	local dataA, dataB = DataService.get(a), DataService.get(b)
	if not dataA or not dataB then
		return S.m("trade.err_left")
	end
	local function collect(data, uids)
		local entries = {}
		for _, uid in ipairs(uids) do
			local entry = findEntry(data, uid)
			if not entry then
				return nil
			end
			table.insert(entries, entry)
		end
		return entries
	end
	local giveA = collect(dataA, trade.offers[a])
	local giveB = collect(dataB, trade.offers[b])
	if not giveA or not giveB then
		return S.m("trade.err_missing")
	end
	if #giveA == 0 and #giveB == 0 then
		return S.m("trade.err_empty")
	end
	-- You cannot "hide" brainrots at a friend's during a rebirth and take them back.
	local function returnsAfterRebirth(entries, receiver, receiverData)
		for _, entry in ipairs(entries) do
			if Formulas.isFromPastLife(entry, receiver.UserId, receiverData.rebirths) then
				return true
			end
		end
		return false
	end
	if returnsAfterRebirth(giveA, b, dataB) or returnsAfterRebirth(giveB, a, dataA) then
		return S.m("trade.err_past_life")
	end
	-- The Roblox answer about the ban could have arrived after the brainrot was put into the trade.
	if paidRandomRefusal(giveA, a, b) or paidRandomRefusal(giveB, b, a) then
		return S.m("trade.err_random")
	end
	local function fits(player, data, giving, getting)
		local after = #data.creatures - #giving + #getting
		return after <= Formulas.slots(data, MonetizationService.passes(player)) or after <= #data.creatures
	end
	if not fits(a, dataA, giveA, giveB) then
		return S.m("trade.err_no_space", { name = a.DisplayName })
	end
	if not fits(b, dataB, giveB, giveA) then
		return S.m("trade.err_no_space", { name = b.DisplayName })
	end

	-- Everything is checked: swap in one step (no yields).
	local function remove(data, entries)
		for _, entry in ipairs(entries) do
			local _, index = findEntry(data, entry.uid)
			table.remove(data.creatures, index)
		end
	end
	local function add(data, entries, receiver, giver)
		for _, entry in ipairs(entries) do
			local lineage = Formulas.mergeLineage(
				table.clone(Formulas.lineageOf(entry, giver.UserId, 0)),
				{ [tostring(receiver.UserId)] = data.rebirths }
			)
			table.insert(data.creatures, { uid = tostring(data.nextUid), id = entry.id, mut = entry.mut, paid = entry.paid, source = entry.source, skin = entry.skin, lineage = lineage })
			data.nextUid += 1
			data.index[entry.id] = true
		end
	end
	remove(dataA, giveA)
	remove(dataB, giveB)
	add(dataA, giveB, a, b)
	add(dataB, giveA, b, a)
	dataA.stats.trades = (dataA.stats.trades or 0) + 1
	dataB.stats.trades = (dataB.stats.trades or 0) + 1
	return nil
end

local function setReady(player, ready)
	local trade = trades[player]
	if not trade then
		return
	end
	trade.ready[player] = ready == true
	if not (trade.ready[trade.a] and trade.ready[trade.b]) then
		trade.confirmAt = nil
		trade.token += 1
		sendState(trade)
		return
	end

	trade.token += 1
	local token = trade.token
	trade.confirmAt = workspace:GetServerTimeNow() + TradeService.CONFIRM_DELAY
	sendState(trade)
	task.delay(TradeService.CONFIRM_DELAY, function()
		if trade.closed or trade.token ~= token then
			return
		end
		local err = execute(trade)
		if err then
			endTrade(trade, S.m("trade.cancelled", { reason = err }), BAD)
			return
		end
		local a, b = trade.a, trade.b
		endTrade(trade, S.m("trade.done"), GOOD)
		for _, participant in ipairs({ a, b }) do
			DataService.markDirty(participant)
			PlotService.render(participant)
			Remotes.Sfx:FireClient(participant, "success")
			Actions.fire(participant, "trade", 1)
			task.spawn(DataService.save, participant)
		end
	end)
end

local function cancel(player)
	local trade = trades[player]
	if trade then
		endTrade(trade, S.m("trade.partner_left", { name = player.DisplayName }), BAD)
	end
end

function TradeService.isTrading(player)
	return trades[player] ~= nil
end

function TradeService.init()
	-- The server is shutting down: a trade must not finish between the players' saves.
	DataService.onClose(function()
		for _, trade in pairs(trades) do
			if not trade.closed then
				endTrade(trade, S.m("trade.server_restart"), BAD)
			end
		end
	end)

	Remotes.TradeRequest.OnServerEvent:Connect(request)
	Remotes.TradeRespond.OnServerEvent:Connect(respond)
	Remotes.TradeSetOffer.OnServerEvent:Connect(setOffer)
	Remotes.TradeReady.OnServerEvent:Connect(setReady)
	Remotes.TradeCancel.OnServerEvent:Connect(cancel)

	Players.PlayerRemoving:Connect(function(player)
		cancel(player)
		invites[player] = nil
		lastRequest[player] = nil
	end)
end

return TradeService
