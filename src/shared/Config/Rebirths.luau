-- Rebirths: reset coins, brainrots and upgrades,
-- but permanently give an income multiplier, luck and a cool title.
-- Player level and the brainrot Index are kept.

local S = require(script.Parent.Parent.Strings)

local Rebirths = {}

Rebirths.INCOME_BONUS = 0.5 -- +50% income per rebirth
Rebirths.LUCK_BONUS = 0.1 -- +10% luck per rebirth

Rebirths.TITLE_COUNT = 10 -- rebirth.1.title ... rebirth.10.title in Strings

function Rebirths.cost(rebirths)
	return math.floor(50000000 * 12 ^ rebirths)
end

function Rebirths.levelRequired(rebirths)
	return 20 + rebirths * 5
end

-- Message (see Strings): the client shows the title in the player's language.
function Rebirths.titleFor(rebirths)
	if rebirths <= 0 then
		return nil
	end
	return S.m("rebirth." .. math.min(rebirths, Rebirths.TITLE_COUNT) .. ".title")
end

return Rebirths
