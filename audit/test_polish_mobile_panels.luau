-- test_polish_mobile_panels.luau
-- Owner, 2026-09-22 (point 4, "only on phones, any phone"): the Backpack and Rebirth windows
-- stretch horizontally on compact phones and lose their shape next to well-proportioned ones,
-- and the Backpack's Aura / Trail lists cut their last cards off.
--
-- Runs the real code on the real authored windows of the three places:
--   * BackpackScript's own fitPanel (extracted from the source, run with the real
--     MenuPanelLayout and a UIScale / UIAspectRatioConstraint from @lune/roblox), before
--     (the pass's backup) and after;
--   * MenuPanelLayout.BindPhoneFit on Rebirth.Rebirth (the RebirthController call);
--   * BackpackScript's releaseAuthoredCardHeight, fitCardsForPhones and bindListCanvas on a
--     copy of each list holding every catalog card, with the UIListLayout's content computed
--     here from the authored card shape (Lune computes no AbsoluteSize).
-- On six landscape phones (844x390, 932x430, 667x375, 740x360, 915x412, 780x360) under a 36 or
-- 58 px top bar, with and without notch insets, plus 1080p and 1440p desktops, it checks:
-- Backpack and Rebirth keep 1.2795 to 1 (+-1%), sit whole in the safe area with their header,
-- take 80%+ of its height; the desktop is untouched (same Size, place and UIScale as before);
-- each list's canvas holds all its cards plus room under the last one, under any UIScale.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")
local PlaceFiles = require("./place_files")

local Vector2, UDim2, UDim, Enum, Instance, Color3 = rb.Vector2, rb.UDim2, rb.UDim, rb.Enum, rb.Instance, rb.Color3
local BACKPACK = "src/common/StarterGui/Backpack/BackpackScript.client.luau"
local BACKUP = "output/FablePolish_20260922/backup_src/common/StarterGui/Backpack/BackpackScript.client.luau"
local ASPECT = 1.2795318365097046
local TOLERANCE = 0.01

local function has(source, needle, message)
	assert(string.find(source, needle, 1, true), message .. "\n  (missing: " .. needle .. ")")
end
local function chunk(source, from, to, label)
	local a = assert(string.find(source, from, 1, true), label .. ": start marker missing: " .. from)
	local b = assert(string.find(source, to, a, true), label .. ": end marker missing: " .. to)
	return string.sub(source, a, b - 1)
end

----------------------------------------------------------------------
-- The real MenuPanelLayout, in a world the test controls
----------------------------------------------------------------------
local function signal()
	local s = { handlers = {} }
	function s:Connect(fn)
		table.insert(self.handlers, fn)
		return { Disconnect = function() end }
	end
	function s:Fire(...)
		for _, fn in table.clone(self.handlers) do
			fn(...)
		end
	end
	return s
end
local world = { TopBar = 58 }
local camera = { ViewportSize = Vector2.new(844, 390), Signals = { ViewportSize = signal() } }
function camera:GetPropertyChangedSignal(name)
	return assert(self.Signals[name], name)
end
local Workspace = { CurrentCamera = camera }
function Workspace:GetPropertyChangedSignal()
	return signal()
end
local UserInputService = { TouchEnabled = true, KeyboardEnabled = false }
local GuiService = {}
function GuiService:GetGuiInset()
	return Vector2.new(0, world.TopBar), Vector2.new(0, 0)
end
local services = { Workspace = Workspace, UserInputService = UserInputService, GuiService = GuiService, TweenService = {} }
local game = {
	GetService = function(_, name)
		return assert(services[name], "service " .. name)
	end,
}
local function env(extra)
	local e = { game = game, workspace = Workspace, Vector2 = Vector2, UDim2 = UDim2, UDim = UDim, Enum = Enum, Instance = Instance, Color3 = Color3,
		task = { delay = function() end } }
	for key, value in extra or {} do
		e[key] = value
	end
	return setmetatable(e, { __index = _G })
end
local HudErgonomics = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/HudErgonomics.luau"), { environment = env() })()
local function loadLayout(path)
	return luau.load(fs.readFile(path), {
		environment = env({
			script = { Parent = { WaitForChild = function(_, name) return { Name = name } end } },
			require = function(module)
				assert(module.Name == "HudErgonomics", "MenuPanelLayout requires " .. tostring(module.Name))
				return HudErgonomics
			end,
		}),
	})()
end
local Layout = loadLayout("src/common/ReplicatedStorage/Shared/MenuPanelLayout.luau")
local Catalog = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/CosmeticCatalog.luau"), { environment = env() })()

-- A ScreenGui as the scripts read it.
local function mockGui(insets)
	local gui = { ScreenInsets = insets, Enabled = false, AbsoluteSize = Vector2.new(0, 0), Signals = {} }
	function gui:GetPropertyChangedSignal(name)
		self.Signals[name] = self.Signals[name] or signal()
		return self.Signals[name]
	end
	function gui:IsA(class)
		return class == "ScreenGui"
	end
	return gui
end

----------------------------------------------------------------------
-- Screens
----------------------------------------------------------------------
local PHONES = {
	Vector2.new(844, 390), Vector2.new(932, 430), Vector2.new(667, 375),
	Vector2.new(740, 360), Vector2.new(915, 412), Vector2.new(780, 360),
}
local TOP_BARS = { 36, 58 }
local NOTCHES = { 0, 47 } -- CoreUISafeInsets also leaves out a landscape phone's notch sides
local DESKTOPS = { { Vector2.new(1920, 1080), 58 }, { Vector2.new(1920, 1080), 36 }, { Vector2.new(2560, 1440), 58 } }

----------------------------------------------------------------------
-- The Backpack window: BackpackScript's own fit
----------------------------------------------------------------------
local source = fs.readFile(BACKPACK)
luau.compile(source)
luau.compile(fs.readFile("src/common/ReplicatedStorage/Shared/MenuPanelLayout.luau"))
local FIT_FROM, FIT_TO = "local authoredPanelSize = mainFrame.Size", "\nfitPanel()\n"
has(source, 'screenGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets', "the Backpack lays out in the safe area")
has(source, 'local MenuPanelLayout = require(Shared:WaitForChild("MenuPanelLayout"))', "BackpackScript uses the shared phone maths")
has(source, "{ Position = OPEN_POS }", "the Backpack still slides to OPEN_POS")
assert(not string.find(source, "\nlocal OPEN_POS = UDim2.new(0.5, 0, 0.48, 0)", 1, true), "a second OPEN_POS would hide the phone fit's place from show()")

-- Runs one version of fitPanel on a fresh copy of the authored window; returns what it drew.
local function runBackpackFit(src, real, safe, layout)
	local frame = real:Clone()
	local gui = mockGui(Enum.ScreenInsets.CoreUISafeInsets)
	gui.AbsoluteSize = safe
	local code = chunk(src, FIT_FROM, FIT_TO, "BackpackScript fitPanel") .. FIT_TO
		.. "return panelScale, function() return OPEN_POS end, panelAspect"
	local panelScale, openPos, shape = luau.load(code, {
		environment = env({ mainFrame = frame, screenGui = gui, MenuPanelLayout = layout }),
	})()
	local position = (openPos and openPos()) or UDim2.new(0.5, 0, 0.48, 0)
	-- The window as Roblox solves it: Size, then the UIAspectRatioConstraint, then the UIScale.
	local w, h = Layout.WindowSize(frame.Size, shape, safe.X, safe.Y)
	return {
		Frame = frame, Size = frame.Size, Position = position, Scale = panelScale.Scale, Shape = shape.AspectRatio,
		Width = w * panelScale.Scale, Height = h * panelScale.Scale, LayoutWidth = w, LayoutHeight = h,
	}
end
local backup = if fs.isFile(BACKUP) then fs.readFile(BACKUP) else nil
local oldLayout = loadLayout(if fs.isFile("output/FablePolish_20260922/backup_src/common/ReplicatedStorage/Shared/MenuPanelLayout.luau")
	then "output/FablePolish_20260922/backup_src/common/ReplicatedStorage/Shared/MenuPanelLayout.luau" else "src/common/ReplicatedStorage/Shared/MenuPanelLayout.luau")
if backup and not string.find(backup, "MenuPanelLayout", 1, true) then
	-- The old fitPanel reads no MenuPanelLayout; nothing to hand it.
	oldLayout = nil
end

local function whole(label, safe, fit, over, beside)
	local cy = fit.Position.Y.Scale * safe.Y + fit.Position.Y.Offset
	local cx = fit.Position.X.Scale * safe.X + fit.Position.X.Offset
	local top = cy - fit.Height / 2 - over * fit.Height
	local bottom = cy + fit.Height / 2
	local left = cx - fit.Width / 2 - beside * fit.Width
	local right = cx + fit.Width / 2 + beside * fit.Width
	assert(top >= -0.5 and bottom <= safe.Y + 0.5 and left >= -0.5 and right <= safe.X + 0.5,
		("%s: not whole in the %dx%d safe area (top %.1f, bottom %.1f, left %.1f, right %.1f)"):format(label, safe.X, safe.Y, top, bottom, left, right))
end

local starterGuis = {}
for _, place in PlaceFiles.Places do
	starterGuis[place.key] = rb.deserializePlace(fs.readFile(place.file)):GetService("StarterGui")
end
local realBackpack = starterGuis.World1.Backpack.MainFrame
local realRebirth = starterGuis.World1.Rebirth.Rebirth
for key, starterGui in starterGuis do
	for _, frame in { starterGui.Backpack.MainFrame, starterGui.Rebirth.Rebirth } do
		local shape = assert(frame:FindFirstChildOfClass("UIAspectRatioConstraint"), key .. ": " .. frame:GetFullName() .. " has no shape")
		assert(math.abs(shape.AspectRatio - ASPECT) < 1e-4 and shape.AspectType == Enum.AspectType.FitWithinMaxSize,
			key .. ": " .. frame:GetFullName() .. " is not the designer's 1.2795 window")
		assert(frame.Size == realBackpack.Size, key .. ": " .. frame:GetFullName() .. " is not 32% x 58.6%")
	end
end
local backpackOver, backpackBeside = Layout.Overhang(realBackpack)

print("Backpack.MainFrame on phones (safe area -> window, before -> after):")
for _, phone in PHONES do
	for _, topBar in TOP_BARS do
		for _, notch in NOTCHES do
			local safe = Vector2.new(phone.X - 2 * notch, phone.Y - topBar)
			local label = ("Backpack %dx%d bar %d notch %d"):format(phone.X, phone.Y, topBar, notch)
			local fit = runBackpackFit(source, realBackpack, safe, Layout)
			local aspect = fit.Width / fit.Height
			assert(math.abs(fit.Shape - ASPECT) < 1e-6, label .. ": the window's UIAspectRatioConstraint was rewritten to " .. fit.Shape)
			assert(math.abs(aspect / ASPECT - 1) <= TOLERANCE, ("%s: drawn %.3f to 1, not the designer's %.4f"):format(label, aspect, ASPECT))
			assert(fit.Height >= 0.8 * safe.Y, ("%s: only %.0f%% of the safe area's height"):format(label, 100 * fit.Height / safe.Y))
			assert(fit.Height <= 0.84 * safe.Y + 0.5 and fit.Width <= 0.94 * safe.X + 0.5, label .. ": bigger than the 94% x 84% box")
			whole(label, safe, fit, backpackOver, backpackBeside)
			if backup and notch == 0 and topBar == 58 then
				local before = runBackpackFit(backup, realBackpack, safe, oldLayout)
				print(("  %-9s safe %dx%d: %4.0fx%-4.0f (%.2f:1)  ->  %4.0fx%-4.0f (%.3f:1, %.0f%% of the height)"):format(
					("%dx%d"):format(phone.X, phone.Y), safe.X, safe.Y, before.Width, before.Height, before.Width / before.Height,
					fit.Width, fit.Height, aspect, 100 * fit.Height / safe.Y))
			end
		end
	end
end
-- Desktops: exactly what the designer's window drew before (Size, place, UIScale, shape).
for _, case in DESKTOPS do
	local view, topBar = case[1], case[2]
	local safe = Vector2.new(view.X, view.Y - topBar)
	local fit = runBackpackFit(source, realBackpack, safe, Layout)
	assert(fit.Size == realBackpack.Size, "desktop: the Backpack's Size changed")
	assert(fit.Position == UDim2.new(0.5, 0, 0.48, 0), "desktop: the Backpack's open place changed")
	assert(math.abs(fit.Shape - ASPECT) < 1e-6, "desktop: the Backpack's shape changed")
	if backup then
		local before = runBackpackFit(backup, realBackpack, safe, oldLayout)
		assert(math.abs(before.Scale - fit.Scale) < 1e-9 and before.Size == fit.Size, "desktop: the Backpack differs from before")
	end
end
print("PASS Backpack: 1.2795 to 1 on 6 phones x 2 top bars x 2 notch insets, 80%+ of the safe height, header whole on screen; desktops untouched")

----------------------------------------------------------------------
-- Rebirth: MenuPanelLayout.BindPhoneFit, as RebirthController calls it
----------------------------------------------------------------------
local rebirthController = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/RebirthController.client.luau")
has(rebirthController, "MenuPanelLayout.BindPhoneFit(gui, frame, OPEN_POS, CLOSED_POS, function(fit)", "RebirthController fits its window on phones")
local rebirthInsets = starterGuis.World1.Rebirth.ScreenInsets
local rebirthOver, rebirthBeside = Layout.Overhang(realRebirth)
local function runRebirthFit(view, topBar, touch, keyboard)
	camera.ViewportSize = view
	world.TopBar = topBar
	UserInputService.TouchEnabled = touch
	UserInputService.KeyboardEnabled = keyboard
	local frame = realRebirth:Clone()
	local gui = mockGui(rebirthInsets)
	local underTopBar = rebirthInsets == Enum.ScreenInsets.CoreUISafeInsets
	gui.AbsoluteSize = if underTopBar then Vector2.new(view.X, view.Y - topBar) else view
	local got = nil
	Layout.BindPhoneFit(gui, frame, UDim2.new(0.5, 0, 0.48, 0), UDim2.new(0.5, 0, 1.28, 0), function(fit)
		got = fit
	end)
	local shape = frame:FindFirstChildOfClass("UIAspectRatioConstraint")
	local w, h = Layout.WindowSize(frame.Size, shape, gui.AbsoluteSize.X, gui.AbsoluteSize.Y)
	return { Frame = frame, Fit = got, Width = w, Height = h, Shape = shape, Screen = gui.AbsoluteSize,
		TopInset = if underTopBar then 0 else topBar }
end
print("Rebirth.Rebirth on phones:")
for _, phone in PHONES do
	for _, topBar in TOP_BARS do
		local label = ("Rebirth %dx%d bar %d"):format(phone.X, phone.Y, topBar)
		local r = runRebirthFit(phone, topBar, true, false)
		assert(r.Shape and math.abs(r.Shape.AspectRatio - ASPECT) < 1e-6 and r.Shape.AspectType == Enum.AspectType.FitWithinMaxSize,
			label .. ": the window's UIAspectRatioConstraint changed")
		local aspect = r.Width / r.Height
		assert(math.abs(aspect / ASPECT - 1) <= TOLERANCE, ("%s: drawn %.3f to 1"):format(label, aspect))
		local room = r.Screen.Y - r.TopInset
		assert(r.Height >= 0.8 * room, ("%s: only %.0f%% of the room's height"):format(label, 100 * r.Height / room))
		assert(r.Width <= 0.94 * r.Screen.X + 0.5, label .. ": wider than 94% of the screen")
		local safe = Vector2.new(r.Screen.X, room)
		local centre = r.Fit.Open.Y.Scale * r.Screen.Y - r.TopInset
		whole(label, safe, { Width = r.Width, Height = r.Height, Position = UDim2.new(0.5, 0, centre / room, 0) }, rebirthOver, rebirthBeside)
		if topBar == 58 then
			print(("  %dx%d: %.0fx%.0f (%.3f:1, %.0f%% of the room under the top bar)"):format(phone.X, phone.Y, r.Width, r.Height, aspect, 100 * r.Height / room))
		end
	end
end
for _, case in DESKTOPS do
	local r = runRebirthFit(case[1], case[2], false, true)
	assert(r.Frame.Size == realRebirth.Size and r.Fit.Open == UDim2.new(0.5, 0, 0.48, 0), "desktop: Rebirth changed")
end
print("PASS Rebirth: its designer's 1.2795 to 1 kept by BindPhoneFit on 6 phones x 2 top bars, 80%+ of the room, whole under the top bar; desktops untouched")

----------------------------------------------------------------------
-- The Aura and Trail lists reach their last card
----------------------------------------------------------------------
has(source, "bindListCanvas(trailFrame)\nbindListCanvas(auraFrame)", "both lists follow their content")
has(source, "local grown = canvas * cards / 7", "addCatalogCards still grows the designer's canvas (modelled below)")
local releaseChunk = chunk(source, "local function releaseAuthoredCardHeight(itemFrame)", "\n-- A card shows its name", "releaseAuthoredCardHeight")
local phoneChunk = chunk(source, "local PHONE_CARD_SCALE = ", "\nlocal function bindListCanvas", "fitCardsForPhones")
local canvasChunk = chunk(source, "local function bindListCanvas(container)", "\nlocal function applyState", "bindListCanvas")
assert(not string.find(source, "AutomaticCanvasSize", 1, true), "the canvas is sized from the layout, not by AutomaticCanvasSize")

-- The list, its layout and its cards as Roblox lays them out. `scale` is every UIScale above.
local function listHarness(real, cards, panel, scale)
	local list = real:Clone()
	-- The window above it carries the UIScales (ResponsivePanelScale, a pop): MenuPanelLayout.ScaleChain reads them there.
	local window = Instance.new("Frame")
	window.Name = "MainFrame"
	local uiScale = Instance.new("UIScale")
	uiScale.Scale = scale
	uiScale.Parent = window
	list.Parent = window
	local template = nil
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			template = template or child
		end
	end
	for index = 1, cards - 7 do
		local card = template:Clone()
		card.Name = "Catalog" .. index
		card.Parent = list
	end
	local realLayout = list:FindFirstChildOfClass("UIListLayout")
	local listShape = list:FindFirstChildOfClass("UIAspectRatioConstraint")
	-- The list's own box inside the panel (its 1.41 shape), before any UIScale.
	local lw, lh = Layout.WindowSize(list.Size, listShape, panel.X, panel.Y)
	local function canvasHeight()
		return math.max(lh, list.CanvasSize.Y.Scale * lh + list.CanvasSize.Y.Offset)
	end
	local function cardBoxes()
		local canvas = canvasHeight()
		local pad = realLayout.Padding.Scale * canvas + realLayout.Padding.Offset
		local y, boxes = 0, {}
		local ordered = {}
		for _, child in list:GetChildren() do
			if child:IsA("Frame") and child.Visible then
				table.insert(ordered, child)
			end
		end
		for index, card in ordered do
			local shape = card:FindFirstChildOfClass("UIAspectRatioConstraint")
			local w, h = Layout.WindowSize(card.Size, shape, lw, canvas)
			if index > 1 then
				y += pad
			end
			table.insert(boxes, { Top = y, Bottom = y + h, Width = w })
			y += h
		end
		return boxes, y
	end
	local signals = { AbsoluteContentSize = signal(), AbsoluteSize = signal(), Visible = signal(), PhoneCardScale = signal() }
	local function proxy(inst, overrides)
		return setmetatable({}, {
			__index = function(_, key)
				local o = overrides[key]
				if o ~= nil then
					if type(o) == "table" and o.Get then
						return o.Get()
					end
					return o
				end
				local value = inst[key]
				if type(value) == "function" then
					return function(_, ...)
						return value(inst, ...)
					end
				end
				return value
			end,
			__newindex = function(_, key, value)
				inst[key] = value
			end,
		})
	end
	local layoutProxy = proxy(realLayout, {
		AbsoluteContentSize = { Get = function()
			local _, height = cardBoxes()
			return Vector2.new(lw * scale, height * scale)
		end },
		GetPropertyChangedSignal = function(_, name)
			return assert(signals[name], name)
		end,
	})
	local listProxy = proxy(list, {
		AbsoluteSize = { Get = function() return Vector2.new(lw * scale, lh * scale) end },
		FindFirstChildOfClass = function(_, class)
			if class == "UIListLayout" then
				return layoutProxy
			end
			return list:FindFirstChildOfClass(class)
		end,
		GetPropertyChangedSignal = function(_, name)
			return assert(signals[name], name)
		end,
		GetAttributeChangedSignal = function(_, name)
			return assert(signals[name], name)
		end,
	})
	return {
		List = list, Proxy = listProxy, Layout = realLayout, Width = lw, Height = lh, Boxes = cardBoxes, Canvas = canvasHeight, Signals = signals,
		Settle = function()
			for _ = 1, 8 do
				local before = tostring(list.CanvasSize) .. tostring(realLayout.Padding)
				signals.AbsoluteContentSize:Fire()
				if tostring(list.CanvasSize) .. tostring(realLayout.Padding) == before then
					return
				end
			end
			error("the list's canvas never settles")
		end,
	}
end

-- late: the list binds on a desktop window, which is then shrunk to phone height (isPhone()
-- turns true at 540 px): fitCardsForPhones runs after bindListCanvas and the gap must follow x0.72.
local function runList(real, cosmeticType, cards, panel, scale, phone, late)
	local h = listHarness(real, cards, panel, scale)
	local bindAsPhone = phone and not late
	UserInputService.TouchEnabled, UserInputService.KeyboardEnabled = bindAsPhone, not bindAsPhone
	camera.ViewportSize = if bindAsPhone then Vector2.new(844, 390) else Vector2.new(1920, 1080)
	local screenGui = mockGui(Enum.ScreenInsets.CoreUISafeInsets)
	local fns = luau.load(releaseChunk .. "\n" .. phoneChunk .. "\n" .. canvasChunk
		.. "\nreturn releaseAuthoredCardHeight, fitCardsForPhones, bindListCanvas", {
		environment = env({ screenGui = screenGui, MenuPanelLayout = Layout }),
	})
	local releaseCard, fitCardsForPhones, bindListCanvas = fns()
	-- wireSingleItem releases every card's authored height; addCatalogCards grows the canvas.
	local count = 0
	for _, card in h.List:GetChildren() do
		if card:IsA("Frame") then
			releaseCard(card)
			count += 1
		end
	end
	assert(count == cards, "the harness holds " .. count .. " cards")
	if cards > 7 then
		local canvas = h.List.CanvasSize.Y.Scale
		local grown = canvas * cards / 7
		h.List.CanvasSize = UDim2.new(0, 0, grown, 0)
		h.Layout.Padding = UDim.new(h.Layout.Padding.Scale * canvas / grown, 0)
	end
	-- Before: the canvas as the designer's numbers and the phone scale left it.
	fitCardsForPhones(h.List)
	local _, contentBefore = h.Boxes()
	local canvasBefore = h.Canvas()
	bindListCanvas(h.Proxy)
	h.Settle()
	if late then
		assert(h.List:GetAttribute("PhoneCardScale") == nil, "late case: the cards were scaled before the resize")
		camera.ViewportSize = Vector2.new(1280, 520)
		fitCardsForPhones(h.List)
		assert(h.List:GetAttribute("PhoneCardScale") == 0.72, "late case: the resize to 520 px did not scale the cards")
		h.Signals.PhoneCardScale:Fire()
		h.Settle()
	end
	local boxes, content = h.Boxes()
	local canvas = h.Canvas()
	local last = boxes[#boxes]
	local label = ("%s list, %d cards, list %.0fx%.0f, UIScale %.2f%s"):format(cosmeticType, cards, h.Width, h.Height, scale, if late then ", desktop shrunk to phone height" elseif phone then ", phone" else "")
	assert(#boxes == cards, label .. ": cards missing from the layout")
	assert(h.List.ScrollingDirection == Enum.ScrollingDirection.Y, label .. ": still scrolls sideways")
	assert(canvas >= content + 0.07 * h.Height - 0.5, ("%s: canvas %.0f for %.0f of cards, no room under the last"):format(label, canvas, content))
	assert(last.Bottom <= canvas - 0.07 * h.Height + 0.5, label .. ": the last card is not reachable with room under it")
	assert(canvas <= content + 0.14 * h.Height, ("%s: canvas %.0f runs far past the %.0f of cards"):format(label, canvas, content))
	-- The gap between cards stays the designer's share of the list (x0.72 on phones).
	local gap = h.Layout.Padding.Offset
	local want = 0.02 * 3 * (if phone then 0.72 else 1) * h.Height
	assert(h.Layout.Padding.Scale == 0 and math.abs(gap - want) <= 1, ("%s: gap %.1f px, the designer's is %.1f"):format(label, gap, want))
	-- The phone card scale still applies.
	if phone then
		assert(math.abs(last.Width / h.Width - 0.96153224 * 0.72) < 0.01, label .. ": phone cards lost PHONE_CARD_SCALE")
	end
	return { Before = canvasBefore, BeforeContent = contentBefore, Canvas = canvas, Content = content, Label = label, Gap = gap }
end

print("Aura / Trail lists (canvas vs cards, before -> after):")
for _, cosmeticType in { "Trail", "Aura" } do
	local real = nil
	for _, child in realBackpack:GetChildren() do
		if child.Name == cosmeticType and child:IsA("ScrollingFrame") then
			real = child
		end
	end
	assert(real, "no " .. cosmeticType .. " list")
	local catalogCards = #Catalog.GetSortedOwnableEntries(cosmeticType)
	assert(catalogCards >= 7, cosmeticType .. ": the catalog has fewer cards than the designer's list")
	for _, phone in PHONES do
		local safe = Vector2.new(phone.X, phone.Y - 58)
		local fit = runBackpackFit(source, realBackpack, safe, Layout)
		local panel = Vector2.new(fit.LayoutWidth, fit.LayoutHeight)
		for _, cards in { 7, catalogCards } do
			for _, extra in { 1, 0.88 } do -- ModalJuice-sized pop on top of ResponsivePanelScale
				local r = runList(real, cosmeticType, cards, panel, fit.Scale * extra, true)
				if extra == 1 and phone == PHONES[1] then
					print(("  %s: before %.0f px of canvas for %.0f px of cards -> %.0f for %.0f"):format(r.Label, r.Before, r.BeforeContent, r.Canvas, r.Content))
				end
			end
		end
	end
	for _, case in DESKTOPS do
		local safe = Vector2.new(case[1].X, case[1].Y - case[2])
		local fit = runBackpackFit(source, realBackpack, safe, Layout)
		local r = runList(real, cosmeticType, catalogCards, Vector2.new(fit.LayoutWidth, fit.LayoutHeight), fit.Scale, false)
		if case == DESKTOPS[1] then
			print(("  %s: before %.0f px of canvas for %.0f px of cards -> %.0f for %.0f"):format(r.Label, r.Before, r.BeforeContent, r.Canvas, r.Content))
			-- The same window shrunk to phone height after the lists bound: gap follows the x0.72 cards.
			for _, cards in { 7, catalogCards } do
				local late = runList(real, cosmeticType, cards, Vector2.new(fit.LayoutWidth, fit.LayoutHeight), fit.Scale, true, true)
				print(("  %s: gap %.1f px, canvas %.0f for %.0f"):format(late.Label, late.Gap, late.Canvas, late.Content))
			end
		end
	end
end
print("PASS lists: every Aura / Trail card reachable with room under the last (7 and every catalog card, phones and desktops, under UIScale 1 and a pop), vertical only, designer's gap and phone card scale kept, also when a desktop window shrinks to phone height after binding")
print("ALL POLISH MOBILE PANEL CHECKS PASSED")
