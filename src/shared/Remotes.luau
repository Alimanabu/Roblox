-- Network events. The server creates them, the client waits.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	-- client -> server
	"Craft", -- (capsuleId)
	"Sell", -- (uid)
	"SellRarity", -- (rarityId) sell all of this rarity
	"Fuse", -- (rarityId) fuse 3 brainrots of one rarity
	"BuyUpgrade", -- (upgradeId)
	"BuyFloor", -- () build the next base floor
	"Rebirth", -- ()
	"SetAutoCraft", -- (capsuleId | nil)
	"ClaimDaily", -- () claim the daily reward
	"ClaimQuest", -- (index) claim the quest reward
	"Admin", -- (command, arg) test commands (admins / Studio only)
	"RedeemCode", -- (text) enter a promo code
	"ClaimGift", -- (index) gift for time in game
	"TradeRequest", -- (targetUserId) invite to trade
	"TradeRespond", -- (fromUserId, accept) respond to an invitation
	"TradeSetOffer", -- ({ uid, ... }) what I put into the trade
	"TradeReady", -- (bool) "Ready"
	"TradeCancel", -- () leave the trade
	"BuySkin", -- (skinId)
	"ApplySkin", -- (uid, skinId | nil)
	"SetSetting", -- (key, bool) player settings
	"SpinWheel", -- () spin the lucky wheel
	"BattleChallenge", -- (targetUserId | "bot") challenge to an aura battle
	"BattleRespond", -- (fromUserId, accept)
	"SetPet", -- (uid | nil) choose a pet
	"RenameCreature", -- (uid, text) give a brainrot a name

	-- server -> client
	"State", -- (snapshot)
	"CraftResult", -- (result)
	"Notify", -- (text, color)
	"Knockback", -- (velocity) you got slapped
	"Sfx", -- (soundName) play a sound
	"TradeState", -- (state | nil) trade state
	"TradeInvite", -- (fromUserId, fromName) you are invited to trade
	"WheelResult", -- (index) what dropped on the wheel
	"BattleInvite", -- (fromUserId, fromName) you were challenged to a battle
	"BattleResult", -- (result) rounds and battle outcome
	"LegendaryDrop", -- ({ userId, name, creatureId, mut }) someone got a legendary drop: a show for everyone
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
