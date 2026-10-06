-- Окно «Как назовёшь брейнрота?».

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.Theme)
local create = Theme.create
local C = Theme.Colors

local RenameDialog = {}
RenameDialog.__index = RenameDialog

function RenameDialog.new(screenGui)
	local self = setmetatable({}, RenameDialog)
	self.frame = create("Frame", {
		Name = "RenameDialog",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(420, 190),
		BackgroundColor3 = C.Panel,
		Visible = false,
		ZIndex = 50,
		Parent = screenGui,
	}, { Theme.corner(16), Theme.stroke(C.Gold, 4), Theme.padding(12) })
	self.title = Theme.label({ Size = UDim2.new(1, 0, 0, 32), Text = "✏️ Как назовёшь брейнрота?", TextColor3 = C.Gold, ZIndex = 51, Parent = self.frame })
	self.box = create("TextBox", {
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundColor3 = C.Card,
		PlaceholderText = "Например: Вася 🤌 (до 20 символов)",
		PlaceholderColor3 = C.Muted,
		Text = "",
		Font = Theme.Font,
		TextScaled = true,
		TextColor3 = C.Text,
		ClearTextOnFocus = false,
		ZIndex = 51,
		Parent = self.frame,
	}, { Theme.corner(10), Theme.padding(8) })
	Theme.button({
		Position = UDim2.new(0, 0, 1, -48),
		Size = UDim2.new(0.5, -6, 0, 48),
		Text = "✅ Готово",
		Color = C.Good,
		ZIndex = 51,
		Parent = self.frame,
	}, function()
		if self.uid then
			Remotes.RenameCreature:FireServer(self.uid, self.box.Text)
		end
		self:hide()
	end)
	Theme.button({
		Position = UDim2.new(0.5, 6, 1, -48),
		Size = UDim2.new(0.5, -6, 0, 48),
		Text = "Отмена",
		Color = C.Bad,
		ZIndex = 51,
		Parent = self.frame,
	}, function()
		self:hide()
	end)
	return self
end

function RenameDialog:show(uid, currentName)
	self.uid = uid
	self.box.Text = currentName or ""
	self.frame.Visible = true
	self.box:CaptureFocus()
end

function RenameDialog:hide()
	self.uid = nil
	self.frame.Visible = false
end

return RenameDialog
