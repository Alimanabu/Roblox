-- Скины: покупка за монеты и надевание на брейнротов.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Skins = require(Shared.Config.Skins)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

local SkinService = {}

local GOOD = Color3.fromRGB(120, 255, 120)
local BAD = Color3.fromRGB(255, 110, 110)

local function buy(player, skinId)
	local data = DataService.get(player)
	local skin = type(skinId) == "string" and Skins.get(skinId)
	if not data or not skin then
		return
	end
	if data.skins[skin.id] then
		Remotes.Notify:FireClient(player, "Этот скин уже твой", BAD)
		return
	end
	if not skin.price then
		Remotes.Notify:FireClient(player, "Этот скин нельзя купить — его надо заслужить 🤌", BAD)
		return
	end
	if data.coins < skin.price then
		Remotes.Notify:FireClient(player, "Не хватает монет: нужно " .. Format.coins(skin.price), BAD)
		return
	end
	data.coins -= skin.price
	data.skins[skin.id] = true
	Remotes.Notify:FireClient(player, "🎨 Куплен скин " .. skin.name .. "! Надень его на брейнрота", GOOD)
	Remotes.Sfx:FireClient(player, "success")
	DataService.markDirty(player)
end

local function apply(player, uid, skinId)
	local data = DataService.get(player)
	if not data or type(uid) ~= "string" then
		return
	end
	if skinId ~= nil and (type(skinId) ~= "string" or not Skins.get(skinId) or not data.skins[skinId]) then
		return
	end
	for _, entry in ipairs(data.creatures) do
		if entry.uid == uid then
			entry.skin = skinId
			DataService.markDirty(player)
			PlotService.render(player)
			return
		end
	end
end

function SkinService.init()
	Remotes.BuySkin.OnServerEvent:Connect(buy)
	Remotes.ApplySkin.OnServerEvent:Connect(apply)
end

return SkinService
