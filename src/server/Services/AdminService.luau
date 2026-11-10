-- Test commands for checking the game: coins, levels, brainrots, events, reset.
-- They work for everyone in Studio and in the published game only for the UserIds in Config/Admins.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local S = require(Shared.Strings)
local Admins = require(Shared.Config.Admins)
local Creatures = require(Shared.Config.Creatures)
local Events = require(Shared.Config.Events)
local Levels = require(Shared.Config.Levels)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local FactoryService = require(script.Parent.FactoryService)
local PlotService = require(script.Parent.PlotService)
local ProgressionService = require(script.Parent.ProgressionService)

local AdminService = {}

local INFO = Color3.fromRGB(120, 200, 255)

function AdminService.isAdmin(player)
	if RunService:IsStudio() then
		return true
	end
	return table.find(Admins.UserIds, player.UserId) ~= nil
end

local function randomOfRarity(rarityId)
	local pool = Creatures.ByRarity[rarityId]
	return pool[math.random(1, #pool)]
end

local COMMANDS = {}

function COMMANDS.coins(player, data, amount)
	amount = math.clamp(tonumber(amount) or 0, 0, 1e15)
	data.coins += amount
	return "+" .. Format.coins(amount)
end

function COMMANDS.levels(player, data, amount)
	amount = math.clamp(math.floor(tonumber(amount) or 1), 1, Levels.MAX_LEVEL)
	data.level = math.min(Levels.MAX_LEVEL, data.level + amount)
	data.xp = 0
	ProgressionService.updateOverhead(player)
	return S.m("admin.level", { level = data.level })
end

function COMMANDS.creature(player, data, rarityId)
	if type(rarityId) ~= "string" or not Creatures.ByRarity[rarityId] then
		return nil
	end
	local creature = randomOfRarity(rarityId)
	FactoryService.give(player, creature.id, "normal")
	return S.m("admin.given", { name = S.m(creature.nameKey) })
end

function COMMANDS.mutant(player, data)
	local creature = randomOfRarity("aura")
	FactoryService.give(player, creature.id, "sixseven")
	return S.m("admin.given_mutant", { name = S.m(creature.nameKey) })
end

function COMMANDS.event(player, data, eventId)
	local event = type(eventId) == "string" and Events.byId(eventId)
	if not event then
		return nil
	end
	workspace:SetAttribute("ForcedEvent", event.id)
	workspace:SetAttribute("ForcedEventUntil", os.time() + 120)
	return S.m("admin.event", { name = S.m(event.nameKey) })
end

function COMMANDS.season(player, data, seasonId)
	if seasonId == "" then
		workspace:SetAttribute("ForcedSeason", nil)
		return S.m("admin.season_off")
	end
	local Seasons = require(Shared.Config.Seasons)
	local season = type(seasonId) == "string" and Seasons.ById[seasonId]
	if not season then
		return nil
	end
	workspace:SetAttribute("ForcedSeason", season.id)
	return S.m("admin.season_on", { name = S.m("season." .. season.id .. ".name") })
end

function COMMANDS.wild(player, data)
	require(script.Parent.WildService).forceSpawn()
	return S.m("admin.wild")
end

function COMMANDS.skipTutorial(player, data)
	data.tutorial.step = 999
	return S.m("admin.tutorial_skipped")
end

function COMMANDS.removeFloors(player, data)
	data.floors = 0
	return S.m("admin.floors_removed")
end

function COMMANDS.resetDaily(player, data)
	data.daily.lastClaimDay = 0
	data.quests.day = 0
	data.playtime = { day = 0, seconds = 0, claimed = {} }
	return S.m("admin.daily_reset")
end

function COMMANDS.reset(player)
	DataService.reset(player)
	ProgressionService.updateOverhead(player)
	return S.m("admin.progress_reset")
end

local function onAdmin(player, command, arg)
	if not AdminService.isAdmin(player) or type(command) ~= "string" then
		return
	end
	local handler = COMMANDS[command]
	local data = DataService.get(player)
	if not handler or not data then
		return
	end
	data.funnel.admin = true -- any admin command makes the profile a test one: no analytics funnel steps
	local result = handler(player, data, arg)
	if result then
		DataService.markDirty(player)
		PlotService.render(player)
		Remotes.Notify:FireClient(player, S.m("admin.result", { text = result }), INFO)
	end
end

function AdminService.init()
	Remotes.Admin.OnServerEvent:Connect(onAdmin)
	Players.PlayerAdded:Connect(function(player)
		if AdminService.isAdmin(player) then
			player:SetAttribute("IsAdmin", true)
		end
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		if AdminService.isAdmin(player) then
			player:SetAttribute("IsAdmin", true)
		end
	end
end

return AdminService
