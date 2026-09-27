-- test_u4_race_pose.luau (Update 4, race_fx, 2026-09-25)
-- Shared/RacePose is pure: this loads the real src file in plain Lune and puts its poses on an
-- R6 rig built from the real R6 Motor6D C0/C1 (Part1 = Part0 * C0 * Transform * C1^-1, with
-- Transform = SurfboardStance.Transform(C0, rotation)), root 3 studs over the floor (y = 0).
-- PLAN §7.5 tests: Set feet tips within [-0.15, 0.15] of the floor and hands <= 0.8 for g = 0
-- and 1; Run and Super feet >= -0.2 over a full stride at s = 0, 0.5, 1; no NaN (also for NaN
-- and infinite inputs); weight 0 = identity; stride rate <= the tier cap (>= 9 frames per
-- stride at 24 FPS on Low); a Perfect launch leans through 40 degrees; Mode, the super latch
-- and the LOD rates; static checks of Race/RacePoseClient (Stepped + RenderStepped only while
-- racing, RacePosed, RaceFovTarget, reduced motion, timed WaitForChild).
-- No CFrame.lookAt anywhere (it is wrong in Lune).
-- Run: lune run audit/test_u4_race_pose.luau   (from the project root)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")

local RacePose = require("../src/common/ReplicatedStorage/Shared/RacePose")
local U4 = require("../src/common/ReplicatedStorage/Shared/Update4Config")

local CFrame = rb.CFrame
local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end

