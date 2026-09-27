-- test_opt6_mobile_panels.luau
-- The designer's menus on phones (2026-09-21: "some UIs are tiny on phones", the Time Gift
-- first: its 15 day cards were 40 px, their Claim buttons 29 x 8 px and their texts 6 px on an
-- 812 x 375 phone). The menus share one window, 32% x 58.6% of the screen at 1.28 to 1; on a
-- compact touch screen MenuPanelLayout.BindPhoneFit now draws it bigger, its shape kept.
--
-- Runs the real MenuPanelLayout (PhoneScreen, PhoneFit, BindPhoneFit) with the real
-- HudErgonomics.IsCompact on the real authored windows of the places, on four landscape and
-- four portrait phones (Worlds 2 and 3 turn with the phone) under a 36 or 58 px top bar, a
-- tablet and four desktops, and checks: most of the room under the top bar used, the window
-- and its header whole inside it, wholly below the screen when closed, the Time Gift's cards
-- 44 px or more, desktops untouched (not one write), a new fit when the screen changes (at rest
-- and mid-slide), ModalJuice's UIScale left alone. Then the Time Gift's own open / close code,
-- the Daily Login's shrink, the Shop's category bar, AfkRewardsController's own fit of the
-- off-centre AFK Earnings panel and the wiring of every controller. Prints each window's size
-- and smallest button before and after.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")
local PlaceFiles = require("./place_files")

local Vector2, UDim2, Enum = rb.Vector2, rb.UDim2, rb.Enum
local UI = "src/common/StarterPlayer/StarterPlayerScripts/UI/"
local EPS = 0.01

local function has(source, needle, message)
	assert(string.find(source, needle, 1, true), message .. "\n  (missing: " .. needle .. ")")
end
local function get(inst, prop, default)
	local ok, value = pcall(function()
		return inst[prop]
	end)
	if ok and value ~= nil then
		return value
	end
	return default
end

----------------------------------------------------------------------
-- The real MenuPanelLayout, in a world the test controls
----------------------------------------------------------------------
local function signal()
	local s = { handlers = {} }
	function s:Connect(fn)
		table.insert(self.handlers, fn)
		local handlers = self.handlers
		return {
			Disconnect = function()
				local index = table.find(handlers, fn)
				if index then
					table.remove(handlers, index)
				end
			end,
		}
	end
	function s:Fire(...)
		for _, fn in table.clone(self.handlers) do
			fn(...)
		end
	end
	return s
end

local world = { TopBar = 58, Delayed = {} }
local camera = { ViewportSize = Vector2.new(812, 375), Signals = { ViewportSize = signal() } }
function camera:GetPropertyChangedSignal(name)
	return assert(self.Signals[name], name)
end
local workspaceSignals = { CurrentCamera = signal() }
local Workspace = { CurrentCamera = camera }
function Workspace:GetPropertyChangedSignal(name)
	return assert(workspaceSignals[name], name)
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
local function moduleEnv(extra)
	local env = {
		game = game,
		Vector2 = Vector2,
		UDim2 = UDim2,
		Enum = Enum,
		task = {
			delay = function(_, fn)
				table.insert(world.Delayed, fn)
			end,
		},
	}
	for key, value in extra or {} do
		env[key] = value
	end
	return setmetatable(env, { __index = _G })
end
local HudErgonomics = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/HudErgonomics.luau"), { environment = moduleEnv() })()
local Layout = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/MenuPanelLayout.luau"), {
	environment = moduleEnv({
		script = { Parent = { WaitForChild = function(_, name) return { Name = name } end } },
		require = function(module)
			assert(module.Name == "HudErgonomics", "MenuPanelLayout requires " .. tostring(module.Name))
			return HudErgonomics
		end,
	}),
})()

-- Puts the test's world on a screen: viewport, top bar, touch and keyboard.
local function setScreen(width, height, topBar, touch, keyboard)
	camera.ViewportSize = Vector2.new(width, height)
	world.TopBar = topBar
	UserInputService.TouchEnabled = touch
	UserInputService.KeyboardEnabled = keyboard
end
local function safeSize(insets, width, height, topBar)
	if insets == Enum.ScreenInsets.CoreUISafeInsets then
		return width, height - topBar
	end
	return width, height
end

----------------------------------------------------------------------
-- The windows, as the places author them
----------------------------------------------------------------------
-- `Block`: the controller hands MenuPanelLayout.PhoneBlock to BindPhoneFit (2026-09-26, owner:
-- "too low / HUGE, make them a bit smaller"): window and header together PhoneBlock.Share of the
-- room, raised by PhoneBlock.Lift, instead of the window alone at 84% of it.
local PANELS = {
	{ Gui = "TimeGift", Frame = "TimeGift", Controller = "TimeGiftController", Block = true },
	{ Gui = "Shop", Frame = "Shop", Controller = "ShopController" },
	{ Gui = "Shop", Frame = "Gift", Controller = "ShopController" },
	{ Gui = "DailyReward", Frame = "Days31", Controller = "DailyRewardController" },
	{ Gui = "Abilities", Frame = "Panel", Controller = "AbilitiesPanel" },
	{ Gui = "Rebirth", Frame = "Rebirth", Controller = "RebirthController" },
	{ Gui = "Evolve", Frame = "Evolve", Controller = "EvolveController" },
	{ Gui = "Worlds", Frame = "Worlds", Controller = "WorldsController" },
	{ Gui = "StageTeleport", Frame = "StageTeleport", Controller = "TeleportController" },
	{ Gui = "Update Logs", Frame = "Title", Controller = "UpdateLogsController" },
	-- Update 4: the designer's uineww.rbxm windows the build puts in StarterGui.
	{ Gui = "Community rewards", Frame = "Community rewards", Controller = "CommunityRewardsController", Block = true },
	{ Gui = "Streak Rewards", Frame = "Streak Rewards", Controller = "StreakRewardsController", Block = true },
	{ Gui = "Playtime Boost", Frame = "Playtime Boost", Controller = "PlaytimeBoostController", Block = true },
}

local places = {}
for _, place in PlaceFiles.Places do
	places[place.key] = rb.deserializePlace(fs.readFile(place.file)):GetService("StarterGui")
end
-- What the fit reads of a window: its Size, its shape and its direct children's boxes.
local function signature(frame)
	local shape = frame:FindFirstChildOfClass("UIAspectRatioConstraint")
	local parts = { tostring(frame.Size), tostring(frame.Position), shape and ("%.5f %s"):format(shape.AspectRatio, tostring(shape.AspectType)) or "-" }
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			table.insert(parts, ("%s %s %s %s %s"):format(child.Name, tostring(child.Size), tostring(child.Position), tostring(child.AnchorPoint), tostring(child.Visible)))
		end
	end
	table.sort(parts)
	return table.concat(parts, "|")
end
for _, panel in PANELS do
	local reference = places.World1[panel.Gui][panel.Frame]
	panel.Real = reference
	panel.Insets = places.World1[panel.Gui].ScreenInsets
	for key, starterGui in places do
		local frame = assert(starterGui:FindFirstChild(panel.Gui) and starterGui[panel.Gui]:FindFirstChild(panel.Frame), key .. " has no " .. panel.Gui .. "." .. panel.Frame)
		assert(signature(frame) == signature(reference), key .. ": " .. panel.Gui .. "." .. panel.Frame .. " differs from World 1's (the numbers below stand for all three places)")
	end
