-- Анимация «что выпало» после создания брейнрота.

local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local Formulas = require(Shared.Util.Formulas)
local Format = require(Shared.Util.Format)

local Theme = require(script.Parent.Theme)
local create = Theme.create
local C = Theme.Colors

local Reveal = {}
Reveal.__index = Reveal

function Reveal.new(screenGui)
	local self = setmetatable({}, Reveal)
	self.frame = create("Frame", {
		Name = "Reveal",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.78),
		Size = UDim2.fromOffset(420, 150),
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 0.1,
		Visible = false,
		ZIndex = 10,
		Parent = screenGui,
	}, { Theme.corner(18), Theme.padding(10) })
	self.stroke = Theme.stroke(C.Text, 4)
	self.stroke.Parent = self.frame
	self.scale = create("UIScale", { Scale = 1, Parent = self.frame })

	self.badge = Theme.label({ Size = UDim2.new(1, 0, 0, 24), Text = "", TextColor3 = C.Coins, ZIndex = 11, Parent = self.frame })
	self.name = Theme.label({ Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 24), Text = "", ZIndex = 11, Parent = self.frame })
	self.rarity = Theme.label({ Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 70), Text = "", ZIndex = 11, Parent = self.frame })
	self.income = Theme.label({ Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 102), Text = "", TextColor3 = C.Good, ZIndex = 11, Parent = self.frame })
	self.token = 0
	return self
end

function Reveal:show(result, state)
	local creature = Creatures.get(result.id)
	if not creature then
		return
	end
	local rarity = Rarities.get(creature.rarity)
	local mutation = Mutations.get(result.mut)
	local epic = rarity.rank >= 6 or mutation.rank >= 4

	self.token += 1
	local token = self.token

	local badges = {}
	if result.fused then
		table.insert(badges, "🧬 СКРЕЩИВАНИЕ")
	end
	if result.isNew then
		table.insert(badges, "✨ НОВЫЙ!")
	end
	if rarity.id == "sixseven" then
		table.insert(badges, "🤌 SIX... SEVEN!!! 🤌")
	end
	self.badge.Text = table.concat(badges, "   ")

	local name = creature.name
	if mutation.id ~= "normal" then
		name = string.format('<font color="#%s">%s</font> %s', mutation.color:ToHex(), mutation.name, name)
	end
	self.name.Text = name
	self.rarity.Text = rarity.name
	self.rarity.TextColor3 = rarity.color
	self.stroke.Color = rarity.color
	local multiplier = state and state.incomeMultiplier or 1
	self.income.Text = "+" .. Format.coins(Formulas.creatureBaseIncome(result) * multiplier) .. "/с"

	self.frame.Visible = true
	self.scale.Scale = 0.3
	TweenService:Create(self.scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = epic and 1.35 or 1,
	}):Play()

	if rarity.rainbow then
		task.spawn(function()
			while self.token == token and self.frame.Visible do
				local hue = (os.clock() * 0.6) % 1
				local color = Color3.fromHSV(hue, 0.8, 1)
				self.stroke.Color = color
				self.rarity.TextColor3 = color
				task.wait()
			end
		end)
	end

	task.delay(epic and 4 or 1.6, function()
		if self.token == token then
			self.frame.Visible = false
		end
	end)
end

return Reveal
