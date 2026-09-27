-- test_leaderboard_champions.luau
-- 2026-09-26 (owner): "the leaderboards don't look good - make the characters' ACCESSORIES show
-- properly and make them DANCE". The #1 champions on the lobby leaderboards' stands
-- (Shared/LeaderboardChampionRig, UI/GlobalLeaderboardDisplay; World2/World3LeaderboardChampions
-- retired; GlobalLeaderboards.server only labels the stands). Checks:
--   1. every file involved compiles at optimisation level 0 (as Studio compiles);
--   2. the dances are Roblox's own R6 dances (the dance1/dance2/dance3 lists of the classic R6
--      Animate script), one per board, none alike;
--   3. ONE champion layer: the World 2 / World 3 champion scripts are comment-only stubs, the
--      server builds no avatar, only UI/GlobalLeaderboardDisplay stands champions, anchors no
--      limb, places before it parents, and clears the retired scripts' folders;
--   4. the rig on real Lune instances: an avatar as CreateHumanoidModelFromDescriptionAsync hands
--      it over (out of the world, limbs and accessories not laid out, some anchored, scripts,
--      a sound, a light, a tool, BodyColors, an old bogus AccessoryWeld) comes out clean, its
--      accessories welded from their attachments (a modern hair, a legacy hat, a back
--      accessory), an R15-only and a layered one dropped, laid out, scaled to the stand's
--      height, facing the board, feet on the stand at the sky lobby's height, ONLY the root
--      anchored, every Motor6D kept; the default R6 in the board's colour is a real jointed R6;
--      unjointed legs, a ScaleTo that does nothing or fails are refused; the dance track loops;
--   5. the real UI/GlobalLeaderboardDisplay in a small fake Roblox (fake clock, scheduler,
--      services and remote; real instances and the real rig module): default champions on the
--      three stands, the rows' #1 avatars replacing them (one per stand, never two), a failed
--      avatar kept as the default and retried, every champion dancing its own dance near the
--      camera and stopping far away, a new #1 swapping in.
-- Run: lune run audit/test_leaderboard_champions.luau   (from the project root)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Instance, Vector3, CFrame, Color3, Enum = roblox.Instance, roblox.Vector3, roblox.CFrame, roblox.Color3, roblox.Enum
local ENV = { Instance = Instance, Vector3 = Vector3, CFrame = CFrame, Color3 = Color3, Enum = Enum }

local RIG_FILE = "src/common/ReplicatedStorage/Shared/LeaderboardChampionRig.luau"
local CLIENT_FILE = "src/common/StarterPlayer/StarterPlayerScripts/UI/GlobalLeaderboardDisplay.client.luau"
local SERVER_FILE = "src/common/ServerScriptService/Social/GlobalLeaderboards.server.luau"
local STUBS = {
	"src/worlds/World2/StarterPlayer/StarterPlayerScripts/Gameplay/World2LeaderboardChampions.client.luau",
	"src/worlds/World3/StarterPlayer/StarterPlayerScripts/Gameplay/World3LeaderboardChampions.client.luau",
}
local R6_ANIMATE = "src/worlds/World1/ServerStorage/WaterRestoreOldMapTemplate/PLAINs/Rig/Animate.client.luau"

local Rig = require("../src/common/ReplicatedStorage/Shared/LeaderboardChampionRig")

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
local function near(a, b, tolerance)
	return math.abs(a - b) <= tolerance
end
local function withoutPosition(cf)
	return cf - cf.Position
end
-- Attachment and joint CFrames come back float32-rounded (-0.4 reads -0.3999939).
local function sameCF(a, b)
	if (a.Position - b.Position).Magnitude > 1e-3 then
		return false
	end
	return a.LookVector:Dot(b.LookVector) > 0.9999 and a.UpVector:Dot(b.UpVector) > 0.9999
end

----------------------------------------------------------------------
-- 1. Compile (O0)
----------------------------------------------------------------------
for _, path in { RIG_FILE, CLIENT_FILE, SERVER_FILE, STUBS[1], STUBS[2] } do
	local ok, problem = pcall(luau.compile, fs.readFile(path), { optimizationLevel = 0 })
	assert(ok, "COMPILE " .. path .. ": " .. tostring(problem))
end
pass("the rig module, the display, the server and the two stubs compile at O0")

----------------------------------------------------------------------
-- 2. The dances
----------------------------------------------------------------------
do
	local animate = read(R6_ANIMATE)
	local lists = {}
	for _, name in { "dance1", "dance2", "dance3" } do
		local block = string.match(animate, name .. " = {(.-)\n%s*},")
		assert(block, "the classic R6 Animate script has its " .. name .. " list")
		lists[name] = block
	end
	local function listOf(id)
		local number = string.match(id, "^rbxassetid://(%d+)$")
		assert(number, id .. " is an rbxassetid")
		for name, block in lists do
			if string.find(block, "id=" .. number, 1, true) then
				return name
			end
		end
		return nil
	end
	assert(listOf(Rig.Dances.Robux) == "dance1" and listOf(Rig.Dances.Speed) == "dance2" and listOf(Rig.Dances.Wins) == "dance3",
		"Robux / Speed / Wins dance the R6 dance, dance2 and dance3")
	assert(listOf(Rig.Dances.Race) == "dance1" and listOf(Rig.DefaultDance) == "dance1", "Race and any other board: R6 dance variants")
	local seen = {}
	for board, id in Rig.Dances do
		assert(not seen[id], board .. " dances like " .. tostring(seen[id]))
		seen[id] = board
	end
	assert(Rig.DanceFor("Speed") == Rig.Dances.Speed and Rig.DanceFor("Nope") == Rig.DefaultDance and Rig.DanceFor(nil) == Rig.DefaultDance)
	has(read("src/common/StarterPlayer/StarterPlayerScripts/Admin/AdminAbuseEffects.client.luau"),
		'R6 = { "' .. Rig.Dances.Robux .. '", "' .. Rig.Dances.Speed .. '", "' .. Rig.Dances.Wins .. '" }',
		"the same R6 dances the disco already plays")
	assert(Rig.DanceNear >= 60 and Rig.DanceFar > Rig.DanceNear, "the dance stops a little past where it starts")
	pass("the dances: R6 dance (182435998) / dance2 (182436842) / dance3 (182436935), Race a dance variant (182491037), none alike")
