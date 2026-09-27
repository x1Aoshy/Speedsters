-- audit/test_fable_tutorial_portal.luau  (2026-09-20)
-- Runs the REAL modules (not copies of their logic) against the real place files:
--   1. every source in src compiles;
--   2. the unlock flight looks at the FRONT of the lobby portal in every world, never from
--      behind, never from inside the floor, and is never blocked at its closing shot;
--   3. the flight plays once per world, ever (join, respawn, level up, rebirth, rejoin);
--   4. the tutorial card fits every screen beside its button, sized from the HUD;
--   5. the Evolve badge stays off the Teleport button;
--   6. the "first aura" guide is owed after the first Win pad even when the player
--      rebirthed (and the server's Step 2 timed out) before touching it;
--   7. the card really builds, with the game's art, out of valid instances/properties.
-- Pass "places" as an argument to also check the three .rbxl files carry these sources.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")
local serde = require("@lune/serde")
local process = require("@lune/process")

local SHARED = "src/common/ReplicatedStorage/Shared/"
local PLACES = {
	{ key = "World1", file = "World1Update3New.rbxl", world = 1 },
	{ key = "World2", file = "World2Update3new.rbxl", world = 2 },
	{ key = "World3", file = "World3Update3New.rbxl", world = 3 },
}
local passed = 0
local function pass(message)
	passed += 1
	print("PASS " .. message)
end

local ENV = {
	Vector3 = rb.Vector3, Vector2 = rb.Vector2, CFrame = rb.CFrame, Color3 = rb.Color3, UDim = rb.UDim, UDim2 = rb.UDim2,
	ColorSequence = rb.ColorSequence, ColorSequenceKeypoint = rb.ColorSequenceKeypoint, Enum = rb.Enum, Instance = rb.Instance,
	math = math, table = table, string = string, tonumber = tonumber, tostring = tostring, pcall = pcall, ipairs = ipairs,
	pairs = pairs, type = type, typeof = typeof, print = print, task = { delay = function() end, spawn = function() end },
}
local function loadModule(name, extra)
	local env = table.clone(ENV)
	for key, value in extra or {} do
		env[key] = value
	end
	return luau.load(fs.readFile(SHARED .. name .. ".luau"), { debugName = name, environment = env })()
end

----------------------------------------------------------------------
-- 1. Everything compiles
----------------------------------------------------------------------
do
	local count = 0
	local function walk(path)
		for _, item in fs.readDir(path) do
			local full = path .. "/" .. item
			if fs.isDir(full) then
				walk(full)
			elseif item:sub(-5) == ".luau" then
				local ok, problem = pcall(luau.compile, fs.readFile(full))
				assert(ok, "SYNTAX " .. full .. ": " .. tostring(problem))
				count += 1
			end
		end
	end
	walk("src/common")
	walk("src/worlds")
	pass(("all %d sources in src compile"):format(count))
end

----------------------------------------------------------------------
-- 2. The flight, on the real portals
----------------------------------------------------------------------
local Shot = loadModule("WorldPortalShot")

local function ancestorNamed(item, names)
	while item do
		if names[item.Name] then
			return true
		end
		item = item.Parent
	end
	return false
end

-- Does the segment a->b pass through the box of `part`? (slab method, in the part's space)
local function segmentHitsPart(a, b, part)
	local cf = part.CFrame
	local la, lb = cf:PointToObjectSpace(a), cf:PointToObjectSpace(b)
	local half = part.Size / 2
	local t0, t1 = 0, 1
	for _, axis in { "X", "Y", "Z" } do
		local from, delta = la[axis], lb[axis] - la[axis]
		if math.abs(delta) < 1e-6 then
			if math.abs(from) > half[axis] then
				return nil
			end
		else
			local n, f = (-half[axis] - from) / delta, (half[axis] - from) / delta
			if n > f then
				n, f = f, n
			end
			t0, t1 = math.max(t0, n), math.min(t1, f)
			if t0 > t1 then
				return nil
			end
		end
	end
	return t0
end

for _, place in PLACES do
	local dm = rb.deserializePlace(fs.readFile(place.file))
	local ws = dm:GetService("Workspace")
	local spawn, portals, solids = nil, {}, {}
	for _, item in ws:GetDescendants() do
		if item:IsA("SpawnLocation") and item.Enabled and not spawn then
			spawn = item.CFrame.Position
		end
		if item:IsA("BasePart") then
			if Shot.PortalNames[item.Name] then
				table.insert(portals, item)
			elseif item.Transparency < 0.6 and item.Size.Magnitude >= 3 and not ancestorNamed(item, { ["world 2 portal"] = true, PortalWorld2 = true, PortalWorld3 = true }) then
				table.insert(solids, item)
			end
		end
	end
	assert(spawn, place.key .. ": no lobby spawn")
	local fallback = assert(Shot.Fallback[place.world], place.key .. ": no authored portal spot")
	local part = assert(Shot.Pick(portals, fallback.Position), place.key .. ": lobby portal not found near its authored spot")
	local position = part.CFrame.Position
	assert((position - spawn).Magnitude < 150, place.key .. ": picked a portal that is not in the lobby")
	assert((position - fallback.Position).Magnitude < 1.5, place.key .. ": the authored spot is stale: " .. tostring(position))
	for _, other in portals do
		if other ~= part then
			assert(Shot.Pick({ other }, fallback.Position) == nil or (other.CFrame.Position - position).Magnitude < 5,
				place.key .. ": an end-of-track portal counts as a lobby portal")
		end
	end

	local toSpawn = (spawn - position) * rb.Vector3.new(1, 0, 1)
	local front = Shot.Front(part.CFrame, part.Size, toSpawn)
	assert(math.abs(front.Magnitude - 1) < 1e-3 and math.abs(front.Y) < 1e-3, place.key .. ": front is not a flat unit vector")
	assert(front:Dot(toSpawn.Unit) > 0.7, place.key .. ": the front does not face the lobby")
	-- The front is the slab's normal: square to the portal's wide side.
	local wide = if part.Size.X <= part.Size.Z then part.CFrame.LookVector else part.CFrame.RightVector
	assert(math.abs(front:Dot(wide)) < 0.02, place.key .. ": the front is not square to the portal")
	assert(front:Dot(fallback.Front) > 0.999, place.key .. ": the authored front is stale")
	-- With no lobby reference streamed in, the authored front decides the side: same answer.
	assert(Shot.Front(part.CFrame, part.Size, fallback.Front):Dot(front) > 0.999, place.key .. ": fallback reference flips the front")
	assert(Shot.Front(part.CFrame, part.Size, -toSpawn):Dot(front) < -0.999, place.key .. ": Front ignores its reference")

	local focus = position
	local floorY = spawn.Y
	-- The probe itself must work: straight down from the spawn there is a floor.
	local seesFloor = false
	for _, solid in solids do
		if segmentHitsPart(spawn + rb.Vector3.new(0, 6, 0), spawn - rb.Vector3.new(0, 30, 0), solid) then
			seesFloor = true
			break
		end
	end
	assert(seesFloor, place.key .. ": the line-of-sight probe cannot even see the lobby floor")
	local worstAngle, blockedAt = 0, nil
	for step = 0, 40 do
		local alpha = step / 40
		local eye = Shot.Eye(focus, front, alpha)
		local offset = eye - focus
		assert(offset:Dot(front) > 10, ("%s: at %.2f the camera is behind (or beside) the portal"):format(place.key, alpha))
		assert(eye.Y > floorY + 4, ("%s: at %.2f the camera is in the floor"):format(place.key, alpha))
		local flatOffset = (offset * rb.Vector3.new(1, 0, 1)).Unit
		local angle = math.deg(math.acos(math.clamp(flatOffset:Dot(front), -1, 1)))
		worstAngle = math.max(worstAngle, angle)
		assert(angle <= 36, place.key .. ": the camera looks at the portal from too far to the side")
		if alpha == 1 then
			assert(angle <= 5, place.key .. ": the closing shot is not face on")
		end
		for _, solid in solids do
			local t = segmentHitsPart(focus, eye, solid)
			if t and t > 0.02 then
				local distance = t * offset.Magnitude
				if not blockedAt or distance < blockedAt.Distance then
					blockedAt = { Distance = distance, Alpha = alpha, Name = solid.Name }
				end
			end
		end
	end
	if blockedAt then
		-- The client pulls the camera in (clearReach); it must still have room for a shot.
		assert(blockedAt.Distance - 2.5 >= Shot.Flight.MinDistance,
			("%s: '%s' blocks the view %.1f studs from the portal"):format(place.key, blockedAt.Name, blockedAt.Distance))
		local reach = blockedAt.Distance - 2.5
		for step = 0, 10 do
			local eye = Shot.Eye(focus, front, step / 10, reach)
			assert((eye - focus):Dot(front) > 8, place.key .. ": a pulled-in camera ends behind the portal")
		end
		print(("  note %s: '%s' is in the way %.1f studs out (alpha %.2f); the client pulls the camera in"):format(
			place.key, blockedAt.Name, blockedAt.Distance, blockedAt.Alpha))
	end
	pass(("%s flight: portal (%.0f, %.0f, %.0f), front (%.2f, %.2f), %.0f studs from spawn, widest angle %.0f deg, clear=%s"):format(
		place.key, position.X, position.Y, position.Z, front.X, front.Z, (position - spawn).Magnitude, worstAngle, tostring(blockedAt == nil)))
end

----------------------------------------------------------------------
-- 3. Once per world, ever
----------------------------------------------------------------------
do
	-- A player who unlocks World 2 while playing.
	local gate = Shot.NewGate()
	assert(not Shot.Observe(gate, 2, true, false), "played before the data was in")
	assert(gate.Baseline[2] == nil, "took a baseline before the data was in")
	assert(not Shot.Observe(gate, 2, false, true), "played on the baseline")
	local plays = 0
	for _, unlocked in { false, false, true, true, true, true } do -- level ups, then the unlock, then respawns/rebirths
		if Shot.Observe(gate, 2, unlocked, true) then
			plays += 1
		end
	end
	assert(plays == 1, "the flight must play exactly once, played " .. plays)
	-- The same player joins again: the saved flag is already on.
	local rejoin = Shot.NewGate()
	for _ = 1, 5 do
		assert(not Shot.Observe(rejoin, 2, true, true), "the flight replayed on a later join")
	end
	-- Worlds are independent.
	local both = Shot.NewGate()
	Shot.Observe(both, 2, true, true)
	Shot.Observe(both, 3, false, true)
	assert(Shot.Observe(both, 3, true, true) and not Shot.Observe(both, 2, true, true), "world gates leak into each other")
	-- An admin reset makes the next unlock a new one (how the team tests it in Studio).
	assert(not Shot.Observe(gate, 2, false, true) and Shot.Observe(gate, 2, true, true), "an admin reset must allow a replay")
	local cinematic = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/WorldPortalCinematic.client.luau")
	for _, gone in { "meetsRequirementsForNextWorld", "WORLD_2_REQUIRED_LEVEL", 'FindFirstChild("Sign"', "WorldPortalCinematicSeen_W" } do
		assert(not cinematic:find(gone, 1, true), "the client still decides unlocks by itself: " .. gone)
	end
	for _, needed in { "Shot.Observe", "Shot.Front", "RequestStreamAroundAsync", "restoreCamera", "UnbindFromRenderStep", "nearPortal" } do
		assert(cinematic:find(needed, 1, true), "WorldPortalCinematic lost " .. needed)
	end
	local service = fs.readFile("src/common/ServerScriptService/Worlds/WorldPortalService.server.luau")
	assert(service:find("tryAutoUnlock", 1, true) and service:find('kind = "SetPersistent", key = key, value = true', 1, true),
		"the server must save the unlock when the requirements are met")
	pass("the flight plays once per world: baseline, unlock, respawn/rebirth, rejoin, two worlds, admin reset")
end

----------------------------------------------------------------------
-- 4. The card fits beside its button on every screen
----------------------------------------------------------------------
local Layout = loadModule("TutorialGuideLayout")
do
	local checks = 0
	for _, viewport in { { 320, 568 }, { 375, 667 }, { 568, 320 }, { 667, 290 }, { 844, 326 }, { 932, 430 }, { 1024, 700 }, { 1366, 700 }, { 1920, 1012 }, { 3840, 2088 } } do
		local vw, vh = viewport[1], viewport[2]
		-- The HUD sidebar is scale-sized: a button is about 11.5% of the screen height.
		local button = math.floor(vh * 0.115)
		local cw, ch = Layout.CardSize(vw, vh, button)
		assert(cw <= vw - 20 and ch <= vh - 20, "card larger than the screen")
		assert(ch >= 96 or vh < 120, "card too small to read")
		assert(ch <= math.max(96, button * 1.4), "card towers over the HUD")
		local barX, barY = vw * 0.0065, vh * 0.28
		for row = 0, 3 do
			for column = 0, 1 do
				local x, y = barX + column * button * 1.08, barY + row * button * 1.08
				local c = Layout.Place(vw, vh, x - 6, y - 6, button + 12, button + 12, cw, ch)
				assert(c.x >= 0 and c.y >= 0 and c.x + c.w <= vw and c.y + c.h <= vh, "card off the screen")
				local overlap = math.max(0, math.min(c.x + c.w, x + button) - math.max(c.x, x))
					* math.max(0, math.min(c.y + c.h, y + button) - math.max(c.y, y))
				assert(overlap == 0, ("card covers its button at %dx%d"):format(vw, vh))
				checks += 1
			end
		end
	end
	-- The old fixed-size call still answers (audit/test_tacos_tutorial_repair uses it).
	local legacy = Layout.Place(1920, 1012, 10, 10, 50, 50)
	assert(legacy.w == 280 and legacy.h == 144)
	pass(checks .. " card placements beside HUD buttons, phone portrait to 4K, none covering the button")
end

----------------------------------------------------------------------
-- 5. The Evolve badge stays off Teleport
----------------------------------------------------------------------
do
	for _, width in { 30, 45, 60, 90, 125, 180, 260 } do
		local gap = width * (0.05 / 0.6) -- the authored grid: 0.6 cells, 0.05 padding
		local shake = 5
		local size, centre, top = Layout.InnerBadge(width, gap, shake)
		local rightEdge = (centre + size / 2) * width + shake
		assert(rightEdge <= width + gap / 2 + 0.01, ("badge reaches Teleport at a %d px button"):format(width))
		assert(size <= 0.36 and size >= 0.28, "badge size out of range")
		assert((centre - size / 2) > 0.4 and top - size / 2 > -0.1, "badge drifted off its corner")
	end
	-- What the designer's badge did: 0.459 wide, centred at 0.975 of the button.
	local authoredEdge = (0.975 + 0.459 / 2) * 125 + 5
	assert(authoredEdge > 125 + 125 * (0.05 / 0.6), "the authored badge never overlapped; this fix is not needed")
	local hud = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/MainHUDController.client.luau")
	assert(hud:find("BadgeLayout.InnerBadge", 1, true), "MainHUDController must size the Evolve badge")
	pass("Evolve badge stays inside its button at every HUD size (the authored one reached 25 px over Teleport)")
end

----------------------------------------------------------------------
-- 6. The first-aura guide after a rebirth-before-win
----------------------------------------------------------------------
do
	local Flow = loadModule("TutorialFlow")
	local state = { SawTutorial = true, WinStage = 1 }
	-- Trained for minutes, Step 2 timed out, rebirthed: nothing claimed yet, no guide yet.
	assert(not Flow.WantsAuraGuide(state), "guide before any Win pad")
	state.ClaimedStage = 1
	assert(Flow.WantsAuraGuide(state), "REGRESSION: no aura guide when the Win pad is claimed after the tutorial timed out")
	state.ClaimedStage = 2
	assert(Flow.WantsAuraGuide(state), "skipping to the Stage 2 pad must count as well")
	assert(not Flow.WantsAuraGuide({ SawTutorial = false, WinStage = 1, ClaimedStage = 1 }), "veterans must not get the guide")
	assert(not Flow.WantsAuraGuide({ SawTutorial = true, WinStage = 2, ClaimedStage = 1 }), "old World 1 waits for its Stage 2 pad")
	assert(not Flow.WantsAuraGuide({ SawTutorial = true, WinStage = 1, ClaimedStage = 1, EquipDone = true }), "guide after it was completed")
	assert(not Flow.WantsAuraGuide({ SawTutorial = true, WinStage = 1, ClaimedStage = 1, Dismissed = true }), "guide after Skip")
	local ready = { CharacterAlive = true, HudReady = true }
	assert(Flow.CanShowNow(ready))
	for _, blocker in { "TutorialActive", "GuideOpen" } do
		local blocked = table.clone(ready)
		blocked[blocker] = true
		assert(not Flow.CanShowNow(blocked), blocker .. " must hold the guide back")
	end
	assert(not Flow.CanShowNow({ HudReady = true }) and not Flow.CanShowNow({ CharacterAlive = true }))

	local client = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/FirstTimeTutorial.client.luau")
	assert(not client:find("priorStep == 2 and", 1, true), "the guide still hangs on Step 2 ending")
	local handler = assert(client:find('player:GetAttributeChangedSignal("LastCompletedSafeZone"):Connect(function()', 1, true))
	assert(client:find("pumpAuraGuide()", handler, true) and client:find("pumpAuraGuide()", handler, true) - handler < 120,
		"claiming a Win pad must offer the guide")
	assert(client:find("sawTutorial = true", 1, true))
	local server = fs.readFile("src/common/ServerScriptService/Social/FirstTimeTutorial.server.luau")
	assert(not server:find('"LastCompletedSafeZone")) == TUTORIAL_WIN_STAGE', 1, true), "the server still needs exactly the first pad")
	local evolve = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/EvolveController.client.luau")
	assert(evolve:find("offered = false", 1, true), "a torn-down Evolve guide must be offered again")
	pass("first-aura guide: owed after a late first Win pad, not for veterans, not after done/skip; held back while another guide is up")
end

----------------------------------------------------------------------
-- 7. The card builds, in the game's art
----------------------------------------------------------------------
do
	-- 2026-09-22: the card's words come from Shared/TutorialText, in the player's language.
	local Text = loadModule("TutorialText", { Font = rb.Font, setmetatable = setmetatable })
	local siblings = { TutorialGuideLayout = Layout, TutorialText = Text }
	local fakeScript = { Parent = { WaitForChild = function(_, name) return assert(siblings[name], "no sibling " .. name) end } }
	local Guide = luau.load(fs.readFile(SHARED .. "TutorialGuide.luau"), { debugName = "TutorialGuide", environment = (function()
		local env = table.clone(ENV)
		env.script = fakeScript
		env.require = function(module) return module end
		env.game = { GetService = function() return {} end }
		env.os = os
		return env
	end)() })()
	-- The aura and Evolve cards (true/false as before), the Rebirth card, and a Russian one.
	for _, case in { { false, 3, "en" }, { true, 2, "en" }, { Guide._Modes.Rebirth.Icon, 2, "en" }, { Guide._Modes.Rebirth.Icon, 2, "ru" } } do
		local icon, steps, lang = case[1], case[2], case[3]
		local canvas = rb.Instance.new("Frame")
		local parts = Guide._BuildCard(canvas, icon, steps, lang)
		assert(parts.Card.Parent == canvas and #parts.Pills == steps)
		local skipLabel = parts.Skip:FindFirstChild("Label")
		assert(skipLabel.Text == Text.Get("Skip", lang) and skipLabel.AutoLocalize == false, "Skip label in the player's language, AutoLocalize off")
		assert(parts.Title.AutoLocalize == false and parts.Message.AutoLocalize == false, "card labels AutoLocalize off")
		-- (Lune does not mirror Font into FontFace: FredokaOne is read from Font, Builder Sans from FontFace.)
		if lang == "ru" then
			assert(parts.Title.FontFace.Family:find("BuilderSans", 1, true) and skipLabel.FontFace.Family:find("BuilderSans", 1, true), "ru card font")
		else
			assert(parts.Title.Font == rb.Enum.Font.FredokaOne and not parts.Title.FontFace.Family:find("BuilderSans", 1, true)
				and not skipLabel.FontFace.Family:find("BuilderSans", 1, true), lang .. " card keeps FredokaOne")
		end
		assert(parts.Icon.Image == (if icon == true then "rbxassetid://92164600998462" elseif icon == false then "rbxassetid://139874655682754" else "rbxassetid://129578402198506"),
			"card icon")
		for _, name in { "Window", "Icon", "Title", "Plate", "Skip" } do
			assert(parts.Card:FindFirstChild(name), "card is missing " .. name)
		end
		assert(parts.Skip:FindFirstChild("Studs") and parts.Skip:FindFirstChild("Rim") and parts.Skip:FindFirstChild("Edge"),
			"Skip is not the game's stud button")
		-- Scale-sized throughout: no child may carry a pixel size (that is what made it tiny on big screens).
		for _, item in parts.Card:GetDescendants() do
			if item:IsA("GuiObject") then
				assert(item.Size.X.Offset == 0 and item.Size.Y.Offset == 0, item.Name .. " has a pixel size")
			end
		end
	end
	local source = fs.readFile(SHARED .. "TutorialGuide.luau")
	for _, art in { "106477372921851", "135496826236732", "74885007861450", "Enum.Font.FredokaOne" } do
		assert(source:find(art, 1, true), "the card lost the game's art: " .. art)
	end
	assert(not source:find('"CanvasGroup"', 1, true), "a CanvasGroup would clip the title and icon on the card's top edge")
	pass("tutorial card builds for the aura, Evolve and Rebirth guides (and in Russian): block window, navy plate, stud Skip, scale-sized, words from TutorialText")
end

----------------------------------------------------------------------
-- 8. (places) the three .rbxl files carry exactly these sources
----------------------------------------------------------------------
if process.args[1] == "places" then
	local manifest = serde.decode("json", fs.readFile("src/manifest.json"))
	local WANTED = {
		"src/common/ReplicatedStorage/Shared/TutorialGuide.luau",
		"src/common/ReplicatedStorage/Shared/TutorialGuideLayout.luau",
		"src/common/ReplicatedStorage/Shared/TutorialText.luau",
		"src/common/ReplicatedStorage/Shared/TutorialFlow.luau",
		"src/common/StarterPlayer/StarterPlayerScripts/UI/RebirthController.client.luau",
		"src/common/ReplicatedStorage/Shared/WorldPortalShot.luau",
		"src/common/StarterPlayer/StarterPlayerScripts/UI/WorldPortalCinematic.client.luau",
		"src/common/StarterPlayer/StarterPlayerScripts/UI/FirstTimeTutorial.client.luau",
		"src/common/StarterPlayer/StarterPlayerScripts/UI/EvolveController.client.luau",
		"src/common/StarterPlayer/StarterPlayerScripts/UI/MainHUDController.client.luau",
		"src/common/ServerScriptService/Social/FirstTimeTutorial.server.luau",
		"src/common/ServerScriptService/Worlds/WorldPortalService.server.luau",
	}
	for _, place in PLACES do
		local dm = rb.deserializePlace(fs.readFile(place.file))
		local rows = {}
		for _, row in manifest.worlds[place.key].scripts do
			rows[row.source] = row
		end
		for _, source in WANTED do
			local row = assert(rows[source], place.key .. " manifest has no row for " .. source)
			local node = dm
			for _, name in row.segments do
				node = assert(node:FindFirstChild(name), place.key .. " is missing " .. table.concat(row.segments, "."))
			end
			assert(node.ClassName == row.class, place.key .. ": " .. node.Name .. " is a " .. node.ClassName)
			assert(node.Source == fs.readFile(source), place.key .. ": " .. node.Name .. " differs from src")
			local twins = 0
			for _, sibling in node.Parent:GetChildren() do
				if sibling.Name == node.Name then
					twins += 1
				end
			end
			assert(twins == 1, place.key .. ": " .. node.Name .. " exists " .. twins .. " times")
		end
		local badge = dm:GetService("StarterGui").Mainhud.LeftSideBar.Evolve["!"]
		assert(math.abs(badge.Size.X.Scale - 0.34) < 1e-3 and badge.Position.X.Scale < 0.87, place.key .. ": the saved Evolve badge is still the big one")
		pass(place.key .. " place carries all " .. #WANTED .. " sources once each, and the small Evolve badge")
	end
end

print(("ALL PASSED (%d groups)"):format(passed))
