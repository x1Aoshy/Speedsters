-- Race/RacePoseClient.client.luau — Update 4 race feel (race_fx, 2026-09-25).
-- Every client draws every racer (the players whose RaceActive attribute is on and whose
-- RaceState is Staged or Racing): Flash's crouch at the line and the launch out of it
-- (Shared.RacePose), and the charge's arcs, the GO burst, the after-images and the rings
-- (Shared.RaceVfx; see 2026-09-26 below). Nothing crosses the network per frame: other
-- racers are drawn from their replicated attributes (RaceChargeLevel at <= 4 Hz,
-- RaceStartGrade, RaceSuperSpeed) and their root's velocity; the local racer from the local
-- attributes Race/RaceInputClient writes (RaceChargeLocal, RaceChargeHeld, RacePredictedGrade,
-- RaceLocalSuper).
--
-- The pose is set on the R6 joints' Transform on Stepped, after the Animator (as
-- Movement/SupermanFlight), blended in over Pose.BlendIn. 2026-09-25 (owner): never a walk in a
-- race: the Animator's own fast run shows while racing (R15SpeedsterRun forces it), so the only
-- procedural poses are the Set crouch and the Pose.Launch crossfade out of it at GO; then the
-- weight blends out over LAUNCH_BLEND_OUT and the joints are the Animator's (no stride, no
-- super dash). While a racer is tracked its character carries the local attribute RacePosed,
-- so SupermanFlight and SurfboardPose stand aside for the whole race.
-- Phones are ~63% of the players at ~24 FPS: the tier (Shared.RaceFeelTier) is picked once per
-- race when the crouch starts, other racers are posed at full rate only near the camera, at a
-- reduced rate further out and not at all beyond, and the two per-frame connections (Stepped
-- for poses, RenderStepped for the VFX) exist only while someone is racing.
-- The local racer's camera: RaceFovTarget (read by SpeedsterClient's FOV loop) narrows while
-- the charge fills, widens at super speed and is cleared after the race; GO and super speed
-- punch the FOV (CameraPunch). GuiService.ReducedMotionEnabled: no shake, half punches, no
-- flashes.
-- 2026-09-26 (owner): no bubble and no particles any more (Shared/RaceVfx): electric arcs over
-- the body while the start is held; at GO the Sonic Boom: shock rings on the ground, a burst of
-- after-images, and on the local screen RaceVfx.LaunchPunch's CameraPunch.Fov / Shake (Perfect
-- 18 / 0.3 s x 1.5, less for Good and Ok, nothing on a Stall) with Shared/RaceScreenFx's shock
-- ring. While running: after-images in the equipped aura's colours past the racer's own cruise
-- (RaceCruiseSpeed), speed lines, a vignette and an FOV that follow the speed over that cruise;
-- rings at speed pads and at the finish line. Trails and auras are left exactly as they are.
-- Kill switches (live): Workspace U4Off_RaceFx, U4Off_RaceGhosts, U4Off_RaceScreen.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared", 30)
if not Shared then
	warn("[RacePoseClient] ReplicatedStorage.Shared is missing; race poses are off")
	return
end

local function load(name: string): any
	local module = Shared:WaitForChild(name, 30)
	if not module then
		warn("[RacePoseClient] Shared." .. name .. " is missing; race poses are off")
		return nil
	end
	local ok, result = pcall(require, module)
	if not ok then
		warn("[RacePoseClient] Shared." .. name .. " failed to load: " .. tostring(result))
		return nil
	end
	return result
end

local U4 = load("Update4Config")
local RacePose = load("RacePose")
local RaceFeelTier = load("RaceFeelTier")
local RaceVfx = load("RaceVfx")
local SurfboardStance = load("SurfboardStance")
local CameraPunch = load("CameraPunch")
local RaceScreenFx = load("RaceScreenFx")
local RaceTrack = load("RaceTrack")
if not (U4 and RacePose and RaceFeelTier and RaceVfx and SurfboardStance and CameraPunch and RaceScreenFx and RaceTrack) then
	return
end
-- Optional: the after-images' aura colours (without it, the race's own colours).
local CosmeticCatalog = load("CosmeticCatalog")

