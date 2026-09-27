-- World3HazardsClient.client.luau
-- The traps of World 3 (Desert), as this player sees them.
--
--   * Tumbleweeds (Stage 2), roadrunners (Stage 3), carts (Stage 7), the serpent (Stage 8)
--     and the scorpions (Stage 9) are drawn here every frame from Shared.World3HazardMotion
--     and the start time the server published, so they move smoothly with no
--     replication. When one of them touches this player's body, the server is told
--     (World3HazardSelfHit) and applies the death. The serpent is the modeller's green
--     Snake grown to the canyon's size; the scorpions are the modeller's Scorpion.
--   * Carts are solid and carry whoever rides on their roof; only their sides hurt.
--   * The flat platforms of Stage 6 (0.6 s) and Stage 10 (0.7 s) shake under this player's
--     feet, then fall away for them alone and come back (3 s / 3.5 s later).
--   * Stage 10: a sandstorm (blowing sand, dusty fog, a warm tint) while this player is on it.
--   * Stage 10's lasers go round off (a faint ghost, safe), warning (a flicker, still safe)
--     and on (solid glowing red, deadly), on the server's clock (Motion.LaserState). While
--     not on, the beam is untouchable here, so nothing on this side counts it as a hit.
--     They turn about their middle here too (Motion.LaserPose, from the home the server
--     published); the server never moves them and kills by that same pose.
--   * Warnings: sinking in the quicksand, and the serpent coming.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
if Config.IsWorld3Place ~= true then
	return
end

local Motion = require(Shared:WaitForChild("World3HazardMotion"))
local player = Players.LocalPlayer
local folder = ReplicatedStorage:WaitForChild("World3HazardLayout")
local selfHit = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("World3HazardSelfHit")
while folder:GetAttribute("Layout") == nil do
	folder.AttributeChanged:Wait()
end
local layout = HttpService:JSONDecode(folder:GetAttribute("Layout"))
local epoch = tonumber(folder:GetAttribute("Epoch")) or Workspace:GetServerTimeNow()

