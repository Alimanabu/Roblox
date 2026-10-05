-- Точка входа клиента Brainrot Factory.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local State = require(script.Parent.State)
local Theme = require(script.Parent.Ui.Theme)
local Hud = require(script.Parent.Ui.Hud)
local Panels = require(script.Parent.Ui.Panels)
local Reveal = require(script.Parent.Ui.Reveal)
local StealStatus = require(script.Parent.Ui.StealStatus)

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
end)
local reveal = Reveal.new(screenGui)

State.onChanged(function(state)
	hud:update(state)
	panels:update(state)
end)

Remotes.State.OnClientEvent:Connect(State.set)
Remotes.Notify.OnClientEvent:Connect(function(text, color)
	hud:notify(text, color)
end)
local craftSound = Theme.create("Sound", {
	Name = "CraftSound",
	SoundId = "rbxasset://sounds/electronicpingshort.wav",
	Volume = 0.5,
	Parent = SoundService,
})
Remotes.CraftResult.OnClientEvent:Connect(function(result)
	reveal:show(result, State.current)
	craftSound:Play()
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
	if root and humanoid then
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		root.AssemblyLinearVelocity = velocity
	end
end)

-- Статус кражи и замка.
local status = StealStatus.new(screenGui)
task.spawn(function()
	while true do
		task.wait(0.2)
		status:update(player, workspace:FindFirstChild("Plots"))
	end
end)

-- Брейнроты на базах покачиваются и крутятся; редкие переливаются радугой.
-- Кнопку «Украсть» видно только на чужих базах, кнопку замка — только на своей.
local plots = workspace:WaitForChild("Plots")
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	local serverNow = workspace:GetServerTimeNow()
	for _, plot in ipairs(plots:GetChildren()) do
		local isMine = plot:GetAttribute("OwnerUserId") == player.UserId
		local locked = (plot:GetAttribute("LockedUntil") or 0) > serverNow
		local lockButton = plot:FindFirstChild("LockButton")
		local lockPrompt = lockButton and lockButton:FindFirstChild("LockPrompt")
		if lockPrompt then
			lockPrompt.Enabled = isMine and not locked
		end
		local folder = plot:FindFirstChild("Creatures")
		if folder then
			for _, part in ipairs(folder:GetChildren()) do
				local stealPrompt = part:FindFirstChild("StealPrompt")
				if stealPrompt then
					stealPrompt.Enabled = not isMine and not locked and plot:GetAttribute("OwnerUserId") ~= nil
				end
				local base = part:GetAttribute("BaseCFrame")
				if base then
					local phase = base.Position.X * 0.3 + base.Position.Z * 0.2
					part.CFrame = base * CFrame.new(0, math.sin(t * 2 + phase) * 0.4, 0) * CFrame.Angles(0, t + phase, 0)
					if part:GetAttribute("Rainbow") then
						part.Color = Color3.fromHSV((t * 0.3 + phase * 0.05) % 1, 0.7, 1)
					end
				end
			end
		end
	end
end)
