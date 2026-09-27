-- test_retention_p1_gameplay.luau (Update 4, p0_gameplay, 2026-09-25)
--   H5  PoseHistory (ring buffer, lerp, clamps, same-time overwrite); a spinning beam that
--       covers a laggy runner NOW but did not where the server holds the body is not a kill
--       once the sweep is rewound; NewWorld1ServerMotion sources.
--   H6  HazardNames (the laserplatform exception, Laser parent, KillBrick, Kill script, Lava);
--       LocalDeathRules.Decide, one case per row; LocalDeathArbiter run in a stub world (Kill,
--       Revive at LastReachedStage, rate limits, the remote it creates); client/server sources.
--   M50 the phone column keeps 24 px between the speedometer and the jump button (36 px top
--       bar); CharacterStatsAdapter's floor / full-speed rule and the race WalkSpeed contract;
--       NEXT_MODE Red -> Yellow -> Green.
--   H10 MovementGuard loaded with stubs in Legacy / Observe / Enforce: a legit run passes, a
--       2000-stud hop + a pad rebase passes Legacy / Observe (recorded as WouldReject gap 4+)
--       and fails Enforce (MissingCheckpoint); a SafeZone rebase in Enforce is +1 only.
--   lune run audit/test_retention_p1_gameplay.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")

local Vector3, CFrame = rb.Vector3, rb.CFrame

local PoseHistory = require("../src/common/ServerScriptService/Services/PoseHistory")
local HazardNames = require("../src/common/ReplicatedStorage/Shared/HazardNames")
local LocalDeathRules = require("../src/common/ServerScriptService/Services/LocalDeathRules")
local H = require("../src/common/ReplicatedStorage/Shared/HudErgonomics")
local Adapter = require("../src/common/ServerScriptService/Services/Stats/CharacterStatsAdapter")

local SERVER_MOTION = "src/worlds/World1/ServerScriptService/Gameplay/NewWorld1ServerMotion.server.luau"
local MAP_SYSTEMS = "src/worlds/World1/ServerScriptService/Gameplay/NewWorld1MapSystems.server.luau"
local MAP_MOTION = "src/worlds/World1/StarterPlayer/StarterPlayerScripts/Gameplay/NewWorld1MapMotion.client.luau"
local R15 = "src/common/StarterPlayer/StarterCharacterScripts/R15SpeedsterRun.client.luau"
local INSTANT = "src/common/StarterPlayer/StarterPlayerScripts/Movement/InstantMovementController.client.luau"
local RAGDOLL = "src/common/StarterPlayer/StarterCharacterScripts/R6DeathRagdoll.server.luau"
local ARBITER = "src/common/ServerScriptService/Gameplay/LocalDeathArbiter.server.luau"
local PURCHASES = "src/common/ServerScriptService/Economy/SpeedProductPurchases.server.luau"
local SELECTOR = "src/common/StarterPlayer/StarterPlayerScripts/UI/WalkSpeedSelector.client.luau"
local GUARD = "src/common/ServerScriptService/Services/MovementGuard.luau"
local PADS = {
	W1 = "src/worlds/World1/ServerScriptService/Gameplay/NewWorld1ManualStagePads.server.luau",
	W2 = "src/worlds/World2/ServerScriptService/Gameplay/World2ManualStagePads.server.luau",
	W3 = "src/worlds/World3/ServerScriptService/Gameplay/World3ManualStagePads.server.luau",
}
local SAFE_ZONES = "src/worlds/World2/ServerScriptService/Gameplay/World2SafeZones.server.luau"

local EPS = 1e-6
local passed = 0
local function pass(message)
	passed += 1
	print("PASS " .. message)
end
local function read(path)
	return (fs.readFile(path):gsub("\r\n", "\n"))
end
local function has(source, needle, message)
	assert(string.find(source, needle, 1, true), message .. " (missing: " .. needle .. ")")
end
local function near(a, b, tolerance)
	return math.abs(a - b) <= (tolerance or EPS)
