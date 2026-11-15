-- "Invite friends": the Roblox invite window (SocialService:PromptGameInvite).
-- Roblox may forbid invites for a player (privacy settings, the platform, a failed request), so
-- CanSendGameInviteAsync is asked first. The window opens only on an exact `true`; anything else
-- (false, nil, another value, an error) gives one short line instead, and nothing breaks.

local S = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Strings)

local Invite = {}

Invite.busy = false -- a request is on its way: more taps do nothing until it answers

-- notify(text): shows a line to the player. Returns true when the invite window was opened.
function Invite.prompt(player, notify)
	if Invite.busy then
		return false
	end
	Invite.busy = true
	local opened = false
	local found, SocialService = pcall(game.GetService, game, "SocialService")
	if found and SocialService then
		local ok, can = pcall(function()
			return SocialService:CanSendGameInviteAsync(player)
		end)
		if ok and can == true then
			opened = pcall(function()
				SocialService:PromptGameInvite(player)
			end)
		end
	end
	Invite.busy = false
	if not opened then
		pcall(notify, S.t("social.invite_unavailable"))
	end
	return opened
end

return Invite
