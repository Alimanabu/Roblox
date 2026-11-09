-- Client entry point of Brainrot Capsule Factory.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local S = require(Shared.Strings)
local Remotes = require(Shared.Remotes)

local State = require(script.Parent.State)
local Sfx = require(script.Parent.Sfx)
local Music = require(script.Parent.Music)
local LegendaryFx = require(script.Parent.LegendaryFx)
local PetFollow = require(script.Parent.PetFollow)
local WorldText = require(script.Parent.WorldText)
local BaseAnimator = require(script.Parent.BaseAnimator)
local RenameDialog = require(script.Parent.Ui.RenameDialog)
local DiscoFx = require(script.Parent.DiscoFx)
local Events = require(Shared.Config.Events)
local Theme = require(script.Parent.Ui.Theme)
local Hud = require(script.Parent.Ui.Hud)
local Panels = require(script.Parent.Ui.Panels)
local Reveal = require(script.Parent.Ui.Reveal)
local StealStatus = require(script.Parent.Ui.StealStatus)
local EventBanner = require(script.Parent.Ui.EventBanner)
local TutorialBanner = require(script.Parent.Ui.TutorialBanner)
local TradeInvite = require(script.Parent.Ui.TradeInvite)
local WheelSpin = require(script.Parent.Ui.WheelSpin)
local BattleView = require(script.Parent.Ui.BattleView)

local player = Players.LocalPlayer

local screenGui = Theme.create("ScreenGui", {
	Name = "BrainrotFactoryUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

-- UI scale for the screen size (phones / tablets / PC).
local uiScale = Theme.create("UIScale", { Parent = screenGui })
local function updateScale()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local size = camera.ViewportSize
	uiScale.Scale = math.clamp(math.min(size.X / 1280, size.Y / 760), 0.5, 1.25)
end
updateScale()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

local panels = Panels.new(screenGui)
local hud = Hud.new(screenGui, function(name)
	panels:open(name)
end, Panels.giftsReady)
local reveal = Reveal.new(screenGui)
local tutorial = TutorialBanner.new(screenGui, hud)

local renameDialog = RenameDialog.new(screenGui)
Panels.onRename = function(uid, currentName)
	renameDialog:show(uid, currentName)
end

Music.start()
PetFollow.start()
WorldText.start()
local announcementsOn = true

State.onChanged(function(state)
	Sfx.enabled = state.settings.sfx
	Music.setEnabled(state.settings.music)
	announcementsOn = state.settings.announcements
	hud:update(state)
	panels:update(state)
	tutorial:update(state)
end)

Remotes.State.OnClientEvent:Connect(State.set)
Remotes.Notify.OnClientEvent:Connect(function(text, color, isAnnouncement)
	if isAnnouncement and not announcementsOn then
		return
	end
	hud:notify(S.text(text), color)
end)
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
Remotes.CraftResult.OnClientEvent:Connect(function(result)
	reveal:show(result, State.current)
	local creature = Creatures.get(result.id)
	local rarity = creature and Rarities.get(creature.rarity)
	if rarity and rarity.rank >= 6 then
		Sfx.play("rare")
	else
		Sfx.play("craft", 1 + (rarity and rarity.rank or 1) * 0.06)
	end
end)
Remotes.Sfx.OnClientEvent:Connect(function(name)
	Sfx.play(name)
end)

-- Lucky wheel.
local wheelSpin = WheelSpin.new(screenGui)
Remotes.WheelResult.OnClientEvent:Connect(function(index)
	wheelSpin:spin(index, function(final)
		Sfx.play(final and "levelup" or "craft", final and 1 or 1.4)
	end)
end)

-- Someone on the server got a legendary drop: show.
Remotes.LegendaryDrop.OnClientEvent:Connect(function(info)
	LegendaryFx.play(screenGui, info, function(name)
		Sfx.play(name)
	end)
end)

-- Aura battles.
local battleInvite = TradeInvite.new(screenGui, Remotes.BattleRespond, 130)
Remotes.BattleInvite.OnClientEvent:Connect(function(fromUserId, fromName)
	battleInvite:show(fromUserId, S.t("battle.invite", { name = fromName }))
	Sfx.play("alarm")
end)
local battleView = BattleView.new(screenGui, function(name)
	Sfx.play(name)
end)
Remotes.BattleResult.OnClientEvent:Connect(function(result)
	if panels.openName ~= "Trade" then
		panels:close()
	end
	battleView:show(result)
end)

-- Trade.
local tradeInvite = TradeInvite.new(screenGui)
Remotes.TradeInvite.OnClientEvent:Connect(function(fromUserId, fromName)
	tradeInvite:show(fromUserId, S.t("trade.invite", { name = fromName }))
	Sfx.play("lock")
end)
Remotes.TradeState.OnClientEvent:Connect(function(tradeState)
	Panels.trade = tradeState
	if tradeState then
		panels:open("Trade", true)
	end
	panels:refresh()
end)
-- While the trade countdown runs, we refresh the window so the numbers change.
task.spawn(function()
	while true do
		task.wait(0.5)
		if Panels.trade and Panels.trade.confirmAt and panels.openName == "Trade" then
			panels:refresh()
		end
	end
end)

-- Walked up to the machine on the base -> open the factory.
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "FactoryPrompt" then
		panels:open("Factory", true)
	end
end)

-- You got slapped: you fly off.
Remotes.Knockback.OnClientEvent:Connect(function(velocity)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	Sfx.play("slap")
	if root and humanoid then
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		root.AssemblyLinearVelocity = velocity
	end
end)

-- Steal and lock status.
local status = StealStatus.new(screenGui)
local eventBanner = EventBanner.new(screenGui)
task.spawn(function()
	while true do
		task.wait(0.2)
		status:update(player, workspace:FindFirstChild("Plots"))
		eventBanner:update()
		-- Minute 67: disco!
		local disco = false
		for _, activeEvent in ipairs(Events.active(workspace:GetServerTimeNow())) do
			disco = disco or activeEvent.event.id == Events.SixSeven.id
		end
		DiscoFx.setActive(disco)
	end
end)

BaseAnimator.start(workspace:WaitForChild("Plots"), player)

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	tutorial:animate(t)

	-- The boss on the plaza sways and turns.
	local boss = workspace:FindFirstChild("Boss")
	local bossBase = boss and boss:GetAttribute("BaseCFrame")
	if bossBase then
		boss:PivotTo(bossBase * CFrame.new(0, math.abs(math.sin(t * 1.5)) * 2, 0) * CFrame.Angles(0, math.sin(t * 0.7) * 0.6, 0))
	end
end)