local DRAW_DISTANCE = 700
local HIT_REPORT_COOLDOWN = 1
local COLLAPSE_SHAKE_SECONDS = 0.6
local COLLAPSE_FALL_SECONDS = 0.45
local COLLAPSE_RETURN_SECONDS = 3
local SERPENT_SEGMENTS = Motion.SerpentPoints
-- The modeller's Snake is a small one: grown this many times to fill the canyon.
local SNAKE_SCALE = 8
local SNAKE_TAPER = 0.35 -- the tail end is this much thinner than the head end
-- Which way the Scorpion mesh faces: its -Z (Roblox's front). Flip if it walks backwards.
local SCORPION_FACES_MINUS_Z = true
local LOW_POWER = game:GetService("UserInputService").TouchEnabled and not game:GetService("UserInputService").KeyboardEnabled
local BODY_PARTS = {
	Head = true, Torso = true, UpperTorso = true, LowerTorso = true,
	["Left Arm"] = true, ["Right Arm"] = true, ["Left Leg"] = true, ["Right Leg"] = true,
	LeftUpperArm = true, LeftLowerArm = true, LeftHand = true, RightUpperArm = true, RightLowerArm = true, RightHand = true,
	LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true, RightUpperLeg = true, RightLowerLeg = true, RightFoot = true,
}

local function elapsedNow()
	return Workspace:GetServerTimeNow() - epoch
end

local visuals = Workspace:FindFirstChild("World3Hazards_Local")
if visuals then
	visuals:Destroy()
end
visuals = Instance.new("Folder")
visuals.Name = "World3Hazards_Local"
visuals.Parent = Workspace

-- A clone of a map model, anchored, with its pivot measured from its bounding box centre
-- in world axes, so it can be placed by its middle and keeps its authored orientation.
local function prepare(template, solid)
	local model = template:Clone()
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = solid
			part.CanTouch = false
			part.CanQuery = solid
			part.CastShadow = false
		end
	end
	local centre = model:GetBoundingBox()
	local pivot = model:GetPivot()
	return model, CFrame.new(pivot.Position - centre.Position) * pivot.Rotation
end

local function part(parent, name, shape, size, color, material)
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Shape = shape
	piece.Size = size
	piece.Color = color
	piece.Material = material or Enum.Material.SmoothPlastic
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanTouch = false
	piece.CanQuery = false
	piece.CastShadow = false
	piece.Parent = parent
	return piece
end

local function hide(model)
	model:PivotTo(CFrame.new(0, -1000, 0))
end

----------------------------------------------------------------------
-- Building the moving hazards
----------------------------------------------------------------------
local tumbleweeds = {}
local tumbleweedTemplate = folder:WaitForChild("Tumbleweed", 10)
for index, lane in layout.Tumbleweeds or {} do
	if tumbleweedTemplate then
		local model, offset = prepare(tumbleweedTemplate, false)
		model.Name = "Tumbleweed" .. index
		model.Parent = visuals
		tumbleweeds[index] = { Model = model, Offset = offset, Lane = lane }
	end
end

-- The roadrunner: a quick bird made of parts until the modeller's mesh arrives.
local function buildRoadrunner(index, runner)
	local model = Instance.new("Model")
	model.Name = "Roadrunner" .. index
	local height = runner.Height
	local brown = Color3.fromRGB(122, 86, 58)
	local blue = Color3.fromRGB(58, 92, 170)
	local orange = Color3.fromRGB(245, 150, 40)
	local pieces = {
		{ "Body", Enum.PartType.Ball, Vector3.new(4.5, 4.5, 4.5), blue, CFrame.new(0, 0, 0) },
		{ "Neck", Enum.PartType.Cylinder, Vector3.new(3, 1.2, 1.2), blue, CFrame.new(0, 2.6, -1.4) * CFrame.Angles(0, 0, math.rad(90)) },
		{ "Head", Enum.PartType.Ball, Vector3.new(2.4, 2.4, 2.4), blue, CFrame.new(0, 4.1, -2) },
		{ "Crest", Enum.PartType.Block, Vector3.new(0.3, 1.6, 1.4), brown, CFrame.new(0, 5.3, -1.6) },
		{ "Beak", Enum.PartType.Block, Vector3.new(0.6, 0.5, 2.2), orange, CFrame.new(0, 4, -3.9) },
		{ "Tail", Enum.PartType.Block, Vector3.new(0.6, 0.5, 4.5), brown, CFrame.new(0, 1.6, 3.6) * CFrame.Angles(math.rad(-30), 0, 0) },
		{ "LeftLeg", Enum.PartType.Cylinder, Vector3.new(height / 2 - 1, 0.5, 0.5), orange, CFrame.new(-0.9, -height / 4 - 1.2, 0) * CFrame.Angles(0, 0, math.rad(90)) },
		{ "RightLeg", Enum.PartType.Cylinder, Vector3.new(height / 2 - 1, 0.5, 0.5), orange, CFrame.new(0.9, -height / 4 - 1.2, 0) * CFrame.Angles(0, 0, math.rad(90)) },
	}
	local layoutParts = {}
	for _, spec in pieces do
		local piece = part(model, spec[1], spec[2], spec[3], spec[4])
		layoutParts[piece] = spec[5]
	end
	model.Parent = visuals
	return { Model = model, Parts = layoutParts, Runner = runner }
end
local roadrunners = {}
for index, runner in layout.Roadrunners or {} do
	roadrunners[index] = buildRoadrunner(index, runner)
end

local carts = {}
local cartTemplate = folder:WaitForChild("Cart", 10)
for index, cart in layout.Carts or {} do
	if cartTemplate then
		local model, offset = prepare(cartTemplate, true)
		model.Name = "Cart" .. index
		model.Parent = visuals
		local parts = {}
		for _, piece in model:GetDescendants() do
			if piece:IsA("BasePart") then
				table.insert(parts, piece)
			end
		end
		carts[index] = { Model = model, Offset = offset, Cart = cart, Parts = parts }
	end
end

-- The serpent: the modeller's Snake, head, body and tail laid along its path. Each piece
-- keeps the turn it has against the body's line in the model (so the head still looks
-- forward and the fangs down); the body is lengthened with copies of its middle pieces.
-- Without the model, a snake of balls.
local serpent = nil
local function buildSnakeSerpent(template)
	local head = template:FindFirstChild("Head")
	local tail = template:FindFirstChild("Tail")
	local torsos = {}
	for index = 1, 5 do
		local piece = template:FindFirstChild("Torso" .. index)
		if piece then
			table.insert(torsos, piece)
		end
	end
	if not (head and tail and #torsos > 0) then
		return nil
	end
	local chain = { head }
	for _, piece in torsos do
		table.insert(chain, piece)
	end
	table.insert(chain, tail)
	-- Each piece against the model's own body line (pointing to the head).
	local function towardHead(index)
		local ahead = chain[math.max(1, index - 1)].CFrame.Position
		local behind = chain[math.min(#chain, index + 1)].CFrame.Position
		local direction = ahead - behind
		return if direction.Magnitude > 1e-3 then direction.Unit else Vector3.new(0, 0, 1)
	end
	local function turnAgainstLine(piece, index)
		local at = piece.CFrame.Position
		local line = CFrame.lookAt(at, at + towardHead(index))
		return (line:Inverse() * piece.CFrame).Rotation
	end
	local model = Instance.new("Model")
	model.Name = "Serpent"
	local pieces = {}
	local count = SERPENT_SEGMENTS
	for index = 1, count do
		local source, sourceIndex
		if index == 1 then
			source, sourceIndex = head, 1
		elseif index == count then
			source, sourceIndex = tail, #chain
		else
			local which = (index - 2) % #torsos + 1
			source, sourceIndex = torsos[which], which + 1
		end
		local piece = source:Clone()
		for _, child in piece:GetChildren() do
			if not child:IsA("DataModelMesh") and not child:IsA("Texture") and not child:IsA("Decal") and not child:IsA("SurfaceAppearance") then
				child:Destroy()
			end
		end
		local grow = SNAKE_SCALE * (1 - SNAKE_TAPER * (index - 1) / math.max(1, count - 1))
		piece.Size = source.Size * grow
		piece.Anchored = true
		piece.CanCollide = false
		piece.CanTouch = false
		piece.CanQuery = false
		piece.CastShadow = false
		piece.Parent = model
		pieces[index] = { Part = piece, Turn = turnAgainstLine(source, sourceIndex) }
	end
	-- The eyes and fangs ride on the head.
	local extras = {}
	for _, child in template:GetChildren() do
		if child:IsA("BasePart") and child ~= head and child ~= tail and not table.find(torsos, child) then
			local extra = child:Clone()
			extra.Size = child.Size * SNAKE_SCALE
			extra.Anchored = true
			extra.CanCollide = false
			extra.CanTouch = false
			extra.CanQuery = false
			extra.CastShadow = false
			-- A file mesh keeps its own size; a shaped one follows the part's.
			local mesh = extra:FindFirstChildWhichIsA("SpecialMesh")
			if mesh and mesh.MeshType == Enum.MeshType.FileMesh then
				mesh.Scale = mesh.Scale * SNAKE_SCALE
			end
			extra.Parent = model
			local offset = head.CFrame:Inverse() * child.CFrame
			table.insert(extras, { Part = extra, Offset = CFrame.new(offset.Position * SNAKE_SCALE) * offset.Rotation })
		end
	end
	local hiss = head:FindFirstChild("Hiss #1")
	model.Parent = visuals
	return { Model = model, Pieces = pieces, Extras = extras, Hiss = hiss and hiss:Clone(), Data = layout.Serpent }
end

if layout.Serpent then
	local template = folder:WaitForChild("Snake", 10)
	serpent = template and buildSnakeSerpent(template)
	if serpent and serpent.Hiss then
		serpent.Hiss.Parent = serpent.Pieces[1].Part
	end
	if not serpent then
		local model = Instance.new("Model")
		model.Name = "Serpent"
		local pieces = {}
		for index = 1, SERPENT_SEGMENTS do
			local size = 10 - (index - 1) / SERPENT_SEGMENTS * 5
			local shade = if index % 2 == 0 then Color3.fromRGB(96, 140, 52) else Color3.fromRGB(128, 170, 64)
			pieces[index] = { Part = part(model, "Segment" .. index, Enum.PartType.Ball, Vector3.new(size, size, size), shade), Turn = CFrame.new() }
		end
		model.Parent = visuals
		serpent = { Model = model, Pieces = pieces, Extras = {}, Data = layout.Serpent }
	end
end

-- The scorpions: the modeller's mesh, one per lane.
local scorpions = {}
local scorpionTemplate = if #(layout.Scorpions or {}) > 0 then folder:WaitForChild("Scorpion", 10) else nil
for index, lane in layout.Scorpions or {} do
	local body
	if scorpionTemplate then
		body = scorpionTemplate:Clone()
		body.Size = Vector3.new(lane.Width, lane.Height, lane.Length)
	else
		body = part(visuals, "Scorpion", Enum.PartType.Block, Vector3.new(lane.Width, lane.Height, lane.Length), Color3.fromRGB(40, 30, 24))
	end
	body.Name = "Scorpion" .. index
	body.Anchored = true
	body.CanCollide = false
	body.CanTouch = false
	body.CanQuery = false
	body.CastShadow = false
	body.Parent = visuals
	scorpions[index] = { Part = body, Lane = lane }
end

----------------------------------------------------------------------
-- Drawing
----------------------------------------------------------------------
local function near(position, root)
	return root and (position - root.Position).Magnitude <= DRAW_DISTANCE
end

local function drawTumbleweeds(elapsed, root)
	for _, entry in tumbleweeds do
		local position, spin, active = Motion.TumbleweedPose(entry.Lane, elapsed)
		if active and near(position, root) then
			entry.IsHidden = false
			entry.Model:PivotTo(CFrame.new(position) * CFrame.Angles(0, 0, spin) * entry.Offset)
		else
			if not entry.IsHidden then
				entry.IsHidden = true
				hide(entry.Model)
			end
		end
	end
end

local function drawRoadrunners(elapsed, root)
	for _, entry in roadrunners do
		local position, heading = Motion.RoadrunnerPose(entry.Runner, elapsed)
		if near(position, root) then
			entry.IsHidden = false
			local frame = CFrame.fromMatrix(position, heading:Cross(Vector3.yAxis).Unit, Vector3.yAxis, -heading)
			local stride = math.sin(elapsed * 22) * 0.6
			for piece, offset in entry.Parts do
				if piece.Name == "LeftLeg" or piece.Name == "RightLeg" then
					-- Legs swing from the hip, in turn.
					local hip = CFrame.new(offset.Position.X, -1.5, 0)
					local swing = CFrame.Angles(if piece.Name == "LeftLeg" then stride else -stride, 0, 0)
					piece.CFrame = frame * hip * swing * hip:Inverse() * offset
				else
					piece.CFrame = frame * offset
				end
			end
		else
			if not entry.IsHidden then
				entry.IsHidden = true
				hide(entry.Model)
			end
		end
	end
end

local function drawCarts(elapsed, root)
	for _, entry in carts do
		local centre, velocity = Motion.CartPose(entry.Cart, elapsed)
		if near(centre, root) then
			entry.IsHidden = false
			entry.Model:PivotTo(CFrame.new(centre) * entry.Offset)
			-- An anchored part with a velocity carries the characters standing on it.
			for _, piece in entry.Parts do
				piece.AssemblyLinearVelocity = Vector3.new(velocity, 0, 0)
			end
		else
			if not entry.IsHidden then
				entry.IsHidden = true
				hide(entry.Model)
				for _, piece in entry.Parts do
					piece.AssemblyLinearVelocity = Vector3.zero
				end
			end
		end
	end
end

local function drawSerpent(elapsed, root)
	if not serpent then
		return
	end
	local data = serpent.Data
	local body = Motion.SerpentBody(data, elapsed, SERPENT_SEGMENTS)
	local phase, _, progress = Motion.SerpentState(data, elapsed)
	if not body or not root or math.abs(root.Position.Z - data.ZStart) > DRAW_DISTANCE * 1.5 then
		if not serpent.IsHidden then
			serpent.IsHidden = true
			hide(serpent.Model)
		end
		return
	end
	serpent.IsHidden = false
	local direction = if data.ZEnd >= data.ZStart then 1 else -1
	if phase == "Warning" then
		-- Rearing up out of the sand at the far end of the canyon, shaking, before it charges.
		local centreX = (data.XMin + data.XMax) / 2
		local rise = math.min(1, progress * 1.5)
		for index = 1, SERPENT_SEGMENTS do
			body[index] = if index <= 6
				then Vector3.new(centreX + math.sin(elapsed * 25 + index) * 0.5, data.FloorY - 8 + rise * (7 - index) * 3.2, data.ZStart + direction * 4)
				else false
		end
		if serpent.Hiss and not serpent.Hiss.IsPlaying and progress < 0.1 then
			serpent.Hiss:Play()
		end
	end
	local away = CFrame.new(0, -1000, 0)
	local headFrame = nil
	for index, entry in serpent.Pieces do
		local point = body[index]
		if point then
			-- The body's line here, pointing to the head.
			local ahead = body[index - 1] or nil
			local behind = body[index + 1] or nil
			local line = if ahead then ahead - point elseif behind then point - behind else Vector3.new(0, 0, direction)
			if line.Magnitude < 1e-3 then
				line = Vector3.new(0, 0, direction)
			end
			local frame = CFrame.lookAt(point, point + line.Unit) * entry.Turn
			entry.Part.CFrame = frame
			if index == 1 then
				headFrame = frame
			end
		else
			entry.Part.CFrame = away
		end
	end
	for _, extra in serpent.Extras do
		extra.Part.CFrame = if headFrame then headFrame * extra.Offset else away
	end
end

local function drawScorpions(elapsed, root)
	for _, entry in scorpions do
		local centre, facing, turning = Motion.ScorpionPose(entry.Lane, elapsed)
		if near(centre, root) then
			entry.IsHidden = false
			-- Turning round at the end of its walk, then off the other way; a small sway.
			local heading = if turning > 0
				then CFrame.Angles(0, turning * math.pi, 0):VectorToWorldSpace(facing)
				else facing
			local sway = if turning > 0 then 0 else math.sin(elapsed * 14 + entry.Lane.Z) * math.rad(4)
			local look = if SCORPION_FACES_MINUS_Z then heading else -heading
			entry.Part.CFrame = CFrame.lookAt(centre, centre + look) * CFrame.Angles(0, sway, 0)
		else
			if not entry.IsHidden then
				entry.IsHidden = true
				entry.Part.CFrame = CFrame.new(0, -1000, 0)
			end
		end
	end
end

----------------------------------------------------------------------
-- Getting hit
----------------------------------------------------------------------
local lastReportAt = 0

local function report(kind, index)
	local now = os.clock()
	if now - lastReportAt < HIT_REPORT_COOLDOWN then
		return
	end
	lastReportAt = now
	selfHit:FireServer(kind, index)
end

local function checkHits(elapsed, character, root)
	local points = {}
	for _, piece in character:GetChildren() do
		if piece:IsA("BasePart") and BODY_PARTS[piece.Name] then
			table.insert(points, piece.Position)
		end
	end
	local rootY = root.Position.Y
	local function test(kind, list)
		for index in list do
			for _, point in points do
				if Motion.Hits(layout, kind, index, elapsed, point, rootY) then
					report(kind, index)
					return true
				end
			end
		end
		return false
	end
	local _ = test("Tumbleweed", layout.Tumbleweeds or {})
		or test("Roadrunner", layout.Roadrunners or {})
		or test("Cart", layout.Carts or {})
		or (layout.Serpent ~= nil and test("Serpent", { true }))
		or test("Scorpion", layout.Scorpions or {})
end

----------------------------------------------------------------------
-- Warnings
----------------------------------------------------------------------
local hud = Instance.new("ScreenGui")
hud.Name = "World3HazardWarnings"
hud.ResetOnSpawn = false
hud.IgnoreGuiInset = true
hud.DisplayOrder = 5
local banner = Instance.new("TextLabel")
banner.Name = "Warning"
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.fromScale(0.5, 0.16)
banner.Size = UDim2.fromScale(0.6, 0.07)
banner.BackgroundTransparency = 1
banner.Font = Enum.Font.GothamBlack
banner.TextScaled = true
banner.TextColor3 = Color3.fromRGB(255, 80, 60)
banner.Text = ""
banner.Visible = false
banner.Parent = hud
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(0, 0, 0)
stroke.Thickness = 3
stroke.Parent = banner
hud.Parent = player:WaitForChild("PlayerGui")

local function inCanyon(root)
	local data = layout.Serpent
	return data ~= nil
		and root.Position.X >= data.XMin - 40 and root.Position.X <= data.XMax + 40
		and Motion.InCanyon(data, root.Position.Z)
		and root.Position.Y <= data.FloorY + 60
end

local function updateWarning(elapsed, root)
	local sink = tonumber(player:GetAttribute("World3QuicksandSink")) or 0
	local text = nil
	if sink > 0 then
		text = "SINKING! GET OFF THE QUICKSAND!"
	elseif root and inCanyon(root) then
		local phase = Motion.SerpentState(layout.Serpent, elapsed)
		if phase == "Warning" or phase == "Pass" then
			text = "THE SERPENT IS COMING! HIDE IN A DUGOUT!"
		end
	end
	banner.Visible = text ~= nil
	if text then
		banner.Text = text
		banner.TextTransparency = 0.15 + 0.15 * math.sin(elapsed * 12)
	end
end

----------------------------------------------------------------------
-- Stages 6 and 10: platforms that give way under this player
----------------------------------------------------------------------
local collapsing = {}

local function collapse(platform)
	local state = collapsing[platform]
	if not state or state.Busy then
		return
	end
	state.Busy = true
	local shakeSeconds = tonumber(platform:GetAttribute("World3CollapseShake")) or COLLAPSE_SHAKE_SECONDS
	local backSeconds = tonumber(platform:GetAttribute("World3CollapseBack")) or COLLAPSE_RETURN_SECONDS
	task.spawn(function()
		local home = state.Home
		local started = os.clock()
		while os.clock() - started < shakeSeconds and platform.Parent do
			local progress = (os.clock() - started) / shakeSeconds
			local shake = 0.25 * progress + 0.05
			platform.CFrame = home * CFrame.new((math.random() - 0.5) * shake, 0, (math.random() - 0.5) * shake)
			platform.Transparency = math.clamp(state.Transparency + progress * 0.45, 0, 0.75)
			RunService.RenderStepped:Wait()
		end
		if not platform.Parent then
			return
		end
		platform.CFrame = home
		platform.CanCollide = false
		local fall = TweenService:Create(platform, TweenInfo.new(COLLAPSE_FALL_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = home * CFrame.new(0, -10, 0),
			Transparency = 1,
		})
		fall:Play()
		task.wait(backSeconds)
		if platform.Parent then
			fall:Cancel()
			platform.CFrame = home
			platform.Transparency = state.Transparency
			platform.CanCollide = state.CanCollide
		end
		state.Busy = false
	end)
end

local function watchPlatform(platform)
	if collapsing[platform] or not platform:IsA("BasePart") or platform:GetAttribute("World3CollapsePlatform") == nil then
		return
	end
	collapsing[platform] = { Home = platform.CFrame, Transparency = platform.Transparency, CanCollide = platform.CanCollide, Busy = false }
	platform.Touched:Connect(function(hit)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or hit.Parent ~= character or not BODY_PARTS[hit.Name] then
			return
		end
		-- Only feet on top set it off, not a brush against its side.
		local top = platform.Position.Y + platform.Size.Y / 2
		if root.Position.Y >= top then
			collapse(platform)
		end
	end)
end

for _, descendant in Workspace:GetDescendants() do
	watchPlatform(descendant)
end
Workspace.DescendantAdded:Connect(watchPlatform)
Workspace.DescendantRemoving:Connect(function(descendant)
	collapsing[descendant] = nil
end)

----------------------------------------------------------------------
-- Stage 10: the sandstorm
----------------------------------------------------------------------
-- While this player is on Stage 10 the sand blows across the cliffs: a box of blowing sand
-- and grit round the camera, the fog closing in, dusty and warm. It eases in and out, and
-- puts the fog back as it was. During an admin snowfall only the sand blows.
local SANDSTORM = {
	FadeSeconds = 1.5,
	FogStart = 15,
	FogEnd = 260,
	FogColor = Color3.fromRGB(214, 172, 112),
	Wind = Vector3.new(1, 0, 0.25).Unit,
	Rate = if LOW_POWER then 45 else 110,
	GritRate = if LOW_POWER then 60 else 160,
}
local sandstorm = { Weight = 0, Parts = nil, Base = nil }
local Lighting = game:GetService("Lighting")

local function insideBox(box, position)
	return box ~= nil
		and position.X >= box.MinX and position.X <= box.MaxX
		and position.Y >= box.MinY and position.Y <= box.MaxY
		and position.Z >= box.MinZ and position.Z <= box.MaxZ
end

local function buildSandstorm()
	local holder = Instance.new("Part")
	holder.Name = "World3Sandstorm"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanTouch = false
	holder.CanQuery = false
	holder.CastShadow = false
	holder.Transparency = 1
	holder.Size = Vector3.new(160, 70, 160)
	local function emitter(name, rate, size, speed, lifetime, transparency, color)
		local sand = Instance.new("ParticleEmitter")
		sand.Name = name
		sand.Texture = "rbxasset://textures/particles/smoke_main.dds"
		sand.Shape = Enum.ParticleEmitterShape.Box
		sand.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		sand.Rate = 0
		sand.Size = size
		sand.Speed = speed
		sand.Lifetime = lifetime
		sand.Transparency = transparency
		sand.Color = ColorSequence.new(color)
		sand.LightInfluence = 0.6
		sand.Rotation = NumberRange.new(0, 360)
		sand.RotSpeed = NumberRange.new(-40, 40)
		sand.Acceleration = SANDSTORM.Wind * 18
		sand.SpreadAngle = Vector2.new(12, 12)
		sand.Parent = holder
		sand:SetAttribute("FullRate", rate)
		return sand
	end
	-- Rolling clouds of sand, and fast grit in front of them.
	local clouds = emitter("Sand", SANDSTORM.Rate, NumberSequence.new({ NumberSequenceKeypoint.new(0, 10), NumberSequenceKeypoint.new(1, 18) }),
		NumberRange.new(40, 60), NumberRange.new(2.5, 3.5),
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.55), NumberSequenceKeypoint.new(1, 1) }),
		Color3.fromRGB(222, 184, 128))
	local grit = emitter("Grit", SANDSTORM.GritRate, NumberSequence.new(0.35), NumberRange.new(70, 95), NumberRange.new(1, 1.6),
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
		Color3.fromRGB(196, 158, 104))
	grit.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	grit.LightEmission = 0
	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "World3SandstormTint"
	tint.Parent = Lighting
	holder.Parent = visuals
	sandstorm.Parts = { Holder = holder, Emitters = { clouds, grit }, Tint = tint }
	sandstorm.Base = { FogStart = Lighting.FogStart, FogEnd = Lighting.FogEnd, FogColor = Lighting.FogColor }
