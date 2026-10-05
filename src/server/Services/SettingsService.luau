-- Настройки игрока (музыка, звуки, объявления) — сохраняются вместе с прогрессом.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)

local SettingsService = {}

local ALLOWED = { music = true, sfx = true, announcements = true }

function SettingsService.init()
	Remotes.SetSetting.OnServerEvent:Connect(function(player, key, value)
		local data = DataService.get(player)
		if not data or not ALLOWED[key] or type(value) ~= "boolean" then
			return
		end
		data.settings[key] = value
		DataService.markDirty(player)
	end)
end

return SettingsService
