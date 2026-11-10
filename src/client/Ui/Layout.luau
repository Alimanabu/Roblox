-- Screen size rules: phone, tablet, PC. Pure functions, the tests call them with their own sizes.
-- The middle of the screen belongs to the game: the HUD stays in the edge strips (20 % on each side).

local Layout = {}

Layout.BASE = Vector2.new(1280, 760) -- the PC screen the HUD was drawn for
Layout.PHONE_SIDE = 500 -- a screen whose short side is below this is a phone
Layout.EDGE = 0.2 -- share of the screen on each side that the HUD may use
Layout.MENU_COLUMN = 145 -- width of one menu column, without the gap
Layout.MENU_X = 10

function Layout.isPhone(size)
	return math.min(size.X, size.Y) < Layout.PHONE_SIDE
end

-- On a phone everything is a bit smaller than the plain fit, on PC it stays as before.
function Layout.scale(size)
	local fit = math.min(size.X / Layout.BASE.X, size.Y / Layout.BASE.Y)
	if Layout.isPhone(size) then
		fit *= 0.85
	end
	return math.clamp(fit, 0.4, 1.25)
end

function Layout.menuWidth(columns)
	return columns * Layout.MENU_COLUMN + (columns - 1) * 5
end

-- PC keeps the two columns. A touch screen gets two columns only if they stay in the left strip.
function Layout.menuColumns(size, touch)
	if not touch then
		return 2
	end
	local scale = Layout.scale(size)
	return if (Layout.MENU_X + Layout.menuWidth(2)) * scale <= size.X * Layout.EDGE then 2 else 1
end

-- The menu starts folded on touch screens (phone, tablet) and open on PC.
function Layout.menuOpenAtStart(touch)
	return not touch
end

function Layout.isTouch()
	local ok, input = pcall(function()
		return game:GetService("UserInputService")
	end)
	return ok and input ~= nil and input.TouchEnabled == true
end

return Layout