end

-- A stand-in for a real window, as BindPhoneFit sees it: every write to Size is counted.
local function mockWindow(real)
	local children = {}
	for _, child in real:GetChildren() do
		if child:IsA("GuiObject") then
			table.insert(children, {
				Name = child.Name, Visible = get(child, "Visible", true), Size = child.Size, Position = child.Position, AnchorPoint = child.AnchorPoint,
				IsA = function(_, class) return class == "GuiObject" end,
			})
		end
	end
	-- ModalJuice's pop (and on consoles ConsolePanelSupport's fit) hang a UIScale on the window.
	local juice = { Name = "ModalJuiceScale", ClassName = "UIScale", Scale = 0.88, IsA = function(_, class) return class == "UIScale" end }
	table.insert(children, juice)
	local shape = real:FindFirstChildOfClass("UIAspectRatioConstraint")
	local state = { Size = real.Size, Position = real.Position, Visible = true, Writes = 0, Juice = juice }
	local methods = {}
	function methods:FindFirstChildOfClass(class)
		return if class == "UIAspectRatioConstraint" then shape else nil
	end
	function methods:GetChildren()
		return table.clone(children)
	end
	return setmetatable({}, {
		__index = function(_, key)
			if methods[key] then
				return methods[key]
			end
			return state[key]
		end,
		__newindex = function(_, key, value)
			if key == "Size" then
				state.Writes += 1
			end
			state[key] = value
		end,
	}), children
end
local function mockGui(insets, width, height)
	local signals = { AbsoluteSize = signal() }
	local gui = { Enabled = false, ScreenInsets = insets, AbsoluteSize = Vector2.new(width, height), Signals = signals }
	function gui:GetPropertyChangedSignal(name)
		return assert(signals[name], name)
	end
	return gui
end

-- Binds `panel` on a screen; returns the window, its ScreenGui and the last fit handed over.
local function bind(panel, width, height, topBar, touch, keyboard)
	setScreen(width, height, topBar, touch, keyboard)
	local sw, sh = safeSize(panel.Insets, width, height, topBar)
	local gui = mockGui(panel.Insets, sw, sh)
	local frame = mockWindow(panel.Real)
	local open, closed = panel.Real.Position, UDim2.new(panel.Real.Position.X.Scale, panel.Real.Position.X.Offset, 1.28, 0)
	local result = { Calls = 0 }
	result.Refit = Layout.BindPhoneFit(gui, frame, open, closed, function(fit)
		result.Fit = fit
		result.Calls += 1
	end, nil, if panel.Block then Layout.PhoneBlock else nil)
	return frame, gui, result, open, closed
end

----------------------------------------------------------------------
-- Pixel boxes of a window and of everything in it
----------------------------------------------------------------------
local function fitAspect(holder, w, h)
	local shape = holder:FindFirstChildOfClass("UIAspectRatioConstraint")
	if not shape then
		return w, h
	end
	-- (w, h) as the scale of a 1 x 1 screen: UDim2 offsets would round the pixels.
	return Layout.WindowSize(UDim2.fromScale(w, h), shape, 1, 1)
end
-- Every GuiObject under `root` drawn at `w` x `h`: { Inst, W, H }. Grid cells take the
-- UIGridLayout's CellSize (and its shape); a scrolling list's children size on its canvas.
local function resolveTree(root, w, h)
	local out = {}
	local function visit(inst, width, height)
		table.insert(out, { Inst = inst, W = width, H = height })
		local cw, ch = width, height
		if inst.ClassName == "ScrollingFrame" then
			local canvas = inst.CanvasSize
			cw = math.max(width, canvas.X.Scale * width + canvas.X.Offset)
			ch = math.max(height, canvas.Y.Scale * height + canvas.Y.Offset)
		end
		local grid = inst:FindFirstChildOfClass("UIGridLayout")
		local cellW, cellH
		if grid then
			cellW, cellH = fitAspect(grid, grid.CellSize.X.Scale * width + grid.CellSize.X.Offset, grid.CellSize.Y.Scale * height + grid.CellSize.Y.Offset)
		end
		for _, child in inst:GetChildren() do
			if child:IsA("GuiObject") then
				if grid then
					visit(child, cellW, cellH)
				else
					local sw, sh = child.Size.X.Scale * cw + child.Size.X.Offset, child.Size.Y.Scale * ch + child.Size.Y.Offset
					sw, sh = fitAspect(child, sw, sh)
					visit(child, sw, sh)
				end
			end
		end
	end
	visit(root, w, h)
	return out
end
-- How far the window's direct children reach past its box, in pixels (their shapes applied).
local function reach(real, w, h)
	local top, bottom, left, right = 0, 0, 0, 0
	for _, child in real:GetChildren() do
		if child:IsA("GuiObject") and get(child, "Visible", true) then
			local cw, ch = fitAspect(child, child.Size.X.Scale * w + child.Size.X.Offset, child.Size.Y.Scale * h + child.Size.Y.Offset)
			local cx, cy = child.Position.X.Scale * w + child.Position.X.Offset, child.Position.Y.Scale * h + child.Position.Y.Offset
			top = math.max(top, -(cy - child.AnchorPoint.Y * ch))
			bottom = math.max(bottom, cy + (1 - child.AnchorPoint.Y) * ch - h)
			left = math.max(left, -(cx - child.AnchorPoint.X * cw))
			right = math.max(right, cx + (1 - child.AnchorPoint.X) * cw - w)
		end
	end
	return top, bottom, left, right
