-- Точка входа клиента Brainrot Factory.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local State = require(script.Parent.State)
local Sfx = require(script.Parent.Sfx)
local Music = require(script.Parent.Music)
local Theme = require(script.Parent.Ui.Theme)
local Hud = require(script.Parent.Ui.Hud)
local Panels = require(script.Parent.Ui.Panels)
local Reveal = require(script.Parent.Ui.Reveal)
local StealStatus = require(script.Parent.Ui.StealStatus)
local EventBanner = require(script.Parent.Ui.EventBanner)
local TutorialBanner = require(script.Parent.Ui.TutorialBanner)
local TradeInvite = require(script.Parent.Ui.TradeInvite)
local WheelSpin = require(script.Parent.Ui.WheelSpin)

local player = Players.LocalPlayer

local screenGui = Theme.create("ScreenGui", {
	Name = "BrainrotFactoryUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

-- Масштаб интерфейса под размер экрана (телефоны / планшеты / ПК).
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

Music.start()
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
	hud:notify(text, color)
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

-- Колесо удачи.
local wheelSpin = WheelSpin.new(screenGui)
Remotes.WheelResult.OnClientEvent:Connect(function(index)
	wheelSpin:spin(index, function(final)
		Sfx.play(final and "levelup" or "craft", final and 1 or 1.4)
	end)
end)

-- Обмен.
local tradeInvite = TradeInvite.new(screenGui)
Remotes.TradeInvite.OnClientEvent:Connect(function(fromUserId, fromName)
	tradeInvite:show(fromUserId, fromName)
	Sfx.play("lock")
end)
Remotes.TradeState.OnClientEvent:Connect(function(tradeState)
	Panels.trade = tradeState
	if tradeState then
		panels:open("Trade", true)
	end
	panels:refresh()
end)
-- Пока идёт отсчёт обмена, обновляем окно, чтобы цифры менялись.
task.spawn(function()
	while true do
		task.wait(0.5)
		if Panels.trade and Panels.trade.confirmAt and panels.openName == "Trade" then
			panels:refresh()
		end
	end
end)

-- Подошёл к машине на базе -> открываем фабрику.
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "FactoryPrompt" then
		panels:open("Factory", true)
	end
end)

-- Тебя шлёпнули — отлетаешь.
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

-- Статус кражи и замка.
local status = StealStatus.new(screenGui)
local eventBanner = EventBanner.new(screenGui)
task.spawn(function()
	while true do
		task.wait(0.2)
		status:update(player, workspace:FindFirstChild("Plots"))
		eventBanner:update()
	end
end)

-- Брейнроты на базах покачиваются и крутятся; редкие переливаются радугой.
-- Кнопку «Украсть» видно только на чужих базах, кнопку замка — только на своей.
local plots = workspace:WaitForChild("Plots")
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	local serverNow = workspace:GetServerTimeNow()
	local camera = workspace.CurrentCamera
	tutorial:animate(t)
	for _, plot in ipairs(plots:GetChildren()) do
		local isMine = plot:GetAttribute("OwnerUserId") == player.UserId
		local locked = (plot:GetAttribute("LockedUntil") or 0) > serverNow
		local lockButton = plot:FindFirstChild("LockButton")
		local lockPrompt = lockButton and lockButton:FindFirstChild("LockPrompt")
		if lockPrompt then
			local shieldOnly = plot:GetAttribute("LockKind") == "shield"
			local ready = (plot:GetAttribute("LockReadyAt") or 0) <= serverNow
			lockPrompt.Enabled = isMine and ready and (not locked or shieldOnly)
		end
		local folder = plot:FindFirstChild("Creatures")
		if folder then
			for _, model in ipairs(folder:GetChildren()) do
				local body = model:IsA("Model") and model.PrimaryPart
				if body then
					local stealPrompt = body:FindFirstChild("StealPrompt")
					if stealPrompt then
						stealPrompt.Enabled = not isMine and not locked and plot:GetAttribute("OwnerUserId") ~= nil
					end
					local base = model:GetAttribute("BaseCFrame")
					-- Анимируем только тех, кто близко к камере — экономим FPS на телефонах.
					if base and camera and (base.Position - camera.CFrame.Position).Magnitude < 140 then
						local phase = base.Position.X * 0.3 + base.Position.Z * 0.2
						model:PivotTo(
							base
								* CFrame.new(0, math.abs(math.sin(t * 2 + phase)) * 0.5, 0)
								* CFrame.Angles(0, math.sin(t * 0.8 + phase) * 0.35, 0)
						)
						if model:GetAttribute("Rainbow") then
							body.Color = Color3.fromHSV((t * 0.3 + phase * 0.05) % 1, 0.7, 1)
						end
					end
				end
			end
		end
	end
end)
