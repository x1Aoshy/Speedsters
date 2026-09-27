-- ReplicatedStorage/Shared/LobbyNpcRig.luau — Update 4 (2026-09-25): the lobby NPCs' bodies and
-- the owner's own NPC models, with the constructors of `env` ({ Instance, Vector3, CFrame,
-- Color3, Enum }: the Roblox globals in the game, @lune/roblox in audit/test_u4_npcs).
-- The owner's models (2026-09-25: Eggman is his own model, Flash may be):
--   OwnerKind(model, taggedKind)         "Eggman" / "Flash" and the model's root when it is one
--   PrepareOwnerModel(env, model, root)  root anchored, the jointed body unanchored and out of the
--                                        way (no collide / touch / query), loose parts kept in
--                                        place, scripts off, Animators gone: the idle owns the joints
--   FindJoints(model)                    the six pose joints on an R6 or an R15 rig
--   AddPrompt(env, root, ...)            the ProximityPrompt on an attachment in the root
-- Built from plain parts (no asset uploads are possible from code; SpecialMesh Sphere, Ball and
-- Cylinder shapes need no asset id):
--   BuildEggman(env, floor)  Dr. Eggman, chunky and stylized: a big egg of a red jacket (a wide
--                            belly under a narrower chest), bald head, huge orange mustache
--                            swept up at the tips, round blue goggles on a strap across the
--                            forehead, small blue pince-nez, white gloves, black pants and boots.
--                            ~7.8 studs tall on his base. Only with LobbyNpcConfig.SpawnPartsEggman.
--   BuildR6(env, floor)      a classic R6 body in Flash's colours. The game no longer spawns it
--                            (2026-09-25, owner: no parts-built Flash); the tests use it as an
--                            owner's R6 model.
--   AddBase(env, model, floor, colors)  the 0.4-stud disc a spawned NPC stands on.
--   Configure(model, root, base)        physics and queries for a spawned NPC.
-- Both rigs are R6-shaped: HumanoidRootPart (anchored) -> RootJoint -> Torso -> Neck / Left
-- Shoulder / Right Shoulder / Left Hip / Right Hip, Motor6Ds named as R6 so Shared/LobbyNpcPose
-- drives either on the client. `floor` is the floor frame under the feet (LobbyNpcConfig.
-- SpotCFrame); every part gets its world CFrame here, so the rig stands right without a pivot
-- (Lune has no PivotTo). Nothing yields, connects or tweens.
local LobbyNpcConfig: any = if typeof(script) == "Instance"
	then require((script :: any).Parent:WaitForChild("LobbyNpcConfig", 10))
	else require("./LobbyNpcConfig")

local LobbyNpcRig = {}

LobbyNpcRig.BaseHeight = 0.4
LobbyNpcRig.JointNames = { "RootJoint", "Neck", "Left Shoulder", "Right Shoulder", "Left Hip", "Right Hip" }
LobbyNpcRig.BaseName = "NpcBase"
LobbyNpcRig.RimName = "NpcBaseRim"

local EGGMAN = {
	Red = { 200, 28, 32 },
	RedDark = { 150, 18, 22 },
	Skin = { 255, 206, 168 },
	Nose = { 250, 168, 140 },
	Mustache = { 222, 116, 38 },
	Black = { 30, 30, 34 },
	Pants = { 40, 40, 46 },
	Grey = { 150, 156, 168 },
	Gold = { 255, 200, 40 },
	White = { 250, 250, 250 },
	Lens = { 70, 170, 255 },
	Glass = { 175, 225, 255 },
	Base = { 46, 52, 66 },
	Rim = { 255, 200, 40 },
}
LobbyNpcRig.EggmanColors = EGGMAN

local FLASH = {
	Suit = { 196, 24, 30 },
	SuitDark = { 150, 14, 20 },
	Gold = { 255, 205, 40 },
	White = { 250, 250, 250 },
	Skin = { 234, 184, 146 },
	Base = { 40, 44, 58 },
	Rim = { 255, 205, 40 },
}
LobbyNpcRig.FlashColors = FLASH

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local Builder = {}
Builder.__index = Builder

