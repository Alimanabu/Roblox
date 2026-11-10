-- Экран на телефоне, планшете и ПК (отзыв игрока 10.11: «середину не вижу, не поняла, как играть»).
-- 1. Раскладка: место каждой видимой плашки считается по Position/Size/AnchorPoint, UIScale и спискам,
--    центральные 60 % экрана (20 % от каждого края) свободны; на ПК меню открыто, как раньше.
-- 2. Крестик закрывает каждую плашку, ☰ открывает и закрывает меню, глаз прячет всё, кроме себя.
-- 3. Обучение: на каждом шаге ровно одна цель, после действия цель переходит дальше, 5 шагов.
-- __LAYOUT_DUMP = true: печатает прямоугольники (RECT|...) для картинок до/после и только меряет.

local failures = 0
local function check(cond, msg)
	if not cond then
		failures += 1
		print("❌ " .. msg)
	end
end

local DUMP_ONLY = __LAYOUT_DUMP == true
local SCREENS = {
	{ id = "телефон_портрет", size = Vector2.new(390, 844), touch = true },
	{ id = "телефон_альбом", size = Vector2.new(844, 390), touch = true },
	{ id = "планшет", size = Vector2.new(1024, 768), touch = true },
	{ id = "ПК", size = Vector2.new(1280, 760), touch = false },
	{ id = "ПК_большой", size = Vector2.new(1920, 1080), touch = false },
}
-- На ПК меряем только то, что вид не сломан (меню открыто, всё на экране): мерило 60 % для телефона и планшета.
local INSET = 36 -- верхняя полоса Roblox, если ScreenGui её не перекрывает
local EDGE = 0.2

local input = game:GetService("UserInputService")
local camera = workspace.CurrentCamera
local function setScreen(screen)
	pcall(function()
		input.TouchEnabled = screen.touch
	end)
	camera.ViewportSize = screen.size
end
setScreen(SCREENS[2]) -- игрок заходит с телефона

local player = World.addPlayer(1001, "Tester")
local S = shared_require("Strings")
World.startServer()
World.startClient()
World.advance(5)
local playerGui = player.PlayerGui
local gui = playerGui:FindFirstChild("BrainrotFactoryUI")
local eyeGui = playerGui:FindFirstChild("BrainrotEyeUI")

-- Прямоугольники ----------------------------------------------------------------------------

local GUI = { Frame = true, TextLabel = true, TextButton = true, ImageLabel = true, ImageButton = true, ScrollingFrame = true, TextBox = true, ViewportFrame = true }
-- Окна, которые игрок открывает сам или которые всплывают на секунды: не постоянный интерфейс.
local MODAL = { Window = true, TutorialArrow = true }

local function parts(u)
	local a = u and u.args or {}
	return a[1] or 0, a[2] or 0, a[3] or 0, a[4] or 0
end
local function vec(v)
	return v and v.X or 0, v and v.Y or 0
end
local function layoutOf(obj)
	for _, child in ipairs(obj:GetChildren()) do
		if child.ClassName == "UIListLayout" or child.ClassName == "UIGridLayout" then
			return child
		end
	end
	return nil
end
local function shown(obj)
	return GUI[obj.ClassName] and obj.Visible ~= false
end

