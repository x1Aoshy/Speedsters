-- TacoFire: steady flames made from the splash the raining tacos make when they hit the floor
-- (TacoEventAssets.StruckVFX). That splash is a one-shot burst; its fire pieces (Fire,
-- FireSpecs, Embers, "3"), in their warm colours, run here as continuous emitters instead, so
-- the Taco Treadmill burns in the same pixel-fire the tacos crash in. Used by the server for
-- the treadmill's standing fire and by Shared/TacoMeteor for the meteor on its way down.
local TacoFire = {}

-- Emitter name in StruckVFX -> particles a second, and how much of the burst's speed to keep
-- (a burst flies outwards fast; a flame climbs slowly).
TacoFire.Recipe = {
	Fire = { Rate = 5, Speed = 1 },
	FireSpecs = { Rate = 8, Speed = 0.3 },
	["Embers [20]"] = { Rate = 4, Speed = 0.45 },
	["3"] = { Rate = 4, Speed = 0.35 },
}
TacoFire.MaxPerFlame = 6

local function isWarm(emitter)
	local first = emitter.Color.Keypoints[1].Value
	return first.R >= first.G -- the splash also has green (lettuce) pieces: not fire
end

-- Clones the fire pieces of `struck` into `parent` (a BasePart or an Attachment) and turns
-- them on. options: Scale (particle size, default 1), Rate (multiplier, default 1), Rise
-- (upward pull in studs/s^2, default 8), Spread (degrees, default 28), Locked (ride with the
-- parent, default false). Returns the emitters made.
function TacoFire.Flames(struck, parent, options)
	options = options or {}
	local made, seen = {}, {}
	if not struck then
		return made
	end
	local scale = options.Scale or 1
	for _, source in struck:GetDescendants() do
		if #made >= TacoFire.MaxPerFlame then
			break
		end
		local recipe = source:IsA("ParticleEmitter") and TacoFire.Recipe[source.Name]
		if recipe and isWarm(source) then
			local first = source.Color.Keypoints[1].Value
			local key = source.Name .. math.floor(first.G * 8)
			if not seen[key] then
				seen[key] = true
				local flame = source:Clone()
				local keypoints = {}
				for _, keypoint in flame.Size.Keypoints do
					table.insert(keypoints, NumberSequenceKeypoint.new(keypoint.Time, keypoint.Value * scale, keypoint.Envelope * scale))
				end
				flame.Size = NumberSequence.new(keypoints)
				flame.Speed = NumberRange.new(flame.Speed.Min * recipe.Speed * math.sqrt(scale), flame.Speed.Max * recipe.Speed * math.sqrt(scale))
				flame.Rate = recipe.Rate * (options.Rate or 1)
				flame.EmissionDirection = Enum.NormalId.Top
				flame.SpreadAngle = Vector2.new(options.Spread or 28, options.Spread or 28)
				flame.Acceleration = Vector3.new(0, options.Rise or 8, 0)
				flame.LockedToPart = options.Locked == true
				flame.Enabled = true
				flame.Parent = parent
				table.insert(made, flame)
			end
		end
	end
	return made
end

return TacoFire