local POSE = U4.Race.Feel.Pose
local CAMERA = U4.Race.Feel.Camera
local SCREEN = U4.Race.Feel.Screen
local SUPER = U4.Race.Super
local QUEUE = U4.Race.Queue
local CHARGE = U4.Race.Charge

local BASE_FOV = 70
local SUPER_ENTER_SECONDS = 0.35
local SUPER_EXIT_SECONDS = 0.25
local REMOTE_GRADE_WAIT = 0.6 -- seconds after GO before another racer's burst goes without a grade
-- RaceInputClient writes RacePredictedGrade on its Heartbeat of the GO frame, after this
-- script's Stepped: the local burst waits this long for it before the charge watch's guess.
local LOCAL_GRADE_WAIT = 0.12
local LAUNCH_BLEND_OUT = 0.15 -- seconds: the launch pose hands the body to the native run
local RELEASE_AFTER = 1 -- VFX are destroyed this long after the pose has blended out
local LOD_SECONDS = 0.25
local DEFAULT_SPRINT = U4.Race.Speed.BaseCruise * U4.Race.Speed.SprintMultiplier
local AWAY_STATES = {
	[Enum.HumanoidStateType.Seated] = true,
	[Enum.HumanoidStateType.Dead] = true,
	[Enum.HumanoidStateType.Ragdoll] = true,
	[Enum.HumanoidStateType.FallingDown] = true,
	[Enum.HumanoidStateType.PlatformStanding] = true,
}
-- The player attributes this script keeps a copy of (one AttributeChanged per player).
local CACHED = {
	RaceActive = "Active",
	RaceState = "State",
	RaceChargeLevel = "Level",
	RaceStartGrade = "GradeAttr",
	RaceSuperSpeed = "SuperRaw",
	RaceSprintSpeed = "SprintSpeed",
	RaceCruiseSpeed = "CruiseSpeed",
	EquippedAuraId = "Aura",
	EquippedTrailId = "Trail",
}

local racers = {} -- [Player] = racer
local caches = {} -- [Player] = the cached attributes
local connections = {} -- [Player] = { RBXScriptConnection }
local stepped: RBXScriptConnection? = nil
local rendered: RBXScriptConnection? = nil
local meter = RaceFeelTier.NewMeter()
local raceTier, raceQuality, tierRaceId = nil, nil, nil
local nextLodAt = 0
local fovTarget: number? = nil

local world = {
	Phase = Workspace:GetAttribute("RacePhase"),
	GoAt = Workspace:GetAttribute("RaceGoAt"),
	RaceId = Workspace:GetAttribute("RaceId"),
}
for attribute, key in { RacePhase = "Phase", RaceGoAt = "GoAt", RaceId = "RaceId" } do
	Workspace:GetAttributeChangedSignal(attribute):Connect(function()
		world[key] = Workspace:GetAttribute(attribute)
	end)
end

RaceVfx.SoundsOn = function()
	return player:GetAttribute("SoundEffects") ~= false
end

-- 2026-09-26 (owner): the race VFX kill switches, live (Workspace U4Off_<Feature>).
local function applyKillSwitches()
	local all = U4.IsOn("RaceFx")
	RaceVfx.SetEnabled({ All = all, Ghosts = all and U4.IsOn("RaceGhosts") })
	RaceScreenFx.SetEnabled(all and U4.IsOn("RaceScreen"))
end
for _, feature in { "RaceFx", "RaceGhosts", "RaceScreen" } do
	Workspace:GetAttributeChangedSignal(U4.KillAttributePrefix .. feature):Connect(applyKillSwitches)
end
applyKillSwitches()

local function reducedMotion(): boolean
	local ok, on = pcall(function()
		return GuiService.ReducedMotionEnabled
	end)
	return ok and on == true
end

local function setFov(value: number?)
	if value ~= nil then
		value = math.floor(value * 10 + 0.5) / 10 -- fewer attribute writes while the gauge moves
	end
	if fovTarget ~= value then
		fovTarget = value
		player:SetAttribute("RaceFovTarget", value)
	end
end