-- Все видимые объекты root с местом на экране в точках: { name, x, y, w, h, text, depth, obj }.
local function collect(root, size)
	local out, problems = {}, {}
	if not root or root.Enabled == false then
		return out, problems
	end
	local scaleObj = root:FindFirstChildOfClass("UIScale")
	local k = scaleObj and scaleObj.Scale or 1
	local top = root.IgnoreGuiInset == false and INSET or 0
	local function place(child, px, py, pw, ph)
		local sxs, sxo, sys, syo = parts(child.Size)
		local w, h = sxs * pw + sxo * k, sys * ph + syo * k
		local pxs, pxo, pys, pyo = parts(child.Position)
		local ax, ay = vec(child.AnchorPoint)
		return px + pxs * pw + pxo * k - ax * w, py + pys * ph + pyo * k - ay * h, w, h
	end
	local function walk(obj, px, py, pw, ph, depth)
		local layout = layoutOf(obj)
		local kids = {}
		for _, child in ipairs(obj:GetChildren()) do
			if shown(child) and not MODAL[child.Name] then
				table.insert(kids, child)
			end
		end
		local rects = {}
		if layout and layout.ClassName == "UIListLayout" then
			table.sort(kids, function(a, b)
				return (a.LayoutOrder or 0) < (b.LayoutOrder or 0)
			end)
			local gap = (layout.Padding and layout.Padding.args[2] or 0) * k
			local total = 0
			for index, child in ipairs(kids) do
				local _, _, w, h = place(child, 0, 0, pw, ph)
				rects[index] = { w = w, h = h }
				total += h + (index > 1 and gap or 0)
			end
			if total > ph + 0.5 then
				table.insert(problems, string.format("%s: содержимое %.0f выше рамки %.0f", obj.Name, total, ph))
			end
			local bottom = layout.VerticalAlignment and layout.VerticalAlignment.Name == "Bottom"
			local y = bottom and py + ph - total or py
			local align = layout.HorizontalAlignment and layout.HorizontalAlignment.Name or "Left"
			for index, rect in ipairs(rects) do
				rect.x = align == "Right" and px + pw - rect.w or align == "Center" and px + (pw - rect.w) / 2 or px
				rect.y = y
				y += rect.h + gap
			end
		elseif layout and layout.ClassName == "UIGridLayout" then
			table.sort(kids, function(a, b)
				return (a.LayoutOrder or 0) < (b.LayoutOrder or 0)
			end)
			local _, cw, _, ch = parts(layout.CellSize)
			local _, gx, _, gy = parts(layout.CellPadding)
			local columns = layout.FillDirectionMaxCells or 1
			for index in ipairs(kids) do
				local column, row = (index - 1) % columns, (index - 1) // columns
				rects[index] = { x = px + column * (cw + gx) * k, y = py + row * (ch + gy) * k, w = cw * k, h = ch * k }
				if (row + 1) * (ch + gy) * k - gy * k > ph + 0.5 then
					table.insert(problems, obj.Name .. ": кнопки ниже рамки меню")
				end
			end
		else
			for index, child in ipairs(kids) do
				local x, y, w, h = place(child, px, py, pw, ph)
				rects[index] = { x = x, y = y, w = w, h = h }
			end
		end
		for index, child in ipairs(kids) do
			local r = rects[index]
			local text = type(child.Text) == "string" and child.Text or ""
			local solid = (child.BackgroundTransparency or 0) < 1
			table.insert(out, { name = child.Name, x = r.x, y = r.y, w = r.w, h = r.h, text = text, solid = solid, depth = depth, obj = child })
			walk(child, r.x, r.y, r.w, r.h, depth + 1)
		end
	end
	walk(root, 0, top, size.X, size.Y - top, 1)
	return out, problems
end

local function overlap(r, size)
	local cx0, cy0, cx1, cy1 = size.X * EDGE, size.Y * EDGE, size.X * (1 - EDGE), size.Y * (1 - EDGE)
	local w = math.min(r.x + r.w, cx1) - math.max(r.x, cx0)
	local h = math.min(r.y + r.h, cy1) - math.max(r.y, cy0)
	return w > 0.5 and h > 0.5
end

-- Что из интерфейса лежит в середине экрана (только то, что видно: фон или надпись).
local function middle(size)
	local bad = {}
	for _, root in ipairs({ gui, eyeGui }) do
		local rects = collect(root, size)
		for _, r in ipairs(rects) do
			if (r.solid or r.text ~= "") and overlap(r, size) then
				table.insert(bad, string.format("%s %.0f,%.0f %.0fx%.0f", r.name, r.x, r.y, r.w, r.h))
			end
		end
	end
	return bad
end

local function dump(screen, state)
	for _, root in ipairs({ gui, eyeGui }) do
		local rects = collect(root, screen.size)
		for _, r in ipairs(rects) do
			if r.solid or r.text ~= "" then
				print(string.format("RECT|%s|%s|%s|%.1f|%.1f|%.1f|%.1f|%d|%s", screen.id, state, r.name, r.x, r.y, r.w, r.h, r.depth,
					(string.gsub(r.text, "[|\n]", " "))))
			end
		end
	end
end

