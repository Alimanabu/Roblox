-- Stores the player's latest state sent by the server.

local State = {}

State.current = nil
local listeners = {}

function State.set(snapshot)
	State.current = snapshot
	for _, callback in ipairs(listeners) do
		task.spawn(callback, snapshot)
	end
end

function State.onChanged(callback)
	table.insert(listeners, callback)
	if State.current then
		task.spawn(callback, State.current)
	end
end

return State
