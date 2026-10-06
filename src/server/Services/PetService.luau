-- Питомец: выбранный брейнрот бегает за игроком по карте (его видят все).
-- Сервер только хранит выбор и пишет атрибут Pet = "id|mutation|skin" на игрока;
-- модель и движение делает каждый клиент сам (плавно и без нагрузки на сервер).

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)

local PetService = {}

local function findEntry(data, uid)
	for _, entry in ipairs(data.creatures) do
		if entry.uid == uid then
			return entry
		end
	end
	return nil
end

-- Обновляет атрибут; если питомца продали/украли/обменяли — снимает его.
function PetService.refresh(player)
	local data = DataService.get(player)
	if not data or not player.Parent then
		return
	end
	-- Если брейнрота сейчас нет (несут воры, продали) — просто прячем питомца;
	-- выбор не сбрасываем: после неудачной кражи питомец вернётся.
	local entry = data.pet and findEntry(data, data.pet)
	local value = entry and (entry.id .. "|" .. entry.mut .. "|" .. (entry.skin or "")) or nil
	if player:GetAttribute("Pet") ~= value then
		player:SetAttribute("Pet", value)
	end
end

local SET_COOLDOWN = 1
local lastSet = {} -- [player] = os.clock()

local function setPet(player, uid)
	local data = DataService.get(player)
	if not data then
		return
	end
	-- Смена питомца пересобирает модель у всех клиентов — не чаще раза в секунду.
	local now = os.clock()
	if lastSet[player] and now - lastSet[player] < SET_COOLDOWN then
		return
	end
	lastSet[player] = now
	if uid ~= nil and (type(uid) ~= "string" or not findEntry(data, uid)) then
		return
	end
	data.pet = uid
	DataService.markDirty(player)
	PetService.refresh(player)
	if uid then
		Remotes.Notify:FireClient(player, "🐾 Теперь этот брейнрот ходит за тобой!", Color3.fromRGB(120, 255, 120))
	end
end

function PetService.init()
	Remotes.SetPet.OnServerEvent:Connect(setPet)
	Players.PlayerRemoving:Connect(function(player)
		lastSet[player] = nil
	end)
	DataService.Loaded.Event:Connect(PetService.refresh)
	-- Брейнротов могут продать, украсть, обменять — периодически сверяемся.
	task.spawn(function()
		while true do
			task.wait(2)
			for _, player in ipairs(Players:GetPlayers()) do
				PetService.refresh(player)
			end
		end
	end)
end

return PetService
