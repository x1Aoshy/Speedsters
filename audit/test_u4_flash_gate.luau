-- test_u4_flash_gate.luau (Update 4, 2026-09-26, owner: The Flash's race gate + the holo board)
-- Shared/FlashGate, Services/Race/RaceArenaBuilder.BuildGate (v2), Gameplay/FlashGateClient,
-- LobbyNpcPose's gate-host idle and build_update4's gate step. Checks:
--   1. the sources compile, none calls CFrame.lookAt; the client has no sparkles (no
--      ParticleEmitter, Sparkles, Fire or Smoke, no sparkles_main.dds), waits for every remote
--      with a timeout, scans no Workspace, fires only RaceRequest("Board"), uses BulkMoveTo, and
--      LobbyNpcsClient's old sparks never turn on;
--   2. the words: every key in en / es / pt (es / pt translated), within FlashGate.Caps;
--   3. the maths: FormatTime / Clock / StatusOf for every race phase / Rows / ShortName,
--      BoardPieces (the top edge stays put), DashFrames, CracklePoints, PhaseProgress;
--   4. the gate in each world: the contract (RaceGatePad invisible 12 x 0.4 x 12 at the floor
--      point, RaceGateSign lines, FlashSpot = LobbyNpcConfig.FlashBeside, HoloBoardAnchor =
--      FlashGate.BoardLocal, RaceGateVersion), parts only (no mesh, texture, script or particle),
--      anchored, no shadow, <= GatePartBudget; the arch: a closed half circle (neighbouring
--      segments meet), symmetric, nothing under the floor, legs on it; the gold band inside the
--      red body and proud of both faces; the medallion at the top with the bolt showing on both
--      faces; the ring pad's discs each higher than the last and covering the trigger's circle,
--      none colliding; a clear walk-through (nothing collides over the pad up to 7.5 studs); it
--      serializes;
--   5. the holo board (BuildBoard): its parts inert, the screen's pieces, every label left
--      untranslated by Roblox, the header fits the collapsed board, the rows and the bar fit the
--      open one; it serializes;
--   6. Flash's gate-host idle: the hero stance and the lightning fist in his loop, FlashFist
--      inside the loop while his right fist is up;
--   7. build_update4 (module mode, in memory): an old stamped gate (v1) is rebuilt as v2, a v2 is
--      kept (unless forced / --rebuild-gate), an unstamped gate is never touched; the flag is
--      parsed and verify asks for v2 and no old board; the runner lists this test; 2026-09-26: with
--      the Blender kit a v2 of ours becomes the mesh gate (v3), which is kept, and never turned back
--      into parts when the kit file is gone;
--   8. 2026-09-26 (owner), the Blender kit (audit/flash_gate_bpy.py): FlashGate.Kit is the manifest,
--      within the budget and Roblox's limits, on FlashGate.Arch's footprint; a stand-in of Studio's
--      import (MeshParts from the manifest, the kit turned 180 degrees with its PivotOffsets, as
--      Studio did to the Green Hill kit) builds the mesh gate in 3 worlds: the contract parts, every
--      mesh where the manifest puts it with the turn undone (the importer's pivot lands on the gate's
--      floor point), its look from the manifest, the legs the only colliders, MedallionGlow a Part,
--      a clear walk-through, it serializes; any quarter turn, an importer's name suffix or unit
--      scale gives the same gate; a missing piece, a Part, a wrong shape or scrambled pivots fall
--      back to the parts with a warning.
-- Run: lune run audit/test_u4_flash_gate.luau   (from the project root; reads no place)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Vector3, CFrame, Instance = roblox.Vector3, roblox.CFrame, roblox.Instance

local SHARED = "src/common/ReplicatedStorage/Shared/"
local CLIENT_FILE = "src/common/StarterPlayer/StarterPlayerScripts/Gameplay/FlashGateClient.client.luau"
local NPC_CLIENT = "src/common/StarterPlayer/StarterPlayerScripts/Gameplay/LobbyNpcsClient.client.luau"
local BUILDER_FILE = "src/common/ServerScriptService/Services/Race/RaceArenaBuilder.luau"
local U4 = require("../src/common/ReplicatedStorage/Shared/Update4Config")
local FlashGate = require("../src/common/ReplicatedStorage/Shared/FlashGate")
local LobbyNpcConfig = require("../src/common/ReplicatedStorage/Shared/LobbyNpcConfig")
local LobbyNpcPose = require("../src/common/ReplicatedStorage/Shared/LobbyNpcPose")
local RaceArenaBuilder = require("../src/common/ServerScriptService/Services/Race/RaceArenaBuilder")

local ENV = {
	Instance = Instance, Vector3 = Vector3, CFrame = CFrame, Color3 = roblox.Color3, Enum = roblox.Enum,
	UDim = roblox.UDim, UDim2 = roblox.UDim2, Vector2 = roblox.Vector2, NumberRange = roblox.NumberRange,
	Font = roblox.Font, ColorSequence = roblox.ColorSequence, NumberSequence = roblox.NumberSequence, RaceAssets = false,
}
local WORLDS = { "World1", "World2", "World3" }

local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end
local function read(path)
	return (fs.readFile(path):gsub("\r\n", "\n"))
end
local function has(source, needle, message)
	assert(string.find(source, needle, 1, true), message .. " (missing: " .. needle .. ")")
end
local function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-3)
end
local function finite(n)
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

----------------------------------------------------------------------
-- 1. Sources
----------------------------------------------------------------------
do
	for _, path in { SHARED .. "FlashGate.luau", CLIENT_FILE, BUILDER_FILE, SHARED .. "LobbyNpcPose.luau", NPC_CLIENT,
		"audit/u4_race_board.luau", "audit/build_update4.luau", SHARED .. "MeshKitImport.luau", "audit/u4_flash_gate_kit.luau" } do
		local source = fs.readFile(path)
		local ok, problem = pcall(luau.compile, source)
		assert(ok, "SYNTAX " .. path .. ": " .. tostring(problem))
		assert(not string.find(source, "lookAt%s*%("), path .. ": calls CFrame.lookAt (wrong in Lune)")
	end
	local client = read(CLIENT_FILE)
	for _, banned in { "ParticleEmitter", "sparkles_main", "\"Sparkles\"", "Instance.new(\"Fire\")", "Instance.new(\"Smoke\")",
		"orkspace:GetDescendants()", "BindToRenderStep" } do
		assert(not string.find(client, banned, 1, true), "FlashGateClient: " .. banned)
	end
	for _, needle in { 'WaitForChild("Remotes", 60)', 'WaitForChild("RaceRequest", 60)', 'WaitForChild("RaceEvent", 60)',
		"Workspace:BulkMoveTo(", 'Instance.new("Beam")', "RaceFeelTier.Detect(meter)", "ProximityPromptService.PromptTriggered",
		'MenuEvents.Listen("Race"', "LobbyNpcPose.FlashFist", "CLIENT.CollapseDistance", "CLIENT.SignHideRadius" } do
		has(client, needle, "FlashGateClient")
	end
	local _, fires = string.gsub(client, ":FireServer%(", "")
	assert(fires == 1 and string.find(client, 'remote:FireServer("Board")', 1, true), "the client sends only RaceRequest(\"Board\")")
	local shared = read(SHARED .. "FlashGate.luau")
	assert(not string.find(shared, "ParticleEmitter", 1, true) and not string.find(shared, "sparkles_main", 1, true), "FlashGate: no particles")
	local npc = read(NPC_CLIENT)
	has(npc, "local on = false and near and tier ~= \"Low\"", "LobbyNpcsClient's sparks stay off")
	pass("sources compile, no lookAt; the client: Beams not particles, remotes with timeouts, no Workspace scan, only RaceRequest(\"Board\"); the NPC sparks off")