end

----------------------------------------------------------------------
-- 3. One champion layer
----------------------------------------------------------------------
do
	for _, path in STUBS do
		local code = read(path):gsub("%-%-[^\n]*", ""):gsub("%s", "")
		assert(code == "", path .. " must be a comment-only stub (retired)")
		has(read(path), "RETIRED 2026-09-26 (owner)", path .. " says why it is retired")
	end

	local server = read(SERVER_FILE)
	for _, needle in { "GetHumanoidDescriptionFromUserId", "CreateHumanoidModelFromDescription", ":ScaleTo(", ":PivotTo(", '"CurrentAvatar"', "installNeutralR6Dummy", "placeAndFreezeAvatar" } do
		assert(not string.find(server, needle, 1, true), "the server builds no champion (found " .. needle .. ")")
	end
	has(server, 'billboard.Name = "ChampionLabel"', "the server still labels each stand")
	has(server, "billboard.Adornee = standTop", "...on the stand")

	-- Only the display (and the server's label) know the champion stands.
	local users = {}
	local function walk(dir)
		for _, name in fs.readDir(dir) do
			local path = dir .. "/" .. name
			if fs.isDir(path) then
				walk(path)
			elseif name:match("%.luau$") and string.find(fs.readFile(path), "_ChampionStandTop", 1, true) then
				table.insert(users, path)
			end
		end
	end
	walk("src/common")
	walk("src/worlds")
	table.sort(users)
	assert(#users == 2 and users[1] == SERVER_FILE and users[2] == CLIENT_FILE,
		"only the server (label) and the display use the champion stands: " .. table.concat(users, ", "))

	local client = read(CLIENT_FILE)
	assert(not string.find(client, ".Anchored = true", 1, true), "the display anchors nothing itself (the rig anchors only the root)")
	for _, needle in {
		'WaitForChild("LeaderboardChampionRig", 10)',
		"ChampionRig.Prepare(RIG_ENV, avatar)",
		"ChampionRig.Place(RIG_ENV, avatar, state.Target)",
		"ChampionRig.Settle(RIG_ENV, model, state.Target)",
		"ChampionRig.LoadDance(RIG_ENV, model, danceId)",
		"ChampionRig.PlayDance(state.DanceTrack)",
		"ChampionRig.StopDance(state.DanceTrack)",
		"distance <= ChampionRig.DanceNear",
		"distance > ChampionRig.DanceFar",
		"Enum.HumanoidRigType.R6",
		'"World2LeaderboardChampionVisuals_LOCAL"',
		'"World3LeaderboardChampionVisuals_LOCAL"',
		'local CHAMPION_FOLDER_NAME = "LeaderboardChampionVisuals_LOCAL"',
	} do
		has(client, needle, "the display")
	end
	local placeAt = assert(string.find(client, "ChampionRig.Place(RIG_ENV, avatar, state.Target)", 1, true))
	local showAt = assert(string.find(client, "showChampion(state, avatar)", placeAt, true))
	assert(placeAt < showAt, "the avatar is placed out of the world, then shown")
	pass("one layer: the World 2 / 3 scripts are stubs, the server only labels, the display places then parents, anchors nothing itself")
end

----------------------------------------------------------------------
-- The fake engine pieces Lune lacks: Model:ScaleTo / GetScale (sizes, positions about the pivot,
-- joint and attachment offsets, file meshes: what Roblox's does) and Animator:LoadAnimation.
----------------------------------------------------------------------
local scaleMode = "normal" -- "normal" | "ignore" | "error"
local function scaledOffset(cf, k)
	return CFrame.new(cf.Position * k) * withoutPosition(cf)
end
roblox.implementMethod("Model", "GetScale", function(self)
	return self:GetAttribute("TestScale") or 1
end)
roblox.implementMethod("Model", "ScaleTo", function(self, newScale)
	if scaleMode == "error" then
		error("ScaleTo failed (test)")
	end
	local k = newScale / (self:GetAttribute("TestScale") or 1)
	self:SetAttribute("TestScale", newScale)
	if scaleMode == "ignore" then
		return
	end
	local pivot = if self.PrimaryPart then self.PrimaryPart.CFrame else CFrame.new()
	for _, d in self:GetDescendants() do
		if d:IsA("BasePart") then
			local relative = pivot:ToObjectSpace(d.CFrame)
			d.Size = d.Size * k
			d.CFrame = pivot * scaledOffset(relative, k)
		elseif d:IsA("JointInstance") then
			d.C0 = scaledOffset(d.C0, k)
			d.C1 = scaledOffset(d.C1, k)
		elseif d:IsA("Attachment") then
			d.CFrame = scaledOffset(d.CFrame, k)
		elseif d:IsA("SpecialMesh") and d.MeshType == Enum.MeshType.FileMesh then
			d.Scale = d.Scale * k
		end
	end
end)
local tracks = {}
local loadAnimationFails = false
roblox.implementMethod("Animator", "LoadAnimation", function(self, animation)
	if loadAnimationFails then
		error("LoadAnimation failed (test)")
	end
	local ok, id = pcall(function()
		return animation.AnimationId
	end)
	local track = { AnimationId = if ok then tostring(id) else "?", Animator = self, Playing = false, Plays = 0, Stops = 0 }
	function track:Play()
		self.Playing = true
		self.Plays += 1
	end
	function track:Stop()
		self.Playing = false
		self.Stops += 1
	end
	table.insert(tracks, track)
	return track
end)

----------------------------------------------------------------------
-- An avatar as CreateHumanoidModelFromDescriptionAsync(R6) hands it over, out of the world:
-- limbs and accessories not laid out (all piled up), some parts anchored.
----------------------------------------------------------------------
local R6_JOINTS = {
	{ "RootJoint", "HumanoidRootPart", "Torso", CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0) },
	{ "Neck", "Torso", "Head", CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), CFrame.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0) },
	{ "Left Shoulder", "Torso", "Left Arm", CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0) },
	{ "Right Shoulder", "Torso", "Right Arm", CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CFrame.new(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0) },
	{ "Left Hip", "Torso", "Left Leg", CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0) },
	{ "Right Hip", "Torso", "Right Leg", CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CFrame.new(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0) },
}
local R6_ATTACHMENTS = {
	Head = { HatAttachment = CFrame.new(0, 0.6, 0), HairAttachment = CFrame.new(0, 0.6, 0), FaceFrontAttachment = CFrame.new(0, 0, -0.6) },
	Torso = { NeckAttachment = CFrame.new(0, 1, 0), BodyFrontAttachment = CFrame.new(0, 0, -0.5), BodyBackAttachment = CFrame.new(0, 0, 0.5), WaistBackAttachment = CFrame.new(0, -1, 0.5) },
	["Left Arm"] = { LeftShoulderAttachment = CFrame.new(0, 1, 0) },
	["Right Arm"] = { RightShoulderAttachment = CFrame.new(0, 1, 0) },
	["Left Leg"] = { LeftFootAttachment = CFrame.new(0, -1, 0) },
	["Right Leg"] = { RightFootAttachment = CFrame.new(0, -1, 0) },
}
local SKIN = Color3.fromRGB(124, 92, 70)
local SHIRT = Color3.fromRGB(13, 105, 172)

