-- TacoMeteor: the Taco Treadmill's arrival (Admin/AdminTreadmillReveal, isTaco).
--
-- A giant golden taco comes down out of the sky like a meteorite, the treadmill inside it,
-- wrapped in fire (the V40 fireball, flame jet and trail in Shared.TacoMeteorAssets) with a
-- ring of tacos orbiting it. It hits the lobby floor: a flash, two shock rings, the V40
-- explosion, the raining tacos' own splash at full size and again all round it, dust. Then
-- the giant taco bursts and the treadmill stands there. The camera follows the whole fall and
-- then circles the landing. (There was a crater of rocks raised from the floor and chunks in
-- the air; the user had them removed on 2026-09-20: only the impact effects stay, and nothing
-- is left burning or standing afterwards.)
--
-- The first half of this module is pure maths (pose, camera) and is tested
-- offline by audit/test_fable_taco_meteor. The second half builds the instances; it only runs
-- on a client. Everything it makes is local to that client and cannot be stood on or block
-- the way to the treadmill.
local Meteor = {}

Meteor.Fall = {
	StartAt = 0.35, -- seconds into the reveal
	Height = 760, -- studs above its place
	Drift = Vector3.new(230, 0, 150), -- and this far to the side: it comes in on a slant
	Power = 2.2, -- > 1: it keeps speeding up until it hits
	Turns = 1.25, -- full tumbles on the way down; it lands upright
}
Meteor.ImpactSeconds = 6 -- how long the landing's effects live
-- The reveal stretches its clock by this much until the hit (Admin/AdminTreadmillReveal), so
-- the fall lasts about 4.5 seconds instead of 2.3 and the words have time to be read.
Meteor.FallStretch = 1.9
Meteor.Camera = {
	GroundUntil = 1.3, -- the shot from the floor, looking up at it
	Blend = 0.8, -- seconds to swing from that shot round to the side (faster is a jump cut)
	ImpactSeconds = 0.7,
	GroundDistance = 78, GroundHeight = 5,
	ChaseDistance = 52, ChaseHeight = 15, ChaseTurn = 0.9,
	OrbitRadius = 46, OrbitCloser = 9, OrbitHeight = 16, OrbitSpin = 0.2,
	Fov = { Ground = 58, Chase = 86, Impact = 96, Orbit = 66 },
}

local function clamp01(x)
	return math.clamp(x, 0, 1)
end

local function smooth(x)
	x = clamp01(x)
	return x * x * (3 - 2 * x)
end

-- 0 when the fall starts, 1 on the floor.
function Meteor.Progress(t, boomAt)
	local fall = Meteor.Fall
	return clamp01((t - fall.StartAt) / math.max(0.01, boomAt - fall.StartAt)) ^ fall.Power
end

-- The world transform that carries the treadmill (as it stands in its place) to where the
-- meteor is at `t`. `heart` is the point it tumbles about.
function Meteor.Pose(t, boomAt, heart)
	local fall = Meteor.Fall
	local left = 1 - Meteor.Progress(t, boomAt)
	if left <= 0 then
		return CFrame.new()
	end
	local offset = (Vector3.new(0, fall.Height, 0) + fall.Drift) * left
	local tumble = CFrame.fromAxisAngle(Vector3.new(0.55, 0.2, 0.81).Unit, left * fall.Turns * 2 * math.pi)
	return CFrame.new(heart + offset) * tumble * CFrame.new(-heart)
end

function Meteor.Position(t, boomAt, heart)
	return Meteor.Pose(t, boomAt, heart) * heart
end

