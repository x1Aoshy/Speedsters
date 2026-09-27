-- SonicBurstMath.luau
-- The numbers of the Sonic Burst ability (Core/Abilities/SonicBurstService on the server,
-- Movement/SonicBurstClient on the client), in one place so both sides and
-- audit/test_sonic_burst agree:
--
--   * the charge: held on the sprint (Shift, the gamepad's sprint trigger, or the touch
--     button), the stamina bar drains as usual, and the more of it this hold has spent the
--     fuller the charge (full after FullChargeSeconds of draining, or an empty bar);
--   * the throw: dash speed = speed + Gain * ln(1 + speed / Knee) * power, never over
--     MaxDashSpeed, where power grows with the charge (MinPower at the least, 1 at full).
--     `speed` is the player's speedometer speed, or how fast they already run if faster.
--     Logarithmic: a new player at 16 studs/s dashes about 6x faster (a quick shove of ~30
--     studs); a veteran at 1000 studs/s gets a massive ~500-stud burst. MaxDashSpeed caps
--     the burst (it never slows anyone down), and the client stops the dash at the first
--     wall;
--   * MovementGuard's allowance for it (how many times the walk speed the dash moves);
--   * the aim: the throw goes where the mouse pointer is (a free cursor) or the camera looks
--     (shift-lock, gamepads, touch screens), and keeps turning with it while it lasts;
--   * the camera's FOV punch: +FovPunch degrees at once, then an elastic settle.
local SonicBurstMath = {}

SonicBurstMath.MinSpeed = 16
-- Seconds of sprinting drain for a full charge (less if the bar empties first).
SonicBurstMath.FullChargeSeconds = 1.6
-- Below this the release is only the end of a sprint, not a burst.
SonicBurstMath.MinCharge = 0.25
-- The throw's power at the least charge that fires, and at full charge.
SonicBurstMath.MinPower = 0.35
-- A press shorter than this is only a sprint: no bubble.
SonicBurstMath.ShowAfterSeconds = 0.25

local function number(value, default)
	local n = tonumber(value)
	if n == nil or n ~= n or math.abs(n) == math.huge then
		return default
	end
	return n
end

function SonicBurstMath.Cooldown(config)
	return math.clamp(number(config and config.AbilitySonicBurstCooldownSeconds, 9), 1, 60)
end

function SonicBurstMath.Charge(config)
	return math.clamp(number(config and config.AbilitySonicBurstChargeSeconds, 0.4), 0.1, 2)
end

function SonicBurstMath.Dash(config)
	return math.clamp(number(config and config.AbilitySonicBurstDashSeconds, 0.35), 0.1, 1.5)
end

-- The speed a burst scales from: the speedometer's, or the current one if faster.
function SonicBurstMath.ReferenceSpeed(selected, current)
	return math.max(SonicBurstMath.MinSpeed, number(selected, 0), number(current, 0))
end

-- The charge after this hold: `startStamina` when it began, `stamina` now, `sprintSeconds`
-- spent actually sprinting (the server accepted it), `drain` the bar's drain per second.
-- It never goes down during a hold (`previous`). A bar that does not drain (an unlimited
-- stamina boost) charges with the time sprinted instead.
function SonicBurstMath.ChargeLevel(startStamina, stamina, sprintSeconds, drain, previous)
	local start = math.max(0, number(startStamina, 0))
	local spent = math.max(0, start - number(stamina, start))
	local rate = math.max(0.1, number(drain, 5.78))
	local full = math.max(0.25, math.min(start, rate * SonicBurstMath.FullChargeSeconds))
	local byStamina = if start > 0 then spent / full else 0
	local seconds = math.max(0, number(sprintSeconds, 0))
	local byTime = if seconds > 0.3 and spent < 0.05 then seconds / SonicBurstMath.FullChargeSeconds else 0
	return math.clamp(math.max(number(previous, 0), byStamina, byTime), 0, 1)
end

