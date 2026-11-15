-- "Invite friends": the Roblox invite window (SocialService:PromptGameInvite).
-- Roblox may forbid invites for a player (privacy settings, the platform, a failed request), so
-- CanSendGameInviteAsync is asked first. The window opens only on an exact `true`. Every other outcome gives the
-- player one line that names the cause (as far as we know it) and what to do, and one warn("[Invite] <branch> ...")
-- for us:
--   false              -> "denied": only Roblox knows why, so the text says "check privacy settings / use the Roblox app"
--   error, nil, timeout, a failed window -> "failed": try again later
--   any other value    -> "unavailable": an answer we do not recognise is a refusal, never a yes
-- A request that does not answer within TIMEOUT seconds frees the button again; its late answer is ignored.

local S = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Strings)

local Invite = {}

Invite.TIMEOUT = 12 -- seconds a request may take before the button works again
Invite.busy = false -- a request is on its way: more taps do nothing until it answers (or the timeout)
Invite.serial = 0 -- number of the current request: a late answer of an older one is ignored

local function show(notify, branch, detail, key)
	warn("[Invite] " .. branch .. ": " .. tostring(detail))
	local ok, err = pcall(notify, S.t(key))
	if not ok then
		warn("[Invite] notify failed: " .. tostring(err))
	end
end

-- notify(text): shows a line to the player. Returns true when the invite window was opened.
function Invite.prompt(player, notify)
	if Invite.busy then
		return false
	end
	Invite.serial += 1
	local mine = Invite.serial
	Invite.busy = true
	task.delay(Invite.TIMEOUT, function()
		if Invite.busy and Invite.serial == mine then
			Invite.busy = false
			Invite.serial += 1 -- the answer of this request, if it ever comes, is now old
			show(notify, "failed (no answer in " .. Invite.TIMEOUT .. " s)", "CanSendGameInviteAsync did not return", "social.invite_failed")
		end
	end)

	local found, SocialService = pcall(game.GetService, game, "SocialService")
	local ok, can = false, nil
	if found and SocialService then
		ok, can = pcall(function()
			return SocialService:CanSendGameInviteAsync(player)
		end)
	end
	if Invite.serial ~= mine then
		warn("[Invite] late answer ignored (the request timed out)")
		return false
	end
	Invite.busy = false

	if not found or not SocialService then
		show(notify, "failed (no SocialService)", SocialService, "social.invite_failed")
		return false
	elseif not ok then
		show(notify, "failed (request error)", can, "social.invite_failed")
		return false
	elseif can == false then
		show(notify, "denied (Roblox answered false)", "invites are not allowed for this player now", "social.invite_denied")
		return false
	elseif can == nil then
		show(notify, "failed (empty answer)", "CanSendGameInviteAsync returned nil", "social.invite_failed")
		return false
	elseif can ~= true then
		show(notify, "unavailable (unexpected answer)", typeof(can) .. " " .. tostring(can), "social.invite_unavailable")
		return false
	end

	local opened, err = pcall(function()
		SocialService:PromptGameInvite(player)
	end)
	if not opened then
		show(notify, "failed (window did not open)", err, "social.invite_failed")
	end
	return opened
end

return Invite
