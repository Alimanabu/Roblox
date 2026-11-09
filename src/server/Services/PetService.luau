-- Pet: the selected brainrot runs after the player around the map (everyone sees it).
-- The server only stores the choice and writes the attribute Pet = "id|mutation|skin" on the player;
-- each client builds the model and the movement itself (smooth and with no server load).

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local S = require(Shared.Strings)
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

-- Updates the attribute; if the pet was sold/stolen/traded, removes it.
function PetService.refresh(player)
	local data = DataService.get(player)
	if not data or not player.Parent then
		return
	end
	-- If the brainrot is absent right now (thieves carry it, sold), we just hide the pet;
	-- the choice is not reset: after a failed steal the pet comes back.
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
	-- Changing the pet rebuilds the model on all clients, so at most once per second.
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
		Remotes.Notify:FireClient(player, S.m("pet.following"), Color3.fromRGB(120, 255, 120))
	end
end

function PetService.init()
	Remotes.SetPet.OnServerEvent:Connect(setPet)
	Players.PlayerRemoving:Connect(function(player)
		lastSet[player] = nil
	end)
	DataService.Loaded.Event:Connect(PetService.refresh)
	-- Brainrots can be sold, stolen, traded, so we re-check periodically.
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
