-- HeatVisionMath.luau
-- Superman's Heat Vision Trail (Config.AbilityHeatVision), in numbers the server, the client
-- and audit/test_heat_vision share: the settings, which way the path runs, how long it is
-- (as far as the aim, within MinLength..MaxLength, short of the first wall) and the slabs of
-- molten rock it is built from.
local HeatVisionMath = {}

HeatVisionMath.Defaults = {
	SkinId = "SupermanSuit",
	MaxLength = 40,
	MinLength = 10,
	BridgeSeconds = 3.5,
	CooldownSeconds = 18,
	Width = 6,
	Thickness = 1.2,
	SegmentLength = 5,
	DrawSeconds = 0.35,
	FadeSeconds = 0.6,
}
-- Studs kept between the end of the path and a wall it stops at.
HeatVisionMath.WallClearance = 1.5
-- A path shorter than this (a wall right in front) is not made, and costs no cooldown.
HeatVisionMath.ShortestPath = 3
-- The path's top sits this far over the floor it starts on, so it shows over it.
HeatVisionMath.Lift = 0.05

-- Config.AbilityHeatVision over the defaults, every number sane.
function HeatVisionMath.Settings(config)
	local given = type(config) == "table" and type(config.AbilityHeatVision) == "table" and config.AbilityHeatVision or {}
	local settings = {}
	for key, value in HeatVisionMath.Defaults do
		local chosen = given[key]
		if type(value) == "number" then
			chosen = tonumber(chosen)
			settings[key] = if chosen and chosen == chosen and chosen > 0 and chosen < math.huge then chosen else value
		else
			settings[key] = if chosen ~= nil then chosen else value
		end
	end
	settings.Enabled = given.Enabled ~= false
	settings.MinLength = math.min(settings.MinLength, settings.MaxLength)
	return settings
end

-- A level direction from `vector`, or from `fallback` when it has none.
function HeatVisionMath.FlatDirection(vector, fallback)
	for _, candidate in { vector, fallback, Vector3.new(0, 0, -1) } do
		if typeof(candidate) == "Vector3" then
			local flat = Vector3.new(candidate.X, 0, candidate.Z)
			if flat.Magnitude > 1e-3 then
				return flat.Unit
			end
		end
	end
	return Vector3.new(0, 0, -1)
end

-- How long the path is: as far as the aim (`aimDistance`, level studs from the feet),
-- never under MinLength or over MaxLength, and short of a wall `wallDistance` ahead.
function HeatVisionMath.Length(settings, aimDistance, wallDistance)
	local length = math.clamp(tonumber(aimDistance) or settings.MaxLength, settings.MinLength, settings.MaxLength)
	if tonumber(wallDistance) then
		length = math.min(length, math.max(0, wallDistance - HeatVisionMath.WallClearance))
	end
	return length
end

-- The slabs of the path, from `start` (the floor at the feet) along `direction` for
-- `length` studs: each SegmentLength long at most, Width wide, Thickness thick, their tops
-- level with the floor it starts on (a little over it), each appearing `Delay` seconds in
-- as the beams draw the path out.
function HeatVisionMath.Segments(settings, start, direction, length)
	local count = math.max(1, math.ceil(length / settings.SegmentLength - 1e-6))
	local each = length / count
	local right = direction:Cross(Vector3.new(0, 1, 0))
	local top = start.Y + HeatVisionMath.Lift
	local slabs = {}
	for index = 1, count do
		local along = Vector3.new(start.X, top - settings.Thickness / 2, start.Z) + direction * (each * (index - 0.5))
		slabs[index] = {
			CFrame = CFrame.fromMatrix(along, right, Vector3.new(0, 1, 0)),
			-- A hair longer than its share, so the slabs meet without a seam.
			Size = Vector3.new(settings.Width, settings.Thickness, each + 0.05),
			Delay = settings.DrawSeconds * (index - 1) / count,
		}
	end
	return slabs
end

-- Seconds until the skill is ready again, from the published ready time (server time).
function HeatVisionMath.ReadyIn(readyAt, now)
	return math.max(0, (tonumber(readyAt) or 0) - now)
end

return HeatVisionMath