-- The camera at `t`: eye, focus and field of view. `yaw` is the side the player was on, so
-- the first shot looks the way they were already looking.
function Meteor.Shot(t, boomAt, heart, floorY, yaw)
	local cam = Meteor.Camera
	local meteor = Meteor.Position(t, boomAt, heart)
	local function around(angle, distance, height)
		return Vector3.new(heart.X + math.cos(angle) * distance, floorY + height, heart.Z + math.sin(angle) * distance)
	end

	local groundEye, groundFov = around(yaw, cam.GroundDistance, cam.GroundHeight), cam.Fov.Ground
	local chaseEye, chaseFov = around(yaw + cam.ChaseTurn, cam.ChaseDistance, cam.ChaseHeight), cam.Fov.Chase
	local toChase = smooth((t - cam.GroundUntil) / cam.Blend)
	local eye = groundEye:Lerp(chaseEye, toChase)
	local fov = groundFov + (chaseFov - groundFov) * toChase
	local focus = meteor

	if t >= boomAt then
		local after = t - boomAt
		-- The hit: a shove back and a wide lens for an instant, then the orbit takes over.
		local kick = math.sin(clamp01(after / cam.ImpactSeconds) * math.pi) * (1 - clamp01(after / cam.ImpactSeconds))
		local settle = smooth(after / cam.ImpactSeconds)
		local along = clamp01(after / 3)
		local orbitEye = around(yaw + cam.ChaseTurn + after * cam.OrbitSpin, cam.OrbitRadius - cam.OrbitCloser * along + kick * 22, cam.OrbitHeight)
		eye = chaseEye:Lerp(orbitEye, settle)
		focus = Vector3.new(heart.X, floorY + 5, heart.Z)
		fov = chaseFov + (cam.Fov.Orbit - chaseFov) * settle + (cam.Fov.Impact - cam.Fov.Orbit) * kick
	end
	return eye, focus, fov
end

----------------------------------------------------------------------
-- Instances (client only)
----------------------------------------------------------------------
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local FIRE = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 245, 170)),
	ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 190, 40)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(235, 80, 20)),
})

-- (Emit does not exist in the offline test runtime.)
local function emit(emitter, count)
	pcall(function()
		emitter:Emit(count)
	end)
end

local function ghost(part)
	part.Anchored = true
	part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
	part.CastShadow = false
	return part
end

-- Every emitter under `root`, its particles `sizeBy` times as big and `speedBy` times as fast.
local function scaleEmitters(root, sizeBy, speedBy)
	for _, emitter in root:GetDescendants() do
		if emitter:IsA("ParticleEmitter") then
			local keypoints = {}
			for _, keypoint in emitter.Size.Keypoints do
				table.insert(keypoints, NumberSequenceKeypoint.new(keypoint.Time, keypoint.Value * sizeBy, keypoint.Envelope * sizeBy))
			end
			emitter.Size = NumberSequence.new(keypoints)
			emitter.Speed = NumberRange.new(emitter.Speed.Min * speedBy, emitter.Speed.Max * speedBy)
		end
	end
end

