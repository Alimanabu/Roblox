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
	"Admin", -- (command, arg) тестовые команды (только админы / Studio)
	"RedeemCode", -- (text) ввести промокод
	"ClaimGift", -- (index) подарок за время в игре
	"TradeRequest", -- (targetUserId) пригласить к обмену
	"TradeRespond", -- (fromUserId, accept) ответить на приглашение
	"TradeSetOffer", -- ({ uid, ... }) что я кладу в обмен
	"TradeReady", -- (bool) «Готов»
	"TradeCancel", -- () выйти из обмена
	"BuySkin", -- (skinId)
	"ApplySkin", -- (uid, skinId | nil)
	"SetSetting", -- (key, bool) настройки игрока
	"SpinWheel", -- () крутить колесо удачи
	"BattleChallenge", -- (targetUserId | "bot") вызвать на аура-баттл
	"BattleRespond", -- (fromUserId, accept)
	"SetPet", -- (uid | nil) выбрать питомца
	"RenameCreature", -- (uid, text) дать брейнроту имя

	-- сервер -> клиент
	"State", -- (snapshot)
	"CraftResult", -- (result)
	"Notify", -- (text, color)
	"Knockback", -- (velocity) тебя шлёпнули
	"Sfx", -- (soundName) проиграть звук
	"TradeState", -- (state | nil) состояние обмена
	"TradeInvite", -- (fromUserId, fromName) тебя зовут обменяться
	"WheelResult", -- (index) что выпало на колесе
	"BattleInvite", -- (fromUserId, fromName) тебя вызвали на баттл
	"BattleResult", -- (result) раунды и итог баттла
	"LegendaryDrop", -- ({ userId, name, creatureId, mut }) кто-то выбил легендарку — шоу для всех
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