local function newBuilder(env: any, model: any, floor: any)
	return setmetatable({ env = env, model = model, floor = floor, parts = 0 }, Builder)
end

function Builder:rgb(values: { number }): any
	return self.env.Color3.fromRGB(values[1], values[2], values[3])
end

-- A part at `localCf` (model space: feet at y 0 above the base, forward -Z).
function Builder:part(name: string, parent: any, size: any, localCf: any, color: { number }, options: any?): any
	local env = self.env
	local o = options or {}
	local part = env.Instance.new("Part")
	part.Name = name
	if o.shape then
		part.Shape = env.Enum.PartType[o.shape]
	end
	part.Size = size
	part.CFrame = self.floor * localCf
	part.Color = self:rgb(color)
	part.Material = env.Enum.Material[o.material or "SmoothPlastic"]
	part.TopSurface = env.Enum.SurfaceType.Smooth
	part.BottomSurface = env.Enum.SurfaceType.Smooth
	part.Transparency = o.transparency or 0
	if o.reflectance then
		part.Reflectance = o.reflectance
	end
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = o.shadow ~= false
	if o.sphere then
		local mesh = env.Instance.new("SpecialMesh")
		mesh.MeshType = env.Enum.MeshType.Sphere
		mesh.Parent = part
	elseif o.head then
		local mesh = env.Instance.new("SpecialMesh")
		mesh.MeshType = env.Enum.MeshType.Head
		mesh.Scale = env.Vector3.new(1.25, 1.25, 1.25)
		mesh.Parent = part
	end
	part.Parent = parent
	self.parts += 1
	return part
end

-- A decoration welded to `bone` where it stands now.
function Builder:decor(name: string, bone: any, size: any, localCf: any, color: { number }, options: any?): any
	local part = self:part(name, self.model, size, localCf, color, options)
	local weld = self.env.Instance.new("Weld")
	weld.Name = "NpcWeld"
	weld.Part0 = bone
	weld.Part1 = part
	weld.C0 = bone.CFrame:Inverse() * part.CFrame
	weld.C1 = self.env.CFrame.new()
	weld.Parent = part
	return part
end

-- A Motor6D turning `part1` about `pivot` (model space, axes of the model): C0 / C1 carry no
-- rotation of their own, so a Transform is a rotation in the parent's (the model's) axes.
function Builder:motor(name: string, part0: any, part1: any, pivot: any): any
	local CFrame = self.env.CFrame
	local world = self.floor * CFrame.new(pivot.X, pivot.Y, pivot.Z)
	local motor = self.env.Instance.new("Motor6D")
	motor.Name = name
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = part0.CFrame:Inverse() * world
	motor.C1 = part1.CFrame:Inverse() * world
	motor.Parent = part0
	return motor
end

-- A cylinder standing up (Roblox cylinders run along X).
function Builder:upright(x: number, y: number, z: number): any
	local CFrame = self.env.CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.pi / 2)
end

-- A cylinder whose axis points along the unit direction (dx, dy, dz).
function Builder:along(x: number, y: number, z: number, dx: number, dy: number, dz: number): any
	local CFrame = self.env.CFrame
	local pitch = math.asin(math.clamp(dy, -1, 1))
	local yaw = math.atan2(-dz, dx)
	return CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, pitch)
end

-- The point on a sphere (centre c, radius r) at `azimuth` degrees right of forward (-Z) and
-- `elevation` degrees up, and that direction.
local function onSphere(c: { number }, r: number, azimuth: number, elevation: number): (number, number, number, number, number, number)
	local az, el = math.rad(azimuth), math.rad(elevation)
	local dx, dy, dz = math.sin(az) * math.cos(el), math.sin(el), -math.cos(az) * math.cos(el)
	return c[1] + dx * r, c[2] + dy * r, c[3] + dz * r, dx, dy, dz
end

-- The front of an ellipsoid (centre c, semi-axes a) at height y: its most forward z, or nil.
local function frontZ(c: { number }, a: { number }, y: number): number?
	local t = (y - c[2]) / a[2]
	if math.abs(t) >= 1 then
		return nil
	end
	return c[3] - a[3] * math.sqrt(1 - t * t)
