-- audit/test_index_scroll_canvas.luau
-- The Skins panel (Index) could not be scrolled to its last row (2026-09-21 report).
--
-- IndexScript sizes the list's canvas from UIGridLayout.AbsoluteContentSize. Roblox reports that
-- in screen pixels, AFTER the panel's UIScale (ResponsivePanelScale), and reads CanvasSize's
-- offset in the panel's own units, BEFORE it: at scale s the canvas came out s times the content
-- (plus 28), so every panel drawn under 100% (wide phones, 1440p, ultrawide, 4K) lost its tail.
--
-- This runs the real sizing code of IndexScript (fitPanel, fitGrid, updateCanvasSize and their
-- signal wiring) against a small model of Roblox's layout, fed with the real numbers authored
-- in StarterGui.Index, and checks that on every screen, and with a forced UIScale of 0.8 and of
-- 1.25, the canvas holds every row with a margin and without a long empty tail.
--
--   lune run audit/test_index_scroll_canvas.luau [path/to/IndexScript.luau] [report]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local rb = require("@lune/roblox")

local SOURCE_PATH = process.args[1] or "src/common/StarterGui/Index/IndexScript.client.luau"
local REPORT_ONLY = process.args[2] == "report"
local PLACE = "World1Update3New.rbxl"

local function between(source, first, last)
	local a = assert(string.find(source, first, 1, true), "chunk " .. first)
	local b = assert(string.find(source, last, a, true), "chunk end " .. last)
	return string.sub(source, a, b - 1)
end

local source = fs.readFile(SOURCE_PATH):gsub("\r\n", "\n")
-- From the responsive constants to the last signal connection: everything that sizes the list.
local chunk = between(source, "local COMPACT_PANEL_SIZE", "-- Skins won rather than evolved into")
	.. "\nreturn { scale = panelScale }"

----------------------------------------------------------------------
-- The authored numbers, from the real place
----------------------------------------------------------------------
local authored
do
	local place = rb.deserializePlace(fs.readFile(PLACE))
	local panel = place:GetService("StarterGui").Index.Index
	local list = panel.ScrollingFrame
	local grid = list.UIGridLayout
	authored = {
		PanelSize = panel.Size,
		PanelAspect = panel:FindFirstChildOfClass("UIAspectRatioConstraint").AspectRatio,
		ListSize = list.Size,
		ListAspect = list:FindFirstChildOfClass("UIAspectRatioConstraint").AspectRatio,
		ListCanvas = list.CanvasSize,
		ScrollBarThickness = list.ScrollBarThickness,
		CellSize = grid.CellSize,
		CellPadding = grid.CellPadding,
		CellAspect = grid:FindFirstChildOfClass("UIAspectRatioConstraint").AspectRatio,
		CardAspect = list.Template:FindFirstChildOfClass("UIAspectRatioConstraint").AspectRatio,
	}
	assert(list.AutomaticCanvasSize == rb.Enum.AutomaticSize.None, "The list's canvas is the script's to size (AutomaticCanvasSize None)")
	assert(authored.CellSize.Y.Scale > 0 and authored.CellPadding.Y.Scale > 0, "The authored cells are scale-sized; re-check this model if that changed")
end

-- Every card the server sends: evolutions, limited and exclusive skins.
local SKIN_COUNT
do
	local SuitCatalog = require("../src/common/ReplicatedStorage/Shared/SuitCatalog")
	SKIN_COUNT = #SuitCatalog.Ordered + #(SuitCatalog.Limited or {}) + #(SuitCatalog.Exclusive or {})
	assert(SKIN_COUNT >= 15, "The Index draws the whole catalog")
end

----------------------------------------------------------------------
-- Fake instances whose property writes fire GetPropertyChangedSignal
----------------------------------------------------------------------
local writes = 0
local function observable(values)
	local signals = {}
	local object = {}
	local methods = {}
	function methods.GetPropertyChangedSignal(_, name)
		signals[name] = signals[name] or {}
		return {
			Connect = function(_, fn)
				table.insert(signals[name], fn)
				return { Disconnect = function() end }
			end,
		}
	end
	function methods.FindFirstChildOfClass(_, class)
		return values["__" .. class]
	end
	return setmetatable(object, {
		__index = function(_, key)
			return methods[key] or values[key]
		end,
		__newindex = function(_, key, value)
			if values[key] == value then
				return
			end
			values[key] = value
			writes += 1
			for _, fn in signals[key] or {} do
				fn()
			end
		end,
	})
