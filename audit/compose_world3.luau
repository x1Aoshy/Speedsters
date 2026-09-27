-- compose_world3.luau
-- Builds World 3's immutable input place (audit/world3_base/input.rbxl) from two pinned
-- files, the way World 1 and World 2 have theirs:
--
--   * World 2's input place gives everything that is not the map: UI, ReplicatedStorage,
--     ServerStorage, StarterPlayer, every shared script, game settings (R6, collision
--     groups). World 2's own scripts outside the map are removed.
--   * "1+ Desert map final.rbxl" gives the map (Stages 1-10 and the End): its Workspace and
--     its Lighting look, cleaned of the backdoor in the lobby portal, the tycoon
--     MoneyScripts in Stage 7 and the empty "Asset Pack Stud" folder.
--   * The modeller's Snake (Stage 8's serpent) and Scorpion (Stage 9) become hazard
--     templates in ServerStorage.World3HazardTemplates: the Snake's free-model AI script,
--     joints and lift force go (World3Hazards moves it), and it turns desert green with
--     its white fangs kept.
--   * The End gets a "Winstage2" marker (the finish's x2 pad) beside its "Winstage1".
--   * The desert lobby gets World 2's starter treadmill ("Golden", renamed "Basic"),
--     scaled like the desert's copies of World 2's treadmills and set in the free slot
--     at the start of the treadmill row, so every player has a treadmill with no lock.
--   * The lobby gets World 2's group reward chest ("Rank Rewards"), beside the spawn.
--   * Workspace and ReplicatedStorage carry PlaceWorldNumber = 3.
--
-- It also writes audit/world3_base/scripts.json, where every script in the new place came
-- from, for audit/register_world3.py to turn into World 3's manifest rows.
--
--   lune run audit/compose_world3.luau
--
-- A new desert map (the modeller's meshes) means a new pinned hash below: check the file,
-- update DESERT_SHA256, compose again, register again.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3

local DESERT_MAP = "1+ Desert map final.rbxl"
local DESERT_SHA256 = "bcccc84855dec18b265018894bd82573e5fc9899696e3d6426e9592e279425b3"
local OUTPUT_DIR = "audit/world3_base"

local manifest = serde.decode("json", fs.readFile("src/manifest.json"))
local world2 = manifest.worlds.World2
local world2Raw = fs.readFile(world2.input)
assert(serde.hash("sha256", world2Raw) == world2.inputSha256, "World 2's input place changed")
local desertRaw = fs.readFile(DESERT_MAP)
assert(serde.hash("sha256", desertRaw) == DESERT_SHA256, "The desert map changed; check it and update DESERT_SHA256")

local base = roblox.deserializePlace(world2Raw)
local desert = roblox.deserializePlace(desertRaw)
local report = {}
local function note(text)
	table.insert(report, text)
	print(text)
end

----------------------------------------------------------------------
-- 1. World 2's scripts, and which of them World 3 keeps
----------------------------------------------------------------------
local original = base:GetDescendants()
local world2RowOf = {}
for _, row in world2.scripts do
	if not row.added then
		local instance = original[row.id]
		assert(instance and instance.ClassName == row.class, "World 2 row does not match its input: " .. row.path)
		world2RowOf[instance] = row
	end
end

local removedWorld2 = 0
for instance, row in world2RowOf do
	if string.sub(row.source, 1, 18) == "src/worlds/World2/" and row.segments[1] ~= "Workspace" then
		instance:Destroy()
		removedWorld2 += 1
	end
end
note("Removed " .. removedWorld2 .. " World 2 scripts outside the map")

----------------------------------------------------------------------
-- 2. The map: World 2's Workspace out, except what every world shares
----------------------------------------------------------------------
local KEEP_FROM_WORLD2 = {
	["Camera|Camera"] = true,
	["Terrain|Terrain"] = true,
	["BestRunAnimR6|Folder"] = true, -- holds a shared script
	["Error|Sound"] = true,
	["Keyboard Click|Sound"] = true,
	["ui-pop-sound-316482|Sound"] = true,
	["winner!|Sound"] = true,
}
local workspace = base:GetService("Workspace")
-- World 2's starter treadmill and its Diamond (to measure the desert's copy against),
-- kept before World 2's map goes.
local world2Admin = workspace:FindFirstChild("Admin")
local starterTreadmill = assert(world2Admin and world2Admin:FindFirstChild("Golden"), "World 2's Golden treadmill is missing"):Clone()
local world2Diamond = assert(world2Admin:FindFirstChild("Diamond"), "World 2's Diamond treadmill is missing")
local function beltOf(treadmill)
	local best, area = nil, 0
	for _, part in assert(treadmill:FindFirstChild("Treadmil", true), "no Treadmil in " .. treadmill.Name):GetDescendants() do
		if part:IsA("BasePart") and part.Size.X * part.Size.Z > area then
			best, area = part, part.Size.X * part.Size.Z
		end
	end
	return best
end
local world2Belt = beltOf(world2Diamond)
local world2BeltCFrame, world2BeltSize = world2Belt.CFrame, world2Belt.Size
-- World 2's group reward: the "Rank Rewards" chest on its pad, which RankReward and
-- RankRewardPanel find by name, and where it stands from World 2's spawn.
local groupReward = assert(workspace:FindFirstChild("Rank Rewards", true), "World 2's Rank Rewards chest is missing"):Clone()
local world2RewardPad = assert(groupReward:FindFirstChild("Pad"), "World 2's Rank Rewards has no Pad")
local world2Spawn = assert(workspace:FindFirstChild("Spawn"), "World 2's spawn is missing")
local world2RewardPadCFrame, world2SpawnPosition = world2RewardPad.CFrame, world2Spawn.CFrame.Position
local removedMap = 0
for _, child in workspace:GetChildren() do
	if not KEEP_FROM_WORLD2[child.Name .. "|" .. child.ClassName] then
		child:Destroy()
		removedMap += 1
	end
end
note("Removed " .. removedMap .. " World 2 map objects from Workspace")

----------------------------------------------------------------------
-- 3. The desert map, cleaned
----------------------------------------------------------------------
local desertWorkspace = desert:GetService("Workspace")

-- The backdoor: scripts that require() code by an asset id hidden in NumberPose values,
-- silent in Studio. Its whole subtree goes; the portal's beams and particles stay.
local portalEffect = desertWorkspace.Lobby["world 2 portal"].Model
local backdoor = portalEffect:FindFirstChild("PoseTexture")
assert(backdoor and backdoor:IsA("Script"), "The portal backdoor is not where it was; inspect the map again")
local hidden = 0
for _, descendant in backdoor:GetDescendants() do
	if descendant.ClassName == "NumberPose" then
		hidden += 1
	end
end
assert(hidden > 0, "The portal script no longer looks like the known backdoor; inspect it before composing")
backdoor:Destroy()
note("Removed the portal backdoor (PoseTexture, " .. hidden .. " hidden asset ids)")

local moneyScripts = 0
for _, descendant in desertWorkspace["Stage 7"]:GetDescendants() do
	if descendant:IsA("LuaSourceContainer") and descendant.Name == "MoneyScript" then
		descendant:Destroy()
		moneyScripts += 1
	end
end
assert(moneyScripts == 14, "Expected 14 tycoon MoneyScripts in Stage 7, found " .. moneyScripts)
note("Removed " .. moneyScripts .. " tycoon MoneyScripts from Stage 7")

local assetPack = desertWorkspace:FindFirstChild("Asset Pack Stud")
assert(assetPack, "Asset Pack Stud folder missing")
assetPack:Destroy()
note("Removed the Asset Pack Stud folder")

-- The hazard templates: the Snake and the Scorpion leave the Workspace (the Snake would
-- otherwise lie at the map's origin running its own AI) for ServerStorage, anchored and
-- touching nothing; World3Hazards hands them to the clients, which draw the hazards.
local SNAKE_HEAD = roblox.Color3.fromRGB(74, 116, 44)
local SNAKE_SCALES = { roblox.Color3.fromRGB(96, 142, 54), roblox.Color3.fromRGB(118, 164, 66) }
local SNAKE_TAIL = roblox.Color3.fromRGB(104, 150, 58)
-- A new folder gets an explicit UniqueId (as build_core's new instances do): a zero id is
-- filled in by the serializer, and the build's authored-graph check would see it change.
local templates = roblox.deserializeModel('<roblox version="4"><Item class="Folder" referent="0"><Properties><UniqueId name="UniqueId">'
	.. "1" .. string.sub(serde.hash("sha256", "world3-compose:World3HazardTemplates"), 2, 32)
	.. "</UniqueId></Properties></Item></roblox>")[1]
templates.Name = "World3HazardTemplates"
local function inert(parts)
	for _, descendant in parts do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.CastShadow = false
		end
	end
end
local snake = assert(desertWorkspace:FindFirstChild("Snake"), "The Snake model is missing from the map")
local snakeBrain = snake:FindFirstChild("Main")
assert(snakeBrain and snakeBrain:IsA("Script") and string.find(snakeBrain.Source, "bodyVelocity", 1, true)
	and not string.find(snakeBrain.Source, "require"), "The Snake's script is not the known free-model AI; inspect it")
snakeBrain:Destroy()
local stripped = 0
for _, descendant in snake:GetDescendants() do
	if descendant:IsA("Constraint") or descendant:IsA("WeldConstraint") or descendant:IsA("BodyMover") then
		descendant:Destroy()
		stripped += 1
	end
end
inert(snake:GetDescendants())
local torso = 0
for _, name in { "Torso1", "Torso2", "Torso3", "Torso4", "Torso5" } do
	torso += 1
	assert(snake:FindFirstChild(name), "The Snake has no " .. name).Color = SNAKE_SCALES[(torso - 1) % 2 + 1]
end
assert(snake:FindFirstChild("Head"), "The Snake has no Head").Color = SNAKE_HEAD
assert(snake:FindFirstChild("Tail"), "The Snake has no Tail").Color = SNAKE_TAIL
for _, name in { "LeftFang", "RightFang" } do
	assert(snake:FindFirstChild(name), "The Snake has no " .. name).Color = roblox.Color3.fromRGB(248, 248, 248)
end
for _, descendant in snake:GetDescendants() do
	assert(not descendant:IsA("LuaSourceContainer"), "The Snake template carries no script")
end
snake.Parent = templates
local scorpion = assert(desertWorkspace:FindFirstChild("Scorpion"), "The Scorpion mesh is missing from the map")
assert(scorpion:IsA("MeshPart") and #scorpion:GetDescendants() == 0, "The Scorpion is one mesh part")
inert({ scorpion })
-- It came in at 1 x 1 x 1: the mesh's own proportions, 16 studs long.
local SCORPION_LENGTH = 16
local natural = scorpion.InitialSize
assert(natural.Z > 0, "The Scorpion mesh has no size")
scorpion.Size = natural * (SCORPION_LENGTH / natural.Z)
scorpion.Parent = templates
templates.Parent = base:GetService("ServerStorage")
note(string.format("Moved the Snake (green, its AI script and %d joints and forces removed) and the Scorpion (%.1f x %.1f x %.1f) to ServerStorage.World3HazardTemplates", stripped, scorpion.Size.X, scorpion.Size.Y, scorpion.Size.Z))

-- The finish: the End's "Winstage1" is its Win pad marker (World 1's naming). Its x2 pad
-- marker, "Winstage2", goes beside it on the End's floor, on the first side that is clear.
local finishArea = assert(desertWorkspace:FindFirstChild("End"), "The End folder is missing")
local finalWin = assert(finishArea:FindFirstChild("Winstage1"), "The End has no Winstage1")
assert(not finishArea:FindFirstChild("Winstage2"), "The End already has a Winstage2; drop this step")
local function box(part)
	local cframe, half = part.CFrame, part.Size / 2
	local extent = Vector3.new(
		math.abs(cframe.RightVector.X) * half.X + math.abs(cframe.UpVector.X) * half.Y + math.abs(cframe.LookVector.X) * half.Z,
		math.abs(cframe.RightVector.Y) * half.X + math.abs(cframe.UpVector.Y) * half.Y + math.abs(cframe.LookVector.Y) * half.Z,
		math.abs(cframe.RightVector.Z) * half.X + math.abs(cframe.UpVector.Z) * half.Y + math.abs(cframe.LookVector.Z) * half.Z
	)
	return cframe.Position - extent, cframe.Position + extent
end
local winLow, winHigh = box(finalWin)
local finishFloor, floorTop = nil, -math.huge
for _, part in finishArea:GetDescendants() do
	if part:IsA("BasePart") and part ~= finalWin then
		local low, high = box(part)
		local centre = finalWin.CFrame.Position
		if centre.X > low.X and centre.X < high.X and centre.Z > low.Z and centre.Z < high.Z
			and high.Y >= winHigh.Y and part.Size.X * part.Size.Z > 10000 and high.Y > floorTop
		then
			finishFloor, floorTop = part, high.Y
		end
	end
end
assert(finishFloor, "No floor under the End's Winstage1")
local function clear(centre)
	local half = (winHigh - winLow) / 2 + Vector3.new(2, 0, 2)
	local low = Vector3.new(centre.X - half.X, floorTop + 0.05, centre.Z - half.Z)
	local high = Vector3.new(centre.X + half.X, floorTop + 10, centre.Z + half.Z)
	for _, part in desertWorkspace:GetDescendants() do
		if part:IsA("BasePart") and part ~= finishFloor and part ~= finalWin then
			local partLow, partHigh = box(part)
			if partLow.X < high.X and partHigh.X > low.X and partLow.Y < high.Y and partHigh.Y > low.Y and partLow.Z < high.Z and partHigh.Z > low.Z then
				return false
			end
		end
	end
	return true
end
local finalX2 = nil
for _, offset in { Vector3.new(-18, 0, 0), Vector3.new(18, 0, 0), Vector3.new(0, 0, -18), Vector3.new(0, 0, 18), Vector3.new(-26, 0, 0), Vector3.new(26, 0, 0) } do
	local centre = finalWin.CFrame.Position + offset
	if clear(centre) then
		finalX2 = finalWin:Clone()
		finalX2.Name = "Winstage2"
		finalX2.CFrame = finalWin.CFrame + offset
		finalX2.Parent = finishArea
		note(string.format("Added the finish's x2 marker Winstage2 at (%.1f, %.1f), beside Winstage1", centre.X, centre.Z))
		break
	end
end
assert(finalX2, "No clear spot beside the End's Winstage1 for its x2 pad")

-- Nothing that loads outside code may remain anywhere in the map.
for _, descendant in desertWorkspace:GetDescendants() do
	assert(descendant.ClassName ~= "NumberPose" or descendant.Value < 1e6, "Asset id hidden in " .. descendant:GetFullName())
	if descendant:IsA("LuaSourceContainer") then
		local source = descendant.Source
		assert(not string.find(source, "require%s*%("), "A map script requires a module: " .. descendant:GetFullName())
		assert(not string.find(source, "getfenv") and not string.find(source, "loadstring"), "Suspicious map script: " .. descendant:GetFullName())
	end
end

local movedMap = 0
for _, child in desertWorkspace:GetChildren() do
	if child.ClassName ~= "Camera" and child.ClassName ~= "Terrain" then
		child.Parent = workspace
		movedMap += 1
	end
end
note("Moved " .. movedMap .. " desert map objects into Workspace")

-- The basic treadmill. The desert's treadmills are World 2's, scaled up and turned; the
-- same scale and turn, measured on Diamond's belt, brings World 2's starter over. It is
-- then slid along the row into the gap between the area's edge and Diamond.
local lobby = workspace.Lobby
local desertBelt = beltOf(lobby.Diamond)
local scale = desertBelt.Size.X / world2BeltSize.X
local starterParts = {}
for _, part in starterTreadmill:GetDescendants() do
	if part:IsA("BasePart") then
		local relative = world2BeltCFrame:Inverse() * part.CFrame
		part.CFrame = desertBelt.CFrame * (CFrame.new(relative.Position * scale) * relative.Rotation)
		part.Size = part.Size * scale
		table.insert(starterParts, part)
	end
end
local function zRange(parts)
	local low, high = math.huge, -math.huge
	for _, part in parts do
		local cframe, half = part.CFrame, part.Size / 2
		local extent = math.abs(cframe.RightVector.Z) * half.X + math.abs(cframe.UpVector.Z) * half.Y + math.abs(cframe.LookVector.Z) * half.Z
		low, high = math.min(low, cframe.Position.Z - extent), math.max(high, cframe.Position.Z + extent)
	end
	return low, high
end
local areaFloor = lobby.Treadmillarea["floor for spawn"]:FindFirstChildWhichIsA("BasePart")
local floorLow = zRange({ areaFloor })
local diamondParts = {}
for _, part in lobby.Diamond:FindFirstChild("Treadmil", true):GetDescendants() do
	if part:IsA("BasePart") then
		table.insert(diamondParts, part)
	end
end
local diamondLow = zRange(diamondParts)
local starterLow, starterHigh = zRange(starterParts)
local slotLow, slotHigh = floorLow + 1.5, diamondLow - 3
assert(starterHigh - starterLow <= slotHigh - slotLow, "The basic treadmill does not fit before Diamond")
local shift = (slotLow + slotHigh) / 2 - (starterLow + starterHigh) / 2
for _, part in starterParts do
	part.CFrame = part.CFrame + Vector3.new(0, 0, shift)
end
pcall(function()
	starterTreadmill.WorldPivot = CFrame.new(0, 0, shift) * desertBelt.CFrame * (world2BeltCFrame:Inverse() * starterTreadmill.WorldPivot)
end)
starterTreadmill.Name = "Basic"
starterTreadmill.Parent = lobby
note(string.format("Added the Basic treadmill to the lobby (World 2's Golden x%.2f, z %.1f to %.1f, before Diamond at %.1f)",
	scale, starterLow + shift, starterHigh + shift, diamondLow))

-- The group reward chest, in the open sand north of the leaderboards (2026-09-18: beside
-- the spawn it stood in front of the leaderboards and the AFK Zone), clear of the way to the
-- stages, turned to the spawn the way World 2's is, its pad on the lobby floor.
local GROUP_REWARD_PAD_X, GROUP_REWARD_PAD_Z = 180, 385
local function facingSpawn(position, spawnPosition)
	local direction = ((spawnPosition - position) * Vector3.new(1, 0, 1)).Unit
	return CFrame.fromMatrix(position, Vector3.new(-direction.Z, 0, direction.X), Vector3.new(0, 1, 0))
end
local lobbyFloorTop = -math.huge
for _, part in lobby:GetChildren() do
	if part:IsA("BasePart") and part.CFrame.UpVector.Y > 0.99 then
		local offset = part.CFrame:PointToObjectSpace(Vector3.new(GROUP_REWARD_PAD_X, part.CFrame.Position.Y, GROUP_REWARD_PAD_Z))
		local top = part.CFrame.Position.Y + part.Size.Y / 2
		if math.abs(offset.X) <= part.Size.X / 2 and math.abs(offset.Z) <= part.Size.Z / 2 and top < 100 then
			lobbyFloorTop = math.max(lobbyFloorTop, top)
		end
	end
end
assert(lobbyFloorTop > 90, "No lobby floor under the group reward chest")
for _, descendant in groupReward:GetDescendants() do
	assert(not descendant:IsA("LuaSourceContainer"), "World 2's Rank Rewards carries a script")
end
local rewardMove = facingSpawn(Vector3.new(GROUP_REWARD_PAD_X, lobbyFloorTop + world2RewardPad.Size.Y / 2, GROUP_REWARD_PAD_Z), lobby.SpawnLocation.CFrame.Position)
	* facingSpawn(world2RewardPadCFrame.Position, world2SpawnPosition):Inverse()
for _, part in groupReward:GetDescendants() do
	if part:IsA("BasePart") then
		part.CFrame = rewardMove * part.CFrame
	end
end
pcall(function()
	groupReward.WorldPivot = rewardMove * groupReward.WorldPivot
end)
groupReward.Parent = lobby
note(string.format("Added World 2's group reward chest to the lobby (pad at %.1f, %.2f, %.1f, facing the spawn)",
	GROUP_REWARD_PAD_X, lobbyFloorTop + world2RewardPad.Size.Y / 2, GROUP_REWARD_PAD_Z))

-- The desert's lighting: its sky and effects, and the properties it sets.
local lighting = base:GetService("Lighting")
local desertLighting = desert:GetService("Lighting")
for _, child in lighting:GetChildren() do
	child:Destroy()
end
for _, child in desertLighting:GetChildren() do
	child.Parent = lighting
end
local database = roblox.getReflectionDatabase()
local copied = {}
local class = database:GetClass("Lighting")
local SKIP = { UniqueId = true, HistoryId = true, Name = true, Parent = true, SourceAssetId = true, Capabilities = true }
while class do
	for name in class.Properties do
		if not SKIP[name] then
			local ok, value = pcall(function()
				return desertLighting[name]
			end)
			local hadOk, had = pcall(function()
				return lighting[name]
			end)
			if ok and (not hadOk or tostring(had) ~= tostring(value)) then
				if pcall(function()
					lighting[name] = value
				end) then
					table.insert(copied, name)
				end
			end
		end
	end
	class = class.Superclass and database:GetClass(class.Superclass) or nil
end
table.sort(copied)
note("Lighting from the desert map: sky and effects, and " .. table.concat(copied, ", "))

----------------------------------------------------------------------
-- 4. World number
----------------------------------------------------------------------
workspace:SetAttribute("IsWorld2", nil)
workspace:SetAttribute("PlaceWorldNumber", 3)
base:GetService("ReplicatedStorage"):SetAttribute("PlaceWorldNumber", 3)
note("PlaceWorldNumber = 3 on Workspace and ReplicatedStorage")

----------------------------------------------------------------------
-- 5. Write the place, and where each of its scripts came from
----------------------------------------------------------------------
-- Scripts are matched between the tree in memory and the tree read back from the file by
-- the position of each object among its siblings, which serialization keeps.
local function siblingPath(instance)
	local path = {}
	local current = instance
	while current.Parent do
		local index = table.find(current.Parent:GetChildren(), current)
		table.insert(path, 1, index)
		current = current.Parent
	end
	return table.concat(path, ".")
end

local originByPath = {}
for _, descendant in base:GetDescendants() do
	if descendant:IsA("LuaSourceContainer") then
		local row = world2RowOf[descendant]
		originByPath[siblingPath(descendant)] = if row then { World2Id = row.id } else { Desert = true }
	end
end

local encoded = roblox.serializePlace(base)
fs.writeDir(OUTPUT_DIR)
fs.writeFile(OUTPUT_DIR .. "/input.rbxl", encoded)

local composed = roblox.deserializePlace(encoded)
local scripts = {}
local counts = { World2 = 0, Desert = 0 }
for id, descendant in composed:GetDescendants() do
	if descendant:IsA("LuaSourceContainer") then
		local origin = assert(originByPath[siblingPath(descendant)], "Unmatched script " .. descendant:GetFullName())
		local segments = {}
		local current = descendant
		while current.Parent do
			table.insert(segments, 1, current.Name)
			current = current.Parent
		end
		local entry = { id = id, class = descendant.ClassName, segments = segments }
		if origin.World2Id then
			entry.world2Id = origin.World2Id
			counts.World2 += 1
		else
			entry.desertSource = descendant.Source
			counts.Desert += 1
		end
		table.insert(scripts, entry)
	end
end
fs.writeFile(OUTPUT_DIR .. "/scripts.json", serde.encode("json", {
	inputSha256 = serde.hash("sha256", encoded),
	world2InputSha256 = world2.inputSha256,
	desertSha256 = DESERT_SHA256,
	report = report,
	scripts = scripts,
}, true))
print(string.format("PASS composed %s/input.rbxl | %d shared scripts from World 2, %d map scripts | sha256 %s",
	OUTPUT_DIR, counts.World2, counts.Desert, serde.hash("sha256", encoded)))
