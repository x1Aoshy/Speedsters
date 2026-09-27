-- audit/test_u4_egg_mobile.luau  (Update 4, 2026-09-26, owner: Dr. Eggman in his Egg Mobile)
-- 2026-09-26 (owner): the ship is the Blender kit (audit/egg_mobile_bpy.py -> design/npc/eggmobile/, the
-- owner's Studio import saved as design/npc/EggMobileKit.rbxm); there is no part-built ship any more. This
-- test builds it from a stand-in kit (MeshParts sized from the manifest, their pivots turned 180 degrees the
-- way Studio's Import 3D turned the Green Hill kit), so it runs before the owner has imported anything.
-- Checks:
--   1. the sources compile; no CFrame.lookAt, no particles or sparkles, no local content, no part-built ship
--      left; the client is tiered, distance- and screen-gated, on the server clock; LobbyNpcsClient plays
--      the driving pose with the player's aim and the Talk reaction, and leaves the "!" to the sign;
--   2. the manifest agrees with Shared/EggMobile (seat, levers, fan, rim...) and Roblox's mesh limits;
--   3. the ship from the stand-in kit: every piece where the manifest puts it (the import's turn read from
--      the pivots and undone; a quarter turn too), coloured from the manifest, joined to the hull root (Welds;
--      Motor6Ds for the rear fan and both levers at their pivots), four invisible colliders loose, the stamp,
--      size, joints hold, survives a place round trip; Eggman seated (Problems empty). Without the kit:
--      no ship, Eggman stands, and a place still carrying an old ship fails Verify;
--   4. as the server adopts him (LobbyNpcRig.PrepareOwnerModel): his root holds the ship, the R6 joints are
--      the ones posed, the colliders stay put;
--   5. the driving animations (forward kinematics on the owner's R6 Eggman in the ship, 20 samples a second
--      over the loop, with players to his left, right and ahead, with the Talk and Laugh reactions): finite,
--      legs under the cockpit floor and inside the hull, chest and head over the rim, arms inside the
--      cockpit, fists on the levers except while LobbyNpcPose.HandsFree says a hand is off (then clear of its
--      lever, so the client lets it go), the "come here" hand points at the player;
--   6. the hover (frame-rate independent, smooth, bounded, the hull never near the floor, periods and phase
--      shared with the pose) and the lever aim maths;
--   7. the three lobbies (read from the .rbxl files, never written): the ship built in memory at Eggman's
--      spot is clear of every lobby part and feature, of Flash and of the portal flight's shot, Eggman in
--      sight of the spawn, and nothing of it trips audit/test_u4_npcs' floor rules;
--   8. with "places" (after audit/build_update4): each place passes u4_egg_mobile.Verify (the kit ship with
--      Eggman seated when design/npc/EggMobileKit.rbxm exists, else no ship and Eggman standing). Without
--      "places" a place's ship is reported (an old part-built one: the next build removes it).
--   lune run audit/test_u4_egg_mobile.luau [places]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Vector3, CFrame = roblox.Vector3, roblox.CFrame

local EggMobile = require("../src/common/ReplicatedStorage/Shared/EggMobile")
local LobbyNpcConfig = require("../src/common/ReplicatedStorage/Shared/LobbyNpcConfig")
local LobbyNpcPose = require("../src/common/ReplicatedStorage/Shared/LobbyNpcPose")
local LobbyNpcRig = require("../src/common/ReplicatedStorage/Shared/LobbyNpcRig")
local Seat = require("./u4_egg_mobile")
local KitImport = require("./kit_import")
local PlaceFiles = require("./place_files")

local SHARED = "src/common/ReplicatedStorage/Shared/"
local MODULE_FILE = SHARED .. "EggMobile.luau"
local CLIENT_FILE = "src/common/StarterPlayer/StarterPlayerScripts/Gameplay/EggMobileClient.client.luau"
local NPC_CLIENT_FILE = "src/common/StarterPlayer/StarterPlayerScripts/Gameplay/LobbyNpcsClient.client.luau"
local CHARACTERS = "design/npc/LobbyCharacters.rbxm"
local PLACES_MODE = process.args[1] == "places"
local ENV = Seat.ENV

local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end
local function finite(n)
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end
local function v3(p)
	return Vector3.new(p[1], p[2], p[3])
end
local function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-6)
end

----------------------------------------------------------------------
-- 1. Sources
----------------------------------------------------------------------
do
	for _, path in { MODULE_FILE, CLIENT_FILE, NPC_CLIENT_FILE, SHARED .. "LobbyNpcPose.luau", "audit/u4_egg_mobile.luau", "audit/kit_import.luau" } do
		local source = fs.readFile(path)
		local ok, problem = pcall(luau.compile, source)
		assert(ok, "SYNTAX " .. path .. ": " .. tostring(problem))
		assert(not string.find(source, "lookAt(", 1, true), path .. ": CFrame.lookAt (wrong in Lune)")
	end
	for _, path in { MODULE_FILE, CLIENT_FILE } do
		-- The code, without its comments (they quote the owner's "NO sparkles").
		local source = string.gsub(fs.readFile(path), "%-%-[^\n]*", "")
		for _, banned in { "ParticleEmitter", "sparkles", "Sparkles", "rbxasset://textures", "rbxassetid://", "MeshId", "Fire\")", "Smoke\")" } do
			assert(not string.find(source, banned, 1, true), path .. " uses " .. banned .. " (the owner: no sparkles, no generic particles, nothing to upload)")
		end
	end
	-- 2026-09-26 (owner): the part-built ship is gone for good.
	local module = string.gsub(fs.readFile(MODULE_FILE), "%-%-[^\n]*", "")
	for _, gone in { "SpecialMesh", "\"Rim\"", "\"Rivet\"", "LogoPlate", "Builder:part", "b:tube" } do
		assert(not string.find(module, gone, 1, true), MODULE_FILE .. " still builds the part-built ship (" .. gone .. ")")
	end
	assert(string.find(module, "EggMobile.Build needs the Blender kit", 1, true), "Build must refuse to run without the kit")
	local client = fs.readFile(CLIENT_FILE)
	for _, needle in {
		"RaceFeelTier.Detect(meter)", "Workspace:GetServerTimeNow()", "RunService.Stepped:Connect", "budget.MotionRadius",
		"visible(camera, ship.pivot.Position, distance)", "CLIENT.VfxRadius", "beam.LightEmission = 1", "gui.MaxDistance = config.MaxDistance",
		"LobbyNpcConfig.KillAttribute", "CollectionService:GetInstanceRemovedSignal(EGGMAN_TAG)", "EggMobile.HoverCFrame(t, CFrame)",
		"EggMobile.StickAngles(", "QuestRewardReady", "QuestAvailable", "LobbyNpcText.Style(word, lang)", "rest(ship)",
		"(stick.length + GRIP_SLACK - rel.Magnitude) / GRIP_FADE", "kind == \"Lamp\"",
	} do
		assert(string.find(client, needle, 1, true), "EggMobileClient lacks " .. needle)
	end
	-- One root write moves the ship; nothing else in the ship is moved part by part.
	assert(not string.find(client, "BulkMoveTo", 1, true) and not string.find(client, "PivotTo", 1, true), "the client moves the ship part by part")
	local _, rootWrites = string.gsub(client, "ship%.root%.CFrame = ", "")
	assert(rootWrites == 2, "the root is written by the hover and the rest only (" .. rootWrites .. ")")
	local npcClient = fs.readFile(NPC_CLIENT_FILE)
	for _, needle in {
		"local def = LobbyNpcPose.Defs[npc.poseKind]", "LobbyNpcPose.Sample(npc.poseKind, t, npc.out, npc.reaction, age, aim)",
		"poseKind = if kind == \"Eggman\" and model:FindFirstChild(EggMobile.ModelName) then EggMobile.PoseKind else kind,",
		"if npc.kind == \"Eggman\" and npc.poseKind == npc.kind then", "updateAim(npc, def, t)", "def.TalkReaction",
		"math.exp(-3 * dt)",
	} do
		assert(string.find(npcClient, needle, 1, true), "LobbyNpcsClient lacks " .. needle)
	end
	local tiers = EggMobile.Client.Tiers
	assert(tiers.High and tiers.Mid and tiers.Low, "the three RaceFeelTier tiers")
	assert(tiers.Low.MotionRadius < tiers.Mid.MotionRadius and tiers.Mid.MotionRadius <= tiers.High.MotionRadius and tiers.High.MotionRadius <= 150,
		"motion radii grow with the tier, at most 150 studs")
	assert(tiers.Low.Hz and tiers.Low.Hz <= 30 and not tiers.Low.PlasmaLight and not tiers.Low.SirenLight and not tiers.Low.Exhaust and not tiers.Low.Pulse,
		"Low: reduced rate, no lights, no jets, no pulse")
	assert(tiers.Low.PlasmaBeams == 1 and tiers.High.PlasmaBeams == 2, "plasma beams per tier")
	for name, budget in tiers do
		assert(math.deg(budget.FanSpeed / (budget.Hz or 60)) < 45, name .. ": the fan would strobe")
	end
	for _, lang in { "en", "es", "pt", "ru", "ar", "id", "fr", "de", "th", "tr" } do
		assert(type(EggMobile.SignWords[lang]) == "string" and EggMobile.SignWords[lang] ~= "", "no sign word for " .. lang)
	end
	assert(EggMobile.SignWord("xx") == "QUESTS" and EggMobile.SignWord("es") == "MISIONES", "sign word fallbacks")
	assert(EggMobile.Client.Sign.MaxDistance >= 160 and EggMobile.Client.Sign.MaxDistance <= 260, "the sign's MaxDistance")
	pass("sources compile; no lookAt, particles, sparkles, local content or part-built ship; the client is tiered ("
		.. tiers.Low.MotionRadius .. "/" .. tiers.Mid.MotionRadius .. "/" .. tiers.High.MotionRadius .. " studs), gated, on the server clock; LobbyNpcsClient passes the aim and plays Talk")
end

----------------------------------------------------------------------
-- 2. The manifest against Shared/EggMobile and Roblox's limits
----------------------------------------------------------------------
local manifest = Seat.ReadManifest()
do
	assert(manifest.kitVersion == EggMobile.KitVersion, "manifest kitVersion " .. tostring(manifest.kitVersion) .. " vs EggMobile.KitVersion " .. EggMobile.KitVersion)
	local ship = manifest.ship
	local function same(a, b, what)
		assert(#a == #b, what .. ": sizes")
		for i = 1, #a do
			assert(near(a[i], b[i], 1e-3), ("%s: %s vs %s"):format(what, table.concat(a, ","), table.concat(b, ",")))
		end
	end
	same(ship.seatRoot, EggMobile.SeatRoot, "seat root")
	same(ship.hullCenter, EggMobile.HullCenter, "hull centre")
	same(ship.fanPivot, EggMobile.FanPivot, "fan pivot")
	assert(near(ship.floorTop, EggMobile.FloorTop) and near(ship.rimTop, EggMobile.RimTop) and near(ship.rimInner, EggMobile.RimInner)
		and near(ship.hullRadius, EggMobile.HullRadius), "floor / rim / hull radius")
	for key, spec in { R = EggMobile.Sticks.Right, L = EggMobile.Sticks.Left } do
		local s = ship.sticks[key]
		same(s.pivot, spec.Pivot, "lever " .. key)
		assert(near(s.length, spec.Length) and s.side == spec.Side, "lever " .. key .. " length / side")
	end
	assert(near(ship.nozzle.y, EggMobile.Nozzle.Y) and near(ship.nozzle.z, EggMobile.Nozzle.Z), "the nozzle")
	local names, glows, roles, total = {}, {}, { fan = 0, stick = 0 }, 0
	for _, entry in manifest.pieces do
		assert(string.sub(entry.name, 1, 3) == EggMobile.PiecePrefix and not names[entry.name], "piece name " .. entry.name)
		names[entry.name] = true
		assert(entry.tris <= 20000 and entry.verts <= 10000 and entry.renderVerts <= 10000, entry.name .. " over Roblox's mesh limits")
		for i = 1, 3 do
			assert(entry.size[i] > 0 and entry.size[i] < 2048, entry.name .. " size")
		end
		assert(roblox.Enum.Material[entry.material] ~= nil, entry.name .. ": material " .. tostring(entry.material))
		assert(entry.role == "static" or entry.role == "glow" or entry.role == "fan" or entry.role == "stick", entry.name .. ": role " .. tostring(entry.role))
		if entry.role == "glow" then
			assert(entry.material == "Neon" and type(entry.glow) == "string", entry.name .. ": a glow is Neon with a kind")
			glows[entry.glow] = true
		end
		if entry.role == "fan" or entry.role == "stick" then
			roles[entry.role] += 1
			assert(entry.side == 1 or entry.side == -1, entry.name .. ": a moving piece has a side")
			local want = if entry.role == "fan" then EggMobile.FanPivot elseif entry.side > 0 then EggMobile.Sticks.Right.Pivot else EggMobile.Sticks.Left.Pivot
			same(entry.motorPivot, want, entry.name .. " motor pivot")
		end
		total += entry.tris
	end
	assert(total == manifest.totalTris and total <= 40000, "total tris " .. total)
	assert(roles.fan == 1 and roles.stick == 2, "one rear fan, two levers")
	for _, kind in { "Plasma", "PlasmaCore", "Exhaust", "Lamp", "Screen" } do
		assert(glows[kind], "no glow piece " .. kind)
	end
	assert(names.EM_LogoRed and names.EM_Glass and names.EM_Seat and names.EM_HullWhite and names.EM_HullBlack, "the logo, glass, bench and hull pieces")
	assert(manifest.reimportCheck and manifest.reimportCheck.worstErrorStuds < 0.01 and #manifest.reimportCheck.missing == 0, "the FBX re-import check")
	pass(("the manifest (kit v%d, %d pieces, %d tris) agrees with Shared/EggMobile: seat, levers, fan, nozzle, rim; every piece within Roblox's limits")
		:format(manifest.kitVersion, #manifest.pieces, total))
end

----------------------------------------------------------------------
-- Geometry helpers
----------------------------------------------------------------------
local function boxOf(part)
	local cf, size = part.CFrame, part.Size
	local lo = { math.huge, math.huge, math.huge }
	local hi = { -math.huge, -math.huge, -math.huge }
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local p = cf * Vector3.new(sx * size.X / 2, sy * size.Y / 2, sz * size.Z / 2)
				lo[1], lo[2], lo[3] = math.min(lo[1], p.X), math.min(lo[2], p.Y), math.min(lo[3], p.Z)
				hi[1], hi[2], hi[3] = math.max(hi[1], p.X), math.max(hi[2], p.Y), math.max(hi[3], p.Z)
			end
		end
	end
	return { x0 = lo[1], y0 = lo[2], z0 = lo[3], x1 = hi[1], y1 = hi[2], z1 = hi[3] }
end

-- Is `point` inside `part` (its shape: Ball, Cylinder along X, else the box)? A kit MeshPart counts by the
-- ellipsoid in its box: its box corners are air (a hazard band's box spans the whole hull); the ship's
-- colliders stand for its real volume with their own shapes.
local function inside(part, point)
	local rel = part.CFrame:PointToObjectSpace(point)
	local half = part.Size / 2
	if part:IsA("MeshPart") then
		local q = Vector3.new(rel.X / half.X, rel.Y / half.Y, rel.Z / half.Z)
		return q.Magnitude <= 1
	end
	local ok, shape = pcall(function()
		return part.Shape
	end)
	if ok and shape == roblox.Enum.PartType.Ball then
		return rel.Magnitude <= math.min(half.X, half.Y, half.Z)
	elseif ok and shape == roblox.Enum.PartType.Cylinder then
		local r = math.min(half.Y, half.Z)
		return math.abs(rel.X) <= half.X and rel.Y * rel.Y + rel.Z * rel.Z <= r * r
	end
	return math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z
end

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

-- Every part's CFrame with the Motor6Ds at `transforms`, from the anchored parts outward.
local function posed(model, transforms)
	local frames = {}
	local joints = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") or d:IsA("Weld") then
			table.insert(joints, d)
		elseif d:IsA("BasePart") and d.Anchored then
			frames[d] = d.CFrame
		end
	end
	local progress = true
	while progress do
		progress = false
		for _, joint in joints do
			if joint.Part0 and joint.Part1 then
				if frames[joint.Part0] and not frames[joint.Part1] then
					frames[joint.Part1] = frames[joint.Part0] * joint.C0 * (transforms[joint] or CFrame.new()) * joint.C1:Inverse()
					progress = true
				end
			end
		end
	end
	return frames
end

local function transformsAt(model, kind, t, reaction, age, aim)
	local out = LobbyNpcPose.Sample(kind, t, LobbyNpcPose.NewOut(), reaction, age, aim)
	local transforms = {}
	for _, joint in (LobbyNpcRig.FindJoints(model)) do
		local basis = joint.motor.C0.Rotation
		transforms[joint.motor] = basis:Inverse() * LobbyNpcPose.ToCFrame(out[joint.name], CFrame) * basis
	end
	return transforms, out
end

-- The owner's R6 Eggman standing on `floor` (as audit/build_update4 places him).
local characters = roblox.deserializeModel(fs.readFile(CHARACTERS))[1]
local function standingEggman(floor)
	local model = characters:FindFirstChild("Eggman"):Clone()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = floor * d.CFrame
		end
	end
	return model
end

-- The stand-in kit as Studio would import it (turned 180 degrees), and the kit the builder gets from it.
local function standInKit(yaw)
	return Seat.KitFromFolder(Seat.StandInKit(manifest, yaw), manifest)
end
local KIT = standInKit(math.pi)

----------------------------------------------------------------------
-- 3. The ship
----------------------------------------------------------------------
local FLOOR = CFrame.new(40, 10, -25) * CFrame.Angles(0, math.rad(35), 0)
local eggman = standingEggman(FLOOR)
assert(near(KIT.importYaw, math.pi, 1e-9) and #KIT.warnings == 0, "the stand-in's 180-degree import turn is read from its pivots: "
	.. math.deg(KIT.importYaw) .. " " .. table.concat(KIT.warnings, "; "))
local ship, report = Seat.Seat(eggman, FLOOR, KIT)
local hull = ship:FindFirstChild(EggMobile.HullName)
local shipParts, colliders, meshes = {}, {}, {}
local specByName = {}
for _, spec in KIT.specs do
	specByName[spec.name] = spec
end
do
	assert(#report.missing == 0 and report.pieces == #manifest.pieces, "every kit piece built")
	local problems = Seat.Problems(eggman, FLOOR)
	assert(#problems == 0, "u4_egg_mobile.Problems: " .. table.concat(problems, "; "))
	local r6Names = {}
	for _, names in LobbyNpcConfig.JointMap do
		for _, name in names do
			r6Names[name] = true
		end
	end
	local motors = { EggFanMotor = 0, EggStickMotor = 0 }
	local turned = CFrame.Angles(0, -math.pi, 0)
	for _, d in ship:GetDescendants() do
		assert(not d:IsA("LuaSourceContainer"), "a script in the ship")
		for _, class in { "Decal", "Texture", "ParticleEmitter", "Sparkles", "Fire", "Smoke", "Seat", "VehicleSeat", "UnionOperation", "SpecialMesh", "SurfaceAppearance" } do
			assert(not d:IsA(class), "the ship holds a " .. class .. ": " .. d:GetFullName())
		end
		if d:IsA("Motor6D") then
			assert(not r6Names[d.Name], d.Name .. ": a ship motor named like a pose joint")
			assert(motors[d.Name] ~= nil, "unknown motor " .. d.Name)
			motors[d.Name] += 1
			assert(d.Part0 == hull, d.Name .. " hangs off the hull root")
			-- The motor turns its piece about the builder's pivot.
			local pivot = if d.Name == "EggFanMotor" then EggMobile.FanPivot
				elseif d.Part1:GetAttribute("EggStick") == 1 then EggMobile.Sticks.Right.Pivot else EggMobile.Sticks.Left.Pivot
			assert(((hull.CFrame * d.C0).Position - (FLOOR * v3(pivot))).Magnitude < 1e-3, d.Name .. " is not at its pivot")
		elseif d:IsA("BasePart") then
			assert(d.Anchored and not d.CanTouch, d.Name .. ": anchored as saved, never touchable")
			if d:GetAttribute("EggCollider") then
				table.insert(colliders, d)
				assert(d.ClassName == "Part" and d.CanCollide and d.CanQuery and d.Transparency == 1 and not d.CastShadow, d.Name .. ": an invisible collider")
			elseif d == hull then
				assert(d.ClassName == "Part" and d.Transparency == 1 and not d.CanCollide and not d.CanQuery, "the hull root is an invisible part")
			else
				assert(d:IsA("MeshPart"), d:GetFullName() .. " is a " .. d.ClassName .. " (only kit pieces)")
				table.insert(shipParts, d)
				table.insert(meshes, d)
				assert(not d.CanCollide and not d.CanQuery, d.Name .. " collides or blocks rays")
				local spec = assert(specByName[d.Name], "no manifest entry for " .. d.Name)
				-- Where the manifest puts it, the import's turn undone; coloured from the manifest.
				local want = FLOOR * CFrame.new(spec.offset) * turned
				assert((d.CFrame.Position - want.Position).Magnitude < 1e-4 and (d.CFrame.LookVector - want.LookVector).Magnitude < 1e-4, d.Name .. " is not where the manifest puts it")
				assert((d.Size - spec.size).Magnitude < 1e-4, d.Name .. " size")
				local c = d.Color
				assert(math.abs(c.R * 255 - spec.color[1]) < 0.6 and math.abs(c.G * 255 - spec.color[2]) < 0.6 and math.abs(c.B * 255 - spec.color[3]) < 0.6, d.Name .. " colour")
				assert(d.Material == roblox.Enum.Material[spec.material] and near(d.Transparency, spec.transparency or 0, 1e-4) and d.CastShadow == (spec.castShadow == true), d.Name .. " material / transparency / shadow")
				assert(d:GetAttribute("EggGlow") == spec.glow, d.Name .. " glow attribute")
			end
		end
	end
	assert(motors.EggFanMotor == 1 and motors.EggStickMotor == 2, "one fan, two levers")
	assert(#colliders == EggMobile.ColliderCount, #colliders .. " colliders")
	assert(#meshes == #manifest.pieces, #meshes .. " kit pieces")
	local count = #shipParts + #colliders + 1
	assert(count == ship:GetAttribute("EggMobileParts") and count <= EggMobile.PartBudget, count .. " parts")
	assert(ship:GetAttribute("EggMobileLook") == "Kit" and ship:GetAttribute("EggMobileImportYaw") == 180 and ship:GetAttribute("EggMobileKitVersion") == manifest.kitVersion, "the kit stamps")
	-- Everything but the colliders is joined to the hull; the colliders to nothing.
	local joined = LobbyNpcRig.JoinedParts(ship, hull)
	for _, part in shipParts do
		assert(joined[part], part.Name .. " is not joined to the hull")
	end
	for _, part in colliders do
		assert(not joined[part], part.Name .. " (a collider) is joined: the hover would move it")
	end
	-- The size, in ship space (the ship is turned 35 degrees here: measured around it).
	local shipLo, shipHi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in shipParts do
		local cf, size = part.CFrame, part.Size
		for _, sx in { -0.5, 0.5 } do
			for _, sy in { -0.5, 0.5 } do
				for _, sz in { -0.5, 0.5 } do
					local p = FLOOR:PointToObjectSpace(cf * Vector3.new(sx * size.X, sy * size.Y, sz * size.Z))
					shipLo = Vector3.new(math.min(shipLo.X, p.X), math.min(shipLo.Y, p.Y), math.min(shipLo.Z, p.Z))
					shipHi = Vector3.new(math.max(shipHi.X, p.X), math.max(shipHi.Y, p.Y), math.max(shipHi.Z, p.Z))
				end
			end
		end
	end
	local size = shipHi - shipLo
	assert(size.X <= 11.5 and size.Z <= 9.6 and shipHi.Y <= EggMobile.Footprint.Top + 0.05 and shipLo.Y >= 0.5, "ship size " .. tostring(size) .. " top " .. shipHi.Y)
	-- The fan spins about its own centre; a lever tilts about its pivot.
	for _, d in ship:GetDescendants() do
		if d:IsA("Motor6D") then
			local spin = CFrame.Angles(0, 0, math.rad(90))
			local tilt = CFrame.Angles(math.rad(20), 0, 0)
			local before = d.Part1.CFrame
			local after = hull.CFrame * d.C0 * (if d.Name == "EggFanMotor" then spin else tilt) * d.C1:Inverse()
			local pivot = hull.CFrame * d.C0
			assert(near((before.Position - pivot.Position).Magnitude, (after.Position - pivot.Position).Magnitude, 1e-4), d.Name .. ": the piece does not turn about its pivot")
			if d.Name == "EggFanMotor" then
				local axis = pivot:VectorToWorldSpace(Vector3.new(0, 0, 1))
				local off = before.Position - pivot.Position
				assert((off - axis * off:Dot(axis)).Magnitude < 0.02, "the fan is not centred on its axis")
			end
		end
	end
	-- A quarter turn (another import) builds the same world boxes; no turn at all too.
	for _, yaw in { math.pi / 2, 0 } do
		local kit = standInKit(yaw)
		assert(near(kit.importYaw, yaw, 1e-9), "import turn " .. math.deg(yaw) .. " read as " .. math.deg(kit.importYaw))
		local other = EggMobile.Build(ENV, FLOOR, kit)
		for _, part in shipParts do
			local twin = other:FindFirstChild(part.Name)
			local a, b = boxOf(part), boxOf(twin)
			assert(math.abs(a.x0 - b.x0) + math.abs(a.y0 - b.y0) + math.abs(a.z0 - b.z0) + math.abs(a.x1 - b.x1) + math.abs(a.y1 - b.y1) + math.abs(a.z1 - b.z1) < 1e-3,
				part.Name .. " lands elsewhere with a " .. math.deg(yaw) .. "-degree import")
		end
	end
	-- Local content is refused.
	local bad = Seat.StandInKit(manifest, math.pi)
	bad:FindFirstChild("EM_HullWhite").MeshId = "rbxasset://eggmobile/hull.mesh"
	assert(not pcall(Seat.KitFromFolder, bad, manifest), "a kit with local content must be refused")
	-- Round trip through a place file: everything survives serialisation.
	local dm = roblox.Instance.new("DataModel")
	eggman.Parent = dm:GetService("Workspace")
	local back = roblox.deserializePlace(roblox.serializePlace(dm))
	local copy = back:GetService("Workspace"):FindFirstChild("Eggman")
	assert(copy and #copy:GetDescendants() == #eggman:GetDescendants(), "the ship does not survive a place round trip")
	local copyProblems = Seat.Problems(copy, FLOOR)
	assert(#copyProblems == 0, "after the round trip: " .. table.concat(copyProblems, "; "))
	eggman.Parent = nil
	pass(("the ship from the stand-in kit: %d MeshParts + hull root + %d colliders, %.1f x %.1f x %.1f studs (W x D x top), each where the manifest puts it (the 180-degree import turn read and undone; 90 and 0 build the same), coloured from it, fan and levers on Motor6Ds at their pivots, joints hold, round trip ok")
		:format(#meshes, #colliders, size.X, size.Z, shipHi.Y))
end

-- Without the kit: no ship, Eggman stands; a place that still carries a ship without a kit fails Verify.
do
	local folder = roblox.Instance.new("Folder")
	folder.Name = "LobbyCharacters"
	local key = PlaceFiles.Places[1].key
	local spot = assert(LobbyNpcConfig.Spot(key, "Eggman"))
	local floor = LobbyNpcConfig.SpotCFrame(spot, CFrame)
	local standing = standingEggman(floor)
	standing.Parent = folder
	local notes = {}
	assert(Seat.Insert(folder, key, notes, false) == nil and not standing:FindFirstChild(EggMobile.ModelName), "no kit: no ship")
	assert(string.find(notes[1] or "", "no Egg Mobile", 1, true), "no kit: the build says so")
	local root = standing:FindFirstChild("HumanoidRootPart")
	assert((root.CFrame.Position - (floor * Vector3.new(0, Seat.StandingRootHeight, 0))).Magnitude < 1e-4, "no kit: Eggman stands at his spot")
	if not fs.isFile(Seat.KitFile) then
		local dm = roblox.Instance.new("DataModel")
		folder.Parent = dm:GetService("Workspace")
		assert(pcall(Seat.Verify, key, dm), "no kit, no ship: Verify passes")
		local old = roblox.Instance.new("Model")
		old.Name = EggMobile.ModelName
		old:SetAttribute("U4Asset", EggMobile.Stamp)
		old:SetAttribute("EggMobileVersion", 1)
		old.Parent = standing
		assert(not pcall(Seat.Verify, key, dm), "a leftover (part-built) ship without the kit must fail Verify")
	end
	pass("without design/npc/EggMobileKit.rbxm: no ship, Eggman stands at his spot, a leftover ship fails Verify")
end

----------------------------------------------------------------------
-- 4. Adopted by the server
----------------------------------------------------------------------
do
	local kind, root = LobbyNpcRig.OwnerKind(eggman, nil)
	assert(kind == "Eggman" and root == eggman.HumanoidRootPart, "the seated Eggman is still adopted as Eggman")
	local before = {}
	for _, d in eggman:GetDescendants() do
		if d:IsA("BasePart") then
			before[d] = d.CFrame
		end
	end
	local prepared = LobbyNpcRig.PrepareOwnerModel(ENV, eggman, root)
	assert(prepared.Scripts == 0, "scripts in Eggman")
	assert(root.Anchored, "his root holds everything")
	for _, part in shipParts do
		assert(not part.Anchored and not part.CanCollide and not part.CanQuery and not part.CanTouch, part.Name .. ": not held by the root, or in the way")
	end
	for _, part in colliders do
		assert(part.Anchored and part.CanCollide, part.Name .. ": the colliders stay anchored and colliding")
	end
	for part, cf in before do
		assert((part.CFrame.Position - cf.Position).Magnitude < 1e-6, part.Name .. " moved when adopted")
	end
	local joints, rig, complete = LobbyNpcRig.FindJoints(eggman)
	assert(rig == "R6" and complete and #joints == 6, "the pose joints: " .. rig .. " " .. #joints)
	for _, joint in joints do
		assert(not joint.motor:IsDescendantOf(ship), joint.name .. " is found in the ship, not on Eggman")
	end
	local lo, hi = math.huge, -math.huge
	for _, d in eggman:GetDescendants() do
		if d:IsA("BasePart") then
			local p = FLOOR:PointToObjectSpace(d.CFrame.Position)
			lo, hi = math.min(lo, p.X), math.max(hi, p.X)
		end
	end
	local reach = math.max(LobbyNpcConfig.Prompt.Eggman.MaxDistance, (hi - lo) / 2 + 6)
	assert(reach >= EggMobile.HullRadius + 6, "the prompt does not reach past the hull")
	pass(("adopted as the server does: %d parts held by his anchored root, %d colliders loose, the R6 pose joints found on him; prompt reach ~%.1f studs")
		:format(prepared.Joined, #colliders, reach))
end

----------------------------------------------------------------------
-- 5. The driving animations
----------------------------------------------------------------------
do
	local def = assert(LobbyNpcPose.Defs[EggMobile.PoseKind], "LobbyNpcPose has no " .. EggMobile.PoseKind)
	assert(def.Reactions.Talk and def.Reactions.Laugh and def.TalkReaction == "Talk" and def.Aims, "the driving def: Talk (the prompt), Laugh, aims")
	local floorTop, rimTop = EggMobile.FloorTop, EggMobile.RimTop
	local LEG_GRAZE = 0.06
	local sticks = {}
	for _, spec in { EggMobile.Sticks.Right, EggMobile.Sticks.Left } do
		sticks[spec.Arm] = spec
	end
	local function local_(p)
		return FLOOR:PointToObjectSpace(p)
	end
	local aims = { false, { yaw = 50, pitch = 0 }, { yaw = -55, pitch = 8 }, { yaw = 5, pitch = 25 } }
	local variants = { { nil, -1 }, { "Talk", 0.15 }, { "Talk", 0.8 }, { "Talk", 1.7 }, { "Talk", 2.6 }, { "Laugh", 1.1 } }
	local samples, worstLeg, worstFist, freed, pointed = 0, -math.huge, 0, 0, 0
	for step = 0, math.floor(def.Loop * 20) do
		local t = 1.7e9 + step / 20
		local loopT = t % def.Loop
		for aimIndex, aim in aims do
			-- The reactions with every aim at a few moments; the loop alone at every step.
			for vIndex, variant in variants do
				if vIndex > 1 and (step % 8 ~= 0 or aimIndex > 2) then
					continue
				end
				local reaction, age = variant[1], if variant[2] >= 0 then variant[2] else nil
				local transforms, out = transformsAt(eggman, EggMobile.PoseKind, t, reaction, age, aim or nil)
				for joint, v in out do
					for index = 1, 6 do
						assert(finite(v[index]), joint .. ": not finite")
					end
					assert(math.abs(v[4]) <= 180 and math.abs(v[5]) <= 180 and math.abs(v[6]) <= 180, joint .. ": over 180 degrees")
					assert(Vector3.new(v[1], v[2], v[3]).Magnitude <= 0.6, joint .. ": moved over 0.6 studs")
				end
				local frames = posed(eggman, transforms)
				samples += 1
				local where = ("%.2f s%s%s"):format(loopT, if reaction then " (" .. reaction .. " " .. age .. ")" else "",
					if aim then (" aim %d/%d"):format(aim.yaw, aim.pitch) else "")
				-- Legs: under the cockpit floor and inside the hull, all along them.
				for _, name in { "Left Leg", "Right Leg" } do
					local leg = eggman[name]
					for _, sx in { -0.5, 0.5 } do
						for sy = -1, 1, 0.25 do
							for _, sz in { -0.5, 0.5 } do
								local world = frames[leg] * Vector3.new(sx, sy, sz)
								local p = local_(world)
								local inTorso = frames[eggman.Torso]:PointToObjectSpace(world)
								if math.abs(inTorso.X) <= 1.1 and math.abs(inTorso.Y) <= 1.02 and math.abs(inTorso.Z) <= 0.52 then
									continue
								end
								worstLeg = math.max(worstLeg, p.Y)
								assert(p.Y <= floorTop + LEG_GRAZE, ("%s pokes out of the cockpit floor (y %.3f > %.2f) at %s"):format(name, p.Y, floorTop, where))
								assert(math.sqrt(p.X * p.X + p.Z * p.Z) <= EggMobile.HullRadius - 0.3, name .. " out of the hull at " .. where)
							end
						end
					end
				end
				-- Chest and head over the rim.
				local head = local_(frames[eggman.Head].Position)
				local chest = local_(frames[eggman.Torso] * Vector3.new(0, 1, 0))
				assert(head.Y >= rimTop + 1.3 and chest.Y >= rimTop + 0.95, ("his head / chest sink into the ship (%.2f / %.2f) at %s"):format(head.Y, chest.Y, where))
				-- Arms inside the cockpit (clear of the rim) where they are below its top, never through the floor.
				for _, name in { "Left Arm", "Right Arm" } do
					local arm = eggman[name]
					for sy = -1, 1, 0.5 do
						for _, sx in { -0.5, 0.5 } do
							for _, sz in { -0.5, 0.5 } do
								local p = local_(frames[arm] * Vector3.new(sx, sy, sz))
								if p.Y <= rimTop + 0.1 then
									assert(math.sqrt(p.X * p.X + p.Z * p.Z) <= EggMobile.RimInner - 0.1, name .. " goes through the rim at " .. where)
									assert(p.Y >= floorTop - 0.05, name .. " goes through the cockpit floor at " .. where)
								end
							end
						end
					end
				end
				-- Fists: on their levers unless the pose frees that hand; a freed hand is clear of its lever (the
				-- client's grip rule lets the lever go).
				local rightFree, leftFree = LobbyNpcPose.HandsFree(EggMobile.PoseKind, loopT, reaction, age)
				for armName, spec in sticks do
					local free = if armName == "Right Arm" then rightFree else leftFree
					local fist = local_(frames[eggman[armName]] * Vector3.new(0, -0.75, 0))
					local rel = fist - v3(spec.Pivot)
					local tilt = math.deg(math.acos(math.clamp(rel.Y / rel.Magnitude, -1, 1)))
					if free <= 0 then
						worstFist = math.max(worstFist, tilt)
						assert(rel.Magnitude >= 0.3 and rel.Magnitude <= spec.Length - 0.2 and tilt <= EggMobile.StickMaxTilt,
							("%s is off its lever (%.2f studs, %.0f degrees) at %s"):format(armName, rel.Magnitude, tilt, where))
					elseif free >= 1 then
						freed += 1
						assert(rel.Magnitude >= spec.Length + 0.1, ("%s is freed but still at its lever (%.2f) at %s"):format(armName, rel.Magnitude, where))
					end
				end
				-- "Come here": with the point fully up and not beckoning, the right arm points along the aim's yaw.
				local w = LobbyNpcPose.DrivingWindows
				if not reaction and loopT >= w.Point[1] + w.Point[3] + 0.05 and loopT <= w.Beckon[1] - 0.05 then
					local arm = frames[eggman["Right Arm"]]
					local dir = FLOOR:VectorToObjectSpace(arm:VectorToWorldSpace(Vector3.new(0, -1, 0)))
					local want = if aim then aim.yaw else -20
					local got = math.deg(math.atan2(-dir.X, -dir.Z))
					assert(math.abs(got - math.clamp(want, -70, 70)) <= 12, ("the point aims %.0f, the player is at %.0f (%s)"):format(got, want, where))
					assert(dir.Y >= math.sin(math.rad(12)), "the pointing hand is low at " .. where)
					pointed += 1
				end
			end
		end
	end
	assert(freed > 50 and pointed > 20, ("the gestures were not sampled (%d freed, %d pointing)"):format(freed, pointed))
	pass(("%s: %d samples (loop %ds, 4 aims, Talk / Laugh): legs under the cockpit floor (highest visible edge %.2f, floor %.2f + %.2f graze), chest and head over the rim, arms in the cockpit, fists on the levers (tilt <= %.0f deg) unless freed (%d freed samples clear of their levers), the point follows the player")
		:format(EggMobile.PoseKind, samples, def.Loop, worstLeg, floorTop, LEG_GRAZE, worstFist, freed))
end

----------------------------------------------------------------------
-- 6. Hover and lever maths
----------------------------------------------------------------------
do
	local def = LobbyNpcPose.Defs[EggMobile.PoseKind]
	local h = EggMobile.Hover
	assert(def.HoverPeriods.Bob == h.BobPeriod and def.HoverPeriods.Roll == h.RollPeriod and def.HoverPeriods.Pitch == h.PitchPeriod
		and def.HoverPhases.Pitch == h.PitchPhase, "the pose's leans must follow the ship's hover periods and phase")
	local lowest = math.huge
	-- The ship's real lowest vertices (the manifest's bottomPoints: a MeshPart's box corner is air under the
	-- round black bottom), checked against the built ship's lowest box.
	local corners = {}
	assert(type(manifest.bottomPoints) == "table" and #manifest.bottomPoints >= 12, "the manifest's bottomPoints")
	local minBox = math.huge
	for _, part in shipParts do
		minBox = math.min(minBox, FLOOR:PointToObjectSpace(part.CFrame.Position).Y - part.Size.Y / 2)
	end
	local minPoint = math.huge
	for _, p in manifest.bottomPoints do
		table.insert(corners, v3(p))
		minPoint = math.min(minPoint, p[2])
	end
	assert(math.abs(minPoint - minBox) < 0.01, ("bottomPoints (%.3f) are not the ship's bottom (%.3f)"):format(minPoint, minBox))
	local CLEARANCE_MIN = 0.2 -- 2026-09-26 (owner: a big black bottom): the hover keeps it at least this high
	local c = EggMobile.HullCenter
	local pivot = CFrame.new(c[1], c[2], c[3])
	local maxStep, prev = 0, nil
	for step = 0, 60 * 30 do
		local t = 1.7e9 + step / 60
		local bob, pitch, yaw, roll = EggMobile.HoverValues(t)
		assert(finite(bob) and finite(pitch) and finite(yaw) and finite(roll), "hover not finite")
		assert(math.abs(bob) <= h.Bob + h.Ripple + 1e-9 and math.abs(pitch) <= h.Pitch + 1e-9 and math.abs(roll) <= h.Roll + 1e-9, "hover out of bounds")
		if prev then
			maxStep = math.max(maxStep, math.abs(bob - prev[1]), math.abs(pitch - prev[2]) / 20, math.abs(roll - prev[3]) / 20)
		end
		prev = { bob, pitch, roll }
		if step % 10 == 0 then
			local frame = pivot * EggMobile.HoverCFrame(t, CFrame) * pivot:Inverse()
			for _, corner in corners do
				lowest = math.min(lowest, (frame * corner).Y)
			end
		end
	end
	assert(maxStep < 0.02, ("the hover jumps %.3f in a 60 Hz frame"):format(maxStep))
	assert(lowest >= CLEARANCE_MIN, ("the ship dips to %.2f studs over the floor"):format(lowest))
	local a = table.pack(EggMobile.HoverValues(1.7e9 + 12.345))
	local b = table.pack(EggMobile.HoverValues(1.7e9 + 12.345))
	assert(a[1] == b[1] and a[2] == b[2] and a[4] == b[4], "the hover is not a function of the time")
	local maxTilt = EggMobile.StickMaxTilt
	for _, d in { { 0, 1, 0 }, { 0.2, 1, 0 }, { -0.1, 1, -0.3 }, { 0.3, 0.8, 0.25 }, { 0.9, 0.3, 0 }, { 0, 0.2, -1 } } do
		local dir = Vector3.new(d[1], d[2], d[3]).Unit
		local rx, rz = EggMobile.StickAngles(d[1], d[2], d[3])
		local up = CFrame.Angles(rx, 0, rz) * Vector3.new(0, 1, 0)
		local tilt = math.deg(math.acos(math.clamp(dir.Y, -1, 1)))
		if tilt <= maxTilt then
			assert((up - dir).Magnitude < 1e-6, "StickAngles misses " .. tostring(dir))
		else
			local got = math.deg(math.acos(math.clamp(up.Y, -1, 1)))
			assert(got <= maxTilt + 0.5, ("StickAngles tilts %.1f > %.1f"):format(got, maxTilt))
			assert(up:Dot(dir) > math.cos(math.rad(tilt - maxTilt + 1)), "StickAngles does not lean toward " .. tostring(dir))
		end
	end
	-- AimArm points the arm where it says.
	for _, py in { { 0, 0 }, { 20, 30 }, { 35, -50 }, { -10, 60 } } do
		local rx, rz = LobbyNpcPose.AimArm(py[1], py[2])
		local d = CFrame.Angles(math.rad(rx), 0, math.rad(rz)) * Vector3.new(0, -1, 0)
		local want = Vector3.new(-math.sin(math.rad(py[2])) * math.cos(math.rad(py[1])), math.sin(math.rad(py[1])), -math.cos(math.rad(py[2])) * math.cos(math.rad(py[1])))
		assert((d - want).Magnitude < 1e-6, "AimArm misses " .. py[1] .. "/" .. py[2])
	end
	pass(("hover: bob +-%.2f, pitch %.1f, roll %.1f deg, smooth (max %.3f a frame), the lowest piece %.2f studs over the floor; periods and phase shared with the pose; lever and arm aim exact")
		:format(h.Bob + h.Ripple, h.Pitch, h.Roll, maxStep, lowest))
end

----------------------------------------------------------------------
-- 7. The three lobbies
----------------------------------------------------------------------
local configSource = fs.readFile(SHARED .. "Config.luau")
local function block(startPattern)
	local start = assert(string.find(configSource, startPattern, 1, true), "Config block " .. startPattern)
	local stop = string.find(configSource, "\n}\n", start, true)
	return string.sub(configSource, start, stop)
end
local function vector(text)
	local x, y, z = string.match(text, "Vector3%.new%(%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*%)")
	return Vector3.new(tonumber(x), tonumber(y), tonumber(z))
end
local afkBlock = block("Config.AfkZone = {")
local spotRadius = tonumber(string.match(afkBlock, "SpotRadius%s*=%s*([%d%.]+)")) or 22
local treadmillBlock = block("Config.AdminTreadmill = {")
local discoBlock = block("Config.AdminDisco = {")
local Shot = luau.load(fs.readFile(SHARED .. "WorldPortalShot.luau"), {
	debugName = "WorldPortalShot",
	environment = { Vector3 = Vector3, math = math, table = table, pairs = pairs, ipairs = ipairs, type = type, tostring = tostring },
})()

local TREADMILL_MODELS = { Basic = true, Golden = true, Candy = true, Diamond = true, Needoh = true, Admin = true, Hacker = true }
local CLEARANCE = { spawn = 14, portal = 10, spinwheel = 8, treadmill = 6, leaderboard = 5, rankrewards = 6, racegate = 8,
	afk = 4, disco = 6, admintreadmill = 8, flash = 5 }

local function ancestorKey(part, ws)
	local cursor = part
	while cursor and cursor ~= ws do
		local name = cursor.Name
		local lower = string.lower(name)
		if name == "SpinWheelLobby" then
			return "spinwheel", cursor
		elseif name == "RaceGate" or name == "RaceLobbyBooth" then
			return "racegate", cursor
		elseif name == "Rank Rewards" then
			return "rankrewards", cursor
		elseif string.find(lower, "leaderboard", 1, true) and not string.find(lower, "area", 1, true) then
			return "leaderboard", part
		elseif string.find(lower, "portal", 1, true) then
			return "portal", cursor
		elseif TREADMILL_MODELS[name] and cursor:IsA("Model") then
			return "treadmill", cursor
		end
		cursor = cursor.Parent
	end
	return nil, nil
end

-- The footprint's outline (world XZ points) of a ship on `floor`: the hull's circle, the wings and the nozzle.
local corners = EggMobile.FootprintCorners(CFrame)
local maxRadius = EggMobile.Footprint.Radius
for _, p in corners do
	maxRadius = math.max(maxRadius, math.sqrt(p[1] * p[1] + p[2] * p[2]))
end
local function footprint(floor)
	local points = {}
	local r = EggMobile.Footprint.Radius
	for index = 0, 47 do
		local a = index * math.pi / 24
		table.insert(points, floor * Vector3.new(r * math.sin(a), 0, -r * math.cos(a)))
	end
	for _, p in corners do
		table.insert(points, floor * Vector3.new(p[1], 0, p[2]))
	end
	return points
end

local function gapToBox(points, box)
	local gap = math.huge
	for _, p in points do
		local dx = math.max(box.x0 - p.X, p.X - box.x1, 0)
		local dz = math.max(box.z0 - p.Z, p.Z - box.z1, 0)
		gap = math.min(gap, math.sqrt(dx * dx + dz * dz))
	end
	return gap
end

local problems, lines = {}, {}
for _, place in PlaceFiles.Places do
	local world = place.key
	local game = roblox.deserializePlace(fs.readFile(place.file))
	local ws = game:GetService("Workspace")
	local spawnPoint = LobbyNpcConfig.Spawns[world]
	local spot = assert(LobbyNpcConfig.Spot(world, "Eggman"), world .. ": no Eggman spot")
	local floor = LobbyNpcConfig.SpotCFrame(spot, CFrame)
	local bad = {}
	local function fail(text)
		table.insert(bad, text)
	end
	-- The ship as the build makes it, in memory (from the stand-in kit).
	local model = standingEggman(floor)
	local builtShip = Seat.Seat(model, floor, KIT)
	local own = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			own[d] = true
		end
	end

	-- The lobby, without the owner's NPC folder (the build replaces its Eggman with this one).
	local lobby, zones = {}, {}
	local existing = ws:FindFirstChild("LobbyCharacters")
	for _, d in ws:GetDescendants() do
		if d:IsA("BasePart") and d.ClassName ~= "Terrain" and not (existing and d:IsDescendantOf(existing))
			and not d:FindFirstAncestor(LobbyNpcConfig.FolderName) then
			local box = boxOf(d)
			if box.x1 >= spawnPoint.X - 260 and box.x0 <= spawnPoint.X + 260 and box.z1 >= spawnPoint.Z - 260 and box.z0 <= spawnPoint.Z + 260
				and box.y1 >= spawnPoint.Y - 10 and box.y0 <= spawnPoint.Y + 60 then
				table.insert(lobby, { part = d, box = box })
				local key, owner = ancestorKey(d, ws)
				if d:IsA("SpawnLocation") then
					key, owner = "spawn", d
				end
				if key then
					local id = key .. ":" .. owner:GetFullName()
					local zone = zones[id]
					if not zone then
						zones[id] = { key = key, name = owner:GetFullName(), box = box }
					else
						local b = zone.box
						zone.box = { x0 = math.min(b.x0, box.x0), y0 = math.min(b.y0, box.y0), z0 = math.min(b.z0, box.z0),
							x1 = math.max(b.x1, box.x1), y1 = math.max(b.y1, box.y1), z1 = math.max(b.z1, box.z1) }
					end
				end
			end
		end
	end
	local function rect(key, center, halfX, halfZ)
		zones[key] = { key = key, name = key, box = { x0 = center.X - halfX, x1 = center.X + halfX, z0 = center.Z - halfZ, z1 = center.Z + halfZ } }
	end
	rect("afk", vector(assert(string.match(afkBlock, world .. "%s*=%s*(Vector3%.new%b())"))), spotRadius, spotRadius)
	rect("admintreadmill", vector(assert(string.match(treadmillBlock, world .. "%s*=%s*{%s*Position%s*=%s*(Vector3%.new%b())"))), 13.5, 19)
	local discoWorld = assert(string.match(discoBlock, world .. "%s*=%s*(%b{})"))
	local discoFloor, discoSize = vector(assert(string.match(discoWorld, "Floor%s*=%s*(Vector3%.new%b())"))), vector(assert(string.match(discoWorld, "Size%s*=%s*(Vector3%.new%b())")))
	rect("disco", discoFloor, discoSize.X / 2, discoSize.Z / 2)
	local flashSpots = { LobbyNpcConfig.Spot(world, "Flash") }
	for _, name in LobbyNpcConfig.BoothNames do
		local booth = ws:FindFirstChild(name)
		local marker = booth and booth:FindFirstChild(LobbyNpcConfig.FlashSpotName, true)
		if marker and marker:IsA("BasePart") then
			table.insert(flashSpots, LobbyNpcConfig.MarkerSpot(marker.CFrame, marker.Size.Y))
		end
	end
	for index, flashSpot in flashSpots do
		rect("flash" .. index, flashSpot.Position, 1.7, 1.7)
		zones["flash" .. index].key = "flash"
	end

	-- a) Nothing of the lobby inside the ship's volume (its pieces' boxes and the colliders' space).
	local outline = footprint(floor)
	local reach = maxRadius + 2.6
	local blockers = {}
	for _, entry in lobby do
		local part, box = entry.part, entry.box
		if (part.CanCollide or part.Transparency < 0.95) and box.y1 > spot.Position.Y + 0.1
			and box.x1 >= spot.Position.X - reach and box.x0 <= spot.Position.X + reach
			and box.z1 >= spot.Position.Z - reach and box.z0 <= spot.Position.Z + reach then
			table.insert(blockers, part)
		end
	end
	local hitParts = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 or (part:IsA("BasePart") and part:GetAttribute("EggCollider")) then
			local cf, size = part.CFrame, part.Size
			for sx = -0.5, 0.5, 0.25 do
				for sy = -0.5, 0.5, 0.25 do
					for sz = -0.5, 0.5, 0.25 do
						local p = cf * Vector3.new(sx * size.X, sy * size.Y, sz * size.Z)
						if inside(part, p) or math.abs(sx) + math.abs(sy) + math.abs(sz) == 0 then
							for _, other in blockers do
								if not hitParts[other] and inside(other, p) then
									hitParts[other] = true
									fail(("%s is inside the Egg Mobile (%s)"):format(other:GetFullName(), part.Name))
								end
							end
						end
					end
				end
			end
		end
	end

	-- b) Clear of the lobby's features.
	local nearest, nearestName = math.huge, ""
	for _, zone in zones do
		local need = CLEARANCE[zone.key]
		if need then
			local gap = gapToBox(outline, zone.box)
			if gap < nearest then
				nearest, nearestName = gap, zone.name
			end
			if gap < need then
				fail(("%.1f studs from %s (needs %d)"):format(gap, zone.name, need))
			end
		end
	end

	-- c) Out of the portal flight's shot (2 studs round the ship's volume).
	local fallback = Shot.Fallback[place.world]
	local shotHit = false
	for stepIndex = 0, 40 do
		local eye = Shot.Eye(fallback.Position, fallback.Front, stepIndex / 40)
		for k = 0, 40 do
			local p = floor:PointToObjectSpace(fallback.Position:Lerp(eye, k / 40))
			local flat = math.sqrt(p.X * p.X + p.Z * p.Z)
			if not shotHit and flat <= maxRadius + 2 and p.Y >= -2 and p.Y <= EggMobile.Footprint.Top + 2 then
				shotHit = true
				fail("in the portal flight's shot")
			end
		end
	end

	-- d) In sight of the spawn: from eye height over it to his seated face.
	local seat = EggMobile.SeatCFrame(floor, CFrame)
	local face = seat * Vector3.new(0, 1.5, -0.4)
	local eyePoint = spawnPoint + Vector3.new(0, 5, 0)
	for _, entry in lobby do
		local part = entry.part
		if not part:IsA("SpawnLocation") and (part.CanCollide or part.Transparency < 0.6) and part.Transparency < 0.95 and part.Size.Magnitude >= 2 then
			local t = segmentHitsPart(eyePoint, face, part)
			if t and t > 0.01 and t < 0.98 then
				fail(part:GetFullName() .. " blocks the view from the spawn")
				break
			end
		end
	end

	-- e) audit/test_u4_npcs' floor rules still hold with the ship at the spot.
	local position = spot.Position
	for part in own do
		if (part.CanCollide or part.Transparency < 0.95) then
			local rel = part.CFrame:PointToObjectSpace(position)
			if math.abs(rel.X) <= part.Size.X / 2 and math.abs(rel.Z) <= part.Size.Z / 2 then
				local top = position.Y + part.Size.Y / 2 - rel.Y
				if top <= position.Y + 1.2 and top >= position.Y - 1 then
					fail(part.Name .. " would read as the floor at Eggman's spot (test_u4_npcs)")
				end
			end
			if part.CanCollide then
				for index = 0, 8 do
					local offset = if index == 0 then Vector3.new(0, 0, 0)
						else Vector3.new(math.cos(index * math.pi / 4), 0, math.sin(index * math.pi / 4)) * 2.6
					local r = part.CFrame:PointToObjectSpace(position + offset)
					if math.abs(r.X) <= part.Size.X / 2 and math.abs(r.Z) <= part.Size.Z / 2 then
						local topAbove = part.Size.Y / 2 - r.Y
						if topAbove >= -1.0 and topAbove <= 0.05 then
							fail(part.Name .. " would read as a floor under a probe (test_u4_npcs)")
						end
					end
				end
			end
		end
	end

	local distance = (Vector3.new(position.X, 0, position.Z) - Vector3.new(spawnPoint.X, 0, spawnPoint.Z)).Magnitude
	if #bad == 0 then
		table.insert(lines, ("  %s Egg Mobile at (%.1f, %.1f, %.1f): clear of the lobby; nearest feature %.1f studs (%s); %.0f studs from the spawn, in sight")
			:format(world, position.X, position.Y, position.Z, nearest, nearestName, distance))
	else
		table.insert(problems, world)
		table.insert(lines, ("  %s Egg Mobile at (%.1f, %.1f, %.1f):"):format(world, position.X, position.Y, position.Z))
		for index = 1, math.min(10, #bad) do
			table.insert(lines, "    FAIL " .. bad[index])
		end
	end

	-- 8. What the place carries (after the build).
	local placed = existing and existing:FindFirstChild("Eggman")
	local placedShip = placed and placed:FindFirstChild(EggMobile.ModelName)
	if PLACES_MODE then
		local ok, err = pcall(Seat.Verify, world, game)
		if ok then
			table.insert(lines, ("  %s place: %s"):format(world, if placedShip then ("Eggman seated in the kit Egg Mobile (%s parts)"):format(tostring(placedShip:GetAttribute("EggMobileParts")))
				else "no Egg Mobile (no kit yet), Eggman standing at his spot"))
		else
			table.insert(problems, world .. " (place)")
			table.insert(lines, "    FAIL " .. tostring(err))
		end
	elseif placedShip then
		local look = placedShip:GetAttribute("EggMobileLook")
		if look == "Kit" and placedShip:GetAttribute("EggMobileVersion") == EggMobile.Version then
			local placeProblems = Seat.Problems(placed, floor)
			if #placeProblems > 0 then
				table.insert(problems, world .. " (place)")
				table.insert(lines, "    FAIL the place's Egg Mobile: " .. table.concat(placeProblems, "; "))
			else
				table.insert(lines, ("  %s place: the kit Egg Mobile, Eggman seated at his spot"):format(world))
			end
		else
			table.insert(lines, ("  %s place: an old Egg Mobile (v%s, part-built); the next audit/build_update4 removes it"):format(world,
				tostring(placedShip:GetAttribute("EggMobileVersion"))))
		end
	else
		table.insert(lines, ("  %s place: no Egg Mobile"):format(world))
	end
	builtShip.Parent = nil
end
print(table.concat(lines, "\n"))
if #problems > 0 then
	error("test_u4_egg_mobile: " .. table.concat(problems, ", "))
end
pass("the Egg Mobile at Eggman's spot is clear of every lobby part and feature, of Flash and of the portal flight, in sight of the spawn, in all 3 places"
	.. (if PLACES_MODE then "; every place passes Verify" else ""))

print(("test_u4_egg_mobile: %d checks passed"):format(passed))
