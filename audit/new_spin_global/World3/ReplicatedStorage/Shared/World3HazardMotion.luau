-- World3HazardMotion.luau
-- The moving hazards of World 3 (Desert) as pure functions of time.
--
-- Nothing here replicates per frame. The server reads the map once
-- (World3HazardLayout), publishes the numbers below and a shared start time, and every
-- client draws the hazards itself from Workspace:GetServerTimeNow() and tests its own
-- character against them, exactly as World 2's tree slammers do. Same pose on every
-- machine, and a player is hit by what they can see.
--
-- Layout entries are plain numbers so they travel as JSON:
--   Tumbleweed { XFrom, XTo, Z, FloorY, Radius, Speed, Offset }   rolls across Stage 2
--   Roadrunner { ZFrom, ZTo, CenterX, Amplitude, Wavelength, FloorY, Height, Radius,
--                Speed, Offset }                                  zigzags along Stage 3
--   Cart       { XMin, XMax, Z, BaseY, Length, Width, Height, Speed, Offset }
--                                                                 shuttles on a Stage 7 rail
--   Serpent    { ZStart, ZEnd, XMin, XMax, FloorY, Height, BodyLength, Speed, WarnTime,
--                Period, Offset, HeadRadius, BodyRadius, Dugouts = { { X, Z, Radius } } }
--                                                                 sweeps the Stage 8 canyon
--   Scorpion   { XFrom, XTo, Z, FloorY, Length, Width, Height, Speed, Pause, Offset }
--                                                                 crosses the Stage 9 trail

local World3HazardMotion = {}

-- Tuning, shared by the layout reader, the server and the clients.
World3HazardMotion.TumbleweedPause = 1.2 -- seconds out of sight between rolls
World3HazardMotion.HitMargin = 0.6 -- studs of forgiveness around every hazard
-- A cart only hurts from the side: someone standing on its roof rides it.
World3HazardMotion.CartRideClearance = 1.5
World3HazardMotion.SerpentHeadReach = 6
-- The serpent's body: this many points from the head to the tail.
World3HazardMotion.SerpentPoints = 16

local function positive(value, fallback)
	value = tonumber(value)
	if value and value == value and value > 0 and value ~= math.huge then
		return value
	end
	return fallback
end

----------------------------------------------------------------------
-- Tumbleweeds
----------------------------------------------------------------------
-- Position, roll angle (radians about the Z axis) and whether it is on the floor now.
function World3HazardMotion.TumbleweedPose(lane, elapsed)
	local distance = math.abs(lane.XTo - lane.XFrom)
	local speed = positive(lane.Speed, 40)
	local radius = positive(lane.Radius, 5)
	local travel = distance / speed
	local period = travel + World3HazardMotion.TumbleweedPause
	local t = (elapsed + (lane.Offset or 0)) % period
	local rolled = math.min(t, travel) * speed
	local direction = if lane.XTo >= lane.XFrom then 1 else -1
	local bounce = math.abs(math.sin(rolled / (radius * 1.6))) * radius * 0.35
	local position = Vector3.new(lane.XFrom + direction * rolled, lane.FloorY + radius + bounce, lane.Z)
	return position, -direction * rolled / radius, t < travel
end

function World3HazardMotion.TumbleweedHits(lane, elapsed, point)
	local position, _, active = World3HazardMotion.TumbleweedPose(lane, elapsed)
	return active and (point - position).Magnitude <= positive(lane.Radius, 5) + World3HazardMotion.HitMargin
end

----------------------------------------------------------------------
-- Roadrunners
----------------------------------------------------------------------
-- Position of the body's centre and the level direction it runs in.
function World3HazardMotion.RoadrunnerPose(runner, elapsed)
	local length = math.abs(runner.ZTo - runner.ZFrom)
	local speed = positive(runner.Speed, 50)
	local period = 2 * length / speed
	local run = ((elapsed + (runner.Offset or 0)) % period) * speed
	local forward = 1
	if run > length then
		run = 2 * length - run
		forward = -1
	end
	local along = if runner.ZTo >= runner.ZFrom then 1 else -1
	local wave = 2 * math.pi / positive(runner.Wavelength, 150)
	local x = runner.CenterX + runner.Amplitude * math.sin(run * wave)
	local z = runner.ZFrom + along * run
	local heading = Vector3.new(runner.Amplitude * wave * math.cos(run * wave) * forward, 0, along * forward)
	return Vector3.new(x, runner.FloorY + positive(runner.Height, 8) / 2, z), heading.Unit
