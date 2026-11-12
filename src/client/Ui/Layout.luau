-- Screen size rules: phone, tablet, PC. Pure functions, the tests call them with their own sizes.
-- The middle of the screen belongs to the game: the HUD stays in the edge strips (20 % on each side).
-- On touch screens everything a finger or an eye must work with is sized in points of the real screen
-- (Layout.PT), not in units of the UIScale: the scale of a phone is small, so units would shrink the buttons.

local Layout = {}

Layout.BASE = Vector2.new(1280, 760) -- the PC screen the HUD was drawn for
Layout.PHONE_SIDE = 500 -- a screen whose short side is below this is a phone
Layout.EDGE = 0.2 -- share of the screen on each side that the HUD may use
Layout.MENU_COLUMN = 145 -- PC: width of one menu column, without the gap
Layout.MENU_X = 10

-- Touch sizes in points of the real screen (after UIScale).
Layout.PT = {
	BUTTON = 46, -- ☰, 🎁, 👁, ⚙
	GAP = 6,
	ROW = 40, -- a row of the opened menu
	CLOSE = 36, -- the ✕ of a plate
	FONT = 12, -- the smallest text
	MENU_WIDTH = 150,
	MENU_FONT = 13,
	MIN_FIT = 10, -- the safety net (Hud.guardFit) never shrinks a text below this (lead's decision 13.11)
	TOP = 4, -- the top row: coins and level
	TOP_ROW = 54, -- its height: the level line in 2 lines of 12 pt and the XP bar under it
	LEFT = 8,
	ROBLOX_BAR = 108, -- the Roblox menu and chat buttons take the top left corner
	HINT = 18, -- the tutorial hint text (a newbie must read it at a glance, 10.11 feedback)
	HINT_STEP = 16, -- the tutorial progress dots
}
Layout.LINE = 1.2 -- line height as a share of the font size
-- Lines of the tutorial hint: the portrait strip under the coins is wide, the landscape column is narrow.
Layout.HINT_LINES = { portrait = 2, landscape = 5, pc = 2 }
Layout.HINT_PC = { WIDTH = 520, FONT = 22, STEP = 18, Y = 148 } -- PC: under the level, units of the UIScale

function Layout.isPhone(size)
	return math.min(size.X, size.Y) < Layout.PHONE_SIDE
end

function Layout.isPortrait(size)
	return size.Y > size.X
end

-- The scale of the old windows and panels. Never below 0.5 (the window must fit a phone width).
function Layout.scale(size)
	local fit = math.min(size.X / Layout.BASE.X, size.Y / Layout.BASE.Y)
	return math.clamp(fit, 0.5, 1.25)
end

function Layout.menuWidth(columns)
	return columns * Layout.MENU_COLUMN + (columns - 1) * 5
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
