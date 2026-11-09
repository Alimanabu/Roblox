-- A shared bus "the player did something": created a brainrot, closed the base, bought an upgrade...
-- Quests and the tutorial subscribe here, while game code just reports actions.
-- This way services do not depend on each other in a circle.

local Actions = {}

local listeners = {}

function Actions.connect(callback)
	table.insert(listeners, callback)
end

function Actions.fire(player, kind, amount)
	for _, callback in ipairs(listeners) do
		local ok, err = pcall(callback, player, kind, amount or 1)
		if not ok then
			warn("[Actions]", kind, err)
		end
	end
end

return Actions