-- Клиент обновляет экран раз в кадр и по таймеру 0,2 с: даём ему пару кадров.
local function frames(count)
	for _ = 1, count or 12 do
		World.frame()
	end
	World.advance(0.3)
end

local function findNamed(root, name)
	for _, item in ipairs(root:GetDescendants()) do
		if item.Name == name then
			return item
		end
	end
	return nil
end

local menuButton = gui and findNamed(gui, "MenuButton")
local menu = gui and findNamed(gui, "Menu")
local eye = eyeGui and findNamed(eyeGui, "EyeButton")

if DUMP_ONLY then
	for _, screen in ipairs(SCREENS) do
		setScreen(screen)
		frames()
		dump(screen, "старт")
		local bad = middle(screen.size)
		print(string.format("MIDDLE|%s|%d|%s", screen.id, #bad, table.concat(bad, "; ")))
	end
	return
end

check(gui ~= nil and eyeGui ~= nil, "нет экранов BrainrotFactoryUI и BrainrotEyeUI")
check(menuButton ~= nil and menu ~= nil and eye ~= nil, "нет кнопки ☰, меню или глаза")

-- 1. Раскладка ------------------------------------------------------------------------------

frames()
check(menu.Visible == false, "на телефоне меню не свёрнуто при входе")
local Remotes = shared_require("Remotes")
for _, screen in ipairs(SCREENS) do
	setScreen(screen)
	frames()
	local _, problems = collect(gui, screen.size)
	for _, problem in ipairs(problems) do
		check(false, screen.id .. ": " .. problem)
	end
	if screen.touch then
		local bad = middle(screen.size)
		check(#bad == 0, screen.id .. ": в середине экрана " .. table.concat(bad, "; "))
		-- Меню, открытое ☰, тоже остаётся у края.
		World.click(menuButton)
		frames()
		check(menu.Visible == true, screen.id .. ": ☰ не открыл меню")
		bad = middle(screen.size)
		check(#bad == 0, screen.id .. ": открытое меню лезет в середину: " .. table.concat(bad, "; "))
		-- Два уведомления подряд: внизу, не в середине.
		Remotes.Notify:FireClient(player, "Test notification one", nil)
		Remotes.Notify:FireClient(player, "Test notification two", nil)
		Remotes.Notify:FireClient(player, "Test notification three", nil)
		frames(2)
		bad = middle(screen.size)
		check(#bad == 0, screen.id .. ": уведомления в середине: " .. table.concat(bad, "; "))
		World.click(menuButton)
		frames()
		check(menu.Visible == false, screen.id .. ": ☰ не закрыл меню")
	else
		-- ПК: прежний вид: меню открыто в две колонки, всё на экране.
		local rects = collect(gui, screen.size)
		local columns = findNamed(gui, "Menu"):FindFirstChildOfClass("UIGridLayout").FillDirectionMaxCells
		check(columns == 2, screen.id .. ": меню не в две колонки: " .. tostring(columns))
		for _, r in ipairs(rects) do
			if r.depth == 1 then
				check(r.x >= -0.5 and r.y >= -0.5 and r.x + r.w <= screen.size.X + 0.5 and r.y + r.h <= screen.size.Y + 0.5,
					string.format("%s: %s за краем экрана %.0f,%.0f %.0fx%.0f", screen.id, r.name, r.x, r.y, r.w, r.h))
			end
		end
	end
end

-- Перезапуск на ПК: меню открыто сразу (новое устройство без касания).
setScreen(SCREENS[4])
frames()
check(menu.Visible == true, "на ПК меню свернулось")
check(gui.IgnoreGuiInset == true, "интерфейс не занимает полосу Roblox сверху")

-- Подписи над брейнротами: в студах (уменьшаются с расстоянием), видны только рядом.
local PlotService = shared_require("Services/PlotService")
check(PlotService.INFO_SIZE.args[2] == 0 and PlotService.INFO_SIZE.args[4] == 0, "подпись над брейнротом в пикселях, а не в студах")
check(PlotService.INFO_DISTANCE <= 60, "подпись видна дальше 60 студов: " .. PlotService.INFO_DISTANCE)

-- 2. Крестики и глаз --------------------------------------------------------------------------

setScreen(SCREENS[2])
frames()
local closables = {}
for _, item in ipairs(gui:GetDescendants()) do
	if item.Name == "Close" and item.Parent and item.Parent.Visible ~= false then
		table.insert(closables, item)
	end
end
local names = {}
for _, close in ipairs(closables) do
	table.insert(names, close.Parent.Name)
end
table.sort(names)
-- Плашки, которые видит новичок: обучение, цель дня, удача, замок базы, событие.
for _, need in ipairs({ "Tutorial", "Goal", "Luck", "LockStatus", "EventBanner" }) do
	check(table.find(names, need) ~= nil, "у плашки " .. need .. " нет крестика (есть: " .. table.concat(names, ", ") .. ")")
end
for _, close in ipairs(closables) do
	local plate = close.Parent
	World.click(close)
	frames()
	check(plate.Visible == false, "крестик не закрыл " .. plate.Name)
end
-- Таймеры каждые 0,2 с не возвращают закрытое.
World.advance(3)
frames()
for _, close in ipairs(closables) do
	check(close.Parent.Visible == false, "закрытая плашка вернулась сама: " .. close.Parent.Name)
end

-- Подписи над брейнротами: две штуки на базе, до глаза видны.
local FactoryService = shared_require("Services/FactoryService")
FactoryService.give(player, "bananito_ninjini", "normal")
FactoryService.give(player, "bananito_ninjini", "normal")
World.advance(2)
local function labelsShown()
	local count = 0
	for _, item in ipairs(workspace.Plots:GetDescendants()) do
		if item.Name == "InfoGui" and item.Enabled ~= false then
			count += 1
		end
	end
	return count
end
check(labelsShown() >= 2, "нет подписей над брейнротами до глаза: " .. labelsShown())

World.click(eye)
check(labelsShown() == 0, "глаз не спрятал подписи сразу: " .. labelsShown())
frames()
check(gui.Enabled == false, "глаз не спрятал интерфейс")
check(eyeGui.Enabled ~= false and eye.Visible ~= false, "глаз спрятал сам себя")
local others = 0
for _, root in ipairs(playerGui:GetChildren()) do
	if root.ClassName == "ScreenGui" and root ~= eyeGui and root.Enabled ~= false then
		others += 1
	end
end
check(others == 0, "после глаза видны другие экраны: " .. others)
-- Брейнрот, появившийся при спрятанном интерфейсе, тоже без подписи.
FactoryService.give(player, "bananito_ninjini", "normal")
World.advance(2)
check(labelsShown() == 0, "подпись нового брейнрота видна при спрятанном интерфейсе: " .. labelsShown())
World.click(eye)
frames()
check(gui.Enabled == true, "глаз не вернул интерфейс")
check(labelsShown() >= 3, "глаз не вернул подписи: " .. labelsShown())
-- База снова пустая: обучению нужны свободные места под 5 капсул.
shared_require("Services/DataService").get(player).creatures = {}
shared_require("Services/DataService").markDirty(player)
World.advance(2)
for _, close in ipairs(closables) do
	local name = close.Parent.Name
	if name ~= "CarryStatus" then
		check(close.Parent.Visible == true, "после глаза не вернулась плашка " .. name)
	end
end

-- 3. Обучение -------------------------------------------------------------------------------

local Actions = shared_require("Services/Actions")
local DataService = shared_require("Services/DataService")
local hintLabel = findNamed(gui, "Hint")

local function focused()
	local list = {}
	for _, item in ipairs(gui:GetDescendants()) do
		if item:GetAttribute("TutorialFocus") then
			table.insert(list, item)
		end
	end
	return list
end

local steps = 0
-- Цель одна, и это нужная кнопка; подсказка — нужная фраза, 3–6 слов.
local function expect(key, target, where)
	frames()
	local list = focused()
	check(#list == (target and 1 or 0), where .. ": целей " .. #list)
	if target then
		check(list[1] == target, where .. ": цель не та: " .. tostring(list[1] and list[1].Name))
		local stroke = target:FindFirstChildOfClass("UIStroke")
		check(stroke and stroke.Color == shared_require("client/Ui/Theme").Colors.Gold, where .. ": цель не светится")
	end
	local text = hintLabel and hintLabel.Text or ""
	check(string.sub(text, 1, #S.t(key)) == S.t(key), where .. ": подсказка «" .. text .. "», нужна «" .. S.t(key) .. "»")
	local _, words = string.gsub(S.t(key), "%S+", "")
	check(words >= 3 and words <= 6, where .. ": в подсказке " .. words .. " слов")
	steps += 1
end

local function withAttr(value)
	for _, item in ipairs(gui:GetDescendants()) do
		if item:GetAttribute("TutorialTarget") == value then
			return item
		end
	end
	return nil
end

local function stepIndex()
	return DataService.get(player).tutorial.step
end

check(stepIndex() == 1, "новичок не на шаге 1: " .. stepIndex())
DataService.get(player).coins = 100000 -- хватит на капсулы и улучшение
DataService.markDirty(player)
frames()
-- Шаг 1: ☰ -> Фабрика -> Создать.
expect("tutorial.do.menu", menuButton, "шаг 1 до меню")
World.click(menuButton)
expect("tutorial.do.factory", findNamed(menu, "Factory"), "шаг 1 меню открыто")
World.click(findNamed(menu, "Factory"))
expect("tutorial.do.craft", withAttr("craft"), "шаг 1 фабрика открыта")
World.click(withAttr("craft"))
World.advance(6)
check(stepIndex() == 2, "после первой капсулы не шаг 2: " .. stepIndex())
-- Шаг 2: ещё 4 капсулы, цель та же кнопка, счётчик растёт.
for craft = 1, 4 do
	expect("tutorial.do.craft", withAttr("craft"), "шаг 2 капсула " .. craft)
	World.click(withAttr("craft"))
	World.advance(6)
end
check(stepIndex() == 3, "после 5 капсул не шаг 3: " .. stepIndex())
-- Шаг 3: окно фабрики открыто — сначала закрыть, потом ⬆️ Улучшения -> купить.
local closeWindow = findNamed(gui, "CloseWindow")
expect("tutorial.do.close", closeWindow, "шаг 3 открыта фабрика")
World.click(closeWindow)
expect("tutorial.do.upgrades", findNamed(menu, "Upgrades"), "шаг 3 меню")
World.click(findNamed(menu, "Upgrades"))
expect("tutorial.do.buy", withAttr("buy"), "шаг 3 улучшения открыты")
World.click(withAttr("buy"))
World.advance(1)
check(stepIndex() == 4, "после улучшения не шаг 4: " .. stepIndex())
-- Шаг 4: замок на базе — кнопки нет, светится сам замок в мире.
World.click(findNamed(gui, "CloseWindow"))
expect("tutorial.do.lock", nil, "шаг 4 замок")
local highlights = 0
for _, item in ipairs(workspace.Plots:GetDescendants()) do
	if item.ClassName == "Highlight" then
		highlights += 1
	end
end
check(highlights == 1, "на шаге 4 подсвечено замков: " .. highlights)
Actions.fire(player, "lock", 1) -- игрок встал на кнопку (сам замок проверяет tests/steal.spec.luau)
World.advance(1)
check(stepIndex() == 5, "после замка не шаг 5: " .. stepIndex())
-- Шаг 5: светится 🎁 -> «Забрать день 1».
expect("tutorial.do.rewards", findNamed(gui, "RewardsButton"), "шаг 5 до наград")
World.click(findNamed(gui, "RewardsButton"))
expect("tutorial.do.claim", withAttr("daily"), "шаг 5 награды открыты")
World.click(withAttr("daily"))
World.advance(1)
frames()
check(stepIndex() == 6, "обучение не закончилось: шаг " .. stepIndex())
check(findNamed(gui, "Tutorial").Visible == false, "после обучения подсказка видна")
check(#focused() == 0, "после обучения осталась цель")

check(#World.errors == 0, "ошибки в коде: " .. #World.errors)
for _, err in ipairs(World.errors) do
	print("   " .. tostring(err))
end

if failures == 0 then
	print(string.format("✅ Экран телефона: %d экранов, середина свободна; крестиков %d; обучение: целей проверено %d, шагов 5", #SCREENS, #closables, steps))
else
	print("❌ Экран телефона: провалено проверок " .. failures)
	error("tests failed")
end
