-- Colors, fonts and small helpers for building the UI in code.

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

-- ✕ in the corner of a plate: hides the plate. The flag is tied to the reason the plate is shown:
-- Theme.show(frame, visible, key) clears it when the reason is gone (visible = false) or changed (another key:
-- the next tutorial step, the lock turning from open to closed). The eye clears all of them (Theme.reopenAll).
Theme.CLOSE = 36 -- on PC, in screen units; on touch screens Hud sizes it in points (Layout.PT.CLOSE)
-- The ✕ stands 4 units from the right edge: a text next to it ends at least 2 units before it
-- (width -Theme.CLOSE - 6 - its left offset; tests/layout.spec.luau checks every plate).
Theme.closables = {}

function Theme.closable(frame)
	local button = Theme.button({
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -4, 0.5, 0),
		Size = UDim2.fromOffset(Theme.CLOSE, Theme.CLOSE),
		Text = "✕",
		Color = Theme.Colors.Bad,
		ZIndex = (frame.ZIndex or 1) + 4,
		Parent = frame,
	}, function()
		frame:SetAttribute("Closed", true)
		frame:SetAttribute("ClosedKey", frame:GetAttribute("ShownKey"))
		frame.Visible = false
	end)
	table.insert(Theme.closables, frame)
	return button
end

function Theme.show(frame, visible, key)
	local closed = frame:GetAttribute("Closed") == true
	if closed and (not visible or frame:GetAttribute("ClosedKey") ~= key) then
		frame:SetAttribute("Closed", nil)
		frame:SetAttribute("ClosedKey", nil)
		closed = false
	end
	frame:SetAttribute("ShownKey", if visible then key else nil)
	frame:SetAttribute("Wanted", visible == true)
	frame.Visible = visible and not closed and frame:GetAttribute("Quiet") ~= true
end

-- "Quiet": the plate steps aside for a while (the tutorial hint leads, Hud:placeSide) without losing its reason
-- to be shown or its ✕ flag; when the quiet ends it comes back exactly as Theme.show left it.
function Theme.quiet(frame, on)
	frame:SetAttribute("Quiet", if on then true else nil)
	local wanted = frame:GetAttribute("Wanted")
	if on then
		frame.Visible = false
	elseif wanted ~= nil then
		frame.Visible = wanted and frame:GetAttribute("Closed") ~= true
	end
end

function Theme.reopenAll()
	for _, frame in ipairs(Theme.closables) do
		frame:SetAttribute("Closed", nil)
		frame:SetAttribute("ClosedKey", nil)
	end
end

return Theme