local function tier(): (string, number?)
	local raceId = world.RaceId
	if raceTier == nil or tierRaceId ~= raceId then
		raceTier, raceQuality = RaceFeelTier.Detect(meter)
		tierRaceId = raceId
		local reduced = reducedMotion()
		RaceVfx.SetReducedMotion(reduced)
		RaceScreenFx.SetReducedMotion(reduced)
		applyKillSwitches()
	end
	return raceTier, raceQuality
end

-- A racer's own cruise (studs/s): the server's RaceCruiseSpeed, else their sprint / x1.4.
local function cruiseOf(target: Player): number
	local cache = caches[target] or {}
	local cruise = tonumber(cache.CruiseSpeed)
	if cruise and cruise == cruise and cruise > 0 then
		return cruise
	end
	local sprint = tonumber(cache.SprintSpeed)
	if sprint and sprint == sprint and sprint > 0 then
		return sprint / U4.Race.Speed.SprintMultiplier
	end
	return U4.Race.Speed.BaseCruise
end

-- The super-speed arcs' colours: the equipped aura's (else the trail's, else the race's own).
-- 2026-09-26 (owner): the after-images take none of them (RaceVfx.GhostColor, the sprint's dark shadow).
local function tintOf(target: Player): (Color3?, Color3?, boolean)
	if not CosmeticCatalog then
		return nil, nil, false
	end
	local cache = caches[target] or {}
	local ok, c1, c2, isAura = pcall(function()
		local aura = CosmeticCatalog.GetEntry("Aura", tostring(cache.Aura or target:GetAttribute("EquippedAura") or ""))
		local trail = CosmeticCatalog.GetEntry("Trail", tostring(cache.Trail or target:GetAttribute("EquippedTrail") or ""))
		return RaceVfx.AuraColors(aura, trail)
	end)
	if not ok then
		return nil, nil, false
	end
	return c1, c2, isAura == true
end

-- The run's FOV: 70 at the own cruise, Camera.SuperFov at the super-speed ratio, in whole
-- degrees (nil = the base FOV).
local function runFov(ratio: number): number?
	local superRatio = SUPER.EnterFraction * U4.Race.Speed.SprintMultiplier
	local t = math.clamp((ratio - 1) / math.max(0.05, superRatio - 1), 0, 1)
	t = t * t * (3 - 2 * t)
	local step = CAMERA.RunFovStep or 1
	local fov = math.floor((BASE_FOV + (CAMERA.SuperFov - BASE_FOV) * t) / step + 0.5) * step
	return if fov <= BASE_FOV then nil else fov
end

local function localRatio(racer): number
	local speed = tonumber(player:GetAttribute("RaceLocalSpeed")) or 0
	if speed ~= speed then
		speed = 0
	end
	return speed / math.max(1, cruiseOf(racer.Player))
end

----------------------------------------------------------------------
-- Tracking
----------------------------------------------------------------------
local function wanted(target: Player): boolean
	local cache = caches[target]
	return cache ~= nil and cache.Active == true and (cache.State == "Staged" or cache.State == "Racing")
end

-- The same Transform (the Animator has not written this joint since this script did).
local function same(a: CFrame, b: CFrame): boolean
	return (a.Position - b.Position).Magnitude < 1e-3 and a.LookVector:Dot(b.LookVector) > 0.99999 and a.UpVector:Dot(b.UpVector) > 0.99999
end

-- Hands the joints back. 2026-09-25: only a joint still holding this script's last write goes
-- to rest; the ones the Animator's run already rewrote are left alone (an identity there would
-- flash the rest pose for a frame in the middle of the race).
local function resetJoints(racer)
	for _, joint in racer.Joints do
		local motor = joint.Motor
		if motor.Parent and joint.Written ~= nil and same(motor.Transform, joint.Written) then
			motor.Transform = CFrame.identity
		end
		joint.Written = nil
	end
end

local function setPosed(character: Model, on: boolean)
	if character.Parent then
		character:SetAttribute("RacePosed", if on then true else nil)
	end
end

