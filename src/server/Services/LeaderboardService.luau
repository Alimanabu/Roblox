-- Таблицы лидеров: leaderstats в списке игроков и глобальные табло на площади.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Formulas = require(Shared.Util.Formulas)
local Format = require(Shared.Util.Format)

local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)

local LeaderboardService = {}

local WRITE_INTERVAL = 120
local READ_INTERVAL = 300
local TOP_COUNT = 10

-- OrderedDataStore хранит только целые числа до 2^63, а заработок может быть огромным.
-- Поэтому храним логарифм: 1 000 000 * log10(x + 1). Точности хватает для сортировки.
local function encode(value)
	return math.floor(math.log10(math.max(0, value) + 1) * 1000000)
end

local function decode(stored)
	return 10 ^ (stored / 1000000) - 1
end

local BOARDS = {
	{
		key = "TopEarned_v1",
		title = "💰 Топ по заработку",
		position = Vector3.new(-26, 13, 0),
		value = function(data)
			return encode(data.totalEarned)
		end,
		format = function(stored)
			return Format.coins(decode(stored))
		end,
	},
	{
		key = "TopRebirths_v1",
		title = "♻️ Топ по перерождениям",
		position = Vector3.new(26, 13, 0),
		value = function(data)
			return data.rebirths
		end,
		format = function(stored)
			return tostring(stored)
		end,
	},
}

local nameCache = {}
local function nameOf(userId)
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	nameCache[userId] = ok and name or ("Игрок " .. userId)
	return nameCache[userId]
end

local function buildBoard(board)
	local part = Instance.new("Part")
	part.Name = "Leaderboard_" .. board.key
	part.Anchored = true
	part.Size = Vector3.new(20, 24, 1)
	part.CFrame = CFrame.lookAt(board.position, Vector3.new(0, board.position.Y, 0))
	part.Color = Color3.fromRGB(28, 24, 48)
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = workspace

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(500, 600)
	gui.LightInfluence = 0
	gui.Parent = part

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 70)
	title.BackgroundColor3 = Color3.fromRGB(255, 80, 160)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Text = board.title
	title.Parent = gui

	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Position = UDim2.fromOffset(16, 80)
	list.Size = UDim2.new(1, -32, 1, -90)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.FredokaOne
	list.TextSize = 34
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextColor3 = Color3.new(1, 1, 1)
	list.RichText = true
	list.Text = "Загрузка..."
	list.Parent = gui

	board.label = list
end

local MEDALS = { "🥇", "🥈", "🥉" }

local function refreshBoard(board)
	if not board.store then
		board.label.Text = "Табло работает\nв опубликованной игре"
		return
	end
	local ok, pages = pcall(function()
		return board.store:GetSortedAsync(false, TOP_COUNT)
	end)
	if not ok then
		if board.label.Text == "Загрузка..." then
			board.label.Text = "Табло работает\nв опубликованной игре"
		end
		return
	end
	local lines = {}
	for rank, entry in ipairs(pages:GetCurrentPage()) do
		local userId = tonumber(string.match(entry.key, "%d+"))
		local name = userId and nameOf(userId) or "?"
		table.insert(lines, string.format(
			'%s %s  <font color="#ffdc50">%s</font>',
			MEDALS[rank] or (rank .. "."),
			name,
			board.format(entry.value)
		))
	end
	board.label.Text = #lines > 0 and table.concat(lines, "\n") or "Пока пусто. Стань первым!"
end

local function writeScores()
	for _, player in ipairs(Players:GetPlayers()) do
		local data = DataService.get(player)
		if data then
			for _, board in ipairs(BOARDS) do
				if board.store then
					pcall(function()
						board.store:SetAsync("u" .. player.UserId, board.value(data))
					end)
				end
			end
		end
	end
end

local function setupLeaderstats(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local income = Instance.new("StringValue")
	income.Name = "Доход/с"
	income.Value = "$0"
	income.Parent = stats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Перерожд."
	rebirths.Parent = stats
	stats.Parent = player
end

function LeaderboardService.init()
	for _, board in ipairs(BOARDS) do
		pcall(function()
			board.store = DataStoreService:GetOrderedDataStore(board.key)
		end)
		buildBoard(board)
	end

	Players.PlayerAdded:Connect(setupLeaderstats)
	for _, player in ipairs(Players:GetPlayers()) do
		setupLeaderstats(player)
	end

	-- leaderstats обновляем часто.
	task.spawn(function()
		while true do
			task.wait(2)
			for _, player in ipairs(Players:GetPlayers()) do
				local data = DataService.get(player)
				local stats = player:FindFirstChild("leaderstats")
				if data and stats then
					local income = Formulas.totalIncome(data, MonetizationService.passes(player))
					stats["Доход/с"].Value = Format.coins(income)
					stats["Перерожд."].Value = data.rebirths
				end
			end
		end
	end)

	-- Глобальные табло — редко, у DataStore есть лимиты.
	task.spawn(function()
		task.wait(10)
		for _, board in ipairs(BOARDS) do
			refreshBoard(board)
		end
		local sinceRead = 0
		while true do
			task.wait(WRITE_INTERVAL)
			writeScores()
			sinceRead += WRITE_INTERVAL
			if sinceRead >= READ_INTERVAL then
				sinceRead = 0
				for _, board in ipairs(BOARDS) do
					refreshBoard(board)
				end
			end
		end
	end)

	-- При выходе записываем результат, чтобы не потерять последний рывок.
	Players.PlayerRemoving:Connect(function(player)
		local data = DataService.get(player)
		if not data then
			return
		end
		for _, board in ipairs(BOARDS) do
			if board.store then
				task.spawn(pcall, function()
					board.store:SetAsync("u" .. player.UserId, board.value(data))
				end)
			end
		end
	end)
end

return LeaderboardService
