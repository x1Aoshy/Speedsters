-- test_feel_letterbox.luau  (2026-09-22)
-- The cinematic letterbox on phones: the owner found the 0.11 bars (22 % of the screen) cut the
-- card, its words and the GO! button on wide phones (19.5:9). Checked here with the real
-- Shared/CinematicFit and the scripts' real layout code:
--   1. CinematicFit: 0.05 bars on phones, 0.11 on a computer; the fit and the clamp.
--   2. Admin/AdminTreadmillReveal: cardLayout (extracted between its markers) on phone screens:
--      the card and GO!, at the pop's peak and risen, inside the band between the bars and the
--      safe area; a computer unchanged (0.11, scale 1, 0.45 -> 0.25).
--   3. UI/WorldPortalCinematic: wordsLayout (extracted) the same way, Skip inside the safe area
--      and clear of the words; a computer exactly the old layout.
--   4. UI/WorldPortalCinematic: playCinematic run with stubs: thin bars on a phone, the fit's
--      UIScale under the untouched pop, and a turned screen laid out again.
--   5. Every changed source compiles.
--   lune run audit/test_feel_letterbox.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")

local SHARED = "src/common/ReplicatedStorage/Shared/"
local FIT = SHARED .. "CinematicFit.luau"
local ADMIN = "src/common/StarterPlayer/StarterPlayerScripts/Admin/AdminTreadmillReveal.client.luau"
local PORTAL = "src/common/StarterPlayer/StarterPlayerScripts/UI/WorldPortalCinematic.client.luau"

local function read(path)
	return (fs.readFile(path):gsub("\r\n", "\n"))
end
local function between(source, first, last, label)
	local a = assert(string.find(source, first, 1, true), label .. ": start marker missing")
	local b = assert(string.find(source, last, a, true), label .. ": end marker missing")
	return string.sub(source, a, b - 1)
end
local function has(source, needle, message)
	assert(string.find(source, needle, 1, true), message)
end
local function pass(message)
	print("PASS " .. message)
end

local function loadFit()
	return luau.load(read(FIT), { environment = { math = math, tonumber = tonumber } })()
end
local Fit = loadFit()

-- Phone screens (landscape, as the game is played): iPhone 12/13/14, 14 Plus/Pro Max, SE/8,
-- a small Android, Pixel-class, and a 19.5:9 one at 1080p-ish density.
local PHONES = {
	rb.Vector2.new(844, 390),
	rb.Vector2.new(932, 430),
	rb.Vector2.new(667, 375),
	rb.Vector2.new(740, 360),
	rb.Vector2.new(915, 412),
	rb.Vector2.new(780, 360), -- 19.5:9
}
local TOP_BARS = { 0, 36, 58 } -- GuiService:GetGuiInset().Y: none (read failed), old and new top bar
local DESKTOPS = { rb.Vector2.new(1920, 1080), rb.Vector2.new(1280, 720), rb.Vector2.new(1366, 768) }

local function near(a, b, epsilon)
	return math.abs(a - b) <= (epsilon or 1e-3)
end
local EPS = 0.01
local function inside(inner, outer, label)
	assert(inner.X >= outer.X - EPS and inner.Y >= outer.Y - EPS
		and inner.X + inner.W <= outer.X + outer.W + EPS and inner.Y + inner.H <= outer.Y + outer.H + EPS,
		("%s: {%.1f,%.1f,%.1f,%.1f} not inside {%.1f,%.1f,%.1f,%.1f}"):format(label,
			inner.X, inner.Y, inner.W, inner.H, outer.X, outer.Y, outer.W, outer.H))
end
local function apart(a, b, label)
	assert(a.X + a.W <= b.X + EPS or b.X + b.W <= a.X + EPS or a.Y + a.H <= b.Y + EPS or b.Y + b.H <= a.Y + EPS, label)
end