end

function World3HazardMotion.RoadrunnerHits(runner, elapsed, point)
	local position = World3HazardMotion.RoadrunnerPose(runner, elapsed)
	local level = Vector3.new(point.X - position.X, 0, point.Z - position.Z).Magnitude
	local height = positive(runner.Height, 8)
	return level <= positive(runner.Radius, 4) + World3HazardMotion.HitMargin
		and point.Y >= runner.FloorY - 1
		and point.Y <= runner.FloorY + height + World3HazardMotion.HitMargin
end

----------------------------------------------------------------------
-- Carts
----------------------------------------------------------------------
-- Centre of the cart and its speed along X (signed).
function World3HazardMotion.CartPose(cart, elapsed)
	local speed = positive(cart.Speed, 40)
	local travel = math.max(0, (cart.XMax - cart.XMin) - cart.Length)
	if travel <= 0 then
		return Vector3.new((cart.XMin + cart.XMax) / 2, cart.BaseY + cart.Height / 2, cart.Z), 0
	end
	local period = 2 * travel / speed
	local run = ((elapsed + (cart.Offset or 0)) % period) * speed
	local velocity = speed
	if run > travel then
		run = 2 * travel - run
		velocity = -speed
	end
	return Vector3.new(cart.XMin + cart.Length / 2 + run, cart.BaseY + cart.Height / 2, cart.Z), velocity
end

-- `rootY` is the character's root height: a player riding on the roof is not hit.
function World3HazardMotion.CartHits(cart, elapsed, point, rootY)
	local centre = World3HazardMotion.CartPose(cart, elapsed)
	local margin = World3HazardMotion.HitMargin
	local roof = cart.BaseY + cart.Height
	if rootY and rootY >= roof + World3HazardMotion.CartRideClearance then
		return false
	end
	return math.abs(point.X - centre.X) <= cart.Length / 2 + margin
		and math.abs(point.Z - centre.Z) <= cart.Width / 2 + margin
		and point.Y >= cart.BaseY - margin
		and point.Y <= roof + margin
end

----------------------------------------------------------------------
-- The serpent
----------------------------------------------------------------------
-- "Rest", "Warning" (it is about to come) or "Pass" (it is sweeping the canyon), the Z of
-- its head during the pass, and how far through the current phase it is (0-1).
function World3HazardMotion.SerpentState(serpent, elapsed)
	local direction = if serpent.ZEnd >= serpent.ZStart then 1 else -1
	local distance = math.abs(serpent.ZEnd - serpent.ZStart) + serpent.BodyLength
	local passTime = distance / positive(serpent.Speed, 100)
	local t = (elapsed + (serpent.Offset or 0)) % positive(serpent.Period, 16)
	if t < serpent.WarnTime then
		return "Warning", serpent.ZStart, t / serpent.WarnTime
	end
	t -= serpent.WarnTime
	if t < passTime then
		return "Pass", serpent.ZStart + direction * t * positive(serpent.Speed, 100), t / passTime
	end
	return "Rest", nil, 0
end

function World3HazardMotion.InDugout(serpent, point)
	for _, dugout in serpent.Dugouts or {} do
		local level = Vector3.new(point.X - dugout.X, 0, point.Z - dugout.Z).Magnitude
		if level <= dugout.Radius then
			return true
		end
	end
	return false
end

-- Whether `z` lies in the canyon between the finish and Stage 8's checkpoint. The
-- checkpoint and the finish block are always safe, even while the tail leaves.
function World3HazardMotion.InCanyon(serpent, z)
	return z >= math.min(serpent.ZStart, serpent.ZEnd) and z <= math.max(serpent.ZStart, serpent.ZEnd)
end

