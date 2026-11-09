-- World labels (signs, hints, tools) are created by the server in English, with a message
-- placed next to them (Strings.apply). Here the client shows them in the player's language.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local S = require(Shared.Strings)

local WorldText = {}

local function show(instance, attribute)
	local property = string.match(attribute, "^" .. S.ATTRIBUTE_PREFIX .. "(.+)$")
	local encoded = property and instance:GetAttribute(attribute)
	if encoded then
		instance[property] = S.text(HttpService:JSONDecode(encoded)[1])
	end
end

local function watch(instance)
	for attribute in pairs(instance:GetAttributes()) do
		show(instance, attribute)
	end
	instance.AttributeChanged:Connect(function(attribute)
		show(instance, attribute)
	end)
end

function WorldText.start()
	if S.language == "en" then
		return
	end
	CollectionService:GetInstanceAddedSignal(S.TAG):Connect(watch)
	for _, instance in ipairs(CollectionService:GetTagged(S.TAG)) do
		watch(instance)
	end
end

return WorldText