-- Drops a racer: joints back to rest, RacePosed off, VFX destroyed a moment later (the last
-- bubble and ring finish first). `gone`: the character is already on its way out.
local function finish(target: Player, gone: boolean?)
	local racer = racers[target]
	if not racer then
		return
	end
	racers[target] = nil
	local character = racer.Character
	-- Both are guarded (motor/character still parented), so a racer whose root streamed out
	-- does not keep RacePosed and leave SupermanFlight/SurfboardPose standing aside for good.
	resetJoints(racer)
	setPosed(character, false)
	-- Dropped before GO (a cancelled countdown): the charge lets go, the bubble fades out.
	RaceVfx.SetCharge(character, 0, nil, false)
	RaceVfx.SetSuper(character, false)
	if racer.IsLocal then
		setFov(nil)
		RaceScreenFx.Show(false)
	end
	if gone then
		RaceVfx.Release(character)
	else
		task.delay(RELEASE_AFTER, function()
			local again = racers[target]
			if not (again and again.Character == character) then
				RaceVfx.Release(character)
			end
		end)
	end
end

local ensureLoops -- forward

local function track(target: Player)
	if racers[target] then
		return
	end
	local character = target.Character
	if not (character and character:IsDescendantOf(Workspace)) then
		return -- streamed out or on its way out: the LOD pass tries again
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local torso = character:FindFirstChild("Torso")
	if not (root and root:IsA("BasePart") and torso) then
		return -- not R6 or not built yet: CharacterAdded tries again
	end
	local joints = {}
	for _, name in RacePose.Names do
		local part = character:FindFirstChild(RacePose.Joints[name])
		local motor = part and part:FindFirstChild(name)
		if motor and motor:IsA("Motor6D") then
			table.insert(joints, { Name = name, Motor = motor, C0 = motor.C0 })
		end
	end
	if #joints == 0 then
		return
	end
	-- Met already running (this client just arrived, or the racer streamed in): no launch.
	local cache = caches[target] or {}
	local startMode = RacePose.Mode(cache.Active, cache.State, world.Phase, Workspace:GetServerTimeNow(), tonumber(world.GoAt))
	startMode = if startMode == "Run" then "Run" else "Set"
	racers[target] = {
		Player = target,
		Character = character,
		Root = root,
		Humanoid = character:FindFirstChildOfClass("Humanoid"),
		IsLocal = target == player,
		Joints = joints,
		Seed = math.random() * 1000,
		Mode = startMode,
		PoseMode = startMode,
		Weight = 0,
		Phi = math.random() * math.pi * 2,
		LaunchAt = nil,
		LaunchG = 0,
		Grade = nil,
		BurstPending = false,
		Latch = RacePose.NewLatch(),
		Super = false,
		Prewarmed = false,
		Watch = RaceVfx.NewChargeWatch(),
		Pose = {},
		Transforms = {},
		HasTransforms = false,
		Rate = math.huge,
		NextPoseAt = 0,
		PoseDt = 0,
	}
	setPosed(character, true)
	ensureLoops()
end

local function refresh(target: Player)
	if wanted(target) then
		track(target)
	end
	-- Leaving is handled by the loop (it blends the pose out first).
end

local function watchPlayer(target: Player)
	if connections[target] then
		return
	end
	local cache = {}
	for attribute, key in CACHED do
		cache[key] = target:GetAttribute(attribute)
	end
	caches[target] = cache
	local list = {}
	connections[target] = list
	table.insert(list, target.AttributeChanged:Connect(function(attribute)
		local key = CACHED[attribute]
		if key then
			cache[key] = target:GetAttribute(attribute)
			if key == "Active" or key == "State" then
				refresh(target)
			end
		end
	end))
	table.insert(list, target.CharacterAdded:Connect(function(character)
		finish(target, true)
		-- The joints are built a moment after the character arrives.
		character:WaitForChild("HumanoidRootPart", 5)
		character:WaitForChild("Torso", 5)
		task.wait(0.2)
		if target.Parent and target.Character == character then
			refresh(target)
		end
	end))
	table.insert(list, target.CharacterRemoving:Connect(function()
		finish(target, true)
	end))
	refresh(target)
end

