-- Минимальные заглушки Roblox API для запуска shared-модулей вне Studio.
Color3 = {
	fromRGB = function(r, g, b)
		return { R = r / 255, G = g / 255, B = b / 255 }
	end,
}

local RandomClass = {}
RandomClass.__index = RandomClass
function RandomClass:NextNumber()
	return math.random()
end
function RandomClass:NextInteger(a, b)
	return math.random(a, b)
end
Random = {
	new = function(seed)
		if seed then
			math.randomseed(seed)
		end
		return setmetatable({}, RandomClass)
	end,
}

__defs = {}
local cache = {}

-- «Инстанс» модуля: script.Parent.Parent.Config.Rarities -> путь "Config/Rarities".
local function node(path)
	return setmetatable({ __path = path }, {
		__index = function(self, key)
			if key == "Parent" then
				local parent = string.match(self.__path, "^(.*)/[^/]+$") or ""
				return node(parent)
			end
			return node(self.__path == "" and key or (self.__path .. "/" .. key))
		end,
	})
end

function require(target)
	local path = target.__path
	if cache[path] == nil then
		local def = __defs[path]
		assert(def, "нет модуля " .. tostring(path))
		cache[path] = def(node(path))
	end
	return cache[path]
end

function shared_require(path)
	return require(node(path))
end
