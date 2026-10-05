-- Цвета, шрифты и маленькие помощники для создания интерфейса кодом.

local Theme = {}

Theme.Font = Enum.Font.FredokaOne
Theme.Colors = {
	Background = Color3.fromRGB(28, 24, 48),
	Panel = Color3.fromRGB(44, 38, 74),
	Card = Color3.fromRGB(60, 52, 98),
	CardLocked = Color3.fromRGB(45, 42, 60),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(180, 175, 210),
	Accent = Color3.fromRGB(255, 80, 160),
	Coins = Color3.fromRGB(255, 220, 80),
	Good = Color3.fromRGB(90, 220, 110),
	Bad = Color3.fromRGB(235, 80, 90),
	Blue = Color3.fromRGB(70, 140, 255),
	Purple = Color3.fromRGB(150, 90, 255),
	Gold = Color3.fromRGB(255, 190, 40),
}

-- create("TextLabel", { Text = "hi" }, { children })
function Theme.create(className, props, children)
	local instance = Instance.new(className)
	for key, value in pairs(props or {}) do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = instance
	end
	if props and props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

local create = Theme.create

function Theme.corner(radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function Theme.stroke(color, thickness)
	return create("UIStroke", {
		Color = color or Color3.new(0, 0, 0),
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Theme.padding(px)
	local u = UDim.new(0, px)
	return create("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end

function Theme.label(props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = Theme.Font,
		TextColor3 = Theme.Colors.Text,
		TextScaled = true,
		RichText = true,
	}
	for key, value in pairs(props) do
		defaults[key] = value
	end
	local label = create("TextLabel", defaults)
	if not label:FindFirstChildOfClass("UIStroke") then
		create("UIStroke", { Thickness = 1.5, Transparency = 0.3, Parent = label })
	end
	return label
end

function Theme.button(props, onClick)
	local color = props.Color or Theme.Colors.Accent
	props.Color = nil
	local defaults = {
		BackgroundColor3 = color,
		Font = Theme.Font,
		TextColor3 = Theme.Colors.Text,
		TextScaled = true,
		AutoButtonColor = true,
		RichText = true,
	}
	for key, value in pairs(props) do
		defaults[key] = value
	end
	local button = create("TextButton", defaults, {
		Theme.corner(10),
		create("UIStroke", { Thickness = 2, Color = Color3.new(0, 0, 0), Transparency = 0.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		create("UITextSizeConstraint", { MaxTextSize = 28 }),
		create("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }),
	})
	if onClick then
		button.Activated:Connect(onClick)
	end
	return button
end

return Theme