end
-- The smallest button of a window drawn at w x h (its shorter side), and the Time Gift's day
-- cards (the whole card claims on touch screens: TimeGiftController's TapArea).
local function targets(real, w, h)
	local smallest, cards = nil, {}
	for _, entry in resolveTree(real, w, h) do
		local inst = entry.Inst
		if inst:IsA("GuiButton") and get(inst, "Visible", true) then
			local side = math.min(entry.W, entry.H)
			if not smallest or side < smallest.Side then
				smallest = { Side = side, W = entry.W, H = entry.H, Name = inst.Name }
			end
		end
		if inst.Parent and inst.Parent.Name == "Frame" and inst.Parent.Parent == real and tonumber(inst.Name) then
			table.insert(cards, math.min(entry.W, entry.H))
		end
	end
	table.sort(cards)
	return smallest, cards[1]
end

----------------------------------------------------------------------
-- 1. Phones, a tablet and desktops, every window
----------------------------------------------------------------------
local PHONES = { { 812, 375 }, { 740, 360 }, { 896, 414 }, { 667, 375 } }
-- World 1 keeps phones in landscape (its StarterGui.ScreenOrientation is LandscapeSensor), but
-- Worlds 2 and 3 turn with the phone (Sensor): portrait phones too.
local PORTRAIT_PHONES = { { 375, 812 }, { 360, 740 }, { 414, 896 }, { 320, 568 } }
local EVERY_PHONE = table.clone(PHONES)
for _, phone in PORTRAIT_PHONES do
	table.insert(EVERY_PHONE, phone)
end
local DESKTOPS = { { 1920, 1080 }, { 1366, 768 }, { 1280, 720 }, { 1000, 600 } }
-- Printed below: every window on an 812 x 375 phone and on a 375 x 812 one.
local report = { [812] = {}, [375] = {} }
for _, panel in PANELS do
	local label = panel.Gui .. "." .. panel.Frame
	-- Phones in landscape and in portrait, both top bars.
	for _, phone in EVERY_PHONE do
		for _, topBar in { 36, 58 } do
			local width, height = phone[1], phone[2]
			local frame, gui, result = bind(panel, width, height, topBar, true, false)
			local fit = result.Fit
			local sw, sh = safeSize(panel.Insets, width, height, topBar)
			local topInset = if panel.Insets == Enum.ScreenInsets.CoreUISafeInsets then 0 else topBar
			local room = sh - topInset
			local w0, h0 = Layout.WindowSize(panel.Real.Size, panel.Real:FindFirstChildOfClass("UIAspectRatioConstraint"), sw, sh)
			local w, h = Layout.WindowSize(frame.Size, panel.Real:FindFirstChildOfClass("UIAspectRatioConstraint"), sw, sh)
			local where = ("%s on %dx%d, top bar %d"):format(label, width, height, topBar)
			if panel.Block then
				assert(fit.Grow > 1 and frame.Writes == 1, where .. ": drawn bigger than the designer's (x" .. fit.Grow .. ")")
			else
				assert(fit.Grow > 1.25 and frame.Writes == 1, where .. ": drawn bigger (x" .. fit.Grow .. ")")
			end
			assert(math.abs(w - fit.Width) < 0.05 and math.abs(h - fit.Height) < 0.05, where .. ": the Size written is the size fitted")
			assert(math.abs(w / h - w0 / h0) < 1e-3, where .. ": its shape is kept")
			local top, bottom, left, right = reach(panel.Real, w, h)
			if panel.Block and width > height then
				-- 2026-09-26: window and header PhoneBlock.Share of the room (the width binds
				-- first on none of these phones), the block PhoneBlock.Lift of it above the middle.
				local share, lift = Layout.PhoneBlock.Share, Layout.PhoneBlock.Lift
				local above = Layout.Overhang(frame)
				local block = h * (1 + above)
				assert(math.abs(block - share * room) < 0.5, ("%s: window and header %.0f px, %.0f%% of the %.0f px room"):format(where, block, 100 * share, room))
				local cy = fit.Open.Y.Scale * sh + fit.Open.Y.Offset
				local blockTop = cy - h / 2 - above * h - topInset
				local blockBottom = room - (cy + h / 2 - topInset)
				assert(math.abs((blockBottom - blockTop) - 2 * lift * room) < 0.5, ("%s: raised %.0f%% of the room (%.1f px above, %.1f px below)"):format(where, 100 * lift, blockTop, blockBottom))
			elseif width > height then
				assert(h >= 0.8 * room, ("%s: uses most of the room under the top bar (%.0f of %.0f px)"):format(where, h, room))
			else
				-- Upright, the width binds: the window and what stands past its sides fill it.
				local across = w + 2 * math.max(left, right)
				assert(across >= 0.85 * sw, ("%s: uses most of the width (%.0f of %d px)"):format(where, across, sw))
			end
			local cx = fit.Open.X.Scale * sw + fit.Open.X.Offset
			local cy = fit.Open.Y.Scale * sh + fit.Open.Y.Offset
			assert(cy - h / 2 - top >= topInset + Layout.PhoneMargin - EPS, ("%s: header under the top bar (its top at %.1f px, the top bar ends at %d)"):format(where, cy - h / 2 - top, topInset))
			assert(cy + h / 2 + bottom <= sh - Layout.PhoneMargin + EPS, where .. ": whole above the bottom edge")
			assert(cx - w / 2 - left >= 0 and cx + w / 2 + right <= sw, where .. ": whole across the screen")
			assert(w <= Layout.PhoneWidthShare * sw + EPS, where .. ": inside 94% of the width")
			local closedTop = fit.Closed.Y.Scale * sh + fit.Closed.Y.Offset - h / 2 - top
			assert(closedTop >= sh - EPS, where .. ": closed, it is wholly below the screen")
			assert(fit.Open.X == panel.Real.Position.X, where .. ": it stays centred across")
			local before, cardBefore = targets(panel.Real, w0, h0)
			local after, cardAfter = targets(panel.Real, w, h)
			if panel.Gui ~= "TimeGift" then
				-- (the Community window's numbered steps are no day cards)
				cardBefore, cardAfter = nil, nil
			end
			if cardAfter then
				assert(cardAfter >= 44, ("%s: a Time Gift day card is %.1f px, under 44"):format(where, cardAfter))
			end
			if report[width] and topBar == 58 then
				table.insert(report[width], ("%-26s %4.0fx%-4.0f -> %4.0fx%-4.0f (x%.2f)  smallest button %2.0fx%-2.0f -> %2.0fx%-2.0f (%s)%s"):format(
					label, w0, h0, w, h, fit.Grow, before.W, before.H, after.W, after.H, after.Name,
					if cardAfter then ("  day card %.0f -> %.0f px"):format(cardBefore, cardAfter) else ""))
			end
		end
	end
	-- A tablet without a keyboard: the window as big as on a 1080p desktop, no bigger (a
	-- PhoneBlock window: no bigger either, and window and header inside its share of the room).
	do
		local frame, _, result = bind(panel, 1024, 768, 58, true, false)
		local sw, sh = safeSize(panel.Insets, 1024, 768, 58)
		local _, h = Layout.WindowSize(frame.Size, panel.Real:FindFirstChildOfClass("UIAspectRatioConstraint"), sw, sh)
		local _, desktop = Layout.WindowSize(panel.Real.Size, panel.Real:FindFirstChildOfClass("UIAspectRatioConstraint"), 1920, 1080)
		if panel.Block then
			local room = sh - (if panel.Insets == Enum.ScreenInsets.CoreUISafeInsets then 0 else 58)
			local above = Layout.Overhang(frame)
			assert(result.Fit.Grow > 1 and h <= desktop + 0.05 and h * (1 + above) <= Layout.PhoneBlock.Share * room + 0.05,
				("%s on a 1024x768 tablet: %.1f px tall (1080p: %.1f), header included %.1f of %.1f px"):format(label, h, desktop, h * (1 + above), room))
		else
			assert(result.Fit.Grow > 1 and math.abs(h - desktop) < 0.05, ("%s on a 1024x768 tablet: %.1f px tall, its 1080p height is %.1f"):format(label, h, desktop))
		end
	end
	-- Desktops (a mouse), a touch laptop with a keyboard, a tablet with its keyboard: untouched.
	local untouched = {}
	for _, desktop in DESKTOPS do
		table.insert(untouched, { desktop[1], desktop[2], false, true })
	end
	table.insert(untouched, { 1920, 1080, true, true })
	table.insert(untouched, { 1024, 768, true, true })
	for _, case in untouched do
		for _, topBar in { 36, 58 } do
			local frame, _, result, open, closed = bind(panel, case[1], case[2], topBar, case[3], case[4])
			local where = ("%s on %dx%d (touch %s, keyboard %s)"):format(label, case[1], case[2], tostring(case[3]), tostring(case[4]))
			assert(frame.Writes == 0 and frame.Size == panel.Real.Size, where .. ": the designer's Size, not one write")
			assert(result.Fit.Grow == 1 and result.Fit.Open == open and result.Fit.Closed == closed, where .. ": the controller's own positions")
		end
	end
end
for _, width in { 812, 375 } do
	print(("Phone %s under a 58 px top bar, before -> after:"):format(if width == 812 then "812x375" else "375x812 (portrait)"))
	for _, line in report[width] do
		print("  " .. line)
	end
end
print("PASS every window: bigger on 4 landscape and 4 portrait phones x 2 top bars (shape kept, 80%+ of the room or 85%+ of the width upright; the PhoneBlock windows - Time Gift, Community, Streak, Playtime Boost - window and header 80% of the room, raised 4% of it; header under the top bar, whole on screen, closed below it), 1080p size (or less) on a keyboardless tablet, untouched on 4 desktops, a touch laptop and a tablet with a keyboard; the three places author them alike")

----------------------------------------------------------------------
-- 2. Over time: a new screen, at rest, mid-slide, never laid out, ModalJuice
----------------------------------------------------------------------
do
	local panel = PANELS[1]
	local frame, gui, result = bind(panel, 812, 375, 58, true, false)
	local first = result.Fit
	gui.Enabled = true
	frame.Position = first.Open
	-- Every phone puts the window at the same scale (it fills 84% of the room there): another
	-- phone only resizes it.
	setScreen(667, 375, 36, true, false)
	gui.AbsoluteSize = Vector2.new(667, 375 - 36)
	camera.Signals.ViewportSize:Fire()
	assert(result.Fit.Grow ~= first.Grow and frame.Writes == 2 and result.Fit.Open == first.Open, "Another phone: a new size, the same place")
	-- A tablet-sized screen (a resized window, a split screen): refitted, and the open window
	-- at rest moves to its new place.
	setScreen(1024, 768, 58, true, false)
	gui.AbsoluteSize = Vector2.new(1024, 768 - 58)
	camera.Signals.ViewportSize:Fire()
	local second = result.Fit
	assert(second.Grow ~= first.Grow and frame.Writes == 3 and second.Open ~= first.Open, "A new screen, a new fit")
	assert(frame.Position == second.Open, "The open window at rest moves to its new place")
	-- Mid-slide: nothing moves under the tween; once it has ended at the old place, it moves.
	frame.Position = UDim2.new(0.5, 0, 0.9, 0)
	table.clear(world.Delayed)
	setScreen(812, 375, 58, true, false)
	gui.AbsoluteSize = Vector2.new(812, 375 - 58)
	gui.Signals.AbsoluteSize:Fire()
	local third = result.Fit
	assert(frame.Position == UDim2.new(0.5, 0, 0.9, 0), "Mid-slide, the tween keeps the window")
	assert(#world.Delayed == 1, "...and it is looked at again after the slide")
	frame.Position = second.Open -- where the running tween ends
	world.Delayed[1]()
	assert(frame.Position == third.Open, "The slide ended at the old place: it moves to the new one")
	-- Closed windows are not moved: the controller slides them from the new positions.
	gui.Enabled = false
	frame.Position = third.Closed
	setScreen(740, 360, 58, true, false)
	gui.AbsoluteSize = Vector2.new(740, 360 - 58)
	gui.Signals.AbsoluteSize:Fire()
	assert(frame.Position == third.Closed, "A closed window stays where the controller left it")
	-- A camera swapped for another one is followed.
	local oldCamera = camera
	local newCamera = { ViewportSize = Vector2.new(896, 414), Signals = { ViewportSize = signal() } }
	newCamera.GetPropertyChangedSignal = oldCamera.GetPropertyChangedSignal
	Workspace.CurrentCamera = newCamera
	workspaceSignals.CurrentCamera:Fire()
	local calls = result.Calls
	newCamera.Signals.ViewportSize:Fire()
	assert(result.Calls == calls + 1, "The new camera's viewport is followed")
	Workspace.CurrentCamera = oldCamera
	workspaceSignals.CurrentCamera:Fire()
	-- ModalJuice's UIScale: never touched (its pop keeps scaling the fitted window).
	local _, children = mockWindow(panel.Real)
	assert(frame.Juice.Scale == 0.88, "ModalJuice's UIScale is left alone")
	assert(#children > 0, "(the stand-in has children)")
	-- A ScreenGui never laid out yet (AbsoluteSize 0 x 0): the screen less the top bar.
	setScreen(812, 375, 58, true, false)
	local blank = mockGui(panel.Insets, 0, 0)
	local screen = Layout.PhoneScreen(blank)
	assert(screen.Width == 812 and screen.Height == 375 - 58 and screen.TopInset == 0 and screen.Compact, "Not laid out yet: the camera, under the top bar")
	local device = Layout.PhoneScreen(mockGui(Enum.ScreenInsets.DeviceSafeInsets, 812, 375))
	assert(device.Height == 375 and device.TopInset == 58, "A ScreenGui that runs under the top bar keeps its window below it")
	camera.ViewportSize = Vector2.new(0, 0)
	assert(Layout.PhoneScreen(mockGui(panel.Insets, 0, 0)) == nil, "No screen yet: nothing to fit")
	-- A tall header (none of today's windows has one) makes the window smaller, never taller
	-- than the room, header included.
	for _, topInset in { 0, 58 } do
		local phone = { Width = 812, Height = 375, TopInset = topInset, Compact = true }
		local fit = Layout.PhoneFit(phone, { Width = 200, Height = 150, Header = 0.4 })
		local room = 375 - topInset
		local top = fit.OpenY * 375 - fit.Height / 2 - 0.4 * fit.Height
		assert(fit.Height < Layout.PhoneHeightShare * room and top >= topInset + Layout.PhoneMargin - EPS and fit.OpenY * 375 + fit.Height / 2 <= 375 - Layout.PhoneMargin + EPS,
			"A tall header counts: window and header stay whole in the room")
	end
	print("PASS over time: a new screen refits; an open window at rest moves at once, one mid-slide once the slide ends; closed ones stay; a new camera is followed; ModalJuice's UIScale untouched; a ScreenGui not laid out yet uses the camera less the top bar")
end

----------------------------------------------------------------------
-- 3. The Time Gift's own open and close, and its cards on touch screens
----------------------------------------------------------------------
do
	local source = fs.readFile(UI .. "TimeGiftController.client.luau")
	local a = assert(string.find(source, "local OPEN_POS = UDim2.new(0.5, 0, 0.48, 0)", 1, true), "TimeGift: OPEN_POS")
	local b = assert(string.find(source, "if closeBtn:IsA(\"GuiButton\") then", a, true), "TimeGift: end of open/close")
	local chunk = string.sub(source, a, b - 1) .. "\nreturn { open = openPanel, close = closePanel }"
	local panel = PANELS[1]
	for _, case in { { 812, 375, true, false }, { 1920, 1080, false, true } } do
		setScreen(case[1], case[2], 58, case[3], case[4])
		local sw, sh = safeSize(panel.Insets, case[1], case[2], 58)
		local ui = mockGui(panel.Insets, sw, sh)
		ui.FindFirstChild = function() return nil end
		local mainFrame = mockWindow(panel.Real)
		local tweens = {}
		local delays = {}
		local fired = {}
		local controller = luau.load(chunk, {
			environment = setmetatable({
				MenuPanelLayout = Layout,
				ui = ui,
				mainFrame = mainFrame,
				isOpen = false,
				UDim2 = UDim2,
				Enum = Enum,
				TweenInfo = { new = function() return {} end },
				TweenService = { Create = function(_, target, _, goal)
					local tween = { Target = target, Goal = goal }
					function tween:Play() end
					function tween:Cancel() end
					table.insert(tweens, tween)
					return tween
				end },
				task = { delay = function(_, fn) table.insert(delays, fn) end },
				PlaytimeRewardsRequest = { FireServer = function(_, action) table.insert(fired, action) end },
			}, { __index = _G }),
		})()
		local grown = case[3]
		controller.open()
		local openGoal = tweens[#tweens].Goal.Position
		assert(ui.Enabled and mainFrame.Visible, "Time Gift opens")
		if grown then
			local above, beside = Layout.Overhang(mainFrame)
			local fitted = Layout.WindowFit(ui, panel.Real.Size, panel.Real:FindFirstChildOfClass("UIAspectRatioConstraint"), above, beside, nil, Layout.PhoneBlock)
			assert(math.abs(openGoal.Y.Scale - fitted.OpenY) < 1e-6 and mainFrame.Size ~= panel.Real.Size, "Phone: it slides to its fitted (PhoneBlock) place, drawn bigger")
			assert(mainFrame.Position.Y.Scale > 1.4, "...from wholly below the screen")
		else
			assert(openGoal == UDim2.new(0.5, 0, 0.48, 0) and mainFrame.Size == panel.Real.Size, "Desktop: the designer's place and size")
			assert(mainFrame.Position == UDim2.new(0.5, 0, 1.28, 0), "...from the designer's closed place")
		end
		controller.close()
		local closeGoal = tweens[#tweens].Goal.Position
		if grown then
			local w, h = Layout.WindowSize(mainFrame.Size, panel.Real:FindFirstChildOfClass("UIAspectRatioConstraint"), sw, sh)
			assert(closeGoal.Y.Scale * sh - h / 2 - reach(panel.Real, w, h) >= sh - EPS, "Phone: it slides away wholly below the screen")
		else
			assert(closeGoal == UDim2.new(0.5, 0, 1.28, 0), "Desktop: it slides away to the designer's closed place")
		end
		for _, fn in delays do fn() end
		assert(ui.Enabled == false and mainFrame.Visible == false, "...and is hidden once closed")
		assert(fired[1] == "Refresh", "(opening asks for its state)")
	end
	has(source, "if UserInputService.TouchEnabled then\n\t\t\tlocal tapArea = Instance.new(\"TextButton\")", "Touch screens: the whole day card claims")
	has(source, "tapArea.Size = UDim2.fromScale(1, 1)", "...all of it")
	has(source, "tapArea.Activated:Connect(onClaim)", "...with the Claim button's own handler (it claims only a ready day)")
	has(source, "tapArea.ZIndex = button.ZIndex + 1", "...drawn over the Claim button")
	print("PASS Time Gift: its own open/close slides between the fitted places on a phone and the designer's on a desktop; on touch screens the whole day card claims")
end

----------------------------------------------------------------------
-- 4. The Daily Login keeps the phone size (its own shrink stays for everything else)
----------------------------------------------------------------------
do
	local source = fs.readFile(UI .. "DailyRewardController.client.luau")
	local a = assert(string.find(source, "-- The panel always stays whole on the screen", 1, true))
	local b = assert(string.find(source, "-- The Claim button is always on top", a, true))
	local fitChunk = string.sub(source, a, b - 1) .. "\nreturn fitOnScreen, function(value) phoneGrow = value end"
	local noSignal = { Connect = function() end }
	local screen = Vector2.new(812, 317)
	local frame = { Size = UDim2.new(0.32, 0, 0.586, 0), AbsoluteSize = Vector2.new(238, 186) }
	function frame:GetPropertyChangedSignal() return noSignal end
	local gui = { AbsoluteSize = screen }
	function gui:GetPropertyChangedSignal() return noSignal end
	local fitOnScreen, setGrow = luau.load(fitChunk, {
		environment = setmetatable({ daysFrame = frame, gui = gui, UDim2 = UDim2 }, { __index = _G }),
	})()
	-- The phone fit wrote x1.43 and hands the growth over; the shrink must not undo it.
	frame.Size = UDim2.new(0.32 * 1.43, 0, 0.586 * 1.43, 0)
	setGrow(1.43)
	fitOnScreen()
	assert(math.abs(frame.Size.X.Scale - 0.32 * 1.43) < 1e-6, "The Daily Login keeps the size the phone fit gave it")
	frame.AbsoluteSize = Vector2.new(238 * 1.43, 186 * 1.43)
	fitOnScreen()
	assert(math.abs(frame.Size.X.Scale - 0.32 * 1.43) < 1e-6, "...also once it is drawn at that size")
	-- Elsewhere (growth 1) the old shrink still runs: an oversized panel is brought inside 76%.
	setGrow(1)
	frame.Size = UDim2.new(0.32, 0, 0.586, 0)
	frame.AbsoluteSize = Vector2.new(900, 700)
	fitOnScreen()
	assert(frame.Size.X.Scale < 0.32 * 0.5, "An oversized panel is still shrunk")
	has(source, "MenuPanelLayout.BindPhoneFit(gui, daysFrame, OPEN_POS, CLOSED_POS, function(fit)\n\tOPEN_POS, CLOSED_POS = fit.Open, fit.Closed\n\tphoneGrow = fit.Grow\n\tfitOnScreen()", "The Daily Login binds the phone fit and hands its growth to its shrink")
	local bindAt = string.find(source, "MenuPanelLayout.BindPhoneFit(gui, daysFrame", 1, true)
	assert(bindAt < string.find(source, "daysFrame.Position = CLOSED_POS\n", 1, true), "...before it first parks the window at CLOSED_POS")
	print("PASS Daily Login: its shrink keeps the phone fit's size and still shrinks an oversized panel elsewhere")
end

----------------------------------------------------------------------
-- 5. The Shop: the category bar grows with the window and keeps its gap; the Gift window
----------------------------------------------------------------------
do
	local source = fs.readFile(UI .. "ShopController.client.luau")
	local a = assert(string.find(source, "local SHOP_AUTHORED_POS = SHOP_OPEN_POS", 1, true), "Shop: the phone block")
	local b = assert(string.find(source, "local shopTween, sideTween, giftTween, dimTween", a, true), "Shop: end of the phone block")
	local chunk = "local SHOP_OPEN_POS = ShopFrame.Position\nlocal SHOP_CLOSED_POS = UDim2.new(SHOP_OPEN_POS.X.Scale, SHOP_OPEN_POS.X.Offset, 1.28, 0)\n"
		.. "local SIDE_OPEN_POS = sidebarHolder.Position\nlocal SIDE_CLOSED_POS = UDim2.new(SIDE_OPEN_POS.X.Scale, SIDE_OPEN_POS.X.Offset, 1.28, 0)\n"
		.. "local GIFT_OPEN_POS = GiftFrame.Position\nlocal GIFT_CLOSED_POS = UDim2.new(GIFT_OPEN_POS.X.Scale, GIFT_OPEN_POS.X.Offset, 1.28, 0)\n"
		.. string.sub(source, a, b - 1)
		.. "\nreturn function() return SHOP_OPEN_POS, SHOP_CLOSED_POS, SIDE_OPEN_POS, SIDE_CLOSED_POS, GIFT_OPEN_POS, GIFT_CLOSED_POS end"
	has(source, 'local SHOP_OPEN_POS = ShopFrame.Position\nlocal SHOP_CLOSED_POS = UDim2.new(SHOP_OPEN_POS.X.Scale, SHOP_OPEN_POS.X.Offset, 1.28, 0)', "(the Shop's positions, as the chunk above rebuilds them)")
	local shopGui = places.World1.Shop
	local realShop, realBar, realGift = shopGui.Shop, shopGui.Listbutton, shopGui.Gift
	local barShape = realBar:FindFirstChildOfClass("UIAspectRatioConstraint")
	for _, case in { { 812, 375, 58 }, { 667, 375, 36 }, { 740, 360, 58 }, { 896, 414, 58 }, { 1024, 768, 58, tablet = true }, { 1920, 1080, 58, desktop = true } } do
		local width, height, topBar = case[1], case[2], case[3]
		setScreen(width, height, topBar, not case.desktop, case.desktop == true)
		local gui = mockGui(shopGui.ScreenInsets, width, height)
		local shop = mockWindow(realShop)
		local gift = mockWindow(realGift)
		local bar = { Size = realBar.Size, Position = realBar.Position }
		function bar:FindFirstChildOfClass(class)
			return if class == "UIAspectRatioConstraint" then barShape else nil
		end
		local positions = luau.load(chunk, {
			environment = setmetatable({
				MenuPanelLayout = Layout, ShopGui = gui, ShopFrame = shop, GiftFrame = gift, sidebarHolder = bar, UDim2 = UDim2,
			}, { __index = _G }),
		})()
		local shopOpen, shopClosed, sideOpen, sideClosed, giftOpen = positions()
		local where = ("Shop on %dx%d"):format(width, height)
		if case.desktop then
			assert(shop.Writes == 0 and gift.Writes == 0 and bar.Size == realBar.Size and sideOpen == realBar.Position, where .. ": the designer's Shop, bar and Gift")
			continue
		end
		local sw, sh = width, height -- DeviceSafeInsets: the whole screen, under the top bar
		local w, h = Layout.WindowSize(shop.Size, realShop:FindFirstChildOfClass("UIAspectRatioConstraint"), sw, sh)
		local w0 = Layout.WindowSize(realShop.Size, realShop:FindFirstChildOfClass("UIAspectRatioConstraint"), sw, sh)
		local grow = w / w0
		local barW, barH = Layout.WindowSize(bar.Size, barShape, sw, sh)
		local barW0 = Layout.WindowSize(realBar.Size, barShape, sw, sh)
		assert(math.abs(barW / barW0 - grow) < 1e-3, where .. ": the bar grows with the window")
		local barLeft = sideOpen.X.Scale * sw + sideOpen.X.Offset - barW / 2
		local barRight = barLeft + barW
		local shopLeft = shopOpen.X.Scale * sw - w / 2
		local gap0 = (realShop.Position.X.Scale * sw - w0 / 2) - (realBar.Position.X.Scale * sw + barW0 / 2)
		assert(barLeft >= 0, where .. ": the bar stays on screen")
		assert(math.abs((shopLeft - barRight) - gap0 * grow) < 0.05, ("%s: the designer's gap to the window, grown (%.1f px)"):format(where, shopLeft - barRight))
		local barTop = sideOpen.Y.Scale * sh - barH / 2
		assert(barTop >= topBar and sideOpen.Y == shopOpen.Y, where .. ": level with the window, under the top bar")
		assert(sideClosed.Y == shopClosed.Y and sideClosed.X == sideOpen.X, where .. ": it slides away with the window")
		assert(barRight <= shopLeft and shopLeft + w <= sw, where .. ": bar and window side by side, on screen")
		local gw, gh = Layout.WindowSize(gift.Size, realGift:FindFirstChildOfClass("UIAspectRatioConstraint"), sw, sh)
		local gw0 = Layout.WindowSize(realGift.Size, realGift:FindFirstChildOfClass("UIAspectRatioConstraint"), sw, sh)
		assert(gw / gw0 > 1.25 and (case.tablet or gh >= 0.8 * (sh - topBar)), ("%s: the Gift window gets its own fit (%.0fx%.0f)"):format(where, gw, gh))
		local giftTop = giftOpen.Y.Scale * sh - gh / 2 - select(1, reach(realGift, gw, gh))
		assert(giftTop >= topBar + Layout.PhoneMargin - EPS, where .. ": the Gift window's header under the top bar")
	end
	-- The Shop open when the screen changes: the bar follows the window, at once at rest, once
	-- its slide has ended mid-slide (the Gift window, hidden behind the Shop, stays put).
	do
		setScreen(812, 375, 58, true, false)
		local gui = mockGui(shopGui.ScreenInsets, 812, 375)
		local shop, gift = mockWindow(realShop), mockWindow(realGift)
		gift.Visible = false
		local bar = { Size = realBar.Size, Position = realBar.Position, Visible = true }
		function bar:FindFirstChildOfClass(class)
			return if class == "UIAspectRatioConstraint" then barShape else nil
		end
		local positions = luau.load(chunk, {
			environment = setmetatable({
				MenuPanelLayout = Layout, ShopGui = gui, ShopFrame = shop, GiftFrame = gift, sidebarHolder = bar, UDim2 = UDim2,
			}, { __index = _G }),
		})()
		local shopOpen, _, sideOpen = positions()
		gui.Enabled = true
		shop.Position, bar.Position = shopOpen, sideOpen
		local giftAt = gift.Position
		setScreen(1024, 768, 58, true, false)
		gui.AbsoluteSize = Vector2.new(1024, 768)
		gui.Signals.AbsoluteSize:Fire()
		local shopOpen2, _, sideOpen2 = positions()
		assert(sideOpen2 ~= sideOpen and shop.Position == shopOpen2 and bar.Position == sideOpen2, "Shop open at rest on a new screen: window and bar move together")
		local sliding = UDim2.new(0.3, 0, 0.9, 0)
		shop.Position, bar.Position = UDim2.new(0.5, 0, 0.9, 0), sliding
		table.clear(world.Delayed)
		setScreen(812, 375, 58, true, false)
		gui.AbsoluteSize = Vector2.new(812, 375)
		gui.Signals.AbsoluteSize:Fire()
		local shopOpen3, _, sideOpen3 = positions()
		assert(bar.Position == sliding and #world.Delayed == 2, "Mid-slide, the tweens keep window and bar; both are looked at after the slide")
		shop.Position, bar.Position = shopOpen2, sideOpen2 -- where their running tweens end
		for _, fn in world.Delayed do
			fn()
		end
		assert(shop.Position == shopOpen3 and bar.Position == sideOpen3, "...then both go to their new places")
		assert(gift.Position == giftAt, "The hidden Gift window is not moved")
	end
	print("PASS Shop: on phones the category bar grows with the window, keeps the designer's gap and stays on screen, and follows the window when the screen changes; the Gift window has its own fit; desktop untouched")
end

----------------------------------------------------------------------
-- 6. The AFK Earnings panel: sized to the other panels' width, it follows them on phones,
--    and stays whole on the screen (it sits right of the middle, its Close past its right edge)
----------------------------------------------------------------------
do
	local Earnings = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/AfkEarningsLayout.luau"), { environment = moduleEnv() })()
	local real = places.World1.AfkRewardsGui.Earnings
	for key, starterGui in places do
		assert(signature(starterGui.AfkRewardsGui.Earnings) == signature(real), key .. ": AfkRewardsGui.Earnings differs from World 1's")
	end
	local insets = places.World1.AfkRewardsGui.ScreenInsets
	local shape = real:FindFirstChildOfClass("UIAspectRatioConstraint")
	-- The other panels' standard fit (2026-09-26: the Time Gift takes PhoneBlock now; the
	-- Rebirth window has the same designer's size and shape and keeps the standard fit).
	local timeGift = nil
	for _, panel in PANELS do
		if panel.Gui == "Rebirth" then
			timeGift = panel
		end
	end
	assert(timeGift and not timeGift.Block, "the Rebirth window, standard fit")
	-- AfkRewardsController's own fit (its UIScale, phoneGrow, phoneMargin and fitPanel), run on
	-- the real panel; `layout` false runs it without MenuPanelLayout, as its pcall allows.
	local controller = fs.readFile(UI .. "AfkRewardsController.client.luau")
	local a = assert(string.find(controller, 'local panelScale = Instance.new("UIScale")', 1, true), "AfkRewardsController: its panel fit")
	local b = assert(string.find(controller, "\nfitPanel()\n", a, true), "AfkRewardsController: its first fit")
	local fitChunk = string.sub(controller, a, b) .. "return fitPanel, panelScale"
	local function earnings(width, height, topBar, touch, keyboard, layout)
		setScreen(width, height, topBar, touch, keyboard)
		local sw, sh = safeSize(insets, width, height, topBar)
		local fitPanel, panelScale = luau.load(fitChunk, {
			environment = setmetatable({
				Instance = { new = function(class) return { ClassName = class, Scale = 1 } end },
				screenGui = mockGui(insets, sw, sh),
				panel = real,
				AfkEarningsLayout = Earnings,
				hasPanelLayout = layout ~= false,
				MenuPanelLayout = Layout,
				UDim2 = UDim2,
				Vector2 = Vector2,
			}, { __index = _G }),
		})()
		fitPanel()
		local scale = panelScale.Scale
		local w, h = Layout.WindowSize(real.Size, shape, sw, sh)
		return w * scale, h * scale, sw, sh, scale
	end
	-- The panel drawn w x h on a sw x sh screen: its left, right, top and bottom, pieces included.
	local function box(w, h, sw, sh)
		local top, bottom, left, right = reach(real, w, h)
		local cx, cy = real.Position.X.Scale * sw + real.Position.X.Offset, real.Position.Y.Scale * sh + real.Position.Y.Offset
		return cx - w / 2 - left, cx + w / 2 + right, cy - h / 2 - top, cy + h / 2 + bottom, top
	end
	for _, phone in EVERY_PHONE do
		for _, topBar in { 36, 58 } do
			local width, height = phone[1], phone[2]
			local w, h, sw, sh, scale = earnings(width, height, topBar, true, false)
			local frame = bind(timeGift, width, height, topBar, true, false)
			local tw = Layout.WindowSize(frame.Size, timeGift.Real:FindFirstChildOfClass("UIAspectRatioConstraint"), sw, sh)
			local where = ("Earnings on %dx%d, top bar %d"):format(width, height, topBar)
			local l, r, t, bottom, top = box(w, h, sw, sh)
			assert(t >= Layout.PhoneMargin - EPS and bottom <= sh - Layout.PhoneMargin + EPS, where .. ": whole under the top bar")
			-- At least the side room the other panels keep there (they fill 94% of the width).
			local side = math.max(Layout.PhoneMargin, (1 - Layout.PhoneWidthShare) / 2 * sw)
			assert(l >= side - EPS and r <= sw - side + EPS, ("%s: whole across the screen, Close included (%.1f..%.1f of %d)"):format(where, l, r, sw))
			assert((real.Position.Y.Scale + 1.1) * sh - h / 2 - top >= sh, where .. ": its closed place (+1.1 of the screen) is wholly below it")
			assert(w <= tw + 0.5, ("%s: never wider than the other panels there (%.1f, the Time Gift %.1f)"):format(where, w, tw))
			local s0 = Earnings.PanelScale(real, sw, sh)
			local w0, h0 = Layout.WindowSize(real.Size, shape, sw, sh)
			w0, h0 = w0 * s0, h0 * s0
			assert(s0 < 1 and w > 1.25 * w0, ("%s: drawn bigger than the desktop rule draws it (%.0f -> %.0f px)"):format(where, w0, w))
			if width > height then
				assert(math.abs(w - tw) < 0.5, ("%s: as wide as the other panels there (%.1f, the Time Gift %.1f)"):format(where, w, tw))
			else
				-- Upright, their growth alone would put its Close past the right edge: it stops
				-- where its right side meets the side room.
				local standard = Earnings.StandardPanel
				local fit = Layout.WindowFit(mockGui(insets, sw, sh), UDim2.fromScale(standard.WidthScale, standard.HeightScale), { AspectRatio = standard.AspectRatio }, standard.Header)
				local full = Earnings.PanelScale(real, sw, sh, fit.Grow) -- no margin: their whole growth
				local fullW, fullH = Layout.WindowSize(real.Size, shape, sw, sh)
				assert(select(2, box(fullW * full, fullH * full, sw, sh)) > sw, where .. ": (grown as much as the other panels, its Close would be off the screen)")
				assert(math.abs(r - (sw - side)) < 0.5, ("%s: as big as the screen lets it be (its right side at %.1f of %d)"):format(where, r, sw))
			end
			if report[width] and topBar == 58 then
				print(("  %-26s %4.0fx%-4.0f -> %4.0fx%-4.0f (x%.2f), its Claim %2.0fx%-2.0f -> %2.0fx%-2.0f, on %dx%d"):format("AfkRewardsGui.Earnings", w0, h0, w, h, w / w0,
					real.Claim.Size.X.Scale * w0, real.Claim.Size.Y.Scale * h0, real.Claim.Size.X.Scale * w, real.Claim.Size.Y.Scale * h, width, height))
			end
		end
	end
	-- The growth never goes under the desktop rule, whatever the margin; with none it is whole.
	do
		local _, _, sw, sh = earnings(375, 812, 58, true, false)
		local s0 = Earnings.PanelScale(real, sw, sh)
		assert(Earnings.PanelScale(real, sw, sh, 3, Vector2.new(sw, sh)) == s0, "A margin with no room left keeps the desktop rule")
		assert(Earnings.PanelScale(real, sw, sh, 3) == s0 * 3, "No margin: the whole growth")
		local w, _, _, _, scale = earnings(375, 812, 58, true, false, false)
		assert(scale == s0 and w < 130, "Without MenuPanelLayout the controller keeps the desktop rule")
	end
	for _, desktop in DESKTOPS do
		local _, _, sw, sh, scale = earnings(desktop[1], desktop[2], 58, false, true)
		assert(scale == Earnings.PanelScale(real, sw, sh) and scale <= 1, "Desktop: Earnings keeps the other panels' width, never above its own")
	end
	has(controller, "local hasPanelLayout, MenuPanelLayout = pcall(function()", "AfkRewardsController builds without MenuPanelLayout (audit/test_runtime_panels runs it so)")
	has(controller, "\tscreenGui.Enabled = true\n\tfitPanel()", "...and fits the panel again as it opens")
	print("PASS AFK Earnings: as wide as the other panels on every landscape phone (grown with them); upright as big as it fits, its Close on screen with the other panels' side room; whole under the top bar, closed below the screen; desktops unchanged")
end

----------------------------------------------------------------------
-- 7. Left alone: the Rank Reward panel already fits phones, the Codes card list is parked
----------------------------------------------------------------------
do
	local real = places.World1.RankRewardGui.Panel
	local size = Layout.ModalSizes.RankReward
	assert(real.Size == UDim2.fromOffset(size.X, size.Y), "The Rank Reward panel is authored at MenuPanelLayout.ModalSizes.RankReward")
	for _, phone in PHONES do
		for _, topBar in { 36, 58 } do
			setScreen(phone[1], phone[2], topBar, true, false)
			local scale = Layout.GetModalScale(camera.ViewportSize, size, true)
			local room = phone[2] - topBar -- its ScreenGui is CoreUISafeInsets
			local where = ("Rank Reward on %dx%d, top bar %d"):format(phone[1], phone[2], topBar)
			assert(size.Y * scale <= room - 20 and size.Y * scale >= 0.8 * room, ("%s: %.0f px tall in a %d px room"):format(where, size.Y * scale, room))
			assert(real.JoinGroup.Size.Y.Offset * scale >= 40 and real.ClaimReward.Size.Y.Offset * scale >= 40, where .. ": its buttons are 40 px or more")
		end
	end
	local rank = fs.readFile(UI .. "RankRewardPanel.client.luau")
	has(rank, "targetScale = MenuPanelLayout.GetModalScale(viewport, PANEL_SIZE, UserInputService.TouchEnabled)", "The Rank Reward panel keeps its own viewport fit")
	has(fs.readFile(UI .. "CodesModalController.client.luau"), "if Config.PromoCodesModalEnabled ~= true then", "The Codes card list stays parked (never shown)")
	has(fs.readFile("src/common/ReplicatedStorage/Shared/Config.luau"), "Config.PromoCodesModalEnabled = false", "...and it is off")
	print("PASS left alone: the Rank Reward panel already fills 80%+ of a phone's room with 40+ px buttons; the Codes card list is parked")
end

----------------------------------------------------------------------
-- 8. Every controller binds its window and slides it between the positions handed over
----------------------------------------------------------------------
do
	local WIRING = {
		TimeGiftController = { "MenuPanelLayout.BindPhoneFit(ui, mainFrame, OPEN_POS, CLOSED_POS, function(fit)\n\tOPEN_POS, CLOSED_POS = fit.Open, fit.Closed\nend, nil, MenuPanelLayout.PhoneBlock)", "{ Position = OPEN_POS }", "{ Position = CLOSED_POS }" },
		DailyRewardController = { "MenuPanelLayout.BindPhoneFit(gui, daysFrame, OPEN_POS, CLOSED_POS, function(fit)\n\tOPEN_POS, CLOSED_POS = fit.Open, fit.Closed", "{ Position = OPEN_POS }", "{ Position = CLOSED_POS }" },
		ShopController = { "MenuPanelLayout.BindPhoneFit(ShopGui, ShopFrame, SHOP_OPEN_POS, SHOP_CLOSED_POS, function(fit)", "MenuPanelLayout.BindPhoneFit(ShopGui, GiftFrame, GIFT_OPEN_POS, GIFT_CLOSED_POS, function(fit)\n\tGIFT_OPEN_POS, GIFT_CLOSED_POS = fit.Open, fit.Closed", "{ Position = SHOP_OPEN_POS }", "{ Position = SIDE_OPEN_POS }", "{ Position = GIFT_OPEN_POS }" },
		AbilitiesPanel = { "MenuPanelLayout.BindPhoneFit(gui, panel, OPEN_POSITION, CLOSED_POSITION, function(fit)\n\tOPEN_POSITION, CLOSED_POSITION = fit.Open, fit.Closed", "{Position = OPEN_POSITION}", "{Position = CLOSED_POSITION}" },
		RebirthController = { "MenuPanelLayout.BindPhoneFit(gui, frame, OPEN_POS, CLOSED_POS, function(fit)\n    OPEN_POS, CLOSED_POS = fit.Open, fit.Closed", "{ Position = OPEN_POS }", "{ Position = CLOSED_POS }" },
		EvolveController = { "MenuPanelLayout.BindPhoneFit(gui, frame, OPEN_POS, CLOSED_POS, function(fit)\n    OPEN_POS, CLOSED_POS = fit.Open, fit.Closed", "{ Position = OPEN_POS }", "{ Position = CLOSED_POS }" },
		WorldsController = { "MenuPanelLayout.BindPhoneFit(worldsGui, worldsFrame, OPEN_POSITION, CLOSED_POSITION, function(fit)\n\tOPEN_POSITION, CLOSED_POSITION = fit.Open, fit.Closed", "{ Position = OPEN_POSITION }", "{ Position = CLOSED_POSITION }" },
		TeleportController = { "MenuPanelLayout.BindPhoneFit(screenGui, mainFrame, OPEN_POS, CLOSED_POS, function(fit)\n\tOPEN_POS, CLOSED_POS = fit.Open, fit.Closed", "{ Position = OPEN_POS }", "{ Position = CLOSED_POS }" },
		UpdateLogsController = { "MenuPanelLayout.BindPhoneFit(gui, titleFrame, OPEN_POS, CLOSED_POS, function(fit)\n\tOPEN_POS, CLOSED_POS = fit.Open, fit.Closed", "{ Position = OPEN_POS }", "{ Position = CLOSED_POS }" },
	}
	for name, needles in WIRING do
		local source = fs.readFile(UI .. name .. ".client.luau")
		luau.compile(source)
		assert(string.find(source, "local MenuPanelLayout = require(", 1, true), name .. " requires MenuPanelLayout")
		for _, needle in needles do
			has(source, needle, name .. ": bound, and its tweens use the positions handed over")
		end
		-- Bound once its positions exist, before its first open.
		local bindAt = string.find(source, "MenuPanelLayout.BindPhoneFit(", 1, true)
		local firstTween = string.find(source, "TweenService:Create(", bindAt, true)
		assert(firstTween, name .. ": its tweens come after the bind")
	end
	-- 2026-09-26: the designer's Update 4 windows (no tweens: they appear in place) take PhoneBlock.
	for _, name in { "CommunityRewardsController", "StreakRewardsController", "PlaytimeBoostController" } do
		local source = fs.readFile(UI .. name .. ".client.luau")
		luau.compile(source)
		has(source, "MenuPanelLayout.BindPhoneFit(gui, window, OPEN_POS, OPEN_POS, function(fit)\n\tOPEN_POS = fit.Open\n\tif isOpen then\n\t\twindow.Position = OPEN_POS\n\tend\nend, nil, MenuPanelLayout.PhoneBlock)", name .. ": bound with PhoneBlock")
	end
	print("PASS wiring: 9 controllers bind their windows and tween between the positions MenuPanelLayout hands them; Community, Streak and Playtime Boost bind with PhoneBlock")
end

print("ALL OPT6 MOBILE PANEL CHECKS PASSED")
