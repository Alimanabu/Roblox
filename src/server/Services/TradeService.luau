-- Обмен брейнротами между игроками.
--
-- 1. Игрок A приглашает B, B принимает.
-- 2. Каждый кладёт в обмен до MAX_OFFER брейнротов.
-- 3. Оба жмут «Готов» -> CONFIRM_DELAY секунд отсчёта.
--    Любое изменение предложения снимает «Готов» у обоих (защита от подмены).
-- 4. Сервер перепроверяет всё и меняет брейнротов за один шаг, затем сохраняет обоих.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
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

local trades = {} -- [player] = trade (одна и та же таблица у обоих участников)
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

-- Что видит игрок в окне обмена.
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
	-- В некоторых странах обмен платными предметами запрещён (правила Roblox).
	if not PolicyService.tradingAllowed(player) then
		Remotes.Notify:FireClient(player, "Обмен недоступен в твоём регионе", BAD)
		return
	end
	if not PolicyService.tradingAllowed(target) then
		Remotes.Notify:FireClient(player, "У этого игрока обмен недоступен", BAD)
		return
	end
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < TradeService.REQUEST_COOLDOWN then
		Remotes.Notify:FireClient(player, "Подожди немного перед новым приглашением", BAD)
		return
	end
	if trades[player] or trades[target] then
		Remotes.Notify:FireClient(player, "Кто-то из вас уже в обмене", BAD)
		return
	end
	lastRequest[player] = now
	invites[target] = invites[target] or {}
	invites[target][player.UserId] = now
	Remotes.TradeInvite:FireClient(target, player.UserId, player.DisplayName)
	Remotes.Notify:FireClient(player, "📨 Приглашение отправлено: " .. target.DisplayName, INFO)
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
		Remotes.Notify:FireClient(from, player.DisplayName .. " отклонил обмен", BAD)
		return
	end
	if not PolicyService.tradingAllowed(player) or not PolicyService.tradingAllowed(from) then
		return
	end
	if trades[player] or trades[from] then
		Remotes.Notify:FireClient(player, "Кто-то из вас уже в обмене", BAD)
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
	local clean, seen = {}, {}
	for _, uid in ipairs(uids) do
		if type(uid) ~= "string" or seen[uid] or not findEntry(data, uid) then
			return
		end
		seen[uid] = true
		table.insert(clean, uid)
	end
	trade.offers[player] = clean
	resetReady(trade)
	sendState(trade)
end

-- Проверяет и проводит обмен. Возвращает текст ошибки или nil.
local function execute(trade)
	local a, b = trade.a, trade.b
	local dataA, dataB = DataService.get(a), DataService.get(b)
	if not dataA or not dataB then
		return "игрок вышел"
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
		return "брейнрота из предложения больше нет"
	end
	if #giveA == 0 and #giveB == 0 then
		return "обмен пустой"
	end
	-- Нельзя «спрятать» брейнротов у друга на время перерождения и забрать обратно.
	local function returnsAfterRebirth(entries, receiver, receiverData)
		for _, entry in ipairs(entries) do
			if Formulas.isFromPastLife(entry, receiver.UserId, receiverData.rebirths) then
				return true
			end
		end
		return false
	end
	if returnsAfterRebirth(giveA, b, dataB) or returnsAfterRebirth(giveB, a, dataA) then
		return "своего брейнрота из прошлой жизни (до перерождения) вернуть нельзя"
	end
	local function fits(player, data, giving, getting)
		local after = #data.creatures - #giving + #getting
		return after <= Formulas.slots(data, MonetizationService.passes(player)) or after <= #data.creatures
	end
	if not fits(a, dataA, giveA, giveB) then
		return "у " .. a.DisplayName .. " не хватает мест на базе"
	end
	if not fits(b, dataB, giveB, giveA) then
		return "у " .. b.DisplayName .. " не хватает мест на базе"
	end

	-- Всё проверено — меняем за один шаг (без yield'ов).
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
			table.insert(data.creatures, { uid = tostring(data.nextUid), id = entry.id, mut = entry.mut, paid = entry.paid, skin = entry.skin, lineage = lineage })
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
			endTrade(trade, "❌ Обмен отменён: " .. err, BAD)
			return
		end
		local a, b = trade.a, trade.b
		endTrade(trade, "🤝 Обмен завершён!", GOOD)
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
		endTrade(trade, "Обмен отменён: " .. player.DisplayName .. " вышел из обмена", BAD)
	end
end

function TradeService.isTrading(player)
	return trades[player] ~= nil
end

function TradeService.init()
	-- Сервер выключается: обмен не должен завершиться между сохранениями игроков.
	DataService.onClose(function()
		for _, trade in pairs(trades) do
			if not trade.closed then
				endTrade(trade, "Обмен отменён: сервер перезапускается", BAD)
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