-- The serpent kills on contact: a body point within its body's thickness (its head is
-- wider) of the line through its body. The dugouts are always out of its reach.
local function distanceToSegment(point, a, b)
	local ab = b - a
	local length = ab:Dot(ab)
	local t = if length > 0 then math.clamp((point - a):Dot(ab) / length, 0, 1) else 0
	return (point - (a + ab * t)).Magnitude
end

function World3HazardMotion.SerpentHits(serpent, elapsed, point)
	local phase = World3HazardMotion.SerpentState(serpent, elapsed)
	if phase ~= "Pass" or World3HazardMotion.InDugout(serpent, point) then
		return false
	end
	local count = World3HazardMotion.SerpentPoints
	local body = World3HazardMotion.SerpentBody(serpent, elapsed, count)
	if not body then
		return false
	end
	local headRadius = positive(serpent.HeadRadius, 5)
	local bodyRadius = positive(serpent.BodyRadius, 3.5)
	local margin = World3HazardMotion.HitMargin
	for index = 1, count - 1 do
		local a, b = body[index], body[index + 1]
		if a and b then
			local radius = if index == 1 then headRadius else bodyRadius * (1 - 0.35 * (index - 1) / (count - 1))
			if distanceToSegment(point, a, b) <= radius + margin then
				return true
			end
		end
	end
	return false
end

function World3HazardMotion.SerpentBody(serpent, elapsed, count)
	local phase, headZ = World3HazardMotion.SerpentState(serpent, elapsed)
	if phase == "Rest" then
		return nil
	end
	local direction = if serpent.ZEnd >= serpent.ZStart then 1 else -1
	local centreX = (serpent.XMin + serpent.XMax) / 2
	local amplitude = math.max(0, (serpent.XMax - serpent.XMin) / 2 - 12)
	local points = {}
	for index = 1, count do
		local along = (index - 1) / math.max(1, count - 1) * serpent.BodyLength
		local z = headZ - direction * along
		local x = centreX + amplitude * math.sin(z / 38 + elapsed * 2.4)
		local lift = if index == 1 then positive(serpent.HeadRadius, 5) else positive(serpent.BodyRadius, 3.5)
		points[index] = if World3HazardMotion.InCanyon(serpent, z) then Vector3.new(x, serpent.FloorY + lift, z) else false
	end
	return points
end

----------------------------------------------------------------------
-- Scorpions
----------------------------------------------------------------------
-- Across the trail and back: it walks from XFrom to XTo, stops and turns round for Pause
-- seconds, walks back, turns again. Returns its middle, the level way it faces, and how
-- far through a turn it is (0 while walking).
function World3HazardMotion.ScorpionPose(scorpion, elapsed)
	local span = math.abs(scorpion.XTo - scorpion.XFrom)
	local speed = positive(scorpion.Speed, 30)
	local pause = math.max(0, tonumber(scorpion.Pause) or 0.6)
	local travel = span / speed
	local period = 2 * (travel + pause)
	local t = (elapsed + (scorpion.Offset or 0)) % period
	local out = if scorpion.XTo >= scorpion.XFrom then 1 else -1
	local x, facing, turning = scorpion.XFrom, out, 0
	if t < travel then
		x = scorpion.XFrom + out * t * speed
	elseif t < travel + pause then
		x, turning = scorpion.XTo, (t - travel) / math.max(pause, 1e-6)
	elseif t < 2 * travel + pause then
		x, facing = scorpion.XTo - out * (t - travel - pause) * speed, -out
	else
		x, facing, turning = scorpion.XFrom, -out, (t - 2 * travel - pause) / math.max(pause, 1e-6)
	end
	local height = positive(scorpion.Height, 8)
	return Vector3.new(x, scorpion.FloorY + height / 2, scorpion.Z), Vector3.new(facing, 0, 0), turning
end

function World3HazardMotion.ScorpionHits(scorpion, elapsed, point)
	local centre = World3HazardMotion.ScorpionPose(scorpion, elapsed)
	local margin = World3HazardMotion.HitMargin
	return math.abs(point.X - centre.X) <= positive(scorpion.Length, 14) / 2 + margin
		and math.abs(point.Z - centre.Z) <= positive(scorpion.Width, 12) / 2 + margin
		and point.Y >= scorpion.FloorY - 1
		and point.Y <= scorpion.FloorY + positive(scorpion.Height, 8) + margin
