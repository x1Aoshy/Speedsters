-- test_world3_hazards.luau
-- World 3 (Desert), step 4, offline against the built place:
--
--   1. World3HazardLayout reads every trap off the real map: 20 cactus, a tumbleweed lane
--      in each gap of Stage 2, two roadrunners on Stage 3, the quicksand, the 8 flat
--      parkour platforms of Stage 6, a cart on each of the 7 rail lines, the serpent's
--      canyon (Stage 8 to Stage 9's checkpoint) with its 5 dugouts, 9 scorpion lanes
--      across Stage 9's trail clear of its rocks and caves, Stage 10's 2 crumbling
--      platforms, 2 lasers, void layer and sandstorm area, and a void height per stage 25
--      studs under its lowest floor (Stage 10's at its void layer; every fall dies above
--      the lava or Baseplate).
--   2. World3HazardMotion: hazards stay on their floors, hit what they touch and only
--      that, carts can be ridden, the serpent kills on contact, spares dugouts and never
--      reaches a checkpoint; scorpions cross their lane and turn round.
--   3. World3Hazards (server) with simulated players: quicksand kills after 2.5 s on sand
--      (safe ground resets, air pauses), the void kills under each stage's height, cactus
--      kills body parts only, self-hit reports only kill a player standing where that
--      hazard runs, and nothing kills a player in teleport grace.
local fs = require("@lune/fs")
local PlaceFiles = require("./place_files")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local Vector3 = roblox.Vector3
local LAYOUT = "src/worlds/World3/ServerScriptService/Gameplay/World3HazardLayout.luau"
local MOTION = "src/worlds/World3/ReplicatedStorage/Shared/World3HazardMotion.luau"
local SERVER = "src/worlds/World3/ServerScriptService/Gameplay/World3Hazards.server.luau"
local TELEPORT = "src/worlds/World3/ServerScriptService/Gameplay/World3StageTeleportService.luau"

local function signal()
	local handlers = {}
	return {
		Connect = function(_, fn)
			table.insert(handlers, fn)
			return { Disconnect = function() end }
		end,
		Fire = function(_, ...)
			for _, fn in handlers do
				fn(...)
			end
		end,
	}
end

local function environment(extra)
	local env = extra or {}
	for _, name in { "CFrame", "Vector3", "Vector2", "Color3", "UDim2", "UDim", "NumberRange", "ColorSequence", "ColorSequenceKeypoint", "NumberSequence", "NumberSequenceKeypoint", "Enum", "Instance" } do
		env[name] = env[name] or roblox[name]
	end
	env.typeof = typeof
	env._G = env._G or {}
	env.print = env.print or function() end
	env.warn = env.warn or function() end
	return setmetatable(env, { __index = _G })
end

local function forward(real, extra)
	return setmetatable({}, { __index = function(_, key)
		if extra and extra[key] ~= nil then
			return extra[key]
		end
		local value = real[key]
		if type(value) == "function" then
			return function(_, ...)
				return value(real, ...)
			end
		end
		return value
	end })
end

local place = roblox.deserializePlace(fs.readFile(PlaceFiles.World3))
local realWorkspace = place:GetService("Workspace")

local configEnv = environment({ workspace = forward(realWorkspace) })
configEnv.game = { PlaceId = 0, GetService = function(_, name)
	return forward(place:GetService(name))
end }
local Config = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/Config.luau"), { environment = configEnv })()
assert(Config.IsWorld3Place == true, "World3NewestStable must be World 3")

-- The stage service, reading the real map.
local raycastResult = nil
local serverClock = 5000
local workspaceProxy = forward(realWorkspace, {
	DescendantAdded = signal(),
	DescendantRemoving = signal(),
	GetServerTimeNow = function()
		return serverClock
	end,
	Raycast = function()
		return raycastResult
	end,
})
local modules = { Config = Config }
local sharedFolder = { WaitForChild = function(_, name)
	return { __module = name }
end }
local stageEnv = environment({
	game = { GetService = function(_, name)
		if name == "Workspace" then
			return workspaceProxy
		end
		return { WaitForChild = function()
			return sharedFolder
		end }
	end },
	require = function(target)
		return modules[target.__module]
	end,
})
local Stages = luau.load(fs.readFile(TELEPORT), { environment = stageEnv })()
modules.World3StageTeleportService = Stages
local Motion = luau.load(fs.readFile(MOTION), { environment = environment() })()
modules.World3HazardMotion = Motion
-- World3Hazards.server builds Stage 10's bridge ramp with the shared plan (2026-09-20).
modules.BridgeRampPlan = luau.load(fs.readFile("src/common/ServerScriptService/Gameplay/BridgeRampPlan.luau"), { environment = environment() })()
local Layout = luau.load(fs.readFile(LAYOUT), { environment = environment() })()

-- 1. The layout --------------------------------------------------------------
local templates = place:GetService("ServerStorage"):FindFirstChild("World3HazardTemplates")
assert(templates and templates:FindFirstChild("Snake") and templates:FindFirstChild("Scorpion"), "The Snake and Scorpion templates are in the place")
local layout = Layout.Read(realWorkspace, Stages, templates)
assert(#layout.Problems == 0, "Hazard layout problems:\n" .. table.concat(layout.Problems, "\n"))

local cactusFolder = realWorkspace["Stage 1"].Cactus
assert(#layout.CactusParts == 60, "20 cactus of 3 parts each, got " .. #layout.CactusParts)
for _, part in layout.CactusParts do
	assert(part:IsDescendantOf(cactusFolder), "Only Stage 1's cactus hurt")
end

local platform = realWorkspace["Stage 2"].Main.Platform
local strips = {}
for _, child in platform:GetChildren() do
	if child:IsA("BasePart") and child.Size.Z < 20 then
		table.insert(strips, child)
	end
end
assert(#layout.Client.Tumbleweeds == 5, "A tumbleweed lane in each of the 5 gaps, got " .. #layout.Client.Tumbleweeds)
for index, lane in layout.Client.Tumbleweeds do
	for _, strip in strips do
		local z = strip.CFrame.Position.Z
		assert(math.abs(lane.Z - z) >= strip.Size.Z / 2 + lane.Radius - 0.01, "Lane " .. index .. " must run between the strips")
	end
	assert(math.abs(lane.FloorY - 91.4) < 0.5, "Tumbleweeds roll on Stage 2's floor")
	assert(math.min(lane.XFrom, lane.XTo) < 185 and math.max(lane.XFrom, lane.XTo) > 305, "Tumbleweeds cross the whole floor")
	assert(index == 1 or (lane.XTo > lane.XFrom) ~= (layout.Client.Tumbleweeds[index - 1].XTo > layout.Client.Tumbleweeds[index - 1].XFrom), "Lanes alternate direction")
end

assert(#layout.Client.Roadrunners == 2, "Two roadrunners")
assert(#layout.QuicksandParts == 3, "The quicksand model's three parts")
for _, part in layout.QuicksandParts do
	assert(part:IsDescendantOf(realWorkspace["Stage 5"]["Quicksand Part"]), "Quicksand comes from the Quicksand Part model")
end

local stage6Platforms, stage10Platforms = 0, 0
for _, part in layout.CollapseParts do
	local stage = layout.CollapseStages[part]
	if stage == 6 then
		stage6Platforms += 1
		local top = part.CFrame.Position.Y + part.Size.Y / 2
		assert(part.Name ~= "Conveyor" and part.Size.Y <= 6 and math.abs(top - 52.3) < 0.5, "Only the flat platforms collapse: " .. part:GetFullName())
	else
		assert(stage == 10, "Collapsing platforms belong to Stage 6 or 10")
		stage10Platforms += 1
		assert(part:IsDescendantOf(realWorkspace["Stage 10"]["Action Parts"]) and part.Size.Y <= 12 and part.CFrame.UpVector.Y > 0.99,
			"Stage 10's crumbling platforms are the flat Action Parts: " .. part:GetFullName())
	end
end
assert(stage6Platforms == 8, "Stage 6 has 8 flat parkour platforms, got " .. stage6Platforms)
assert(stage10Platforms == 2, "Stage 10 has 2 crumbling platforms, got " .. stage10Platforms)
assert(Layout.Collapse[6].Shake == 0.6 and Layout.Collapse[6].Back == 3, "Stage 6: 0.6 s shake, back after 3 s")
assert(Layout.Collapse[10].Shake == 2.0 and Layout.Collapse[10].Back >= 3 and Layout.Collapse[10].Back <= 4, "Stage 10: 2.0 s shake, back after 3-4 s")

-- Stage 9: scorpion lanes across the trail, clear of the rocks and caves.
local from9 = Layout.BoundsOf(Stages.GetStageMarkers(9).Checkpoint)
local to9 = Layout.BoundsOf(Stages.GetStageMarkers(10).Checkpoint)
assert(#layout.Client.Scorpions == 9, "9 scorpion lanes across Stage 9, got " .. #layout.Client.Scorpions)
local scorpionTemplate = templates.Scorpion
local blockers = {}
for _, part in realWorkspace["Stage 9"]:GetDescendants() do
	if part:IsA("BasePart") then
		local box = Layout.BoundsOf(part)
		local ok, collides = pcall(function()
			return part.CanCollide
		end)
		if (not ok or collides) and box.MaxY > 119.5 + 8 and box.MinY < 119.5 + scorpionTemplate.Size.Y and (box.MaxX - box.MinX) * (box.MaxZ - box.MinZ) >= 20 then
			table.insert(blockers, box)
		end
	end
end
for index, lane in layout.Client.Scorpions do
	assert(lane.Z < from9.MinZ - 30 and lane.Z > to9.MaxZ + 30, "Scorpion " .. index .. " runs between Stage 9's and Stage 10's checkpoints")
	assert(math.abs(lane.FloorY - 119.5) < 0.6, "Scorpion " .. index .. " walks on Stage 9's trail")
	assert(math.abs(lane.XTo - lane.XFrom) >= 60, "Scorpion " .. index .. " crosses a good stretch of the trail")
	assert(math.abs(lane.Length - scorpionTemplate.Size.Z) < 0.01 and math.abs(lane.Height - scorpionTemplate.Size.Y) < 0.01, "Lanes take the Scorpion model's size")
	assert(index == 1 or (lane.XTo > lane.XFrom) ~= (layout.Client.Scorpions[index - 1].XTo > layout.Client.Scorpions[index - 1].XFrom), "Lanes alternate direction")
	local low, high = math.min(lane.XFrom, lane.XTo) - lane.Length / 2, math.max(lane.XFrom, lane.XTo) + lane.Length / 2
	for _, box in blockers do
		if box.MinZ < lane.Z + lane.Width / 2 and box.MaxZ > lane.Z - lane.Width / 2 then
			assert(box.MaxX <= low or box.MinX >= high, string.format("Scorpion %d never walks through a rock or cave (x %.0f..%.0f)", index, box.MinX, box.MaxX))
		end
	end
end
assert(realWorkspace:FindFirstChild("Scorpion") == nil and realWorkspace:FindFirstChild("Snake") == nil, "No still Snake or Scorpion in the map")

-- Stage 10: lasers, the void layer and the sandstorm's area.
assert(#layout.LaserParts == 2, "Stage 10's 2 laser bars kill")
for _, part in layout.LaserParts do
	assert(string.lower(part.Name) == "laser" and part:IsDescendantOf(realWorkspace["Stage 10"]), "Lasers are the red laser bars")
end
assert(#layout.VoidParts == 3, "Stage 10's 3 void parts kill")
for _, part in layout.VoidParts do
	assert(part:IsDescendantOf(realWorkspace["Stage 10"]["Void (SCRIPT THE KILL)"]), "Void parts come from the Void folder")
end
local function insideBox(box, point)
	return point.X >= box.MinX and point.X <= box.MaxX and point.Y >= box.MinY and point.Y <= box.MaxY and point.Z >= box.MinZ and point.Z <= box.MaxZ
end
local storm = layout.Client.Sandstorm
assert(storm and insideBox(storm, Stages.GetStageReferencePosition(10)) and insideBox(storm, layout.LaserParts[1].CFrame.Position),
	"The sandstorm covers Stage 10")
assert(not insideBox(storm, Stages.GetStageReferencePosition(9)) and not insideBox(storm, Stages.GetStageReferencePosition(1)),
	"...and stays off the other stages")

assert(#layout.Client.Carts == 7, "A cart on each of the 7 rail lines, got " .. #layout.Client.Carts)
local lineZ = {}
for _, line in realWorkspace["Stage 7"].Rails:GetChildren() do
	local box = Layout.BoundsOf(line)
	table.insert(lineZ, (box.MinZ + box.MaxZ) / 2)
end
for index, cart in layout.Client.Carts do
	local onLine = false
	for _, z in lineZ do
		onLine = onLine or math.abs(cart.Z - z) < 0.01
	end
	assert(onLine and math.abs(cart.BaseY - 119.5) < 1 and cart.Length > cart.Width, "Cart " .. index .. " rides its rail line lengthwise")
end

local serpent = layout.Client.Serpent
assert(serpent and math.abs(serpent.ZStart - (-5765)) < 1 and math.abs(serpent.ZEnd - (-5162)) < 1,
	"The serpent runs from Stage 9's checkpoint back to Stage 8's")
assert(serpent.HeadRadius > serpent.BodyRadius and serpent.BodyRadius >= 3, "It has a head and a body of its own thickness")
assert(#serpent.Dugouts == 5, "The 5 pits are the dugouts")
for _, dugout in serpent.Dugouts do
	assert(dugout.X > serpent.XMin and dugout.X < serpent.XMax and Motion.InCanyon(serpent, dugout.Z) and dugout.Radius > 10,
		"Dugouts lie in the canyon")
end

local expectedPlanes = { 57.0, 55.5, 56.5, 66.0, 105.9, 26.7, 84.2, 84.2, 84.2, 115.1 }
local lavaTop = { [1] = 44.7, [2] = 44.7, [3] = 44.7, [4] = 59.2, [6] = -33.7 }
for stage = 1, 10 do
	local plane = layout.VoidPlanes[stage]
	assert(plane and math.abs(plane - expectedPlanes[stage]) < 0.6, string.format("Stage %d void at %.1f, expected about %.1f", stage, plane or -1, expectedPlanes[stage]))
	local reference = Stages.GetStageReferencePosition(stage)
	assert(reference.Y - plane >= (if stage == 10 then Layout.Stage10VoidBelowCheckpoint else 25), "Stage " .. stage .. "'s own checkpoint is well above its void")
	assert(plane > (lavaTop[stage] or 0) and plane > 3, "A fall in Stage " .. stage .. " dies before it reaches lava or the Baseplate")
end
assert(layout.VoidPlanes[6] <= 52.3 - 25, "Stage 6's parkour at y 52 stays 25 studs above the void")
local finishTop = Stages.GetFinish().Checkpoint
assert(finishTop.CFrame.Position.Y + finishTop.Size.Y / 2 - layout.VoidPlanes[10] >= 8, "The finish is above the void")

-- Stage 10's void is just under its route (2026-09-18: it was the void layer at y 25, and a
-- fall landed alive on a rock ledge 90 studs above it). Every surface a player can stand on
-- over Stage 10 (nothing lying right on top of it) is either the route, where a standing
-- character (root 3 over its feet) is well above the void, or a ledge under it, where the
-- same character is under the void and dies.
do
	local plane = layout.VoidPlanes[10]
	local checkpointTop = Stages.GetStageReferencePosition(10).Y
	local surfaces = {}
	for _, folderName in { "Stage 10", "End" } do
		for _, part in realWorkspace[folderName]:GetDescendants() do
			if part:IsA("BasePart") and part.CanCollide and part.Transparency < 0.95 then
				local box = Layout.BoundsOf(part)
				if (box.MaxX - box.MinX) * (box.MaxZ - box.MinZ) >= 16 and box.MaxY > 60 and box.MaxY < checkpointTop + 15 then
					table.insert(surfaces, { Part = part, Box = box })
				end
			end
		end
	end
	local function covered(entry)
		-- Something solid lies over all of its top, right on it (a stone's own upper layer).
		for _, other in surfaces do
			local box = other.Box
			if other ~= entry and box.MaxY > entry.Box.MaxY + 0.05 and box.MinY <= entry.Box.MaxY + 0.5
				and box.MinX <= entry.Box.MinX + 0.5 and box.MaxX >= entry.Box.MaxX - 0.5
				and box.MinZ <= entry.Box.MinZ + 0.5 and box.MaxZ >= entry.Box.MaxZ - 0.5
			then
				return true
			end
		end
		return false
	end
	local route, ledges = 0, 0
	for _, entry in surfaces do
		if not covered(entry) and string.lower(entry.Part.Name) ~= "laser" then
			local rootY = entry.Box.MaxY + 3
			if entry.Box.MaxY >= checkpointTop - 3 then
				route += 1
				assert(rootY - plane >= 5, entry.Part:GetFullName() .. " (top " .. entry.Box.MaxY .. ") is on the route: well above the void")
			else
				ledges += 1
				assert(rootY < plane - 1, entry.Part:GetFullName() .. " (top " .. entry.Box.MaxY .. ") is a ledge under the route: a fall onto it dies")
			end
		end
	end
	assert(route >= 10 and ledges >= 5, "Stage 10's stones and the ledges under them (" .. route .. " / " .. ledges .. ")")
end
print("PASS the layout reads every trap off the map, and a void height per stage 25 studs under its lowest floor (Stage 10's just under its route, over every ledge)")

-- Stage 10's lasers: a fair cycle, the same clock on every client and the server.
do
	local settings = Motion.Laser
	local offSeconds = settings.Period - settings.OnSeconds - settings.WarnSeconds
	assert(offSeconds >= 1.5 and settings.WarnSeconds >= 0.8 and settings.OnSeconds <= settings.Period / 2, "A safe window of at least 1.5 s, then a warning of about a second, then on for under half the cycle")
	local seen = {}
	local previous = nil
	for step = 0, 499 do
		local t = step * settings.Period / 500
		local state = Motion.LaserState(1, t)
		seen[state] = (seen[state] or 0) + 1
		if previous and previous ~= state then
			local order = previous .. ">" .. state
			assert(order == "Off>Warn" or order == "Warn>On" or order == "On>Off", "Off, then the warning, then on: " .. order)
		end
		previous = state
	end
	assert(math.abs(seen.Off / 500 * settings.Period - offSeconds) < 0.05 and math.abs(seen.Warn / 500 * settings.Period - settings.WarnSeconds) < 0.05, "Each state lasts its time")
	assert(Motion.LaserState(2, 0) == Motion.LaserState(1, settings.Period / 2), "The second laser runs half a cycle after the first")
	assert(Motion.LaserState(1, 7 + settings.Period) == Motion.LaserState(1, 7), "It repeats every cycle")
	local onAt = offSeconds + settings.WarnSeconds
	assert(not Motion.LaserDeadly(1, onAt + 0.1), "The server waits a moment after it comes on (it sees characters a little late)")
	assert(Motion.LaserDeadly(1, onAt + Motion.LaserServerLag + 0.05), "...then it is deadly")
	assert(not Motion.LaserDeadly(1, offSeconds + 0.5) and not Motion.LaserDeadly(1, 0.5), "Never while warning or off")
	local box = { MinX = 0, MaxX = 100, MinY = 123, MaxY = 125, MinZ = 0, MaxZ = 3 }
	assert(Motion.LaserTouches(box, Vector3.new(50, 124, 1.5)), "Standing in the beam touches it")
	assert(not Motion.LaserTouches(box, Vector3.new(50, 128.5, 1.5)), "Jumping clear over it does not")
	assert(not Motion.LaserTouches(box, Vector3.new(50, 124, 5)), "Standing beside it does not")
	print("PASS lasers: off (safe) " .. offSeconds .. " s, a warning flicker " .. settings.WarnSeconds .. " s, on " .. settings.OnSeconds .. " s, half a cycle apart, deadly only while on")
end

-- 2. Motion ------------------------------------------------------------------
for index, lane in layout.Client.Tumbleweeds do
	local rolled = false
	local first = Motion.TumbleweedPose(lane, 10)
	for t = 0, 40, 0.37 do
		local position, _, active = Motion.TumbleweedPose(lane, t)
		assert(position.X >= math.min(lane.XFrom, lane.XTo) - 0.01 and position.X <= math.max(lane.XFrom, lane.XTo) + 0.01, "Tumbleweed stays in its lane")
		assert(math.abs(position.Z - lane.Z) < 0.01 and position.Y >= lane.FloorY + lane.Radius - 0.01, "Tumbleweed rolls on the floor")
		assert(Motion.TumbleweedPose(lane, t) == position, "Motion is a pure function of time")
		if active then
			assert(Motion.Hits(layout.Client, "Tumbleweed", index, t, position), "A tumbleweed hits what it touches")
			assert(not Motion.Hits(layout.Client, "Tumbleweed", index, t, position + Vector3.new(0, 0, lane.Radius + 3)), "A tumbleweed misses the next lane")
		else
			assert(not Motion.Hits(layout.Client, "Tumbleweed", index, t, position), "Out of sight, it hits nothing")
		end
		rolled = rolled or position ~= first
	end
	assert(rolled, "Tumbleweeds roll")
end

local runwayBox = Layout.BoundsOf(realWorkspace["Stage 3"].Platform)
for index, runner in layout.Client.Roadrunners do
	for t = 0, 60, 0.53 do
		local position = Motion.RoadrunnerPose(runner, t)
		assert(position.X > runwayBox.MinX and position.X < runwayBox.MaxX and position.Z > runwayBox.MinZ and position.Z < runwayBox.MaxZ,
			"Roadrunner " .. index .. " stays on its platform")
		assert(Motion.Hits(layout.Client, "Roadrunner", index, t, position), "A roadrunner hits what it runs into")
		assert(not Motion.Hits(layout.Client, "Roadrunner", index, t, position + Vector3.new(runner.Radius + 4, 0, 0)), "and misses what it passes")
	end
end

for index, cart in layout.Client.Carts do
	for t = 0, 30, 0.41 do
		local centre = Motion.CartPose(cart, t)
		assert(centre.X - cart.Length / 2 >= cart.XMin - 0.01 and centre.X + cart.Length / 2 <= cart.XMax + 0.01, "Carts stay on their rails")
		local roof = cart.BaseY + cart.Height
		assert(Motion.Hits(layout.Client, "Cart", index, t, centre + Vector3.new(0, -cart.Height / 4, 0), cart.BaseY + 3), "A cart hits whoever stands in its way")
		assert(not Motion.Hits(layout.Client, "Cart", index, t, Vector3.new(centre.X, roof, centre.Z), roof + 3), "A rider on the roof is safe")
	end
end

local function serpentTime(targetHeadZ)
	for t = 0, serpent.Period, 0.01 do
		local phase, headZ = Motion.SerpentState(serpent, t)
		if phase == "Pass" and math.abs(headZ - targetHeadZ) < 1.5 then
			return t
		end
	end
	error("no pass through " .. targetHeadZ)
end
local centreX = (serpent.XMin + serpent.XMax) / 2
local middle = (serpent.ZStart + serpent.ZEnd) / 2
local passing = serpentTime(middle)
-- It kills on contact: its head and body, not the canyon around them.
local body = Motion.SerpentBody(serpent, passing, Motion.SerpentPoints)
assert(Motion.Hits(layout.Client, "Serpent", 1, passing, body[1]), "The serpent's head kills what it touches")
assert(Motion.Hits(layout.Client, "Serpent", 1, passing, body[6] + Vector3.new(0, 0, 0)), "...and so does its body")
for _, index in { 3, 8, 12 } do
	local point = body[index]
	local farSide = if point.X > centreX then serpent.XMin + 5 else serpent.XMax - 5
	if math.abs(farSide - point.X) > 25 then
		assert(not Motion.Hits(layout.Client, "Serpent", 1, passing, Vector3.new(farSide, serpent.FloorY + 3, point.Z)), "Away from its body the canyon is safe")
	end
end
assert(not Motion.Hits(layout.Client, "Serpent", 1, passing, Vector3.new(centreX, serpent.FloorY + 3, middle + 40)), "and nothing ahead of its head")
for _, dugout in serpent.Dugouts do
	local over = serpentTime(dugout.Z + 20)
	assert(not Motion.Hits(layout.Client, "Serpent", 1, over, Vector3.new(dugout.X, serpent.FloorY + 3, dugout.Z)), "A dugout is safe while the serpent passes")
	for _, point in Motion.SerpentBody(serpent, over, Motion.SerpentPoints) do
		if point and not Motion.InDugout(serpent, point) then
			assert(Motion.Hits(layout.Client, "Serpent", 1, over, point), "Out of the dugout, its body still kills")
		end
	end
end
local leaving = serpentTime(serpent.ZEnd + 60)
local checkpoint8 = Stages.GetStageMarkers(8).Checkpoint.CFrame.Position
assert(not Motion.Hits(layout.Client, "Serpent", 1, leaving, Vector3.new(checkpoint8.X, serpent.FloorY + 3, serpent.ZEnd + 20)), "Stage 8's checkpoint is never reached")
for t = 0, serpent.WarnTime - 0.01, 0.2 do
	assert(Motion.SerpentState(serpent, t) == "Warning" and not Motion.Hits(layout.Client, "Serpent", 1, t, Vector3.new(centreX, serpent.FloorY + 3, middle)), "The warning never kills")
end
local resting = serpent.Period - 0.5
assert(Motion.SerpentState(serpent, resting) == "Rest" and not Motion.Hits(layout.Client, "Serpent", 1, resting, Vector3.new(centreX, serpent.FloorY + 3, middle)), "Nothing kills while it rests")
-- Scorpions cross their lane and back, turn round at each end, and sting what they touch.
for index, lane in layout.Client.Scorpions do
	local turned = false
	local low, high = math.min(lane.XFrom, lane.XTo), math.max(lane.XFrom, lane.XTo)
	for t = 0, 30, 0.29 do
		local centre, facing, turning = Motion.ScorpionPose(lane, t)
		assert(centre.X >= low - 0.01 and centre.X <= high + 0.01 and math.abs(centre.Z - lane.Z) < 0.01, "Scorpion " .. index .. " keeps to its lane")
		assert(math.abs(centre.Y - (lane.FloorY + lane.Height / 2)) < 0.01 and math.abs(facing.Magnitude - 1) < 1e-6, "on the trail, facing along it")
		assert(Motion.Hits(layout.Client, "Scorpion", index, t, centre), "A scorpion stings what it touches")
		assert(not Motion.Hits(layout.Client, "Scorpion", index, t, centre + Vector3.new(0, 0, lane.Width / 2 + 2)), "...not what passes beside it")
		assert(not Motion.Hits(layout.Client, "Scorpion", index, t, centre + Vector3.new(0, lane.Height + 2, 0)), "...nor a player jumping over it")
		turned = turned or turning > 0
	end
	assert(turned, "Scorpions stop and turn round at each end")
end
print("PASS hazards stay on their floors and hit only what they touch; carts carry riders; the serpent kills on contact and spares dugouts and checkpoints; scorpions cross and turn")

-- 3. The server ---------------------------------------------------------------
local players = {}
local playersService = { PlayerRemoving = signal() }
function playersService:GetPlayers()
	return players
end
function playersService:GetPlayerFromCharacter(character)
	return character.Player
end
local heartbeat = signal()
local layoutFolder = roblox.Instance.new("Folder")
layoutFolder.Name = "World3HazardLayout"
local selfHitRemote = { OnServerEvent = signal() }
local replicated = {
	WaitForChild = function(_, name)
		assert(name == "Shared")
		return sharedFolder
	end,
	FindFirstChild = function(_, name)
		if name == "World3HazardLayout" then
			return layoutFolder
		elseif name == "Remotes" then
			return { FindFirstChild = function(_, child)
				assert(child == "World3HazardSelfHit", child)
				return selfHitRemote
			end }
		end
		return nil
	end,
}
local cactusTouched, laserTouched, voidTouched = {}, {}, {}
modules.World3HazardLayout = {
	BoundsOf = Layout.BoundsOf,
	Collapse = Layout.Collapse,
	Read = function(_, stages, templatesFolder)
		assert(templatesFolder == templates, "The server reads the templates from ServerStorage")
		local read = Layout.Read(realWorkspace, stages, templatesFolder)
		for list, signals in { [read.CactusParts] = cactusTouched, [read.LaserParts] = laserTouched, [read.VoidParts] = voidTouched } do
			for index in list do
				local touched = signal()
				signals[index] = touched
				list[index] = { Touched = touched, CanCollide = true, Attributes = {}, SetAttribute = function(self, key, value)
					self.Attributes[key] = value
				end }
			end
		end
		return read
	end,
}
local serverEnv = environment({
	require = function(target)
		return assert(modules[target.__module], tostring(target.__module))
	end,
	RaycastParams = { new = function()
		return {}
	end },
})
serverEnv.script = { Parent = { WaitForChild = function(_, name)
	return { __module = name }
end } }
serverEnv.game = { GetService = function(_, name)
	return assert(({
		HttpService = { JSONEncode = function(_, value)
			return serde.encode("json", value)
		end },
		CollectionService = { AddTag = function(_, part, tag)
			part.Tag = tag
		end },
		Players = playersService,
		ReplicatedStorage = replicated,
		RunService = { Heartbeat = heartbeat },
		ServerStorage = { FindFirstChild = function(_, name)
			return if name == "World3HazardTemplates" then templates else nil
		end },
		Workspace = workspaceProxy,
	})[name], name)
end }
local Server = luau.load(fs.readFile(SERVER), { environment = serverEnv })()

local published = serde.decode("json", layoutFolder:GetAttribute("Layout"))
assert(#published.Tumbleweeds == 5 and #published.Carts == 7 and #published.Roadrunners == 2 and #published.Serpent.Dugouts == 5,
	"The server publishes the moving hazards for the clients")
assert(layoutFolder:GetAttribute("Epoch") == 5000, "and the shared start time")
assert(layoutFolder:FindFirstChild("Tumbleweed") and layoutFolder:FindFirstChild("Cart"), "The map's tumbleweed and wagon become the clients' models")
assert(#published.Scorpions == 9 and published.Sandstorm ~= nil, "The server publishes the scorpions and the sandstorm's area")
local snake = layoutFolder:FindFirstChild("Snake")
assert(snake and layoutFolder:FindFirstChild("Scorpion"), "The clients get the modeller's Snake and Scorpion")
local green = snake.Torso1.Color
assert(green.G > green.R * 1.3 and green.G > green.B * 1.5, "The Snake is desert green")
for _, fang in { snake.LeftFang, snake.RightFang } do
	assert(fang.Color.R > 0.9 and fang.Color.G > 0.9 and fang.Color.B > 0.9, "...with white fangs")
end
assert(realWorkspace["Stage 2"].Main:FindFirstChild("Tumbleweed") == nil, "and leave the course, so no still copy blocks it")
for index, part in Server.Layout.CollapseParts do
	assert(part:GetAttribute("World3CollapsePlatform") == index, "Collapsing platforms are tagged for the clients")
	local stage = Server.Layout.CollapseStages[part]
	assert(part:GetAttribute("World3CollapseShake") == Layout.Collapse[stage].Shake and part:GetAttribute("World3CollapseBack") == Layout.Collapse[stage].Back,
		"...with their stage's shake and return times")
end

local function makePlayer(position)
	local attributes = { DataLoaded = true }
	local humanoid = { Health = 100 }
	local root = { Position = position }
	local character = { Attributes = {} }
	function character:FindFirstChildOfClass(class)
		return if class == "Humanoid" then humanoid else nil
	end
	function character:FindFirstChild(name)
		return if name == "HumanoidRootPart" then root else nil
	end
	function character:GetAttribute(key)
		return self.Attributes[key]
	end
	local player = { Character = character, Humanoid = humanoid, Root = root }
	character.Player = player
	function player:GetAttribute(key)
		return attributes[key]
	end
	function player:SetAttribute(key, value)
		attributes[key] = value
	end
	table.insert(players, player)
	return player
end
local function step(times)
	for _ = 1, times do
		Server.Step(0.1)
	end
end

-- Quicksand.
local quicksandTop = Server.Layout.QuicksandParts[1]
for _, part in Server.Layout.QuicksandParts do
	if part.CFrame.Position.Y + part.Size.Y / 2 > quicksandTop.CFrame.Position.Y + quicksandTop.Size.Y / 2 then
		quicksandTop = part
	end
end
local sandSpot = Vector3.new(208, 144, -2774)
local safePart = realWorkspace["Stage 5"].Folder:FindFirstChildWhichIsA("Model"):FindFirstChildWhichIsA("BasePart", true)

local sinker = makePlayer(sandSpot)
raycastResult = { Instance = quicksandTop }
step(24)
assert(sinker.Humanoid.Health > 0 and sinker:GetAttribute("World3QuicksandSink") > 0.9, "2.4 s on quicksand: still alive, nearly sunk")
step(2)
assert(sinker.Humanoid.Health == 0 and sinker:GetAttribute("World3LastHazard") == "Quicksand", "Past 2.5 s on quicksand, the player sinks")
table.clear(players)

local hopper = makePlayer(sandSpot)
step(20)
raycastResult = { Instance = safePart }
step(1)
assert(hopper:GetAttribute("World3QuicksandSink") == 0, "Stepping onto safe ground resets the sinking")
raycastResult = { Instance = quicksandTop }
step(20)
raycastResult = nil
step(10)
assert(hopper.Humanoid.Health > 0, "In the air, the sinking pauses")
raycastResult = { Instance = quicksandTop }
step(6)
assert(hopper.Humanoid.Health == 0, "but does not reset: hopping in place still sinks")
table.clear(players)

-- The void.
raycastResult = nil
local parkour = makePlayer(Vector3.new(286, 55, -3600))
local fallen = makePlayer(Vector3.new(286, 20, -3600))
local lobby = makePlayer(Vector3.new(265, 98, 521))
local lobbyFall = makePlayer(Vector3.new(265, 50, 521))
local graced = makePlayer(Vector3.new(286, 20, -3600))
graced:SetAttribute("StageTeleportArrivalGraceUntil", os.clock() + 60)
step(1)
assert(parkour.Humanoid.Health > 0, "Standing on Stage 6's parkour (y 55) is alive")
assert(fallen.Humanoid.Health == 0 and fallen:GetAttribute("World3LastHazard") == "Void", "Below Stage 6's void height, the player dies")
assert(lobby.Humanoid.Health > 0 and lobbyFall.Humanoid.Health == 0, "The lobby has its own void height")
assert(graced.Humanoid.Health > 0, "A player just teleported is never killed")
table.clear(players)

-- Cactus.
local pricked = makePlayer(Vector3.new(240, 97, 250))
local function body(name, owner)
	return { Name = name, Parent = owner.Character, IsA = function(_, class)
		return class == "BasePart"
	end }
end
cactusTouched[1]:Fire(body("Handle", pricked))
cactusTouched[1]:Fire(body("HumanoidRootPart", pricked))
assert(pricked.Humanoid.Health > 0, "A hat or the invisible root touching a cactus does not kill")
cactusTouched[1]:Fire(body("Left Leg", pricked))
assert(pricked.Humanoid.Health == 0 and pricked:GetAttribute("World3LastHazard") == "Cactus", "A leg touching a cactus kills")
table.clear(players)

-- Stage 10's lasers and void layer.
for index, part in Server.Layout.LaserParts do
	assert(part.CanCollide == false and part.Attributes.World3LaserIndex == index and part.Tag == "World3Laser", "Laser " .. index .. " is a beam (passable), numbered and tagged for the clients")
	-- 2026-09-21: the bars turn on the clients only; the server publishes where each was built.
	assert(part.Attributes.World3LaserHome == Server.Layout.LaserHomes[index], "Laser " .. index .. "'s home is published for the clients")
end
local laserSettings = Motion.Laser
local laserOff = laserSettings.Period - laserSettings.OnSeconds - laserSettings.WarnSeconds
-- Laser 1's beam (the other runs half a cycle apart, somewhere else).
local beam = Server.Layout.LaserBoxes[1]
local beamX, beamZ = (beam.MinX + beam.MaxX) / 2, (beam.MinZ + beam.MaxZ) / 2
local zapped = makePlayer(Vector3.new(beamX, beam.MinY + 0.5, beamZ))
serverClock = 5000 + 0.5 -- laser 1 off
laserTouched[1]:Fire(body("Right Arm", zapped))
assert(zapped.Humanoid.Health > 0, "Walking through a laser while it is off is safe")
serverClock = 5000 + laserOff + 0.5 -- warning
laserTouched[1]:Fire(body("Right Arm", zapped))
step(1)
assert(zapped.Humanoid.Health > 0, "...and while it flickers its warning")
serverClock = 5000 + laserOff + laserSettings.WarnSeconds + 0.6 -- on
laserTouched[1]:Fire(body("Handle", zapped))
assert(zapped.Humanoid.Health > 0, "A hat touching a laser does not kill")
laserTouched[1]:Fire(body("Right Arm", zapped))
assert(zapped.Humanoid.Health == 0 and zapped:GetAttribute("World3LastHazard") == "Laser", "A laser kills while it is on")
table.clear(players)
local standing = makePlayer(Vector3.new(beamX, beam.MinY + 0.5, beamZ))
local beside = makePlayer(Vector3.new(beamX, beam.MinY + 0.5, beamZ + 10))
local over = makePlayer(Vector3.new(beamX, beam.MaxY + 3.5, beamZ))
step(1)
assert(standing.Humanoid.Health == 0 and standing:GetAttribute("World3LastHazard") == "Laser", "Standing in the beam when it comes on dies")
assert(beside.Humanoid.Health > 0 and over.Humanoid.Health > 0, "...beside it or jumping over it does not")
table.clear(players)
-- The bar turns about its middle: the server kills by where it is now, not where it was built.
do
	local home = Server.Layout.LaserHomes[1]
	local now = serverClock - 5000
	local turnedAway = makePlayer(home * Vector3.new(40, 0, 0))
	local underTheBar = makePlayer(Motion.LaserPose(home, 1, now) * Vector3.new(40, 0, 0))
	step(1)
	assert(turnedAway.Humanoid.Health > 0, "Where the bar was built, 40 studs out, is safe once it has turned away")
	assert(underTheBar.Humanoid.Health == 0 and underTheBar:GetAttribute("World3LastHazard") == "Laser", "...and where it has turned to kills")
	for _, part in Server.Layout.LaserParts do
		assert(rawget(part, "CFrame") == nil, "The server never moves a laser (the clients turn them)")
	end
	table.clear(players)
end
serverClock = 5000
local sunkInVoid = makePlayer(Vector3.new(220, 26, -7600))
voidTouched[3]:Fire(body("Left Leg", sunkInVoid))
assert(sunkInVoid.Humanoid.Health == 0 and sunkInVoid:GetAttribute("World3LastHazard") == "Void", "Touching the void layer kills")
table.clear(players)
local onPlatform = makePlayer(Vector3.new(150, 129, -7635))
local belowCliffs = makePlayer(Vector3.new(150, 24, -7635))
local onLaserFloor = makePlayer(Vector3.new(180, 123.9, -8200))
local onLowestStone = makePlayer(Vector3.new(270, 120.65, -6770))
local onLedge = makePlayer(Vector3.new(275, 112.7, -7510))
step(1)
assert(onPlatform.Humanoid.Health > 0, "Standing on Stage 10's platforms is alive")
assert(onLaserFloor.Humanoid.Health > 0, "...on the laser floor between the beams too")
assert(onLowestStone.Humanoid.Health > 0, "...and on its lowest stepping stone")
assert(onLedge.Humanoid.Health == 0 and onLedge:GetAttribute("World3LastHazard") == "Void", "A fall onto a rock ledge under the route dies instead of leaving the player stuck")
assert(belowCliffs.Humanoid.Health == 0 and belowCliffs:GetAttribute("World3LastHazard") == "Void", "Below the void layer's top, a fall dies")
table.clear(players)

-- Self-hit reports.
local rolledOver = makePlayer(Vector3.new(245, 95, -151))
Server.OnSelfHit(rolledOver, "Tumbleweed", 1)
assert(rolledOver.Humanoid.Health == 0, "A player on Stage 2 hit by a tumbleweed dies")
local faker = makePlayer(Vector3.new(265, 98, 521))
Server.OnSelfHit(faker, "Tumbleweed", 1)
assert(faker.Humanoid.Health > 0, "A report from far away from that hazard is ignored")
for _, bad in { { "Tumbleweed", 99 }, { "Lava", 1 }, { "Serpent", 2 }, { "Cart", 1.5 } } do
	local someone = makePlayer(Vector3.new(245, 95, -151))
	Server.OnSelfHit(someone, bad[1], bad[2])
	assert(someone.Humanoid.Health > 0, "A report of a hazard that does not exist is ignored")
end
local dugout = serpent.Dugouts[2]
local hiding = makePlayer(Vector3.new(dugout.X, serpent.FloorY + 3, dugout.Z))
Server.OnSelfHit(hiding, "Serpent", 1)
assert(hiding.Humanoid.Health > 0, "A player inside a dugout cannot be killed by the serpent")
local caught = makePlayer(Vector3.new(centreX, serpent.FloorY + 3, middle))
Server.OnSelfHit(caught, "Serpent", 1)
assert(caught.Humanoid.Health == 0 and caught:GetAttribute("World3LastHazard") == "Serpent", "A player caught in the canyon dies")
local lane = layout.Client.Scorpions[4]
local stung = makePlayer(Vector3.new((lane.XFrom + lane.XTo) / 2, lane.FloorY + 3, lane.Z))
Server.OnSelfHit(stung, "Scorpion", 4)
assert(stung.Humanoid.Health == 0 and stung:GetAttribute("World3LastHazard") == "Scorpion", "A player stung on Stage 9 dies")
local liar = makePlayer(Vector3.new(265, 98, 521))
Server.OnSelfHit(liar, "Scorpion", 4)
assert(liar.Humanoid.Health > 0, "A scorpion report from the lobby is ignored")
local nobody = makePlayer(Vector3.new((lane.XFrom + lane.XTo) / 2, lane.FloorY + 3, lane.Z))
Server.OnSelfHit(nobody, "Scorpion", 99)
assert(nobody.Humanoid.Health > 0, "A scorpion that does not exist stings nobody")
-- Stage 10's floor sits in a "laserplatform" model: the run script's own death prediction
-- must not count it as a laser (stepping on it killed, 2026-09-18).
do
	local run = fs.readFile("src/common/StarterPlayer/StarterCharacterScripts/R15SpeedsterRun.client.luau")
	-- 2026-09-25 (Update 4, H6): the rule is Shared/HazardNames, shared with the server's judge.
	assert(string.find(run, "local isLethal = HazardNames.IsNamedLethalPart(hitPart)", 1, true), "The run script's lethal rule")
	local HazardNames = require("../src/common/ReplicatedStorage/Shared/HazardNames")
	local function isLethal(name, parentName, part)
		return HazardNames.IsNamedLethalPart({ Name = name, Parent = { Name = parentName }, FindFirstChild = part.FindFirstChild })
	end
	local plainPart = { FindFirstChild = function() return nil end }
	assert(not isLethal("part", "laserplatform", plainPart), "Stage 10's laser-platform floor is not deadly")
	assert(isLethal("laser", "laserplatform", plainPart), "...its laser beam is")
	assert(isLethal("part", "laser", plainPart), "...and so are the beams of a model called Laser")
	assert(isLethal("part", "void (script the kill)", plainPart) and isLethal("lava", "stage 1", plainPart), "Kill layers and lava still are")
	local client = fs.readFile("src/worlds/World3/StarterPlayer/StarterPlayerScripts/Gameplay/World3HazardsClient.client.luau")
	assert(string.find(client, 'CollectionService:GetInstanceAddedSignal("World3Laser"):Connect(addLaser)', 1, true), "The clients find the lasers as they stream in")
	assert(string.find(client, "local deadly = state == \"On\"\n\t\t\tif part.CanTouch ~= deadly then\n\t\t\t\tpart.CanTouch = deadly", 1, true), "...and a laser is only touchable while it is on")
end
print("PASS the server: quicksand after 2.5 s (safe ground resets, air pauses), void per stage (Stage 10's just under its route), cactus, lasers only while on and void layer by body parts, self-hit reports only where the hazard runs")

-- 4. Nothing left behind: per-player state is dropped when a player leaves; the deadly
-- parts' connections belong to the map, not to players; the client forgets platforms
-- that leave (streaming) and builds each hazard once.
local serverSource = fs.readFile(SERVER)
assert(string.find(serverSource, "Players.PlayerRemoving:Connect(function(player)\n\tlastSelfHitAt[player] = nil\n\tsunk[player] = nil\n\tshownSink[player] = nil", 1, true),
	"The server drops every player's state when they leave")
local clientSource = fs.readFile("src/worlds/World3/StarterPlayer/StarterPlayerScripts/Gameplay/World3HazardsClient.client.luau")
assert(string.find(clientSource, "Workspace.DescendantRemoving:Connect(function(descendant)\n\tcollapsing[descendant] = nil", 1, true),
	"The client forgets platforms that stream out")
assert(string.find(clientSource, 'tonumber(platform:GetAttribute("World3CollapseShake"))', 1, true)
	and string.find(clientSource, 'tonumber(platform:GetAttribute("World3CollapseBack"))', 1, true), "The client uses each platform's own timing")
assert(string.find(clientSource, "removeSandstorm()", 1, true) and string.find(clientSource, "Lighting.FogEnd = sandstorm.Base.FogEnd", 1, true),
	"The sandstorm removes itself and puts the fog back")
print("PASS nothing left behind: player state dropped on leave, map-owned connections, platforms forgotten when they stream out, the fog put back")

-- 5. The client's drawing, run for real on the place's models: the serpent is the green
-- Snake grown along its body (fangs leading), the scorpions walk their lanes facing where
-- they go, and the sandstorm comes on Stage 10 and leaves the fog as it found it.
do
	local clientSource = fs.readFile("src/worlds/World3/StarterPlayer/StarterPlayerScripts/Gameplay/World3HazardsClient.client.luau")
	local function between(first, last)
		local a = assert(string.find(clientSource, first, 1, true), "client chunk " .. first)
		local b = assert(string.find(clientSource, last, a, true), "client chunk end " .. last)
		return string.sub(clientSource, a, b - 1)
	end
	-- Lune's CFrame.lookAt gets most directions wrong; the code gets Roblox's.
	local function lookAt(at, target)
		local look = (target - at).Unit
		local up = Vector3.new(0, 1, 0)
		if math.abs(look:Dot(up)) > 0.9999 then
			up = Vector3.new(0, 0, 1)
		end
		local right = look:Cross(up).Unit
		return roblox.CFrame.fromMatrix(at, right, right:Cross(look), -look)
	end
	local clientTemplates = roblox.Instance.new("Folder")
	for _, name in { "Snake", "Scorpion" } do
		templates[name]:Clone().Parent = clientTemplates
	end
	local visuals = roblox.Instance.new("Folder")
	local lighting = roblox.Instance.new("Lighting")
	lighting.FogStart, lighting.FogEnd, lighting.FogColor = 0, 100000, roblox.Color3.new(0.75, 0.75, 0.75)
	local camera = roblox.Instance.new("Camera")
	local published = serde.decode("json", layoutFolder:GetAttribute("Layout"))
	local function farAway(model)
		for _, piece in model:GetDescendants() do
			if piece:IsA("BasePart") then
				piece.CFrame = roblox.CFrame.new(0, -1000, 0)
			end
		end
	end
	local clientEnv = environment({
		CFrame = setmetatable({ lookAt = lookAt }, { __index = roblox.CFrame }),
		layout = published,
		folder = { WaitForChild = function(_, name)
			return clientTemplates:FindFirstChild(name)
		end },
		visuals = visuals,
		Motion = Motion,
		SERPENT_SEGMENTS = Motion.SerpentPoints,
		SNAKE_SCALE = assert(tonumber(string.match(clientSource, "local SNAKE_SCALE = ([%d%.]+)"))),
		SNAKE_TAPER = assert(tonumber(string.match(clientSource, "local SNAKE_TAPER = ([%d%.]+)"))),
		SCORPION_FACES_MINUS_Z = true,
		DRAW_DISTANCE = 700,
		LOW_POWER = false,
		hide = farAway,
		near = function(position, root)
			return root and (position - root.Position).Magnitude <= 700
		end,
		part = function(parent, name, shape, size, color)
			local piece = roblox.Instance.new("Part")
			piece.Name, piece.Shape, piece.Size, piece.Color, piece.Anchored = name, shape, size, color, true
			piece.Parent = parent
			return piece
		end,
		Workspace = {
			CurrentCamera = camera,
			GetAttribute = function()
				return nil
			end,
			GetServerTimeNow = function()
				return 5000
			end,
		},
		game = { GetService = function(_, name)
			assert(name == "Lighting", name)
			return lighting
		end },
	})
	local chunk = between("local serpent = nil", "----------------------------------------------------------------------\n-- Drawing")
		.. between("local function drawSerpent", "----------------------------------------------------------------------\n-- Getting hit")
		.. between("local SANDSTORM = {", "----------------------------------------------------------------------\n-- Stage 10's lasers")
		.. "\nreturn serpent, scorpions, drawSerpent, drawScorpions, updateSandstorm, sandstorm"
	local built, scorpionsDrawn, drawSerpent, drawScorpions, updateSandstorm, sandstorm = luau.load(chunk, { environment = clientEnv })()

	-- Stage 10's lasers as a client draws them: a ghost while off, a flicker while warning,
	-- solid red while on, and touchable only then.
	do
		local beams = {}
		for index = 1, 2 do
			local beam = roblox.Instance.new("Part")
			beam.Name = "laser"
			beam.CanCollide = true
			beam:SetAttribute("World3LaserIndex", index)
			beam.Parent = visuals
			beams[index] = beam
		end
		local laserEnv = environment({
			Motion = Motion,
			CollectionService = {
				GetTagged = function(_, tag)
					assert(tag == "World3Laser", tag)
					return beams
				end,
				GetInstanceAddedSignal = function() return signal() end,
				GetInstanceRemovedSignal = function() return signal() end,
			},
		})
		local drawLasers = luau.load(between("local LASER_LOOK = {", "----------------------------------------------------------------------\n-- Every frame") .. "\nreturn drawLasers", { environment = laserEnv })()
		local settings = Motion.Laser
		local offSeconds = settings.Period - settings.OnSeconds - settings.WarnSeconds
		assert(not beams[1].CanCollide and beams[1].Material == roblox.Enum.Material.Neon, "A glowing beam nobody bumps into")
		drawLasers(0.5)
		assert(beams[1].Transparency > 0.8 and beams[1].CanTouch == false, "Off: a faint ghost, untouchable")
		local looks = {}
		for step = 0, 20 do
			drawLasers(offSeconds + step * settings.WarnSeconds / 21)
			looks[beams[1].Transparency] = true
			assert(beams[1].CanTouch == false, "Warning: still untouchable")
		end
		local count = 0
		for _ in looks do
			count += 1
		end
		assert(count >= 2, "Warning: it flickers")
		drawLasers(offSeconds + settings.WarnSeconds + 0.5)
		assert(beams[1].Transparency == 0 and beams[1].CanTouch == true and beams[1].Color.R > 0.9 and beams[1].Color.G < 0.3, "On: solid red, and deadly")
		assert(beams[2].CanTouch == false, "The other laser is half a cycle behind: off right now")
		print("PASS laser drawing: a ghost while off, a flicker while warning, solid red and touchable only while on")
	end

	-- The serpent: the Snake's head, body pieces and tail, grown, green, with eyes and fangs.
	local scale = clientEnv.SNAKE_SCALE
	assert(#built.Pieces == Motion.SerpentPoints, "One piece of the Snake at every point of the serpent's body")
	assert(built.Pieces[1].Part.Name == "Head" and built.Pieces[#built.Pieces].Part.Name == "Tail", "The Snake's head leads and its tail follows")
	assert((built.Pieces[1].Part.Size - templates.Snake.Head.Size * scale).Magnitude < 1e-3, "The head is the model's, grown " .. scale .. " times")
	assert(#built.Extras == 4, "Its eyes and fangs ride on the head")
	for _, entry in built.Pieces do
		local colour = entry.Part.Color
		assert(colour.G > colour.R and colour.G > colour.B, "Every piece of the serpent is green")
		assert(entry.Part.Anchored and not entry.Part.CanCollide and not entry.Part.CanTouch, "...and touches nothing (the motion decides the hits)")
	end
	local passingAt = serpentTime(middle)
	local root = { Position = Vector3.new(centreX, serpent.FloorY + 3, middle) }
	drawSerpent(passingAt, root)
	local points = Motion.SerpentBody(serpent, passingAt, Motion.SerpentPoints)
	for index, entry in built.Pieces do
		if points[index] then
			assert((entry.Part.CFrame.Position - points[index]).Magnitude < 1e-3, "Piece " .. index .. " sits on the serpent's body")
		end
	end
	local head = built.Pieces[1].Part.CFrame.Position
	local forward = (points[1] - points[2]).Unit
	for _, extra in built.Extras do
		assert((extra.Part.CFrame.Position - head).Magnitude < built.Pieces[1].Part.Size.Magnitude, extra.Part.Name .. " is on the head")
		if string.find(extra.Part.Name, "Fang", 1, true) then
			assert((extra.Part.CFrame.Position - head):Dot(forward) > 0, "The fangs lead, as in the model")
		end
	end
	drawSerpent(serpent.Period - 0.5, root)
	assert(built.Pieces[1].Part.CFrame.Position.Y < -500, "Resting, the serpent is out of sight")

	-- The scorpions: the modeller's mesh at the lane's size, walking where the motion says.
	assert(#scorpionsDrawn == #published.Scorpions, "One scorpion per lane")
	for index, entry in scorpionsDrawn do
		local lane = entry.Lane
		assert((entry.Part.Size - Vector3.new(lane.Width, lane.Height, lane.Length)).Magnitude < 1e-3, "Scorpion " .. index .. " is the lane's size")
		for _, t in { 1.3, 4.1, 9.7 } do
			local centre, facing, turning = Motion.ScorpionPose(lane, t)
			drawScorpions(t, { Position = centre })
			assert((entry.Part.CFrame.Position - centre).Magnitude < 1e-3, "Scorpion " .. index .. " is where it walks")
			if turning == 0 then
				assert(entry.Part.CFrame.LookVector:Dot(facing) > 0.99, "...facing the way it walks")
			end
		end
	end

	-- The sandstorm: on Stage 10 it comes in; off it, it goes and the fog is as it was.
	local onStage10 = { Position = Stages.GetStageReferencePosition(10) + Vector3.new(0, 3, 0) }
	for _ = 1, 20 do
		updateSandstorm(0.1, onStage10)
	end
	assert(sandstorm.Weight == 1 and sandstorm.Parts, "On Stage 10 the sandstorm blows")
	for _, emitter in sandstorm.Parts.Emitters do
		assert(emitter.Rate > 0 and emitter.Rate == emitter:GetAttribute("FullRate"), "...sand in the air")
	end
	assert(lighting.FogEnd <= 260 and lighting:FindFirstChild("World3SandstormTint"), "...the fog closes in, dusty and warm")
	for _ = 1, 20 do
		updateSandstorm(0.1, { Position = Stages.GetStageReferencePosition(9) })
	end
	assert(sandstorm.Weight == 0 and sandstorm.Parts == nil and not lighting:FindFirstChild("World3SandstormTint"), "Off Stage 10 the sandstorm is gone")
	assert(lighting.FogEnd == 100000 and lighting.FogStart == 0, "...and the fog is as it was")
	print("PASS the client draws the green Snake along the serpent (fangs leading), the scorpions on their lanes, and the sandstorm on Stage 10 only")
end