-- The real R6 joints (every R6 character since 2006).
local R6 = {
	RootJoint = {
		Part0 = "HumanoidRootPart", Part1 = "Torso",
		C0 = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
		C1 = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
	},
	Neck = {
		Part0 = "Torso", Part1 = "Head",
		C0 = CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
		C1 = CFrame.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
	},
	["Right Shoulder"] = {
		Part0 = "Torso", Part1 = "Right Arm",
		C0 = CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
		C1 = CFrame.new(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
	},
	["Left Shoulder"] = {
		Part0 = "Torso", Part1 = "Left Arm",
		C0 = CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
		C1 = CFrame.new(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
	},
	["Right Hip"] = {
		Part0 = "Torso", Part1 = "Right Leg",
		C0 = CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
		C1 = CFrame.new(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
	},
	["Left Hip"] = {
		Part0 = "Torso", Part1 = "Left Leg",
		C0 = CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
		C1 = CFrame.new(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
	},
}
local ORDER = { "RootJoint", "Neck", "Right Shoulder", "Left Shoulder", "Right Hip", "Left Hip" }

-- The client converts with SurfboardStance.Transform: use the real one.
local env = setmetatable({ CFrame = rb.CFrame, Vector3 = rb.Vector3 }, { __index = _G })
local SurfboardStance = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/SurfboardStance.luau"), { environment = env })()

local function finiteFrame(frame)
	for _, value in { frame:GetComponents() } do
		if value ~= value or value == math.huge or value == -math.huge then
			return false
		end
	end
	return true
end

-- Places the rig for a pose; returns part name -> CFrame.
local function place(pose, weight)
	local parts = { HumanoidRootPart = CFrame.new(0, 3, 0) }
	local posed = if weight then RacePose.Weighted(pose, weight) else pose
	for _, name in ORDER do
		local joint = R6[name]
		local rotation = posed[name] or CFrame.identity
		local transform = SurfboardStance.Transform(joint.C0, rotation)
		parts[joint.Part1] = parts[joint.Part0] * joint.C0 * transform * joint.C1:Inverse()
	end
	return parts
end
local function tipY(part)
	return (part * CFrame.new(0, -1, 0)).Position.Y
end
local function feet(parts)
	return math.min(tipY(parts["Left Leg"]), tipY(parts["Right Leg"])), math.max(tipY(parts["Left Leg"]), tipY(parts["Right Leg"]))
end
local function hands(parts)
	return math.max(tipY(parts["Left Arm"]), tipY(parts["Right Arm"]))
end
local function allFinite(pose)
	for _, name in ORDER do
		if not pose[name] or not finiteFrame(pose[name]) then
			return false
		end
	end
	return true
end

----------------------------------------------------------------------
-- 0. The rig at rest stands on the floor (the constants are right)
----------------------------------------------------------------------
do
	local parts = place({})
	local low, high = feet(parts)
	assert(math.abs(low) < 1e-4 and math.abs(high) < 1e-4, "R6 at rest: soles on the floor")
	assert(math.abs(tipY(parts["Right Arm"]) - 2) < 1e-4, "R6 at rest: hands 2 studs over the floor")
	assert(math.abs(parts.Head.Position.Y - 4.5) < 1e-4, "R6 at rest: head centre at 4.5")
	pass("the R6 rig built from the real C0/C1 stands on the floor at rest")
end

----------------------------------------------------------------------
-- 1. Set: the Flash crouch
----------------------------------------------------------------------
do
	local worstLow, worstHigh, worstHand = math.huge, -math.huge, -math.huge
	for _, g in { 0, 0.25, 0.5, 0.7, 0.84, 0.9, 1 } do
		for _, seed in { 0, 3.7, 811.2 } do
			for step = 0, 200 do
				local t = step * 0.0137
				local pose = RacePose.Set(g, t, seed)
				assert(allFinite(pose), "Set pose finite")
				local parts = place(pose)
				local low, high = feet(parts)
				worstLow, worstHigh = math.min(worstLow, low), math.max(worstHigh, high)
				worstHand = math.max(worstHand, hands(parts))
				if g == 0 or g == 1 then
					assert(low >= -0.15 and high <= 0.15, string.format("Set g=%g t=%g: feet tips %.3f..%.3f within 0.15 of the floor", g, t, low, high))
					assert(hands(parts) <= 0.8, string.format("Set g=%g: hands %.3f <= 0.8", g, hands(parts)))
				end
			end
		end
	end
	assert(worstLow >= -0.15 and worstHigh <= 0.15 and worstHand <= 0.8, "Set: every gauge keeps the feet down and the hands low")
	-- The lean deepens with the gauge; the tremble grows only once it overfills.
	local lean0 = RacePose.Lean(RacePose.Set(0, 0, 1).RootJoint)
	local lean1 = RacePose.Lean(RacePose.Set(1, 0, 1).RootJoint)
	assert(math.abs(lean0 - 66) < 3 and math.abs(lean1 - 70) < 3 and lean1 > lean0, "Set lean 66 -> 70 degrees")
	local function tremble(g)
		local spread = 0
		local base = RacePose.Set(g, 0, 5).RootJoint
		for step = 1, 50 do
			local frame = RacePose.Set(g, step / 97, 5).RootJoint
			local _, _, _, r00, r01, r02 = frame:GetComponents()
			local _, _, _, b00, b01, b02 = base:GetComponents()
			spread = math.max(spread, math.abs(r01 - b01) + math.abs(r02 - b02) + math.abs(r00 - b00))
		end
		return spread
	end
	assert(tremble(1) > 3 * tremble(0.7), "the crouch trembles when overcharged, steady in the zone")
	pass(string.format("Set: feet %.3f..%.3f of the floor, hands <= %.3f, lean %.1f -> %.1f, trembling only when overfilled", worstLow, worstHigh, worstHand, lean0, lean1))
end

----------------------------------------------------------------------
-- 2. Run and Super: feet never under the floor, over a whole stride
----------------------------------------------------------------------
do
	local worstRun, worstSuper = math.huge, math.huge
	for _, s in { 0, 0.5, 1 } do
		for step = 0, 628 do
			local phi = step / 100
			local t = step * 0.021
			local run = RacePose.Run(phi, s, t)
			assert(allFinite(run), "Run pose finite")
			local low = feet(place(run))
			worstRun = math.min(worstRun, low)
			assert(low >= -0.2, string.format("Run s=%g phi=%.2f: feet %.3f >= -0.2", s, phi, low))
			local super = RacePose.Super(phi, t)
			assert(allFinite(super), "Super pose finite")
			local superLow = feet(place(super))
			worstSuper = math.min(worstSuper, superLow)
			assert(superLow >= -0.2, string.format("Super phi=%.2f: feet %.3f >= -0.2", phi, superLow))
		end
	end
	-- The stride reaches the floor (it is a run, not a hover) and leans with speed.
	assert(worstRun <= 0.05 and worstSuper <= 0.05, "a foot comes down to the floor in each stride")
	local slow = RacePose.Lean(RacePose.Run(0, 0, 0).RootJoint)
	local fast = RacePose.Lean(RacePose.Run(0, 1, 0).RootJoint)
	local super = RacePose.Lean(RacePose.Super(0, 0).RootJoint)
	assert(math.abs(slow - 10) < 0.5 and math.abs(fast - 20) < 0.5 and math.abs(super - 34) < 0.5, "leans: run 10 -> 20, super 34")
	-- Opposite arm and leg swing together.
	local stride = RacePose.Run(math.pi / 2, 1, 0)
	local parts = place(stride)
	local rightLegForward = (parts["Right Leg"] * CFrame.new(0, -1, 0)).Position.Z < 0
	local leftArmForward = (parts["Left Arm"] * CFrame.new(0, -1, 0)).Position.Z < (parts["Right Arm"] * CFrame.new(0, -1, 0)).Position.Z
	assert(rightLegForward and leftArmForward, "right leg forward with the left arm")
	-- Super: arms swept back (hands behind the shoulders).
	local superParts = place(RacePose.Super(0, 0))
	assert((superParts["Right Arm"] * CFrame.new(0, -1, 0)).Position.Z > superParts.Torso.Position.Z, "super: arms swept back")
	pass(string.format("Run/Super: lowest foot %.3f / %.3f over full strides at s = 0, 0.5, 1; lean %.0f/%.0f/%.0f; arms opposite the legs, swept back at super speed", worstRun, worstSuper, slow, fast, super))
end

----------------------------------------------------------------------
-- 3. The launch: Set -> Run in Pose.Launch seconds, a Perfect drives out through 40 degrees
----------------------------------------------------------------------
do
	local launch = U4.Race.Feel.Pose.Launch
	local leans = {}
	local lowest = math.huge
	for step = 0, 44 do
		local tau = launch * step / 44
		local pose = RacePose.Launch(tau, 0.7, "Perfect", 0.3, 0.2, 1, 9)
		assert(allFinite(pose), "launch pose finite")
		leans[#leans + 1] = RacePose.Lean(pose.RootJoint)
		lowest = math.min(lowest, (feet(place(pose))))
	end
	local through = false
	for index = 2, #leans do
		if (leans[index - 1] - 40) * (leans[index] - 40) <= 0 then
			through = true
		end
	end
	assert(math.abs(leans[1] - RacePose.Lean(RacePose.Set(0.7, 1, 9).RootJoint)) < 0.5, "the launch starts from the crouch")
	assert(through, "a Perfect launch passes through 40 degrees")
	assert(lowest >= -0.35, string.format("the launch keeps the feet about the floor (%.3f)", lowest))
	local done = RacePose.Launch(launch, 0.7, "Good", 0.3, 0.2, 1, 9)
	local run = RacePose.Run(0.3, 0.2, 1)
	for _, name in ORDER do
		local a, b = { done[name]:GetComponents() }, { run[name]:GetComponents() }
		for index = 1, 12 do
			assert(math.abs(a[index] - b[index]) < 1e-3, "the launch ends on the stride: " .. name)
		end
	end
	assert(math.abs(RacePose.EaseOutBack(0)) < 1e-9 and math.abs(RacePose.EaseOutBack(1) - 1) < 1e-9, "ease-out-back 0 -> 1")
	local peak = 0
	for step = 0, 100 do
		peak = math.max(peak, RacePose.EaseOutBack(step / 100))
	end
	assert(peak > 1 and peak < 1.15, "ease-out-back overshoots a little")
	pass(string.format("launch: %.1f -> %.1f degrees through 40 on a Perfect, ends on the stride, lowest foot %.3f", leans[1], leans[#leans], lowest))
end

----------------------------------------------------------------------
-- 4. No NaN, weight 0 = identity, blends
----------------------------------------------------------------------
do
	local nan, inf = 0 / 0, math.huge
	for _, pose in {
		RacePose.Set(nan, inf, nan),
		RacePose.Set(-5, -inf, nil),
		RacePose.Set(7, 1e9, 1e12),
		RacePose.Run(nan, nan, nan),
		RacePose.Run(inf, -3, inf),
		RacePose.Super(nan, inf),
		RacePose.Launch(nan, nan, "Perfect", nan, nan, nan, nan),
		RacePose.Launch(-inf, 2, nil, inf, inf, inf, inf),
	} do
		assert(allFinite(pose), "NaN / infinite inputs still give a finite pose")
	end
	assert(RacePose.StrideRate(nan, "High") == 1.6 and RacePose.Noise(nan, inf) == RacePose.Noise(nan, inf), "stride and noise survive NaN")

	local pose = RacePose.Set(0.8, 1.3, 2)
	local rest = RacePose.Weighted(pose, 0)
	for _, name in ORDER do
		assert(rest[name] == CFrame.identity, "weight 0 = identity: " .. name)
		assert(SurfboardStance.Transform(R6[name].C0, rest[name]) == CFrame.identity, "identity rotation = identity Transform")
	end
	local parts = place(pose, 0)
	local low, high = feet(parts)
	assert(math.abs(low) < 1e-4 and math.abs(high) < 1e-4, "weight 0 leaves the rig at rest")
	local full = RacePose.Weighted(pose, 1)
	local blended = RacePose.Blend(RacePose.Run(1, 1, 0), pose, 1)
	local same = RacePose.Blend(pose, RacePose.Run(1, 1, 0), 0)
	for _, name in ORDER do
		assert(full[name] == pose[name] and blended[name] == pose[name] and same[name] == pose[name], "weight 1 = the pose, Blend ends")
	end
	local half = RacePose.Blend({}, pose, 0.5)
	assert(allFinite(half), "Blend treats missing joints as identity")
	pass("no NaN from NaN/inf inputs; weight 0 = identity (rig at rest); Blend/Weighted ends are exact")
end

----------------------------------------------------------------------
-- 5. Stride rate, Mode, latch, LOD
----------------------------------------------------------------------
do
	local caps = U4.Race.Feel.Pose.StrideCap
	for _, tier in { "High", "Mid", "Low" } do
		for step = 0, 20 do
			local s = step / 20
			local rate = RacePose.StrideRate(s, tier)
			assert(rate >= 1.6 and rate <= caps[tier] + 1e-9, "stride rate within 1.6 .. cap on " .. tier)
		end
		assert(RacePose.StrideRate(5, tier) == caps[tier], "stride rate capped on " .. tier)
	end
	assert(24 / RacePose.StrideRate(1, "Low") >= 9, ">= 9 frames per stride at 24 FPS on Low")
	assert(math.abs(RacePose.StrideRate(0.5, "High") - 2.6) < 1e-9, "1.6 + 2.0 s")

	assert(RacePose.Mode(false, "Racing", "Running", 10, 5) == "Done", "not active -> Done")
	assert(RacePose.Mode(true, "Queued", "Gathering", 10, nil) == "Done", "queued in the staging box -> no pose")
	assert(RacePose.Mode(true, "Staged", "Staging", 1, 10) == "Set", "staged -> Set")
	assert(RacePose.Mode(true, "Staged", "Countdown", 9, 10) == "Set", "countdown -> Set")
	assert(RacePose.Mode(true, "Staged", "Running", 10.05, 10) == "Run", "past GO before the state arrives -> Run")
	assert(RacePose.Mode(true, "Staged", "Countdown", 10.01, 10) == "Run", "past GO on the server clock before the phase arrives -> Run")
	assert(RacePose.Mode(true, "Staged", "Staging", 10.01, 10) == "Set" and RacePose.Mode(true, "Staged", "Countdown", 9, nil) == "Set", "no GO yet -> Set")
	assert(RacePose.Mode(true, "Racing", "Running", 12, 10) == "Run", "racing -> Run")
	assert(RacePose.Mode(true, "Finished", "Running", 40, 10) == "Done", "finished -> Done")
	assert(RacePose.Mode(true, "", "Results", 40, 10) == "Done", "cleared -> Done")
	-- RaceService stages the racers before it sets RacePhase = "Staging": a client can see Staged
	-- under the old phase (and last race's RaceGoAt). That must not drop the racer, nor crouch.
	assert(RacePose.Mode(true, "Staged", "Gathering", 100, 50) == "Set" and RacePose.Mode(true, "Staged", "Cooldown", 100, 50) == "Set", "staged under the old phase -> Set (not dropped)")
	local lead = U4.Race.Queue.SetLeadSeconds
	assert(not RacePose.Crouching("Set", "Gathering", 100, 50, lead), "a stale GO under Gathering does not crouch")
	assert(not RacePose.Crouching("Set", "Staging", 5, 10, lead) and RacePose.Crouching("Set", "Countdown", 6.6, 10, lead), "the crouch starts SetLeadSeconds before GO")
	assert(RacePose.Crouching("Set", "Countdown", 0, nil, lead) and not RacePose.Crouching("Run", "Countdown", 9, 10, lead), "no GO known yet -> crouch; Run never crouches")

	local latch = RacePose.NewLatch()
	assert(RacePose.UpdateLatch(latch, true, 0, 0.35, 0.25) == false, "super needs 0.35 s")
	assert(RacePose.UpdateLatch(latch, true, 0.3, 0.35, 0.25) == false, "...still off at 0.3 s")
	assert(RacePose.UpdateLatch(latch, false, 0.32, 0.35, 0.25) == false and RacePose.UpdateLatch(latch, true, 0.4, 0.35, 0.25) == false, "a dip restarts the wait")
	assert(RacePose.UpdateLatch(latch, true, 0.76, 0.35, 0.25) == true, "on after 0.35 s held")
	assert(RacePose.UpdateLatch(latch, false, 1.0, 0.35, 0.25) == true and RacePose.UpdateLatch(latch, false, 1.2, 0.35, 0.25) == true, "stays on under 0.25 s below")
	assert(RacePose.UpdateLatch(latch, false, 1.26, 0.35, 0.25) == false, "off after 0.25 s below")

	local lod = U4.Race.Feel.Pose.Lod
	assert(RacePose.LodRate("High", 1e6, true) == math.huge, "the local racer is always full rate")
	assert(RacePose.LodRate("High", lod.High.Full, false) == math.huge and RacePose.LodRate("High", 200, false) == 20 and RacePose.LodRate("High", 251, false) == 0, "High: full <= 150, 20 Hz <= 250, none beyond")
	assert(RacePose.LodRate("Mid", 60, false) == math.huge and RacePose.LodRate("Mid", 100, false) == 15 and RacePose.LodRate("Mid", 151, false) == 0, "Mid: full <= 60, 15 Hz <= 150, none beyond")
	assert(RacePose.LodRate("Low", 61, false) == 15 and RacePose.LodRate(nil, 0 / 0, false) == 0, "Low as Mid; unknown distance = not posed")
	pass("stride rate within the tier caps; Mode Set/Run/Done; super latch 0.35 s in / 0.25 s out; LOD rates per tier")
end

----------------------------------------------------------------------
-- 6. The source: pure module, and the client's contract
----------------------------------------------------------------------
do
	local pose = fs.readFile("src/common/ReplicatedStorage/Shared/RacePose.luau")
	assert(not string.find(pose, "lookAt", 1, true), "RacePose never uses CFrame.lookAt")
	assert(not string.find(pose, "game:", 1, true) and not string.find(pose, "Instance.new", 1, true), "RacePose is pure")
	local client = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Race/RacePoseClient.client.luau")
	local code = string.gsub(client, "%-%-[^\n]*", "")
	local function count(needle)
		local n = 0
		for _ in string.gmatch(code, needle) do
			n += 1
		end
		return n
	end
	assert(count("RunService%.Stepped:Connect") == 1 and count("RunService%.RenderStepped:Connect") == 1, "one Stepped (poses) and one RenderStepped (VFX)")
	assert(count("Heartbeat") == 0 and count("BindToRenderStep") == 0, "no other per-frame hooks")
	assert(string.find(code, "stepped:Disconnect()", 1, true) and string.find(code, "rendered:Disconnect()", 1, true), "the per-frame connections go away when nobody races")
	for call in string.gmatch(code, "WaitForChild%b()") do
		assert(string.find(call, ",", 1, true), "every WaitForChild has a timeout: " .. call)
	end
	assert(string.find(code, 'SetAttribute("RacePosed"', 1, true), "marks posed characters with RacePosed")
	assert(string.find(code, 'SetAttribute("RaceFovTarget"', 1, true), "writes RaceFovTarget")
	assert(string.find(code, "ReducedMotionEnabled", 1, true) and string.find(code, "pcall", 1, true), "reads ReducedMotionEnabled (pcall)")
	assert(string.find(code, "SurfboardStance.Transform(joint.C0", 1, true), "Transform from the joint's C0")
	assert(string.find(code, "motor.Transform:Lerp(target, weight)", 1, true), "blends from the Animator's pose")
	assert(string.find(code, "RaceChargeLevel", 1, true) and string.find(code, "RaceChargeLocal", 1, true), "gauge: RaceChargeLevel (others) / RaceChargeLocal (local)")
	assert(string.find(code, "RaceLocalSuper", 1, true) and string.find(code, "RaceSuperSpeed", 1, true), "super: RaceLocalSuper (local) / RaceSuperSpeed (others)")
	assert(not string.find(code, "Instance.new", 1, true) and not string.find(code, ":Clone(", 1, true), "the client makes no instances (RaceVfx.Prewarm does)")
	assert(not string.find(code, "GetDescendants", 1, true), "no descendant walks")
	assert(string.find(code, "RacePose.Crouching(", 1, true), "the crouch waits for this race's phase (RacePose.Crouching)")
	assert(string.find(code, "IsDescendantOf(Workspace)", 1, true) and string.find(code, "not racers[target] and wanted(target)", 1, true), "streamed-out racers are re-tracked when back in the workspace")
	pass("RacePose is pure; RacePoseClient: 1 Stepped + 1 RenderStepped disconnected when idle, timed WaitForChild, RacePosed, RaceFovTarget, reduced motion")
end

print(string.format("test_u4_race_pose: %d checks passed", passed))