end

local function removeSandstorm()
	if sandstorm.Parts then
		sandstorm.Parts.Holder:Destroy()
		sandstorm.Parts.Tint:Destroy()
		sandstorm.Parts = nil
	end
	if sandstorm.Base then
		Lighting.FogStart = sandstorm.Base.FogStart
		Lighting.FogEnd = sandstorm.Base.FogEnd
		Lighting.FogColor = sandstorm.Base.FogColor
		sandstorm.Base = nil
	end
end

local function updateSandstorm(dt, root)
	local area = layout.Sandstorm
	local inside = root ~= nil and insideBox(area, root.Position)
	sandstorm.Weight = math.clamp(sandstorm.Weight + (if inside then dt else -dt) / SANDSTORM.FadeSeconds, 0, 1)
	local w = sandstorm.Weight
	if w == 0 then
		removeSandstorm()
		return
	end
	if not sandstorm.Parts then
		buildSandstorm()
	end
	local camera = Workspace.CurrentCamera
	if camera then
		-- The box sits upwind of the camera, so the sand comes through the view.
		local position = camera.CFrame.Position - SANDSTORM.Wind * 40
		sandstorm.Parts.Holder.CFrame = CFrame.lookAt(position, position + SANDSTORM.Wind)
	end
	for _, emitter in sandstorm.Parts.Emitters do
		emitter.Rate = (tonumber(emitter:GetAttribute("FullRate")) or 0) * w
		emitter.EmissionDirection = Enum.NormalId.Front
	end
	local tint = sandstorm.Parts.Tint
	tint.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(255, 232, 196), w)
	tint.Saturation = -0.12 * w
	tint.Contrast = 0.06 * w
	-- The fog: not while an admin snowfall has the sky.
	local snowing = (tonumber(Workspace:GetAttribute("AdminSnowUntil")) or 0) > Workspace:GetServerTimeNow()
	local base = sandstorm.Base
	if not snowing and base then
		local eased = w * w * (3 - 2 * w)
		Lighting.FogStart = base.FogStart + (SANDSTORM.FogStart - base.FogStart) * eased
		Lighting.FogEnd = base.FogEnd + (math.min(base.FogEnd, SANDSTORM.FogEnd) - base.FogEnd) * eased
		Lighting.FogColor = base.FogColor:Lerp(SANDSTORM.FogColor, eased)
	end