-- The giant taco, its ring of small tacos and its fire. `fireAssets` is
-- Shared.TacoMeteorAssets (Wrap, Jet, Trail from the V40 place); without it the two built-in
-- emitters still make a fireball. `tacoFire` = { Fire = Shared.TacoFire, Struck = the raining
-- tacos' StruckVFX } adds that same pixel-fire round the meteor.
-- Returns { Update(t, pose), Burst(), Destroy() }.
-- The giant taco is TacoWidth times as wide as the treadmill inside it. It was 1.5 and the user
-- found it too big: 20% less. The V40 fireball, the jet and the taco fire are sized from it.
Meteor.TacoWidth = 1.2
function Meteor.BuildAura(heart, size, lowPower, tacoVisual, fireAssets, tacoFire)
	local folder = Instance.new("Folder")
	folder.Name = "TacoMeteor_Local"
	folder.Parent = Workspace
	local span = math.max(size.X, size.Z)
	local shellWidth = span * Meteor.TacoWidth
	local stoppable = {}

	local core = ghost(Instance.new("Part"))
	core.Name = "Core"
	core.Transparency = 1
	core.Size = Vector3.new(2, 2, 2)
	core.CFrame = CFrame.new(heart)
	core.Parent = folder
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 50)
	light.Range = 60
	light.Brightness = 5
	light.Parent = core
	local fire = Instance.new("ParticleEmitter")
	fire.Name = "Fire"
	fire.Texture = "rbxasset://textures/particles/fire_main.dds"
	fire.Color = FIRE
	fire.LightEmission = 0.9
	fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, span * 0.45), NumberSequenceKeypoint.new(1, span * 0.1) })
	fire.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	fire.Lifetime = NumberRange.new(0.5, 0.9)
	fire.Speed = NumberRange.new(2, 8)
	fire.SpreadAngle = Vector2.new(180, 180)
	fire.Rate = if lowPower then 35 else 80
	fire.Parent = core
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Smoke"
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(90, 60, 40), Color3.fromRGB(40, 35, 35))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, span * 0.3), NumberSequenceKeypoint.new(1, span * 0.7) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(1.2, 2)
	smoke.Speed = NumberRange.new(1, 4)
	smoke.Rate = if lowPower then 12 else 30
	smoke.Parent = core
	table.insert(stoppable, fire)
	table.insert(stoppable, smoke)
	if tacoFire and tacoFire.Fire and tacoFire.Struck then
		-- In every direction and left behind as it falls: the tail of the meteor.
		for _, flame in tacoFire.Fire.Flames(tacoFire.Struck, core, { Scale = shellWidth / 9, Rate = if lowPower then 1.5 else 4, Rise = 0, Spread = 180 }) do
			table.insert(stoppable, flame)
		end
	end

	-- The V40 fireball wrapped round it: the short-lived flames ride with the meteor, the
	-- long-lived embers and smoke are left behind it as a tail.
	local wrap = fireAssets and fireAssets:FindFirstChild("Wrap")
	if wrap then
		wrap = wrap:Clone()
		ghost(wrap)
		wrap.CFrame = CFrame.new(heart)
		scaleEmitters(wrap, shellWidth * 0.55 / 18, 1.4)
		for _, emitter in wrap:GetDescendants() do
			if emitter:IsA("ParticleEmitter") and emitter.Rate > 0 then
				emitter.LockedToPart = emitter.Lifetime.Max <= 0.9
				emitter.Rate *= if lowPower then 0.5 else 1.6
				emitter.Enabled = true
				table.insert(stoppable, emitter)
			end
		end
		wrap.Parent = folder
	end
	-- The flame jet: always pointing back up the way it came.
	local jet = fireAssets and fireAssets:FindFirstChild("Jet")
	if jet then
		jet = jet:Clone()
		ghost(jet)
		jet.CFrame = CFrame.new(heart)
		scaleEmitters(jet, shellWidth / 7, 2.2)
		for _, emitter in jet:GetDescendants() do
			if emitter:IsA("ParticleEmitter") then
				emitter.LockedToPart = false
				emitter.Lifetime = NumberRange.new(emitter.Lifetime.Min * 2.2, emitter.Lifetime.Max * 2.2)
				emitter.Rate = if lowPower then 40 else 110
				emitter.Enabled = true
				table.insert(stoppable, emitter)
			end
		end
		jet.Parent = folder
	end
	local trail = fireAssets and fireAssets:FindFirstChild("Trail")
	if trail then
		trail = trail:Clone()
		local left, right = Instance.new("Attachment"), Instance.new("Attachment")
		left.CFrame, right.CFrame = CFrame.new(-shellWidth * 0.35, 0, 0), CFrame.new(shellWidth * 0.35, 0, 0)
		left.Parent, right.Parent = core, core
		trail.Attachment0, trail.Attachment1 = left, right
		trail.Color = FIRE
		trail.LightEmission = 0.8
		trail.Lifetime = 1.1
		trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
		trail.Enabled = true
		trail.Parent = core
	end

	-- The giant taco: the treadmill is its filling.
	local shell = ghost(Instance.new("Part"))
	shell.Name = "GiantTaco"
	shell.Size = Vector3.new(1, 1, 1)
	shell.CFrame = CFrame.new(heart)
	shell.Parent = folder
	tacoVisual.Decorate(shell, shellWidth / 2.5)

	local ring = {}
	local count = if lowPower then 6 else 12
	for index = 1, count do
		local root = ghost(Instance.new("Part"))
		root.Name = "AuraTaco"
		root.Size = Vector3.new(1, 1, 1)
		root.CFrame = CFrame.new(heart)
		root.Parent = folder
		tacoVisual.Decorate(root, 2.2)
		table.insert(ring, { Root = root, Phase = index / count * 2 * math.pi, Tilt = if index % 2 == 0 then 0.5 else -0.35 })
	end

	local aura = {}
	local lastCentre = nil
	function aura.Update(t, pose)
		local centre = pose * heart
		core.CFrame = CFrame.new(centre)
		shell.CFrame = pose * CFrame.new(heart) * CFrame.Angles(0, math.pi / 2, 0)
		tacoVisual.EnsureVisible(shell)
		if wrap then
			wrap.CFrame = CFrame.new(centre)
		end
		if jet then
			local back = if lastCentre then lastCentre - centre else Vector3.new(0, 1, 0)
			if back.Magnitude > 0.05 then
				local up = back.Unit
				local side = up:Cross(if math.abs(up.X) > 0.9 then Vector3.new(0, 0, 1) else Vector3.new(1, 0, 0)).Unit
				jet.CFrame = CFrame.fromMatrix(centre + up * (shellWidth * 0.3), side, up)
			end
		end
		lastCentre = centre
		local radius = span * 0.95
		for _, taco in ring do
			local angle = taco.Phase + t * 5.5
			local offset = CFrame.Angles(taco.Tilt, 0, taco.Tilt * 0.6) * Vector3.new(math.cos(angle) * radius, math.sin(angle * 2) * 3, math.sin(angle) * radius)
			taco.Root.CFrame = CFrame.new(centre + offset) * CFrame.Angles(angle, angle * 1.7, 0)
		end
	end
	-- The hit: the fire stops, the shell swells and fades, the ring is thrown outwards.
	function aura.Burst()
		for _, emitter in stoppable do
			emitter.Enabled = false
			emitter.Rate = 0
		end
		if trail then
			trail.Enabled = false
		end
		light.Brightness = 12
		TweenService:Create(light, TweenInfo.new(0.7), { Brightness = 0 }):Play()
		for _, piece in shell:GetDescendants() do
			if piece:IsA("BasePart") then
				TweenService:Create(piece, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Transparency = 1, Size = piece.Size * 1.3 }):Play()
			end
		end
		for _, taco in ring do
			local from = taco.Root.CFrame.Position
			local outward = (from - core.CFrame.Position) * Vector3.new(1, 0, 1)
			outward = if outward.Magnitude > 0.1 then outward.Unit else Vector3.new(1, 0, 0)
			TweenService:Create(taco.Root, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ CFrame = CFrame.new(from + outward * (span * 0.9) + Vector3.new(0, span * 0.45, 0)) * CFrame.Angles(2, 3, 1) }):Play()
		end
		-- Long enough for the embers already in the air to burn out.
		Debris:AddItem(shell, 0.4)
		for _, taco in ring do
			Debris:AddItem(taco.Root, 0.7)
		end
		Debris:AddItem(folder, 2.6)
	end
	function aura.Destroy()
		folder:Destroy()
	end
	return aura
