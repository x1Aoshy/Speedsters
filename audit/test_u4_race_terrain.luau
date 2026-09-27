-- test_u4_race_terrain.luau (Update 4, race_server, 2026-09-25): Astra's final map
-- (design/race/CONTRATO_MAPA_ASTRA.md §2b) is a straight track with gentle hills and speed pads.
--   1. the ground profile (RaceTrack): the builder's flat arena gives a flat profile (nothing
--      changes on it); a fake hilly profile (hills up to ~9 degrees, crests, a cross tilt, flat
--      start and finish) is built on the grid, encoded / decoded exactly (the Workspace attribute),
--      interpolated like its sampler, and the contract checker flags a steep slope, a step and a
--      start that is not flat;
--   2. heights over the ground: spikes (standing vs jumping), the corridor, falls;
--   3. the server's envelope (RaceService.Validator) against simulated clients on the hills with
--      0-300 ms latency: honest racers at Speed 1 / 1e6 / 1e18, with jumps on hills and crests and
--      a client whose horizontal progress is the slope's path length, get no corrections; a x1.3
--      hacker on the hills is still corrected;
--   4. speed pads: the builder's pads read from their parts, the payload round trip, the feet-on-
--      the-pad rule; an honest crossing is boosted on both sides (never corrected, faster), a pad
--      at the footprint's edge the client missed is still granted by the server (never
--      corrected), a boost claimed without a pad is corrected, a second pad refreshes and never
--      stacks; the plausibility floor with pads stays over the record floor (MinPlausibleMs) and under
--      the best honest race.
--   5. 2026-09-26 (owner: Sonic Dash speeds): ground adhesion (RaceTrack.AdhesionVelocity): at
--      105-913 studs/s over the hills the root stays within the spikes' reach (without it a
--      racer flies off the crests over the rows); it never adds upward speed and leaves jumps.
-- Run: lune run audit/test_u4_race_terrain.luau   (from the project root)
local roblox = require("@lune/roblox")

local U4 = require("../src/common/ReplicatedStorage/Shared/Update4Config")
local RaceTrack = require("../src/common/ReplicatedStorage/Shared/RaceTrack")
local RaceMath = require("../src/common/ReplicatedStorage/Shared/RaceMath")
local RaceService = require("../src/common/ServerScriptService/Services/Race/RaceService")
local RaceArenaBuilder = require("../src/common/ServerScriptService/Services/Race/RaceArenaBuilder")

local Validator = RaceService.Validator
local GROUND, PADS, TRACK = U4.Race.Ground, U4.Race.Pads, U4.Race.Track
local ENV = {
	Instance = roblox.Instance, Vector3 = roblox.Vector3, CFrame = roblox.CFrame, Color3 = roblox.Color3,
	Enum = roblox.Enum, UDim2 = roblox.UDim2, NumberRange = roblox.NumberRange,
}

local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end
local function near(a, b, eps)
	return math.abs(a - b) <= eps
end

-- Deterministic random numbers.
local function generator(seed)
	local state = seed % 2147483648
	return function()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
end

----------------------------------------------------------------------
-- The builder's arena, and a sampler that stands in for RaceServer's raycast in Lune: the top
-- of the highest visible, colliding, axis-aligned part under (s, x) (the floor slabs).
----------------------------------------------------------------------
local arena = RaceArenaBuilder.Build(roblox.Instance.new("Folder"), ENV)
local function boxSampler(root)
	local boxes = {}
	for _, part in root:GetDescendants() do
		if part:IsA("BasePart") and part.CanCollide and part.CanQuery and part.Transparency < 1 then
			local p, size = part.CFrame.Position, part.Size
			table.insert(boxes, { x0 = p.X - size.X / 2, x1 = p.X + size.X / 2, z0 = p.Z - size.Z / 2, z1 = p.Z + size.Z / 2, top = p.Y + size.Y / 2 })
		end
	end
	return function(s, x)
		local sampleS = math.clamp(s, RaceTrack.ProfileS0 + 1, RaceTrack.ProfileS1 - 1)
		local world = RaceTrack.ToWorld(sampleS, x, 0)
		local best = nil
		for _, box in boxes do
			if world.X >= box.x0 and world.X <= box.x1 and world.Z >= box.z0 and world.Z <= box.z1 and box.top <= world.Y + GROUND.CastAbove then
				best = math.max(best or -math.huge, box.top)
			end
		end
		return if best then best - RaceTrack.Origin.Y else nil
	end
