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
	{ id = "телефон_360", size = Vector2.new(360, 780), touch = true },
	{ id = "телефон_800", size = Vector2.new(800, 360), touch = true }, -- самый частый Android в альбоме (reviewer 10.11)
}
-- Окно Roblox на ноутбуке не во весь экран: масштаб окон 0,71, ✕ окна в единицах был бы 31×28 pt. Здесь меряются
-- только ✕ окон (checkWindowClose); раскладка ПК в маленьком окне остаётся в единицах масштаба и в SCREENS не входит.
local SMALL_PC = { id = "ПК_окно", size = Vector2.new(960, 540), touch = false }
local MIN_MEASURED = 15 -- меньше измеренных элементов на экране: тест ничего не доказывает
-- Размеры касания в точках экрана (после UIScale): ☰ ≥ 44, строка меню ≥ 40 с зазором ≥ 6, ✕ ≥ 36, текст ≥ 12.
local MIN_BUTTON, MIN_ROW, MIN_GAP, MIN_CLOSE, MIN_FONT = 44, 40, 6, 36, 12
-- Подсказка обучения (отзыв 10.11 «не поняла, как играть»): текст ≥ 18 pt, у верхнего края (верх рамки не ниже 70 pt).
local MIN_HINT, HINT_TOP = 18, 70
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
local function collect(root, size, withModal)
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
	local function walk(obj, px, py, pw, ph, depth, clip, inMenu)
		local layout = layoutOf(obj)
		local kids = {}
		for _, child in ipairs(obj:GetChildren()) do
			if shown(child) and (withModal or not MODAL[child.Name]) then
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
			if total > ph + 0.5 and obj.ClassName ~= "ScrollingFrame" then
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
			local cxs, cw, cys, ch = parts(layout.CellSize)
			local _, gx, _, gy = parts(layout.CellPadding)
			local columns = layout.FillDirectionMaxCells or 1
			local cellW, cellH = cxs * pw + cw * k, cys * ph + ch * k
			for index in ipairs(kids) do
				local column, row = (index - 1) % columns, (index - 1) // columns
				rects[index] = { x = px + column * (cellW + gx * k), y = py + row * (cellH + gy * k), w = cellW, h = cellH }
				if (row + 1) * (cellH + gy * k) - gy * k > ph + 0.5 and obj.ClassName ~= "ScrollingFrame" then
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
			-- Прокрутка обрезает: что вышло за рамку списка, на экране не видно.
			local cx0, cy0, cx1, cy1 = r.x, r.y, r.x + r.w, r.y + r.h
			if clip then
				cx0, cy0 = math.max(cx0, clip.x), math.max(cy0, clip.y)
				cx1, cy1 = math.min(cx1, clip.x + clip.w), math.min(cy1, clip.y + clip.h)
			end
			local visible = cx1 - cx0 > 0.5 and cy1 - cy0 > 0.5
			local inside = inMenu or child.Name == "Menu"
			if visible then
				table.insert(out, { name = child.Name, x = cx0, y = cy0, w = cx1 - cx0, h = cy1 - cy0, fullW = r.w, fullH = r.h, fullY = r.y,
					text = text, solid = solid, depth = depth, obj = child, menu = inside })
			end
			local childClip = clip
			if child.ClassName == "ScrollingFrame" then
				childClip = { x = r.x, y = r.y, w = r.w, h = r.h }
			end
			if visible then
				walk(child, r.x, r.y, r.w, r.h, depth + 1, childClip, inside)
			end
		end
	end
	walk(root, 0, top, size.X, size.Y - top, 1, nil, false)
	return out, problems
end

local function overlap(r, size)
	local cx0, cy0, cx1, cy1 = size.X * EDGE, size.Y * EDGE, size.X * (1 - EDGE), size.Y * (1 - EDGE)
	local w = math.min(r.x + r.w, cx1) - math.max(r.x, cx0)
	local h = math.min(r.y + r.h, cy1) - math.max(r.y, cy0)
	return w > 0.5 and h > 0.5
end

-- Что из интерфейса лежит в середине экрана (только то, что видно: фон или надпись) и сколько элементов измерено.
-- Выдвинутое меню (кнопка ☰) — временная панель, как окно: в середину его не считаем, его размеры проверяются отдельно.
local function middle(size)
	local bad, measured = {}, 0
	for _, root in ipairs({ gui, eyeGui }) do
		local rects = collect(root, size)
		for _, r in ipairs(rects) do
			if (r.solid or r.text ~= "") and not r.menu then
				measured += 1
			end
			if (r.solid or r.text ~= "") and not r.menu and overlap(r, size) then
				table.insert(bad, string.format("%s %.0f,%.0f %.0fx%.0f", r.name, r.x, r.y, r.w, r.h))
			end
		end
	end
	return bad, measured
end

