-- Общая шина «игрок что-то сделал»: создал брейнрота, закрыл базу, купил улучшение...
-- Задания и обучение подписываются сюда, а игровой код просто сообщает о действиях.
-- Так сервисы не зависят друг от друга по кругу.

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
