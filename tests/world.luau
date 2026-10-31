-- Заглушка мира Roblox: настоящие сервер и клиент игры работают вместе в одном процессе.
-- Время виртуальное (World.advance), сеть мгновенная, но копирует таблицы, как настоящая.
-- Нужна там, где важен весь путь: от кнопки в окне до сервера и обратно на экран.

World = { errors = {}, texts = {}, sent = {}, locale = __LOCALE or "en-us", studio = true }

local clock = 0
local START_TIME = 1794312600 -- 2026-11-10, вне сезонов
local sleeping = {}
local sequence = 0

local realOs = os
os = setmetatable({
	clock = function()
		return clock
	end,
	time = function(date)
		if date then
			return realOs.time(date)
		end
		return START_TIME + math.floor(clock)
	end,
}, { __index = realOs })

local function resume(thread, ...)
	local ok, err = coroutine.resume(thread, ...)
	if not ok then
		local report = debug.traceback(thread, tostring(err))
		table.insert(World.errors, report)
		print("❌ ошибка в потоке: " .. report)
	end
end

local function sleep(seconds, thread, ...)
	sequence += 1
	table.insert(sleeping, { at = clock + (seconds or 0), order = sequence, thread = thread, args = table.pack(...) })
end

task = {}

function task.wait(seconds)
	sleep(math.max(seconds or 0, 1 / 60), coroutine.running())
	coroutine.yield()
	return seconds
end

function task.spawn(callback, ...)
	local thread = coroutine.create(callback)
	resume(thread, ...)
	return thread
end

function task.defer(callback, ...)
	sleep(0, coroutine.create(callback), ...)
end

function task.delay(seconds, callback, ...)
	sleep(seconds, coroutine.create(callback), ...)
end

function warn(...) end

local function wakeSleepers(untilTime)
	while true do
		local best, bestIndex
		for index, sleeper in ipairs(sleeping) do
			if sleeper.at <= untilTime and (not best or sleeper.at < best.at or (sleeper.at == best.at and sleeper.order < best.order)) then
				best, bestIndex = sleeper, index
			end
		end
		if not best then
			return
		end
		table.remove(sleeping, bestIndex)
		clock = math.max(clock, best.at)
		resume(best.thread, table.unpack(best.args, 1, best.args.n))
	end
end

function World.advance(seconds)
	local target = clock + seconds
	wakeSleepers(target)
	clock = target
end

function World.now()
	return clock
end

-- Сигналы ---------------------------------------------------------------------

local function newSignal()
	local signal = { listeners = {}, waiting = {} }
	function signal:Connect(callback)
		local connection = { Connected = true }
		table.insert(self.listeners, connection)
		connection.callback = callback
		function connection:Disconnect()
			connection.Connected = false
		end
		return connection
	end
	function signal:Once(callback)
		local connection
		connection = self:Connect(function(...)
			connection:Disconnect()
			callback(...)
		end)
		return connection
	end
	function signal:Wait()
		table.insert(self.waiting, coroutine.running())
		return coroutine.yield()
	end
	function signal:Fire(...)
		for _, connection in ipairs(table.clone(self.listeners)) do
			if connection.Connected then
				task.spawn(connection.callback, ...)
			end
		end
		local waiting = self.waiting
		self.waiting = {}
		for _, thread in ipairs(waiting) do
			resume(thread, ...)
		end
	end
	return signal
end

-- Простые типы ----------------------------------------------------------------

local Vec = {}
Vector3 = {}
function Vector3.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vec)
end
Vector3.zero = Vector3.new()
Vector3.one = Vector3.new(1, 1, 1)
Vec.__index = function(self, key)
	if key == "Magnitude" then
		return math.sqrt(self.X ^ 2 + self.Y ^ 2 + self.Z ^ 2)
	elseif key == "Unit" then
		local length = self.Magnitude
		return if length == 0 then Vector3.zero else self / length
	end
	return Vec[key]
