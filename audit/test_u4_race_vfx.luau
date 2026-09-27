-- test_u4_race_vfx.luau (Update 4, race_fx; rewritten 2026-09-26 for the owner's race VFX)
-- Shared/RaceVfx, Shared/RaceScreenFx and Shared/RaceFeelTier after the owner's 2026-09-26
-- request (no bubble, no particles; Sonic Burst style arcs, rings, after-images, screen FX):
--   * static: nothing is built outside Prewarm (no Instance.new / :Clone( / TweenService /
--     Debris reachable from Step, SetCharge, SetSuper, Burst, PadBoost, Finish, SetTint,
--     SetCruise, SetEnabled; RaceScreenFx's Step, Shock, Show likewise); RaceVfx makes only
--     folders, attachments, beams, parts (ring holders), a PointLight and sounds, its only clone
--     is the after-images' body parts; RaceScreenFx only a ScreenGui, frames, gradients,
--     corners and strokes. No ParticleEmitter, Sparkles, engine particle texture, BubbleModule,
--     Glass or Trail anywhere in the race VFX code, and nothing there touches SpeedsterCosmetics;
--   * the budgets per tier (Update4Config Feel.Lightning / AfterImage / Rings / Screen);
--   * RaceVfx in plain Lune on an R6 character (with a face, a Motor6D, an accessory and an
--     equipped aura + trail): Prewarm builds exactly the plan (arc attachments on the body,
--     beams, a pool of dark SmoothPlastic body-part silhouettes, the shared rings); the hot path builds
--     nothing; the aura's and the trail's emitters stay on and untouched; Release cleans up;
--   * the arcs: only while held or venting; more lit, wider and re-rolled faster the fuller the
--     gauge; cyan / gold in the zone / red venting; chains that taper; remote hold read from the
--     level rising; only the nearest others;
--   * GO: LaunchPunch (Perfect Fov 18 + Shake 0.3 x 1.5, Good 0.6, Ok 0.3, Stall none; reduced
--     motion: half, no shake), Perfect two ground rings / Good one / Ok a small one / Stall
--     none, every arc flashing, the torso light; rings are true circles (Bezier handles r x
--     0.5523), flat at the feet or a gate across the track at the finish;
--   * after-images: cadence per tier (0.05 / 0.08 / 0.12 s), speed threshold relative to the
--     racer's own cruise, transparency 0.3 -> 0.7 -> 1, the sprint's dark shadow (2026-09-26,
--     owner: Color3.fromRGB(28, 17, 38), SmoothPlastic, never the aura's or gold tints), fixed
--     pool, BulkMoveTo'd body-part frames, the nearest others only, the kill switches;
--   * RaceScreenFx: speed lines / vignette levels from the speed over the own cruise and the FOV,
--     shock rings, reduced motion, the kill switch, nothing built in Step;
--   * the charge watch; sounds are live ids; the client contracts (RacePoseClient, RaceInputClient,
--     RaceHudController).
-- Run: lune run audit/test_u4_race_vfx.luau   (from the project root)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")

local SHARED = "src/common/ReplicatedStorage/Shared/"
local CLIENT = "src/common/StarterPlayer/StarterPlayerScripts/"
local U4 = require("../src/common/ReplicatedStorage/Shared/Update4Config")
local RaceFeelTier = require("../src/common/ReplicatedStorage/Shared/RaceFeelTier")
local RaceChargeMath = require("../src/common/ReplicatedStorage/Shared/RaceChargeMath")

local FEEL = U4.Race.Feel
local GHOST = FEEL.AfterImage
local RINGS = FEEL.Rings
local LIGHTNING = FEEL.Lightning
local SCREEN = FEEL.Screen
local COLORS = FEEL.Vfx.Colors

math.randomseed(20260926)

local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end

local function stripComments(source)
	source = string.gsub(source, "%-%-%[(=*)%[.-%]%1%]", "")
	return (string.gsub(source, "%-%-[^\n]*", ""))
end

local function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-6)
end

-- Top-level functions and their bodies (a body runs to the next top-level header).
local function bodiesOf(code)
	local headers = {}
	for position, name in string.gmatch(code, "()\n[local ]*function ([%w_%.]+)%(") do
		table.insert(headers, { At = position, Name = name })
	end
	local bodies = {}
	for index, header in headers do
		local stop = if headers[index + 1] then headers[index + 1].At else #code
		bodies[header.Name] = string.sub(code, header.At, stop)
	end
	return bodies
end

-- Every builder reachable from the hot entry points fails the check.
local function checkHotPath(label, code, builders, entries)
	local bodies = bodiesOf(code)
	for name, body in bodies do
		local builds = string.find(body, "Instance.new", 1, true) or string.find(body, ":Clone(", 1, true)
		assert(not builds or builders[name], label .. ": only the Prewarm builders make instances, not " .. name)
	end
	for name in builders do
		assert(bodies[name], label .. ": builder " .. name .. " exists")
	end
	local reached = {}
	local function visit(name)
		if reached[name] or not bodies[name] then
			return
		end
		reached[name] = true
		for called in string.gmatch(bodies[name], "([%w_%.]+)%(") do
			visit(called)
		end
	end
	for _, entry in entries do
		assert(bodies[entry], label .. " has " .. entry)
		visit(entry)
	end
	local count = 0
	for name in reached do
		assert(not builders[name], label .. ": " .. name .. " is reachable from the hot path")
		count += 1
	end
	return count
end

----------------------------------------------------------------------
-- 1. Static: nothing built outside Prewarm; no particles, no bubble, cosmetics untouched
----------------------------------------------------------------------
local VFX_SOURCE = fs.readFile(SHARED .. "RaceVfx.luau")
local SCREEN_SOURCE = fs.readFile(SHARED .. "RaceScreenFx.luau")
do
	local code = stripComments(VFX_SOURCE)
	local checked = checkHotPath("RaceVfx", code, {
		container = true, newFolder = true, newAttachment = true, newBeam = true, newGhost = true,
		buildRings = true, ensureShared = true, ["RaceVfx.Prewarm"] = true,
	}, { "RaceVfx.Step", "RaceVfx.SetCharge", "RaceVfx.SetSuper", "RaceVfx.Burst", "RaceVfx.PadBoost", "RaceVfx.Finish",
		"RaceVfx.SetTint", "RaceVfx.SetCruise", "RaceVfx.SetEnabled", "RaceVfx.SetReducedMotion", "RaceVfx.Release" })
	local ALLOWED = { Folder = true, Attachment = true, Beam = true, Part = true, PointLight = true, Sound = true }
	local classes = 0
	for className in string.gmatch(code, 'Instance%.new%(%s*"([%w_]+)"') do
		classes += 1
		assert(ALLOWED[className], "RaceVfx makes a " .. className .. " (only folders, attachments, beams, ring parts, a light, sounds)")
	end
	assert(classes >= 6, "Instance.new calls found")
	local clones = 0
	for _ in string.gmatch(code, ":Clone%(") do
		clones += 1
	end
	local bodies = bodiesOf(code)
	assert(clones == 1 and string.find(bodies.newGhost, "source:Clone()", 1, true), "the only :Clone( is an after-image's body part")
	assert(string.find(bodies.newGhost, 'child:IsA("SpecialMesh")', 1, true) and string.find(bodies.newGhost, "child:Destroy()", 1, true),
		"a silhouette keeps nothing but a head mesh (no decals, joints, scripts)")
	assert(string.find(bodies.bodyParts, 'child.Name ~= "HumanoidRootPart"', 1, true) and string.find(bodies.bodyParts, "character:GetChildren()", 1, true),
		"silhouettes copy the body parts only (direct children: never an accessory's Handle)")
	assert(string.find(bodies.stepGhosts, "RaceVfx.GhostsWanted(speed, entry.Cruise", 1, true), "the after-images' threshold is the racer's own cruise")
	assert(string.find(code, "workspace:BulkMoveTo(bulkParts, bulkFrames", 1, true), "moved with workspace:BulkMoveTo")
	assert(not string.find(code, "TweenService", 1, true) and not string.find(code, "Debris", 1, true), "no TweenService or Debris")
	pass("RaceVfx: only Prewarm's builders make instances (" .. checked .. " hot functions checked); folders, attachments, beams, ring parts, a light and sounds; the only clone is a body part")

	local screen = stripComments(SCREEN_SOURCE)
	local screenChecked = checkHotPath("RaceScreenFx", screen, { frame = true, gradient = true, build = true },
		{ "RaceScreenFx.Step", "RaceScreenFx.Shock", "RaceScreenFx.Show", "RaceScreenFx.SetEnabled", "RaceScreenFx.SetReducedMotion" })
	local SCREEN_ALLOWED = { ScreenGui = true, Frame = true, UIGradient = true, UICorner = true, UIStroke = true }
	for className in string.gmatch(screen, 'Instance%.new%(%s*"([%w_]+)"') do
		assert(SCREEN_ALLOWED[className], "RaceScreenFx makes a " .. className)
	end
	assert(not string.find(screen, ":Clone(", 1, true) and not string.find(screen, "Image", 1, true) and not string.find(screen, "rbxasset", 1, true)
		and not string.find(screen, "TweenService", 1, true), "RaceScreenFx: no clones, no images, no asset ids, no tweens")
	pass("RaceScreenFx: only Prewarm builds (" .. screenChecked .. " hot functions checked): a ScreenGui, frames, gradients, corners, strokes; no images")

	-- The owner: zero Sparkles / generic particles, no bubble, the cosmetics never touched.
	local RACE_FILES = {
		SHARED .. "RaceVfx.luau", SHARED .. "RaceScreenFx.luau", SHARED .. "RaceFeelTier.luau",
		CLIENT .. "Race/RacePoseClient.client.luau", CLIENT .. "Race/RaceInputClient.client.luau",
		CLIENT .. "UI/RaceHudController.client.luau",
	}
	for _, path in RACE_FILES do
		local text = stripComments(fs.readFile(path))
		for _, forbidden in { "ParticleEmitter", "Sparkles", "sparkles_main", "textures/particles", "BubbleModule", "SpeedsterCosmetics",
			'IsA("Trail")', 'ClassName == "Trail"', 'OfClass("Trail")', 'WhichIsA("Trail")', "Material.Glass", '"Glass"', "Highlight", "CFrame.lookAt" } do
			assert(not string.find(text, forbidden, 1, true), path .. " has " .. forbidden)
		end
	end
	for _, path in { SHARED .. "RaceVfx.luau", SHARED .. "RaceScreenFx.luau", CLIENT .. "Race/RacePoseClient.client.luau" } do
		local text = stripComments(fs.readFile(path))
		assert(not string.find(text, "LocalTransparencyModifier", 1, true), path .. " hides nothing on the character")
	end
	pass("no ParticleEmitter / Sparkles / engine particle texture / BubbleModule / Glass / Highlight in the race VFX code; nothing there touches SpeedsterCosmetics or trails")
end

----------------------------------------------------------------------
-- The modules in Lune, with a counting Instance.new
----------------------------------------------------------------------
local created = {}
local function resetCount()
	created = {}
end
local function total()
	local n = 0
	for _, count in created do
		n += count
	end
	return n
end
local CountingInstance = {
	new = function(className)
		created[className] = (created[className] or 0) + 1
		return rb.Instance.new(className)
	end,
}
local modules = { ["./Update4Config"] = U4, ["./RaceFeelTier"] = RaceFeelTier, ["./RaceChargeMath"] = RaceChargeMath }
local env = setmetatable({
	Instance = CountingInstance,
	Vector3 = rb.Vector3, CFrame = rb.CFrame, Color3 = rb.Color3, Vector2 = rb.Vector2, Enum = rb.Enum,
	ColorSequence = rb.ColorSequence, NumberSequence = rb.NumberSequence, NumberSequenceKeypoint = rb.NumberSequenceKeypoint,
	UDim = rb.UDim, UDim2 = rb.UDim2,
	require = function(path)
		return modules[path] or error("unexpected require " .. tostring(path))
	end,
}, { __index = _G })
local RaceVfx = luau.load(VFX_SOURCE, { environment = env })()
local RaceScreenFx = luau.load(SCREEN_SOURCE, { environment = env })()

local fxFolder = rb.Instance.new("Folder")
fxFolder.Name = "RaceFx"
RaceVfx.Container = fxFolder

local Y0 = 12000
local R6_PARTS = {
	HumanoidRootPart = { rb.CFrame.new(0, 3, 0), rb.Vector3.new(2, 2, 1) },
	Torso = { rb.CFrame.new(0, 3, 0), rb.Vector3.new(2, 2, 1) },
	Head = { rb.CFrame.new(0, 4.5, 0), rb.Vector3.new(2, 1, 1) },
	["Right Arm"] = { rb.CFrame.new(1.5, 3, 0), rb.Vector3.new(1, 2, 1) },
	["Left Arm"] = { rb.CFrame.new(-1.5, 3, 0), rb.Vector3.new(1, 2, 1) },
	["Right Leg"] = { rb.CFrame.new(0.5, 1, 0), rb.Vector3.new(1, 2, 1) },
	["Left Leg"] = { rb.CFrame.new(-0.5, 1, 0), rb.Vector3.new(1, 2, 1) },
}
local BODY = { Head = true, Torso = true, ["Right Arm"] = true, ["Left Arm"] = true, ["Right Leg"] = true, ["Left Leg"] = true }
local characters = rb.Instance.new("Folder")

-- An R6 character as the game has it: a face, the joints, an accessory, clothing, and the
-- server's SpeedsterCosmetics (an aura's emitter, a trail).
local function newCharacter(name, x)
	local model = rb.Instance.new("Model")
	model.Name = name
	for partName, spec in R6_PARTS do
		local part = rb.Instance.new("Part")
		part.Name = partName
		part.Size = spec[2]
		part.CFrame = rb.CFrame.new(x, Y0, 0) * spec[1]
		part.AssemblyLinearVelocity = rb.Vector3.new(0, 0, 0)
		part.Parent = model
	end
	local head = model.Head
	local mesh = rb.Instance.new("SpecialMesh")
	mesh.MeshType = rb.Enum.MeshType.Head
	mesh.Parent = head
	local face = rb.Instance.new("Decal")
	face.Name = "face"
	face.Parent = head
	local neck = rb.Instance.new("Motor6D")
	neck.Name = "Neck"
	neck.Part0 = model.Torso
	neck.Part1 = head
	neck.Parent = model.Torso
	local hat = rb.Instance.new("Accessory")
	hat.Name = "Hair"
	local handle = rb.Instance.new("Part")
	handle.Name = "Handle"
	handle.CFrame = head.CFrame
	handle.Parent = hat
	hat.Parent = model
	rb.Instance.new("Shirt").Parent = model
	local cosmetics = rb.Instance.new("Folder")
	cosmetics.Name = "SpeedsterCosmetics"
	local aura = rb.Instance.new("Model")
	aura.Name = "EquippedAura"
	local holder = rb.Instance.new("Part")
	holder.Name = "EffectHolder"
	holder.Transparency = 1
	holder.Parent = aura
	local emitter = rb.Instance.new("ParticleEmitter")
	emitter.Enabled = true
	emitter.Rate = 30
	emitter.Parent = holder
	aura.Parent = cosmetics
	local trailSlot = rb.Instance.new("Model")
	trailSlot.Name = "EquippedTrail"
	local trailHolder = rb.Instance.new("Part")
	trailHolder.Name = "EffectHolder"
	trailHolder.Transparency = 1
	trailHolder.Parent = trailSlot
	local trail = rb.Instance.new("Trail")
	trail.Enabled = true
	trail.Parent = trailHolder
	trailSlot.Parent = cosmetics
	cosmetics.Parent = model
	model.Parent = characters
	return model
end

-- Moves a character `dz` studs down the track (-Z) at `speed` studs/s.
local function run(model, dz, speed)
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			part.CFrame = part.CFrame + rb.Vector3.new(0, 0, -dz)
			part.AssemblyLinearVelocity = rb.Vector3.new(0, 0, -(speed or 0))
		end
	end
end
local function setSpeed(model, speed)
	run(model, 0, speed)
end

local function descendantsOf(className, root)
	local list = {}
	for _, item in root:GetDescendants() do
		if item.ClassName == className then
			table.insert(list, item)
		end
	end
	return list
end
local function arcPoints(model)
	local n = 0
	for _, item in model:GetDescendants() do
		if item:IsA("Attachment") and item.Name == RaceVfx.ArcName then
			n += 1
		end
	end
	return n
end
local function cosmeticsState(model)
	local out = {}
	for _, item in model.SpeedsterCosmetics:GetDescendants() do
		if item:IsA("ParticleEmitter") or item:IsA("Trail") then
			table.insert(out, tostring(item.Enabled) .. item:GetFullName())
		elseif item:IsA("BasePart") then
			table.insert(out, tostring(item.Transparency) .. item:GetFullName())
		end
	end
	table.sort(out)
	return table.concat(out, "|")
end

local DT = 1 / 60
local EYE = rb.Vector3.new(0, Y0 + 5, 60)
local clockNow = 100
local function tick(seconds)
	clockNow += seconds
	return clockNow
end
local function frames(seconds, dt, each)
	local step = dt or DT
	for _ = 1, math.floor(seconds / step + 0.5) do
		if each then
			each(step)
		end
		RaceVfx.Step(step, EYE, tick(step))
	end
end

----------------------------------------------------------------------
-- 2. The budgets and the plans per tier
----------------------------------------------------------------------
do
	local high, mid, low = RaceFeelTier.Budget("High"), RaceFeelTier.Budget("Mid"), RaceFeelTier.Budget("Low")
	for _, budget in { high, mid, low } do
		for _, row in { budget.Own, budget.Other } do
			for _, gone in { "Bubble", "BubblePool", "PalmEmitters", "Bolts", "ParticlesPerSecond", "LightningRate", "BurstParticles", "Skin" } do
				assert(row[gone] == nil, budget.Tier .. ": no " .. gone .. " left in the budget")
			end
		end
		assert(budget.GlassOnScreenCap == nil and budget.OthersParticleCap == nil and budget.OthersBubbleCap == nil, budget.Tier .. ": no Glass / particle / bubble caps")
	end
	local expected = {
		High = { Own = { 6, 5, 24, 30, 20, 1, 7, 0.05 }, Other = { 2, 4, 6, 8, 10 }, OthersArcCap = 6, OthersGhostCap = 3, OthersGhostPool = 12, RingPool = 8 },
		Mid = { Own = { 4, 4, 12, 16, 12, 0, 5, 0.08 }, Other = { 1, 4, 3, 4, 8 }, OthersArcCap = 3, OthersGhostCap = 1, OthersGhostPool = 3, RingPool = 5 },
		Low = { Own = { 2, 4, 6, 8, 8, 0, 3, 0.12 }, Other = { 0, 0, 0, 0, 0 }, OthersArcCap = 0, OthersGhostCap = 0, OthersGhostPool = 0, RingPool = 3 },
	}
	for tier, want in expected do
		local own, other = RaceVfx.Plan(tier, true), RaceVfx.Plan(tier, false)
		local o = want.Own
		assert(own.Arcs == o[1] and own.ArcPoints == o[2] and own.ArcBeams == o[3] and own.ArcAttachments == o[4] and own.ArcHz == o[5],
			string.format("%s own arcs %d x %d (%d beams, %d attachments) at %d Hz", tier, o[1], o[2], o[3], o[4], o[5]))
		assert(own.Lights == o[6] and own.GhostPool == o[7] and near(own.GhostEvery, o[8]), string.format("%s own: %d light, %d after-images every %.2f s", tier, o[6], o[7], o[8]))
		local t = want.Other
		assert(other.Arcs == t[1] and other.ArcPoints == t[2] and other.ArcBeams == t[3] and other.ArcAttachments == t[4] and other.ArcHz == t[5],
			tier .. " others' arcs")
		assert(other.Lights == 0 and other.GhostPool == 0, tier .. ": others have no light and no own pool")
		assert(own.OthersArcCap == want.OthersArcCap and own.OthersGhostCap == want.OthersGhostCap and own.OthersGhostPool == want.OthersGhostPool and own.RingPool == want.RingPool,
			tier .. ": nearest-others caps and shared pools")
		assert(RaceVfx.PlanCounts(own).Particles == 0 and RaceVfx.PlanCounts(other).Particles == 0, "no particles planned")
		assert(own.Distance == math.huge and own.RingDistance == math.huge, "the own racer always shows")
		-- The hand-set quality no longer changes a budget (no Glass tier).
		assert(RaceVfx.Plan(tier, true, 10).GhostPool == own.GhostPool and RaceVfx.Plan(tier, true, 1).Arcs == own.Arcs, tier .. ": quality does not change the plan")
	end
	assert(RaceVfx.Plan("Low", false).GhostEvery == nil and RaceVfx.Plan("Low", false).RingDistance == 0, "Low: other racers get no after-images and no rings")
	assert(RaceVfx.Plan("High", false).GhostDistance == GHOST.OtherDistance.High and RaceVfx.Plan("High", false).RingDistance == RINGS.OtherDistance.High, "High others: after-images <= 90, rings <= 120 studs")
	assert(high.CpuMs == 0.6 and mid.CpuMs == 0.35 and low.CpuMs == 0.25, "CPU budgets")
	assert(high.ScreenLines == 28 and mid.ScreenLines == 16 and low.ScreenLines == 8, "screen lines 28 / 16 / 8")
	pass("budgets: arcs 6x5 / 4x4 / 2x4 at 20 / 12 / 8 Hz, after-images every 0.05 / 0.08 / 0.12 s (pools 7 / 5 / 3), rings 8 / 5 / 3; others 2 / 1 / 0 arcs on the nearest 6 / 3 / 0, after-images on the nearest 3 / 1 / 0; no particles, bubbles or Glass")
end

----------------------------------------------------------------------
-- 3. Tiers and the FPS meter
----------------------------------------------------------------------
do
	local C = RaceFeelTier.Classify
	assert(C(false, 60, nil) == "High" and C(false, 45, nil) == "High", "PC/console >= 45 = High")
	assert(C(false, 44, nil) == "Mid" and C(false, 25, nil) == "Mid" and C(false, 24, nil) == "Low", "any device 25-45 Mid, < 25 Low")
	assert(C(true, 60, nil) == "Mid" and C(true, 30, nil) == "Mid" and C(true, 29, nil) == "Low" and C(true, 24, nil) == "Low", "touch-only never High; < 30 Low")
	assert(C(false, 120, 3) == "Low" and C(false, 120, 4) == "High" and C(false, 120, nil) == "High", "quality <= 3 by hand = Low")
	assert(C(true, nil, nil) == "Low" and C(false, nil, nil) == "Mid", "no reading yet: phones Low, others Mid")
	assert(RaceFeelTier.HandQuality(0) == nil and RaceFeelTier.HandQuality(3) == 3 and RaceFeelTier.HandQuality(0 / 0) == nil, "Automatic (0) is not a hand setting")
	local meter = RaceFeelTier.NewMeter()
	for _ = 1, 30 do
		RaceFeelTier.Sample(meter, 1 / 24)
	end
	assert(RaceFeelTier.Reading(meter) == nil, "under 2 s: no reading")
	for _ = 1, 30 do
		RaceFeelTier.Sample(meter, 1 / 24)
	end
	RaceFeelTier.Sample(meter, 5)
	RaceFeelTier.Sample(meter, 0 / 0)
	local fps = RaceFeelTier.Reading(meter)
	assert(fps and math.abs(fps - 24) < 0.5, "EMA of 1/dt reads 24 FPS")
	local tier = RaceFeelTier.Detect(meter)
	assert(tier == "Mid" or tier == "Low", "Detect works without a game")
	pass("tiers: High >= 45 (not touch-only), Mid 25-45 / touch >= 30, Low below or quality <= 3; the meter is an EMA over >= 2 s")
end

----------------------------------------------------------------------
-- 4. Prewarm builds the plan; the hot path builds nothing; the cosmetics stay on; Release
----------------------------------------------------------------------
do
	for _, case in { { "High", true }, { "Mid", true }, { "Low", true }, { "High", false }, { "Mid", false }, { "Low", false } } do
		local tier, isLocal = case[1], case[2]
		local label = tier .. " " .. (if isLocal then "own" else "other")
		RaceVfx.ReleaseAll()
		resetCount()
		local character = newCharacter("Pre" .. tier .. (if isLocal then "Own" else "Other"), 0)
		local cosmeticsBefore = cosmeticsState(character)
		local entry = RaceVfx.Prewarm(character, tier, isLocal)
		assert(entry, "Prewarm " .. label)
		local plan = entry.Plan
		local want = RaceVfx.PlanCounts(plan, 6)
		local shared = RaceVfx.SharedCounts(plan, 6)
		assert(arcPoints(character) == want.Attachment, label .. ": " .. want.Attachment .. " arc attachments on the body")
		assert(#descendantsOf("Beam", entry.Folder) == want.Beam, label .. ": " .. want.Beam .. " arc beams")
		assert(#descendantsOf("PointLight", character) == want.PointLight and #descendantsOf("Sound", character) == want.Sound, label .. ": light and sounds")
		-- The after-images: body parts only, the sprint's dark shadow (2026-09-26, owner: SmoothPlastic,
		-- Color3.fromRGB(28, 17, 38)), quiet, parked invisible at the racer.
		local ghostParts = 0
		for _, ghost in entry.Ghosts do
			for _, part in ghost.Parts do
				ghostParts += 1
				assert(BODY[part.Name], label .. ": a silhouette of a body part, not " .. part.Name)
				assert(part.Material == rb.Enum.Material.SmoothPlastic, "after-images are SmoothPlastic (the sprint's shadow)")
				assert(part.Color:ToHex() == rb.Color3.fromRGB(28, 17, 38):ToHex(), "after-images are the sprint's dark shadow colour")
				assert(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery and not part.CastShadow, "after-images are quiet")
				assert(part.Transparency == 1 and math.abs(part.CFrame.Position.Y - Y0) < 6, "parked invisible at the racer")
				for _, child in part:GetChildren() do
					assert(child:IsA("SpecialMesh") and child.TextureId == "", label .. ": nothing inside a silhouette but an untextured head mesh (" .. child.ClassName .. ")")
				end
			end
		end
		assert(#entry.Ghosts == plan.GhostPool and ghostParts == want.GhostParts, label .. ": " .. plan.GhostPool .. " after-images of 6 parts")
		-- The shared pools.
		local pools = RaceVfx.Shared()
		assert(#pools.Rings == shared.RingParts, label .. ": " .. shared.RingParts .. " rings")
		for _, ring in pools.Rings do
			assert(#ring.Points == 4 and #ring.Beams == 4 and ring.Part.Transparency == 1 and not ring.Part.CanCollide and not ring.Part.CanQuery, "a ring: an invisible holder, 4 points, 4 beams")
		end
		assert(#pools.Others == (if isLocal then 0 else shared.OtherGhosts), label .. ": the others' shared after-images")
		for _, ghost in pools.Others do
			for _, part in ghost.Parts do
				assert(part.Material == rb.Enum.Material.SmoothPlastic and part.Color:ToHex() == RaceVfx.GhostColor:ToHex(),
					label .. ": the others' after-images are the dark shadow too")
			end
		end
		-- No particle, sparkle, trail, highlight or Glass made; every beam untextured and glowing.
		for _, className in { "ParticleEmitter", "Sparkles", "Trail", "Highlight", "Fire", "Smoke", "MeshPart", "WedgePart" } do
			assert(created[className] == nil, label .. ": Prewarm made a " .. className)
		end
		for _, beam in descendantsOf("Beam", fxFolder) do
			assert(beam.LightEmission == 1 and beam.LightInfluence == 0 and beam.Enabled == false, "beams glow and start off")
			local ok, texture = pcall(function()
				return beam.Texture
			end)
			assert(not ok or texture == "", "beams are untextured (solid bands)")
		end
		for _, part in fxFolder:GetDescendants() do
			assert(not part:IsA("BasePart") or part.Material ~= rb.Enum.Material.Glass, "nothing is Glass")
		end
		local before = total()
		assert(RaceVfx.Prewarm(character, tier, isLocal) == entry and total() == before, "a second Prewarm builds nothing")

		-- The hot path: charge held, vent, let go, GO, pads, super speed, the finish, running.
		resetCount()
		RaceVfx.SetCruise(character, 200)
		RaceVfx.SetTint(character, rb.Color3.fromRGB(176, 93, 255), rb.Color3.fromRGB(130, 60, 190), true)
		local shape = #fxFolder:GetDescendants() + #character:GetDescendants()
		for step = 0, 60 do
			RaceVfx.SetCharge(character, step / 50, clockNow, if isLocal then true else nil)
			RaceVfx.Step(DT, EYE, tick(DT))
		end
		for step = 1, 20 do
			RaceVfx.SetCharge(character, 0.6 - step * 0.01, clockNow, if isLocal then false else nil)
			RaceVfx.Step(DT, EYE, tick(DT))
		end
		RaceVfx.Burst(character, "Perfect", clockNow)
		RaceVfx.SetSuper(character, true, clockNow)
		for index = 1, 150 do
			run(character, 5, 300)
			if index % 50 == 0 then
				RaceVfx.PadBoost(character, clockNow)
			end
			RaceVfx.Step(DT, EYE, tick(DT))
		end
		RaceVfx.Finish(character, nil, clockNow)
		RaceVfx.SetSuper(character, false, clockNow)
		frames(1)
		assert(total() == 0, label .. ": nothing built after Prewarm (" .. total() .. ")")
		assert(#fxFolder:GetDescendants() + #character:GetDescendants() == shape, label .. ": the instance tree is unchanged by the hot path")
		-- (2) The owner: the equipped aura and trail stay on and untouched through all of it.
		assert(cosmeticsState(character) == cosmeticsBefore, label .. ": the aura's emitter and the trail are untouched")
		-- The next race on the same character: handed back reset.
		assert(RaceVfx.Prewarm(character, tier, isLocal) == entry and entry.Launched == false and entry.Super == false and entry.ArcBase == "Off", label .. ": reset for the next race")
		for _, ghost in entry.Ghosts do
			assert(not ghost.Alive, label .. ": after-images parked by the reset")
		end
		RaceVfx.Release(character)
		assert(RaceVfx.Get(character) == nil and entry.Folder.Parent == nil, "Release removes the racer's VFX")
		assert(arcPoints(character) == 0 and #descendantsOf("PointLight", character) == 0 and #descendantsOf("Sound", character) == 0, "Release leaves nothing on the character")
		assert(cosmeticsState(character) == cosmeticsBefore, "Release leaves the cosmetics as they were")
	end
	RaceVfx.ReleaseAll()
	assert(RaceVfx.Count() == 0 and not RaceVfx.Active() and #RaceVfx.Shared().Rings == 0, "ReleaseAll clears the shared pools")
	pass("Prewarm per tier: arc attachments on the body, beams, dark SmoothPlastic body-part silhouettes (no accessory, face or joint), shared rings / others' after-images; the hot path builds nothing; the equipped aura and trail stay on and untouched; reset and Release")
end

----------------------------------------------------------------------
-- 5. The arcs: only while held or venting; fuller = more, wider, faster; colours; chains
----------------------------------------------------------------------
local function litShare(entry)
	local lit = 0
	for _, arc in entry.Arcs do
		if arc.On then
			lit += 1
		end
	end
	return lit / math.max(1, #entry.Arcs)
end
local function rootWidth(entry)
	return entry.Arcs[1].Beams[1].Width0
end
local function arcColor(entry)
	local keys = entry.Arcs[1].Beams[1].Color.Keypoints
	return keys[#keys].Value
end
local function sameColor(a, b)
	return math.abs(a.R - b.R) < 0.01 and math.abs(a.G - b.G) < 0.01 and math.abs(a.B - b.B) < 0.01
end
do
	local character = newCharacter("Arcs", 0)
	local entry = RaceVfx.Prewarm(character, "High", true)
	-- Not held: nothing.
	for _ = 1, 30 do
		RaceVfx.SetCharge(character, 0.5, clockNow, false)
		RaceVfx.Step(DT, EYE, tick(DT))
	end
	assert(litShare(entry) == 0, "not held: no arcs")
	-- Held at a low and a high gauge for a second each.
	local function hold(g, seconds)
		local rolls0 = entry.Rolls
		local lit, samples, widest, leap = 0, 0, 0, 0
		local moved = 0
		local last = entry.Arcs[1].Points[2].CFrame
		for _ = 1, math.floor(seconds / DT + 0.5) do
			RaceVfx.SetCharge(character, g, clockNow, true)
			RaceVfx.Step(DT, EYE, tick(DT))
			lit += litShare(entry)
			samples += 1
			widest = math.max(widest, rootWidth(entry))
			for _, arc in entry.Arcs do
				if arc.On then
					local tip = arc.Points[#arc.Points].CFrame.Position
					local size = arc.Part.Size
					leap = math.max(leap, math.max(math.abs(tip.X) - size.X / 2, math.abs(tip.Z) - size.Z / 2))
				end
			end
			local now = entry.Arcs[1].Points[2].CFrame
			if now ~= last then
				moved += 1
				last = now
			end
		end
		return (entry.Rolls - rolls0) / seconds, lit / samples, widest, leap, moved
	end
	local lowHz, lowLit, lowWidth, lowLeap = hold(0.2, 2)
	assert(sameColor(arcColor(entry), RaceVfx.BoltColor), "below the zone the arcs are cyan")
	local zoneHz = hold((U4.Race.Charge.ZoneLo + U4.Race.Charge.ZoneHi) / 2, 0.5)
	assert(sameColor(arcColor(entry), COLORS.Burst), "inside the zone the arcs are gold-white (let go now)")
	assert(entry.Light and entry.Light.Enabled, "High own: the torso glows inside the zone")
	local highHz, highLit, highWidth, highLeap, moved = hold(0.97, 2)
	assert(lowHz > 8 and lowHz < 16 and highHz > 17 and highHz < 23, string.format("re-rolled %.1f -> %.1f times a second (High: 20 at full)", lowHz, highHz))
	assert(highLit > lowLit + 0.25 and highWidth > lowWidth * 1.8 and highLeap > lowLeap + 0.3,
		string.format("fuller = more lit (%.2f -> %.2f), wider (%.3f -> %.3f), leaping further (%.2f -> %.2f)", lowLit, highLit, lowWidth, highWidth, lowLeap, highLeap))
	assert(moved >= 20, "the chains' points jump at every re-roll")
	-- The chains: consecutive attachments, tapering widths.
	for _, arc in entry.Arcs do
		for k, beam in arc.Beams do
			assert(beam.Attachment0 == arc.Points[k] and beam.Attachment1 == arc.Points[k + 1], "a chain links consecutive points")
			assert(beam.Width1 < beam.Width0 and (k == 1 or near(beam.Width0, arc.Beams[k - 1].Width1, 1e-4)), "a chain tapers continuously")
			assert(beam.Segments == 1 and beam.FaceCamera, "straight camera-facing segments")
		end
		assert(near(arc.Beams[#arc.Beams].Width1, arc.Beams[1].Width0 * LIGHTNING.Taper, 1e-4), "the tip is Taper of the root")
	end
	-- Venting: red. Let go: gone at the next frame.
	RaceVfx.SetCharge(character, 1, tick(DT), true)
	frames(0.2, DT, function()
		RaceVfx.SetCharge(character, 0.98, clockNow, true)
	end)
	assert(entry.Venting and litShare(entry) > 0 and sameColor(arcColor(entry), COLORS.Overheat), "venting crackles red")
	frames(0.7, DT, function()
		RaceVfx.SetCharge(character, 0.6, clockNow, false)
	end)
	assert(litShare(entry) == 0 and not entry.Light.Enabled, "let go: the arcs and the glow go at once")
	-- Super speed: calmer, in the aura's colour.
	RaceVfx.Burst(character, "Ok", tick(DT))
	frames(0.5)
	local aura = rb.Color3.fromRGB(255, 72, 72)
	RaceVfx.SetTint(character, aura, aura, true)
	RaceVfx.SetSuper(character, true, tick(DT))
	local rolls0 = entry.Rolls
	frames(1)
	local superHz = entry.Rolls - rolls0
	assert(superHz >= 10 and superHz <= 14 and sameColor(arcColor(entry), aura), string.format("super speed: calmer (%d re-rolls a second) in the aura's colour", superHz))
	RaceVfx.SetSuper(character, false, tick(DT))
	frames(0.1)
	assert(litShare(entry) == 0, "off when super speed ends")
	RaceVfx.ReleaseAll()

	-- Others: the hold read from the level rising; only the nearest OthersArcCap; not far ones.
	local own = newCharacter("ArcsOwn", 0)
	RaceVfx.Prewarm(own, "High", true)
	local others = {}
	for index = 1, 8 do
		others[index] = newCharacter("ArcsOther" .. index, index * 3)
		RaceVfx.Prewarm(others[index], "High", false)
	end
	local far = newCharacter("ArcsFar", 200)
	RaceVfx.Prewarm(far, "High", false)
	local level = 0
	local peak = 0
	for step = 1, 90 do
		if step % 15 == 1 then
			level = math.min(9, level + 1)
		end
		for _, character in others do
			RaceVfx.SetCharge(character, level / 10, clockNow)
		end
		RaceVfx.SetCharge(far, level / 10, clockNow)
		RaceVfx.Step(DT, EYE, tick(DT))
		local showing = 0
		for _, character in others do
			if litShare(RaceVfx.Get(character)) > 0 then
				showing += 1
			end
		end
		peak = math.max(peak, showing)
		assert(litShare(RaceVfx.Get(far)) == 0, "a racer beyond 90 studs shows no arcs")
	end
	assert(peak >= 4 and peak <= RaceFeelTier.Budget("High").OthersArcCap, "only the nearest 6 others crackle (" .. peak .. ")")
	assert(RaceVfx.Get(others[1]).Charge.Held, "another racer's rising level = held")
	for _ = 1, 40 do
		for _, character in others do
			RaceVfx.SetCharge(character, level / 10, clockNow)
		end
		RaceVfx.Step(DT, EYE, tick(DT))
	end
	assert(litShare(RaceVfx.Get(others[1])) == 0, "a level that stops rising = let go: no arcs")
	RaceVfx.ReleaseAll()
	pass(string.format("arcs: only while held / venting; %.0f -> %.0f re-rolls/s, lit %.0f%% -> %.0f%%, width %.2f -> %.2f from g 0.2 to 0.97 (zone %.0f/s); cyan / gold in the zone / red venting; tapered chains; super calmer in the aura colour; the nearest %d others", lowHz, highHz, 100 * lowLit, 100 * highLit, lowWidth, highWidth, zoneHz, peak))
end

----------------------------------------------------------------------
-- 6. GO: the Sonic Boom (LaunchPunch, rings, arc flash, light); rings are circles
----------------------------------------------------------------------
local function aliveRings()
	local n = 0
	for _, ring in RaceVfx.Shared().Rings do
		if ring.Alive then
			n += 1
		end
	end
	return n
end
do
	local punch = {}
	for _, grade in { "Perfect", "Good", "Ok", "Stall" } do
		punch[grade] = RaceVfx.LaunchPunch(grade, false)
	end
	assert(near(punch.Perfect.Fov, 18) and near(punch.Perfect.ShakeSeconds, 0.3) and near(punch.Perfect.ShakeStrength, 1.5), "Perfect: CameraPunch.Fov(18), Shake(0.3, 1.5)")
	assert(near(punch.Good.Fov, 10.8) and near(punch.Good.ShakeStrength, 0.9) and near(punch.Ok.Fov, 5.4) and near(punch.Ok.ShakeStrength, 0.45), "Good 0.6 and Ok 0.3 of it")
	assert(punch.Stall.Fov == 0 and punch.Stall.ShakeStrength == 0 and punch.Stall.ShakeSeconds == 0 and punch.Stall.Share == 0, "Stall: no punch")
	local reduced = RaceVfx.LaunchPunch("Perfect", true)
	assert(near(reduced.Fov, 9) and reduced.ShakeStrength == 0, "reduced motion: half the punch, no shake")

	local results = {}
	for _, grade in { "Perfect", "Good", "Ok", "Stall" } do
		RaceVfx.ReleaseAll()
		local character = newCharacter("Go" .. grade, 0)
		local entry = RaceVfx.Prewarm(character, "High", true)
		frames(0.3, DT, function()
			RaceVfx.SetCharge(character, 0.7, clockNow, true)
		end)
		local start = clockNow
		RaceVfx.Burst(character, grade, clockNow)
		local lightPeak = if entry.Light and entry.Light.Enabled then entry.Light.Brightness else 0
		RaceVfx.Step(DT, EYE, tick(DT))
		local flashLit = litShare(entry)
		local rings = aliveRings()
		local maxRadius, radii, fades = 0, {}, {}
		local ringOne = nil
		for _, ring in RaceVfx.Shared().Rings do
			if ring.Alive and (not ringOne or ring.Start < ringOne.Start) then
				ringOne = ring
			end
		end
		for _ = 1, 50 do
			RaceVfx.Step(DT, EYE, tick(DT))
			if ringOne and ringOne.Alive and ringOne.Placed then
				local r = ringOne.Points[1].CFrame.Position.Magnitude
				table.insert(radii, r)
				local keys = ringOne.Beams[1].Transparency.Keypoints
				table.insert(fades, keys[1].Value)
				maxRadius = math.max(maxRadius, r)
				-- A true circle: every point at r, flat, with Bezier handles of r x 0.5523.
				for _, point in ringOne.Points do
					local p = point.CFrame.Position
					assert(near(p.Magnitude, r, 1e-3) and near(p.Y, 0, 1e-4), "ring points on a circle in the holder's plane")
				end
				assert(near(ringOne.Beams[1].CurveSize0, r * RaceVfx.CurveK, 1e-3) and near(ringOne.Beams[1].CurveSize1, r * RaceVfx.CurveK, 1e-3), "Bezier quarter-circle handles")
				local feet = entry.Root.CFrame.Position.Y - RaceVfx.FeetDrop
				assert(near(ringOne.Part.CFrame.Position.Y, feet, 0.01), "the GO ring lies on the ground at the feet")
			end
		end
		local grows, fading = true, true
		for index = 2, #radii do
			grows = grows and radii[index] >= radii[index - 1] - 1e-6
			fading = fading and fades[index] >= fades[index - 1] - 1e-6
		end
		results[grade] = { Rings = rings, Radius = maxRadius, Lit = flashLit, Light = lightPeak }
		if grade == "Stall" then
			assert(rings == 0 and sameColor(arcColor(entry), COLORS.Overheat), "Stall: no ring, a red sputter")
		else
			local look = RINGS.Go[grade]
			assert(rings == look.Count, grade .. ": " .. look.Count .. " ring(s)")
			assert(grows and fading and maxRadius > look.R1 * 0.8 and maxRadius <= look.R1 + 1e-3, string.format("%s: the ring grows to %.1f (R1 %d) and fades", grade, maxRadius, look.R1))
			assert(flashLit == 1, grade .. ": every arc flashes at GO")
			assert(entry.GhostBurstUntil > start + GHOST.BurstSeconds[grade] - 0.05, grade .. ": a burst of after-images")
		end
		assert(aliveRings() == 0, grade .. ": the rings are gone within their life")
		assert(litShare(entry) == 0, grade .. ": the flash ends")
		if entry.Light then
			assert(not entry.Light.Enabled and near(entry.Light.Range, RaceVfx.LightRange), "the light flash is over")
		end
	end
	assert(results.Perfect.Radius > results.Good.Radius and results.Good.Radius > results.Ok.Radius, "Perfect > Good > Ok")
	assert(results.Perfect.Light >= RaceVfx.FlashBrightness - 1e-6 and results.Good.Light < results.Perfect.Light, "the torso light flashes by the grade")

	-- The finish: a gate of rings across the track (points in one plane of constant Z).
	RaceVfx.ReleaseAll()
	local character = newCharacter("Finish", 0)
	RaceVfx.Prewarm(character, "High", true)
	local line = rb.CFrame.new(3, Y0 + 3, -2000)
	RaceVfx.Finish(character, line, clockNow)
	frames(0.1)
	local gate = nil
	for _, ring in RaceVfx.Shared().Rings do
		if ring.Alive and ring.Placed then
			gate = ring
		end
	end
	assert(gate and (gate.Part.CFrame.Position - line.Position).Magnitude < 1e-3, "the finish ring stands on the line")
	local ys, xs = {}, {}
	for _, point in gate.Points do
		local world = gate.Part.CFrame * point.CFrame
		assert(near(world.Position.Z, line.Position.Z, 1e-2), "the finish ring is a gate across the track (constant Z)")
		table.insert(xs, world.Position.X)
		table.insert(ys, world.Position.Y)
	end
	assert(math.max(table.unpack(ys)) - math.min(table.unpack(ys)) > 2 and math.max(table.unpack(xs)) - math.min(table.unpack(xs)) > 2, "...spanning up and across")
	assert(aliveRings() == RINGS.Finish.Count, "two finish rings")
	-- The pool never grows: 20 pads in a row recycle the oldest rings.
	for _ = 1, 20 do
		RaceVfx.PadBoost(character, clockNow)
		RaceVfx.Step(DT, EYE, tick(DT))
	end
	assert(#RaceVfx.Shared().Rings == RINGS.Pool.High and aliveRings() <= RINGS.Pool.High, "the ring pool is fixed (the oldest is recycled)")
	frames(1)
	-- Reduced motion: one smaller ring, no light flash.
	RaceVfx.SetReducedMotion(true)
	RaceVfx.ReleaseAll()
	character = newCharacter("GoReduced", 0)
	local entry = RaceVfx.Prewarm(character, "High", true)
	RaceVfx.Burst(character, "Perfect", clockNow)
	local reducedRadius = 0
	for _ = 1, 40 do
		RaceVfx.Step(DT, EYE, tick(DT))
		for _, ring in RaceVfx.Shared().Rings do
			if ring.Alive and ring.Placed then
				reducedRadius = math.max(reducedRadius, ring.Points[1].CFrame.Position.Magnitude)
			end
		end
		assert(aliveRings() <= 1, "reduced motion: one ring")
	end
	assert(reducedRadius < RINGS.Go.Perfect.R1 * 0.75 and not entry.Light.Enabled, "reduced motion: a smaller ring, no light flash")
	RaceVfx.SetReducedMotion(false)
	RaceVfx.ReleaseAll()
	pass(string.format("GO: LaunchPunch Perfect Fov 18 + Shake(0.3, 1.5), Good x0.6, Ok x0.3, Stall none (reduced: half, no shake); rings Perfect 2 to %.1f, Good 1 to %.1f, Ok 1 to %.1f, Stall none; true circles; every arc flashes; the finish is a gate across the track; fixed pool", results.Perfect.Radius, results.Good.Radius, results.Ok.Radius))
end

----------------------------------------------------------------------
-- 7. After-images: cadence, threshold, fade, colours, pool, the nearest others, switches
----------------------------------------------------------------------
do
	-- The fade and the threshold (pure).
	local life = 0.3
	assert(near(RaceVfx.GhostTransparency(0, life), 0.3) and near(RaceVfx.GhostTransparency(0.15, life), 0.7) and RaceVfx.GhostTransparency(0.3, life) == 1, "0.3 -> 0.7 -> 1")
	local previous = 0
	for step = 0, 30 do
		local t = RaceVfx.GhostTransparency(step / 100, life)
		assert(t >= previous - 1e-9, "the fade never goes back")
		previous = t
	end
	local cruise = 250
	assert(not RaceVfx.GhostsWanted(cruise * 1.1, cruise, false, false) and RaceVfx.GhostsWanted(cruise * GHOST.SpeedFrom, cruise, false, false),
		"after-images from SpeedFrom x the racer's own cruise")
	assert(RaceVfx.GhostsWanted(40, cruise, true, false) and RaceVfx.GhostsWanted(40, cruise, false, true) and not RaceVfx.GhostsWanted(5, cruise, true, true),
		"...or in a burst window / at super speed, never standing still")
	assert(not RaceVfx.GhostsWanted(0 / 0, cruise, false, false), "NaN speed: none")

	-- 2026-09-26 (owner): the after-images are the sprint's dark shadow (R15SpeedsterRun's
	-- AFTERIMAGE_COLOR, SmoothPlastic), never the aura's or the race's gold tints.
	local sprint = fs.readFile("src/common/StarterPlayer/StarterCharacterScripts/R15SpeedsterRun.client.luau")
	local sr, sg, sb = string.match(sprint, "local AFTERIMAGE_COLOR = Color3%.fromRGB%((%d+), (%d+), (%d+)%)")
	assert(sr and RaceVfx.GhostColor:ToHex() == rb.Color3.fromRGB(tonumber(sr), tonumber(sg), tonumber(sb)):ToHex()
		and RaceVfx.GhostColor:ToHex() == rb.Color3.fromRGB(28, 17, 38):ToHex(), "GhostColor is the sprint's after-image colour (28, 17, 38)")
	assert(GHOST.Material == "SmoothPlastic" and GHOST.Color[1] == 28 and GHOST.Color[2] == 17 and GHOST.Color[3] == 38,
		"Update4Config AfterImage: SmoothPlastic, Color { 28, 17, 38 }")
	assert(GHOST.Transparency[1] == 0.3 and GHOST.Transparency[2] == 0.7 and GHOST.Transparency[3] == 1, "fading 0.3 -> 0.7 -> 1")
	assert(RaceVfx.GhostColors == nil, "no after-image colours from the aura any more (GhostColors is gone)")
	-- The super-speed arcs still take the aura's colours (AuraColors, fed to SetTint).
	local Catalog = luau.load(fs.readFile(SHARED .. "CosmeticCatalog.luau"), { environment = setmetatable({ Color3 = rb.Color3 }, { __index = _G }) })()
	local auraEntry = Catalog.GetEntry("Aura", "Aura01")
	local trailEntry = Catalog.GetEntry("Trail", "Trail01")
	local c1, c2, isAura = RaceVfx.AuraColors(auraEntry, trailEntry)
	assert(isAura and c1 == auraEntry.ThemeColor and sameColor(c2, auraEntry.ThemeColor:Lerp(auraEntry.ThemeDarkColor, 0.5)), "the arcs: the aura's ThemeColor and a darker half")
	local t1, _, trailIsAura = RaceVfx.AuraColors(nil, trailEntry)
	assert(t1 == trailEntry.ThemeColor and not trailIsAura, "no aura: the trail's colours")
	local f1, f2 = RaceVfx.AuraColors(nil, nil)
	assert(f1 == COLORS.Burst and f2 == RaceVfx.BoltColor, "neither: the race's gold and bolt colours")

	-- The cadence per tier (own racer), running at 1.5x their cruise.
	local counts = {}
	for _, tier in { "High", "Mid", "Low" } do
		RaceVfx.ReleaseAll()
		local character = newCharacter("Ghost" .. tier, 0)
		local entry = RaceVfx.Prewarm(character, tier, true)
		RaceVfx.SetCruise(character, 200)
		RaceVfx.SetTint(character, c1, c2, true)
		RaceVfx.Burst(character, "Ok", clockNow)
		frames(0.5) -- standing: the Ok burst window passes with no speed
		assert(entry.Stamps == 0, tier .. ": no after-images standing still")
		local dt = 1 / 120
		local stamps0 = entry.Stamps
		local maxAlive, sampledHalf = 0, nil
		local colors = {}
		for _ = 1, 120 do
			run(character, 300 * dt, 300)
			RaceVfx.Step(dt, EYE, tick(dt))
			local alive = 0
			for _, ghost in entry.Ghosts do
				if ghost.Alive then
					alive += 1
					local age = clockNow - ghost.Born
					if not sampledHalf and math.abs(age - ghost.Life / 2) < 0.006 then
						sampledHalf = ghost.Parts[1].Transparency
					end
				end
			end
			maxAlive = math.max(maxAlive, alive)
		end
		local stamps = entry.Stamps - stamps0
		counts[tier] = stamps
		local every = entry.Plan.GhostEvery
		assert(math.abs(stamps - 1 / every) <= 1.5, string.format("%s: %d stamps in 1 s (every %.2f s)", tier, stamps, every))
		assert(#entry.Ghosts == entry.Plan.GhostPool and maxAlive <= entry.Plan.GhostPool, tier .. ": a fixed pool")
		assert(sampledHalf and math.abs(sampledHalf - 0.7) <= 0.051, tier .. ": ~0.7 at half its life (" .. tostring(sampledHalf) .. ")")
		-- The newest: at the body parts' frames, 0.3, the dark shadow whatever the aura (SetTint above).
		RaceVfx.Step(dt, EYE, tick(every))
		local newest = nil
		for _, ghost in entry.Ghosts do
			if ghost.Alive and (not newest or ghost.Born > newest.Born) then
				newest = ghost
			end
		end
		assert(newest and clockNow - newest.Born < 1e-6, tier .. ": stamped this frame")
		for name, part in newest.ByName do
			assert((part.CFrame.Position - character[name].CFrame.Position).Magnitude < 1e-3, tier .. ": a silhouette where the body part is")
			assert(near(part.Transparency, 0.3, 1e-4), tier .. ": a fresh after-image at 0.3")
			colors[part.Color:ToHex()] = true
		end
		RaceVfx.Step(dt, EYE, tick(every))
		for _, ghost in entry.Ghosts do
			if ghost.Alive and clockNow - ghost.Born < 1e-6 then
				colors[ghost.Parts[1].Color:ToHex()] = true
			end
		end
		local shadow = RaceVfx.GhostColor:ToHex()
		for hex in colors do
			assert(hex == shadow, tier .. ": an after-image in " .. hex .. ", not the sprint's dark shadow " .. shadow)
		end
		assert(colors[shadow] and not colors[c1:ToHex()] and not colors[c2:ToHex()], tier .. ": the dark shadow, never the aura's colours")
		for _, ghost in entry.Ghosts do
			for _, part in ghost.Parts do
				assert(part.Material == rb.Enum.Material.SmoothPlastic, tier .. ": SmoothPlastic")
			end
		end
		-- Under the threshold (1.05x): none; the kill switch: none and all parked.
		for _ = 1, 30 do
			run(character, 210 * dt, 210)
			RaceVfx.Step(dt, EYE, tick(dt))
		end
		local slow = entry.Stamps
		frames(0.5, dt, function(step)
			run(character, 210 * step, 210)
		end)
		assert(entry.Stamps == slow, tier .. ": no after-images at 1.05x the cruise")
		RaceVfx.SetEnabled({ All = true, Ghosts = false })
		frames(0.3, dt, function(step)
			run(character, 300 * step, 300)
		end)
		assert(entry.Stamps == slow, tier .. ": the Ghosts kill switch stops them")
		for _, ghost in entry.Ghosts do
			assert(not ghost.Alive and ghost.Parts[1].Transparency == 1, "...and hides the ones showing")
		end
		RaceVfx.SetEnabled({ All = true, Ghosts = true })
	end
	RaceVfx.ReleaseAll()

	-- Others: only the nearest OthersGhostCap stamp (High 3, Mid 1), Low none.
	for _, tier in { "High", "Mid", "Low" } do
		RaceVfx.ReleaseAll()
		local own = newCharacter("GhostOwn" .. tier, 0)
		RaceVfx.Prewarm(own, tier, true)
		local list = {}
		for index = 1, 5 do
			list[index] = newCharacter("GhostOther" .. tier .. index, index * 4)
			RaceVfx.Prewarm(list[index], tier, false)
			RaceVfx.SetCruise(list[index], 200)
		end
		-- The camera follows the pack (a chase camera 15 studs behind).
		for _ = 1, 18 do
			for _, character in list do
				run(character, 300 / 60, 300)
			end
			local eye = list[1].Torso.CFrame.Position + rb.Vector3.new(0, 5, 15)
			RaceVfx.Step(1 / 60, eye, tick(1 / 60))
		end
		local stamping = 0
		for index, character in list do
			local entry = RaceVfx.Get(character)
			if entry.Stamps > 0 then
				stamping += 1
				assert(index <= RaceVfx.Plan(tier, false).OthersGhostCap, tier .. ": only the nearest stamp")
			end
		end
		assert(stamping == RaceVfx.Plan(tier, true).OthersGhostCap, string.format("%s: %d nearest others leave after-images", tier, stamping))
		assert(#RaceVfx.Shared().Others == RaceVfx.Plan(tier, true).OthersGhostPool, tier .. ": the others' shared pool")
	end
	-- The whole kill switch: arcs, rings and after-images away at once.
	RaceVfx.ReleaseAll()
	local character = newCharacter("KillAll", 0)
	local entry = RaceVfx.Prewarm(character, "High", true)
	RaceVfx.Burst(character, "Perfect", clockNow)
	frames(0.1, DT, function(step)
		run(character, 300 * step, 300)
	end)
	assert(aliveRings() > 0 and entry.Stamps > 0, "before the switch: rings and after-images")
	RaceVfx.SetEnabled({ All = false })
	frames(0.3, DT, function(step)
		run(character, 300 * step, 300)
	end)
	assert(aliveRings() == 0 and litShare(entry) == 0 and not entry.Light.Enabled, "U4Off_RaceFx: nothing shows")
	for _, ghost in entry.Ghosts do
		assert(not ghost.Alive, "U4Off_RaceFx: no after-images")
	end
	RaceVfx.SetEnabled({ All = true, Ghosts = true })
	RaceVfx.ReleaseAll()
	pass(string.format("after-images: %d / %d / %d stamps a second on High / Mid / Low at 1.5x the own cruise, none at 1.05x or standing; 0.3 -> 0.7 -> 1; the sprint's dark shadow (28, 17, 38, SmoothPlastic) whatever the aura, the arcs keep the aura's colours; fixed pools; the nearest 3 / 1 / 0 others; kill switches", counts.High, counts.Mid, counts.Low))
end

----------------------------------------------------------------------
-- 8. RaceScreenFx: speed lines, vignette, shock rings
----------------------------------------------------------------------
do
	local lines, vignette = RaceScreenFx.Levels(1, 70)
	assert(lines == 0 and vignette == 0, "at the own cruise and 70: nothing")
	assert(RaceScreenFx.Levels(SCREEN.LinesFrom, 70) == 0 and RaceScreenFx.Levels(SCREEN.LinesFull, 70) == 1, "lines from LinesFrom to LinesFull x the cruise")
	local mid = RaceScreenFx.Levels((SCREEN.LinesFrom + SCREEN.LinesFull) / 2, 70)
	assert(near(mid, 0.5, 1e-6), "half-way: half the lines")
	local _, wide = RaceScreenFx.Levels(1, SCREEN.FovFull)
	assert(wide > 0.4 and wide < 0.5, "the vignette follows the FOV")
	assert(RaceScreenFx.Levels(0 / 0, 0 / 0) == 0, "NaN: nothing")
	for _, tier in { "High", "Mid", "Low" } do
		local parent = rb.Instance.new("Folder")
		parent.Name = "PlayerGui"
		resetCount()
		local state = RaceScreenFx.Prewarm(parent, tier)
		local gui = parent:FindFirstChild(RaceScreenFx.GuiName)
		assert(state and gui and gui:IsA("ScreenGui") and gui.Enabled == false and gui.DisplayOrder < 60 and gui.IgnoreGuiInset, tier .. ": the ScreenGui under RaceHud, off until shown")
		assert(#state.Lines == SCREEN.Lines[tier] and #state.Rings == SCREEN.ShockRings[tier] and #state.Edges == 4, tier .. ": lines, shock rings, four edges")
		for _, className in { "ImageLabel", "ImageButton", "ParticleEmitter" } do
			assert(#descendantsOf(className, gui) == 0, "no " .. className)
		end
		assert(RaceScreenFx.Prewarm(parent, tier) == state, "a second Prewarm builds nothing")
		resetCount()
		local shape = #gui:GetDescendants()
		RaceScreenFx.Show(true)
		assert(gui.Enabled, "shown")
		local viewport = rb.Vector2.new(1280, 720)
		local centre = viewport * 0.5
		local function visibleLines()
			local n = 0
			for _, line in state.Lines do
				if line.Frame.Visible then
					n += 1
				end
			end
			return n
		end
		local ratio = 1.3
		local level = RaceScreenFx.Levels(ratio, 90)
		local outward, checks = 0, 0
		local lastDistance = {}
		for _ = 1, 60 do
			RaceScreenFx.Step(1 / 60, { Ratio = ratio, Fov = 90, Viewport = viewport, Now = tick(1 / 60) })
			for index, line in state.Lines do
				if line.Frame.Visible then
					local p = line.Frame.Position
					local d = (rb.Vector2.new(p.X.Offset, p.Y.Offset) - centre).Magnitude
					if lastDistance[index] and d ~= lastDistance[index] then
						checks += 1
						if d > lastDistance[index] then
							outward += 1
						end
					end
					lastDistance[index] = d
				end
			end
		end
		assert(visibleLines() == RaceScreenFx.LineCount(#state.Lines, level), tier .. ": lines for the speed")
		assert(checks > 0 and outward / checks > 0.8, tier .. ": the lines fly outward")
		local edge = state.Edges[1]
		assert(edge.BackgroundTransparency < 0.9 and edge.BackgroundTransparency > 1 - SCREEN.VignetteAlpha - 1e-6, tier .. ": the vignette darkens with the speed")
		RaceScreenFx.Step(1 / 60, { Ratio = ratio, Fov = 90, Super = true, Viewport = viewport, Now = tick(1 / 60) })
		assert(edge.BackgroundColor3 == RaceScreenFx.Colors.Super, tier .. ": cyan at super speed")
		-- At the cruise: the lines go.
		RaceScreenFx.Step(1 / 60, { Ratio = 1, Fov = 70, Viewport = viewport, Now = tick(1 / 60) })
		assert(visibleLines() == 0, tier .. ": no lines at the cruise")
		-- The Sonic Boom on the screen.
		RaceScreenFx.Shock(1, clockNow)
		local sizes = {}
		local strokeFade = {}
		for _ = 1, 20 do
			RaceScreenFx.Step(1 / 60, { Ratio = 1, Fov = 70, Viewport = viewport, Now = tick(1 / 60) })
			local ring = state.Rings[1]
			if ring.Frame.Visible then
				table.insert(sizes, ring.Frame.Size.X.Offset)
				table.insert(strokeFade, ring.Stroke.Transparency)
			end
		end
		assert(#sizes > 5 and sizes[#sizes] > sizes[1] * 2 and strokeFade[#strokeFade] > strokeFade[1], tier .. ": the shock ring races out and fades")
		RaceScreenFx.Step(1 / 60, { Ratio = 1, Fov = 70, Viewport = viewport, Now = tick(SCREEN.ShockSeconds) })
		RaceScreenFx.Step(1 / 60, { Ratio = 1, Fov = 70, Viewport = viewport, Now = tick(0.2) })
		for _, ring in state.Rings do
			assert(not ring.Frame.Visible, tier .. ": gone after ShockSeconds")
		end
		-- Reduced motion: no lines, no ring.
		RaceScreenFx.SetReducedMotion(true)
		RaceScreenFx.Shock(1, clockNow)
		for _ = 1, 10 do
			RaceScreenFx.Step(1 / 60, { Ratio = 1.5, Fov = 100, Viewport = viewport, Now = tick(1 / 60) })
		end
		assert(visibleLines() == 0 and not state.Rings[1].Frame.Visible, tier .. ": reduced motion: no lines, no ring")
		RaceScreenFx.SetReducedMotion(false)
		assert(total() == 0 and #gui:GetDescendants() == shape, tier .. ": nothing built by Step / Shock / Show")
		-- The kill switch.
		RaceScreenFx.SetEnabled(false)
		assert(not gui.Enabled and not RaceScreenFx.IsShown(), tier .. ": U4Off_RaceScreen hides it")
		RaceScreenFx.Show(true)
		assert(not gui.Enabled, tier .. ": and keeps it hidden")
		RaceScreenFx.SetEnabled(true)
		RaceScreenFx.Show(false)
		RaceScreenFx.Release()
		assert(gui.Parent == nil, "Release")
	end
	pass("RaceScreenFx: speed lines from 1.05 to 1.4x the own cruise, flying outward, 28 / 16 / 8 per tier; the vignette with speed and FOV (cyan at super speed); a shock ring racing out; reduced motion and the kill switch; nothing built after Prewarm")
end

----------------------------------------------------------------------
-- 9. The charge watch predicts the grade like RaceChargeMath
----------------------------------------------------------------------
do
	local C = U4.Race.Charge
	local function runWatch(profile, grace)
		local watch = RaceVfx.NewChargeWatch()
		local goAt = 10
		local t = goAt - 3
		while t <= goAt + 1e-9 do
			RaceVfx.WatchCharge(watch, profile(t, goAt), t, goAt)
			t += 1 / 30
		end
		return RaceVfx.PredictGrade(watch, grace), watch
	end
	assert(runWatch(function()
		return (C.CoreLo + C.CoreHi) / 2
	end) == "Perfect", "held in the core for the whole window = Perfect")
	local good = runWatch(function(t, goAt)
		return if t < goAt - 0.9 then 0.3 else (C.ZoneLo + C.ZoneHi) / 2
	end)
	assert(good == "Good" or good == "Ok", "late into the zone = Good/Ok")
	local stall, watch = runWatch(function(t, goAt)
		return if t < goAt - 0.5 then 0.5 else 1
	end)
	assert(stall == "Stall" and watch.VentedLate, "overheating in the last 0.75 s = Stall")
	assert(runWatch(function(t, goAt)
		return if t < goAt - 0.5 then 0.5 else 1
	end, true) == "Ok", "grace turns Stall into Ok")
	assert(runWatch(function()
		return 0
	end) == "Ok", "no charge = Ok")
	pass("the local grade prediction: core = Perfect, late overheat = Stall (grace Ok), nothing = Ok")
end

----------------------------------------------------------------------
-- 10. Sounds, config, the client contracts
----------------------------------------------------------------------
do
	local LIVE = { ["9114277757"] = true, ["72264591133889"] = true, ["9114615010"] = true, ["9119382815"] = true,
		["90156573887604"] = true } -- PadWhoosh (the owner's upload, 2026-09-26)
	for key, id in FEEL.Sounds do
		local number = string.match(id, "^rbxassetid://(%d+)$")
		assert(id == "" or (number and LIVE[number]), "Feel.Sounds." .. key .. " is empty or a live id: " .. id)
	end
	assert(FEEL.Sounds.SuperWind == "", "no wind sound until the owner uploads one")
	assert(not string.find(stripComments(VFX_SOURCE), "rbxassetid://", 1, true), "RaceVfx plays only Update4Config's ids")
	assert(FEEL.Turbine.Pitch[2] > FEEL.Turbine.Pitch[1] and FEEL.Turbine.Volume[2] > FEEL.Turbine.Volume[1], "the turbine climbs")
	local config = fs.readFile(SHARED .. "Update4Config.luau")
	assert(string.find(config, "\n-- 2026-09-26 (owner): race VFX.", 1, true), "the owner's race VFX block in Update4Config")
	assert(U4.Flags.RaceFx and U4.Flags.RaceGhosts and U4.Flags.RaceScreen and U4.IsOn("RaceFx") and U4.IsOn("RaceGhosts") and U4.IsOn("RaceScreen"), "the kill-switchable features ship on")

	for _, path in {
		CLIENT .. "Movement/SupermanFlight.client.luau",
		CLIENT .. "Movement/SurfboardPose.client.luau",
	} do
		local code = stripComments(fs.readFile(path))
		local aside = string.match(code, "local function standsAside.-\nend\n")
		assert(aside and string.find(aside, 'GetAttribute("RacePosed") == true', 1, true), path .. " stands aside on RacePosed")
	end

	local client = stripComments(fs.readFile(CLIENT .. "Race/RacePoseClient.client.luau"))
	local function has(needle, message)
		assert(string.find(client, needle, 1, true), "RacePoseClient: " .. message .. " (" .. needle .. ")")
	end
	assert(not string.find(client, "RacePose.Run(", 1, true) and not string.find(client, "RacePose.Super(", 1, true), "RacePoseClient applies no procedural Run / Super pose")
	has("RacePose.Set(", "the crouch")
	has("RacePose.Launch(", "the launch")
	has("RaceVfx.SetCharge(character, g, clock, if racer.IsLocal then localHeld() else nil)", "the local hold drives the arcs")
	has('GetAttribute("RacePredictedGrade")', "the predicted grade")
	has("local punch = RaceVfx.LaunchPunch(grade, reducedMotion())", "GO's punch by the grade, reduced motion respected")
	has("CameraPunch.Fov(punch.Fov)", "the FOV punch")
	has("CameraPunch.Shake(punch.ShakeSeconds, punch.ShakeStrength)", "the shake")
	has("RaceScreenFx.Shock(punch.Share)", "the screen's shock ring")
	assert(not string.find(client, "CAMERA.PerfectPunch", 1, true) and not string.find(client, "CameraPunch.Shake(0.25", 1, true), "no old GO punch")
	has("RaceVfx.SetTint(character, tintOf(target))", "the arcs' aura colours")
	has("return RaceVfx.AuraColors(aura, trail)", "the arcs' colours from the aura (the after-images stay the dark shadow)")
	assert(not string.find(client, "GhostColors", 1, true), "RacePoseClient no longer tints the after-images")
	has("RaceVfx.SetCruise(character, cruiseOf(target))", "the racer's own cruise")
	has("RaceCruiseSpeed", "the server's cruise")
	has("setFov(runFov(localRatio(racer)))", "the run's FOV follows the speed over the cruise")
	has("RaceVfx.Finish(racer.Character", "the finish ring")
	has("RaceTrack.GroundCFrame(RaceTrack.Length, x)", "...on the finish line")
	has("RaceScreenFx.Shock(SCREEN.PadShock)", "a pad's screen shock")
	has("RaceScreenFx.Step(dt,", "the screen follows the run")
	has('U4.IsOn("RaceFx")', "kill switch RaceFx")
	has('U4.IsOn("RaceGhosts")', "kill switch RaceGhosts")
	has('U4.IsOn("RaceScreen")', "kill switch RaceScreen")
	has("Workspace:GetAttributeChangedSignal(U4.KillAttributePrefix .. feature):Connect(applyKillSwitches)", "the switches are live")
	has("not RaceVfx.Active()", "the loops wait for the last ring")

	local input = stripComments(fs.readFile(CLIENT .. "Race/RaceInputClient.client.luau"))
	assert(string.find(input, "hum.PlaybackSpeed = TURBINE.Pitch[1] + (TURBINE.Pitch[2] - TURBINE.Pitch[1]) * level ^ 1.3", 1, true)
		and string.find(input, "hum.Volume = TURBINE.Volume[1] + (TURBINE.Volume[2] - TURBINE.Volume[1]) * level", 1, true), "RaceInputClient: the turbine's pitch and volume climb with the gauge")
	local hud = stripComments(fs.readFile(CLIENT .. "UI/RaceHudController.client.luau"))
	assert(string.find(hud, '"RaceScreenFx" })', 1, true), "RaceHudController keeps RaceScreenFx on screen")

	-- The build still ships ReplicatedStorage/BubbleModule (+ its Mesh): unchanged, but no race
	-- code uses it any more (section 1).
	local src = fs.readFile("src/common/ReplicatedStorage/BubbleModule.luau")
	local ok, bytes = pcall(fs.readFile, "design/vfx/BubbleModule.rbxm")
	if ok then
		local roots = rb.deserializeModel(bytes)
		assert(#roots == 1 and (string.gsub(src, "\r\n", "\n")) == (string.gsub(roots[1].Source, "\r\n", "\n")), "BubbleModule.luau still equals the rbxm's Source")
	end
	pass("Feel.Sounds are live ids or empty; the race VFX block and switches; RacePoseClient: Set + launch poses, LaunchPunch / Shake / screen shock, aura tint, own cruise, run FOV, finish ring on the line, live kill switches; RaceInputClient's turbine; RaceHudController keeps RaceScreenFx")
end

print(string.format("test_u4_race_vfx: %d checks passed", passed))
