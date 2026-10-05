-- Ивенты на весь сервер. Время берётся по UTC, поэтому ивенты идут одновременно
-- на всех серверах — можно звать друзей: «через 2 минуты Минута 67!».

local Events = {}

Events.CYCLE = 15 * 60 -- случайный ивент начинается каждые 15 минут...
Events.DURATION = 3 * 60 -- ...и длится 3 минуты

Events.Random = {
	{ id = "luck_storm", name = "🍀 Шторм удачи", desc = "x2 удачи всем!", luck = 2, color = Color3.fromRGB(120, 255, 120) },
	{ id = "money_rain", name = "💰 Денежный дождь", desc = "x2 дохода всем!", income = 2, color = Color3.fromRGB(255, 220, 80) },
	{ id = "mutant_fog", name = "🧬 Мутаген-туман", desc = "x3 шанс мутаций!", mutation = 3, color = Color3.fromRGB(200, 120, 255) },
	{ id = "turbo", name = "⚡ Турбо-фабрика", desc = "Машины работают в 2 раза быстрее!", speed = 2, color = Color3.fromRGB(80, 200, 255) },
}

-- Каждый час с 6:00 по 7:59 минуты — «6-7».
Events.SixSeven = {
	id = "minute67",
	name = "🤌 МИНУТА 67",
	desc = "Шанс SIX SEVEN и мутации 67 x6.7!",
	secret = 6.7,
	mutation67 = 6.7,
	color = Color3.fromRGB(255, 230, 0),
	startMinute = 6,
	endMinute = 8, -- не включительно
}

function Events.byId(id)
	if id == Events.SixSeven.id then
		return Events.SixSeven
	end
	for _, event in ipairs(Events.Random) do
		if event.id == id then
			return event
		end
	end
	return nil
end

local function randomEventFor(cycleIndex)
	-- Перемешиваем порядок, чтобы ивенты не шли по кругу предсказуемо.
	local index = (cycleIndex * 7919 + 13) % #Events.Random + 1
	return Events.Random[index]
end

-- Список активных ивентов: { { event, endsAt } }.
function Events.active(time)
	local result = {}
	local cycleIndex = math.floor(time / Events.CYCLE)
	local cycleStart = cycleIndex * Events.CYCLE
	if time - cycleStart < Events.DURATION then
		table.insert(result, { event = randomEventFor(cycleIndex), endsAt = cycleStart + Events.DURATION })
	end

	local hourStart = math.floor(time / 3600) * 3600
	local minute = (time - hourStart) / 60
	local six = Events.SixSeven
	if minute >= six.startMinute and minute < six.endMinute then
		table.insert(result, { event = six, endsAt = hourStart + six.endMinute * 60 })
	end

	-- Ивент, запущенный вручную через панель «🛠 Тест» (атрибуты на workspace).
	local forcedId = workspace and workspace:GetAttribute("ForcedEvent")
	local forcedUntil = workspace and workspace:GetAttribute("ForcedEventUntil")
	if forcedId and forcedUntil and time < forcedUntil then
		local forced = Events.byId(forcedId)
		local already = false
		for _, active in ipairs(result) do
			already = already or active.event == forced
		end
		if forced and not already then
			table.insert(result, { event = forced, endsAt = forcedUntil })
		end
	end
	return result
end

-- Ближайший ивент, который ещё не начался: event, startsAt.
function Events.nextEvent(time)
	local cycleIndex = math.floor(time / Events.CYCLE) + 1
	local nextRandom = cycleIndex * Events.CYCLE

	local hourStart = math.floor(time / 3600) * 3600
	local nextSix = hourStart + Events.SixSeven.startMinute * 60
	if nextSix <= time then
		nextSix += 3600
	end
	if nextSix < nextRandom then
		return Events.SixSeven, nextSix
	end
	return randomEventFor(cycleIndex), nextRandom
end

-- Множители от всех активных ивентов.
function Events.modifiers(time)
	local mods = { luck = 1, income = 1, mutation = 1, speed = 1, secret = 1, mutation67 = 1 }
	for _, active in ipairs(Events.active(time)) do
		for key in pairs(mods) do
			local value = active.event[key]
			if type(value) == "number" then
				mods[key] *= value
			end
		end
	end
	return mods
end

return Events
