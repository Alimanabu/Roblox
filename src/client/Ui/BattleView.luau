-- Экран аура-баттла: раунды появляются по очереди, в конце — победа или поражение.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Creatures = require(Shared.Config.Creatures)
local Rarities = require(Shared.Config.Rarities)

local Theme = require(script.Parent.Theme)
local Viewport = require(script.Parent.Viewport)
local create = Theme.create
local C = Theme.Colors

local BattleView = {}
BattleView.__index = BattleView

local ROUND_DELAY = 1.3

function BattleView.new(screenGui, onSfx)
	local self = setmetatable({}, BattleView)
	self.onSfx = onSfx
	self.frame = create("Frame", {
		Name = "BattleView",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(600, 430),
		BackgroundColor3 = C.Background,
		Visible = false,
		ZIndex = 40,
		Parent = screenGui,
	}, { Theme.corner(20), Theme.stroke(C.Purple, 5), Theme.padding(12) })
	self.title = Theme.label({ Size = UDim2.new(1, 0, 0, 40), Text = "", TextColor3 = C.Gold, ZIndex = 41, Parent = self.frame })
	self.rows = create("Frame", {
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.new(1, 0, 0, 270),
		BackgroundTransparency = 1,
		ZIndex = 41,
		Parent = self.frame,
	}, { create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	self.result = Theme.label({ Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 322), Text = "", ZIndex = 41, Parent = self.frame })
	self.footer = Theme.label({ Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 368), Text = "", TextColor3 = C.Muted, ZIndex = 41, Parent = self.frame })
	Theme.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(40, 36),
		Text = "✕",
		Color = C.Bad,
		ZIndex = 42,
		Parent = self.frame,
	}, function()
		self.token += 1
		self.frame.Visible = false
	end)
	self.token = 0
	return self
end

local function side(parent, member, power, alignRight, won)
	local creature = member and Creatures.get(member.id)
	local holder = create("Frame", {
		Size = UDim2.new(0.42, 0, 1, 0),
		Position = alignRight and UDim2.fromScale(0.58, 0) or UDim2.fromScale(0, 0),
		BackgroundColor3 = won and Color3.fromRGB(40, 90, 50) or C.Card,
		ZIndex = 41,
		Parent = parent,
	}, { Theme.corner(10) })
	if not creature then
		Theme.label({ Size = UDim2.fromScale(1, 1), Text = "— пусто —", TextColor3 = C.Muted, ZIndex = 42, Parent = holder })
		return
	end
	local rarity = Rarities.get(creature.rarity)
	local preview = Viewport.creature({
		Size = UDim2.fromOffset(70, 70),
		Position = alignRight and UDim2.new(1, -72, 0, 6) or UDim2.fromOffset(2, 6),
		ZIndex = 42,
		Parent = holder,
	}, member.id, member.mut, false, member.skin)
	preview.ZIndex = 42
	Theme.label({
		Size = UDim2.new(1, -80, 0, 30),
		Position = alignRight and UDim2.fromOffset(6, 8) or UDim2.fromOffset(74, 8),
		Text = creature.name,
		TextColor3 = rarity.color,
		ZIndex = 42,
		Parent = holder,
	})
	Theme.label({
		Size = UDim2.new(1, -80, 0, 30),
		Position = alignRight and UDim2.fromOffset(6, 44) or UDim2.fromOffset(74, 44),
		Text = "✨ " .. power,
		TextColor3 = won and C.Good or C.Text,
		ZIndex = 42,
		Parent = holder,
	})
end

function BattleView:show(result)
	self.token += 1
	local token = self.token
	self.rows:ClearAllChildren()
	create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = self.rows })
	self.title.Text = "⚔️ Ты  vs  " .. result.opponentName
	self.result.Text = ""
	self.footer.Text = ""
	self.frame.Visible = true

	task.spawn(function()
		for index, round in ipairs(result.rounds) do
			task.wait(ROUND_DELAY)
			if self.token ~= token then
				return
			end
			local row = create("Frame", {
				Size = UDim2.new(1, 0, 0, 84),
				BackgroundTransparency = 1,
				LayoutOrder = index,
				ZIndex = 41,
				Parent = self.rows,
			})
			side(row, round.a, round.powerA, false, round.aWins)
			Theme.label({
				Size = UDim2.new(0.16, 0, 1, 0),
				Position = UDim2.fromScale(0.42, 0),
				Text = round.aWins and "◀ 🏆" or "🏆 ▶",
				TextColor3 = round.aWins and C.Good or C.Bad,
				ZIndex = 42,
				Parent = row,
			})
			side(row, round.b, round.powerB, true, not round.aWins)
			if self.onSfx then
				self.onSfx(round.aWins and "success" or "slap")
			end
		end
		task.wait(0.6)
		if self.token ~= token then
			return
		end
		self.result.Text = result.won and "🏆 ПОБЕДА! Твоя аура сильнее!" or "😢 Поражение... аура подкачать бы"
		self.result.TextColor3 = result.won and C.Good or C.Bad
		local footer = "Очки ауры: " .. result.points .. " • " .. result.rank
		if result.won and result.reward ~= "" then
			footer = "Награда: " .. result.reward .. "   " .. footer
		end
		self.footer.Text = footer
		if self.onSfx then
			self.onSfx(result.won and "levelup" or "lose")
		end
		task.wait(6)
		if self.token == token then
			self.frame.Visible = false
		end
	end)
end

return BattleView