end

----------------------------------------------------------------------
-- 2. Words
----------------------------------------------------------------------
do
	local en = FlashGate.Strings.en
	for key in FlashGate.Caps do
		assert(type(en[key]) == "string", "no English for " .. key)
	end
	for key in en do
		assert(FlashGate.Caps[key], "no cap for " .. key)
	end
	for _, lang in FlashGate.Required do
		local strings = assert(FlashGate.Strings[lang], "no " .. lang)
		for key, cap in FlashGate.Caps do
			local text = strings[key]
			assert(type(text) == "string" and text ~= "", lang .. " lacks " .. key)
			assert(FlashGate.MeasuredLength(text) <= cap, ("%s %s is %d long (cap %d): %s"):format(lang, key, FlashGate.MeasuredLength(text), cap, text))
		end
	end
	for _, lang in { "es", "pt" } do
		for _, key in { "Title", "Hint", "Empty", "NoTime", "Weekly" } do
			assert(FlashGate.Strings[lang][key] ~= en[key], lang .. " " .. key .. " is not translated")
		end
	end
	assert(en.Title == "MULTIPLAYER RACE", "the reference's title")
	assert(FlashGate.Get("Title", "xx") == en.Title and FlashGate.Get("Nope", "es") == "Nope", "fallbacks")
	assert(FlashGate.Format("Status", "en", FlashGate.Get("Open", "en")) == "STATUS: OPEN", "STATUS: OPEN")
	pass("words: every key in en / es / pt within its cap; STATUS: OPEN")
end