end

----------------------------------------------------------------------
-- Stage 10's lasers
----------------------------------------------------------------------
local LASER_LOOK = {
	On = { Color = Color3.fromRGB(255, 35, 35), Transparency = 0 },
	Warn = { Color = Color3.fromRGB(255, 150, 40), Bright = 0.2, Dim = 0.75, FlickerHz = 8 },
	Off = { Color = Color3.fromRGB(255, 90, 90), Transparency = 0.88 },
}
local lasers = {} -- [part] = its number
local laserHomes = {} -- [part] = where it was built: what it turns about
-- The home the server published (World3LaserHome), never the part as it is now: this script
-- turns the part, so a bar read after that would be taken part-way round. The server does
-- not move the part, so without the attribute the part as it arrives is still at home.
local function laserHome(part)
	local published = part:GetAttribute("World3LaserHome")
	if typeof(published) == "CFrame" then
		return published
	end
	local ok, arrived = pcall(function()
		return part.CFrame
	end)
	return if ok then arrived else nil
end
local function addLaser(part)
	if part:IsA("BasePart") then
		lasers[part] = tonumber(part:GetAttribute("World3LaserIndex")) or 1
		laserHomes[part] = laserHome(part)
		part.Material = Enum.Material.Neon
		part.CanCollide = false
	end