----------------------------------------------------------------------
-- 1. CinematicFit
----------------------------------------------------------------------
do
	for _, view in PHONES do
		assert(Fit.Bars(view.X, view.Y, true) == 0.05, "a phone's bars are 0.05 of the height")
		assert(Fit.Bars(view.X, view.Y, false) == 0.05, "a screen under 500 px tall is a phone's, touch or not")
	end
	for _, view in DESKTOPS do
		assert(Fit.Bars(view.X, view.Y, false) == 0.11, "a computer keeps 0.11 bars")
	end
	assert(Fit.Bars(1024, 768, true) == 0.05, "a touch-only tablet counts as a phone")
	assert(Fit.Fit(720, 236, 1920, 900) == 1, "a card that fits keeps scale 1 (never grows)")
	assert(near(Fit.Fit(1000, 100, 516, 900, 8), 0.5), "too wide: scaled to the band less the margins")
	assert(near(Fit.Fit(100, 400, 900, 216, 8), 0.5), "too tall: the same")
	assert(Fit.Fit(1000, 1000, 10, 10) == Fit.MinScale, "never below the smallest scale")
	assert(Fit.Clamp(50, 100, 0, 400, 8) == 58 and Fit.Clamp(390, 100, 0, 400, 8) == 342 and Fit.Clamp(200, 100, 0, 400, 8) == 200,
		"a centre moves just enough to keep the extent inside")
	local wide = Fit.Insets(844, 390, true, 58)
	assert(wide.Top == 58 and wide.Left >= 44 and wide.Right == wide.Left and wide.Bottom > 0, "a 19.5:9 phone: top bar, notch both sides, home indicator")
	local plain = Fit.Insets(667, 375, true, 36)
	assert(plain.Left == 0 and plain.Bottom == 0 and plain.Top == 36, "a 16:9 phone has no notch")
	local desk = Fit.Insets(1920, 1080, false, 58)
	assert(desk.Left == 0 and desk.Right == 0 and desk.Bottom == 0 and desk.Top == 58, "a computer: only the top bar")
	local band = Fit.Band(844, 390, 0.05, wide)
	assert(band.Y == 58 and band.X == wide.Left and near(band.Y + band.H, 390 - math.max(19.5, wide.Bottom)), "the band: between the bars, inside the safe area")
	pass("CinematicFit: 0.05 bars on phones and short screens, 0.11 on a computer; fit <= 1, clamp, insets and band")
end

