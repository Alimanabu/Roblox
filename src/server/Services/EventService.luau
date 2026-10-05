-- Ивенты на весь сервер: объявления о начале/конце и множители для расчётов.

local Lighting = game:GetService("Lighting")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Events = require(Shared.Config.Events)
local Remotes = require(Shared.Remotes)

local EventService = {}

function EventService.mods()
	return Events.modifiers(os.time())
end

function EventService.init()
	-- Небо слегка окрашивается в цвет активного ивента.
	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "EventTint"
	tint.Enabled = false
	tint.Parent = Lighting

	local activeIds = {}
	local warned = {}
	task.spawn(function()
		while true do
			local now = os.time()
			local current = {}
			local tintColor
			for _, active in ipairs(Events.active(now)) do
				local event = active.event
				current[event.id] = true
				tintColor = event.color
				if not activeIds[event.id] then
					Remotes.Notify:FireAllClients("🎉 Начался ивент " .. event.name .. ": " .. event.desc, event.color)
				end
			end
			for id in pairs(activeIds) do
				if not current[id] then
					Remotes.Notify:FireAllClients("Ивент закончился. Следующий скоро!", Color3.fromRGB(200, 200, 200))
				end
			end
			activeIds = current

			-- Предупреждаем за минуту до ивента.
			local nextEvent, startsAt = Events.nextEvent(now)
			local key = nextEvent.id .. startsAt
			if startsAt - now <= 60 and not warned[key] then
				warned[key] = true
				Remotes.Notify:FireAllClients("⏰ Через минуту: " .. nextEvent.name .. "!", nextEvent.color)
			end

			tint.Enabled = tintColor ~= nil
			if tintColor then
				tint.TintColor = Color3.new(1, 1, 1):Lerp(tintColor, 0.25)
				tint.Saturation = 0.15
			end
			task.wait(1)
		end
	end)
end

return EventService