end

-- What the floor is made of under `position` (looking down from above it). Returns nil when
-- there is no floor there (a gap, the edge of the lobby), false when this runtime cannot cast.
function Meteor.FloorUnder(position, params)
	local cast = Meteor._raycast
	local ok, hit = pcall(function()
		if cast then
			return cast(position + Vector3.new(0, 30, 0), Vector3.new(0, -90, 0), params)
		end
		return Workspace:Raycast(position + Vector3.new(0, 30, 0), Vector3.new(0, -90, 0), params)
	end)
	if not ok then
		return false
	end
	if not hit then
		return nil
	end
	local color, variant = Color3.fromRGB(120, 110, 100), ""
	pcall(function()
		if hit.Instance:IsA("Terrain") then
			color = hit.Instance:GetMaterialColor(hit.Material)
		else
			color = hit.Instance.Color
			variant = hit.Instance.MaterialVariant
		end
	end)
	local material = hit.Material
	if material == Enum.Material.Air then
		material = Enum.Material.Slate
	end
	return { Y = hit.Position.Y, Color = color, Material = material, Variant = variant }
end

local function splash(struck, parent, at, sizeBy, emitBy, cap)
	if not struck then
		return
	end
	local burst = struck:Clone()
	if burst:IsA("BasePart") then
		ghost(burst)
		burst.Transparency = 1
		burst.CFrame = CFrame.new(at)
	elseif burst:IsA("Model") then
		burst:PivotTo(CFrame.new(at))
	end
	burst.Parent = parent
	scaleEmitters(burst, sizeBy, math.sqrt(sizeBy) * 1.3)
	for _, emitter in burst:GetDescendants() do
		if emitter:IsA("ParticleEmitter") then
			emitter.Enabled = false
			emit(emitter, math.min((tonumber(emitter:GetAttribute("EmitCount")) or 12) * emitBy, cap))
		end
	end
end