end
Vec.__add = function(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
Vec.__sub = function(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
Vec.__mul = function(a, b)
	if type(a) == "number" then
		a, b = b, a
	end
	return if type(b) == "number" then Vector3.new(a.X * b, a.Y * b, a.Z * b) else Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
Vec.__div = function(a, b)
	return Vector3.new(a.X / b, a.Y / b, a.Z / b)
end
Vec.__unm = function(a)
	return Vector3.new(-a.X, -a.Y, -a.Z)
end
function Vec:Dot(other)
	return self.X * other.X + self.Y * other.Y + self.Z * other.Z
end
function Vec:Lerp(other, alpha)
	return self + (other - self) * alpha
end
function Vec:Cross(o)
	return Vector3.new(self.Y * o.Z - self.Z * o.Y, self.Z * o.X - self.X * o.Z, self.X * o.Y - self.Y * o.X)
end

Vector2 = {
	new = function(x, y)
		return { X = x or 0, Y = y or 0 }
	end,
}
Vector2.zero = Vector2.new()

local CF = {}
CFrame = {}
local function cframe(position, right, up, back)
	return setmetatable({ Position = position, right = right, up = up, back = back }, CF)
end
local X, Y, Z = Vector3.new(1, 0, 0), Vector3.new(0, 1, 0), Vector3.new(0, 0, 1)
function CFrame.new(x, y, z)
	if type(x) == "table" then
		return cframe(x, X, Y, Z)
	end
	return cframe(Vector3.new(x, y, z), X, Y, Z)
end
CFrame.identity = CFrame.new()
function CFrame.lookAt(at, target)
	local back = (at - target).Unit
	local right = Y:Cross(back).Unit
	return cframe(at, right, back:Cross(right), back)
end
function CFrame.Angles(x, y, z)
	local cy, sy = math.cos(y), math.sin(y)
	-- Для заглушки хватает поворота вокруг вертикали: наклоны на расчёты не влияют.
	return cframe(Vector3.zero, Vector3.new(cy, 0, -sy), Y, Vector3.new(sy, 0, cy))
end
CF.__index = function(self, key)
	if key == "X" or key == "Y" or key == "Z" then
		return self.Position[key]
	elseif key == "LookVector" then
		return -self.back
	elseif key == "RightVector" then
		return self.right
	elseif key == "UpVector" then
		return self.up
	end
	return CF[key]
end
function CF:VectorToWorld(v)
	return self.right * v.X + self.up * v.Y + self.back * v.Z
end
CF.__mul = function(a, b)
	if getmetatable(b) == Vec then
		return a.Position + a:VectorToWorld(b)
	end
	return cframe(a.Position + a:VectorToWorld(b.Position), a:VectorToWorld(b.right), a:VectorToWorld(b.up), a:VectorToWorld(b.back))
end
function CF:Inverse()
	local r, u, b = self.right, self.up, self.back
	local right, up, back = Vector3.new(r.X, u.X, b.X), Vector3.new(r.Y, u.Y, b.Y), Vector3.new(r.Z, u.Z, b.Z)
	local p = self.Position
	return cframe(-Vector3.new(r:Dot(p), u:Dot(p), b:Dot(p)), right, up, back)
end
function CF:PointToObjectSpace(point)
	return self:Inverse() * point
end

local Col = {}
Col.__index = Col
Color3 = {}
function Color3.new(r, g, b)
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, Col)
end
function Color3.fromRGB(r, g, b)
	return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
end
function Color3.fromHSV()
	return Color3.new(1, 1, 1)
end
function Col:ToHex()
	return string.format("%02x%02x%02x", self.R * 255, self.G * 255, self.B * 255)
end
function Col:Lerp(other, alpha)
	return Color3.new(self.R + (other.R - self.R) * alpha, self.G + (other.G - self.G) * alpha, self.B + (other.B - self.B) * alpha)
end
function Col:ToHSV()
	return 0, 0, 1
end

local function plain(name)
	return {
		new = function(...)
			return { __type = name, args = { ... } }
		end,
	}
end
UDim = plain("UDim")
TweenInfo = plain("TweenInfo")
NumberRange = plain("NumberRange")
NumberSequence = plain("NumberSequence")
ColorSequence = plain("ColorSequence")
UDim2 = plain("UDim2")
UDim2.fromOffset = UDim2.new
UDim2.fromScale = UDim2.new

local function enumGroup(group)
	return setmetatable({}, {
		__index = function(self, key)
			local item = { Name = key, EnumType = group }
			rawset(self, key, item)
			return item
		end,
	})
end
Enum = setmetatable({}, {
	__index = function(self, key)
		local group = enumGroup(key)
		rawset(self, key, group)
		return group
	end,
})

-- Инстансы ----------------------------------------------------------------------

local Inst = {}
local Meta = {}
local PARTS = { Part = true, WedgePart = true, MeshPart = true, TrussPart = true, CornerWedgePart = true, SpawnLocation = true, Seat = true }
local EVENTS = {
	Activated = true, MouseButton1Click = true, MouseEnter = true, MouseLeave = true, FocusLost = true, Died = true, Ended = true,
	Completed = true, Triggered = true, ChildAdded = true, ChildRemoved = true, DescendantAdded = true, AncestryChanged = true,
	AttributeChanged = true, CharacterAdded = true, CharacterRemoving = true, OnClientEvent = true, OnServerEvent = true, Event = true,
}
local TEXT_FIELDS = { Text = true, PlaceholderText = true, ActionText = true, ObjectText = true, ToolTip = true }
local tagged = {}
local tagSignals = {}

local function raw(self)
	return rawget(self, "__state")
end

function Instance_new(class, name)
	local state = { props = { ClassName = class, Name = name or class }, children = {}, attrs = {}, signals = {}, tags = {} }
	local self = setmetatable({ __state = state }, Meta)
	if class == "Humanoid" then
		state.props.Health, state.props.MaxHealth, state.props.WalkSpeed = 100, 100, 16
	end
	return self
end
Instance = { new = Instance_new }

local function signalOf(self, key)
	local state = raw(self)
	state.signals[key] = state.signals[key] or newSignal()
	return state.signals[key]
end

Meta.__index = function(self, key)
	local state = raw(self)
	local value = state.props[key]
	if value ~= nil then
		return value
	end
	if Inst[key] then
		return Inst[key]
	end
	if EVENTS[key] then
		return signalOf(self, key)
	end
	for _, child in ipairs(state.children) do
		if child.Name == key then
			return child
		end
	end
	if PARTS[state.props.ClassName] then
		if key == "CFrame" then
			return CFrame.identity
		elseif key == "Position" then
			return self.CFrame.Position
		elseif key == "Size" then
			return Vector3.new(4, 1, 2)
		end
	end
	return nil
end

Meta.__newindex = function(self, key, value)
	local state = raw(self)
	if key == "Parent" then
		local old = state.props.Parent
		if old then
			local list = raw(old).children
			local index = table.find(list, self)
			if index then
				table.remove(list, index)
			end
			signalOf(old, "ChildRemoved"):Fire(self)
		end
		state.props.Parent = value
		if value then
			table.insert(raw(value).children, self)
			signalOf(value, "ChildAdded"):Fire(self)
		end
		signalOf(self, "AncestryChanged"):Fire(self, value)
		return
	end
	if key == "Position" and PARTS[state.props.ClassName] then
		key, value = "CFrame", CFrame.new(value)
	end
	state.props[key] = value
	if TEXT_FIELDS[key] and type(value) == "string" and value ~= "" then
		World.texts[value] = true
	end
	local waiters = state.signals["prop:" .. key]
	if waiters then
		waiters:Fire()
	end
end

function Inst:IsA(class)
	local own = self.ClassName
	return own == class or (class == "BasePart" and PARTS[own] == true) or (class == "PVInstance" and own == "Model")
end
function Inst:GetChildren()
	return table.clone(raw(self).children)
end
function Inst:GetDescendants()
	local out = {}
	for _, child in ipairs(raw(self).children) do
		table.insert(out, child)
		for _, inner in ipairs(child:GetDescendants()) do
			table.insert(out, inner)
		end
	end
	return out
end
function Inst:FindFirstChild(name, recursive)
	local list = if recursive then self:GetDescendants() else raw(self).children
	for _, child in ipairs(list) do
		if child.Name == name then
			return child
		end
	end
	return nil
end
function Inst:FindFirstChildOfClass(class)
	for _, child in ipairs(raw(self).children) do
		if child.ClassName == class then
			return child
		end
	end
	return nil
end
function Inst:WaitForChild(name, timeout)
	local waited = 0
	while true do
		local child = self:FindFirstChild(name)
		if child then
			return child
		end
		if waited >= (timeout or 30) then
			if timeout then
				return nil
			end
			error("WaitForChild: нет " .. name .. " в " .. self.Name)
		end
		task.wait(0.05)
		waited += 0.05
	end
end
function Inst:FindFirstAncestor(name)
	local parent = self.Parent
	while parent do
		if parent.Name == name then
			return parent
		end
		parent = parent.Parent
	end
	return nil
end
function Inst:FindFirstAncestorWhichIsA(class)
	local parent = self.Parent
	while parent do
		if parent:IsA(class) then
			return parent
		end
		parent = parent.Parent
	end
	return nil
end
function Inst:IsDescendantOf(ancestor)
	local parent = self.Parent
	while parent do
		if parent == ancestor then
			return true
		end
		parent = parent.Parent
	end
	return false
end
function Inst:Destroy()
	self.Parent = nil
	raw(self).destroyed = true
end
function Inst:ClearAllChildren()
	for _, child in ipairs(self:GetChildren()) do
		child:Destroy()
	end
end
function Inst:Clone()
	local state = raw(self)
	local copy = Instance_new(state.props.ClassName)
	for key, value in pairs(state.props) do
		if key ~= "Parent" then
			raw(copy).props[key] = value
		end
	end
	raw(copy).attrs = table.clone(state.attrs)
	for tag in pairs(state.tags) do
		game:GetService("CollectionService"):AddTag(copy, tag)
	end
	for _, child in ipairs(state.children) do
		child:Clone().Parent = copy
	end
	return copy
end
function Inst:SetAttribute(name, value)
	raw(self).attrs[name] = value
	signalOf(self, "AttributeChanged"):Fire(name)
	local changed = raw(self).signals["attr:" .. name]
	if changed then
		changed:Fire()
	end
end
function Inst:GetAttribute(name)
	return raw(self).attrs[name]
end
function Inst:GetAttributes()
	return table.clone(raw(self).attrs)
end
function Inst:GetAttributeChangedSignal(name)
	return signalOf(self, "attr:" .. name)
end
function Inst:GetPropertyChangedSignal(name)
	return signalOf(self, "prop:" .. name)
end
function Inst:Play() end
function Inst:Stop() end
function Inst:Pause() end
function Inst:Resume() end
function Inst:CaptureFocus() end
function Inst:ChangeState() end
function Inst:ScaleTo() end
function Inst:GetExtentsSize()
	return Vector3.new(4, 4, 4)
end
function Inst:GetBoundingBox()
	return self:GetPivot(), Vector3.new(4, 4, 4)
end
function Inst:GetPivot()
	if PARTS[self.ClassName] then
		return self.CFrame
	end
	local primary = self.PrimaryPart
	return if primary then primary.CFrame else (raw(self).pivot or CFrame.identity)
end
function Inst:PivotTo(target)
	World.pivots = (World.pivots or 0) + 1
	local from = self:GetPivot()
	if PARTS[self.ClassName] then
		self.CFrame = target
		return
	end
	raw(self).pivot = target
	local shift = target * from:Inverse()
	for _, part in ipairs(self:GetDescendants()) do
		if PARTS[part.ClassName] then
			part.CFrame = shift * part.CFrame
		end
	end
end

-- Сеть: копия вместо ссылки, метатаблицы теряются, как при настоящей передаче.
local function wire(value)
	if type(value) ~= "table" or getmetatable(value) == Meta then
		return value
	end
	local copy = {}
	for key, item in pairs(value) do
		copy[key] = wire(item)
	end
	return setmetatable(copy, getmetatable(value))
end

local function deliver(self, player, ...)
	table.insert(World.sent, { remote = self.Name, player = player, args = wire({ ... }) })
	if player == World.localPlayer then
		signalOf(self, "OnClientEvent"):Fire(table.unpack(wire({ ... })))
	end
end
function Inst:FireClient(player, ...)
	deliver(self, player, ...)
end
function Inst:FireAllClients(...)
	for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
		deliver(self, player, ...)
	end
end
function Inst:FireServer(...)
	signalOf(self, "OnServerEvent"):Fire(World.localPlayer, table.unpack(wire({ ... })))
end
function Inst:Fire(...)
	signalOf(self, "Event"):Fire(...)
end
function Inst:Kick(message)
	World.kicked = World.kicked or {}
	World.kicked[self] = message
end
function Inst:IsFriendsWith()
	return false
end
function Inst:IsInGroup()
	return false
end

-- Сервисы -------------------------------------------------------------------------

local memoryStores = {}
local function memoryStore(name)
	memoryStores[name] = memoryStores[name] or { data = {} }
	local store = memoryStores[name]
	function store:UpdateAsync(key, transform)
		local result = transform(wire(self.data[key]))
		if result ~= nil then
			self.data[key] = wire(result)
		end
		return result
	end
	function store:SetAsync(key, value)
		self.data[key] = value
	end
	function store:GetSortedAsync()
		return {
			GetCurrentPage = function()
				return {}
			end,
		}
	end
	return store
end

local function canonical(value)
	if type(value) ~= "table" then
		return string.format("%q", tostring(value))
	end
	local keys = {}
	for key in pairs(value) do
		table.insert(keys, tostring(key))
	end
	table.sort(keys)
	local parts = {}
	for _, key in ipairs(keys) do
		table.insert(parts, key .. "=" .. canonical(value[key] == nil and value[tonumber(key)] or value[key]))
	end
	return "{" .. table.concat(parts, ",") .. "}"
end
local jsonStore = {}

local function service(class, extra)
	local object = Instance_new(class)
	for key, value in pairs(extra or {}) do
		rawget(object, "__state").props[key] = value
	end
	return object
end

local noop = function() end
local players = service("Players", { PlayerAdded = newSignal(), PlayerRemoving = newSignal() })
function Inst:GetPlayers()
	return self:GetChildren()
end
function Inst:GetPlayerByUserId(userId)
	for _, player in ipairs(self:GetChildren()) do
		if player.UserId == userId then
			return player
		end
	end
	return nil
end
function Inst:GetNameFromUserIdAsync(userId)
	return "#" .. userId
end

local runService = service("RunService", {
	RenderStepped = newSignal(),
	Heartbeat = newSignal(),
	IsStudio = function()
		return World.studio
	end,
	IsServer = function()
		return true
	end,
	IsClient = function()
		return true
	end,
})

local services = {
	Players = players,
	RunService = runService,
	ReplicatedStorage = service("ReplicatedStorage"),
	Lighting = service("Lighting"),
	SoundService = service("SoundService"),
	StarterPack = service("StarterPack"),
	ProximityPromptService = service("ProximityPromptService", { PromptTriggered = newSignal(), PromptButtonHoldBegan = newSignal(), PromptButtonHoldEnded = newSignal() }),
	Debris = service("Debris", { AddItem = noop }),
	BadgeService = service("BadgeService", { AwardBadge = noop }),
	TweenService = service("TweenService", {
		Create = function(_, instance, _, goal)
			local tween = Instance_new("Tween")
			rawget(tween, "__state").props.Play = function()
				for key, value in pairs(goal) do
					instance[key] = value
				end
				task.defer(function()
					tween.Completed:Fire()
				end)
			end
			return tween
		end,
	}),
	HttpService = service("HttpService", {
		JSONEncode = function(_, value)
			local text = canonical(value)
			jsonStore[text] = wire(value)
			return text
		end,
		JSONDecode = function(_, text)
			return wire(jsonStore[text])
		end,
	}),
	CollectionService = service("CollectionService", {
		AddTag = function(_, instance, tag)
			rawget(instance, "__state").tags[tag] = true
			tagged[tag] = tagged[tag] or {}
			table.insert(tagged[tag], instance)
			if tagSignals[tag] then
				tagSignals[tag]:Fire(instance)
			end
		end,
		GetTagged = function(_, tag)
			return table.clone(tagged[tag] or {})
		end,
		GetInstanceAddedSignal = function(_, tag)
			tagSignals[tag] = tagSignals[tag] or newSignal()
			return tagSignals[tag]
		end,
	}),
	DataStoreService = service("DataStoreService", {
		GetDataStore = function(_, name)
			if World.noStore then
				error("DataStore недоступен")
			end
			return memoryStore(name)
		end,
		GetOrderedDataStore = function(_, name)
			return memoryStore(name)
		end,
	}),
	MarketplaceService = service("MarketplaceService", {
		PromptGamePassPurchaseFinished = newSignal(),
		PromptGamePassPurchase = noop,
		PromptProductPurchase = noop,
		UserOwnsGamePassAsync = function()
			return false
		end,
	}),
	PolicyService = service("PolicyService", {
		GetPolicyInfoForPlayerAsync = function()
			return { ArePaidRandomItemsRestricted = false, IsPaidItemTradingAllowed = true }
		end,
	}),
	TextService = service("TextService", {
		FilterStringAsync = function(_, text)
			return {
				GetNonChatStringForBroadcastAsync = function()
					return text
				end,
			}
		end,
	}),
	LocalizationService = service("LocalizationService"),
	AnalyticsService = setmetatable({}, {
		__index = function()
			return noop
		end,
	}),
}

World.services = services

local translations = Instance_new("LocalizationTable", "Translations")
rawget(translations, "__state").props.GetEntries = function()
	return __translationEntries or {}
end
translations.Parent = services.LocalizationService

workspace = service("Workspace", {
	GetServerTimeNow = function()
		return START_TIME + clock
	end,
})
local camera = Instance_new("Camera", "Camera")
camera.CFrame = CFrame.identity
camera.ViewportSize = Vector2.new(1280, 760)
camera.Parent = workspace
rawget(workspace, "__state").props.CurrentCamera = camera

game = {
	JobId = "world",
	BindToClose = noop,
	GetService = function(_, name)
		return assert(services[name], "нет заглушки сервиса " .. name)
	end,
}
services.ReplicatedStorage.__shared = nil
rawget(services.ReplicatedStorage, "__state").props.WaitForChild = function(self, name, timeout)
	if name == "Shared" then
		return node("")
	end
	return Inst.WaitForChild(self, name, timeout)
end

-- Игроки и запуск -----------------------------------------------------------------

function World.addPlayer(userId, name)
	local player = Instance_new("Player", name)
	local props = rawget(player, "__state").props
	props.UserId, props.DisplayName, props.LocaleId = userId, name, World.locale
	local function part(partName, parent)
		local item = Instance_new("Part", partName)
		item.Parent = parent
		return item
	end
	local gui = Instance_new("PlayerGui", "PlayerGui")
	gui.Parent = player
	local backpack = Instance_new("Backpack", "Backpack")
	backpack.Parent = player
	local character = Instance_new("Model", name)
	local root = part("HumanoidRootPart", character)
	part("Head", character)
	character.PrimaryPart = root
	local humanoid = Instance_new("Humanoid", "Humanoid")
	humanoid.Parent = character
	character.Parent = workspace
	if not World.localPlayer then
		World.localPlayer = player
		rawget(players, "__state").props.LocalPlayer = player
	end
	player.Parent = players
	players.PlayerAdded:Fire(player)
	props.Character = character
	player.CharacterAdded:Fire(character)
	return player
end

function World.removePlayer(player)
	player.Parent = nil
	players.PlayerRemoving:Fire(player)
end

function World.startServer()
	shared_require("Main")
end

function World.startClient()
	task.spawn(shared_require, "client/Main")
end

-- Один кадр клиента: RenderStepped видит тот же виртуальный час.
function World.frame()
	World.advance(1 / 60)
	runService.RenderStepped:Fire(1 / 60)
end

function World.buttons(root)
	local out = {}
	for _, item in ipairs(root:GetDescendants()) do
		if item.ClassName == "TextButton" or item.ClassName == "ImageButton" then
			table.insert(out, item)
		end
	end
	return out
end

function World.find(root, text)
	for _, item in ipairs(World.buttons(root)) do
		if item.Text == text then
			return item
		end
	end
	return nil
end

function World.click(button)
	button.Activated:Fire()
end

function World.prompt(prompt, player, holdSeconds)
	local serviceObject = services.ProximityPromptService
	serviceObject.PromptButtonHoldBegan:Fire(prompt, player)
	World.advance(holdSeconds or 0)
	serviceObject.PromptTriggered:Fire(prompt, player)
end