----------------------------------------------------------------------
-- 2. The admin treadmill card
----------------------------------------------------------------------
local admin = read(ADMIN)
do
	has(admin, 'local CinematicFit = require(Shared:WaitForChild("CinematicFit"))', "the reveal uses CinematicFit")
	has(admin, "local layout = cardLayout(view, LOW_POWER or isMobile, topBarInset())", "every frame lays the card out for the screen as it is now")
	has(admin, "local barFraction = layout.Bar", "the bars come from the layout")
	assert(not string.find(admin, "then 0.075 else 0.08", 1, true) and not string.find(admin, "(CARD.Height * 1.6)", 1, true), "the old bar shares and the old fit are gone")
	has(admin, "local fit = layout.Fit", "the card's scale is the fit")
	has(admin, "cardScale.Scale = fit * easeBack(afterCard, 0.05, 0.45) * (1 - shut)", "...times the pop, which is untouched")
	has(admin, "local centreY = layout.PopY + (layout.RiseY - layout.PopY) * rise", "the card pops in and rises inside the band")
	has(admin, "goScale.Scale = (if hovering then 1.08 else 1) + 0.05 * math.sin(t * 6)", "GO! keeps its pulse")

	local CARD = luau.load(string.match(admin, "(local CARD = %b{})") .. "\nreturn CARD")()
	local chunk = between(admin, "-- LETTERBOX LAYOUT BEGIN", "-- LETTERBOX LAYOUT END", "admin layout")
	local cardLayout = luau.load(chunk .. "\nreturn cardLayout", { environment = {
		CinematicFit = Fit, CARD = CARD, Vector2 = rb.Vector2, math = math,
	} })()
	-- GO! inside the card, where the script puts it.
	has(admin, "local goX = CARD.Width - CARD.Pad - 124", "GO!'s place in the card")
	has(admin, "Position = UDim2.fromOffset(goX, 154),\n\t\tSize = UDim2.fromOffset(goWidth, 44),", "GO!'s size")
	local GO = { X = CARD.Width - CARD.Pad - 124, Y = 154, W = 124, H = 44 }
	local REACH = 12 -- the close button stands 12 px out of the top-right corner
	has(admin, "Position = UDim2.new(1, -20, 0, 20),\n\t\tSize = UDim2.fromOffset(64, 64),", "the close button's corner")

	-- The card (with its reach) and GO! at scale s, centred at (cx, cy).
	local function rects(view, s, cy)
		local w, h = CARD.Width * s, CARD.Height * s
		local left, top = view.X / 2 - w / 2, cy - h / 2
		return {
			Card = { X = left - REACH * s, Y = top - REACH * s, W = w + 2 * REACH * s, H = h + 2 * REACH * s },
			Go = { X = left + GO.X * s, Y = top + GO.Y * s, W = GO.W * s, H = GO.H * s },
		}
	end
	local function shrink(r, m)
		return { X = r.X + m, Y = r.Y + m, W = r.W - 2 * m, H = r.H - 2 * m }
	end

	local worst = 1
	for _, view in PHONES do
		for _, topBar in TOP_BARS do
			local label = ("admin %dx%d top %d"):format(view.X, view.Y, topBar)
			local layout = cardLayout(view, true, topBar)
			assert(layout.Bar == 0.05, label .. ": 0.05 bars")
			assert(layout.Fit <= 1 and layout.Fit > 0.5, label .. ": a readable fit (" .. layout.Fit .. ")")
			worst = math.min(worst, layout.Fit)
			local insets = Fit.Insets(view.X, view.Y, true, topBar)
			local band = shrink(Fit.Band(view.X, view.Y, layout.Bar, insets), Fit.Margin - 0.01)
			local safe = shrink(Fit.Band(view.X, view.Y, 0, insets), Fit.Margin - 0.01)
			-- Popping in, at the pop's peak (easeBack tops out at x1.0999), between the bars.
			local peak = rects(view, layout.Fit * 1.0999, layout.PopY * view.Y)
			inside(peak.Card, band, label .. ": the card at the pop's peak is between the bars and in the safe area")
			inside(peak.Go, band, label .. ": GO! at the pop's peak too")
			-- Settled and risen towards the top (the bars have gone by then): inside the safe area.
			for _, rise in { 0, 0.5, 1 } do
				local cy = (layout.PopY + (layout.RiseY - layout.PopY) * rise) * view.Y
				local settled = rects(view, layout.Fit, cy)
				inside(settled.Card, safe, label .. ": the card (rise " .. rise .. ") is in the safe area")
				inside(settled.Go, safe, label .. ": GO! (rise " .. rise .. ") is in the safe area")
				inside(settled.Go, settled.Card, label .. ": GO! is on the card")
				if rise == 0 then
					inside(settled.Card, band, label .. ": the settled card is between the bars")
				end
			end
		end
	end
	for _, view in DESKTOPS do
		local layout = cardLayout(view, false, 58)
		assert(layout.Bar == 0.11 and layout.Fit == 1, view.X .. "x" .. view.Y .. ": a computer keeps 0.11 bars and scale 1")
		assert(near(layout.PopY, 0.45) and near(layout.RiseY, 0.25), view.X .. "x" .. view.Y .. ": pops in at 0.45 and rises to 0.25, as before")
	end
	pass(("AdminTreadmillReveal: on 6 phone screens x 3 top bars the card and GO! stay between 0.05 bars and inside the safe area, popping and risen (smallest fit %.3f); computers unchanged"):format(worst))
end