Players.PlayerAdded:Connect(watchPlayer)
for _, target in Players:GetPlayers() do
	task.spawn(watchPlayer, target)
end
Players.PlayerRemoving:Connect(function(target)
	finish(target, true)
	for _, connection in connections[target] or {} do
		connection:Disconnect()
	end
	connections[target] = nil
	caches[target] = nil
end)

-- 2026-09-25 (speed pads): the local racer's pad (Race/RaceInputClient predicts it and writes
-- RaceBoostAt): a short FOV kick and the pad's feel (RaceVfx.PadBoost: a ring on the ground,
-- a flash of arcs, a burst of after-images, the whoosh; RaceScreenFx: a smaller shock ring).
local PAD_PUNCH = CAMERA.PadPunch or 8
player:GetAttributeChangedSignal("RaceBoostAt"):Connect(function()
	local racer = racers[player]
	if not racer or type(player:GetAttribute("RaceBoostAt")) ~= "number" then
		return
	end
	CameraPunch.Fov(PAD_PUNCH * (if reducedMotion() then 0.5 else 1))
	RaceVfx.PadBoost(racer.Character, os.clock())
	RaceScreenFx.Shock(SCREEN.PadShock)
end)

----------------------------------------------------------------------
-- The pose loop
----------------------------------------------------------------------
local function standsAside(racer): boolean
	local humanoid = racer.Humanoid
	local character = racer.Character
	return not humanoid
		or humanoid.Health <= 0
		or humanoid.Sit
		or AWAY_STATES[humanoid:GetState()] == true
		or character:GetAttribute("Ragdolled") == true
		or character:GetAttribute("Dead") == true
end

local function horizontalSpeed(root: BasePart): number
	local velocity = root.AssemblyLinearVelocity
	return Vector3.new(velocity.X, 0, velocity.Z).Magnitude
end

local function localGauge(): number
	local g = tonumber(player:GetAttribute("RaceChargeLocal")) or 0
	return if g == g then math.clamp(g, 0, 1) else 0
end

local function gaugeOf(racer): number
	if racer.IsLocal then
		return localGauge()
	end
	local level = tonumber(caches[racer.Player] and caches[racer.Player].Level) or 0
	return math.clamp(level / 10, 0, 1)
end

-- The local racer's hold (RaceInputClient: Shift, R2 or the touch button, every frame).
local function localHeld(): boolean
	return player:GetAttribute("RaceChargeHeld") == true
end

-- 2026-09-25: the local grade is RaceInputClient's exact prediction (RacePredictedGrade,
-- written once at GO), else the server's, else nil (the charge watch guesses after the wait).
local function localGrade(cache): string?
	local predicted = player:GetAttribute("RacePredictedGrade")
	if type(predicted) == "string" and predicted ~= "" then
		return predicted
	end
	return if type(cache.GradeAttr) == "string" then cache.GradeAttr else nil
end

-- The local burst and the camera's kick: the Sonic Boom (2026-09-26, owner): Perfect
-- CameraPunch.Fov(18) + Shake(0.3, 1.5), Good and Ok less, a Stall nothing (RaceVfx.LaunchPunch;
-- reduced motion: half the punch, no shake), with the screen's shock ring.
local function launchLocal(racer, grade: string)
	racer.Grade = grade
	RaceVfx.Burst(racer.Character, grade)
	local punch = RaceVfx.LaunchPunch(grade, reducedMotion())
	if punch.Fov > 0 then
		CameraPunch.Fov(punch.Fov)
	end
	if punch.ShakeStrength > 0 then
		CameraPunch.Shake(punch.ShakeSeconds, punch.ShakeStrength)
	end
	RaceScreenFx.Shock(punch.Share)
end

-- GO: the launch, the burst and the local camera's kick.
local function onGo(racer, clock: number)
	racer.LaunchAt = clock
	racer.LaunchG = gaugeOf(racer)
	local cache = caches[racer.Player] or {}
	if racer.IsLocal then
		setFov(nil)
		local grade = localGrade(cache)
		if grade then
			launchLocal(racer, grade)
		else
			racer.BurstPending = true
		end
	else
		racer.Grade = if type(cache.GradeAttr) == "string" then cache.GradeAttr else nil
		if racer.Grade then
			RaceVfx.Burst(racer.Character, racer.Grade)
		else
			racer.BurstPending = true
		end
	end