end

local function fitWithin(maxWidth, maxHeight, ratio) -- UIAspectRatioConstraint, FitWithinMaxSize
	local width = math.min(maxWidth, maxHeight * ratio)
	return width, width / ratio
end

-- One Index panel on one screen. `safe` is the ScreenGui's AbsoluteSize. `cellsFollowCanvas`:
-- scale-sized cells and gaps in a ScrollingFrame are fractions of its canvas (what Studio shows
-- for this panel: two columns at the authored 2-page canvas), so the canvas and the gaps feed
-- each other; the check also holds if they were fractions of the window.
local function newPanel(safe, cellsFollowCanvas)
	local panelAspect = { AspectRatio = authored.PanelAspect }
	local screenGui = observable({ AbsoluteSize = safe })
	local mainFrame = observable({ Size = authored.PanelSize, __UIAspectRatioConstraint = panelAspect })
	local scrollFrame = observable({
		AbsoluteSize = rb.Vector2.new(0, 0),
		CanvasSize = authored.ListCanvas,
		ScrollBarThickness = authored.ScrollBarThickness,
	})
	local gridLayout = observable({
		AbsoluteContentSize = rb.Vector2.new(0, 0),
		CellSize = authored.CellSize,
		CellPadding = authored.CellPadding,
	})
	local equippedTemplate = observable({ __UIAspectRatioConstraint = { AspectRatio = authored.CardAspect } })
	local skins = table.create(SKIN_COUNT, true)

	local panelScale = observable({ Scale = 1 })
	local loaded = luau.load(chunk, {
		environment = setmetatable({
			screenGui = screenGui,
			mainFrame = mainFrame,
			scrollFrame = scrollFrame,
			gridLayout = gridLayout,
			equippedTemplate = equippedTemplate,
			currentSkins = skins,
			UDim2 = rb.UDim2,
			Instance = {
				new = function(class)
					assert(class == "UIScale", "only the panel's UIScale is created here")
					return panelScale
				end,
			},
		}, { __index = _G }),
	})()
	assert(loaded.scale == panelScale, "ResponsivePanelScale is the panel's one UIScale")

	local state = {}
	-- Roblox's layout pass, in the panel's own (unscaled) units; what scripts read back
	-- (AbsoluteSize, AbsoluteContentSize) is multiplied by the UIScale above it.
	local function pass()
		local scale = panelScale.Scale
		local size = mainFrame.Size
		local panelWidth, panelHeight = fitWithin(size.X.Scale * safe.X + size.X.Offset, size.Y.Scale * safe.Y + size.Y.Offset, panelAspect.AspectRatio)
		local width, height = fitWithin(authored.ListSize.X.Scale * panelWidth, authored.ListSize.Y.Scale * panelHeight, authored.ListAspect)
		local canvas = scrollFrame.CanvasSize
		-- CanvasSize: scale of the list's own size, offset in unscaled units.
		local canvasHeight = math.max(height, canvas.Y.Scale * height + canvas.Y.Offset)
		local cell, gap = gridLayout.CellSize, gridLayout.CellPadding
		local basis = if cellsFollowCanvas then canvasHeight else height
		local cellWidth, cellHeight = fitWithin(cell.X.Scale * width + cell.X.Offset, cell.Y.Scale * basis + cell.Y.Offset, authored.CellAspect)
		local gapX = gap.X.Scale * width + gap.X.Offset
		local gapY = gap.Y.Scale * basis + gap.Y.Offset
		local columns = math.max(1, math.floor((width + gapX + 1e-6) / (cellWidth + gapX)))
		local rows = math.ceil(SKIN_COUNT / columns)
		local content = rows * cellHeight + (rows - 1) * gapY
		state.Scale, state.Width, state.Height = scale, width, height
		state.Columns, state.Rows, state.RowHeight = columns, rows, cellHeight
		state.Content, state.Canvas = content, canvasHeight
		local function moved(old, new)
			return math.abs(old.X - new.X) > 0.01 or math.abs(old.Y - new.Y) > 0.01
		end
		local listSize = rb.Vector2.new(width * scale, height * scale)
		if moved(scrollFrame.AbsoluteSize, listSize) then
			scrollFrame.AbsoluteSize = listSize
		end
		local contentSize = rb.Vector2.new(width * scale, content * scale)
		if moved(gridLayout.AbsoluteContentSize, contentSize) then
			gridLayout.AbsoluteContentSize = contentSize
		end
	end
	local function settle()
		for _ = 1, 200 do
			local before = writes
			pass()
			if writes == before then
				pass()
				return state
			end
		end
		error("the layout never settles: the canvas and the cells feed each other")
	end
	return { settle = settle, scale = panelScale, state = state }