end
for _, part in CollectionService:GetTagged("World3Laser") do
	addLaser(part)
end
CollectionService:GetInstanceAddedSignal("World3Laser"):Connect(addLaser)
CollectionService:GetInstanceRemovedSignal("World3Laser"):Connect(function(part)
	lasers[part] = nil
	laserHomes[part] = nil
end)

local function drawLasers(elapsed, root)
	for part, index in lasers do
		if part.Parent then
			local home = laserHomes[part]
			if not home then
				-- Never turned here yet (no home, no write), so the part is still where it arrived.
				home = laserHome(part)
				laserHomes[part] = home
			end
			if not home or (root and (home.Position - root.Position).Magnitude > DRAW_DISTANCE) then
				continue
			end

			local state, through = Motion.LaserState(index, elapsed)
			local look = LASER_LOOK[state]
			if state == "Warn" then
				-- Faster and brighter as it gets close to coming on.
				local wave = math.sin(elapsed * math.pi * 2 * look.FlickerHz * (1 + through)) > 0
				part.Transparency = if wave then look.Bright else look.Dim
			else
				part.Transparency = look.Transparency
			end
			part.Color = look.Color
			local deadly = state == "On"
			if part.CanTouch ~= deadly then
				part.CanTouch = deadly
			end

			-- It turns about its middle here, every frame, on the server's clock. The server moves
			-- no part (it tests this same pose), so nothing arrives late to snap it back.
			part.CFrame = Motion.LaserPose(home, index, elapsed)
		else
			lasers[part] = nil
			laserHomes[part] = nil
		end
	end
