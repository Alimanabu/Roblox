-- Tutorial for newbies: steps in order.
-- action is the action that counts the step (see server/Services/Actions), count is how many times.
-- menu is which menu button to highlight.

local S = require(script.Parent.Parent.Strings)

local Tutorial = {}

Tutorial.Steps = {
	{ action = "craft", count = 1, menu = "Factory", reward = 100 },
	{ action = "craft", count = 4, menu = "Factory", reward = 200 },
	{ action = "upgrade", count = 1, menu = "Upgrades", reward = 300 },
	{ action = "lock", count = 1, highlightLock = true, reward = 300 },
	{ action = "daily", count = 1, menu = "Rewards", reward = 500 },
}

for index, step in ipairs(Tutorial.Steps) do
	S.fill(step, "tutorial." .. index, "text")
end

return Tutorial