-- The landing. `tacoAssets` is Shared.TacoEventAssets (the raining tacos' StruckVFX splash),
-- `fireAssets` is Shared.TacoMeteorAssets (the V40 explosion, "Boom").
function Meteor.Impact(centre, size, lowPower, tacoAssets, fireAssets)
	local span = math.max(size.X, size.Z)
	local radius = span * 0.85
	local folder = Instance.new("Folder")
	folder.Name = "TacoMeteorImpact_Local"
	folder.Parent = Workspace
	Debris:AddItem(folder, Meteor.ImpactSeconds)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { folder }
	for _, name in { "AdminSpawnedTreadmills", "TacoMeteor_Local" } do
		local found = Workspace:FindFirstChild(name)
		if found then
			table.insert(ignore, found)
		end
	end
	pcall(function()
		for _, player in game:GetService("Players"):GetPlayers() do
			if player.Character then
				table.insert(ignore, player.Character)
			end
		end
	end)
	params.FilterDescendantsInstances = ignore
	-- The floor it lands on only gives the dust its colour now.
	local fallback = Meteor.FloorUnder(centre, params) or { Y = centre.Y, Color = Color3.fromRGB(120, 110, 100), Material = Enum.Material.Slate, Variant = "" }

	local fx = ghost(Instance.new("Part"))
	fx.Name = "TacoMeteorSplash"
	fx.Transparency = 1
	fx.Size = Vector3.new(1, 1, 1)
	fx.CFrame = CFrame.new(centre + Vector3.new(0, 0.5, 0))
	fx.Parent = folder

	-- A ball of light, two shock rings, the V40 explosion...
	local flash = ghost(Instance.new("Part"))
	flash.Name = "Flash"
	flash.Shape = Enum.PartType.Ball
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(255, 225, 120)
	flash.Transparency = 0.15
	flash.Size = Vector3.new(6, 6, 6)
	flash.CFrame = CFrame.new(centre + Vector3.new(0, 3, 0))
	flash.Parent = folder
	TweenService:Create(flash, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(radius * 2.4, radius * 2.4, radius * 2.4), Transparency = 1 }):Play()
	Debris:AddItem(flash, 0.5)
	for index, width in { radius * 3.2, radius * 2.1 } do
		local ringPart = ghost(Instance.new("Part"))
		ringPart.Name = "ShockRing"
		ringPart.Shape = Enum.PartType.Cylinder
		ringPart.Material = Enum.Material.Neon
		ringPart.Color = if index == 1 then Color3.fromRGB(255, 205, 70) else Color3.fromRGB(255, 255, 255)
		ringPart.Transparency = 0.3
		ringPart.Size = Vector3.new(0.4, 2, 2)
		ringPart.CFrame = CFrame.new(centre + Vector3.new(0, 0.3 * index, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		ringPart.Parent = folder
		TweenService:Create(ringPart, TweenInfo.new(0.6 + index * 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = Vector3.new(0.4, width, width), Transparency = 1 }):Play()
	end
	local boom = fireAssets and fireAssets:FindFirstChild("Boom")
	if boom then
		boom = boom:Clone()
		ghost(boom)
		boom.CFrame = CFrame.new(centre + Vector3.new(0, 4, 0))
		boom.Parent = folder
		scaleEmitters(boom, radius / 9, radius / 12)
		for _, emitter in boom:GetDescendants() do
			if emitter:IsA("ParticleEmitter") then
				emitter.Enabled = false
				emit(emitter, math.min((tonumber(emitter:GetAttribute("EmitCount")) or 6) * (if lowPower then 1 else 2), if lowPower then 20 else 60))
			end
		end
	end

	-- ...and the tacos' own splash, where nobody can miss it: once in the middle at meteor
	-- size, then in a ring round the landing one after another.
	local struck = tacoAssets and tacoAssets:FindFirstChild("StruckVFX")
	splash(struck, fx, centre + Vector3.new(0, 1, 0), 6, 4, if lowPower then 40 else 100)
	local rim = if lowPower then 4 else 8
	for index = 1, rim do
		local angle = index / rim * 2 * math.pi
		local at = centre + Vector3.new(math.cos(angle) * radius * 0.9, 1.5, math.sin(angle) * radius * 0.9)
		task.delay(0.08 + index * 0.06, function()
			if folder.Parent then
				splash(struck, fx, at, 2.6, 2, if lowPower then 16 else 36)
			end
		end)
	end
	local dust = Instance.new("ParticleEmitter")
	dust.Name = "Dust"
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(fallback.Color:Lerp(Color3.new(1, 1, 1), 0.35), fallback.Color)
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, radius * 0.25), NumberSequenceKeypoint.new(1, radius * 0.9) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(1.4, 2.6)
	dust.Speed = NumberRange.new(radius * 0.6, radius * 1.4)
	dust.SpreadAngle = Vector2.new(85, 85)
	dust.EmissionDirection = Enum.NormalId.Top
	dust.Drag = 3
	dust.Rate = 0
	dust.Parent = fx
	emit(dust, if lowPower then 30 else 80)
	return folder
end

return Meteor