end

----------------------------------------------------------------------
-- Stage 10: Canyon Crosswind (push to the side)
----------------------------------------------------------------------
local WIND_ZONE = {
	MinX = 140, MaxX = 300,
	MinY = 110, MaxY = 175,
	MinZ = -7220, MaxZ = -7000,
	PushSpeed = -36, -- Pushes to the left (-X) across the canyon trail
}

local function updateWindZone(dt, root)
	if not root then return end
	local pos = root.Position
	if pos.X >= WIND_ZONE.MinX and pos.X <= WIND_ZONE.MaxX
		and pos.Y >= WIND_ZONE.MinY and pos.Y <= WIND_ZONE.MaxY
		and pos.Z >= WIND_ZONE.MinZ and pos.Z <= WIND_ZONE.MaxZ
	then
		local currentVel = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(
			currentVel.X + WIND_ZONE.PushSpeed * math.min(dt, 0.05) * 4,
			currentVel.Y,
			currentVel.Z
		)
	end
end

----------------------------------------------------------------------
-- Every frame
----------------------------------------------------------------------
RunService.RenderStepped:Connect(function(dt)
	local elapsed = elapsedNow()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	drawTumbleweeds(elapsed, root)
	drawRoadrunners(elapsed, root)
	drawCarts(elapsed, root)
	drawSerpent(elapsed, root)
	drawScorpions(elapsed, root)
	updateSandstorm(dt, root)
	updateWarning(elapsed, root)
	drawLasers(elapsed, root)
end)

RunService.Heartbeat:Connect(function(dt)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root then
		checkHits(elapsedNow(), character, root)
		updateWindZone(dt or 0.016, root)
	end
end)