local function accessory(model, name, attachmentName, attachmentCFrame, size)
	local item = Instance.new("Accessory")
	item.Name = name
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = size or Vector3.new(2, 1, 2)
	handle.CFrame = CFrame.new(40, -25, 12) -- where the asset left it: nowhere near the head
	handle.Anchored = true
	handle.Parent = item
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.Scale = Vector3.new(1, 1, 1)
	mesh.Parent = handle
	if attachmentName then
		local attachment = Instance.new("Attachment")
		attachment.Name = attachmentName
		attachment.CFrame = attachmentCFrame
		attachment.Parent = handle
	end
	item.Parent = model
	return item, handle
end

local function makeAvatar(userId)
	local model = Instance.new("Model")
	model.Name = "User" .. tostring(userId)
	local parts = {}
	for _, spec in {
		{ "HumanoidRootPart", Vector3.new(2, 2, 1) },
		{ "Torso", Vector3.new(2, 2, 1) },
		{ "Head", Vector3.new(2, 1, 1) },
		{ "Left Arm", Vector3.new(1, 2, 1) },
		{ "Right Arm", Vector3.new(1, 2, 1) },
		{ "Left Leg", Vector3.new(1, 2, 1) },
		{ "Right Leg", Vector3.new(1, 2, 1) },
	} do
		local part = Instance.new("Part")
		part.Name = spec[1]
		part.Size = spec[2]
		part.CFrame = CFrame.new(0, 0, 0) -- not laid out yet
		part.Anchored = spec[1] == "Head" or spec[1] == "Left Leg"
		part.Parent = model
		parts[spec[1]] = part
		for name, cf in R6_ATTACHMENTS[spec[1]] or {} do
			local attachment = Instance.new("Attachment")
			attachment.Name = name
			attachment.CFrame = cf
			attachment.Parent = part
		end
	end
	for _, joint in R6_JOINTS do
		local motor = Instance.new("Motor6D")
		motor.Name = joint[1]
		motor.Part0 = parts[joint[2]]
		motor.Part1 = parts[joint[3]]
		motor.C0 = joint[4]
		motor.C1 = joint[5]
		motor.Parent = parts[joint[2]]
	end
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Parent = parts.Head
	local colors = Instance.new("BodyColors")
	for _, field in { "HeadColor3", "LeftArmColor3", "RightArmColor3", "LeftLegColor3", "RightLegColor3" } do
		colors[field] = SKIN
	end
	colors.TorsoColor3 = SHIRT
	colors.Parent = model
	Instance.new("Shirt").Parent = model
	Instance.new("Pants").Parent = model
	Instance.new("Humanoid").Parent = model
	local animate = Instance.new("LocalScript")
	animate.Name = "Animate"
	animate.Parent = model
	Instance.new("Script").Parent = model
	Instance.new("Sound").Parent = parts.Head
	Instance.new("PointLight").Parent = parts.Torso
	Instance.new("Tool").Parent = model

	-- A modern hair with an old AccessoryWeld that holds it wrong.
	local _, hair = accessory(model, "Hair", "HairAttachment", CFrame.new(0, -0.4, 0.1))
	local bogus = Instance.new("Weld")
	bogus.Name = "AccessoryWeld"
	bogus.Part0 = hair
	bogus.Part1 = parts.Head
	bogus.C0 = CFrame.new(5, 5, 5)
	bogus.Parent = hair
	-- A legacy hat (no attachment: its AttachmentPoint on top of the head).
	local hat = accessory(model, "ClassicHat", nil, nil, Vector3.new(2, 1, 2))
	hat.AttachmentPoint = CFrame.new(0, -0.25, 0)
	-- A back accessory with an old WeldConstraint.
	local _, back = accessory(model, "Wings", "BodyBackAttachment", CFrame.new(0, 0, -0.3), Vector3.new(3, 3, 1))
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = back
	constraint.Part1 = parts.Torso
	constraint.Parent = back
	-- Fit nowhere on an R6: an R15-only attachment, a layered jacket.
	accessory(model, "Watch", "LeftWristRigAttachment", CFrame.new())
	local _, jacket = accessory(model, "Jacket", "BodyFrontAttachment", CFrame.new())
	Instance.new("WrapLayer").Parent = jacket
	return model
