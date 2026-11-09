-- Brainrot names. Any text from players MUST be filtered through
-- TextService (a Roblox rule), otherwise the game can be banned.

local Players = game:GetService("Players")
local TextService = game:GetService("TextService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local S = require(Shared.Strings)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

local NameService = {}

local MAX_LENGTH = 20
local COOLDOWN = 5

local GOOD = Color3.fromRGB(120, 255, 120)
local BAD = Color3.fromRGB(255, 110, 110)

local lastRename = {} -- [player] = os.clock()

local function filter(text, player)
	local ok, result = pcall(function()
		local filtered = TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat)
		return filtered:GetNonChatStringForBroadcastAsync()
	end)
	return ok and result or nil
end

local function rename(player, uid, text)
	local data = DataService.get(player)
	if not data or type(uid) ~= "string" or type(text) ~= "string" then
		return
	end
	local now = os.clock()
	if lastRename[player] and now - lastRename[player] < COOLDOWN then
		Remotes.Notify:FireClient(player, S.m("common.wait"), BAD)
		return
	end
	lastRename[player] = now

	local entry
	for _, candidate in ipairs(data.creatures) do
		if candidate.uid == uid then
			entry = candidate
			break
		end
	end
	if not entry then
		return
	end

	if #text > 200 then
		return
	end
	text = text:gsub("[%c]", ""):gsub("^%s+", ""):gsub("%s+$", "")
	if text == "" then
		entry.nickname = nil
	else
		if utf8.len(text) == nil or utf8.len(text) > MAX_LENGTH then
			Remotes.Notify:FireClient(player, S.m("name.too_long", { max = MAX_LENGTH }), BAD)
			return
		end
		local filtered = filter(text, player)
		if not filtered then
			Remotes.Notify:FireClient(player, S.m("name.filter_failed"), BAD)
			return
		end
		entry.nickname = filtered
	end
	DataService.markDirty(player)
	PlotService.render(player)
	local shown = entry.nickname and entry.nickname:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
	Remotes.Notify:FireClient(player, if shown then S.m("name.changed", { name = shown }) else S.m("name.removed"), GOOD)
end

function NameService.init()
	Remotes.RenameCreature.OnServerEvent:Connect(rename)
	Players.PlayerRemoving:Connect(function(player)
		lastRename[player] = nil
	end)
end

return NameService