local function dump(screen, state, withModal)
	for _, root in ipairs({ gui, eyeGui }) do
		local rects = collect(root, screen.size, withModal)
		local scaleObj = root:FindFirstChildOfClass("UIScale")
		local k = scaleObj and scaleObj.Scale or 1
		for _, r in ipairs(rects) do
			if r.solid or r.text ~= "" then
				-- Размер текста в точках (0 — растягивается по рамке): схемы рисуют настоящий размер шрифта.
				local font = if r.obj.TextScaled == false and type(r.obj.TextSize) == "number" then r.obj.TextSize * k else 0
				print(string.format("RECT|%s|%s|%s|%.1f|%.1f|%.1f|%.1f|%d|%.1f|%s", screen.id, state, r.name, r.x, r.y, r.w, r.h, r.depth,
					font, (string.gsub(r.text, "[|\n]", " "))))
				if r.name == "MenuButton" or r.name == "Close" or r.name == "Factory" then
					print(string.format("TOUCH|%s|%s|%.1f|%.1f", screen.id, r.name, r.fullW, r.fullH))
				end
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
		local bad, measured = middle(screen.size)
		print(string.format("MIDDLE|%s|%d|%s", screen.id, #bad, table.concat(bad, "; ")))
		print(string.format("MEASURED|%s|%d", screen.id, measured))
		if screen.touch then
			World.click(menuButton)
			frames()
			dump(screen, "меню")
			-- Окно фабрики открыто: ✕ окна на картинке (окна в мерке середины не участвуют).
			local factory = findNamed(menu, "Factory")
			if factory then
				World.click(factory)
				frames()
				dump(screen, "окно", true)
				local closeWindow = findNamed(gui, "CloseWindow")
				if closeWindow then
					World.click(closeWindow)
					frames()
				end
			end
			if menu.Visible then
				World.click(menuButton)
				frames()
			end
			-- Подсказку закрыли ✕: плашки на месте.
			local hintPlate = findNamed(gui, "Tutorial")
			if hintPlate and hintPlate:FindFirstChild("Close") then
				World.click(hintPlate.Close)
				frames()
				dump(screen, "без_подсказки")
				World.click(eye)
				frames()
				World.click(eye)
				frames()
			end
			-- Окно «С возвращением» (его нет в старом коде: картинки не будет).
			if findNamed(gui, "WelcomeBack") then
				shared_require("Remotes").WelcomeBack:FireClient(player, 10800)
				frames()
				dump(screen, "с_возвращением")
				World.click(findNamed(gui, "WelcomeBack"))
				frames()
			end
		end
	end
	return
end

check(gui ~= nil and eyeGui ~= nil, "нет экранов BrainrotFactoryUI и BrainrotEyeUI")
check(menuButton ~= nil and menu ~= nil and eye ~= nil, "нет кнопки ☰, меню или глаза")

-- 1. Раскладка ------------------------------------------------------------------------------

-- Середина свободна, измерено ≥ 15, размеры касания в точках, текст ≥ 12 pt; крестиков на экране не меньше closes.
local function measureTouch(screen, phase, closes)
	local where = screen.id .. " (" .. phase .. ")"
	local bad, measured = middle(screen.size)
	check(#bad == 0, where .. ": в середине экрана " .. table.concat(bad, "; "))
	check(measured >= MIN_MEASURED, where .. ": измерено элементов " .. measured .. ", нужно не меньше " .. MIN_MEASURED)
	local rects = collect(gui, screen.size)
	for _, r in ipairs(collect(eyeGui, screen.size)) do
		table.insert(rects, r)
	end
	-- Окна и панели (они остались в единицах UIScale) не мельче, чем было: масштаб не ниже 0,5.
	check(gui:FindFirstChildOfClass("UIScale").Scale >= 0.5 - 0.001, where .. ": масштаб окон ниже 0,5")
	local seen = {}
	for _, r in ipairs(rects) do
		seen[r.name] = (seen[r.name] or 0) + 1
		local need = (r.name == "MenuButton" or r.name == "RewardsButton" or r.name == "EyeButton" or r.name == "SettingsButton") and MIN_BUTTON
			or r.name == "Close" and MIN_CLOSE
		if need and r.obj.ClassName == "TextButton" then
			check(r.fullW >= need - 0.5 and r.fullH >= need - 0.5,
				string.format("%s: %s %.1fx%.1f pt, нужно не меньше %d", where, r.name, r.fullW, r.fullH, need))
		end
		-- Текст фиксированного размера читается: не меньше 12 pt.
		if r.obj.TextScaled == false and type(r.obj.TextSize) == "number" and r.text ~= "" then
			local k = gui:FindFirstChildOfClass("UIScale").Scale
			check(r.obj.TextSize * k >= MIN_FONT - 0.01,
				string.format("%s: %s «%s» %.1f pt, нужно не меньше %d", where, r.name, r.text, r.obj.TextSize * k, MIN_FONT))
		end
	end
	check((seen.MenuButton or 0) == 1 and (seen.Close or 0) >= closes,
		string.format("%s: не нашёл ☰ или крестики для замера (крестиков %d, нужно %d)", where, seen.Close or 0, closes))
	print(string.format("MEASURE|%s|%s|измерено %d|крестиков %d", screen.id, phase, measured, seen.Close or 0))
end

-- Ширина строки в точках по замеру шрифтов (tests/text_widths.luau: дата, источник, ширина каждого знака в долях кегля;
-- знака нет в таблице — коэффициент его класса). WIDTH_MULT > 1 — «шрифт шире на столько»: так считается запас.
local Widths = shared_require("TextWidths")
local WIDTH_MULT = 1
local function charClass(ch, code)
	if code >= 0x2190 then
		return "symbol"
	elseif string.find("әғқңөұүһіӘҒҚҢӨҰҮҺІ", ch, 1, true) then
		return "kk"
	elseif code >= 0x0400 and code <= 0x04FF then
		return if code < 0x0430 or (code >= 0x0400 and code < 0x0410) then "cyr_upper" else "cyr_lower"
	elseif ch:match("%l") then
		return "latin_lower"
	elseif ch:match("%u") then
		return "latin_upper"
	elseif ch:match("%d") then
		return "digit"
	elseif ch == " " then
		return "space"
	end
	return "punct"
end
local function textWidth(text, font)
	local width = 0
	for _, code in utf8.codes(text) do
		local ch = utf8.char(code)
		local em = Widths.chars[ch] or Widths.classes[charClass(ch, code)]
		width += em * font
	end
	return width * WIDTH_MULT
end
-- Сколько строк займёт текст при переносе по словам.
local function wrappedLines(text, font, width)
	local lines, current = 1, 0
	local space = textWidth(" ", font)
	for word in string.gmatch(text, "%S+") do
		local w = textWidth(word, font)
		if current == 0 then
			current = w
		elseif current + space + w <= width then
			current += space + w
		else
			lines += 1
			current = w
		end
		while current > width do -- слово длиннее строки
			lines += 1
			current -= width
		end
	end
	return lines
end

-- Подсказка обучения: у верхнего края, текст ≥ 18 pt, любая фраза обучения на языке игрока помещается в рамку.
local HINT_KEYS = { "tutorial.do.menu", "tutorial.do.factory", "tutorial.do.craft", "tutorial.do.upgrades", "tutorial.do.buy",
	"tutorial.do.lock", "tutorial.do.rewards", "tutorial.do.claim", "tutorial.do.close" }
local hintChecked = 0
local function checkHint(screen)
	local k = gui:FindFirstChildOfClass("UIScale").Scale
	local frame, label = findNamed(gui, "Tutorial"), findNamed(gui, "Hint")
	local r, lr
	for _, item in ipairs(collect(gui, screen.size)) do
		if item.obj == frame then
			r = item
		elseif item.obj == label then
			lr = item
		end
	end
	check(r ~= nil and lr ~= nil, screen.id .. ": подсказка обучения не на экране")
	if not r or not lr then
		return
	end
	check(r.y <= HINT_TOP, string.format("%s: подсказка не у верхнего края: верх на %.0f pt", screen.id, r.y))
	local font = label.TextSize * k
	check(label.TextScaled == false and font >= MIN_HINT - 0.01, string.format("%s: текст подсказки %.1f pt, нужно не меньше %d", screen.id, font, MIN_HINT))
	check(lr.y + lr.fullH <= r.y + r.fullH + 0.5, screen.id .. ": текст подсказки ниже её рамки")
	local fits = math.floor((lr.fullH + 0.01) / (font * 1.2))
	for _, key in ipairs(HINT_KEYS) do
		for _, suffix in ipairs({ "", "  (4/4)" }) do
			local text = S.t(key) .. suffix
			local lines = wrappedLines(text, font, lr.fullW)
			hintChecked += 1
			check(lines <= fits, string.format("%s: «%s» в %d строк, в рамку влезает %d (ширина %.0f pt)", screen.id, text, lines, fits, lr.fullW))
		end
	end
	print(string.format("HINT|%s|шрифт %.1f pt|верх %.0f pt|рамка %.0fx%.0f pt|строк влезает %d", screen.id, font, r.y, r.fullW, r.fullH, fits))
end

-- Опись плашек правой колонки и нижней строки (урок 15): у каждой плашки решение, что с ней во время обучения.
-- "тихая" — уступает место подсказке; "видна" — видна всегда, когда есть причина (кража, замок).
-- Плашка, которой нет в описи, роняет тест: новая плашка без решения не должна молча пропасть с экрана.
local DURING_TUTORIAL = { Goal = "тихая", Luck = "тихая", EventBanner = "тихая", LockStatus = "видна", CarryStatus = "видна" }
local function rectOf(obj, size)
	for _, r in ipairs(collect(gui, size)) do
		if r.obj == obj then
			return r
		end
	end
	return nil
end
local function overlaps(a, b)
	return math.min(a.x + a.w, b.x + b.w) - math.max(a.x, b.x) > 0.5 and math.min(a.y + a.h, b.y + b.h) - math.max(a.y, b.y) > 0.5
end
-- Плашка видна целиком: на экране, вне середины, не под подсказкой обучения.
local function plainlyVisible(plate, screen, where)
	local r = rectOf(plate, screen.size)
	check(plate.Visible == true and r ~= nil, where .. ": плашка " .. plate.Name .. " не видна")
	if not r then
		return
	end
	check(r.x >= -0.5 and r.y >= -0.5 and r.x + r.w <= screen.size.X + 0.5 and r.y + r.h <= screen.size.Y + 0.5,
		string.format("%s: %s за краем экрана %.0f,%.0f %.0fx%.0f", where, plate.Name, r.x, r.y, r.w, r.h))
	check(not overlap(r, screen.size), string.format("%s: %s в середине экрана %.0f,%.0f", where, plate.Name, r.x, r.y))
	local hint = findNamed(gui, "Tutorial")
	local h = hint.Visible and rectOf(hint, screen.size)
	check(not (h and overlaps(r, h)), string.format("%s: %s под подсказкой обучения", where, plate.Name))
	print(string.format("PLATE|%s|%s|%.0f,%.0f %.0fx%.0f", where, plate.Name, r.x, r.y, r.w, r.h))
end
local function inventory(screen)
	local found = {}
	for _, child in ipairs(findNamed(gui, "Side"):GetChildren()) do
		if child.ClassName == "Frame" or child.ClassName == "TextButton" then
			found[child.Name] = true
		end
	end
	found.CarryStatus = findNamed(gui, "CarryStatus") ~= nil or nil
	local count = 0
	for name in pairs(found) do
		count += 1
		check(DURING_TUTORIAL[name] ~= nil, screen.id .. ": плашка " .. name .. " без решения на время обучения (урок 15)")
	end
	for name in pairs(DURING_TUTORIAL) do
		check(found[name], screen.id .. ": в описи плашка " .. name .. ", а в интерфейсе её нет")
	end
	return count
end
local platesChecked = 0
-- Обучение ведёт: тихие плашки ушли, замок виден, кража во время обучения показывает таймер.
local function duringTutorial(screen)
	local where = screen.id .. " (обучение)"
	platesChecked += inventory(screen)
	for name, rule in pairs(DURING_TUTORIAL) do
		local plate = findNamed(gui, name)
		if rule == "тихая" then
			check(plate.Visible == false, where .. ": плашка " .. name .. " не уступила место подсказке")
		elseif name == "LockStatus" then
			plainlyVisible(plate, screen, where)
		end
	end
	local carry = findNamed(gui, "CarryStatus")
	player:SetAttribute("CarryDeadline", workspace:GetServerTimeNow() + 60)
	frames()
	plainlyVisible(carry, screen, where .. " + кража")
	local bad = middle(screen.size)
	check(#bad == 0, where .. " + кража: в середине экрана " .. table.concat(bad, "; "))
	player:SetAttribute("CarryDeadline", nil)
	frames()
	check(carry.Visible == false, where .. ": плашка «несёшь» осталась после кражи")
end

-- ✕ окон игры и битвы: на сенсорном экране не меньше 36 pt, окно не шире экрана, список окна начинается под ✕.
local function checkWindowClose(screen)
	local k = gui:FindFirstChildOfClass("UIScale").Scale
	local window = findNamed(gui, "Window")
	local close = findNamed(gui, "CloseWindow")
	local _, cw, _, ch = parts(close.Size)
	check(cw * k >= MIN_CLOSE - 0.01 and ch * k >= MIN_CLOSE - 0.01,
		string.format("%s: ✕ окна %.1fx%.1f pt, нужно не меньше %d", screen.id, cw * k, ch * k, MIN_CLOSE))
	local _, ww, _, wh = parts(window.Size)
	local _, _, _, cy = parts(close.Position)
	check(ww * k <= screen.size.X + 0.5, string.format("%s: окно %.0f pt шире экрана", screen.id, ww * k))
	local content
	for _, child in ipairs(window:GetChildren()) do
		if child.ClassName == "ScrollingFrame" then
			content = child
		end
	end
	local _, _, _, top = parts(content.Position)
	check(top >= cy + ch - 0.5, string.format("%s: список окна начинается на %.0f, ✕ кончается на %.0f", screen.id, top, cy + ch))
	check(wh > top, screen.id .. ": окно ниже ✕ пустое")
	local battleClose = findNamed(gui, "CloseBattle")
	check(battleClose ~= nil, "нет ✕ у окна битвы")
	local bw, bh = 0, 0
	if battleClose then
		_, bw, _, bh = parts(battleClose.Size)
		check(bw * k >= MIN_CLOSE - 0.01 and bh * k >= MIN_CLOSE - 0.01,
			string.format("%s: ✕ битвы %.1fx%.1f pt, нужно не меньше %d", screen.id, bw * k, bh * k, MIN_CLOSE))
	end
	print(string.format("WINCLOSE|%s|окно %.1fx%.1f pt|битва %.1fx%.1f pt", screen.id, cw * k, ch * k, bw * k, bh * k))
end

-- 1б. Текст плашек и верхней строки (reviewer 10.11, замечание 3; урок 20). Каждая фраза, которая может попасть в надпись,
-- на языке игрока помещается в рамку не больше чем в 2 строки и не обрезается; растягиваемый текст (TextScaled) Roblox
-- уменьшает, пока он не влезет, поэтому для него считается размер, который получится, и он не мельче 12 pt.
-- Фразы берутся из словаря с самыми длинными параметрами, а не с теми, что сейчас на экране.
local MAX_LINES = 2
local Format0 = shared_require("Util/Format")
local Events0 = shared_require("Config/Events")
local Daily0 = shared_require("Config/Daily")
local Levels0 = shared_require("Config/Levels")
local Rebirths0 = shared_require("Config/Rebirths")
local function plain(text)
	return (string.gsub(text, "<[^>]+>", ""))
end
-- touch: фразы сенсорного экрана (у события одна строка, у уровня нет титула перерождения), иначе ПК.
local function plateTexts(touch)
	local list = {}
	local function add(name, text)
		list[name] = list[name] or {}
		table.insert(list[name], text)
	end
	local days = #Daily0.Rewards
	add("Goal", S.t("hud.goal_daily", { day = days, total = days }))
	add("Goal", S.t("hud.goal_quest_done"))
	add("Goal", S.t("hud.goal_gift"))
	for _, quest in ipairs(Daily0.QuestPool) do
		-- На плашке — короткий текст задания (quest.<id>.short); окно наград и уведомление показывают полный.
		add("Goal", S.t("hud.goal_quest", { quest = S.t("quest." .. quest.id .. ".short"), progress = quest.target - 1, target = quest.target }))
	end
	add("Goal", S.t("hud.goal_next_gift", { minutes = 60 }))
	-- Таймеры плашек такие же, как в Hud: «через 23:59» до полуночи UTC, буст «1:29:59».
	-- «Вернись через 23 ч» и в последний час «через 59 мин»: обе формы.
	for _, left in ipairs({ 86399, 3599 }) do
		add("Goal", S.t("hud.goal_tomorrow", { time = Format0.hoursOrMinutes(left), day = days - 1, total = days }))
		add("Goal", S.t("hud.goal_mega", { time = Format0.hoursOrMinutes(left), day = days }))
	end
	add("LuckText", S.t("hud.luck", { luck = "99.99" }))
	add("BoostText", S.t("hud.boost", { time = Format0.timer(899) }))
	add("BoostText", S.t("hud.boost", { time = Format0.timer(5399) })) -- два буста подряд: больше часа
	add("BoostText", S.t("hud.vip"))
	for _, key in ipairs({ "status.shield", "status.locked", "status.lock_ready" }) do
		add("LockText", S.t(key, { time = Format0.time(599) }))
	end
	add("LockText", S.t("status.open"))
	add("CarryText", S.t("status.carry", { time = Format0.time(59) }))
	local events = {}
	for _, event in ipairs(Events0.Random) do
		table.insert(events, event)
	end
	for _, event in ipairs(Events0.Hourly) do
		table.insert(events, event)
	end
	-- Плашка события берёт строки из EventBanner.lines: идёт сейчас (до 3 мин) и следующее (до 15 мин).
	local EventBanner0 = shared_require("client/Ui/EventBanner")
	for _, event in ipairs(events) do
		for _, case in ipairs({ { true, Events0.DURATION - 1 }, { false, Events0.CYCLE - 1 } }) do
			local title, info = EventBanner0.lines(event, case[1], case[2], touch)
			if not touch then
				add("EventTitle", title)
			end
			add("EventInfo", info)
		end
	end
	add("CoinsText", Format0.coins(999.9e18))
	add("IncomeText", S.t("common.per_second", { coins = "+" .. Format0.coins(999.9e15) }))
	for _, title in ipairs(Levels0.Titles) do
		local name = S.t("level." .. title.level .. ".name")
		add("LevelText", S.t("common.title_level", { title = name, level = Levels0.MAX_LEVEL }))
		for rebirth = 1, if touch then 0 else Rebirths0.TITLE_COUNT do
			add("LevelText", string.format('%s • <font color="#ffbe28">♻️ %s</font>',
				S.t("common.title_level", { title = name, level = Levels0.MAX_LEVEL }), S.t("rebirth." .. rebirth .. ".title")))
		end
	end
	-- Опыт: самый большой порог уровня (до 67-го).
	local xpMax = Format0.number(Levels0.xpToNext(Levels0.MAX_LEVEL - 1))
	add("XpText", xpMax .. " / " .. xpMax .. " XP")
	add("Badge", "!")
	return list
end
local PLATE_TEXTS = { [true] = plateTexts(true), [false] = plateTexts(false) }

-- Наибольший размер шрифта, при котором текст влезает в рамку (так Roblox растягивает TextScaled), и число строк при нём.
local function scaledFit(text, width, height, maxSize)
	for size = math.floor(maxSize), 1, -1 do
		local lines = wrappedLines(text, size, width)
		if lines * size * 1.2 <= height + 0.01 then
			return size, lines
		end
	end
	return 0, 99
end

local textsChecked = 0
local closeChecked = 0
-- Запас: во сколько раз шрифт может оказаться шире замера, прежде чем фраза перестанет помещаться (урок 23).
-- Порог 5 %: разница движка и Pillow (сглаживание, округление до пикселя) и подстановка другого запасного шрифта.
local MIN_MARGIN = 0.05
local worst = { margin = math.huge }
local worstBy = {} -- надпись -> наименьший запас на всех экранах
local function margin(fits)
	if not fits() then
		return 0
	end
	local lo, hi = 1, 3
	for _ = 1, 20 do
		local mid = (lo + hi) / 2
		WIDTH_MULT = mid
		local ok = fits()
		WIDTH_MULT = 1
		if ok then
			lo = mid
		else
			hi = mid
		end
	end
	return lo - 1
end
-- Рамка текста: прямоугольник надписи минус UIPadding (в точках).
local function textBox(r, k)
	local pad = r.obj:FindFirstChildOfClass("UIPadding")
	local function off(value)
		return value and value.args and value.args[2] or 0
	end
	local w, h = r.fullW, r.fullH
	if pad then
		w -= (off(pad.PaddingLeft) + off(pad.PaddingRight)) * k
		h -= (off(pad.PaddingTop) + off(pad.PaddingBottom)) * k
	end
	return w, h
end
local function checkPlateText(screen)
	local k = gui:FindFirstChildOfClass("UIScale").Scale
	-- Плашки показываются на время замера (замер синхронный: клиент между строками не перерисовывает экран).
	local plates = {}
	for _, name in ipairs({ "Goal", "Luck", "LockStatus", "CarryStatus", "EventBanner" }) do
		local plate = findNamed(gui, name)
		if plate then
			plates[plate] = plate.Visible
			plate.Visible = true
		end
	end
	for _, item in ipairs(gui:GetDescendants()) do
		if item.Name == "Badge" then
			plates[item] = item.Visible
			item.Visible = true
		end
	end
	local found = {}
	local textsOf = PLATE_TEXTS[screen.touch == true]
	for _, r in ipairs(collect(gui, screen.size)) do
		local texts = textsOf[r.name]
		if texts and (r.obj.ClassName == "TextLabel" or r.obj.ClassName == "TextButton") then
			found[r.name] = true
			local w, h = textBox(r, k)
			local constraint = r.obj:FindFirstChildOfClass("UITextSizeConstraint")
			local maxSize = (constraint and constraint.MaxTextSize or 100) * k
			for _, raw in ipairs(texts) do
				local text = plain(raw)
				textsChecked += 1
				local fits
				if r.obj.TextScaled then
					fits = function()
						local size, lines = scaledFit(text, w, h, maxSize)
						return size >= MIN_FONT and lines <= MAX_LINES
					end
				else
					local font = r.obj.TextSize * k
					fits = function()
						local lines = if r.obj.TextWrapped then wrappedLines(text, font, w) else (textWidth(text, font) <= w and 1 or 99)
						return lines <= MAX_LINES and lines * font * 1.2 <= h + 0.5
					end
				end
				local m = margin(fits)
				worstBy[r.name] = math.min(worstBy[r.name] or math.huge, m)
				if m < worst.margin then
					worst = { margin = m, text = text, where = screen.id .. " " .. r.name }
				end
				check(m >= MIN_MARGIN, string.format("%s: %s «%s» запас ширины %.1f %%, нужно не меньше %.0f %%",
					screen.id, r.name, text, m * 100, MIN_MARGIN * 100))
				if r.obj.TextScaled then
					local size, lines = scaledFit(text, w, h, maxSize)
					check(size >= MIN_FONT and lines <= MAX_LINES, string.format("%s: %s «%s» растягивается до %d pt в %d строк (рамка %.0fx%.0f pt), нужно ≥ %d pt и ≤ %d строк",
						screen.id, r.name, text, size, lines, w, h, MIN_FONT, MAX_LINES))
				else
					local font = r.obj.TextSize * k
					local lines = if r.obj.TextWrapped then wrappedLines(text, font, w) else (textWidth(text, font) <= w and 1 or 99)
					check(lines <= MAX_LINES and lines * font * 1.2 <= h + 0.5, string.format("%s: %s «%s» %.0f pt в %d строк, в рамку %.0fx%.0f pt влезает %d",
						screen.id, r.name, text, font, lines, w, h, math.floor((h + 0.5) / (font * 1.2))))
				end
			end
		end
	end
	-- Надпись плашки не заходит под её ✕ (reviewer 10.11, замечание 6: строка события на ПК под крестиком).
	local rects = collect(gui, screen.size)
	local compared = 0
	for plate in pairs(plates) do
		local close = plate.Name ~= "Badge" and plate:FindFirstChild("Close")
		local closeRect
		for _, r in ipairs(rects) do
			if close and r.obj == close then
				closeRect = r
			end
		end
		check(plate.Name == "Badge" or closeRect ~= nil, screen.id .. ": у плашки " .. plate.Name .. " не найден ✕ на экране: сравнивать не с чем")
		if closeRect then
			for _, r in ipairs(rects) do
				if (r.obj.Parent == plate or r.obj == plate) and r.obj ~= close and textsOf[r.name] and r.obj.Visible ~= false then
					local w = textBox(r, k)
					local pad = r.obj:FindFirstChildOfClass("UIPadding")
					local left = if pad then (pad.PaddingLeft.args[2] or 0) * k else 0
					local box = { x = r.x + left, y = r.y, w = w, h = r.h }
					check(not overlaps(box, closeRect), string.format("%s: надпись %s заходит под ✕ плашки %s (%.0f..%.0f, ✕ с %.0f)",
						screen.id, r.name, plate.Name, box.x, box.x + box.w, closeRect.x))
					closeChecked += 1
					compared += 1
				end
			end
		end
	end
	for plate, visible in pairs(plates) do
		plate.Visible = visible
	end
	for name in pairs(textsOf) do
		check(found[name], screen.id .. ": надпись " .. name .. " не нашлась для замера текста")
	end
	-- Надписей рядом с ✕: телефон — цель, удача (2), замок, «несёшь», событие (1 строка); ПК — то же, у события 2 надписи.
	local needCompared = if screen.touch then 6 else 7
	check(compared >= needCompared, string.format("%s: надписей сверено с ✕ %d, нужно не меньше %d", screen.id, compared, needCompared))
	print(string.format("TEXT|%s|надписей %d|фраз проверено всего %d|надписей рядом с ✕ всего %d", screen.id, (function()
		local n = 0
		for _ in pairs(found) do
			n += 1
		end
		return n
	end)(), textsChecked, closeChecked))
end
-- Минимальный запас ширины по языку прогона (печатается в конце раздела 1, урок 23).
local function printMargin()
	print(string.format("ЗАПАС|%s|мин %.1f %%|%s|«%s»|таблица %s", tostring(__LOCALE), worst.margin * 100, worst.where or "-",
		worst.text or "-", Widths.date))
	local names = {}
	for name in pairs(worstBy) do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in ipairs(names) do
		print(string.format("ЗАПАС_НАДПИСЬ|%s|%s|%.1f %%", tostring(__LOCALE), name, worstBy[name] * 100))
	end
end

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
		-- Состояние А: обучение ведёт — подсказка сверху, плашки уступили ей место.
		-- Состояние Б: подсказку закрыли ✕ — плашки на месте; мерки те же, крестиков не меньше 3, как до этого круга.
		local hintPlate = findNamed(gui, "Tutorial")
		check(hintPlate and hintPlate.Visible == true, screen.id .. ": новичок не видит подсказку обучения")
		measureTouch(screen, "обучение", 2)
		checkHint(screen)
		duringTutorial(screen)
		World.click(hintPlate:FindFirstChild("Close"))
		frames()
		check(hintPlate.Visible == false, screen.id .. ": ✕ не закрыл подсказку")
		for name, rule in pairs(DURING_TUTORIAL) do
			if rule == "тихая" then
				check(findNamed(gui, name).Visible == true, screen.id .. ": ✕ подсказки не вернул плашку " .. name)
			end
		end
		measureTouch(screen, "без подсказки", 3)
		checkPlateText(screen)
		World.click(eye) -- глаз дважды: всё закрытое снова на экране, подсказка тоже
		frames()
		World.click(eye)
		frames()
		check(hintPlate.Visible == true, screen.id .. ": глаз не вернул подсказку")
		-- Меню, открытое ☰: строки ≥ 40 pt с зазором ≥ 6 pt, текст ≥ 12 pt, всё в границах экрана.
		World.click(menuButton)
		frames()
		check(menu.Visible == true, screen.id .. ": ☰ не открыл меню")
		local rows = {}
		for _, r in ipairs(collect(gui, screen.size)) do
			if r.menu and r.obj.ClassName == "TextButton" then
				table.insert(rows, r)
			end
		end
		check(#rows >= 6, screen.id .. ": в меню видно строк " .. #rows)
		table.sort(rows, function(a, b)
			return a.fullY < b.fullY
		end)
		local scale = gui:FindFirstChildOfClass("UIScale").Scale
		for index, r in ipairs(rows) do
			check(r.fullH >= MIN_ROW - 0.5, string.format("%s: строка меню %s %.1f pt, нужно не меньше %d", screen.id, r.name, r.fullH, MIN_ROW))
			check(r.obj.TextScaled == false and type(r.obj.TextSize) == "number" and r.obj.TextSize * scale >= MIN_FONT - 0.01,
			string.format("%s: текст меню %s растягивается или мельче %d pt", screen.id, r.name, MIN_FONT))
			check(r.x >= -0.5 and r.x + r.w <= screen.size.X + 0.5 and r.y >= -0.5 and r.y + r.h <= screen.size.Y + 0.5,
				screen.id .. ": меню за краем экрана: " .. r.name)
			if rows[index + 1] then
				local gap = rows[index + 1].fullY - (r.fullY + r.fullH)
				check(gap >= MIN_GAP - 0.5, string.format("%s: зазор между %s и %s %.1f pt, нужно не меньше %d", screen.id, r.name, rows[index + 1].name, gap, MIN_GAP))
			end
		end
		-- Титул перерождения на сенсорном экране — первой строкой меню ☰ (решение лида 13.11): виден, и каждый из 10 титулов
		-- на языке игрока помещается в строку меню не больше чем в 2 строки с запасом ширины (урок 23).
		do
			local ClientState1 = shared_require("client/State")
			local saved = ClientState1.current
			local state = table.clone(saved)
			state.rebirthTitle = S.m("rebirth.10.title")
			ClientState1.set(state)
			frames()
			local label = findNamed(menu, "RebirthTitle")
			local r = label and rectOf(label, screen.size)
			check(r ~= nil and label.Visible == true, screen.id .. ": титула перерождения нет в меню ☰")
			if r then
				local font = label.TextSize * scale
				for n = 1, 10 do
					local text = "♻️ " .. S.t("rebirth." .. n .. ".title")
					local m = margin(function()
						local lines = wrappedLines(text, font, r.fullW)
						return lines <= MAX_LINES and lines * font * 1.2 <= r.fullH + 0.5
					end)
					textsChecked += 1
					check(m >= MIN_MARGIN, string.format("%s: титул «%s» в меню, запас ширины %.1f %%", screen.id, text, m * 100))
					worstBy.RebirthTitle = math.min(worstBy.RebirthTitle or math.huge, m)
					if m < worst.margin then
						worst = { margin = m, text = text, where = screen.id .. " RebirthTitle" }
					end
				end
			end
			ClientState1.set(saved)
			frames()
			check(label == nil or label.Visible == false, screen.id .. ": без перерождения титул остался в меню")
		end
		-- Два уведомления подряд: внизу, не в середине.
		Remotes.Notify:FireClient(player, "Test notification one", nil)
		Remotes.Notify:FireClient(player, "Test notification two", nil)
		Remotes.Notify:FireClient(player, "Test notification three", nil)
		frames(2)
		local bad = middle(screen.size)
		check(#bad == 0, screen.id .. ": уведомления в середине: " .. table.concat(bad, "; "))
		World.click(menuButton)
		frames()
		check(menu.Visible == false, screen.id .. ": ☰ не закрыл меню")
		checkWindowClose(screen)
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
		-- На ПК тоже не меньше 15 измеренных (reviewer 10.11, замечание 4): пустой набор не проходит.
		local _, measured = middle(screen.size)
		check(measured >= MIN_MEASURED, screen.id .. ": измерено элементов " .. measured .. ", нужно не меньше " .. MIN_MEASURED)
		print(string.format("MEASURE|%s|ПК|измерено %d", screen.id, measured))
		checkPlateText(screen)
		checkWindowClose(screen)
	end
end

setScreen(SMALL_PC)
frames()
checkWindowClose(SMALL_PC)

-- Страховка в игре (урок 23): движок сказал «текст не влез» (TextFits = false) — надпись ужимается, не выше своего
-- размера; новая раскладка возвращает текст фиксированного размера.
setScreen(SCREENS[7])
frames()
do
	local label = findNamed(gui, "LuckText")
	local size = label.TextSize
	check(label.TextScaled == false, "на телефоне надпись удачи растягивается до проверки страховки")
	label.TextFits = false
	local limit = label:FindFirstChild("FitLimit")
	check(label.TextScaled == true and limit ~= nil and limit.MaxTextSize == math.floor(size),
		"TextFits = false не ужал надпись: TextScaled " .. tostring(label.TextScaled))
	setScreen(SCREENS[2])
	frames()
	check(label.TextScaled == false and label:FindFirstChild("FitLimit") == nil, "новая раскладка не вернула фиксированный размер")
end
printMargin()

-- Перезапуск на ПК: меню открыто сразу (новое устройство без касания).
setScreen(SCREENS[4])
frames()
check(menu.Visible == true, "на ПК меню свернулось")
check(gui.IgnoreGuiInset == true, "интерфейс не занимает полосу Roblox сверху")

-- Подписи над брейнротами: в студах (уменьшаются с расстоянием), видны только рядом.
-- Смотрим на построенную подпись, а не только на константы: она могла бы вернуться к пикселям.
local PlotService = shared_require("Services/PlotService")
local FactoryService0 = shared_require("Services/FactoryService")
FactoryService0.give(player, "bananito_ninjini", "normal")
World.advance(2)
local builtInfo
for _, item in ipairs(workspace.Plots:GetDescendants()) do
	if item.Name == "InfoGui" then
		builtInfo = item
	end
end
check(builtInfo ~= nil, "нет построенной подписи InfoGui")
if builtInfo then
	local _, xo, _, yo = parts(builtInfo.Size)
	check(xo == 0 and yo == 0, "построенная подпись в пикселях: " .. xo .. "x" .. yo)
	check(builtInfo.MaxDistance <= 60, "построенная подпись видна на " .. builtInfo.MaxDistance .. " студов")
end
shared_require("Services/DataService").get(player).creatures = {}
shared_require("Services/DataService").markDirty(player)
World.advance(2)
check(PlotService.INFO_SIZE.args[2] == 0 and PlotService.INFO_SIZE.args[4] == 0, "подпись над брейнротом в пикселях, а не в студах")
check(PlotService.INFO_DISTANCE <= 60, "подпись видна дальше 60 студов: " .. PlotService.INFO_DISTANCE)

-- 2. Крестики и глаз --------------------------------------------------------------------------

setScreen(SCREENS[2])
frames()
-- Новичок: сначала ✕ подсказки обучения (тихие плашки уступают ей место и возвращаются после ✕), потом все остальные.
local closables = {}
local tutorialPlate = findNamed(gui, "Tutorial")
if tutorialPlate.Visible and tutorialPlate:FindFirstChild("Close") then
	table.insert(closables, tutorialPlate.Close)
	World.click(tutorialPlate.Close)
	frames()
end
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
-- Глаз вернул всё, подсказку обучения тоже: пока она ведёт, тихие плашки уступают ей место, остальные видны.
check(findNamed(gui, "Tutorial").Visible == true, "после глаза не вернулась подсказка обучения")
for _, close in ipairs(closables) do
	local name = close.Parent.Name
	if DURING_TUTORIAL[name] == "тихая" then
		check(close.Parent.Visible == false, "после глаза тихая плашка " .. name .. " рядом с подсказкой обучения")
	elseif name ~= "CarryStatus" then
		check(close.Parent.Visible == true, "после глаза не вернулась плашка " .. name)
	end
end
-- Исходное свойство «глаз снимает ✕» для тихих плашек проверяется без подсказки (урок 18): все три закрывали ✕ выше,
-- подсказку закрыли ✕ — цель, удача и событие должны быть на экране. Не видны — глаз не снял с них флаг «закрыто».
World.click(findNamed(gui, "Tutorial").Close)
frames()
World.advance(1.2) -- цель и удача пересчитываются раз в секунду
frames()
for name, rule in pairs(DURING_TUTORIAL) do
	if rule == "тихая" then
		local plate = findNamed(gui, name)
		check(plate:GetAttribute("Closed") ~= true, "глаз не снял флаг «закрыто» с плашки " .. name)
		check(plate.Visible == true, "после глаза и ✕ подсказки не вернулась плашка " .. name)
	end
end

-- 2б. ✕ привязан к условию показа: плашка «несёшь брейнрота» и замок базы возвращаются в следующий раз ---------------

local function plateOf(name)
	return findNamed(gui, name)
end
local function closeOf(plate)
	return plate:FindFirstChild("Close")
end
local function serverNow()
	return workspace:GetServerTimeNow()
end

-- Несёшь брейнрота: ✕ -> таймер сбросили -> снова выставили -> плашка видна.
local carry = plateOf("CarryStatus")
player:SetAttribute("CarryDeadline", serverNow() + 60)
frames()
check(carry.Visible == true, "плашка «несёшь» не появилась при таймере")
World.click(closeOf(carry))
frames()
check(carry.Visible == false, "✕ не закрыл плашку «несёшь»")
World.advance(2)
check(carry.Visible == false, "закрытая плашка «несёшь» вернулась при том же таймере")
player:SetAttribute("CarryDeadline", nil)
frames()
player:SetAttribute("CarryDeadline", serverNow() + 60)
frames()
check(carry.Visible == true, "после нового таймера плашка «несёшь» осталась закрытой навсегда")
-- Другой таймер без паузы (вторая кража сразу за первой) тоже снимает ✕.
World.click(closeOf(carry))
frames()
player:SetAttribute("CarryDeadline", serverNow() + 90)
frames()
check(carry.Visible == true, "новая кража без паузы не вернула плашку")
player:SetAttribute("CarryDeadline", nil)
frames()

-- Замок базы: настоящий замок (кнопка на базе), состояния «открыта» -> «закрыта» -> «перезарядка» -> «открыта».
-- ✕ закрывает плашку только на своё состояние: в следующем она снова на экране.
local lockPlate = plateOf("LockStatus")
local StealService0 = shared_require("Services/StealService")
local MoveGuard0 = shared_require("Services/MoveGuardService")
local lockButton
for _, plot in ipairs(workspace.Plots:GetChildren()) do
	if plot:GetAttribute("OwnerUserId") == player.UserId then
		lockButton = plot:FindFirstChild("LockButton")
	end
end
check(lockButton ~= nil, "нет кнопки замка на своей базе")
if lockButton then
	frames()
	check(lockPlate.Visible == true, "плашка замка не видна в состоянии «открыта»")
	World.click(closeOf(lockPlate))
	frames()
	check(lockPlate.Visible == false, "✕ не закрыл плашку замка")
	World.advance(2)
	check(lockPlate.Visible == false, "закрытая плашка замка вернулась без смены состояния")
	-- Игрок встал на кнопку и нажал замок.
	local standAt = lockButton.Position + Vector3.new(0, 3, 0)
	MoveGuard0.teleported(player, standAt)
	player.Character.HumanoidRootPart.CFrame = CFrame.lookAt(standAt, standAt + Vector3.new(0, 0, 1))
	World.advance(MoveGuard0.TELEPORT_GRACE + 4)
	World.prompt(lockButton.LockPrompt, player, 0)
	frames()
	check(StealService0.isLocked(player), "замок не закрылся у кнопки (сломан сам тест)")
	check(lockPlate.Visible == true, "замок закрыли, а плашка осталась закрытой навсегда")
	World.click(closeOf(lockPlate))
	frames()
	check(lockPlate.Visible == false, "✕ не закрыл плашку «замок закрыт»")
	World.advance(StealService0.LOCK_TIME + 2) -- замок кончился, началась перезарядка
	frames()
	check(lockPlate.Visible == true, "перезарядка замка не вернула плашку")
	World.click(closeOf(lockPlate))
	frames()
	World.advance(StealService0.LOCK_COOLDOWN + 2) -- перезарядка кончилась: снова «открыта»
	frames()
	check(lockPlate.Visible == true, "замок снова открыт, а плашка осталась закрытой")
end

-- 2в. Урок 7 для цели, удачи и события: ✕ держится, пока причина та же, и снимается, когда она сменилась ---------------

do
	local ClientState = shared_require("client/State")
	local Events = shared_require("Config/Events")
	local function copy(value)
		if type(value) ~= "table" then
			return value
		end
		local out = {}
		for key, item in pairs(value) do
			out[key] = copy(item)
		end
		return out
	end
	-- Состояние «как с сервера», но с подменённой частью: клиент перерисует экран, как при настоящем ответе.
	local function setState(change)
		local state = copy(ClientState.current)
		change(state)
		ClientState.set(state)
		frames()
		World.advance(1.2) -- цель и удача пересчитываются раз в секунду
		frames()
	end
	local real = copy(ClientState.current)
	-- Подсказка обучения ведёт: цель, удача и событие тихие. Здесь проверяется их ✕: подсказку закрываем.
	local tutorialHint = findNamed(gui, "Tutorial")
	if tutorialHint.Visible then
		World.click(tutorialHint.Close)
		frames()
	end

	-- Цель: «забери награду дня» -> ✕ -> та же цель -> закрыта; цель сменилась («задание выполнено») -> видна.
	local goal = plateOf("Goal")
	setState(function(state)
		state.rewards.canClaim = true
	end)
	check(goal.Visible == true, "цель «награда дня» не видна")
	World.click(closeOf(goal))
	frames()
	World.advance(3)
	frames()
	check(goal.Visible == false, "закрытая цель вернулась без смены цели")
	setState(function(state)
		state.rewards.canClaim = false
		local quest = state.rewards.quests[1]
		if quest then
			quest.progress, quest.claimed = quest.target, false
		end
	end)
	check(goal.Visible == true, "цель сменилась (задание выполнено), а плашка осталась закрытой навсегда")

	-- Удача: ✕ -> та же удача -> закрыта; начался буст удачи -> видна.
	local luck = plateOf("Luck")
	check(luck.Visible == true, "удача не видна до ✕: проверка ✕ ничего не докажет")
	World.click(closeOf(luck))
	frames()
	World.advance(3)
	frames()
	check(luck.Visible == false, "закрытая удача вернулась без смены удачи")
	setState(function(state)
		state.luckBoostLeft = 900
		state.luck = (state.luck or 1) * 2
	end)
	check(luck.Visible == true, "начался буст удачи, а плашка удачи осталась закрытой навсегда")

	-- Событие: ✕ на «следующее событие» -> ждём -> закрыто; событие началось -> плашка видна.
	local event = plateOf("EventBanner")
	check(event.Visible == true, "событие не видно до ✕: проверка ✕ ничего не докажет")
	World.click(closeOf(event))
	frames()
	World.advance(3)
	frames()
	check(event.Visible == false, "закрытое событие вернулось само до начала события")
	local now = workspace:GetServerTimeNow()
	local _, startsAt = Events.nextEvent(now)
	World.skip(startsAt - now + 1) -- до начала следующего события
	frames()
	check(#Events.active(workspace:GetServerTimeNow()) > 0, "событие не началось (сломан сам тест)")
	check(event.Visible == true, "событие началось, а плашка события осталась закрытой навсегда")

	ClientState.set(real)
	World.click(eye) -- глаз дважды: подсказка обучения снова на экране для раздела 3
	frames()
	World.click(eye)
	frames()
	shared_require("Services/DataService").sendNow(player)
	frames()
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

-- Тупик на шаге 5: награду дня забрали на шагах 1–4. Другой игрок: шаги 1–4 пройдены, шаг 5 закрылся сам.
do
	local Remotes0 = shared_require("Remotes")
	local friend = World.addPlayer(1002, "Friend")
	World.advance(2)
	local fd = DataService.get(friend)
	check(fd.tutorial.step == 1, "второй игрок не на шаге 1: " .. fd.tutorial.step)
	local coinsBefore = fd.coins
	Remotes0.ClaimDaily.OnServerEvent:Fire(friend) -- награду дня забрали на шаге 1
	check(fd.tutorial.step == 1, "награда дня сдвинула шаг 1: " .. fd.tutorial.step)
	for _, action in ipairs({ "craft", "craft", "craft", "craft", "craft", "upgrade", "lock" }) do
		Actions.fire(friend, action, 1)
	end
	check(fd.tutorial.step == 6, "шаг 5 не закрылся сам после шагов 1–4: шаг " .. fd.tutorial.step)
	local expected = 100 + 200 + 300 + 300 + 500 -- награды шагов 1–5
	check(fd.coins - coinsBefore >= expected, "за шаг 5 нет награды: " .. (fd.coins - coinsBefore))
	-- Старое сохранение стоит на шаге 5, а награда дня уже получена: при входе шаг закрывается.
	fd.tutorial.step, fd.tutorial.progress = 5, 0
	DataService.sendNow(friend)
	check(fd.tutorial.step == 6, "старое сохранение осталось на шаге 5: " .. fd.tutorial.step)
	-- Награда дня не получена: шаг 5 ждёт (тупика нет, кнопка живая).
	fd.daily.lastClaimDay = nil
	fd.tutorial.step = 5
	DataService.sendNow(friend)
	check(fd.tutorial.step == 5, "шаг 5 закрылся без награды дня: " .. fd.tutorial.step)
	World.removePlayer(friend)
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
-- ✕ на подсказке прячет её только на этом шаге: на шаге 3 она снова на экране.
local hint = findNamed(gui, "Tutorial")
expect("tutorial.do.craft", withAttr("craft"), "шаг 2 капсула 1")
World.click(hint:FindFirstChild("Close"))
frames()
check(hint.Visible == false and #focused() == 0, "✕ не спрятал подсказку обучения и стрелку")
World.advance(3)
check(hint.Visible == false, "закрытая подсказка вернулась на том же шаге")
for craft = 1, 4 do
	World.click(withAttr("craft"))
	World.advance(6)
end
frames()
check(hint.Visible == true, "подсказка осталась закрытой на следующем шаге")
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
-- Шаг 4 — это замок: плашка замка видна целиком на каждом сенсорном экране (решение лида 11.11).
for _, screen in ipairs(SCREENS) do
	if screen.touch then
		setScreen(screen)
		frames()
		plainlyVisible(findNamed(gui, "LockStatus"), screen, screen.id .. " (шаг 4)")
	end
end
setScreen(SCREENS[2])
frames()
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
-- Конец обучения — второй путь выхода из «тихого» режима (первый — ✕ подсказки, третий — глаз, урок 19):
-- цель, удача и событие возвращаются сами, без ✕ и без глаза.
World.advance(1.2)
frames()
for name, rule in pairs(DURING_TUTORIAL) do
	if rule == "тихая" then
		check(findNamed(gui, name).Visible == true, "после конца обучения не вернулась плашка " .. name)
	end
end
check(#focused() == 0, "после обучения осталась цель")

check(#World.errors == 0, "ошибки в коде: " .. #World.errors)
for _, err in ipairs(World.errors) do
	print("   " .. tostring(err))
end

if failures == 0 then
	print(string.format("✅ Экран телефона: %d экранов, середина свободна; крестиков %d; обучение: целей проверено %d, шагов 5; плашек в описи проверено %d", #SCREENS, #closables, steps, platesChecked))
else
	print("❌ Экран телефона: провалено проверок " .. failures)
	error("tests failed")
end