----------------------------------------------------------------------
-- 3. Maths
----------------------------------------------------------------------
do
	assert(FlashGate.FormatTime(32450) == "00:32.45" and FlashGate.FormatTime(75005) == "01:15.01", "mm:ss.cc")
	assert(FlashGate.FormatTime(0) == "--:--.--" and FlashGate.FormatTime(nil) == "--:--.--" and FlashGate.FormatTime(0 / 0) == "--:--.--", "no time")
	assert(FlashGate.FormatTime(59999) == "01:00.00", "rounding carries into the minute")
	assert(FlashGate.Clock(75) == "1:15" and FlashGate.Clock(0.2) == "0:01" and FlashGate.Clock(-3) == "0:00", "clock")
	local now = 1000
	local cases = {
		{ "Gathering", now + 15, true, false, "OpenIn", "0:15", "Green" },
		{ "Gathering", now + 15, true, true, "Mega", "0:15", "Amber" },
		{ "Staging", now + 3, true, false, "Starting", nil, "Amber" },
		{ "Countdown", now + 4.2, true, false, "StartingIn", "5", "Amber" },
		{ "Running", now + 32, true, false, "Racing", "0:32", "Orange" },
		{ "Results", now + 7, true, false, "NextIn", "0:07", "Cyan" },
		{ "Cooldown", now + 8, true, false, "NextIn", "0:08", "Cyan" },
		{ nil, nil, true, false, "Open", nil, "Green" },
		{ "Idle", nil, true, false, "Open", nil, "Green" },
		{ "Running", now + 32, false, false, "Closed", nil, "Muted" },
	}
	for _, case in cases do
		local key, argument, colorName = FlashGate.StatusOf(case[1], case[2], now, case[3], case[4])
		assert(key == case[5] and argument == case[6] and colorName == case[7],
			("StatusOf(%s): %s %s %s"):format(tostring(case[1]), key, tostring(argument), colorName))
		assert(FlashGate.Colors[colorName], "colour " .. colorName)
	end
	local line = FlashGate.StatusLine("Gathering", now + 15, now, true, false, "en")
	assert(line == "STATUS: OPEN · 0:15", line)
	local rows = FlashGate.Rows({
		{ UserId = 1, Name = "flash_speedster", Ms = 32000 }, "junk", { UserId = 2, Name = "", Ms = 45000 }, { UserId = 3, Ms = 0 },
		{ UserId = 4, Name = "neon_racer", Ms = 63000 }, { UserId = 5, Name = "runner_xyz", Ms = 75000 },
		{ UserId = 6, Name = "a", Ms = 80000 }, { UserId = 7, Name = "b", Ms = 90000 },
	}, 5)
	assert(#rows == 5 and rows[1].Name == "FLASH_SPEEDSTER" and rows[1].Time == "00:32.00" and rows[2].Name == "?"
		and rows[3].Rank == 3 and rows[3].UserId == 4 and rows[5].UserId == 6, "rows skip malformed entries and stop at 5")
	assert(#FlashGate.Rows(nil, 5) == 0, "no list, no rows")
	assert(FlashGate.ShortName("abcdefghijklmnopqrstuvwxyz", 10) == "ABCDEFGHI…", "a long name is cut")
	assert(FlashGate.PhaseProgress(100, 120, 110) == 0.5 and FlashGate.PhaseProgress(100, nil, 110) == nil
		and FlashGate.PhaseProgress(100, 120, 200) == 1, "phase progress")

	-- The board opens downward: the top edge never moves; the edges frame the glass.
	local b = FlashGate.Board
	for _, shown in { b.Header, (b.Header + b.Height) / 2, b.Height } do
		local pieces = FlashGate.BoardPieces(shown, Vector3, CFrame)
		local glass = pieces.Glass
		assert(near(glass[1].Position.Y + glass[2].Y / 2, b.Height / 2) and near(glass[2].Y, shown), "glass top at the board's top")
		assert(near(pieces.EdgeTop[1].Position.Y, b.Height / 2 + b.Border / 2), "top edge fixed")
		assert(near(pieces.EdgeBottom[1].Position.Y, b.Height / 2 - shown - b.Border / 2), "bottom edge under the glass")
		assert(near(pieces.EdgeLeft[2].Y, shown) and near(math.abs(pieces.EdgeLeft[1].Position.X), (b.Width + b.Border) / 2), "side edges")
	end
	-- Dashes: evenly round the circle, long axis along it.
	local frames = FlashGate.DashFrames(5, 8, 0.3, 0.3, CFrame)
	assert(#frames == 8, "8 dashes")
	for _, cf in frames do
		local p = cf.Position
		local radial = Vector3.new(p.X, 0, p.Z)
		assert(near(radial.Magnitude, 5, 1e-3) and near(p.Y, 0.3), "on the circle")
		assert(math.abs(cf.LookVector:Dot(radial.Unit)) < 1e-3, "along the circle")
	end
	-- Crackles: from the start, `length` along the direction, jitter bounded.
	-- Roblox's Random (NextNumber), which Lune lacks: a small LCG.
	local seed = 7
	local rng = {}
	function rng:NextNumber(a, b)
		seed = (seed * 1103515245 + 12345) % 2147483648
		local u = seed / 2147483648
		return if a then a + (b - a) * u else u
	end
	for _ = 1, 50 do
		local start = Vector3.new(rng:NextNumber(-5, 5), rng:NextNumber(0, 5), rng:NextNumber(-5, 5))
		local direction = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)).Unit
		local points = FlashGate.CracklePoints(rng, start, direction, 1.5, 0.35, 3, Vector3)
		assert(#points == 4 and (points[1] - start).Magnitude < 1e-6, "four points from the start")
		assert(near((points[4] - start):Dot(direction), 1.5, 1e-3) and (points[4] - start - direction * 1.5).Magnitude < 1e-3, "ends straight ahead")
		for index = 2, 3 do
			local along = start + direction * (1.5 * (index - 1) / 3)
			local off = points[index] - along
			assert(off.Magnitude <= 0.35 * math.sqrt(2) + 1e-4 and math.abs(off:Dot(direction)) < 1e-4, "jitter sideways, bounded")
			assert(finite(points[index].X) and finite(points[index].Y) and finite(points[index].Z), "finite")
		end
	end
	pass("maths: mm:ss.cc, clocks, the status of every race phase, rows, names, the board opening downward, dashes, crackles")
end

----------------------------------------------------------------------
-- 4. The gate
----------------------------------------------------------------------
do
	local ARCH, PAD = FlashGate.Arch, FlashGate.Pad
	local summary = nil
	for _, world in WORLDS do
		local gate = RaceArenaBuilder.BuildGate(Instance.new("Folder"), world, ENV)
		assert(gate and gate.Name == "RaceGate" and gate:GetAttribute("RaceGateVersion") == FlashGate.Version
			and RaceArenaBuilder.GateVersion == FlashGate.Version, world .. ": RaceGate v" .. FlashGate.Version)
		assert(gate:GetAttribute("RaceGateAssets") == false and gate:GetAttribute("RaceGateWorld") == world
			and gate:GetAttribute("RaceGateKit") == false, world .. ": attributes")
		local base = RaceArenaBuilder.GateCFrame(world, ENV)
		local inverse = base:Inverse()
		local floorY = U4.Race.Gate[world].Position.Y
		-- Parts only, anchored, no shadow; no meshes, textures, scripts, particles, lights.
		local parts = {}
		for _, d in gate:GetDescendants() do
			assert(not (d:IsA("MeshPart") or d:IsA("Texture") or d:IsA("Decal") or d:IsA("LuaSourceContainer")
				or d:IsA("ParticleEmitter") or d:IsA("Sparkles") or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Light")),
				world .. ": " .. d.ClassName .. " " .. d:GetFullName())
			if d:IsA("BasePart") then
				assert(d.Anchored and not d.CastShadow and d:GetAttribute("RaceArenaPart") == true, world .. ": " .. d.Name .. " anchored, no shadow")
				assert(not d.CanTouch, world .. ": " .. d.Name .. " touches")
				table.insert(parts, d)
			end
		end
		assert(#parts <= RaceArenaBuilder.GatePartBudget and gate:GetAttribute("RaceArenaParts") == #parts,
			world .. ": " .. #parts .. " parts (budget " .. RaceArenaBuilder.GatePartBudget .. ")")
		-- The contract.
		local pad = gate:FindFirstChild("RaceGatePad")
		assert(pad and near(pad.Size.X, 12) and near(pad.Size.Y, 0.4) and near(pad.Size.Z, 12) and pad.Transparency == 1
			and not pad.CanCollide and pad:GetAttribute("PadTriggerHeight") == 10, world .. ": RaceGatePad")
		assert(((inverse * pad.CFrame).Position - Vector3.new(0, 0.2, 0)).Magnitude < 0.02, world .. ": the pad at the floor point")
		local sign = gate:FindFirstChild("RaceGateSign")
		assert(sign and sign:IsA("BillboardGui") and sign.Adornee == gate:FindFirstChild("SignAnchor") and sign.MaxDistance >= 200, world .. ": RaceGateSign")
		for _, name in { "Title", "Status", "Record" } do
			assert(sign:FindFirstChild(name) and sign[name]:IsA("TextLabel"), world .. ": RaceGateSign." .. name)
		end
		local spot = gate:FindFirstChild("FlashSpot")
		local expected = LobbyNpcConfig.FlashBeside(world)
		assert(spot and spot:GetAttribute("FlashSpot") == true and spot.Transparency == 1 and not spot.CanCollide and not spot.CanQuery, world .. ": FlashSpot")
		local feet = spot.CFrame.Position - Vector3.new(0, spot.Size.Y / 2, 0)
		assert((feet - expected.Position).Magnitude < 0.02, world .. ": FlashSpot is LobbyNpcConfig.FlashBeside (the build's Flash)")
		assert(spot.CFrame.LookVector:Dot(base.LookVector) > 0.999, world .. ": Flash faces the players")
		local spotted = LobbyNpcConfig.MarkerSpot(spot.CFrame, spot.Size.Y)
		assert((spotted.Position - expected.Position).Magnitude < 0.02, world .. ": LobbyNpcs reads the same point")
		local anchor = gate:FindFirstChild("HoloBoardAnchor")
		assert(anchor and anchor.Transparency == 1 and not anchor.CanCollide and not anchor.CanQuery, world .. ": HoloBoardAnchor inert")
		assert(near(anchor.Size.X, FlashGate.Board.Width) and near(anchor.Size.Y, FlashGate.Board.Height), world .. ": the anchor is the open board")
		local want = base * FlashGate.BoardLocal(LobbyNpcConfig.FlashBesideGate[world], CFrame)
		assert((anchor.CFrame.Position - want.Position).Magnitude < 0.02 and anchor.CFrame.LookVector:Dot(want.LookVector) > 0.999, world .. ": anchor at BoardLocal")
		-- Past Flash, away from the arch, facing the players (turned a little toward the gate).
		local anchorLocal = inverse * anchor.CFrame
		local flashLocal = inverse * feet
		assert(math.abs(anchorLocal.Position.X) > math.abs(flashLocal.X) + 5, world .. ": the board is past Flash")
		assert(anchorLocal.LookVector.Z < -0.95, world .. ": the board faces the players")
		assert(anchorLocal.Position.Y - FlashGate.Board.Height / 2 >= 2, world .. ": the board floats")

		-- The arch.
		local arch = gate:FindFirstChild("Arch")
		local red, gold = {}, {}
		local lowest, highest = math.huge, -math.huge
		for _, part in arch:GetChildren() do
			local l = inverse * part.CFrame
			local list = if string.sub(part.Name, 1, 3) == "Red" then red else gold
			table.insert(list, { part = part, l = l })
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local p = l * Vector3.new(sx * part.Size.X / 2, sy * part.Size.Y / 2, sz * part.Size.Z / 2)
						lowest, highest = math.min(lowest, p.Y), math.max(highest, p.Y)
					end
				end
			end
		end
		assert(#red == ARCH.Segments + 2, world .. ": " .. #red .. " red pieces")
		local goldArc = 0
		for k = 1, ARCH.Segments do
			if math.abs((k - 0.5) * 180 / ARCH.Segments - 90) >= ARCH.BandGapDegrees then
				goldArc += 1
			end
		end
		assert(#gold == goldArc + 2 and goldArc < ARCH.Segments and goldArc >= ARCH.Segments - 8, world .. ": the gold band stops at the medallion")
		-- As in the reference, the band stops a little short of the medallion: a short stretch of
		-- red shows between its ends and the glow ring (under 2 studs a side).
		local lastGold = 0
		for k = 1, ARCH.Segments do
			local angle = (k - 0.5) * math.pi / ARCH.Segments
			if angle < math.pi / 2 and math.abs(math.deg(angle) - 90) >= ARCH.BandGapDegrees then
				lastGold = angle + math.pi / ARCH.Segments / 2
			end
		end
		local bandEndX = (ARCH.BandInner + ARCH.BandOuter) / 2 * math.cos(lastGold)
		assert(bandEndX > ARCH.Glow and bandEndX < ARCH.Glow + 2, world .. ": the band ends " .. bandEndX .. " studs from the centre line")
		assert(lowest >= -0.01, world .. ": the arch never dips under the floor (" .. lowest .. ")")
		assert(near(highest, ARCH.Leg + ARCH.Outer, 0.1), world .. ": the arch is " .. highest .. " tall")
		for _, side in { "RedLegL", "RedLegR" } do
			local leg = arch:FindFirstChild(side)
			local l = inverse * leg.CFrame
			assert(near(l.Position.Y - leg.Size.Y / 2, 0, 0.01) and leg.CanCollide, world .. ": " .. side .. " on the floor, solid")
		end
		-- Neighbouring red segments meet at the outer edge (a closed, smooth half circle).
		local step = math.pi / ARCH.Segments
		for k = 1, ARCH.Segments - 1 do
			local a, b = arch:FindFirstChild("Red" .. k), arch:FindFirstChild("Red" .. (k + 1))
			local la, lb = inverse * a.CFrame, inverse * b.CFrame
			local outerA = la * Vector3.new(a.Size.X / 2, a.Size.Y / 2, 0)
			local outerB = lb * Vector3.new(b.Size.X / 2, -b.Size.Y / 2, 0)
			assert((outerA - outerB).Magnitude < 0.06, world .. ": red segments " .. k .. "/" .. (k + 1) .. " leave a gap")
			local mid = (k - 0.5) * step
			assert(near(la.Position.X, math.cos(mid) * (ARCH.Inner + ARCH.Outer) / 2, 0.01), world .. ": segment " .. k .. " on the circle")
		end
		-- Symmetric about the gate's centre line.
		for k = 1, ARCH.Segments do
			local a, b = arch:FindFirstChild("Red" .. k), arch:FindFirstChild("Red" .. (ARCH.Segments + 1 - k))
			local pa, pb = (inverse * a.CFrame).Position, (inverse * b.CFrame).Position
			assert(near(pa.X, -pb.X, 0.01) and near(pa.Y, pb.Y, 0.01), world .. ": symmetric")
		end
		-- The gold band: inside the red body's radial extent, proud of both faces.
		assert(ARCH.BandInner > ARCH.Inner and ARCH.BandOuter < ARCH.Outer and ARCH.BandDepth > ARCH.Depth, "gold band inlaid")
		-- The medallion at the top of the band; the bolt through both faces, within the face.
		local medallion = gate:FindFirstChild("Medallion")
		local centreY = ARCH.Leg + (ARCH.BandInner + ARCH.BandOuter) / 2
		for _, name in { "MedallionGlow", "MedallionRim", "MedallionFace" } do
			local part = medallion:FindFirstChild(name)
			local l = inverse * part.CFrame
			assert(part.Shape == roblox.Enum.PartType.Cylinder and near(l.Position.X, 0, 0.01) and near(l.Position.Y, centreY, 0.01)
				and math.abs(l.RightVector.Z) > 0.999, world .. ": " .. name .. " faces the players at the top")
		end
		assert(medallion.MedallionGlow.Material == roblox.Enum.Material.Neon and not medallion.MedallionGlow.CanCollide, world .. ": the glow ring")
		assert(ARCH.Rim > ARCH.Face and ARCH.Glow > ARCH.Rim and ARCH.FaceDepth > ARCH.RimDepth and ARCH.BoltDepth > ARCH.FaceDepth, "medallion layers")
		local bolts = 0
		for _, part in medallion:GetChildren() do
			if string.sub(part.Name, 1, 13) == "MedallionBolt" then
				bolts += 1
				local l = inverse * part.CFrame
				local reach = math.sqrt(l.Position.X ^ 2 + (l.Position.Y - centreY) ^ 2) + part.Size.X / 2
				assert(reach <= ARCH.Face + 0.05 and part.Material == roblox.Enum.Material.Neon, world .. ": the bolt stays on the face")
			end
		end
		assert(bolts == #FlashGate.Bolt, world .. ": the bolt's strokes")
		-- The ring pad: each disc higher than the last, the covers smaller than their glows.
		local ringPad = gate:FindFirstChild("RingPad")
		local order = { "PadBase" }
		for index = 1, #PAD.Rings do
			table.insert(order, "RingGlow" .. index)
			table.insert(order, "RingCover" .. index)
		end
		local lastTop, lastRadius = 0, math.huge
		for _, name in order do
			local disc = ringPad:FindFirstChild(name)
			local l = inverse * disc.CFrame
			local top = l.Position.Y + disc.Size.X / 2
			assert(disc.Shape == roblox.Enum.PartType.Cylinder and math.abs(l.RightVector.Y) > 0.999, world .. ": " .. name .. " lies flat")
			assert(near(l.Position.Y - disc.Size.X / 2, 0, 0.005), world .. ": " .. name .. " on the floor")
			assert(top > lastTop + 0.01, world .. ": " .. name .. " is not above the disc under it")
			assert(disc.Size.Y / 2 < lastRadius, world .. ": " .. name .. " is not inside the disc under it")
			assert(not disc.CanCollide and not disc.CanQuery, world .. ": " .. name .. " trips nobody")
			lastTop, lastRadius = top, disc.Size.Y / 2
		end
		assert(PAD.Radius >= RaceArenaBuilder.GatePadSize / 2, "the ring pad covers the trigger's circle")
		for _, spec in PAD.Dashes do
			assert(spec[2] + spec[4] / 2 <= PAD.Radius, "the dashes stay on the pad")
		end
		-- Walk through: nothing collides over the 12 x 12 pad up to 7.5 studs (a player and his jump).
		for _, part in parts do
			if part.CanCollide then
				local l = inverse * part.CFrame
				for _, sx in { -1, 1 } do
					for _, sy in { -1, 1 } do
						for _, sz in { -1, 1 } do
							local p = l * Vector3.new(sx * part.Size.X / 2, sy * part.Size.Y / 2, sz * part.Size.Z / 2)
							assert(not (math.abs(p.X) < 6 and p.Y < 7.5 and math.abs(p.Z) < 6), world .. ": " .. part.Name .. " blocks the way through")
						end
					end
				end
			end
		end
		assert(ARCH.Inner >= 9 and ARCH.Leg + ARCH.Inner >= 10, "the opening is 18 studs wide and 10 tall")
		local ok, err = pcall(roblox.serializeModel, { gate })
		assert(ok, world .. ": the gate serializes: " .. tostring(err))
		summary = string.format("%d parts, %.1f wide, %.1f tall (medallion top %.1f)", #parts, ARCH.Outer * 2, ARCH.Leg + ARCH.Outer,
			centreY + ARCH.Glow)
		assert(floorY, "floor")
	end
	pass("the gate in 3 worlds: " .. summary .. "; contract, parts only, closed symmetric arch on the floor, inlaid band, bolt medallion, stacked ring pad, walk-through, serializes")
end

----------------------------------------------------------------------
-- 5. The holo board
----------------------------------------------------------------------
do
	local b = FlashGate.Board
	local model = FlashGate.BuildBoard(ENV)
	assert(model:IsA("Model") and model.Name == FlashGate.Names.Board, "the board model")
	local count = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			count += 1
			assert(d.Anchored and not d.CanCollide and not d.CanTouch and not d.CanQuery and not d.CastShadow, d.Name .. " inert")
		end
		assert(not d:IsA("LuaSourceContainer") and not d:IsA("ParticleEmitter"), "no scripts or particles")
		if d:IsA("TextLabel") then
			assert(d.AutoLocalize == false, d:GetFullName() .. " would be auto-translated")
		end
	end
	assert(count == 5, "glass + four edges")
	for _, name in { "EdgeTop", "EdgeBottom", "EdgeLeft", "EdgeRight" } do
		local edge = model:FindFirstChild(name)
		assert(edge.Material == roblox.Enum.Material.Neon, name .. " is Neon")
	end
	local screen = model.Glass:FindFirstChild(FlashGate.Names.Screen)
	assert(screen and screen:IsA("SurfaceGui") and screen.Face == roblox.Enum.NormalId.Front and screen.LightInfluence == 0, "the screen")
	for _, name in { "Back", "Brackets", "Title", "Status", "Caption", "Divider", "List", "Footer", "Bar" } do
		assert(screen:FindFirstChild(name), "the screen lacks " .. name)
	end
	assert(screen.Bar:FindFirstChild("Fill") and screen.List:FindFirstChild("Empty"), "bar fill, empty line")
	for index = 1, b.Rows do
		local row = screen.List:FindFirstChild("Row" .. index)
		assert(row and row:FindFirstChild("Mine") and row:FindFirstChild("Rank") and row:FindFirstChild("PlayerName") and row:FindFirstChild("Time"), "Row" .. index)
	end
	local header = b.Header * b.PixelsPerStud
	local height = b.Height * b.PixelsPerStud
	assert(b.CaptionY + b.CaptionH <= header, "title, status and hint fit the collapsed board")
	assert(b.ListY + b.RowH * b.Rows <= b.FooterY and b.FooterY + b.FooterH <= b.BarY and b.BarY + b.BarH <= height - 4, "rows, footer and bar fit the open board")
	assert(b.Header < b.Height and b.Width >= 8, "sizes")
	local ok, err = pcall(roblox.serializeModel, { model })
	assert(ok, "the board serializes: " .. tostring(err))
	pass("the holo board: glass + 4 Neon edges (inert), the screen's title / status / hint in the header, 5 rows, footer and bar in the open board")
end

----------------------------------------------------------------------
-- 6. Flash hosts the gate
----------------------------------------------------------------------
do
	local def = LobbyNpcPose.Defs.Flash
	local window = LobbyNpcPose.FlashFist
	assert(type(window) == "table" and window[1] < window[2] and window[2] <= def.Loop, "FlashFist inside the loop")
	local out = LobbyNpcPose.NewOut()
	local mid = (window[1] + window[2]) / 2
	LobbyNpcPose.Sample("Flash", 1.7e9 - (1.7e9 % def.Loop) + mid, out)
	assert(out["Right Shoulder"][4] >= 150, "the right fist is up during FlashFist (" .. out["Right Shoulder"][4] .. ")")
	LobbyNpcPose.Sample("Flash", 20, out)
	assert(out["Right Shoulder"][4] < 0 and out["Right Shoulder"][6] > 15 and out["Left Shoulder"][6] < -15, "hero stance: fists on the hips at 20 s")
	-- The loop still holds the idles test_u4_npcs times: the stretch, the watch.
	LobbyNpcPose.Sample("Flash", 4.4, out)
	assert(out["Right Hip"][4] < -50, "the leg stretch at 4.4 s")
	LobbyNpcPose.Sample("Flash", 13.6, out)
	assert(out["Left Shoulder"][4] > 70, "the watch at 13.6 s")
	pass(("Flash's idle (%d s): the hero stance and the lightning fist (%.1f-%.1f s) after his stretches and his watch"):format(def.Loop, window[1], window[2]))
end

----------------------------------------------------------------------
-- 7. build_update4's gate step
----------------------------------------------------------------------
do
	-- 2026-09-26: the part-built flow first, whether or not the owner's kit file is there yet.
	local Kit = require("./u4_flash_gate_kit")
	Kit.SetOverride(false)
	local fakeProcess = { args = { "module" }, exit = function() end, exec = process.exec, env = process.env }
	local chunk = luau.load(read("audit/build_update4.luau"), {
		debugName = "build_update4",
		environment = setmetatable({
			require = function(path)
				if path == "@lune/process" then
					return fakeProcess
				end
				return require(path)
			end,
		}, { __index = _G }),
	})
	local build = chunk()
	assert(type(build) == "table" and type(build.refreshGate) == "function", "module mode exports refreshGate")
	local dm = Instance.new("DataModel")
	local workspace = dm:GetService("Workspace")
	-- The 09-25 part frame, stamped: rebuilt as v2.
	local old = Instance.new("Model")
	old.Name = "RaceGate"
	old:SetAttribute("U4Asset", "RaceGate")
	local lintel = Instance.new("Part")
	lintel.Name = "Lintel"
	lintel.Parent = old
	old.Parent = workspace
	local notes = {}
	assert(build.refreshGate(dm, "World1", notes, false) == true and old.Parent == nil, "an old gate of ours is rebuilt")
	local gate = workspace:FindFirstChild("RaceGate")
	assert(gate and gate:GetAttribute("U4Asset") == "RaceGate" and gate:GetAttribute("RaceGateVersion") == FlashGate.Version
		and gate:FindFirstChild("Arch") and gate:FindFirstChild("HoloBoardAnchor"), "v2 in, stamped")
	assert(string.find(notes[#notes], "replaced v1", 1, true), "the note says what it replaced")
	-- v2: kept; forced: rebuilt.
	assert(build.refreshGate(dm, "World1", notes, false) == false and workspace.RaceGate == gate, "a current gate is kept")
	assert(build.refreshGate(dm, "World1", notes, true) == true and gate.Parent == nil, "--rebuild-gate rebuilds it")
	-- Not ours: never touched, whatever its version.
	workspace.RaceGate.Parent = nil
	local theirs = Instance.new("Model")
	theirs.Name = "RaceGate"
	theirs.Parent = workspace
	assert(build.refreshGate(dm, "World1", notes, true) == false and theirs.Parent == workspace and workspace.RaceGate == theirs,
		"an unstamped (the owner's) gate is never replaced")
	-- No gate at all: built.
	theirs.Parent = nil
	assert(build.refreshGate(dm, "World2", notes, false) == true and workspace.RaceGate:GetAttribute("RaceGateWorld") == "World2", "a missing gate is built")
	-- 2026-09-26 (owner): with the Blender kit our part-built v2 becomes the mesh gate; a mesh gate
	-- is kept, and not turned back into parts when the kit file is gone.
	local manifest = assert(Kit.Manifest(), Kit.ManifestFile .. " is missing (run audit/flash_gate_bpy.py)")
	local v2 = workspace.RaceGate
	assert(v2:GetAttribute("RaceGateVersion") == FlashGate.Version and v2:GetAttribute("RaceGateKit") == false, "the World 2 gate is v2")
	Kit.SetOverride(Kit.StandIn(manifest))
	assert(build.refreshGate(dm, "World2", notes, false) == true and v2.Parent == nil, "a v2 gate of ours becomes the mesh gate")
	local meshGate = workspace.RaceGate
	assert(meshGate:GetAttribute("RaceGateVersion") == FlashGate.MeshVersion and meshGate:GetAttribute("RaceGateKit") == true
		and meshGate:GetAttribute("U4Asset") == "RaceGate" and meshGate.Arch:FindFirstChild("FG_ArchRed"), "the mesh gate, stamped")
	assert(string.find(notes[#notes], "Blender meshes", 1, true) and string.find(notes[#notes], "replaced v2", 1, true), notes[#notes])
	assert(build.refreshGate(dm, "World2", notes, false) == false and workspace.RaceGate == meshGate, "the mesh gate is kept")
	Kit.SetOverride(false)
	assert(build.refreshGate(dm, "World2", notes, false) == false and workspace.RaceGate == meshGate, "no kit: the mesh gate stays (not back to parts)")
	Kit.SetOverride(nil)

	local source = read("audit/build_update4.luau")
	for _, needle in {
		'local REBUILD_GATE = table.find(process.args, "--rebuild-gate") ~= nil',
		'elseif arg == "--rebuild-race" or arg == "--greenhill" or arg == "--rebuild-gate" then',
		"insertRace(dm, key, notes)\n\trefreshGate(dm, key, notes, false)",
		'require("./u4_race_board").Remove(dm, notes)',
		'local want = RaceArenaBuilder.GateVersionFor(FlashGateKit.Load())',
		'assert((tonumber(gate:GetAttribute("RaceGateVersion")) or 0) >= want',
		'local FlashGateKit = require("./u4_flash_gate_kit")',
		'ENV.FlashGateKit = kit or false',
		'ENV.FlashGateKit = FlashGateKit.Load() or false',
		'assert(raceBoard == 0, key .. ": " .. raceBoard .. " old Race_* board parts left")',
	} do
		has(source, needle, "build_update4")
	end
	local runner = read("audit/run_update4_checks.luau")
	has(runner, '{ "audit/test_u4_flash_gate.luau" }', "run_update4_checks lists this test")
	pass("build_update4: an old gate of ours becomes v2, v2 kept unless --rebuild-gate, the owner's gate never touched, a missing one built; "
		.. "with the Blender kit a v2 becomes the mesh gate, kept, never back to parts; verify asks for the kit's version and no old board")
end

----------------------------------------------------------------------
-- 8. The Blender kit (2026-09-26, owner)
----------------------------------------------------------------------
do
	local Kit = require("./u4_flash_gate_kit")
	local MeshKitImport = require("../src/common/ReplicatedStorage/Shared/MeshKitImport")
	local manifest = assert(Kit.Manifest(), Kit.ManifestFile .. " is missing (run audit/flash_gate_bpy.py)")
	local KIT = FlashGate.Kit
	local ARCH = FlashGate.Arch

	-- (a) FlashGate.Kit is the manifest (audit/flash_gate_bpy.py writes both).
	assert(type(KIT) == "table" and #KIT.Pieces == #manifest.pieces and KIT.Triangles == manifest.totalTris, "FlashGate.Kit is the manifest")
	local byName, names = {}, {}
	for index, piece in manifest.pieces do
		local spec = KIT.Pieces[index]
		assert(spec.Name == piece.name and spec.Group == piece.group and spec.Material == piece.material, piece.name .. ": name, group, material")
		for i = 1, 3 do
			assert(near(spec.Size[i], piece.size[i], 1e-3) and near(spec.Offset[i], piece.bboxCenterOffset[i], 1e-3)
				and spec.Color[i] == piece.color[i], piece.name .. ": size, offset, colour")
		end
		assert(spec.CanCollide == piece.canCollide and spec.CastShadow == piece.castShadow and near(spec.Reflectance, piece.reflectance)
			and spec.Triangles == piece.tris, piece.name .. ": flags")
		assert(roblox.Enum.Material[spec.Material], piece.name .. ": a Roblox material")
		assert(table.find({ FlashGate.Names.Arch, FlashGate.Names.Medallion, FlashGate.Names.RingPad }, spec.Group), piece.name .. ": group")
		byName[spec.Name] = spec
		table.insert(names, spec.Name)
	end
	local glow = manifest.gate.medallionGlow
	assert(near(KIT.Glow.Radius, glow.radius) and near(KIT.Glow.Depth, glow.depth) and near(KIT.Glow.Centre[2], glow.centre[2]), "Kit.Glow")
	-- The delivery: binary FBX files with no path of the (non-ASCII) user folder, the OBJ fallbacks,
	-- the renders (the reference side by side) and the owner's guide.
	local DIR = "design/race/flashgate/"
	local function fbxOk(path)
		local bytes = fs.readFile(path)
		assert(string.sub(bytes, 1, 18) == "Kaydara FBX Binary" and not string.find(bytes, "Aoshy", 1, true), path .. ": binary FBX, ASCII-only")
	end
	fbxOk(DIR .. manifest.fbx)
	for _, name in names do
		fbxOk(DIR .. "fbx/" .. name .. ".fbx")
		assert(fs.isFile(DIR .. "obj/" .. name .. ".obj"), name .. ".obj")
	end
	for _, render in { "00_compare_front", "01_front", "02_lobby_flashspot", "03_three_quarter", "04_medallion", "05_back" } do
		assert(fs.isFile(DIR .. "preview/" .. render .. ".png"), "preview/" .. render .. ".png")
	end
	local guide = read(DIR .. "IMPORTAR_ARCO.md")
	for _, needle in { "FlashGateKit.rbxm", "Scale Unit: Stud", "Merge Meshes: DESACTIVADO", [[C:\Users\Public\FlashGateKit\FlashGateKit.fbx]],
		"RenderFidelity = Precise", "CollisionFidelity = Hull" } do
		has(guide, needle, "IMPORTAR_ARCO.md")
	end
	for _, name in names do
		has(guide, name, "IMPORTAR_ARCO.md lists every piece")
	end

	-- (b) Budget, Roblox's limits, the footprint of the part-built gate, the pieces' roles.
	assert(manifest.totalTris <= 25000, manifest.totalTris .. " triangles")
	local sum = 0
	for _, piece in manifest.pieces do
		assert(piece.tris <= 20000 and piece.verts <= 10000 and piece.renderVerts <= 10000, piece.name .. " is over Roblox's mesh limits")
		sum += piece.tris
	end
	assert(sum == manifest.totalTris, "the triangle total")
	local g = manifest.gate
	assert(near(g.inner, ARCH.Inner) and near(g.outer, ARCH.Outer) and near(g.leg, ARCH.Leg) and near(g.depth, ARCH.Depth)
		and near(g.bandInner, ARCH.BandInner) and near(g.bandOuter, ARCH.BandOuter), "the kit's arch is FlashGate.Arch's")
	assert(near(g.width, 2 * ARCH.Outer, 0.01) and near(g.height, ARCH.Leg + ARCH.Outer, 0.01) and near(g.opening, 2 * ARCH.Inner, 0.01),
		"25 wide, 13.5 tall, 18.6 open, as the part-built gate")
	assert(g.medallionTop <= ARCH.SignHeight - 2 and near(g.padRadius, FlashGate.Pad.Radius), "the sign over the medallion, the pad's radius")
	for name, spec in byName do
		local isLeg = name == "FG_LegL" or name == "FG_LegR"
		assert(spec.CanCollide == isLeg, name .. ": only the legs collide")
	end
	assert(byName.FG_Bolt.Material == "Neon" and byName.FG_PadRingCyan.Material == "Neon" and byName.FG_PadRingGold.Material == "Neon", "the Neon pieces")
	-- The rings are FlashGate.Pad.Rings (outer radii), the client's dashes turn over the dark disc between them.
	local rings = FlashGate.Pad.Rings
	assert(near(byName.FG_PadRingCyan.Size[1] / 2, rings[1][2], 0.02) and near(byName.FG_PadRingGold.Size[1] / 2, rings[2][2], 0.02), "ring radii")
	assert(near(byName.FG_PadDisc.Size[1] / 2, FlashGate.Pad.Radius, 0.01) and byName.FG_PadDisc.Size[1] >= RaceArenaBuilder.GatePadSize,
		"the disc covers the trigger")
	assert(g.padTop < FlashGate.Pad.DashHeight - FlashGate.Pad.DashThickness / 2, "the dashes float over the disc")
	for _, name in { "FG_PadDisc", "FG_PadRingCyan", "FG_PadRingGold" } do
		local spec = byName[name]
		assert(spec.Offset[2] + spec.Size[2] / 2 <= 0.6, name .. " stays low (nobody trips; it does not collide)")
	end

	-- (c) Studio's import, simulated: the stand-in kit turned 180 degrees (with an importer wrap and a
	-- SurfaceAppearance to strip) builds the mesh gate in every world.
	local function build(world, standIn)
		local warnings = {}
		local env = table.clone(ENV)
		env.FlashGateKit = standIn
		env.Warn = function(text)
			table.insert(warnings, text)
		end
		return RaceArenaBuilder.BuildGate(Instance.new("Folder"), world, env), warnings
	end
	local function checkMeshGate(world, gate, warnings, standIn, turn, label)
		local tag = world .. " (" .. label .. ")"
		assert(#warnings == 0, tag .. ": " .. table.concat(warnings, "; "))
		assert(gate:GetAttribute("RaceGateVersion") == FlashGate.MeshVersion and gate:GetAttribute("RaceGateKit") == true
			and gate:GetAttribute("RaceGateKitTurn") == turn * 90 and gate:GetAttribute("RaceGateAssets") == false, tag .. ": v3 attributes")
		local base = RaceArenaBuilder.GateCFrame(world, ENV)
		local inverse = base:Inverse()
		local index = MeshKitImport.Index(standIn)
		local count, meshes = 0, 0
		for _, d in gate:GetDescendants() do
			assert(not (d:IsA("LuaSourceContainer") or d:IsA("ParticleEmitter") or d:IsA("SurfaceAppearance") or d:IsA("Texture") or d:IsA("Decal")),
				tag .. ": " .. d.ClassName .. " " .. d:GetFullName())
			if d:IsA("BasePart") then
				count += 1
				assert(d.Anchored and not d.CanTouch and d:GetAttribute("RaceArenaPart") == true, tag .. ": " .. d.Name .. " anchored, no touch")
				if d:IsA("MeshPart") then
					meshes += 1
				end
				-- Walk through: nothing collides over the 12 x 12 pad up to 7.5 studs.
				if d.CanCollide then
					local l = inverse * d.CFrame
					for _, sx in { -1, 1 } do
						for _, sy in { -1, 1 } do
							for _, sz in { -1, 1 } do
								local q = l * Vector3.new(sx * d.Size.X / 2, sy * d.Size.Y / 2, sz * d.Size.Z / 2)
								assert(not (math.abs(q.X) < 6 and q.Y < 7.5 and math.abs(q.Z) < 6), tag .. ": " .. d.Name .. " blocks the way through")
							end
						end
					end
				end
			end
		end
		assert(meshes == #KIT.Pieces and count <= RaceArenaBuilder.GatePartBudget and gate:GetAttribute("RaceArenaParts") == count,
			tag .. ": " .. meshes .. " meshes, " .. count .. " parts")
		for _, stale in { "Red1", "RedLegL", "Gold1", "MedallionRim", "MedallionBolt1", "PadBase", "RingGlow1" } do
			assert(gate:FindFirstChild(stale, true) == nil, tag .. ": part-built " .. stale .. " left in")
		end
		-- Every mesh where the manifest puts it, the import's turn undone, its look from the manifest.
		local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
		for _, spec in KIT.Pieces do
			local group = gate:FindFirstChild(spec.Group)
			local part = group and group:FindFirstChild(spec.Name)
			assert(part and part:IsA("MeshPart") and #part:GetChildren() == 0, tag .. ": " .. spec.Group .. "." .. spec.Name)
			local want = MeshKitImport.TurnedSize(spec.Size, turn)
			assert(near(part.Size.X, want[1]) and near(part.Size.Y, want[2]) and near(part.Size.Z, want[3]), tag .. ": " .. spec.Name .. " size")
			local authored = inverse * (part.CFrame * CFrame.Angles(0, turn * math.pi / 2, 0))
			assert((authored.Position - Vector3.new(spec.Offset[1], spec.Offset[2], spec.Offset[3])).Magnitude < 0.02
				and authored.LookVector:Dot(Vector3.new(0, 0, -1)) > 0.9999 and authored.UpVector:Dot(Vector3.new(0, 1, 0)) > 0.9999,
				tag .. ": " .. spec.Name .. " is not where the manifest puts it, with its axes")
			-- The importer's own pivot (the piece's authored origin) lands on the gate's floor point.
			local source = MeshKitImport.Find(index, spec.Name)
			local k = part.Size.Y / source.Size.Y
			local pivot = part.CFrame * CFrame.new(source.PivotOffset.Position * k)
			assert((pivot.Position - base.Position).Magnitude < 0.03, tag .. ": " .. spec.Name .. "'s imported pivot is off the gate origin by "
				.. (pivot.Position - base.Position).Magnitude)
			assert(((part.CFrame * part.PivotOffset).Position - base.Position).Magnitude < 0.03
				and (part.CFrame * part.PivotOffset).LookVector:Dot(base.LookVector) > 0.9999, tag .. ": " .. spec.Name .. " pivots on the gate origin")
			assert(part.Color == roblox.Color3.fromRGB(spec.Color[1], spec.Color[2], spec.Color[3]) and part.Material == roblox.Enum.Material[spec.Material]
				and near(part.Reflectance, spec.Reflectance) and part.Transparency == 0 and part.CastShadow == spec.CastShadow, tag .. ": " .. spec.Name .. " look")
			assert(part.CanCollide == spec.CanCollide and part.CanQuery == spec.CanCollide and part:GetAttribute("RaceAsset") == FlashGate.KitStamp,
				tag .. ": " .. spec.Name .. " flags")
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local q = inverse * (part.CFrame * Vector3.new(sx * part.Size.X / 2, sy * part.Size.Y / 2, sz * part.Size.Z / 2))
						if spec.Group ~= FlashGate.Names.RingPad then -- the arch and its medallion
							lo = Vector3.new(math.min(lo.X, q.X), math.min(lo.Y, q.Y), math.min(lo.Z, q.Z))
							hi = Vector3.new(math.max(hi.X, q.X), math.max(hi.Y, q.Y), math.max(hi.Z, q.Z))
						end
					end
				end
			end
		end
		-- The part gate's footprint: 25 wide on the floor, about 4 deep, its top under the sign.
		assert(near(hi.X - lo.X, 2 * ARCH.Outer, 0.05) and near(lo.Y, 0, 0.02) and hi.Z - lo.Z <= 4 and hi.Y >= ARCH.Leg + ARCH.Outer
			and hi.Y <= ARCH.SignHeight - 2, tag .. ": the arch's box " .. tostring(hi - lo) .. " from " .. tostring(lo))
		for _, name in { "FG_LegL", "FG_LegR" } do
			local leg = gate.Arch[name]
			local l = inverse * leg.CFrame
			assert(near(l.Position.Y - leg.Size.Y / 2, 0, 0.02) and leg.CanCollide, tag .. ": " .. name .. " stands on the floor, solid")
			assert((name == "FG_LegL") == (l.Position.X < 0), tag .. ": " .. name .. " on the gate's " .. (if name == "FG_LegL" then "left" else "right"))
		end
		-- MedallionGlow: a Neon cylinder Part around the mesh rim (the client breathes it).
		local glowPart = gate.Medallion:FindFirstChild(FlashGate.Names.MedallionGlow)
		local l = inverse * glowPart.CFrame
		assert(glowPart.ClassName == "Part" and glowPart.Shape == roblox.Enum.PartType.Cylinder and glowPart.Material == roblox.Enum.Material.Neon
			and not glowPart.CanCollide and math.abs(l.RightVector.Z) > 0.999 and near(l.Position.Y, KIT.Glow.Centre[2], 0.02)
			and near(l.Position.X, 0, 0.02) and glowPart.Size.Y / 2 > byName.FG_MedallionRim.Size[2] / 2, tag .. ": MedallionGlow around the rim")
		assert(gate:FindFirstChild("MedallionGlow", true) == glowPart, tag .. ": the client finds MedallionGlow")
		-- The contract, as the part-built gate has it.
		local pad = gate:FindFirstChild("RaceGatePad")
		assert(pad and near(pad.Size.X, 12) and near(pad.Size.Y, 0.4) and pad.Transparency == 1 and not pad.CanCollide
			and pad:GetAttribute("PadTriggerHeight") == 10 and ((inverse * pad.CFrame).Position - Vector3.new(0, 0.2, 0)).Magnitude < 0.02, tag .. ": RaceGatePad")
		local sign = gate:FindFirstChild("RaceGateSign")
		assert(sign and sign:IsA("BillboardGui") and sign.Adornee == gate:FindFirstChild("SignAnchor") and sign:FindFirstChild("Title")
			and sign:FindFirstChild("Status") and sign:FindFirstChild("Record"), tag .. ": RaceGateSign")
		assert((inverse * sign.Adornee.CFrame).Position.Y > hi.Y, tag .. ": the sign over the gate")
		local spot = gate:FindFirstChild("FlashSpot")
		local expected = LobbyNpcConfig.FlashBeside(world)
		assert(spot and ((spot.CFrame.Position - Vector3.new(0, spot.Size.Y / 2, 0)) - expected.Position).Magnitude < 0.02, tag .. ": FlashSpot")
		local anchor = gate:FindFirstChild("HoloBoardAnchor")
		local wantBoard = base * FlashGate.BoardLocal(LobbyNpcConfig.FlashBesideGate[world], CFrame)
		assert(anchor and (anchor.CFrame.Position - wantBoard.Position).Magnitude < 0.02 and not anchor.CanCollide, tag .. ": HoloBoardAnchor")
		local ok, err = pcall(roblox.serializeModel, { gate })
		assert(ok, tag .. ": the gate serializes: " .. tostring(err))
	end
	for _, world in WORLDS do
		local standIn = Kit.StandIn(manifest, { turn = 2, wrap = true, surfaceAppearance = true })
		local gate, warnings = build(world, standIn)
		checkMeshGate(world, gate, warnings, standIn, 2, "Studio's 180-degree turn")
	end
	assert(RaceArenaBuilder.GateVersionFor(nil) == FlashGate.Version and RaceArenaBuilder.GateVersionFor(Kit.StandIn(manifest)) == FlashGate.MeshVersion
		and FlashGate.MeshVersion > FlashGate.Version, "GateVersionFor")

	-- (d) Any quarter turn, an importer's name suffix, another import unit: the same gate.
	for _, turn in { 0, 1, 3 } do
		local standIn = Kit.StandIn(manifest, { turn = turn })
		local gate, warnings = build("World1", standIn)
		checkMeshGate("World1", gate, warnings, standIn, turn, turn * 90 .. "-degree turn")
	end
	local suffixed = Kit.StandIn(manifest, { rename = { FG_ArchRed = "FG_ArchRed.001", FG_Bolt = "FG_Bolt_Mesh" } })
	local gate, warnings = build("World3", suffixed)
	checkMeshGate("World3", gate, warnings, suffixed, 2, "importer suffixes")
	local metres = Kit.StandIn(manifest, { scale = 0.01 })
	gate, warnings = build("World2", metres)
	checkMeshGate("World2", gate, warnings, metres, 2, "1/100 import scale")

	-- The owner's kit itself (design/race/flashgate/FlashGateKit.rbxm), once it is saved.
	local real = Kit.Load()
	if real then
		local turn = RaceArenaBuilder.ResolveGateKit(real)
		assert(turn.ok, Kit.KitFile .. " does not fit: " .. table.concat(turn.problems, "; "))
		for _, world in WORLDS do
			gate, warnings = build(world, real)
			checkMeshGate(world, gate, warnings, real, turn.turn, "the owner's " .. Kit.KitFile)
		end
		print(("  the owner's kit: fits, the import turned it %d degrees"):format(turn.turn * 90))
	else
		print("  no " .. Kit.KitFile .. " yet (design/race/flashgate/IMPORTAR_ARCO.md): the build keeps the part-built gate")
	end

	-- (e) A kit that does not fit is reported and the parts are built.
	local function fallsBack(label, standIn, needle)
		local built, notes = build("World1", standIn)
		assert(built:GetAttribute("RaceGateVersion") == FlashGate.Version and built:GetAttribute("RaceGateKit") == false
			and built.Arch:FindFirstChild("Red1") and not built:FindFirstChild("FG_ArchRed", true), label .. ": the parts are built")
		assert(#notes == 1 and string.find(notes[1], needle, 1, true), label .. ": warned (" .. tostring(notes[1]) .. ")")
		assert(RaceArenaBuilder.GateVersionFor(standIn) == FlashGate.Version, label .. ": GateVersionFor")
	end
	fallsBack("a missing piece", Kit.StandIn(manifest, { omit = { FG_BandGold = true } }), "FG_BandGold is missing")
	local asPart = Kit.StandIn(manifest)
	local wrong = asPart:FindFirstChild("FG_Bolt", true)
	local block = Instance.new("Part")
	block.Name, block.Size, block.CFrame, block.Parent = "FG_Bolt", wrong.Size, wrong.CFrame, wrong.Parent
	wrong.Parent = nil
	fallsBack("a Part for a mesh", asPart, "FG_Bolt is a Part")
	local squashed = Kit.StandIn(manifest)
	local rim = squashed:FindFirstChild("FG_MedallionRim", true)
	rim.Size = Vector3.new(rim.Size.X, rim.Size.Y * 0.5, rim.Size.Z)
	fallsBack("a wrong shape", squashed, "FG_MedallionRim has the wrong shape")
	local scrambled = Kit.StandIn(manifest)
	for _, part in scrambled:GetDescendants() do
		if part:IsA("MeshPart") then
			part.PivotOffset = CFrame.new(part.PivotOffset.Position.Z + 3, 0, -part.PivotOffset.Position.X)
		end
	end
	fallsBack("scrambled pivots", scrambled, "match no quarter turn")
	pass(("the Blender kit: %d meshes, %d triangles (<= 25000), FlashGate.Kit = the manifest, the part gate's footprint; Studio's 180-degree "
		.. "import (and 0/90/270, suffixes, 1/100 scale) builds v%d in 3 worlds with the turn undone, the manifest's look, only the legs "
		.. "colliding, the contract parts; a kit that does not fit falls back to the parts with a warning"):format(#KIT.Pieces, KIT.Triangles, FlashGate.MeshVersion))
end

print(("test_u4_flash_gate: %d checks passed"):format(passed))
