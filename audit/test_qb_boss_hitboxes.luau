-- audit/test_qb_boss_hitboxes.luau  (2026-09-21)
-- "The NPC hitboxes are weird": players died to Zoom, Reverse Flash, Sonic.EXE and the World 1
-- hammers without touching them on their own screen ("from 10 metres"). Everything here runs
-- the REAL sources (the shared module, functions cut out of the scripts by their markers, the
-- real boss models from the places):
--   1. Shared.BossContact: the box test (with its forgiveness margin) is the World 1 hammer
--      maths; the root history rewinds a moving, turning boss; a snap clears it; the visible
--      size of a SpecialMesh part never grows a hitbox.
--   2. Sonic.EXE (World 2 place): its legs are tested as the 1.5-stud legs players see, not as
--      5.08-stud cubes.
--   3. Zoom / Reverse Flash (World 1 place): the real configure rules keep the invisible root,
--      Zoom's transparent Head and Reverse Flash's *Lightning holders out of contact, and give
--      Reverse Flash's R15 torso back; the real contact sweep spares a runner the server holds
--      late and kills one the rewound boss really reaches; no Touched kill is left.
--   4. Arrival grace on the shared clock (clients used to compare their own os.clock()).
--   5. The World 1 hammer backstop poses the hammer when the runner was really there.
--
--   lune run audit/test_qb_boss_hitboxes.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local PlaceFiles = require("./place_files")

local Vector3, CFrame, Instance, Enum = roblox.Vector3, roblox.CFrame, roblox.Instance, roblox.Enum

local CONTACT = "src/common/ReplicatedStorage/Shared/BossContact.luau"
local ZOOM = "src/common/ServerScriptService/Bosses/ZoomBoss.server.luau"
local RF = "src/worlds/World1/ServerScriptService/Bosses/ReverseFlashBoss.server.luau"
local SONIC_CLIENT = "src/worlds/World2/StarterPlayer/StarterPlayerScripts/Gameplay/World2SonicEXEBoss.client.luau"
local SONIC_SERVER = "src/worlds/World2/ServerScriptService/Bosses/World2SonicEXEBoss.server.luau"
local HAMMER_MODULE = "src/worlds/World1/ReplicatedStorage/Shared/World1HammerMotion.luau"
local W1_MOTION = "src/worlds/World1/ServerScriptService/Gameplay/NewWorld1ServerMotion.server.luau"
local COMMON_TELEPORT = "src/common/ServerScriptService/Services/StageTeleportService.luau"
local W2_TELEPORT = "src/worlds/World2/ServerScriptService/Gameplay/World2StageTeleportService.luau"
local W2_SPEED_FORCE = "src/worlds/World2/ServerScriptService/Gameplay/World2SpeedForce.server.luau"
local SPEEDSTER_RUN = "src/common/StarterPlayer/StarterCharacterScripts/R15SpeedsterRun.client.luau"
local W3_TELEPORT = "src/worlds/World3/ServerScriptService/Gameplay/World3StageTeleportService.luau"

local function read(path)
	return (string.gsub(fs.readFile(path), "\r\n", "\n"))
end
local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end
local function near(a, b, tolerance, label)
	assert(math.abs(a - b) <= tolerance, ("%s: %s vs %s"):format(label, tostring(a), tostring(b)))
