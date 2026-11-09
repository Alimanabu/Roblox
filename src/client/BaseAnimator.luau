-- Brainrots on the bases sway and spin; rare ones shimmer with a rainbow.
-- The "Steal" button is only visible on other players' bases, the lock button only on your own.
--
-- A phone must not loop over every model on the map (up to 160) each frame, so the work is split:
-- every REFRESH_EVERY seconds we walk the bases, place the buttons and collect those near the camera;
-- each frame we move only those, and the far ones every other frame (once per FAR_EVERY frames).

local RunService = game:GetService("RunService")

local DiscoFx = require(script.Parent.DiscoFx)

local BaseAnimator = {}

BaseAnimator.REFRESH_EVERY = 0.25
BaseAnimator.ANIMATE_DISTANCE = 140 -- farther than the camera: not animated at all
BaseAnimator.NEAR_DISTANCE = 70 -- closer: animated every frame
BaseAnimator.FAR_EVERY = 3

local nearby = {} -- { { model, body, base, phase, far, rainbow } }
local frame = 0

local function setEnabled(prompt, enabled)
	if prompt and prompt.Enabled ~= enabled then
		prompt.Enabled = enabled
	end
end

local function refresh(plots, player)
	local serverNow = workspace:GetServerTimeNow()
	local camera = workspace.CurrentCamera
	local cameraPosition = camera and camera.CFrame.Position
	table.clear(nearby)
	for _, plot in ipairs(plots:GetChildren()) do
		local ownerId = plot:GetAttribute("OwnerUserId")
		local isMine = ownerId == player.UserId
		local locked = (plot:GetAttribute("LockedUntil") or 0) > serverNow
		local lockButton = plot:FindFirstChild("LockButton")
		local shieldOnly = plot:GetAttribute("LockKind") == "shield"
		local ready = (plot:GetAttribute("LockReadyAt") or 0) <= serverNow
		setEnabled(lockButton and lockButton:FindFirstChild("LockPrompt"), isMine and ready and (not locked or shieldOnly))
		-- Build sign: only the owner buys floors.
		local buildSign = plot:FindFirstChild("BuildSign")
		setEnabled(buildSign and buildSign:FindFirstChild("BuildPrompt"), isMine and plot:GetAttribute("CanBuild") == true)

		local canSteal = not isMine and not locked and ownerId ~= nil
		local folder = plot:FindFirstChild("Creatures")
		if folder then
			for _, model in ipairs(folder:GetChildren()) do
				local body = model:IsA("Model") and model.PrimaryPart
				if body then
					setEnabled(body:FindFirstChild("StealPrompt"), canSteal)
					local base = model:GetAttribute("BaseCFrame")
					local distance = base and cameraPosition and (base.Position - cameraPosition).Magnitude
					if distance and distance < BaseAnimator.ANIMATE_DISTANCE then
						table.insert(nearby, {
							model = model,
							body = body,
							base = base,
							phase = base.Position.X * 0.3 + base.Position.Z * 0.2,
							far = distance >= BaseAnimator.NEAR_DISTANCE,
							rainbow = model:GetAttribute("Rainbow"),
						})
					end
				end
			end
		end
	end
end

local function animate()
	frame += 1
	local t = os.clock()
	local disco = DiscoFx.isActive()
	for index, item in ipairs(nearby) do
		if item.model.Parent and (not item.far or (index + frame) % BaseAnimator.FAR_EVERY == 0) then
			local base, phase = item.base, item.phase
			if disco then
				-- Disco: they jump to the beat and spin.
				item.model:PivotTo(
					base
						* CFrame.new(0, math.abs(math.sin(t * 6)) * 2.2, 0)
						* CFrame.Angles(0, t * 4 + phase, math.sin(t * 6) * 0.25)
				)
			else
				item.model:PivotTo(
					base
						* CFrame.new(0, math.abs(math.sin(t * 2 + phase)) * 0.5, 0)
						* CFrame.Angles(0, math.sin(t * 0.8 + phase) * 0.35, 0)
				)
			end
			if item.rainbow then
				item.body.Color = Color3.fromHSV((t * 0.3 + phase * 0.05) % 1, 0.7, 1)
			end
		end
	end
end

function BaseAnimator.start(plots, player)
	RunService.RenderStepped:Connect(animate)
	task.spawn(function()
		while true do
			refresh(plots, player)
			task.wait(BaseAnimator.REFRESH_EVERY)
		end
	end)
end

return BaseAnimator