end

-- The hilly map: flat staging box, start line and finish (to s 100 and from s 1700), rolling
-- hills of 20 studs over 400 (max grade 0.157, ~8.9 degrees) with their crests, and a gentle
-- cross tilt (1 stud across the track).
local HILL_A, HILL_L = 20, 400
local function hillHeight(s, x)
	if s <= 100 or s >= 1700 then
		return 0
	end
	local main = HILL_A * (1 - math.cos(2 * math.pi * (s - 100) / HILL_L)) / 2
	-- the tilt fades in and out with the hills so the flat zones stay flat
	return main + (x / 31.5) * 0.5 * (main / HILL_A)
end

----------------------------------------------------------------------
-- 1. Profiles
----------------------------------------------------------------------
local flat, hilly
do
	flat = RaceTrack.BuildProfile(boxSampler(arena))
	assert(flat.Flat and flat.Allowance == 0, "the builder's arena gives a flat profile")
	assert(RaceTrack.FlatProfile().Flat and RaceTrack.GetProfile().Flat, "flat by default")
	local encodedFlat = RaceTrack.EncodeProfile(flat)
	assert(encodedFlat == "RG1;4;-64;547;-31.5,0,31.5;0*547|0*547|0*547", "the flat profile's attribute: " .. encodedFlat)
	assert(RaceTrack.ProfileCount == 547 and RaceTrack.ProfileS0 == -64 and RaceTrack.ProfileS1 == 2120, "547 samples from -64 to 2120, every 4 studs")

	hilly = RaceTrack.BuildProfile(hillHeight)
	assert(not hilly.Flat, "the hills are not flat")
	local encoded = RaceTrack.EncodeProfile(hilly)
	local decoded = assert(RaceTrack.DecodeProfile(encoded), "decodes")
	for column, list in hilly.Heights do
		for index, h in list do
			assert(decoded.Heights[column][index] == h, "exact round trip")
		end
	end
	assert(decoded.Allowance == hilly.Allowance and #encoded < 20000, "same allowance, a compact attribute (" .. #encoded .. " chars)")
	assert(hilly.Allowance > 0.01 and hilly.Allowance < 0.0155, string.format("slope allowance of a ~9 degree hill (%.4f)", hilly.Allowance))
	local rand = generator(99)
	local worst = 0
	for _ = 1, 4000 do
		local s = -60 + rand() * 2170
		local x = -31.5 + rand() * 63
		worst = math.max(worst, math.abs(RaceTrack.Ground(s, x, hilly) - hillHeight(s, x)))
	end
	assert(worst < 0.1, string.format("Ground interpolates the sampler within 0.1 studs (%.3f)", worst))
	assert(#RaceTrack.CheckProfile(hilly) == 0 and #RaceTrack.CheckProfile(flat) == 0, "the hills keep the map contract")
	-- Garbage never decodes.
	for _, bad in { nil, 5, "", "RG1;4;-64;547;x;0*547", "RG1;4;-64;547;-31.5,0,31.5;0*546|0*547|0*547", "RG1;4;-64;547;-31.5,0,31.5;0*547|0*547",
		"RG1;4;-64;547;-31.5,0,31.5;999999*547|0*547|0*547" } do
		assert(RaceTrack.DecodeProfile(bad) == nil, "refused: " .. tostring(bad))
	end
	-- The contract checker (the server warns the map's author).
	local steep = RaceTrack.BuildProfile(function(s)
		return if s > 500 and s < 540 then (s - 500) * 0.25 elseif s >= 540 and s < 600 then 10 - (s - 540) / 6 else 0
	end)
	local stepped = RaceTrack.BuildProfile(function(s)
		return if s > 800 and s < 900 then 1.5 else 0
	end)
	local raisedStart = RaceTrack.BuildProfile(function(s)
		return if s < 0 then 2 else 0
	end)
	local function mentions(issues, word)
		for _, text in issues do
			if string.find(text, word, 1, true) then
				return true
			end
		end
		return false
	end
	assert(mentions(RaceTrack.CheckProfile(steep), "slope of 14"), "a 14 degree slope is flagged")
	assert(mentions(RaceTrack.CheckProfile(stepped), "step of 1.50"), "a 1.5 stud step is flagged")
	assert(mentions(RaceTrack.CheckProfile(raisedStart), "not flat"), "a raised start is flagged")
	pass(string.format("profiles: the builder's arena is flat (%s); hills round-trip exactly (%d chars), interpolate within %.3f, allowance %.4f; the checker flags slopes, steps and a raised start",
		encodedFlat, #encoded, worst, hilly.Allowance))
end

----------------------------------------------------------------------
-- 2. Heights over the ground
----------------------------------------------------------------------
do
	RaceTrack.SetProfile(hilly)
	local tile
	for _, candidate in RaceTrack.SpikeTiles() do
		if RaceTrack.Ground(candidate.s, candidate.x) > 5 then
			tile = candidate
			break
		end
	end
	assert(tile, "a spike tile on a hill")
	local ground = RaceTrack.Ground(tile.s, tile.x)
	assert(RaceTrack.SpikeAt(tile.s, tile.x, ground + 3), "standing on a hill over a spike: hit")
	assert(not RaceTrack.SpikeAt(tile.s, tile.x, ground + 3.5), "jumping over it (0.5 higher than standing): clear")
	assert(RaceTrack.SweptSpike(tile.s - 6, tile.x, tile.s + 6, tile.x, RaceTrack.Ground(tile.s - 6, tile.x) + 3, RaceTrack.Ground(tile.s + 6, tile.x) + 3) == tile, "running over it on the slope: hit")
	assert(RaceTrack.InCorridor(1000, 0, RaceTrack.Ground(1000, 0) + 70) and not RaceTrack.InCorridor(1000, 0, RaceTrack.Ground(1000, 0) + 81), "the corridor's height is over the ground")
	assert(RaceTrack.HeightAboveGround(1000, 0, RaceTrack.Ground(1000, 0) + 3) == 3, "HeightAboveGround")
	local slot = RaceTrack.SlotPosition(1)
	local _, _, slotY = RaceTrack.ToLocal(slot)
	assert(near(slotY, 3, 1e-6), "the staging box stays flat: slots 3 over Origin.Y")
	RaceTrack.SetProfile(nil)
	assert(not RaceTrack.SpikeAt(tile.s, tile.x, ground + 3), "on the flat profile the same height is a jump")
	assert(RaceTrack.SpikeAt(tile.s, tile.x, 3), "...and 3 over Origin.Y is standing")
	pass("heights over the ground: spikes hit standing on a hill, jumping clears them; the corridor and falls measure from the ground; flat staging")
end

----------------------------------------------------------------------
-- 3. Simulated racers against the server's envelope
----------------------------------------------------------------------
-- spec: rawSpeed, lane x, profile, pads, base latency, jitter, sprint policy ("paced" | "never"),
--   jumpEvery, pathFactor (horizontal progress x the slope's path length), speedHack {from,
--   factor}, fakePadAt (boost claimed at these s without a pad), seed.
local SAMPLE = 0.05
local DT = 1 / 60
local function simulate(spec)
	local profile = spec.profile or RaceTrack.FlatProfile()
	RaceTrack.SetProfile(profile)
	local params = RaceMath.Params(spec.rawSpeed or 1e6, 5, 1)
	local rand = generator(spec.seed or 1)
	local x = spec.x or 4.5
	local goAt = 0
	local s0 = -10
	local client = RaceMath.NewState(params, "Perfect", nil, goAt, s0)
	local v = Validator.New(params, goAt, s0, x, "Perfect", spec.pads, profile.Allowance)
	local hist = { { t = goAt, s = s0, y = RaceTrack.Ground(s0, x) + 3 } }
	local walk = 0
	local phase = rand() * 10
	local function latency(t)
		walk = math.clamp(walk + (rand() - 0.5) * 0.02, -0.08, 0.08)
		return math.clamp((spec.base or 0.1) + (spec.jitter or 0.08) * math.sin(t * 1.7 + phase) + walk, 0, 0.3)
	end
	local out = { corrections = 0, boostsClient = 0, boostsServer = 0, strikes = 0 }
	local pending = {}
	local t, nextSample = goAt, goAt + SAMPLE
	local airUntil, jumpAt, nextJump = nil, nil, goAt + (spec.jumpEvery or math.huge)
	local lastS, lastY = s0, RaceTrack.Ground(s0, x) + 3
	local on = true
	local fakeIndex = 1
	local finishT = nil
	local sprintSent, sprintQueue = false, {}
	while t < 80 and not finishT do
		t += DT
		-- Corrections reach the client a latency later: the server pivots it back.
		for index = #pending, 1, -1 do
			if pending[index].at <= t then
				client.s, client.v = pending[index].s, pending[index].v
				lastS = client.s
				table.remove(pending, index)
			end
		end
		local sprint = false
		if spec.policy == "paced" then
			if on and not client.sprinting and client.pool <= 0.001 then
				on = false
			elseif not on and client.pool >= 0.6 then
				on = true
			end
			sprint = on
		end
		-- RaceSprint reaches the server a latency later (edges only).
		if sprint ~= sprintSent then
			sprintSent = sprint
			table.insert(sprintQueue, { at = t + latency(t), on = sprint })
		end
		local jumped = false
		if (not airUntil or t >= airUntil) and t >= nextJump then
			jumped, jumpAt, airUntil, nextJump = true, t, t + 0.5, t + spec.jumpEvery
		end
		local airborne = airUntil ~= nil and t < airUntil
		local before = client.s
		RaceMath.Step(client, { forward = 1, sprint = sprint, grounded = not airborne, jumped = jumped }, DT, params, t)
		local progress = client.s - before
		if spec.pathFactor then
			-- The worst honest case on a slope: horizontal progress = the path's length.
			local grade = (RaceTrack.Ground(client.s + 1, x) - RaceTrack.Ground(client.s - 1, x)) / 2
			client.s = before + progress * math.sqrt(1 + grade * grade)
		end
		local hack = spec.speedHack
		if hack and t >= hack.from then
			client.s = before + (client.s - before) * hack.factor
		end
		local s = client.s
		local y = RaceTrack.Ground(s, x) + 3
		if airborne then
			-- A jump off the slope: its arc over the takeoff height (the ground may fall away).
			local takeoff = RaceTrack.Ground(lastS, x) + 3
			y = math.max(y, takeoff + 7 * math.sin(math.pi * (t - jumpAt) / 0.5))
		end
		-- Spikes as the client sees them (the server confirms with its own swept test).
		local tile = RaceTrack.SweptSpike(lastS, x, s, x, lastY, y)
		if tile then
			RaceMath.SpikeHit(client, t)
		end
		-- Pads, predicted on the exact footprint.
		local pad, fraction = RaceTrack.SweptPad(spec.pads, lastS, x, lastY, s, x, y, 0)
		if pad and RaceMath.PadHit(client, pad.boost, pad.seconds, t - DT * (1 - fraction)) then
			out.boostsClient += 1
		end
		local fake = spec.fakePadAt and spec.fakePadAt[fakeIndex]
		if fake and s >= fake then
			fakeIndex += 1
			RaceMath.PadHit(client, PADS.DefaultBoost, PADS.DefaultSeconds, t)
			out.boostsClient += 1
		end
		lastS, lastY = s, y
		table.insert(hist, { t = t, s = s, y = y })
		if s >= TRACK.Length and not finishT then
			finishT = t
		end
		-- The server's samples: the client's history a latency late.
		while t >= nextSample do
			local now = nextSample
			nextSample += SAMPLE
			while sprintQueue[1] and sprintQueue[1].at <= now do
				v.sprint = table.remove(sprintQueue, 1).on
			end
			local at = now - latency(now)
			local a, b = hist[1], hist[#hist]
			for index = #hist, 2, -1 do
				if hist[index - 1].t <= at then
					a, b = hist[index - 1], hist[index]
					break
				end
			end
			local w = if b.t > a.t then math.clamp((at - a.t) / (b.t - a.t), 0, 1) else 1
			local os_ = a.s + (b.s - a.s) * w
			local oy = a.y + (b.y - a.y) * w
			local result = Validator.Step(v, now, os_, x, oy)
			if result.pad then
				out.boostsServer += 1
			end
			if result.correction then
				out.corrections += 1
				out.firstCorrectionAt = out.firstCorrectionAt or now
				table.insert(pending, { at = now + latency(now), s = result.correction.s, v = result.correction.v })
			end
		end
	end
	out.finishT = finishT
	out.strikes = v.strikes
	RaceTrack.SetProfile(nil)
	return out
end

do
	local runs, finishes = 0, {}
	for index, rawSpeed in { 1, 1e6, 1e18 } do
		for _, variant in {
			{ label = "paced", policy = "paced" },
			{ label = "jumps on hills and crests", policy = "paced", jumpEvery = 2.3 },
			{ label = "path length as progress", policy = "never", pathFactor = true },
		} do
			for _, latencyCase in { { base = 0.03, jitter = 0.03 }, { base = 0.15, jitter = 0.12 } } do
				runs += 1
				local result = simulate({
					rawSpeed = rawSpeed, profile = hilly, policy = variant.policy, jumpEvery = variant.jumpEvery,
					pathFactor = variant.pathFactor, base = latencyCase.base, jitter = latencyCase.jitter, seed = runs * 7 + index,
					x = RaceTrack.LaneX(1 + (runs % 8)),
				})
				assert(result.corrections == 0, string.format("honest Speed %g on the hills (%s, %.2f s latency): %d correction(s)", rawSpeed, variant.label, latencyCase.base, result.corrections))
				assert(result.finishT, "finishes")
				finishes[rawSpeed] = math.max(finishes[rawSpeed] or 0, result.finishT)
			end
		end
	end
	-- A x1.3 hacker on the hills is still corrected (from GO and mid-race).
	local hackGo = simulate({ rawSpeed = 1e6, profile = hilly, policy = "paced", speedHack = { from = 0, factor = 1.3 }, seed = 5 })
	local hackMid = simulate({ rawSpeed = 1e18, profile = hilly, policy = "paced", speedHack = { from = 4, factor = 1.3 }, seed = 6 })
	assert(hackGo.corrections >= 1 and hackGo.firstCorrectionAt <= 3.2, "x1.3 from GO on the hills corrected within ~3 s")
	assert(hackMid.corrections >= 1 and hackMid.firstCorrectionAt - 4 <= 2.2, "x1.3 mid-race at the speed cap on the hills corrected within ~2 s")
	-- The same honest racer on the flat arena behaves as before (no allowance, no pads).
	local flatRun = simulate({ rawSpeed = 1e6, policy = "paced", seed = 11 })
	assert(flatRun.corrections == 0 and RaceTrack.FlatProfile().Allowance == 0, "flat arena: nothing changes")
	pass(string.format("envelope on the hills: %d honest runs (Speed 1 / 1e6 / 1e18, jumps, crests, path-length progress, 0-300 ms) with 0 corrections; x1.3 caught after %.2f s / %.2f s",
		runs, hackGo.firstCorrectionAt, hackMid.firstCorrectionAt - 4))
end

----------------------------------------------------------------------
-- 4. Speed pads
----------------------------------------------------------------------
do
	-- The builder's pads, from their parts.
	local folder = assert(arena:FindFirstChild("SpeedPads"), "RaceArena.SpeedPads")
	assert(folder.ModelStreamingMode == roblox.Enum.ModelStreamingMode.Persistent, "pads are Persistent (phones keep them)")
	local pads = RaceTrack.PadsFromParts(folder:GetDescendants())
	assert(#pads == #RaceArenaBuilder.PadSpots and #pads == 3, "three pads (the arrows are not pads)")
	for index, pad in pads do
		local s = RaceArenaBuilder.PadSpots[index]
		assert(near(pad.s0, s - 8, 1e-3) and near(pad.s1, s + 8, 1e-3) and near(pad.x0, -9, 1e-3) and near(pad.x1, 9, 1e-3) and near(pad.top, 0.2, 1e-3),
			"pad footprint at s " .. s)
		assert(pad.boost == PADS.DefaultBoost and pad.seconds == PADS.DefaultSeconds, "default Boost / Seconds")
		for _, spike in RaceTrack.SpikeTiles() do
			assert(math.abs(spike.s - s) > 20, "pads clear of the spike rows")
		end
	end
	for _, part in folder:GetDescendants() do
		if part:IsA("BasePart") then
			assert(not part.CanCollide and not part.CanTouch and not part.CanQuery and part.Anchored, "pads are inert")
			assert(part:HasTag("RaceSpeedPad") and not part:HasTag("RaceDecorLowPower"), "tagged RaceSpeedPad, never hidden on phones")
		end
	end
	-- Attributes are clamped; a yawed or tilted pad still gives a footprint.
	local part = roblox.Instance.new("Part")
	part.Name = "SpeedPad"
	part.Size = roblox.Vector3.new(10, 0.2, 10)
	part.CFrame = roblox.CFrame.new(RaceTrack.ToWorld(700, 0, 5)) * roblox.CFrame.Angles(math.rad(5), math.rad(45), 0)
	part:SetAttribute("Boost", 9)
	part:SetAttribute("Seconds", -1)
	local odd = assert(RaceTrack.PadFromPart(part), "a yawed pad")
	assert(odd.boost == PADS.MaxBoost and odd.seconds == 0.1 and odd.s1 - odd.s0 > 13 and odd.top > 5, "clamped attributes, the corners' box")
	-- The payload round trip (the Staged event), bad rows dropped.
	local payload = RaceTrack.PadsToPayload(pads)
	local back = RaceTrack.PadsFromPayload(payload)
	assert(#back == 3 and back[2].s0 == pads[2].s0 and back[3].boost == pads[3].boost, "payload round trip")
	assert(#RaceTrack.PadsFromPayload({ { 1, 0, 0, 1, 0, 1, 1 }, "x", { 0 / 0, 1, 2, 3, 4, 5, 6 } }) == 0 and #RaceTrack.PadsFromPayload(nil) == 0, "bad rows dropped")
	-- Feet on the pad: over it, within 1 below .. 3 above its top; a jump over it misses.
	local pad = pads[1]
	local p, fraction = RaceTrack.SweptPad(pads, pad.s0 - 10, 0, 3.2, pad.s0 + 2, 0, 3.2, 0)
	assert(p == pad and near(fraction, 10 / 12, 1e-6), "running onto the pad: hit where it enters")
	assert(RaceTrack.SweptPad(pads, pad.s0 - 10, 0, 7.5, pad.s0 + 20, 0, 7.5, 0) == nil, "4.3 studs over it: a jump clears it")
	assert(RaceTrack.SweptPad(pads, pad.s0 - 10, 12, 3.2, pad.s1 + 10, 12, 3.2, 0) == nil, "beside it: nothing")
	assert(RaceTrack.SweptPad(pads, pad.s0 - 10, 9.8, 3.2, pad.s1 + 10, 9.8, 3.2, 0) == nil
		and RaceTrack.SweptPad(pads, pad.s0 - 10, 9.8, 3.2, pad.s1 + 10, 9.8, 3.2, PADS.ServerMargin) == pad, "the server's margin grants an edge the client's exact test missed")
	-- A second pad refreshes, never stacks.
	local params = RaceMath.Params(1e6, 5, 1)
	local state = RaceMath.NewState(params, "Ok", params.Vc, 0)
	assert(RaceMath.PadHit(state, 1.25, 1.5, 10) and near(state.v, params.Vc * 1.25, 1e-9) and state.boostUntil == 11.5, "a pad: kick x1.25 and 1.5 s of boost")
	assert(not RaceMath.PadHit(state, 1.25, 1.5, 11) and near(state.v, params.Vc * 1.25, 1e-9) and state.boostUntil == 12.5, "a second pad: refreshed, no second kick")
	assert(near(RaceMath.Target(state, { forward = 1 }, params, 12) / params.Vc, 1.25, 1e-9) and RaceMath.Target(state, { forward = 1 }, params, 12.6) == params.Vc, "the cap x1.25 while it lasts, x1 after")
	assert(RaceMath.BoostAt(state, 12) == 1.25 and RaceMath.BoostAt(state, 13) == 1, "BoostAt")

	-- Honest crossings on the hills with the pads: boosted on both sides, never corrected, faster.
	local hillyPads = {}
	for _, row in pads do
		-- The same pads laid on the hills.
		local copy = table.clone(row)
		copy.top = RaceTrack.Ground((row.s0 + row.s1) / 2, 0, hilly) + 0.2
		table.insert(hillyPads, copy)
	end
	local worstBoostCorrections, faster = 0, 0
	for index, rawSpeed in { 1, 1e6, 1e18 } do
		local withPads = simulate({ rawSpeed = rawSpeed, profile = hilly, pads = hillyPads, policy = "paced", x = 4.5, base = 0.12, jitter = 0.1, seed = 40 + index })
		local without = simulate({ rawSpeed = rawSpeed, profile = hilly, policy = "paced", x = 4.5, base = 0.12, jitter = 0.1, seed = 40 + index })
		assert(withPads.corrections == 0, string.format("honest pad crossings at Speed %g: %d correction(s)", rawSpeed, withPads.corrections))
		assert(withPads.boostsClient == 3 and withPads.boostsServer == 3, string.format("3 pads boosted on both sides at Speed %g (client %d, server %d)", rawSpeed, withPads.boostsClient, withPads.boostsServer))
		assert(withPads.finishT < without.finishT, "the pads make the race faster")
		faster = math.max(faster, without.finishT - withPads.finishT)
		worstBoostCorrections = math.max(worstBoostCorrections, withPads.corrections)
	end
	-- The edge of a pad the client missed and the server granted: still no correction.
	local edge = simulate({ rawSpeed = 1e12, pads = pads, policy = "paced", x = 9.6, seed = 51 })
	assert(edge.corrections == 0 and edge.boostsClient == 0 and edge.boostsServer >= 1, "a pad's edge: the server grants, the client did not boost, no correction")
	-- A boost claimed without a pad (lane 8, far from them): corrected.
	local cheat = simulate({ rawSpeed = 1e12, pads = pads, policy = "paced", x = 31.5, fakePadAt = { 442, 1042, 1492 }, seed = 52 })
	assert(cheat.boostsServer == 0 and cheat.corrections >= 1, "a boost without a pad is corrected (" .. cheat.corrections .. ")")

	-- Balance: the plausibility floor with the pads stays over the record floor and well under
	-- the best honest race with every pad.
	local top = RaceMath.Params(1e300, 70, 1)
	local floor = RaceMath.PlausibleMs(top, pads, hilly.Allowance)
	assert(floor >= U4.Race.Validation.MinPlausibleMs and floor <= RaceMath.PlausibleMs(top), "pads lower the floor, never under the record floor (MinPlausibleMs)")
	local best = simulate({ rawSpeed = 1e300, pads = pads, policy = "paced", x = 4.5, base = 0, jitter = 0, seed = 60 })
	assert(best.finishT * 1000 > floor * 1.3 and best.finishT * 1000 > U4.Race.Validation.MinPlausibleMs * 1.5,
		string.format("the fastest honest race with every pad (%.2f s) is far over the floors (%d ms)", best.finishT, floor))
	pass(string.format("pads: 3 from the builder, clamped attributes, payload round trip, feet rule, server margin; honest crossings boosted on both sides with 0 corrections (up to %.2f s faster); a claimed boost corrected %d time(s); refresh never stacks; best race with pads %.2f s > floor %d ms",
		faster, cheat.corrections, best.finishT, floor))
end

----------------------------------------------------------------------
-- 5. Ground adhesion (2026-09-26, owner: Sonic Dash speeds)
----------------------------------------------------------------------
-- A root running down the hills at a constant speed, frame by frame (Heartbeat: the adhesion cap,
-- as Movement/InstantMovementController applies it), physics at 240 Hz (gravity; the floor holds
-- the root at its standing height and lifts it along a climb, like the humanoid's hip spring).
-- Without adhesion a racer leaves every crest and flies over spike rows; with it the root stays
-- within the spikes' reach (under 0.4 studs over its standing height) the whole way, and a
-- jump (not capped) still clears a row.
do
	RaceTrack.SetProfile(hilly)
	local G, STAND = 196.2, RaceTrack.RootHeight
	local function run(speed, adhesion, x)
		local s, y, vy = 0, RaceTrack.Ground(0, x) + STAND, 0
		local worst, worstAt, flown, rowsAirborne = 0, 0, 0, 0
		local rowIndex, rows = 1, RaceTrack.SpikeRows()
		local frame, sub = 1 / 60, 1 / 240
		while s < TRACK.Length do
			if adhesion then
				vy = RaceTrack.AdhesionVelocity(s, x, y, speed, 0, vy, STAND)
			end
			for _ = 1, 4 do
				local g0 = RaceTrack.Ground(s, x)
				s += speed * sub
				vy -= G * sub
				y += vy * sub
				local g1 = RaceTrack.Ground(s, x)
				if y <= g1 + STAND then
					y = g1 + STAND
					vy = math.max(vy, (g1 - g0) / sub)
				end
				local hover = y - g1 - STAND
				if hover > worst then
					worst, worstAt = hover, s
				end
				if hover > 0.4 then
					flown += speed * sub
				end
				local row = rows[rowIndex]
				if row and s >= row.s then
					rowIndex += 1
					if hover >= RaceTrack.SpikeHeight() - STAND then
						rowsAirborne += 1
					end
				end
			end
		end
		return worst, worstAt, flown, rowsAirborne
	end
	local lines = {}
	for _, speed in { 105, 300, 420, 609, 913 } do
		for _, x in { 0, 31.5 } do
			local worst, at, flown, airborne = run(speed, true, x)
			assert(worst < 0.4 and airborne == 0, string.format("adhesion at %d studs/s (x %g): hover %.2f at s %.0f, %d rows flown over", speed, x, worst, at, airborne))
			if x == 0 then
				local freeWorst, _, freeFlown, freeAirborne = run(speed, false, x)
				table.insert(lines, string.format("%d: %.2f (free %.1f, %.0f studs airborne, %d rows)", speed, worst, freeWorst, freeFlown, freeAirborne))
				if speed >= 420 then
					assert(freeWorst > 1 and freeFlown > 100, "without adhesion a racer flies off the crests at " .. speed)
				end
			end
		end
	end
	-- The cap itself: never more upward speed than given; a jump's height (over SnapStuds) is left
	-- alone; a root under its standing height may rise; on a flat floor nothing changes.
	math.randomseed(11)
	for _ = 1, 2000 do
		local s, x = math.random() * 2000, (math.random() - 0.5) * 63
		local y = RaceTrack.Ground(s, x) + STAND + (math.random() - 0.5) * 8
		local vy = (math.random() - 0.5) * 120
		local capped = RaceTrack.AdhesionVelocity(s, x, y, 100 + math.random() * 800, (math.random() - 0.5) * 200, vy, STAND)
		assert(capped <= vy, "never adds upward speed")
		if y - RaceTrack.Ground(s, x) - STAND > U4.Race.Adhesion.SnapStuds then
			assert(capped == vy, "a jump's height is left alone")
		end
	end
	local sCrest = 100 + HILL_L * 0.5 -- the first crest
	local jumpY = RaceTrack.Ground(sCrest, 0) + STAND + U4.Race.Adhesion.SnapStuds + 0.5
	assert(RaceTrack.AdhesionVelocity(sCrest, 0, jumpY, 609, 0, 40, STAND) == 40, "a jump over a crest keeps its lift")
	assert(RaceTrack.AdhesionVelocity(sCrest, 0, RaceTrack.Ground(sCrest, 0) + STAND - 0.5, 300, 0, 50, STAND) > 0, "under its standing height the root may rise, even on a crest")
	RaceTrack.SetProfile(nil)
	assert(RaceTrack.AdhesionVelocity(500, 0, STAND, 609, 0, 0, STAND) == 0 and RaceTrack.AdhesionVelocity(500, 0, STAND + 0.05, 609, 0, -3, STAND) == -3,
		"flat floor, standing: nothing changes")
	pass("ground adhesion on 9-degree hills: the root stays within the spikes' reach at every speed (worst hover " .. table.concat(lines, "; ") .. ")")
end

print(string.format("test_u4_race_terrain: %d checks passed", passed))