end
local function slice(source, startMarker, endMarker, label)
	local a = assert(string.find(source, startMarker, 1, true), label .. ": start marker")
	local b = assert(string.find(source, endMarker, a + #startMarker, true), label .. ": end marker")
	return string.sub(source, a, b - 1)
end
local function environment(values)
	local env = setmetatable({}, { __index = _G })
	for key, value in { Vector3 = Vector3, CFrame = CFrame, Enum = Enum } do
		env[key] = value
	end
	for key, value in values or {} do
		env[key] = value
	end
	return env
end
local function number(source, name)
	return assert(tonumber(string.match(source, "\nlocal " .. name .. " = ([%d%.]+)")), name)
end

for _, path in { CONTACT, ZOOM, RF, SONIC_CLIENT, SONIC_SERVER, W1_MOTION, COMMON_TELEPORT, W2_TELEPORT, W2_SPEED_FORCE, SPEEDSTER_RUN } do
	local ok, problem = pcall(luau.compile, fs.readFile(path))
	assert(ok, path .. " does not compile: " .. tostring(problem))
end

local BossContact = luau.load(read(CONTACT), { debugName = "BossContact", environment = environment() })()
local HammerMotion = luau.load(read(HAMMER_MODULE), { debugName = "World1HammerMotion", environment = environment() })()

----------------------------------------------------------------------------------------------
-- 1. Shared.BossContact
----------------------------------------------------------------------------------------------
do
	-- The forgiveness margin: a 2-stud body 0.3 studs into a 4-stud box is a graze, 0.5 is a hit.
	local box, body = Vector3.new(4, 4, 4), Vector3.new(2, 2, 2)
	local graze, hit = CFrame.new(2 + 1 - 0.3, 0, 0), CFrame.new(2 + 1 - 0.5, 0, 0)
	assert(not BossContact.BoxesOverlap(CFrame.new(), box, graze, body, 0.35), "0.3 studs in is forgiven by the 0.35 margin")
	assert(BossContact.BoxesOverlap(CFrame.new(), box, graze, body, 0), "...and is a touch without it")
	assert(BossContact.BoxesOverlap(CFrame.new(), box, hit, body, 0.35), "0.5 studs in is a hit")
	-- Turned 45 degrees the box reaches 2.83 studs along X (2.33 once shrunk).
	local turned = CFrame.Angles(0, math.rad(45), 0)
	assert(BossContact.BoxesOverlap(turned, box, CFrame.new(3.0, 0, 0), body, 0.35), "a turned box reaches further along its diagonal")
	assert(not BossContact.BoxesOverlap(turned, box, CFrame.new(3.5, 0, 0), body, 0.35), "...but 3.5 away is clear once shrunk")
	assert(BossContact.BoxesOverlap(turned, box, CFrame.new(3.5, 0, 0), body, 0), "...(and touched without the margin)")
	assert(not BossContact.BoxesOverlap(CFrame.new(), Vector3.new(0.5, 4, 4), CFrame.new(), body, 0.35), "a sliver thinner than the margin touches nothing")
	-- The port is the World 1 hammer maths, answer for answer.
	-- A small fixed-seed generator (Lune has no Random), so every run tests the same cases.
	local seed = 21092026
	local random = {}
	function random:NextNumber(low, high)
		seed = (seed * 1103515245 + 12345) % 2147483648
		return low + (high - low) * seed / 2147483648
	end
	local function randomCFrame()
		return CFrame.new(random:NextNumber(-6, 6), random:NextNumber(-6, 6), random:NextNumber(-6, 6))
			* CFrame.Angles(random:NextNumber(-math.pi, math.pi), random:NextNumber(-math.pi, math.pi), random:NextNumber(-math.pi, math.pi))
	end
	local hits = 0
	for _ = 1, 3000 do
		local a, b = randomCFrame(), randomCFrame()
		local sizeA = Vector3.new(random:NextNumber(0.2, 9), random:NextNumber(0.2, 9), random:NextNumber(0.2, 9))
		local sizeB = Vector3.new(random:NextNumber(0.2, 5), random:NextNumber(0.2, 5), random:NextNumber(0.2, 5))
		local shrink = random:NextNumber(0, 0.8)
		local mine = BossContact.BoxesOverlap(a, sizeA, b, sizeB, shrink)
		assert(mine == HammerMotion.BoxesOverlap(a, sizeA, b, sizeB, shrink), "BossContact.BoxesOverlap differs from World1HammerMotion.BoxesOverlap")
		if mine then
			hits += 1
		end
	end
	assert(hits > 300 and hits < 2700, "the random cases cover both answers (" .. hits .. " hits)")
	pass("box test: 0.3 in with a 0.35 margin is spared, 0.5 in is hit, a 45-degree box reaches its diagonal; 3000 random cases answer as World1HammerMotion.BoxesOverlap")
end

do
	near(BossContact.RewindSeconds(0.2, 0.06, 0.3), 0.26, 1e-9, "ping 0.2")
	near(BossContact.RewindSeconds(0.9, 0.06, 0.3), 0.3, 1e-9, "capped")
	near(BossContact.RewindSeconds(nil, 0.06, 0.3), 0.16, 1e-9, "no ping reads 0.1")
	near(BossContact.RewindSeconds(0 / 0, 0.06, 0.3), 0.16, 1e-9, "NaN ping reads 0.1")
	near(BossContact.RewindSeconds(-1, 0, 0.3), 0.1, 1e-9, "negative ping reads 0.1")

	-- A boss running 56 studs/s along its look vector at 60 Hz while turning 60 degrees a second.
	local SPEED, TURN, DT = 56, math.rad(60), 1 / 60
	local chestOffset = CFrame.new(0, 4, 0)
	local chestSize = Vector3.new(10, 8, 5)
	local history = BossContact.NewHistory(64, 25)
	local position, yaw, now = Vector3.new(0, 15, 0), 0, 1000
	local poses = {}
	for frame = 0, 90 do
		local rootCFrame = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
		history:Record(now, rootCFrame)
		poses[frame] = { Time = now, Root = rootCFrame }
		if frame < 90 then
			position += rootCFrame.LookVector * SPEED * DT
			yaw += TURN * DT
			now += DT
		end
	end
	assert(#history.Samples == 64, "the history keeps its capacity, not every frame")
	local currentRoot = poses[90].Root
	local currentChest = currentRoot * chestOffset
	local rewind = BossContact.RewindSeconds(0.2, 0.06, 0.3)
	local pastRoot = assert(history:At(now - rewind))
	-- 0.26 s = 15.6 frames back: between frames 74 and 75.
	local expected = poses[74].Root:Lerp(poses[75].Root, 0.4)
	assert((pastRoot.Position - expected.Position).Magnitude < 1e-3, "At() blends the two samples around the time")
	near((currentRoot.Position - pastRoot.Position).Magnitude, SPEED * rewind, 0.2, "the rewound root is 0.26 s of running back")
	local rewoundChest = BossContact.Rewind(pastRoot, currentRoot, currentChest)
	local trueChest = pastRoot * chestOffset
	assert((rewoundChest.Position - trueChest.Position).Magnitude < 1e-3, "the rewound chest sits on the rewound body")
	assert(rewoundChest.LookVector:Dot(pastRoot.LookVector) > 0.9999, "...turned the way the boss faced then (yaw included)")
	assert(currentChest.LookVector:Dot(pastRoot.LookVector) < 0.99, "(the boss really turned in the meantime)")
	local body = Vector3.new(2, 2, 1)
	local function hits(bodyCFrame)
		return BossContact.BoxesOverlap(rewoundChest, chestSize, bodyCFrame, body, 0.35)
	end
	-- Where the server holds a laggy runner: inside the chest of NOW (Touched killed that).
	assert(BossContact.BoxesOverlap(currentChest, chestSize, currentChest, body, 0.35), "the stale body overlaps the boss of now")
	assert(not hits(currentChest), "...but not the boss the runner saw: spared")
	assert(not hits(currentChest * CFrame.new(0, 0, 8)), "a runner 8 studs behind the current chest is spared")
	assert(hits(rewoundChest * CFrame.new(0, 0, -(2.5 + 0.5 - 1))), "a runner 1 stud inside the rewound chest is hit")
	-- Before the oldest sample it answers the oldest; with no sample at all, nil.
	assert(history:At(0) == history.Samples[1].CFrame and history:At(now + 5) == currentRoot, "At() clamps to the samples it has")

	-- A snap: Clear() forgets the old spot; a jump longer than maxJump does the same by itself.
	local home = CFrame.new(500, 15, 500)
	history:Clear()
	assert(history:At(now) == nil, "a cleared history has no pose")
	history:Record(now + DT, home)
	assert(history:At(now + DT - rewind) == home, "right after a snap the boss is only where it is")
	local walker = BossContact.NewHistory(64, 25)
	walker:Record(1, CFrame.new(0, 15, 0))
	walker:Record(1 + DT, CFrame.new(0.9, 15, 0))
	walker:Record(1 + 2 * DT, home)
	assert(#walker.Samples == 1 and walker:At(0) == home, "a 500-stud jump in one frame starts the history again (no ghost at the old spot)")
	pass("root history: rewound 0.26 s (ping 0.2) a turning 56 studs/s boss spares a runner in its current chest or 8 studs behind it, hits one 1 stud inside the rewound chest; a snap clears it")
end

do
	local function meshPart(size, meshType, scale)
		local part = Instance.new("Part")
		part.Size = size
		if meshType then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = meshType
			mesh.Scale = scale
			mesh.Parent = part
		end
		return part
	end
	local function equal(a, b)
		return (a - b).Magnitude < 1e-4
	end
	local cube = Vector3.new(5.08, 5.08, 5.08)
	assert(equal(BossContact.VisibleSize(meshPart(cube)), cube), "no mesh: the part")
	assert(equal(BossContact.VisibleSize(meshPart(cube, Enum.MeshType.Head, Vector3.new(0.3, 0.8, 1))), Vector3.new(1.524, 4.064, 5.08)), "Head mesh: scaled")
	assert(equal(BossContact.VisibleSize(meshPart(cube, Enum.MeshType.Brick, Vector3.new(2, 0.5, 1))), Vector3.new(5.08, 2.54, 5.08)), "Brick mesh: scaled, capped at the part")
	assert(equal(BossContact.VisibleSize(meshPart(cube, Enum.MeshType.Cylinder, Vector3.new(1, 0.25, 0.25))), Vector3.new(5.08, 1.27, 1.27)), "Cylinder mesh")
	assert(equal(BossContact.VisibleSize(meshPart(cube, Enum.MeshType.Sphere, Vector3.new(1.1, 1.1, 1.1))), cube), "Sphere drawn bigger than its part keeps the part")
	assert(equal(BossContact.VisibleSize(meshPart(cube, Enum.MeshType.Sphere, Vector3.new(0.5, 1, 1))), Vector3.new(2.54, 5.08, 5.08)), "Sphere diameter per axis")
	assert(equal(BossContact.VisibleSize(meshPart(cube, Enum.MeshType.FileMesh, Vector3.new(0.1, 0.1, 0.1))), cube), "FileMesh scale is in mesh units: the part")
	-- The runner's body: R6 and R15 names only.
	local character = Instance.new("Model")
	for _, name in { "Head", "UpperTorso", "LowerTorso", "LeftFoot", "Torso", "Left Arm", "HumanoidRootPart", "Handle", "WingsPart" } do
		local part = Instance.new("Part")
		part.Name = name
		part.Parent = character
	end
	local hat = Instance.new("Accessory")
	hat.Parent = character
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Parent = hat
	local names = {}
	for _, part in BossContact.GetBodyParts(character) do
		table.insert(names, part.Name)
	end
	table.sort(names)
	assert(table.concat(names, ",") == "Head,Left Arm,LeftFoot,LowerTorso,Torso,UpperTorso", "body parts: " .. table.concat(names, ","))
	pass("visible size: Head/Brick/Cylinder/Sphere meshes scale down, never up; FileMesh keeps the part; the body is limbs, torso and head (no root, hats or wings)")
end

----------------------------------------------------------------------------------------------
-- 2. Sonic.EXE in the World 2 place
----------------------------------------------------------------------------------------------
local world2 = roblox.deserializePlace(fs.readFile(PlaceFiles.World2))
do
	local sonic
	for _, item in world2:GetService("Workspace"):GetDescendants() do
		if item:IsA("Model") and item.Name == "Sonic.EXE" then
			sonic = item
			break
		end
	end
	assert(sonic, "Sonic.EXE is in the World 2 place")
	local count = 0
	for _, part in sonic:GetDescendants() do
		if part:IsA("BasePart") then
			local visible = BossContact.VisibleSize(part)
			assert(visible.X <= part.Size.X + 1e-6 and visible.Y <= part.Size.Y + 1e-6 and visible.Z <= part.Size.Z + 1e-6,
				part.Name .. " would grow: " .. tostring(visible) .. " > " .. tostring(part.Size))
			count += 1
		end
	end
	local leg = assert(sonic:FindFirstChild("LeftUpperLeg", true))
	local legSize = BossContact.VisibleSize(leg)
	near(leg.Size.X, 5.08, 0.01, "the leg part is a 5.08 cube")
	near(legSize.X, 1.52, 0.01, "the leg players see is 1.52 wide")
	-- A runner's torso 3 studs to the side of the leg, level with it.
	local torso = Instance.new("Part")
	torso.Name = "UpperTorso"
	torso.Size = Vector3.new(2, 2, 1)
	torso.CFrame = leg.CFrame * CFrame.new(3, 0, 0)
	torso.Parent = Instance.new("Model")
	-- The old client query: the leg's bounds against the body box padded by 0.4.
	local function aabb(cframe, size)
		local half = size * 0.5
		return Vector3.new(
			math.abs(cframe.RightVector.X) * half.X + math.abs(cframe.UpVector.X) * half.Y + math.abs(cframe.LookVector.X) * half.Z,
			math.abs(cframe.RightVector.Y) * half.X + math.abs(cframe.UpVector.Y) * half.Y + math.abs(cframe.LookVector.Y) * half.Z,
			math.abs(cframe.RightVector.Z) * half.X + math.abs(cframe.UpVector.Z) * half.Y + math.abs(cframe.LookVector.Z) * half.Z)
	end
	local legHalf = aabb(leg.CFrame, leg.Size)
	local bodyHalf = aabb(torso.CFrame, torso.Size + Vector3.new(0.4, 0.4, 0.4))
	local gap = leg.CFrame.Position - torso.CFrame.Position
	local oldHit = math.abs(gap.X) <= legHalf.X + bodyHalf.X and math.abs(gap.Y) <= legHalf.Y + bodyHalf.Y and math.abs(gap.Z) <= legHalf.Z + bodyHalf.Z
	assert(oldHit, "the old bounding-box query killed a runner 3 studs beside the leg")
	assert(not BossContact.CharacterTouches({ leg }, { torso }, 0, nil, nil, nil), "the visible leg does not reach 3 studs")
	torso.CFrame = leg.CFrame * CFrame.new(1.5, 0, 0)
	assert(BossContact.CharacterTouches({ leg }, { torso }, 0, nil, nil, nil), "...and still kills a runner who walks into it")
	pass(("Sonic.EXE: %d parts, none tested bigger than its part; LeftUpperLeg is %.2f wide (was %.2f), a runner 3 studs beside it lives"):format(count, legSize.X, leg.Size.X))

	-- The client contact: exact boxes, body parts only, no bounding-box query left; ice stops it.
	local client = read(SONIC_CLIENT)
	assert(not client:find(":GetPartBoundsInBox(", 1, true) and not client:find("CONTACT_PADDING", 1, true) and not client:find("sonicOverlap", 1, true),
		"the Sonic client still has the bounding-box query")
	local detect = slice(client, "local function detectSonicContact()", "RunService.RenderStepped:Connect(detectSonicContact)", "detect")
	local frozen = assert(detect:find('if Workspace:GetAttribute("AdminWorldFrozen") == true then', 1, true), "the Sonic client ignores the Snow freeze")
	assert(frozen < assert(detect:find("localKillFromSonic()", 1, true)), "...the freeze check comes before any kill")
	assert(detect:find("BossContact.CharacterTouches(validDamageParts, characterParts, CONTACT_SHRINK, nil, nil, damageSizes)", 1, true), "the client uses the exact box test")
	assert(client:find("damageSizes[part] = BossContact.VisibleSize(part)", 1, true), "...with the visible sizes")
	assert(client:find("return BossContact.IsBodyPartName(part.Name)", 1, true), "...against body parts only")
	local server = read(SONIC_SERVER)
	local handler = slice(server, "contactRemote.OnServerEvent:Connect(function(player)", "\nend)", "remote")
	local serverFrozen = assert(handler:find('if Workspace:GetAttribute("AdminWorldFrozen") == true then', 1, true), "the Sonic remote ignores the Snow freeze")
	assert(serverFrozen < assert(handler:find("targetHumanoid.Health = 0", 1, true)), "...before it kills")
	pass("Sonic.EXE client: no bounding-box query, the exact visible boxes against the body; client and remote both stand down while the world is frozen")
end

----------------------------------------------------------------------------------------------
-- 3. Zoom and Reverse Flash in the World 1 place
----------------------------------------------------------------------------------------------
local PLACE1 = fs.readFile(PlaceFiles.World1)
local function findBoss(dm, name)
	for _, item in dm:GetService("Workspace"):GetDescendants() do
		if item:IsA("Model") and item.Name == name then
			return item
		end
	end
	error(name .. " is not in the World 1 place")
end

-- Run the real effect stripping and configureBossPart of a boss script on the place's model.
local function configure(source, name, effectStart, effectEnd, removeCall)
	local dm = roblox.deserializePlace(PLACE1)
	local boss = findBoss(dm, name)
	local root = assert(boss:FindFirstChild("HumanoidRootPart", true))
	local chunk = slice(source, "local function normalizeName(value)", "local function objectDepth", name .. " names")
		.. slice(source, effectStart, effectEnd, name .. " effects")
		.. slice(source, "local configuredBossParts = {}", "for _, descendant in ipairs(boss:GetDescendants()) do", name .. " configure")
		.. "\n" .. removeCall .. "\nfor _, d in ipairs(boss:GetDescendants()) do if d:IsA(\"BasePart\") then configureBossPart(d) end end\n"
		.. "return { contactParts = contactParts, contactSizes = contactSizes, contactReach = contactReach }\n"
	local result = luau.load(chunk, { debugName = name .. " configure", environment = environment({
		boss = boss, root = root, BossContact = BossContact,
	}) })()
	return boss, root, result
end

local zoomSource, rfSource = read(ZOOM), read(RF)
local zoomBoss, zoomRoot, zoom = configure(zoomSource, "Zoom", "local bossTrailModel = nil", "local function getProjectTrailTemplate()", "removeBuiltInSpeedEffects()")
local rfBoss, rfRoot, rf = configure(rfSource, "ReverseFlashBoss", "local coreR6PartNames = {", "local function recolorAndEnableBossTrail", "removeBuiltInBossEffects()")
do
	local function names(result)
		local set = {}
		for _, part in result.contactParts do
			assert(part.Transparency < 0.95, part.Name .. " is invisible but kills")
			set[part.Name] = true
		end
		return set
	end
	for _, pair in { { zoomBoss, zoom, "Zoom" }, { rfBoss, rf, "Reverse Flash" } } do
		for _, part in pair[1]:GetDescendants() do
			if part:IsA("BasePart") then
				assert(part.CanTouch == false, pair[3] .. "." .. part.Name .. " still fires Touched")
			end
		end
	end
	local zoomNames, rfNames = names(zoom), names(rf)
	assert(not zoomNames.HumanoidRootPart and not zoomNames.Head, "Zoom's invisible root and transparent Head do not kill")
	assert(zoomNames.UpperTorso and zoomNames.FakeHead and zoomNames.LeftLowerLeg, "Zoom's visible torso, head and legs do")
	assert(not rfNames.HumanoidRootPart, "Reverse Flash's invisible root does not kill")
	for name in rfNames do
		assert(not name:find("Lightning", 1, true), "Reverse Flash's " .. name .. " effect holder kills")
	end
	assert(rfNames.UpperTorso and rfNames.LowerTorso and rfNames.LeftUpperArm and rfNames.RightLowerLeg, "Reverse Flash's R15 torso, arms and legs are contact parts")
	local upper = assert(rfBoss:FindFirstChild("UpperTorso", true))
	assert(upper.CanQuery == true, "Reverse Flash's UpperTorso keeps CanQuery")
	for _, trail in upper:GetChildren() do
		assert(not trail:IsA("Trail"), "...while its built-in trails are still stripped")
	end
	assert(zoom.contactReach > 10 and zoom.contactReach < 40 and rf.contactReach > 8 and rf.contactReach < 40, "the broad-phase reach is the body's size")
	-- The old name list (the snapshot before this work) took the R15 torso for an effect holder.
	local oldSource = fs.readFile("output/FableQB_20260921/backup_src/worlds/World1/ServerScriptService/Bosses/ReverseFlashBoss.server.luau")
	local dm = roblox.deserializePlace(PLACE1)
	local oldBoss = findBoss(dm, "ReverseFlashBoss")
	luau.load(slice(oldSource, "local function normalizeName(value)", "local function objectDepth", "old names")
		.. slice(oldSource, "local coreR6PartNames = {", "local function recolorAndEnableBossTrail", "old effects")
		.. slice(oldSource, "local configuredBossParts = {}", "for _, descendant in ipairs(boss:GetDescendants()) do", "old configure")
		.. "\nremoveBuiltInBossEffects()\nfor _, d in ipairs(boss:GetDescendants()) do if d:IsA(\"BasePart\") then configureBossPart(d) end end\n",
		{ debugName = "old RF", environment = environment({ boss = oldBoss, root = oldBoss:FindFirstChild("HumanoidRootPart", true) }) })()
	assert(oldBoss:FindFirstChild("UpperTorso", true).CanQuery == false, "(the old list really switched the R15 torso off)")
	pass(("Zoom: %d contact parts, Reverse Flash: %d; no invisible root, no transparent Head, no *Lightning holder; RF's R15 torso is back (the old list switched it off); no boss part fires Touched"):format(#zoom.contactParts, #rf.contactParts))
end

-- The real sweepContacts of each boss, on its real model, moved through a chase.
local function sweepRun(source, boss, root, configured, label, safeZoneRule)
	local block = slice(source, "local rootHistory = BossContact.NewHistory", "\nlocal currentTargetPlayer = nil", label .. " sweep")
		.. "\nreturn { rootHistory = rootHistory, sweepContacts = sweepContacts }\n"
	local frozen = false
	local players = {}
	local eligible = {}
	local outsideArea = false -- outside the chase area (BossArea / ZoomsArena) but not in a safe zone
	local sim = luau.load(block, { debugName = label .. " sweep", environment = environment({
		BossContact = BossContact, root = root,
		contactParts = configured.contactParts, contactSizes = configured.contactSizes, contactReach = configured.contactReach,
		ROOT_HISTORY_SAMPLES = number(source, "ROOT_HISTORY_SAMPLES"), ROOT_HISTORY_MAX_JUMP = number(source, "ROOT_HISTORY_MAX_JUMP"),
		CONTACT_SHRINK = number(source, "CONTACT_SHRINK"), CONTACT_EXTRA_REWIND = number(source, "CONTACT_EXTRA_REWIND"),
		CONTACT_MAX_REWIND = number(source, "CONTACT_MAX_REWIND"), CONTACT_BODY_REACH = number(source, "CONTACT_BODY_REACH"),
		TOUCH_DEBOUNCE = number(source, "TOUCH_DEBOUNCE"), SAFE_ZONE_ATTRIBUTE = "SafeZoneProtected",
		lastTouchAt = setmetatable({}, { __mode = "k" }),
		Players = { GetPlayers = function()
			return players
		end },
		Workspace = { GetAttribute = function(_, name)
			return if name == "AdminWorldFrozen" then frozen else nil
		end },
		getEligibleTarget = function(player)
			local character = player.Character
			if not eligible[player] or outsideArea then
				return nil, nil
			end
			return character:FindFirstChild("HumanoidRootPart"), player.Humanoid
		end,
		-- One runner per probe: "not eligible" stands for a safe zone.
		isInAnySafeZone = function()
			return next(eligible) == nil
		end,
	}) })()
	assert(number(source, "CONTACT_SHRINK") == 0.35 and number(source, "CONTACT_EXTRA_REWIND") == 0.06 and number(source, "CONTACT_MAX_REWIND") == 0.3, label .. " constants")

	-- Every boss part keeps its place on the root, as the rig's joints do.
	local parts, offsets = {}, {}
	for _, part in boss:GetDescendants() do
		if part:IsA("BasePart") then
			table.insert(parts, part)
			offsets[part] = root.CFrame:Inverse() * part.CFrame
		end
	end
	local function placeBoss(rootCFrame)
		for _, part in parts do
			part.CFrame = rootCFrame * offsets[part]
		end
	end
	-- A 56 studs/s chase along the boss's look vector, turning gently, recorded at 60 Hz.
	local start = root.CFrame
	local now = 500
	for frame = 0, 60 do
		local rootCFrame = start * CFrame.Angles(0, math.rad(20) * frame / 60, 0) * CFrame.new(0, 0, -56 * frame / 60)
		placeBoss(rootCFrame)
		sim.rootHistory:Record(now, root.CFrame)
		if frame < 60 then
			now += 1 / 60
		end
	end

	local function runner(ping)
		local character = Instance.new("Model")
		local rootPart = Instance.new("Part")
		rootPart.Name = "HumanoidRootPart"
		rootPart.Size = Vector3.new(2, 2, 1)
		rootPart.Parent = character
		local torso = Instance.new("Part")
		torso.Name = "UpperTorso"
		torso.Size = Vector3.new(2, 2, 1)
		torso.Parent = character
		-- A big accessory hanging off the back: never the body.
		local wings = Instance.new("Part")
		wings.Name = "Handle"
		wings.Size = Vector3.new(12, 12, 12)
		wings.Parent = character
		local attributes = {}
		-- A real Humanoid: Reverse Flash's contact rule finds it with FindFirstChildOfClass.
		-- (Lune has no TakeDamage; the kill pcalls it after setting Health to 0.)
		local humanoid = Instance.new("Humanoid")
		humanoid.MaxHealth = 100
		humanoid.Health = 100
		humanoid.Parent = character
		local player = { Character = character, Humanoid = humanoid }
		function player:GetAttribute(name)
			return attributes[name]
		end
		function player:SetAttribute(name, value)
			attributes[name] = value
		end
		function player:GetNetworkPing()
			if ping == "error" then
				error("not available")
			end
			return ping
		end
		local function place(cframe)
			rootPart.CFrame = cframe
			torso.CFrame = cframe
			wings.CFrame = cframe * CFrame.new(0, 0, 7)
		end
		return player, place
	end
	local function probe(ping, cframe, setup)
		local player, place = runner(ping)
		place(cframe)
		table.clear(players)
		table.insert(players, player)
		eligible = { [player] = true }
		if setup then
			setup(player)
		end
		sim.sweepContacts(now)
		frozen = false
		outsideArea = false
		return player.Humanoid.Health <= 0 and player.Character:GetAttribute("Dead") == true, player
	end
	local chest = assert(boss:FindFirstChild("UpperTorso", true))
	local chestNow = chest.CFrame
	local rewind = BossContact.RewindSeconds(0.2, number(source, "CONTACT_EXTRA_REWIND"), number(source, "CONTACT_MAX_REWIND"))
	local chestThen = BossContact.Rewind(sim.rootHistory:At(now - rewind), root.CFrame, chestNow)
	local depth = chest.Size.Z * 0.5 + 0.5 - 1 -- the runner's box 1 stud inside the chest's front face
	local lateBody = Instance.new("Part")
	lateBody.Size = Vector3.new(2, 2, 1)
	lateBody.CFrame = chestNow
	lateBody.Parent = Instance.new("Model")
	assert(BossContact.CharacterTouches(configured.contactParts, { lateBody }, 0.35, nil, nil, configured.contactSizes), label .. ": (without the rewind the late body is inside the boss)")
	assert(not probe(0.2, chestNow), label .. ": a runner the server holds late, inside the boss of now, is spared (Touched killed them)")
	assert(not probe(0.2, chestNow * CFrame.new(0, 0, 8)), label .. ": a runner 8 studs behind the chest is spared")
	assert(probe(0.2, chestThen * CFrame.new(0, 0, -depth)), label .. ": a runner 1 stud inside the chest they saw is killed")
	assert(probe("error", BossContact.Rewind(sim.rootHistory:At(now - 0.16), root.CFrame, chestNow) * CFrame.new(0, 0, -depth)), label .. ": an unreadable ping rewinds 0.1 + 0.06 s")
	assert(not probe(0.2, chestThen * CFrame.new(0, 0, -depth), function()
		frozen = true
	end), label .. ": nobody is caught while the world is frozen")
	assert(not probe(0.2, chestThen * CFrame.new(0, 0, -depth), function(player)
		player:SetAttribute("StageTeleportInvulnerable", true)
	end), label .. ": a teleporting runner is spared")
	assert(not probe(0.2, chestThen * CFrame.new(0, 0, -depth), function(player)
		player:SetAttribute("StageTeleportArrivalGraceUntil", os.clock() + 100 + now)
	end), label .. ": the arrival grace (server clock) is honoured")
	assert(not probe(0.2, chestThen * CFrame.new(0, 0, -depth), function(player)
		eligible[player] = nil
	end), label .. ": a runner in a safe zone is left alone")
	local outsideCaught = probe(0.2, chestThen * CFrame.new(0, 0, -depth), function()
		outsideArea = true
	end)
	if safeZoneRule then
		-- Reverse Flash's Touched never asked for BossArea: a runner just past its edge, not in a
		-- safe zone, is still caught (the final review's parity finding, 2026-09-21).
		assert(outsideCaught, label .. ": a runner just outside BossArea is still caught, as Touched did")
	else
		assert(not outsideCaught, label .. ": only runners inside the arena are caught, as Touched did (ZoomsArena)")
	end
	if safeZoneRule then
		assert(not probe(0.2, chestThen * CFrame.new(0, 0, -depth), function(player)
			player:SetAttribute("SafeZoneProtected", true)
		end), label .. ": a SafeZoneProtected player is spared")
		assert(not probe(0.2, chestThen * CFrame.new(0, 0, -depth), function(player)
			player.Character:SetAttribute("SafeZoneProtected", true)
		end), label .. ": a SafeZoneProtected character is spared")
	end
	-- The accessory is not the body: wings reaching into the rewound chest do not kill.
	assert(not probe(0.2, chestThen * CFrame.new(0, 0, -depth) * CFrame.new(0, 0, -7 - 4)), label .. ": a hat or wings in the boss do not kill")
	-- A snap home clears the history: the rewound ghost is gone from the chase spot.
	sim.rootHistory:Clear()
	placeBoss(start)
	sim.rootHistory:Record(now + 1 / 60, root.CFrame)
	now += 1 / 60
	assert(not probe(0.2, chestThen * CFrame.new(0, 0, -depth)), label .. ": after a snap home nothing kills at the old spot")
	placeBoss(start)
end

sweepRun(zoomSource, zoomBoss, zoomRoot, zoom, "Zoom", false)
sweepRun(rfSource, rfBoss, rfRoot, rf, "Reverse Flash", true)
pass("contact sweep (real sweepContacts on the real rigs, 56 studs/s chase, ping 0.2): the late server body is spared, 1 stud into the rewound chest kills; freeze, teleport, arrival grace, chase area, SafeZoneProtected and accessories all spare")

do
	for _, pair in { { zoomSource, "Zoom" }, { rfSource, "Reverse Flash" } } do
		local source, label = pair[1], pair[2]
		for _, gone in { ".Touched", "killPlayerOnTouch", "connectTouch", "connectBossTouch", "getPlayerCharacterFromHit", "touchConnections", "CanTouch = true" } do
			assert(not source:find(gone, 1, true), label .. " still has " .. gone)
		end
		local heartbeat = assert(source:find("heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)", 1, true))
		local frozen = assert(source:find('if Workspace:GetAttribute("AdminWorldFrozen") == true then', heartbeat, true))
		local now = assert(source:find("\n\tlocal now = os.clock()\n\trootHistory:Record(now, root.CFrame)\n\tsweepContacts(now)\n", heartbeat, true), label .. ": record and sweep right after the clock")
		assert(frozen < now, label .. ": ...and after the freeze check")
		for _, fn in { "local function snapBossHome()", "local function stopBoss()" } do
			local body = slice(source, fn, "\nend\n", label .. " " .. fn)
			assert(body:find("rootHistory:Clear()", 1, true), label .. ": " .. fn .. " clears the history")
		end
	end
	local gate = assert(zoomSource:find("if Config.IsWorld2Place == true or Config.IsWorld3Place == true then", 1, true), "Zoom returns outside World 1")
	assert(gate < assert(zoomSource:find("local BossContact = require", 1, true)), "...before it requires anything else")
	pass("Zoom / Reverse Flash: no Touched kill wiring left; every Heartbeat records the root and sweeps after the freeze check; snaps and stops clear the history; Zoom still returns outside World 1")
end

----------------------------------------------------------------------------------------------
-- 4. Arrival grace on the clock clients share
----------------------------------------------------------------------------------------------
do
	-- The real isLocallySafe of the Sonic client. The server's os.clock() stamp (5000) means
	-- nothing on a client whose own clock reads 100.
	local client = read(SONIC_CLIENT)
	local serverNow = 1.7e9
	local attributes = {}
	local player = { GetAttribute = function(_, name)
		return attributes[name]
	end }
	local character = Instance.new("Model")
	local isLocallySafe = luau.load(slice(client, "local function isLocallySafe()", "\nlocal function localKillFromSonic()", "isLocallySafe")
		.. "\nreturn isLocallySafe\n", { debugName = "isLocallySafe", environment = environment({
		player = player, character = character,
		Workspace = { GetServerTimeNow = function()
			return serverNow
		end },
		os = { clock = function()
			return 100
		end },
	}) })()
	attributes.StageTeleportArrivalGraceUntil = 5000
	assert(isLocallySafe() == false, "a server os.clock() stamp alone no longer makes the client safe")
	attributes.StageTeleportArrivalGraceUntilServerTime = serverNow + 1.75
	assert(isLocallySafe() == true, "the ServerTime stamp gives the grace")
	serverNow += 2
	assert(isLocallySafe() == false, "...for 1.75 s, not for the server's uptime")

	-- The real writer of the common stage trips stamps both, on their own clocks.
	local teleport = read(COMMON_TELEPORT)
	local written = {}
	local stub = { Parent = "Players" }
	function stub:GetAttribute(name)
		return written[name]
	end
	function stub:SetAttribute(name, value)
		written[name] = value
	end
	local arm = luau.load(slice(teleport, "local TELEPORT_INVULNERABLE_SECONDS", "\nlocal cachedNormalSpawn", "arm")
		.. "\nreturn armTeleportInvulnerability\n", { debugName = "arm", environment = environment({
		-- 2026-09-25 (Update 4): the slice now runs the world dispatch (arrival grace) first.
		Config = { IsWorld2Place = false, IsWorld3Place = false, StageCount = 10 },
		Players = "Players",
		task = { delay = function() end },
		os = { clock = function()
			return 42
		end },
		Workspace = { GetServerTimeNow = function()
			return 1.7e9
		end },
	}) })()
	arm(stub)
	assert(written.StageTeleportArrivalGraceUntil == 42 + 1.5, "the server attribute is unchanged (server os.clock)")
	assert(written.StageTeleportArrivalGraceUntilServerTime == 1.7e9 + 1.5, "the ServerTime copy has the same window")

	-- Every writer in src stamps both with the same duration. The one that cannot yet (World 3's
	-- stage trips, owned elsewhere) is covered by the client's change-of-attribute window, so it
	-- must never grant more than that window.
	local lavaSource = read(SPEEDSTER_RUN)
	local fallbackSeconds = number(lavaSource, "ARRIVAL_GRACE_FALLBACK_SECONDS")
	local writers, plainOnly = 0, {}
	local function scanWriters(dir)
		for _, name in fs.readDir(dir) do
			local path = dir .. "/" .. name
			if fs.isDir(path) then
				scanWriters(path)
			elseif name:match("%.luau$") and not name:match("%.client%.luau$") then
				local source = read(path)
				local plain, shared = {}, {}
				for duration in source:gmatch('SetAttribute%("StageTeleportArrivalGraceUntil", os%.clock%(%) %+ ([^%)\n]+)%)') do
					table.insert(plain, duration)
				end
				for duration in source:gmatch('SetAttribute%("StageTeleportArrivalGraceUntilServerTime", [Ww]orkspace:GetServerTimeNow%(%) %+ ([^%)\n]+)%)') do
					table.insert(shared, duration)
				end
				local _, anyWrites = source:gsub('SetAttribute%("StageTeleportArrivalGraceUntil",', "")
				assert(anyWrites == #plain, path .. ": a StageTeleportArrivalGraceUntil write this scan does not understand")
				if #plain > 0 then
					writers += 1
					if #shared == 0 then
						table.insert(plainOnly, path)
						for _, duration in plain do
							local seconds = tonumber(duration) or number(source, duration)
							assert(seconds <= fallbackSeconds, path .. " grants " .. seconds .. " s without the ServerTime stamp; clients only cover " .. fallbackSeconds)
						end
					else
						assert(table.concat(plain, "|") == table.concat(shared, "|"), path .. ": " .. table.concat(plain, "|") .. " vs " .. table.concat(shared, "|"))
					end
				end
			end
		end
	end
	scanWriters("src")
	assert(writers == 4, "4 files write the arrival grace (" .. writers .. ")")
	-- World 3's stage trips stamp it too since the lead's follow-up (2026-09-21).
	assert(#plainOnly == 0, "every writer stamps the ServerTime copy: " .. table.concat(plainOnly, ", "))

	-- No client compares the server's os.clock() stamp; the readers use the shared clock.
	local clientReaders = 0
	local function walk(dir)
		for _, name in fs.readDir(dir) do
			local path = dir .. "/" .. name
			if fs.isDir(path) then
				walk(path)
			elseif name:match("%.client%.luau$") then
				local source = read(path)
				assert(not source:find('GetAttribute("StageTeleportArrivalGraceUntil")', 1, true), path .. " compares the server's os.clock() stamp on the client")
				if source:find('"StageTeleportArrivalGraceUntilServerTime"', 1, true) then
					assert(source:find("GetServerTimeNow()", 1, true), path .. " reads the ServerTime stamp without the server clock")
					clientReaders += 1
				end
			end
		end
	end
	walk("src")
	assert(clientReaders == 2, "the Sonic client and the lava prediction read the ServerTime copy (" .. clientReaders .. ")")
	assert(lavaSource:find("or isInArrivalGrace(p)) then", 1, true), "the lava prediction asks isInArrivalGrace")

	-- The real World 3 place() (a stage trip) and the real lava-prediction grace, together. The
	-- runner's player fires the attribute-changed signal the way Roblox does.
	local now3, serverClock = 1.7e9, 50000
	local attrs3, listeners = {}, {}
	local player3 = {}
	function player3:GetAttribute(name)
		return attrs3[name]
	end
	function player3:SetAttribute(name, value)
		local changed = attrs3[name] ~= value
		attrs3[name] = value
		if changed then
			for _, callback in listeners[name] or {} do
				callback()
			end
		end
	end
	function player3:GetAttributeChangedSignal(name)
		return { Connect = function(_, callback)
			listeners[name] = listeners[name] or {}
			table.insert(listeners[name], callback)
		end }
	end
	local shared = { GetServerTimeNow = function()
		return now3
	end }
	local isInArrivalGrace = luau.load(slice(lavaSource, "-- Arrival grace for the touch prediction", "\n-- Instant touch prediction", "lava grace")
		.. "\nreturn isInArrivalGrace\n", { debugName = "isInArrivalGrace", environment = environment({
		localPlayer = player3, Workspace = shared,
	}) })()
	local w3Source = read(W3_TELEPORT)
	local root3 = { Size = Vector3.new(2, 2, 1) }
	function root3:IsA(className)
		return className == "BasePart"
	end
	local character3 = {}
	function character3:FindFirstChildOfClass()
		return { Health = 100, HipHeight = 2 }
	end
	function character3:FindFirstChild(name)
		return name == "HumanoidRootPart" and root3 or nil
	end
	function character3:GetDescendants()
		return {}
	end
	function character3:PivotTo() end
	player3.Character = character3
	local place = luau.load("local ARRIVAL_GRACE_SECONDS = " .. number(w3Source, "ARRIVAL_GRACE_SECONDS") .. "\n"
		.. slice(w3Source, "local function zeroVelocity(character)", "\nfunction Service.TeleportPlayer", "World 3 place")
		.. "\nreturn place\n", { debugName = "World3place", environment = environment({
		os = { clock = function()
			return serverClock
		end },
		Workspace = shared,
	}) })()
	assert(isInArrivalGrace(player3) == false, "no grace before any trip")
	assert(place(player3, Vector3.new(0, 10, 0), Vector3.new(0, 0, -1), 4, "stage") == true, "World 3 place() ran")
	assert(attrs3.StageTeleportArrivalGraceUntil == serverClock + 1.75 and attrs3.StageTeleportArrivalGraceUntilServerTime == now3 + 1.75,
		"World 3 stamps the server os.clock() and the shared-clock copy")
	now3 += 1.5
	assert(isInArrivalGrace(player3) == true, "a World 3 stage trip spares the lava prediction during the server's 1.75 s grace")
	now3 += 0.5
	assert(isInArrivalGrace(player3) == false, "...and only for 1.75 s")
	-- The change-of-attribute window alone still covers an os.clock()-only writer (an older server).
	attrs3.StageTeleportArrivalGraceUntilServerTime = nil
	player3:SetAttribute("StageTeleportArrivalGraceUntil", serverClock + 99)
	now3 += 1.5
	assert(isInArrivalGrace(player3) == true, "an os.clock()-only stamp still opens the 1.75 s fallback")
	now3 += 0.5
	assert(isInArrivalGrace(player3) == false, "...and only for 1.75 s")
	-- A ServerTime stamp (Worlds 1 and 2, Speed Force) is honoured on its own.
	attrs3.StageTeleportArrivalGraceUntilServerTime = now3 + 5
	assert(isInArrivalGrace(player3) == true, "the ServerTime stamp gives its full window")
	pass(("arrival grace: clients use the shared clock (StageTeleportArrivalGraceUntilServerTime, not the server's uptime); all %d writers stamp both with the same window; an os.clock()-only stamp still gets %.2f s on the client through the attribute-change window"):format(writers, fallbackSeconds))
end

----------------------------------------------------------------------------------------------
-- 5. The World 1 hammer backstop
----------------------------------------------------------------------------------------------
do
	local source = read(W1_MOTION)
	assert(source:find("if exactHammerTouchesCharacter(group, character, player) then", 1, true), "the backstop is given the player")
	local chunk = slice(source, "local function normalizeName(value)", "\nlocal function", "normalizeName") .. "\n"
		.. slice(source, "local HAMMER_VISIBLE_BODY_NAMES = {", "\n-- A character can receive", "body names") .. "\n"
		-- 2026-09-25 (Update 4, H5): the rewind moved up and is shared by every moving group.
		.. slice(source, "local HAMMER_EXTRA_REWIND_SECONDS", "\n-- Every other moving group", "rewind")
		.. "\nlocal getHammerRewindSeconds = getRewindSeconds\n"
		.. slice(source, "local HAMMER_BACKSTOP_SHRINK", "\nlocal function checkPlayerContact", "backstop")
		.. "\nreturn exactHammerTouchesCharacter\n"
	local touches = luau.load(chunk, { debugName = "hammer backstop", environment = environment({ HammerMotion = HammerMotion }) })()
	assert(source:find("player:GetNetworkPing()", 1, true), "the backstop reads the runner's ping")

	local pivot, axis, phase = Vector3.new(0, 20, 0), Vector3.new(0, 0, 1), 0
	local head = Instance.new("Part")
	head.Size = Vector3.new(6, 4, 4)
	local group = { Parts = { head }, Record = {
		OriginCFrames = { [head] = CFrame.new(0, 2, 0) },
		HammerSystem = { PivotPosition = pivot, Axis = axis, PhaseOffset = phase, ServerTime = 0 },
	} }
	local character = Instance.new("Model")
	local torso = Instance.new("Part")
	torso.Name = "UpperTorso"
	torso.Size = Vector3.new(2, 2, 1)
	torso.Parent = character
	local function player(ping)
		return { GetNetworkPing = function()
			if ping == "error" then
				error("no ping")
			end
			return ping
		end }
	end
	-- The old backstop: the hammer of NOW and of 0.12 s ago against the body the server holds.
	local function oldBackstop(serverTime)
		for _, t in { serverTime, serverTime - 0.12 } do
			local pose = HammerMotion.Transform(pivot, axis, HammerMotion.AngleAt(phase, t))
			if not HammerMotion.BoxesOverlap(pose * CFrame.new(0, 2, 0), head.Size, torso.CFrame, torso.Size, 0.6) then
				return false
			end
		end
		return true
	end
	-- "The hammers hit when you're already on the next platform": a body the hammer reaches only
	-- now, where a runner with ping 0.2 still stands on the server but had left on their screen.
	local found, spared, oldKills = nil, 0, 0
	for step = 0, 300 do
		local serverTime = 3 + step * 0.01
		group.Record.HammerSystem.ServerTime = serverTime
		for x = -16, 16, 0.5 do
			torso.CFrame = CFrame.new(x, 2, 0)
			if oldBackstop(serverTime) then
				oldKills += 1
				if not touches(group, character, player(0.2)) then
					spared += 1
					found = found or { serverTime, x }
				end
			end
		end
	end
	assert(found, "some body the old backstop killed is spared once the hammer is rewound")
	-- A runner who really stays there is still hit, 0.15 s later (when the server's copy of them
	-- has caught up with where they stood as the hammer came through on their screen).
	group.Record.HammerSystem.ServerTime = found[1] + 0.15
	torso.CFrame = CFrame.new(found[2], 2, 0)
	local laterHit = touches(group, character, player(0.2))
	assert(laterHit, "a runner who stays under the hammer is still killed")
	-- A body squarely under the resting hammer is hit at any ping (the backstop still works).
	torso.CFrame = CFrame.new(0, 2, 0)
	for _, ping in { 0, 0.2, "error", 0.9 } do
		local hitFrames = 0
		for step = 0, 300 do
			group.Record.HammerSystem.ServerTime = 3 + step * 0.01
			if touches(group, character, player(ping)) then
				hitFrames += 1
			end
		end
		assert(hitFrames > 0, "the backstop still kills a body the hammer passes through at ping " .. tostring(ping))
	end
	pass(("hammer backstop: posed at ServerTime - (ping/2 + 0.05, max 0.25); at ping 0.2, %d of the %d bodies the old backstop killed live at that instant (e.g. x=%.1f, t=%.2f), one that stays is hit 0.15 s later (%s); a body under the swing is still hit at any ping"):format(spared, oldKills, found[2], found[1], tostring(laterHit)))
end

print(("ALL %d PASSED"):format(passed))
