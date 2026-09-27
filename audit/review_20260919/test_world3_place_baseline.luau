-- test_world3_place.luau
-- World 3 (Desert), step 2: the built place audit/review_20260919/World3.rbxl.
--
--   * Clean: no backdoor (hidden asset ids, map scripts that require code), no tycoon
--     MoneyScripts, no Asset Pack Stud.
--   * It says it is World 3, and Config reads that from the attribute, not the map.
--   * It runs the same shared game as World 2: every shared script World 2 has, the same
--     UI and assets, and none of World 2's own scripts.
--   * The desert course is intact, and the Stage teleport service is in place.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local manifest = serde.decode("json", fs.readFile("src/manifest.json"))
local world3 = manifest.worlds.World3
assert(world3 and world3.latestInput == "World3Update3.rbxl", "World 3 must be registered in src/manifest.json")
assert(serde.hash("sha256", fs.readFile(world3.input)) == world3.inputSha256, "World 3's input place must match its pinned hash")

local place = roblox.deserializePlace(fs.readFile("audit/review_20260919/World3.rbxl"))
local world2Place = roblox.deserializePlace(fs.readFile("audit/review_20260919/World2.rbxl"))
local workspace = place:GetService("Workspace")

-- 1. Clean.
local mapScripts = 0
local sharedInWorkspace = workspace:FindFirstChild("BestRunAnimR6")
for _, descendant in place:GetDescendants() do
	assert(descendant.ClassName ~= "NumberPose" or descendant.Value < 1e6, "Hidden asset id in " .. descendant:GetFullName())
	if descendant:IsA("LuaSourceContainer") then
		assert(descendant.Name ~= "MoneyScript", "Tycoon MoneyScript left in " .. descendant:GetFullName())
		assert(descendant.Name ~= "PoseTexture" and descendant.Name ~= "LightConfig", "Portal backdoor left in " .. descendant:GetFullName())
		assert(not string.find(descendant.Source, "getfenv") and not string.find(descendant.Source, "loadstring"),
			"Suspicious script " .. descendant:GetFullName())
		if descendant:IsDescendantOf(workspace) and not (sharedInWorkspace and descendant:IsDescendantOf(sharedInWorkspace)) then
			mapScripts += 1
			assert(not string.find(descendant.Source, "require%s*%("), "A map script requires a module: " .. descendant:GetFullName())
		end
	end
end
assert(workspace:FindFirstChild("Asset Pack Stud") == nil, "Asset Pack Stud must be gone")
assert(mapScripts == 7, "World 3's map keeps its 7 own scripts (lava, Stage 6's and Stage 10's conveyors, pyramid seat), found " .. mapScripts)
-- The final map's Snake came with a free-model AI script; only its look is kept.
assert(workspace:FindFirstChild("Snake") == nil and workspace:FindFirstChild("Scorpion") == nil, "The Snake and Scorpion are templates, not in the Workspace")
local templates = place:GetService("ServerStorage"):FindFirstChild("World3HazardTemplates")
assert(templates and templates:FindFirstChild("Snake") and templates:FindFirstChild("Scorpion"), "The Snake and Scorpion wait in ServerStorage.World3HazardTemplates")
for _, descendant in templates:GetDescendants() do
	assert(not descendant:IsA("LuaSourceContainer"), "The hazard templates carry no script: " .. descendant:GetFullName())
	assert(not descendant:IsA("Constraint") and not descendant:IsA("WeldConstraint"), "The Snake's joints and forces are gone: " .. descendant:GetFullName())
	if descendant:IsA("BasePart") then
		assert(descendant.Anchored and not descendant.CanCollide and not descendant.CanTouch, descendant.Name .. " is inert")
	end
end
print("PASS World 3 is clean: no backdoor, no MoneyScripts, no asset pack, no Snake AI, only the map's 7 own scripts")

-- 2. It says it is World 3.
assert(workspace:GetAttribute("PlaceWorldNumber") == 3 and place:GetService("ReplicatedStorage"):GetAttribute("PlaceWorldNumber") == 3,
	"PlaceWorldNumber must be 3 on Workspace and ReplicatedStorage")