-- The throw's power for a charge (1 at full charge; MinPower at the least that fires).
function SonicBurstMath.Power(charge)
	local c = math.clamp(number(charge, 1), 0, 1)
	return SonicBurstMath.MinPower + (1 - SonicBurstMath.MinPower) * c
end

function SonicBurstMath.DashSpeed(speed, config, charge)
	local gain = math.max(0, number(config and config.AbilitySonicBurstGain, 90)) * SonicBurstMath.Power(charge)
	local knee = math.max(1, number(config and config.AbilitySonicBurstKnee, 12))
	local cap = math.max(SonicBurstMath.MinSpeed, number(config and config.AbilitySonicBurstMaxDashSpeed, 2200))
	local base = math.max(SonicBurstMath.MinSpeed, number(speed, SonicBurstMath.MinSpeed))
	-- Capped for the physics' sake, but never slower than the player already runs.
	return math.max(base, math.min(cap, base + gain * math.log(1 + base / knee)))
end

function SonicBurstMath.DashDistance(speed, config, charge)
	return SonicBurstMath.DashSpeed(speed, config, charge) * SonicBurstMath.Dash(config)
end

-- How many times its walk speed the dash moves the player (MovementGuard's allowance).
function SonicBurstMath.GuardMultiplier(speed, config, charge)
	local base = math.max(SonicBurstMath.MinSpeed, number(speed, SonicBurstMath.MinSpeed))
	return math.clamp(SonicBurstMath.DashSpeed(base, config, charge) / base, 1, 8)
end

-- A flat unit direction from what the client sent, or `fallback` (the root's look).
function SonicBurstMath.FlatDirection(direction, fallback)
	for _, candidate in { direction, fallback } do
		if typeof(candidate) == "Vector3" then
			local flat = Vector3.new(candidate.X, 0, candidate.Z)
			local length = flat.Magnitude
			if length == length and length > 0.01 and length ~= math.huge then
				return flat / length
			end
		end
	end
	return Vector3.new(0, 0, -1)
end

-- Where a pointer aims from `rootPosition`: the point on the ground level of the root under
-- the pointer's ray (`origin`, `direction`), or, if the ray does not come down in front of the
-- player (pointed at the sky, or at the player's feet), the flat way the ray points.
SonicBurstMath.AimMinDistance = 3
function SonicBurstMath.AimAt(rootPosition, origin, direction, fallback)
	if typeof(rootPosition) ~= "Vector3" or typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		return SonicBurstMath.FlatDirection(direction, fallback)
	end
	if math.abs(direction.Y) > 1e-4 then
		local t = (rootPosition.Y - origin.Y) / direction.Y
		if t > 0 then
			local point = origin + direction * t
			local flat = Vector3.new(point.X - rootPosition.X, 0, point.Z - rootPosition.Z)
			if flat.Magnitude >= SonicBurstMath.AimMinDistance then
				return flat.Unit
			end
		end
	end
	return SonicBurstMath.FlatDirection(direction, fallback)
end

-- Turns the dash's `current` direction toward `wanted` (both flat units) over `dt` seconds.
SonicBurstMath.SteerRate = 14
function SonicBurstMath.Steer(current, wanted, dt)
	local blend = math.clamp(number(dt, 0) * SonicBurstMath.SteerRate, 0, 1)
	local mixed = current:Lerp(wanted, blend)
	if mixed.Magnitude < 0.05 then
		return wanted
	end
	return mixed.Unit
end

-- The FOV punch, `t` seconds after the burst: +punch within 0.07 s, then an elastic,
-- damped return to 0 (gone after about 1.2 s).
SonicBurstMath.PunchRise = 0.07
SonicBurstMath.PunchLength = 1.2
function SonicBurstMath.FovOffset(t, punch)
	punch = number(punch, 18)
	if t < 0 or t >= SonicBurstMath.PunchLength then
		return 0
	end
	local rise = SonicBurstMath.PunchRise
	if t < rise then
		local x = t / rise
		return punch * (1 - (1 - x) * (1 - x))
	end
	local s = t - rise
	return punch * math.exp(-s * 6.5) * math.cos(s * 9)
end

return SonicBurstMath
