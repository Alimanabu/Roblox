-- Plates in the right column of the HUD: "carry the brainrot home" and the lock state of your base.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local S = require(Shared.Strings)
local Format = require(Shared.Util.Format)

local Theme = require(script.Parent.Theme)
local create = Theme.create
local C = Theme.Colors

local StealStatus = {}
StealStatus.__index = StealStatus

function StealStatus.new(hud)
	local side = hud.side
	local self = setmetatable({}, StealStatus)

	self.carry = create("Frame", {
		Name = "CarryStatus",
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundColor3 = C.Bad,
		Visible = false,
		LayoutOrder = 1,
		Parent = side,
	}, { Theme.corner(14), Theme.stroke(Color3.new(1, 1, 1), 3) })
	self.carryLabel = Theme.label({
		Size = UDim2.new(1, -Theme.CLOSE - 8, 1, -8),
		Position = UDim2.fromOffset(8, 4),
		Text = "",
		TextWrapped = true,
		Parent = self.carry,
	})
	Theme.closable(self.carry)
	hud:addPlate(self.carry, { self.carryLabel }, { land = 44, dock = "carry" })

	self.lock = create("Frame", {
		Name = "LockStatus",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 0.15,
		LayoutOrder = 4,
		Parent = side,
	}, { Theme.corner(12) })
	self.lockStroke = Theme.stroke(C.Blue, 3)
	self.lockStroke.Parent = self.lock
	self.lockLabel = Theme.label({
		Size = UDim2.new(1, -Theme.CLOSE - 6, 1, -8),
		Position = UDim2.fromOffset(6, 4),
		Text = "",
		Parent = self.lock,
	})
	Theme.closable(self.lock)
	hud:addPlate(self.lock, { self.lockLabel }, { land = 40 })
	return self
end

function StealStatus:update(player, plots)
	local serverNow = workspace:GetServerTimeNow()

	local deadline = player:GetAttribute("CarryDeadline")
	Theme.show(self.carry, deadline ~= nil, deadline) -- ✕ stays only for this carry
	if deadline then
		self.carryLabel.Text = S.t("status.carry", { time = Format.time(deadline - serverNow) })
	end

	local myPlot
	if plots then
		for _, plot in ipairs(plots:GetChildren()) do
			if plot:GetAttribute("OwnerUserId") == player.UserId then
				myPlot = plot
				break
			end
		end
	end
	local left = (myPlot and myPlot:GetAttribute("LockedUntil") or 0) - serverNow
	local readyIn = (myPlot and myPlot:GetAttribute("LockReadyAt") or 0) - serverNow
	local kind = if left > 0
		then (if myPlot:GetAttribute("LockKind") == "shield" then "shield" else "locked")
		elseif readyIn > 0 then "ready"
		else "open"
	-- ✕ closes the plate only while the base stays in this lock state: the next state shows it again.
	Theme.show(self.lock, myPlot ~= nil, kind)
	if not myPlot then
		return
	end
	if left > 0 then
		self.lockLabel.Text = S.t(if kind == "shield" then "status.shield" else "status.locked", { time = Format.time(left) })
		self.lockLabel.TextColor3 = C.Good
		self.lockStroke.Color = C.Good
	elseif (myPlot:GetAttribute("LockReadyAt") or 0) > serverNow then
		self.lockLabel.Text = S.t("status.lock_ready", { time = Format.time(readyIn) })
		self.lockLabel.TextColor3 = C.Gold
		self.lockStroke.Color = C.Gold
	else
		self.lockLabel.Text = S.t("status.open")
		self.lockLabel.TextColor3 = C.Bad
		self.lockStroke.Color = C.Bad
	end
end

return StealStatus