assert(workspace:GetAttribute("IsWorld2") == nil, "World 3 must not carry World 2's IsWorld2 attribute")
local noSignal = { Connect = function() end }
local function forward(real)
	return setmetatable({}, { __index = function(_, key)
		if key == "DescendantAdded" or key == "DescendantRemoving" then
			return noSignal
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
local env = setmetatable({ workspace = forward(workspace), typeof = typeof, print = function() end, warn = function() end, _G = {} }, { __index = _G })
for _, name in { "CFrame", "Vector3", "Color3", "UDim2", "UDim", "Vector2", "NumberRange", "ColorSequence", "ColorSequenceKeypoint", "NumberSequence", "NumberSequenceKeypoint", "BrickColor", "Enum", "Instance" } do
	env[name] = roblox[name]
end
env.game = { PlaceId = 0, GetService = function(_, name)
	return forward(place:GetService(name))
end }
-- Take the map check away: World 3 must be known from its attribute alone.
local stage1 = workspace:FindFirstChild("Stage 1")
stage1.Name = "Stage 1 (hidden from the map check)"
local config = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/Config.luau"), { environment = env })()
stage1.Name = "Stage 1"
assert(config.IsWorld3Place == true and config.IsWorld2Place == false and config.IsNewWorld1Map == false and config.StageCount == 10,
	"Config must detect World 3 from PlaceWorldNumber")
print("PASS World3NewestStable says PlaceWorldNumber = 3, and Config reads it without the map check")

-- 3. The same shared game as World 2.
local function sources(world)
	local set = {}
	for _, row in manifest.worlds[world].scripts do
		if string.sub(row.source, 1, 11) == "src/common/" then
			set[table.concat(row.segments, "/")] = row.source
		elseif string.sub(row.source, 1, 11) == "src/worlds/" then
			assert(world ~= "World3" or string.sub(row.source, 1, 18) == "src/worlds/World3/", "World 3 runs another world's script: " .. row.source)
		end
	end
	return set
end
local shared2, shared3 = sources("World2"), sources("World3")
for path, source in shared2 do
	assert(shared3[path] == source, "World 3 is missing World 2's shared script " .. path)
end
for path in shared3 do
	assert(shared2[path], "World 3 has a shared script World 2 does not: " .. path)
end
-- World 2's own scripts (src/worlds/World2) outside its map must not come along. Shared
-- scripts named after World 2, like Worlds.World2StageSystem, stay: they stop at once
-- outside World 2, as they do in World 1.
local function at(segments)
	local current = place
	for _, name in segments do
		current = current and current:FindFirstChild(name)
	end
	return current
end
local world2Own = 0
for _, row in manifest.worlds.World2.scripts do
	if string.sub(row.source, 1, 18) == "src/worlds/World2/" and row.segments[1] ~= "Workspace" then
		world2Own += 1
		assert(at(row.segments) == nil, "World 2's own script left in World 3: " .. row.path)
	end
end
assert(world2Own == 19, "World 2 had 19 scripts of its own outside the map, now " .. world2Own)
for _, service in { "StarterGui", "ServerStorage", "ReplicatedFirst", "SoundService", "MaterialService" } do
	local a = roblox.serializeModel(world2Place:GetService(service):GetChildren())
	local children = {}
	for _, child in place:GetService(service):GetChildren() do
		-- World 3's own hazard templates are its only addition.
		if not (service == "ServerStorage" and child.Name == "World3HazardTemplates") then
			table.insert(children, child)
		end
	end
	local b = roblox.serializeModel(children)
	assert(a == b, service .. " must be exactly World 2's")
end
local function withoutScripts(root)
	local count = 0
	for _, descendant in root:GetDescendants() do
		if not descendant:IsA("LuaSourceContainer") then
			count += 1
		end
	end
	return count
end
assert(withoutScripts(place:GetService("ReplicatedStorage")) == withoutScripts(world2Place:GetService("ReplicatedStorage")),
	"ReplicatedStorage assets must be World 2's")
assert(place:GetService("StarterPlayer").GameSettingsAvatar == world2Place:GetService("StarterPlayer").GameSettingsAvatar, "World 3 keeps the game's avatar setting")
print("PASS World 3 has every shared script World 2 has, World 2's UI and assets, and none of World 2's own scripts")

-- 4. The desert course and its Stage service.
for stage = 1, 10 do
	assert(workspace:FindFirstChild("Stage " .. stage), "Stage " .. stage .. " missing")
end
assert(workspace:FindFirstChild("End") and workspace.End:FindFirstChild("Winstage1") and workspace.End:FindFirstChild("Winstage2"), "The End (the finish) and its pad markers are in place")
assert(workspace.Lobby:FindFirstChildOfClass("SpawnLocation"), "The lobby spawn is missing")
assert(workspace.Lobby["world 2 portal"]:FindFirstChild("PortalWorld2", true), "The portal to World 2 is missing")
local lighting = place:GetService("Lighting")
assert(lighting.GlobalShadows == true and lighting:FindFirstChild("Stylized"), "World 3 keeps the desert's lighting")
local gameplay = place:GetService("ServerScriptService"):FindFirstChild("Gameplay")
local service = gameplay and gameplay:FindFirstChild("World3StageTeleportService")
assert(service and service:IsA("ModuleScript")
	and service.Source == fs.readFile("src/worlds/World3/ServerScriptService/Gameplay/World3StageTeleportService.luau"),
	"World3StageTeleportService must be built into ServerScriptService.Gameplay")
print("PASS the desert course, lobby spawn, portal and lighting are in place, with World3StageTeleportService")

