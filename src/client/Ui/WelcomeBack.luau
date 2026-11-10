-- "Welcome back" window: the player came back after a break and sees what the factory earned meanwhile
-- (IncomeService.giveOfflineIncome). The coins are already on the balance: nothing to claim, nothing to buy,
-- no timer. One tap anywhere closes it: the dimmed screen, the card or the button.
-- Sizes are in points of the real screen (n / UIScale), like the touch HUD (Ui/Layout).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local S = require(Shared.Strings)
local Format = require(Shared.Util.Format)

local Theme = require(script.Parent.Theme)
local create = Theme.create
local C = Theme.Colors

local WelcomeBack = {}
WelcomeBack.__index = WelcomeBack

-- Points: the card, the fonts and the button (a finger needs 44+).
WelcomeBack.PT = { WIDTH = 340, HEIGHT = 230, TITLE = 26, TEXT = 20, BUTTON_W = 200, BUTTON_H = 52, BUTTON_FONT = 22, MARGIN = 16 }

function WelcomeBack.new(screenGui)
	local self = setmetatable({}, WelcomeBack)
	local close = function()
		self:hide()
	end
	-- The whole screen is one button: a tap anywhere closes the window.
	self.frame = Theme.button({
		Name = "WelcomeBack",
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0, 0),
		Text = "",
		Color = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		AutoButtonColor = false,
		ZIndex = 50,
		Visible = false,
		Parent = screenGui,
	}, close)
	self.frame:FindFirstChildOfClass("UICorner"):Destroy()
	self.frame:FindFirstChildOfClass("UIStroke"):Destroy()
	self.card = Theme.button({
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Text = "",
		Color = C.Panel,
		AutoButtonColor = false,
		ZIndex = 51,
		Parent = self.frame,
	}, close)
	local stroke = self.card:FindFirstChildOfClass("UIStroke")
	stroke.Color, stroke.Thickness, stroke.Transparency = C.Gold, 4, 0
	self.title = Theme.label({
		Name = "Title",
		Text = S.t("welcome.title"),
		TextColor3 = C.Gold,
		TextScaled = false,
		ZIndex = 52,
		Parent = self.card,
	})
	self.text = Theme.label({
		Name = "Text",
		Text = "",
		TextScaled = false,
		TextWrapped = true,
		ZIndex = 52,
		Parent = self.card,
	})
	self.ok = Theme.button({
		Name = "Ok",
		AnchorPoint = Vector2.new(0.5, 1),
		Text = S.t("welcome.ok"),
		Color = C.Good,
		TextScaled = false,
		ZIndex = 52,
		Parent = self.card,
	}, close)
	self:applyLayout(Vector2.new(1280, 760), 1)
	return self
end

-- size: the screen in points, scale: the UIScale of the screen gui.
function WelcomeBack:applyLayout(size, scale)
	local u = 1 / scale
	local P = WelcomeBack.PT
	local width = math.min(P.WIDTH, size.X - 2 * P.MARGIN)
	self.card.Size = UDim2.fromOffset(width * u, P.HEIGHT * u)
	self.title.Position = UDim2.fromOffset(P.MARGIN * u, 14 * u)
	self.title.Size = UDim2.new(1, -2 * P.MARGIN * u, 0, 34 * u)
	self.title.TextSize = P.TITLE * u
	self.text.Position = UDim2.fromOffset(P.MARGIN * u, 54 * u)
	self.text.Size = UDim2.new(1, -2 * P.MARGIN * u, 0, 100 * u)
	self.text.TextSize = P.TEXT * u
	self.ok.Position = UDim2.new(0.5, 0, 1, -14 * u)
	self.ok.Size = UDim2.fromOffset(P.BUTTON_W * u, P.BUTTON_H * u)
	self.ok.TextSize = P.BUTTON_FONT * u
	local constraint = self.ok:FindFirstChildOfClass("UITextSizeConstraint")
	if constraint then
		constraint.MaxTextSize = P.BUTTON_FONT * u
	end
end

function WelcomeBack:show(coins)
	if type(coins) ~= "number" or coins <= 0 then
		return
	end
	self.text.Text = S.t("welcome.text", { coins = "+" .. Format.coins(coins) })
	self.frame.Visible = true
end

function WelcomeBack:hide()
	self.frame.Visible = false
end

return WelcomeBack