----------------------------------------------------------------------
-- 3. The portal flight's words and Skip
----------------------------------------------------------------------
local portal = read(PORTAL)
local portalLayoutChunk = between(portal, "-- LETTERBOX LAYOUT BEGIN", "-- LETTERBOX LAYOUT END", "portal layout")
do
	assert(not string.find(portal, "local BAR = 0.11", 1, true), "no fixed 0.11 bar any more")
	has(portal, "shutter(barShare, timeline.Open, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)", "the letterbox opens to the layout's bars")
	has(portal, 'local pop = make("UIScale", { Scale = 0.6 }, block)', "the pop is still the words' own UIScale")
	has(portal, "TweenService:Create(pop, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()", "...popping to 1")
	has(portal, "fitScale.Scale = layout.Fit", "the fit is a UIScale of its own around the words")
	has(portal, 'GetPropertyChangedSignal("ViewportSize"):Connect(applyLayout)', "a screen that changes size is laid out again")

	local wordsLayout = luau.load(portalLayoutChunk .. "\nreturn wordsLayout", { environment = {
		CinematicFit = Fit, Vector2 = rb.Vector2, math = math,
	} })()
	local worst = 1
	for _, view in PHONES do
		for _, topBar in TOP_BARS do
			local label = ("portal %dx%d top %d"):format(view.X, view.Y, topBar)
			local layout = wordsLayout(view, true, topBar)
			assert(layout.Bar == 0.05, label .. ": 0.05 bars")
			assert(layout.Fit <= 1 and layout.Fit > 0.5, label .. ": a readable fit (" .. layout.Fit .. ")")
			worst = math.min(worst, layout.Fit)
			local insets = Fit.Insets(view.X, view.Y, true, topBar)
			local band = Fit.Band(view.X, view.Y, layout.Bar, insets)
			local safe = Fit.Band(view.X, view.Y, 0, insets)
			-- The words grow from their bottom middle: fit x pop (at its peak, and settled).
			for _, pop in { 1.0999, 1, 0.8 } do
				local s = layout.Fit * pop
				local w, h = layout.Words.X * s, layout.Words.Y * s
				local words = { X = view.X / 2 - w / 2, Y = layout.Bottom - h, W = w, H = h }
				inside(words, band, label .. ": the words (pop " .. pop .. ") between the bars and in the safe area")
			end
			local skip = {
				X = view.X - layout.SkipRight - layout.SkipSize.X, Y = view.Y - layout.SkipBottom - layout.SkipSize.Y,
				W = layout.SkipSize.X, H = layout.SkipSize.Y,
			}
			inside(skip, safe, label .. ": Skip is in the safe area")
			assert(skip.W >= 84 and skip.H >= 26, label .. ": Skip is still a thumb's size")
			local w, h = layout.Words.X * layout.Fit * 1.0999, layout.Words.Y * layout.Fit * 1.0999
			apart({ X = view.X / 2 - w / 2, Y = layout.Bottom - h, W = w, H = h }, skip, label .. ": the words never cover Skip")
		end
	end
	for _, view in DESKTOPS do
		local label = ("portal %dx%d"):format(view.X, view.Y)
		local layout = wordsLayout(view, false, 58)
		assert(layout.Bar == 0.11 and layout.Fit == 1, label .. ": a computer keeps 0.11 bars and scale 1")
		-- (Within the pixel a UDim offset rounds to.)
		assert(near(layout.Bottom, view.Y * (1 - 0.11 - 0.025), 1), label .. ": the words where they always were")
		assert(near(layout.Words.X, math.min(view.X * 0.9, 920), 1) and near(layout.Words.Y, math.min(view.Y * 0.3, 250), 1), label .. ": ...at their old size")
		assert(layout.SkipRight == 18 and layout.SkipBottom == 10, label .. ": Skip in its old corner")
		assert(near(layout.SkipSize.X, math.clamp(view.X * 0.14, 84, 150), 1) and near(layout.SkipSize.Y, math.clamp(view.Y * 0.11 - 16, 26, 46), 1), label .. ": ...at its old size")
	end
	pass(("WorldPortalCinematic: on 6 phone screens x 3 top bars the words stay between 0.05 bars and in the safe area through the pop, Skip in the safe area and clear of them (smallest fit %.3f); computers unchanged"):format(worst))
end