end

-- A stand like World 1's (sky lobby, y ~37,475), its board facing -X.
local function makeStand(parent, prefix, z)
	local standTop = Instance.new("Part")
	standTop.Name = prefix .. "_ChampionStandTop"
	standTop.Size = Vector3.new(10.641081, 0.6318152, 6.517662)
	standTop.CFrame = CFrame.new(419.75314, 37474.598, z)
	standTop.Anchored = true
	standTop.Parent = parent
	local frame = Instance.new("Part")
	frame.Name = prefix .. "_LeaderboardFrame"
	frame.Size = Vector3.new(1, 23.377124786376953, 16)
	frame.CFrame = CFrame.new(422, 37488, z + 15)
	frame.Anchored = true
	frame.Parent = parent
	local screen = Instance.new("Part")
	screen.Name = prefix .. "_LeaderboardScreen"
	screen.Size = Vector3.new(14, 18, 0.2)
	screen.CFrame = Rig.Facing(ENV, Vector3.new(421, 37488, z + 15), Vector3.new(-1, 0, 0))
	screen.Anchored = true
	screen.Parent = parent
	return standTop, frame, screen
end

local function anchoredParts(model)
	local list = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Anchored then
			table.insert(list, d.Name)
		end
	end
	return list
end

-- The checks every placed champion must pass.
local function checkStanding(model, target, label)
	assert(model:GetAttribute("ChampionValidation") == "PassedRootAnchoredR6", label .. ": validation " .. tostring(model:GetAttribute("ChampionValidation")))
	local anchored = anchoredParts(model)
	assert(#anchored == 1 and anchored[1] == "HumanoidRootPart", label .. ": only the root is anchored (" .. table.concat(anchored, ", ") .. ")")
	assert(model:GetAttribute("ChampionAnchoredPartCount") == 1 and model:GetAttribute("ChampionFreezeMode") == "RootOnlyMotor6D", label .. ": freeze attributes")
	local feet = assert(Rig.FeetBottomY(model))
	assert(near(feet, target.SurfaceY, Rig.FeetEpsilon), string.format("%s: feet %.4f on the stand %.4f", label, feet, target.SurfaceY))
	local height = Rig.BodyHeight(model)
	assert(near(height, target.Height, target.Height * 0.01), string.format("%s: %.3f studs tall (stand wants %.3f)", label, height, target.Height))
	local root = model:FindFirstChild("HumanoidRootPart")
	assert(model.PrimaryPart == root, label .. ": the root is the PrimaryPart")
	assert(near(root.CFrame.Position.X, target.Position.X, 0.02) and near(root.CFrame.Position.Z, target.Position.Z, 0.02), label .. ": centred on the stand")
	local head = model:FindFirstChild("Head")
	assert(head.CFrame.LookVector:Dot(target.Front) > 0.999, label .. ": faces the board's front")
	local motors = 0
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			motors += 1
		end
		assert(not d:IsA("LuaSourceContainer"), label .. ": no script left in the model (" .. d:GetFullName() .. ")")
	end
	assert(motors == 6, label .. ": the six R6 Motor6Ds stay for the dance, got " .. motors)
	-- Every accessory is welded to the body, where its weld says, within the body's span.
	local low, high = feet, feet + height
	for _, item in model:GetChildren() do
		if item:IsA("Accoutrement") then
			local handle = item:FindFirstChild("Handle")
			assert(not handle.Anchored, label .. ": " .. item.Name .. " is not anchored")
			local weld = handle:FindFirstChild("AccessoryWeld")
			assert(weld and weld:IsA("Weld") and weld.Part0 == handle and weld.Part1 and weld.Part1.Parent == model,
				label .. ": " .. item.Name .. " is welded to the body")
			local a = (handle.CFrame * weld.C0).Position
			local b = (weld.Part1.CFrame * weld.C1).Position
			assert((a - b).Magnitude < 0.03, string.format("%s: %s sits where its weld holds it (%.3f off)", label, item.Name, (a - b).Magnitude))
			local y = handle.CFrame.Position.Y
			assert(y > low and y < high + 3, string.format("%s: %s is on the body (y %.2f, body %.2f..%.2f)", label, item.Name, y, low, high))
			local offset = handle.CFrame.Position - root.CFrame.Position
			assert(Vector3.new(offset.X, 0, offset.Z).Magnitude < 3 * target.Height / 5, label .. ": " .. item.Name .. " stays by the body")
		end
	end
end

----------------------------------------------------------------------
-- 4. The rig on Lune instances
----------------------------------------------------------------------
local lobby = Instance.new("Model")
lobby.Name = "leaderboard1"
local standTop, frame, screen = makeStand(lobby, "Robux", -1795.4445)
local target = assert(Rig.StandTarget(ENV, standTop, frame, screen))
do
	assert(target.SupportName == "Robux_ChampionStandTop", "the target names its stand")
	assert(near(target.SurfaceY, 37474.598 + 0.6318152 / 2, 0.01), "the stand's top surface")
	assert(near(target.Height, 18, 1e-6), "23.4-stud frame x 1.12 capped at 18 studs")
	assert(target.Front:Dot(Vector3.new(-1, 0, 0)) > 0.9999, "the board's horizontal front")
	assert(Rig.StandTarget(ENV, nil, frame, screen) == nil, "no stand, no target")

	-- Prepare
	local avatar = makeAvatar(111)
	local summary = Rig.Prepare(ENV, avatar)
	assert(summary.Attached == 3 and summary.Dropped == 2, ("3 accessories on, 2 dropped; got %d / %d"):format(summary.Attached, summary.Dropped))
	assert(avatar:FindFirstChild("Hair") and avatar:FindFirstChild("ClassicHat") and avatar:FindFirstChild("Wings"), "hair, hat and wings kept")
	assert(not avatar:FindFirstChild("Watch") and not avatar:FindFirstChild("Jacket"), "the R15-only watch and the layered jacket are dropped, not left lying")
	for _, d in avatar:GetDescendants() do
		assert(not (d:IsA("LuaSourceContainer") or d:IsA("Tool") or d:IsA("Sound") or d:IsA("Light")), "Prepare leaves no " .. d.ClassName)
		if d:IsA("BasePart") then
			assert(not d.Anchored and not d.CanCollide, d.Name .. " unanchored, not colliding")
		end
		if d:IsA("WeldConstraint") then
			error("the back accessory's old WeldConstraint is replaced by its AccessoryWeld")
		end
	end
	assert(avatar.Torso.Color == SHIRT and avatar.Head.Color == SKIN and avatar["Left Leg"].Color == SKIN, "the BodyColors are on the parts")
	local humanoid = avatar:FindFirstChildOfClass("Humanoid")
	assert(humanoid:FindFirstChildOfClass("Animator"), "the Humanoid gets an Animator")
	assert(humanoid.EvaluateStateMachine == false and humanoid.DisplayDistanceType == Enum.HumanoidDisplayDistanceType.None
		and humanoid.HealthDisplayType == Enum.HumanoidHealthDisplayType.AlwaysOff and humanoid.BreakJointsOnDeath == false,
		"a quiet statue Humanoid")
	local hairWeld = avatar.Hair.Handle:FindFirstChild("AccessoryWeld")
	assert(sameCF(hairWeld.C0, CFrame.new(0, -0.4, 0.1)) and sameCF(hairWeld.C1, CFrame.new(0, 0.6, 0)) and hairWeld.Part1 == avatar.Head,
		"the hair's bogus weld is rebuilt from HairAttachment on both sides")
	assert(#avatar.Hair.Handle:GetChildren() == 3, "one AccessoryWeld on the hair (mesh, attachment, weld)")
	local hatWeld = avatar.ClassicHat.Handle:FindFirstChild("AccessoryWeld")
	assert(hatWeld.Part1 == avatar.Head and sameCF(hatWeld.C0, CFrame.new(0, -0.25, 0)) and sameCF(hatWeld.C1, CFrame.new(0, 0.5, 0)),
		"the legacy hat sits by its AttachmentPoint on top of the head")
	assert(avatar.Wings.Handle.AccessoryWeld.Part1 == avatar.Torso, "the wings on the torso's BodyBackAttachment")
	pass("Prepare: scripts, sound, light and tool out; parts unanchored; BodyColors on; quiet Humanoid + Animator; hair / hat / wings welded from their attachments, the R15-only and layered ones dropped")

	-- Place
	local ok, reason = Rig.Place(ENV, avatar, target)
	assert(ok, "the avatar stands: " .. tostring(reason))
	checkStanding(avatar, target, "avatar")
	local hairTop = avatar.Hair.Handle.CFrame.Position.Y
	local torsoTop = select(2, Rig.VerticalBounds(avatar.Torso))
	assert(hairTop > torsoTop, "the hair is on the head, above the torso (it used to lie at the stand's foot)")
	assert(near(avatar:GetScale(), 18 / 5, 1e-4), "scaled x3.6 (a 5-stud R6 to 18 studs)")
	assert(avatar:GetAttribute("ChampionSupportPart") == "Robux_ChampionStandTop" and avatar:GetAttribute("ChampionPlacementRoute") == Rig.Version,
		"the placement attributes")
	assert(avatar.Parent == nil, "Place works out of the world and leaves parenting to the caller")
	assert(Rig.Settle(ENV, avatar, target) and avatar:GetAttribute("ChampionSettled") == true, "Settle: the feet are already right")
	pass("Place: laid out, x3.6, facing the board, feet on the sky stand, accessories where their welds hold them, only the root anchored, 6 Motor6Ds kept")

	-- Dance
	local track = assert(Rig.LoadDance(ENV, avatar, Rig.DanceFor("Robux")), "the dance loads on the Animator")
	assert(track.Looped == true and track.Priority == Enum.AnimationPriority.Action, "the dance loops, at Action priority")
	assert(track.Animator.Parent == avatar:FindFirstChildOfClass("Humanoid"), "on the champion's own Animator")
	assert(string.find(track.AnimationId, "182435998", 1, true) or track.AnimationId == "?", "the Robux dance id")
	assert(Rig.PlayDance(track) and track.Playing, "PlayDance plays it")
	Rig.StopDance(track)
	assert(not track.Playing and track.Stops == 1, "StopDance stops it")
	assert(Rig.PlayDance(nil) == false, "no track, nothing plays")
	loadAnimationFails = true
	assert(Rig.LoadDance(ENV, avatar, Rig.DanceFor("Wins")) == nil, "a dance that cannot load leaves the champion standing")
	loadAnimationFails = false
	local noHumanoid = Instance.new("Model")
	assert(Rig.LoadDance(ENV, noHumanoid, Rig.DefaultDance) == nil, "no Humanoid, no dance")
	pass("the dance: a looping Action track on the champion's Animator; Play / Stop; a failed load just stands")

	-- The default champion
	local accent = Color3.fromRGB(0, 255, 92)
	local neutral = Rig.BuildNeutralR6(ENV, "Robux_ChampionFallback_R6", accent)
	local names = {}
	for _, d in neutral:GetDescendants() do
		if d:IsA("Motor6D") then
			names[d.Name] = d.Parent.Name .. ">" .. d.Part1.Name
		end
	end
	assert(names.RootJoint == "HumanoidRootPart>Torso" and names.Neck == "Torso>Head" and names["Left Shoulder"] == "Torso>Left Arm"
		and names["Right Shoulder"] == "Torso>Right Arm" and names["Left Hip"] == "Torso>Left Leg" and names["Right Hip"] == "Torso>Right Leg",
		"the default champion has the six R6 Motor6Ds where an avatar has them")
	local head = neutral:FindFirstChild("Head")
	assert(head:FindFirstChildOfClass("SpecialMesh").MeshType == Enum.MeshType.Head and head:FindFirstChild("face"), "a classic head with a face")
	assert(neutral.Torso.Color == accent and neutral:FindFirstChildOfClass("BodyColors").TorsoColor3 == accent, "the board's colour on the torso")
	assert(neutral:FindFirstChildOfClass("Humanoid").RigType == Enum.HumanoidRigType.R6, "an R6 Humanoid")
	assert(near(Rig.BodyHeight(neutral), 5, 1e-3), "a 5-stud R6, laid out")
	Rig.Prepare(ENV, neutral)
	assert(Rig.Place(ENV, neutral, target), "the default champion stands")
	checkStanding(neutral, target, "default")
	assert(Rig.LoadDance(ENV, neutral, Rig.DanceFor("Robux")), "the default champion dances too")
	pass("the default champion: a jointed R6 (classic head, face, the board's colour) that stands and dances like an avatar")

	-- Refusals
	local loose = makeAvatar(5)
	loose.Torso:FindFirstChild("Left Hip"):Destroy()
	Rig.Prepare(ENV, loose)
	local placed, why = Rig.Place(ENV, loose, target)
	assert(not placed and why == "NotAJointedR6", "a leg not jointed to the body is refused: " .. tostring(why))
	scaleMode = "ignore"
	local unscaled = makeAvatar(6)
	Rig.Prepare(ENV, unscaled)
	placed, why = Rig.Place(ENV, unscaled, target)
	assert(not placed and why == "RejectedBodyHeight" and unscaled:GetAttribute("ChampionValidation") == "RejectedBodyHeight",
		"a body that did not scale is refused: " .. tostring(why))
	scaleMode = "error"
	local failing = makeAvatar(7)
	Rig.Prepare(ENV, failing)
	placed, why = Rig.Place(ENV, failing, target)
	assert(not placed and string.find(tostring(why), "^ScaleTo"), "a ScaleTo error is refused: " .. tostring(why))
	scaleMode = "normal"
	local parented = makeAvatar(8)
	parented.Parent = lobby
	Rig.Prepare(ENV, parented)
	assert(Rig.Place(ENV, parented, target) and parented.Parent == nil, "a model in the world is taken out before it is laid out")
	pass("refused: unjointed legs, a body that did not scale, a ScaleTo error; a parented model is placed out of the world")
end

----------------------------------------------------------------------
-- 5. The real display in a small fake Roblox
----------------------------------------------------------------------
do
	-- The clock and the scheduler.
	local clockNow = 100
	local sleepers = {}
	local function resume(co, ...)
		local ok, problem = coroutine.resume(co, ...)
		if not ok then
			error("a client thread failed: " .. tostring(problem) .. "\n" .. debug.traceback(co), 0)
		end
	end
	local fakeTask = {}
	function fakeTask.spawn(fn, ...)
		local co = coroutine.create(fn)
		resume(co, ...)
		return co
	end
	function fakeTask.defer(fn, ...)
		table.insert(sleepers, { at = clockNow, fn = fn, args = table.pack(...) })
	end
	function fakeTask.delay(seconds, fn, ...)
		table.insert(sleepers, { at = clockNow + (seconds or 0), fn = fn, args = table.pack(...) })
	end
	function fakeTask.wait(seconds)
		table.insert(sleepers, { at = clockNow + (seconds or 0), co = coroutine.running() })
		coroutine.yield()
		return seconds or 0
	end
	local function run(seconds)
		local steps = math.max(1, math.round(seconds / 0.1))
		for _ = 1, steps do
			clockNow += 0.1
			local due = {}
			local index = 1
			while index <= #sleepers do
				if sleepers[index].at <= clockNow + 1e-9 then
					table.insert(due, table.remove(sleepers, index))
				else
					index += 1
				end
			end
			for _, item in due do
				if item.co then
					if coroutine.status(item.co) == "suspended" then
						resume(item.co)
					end
				else
					fakeTask.spawn(item.fn, table.unpack(item.args, 1, item.args.n))
				end
			end
		end
	end

	-- The remote.
	local handlers = {}
	local fired = {}
	local remote = {
		OnClientEvent = { Connect = function(_, fn)
			table.insert(handlers, fn)
			return { Disconnect = function() end }
		end },
	}
	function remote:FireServer(...)
		table.insert(fired, { ... })
	end
	local function send(categoryId, userId)
		local rows = {}
		if userId then
			rows[1] = { Rank = 1, UserId = userId, Username = "User" .. userId, Value = "1" }
		end
		for _, fn in handlers do
			fn(categoryId, rows, false)
		end
	end

	-- The services.
	local rigHandle = { Name = "LeaderboardChampionRig" }
	local shared = { WaitForChild = function(_, name)
		return if name == "LeaderboardChampionRig" then rigHandle else nil
	end }
	local remotes = { WaitForChild = function(_, name)
		assert(name == "GlobalLeaderboardDisplay", name)
		return remote
	end }
	local replicatedStorage = { WaitForChild = function(_, name)
		return if name == "Remotes" then remotes elseif name == "Shared" then shared else nil
	end }
	local world = Instance.new("Folder")
	world.Name = "Workspace"
	local board = Instance.new("Model")
	board.Name = "leaderboard1"
	local targets = {}
	for index, id in { "Robux", "Speed", "Wins" } do
		local top, boardFrame, boardScreen = makeStand(board, id, -1795.4445 + (index - 1) * 39.9)
		targets[id] = Rig.StandTarget(ENV, top, boardFrame, boardScreen)
	end
	-- What a retired World 2 script left behind.
	local stale = Instance.new("Folder")
	stale.Name = "World2LeaderboardChampionVisuals_LOCAL"
	stale.Parent = board
	board.Parent = world
	local camera = { CFrame = CFrame.new(400, 37482, -1755) }
	local fakeWorkspace = { CurrentCamera = camera }
	function fakeWorkspace:FindFirstChild(name, recursive)
		return world:FindFirstChild(name, recursive)
	end
	local playerGui = Instance.new("Folder")
	playerGui.Name = "PlayerGui"
	local failing = {}
	local descriptionCalls = {}
	local fakePlayers = {
		LocalPlayer = { Name = "Tester", UserId = 1, WaitForChild = function()
			return playerGui
		end },
	}
	function fakePlayers:GetHumanoidDescriptionFromUserIdAsync(userId)
		descriptionCalls[userId] = (descriptionCalls[userId] or 0) + 1
		if failing[userId] then
			error("HTTP 429 (Too Many Requests) (test)")
		end
		local description = Instance.new("HumanoidDescription")
		description:SetAttribute("UserId", userId)
		return description
	end
	function fakePlayers:CreateHumanoidModelFromDescriptionAsync(description, rigType)
		assert(rigType == Enum.HumanoidRigType.R6, "the champions are R6")
		return makeAvatar(description:GetAttribute("UserId"))
	end
	local services = { Players = fakePlayers, ReplicatedStorage = replicatedStorage, Workspace = fakeWorkspace }
	local warnings, prints = {}, {}
	local env = setmetatable({
		game = { GetService = function(_, name)
			return assert(services[name], "service " .. name)
		end },
		task = fakeTask,
		os = setmetatable({ clock = function()
			return clockNow
		end }, { __index = os }),
		require = function(handle)
			assert(handle == rigHandle, "the display requires only the rig module")
			return Rig
		end,
		print = function(...)
			table.insert(prints, table.concat({ ... }, " "))
		end,
		warn = function(...)
			table.insert(warnings, table.concat({ ... }, " "))
		end,
		typeof = typeof,
		Instance = Instance, Vector3 = Vector3, CFrame = CFrame, Color3 = Color3, Enum = Enum,
		UDim = roblox.UDim, UDim2 = roblox.UDim2, Vector2 = roblox.Vector2,
	}, { __index = _G })

	luau.load(read(CLIENT_FILE), { debugName = "GlobalLeaderboardDisplay", environment = env })()
	run(1)

	local folder = board:FindFirstChild("LeaderboardChampionVisuals_LOCAL")
	assert(folder, "the display makes its champion folder on leaderboard1")
	assert(stale.Parent == nil, "the retired World 2 script's folder is cleared")
	local function champions()
		local byStand = {}
		for _, model in folder:GetChildren() do
			local stand = model:GetAttribute("ChampionSupportPart")
			assert(stand, model.Name .. " names its stand")
			assert(byStand[stand] == nil, "two champions on " .. stand .. ": " .. model.Name .. " and " .. tostring(byStand[stand] and byStand[stand].Name))
			byStand[stand] = model
		end
		return byStand
	end
	local function onStand(id)
		return champions()[id .. "_ChampionStandTop"]
	end
	for _, id in { "Robux", "Speed", "Wins" } do
		local model = assert(onStand(id), id .. " has a default champion")
		assert(model:GetAttribute("ChampionVisualKind") == "NeutralR6Fallback", id .. ": the default champion first")
		checkStanding(model, targets[id], id .. " default")
		assert(model:GetAttribute("ChampionSettled") == true, id .. ": settled a frame after it entered the world")
		assert(model:GetAttribute("ChampionDancing") == true and model:GetAttribute("ChampionDanceId") == Rig.Dances[id], id .. " default champion dances its dance")
	end
	assert(#folder:GetChildren() == 3, "three champions, one per stand")
	local sawRequest = false
	for _, call in fired do
		sawRequest = sawRequest or call[1] == "Request"
	end
	assert(sawRequest, "the display asks the server for the rows")
	pass("the display: a default champion on each of the 3 stands, settled and dancing; the retired World 2 folder cleared")

	-- The rows: #1 avatars. Wins's cannot load at first.
	failing[333] = true
	send("Robux", 111)
	send("Speed", 222)
	send("Wins", 333)
	run(1)
	local robux, speed, wins = onStand("Robux"), onStand("Speed"), onStand("Wins")
	assert(robux.Name == "Robux_NumberOneR6FullAppearance_111" and robux:GetAttribute("ChampionPublicAppearanceUserId") == 111, "Robux's #1 stands")
	assert(speed.Name == "Speed_NumberOneR6FullAppearance_222", "Speed's #1 stands")
	assert(wins:GetAttribute("ChampionVisualKind") == "NeutralR6Fallback", "Wins keeps its default champion while the avatar fails")
	for id, model in { Robux = robux, Speed = speed } do
		checkStanding(model, targets[id], id .. " #1")
		assert(model:GetAttribute("ChampionAccessoriesAttached") == 3 and model:GetAttribute("ChampionAccessoriesDropped") == 2, id .. ": 3 accessories on, 2 dropped")
		assert(model:FindFirstChild("Hair").Handle.CFrame.Position.Y > select(2, Rig.VerticalBounds(model.Torso)), id .. ": the hair on the head")
		assert(model:GetAttribute("ChampionDancing") == true and model:GetAttribute("ChampionDanceId") == Rig.Dances[id], id .. " #1 dances its own dance")
	end
	assert(#folder:GetChildren() == 3, "still one champion per stand")
	local failedWarning = false
	for _, text in warnings do
		failedWarning = failedWarning or (string.find(text, "Wins could not show #1 user 333", 1, true) ~= nil)
	end
	assert(failedWarning, "the failure is reported once")
	assert(descriptionCalls[333] == 1, "one try so far")
	failing[333] = nil
	run(16)
	wins = onStand("Wins")
	assert(descriptionCalls[333] == 2 and wins.Name == "Wins_NumberOneR6FullAppearance_333", "the Wins avatar is asked again 15 s later and stands")
	checkStanding(wins, targets.Wins, "Wins #1")
	assert(wins:GetAttribute("ChampionDancing") == true and wins:GetAttribute("ChampionDanceId") == Rig.Dances.Wins, "Wins #1 dances")
	local ids = {}
	for _, model in champions() do
		ids[model:GetAttribute("ChampionDanceId")] = true
	end
	assert(ids[Rig.Dances.Robux] and ids[Rig.Dances.Speed] and ids[Rig.Dances.Wins], "three different dances on the three stands")
	pass("the rows: each #1's full R6 avatar replaces the default (accessories on, root anchored, dancing its board's dance); a failed avatar keeps the default and is retried")

	-- Far from the camera the dances stop; back near, the same tracks play again.
	local loaded = #tracks
	camera.CFrame = CFrame.new(400 + 600, 37482, -1755)
	run(1)
	for id, model in champions() do
		assert(model:GetAttribute("ChampionDancing") == false, id .. " stops dancing far away")
	end
	local playing = 0
	for _, track in tracks do
		-- (the tracks of replaced champions went with their destroyed Animators)
		local ok, alive = pcall(function()
			return track.Animator:IsDescendantOf(folder)
		end)
		if track.Playing and ok and alive then
			playing += 1
		end
	end
	assert(playing == 0, "no champion track plays far away")
	camera.CFrame = CFrame.new(400, 37482, -1755)
	run(1)
	for id, model in champions() do
		assert(model:GetAttribute("ChampionDancing") == true, id .. " dances again near")
	end
	assert(#tracks == loaded, "the same tracks play again (nothing reloaded)")
	pass("the dances stop past " .. Rig.DanceFar .. " studs from the camera and play again within " .. Rig.DanceNear .. " (the same tracks)")

	-- A new #1, the same #1 again, and a board with no rows.
	local old = onStand("Robux")
	send("Robux", 444)
	run(1)
	local new = onStand("Robux")
	assert(new.Name == "Robux_NumberOneR6FullAppearance_444" and old.Parent == nil, "a new #1 replaces the old one")
	checkStanding(new, targets.Robux, "new Robux #1")
	assert(new:GetAttribute("ChampionDancing") == true, "the new #1 dances")
	local calls = descriptionCalls[444]
	send("Robux", 444)
	run(1)
	assert(descriptionCalls[444] == calls and onStand("Robux") == new, "the same #1 again loads nothing")
	send("Speed", nil)
	run(1)
	assert(onStand("Speed"):GetAttribute("ChampionVisualKind") == "NeutralR6Fallback", "a board with no rows shows the default champion")
	assert(#folder:GetChildren() == 3, "one champion per stand throughout")
	pass("a new #1 swaps in and dances; the same #1 loads nothing; no rows -> the default champion; never two on a stand")
end

print(string.format("test_leaderboard_champions: %d checks passed", passed))