end

----------------------------------------------------------------------
-- The disc under their feet
----------------------------------------------------------------------
function LobbyNpcRig.AddBase(env: any, model: any, floor: any, colors: any): (any, any)
	local b = newBuilder(env, model, floor)
	local h = LobbyNpcRig.BaseHeight
	local base = b:part(LobbyNpcRig.BaseName, model, env.Vector3.new(h, 5.6, 5.6), b:upright(0, h / 2, 0), colors.Base, { shape = "Cylinder", material = "Metal", shadow = false })
	base.Anchored = true
	base.CanCollide = true
	base.CanQuery = true
	local rim = b:part(LobbyNpcRig.RimName, model, env.Vector3.new(0.12, 5.9, 5.9), b:upright(0, 0.06, 0), colors.Rim, { shape = "Cylinder", material = "Neon", shadow = false })
	rim.Anchored = true
	return base, rim
end

----------------------------------------------------------------------
-- Dr. Eggman
----------------------------------------------------------------------
-- Model space: feet on the base's top (y = BaseHeight), forward -Z. Semi-axes of the two
-- body ellipsoids (their parts' sizes halved), shared by the buttons' placement.
local BELLY_C, BELLY_A = { 0, 3.4, 0 }, { 2.3, 1.8, 2.1 }
local CHEST_C, CHEST_A = { 0, 4.55, 0.05 }, { 1.9, 1.45, 1.7 }
local HEAD_C, HEAD_R = { 0, 6.4, -0.1 }, 1.05

function LobbyNpcRig.BuildEggman(env: any, floor: any): any
	local Vector3, CFrame = env.Vector3, env.CFrame
	local model = env.Instance.new("Model")
	model.Name = "DrEggman"
	local b = newBuilder(env, model, floor)
	local lift = LobbyNpcRig.BaseHeight
	local function at(x: number, y: number, z: number): any
		return CFrame.new(x, y + lift, z)
	end
	local function v(x: number, y: number, z: number): any
		return Vector3.new(x, y + lift, z)
	end

	-- Bones.
	local root = b:part("HumanoidRootPart", model, Vector3.new(2, 2, 1), at(0, 3.6, 0), EGGMAN.Red, { transparency = 1, shadow = false })
	root.Anchored = true
	local torso = b:part("Torso", model, Vector3.new(BELLY_A[1] * 2, BELLY_A[2] * 2, BELLY_A[3] * 2), at(BELLY_C[1], BELLY_C[2], BELLY_C[3]), EGGMAN.Red, { sphere = true })
	local head = b:part("Head", model, Vector3.new(HEAD_R * 2, HEAD_R * 2, HEAD_R * 2), at(HEAD_C[1], HEAD_C[2], HEAD_C[3]), EGGMAN.Skin, { shape = "Ball" })
	local arms, legs = {}, {}
	for _, side in { -1, 1 } do
		local name = if side < 0 then "Left" else "Right"
		arms[side] = b:part(name .. " Arm", model, Vector3.new(0.9, 2.1, 0.9), at(side * 1.95, 4.1, 0), EGGMAN.Red)
		legs[side] = b:part(name .. " Leg", model, Vector3.new(0.8, 1.75, 0.8), at(side * 0.8, 1.05, 0), EGGMAN.Pants)
	end

	-- Joints (pivots in model space).
	b:motor("RootJoint", root, torso, v(0, 2.0, 0))
	b:motor("Neck", torso, head, v(0, 5.6, -0.1))
	for _, side in { -1, 1 } do
		local name = if side < 0 then "Left" else "Right"
		b:motor(name .. " Shoulder", torso, arms[side], v(side * 1.95, 5.05, 0))
		b:motor(name .. " Hip", torso, legs[side], v(side * 0.8, 1.9, 0))
	end

	-- The jacket: a narrower chest over the belly makes the egg; a dark collar under the head;
	-- three gold buttons down the front.
	b:decor("Chest", torso, Vector3.new(CHEST_A[1] * 2, CHEST_A[2] * 2, CHEST_A[3] * 2), at(CHEST_C[1], CHEST_C[2], CHEST_C[3]), EGGMAN.Red, { sphere = true })
	b:decor("Collar", torso, Vector3.new(2.3, 0.5, 2.1), at(0, 5.8, -0.05), EGGMAN.RedDark, { sphere = true })
	for index, y in { 5.3, 4.5, 3.7 } do
		local z = math.min(frontZ(CHEST_C, CHEST_A, y) or 0, frontZ(BELLY_C, BELLY_A, y) or 0)
		b:decor("Button" .. index, torso, Vector3.new(0.34, 0.34, 0.34), at(0, y, z - 0.02), EGGMAN.Gold, { shape = "Ball", material = "Metal", reflectance = 0.15 })
	end

	-- The head: nose, the huge mustache (two halves swept back and up at the tips), ears,
	-- the goggles on their strap across the forehead, the small pince-nez.
	b:decor("Nose", head, Vector3.new(0.64, 0.64, 0.64), at(0, 6.3, -1.18), EGGMAN.Nose, { shape = "Ball" })
	for _, side in { -1, 1 } do
		local name = if side < 0 then "Left" else "Right"
		local stache = at(side * 1.02, 5.98, -0.98) * CFrame.Angles(0, -side * math.rad(22), 0) * CFrame.Angles(0, 0, side * math.rad(16))
		b:decor(name .. "Mustache", head, Vector3.new(2.15, 0.62, 0.85), stache, EGGMAN.Mustache, { sphere = true })
		b:decor(name .. "Ear", head, Vector3.new(0.5, 0.5, 0.5), at(side * 1.02, 6.35, -0.05), EGGMAN.Skin, { shape = "Ball" })
		-- Goggles: a black rim and a blue lens, facing out of the forehead.
		local x, y, z, dx, dy, dz = onSphere(HEAD_C, HEAD_R + 0.1, side * 26, 34)
		b:decor(name .. "GoggleRim", head, Vector3.new(0.22, 0.98, 0.98), b:along(x, y + lift, z, dx, dy, dz), EGGMAN.Black, { shape = "Cylinder" })
		x, y, z = onSphere(HEAD_C, HEAD_R + 0.22, side * 26, 34)
		b:decor(name .. "GoggleLens", head, Vector3.new(0.1, 0.76, 0.76), b:along(x, y + lift, z, dx, dy, dz), EGGMAN.Lens, { shape = "Cylinder", reflectance = 0.25 })
		-- Pince-nez in front of the eyes.
		x, y, z, dx, dy, dz = onSphere(HEAD_C, HEAD_R + 0.04, side * 22, 9)
		b:decor(name .. "Glass", head, Vector3.new(0.08, 0.44, 0.44), b:along(x, y + lift, z, dx, dy, dz), EGGMAN.Glass, { shape = "Cylinder", reflectance = 0.2 })
	end
	b:decor("GoggleStrap", head, Vector3.new(2.02, 0.28, 2.02), at(0, 6.98, -0.1), EGGMAN.Black, { sphere = true })

	-- Round shoulders (they turn with the arm); sleeves end in white cuffs and gloves; black
	-- boots with a grey band.
	for _, side in { -1, 1 } do
		local name = if side < 0 then "Left" else "Right"
		b:decor(name .. "ShoulderBall", arms[side], Vector3.new(1.08, 1.08, 1.08), at(side * 1.95, 4.98, 0), EGGMAN.Red, { shape = "Ball" })
		b:decor(name .. "Cuff", arms[side], Vector3.new(0.32, 1.06, 1.06), b:upright(side * 1.95, 3.2 + lift, 0), EGGMAN.White, { shape = "Cylinder" })
		b:decor(name .. "Glove", arms[side], Vector3.new(1.0, 1.0, 1.0), at(side * 1.95, 2.86, 0), EGGMAN.White, { shape = "Ball" })
		b:decor(name .. "Boot", legs[side], Vector3.new(1.08, 0.78, 1.55), at(side * 0.8, 0.36, -0.2), EGGMAN.Black, { sphere = true })
		b:decor(name .. "BootBand", legs[side], Vector3.new(0.24, 0.96, 0.96), b:upright(side * 0.8, 0.82 + lift, 0), EGGMAN.Grey, { shape = "Cylinder", material = "Metal" })
	end

	local base = LobbyNpcRig.AddBase(env, model, floor, EGGMAN)
	model.PrimaryPart = root
	model:SetAttribute("NpcParts", b.parts + 2)
	LobbyNpcRig.Configure(model, root, base)
	return model
end

----------------------------------------------------------------------
-- A classic R6 body (Flash's fallback)
----------------------------------------------------------------------
-- The R6 joint frames every avatar has, so poses are the same on this body and on one the
-- avatar service builds (Players:CreateHumanoidModelFromDescription).
local R6_JOINTS = {
	{ "RootJoint", "HumanoidRootPart", "Torso", { 0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0 }, { 0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0 } },
	{ "Neck", "Torso", "Head", { 0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0 }, { 0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0 } },
	{ "Right Shoulder", "Torso", "Right Arm", { 1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0 }, { -0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0 } },
	{ "Left Shoulder", "Torso", "Left Arm", { -1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0 }, { 0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0 } },
	{ "Right Hip", "Torso", "Right Leg", { 1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0 }, { 0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0 } },
	{ "Left Hip", "Torso", "Left Leg", { -1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0 }, { -0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0 } },
}
LobbyNpcRig.R6Joints = R6_JOINTS
-- The R6 root's height above the feet.
LobbyNpcRig.R6RootHeight = 3

function LobbyNpcRig.BuildR6(env: any, floor: any, name: string?): any
	local Vector3, CFrame = env.Vector3, env.CFrame
	local model = env.Instance.new("Model")
	model.Name = name or "TheFlash"
	local b = newBuilder(env, model, floor)
	local lift = LobbyNpcRig.BaseHeight
	local function at(x: number, y: number, z: number): any
		return CFrame.new(x, y + lift, z)
	end
	local parts = {}
	parts.HumanoidRootPart = b:part("HumanoidRootPart", model, Vector3.new(2, 2, 1), at(0, 3, 0), FLASH.Suit, { transparency = 1, shadow = false })
	parts.HumanoidRootPart.Anchored = true
	parts.Torso = b:part("Torso", model, Vector3.new(2, 2, 1), at(0, 3, 0), FLASH.Suit)
	parts.Head = b:part("Head", model, Vector3.new(2, 1, 1), at(0, 4.5, 0), FLASH.Suit, { head = true })
	parts["Right Arm"] = b:part("Right Arm", model, Vector3.new(1, 2, 1), at(1.5, 3, 0), FLASH.Suit)
	parts["Left Arm"] = b:part("Left Arm", model, Vector3.new(1, 2, 1), at(-1.5, 3, 0), FLASH.Suit)
	parts["Right Leg"] = b:part("Right Leg", model, Vector3.new(1, 2, 1), at(0.5, 1, 0), FLASH.SuitDark)
	parts["Left Leg"] = b:part("Left Leg", model, Vector3.new(1, 2, 1), at(-0.5, 1, 0), FLASH.SuitDark)
	for _, joint in R6_JOINTS do
		local motor = env.Instance.new("Motor6D")
		motor.Name = joint[1]
		motor.Part0 = parts[joint[2]]
		motor.Part1 = parts[joint[3]]
		motor.C0 = CFrame.new(table.unpack(joint[4]))
		motor.C1 = CFrame.new(table.unpack(joint[5]))
		motor.Parent = parts[joint[2]]
	end
	local humanoid = env.Instance.new("Humanoid")
	humanoid.RigType = env.Enum.HumanoidRigType.R6
	humanoid.Parent = model
	-- The R6 head's attachments, so Humanoid:AddAccessory can put the suit's mask on.
	for _, point in { { "HatAttachment", 0, 0.6, 0 }, { "HairAttachment", 0, 0.6, 0 }, { "FaceFrontAttachment", 0, 0, -0.6 }, { "FaceCenterAttachment", 0, 0, 0 } } do
		local attachment = env.Instance.new("Attachment")
		attachment.Name = point[1]
		attachment.CFrame = CFrame.new(point[2], point[3], point[4])
		attachment.Parent = parts.Head
	end

	-- The suit's marks, as parts (hidden by the server once real clothing is on).
	local torso, head = parts.Torso, parts.Head
	local marks = env.Instance.new("Folder")
	marks.Name = "FallbackSuit"
	marks.Parent = model
	local function mark(markName: string, bone: any, size: any, cf: any, color: { number }, options: any?)
		local part = b:decor(markName, bone, size, cf, color, options)
		part.Parent = marks
		return part
	end
	mark("Emblem", torso, Vector3.new(0.06, 1.0, 1.0), CFrame.new(0, 3.45 + lift, -0.52) * CFrame.Angles(0, math.pi / 2, 0), FLASH.White, { shape = "Cylinder" })
	mark("Bolt", torso, Vector3.new(0.14, 0.9, 0.06), CFrame.new(0, 3.45 + lift, -0.56) * CFrame.Angles(0, 0, math.rad(-28)), FLASH.Gold, { material = "Neon" })
	mark("Belt", torso, Vector3.new(2.04, 0.22, 1.04), at(0, 2.12, 0), FLASH.Gold, { material = "Neon" })
	for _, side in { -1, 1 } do
		mark(if side < 0 then "LeftWing" else "RightWing", head, Vector3.new(0.1, 0.22, 0.7), CFrame.new(side * 0.66, 4.65 + lift, 0.05) * CFrame.Angles(math.rad(-20), 0, 0), FLASH.Gold, { material = "Neon" })
	end

	local base = LobbyNpcRig.AddBase(env, model, floor, FLASH)
	model.PrimaryPart = parts.HumanoidRootPart
	LobbyNpcRig.Configure(model, parts.HumanoidRootPart, base)
	return model
end

----------------------------------------------------------------------
-- The owner's models
----------------------------------------------------------------------
-- The part an NPC is held by: HumanoidRootPart, else the PrimaryPart.
function LobbyNpcRig.FindRoot(model: any): any?
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	local primary = model.PrimaryPart
	return if primary and primary:IsA("BasePart") then primary else nil
end

-- (kind, root) when `model` is one of the owner's NPCs: a Model named as LobbyNpcConfig.OwnerNames
-- says, with a Humanoid or an AnimationController, or one he tagged (`taggedKind`); and a root
-- part. Player characters and our own folder are the caller's to rule out (Players service).
function LobbyNpcRig.OwnerKind(model: any, taggedKind: string?): (string?, any?)
	if typeof(model) ~= "Instance" or not model:IsA("Model") then
		return nil, nil
	end
	local kind = taggedKind or LobbyNpcConfig.KindForName(model.Name)
	if kind == nil then
		return nil, nil
	end
	if taggedKind == nil and not (model:FindFirstChildOfClass("Humanoid") or model:FindFirstChildOfClass("AnimationController")) then
		return nil, nil
	end
	local root = LobbyNpcRig.FindRoot(model)
	if not root then
		return nil, nil
	end
	return kind, root
end

-- The parts joined to `root` (Motor6D, Weld and the other joints, WeldConstraint), root included.
function LobbyNpcRig.JoinedParts(model: any, root: any): { [any]: boolean }
	local links: { [any]: { any } } = {}
	local function link(a: any, b: any)
		if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
			links[a] = links[a] or {}
			links[b] = links[b] or {}
			table.insert(links[a], b)
			table.insert(links[b], a)
		end
	end
	for _, item in model:GetDescendants() do
		if item:IsA("JointInstance") or item:IsA("WeldConstraint") then
			link(item.Part0, item.Part1)
		end
	end
	local joined = { [root] = true }
	local queue = { root }
	while #queue > 0 do
		local part = table.remove(queue)
		for _, other in links[part] or {} do
			if not joined[other] then
				joined[other] = true
				table.insert(queue, other)
			end
		end
	end
	return joined
end

-- Readies an owner's model where he left it (position and rotation untouched): the root anchored
-- (it cannot fall), the body joined to it unanchored so its joints can move, and out of the way
-- (no collide / touch / query: clicks, the camera and raycasts pass through); loose parts (a
-- pedestal, a prop) stay as authored, anchored if they were not. Scripts inside are switched off
-- and Animators removed, so nothing plays animations against the procedural idle; the Humanoid
-- shows no name or health bar and runs no states. Returns { Joined, Loose, Scripts }.
function LobbyNpcRig.PrepareOwnerModel(env: any, model: any, root: any): { Joined: number, Loose: number, Scripts: number }
	local report = { Joined = 0, Loose = 0, Scripts = 0 }
	for _, item in model:GetDescendants() do
		if item:IsA("LuaSourceContainer") and not item:IsA("ModuleScript") then
			local off = pcall(function()
				item.Enabled = false
			end)
			if not off then
				pcall(function()
					item.Disabled = true
				end)
			end
			report.Scripts += 1
		elseif item:IsA("Animator") then
			item:Destroy()
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local Enum = env.Enum
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.BreakJointsOnDeath = false
		humanoid.RequiresNeck = false
		pcall(function()
			humanoid.EvaluateStateMachine = false
		end)
	end
	local joined = LobbyNpcRig.JoinedParts(model, root)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			if joined[part] then
				part.Anchored = part == root
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = false
				report.Joined += 1
			else
				part.Anchored = true
				report.Loose += 1
			end
		end
	end
	return report
end

-- The pose joints found on `model` (LobbyNpcConfig.JointMap: the R6 name, else R15's), each with
-- its Motor6D; the rig they read as ("R6", "R15" or "Custom"); and whether the four limbs are
-- there (without them the client skips the idle, with one warning).
function LobbyNpcRig.FindJoints(model: any): ({ { name: string, motor: any } }, string, boolean)
	local joints = {}
	local found: { [string]: boolean } = {}
	local rig = "Custom"
	for _, pose in LobbyNpcRig.JointNames do
		for index, candidate in LobbyNpcConfig.JointMap[pose] do
			local motor = model:FindFirstChild(candidate, true)
			if motor and motor:IsA("Motor6D") and motor.Part0 and motor.Part1 then
				table.insert(joints, { name = pose, motor = motor })
				found[pose] = true
				if pose == "Left Shoulder" then
					rig = if index == 1 then "R6" else "R15"
				end
				break
			end
		end
	end
	local complete = true
	for _, pose in LobbyNpcConfig.RequiredJoints do
		complete = complete and found[pose] == true
	end
	return joints, rig, complete
end

-- The NPC's ProximityPrompt, on an attachment in its root `offset` above the root's centre
-- (English: each client puts its own language on its copy). E / ButtonX / a tap, no hold, no
-- line of sight (the NPC's own body or a booth counter must not hide it).
function LobbyNpcRig.AddPrompt(env: any, root: any, offset: any, maxDistance: number, actionText: string, objectText: string): any
	local old = root:FindFirstChild("PromptAttachment")
	if old then
		old:Destroy()
	end
	local attachment = env.Instance.new("Attachment")
	attachment.Name = "PromptAttachment"
	attachment.Position = offset
	attachment.Parent = root
	local prompt = env.Instance.new("ProximityPrompt")
	prompt.Name = "NpcPrompt"
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = env.Enum.KeyCode.E
	prompt.GamepadKeyCode = env.Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = maxDistance
	prompt.RequiresLineOfSight = false
	prompt.AutoLocalize = false
	prompt.Parent = attachment
	return prompt
end

----------------------------------------------------------------------
-- Physics and queries
----------------------------------------------------------------------
-- Only the root (anchored, invisible) and the base (anchored, colliding) hold the NPC in
-- place; every other part moves with the joints, never collides, touches or blocks a ray, so
-- clicks, the camera and the tutorial's raycasts pass through the NPC.
function LobbyNpcRig.Configure(model: any, root: any, base: any?)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local isBase = part == base or part.Name == LobbyNpcRig.RimName
			part.CanTouch = false
			if part == base then
				part.Anchored = true
				part.CanCollide = true
				part.CanQuery = true
			else
				part.CanCollide = false
				part.CanQuery = false
				part.Anchored = part == root or isBase
			end
		end
	end
	root.Anchored = true
end

return LobbyNpcRig
