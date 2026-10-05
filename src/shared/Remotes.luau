-- Сетевые события. Сервер их создаёт, клиент ждёт.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	-- клиент -> сервер
	"Craft", -- (capsuleId)
	"Sell", -- (uid)
	"SellRarity", -- (rarityId) продать всех этой редкости
	"Fuse", -- (rarityId) скрестить 3 брейнрота одной редкости
	"BuyUpgrade", -- (upgradeId)
	"Rebirth", -- ()
	"SetAutoCraft", -- (capsuleId | nil)
	"ClaimDaily", -- () забрать ежедневную награду
	"ClaimQuest", -- (index) забрать награду за задание

	-- сервер -> клиент
	"State", -- (snapshot)
	"CraftResult", -- (result)
	"Notify", -- (text, color)
	"Knockback", -- (velocity) тебя шлёпнули
}

local Remotes = {}

local folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in ipairs(EVENTS) do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

for _, name in ipairs(EVENTS) do
	Remotes[name] = folder:WaitForChild(name)
end

return Remotes
