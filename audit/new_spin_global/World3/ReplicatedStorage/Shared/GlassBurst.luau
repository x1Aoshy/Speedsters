-- GlassBurst.luau
-- Glass breaking in the world, client-side (every piece is local to the client that draws
-- it): a pane smashed through at speed (Movement/StageBarrierShatter: a stage barrier or the
-- finish) or a bubble bursting (the Sonic Burst ability). The glass flies apart in shards
-- that spin, fall and fade, with a burst of glittering splinters and the smash sound.
--
-- It replaces the full-screen Glass Shatter the sprint used to set off every few seconds:
-- here it only happens on a real impact, and each burst is a handful of parts for under a
-- second, so phones keep their frame rate.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local GlassBurst = {}

GlassBurst.SoundId = tostring(Config.GlassBreakSoundId or "")
GlassBurst.MaxShards = 18
GlassBurst.Lifetime = 0.95
GlassBurst.Gravity = 70
GlassBurst.FolderName = "GlassBurstRuntime"
GlassBurst.Color = Color3.fromRGB(226, 244, 255)

local function rng(a, b)
	return a + math.random() * (b - a)
end

-- Cuts a w x h rectangle into about 2^depth pieces, alternately across its longer side.
function GlassBurst.Slice(x, y, w, h, depth, out)
	out = out or {}
	if depth <= 0 then
		table.insert(out, { X = x, Y = y, W = w, H = h })
		return out
	end
	if w > h then
		local cut = w * rng(0.3, 0.7)
		GlassBurst.Slice(x, y, cut, h, depth - 1, out)
		GlassBurst.Slice(x + cut, y, w - cut, h, depth - 1, out)
	else
		local cut = h * rng(0.3, 0.7)
		GlassBurst.Slice(x, y, w, cut, depth - 1, out)
		GlassBurst.Slice(x, y + cut, w, h - cut, depth - 1, out)
	end
	return out
end

local function folder()
	local existing = Workspace:FindFirstChild(GlassBurst.FolderName)
	if existing then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = GlassBurst.FolderName
	created.Parent = Workspace
	return created
end

local function splinters(position, direction, amount, color)
	local anchor = Instance.new("Part")
	anchor.Name = "GlassSplinters"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(position)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.8
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new(0, 1)
	emitter.Lifetime = NumberRange.new(0.35, 0.7)
	emitter.Speed = NumberRange.new(18, 42)
	emitter.SpreadAngle = Vector2.new(70, 70)
	emitter.Acceleration = Vector3.new(0, -40, 0)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-400, 400)
	emitter.EmissionDirection = Enum.NormalId.Front
	emitter.Enabled = false
	emitter.Parent = anchor
	if direction.Magnitude > 0.01 then
		anchor.CFrame = CFrame.lookAt(position, position + direction)
	end
	anchor.Parent = folder()
	emitter:Emit(amount)
	Debris:AddItem(anchor, 1.2)
end

local function play(soundId, position, volume)
	if not soundId or soundId == "" then
		return
	end
	local holder = Instance.new("Attachment")
	holder.Name = "GlassBurstSound"
	holder.WorldCFrame = CFrame.new(position)
	holder.Parent = Workspace.Terrain
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 1
	sound.RollOffMaxDistance = 220
	sound.PlaybackSpeed = rng(0.95, 1.08)
	sound.Parent = holder
	sound:Play()
	Debris:AddItem(holder, 3)
end

-- Smashes a glass pane: `frame` is the pane (its LookVector is the way the glass flies),
-- `size` its width and height. opts:
--   Speed      how hard it was hit (studs/s), 0-400: the shards fly faster
--   Depth      2-4, how many pieces (2^Depth, at most MaxShards)
--   Sound      false for silence (the player turned sound effects off)
--   Volume     the smash's volume
--   Color      the glass tint
function GlassBurst.Pane(frame: CFrame, size: Vector2, opts)
	opts = opts or {}
	local punch = math.clamp((tonumber(opts.Speed) or 60) / 200, 0.4, 2)
	local depth = math.clamp(math.floor(tonumber(opts.Depth) or 4), 2, 4)
	local color = opts.Color or GlassBurst.Color
	local pieces = GlassBurst.Slice(0, 0, size.X, size.Y, depth)
	local shards = {}
	local parent = folder()
	for index, piece in pieces do
		if index > GlassBurst.MaxShards then
			break
		end
		local centre = Vector2.new(piece.X + piece.W / 2 - size.X / 2, size.Y / 2 - (piece.Y + piece.H / 2))
		local part = Instance.new("Part")
		part.Name = "GlassShard"
		part.Size = Vector3.new(math.max(0.2, piece.W * 0.94), math.max(0.2, piece.H * 0.94), 0.08)
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Material = Enum.Material.Glass
		part.Color = color
		part.Reflectance = 0.3
		part.Transparency = 0.35
		local start = frame * CFrame.new(centre.X, centre.Y, 0)
		part.CFrame = start
		part.Parent = parent
		local outward = centre.Magnitude > 0.01 and centre.Unit or Vector2.new(0, 1)
		table.insert(shards, {
			Part = part,
			Start = start,
			-- In the pane's own frame: out from the impact, and on through it (-Z is forward).
			Velocity = Vector3.new(outward.X * rng(6, 16), outward.Y * rng(6, 16) + rng(2, 8), -rng(14, 34)) * punch,
			Spin = Vector3.new(rng(-6, 6), rng(-6, 6), rng(-8, 8)),
		})
	end

	splinters(frame.Position, frame.LookVector, math.floor(24 * math.min(punch, 1.5)), color)
	if opts.Sound ~= false then
		play(GlassBurst.SoundId, frame.Position, opts.Volume or 1.1)
	end

	local elapsed = 0
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		if elapsed >= GlassBurst.Lifetime then
			connection:Disconnect()
			for _, shard in shards do
				shard.Part:Destroy()
			end
			return
		end
		local fade = math.clamp((elapsed - GlassBurst.Lifetime * 0.45) / (GlassBurst.Lifetime * 0.55), 0, 1)
		local fall = GlassBurst.Gravity * 0.5 * elapsed * elapsed
		for _, shard in shards do
			local moved = shard.Velocity * elapsed
			local spin = shard.Spin * elapsed
			local cframe = shard.Start * CFrame.new(moved) * CFrame.Angles(spin.X, spin.Y, spin.Z)
			shard.Part.CFrame = cframe - Vector3.new(0, fall, 0)
			shard.Part.Transparency = 0.35 + 0.65 * fade
		end
	end)
	return shards
end

-- Bursts a glass sphere of `radius` at `position`: the same shards, flying out every way.
function GlassBurst.Sphere(position: Vector3, radius: number, opts)
	opts = opts or {}
	local faces = {
		CFrame.lookAt(position, position + Vector3.new(0, 0, -1)),
		CFrame.lookAt(position, position + Vector3.new(0, 0, 1)),
		CFrame.lookAt(position, position + Vector3.new(1, 0, 0)),
		CFrame.lookAt(position, position + Vector3.new(-1, 0, 0)),
	}
	local side = radius * 1.4
	for index, face in faces do
		local pane = face * CFrame.new(0, 0, -radius * 0.6)
		GlassBurst.Pane(pane, Vector2.new(side, side), {
			Speed = opts.Speed,
			Depth = 2,
			Color = opts.Color,
			-- One smash for the whole bubble.
			Sound = index == 1 and opts.Sound ~= false,
			Volume = opts.Volume,
		})
	end
end

return GlassBurst