end

----------------------------------------------------------------------
-- Stage 10's lasers
----------------------------------------------------------------------
-- Each laser goes round Off -> Warn -> On every Period seconds, the two of them half a
-- period apart (2026-09-18 pre-launch review: they were always on). Off, the beam is a faint
-- ghost anyone can walk through; in the last WarnSeconds before it comes on it flickers
-- (still safe); On, it glows solid red and kills. Clients draw it and the server kills
-- from the same clock (the published start time).
World3HazardMotion.Laser = { Period = 5, OnSeconds = 2.2, WarnSeconds = 1 }
-- The server sees a character a moment late: it counts a laser deadly only when it was
-- already On this long ago too, so a player who crossed while it was off is never killed
-- when the server catches up.
World3HazardMotion.LaserServerLag = 0.25

-- Laser `index`'s state at `elapsed` seconds ("Off", "Warn" or "On") and how far through
-- that state it is (0 to 1).
function World3HazardMotion.LaserState(index, elapsed)
	local settings = World3HazardMotion.Laser
	local offSeconds = settings.Period - settings.OnSeconds - settings.WarnSeconds
	local t = (elapsed + ((tonumber(index) or 1) - 1) * settings.Period / 2) % settings.Period
	if t < offSeconds then
		return "Off", t / offSeconds
	elseif t < offSeconds + settings.WarnSeconds then
		return "Warn", (t - offSeconds) / settings.WarnSeconds
	end
	return "On", (t - offSeconds - settings.WarnSeconds) / settings.OnSeconds
end

-- Whether the server counts laser `index` as deadly at `elapsed`.
function World3HazardMotion.LaserDeadly(index, elapsed)
	return World3HazardMotion.LaserState(index, elapsed) == "On"
		and World3HazardMotion.LaserState(index, elapsed - World3HazardMotion.LaserServerLag) == "On"
end

-- Whether a character whose root is at `root` touches laser box `box` (the beam's own
-- bounds): the body reaches about 3 studs under the root, 2.5 over it and 1 to each side.
function World3HazardMotion.LaserTouches(box, root)
	return box ~= nil
		and root.X >= box.MinX - 1 and root.X <= box.MaxX + 1
		and root.Z >= box.MinZ - 1 and root.Z <= box.MaxZ + 1
		and root.Y > box.MinY - 2.5 and root.Y < box.MaxY + 3
end

----------------------------------------------------------------------
-- One entry point
----------------------------------------------------------------------
World3HazardMotion.Kinds = { "Tumbleweed", "Roadrunner", "Cart", "Serpent", "Scorpion" }

-- Whether body point `point` (with the character's root at height `rootY`) is inside
-- hazard `kind` number `index` at `elapsed` seconds.
function World3HazardMotion.Hits(layout, kind, index, elapsed, point, rootY)
	if kind == "Tumbleweed" then
		local lane = layout.Tumbleweeds and layout.Tumbleweeds[index]
		return lane ~= nil and World3HazardMotion.TumbleweedHits(lane, elapsed, point)
	elseif kind == "Roadrunner" then
		local runner = layout.Roadrunners and layout.Roadrunners[index]
		return runner ~= nil and World3HazardMotion.RoadrunnerHits(runner, elapsed, point)
	elseif kind == "Cart" then
		local cart = layout.Carts and layout.Carts[index]
		return cart ~= nil and World3HazardMotion.CartHits(cart, elapsed, point, rootY)
	elseif kind == "Serpent" then
		return layout.Serpent ~= nil and index == 1 and World3HazardMotion.SerpentHits(layout.Serpent, elapsed, point)
	elseif kind == "Scorpion" then
		local scorpion = layout.Scorpions and layout.Scorpions[index]
		return scorpion ~= nil and World3HazardMotion.ScorpionHits(scorpion, elapsed, point)
	end
	return false
end

return World3HazardMotion