end

-- A burst still waiting for its grade after GO.
local function resolveBurst(racer, cache, clock: number)
	local waited = clock - racer.LaunchAt
	if racer.IsLocal then
		local grade = localGrade(cache)
		if grade or waited >= LOCAL_GRADE_WAIT then
			racer.BurstPending = false
			local grace = (tonumber(player:GetAttribute("RaceFinishes")) or 0) < CHARGE.GraceRaces
			launchLocal(racer, grade or RaceVfx.PredictGrade(racer.Watch, grace))
		end
		return
	end
	local grade = cache.GradeAttr
	if type(grade) == "string" or waited >= REMOTE_GRADE_WAIT then
		racer.BurstPending = false
		racer.Grade = if type(grade) == "string" then grade else nil
		RaceVfx.Burst(racer.Character, racer.Grade or "Ok")
	end
end

local function onSuper(racer, on: boolean)
	racer.Super = on
	RaceVfx.SetSuper(racer.Character, on)
	if racer.IsLocal then
		if on then
			setFov(CAMERA.SuperFov)
			CameraPunch.Fov(CAMERA.SuperPunch * (if reducedMotion() then 0.5 else 1))
			RaceScreenFx.Shock(SCREEN.SuperShock)
		else
			-- Back to the speed's own FOV (onStepped keeps it from here).
			setFov(runFov(localRatio(racer)))
		end
	end
end

-- 2026-09-26 (owner): a racer crossing the line: a gate of rings across the track on the
-- finish line, in the racer's lane (the state arrives a ping late, when they are past it).
local function finishLine(racer)
	local root = racer.Root
	if not root.Parent then
		return
	end
	local _, x = RaceTrack.ToLocal(root.Position)
	-- (GroundCFrame: where a root stands on the line, i.e. at body height.)
	RaceVfx.Finish(racer.Character, RaceTrack.GroundCFrame(RaceTrack.Length, x))
	if racer.IsLocal then
		RaceScreenFx.Shock(SCREEN.FinishShock)
	end
end

-- Whether the procedural pose has this racer now: the crouch at the line, then the launch
-- (Pose.Launch seconds after GO). 2026-09-25 (owner): never a procedural stride or super dash
-- in a race; the Animator's native fast run shows from the end of the launch.
local function launching(racer, clock: number): boolean
	return racer.LaunchAt ~= nil and clock - racer.LaunchAt < POSE.Launch
end

-- The target pose for this frame (into racer.Pose); false once the launch is over (the last
-- launch frame is kept while the weight blends out).
local function computePose(racer, clock: number, dt: number, tierName: string): boolean
	local t = clock + racer.Seed
	if racer.PoseMode == "Set" then
		RacePose.Set(racer.SetG or 0, t, racer.Seed, racer.Pose)
		return true
	end
	if not launching(racer, clock) then
		return false
	end
	local sprint = tonumber(caches[racer.Player] and caches[racer.Player].SprintSpeed) or DEFAULT_SPRINT
	local s = math.clamp(horizontalSpeed(racer.Root) / math.max(1, sprint), 0, 1)
	racer.Phi = (racer.Phi + 2 * math.pi * RacePose.StrideRate(s, tierName) * dt) % (2 * math.pi * 1000)
	RacePose.Launch(clock - racer.LaunchAt, racer.LaunchG, racer.Grade, racer.Phi, s, t, racer.Seed, racer.Pose)
	return true
end

local function toTransforms(racer)
	local drop = 0
	local humanoid = racer.Humanoid
	if humanoid then
		-- A raised HipHeight (the Silver Surfer's hover) would leave the feet in the air. Only
		-- the hover over SkinSystem's saved base comes off (R6's own HipHeight is 0).
		local base = tonumber(racer.Character:GetAttribute("SurfboardBaseHipHeight")) or 0
		drop = math.clamp(humanoid.HipHeight - base, 0, 2)
	end
	for _, joint in racer.Joints do
		local rotation = racer.Pose[joint.Name]
		if rotation then
			if joint.Name == "RootJoint" and drop > 0 then
				rotation = CFrame.new(0, -drop, 0) * rotation
			end
			racer.Transforms[joint.Name] = SurfboardStance.Transform(joint.C0, rotation)
		end
	end
	racer.HasTransforms = true