end
local function slice(source, first, last)
	local a = assert(string.find(source, first, 1, true), "slice start not found: " .. first)
	local b = assert(string.find(source, last, a + #first, true), "slice end not found: " .. last)
	return string.sub(source, a, b - 1)
end
local function signal()
	local s = { handlers = {} }
	function s:Connect(fn)
		table.insert(self.handlers, fn)
		return { Disconnect = function() end }
	end
	function s:Fire(...)
		for _, fn in self.handlers do
			fn(...)
		end
	end
	return s
end

-- Every file this workstream wrote or changed still compiles.
do
	for _, path in {
		SERVER_MOTION, MAP_SYSTEMS, MAP_MOTION, R15, ARBITER, PURCHASES, SELECTOR, GUARD, SAFE_ZONES, PADS.W1, PADS.W2, PADS.W3,
		"src/common/ServerScriptService/Services/PoseHistory.luau",
		"src/common/ReplicatedStorage/Shared/HazardNames.luau",
		"src/common/ServerScriptService/Services/LocalDeathRules.luau",
		"src/common/ReplicatedStorage/Shared/HudErgonomics.luau",
		"src/common/ServerScriptService/Services/Stats/CharacterStatsAdapter.luau",
	} do
		local ok, err = pcall(luau.compile, read(path))
		assert(ok, path .. " does not compile: " .. tostring(err))
	end
	pass("all 17 files compile")
end

----------------------------------------------------------------------
-- H5: PoseHistory
----------------------------------------------------------------------
local OMEGA = math.rad(52)
local function spin(t)
	return CFrame.Angles(0, OMEGA * t, 0)
end
do
	local h = PoseHistory.new()
	assert(PoseHistory.At(h, 1) == nil, "an empty history has no pose")
	for i = 0, 60 do
		PoseHistory.Push(h, i / 30, spin(i / 30))
	end
	assert(h.Count == 12, "12 samples kept")
	assert(near(PoseHistory.Span(h), 11 / 30, 1e-9), "12 samples at 30 Hz span 0.367 s")
	for _, t in { 1.9, 1.95, 1.99, 1.8, 1.7 } do
		local got = { PoseHistory.At(h, t):GetComponents() }
		local want = { spin(t):GetComponents() }
		for i = 1, 12 do
			assert(near(got[i], want[i], EPS), ("At(%.2f) component %d: %.9f vs %.9f"):format(t, i, got[i], want[i]))
		end
		-- A point on the beam 30 studs out (float32 CFrames: 1e-4 there).
		local p = PoseHistory.At(h, t) * Vector3.new(30, 0, 0)
		assert((p - spin(t) * Vector3.new(30, 0, 0)).Magnitude < 1e-4, "a point 30 studs out follows the spin")
	end
	-- Clamped at both ends.
	local newest = { PoseHistory.At(h, 99):GetComponents() }
	local oldest = { PoseHistory.At(h, -99):GetComponents() }
	local wantNewest, wantOldest = { spin(2):GetComponents() }, { spin(49 / 30):GetComponents() }
	for i = 1, 12 do
		assert(near(newest[i], wantNewest[i]) and near(oldest[i], wantOldest[i]), "clamped to the newest / oldest sample")
	end
	-- A push at the same time overwrites the newest.
	PoseHistory.Push(h, 2, CFrame.new(5, 0, 0))
	assert(h.Count == 12 and PoseHistory.At(h, 2).Position.X == 5, "same-time push overwrites")
	assert(near(PoseHistory.At(h, 2 - 1 / 60).Position.X, 2.5, 1e-5), "...and is blended against the one before")
	-- A clock that steps back restarts the history.
	PoseHistory.Push(h, 1, CFrame.new(7, 0, 0))
	assert(h.Count == 1 and PoseHistory.At(h, 0).Position.X == 7, "a backwards time restarts")
	pass("PoseHistory: analytic spin within 1e-6, clamps both ends, same-time overwrite, restart on a backwards clock")
end

-- The rewound sweep on a 132x1x1 beam spinning 52 deg/s, runner 30 studs out.
do
	local motion = read(SERVER_MOTION)
	local pointInside = luau.load(
		"local BODY_PADDING = Vector3.new(2.6, 3.5, 2.6)\n"
			.. slice(motion, "local function pointInsideExpandedPart", "local previousRootByPlayer")
			.. "\nreturn pointInsideExpandedPart",
		{ environment = { Vector3 = Vector3, math = math } }
	)()
	local INTERVAL = 1 / 30
	local size = Vector3.new(132, 1, 1)
	local origin = CFrame.new()
	local record = { OriginCFrames = { beam = origin }, History = PoseHistory.new() }
	local now = 2
	for i = 0, 60 do
		PoseHistory.Push(record.History, i / 30, spin(i / 30))
	end
	local runner = spin(now) * Vector3.new(30, 0, 0) -- right on the beam as it is NOW
	local function sweepKills(fromT, toT)
		local a = PoseHistory.At(record.History, fromT) * origin
		local b = PoseHistory.At(record.History, toT) * origin
		for i = 1, 8 do
			if pointInside(runner, a:Lerp(b, i / 8), size) then
				return true
			end
		end
		return false
	end
	assert(sweepKills(now - INTERVAL, now), "the unrewound sweep (last tick -> now) kills the runner")
	-- ping 0.3 -> rewind clamp(0.15 + 0.05, 0, 0.25) = 0.2 s.
	local seenAt = now - math.clamp(0.3 * 0.5 + 0.05, 0, 0.25)
	assert(not sweepKills(seenAt - INTERVAL, seenAt), "the rewound sweep kills a runner the beam had not reached at the seen time")
	-- ...and still kills one the beam covered then.
	runner = spin(seenAt) * Vector3.new(30, 0, 0)
	assert(sweepKills(seenAt - INTERVAL, seenAt), "a runner inside the rewound beam still dies")

	-- The sources.
	for _, needle in {
		"partCFrameAt(group.Record, part, seenAt)",
		"partCFrameAt(group.Record, part, seenBefore)",
		"local seenAt = lastMotionServerTime - getRewindSeconds(player)",
		"PoseHistory.Push(record.History, serverTime, record.Transform)",
		"lastMotionServerTime = serverTime",
		"partCFrameAt(system.Record, system.HazardPart, lastMotionServerTime - getRewindSeconds(player))",
		"if checkExactCylinderContact(character, humanoid, root, player) then",
		"partToRecord[part] = record",
		"_G.SpeedsterHazardPoseAt = function(part, serverTime)",
		"serverTime - motionStartServerTime",
		"local getHammerRewindSeconds = getRewindSeconds",
		"return math.clamp(ping * 0.5 + HAMMER_EXTRA_REWIND_SECONDS, 0, HAMMER_MAX_REWIND_SECONDS)",
		-- test_admin_abuse_panel.luau:276-277 read these two.
		'if lavaFrozen and (group.HazardKey == "LavaUp" or group.HazardKey == "Lava") then',
		'if Workspace:GetAttribute("AdminWorldFrozen") ~= true then\n\t\t\tupdateLavaUp(serverTime)',
	} do
		has(motion, needle, "NewWorld1ServerMotion")
	end
	-- The history is pushed after every pose of the tick and before the contact checks.
	local tick = slice(motion, "\t\tupdateBridge(serverTime)\n", "checkPlayerContact(player)")
	has(tick, "PoseHistory.Push", "the history is filled before the contact checks")
	-- The cull before the rewound centres never drops a group whose rewound centre is in reach,
	-- and drops a far one.
	local cull = luau.load(
		slice(motion, "local function distanceToBounds", "local function setPartsFromWorldTransform")
			.. slice(motion, "local function rewoundCentreMayReach", "-- The body the server holds is where the runner was about half a ping (plus the interpolation\n-- buffer) ago, while every client draws the hammer")
			.. "\nreturn rewoundCentreMayReach",
		{ environment = { math = math } }
	)()
	local centre = Vector3.new(5200, 37000, -2400) -- far from the origin, like World 1's map
	local bounds = CFrame.new(centre)
	local spinRecord = { OriginCFrames = {}, BoundsCFrame = bounds, History = PoseHistory.new() }
	local slideRecord = { OriginCFrames = {}, BoundsCFrame = bounds, History = PoseHistory.new() }
	local function grow(r, c)
		r.TravelMin = if r.TravelMin then Vector3.new(math.min(r.TravelMin.X, c.X), math.min(r.TravelMin.Y, c.Y), math.min(r.TravelMin.Z, c.Z)) else c
		r.TravelMax = if r.TravelMax then Vector3.new(math.max(r.TravelMax.X, c.X), math.max(r.TravelMax.Y, c.Y), math.max(r.TravelMax.Z, c.Z)) else c
	end
	for i = 0, 60 do
		local t = i / 30
		local spinT = CFrame.new(centre) * spin(t) * CFrame.new(-centre)
		local slideT = CFrame.new(0, 0, 120 * math.sin(t * 3))
		PoseHistory.Push(spinRecord.History, t, spinT)
		PoseHistory.Push(slideRecord.History, t, slideT)
		grow(spinRecord, (spinT * bounds).Position)
		grow(slideRecord, (slideT * bounds).Position)
	end
	for _, r in { spinRecord, slideRecord } do
		local group = { Record = r, Radius = 66 }
		for step = 0, 40 do
			local t = 1.7 + step * 0.0077
			local seen = (PoseHistory.At(r.History, t) * bounds).Position
			for _, dir in { Vector3.new(1, 0, 0), Vector3.new(0, 0, -1), Vector3.new(0.6, 0.8, 0) } do
				assert(cull(group, seen + dir * 74, 74), "a runner in reach of a rewound centre is never culled")
			end
		end
		assert(not cull(group, centre + Vector3.new(400, 0, 0), 74), "a runner 400 studs away is culled")
	end
	has(motion, "rewoundCentreMayReach(group, currentRoot, group.Radius + 8 + (currentRoot - previousRoot).Magnitude)", "the cull guards the rewound centres")

	-- Heartbeat order: the rewind helper is defined before its first use.
	local defined = assert(string.find(motion, "local function getRewindSeconds(player)", 1, true))
	local firstUse = assert(string.find(motion, "getRewindSeconds(player)", defined + 30, true))
	assert(defined < firstUse and defined < assert(string.find(motion, "local function checkExactCylinderContact", 1, true)), "getRewindSeconds is defined before the cylinder check")
	pass("H5: a 52 deg/s beam covering the runner now but not 0.2 s ago does not kill once rewound; sources wired")
end

----------------------------------------------------------------------
-- H6: HazardNames and LocalDeathRules
----------------------------------------------------------------------
local function part(name, parentName, props)
	local model = rb.Instance.new("Model")
	model.Name = parentName or "Map"
	local p = rb.Instance.new("Part")
	p.Name = name
	p.Parent = model
	p.Size = (props and props.Size) or Vector3.new(4, 1, 4)
	p.CFrame = (props and props.CFrame) or CFrame.new()
	return p
end
do
	assert(not HazardNames.IsLethalPart(part("Floor", "laserplatform")), "World 3's laserplatform floor is not lethal")
	assert(not HazardNames.IsLethalName("floor", "laserplatform"), "...by name either")
	assert(HazardNames.IsLethalPart(part("Beam", "Laser")), "a part of a Laser model is lethal")
	assert(HazardNames.IsLethalPart(part("Beam", "Lasers")), "...of Lasers too")
	assert(HazardNames.IsLethalPart(part("KillBrick", "Map")), "KillBrick is lethal")
	assert(HazardNames.IsLethalPart(part("Lava", "Map")) and HazardNames.IsLethalPart(part("Part", "LavaUp")), "Lava / LavaUp are lethal")
	local scripted = part("Block", "Map")
	local killScript = rb.Instance.new("Script")
	killScript.Name = "Kill script"
	killScript.Parent = scripted
	assert(HazardNames.IsLethalPart(scripted) and HazardNames.IsNamedLethalPart(scripted), "a part with a Kill script child is lethal")
	local marked = part("Head", "Hammer2")
	marked:SetAttribute("NewWorld1HazardKey", "Hammer")
	assert(HazardNames.IsLethalPart(marked) and not HazardNames.IsNamedLethalPart(marked),
		"a World 1 hazard mark is evidence for the server, but the character's prediction is unchanged")
	assert(not HazardNames.IsLethalPart(part("Floor", "Stage3")) and not HazardNames.IsLethalPart(nil), "a floor / nil is not")
	pass("HazardNames: laserplatform floor safe; Laser parent, KillBrick, Kill script, Lava lethal; hazard key server-only")
end

do
	local killBrick = part("KillBrick", "Map", { CFrame = CFrame.new(0, 0, 0), Size = Vector3.new(4, 1, 4) })
	local base = {
		part = killBrick, now = 1000, clientTime = 1000, rootPosition = Vector3.new(0, 3, 0),
		rootSpeed = 0, walkSpeed = 16, boosting = false, ping = 0.1,
	}
	local function decide(overrides)
		local ctx = table.clone(base)
		for key, value in overrides do
			ctx[key] = value
		end
		return LocalDeathRules.Decide(ctx)
	end
	local function expect(overrides, result, reason, label)
		local got, why = decide(overrides)
		assert(got == result and (reason == nil or why == reason), ("%s: expected %s/%s, got %s/%s"):format(label, result, tostring(reason), got, why))
	end
	expect({ serverDead = true }, "Ignore", "Dead", "1 server already dead")
	for _, flag in { "safeZone", "teleportInvulnerable", "arrivalGrace", "revivedJustNow", "raceActive" } do
		expect({ [flag] = true }, "Revive", "Protected", "2 " .. flag)
	end
	local frozen = part("Lava", "Map")
	frozen:SetAttribute("AdminFrozenLava", true)
	expect({ part = frozen }, "Revive", "Protected", "2 frozen lava part")
	expect({ part = part("Lava", "Map"), worldFrozen = true }, "Revive", "Protected", "2 lava in a frozen world")
	-- 3-4: the watchdog sends no part.
	do
		local ctx = table.clone(base)
		ctx.part = nil
		local r, why = LocalDeathRules.Decide(ctx)
		-- 2026-09-25 (final fix): no evidence is the old plain reset, never a free respawn.
		assert(r == "Kill" and why == "NoEvidence", "3 watchdog, nothing accepted: " .. r .. "/" .. why)
		ctx.claimAccepted = true
		r, why = LocalDeathRules.Decide(ctx)
		assert(r == "Kill" and why == "Accepted", "4 watchdog after an accepted claim: " .. r .. "/" .. why)
	end
	expect({ part = part("Floor", "laserplatform") }, "Revive", "NotLethal", "5 not lethal")
	expect({ part = part("Floor", "laserplatform"), rootVelocityY = -150 }, "Kill", "Falling", "5 not lethal, but falling fast")
	expect({ part = part("Floor", "laserplatform"), rootVelocityY = -60 }, "Revive", "NotLethal", "5 ...a jump's landing is not a fall")
	expect({ rootPosition = Vector3.new(0, 0.5 + 10.1, 0), rootVelocityY = -150 }, "Kill", "Falling", "7 too far, but falling fast")
	expect({ safeZone = true, rootVelocityY = -150 }, "Revive", "Protected", "2 protected even while falling")
	local moving = part("LaserBeam", "Laser1")
	moving:SetAttribute("TrackMoving", true)
	expect({ part = moving, rootPosition = Vector3.new(500, 0, 0) }, "Kill", "LegacyTrust", "6 moving part, no pose provider")
	-- 7: Reach = 6 + max(rootSpeed, walk x boost) * clamp(ping / 2 + 0.2, 0.2, 0.6).
	assert(near(LocalDeathRules.Reach(base), 10), "reach at walk 16, ping 0.1 = 10")
	expect({ rootPosition = Vector3.new(0, 0.5 + 9.9, 0) }, "Kill", "Contact", "8 within reach")
	expect({ rootPosition = Vector3.new(0, 0.5 + 10.1, 0) }, "Revive", "TooFar", "7 just past reach")
	expect({ rootPosition = Vector3.new(0, 0.5 + 12.7, 0), boosting = true }, "Kill", "Contact", "7 boosting: 6 + 27.2 x 0.25 = 12.8")
	expect({ rootPosition = Vector3.new(0, 0.5 + 12.9, 0), boosting = true }, "Revive", "TooFar", "7 ...and not past it")
	expect({ rootPosition = Vector3.new(0, 0.5 + 95, 0), rootSpeed = 150, ping = 5 }, "Kill", "Contact", "7 lead capped at 0.6 s: 6 + 150 x 0.6 = 96")
	expect({ rootPosition = Vector3.new(0, 0.5 + 97, 0), rootSpeed = 150, ping = 5 }, "Revive", "TooFar", "7 ...and never more")
	expect({ rootPosition = Vector3.new(0, 0.5 + 12, 0), ping = 0 / 0, walkSpeed = 0 / 0 }, "Revive", "TooFar", "7 NaN ping / walk read as 0.1 / 16")
	-- 7 with a pose provider: the hazard is judged where it was at the claimed time, clamped
	-- to the last second.
	local asked = nil
	local function poseAt(_, t)
		asked = t
		return CFrame.new(200, 0, 0)
	end
	expect({ part = moving, poseAt = poseAt, rootPosition = Vector3.new(200, 3, 0), clientTime = 999.8 }, "Kill", "Contact", "7 posed hazard at the body")
	assert(near(asked, 999.8), "the pose is asked at the claimed time")
	expect({ part = moving, poseAt = poseAt, rootPosition = Vector3.new(0, 3, 0), clientTime = 900 }, "Revive", "TooFar", "7 posed hazard far away")
	assert(near(asked, 999), "a claimed time older than 1 s is clamped to now - 1")
	expect({ part = moving, poseAt = poseAt, clientTime = 5000 }, "Revive", "TooFar", "7 a future time is clamped to now")
	assert(near(asked, 1000), "...to now")
	expect({ part = moving, poseAt = function() return nil end }, "Kill", "LegacyTrust", "6 a provider that cannot pose the part")
	expect({ part = moving, poseAt = function() error("boom") end }, "Kill", "LegacyTrust", "6 a provider that throws")
	-- The provider poses any part it knows (World 1's records), a still-looking one included;
	-- a part it does not know is judged where the server holds it.
	expect({ poseAt = poseAt, rootPosition = Vector3.new(200, 3, 0) }, "Kill", "Contact", "7 provider pose for a part with no moving flag")
	expect({ poseAt = function() return nil end, rootPosition = Vector3.new(0, 3, 0) }, "Kill", "Contact", "7 unknown to the provider: the server's part")
	expect({ poseAt = function() return nil end, rootPosition = Vector3.new(200, 3, 0) }, "Revive", "TooFar", "7 ...and far from it")
	-- World 3's Stage 10 lasers turn on the clients only: trusted like World 1's tracks.
	local w3Laser = part("Laser", "Lasers")
	w3Laser:SetAttribute("World3LaserIndex", 2)
	expect({ part = w3Laser, rootPosition = Vector3.new(60, 3, 0) }, "Kill", "LegacyTrust", "6 World 3 turning laser")
	local body = table.clone(base)
	body.rootPosition = nil
	assert(select(1, LocalDeathRules.Decide(body)) == "Revive", "no body on the server: nothing to kill, respawn")
	pass("LocalDeathRules rows 1-8")
end

-- LocalDeathArbiter, run with stand-ins: the remote it creates, Kill, Revive, rate limits.
do
	local source = read(ARBITER)
	local now = 1000
	local created = {}
	local function fakeInstance(className)
		local object = { ClassName = className, IsFake = true }
		if className == "RemoteEvent" then
			object.OnServerEvent = signal()
		end
		created[#created + 1] = object
		return object
	end
	local remotes = { children = {} }
	function remotes:FindFirstChild(name)
		return self.children[name]
	end
	local workspaceAttributes = {}
	local Workspace = {
		GetServerTimeNow = function() return now end,
		GetAttribute = function(_, name) return workspaceAttributes[name] end,
	}
	local servicesFolder = {
		WaitForChild = function(_, name)
			return "module:" .. name
		end,
	}
	local events = {}
	local modules = {
		["module:LocalDeathRules"] = LocalDeathRules,
		-- The real limiter on this test's clock.
		["module:ServerRateLimiter"] = luau.load(read("src/common/ServerScriptService/Services/ServerRateLimiter.luau"),
			{ environment = setmetatable({ os = { clock = function() return now end } }, { __index = _G }) })(),
		["module:FunnelAnalytics"] = { Event = function(_, name, _, fields) table.insert(events, { name = name, fields = fields }) return true end },
		["module:Config"] = { IsWorld2Place = false, IsWorld3Place = false },
	}
	local fakeG = {}
	local playersService = { PlayerRemoving = signal() }
	local delayed = {}
	local function runDelayed()
		local due = delayed
		delayed = {}
		for _, job in due do
			if job.at <= now then
				job.fn(table.unpack(job.args, 1, job.args.n))
			else
				table.insert(delayed, job)
			end
		end
	end
	local env = setmetatable({
		game = { GetService = function(_, name)
			if name == "Workspace" then return Workspace end
			if name == "Players" then return playersService end
			if name == "ServerScriptService" then return { WaitForChild = function() return servicesFolder end } end
			if name == "ReplicatedStorage" then
				return {
					WaitForChild = function() return { WaitForChild = function(_, n) return "module:" .. n end } end,
					FindFirstChild = function(_, n) return if n == "Remotes" then remotes else nil end,
				}
			end
			return {}
		end },
		require = function(target) return assert(modules[target], "unexpected require " .. tostring(target)) end,
		Instance = { new = fakeInstance },
		_G = fakeG,
		typeof = function(value)
			if type(value) == "table" and rawget(value, "IsInstance") then return "Instance" end
			return typeof(value)
		end,
		print = function() end,
		Enum = rb.Enum,
		os = { clock = function() return now end, time = os.time },
		task = {
			spawn = function(fn, ...) fn(...) end,
			delay = function(seconds, fn, ...)
				table.insert(delayed, { at = now + seconds, fn = fn, args = table.pack(...) })
				runDelayed()
			end,
		},
	}, { __index = _G })
	luau.load(source, { environment = env })()
	local claim = nil
	for _, object in created do
		if object.ClassName == "RemoteEvent" then
			assert(object.Name == "LocalDeathClaim" and object.Parent == remotes, "the arbiter creates Remotes.LocalDeathClaim")
			claim = object
		end
	end
	assert(claim, "no LocalDeathClaim remote was created")

	local function newWorld(stage)
		local attributes = { LastReachedStage = stage, RealWalkSpeedSelected = 16 }
		local humanoid = { Health = 100, WalkSpeed = 16 }
		local root = { IsInstance = true, Position = Vector3.new(0, 3, 0), AssemblyLinearVelocity = Vector3.new(0, 0, 0),
			IsA = function(_, c) return c == "BasePart" end }
		local character = { IsInstance = true, Parent = true, attributes = {} }
		function character:FindFirstChildOfClass(c) return if c == "Humanoid" then humanoid else nil end
		function character:FindFirstChild(n) return if n == "HumanoidRootPart" then root else nil end
		function character:GetAttribute(n) return self.attributes[n] end
		local player = { IsInstance = true, Name = "Runner", Parent = true, Character = character, attributes = attributes }
		function player:GetAttribute(n) return self.attributes[n] end
		function player:GetNetworkPing() return 0.1 end
		return player, humanoid, character
	end
	local function hazard(name, position)
		local p = part(name, "Map", { CFrame = CFrame.new(position), Size = Vector3.new(4, 1, 4) })
		-- A table stand-in the arbiter can check (typeof Instance, a BasePart in Workspace).
		return setmetatable({ IsInstance = true, IsA = function(_, c) return c == "BasePart" end,
			IsDescendantOf = function(_, ancestor) return ancestor == Workspace end,
			GetAttribute = function(_, n) return p:GetAttribute(n) end,
			FindFirstChild = function(_, n) return p:FindFirstChild(n) end,
		}, { __index = function(_, key) return p[key] end })
	end

	-- A KillBrick right under the body: confirmed, the server humanoid dies.
	local player, humanoid = newWorld(4)
	claim.OnServerEvent:Fire(player, hazard("KillBrick", Vector3.new(0, 0, 0)), now)
	assert(humanoid.Health == 0, "a confirmed claim kills the server humanoid")
	assert(events[1] and events[1].name == "LocalDeath_Kill_v2" and events[1].fields.CustomField01 == "Contact" and events[1].fields.CustomField02 == "W1",
		"...and reports LocalDeath_Kill_v2 {Contact, W1}")

	-- A KillBrick 200 studs away: overruled, respawned at LastReachedStage once 0.5 s have passed
	-- (2026-09-25 final fix: a death the server sees meanwhile wins, see below).
	local revived = {}
	fakeG.SpeedsterOverruledRevive = function(p, stage) table.insert(revived, { p, stage }) end
	now += 10
	local far, farHumanoid = newWorld(6)
	far.attributes.ReviveStageAtDeath = 2 -- left over from an older death
	claim.OnServerEvent:Fire(far, hazard("KillBrick", Vector3.new(200, 0, 0)), now)
	assert(#revived == 0, "an overruled respawn waits 0.5 s")
	now += 0.6
	runDelayed()
	assert(farHumanoid.Health == 100 and #revived == 1 and revived[1][1] == far and revived[1][2] == 6,
		"a claim far from the server body is overruled: a respawn at LastReachedStage 6, the humanoid untouched")
	assert(events[2] and events[2].name == "LocalDeath_Revive_v2" and events[2].fields.CustomField01 == "TooFar", "...and reported as Revive/TooFar")
	-- One decision per character: that character's later claims are dropped.
	now += 1
	claim.OnServerEvent:Fire(far, hazard("KillBrick", Vector3.new(0, 0, 0)), now)
	assert(farHumanoid.Health == 100 and #revived == 1, "an overruled character's later claims are dropped")

	-- Rate limit: a second claim inside 0.5 s is dropped.
	local quick, quickHumanoid = newWorld(2)
	now += 10
	claim.OnServerEvent:Fire(quick, "not a part", now) -- no evidence -> a plain death
	assert(#revived == 1 and quickHumanoid.Health == 0, "a claim with no usable part is a plain death (NoEvidence), not a free respawn")
	local _, newHumanoid, newCharacter = newWorld(2)
	quick.Character = newCharacter
	now += 0.2
	claim.OnServerEvent:Fire(quick, hazard("KillBrick", Vector3.new(0, 0, 0)), now)
	assert(newHumanoid.Health == 100, "a claim 0.2 s after the last one is dropped")
	now += 0.4
	claim.OnServerEvent:Fire(quick, hazard("KillBrick", Vector3.new(0, 0, 0)), now)
	assert(newHumanoid.Health == 0, "...and accepted 0.6 s after")
	assert(#events == 3, "telemetry at most once per 5 s per player (" .. #events .. " events)")
	-- Race: a runner in a race is never killed by a claim, and respawns at once.
	local racer, racerHumanoid = newWorld(3)
	racer.attributes.RaceActive = true
	now += 10
	claim.OnServerEvent:Fire(racer, hazard("SpikeTile", Vector3.new(0, 0, 0)), now)
	assert(racerHumanoid.Health == 100 and #revived == 2, "RaceActive: Protected, never a kill, respawned at once")
	-- A second overruled death inside 3 s is respawned late, never dropped (the watchdog asks once).
	local _, _, racerCharacter2 = newWorld(3)
	racer.Character = racerCharacter2
	now += 1
	claim.OnServerEvent:Fire(racer, hazard("SpikeTile", Vector3.new(0, 0, 0)), now)
	assert(#revived == 2, "a respawn 1 s after the last one waits")
	now += 2.1
	runDelayed()
	assert(#revived == 3 and revived[3][1] == racer, "...and happens once 3 s have passed")
	-- A late respawn is skipped when the character was replaced meanwhile.
	local _, _, racerCharacter3 = newWorld(3)
	racer.Character = racerCharacter3
	now += 1
	claim.OnServerEvent:Fire(racer, hazard("SpikeTile", Vector3.new(0, 0, 0)), now)
	local _, _, racerCharacter4 = newWorld(3)
	racer.Character = racerCharacter4
	now += 3
	runDelayed()
	assert(#revived == 3, "a late respawn for a character already replaced does nothing")
	playersService.PlayerRemoving:Fire(racer)
	-- Garbage arguments never throw; with no usable part the claim is the old plain reset.
	local junk, junkHumanoid = newWorld(1)
	now += 10
	claim.OnServerEvent:Fire(junk, { Name = "KillBrick" }, 0 / 0) -- a client can send a table, never a fake Instance
	assert(junkHumanoid.Health == 0 and #revived == 3, "a table sent as the part is no evidence: a plain death, no respawn")

	-- Falling: a body the server sees dropping fast is not overruled (a claim sent just before
	-- the void or a server kill brick would dodge that death).
	local faller, fallerHumanoid, fallerCharacter = newWorld(4)
	fallerCharacter:FindFirstChild("HumanoidRootPart").AssemblyLinearVelocity = Vector3.new(0, -150, 0)
	now += 10
	claim.OnServerEvent:Fire(faller, hazard("KillBrick", Vector3.new(200, 0, 0)), now)
	now += 0.6
	runDelayed()
	assert(fallerHumanoid.Health == 0 and #revived == 3, "falling at 150 studs/s: a plain death (Falling)")

	-- Budget: past 3 overruled respawns in 3 minutes a claim is a plain death (the old reset),
	-- so a client cannot farm free respawns at its stage start.
	local spammer = newWorld(5)
	local before = #revived
	for _ = 1, 3 do
		now += 3.1
		local _, _, fresh = newWorld(5)
		spammer.Character = fresh
		claim.OnServerEvent:Fire(spammer, hazard("KillBrick", Vector3.new(200, 0, 0)), now)
		now += 0.6
		runDelayed()
	end
	assert(#revived == before + 3, "3 overruled respawns in 3 minutes: " .. (#revived - before))
	now += 3.1
	local _, fourthHumanoid, fourth = newWorld(5)
	spammer.Character = fourth
	claim.OnServerEvent:Fire(spammer, hazard("KillBrick", Vector3.new(200, 0, 0)), now)
	now += 0.6
	runDelayed()
	assert(#revived == before + 3 and fourthHumanoid.Health == 0, "the 4th in 3 minutes is a plain death")
	now += 181
	local _, _, refilled = newWorld(5)
	spammer.Character = refilled
	claim.OnServerEvent:Fire(spammer, hazard("KillBrick", Vector3.new(200, 0, 0)), now)
	now += 0.6
	runDelayed()
	assert(#revived == before + 4, "the budget refills after 3 minutes")

	-- A respawn is dropped when the server saw a real death meanwhile (its revive offer): within
	-- the 0.5 s wait, and while a second one waits for the 3 s spacing.
	local dodger, dodgerHumanoid = newWorld(4)
	now += 10
	claim.OnServerEvent:Fire(dodger, hazard("KillBrick", Vector3.new(200, 0, 0)), now)
	dodgerHumanoid.Health = 0 -- the kill brick the claim tried to dodge
	now += 0.6
	runDelayed()
	assert(#revived == before + 4, "a death the server sees within 0.5 s of the claim wins")
	local dying = newWorld(4)
	now += 10
	claim.OnServerEvent:Fire(dying, hazard("KillBrick", Vector3.new(200, 0, 0)), now)
	now += 0.6
	runDelayed()
	assert(#revived == before + 5, "first respawn after 0.5 s")
	local _, dyingHumanoid, dyingCharacter = newWorld(4)
	dying.Character = dyingCharacter
	now += 1
	claim.OnServerEvent:Fire(dying, hazard("KillBrick", Vector3.new(200, 0, 0)), now) -- waits for the 3 s spacing
	dyingHumanoid.Health = 0 -- World 1's contact remote kills it for real
	now += 3
	runDelayed()
	assert(#revived == before + 5, "a respawn scheduled before a real server death is dropped")

	-- Without SpeedProductPurchases' hook: a plain LoadCharacter, never a client left dead.
	fakeG.SpeedsterOverruledRevive = nil
	local lonely = newWorld(2)
	local loads = 0
	function lonely:LoadCharacter() loads += 1 end
	now += 10
	claim.OnServerEvent:Fire(lonely, hazard("KillBrick", Vector3.new(200, 0, 0)), now)
	now += 0.6
	runDelayed()
	assert(loads == 1, "the fallback respawns with LoadCharacter")
	pass("LocalDeathArbiter: creates LocalDeathClaim; Kill / Revive at LastReachedStage after 0.5 s; no part = plain death; falling = plain death; 0.5 s and one decision per character; 5 s telemetry; RaceActive protected at once; a respawn inside 3 s is late, not dropped; 3 per 3 min; a real death meanwhile wins; LoadCharacter fallback")
end

-- H6 sources: the client claims, the watchdog no longer resets, the Esc reset still does.
do
	local run = read(R15)
	has(run, 'remotes:WaitForChild("LocalDeathClaim", 10)', "R15 finds the claim remote with a timeout")
	has(run, "localDeathClaim:FireServer(hitPart, seenAt)", "R15 fires LocalDeathClaim")
	has(run, "claimLocalDeath(nil, nil)", "the watchdog claims with no part")
	assert(not string.find(run, "PlayerResetRequest", 1, true), "R15 no longer references PlayerResetRequest")
	has(run, "HazardNames.IsNamedLethalPart(hitPart)", "the prediction uses Shared/HazardNames")
	local touch = slice(run, "local function setupLethalTouchPrediction", "setupLethalTouchPrediction()")
	local skip = assert(string.find(touch, 'hitPart:GetAttribute("SafeZoneProtected") == true', 1, true), "the prediction skips safe zones")
	local claimAt = assert(string.find(touch, "claimLocalDeath(hitPart, Workspace:GetServerTimeNow())", 1, true), "the prediction claims")
	local kill = assert(string.find(touch, "humanoid.Health = 0", 1, true))
	assert(skip < claimAt and claimAt < kill, "skip, then claim, then the local kill")
	has(touch, 'if isLethal and (hitPart:GetAttribute("AdminFrozenLava") == true', "frozen lava is still left alone (test_admin_abuse_panel)")
	has(read(INSTANT), "PlayerResetRequest", "InstantMovementController still sends PlayerResetRequest (Esc reset)")
	has(read(RAGDOLL), "PlayerResetRequest", "R6DeathRagdoll still handles PlayerResetRequest")
	local arbiter = read(ARBITER)
	has(arbiter, 'claimRemote.Name = "LocalDeathClaim"', "LocalDeathArbiter creates LocalDeathClaim")
	has(arbiter, 'return require(game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("FunnelAnalytics", 10))', "the standard FunnelAnalytics loader")
	local purchases = read(PURCHASES)
	local overruled = slice(purchases, "_G.SpeedsterOverruledRevive = function(player, stage)", "local function grantFlightAbilityTransaction")
	local load = assert(string.find(overruled, "pcall(player.LoadCharacter, player)", 1, true))
	local grant = assert(string.find(overruled, "grantReviveTransaction(player)", 1, true))
	assert(load < grant, "LoadCharacter before grantReviveTransaction")
	has(overruled, 'Token = "overruled"', "the overruled context")
	local systems = read(MAP_SYSTEMS)
	has(systems, 'player:GetAttribute("SafeZoneProtected") == true', "World 1's contact remote honours safe zones")
	has(systems, 'os.clock() < (tonumber(player:GetAttribute("StageTeleportArrivalGraceUntil")) or 0)', "...and the arrival grace")
	local killLocal = slice(read(MAP_MOTION), "local function killLocalForHazard(hazardKey)", "local function isAxisAligned")
	has(killLocal, 'localPlayer:GetAttribute("SafeZoneProtected") == true', "World 1's client hitbox skips safe zones")
	pass("H6 sources: claim before the local kill, watchdog claims, Esc reset untouched, arbiter remote, overruled revive, safe-zone skips")
end

----------------------------------------------------------------------
-- M50
----------------------------------------------------------------------
do
	local PHONES = { { 844, 390 }, { 667, 375 }, { 740, 360 }, { 812, 375 }, { 896, 414 }, { 932, 430 }, { 915, 412 }, { 800, 360 } }
	assert(H.ColumnJumpGap == 24, "ColumnJumpGap = 24")
	local worst = math.huge
	for _, size in PHONES do
		for count = 1, 2 do
			local column = H.PhoneColumn(size[1], size[2], true, false, count, 36)
			local gap = column.Jump.Top - column.Speedometer.Rect.Bottom
			worst = math.min(worst, gap)
			assert(gap >= 24 - EPS, ("%dx%d, %d badges: the speedometer is %.1f px above the jump button"):format(size[1], size[2], count, gap))
		end
	end
	print(("  M50: the closest speedometer is %.1f px above the jump button"):format(worst))

	-- CharacterStatsAdapter (no Config in Lune: floor 16, full speed at 24 or less).
	local function stubPlayer(attributes)
		local model = rb.Instance.new("Model")
		local humanoid = rb.Instance.new("Humanoid")
		humanoid.Parent = model
		humanoid.WalkSpeed = 1
		return {
			Character = model,
			GetAttribute = function(_, name) return attributes[name] end,
			SetAttribute = function(_, name, value) attributes[name] = value end,
		}, humanoid
	end
	local p, humanoid = stubPlayer({ WalkSpeedMode = "Green" })
	local actual = Adapter.Update(p, 1)
	assert(near(actual, 8) and near(humanoid.WalkSpeed, 8), "Speed 1 in Green walks its full 8 (was 1.6): " .. tostring(actual))
	local top, topHumanoid = stubPlayer({ WalkSpeedMode = "Green" })
	actual = Adapter.Update(top, 3.37e15)
	assert(near(top:GetAttribute("RealWalkSpeedMax"), 300, 1e-6) and near(actual, 60, 1e-6) and near(topHumanoid.WalkSpeed, 60, 1e-4), "maximum 300 in Green: 60")
	-- A maximum of 30 (above 24): Green's 6 is floored at 16.
	local StatsService = require("../src/common/ServerScriptService/Services/Stats/StatsService")
	local rules = Adapter.GetRules()
	local speed30 = nil
	for exponent = 1, 16, 0.01 do
		local r = StatsService.CalculateWalkSpeed(10 ^ exponent, rules, { worldMultiplier = 1, selectorMultiplier = 1, boostMultiplier = 1, permanentMultiplier = 1 })
		if r.ok and r.value >= 30 then
			speed30 = 10 ^ exponent
			break
		end
	end
	assert(speed30, "a Speed with a maximum walk of 30 exists")
	local floored = stubPlayer({ WalkSpeedMode = "Green" })
	actual = Adapter.Update(floored, speed30)
	assert(near(actual, 16), "above 24, Green never drops under 16 (" .. tostring(actual) .. ")")
	local yellow = stubPlayer({ WalkSpeedMode = "Yellow" })
	actual = Adapter.Update(yellow, speed30)
	assert(near(actual, 16) or actual > 16, "Yellow above 24 is at least 16")
	-- Race: no WalkSpeed write while RaceActive (the race client owns it).
	local racer, racerHumanoid = stubPlayer({ WalkSpeedMode = "Red", RaceActive = true })
	actual = Adapter.Update(racer, 3.37e15)
	assert(near(actual, 300, 1e-6) and racerHumanoid.WalkSpeed == 1, "RaceActive: the adapter leaves WalkSpeed alone")
	assert(near(racer:GetAttribute("RealWalkSpeedSelected"), 300, 1e-6), "...and still publishes the attributes")

	-- NEXT_MODE: Red -> Yellow -> Green -> Red; Custom -> Red.
	local nextMode = luau.load(slice(read(SELECTOR), "local NEXT_MODE = {", "local function getModeMultiplier") .. "\nreturn NEXT_MODE")()
	assert(nextMode.Red == "Yellow" and nextMode.Yellow == "Green" and nextMode.Green == "Red" and nextMode.Custom == "Red", "NEXT_MODE cycles Red -> Yellow -> Green")
	has(read(SELECTOR), "Config.WalkSpeedSelectorFullBelow", "the dial's read-out follows the same floor rule")
	pass("M50: >= 24 px above the jump button on 8 phones (36 px top bar), floor 16 / full speed <= 24, no race WalkSpeed write, Red -> Yellow")
end

----------------------------------------------------------------------
-- H10: MovementGuard in Legacy / Observe / Enforce
----------------------------------------------------------------------
local guardSource = read(GUARD)
local function loadGuard(mode)
	local clock = 0
	local config = { StageCount = 10, MovementGuardMode = mode, FinalPadCooldownSeconds = 1.5, BoostWalkSpeedMultiplier = 1.7 }
	local stages = {
		GetStageReferencePosition = function(stage) return if stage >= 1 and stage <= 10 then Vector3.new(stage * 1000, 0, 0) else nil end,
		GetNearestStage = function(position)
			local best, bestDistance = nil, math.huge
			for stage = 1, 10 do
				local d = (Vector3.new(stage * 1000, 0, 0) - position).Magnitude
				if d < bestDistance then
					best, bestDistance = stage, d
				end
			end
			return best, bestDistance
		end,
	}
	local events = {}
	local analytics = { Event = function(_, name, _, fields) table.insert(events, { name = name, fields = fields }) return true end }
	local heartbeat = signal()
	local root = { Position = Vector3.new(1000, 0, 0), Parent = true, IsA = function(_, c) return c == "BasePart" end }
	local humanoid = { Health = 100, WalkSpeed = 300 }
	local character = { Parent = true }
	function character:FindFirstChild(n) return if n == "HumanoidRootPart" then root else nil end
	function character:FindFirstChildOfClass(c) return if c == "Humanoid" then humanoid else nil end
	local attributes = { RealWalkSpeedSelected = 300 }
	local player = { Character = character, Name = "Runner" }
	function player:GetAttribute(n) return attributes[n] end
	local fakeG = {}
	local env = setmetatable({
		game = { GetService = function(_, name)
			if name == "RunService" then return { Heartbeat = heartbeat } end
			if name == "Players" then return { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return { player } end } end
			if name == "ReplicatedStorage" then return { WaitForChild = function() return { WaitForChild = function() return "Config" end } end } end
			if name == "Workspace" then return { GetServerTimeNow = function() return clock end } end
			if name == "ServerScriptService" then return { WaitForChild = function() return { WaitForChild = function() return "FunnelAnalytics" end } end } end
			return {}
		end },
		script = { Parent = { WaitForChild = function() return "StageTeleportService" end } },
		require = function(target)
			if target == "Config" then return config end
			if target == "StageTeleportService" then return stages end
			if target == "FunnelAnalytics" then return analytics end
			error("unexpected require " .. tostring(target))
		end,
		os = { clock = function() return clock end, time = function() return 1790000000 end },
		Vector3 = Vector3,
		_G = fakeG,
		Enum = rb.Enum,
		print = function() end,
	}, { __index = _G })
	local guard = luau.load(guardSource, { environment = env })()
	guard.ResetForCharacter(player, character)
	local world = { guard = guard, player = player, root = root, events = events, config = config }
	function world.advance(seconds, velocity)
		local steps = math.floor(seconds / 0.1 + 0.5)
		for _ = 1, steps do
			clock += 0.1
			if velocity then
				root.Position += velocity * 0.1
			end
			heartbeat:Fire(0.1)
		end
	end
	function world.teleport(position)
		clock += 0.1
		root.Position = position
		heartbeat:Fire(0.1)
	end
	function world.pad(stage)
		fakeG.VortexMovementGuardRebase(player, stage, "Pad")
		return guard.CanClaim(player, stage, stage == 10)
	end
	function world.skipClock(seconds)
		clock += seconds
	end
	return world
end

do
	for _, mode in { "Legacy", "Observe", "Enforce" } do
		-- A legit run at 300 studs/s, claiming each stage's pad on arrival.
		local w = loadGuard(mode)
		w.advance(3.5) -- past the spawn's steady window
		for stage = 2, 10 do
			w.advance(1000 / 300, Vector3.new(300, 0, 0))
			w.root.Position = Vector3.new(stage * 1000, 0, 0)
			w.advance(0.1)
			local ok, reason = w.pad(stage)
			assert(ok, ("%s: a legit run is refused at stage %d (%s)"):format(mode, stage, tostring(reason)))
			w.skipClock(31) -- one telemetry record per stage
		end
		if mode == "Observe" then
			assert(#w.events == 9, "Observe records one event per 30 s: " .. #w.events)
			for _, event in w.events do
				assert(event.name == "MG_StrictPass_v2", "a legit run is a strict pass (" .. event.name .. " " .. tostring(event.fields.CustomField02) .. ")")
			end
			assert(w.events[9].fields.CustomField01 == "W1-S10-F" and w.events[9].fields.CustomField02 == "Pass-gap0", "fields W1-S10-F / Pass-gap0")
		else
			assert(#w.events == 0, mode .. " records nothing")
		end
		assert(w.guard.GetStrictProgress(w.player) == 10, mode .. ": the strict lane followed the run")

		-- A hop of 2000 studs every 0.1 s from stage 1 to stage 9, then its pad.
		local h = loadGuard(mode)
		h.advance(3.5)
		for stage = 3, 9, 2 do
			h.teleport(Vector3.new(stage * 1000, 0, 0))
		end
		h.advance(0.1)
		local ok, reason = h.pad(9)
		if mode == "Enforce" then
			assert(ok == false and reason == "MissingCheckpoint", "Enforce refuses the hop: " .. tostring(reason))
		else
			assert(ok == true, mode .. " still lets the hop claim (unchanged behaviour): " .. tostring(reason))
		end
		if mode == "Observe" then
			local event = h.events[1]
			assert(event and event.name == "MG_StrictWouldReject_v2", "Observe records the hop as WouldReject")
			assert(event.fields.CustomField01 == "W1-S9" and event.fields.CustomField02 == "MissingCheckpoint-gap4+", "fields W1-S9 / MissingCheckpoint-gap4+: " .. tostring(event.fields.CustomField02))
		end
		assert(h.guard.GetStrictProgress(h.player) == 1, mode .. ": pads never move the strict lane")
	end

	-- Enforce: a SafeZone rebase raises strict progress by exactly one; a Pad does nothing.
	local e = loadGuard("Enforce")
	local function rebase(...)
		return e.guard.Rebase(e.player, ...)
	end
	rebase(4, "SafeZone")
	assert(e.guard.GetStrictProgress(e.player) == 1, "SafeZone +3 ignored")
	rebase(2, "SafeZone")
	assert(e.guard.GetStrictProgress(e.player) == 2, "SafeZone +1 accepted")
	rebase(3, "Pad")
	assert(e.guard.GetStrictProgress(e.player) == 2 and e.guard.GetProgress(e.player) == 1, "a Pad in Enforce is a no-op")
	rebase(7, nil)
	assert(e.guard.GetStrictProgress(e.player) == 7 and e.guard.GetProgress(e.player) == 7, "a teleport (nil source) rebases both lanes")
	-- Observe: SafeZone / Pad rebase the legacy lane only.
	local o = loadGuard("Observe")
	o.guard.Rebase(o.player, 5, "SafeZone")
	assert(o.guard.GetProgress(o.player) == 5 and o.guard.GetStrictProgress(o.player) == 1, "Observe: a SafeZone rebase moves the legacy lane only")
	-- The pads and World 2's safe zones pass their source.
	for key, path in PADS do
		has(read(path), 'pcall(rebase, player, stage, "Pad")', key .. " pads pass Pad")
	end
	has(read(SAFE_ZONES), 'pcall(rebase, player, stage, "SafeZone")', "World 2's safe zones pass SafeZone")
	has(guardSource, "MovementGuard.Rebase(player, progressTarget, source)", "the global hook passes the source through")
	pass("H10: legit runs pass every mode; the hop passes Legacy/Observe (WouldReject gap4+) and fails Enforce; SafeZone +1 only; sources pass Pad/SafeZone")
end

print(("test_retention_p1_gameplay: %d groups passed"):format(passed))