----------------------------------------------------------------------
-- 4. The portal flight run with stubs
----------------------------------------------------------------------
do
	local function signal()
		local s = { listeners = {} }
		function s:Connect(callback)
			table.insert(self.listeners, callback)
			return { Disconnect = function()
				local index = table.find(self.listeners, callback)
				if index then
					table.remove(self.listeners, index)
				end
			end }
		end
		function s:Fire(...)
			for _, callback in table.clone(self.listeners) do
				callback(...)
			end
		end
		function s:Wait() end
		return s
	end
	local EVENTS = { Activated = true, Destroying = true }
	local methods = {}
	local function instance(class)
		local object = { props = { ClassName = class, Name = class }, children = {}, events = {}, attributes = {} }
		return setmetatable(object, {
			__index = function(self, key)
				if methods[key] then
					return methods[key]
				end
				if self.props[key] ~= nil then
					return self.props[key]
				end
				if EVENTS[key] then
					self.events[key] = self.events[key] or signal()
					return self.events[key]
				end
				for _, child in self.children do
					if child.Name == key then
						return child
					end
				end
				return nil
			end,
			__newindex = function(self, key, value)
				if key == "Parent" then
					local old = self.props.Parent
					if old then
						local index = table.find(old.children, self)
						if index then
							table.remove(old.children, index)
						end
					end
					if value then
						table.insert(value.children, self)
					end
				end
				self.props[key] = value
				local changed = self.events["Prop_" .. key]
				if changed then
					changed:Fire()
				end
			end,
		})
	end
	function methods:GetPropertyChangedSignal(name)
		self.events["Prop_" .. name] = self.events["Prop_" .. name] or signal()
		return self.events["Prop_" .. name]
	end
	function methods:FindFirstChild(name)
		for _, child in self.children do
			if child.Name == name then
				return child
			end
		end
		return nil
	end
	function methods:FindFirstChildOfClass(class)
		for _, child in self.children do
			if child.ClassName == class then
				return child
			end
		end
		return nil
	end
	function methods:Destroy()
		if self.events.Destroying then
			self.events.Destroying:Fire()
		end
		self.Parent = nil
	end
	function methods:Play() end
	function methods:SetAttribute(name, value)
		self.attributes[name] = value
	end
	function methods:GetAttribute(name)
		return self.attributes[name]
	end
	function methods:GetDescendants()
		return {}
	end
	function methods:Raycast()
		return nil
	end
	function methods:RequestStreamAroundAsync() end

	local Shot = luau.load(read(SHARED .. "WorldPortalShot.luau"), { environment = {
		Vector3 = rb.Vector3, math = math, table = table, ipairs = ipairs, pairs = pairs, type = type,
	} })()

	local function run(view, touchOnly, topBar)
		local clock = 0
		local camera = instance("Camera")
		camera.ViewportSize = view
		camera.CameraType = rb.Enum.CameraType.Custom
		camera.FieldOfView = 70
		local workspace = instance("Workspace")
		workspace.CurrentCamera = camera
		local playerGui = instance("PlayerGui")
		local player = instance("Player")
		local binds = {}
		local seen = {}
		local waits = 0
		local env
		env = setmetatable({
			Instance = { new = instance },
			Enum = rb.Enum, UDim = rb.UDim, UDim2 = rb.UDim2, Vector2 = rb.Vector2, Vector3 = rb.Vector3,
			CFrame = rb.CFrame, Color3 = rb.Color3, ColorSequence = rb.ColorSequence,
			ColorSequenceKeypoint = rb.ColorSequenceKeypoint, typeof = typeof,
			TweenInfo = { new = function(...) return { ... } end },
			RaycastParams = { new = function() return {} end },
			os = { clock = function() return clock end },
			CinematicFit = Fit, Shot = Shot,
			LOW_POWER = touchOnly,
			GuiService = { GetGuiInset = function() return rb.Vector2.new(0, topBar), rb.Vector2.new(0, 0) end },
			TweenService = { Create = function(_, object, _, goal)
				local done = signal()
				return {
					Completed = done,
					Play = function()
						for key, value in goal do
							object[key] = value
						end
						done:Fire(rb.Enum.PlaybackState.Completed)
					end,
				}
			end },
			RunService = {
				BindToRenderStep = function(_, name, _, callback) binds[name] = callback end,
				UnbindFromRenderStep = function(_, name) binds[name] = nil end,
			},
			SoundService = instance("SoundService"),
			Workspace = workspace,
			PlayerGui = playerGui,
			player = player,
			MenuEvents = { CloseAll = signal() },
			InterfaceHider = { Hide = function() end, Show = function() end },
			CURRENT_WORLD = 1, TARGET_WORLD = 2,
			RENDER_NAME = "WorldPortalCinematicCamera", INTERFACE_OWNER = "WorldPortalCinematic",
			INK = rb.Color3.fromRGB(11, 27, 61), WHITE = rb.Color3.new(1, 1, 1), STUDS = "rbxassetid://0",
			SOUNDS = { Reveal = { Id = "a", Volume = 1 }, Portal = { Id = "b", Volume = 1 } },
			task = {
				delay = function() end,
				wait = function()
					waits += 1
					local gui = playerGui:FindFirstChild("WorldPortalCinematicGui")
					if gui and #seen == 0 then
						-- Mid-hold: what the player sees; then the phone turns (a new size) and a frame renders.
						local fit = gui.WordsFit
						table.insert(seen, {
							Bar = gui.BarTop.Size.Y.Scale, BarBottom = gui.BarBottom.Size.Y.Scale,
							Fit = fit.Fit.Scale, Pop = fit.Words.UIScale.Scale,
							Bottom = fit.Position.Y.Offset, Words = fit.Size, Skip = gui.SkipCinematic,
							SkipPosition = gui.SkipCinematic.Position,
						})
						camera.ViewportSize = rb.Vector2.new(view.Y * 2.4, view.Y) -- signal: laid out again
						table.insert(seen, { Fit = fit.Fit.Scale, Bar = gui.BarTop.Size.Y.Scale, Bottom = fit.Position.Y.Offset })
						camera.ViewportSize = view
						binds.WorldPortalCinematicCamera()
					end
					clock += 10
				end,
			},
		}, { __index = _G })
		local chunk = between(portal, "local function make(className, properties, parent)", "----------------------------------------------------------------------\n-- The portal", "portal make")
			.. between(portal, "local function words(parent, properties, maxSize, strokeThickness)", "----------------------------------------------------------------------\n-- When it plays", "portal flight")
		-- The portal lookups (left out above) need the world; the shot uses the authored fallback here.
		local playCinematic = luau.load(
			"local function findPortal() local f = Shot.Fallback[CURRENT_WORLD] return f.Position, f.Front, nil end\n"
				.. "local function clearReach() return nil end\n" .. chunk .. "\nreturn playCinematic",
			{ environment = env })()
		playCinematic()
		assert(waits > 0 and #seen == 2, "the flight ran through its hold")
		assert(playerGui:FindFirstChild("WorldPortalCinematicGui") == nil and next(binds) == nil, "...and cleaned up")
		return seen
	end

	-- A 19.5:9 phone with the new top bar.
	local view = rb.Vector2.new(844, 390)
	local seen = run(view, true, 58)
	local expected = luau.load(portalLayoutChunk .. "\nreturn wordsLayout", { environment = { CinematicFit = Fit, Vector2 = rb.Vector2, math = math } })()(view, true, 58)
	assert(near(seen[1].Bar, 0.05, 1e-6) and near(seen[1].BarBottom, 0.05, 1e-6), "the phone's letterbox rests at 0.05 bars (" .. seen[1].Bar .. ")")
	assert(near(seen[1].Fit, expected.Fit) and seen[1].Fit < 1, "the words' fit UIScale is the layout's (" .. seen[1].Fit .. ")")
	assert(seen[1].Pop == 1, "the pop inside it still ends at 1")
	assert(near(seen[1].Bottom, expected.Bottom) and near(seen[1].Words.X.Offset, expected.Words.X), "the words sit where the layout puts them")
	assert(seen[1].SkipPosition.X.Offset == -expected.SkipRight and seen[1].SkipPosition.Y.Offset == -expected.SkipBottom, "Skip inside the safe area")
	local turned = luau.load(portalLayoutChunk .. "\nreturn wordsLayout", { environment = { CinematicFit = Fit, Vector2 = rb.Vector2, math = math } })()(rb.Vector2.new(390 * 2.4, 390), true, 58)
	assert(near(seen[2].Fit, turned.Fit) and near(seen[2].Bar, 0.05, 1e-6), "a new screen size is laid out again at once")

	-- A computer: exactly as before.
	local desk = run(rb.Vector2.new(1920, 1080), false, 58)
	assert(near(desk[1].Bar, 0.11, 1e-6) and desk[1].Fit == 1 and desk[1].Pop == 1, "a computer: 0.11 bars, scale 1, the pop to 1")
	assert(near(desk[1].Bottom, 1080 * 0.865, 1) and desk[1].Words.X.Offset == 920 and desk[1].Words.Y.Offset == 250, "a computer: the words where and as big as before")
	assert(desk[1].SkipPosition.X.Offset == -18 and desk[1].SkipPosition.Y.Offset == -10, "a computer: Skip in its old corner")
	pass("WorldPortalCinematic.playCinematic (stubbed): a phone's letterbox rests at 0.05, the fit UIScale wraps the untouched pop, a resize is laid out again; a computer is unchanged")
end

----------------------------------------------------------------------
-- 5. Compiles
----------------------------------------------------------------------
do
	for _, path in { FIT, ADMIN, PORTAL } do
		local ok, problem = pcall(luau.compile, read(path))
		assert(ok, path .. " does not compile: " .. tostring(problem))
	end
	pass("CinematicFit, AdminTreadmillReveal and WorldPortalCinematic compile")
end

print("ALL LETTERBOX CHECKS PASSED")