end

----------------------------------------------------------------------
-- The checks
----------------------------------------------------------------------
local MIN_MARGIN = 16 -- unscaled px below the last row
local MAX_TAIL = 96 -- ...and never a long empty tail
local failures = {}
local function check(label, state)
	local margin = state.Canvas - state.Content
	local line = ("%-34s scale %.3f  %d x %d rows of %3.0f  content %6.0f  canvas %6.0f  margin %7.1f (%.2f rows)"):format(
		label, state.Scale, state.Columns, state.Rows, state.RowHeight, state.Content, state.Canvas, margin, margin / state.RowHeight)
	print(line)
	if margin < 0 then
		table.insert(failures, label .. ": the last row is cut, the canvas is " .. string.format("%.0f", -margin) .. " px short")
	elseif margin < MIN_MARGIN then
		table.insert(failures, label .. ": only " .. string.format("%.0f", margin) .. " px under the last row, no margin for rounding")
	elseif margin > MAX_TAIL then
		table.insert(failures, label .. ": " .. string.format("%.0f", margin) .. " px of empty tail under the last row")
	end
end

local SCREENS = {
	{ "phone 667x317", rb.Vector2.new(667, 317) },
	{ "phone 844x330", rb.Vector2.new(844, 330) },
	{ "wide phone 915x360", rb.Vector2.new(915, 360) },
	{ "portrait phone 390x740", rb.Vector2.new(390, 740) },
	{ "tablet 1024x710", rb.Vector2.new(1024, 710) },
	{ "laptop 1366x700", rb.Vector2.new(1366, 700) },
	{ "desktop 1920x1020", rb.Vector2.new(1920, 1020) },
	{ "desktop 2560x1382", rb.Vector2.new(2560, 1382) },
	{ "ultrawide 2587x1000", rb.Vector2.new(2587, 1000) },
	{ "4K 3840x2102", rb.Vector2.new(3840, 2102) },
}
local cases = 0
for _, cellsFollowCanvas in { true, false } do
	print(if cellsFollowCanvas then "-- scale-sized cells as fractions of the canvas" else "-- scale-sized cells as fractions of the window")
	-- 1. As fitPanel really scales it.
	for _, screen in SCREENS do
		local panel = newPanel(screen[2], cellsFollowCanvas)
		check(screen[1], panel.settle())
		cases += 1
	end
	-- 2. Any UIScale at all: 0.8 (the canvas used to come out 20% short) and 1.25 (25% long).
	for _, forced in { 0.8, 1.25 } do
		for _, screen in { SCREENS[2], SCREENS[7] } do
			local panel = newPanel(screen[2], cellsFollowCanvas)
			panel.settle()
			panel.scale.Scale = forced
			check(("%s, UIScale %.2f"):format(screen[1], forced), panel.settle())
			cases += 1
		end
	end
end

if #failures > 0 and not REPORT_ONLY then
	error("INDEX SCROLL CANVAS: " .. #failures .. " failures\n  " .. table.concat(failures, "\n  "))
end
if REPORT_ONLY then
	print(("REPORT %s: %d of %d cases outside [%d, %d] px"):format(SOURCE_PATH, #failures, cases, MIN_MARGIN, MAX_TAIL))
	for _, failure in failures do
		print("  " .. failure)
	end
else
	print("PASS Index: on every screen and under any UIScale the canvas holds the last row, with a short tail")
end