end

local function applyTransforms(racer, weight: number)
	if not racer.HasTransforms then
		return
	end
	for _, joint in racer.Joints do
		local target = racer.Transforms[joint.Name]
		local motor = joint.Motor
		if target and motor.Parent then
			local value
			if weight < 1 and joint.Written ~= nil and same(motor.Transform, joint.Written) then
				-- 2026-09-25: nothing animates this joint (R6's run leaves RootJoint and Neck
				-- alone): blend from rest, or it would keep the pose once the weight is gone.
				value = CFrame.identity:Lerp(target, weight)
			else
				value = if weight >= 1 then target else motor.Transform:Lerp(target, weight)
			end
			motor.Transform = value
			joint.Written = value
		end
	end
end

local function lodPass()
	local camera = Workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position
	local tierName = raceTier or "Low"
	for _, racer in racers do
		if racer.IsLocal then
			racer.Rate = math.huge
		else
			local distance = if eye and racer.Root.Parent then (racer.Root.Position - eye).Magnitude else 0
			racer.Rate = RacePose.LodRate(tierName, distance, false)
		end
	end
	-- 2026-09-25 review: a racer whose character streamed out was dropped and nothing else
	-- re-tracks them before their next RaceState change; pick them up when they stream back
	-- in (a few attribute reads per player, 4 Hz, only while the loop runs).
	for target in caches do
		if not racers[target] and wanted(target) then
			track(target)
		end
	end
end

local function onStepped(_, dt: number)
	local clock = os.clock()
	RaceFeelTier.Sample(meter, dt)
	local serverNow = Workspace:GetServerTimeNow()
	local goAt = tonumber(world.GoAt)
	if clock >= nextLodAt then
		nextLodAt = clock + LOD_SECONDS
		lodPass()
	end
	for target, racer in racers do
		local character = racer.Character
		if character.Parent == nil or racer.Root.Parent == nil then
			finish(target, true)
			continue
		end
		local cache = caches[target] or {}
		local mode = RacePose.Mode(cache.Active, cache.State, world.Phase, serverNow, goAt)
		local aside = standsAside(racer)
		local tierName = raceTier or "Low"

		-- The crouch starts SetLeadSeconds before GO (charge opens 0.5 s later).
		local crouch = RacePose.Crouching(mode, world.Phase, serverNow, goAt, QUEUE.SetLeadSeconds)
		if mode ~= "Done" and (crouch or mode == "Run") and not racer.Prewarmed then
			racer.Prewarmed = true
			local name, quality = tier()
			tierName = name
			RaceVfx.Prewarm(character, name, racer.IsLocal, quality)
			-- 2026-09-26 (owner): the arcs in the aura's colours; the after-images (past the racer's own
			-- cruise) are always the sprint's dark shadow.
			RaceVfx.SetTint(character, tintOf(target))
			RaceVfx.SetCruise(character, cruiseOf(target))
			if racer.IsLocal then
				RaceScreenFx.Prewarm(player:FindFirstChildOfClass("PlayerGui"), name)
				RaceScreenFx.Show(true)
			end
		end

		if mode == "Run" and racer.Mode == "Set" then
			onGo(racer, clock)
		end
		if mode ~= "Done" then
			racer.Mode = mode
			racer.PoseMode = mode
		elseif racer.Mode ~= "Done" then
			local crossed = racer.Mode == "Run" and cache.State == "Finished"
			racer.Mode = "Done"
			if racer.Super then
				onSuper(racer, false)
			end
			if racer.IsLocal then
				setFov(nil)
			end
			if crossed then
				finishLine(racer)
			end
		end

		-- Charge (before GO) and a burst still waiting for its grade (after GO). The local
		-- racer's hold drives the charge's arcs every frame; another racer's is read from its
		-- level rising (RaceVfx).
		if mode == "Set" then
			local g = gaugeOf(racer)
			racer.SetG = g
			RaceVfx.SetCharge(character, g, clock, if racer.IsLocal then localHeld() else nil)
			if racer.IsLocal then
				RaceVfx.WatchCharge(racer.Watch, g, serverNow, goAt)
				if crouch then
					setFov(BASE_FOV - CAMERA.SetFovDrop * g)
				end
			end
		elseif racer.BurstPending and racer.LaunchAt then
			resolveBurst(racer, cache, clock)
		end

		-- Super speed, with hysteresis both ways (VFX and camera only: no pose).
		if mode == "Run" then
			local raw = if racer.IsLocal then player:GetAttribute("RaceLocalSuper") == true else cache.SuperRaw == true
			local on = RacePose.UpdateLatch(racer.Latch, raw, clock, SUPER_ENTER_SECONDS, SUPER_EXIT_SECONDS)
			if on ~= racer.Super then
				onSuper(racer, on)
			end
			-- 2026-09-26 (owner): the run's FOV follows the speed over the racer's own cruise.
			if racer.IsLocal and not racer.Super then
				setFov(runFov(localRatio(racer)))
			end
		end

		-- The weight: in over BlendIn while crouched and launching; out over LAUNCH_BLEND_OUT
		-- once the launch is over (the native run takes the body), over BlendOut otherwise.
		local posing = mode ~= "Done" and not aside and racer.Rate > 0
			and ((mode == "Set" and crouch) or (mode == "Run" and launching(racer, clock)))
		if posing then
			racer.Weight = math.min(1, racer.Weight + dt / math.max(0.01, POSE.BlendIn))
		else
			local out = if mode == "Run" then math.min(LAUNCH_BLEND_OUT, POSE.BlendOut) else POSE.BlendOut
			racer.Weight = math.max(0, racer.Weight - dt / math.max(0.01, out))
		end
		if racer.Weight <= 0 then
			if mode == "Done" then
				finish(target)
			elseif racer.HasTransforms then
				racer.HasTransforms = false
				resetJoints(racer)
			end
			continue
		end

		-- Near: every frame. Further: recomputed at the LOD rate, the last pose re-applied in
		-- between (the Animator overwrites the joints every frame). After the launch the last
		-- launch frame is only faded out.
		racer.PoseDt += dt
		if racer.Rate == math.huge or clock >= racer.NextPoseAt or not racer.HasTransforms then
			if racer.Rate ~= math.huge then
				racer.NextPoseAt = clock + 1 / racer.Rate
			end
			if computePose(racer, clock, racer.PoseDt, tierName) then
				toTransforms(racer)
			end
			racer.PoseDt = 0
		end
		applyTransforms(racer, racer.Weight)
	end
	-- (RaceVfx.Active: a racer, or a ring / after-image still playing out.)
	if next(racers) == nil and not RaceVfx.Active() then
		RaceScreenFx.Show(false)
		if stepped then
			stepped:Disconnect()
			stepped = nil
		end
		if rendered then
			rendered:Disconnect()
			rendered = nil
		end
	end
end

local function onRender(dt: number)
	local camera = Workspace.CurrentCamera
	RaceVfx.Step(dt, if camera then camera.CFrame.Position else nil)
	-- 2026-09-26 (owner): the own racer's screen: speed lines, vignette, shock rings.
	local own = racers[player]
	if own and camera then
		local boostUntil = tonumber(player:GetAttribute("RaceBoostUntil"))
		RaceScreenFx.Step(dt, {
			Ratio = if own.Mode == "Run" then localRatio(own) else 0,
			Fov = camera.FieldOfView,
			Super = own.Super,
			Boosted = boostUntil ~= nil and Workspace:GetServerTimeNow() < boostUntil,
			Viewport = camera.ViewportSize,
		})
	end
end

ensureLoops = function()
	if not stepped then
		meter = RaceFeelTier.NewMeter()
		stepped = RunService.Stepped:Connect(onStepped)
	end
	if not rendered then
		rendered = RunService.RenderStepped:Connect(onRender)
	end
end
