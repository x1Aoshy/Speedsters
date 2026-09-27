-- test_world3_stage_teleport.luau
-- World 3 (Desert), step 1: Config knows which world it is in, and the stage teleport
-- service reads the desert map the way the map is really built.
--
--   * Config detects World 3 on the desert map, and still detects World 1 and World 2 as
--     themselves (their places carry PlaceWorldNumber, so the map check never runs there).
--   * Every "Stage N" folder (2-8) gives exactly one checkpoint with its Win, Skip and x2
--     pads standing on it, although every part is named ...1 in every stage.
--   * Checkpoints run away from the spawn in stage order.
--   * GetNearestStage returns the last checkpoint passed, never the next one ahead.
local fs = require("@lune/fs")
local PlaceFiles = require("./place_files")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local MAP = "1+ Desert map final.rbxl"
-- The course is read on the composed place (audit/compose_world3.luau), which is what ships:
-- the map cleaned, with the finish's x2 marker added to the End.
local COMPOSED = "audit/world3_base/input.rbxl"
local CONFIG = fs.readFile("src/common/ReplicatedStorage/Shared/Config.luau")
local SERVICE = fs.readFile("src/worlds/World3/ServerScriptService/Gameplay/World3StageTeleportService.luau")

local noSignal = { Connect = function() end }

-- A stand-in for a service instance: forwards to the real (offline) instance, with the
-- events Lune instances do not have.
local function proxy(real)
	return setmetatable({}, {
		__index = function(_, key)
			if key == "DescendantAdded" or key == "DescendantRemoving" or key == "ChildAdded" then
				return noSignal
			end
			local value = real[key]
			if type(value) == "function" then
				return function(_, ...)
					return value(real, ...)
				end
			end
			return value
		end,
	})
end

local function environment(game)
	local workspace = proxy(game:GetService("Workspace"))
	local replicated = game:GetService("ReplicatedStorage")
	local env = {
		workspace = workspace,
		typeof = typeof,
		warn = function() end,
		print = function() end,
		_G = {},
	}
	for _, name in { "CFrame", "Vector3", "Color3", "UDim2", "UDim", "Vector2", "NumberRange", "ColorSequence", "ColorSequenceKeypoint", "NumberSequence", "NumberSequenceKeypoint", "BrickColor", "Enum", "Instance" } do
		env[name] = roblox[name]
	end
	env.game = {
		PlaceId = 0,
		GetService = function(_, name)
			if name == "Workspace" then
				return workspace
			elseif name == "ReplicatedStorage" then
				return setmetatable({
					WaitForChild = function(self)
						return self
					end,
				}, { __index = function(_, key)
					local value = replicated[key]
					if type(value) == "function" then
						return function(_, ...)
							return value(replicated, ...)
						end
					end
					return value
				end })
			end
			return proxy(game:GetService(name))
		end,
	}
	return setmetatable(env, { __index = _G })
end

local function loadConfig(file)
	local game = roblox.deserializePlace(fs.readFile(file))
	local env = environment(game)
	local config = luau.load(CONFIG, { environment = env })()
	return config, game, env
end

-- 1. Config: which world is this?
local desertConfig, desert, desertEnv = loadConfig(MAP)
assert(desertConfig.IsWorld3Place == true, "The desert map must be detected as World 3")
assert(desertConfig.IsWorld2Place == false, "The desert map is not World 2")
assert(desertConfig.IsNewWorld1Map == false, "The desert map must not start World 1's systems")
assert(desertConfig.StageCount == 10, "World 3 has 10 stages")
assert(desertConfig.TreadmillBaseGains.Diamond == desertConfig.World3TreadmillProfiles.Diamond.BaseGain, "World 3 treadmills use World 3 profiles")
assert(desertConfig.TreadmillBaseGains.Needoh == desertConfig.World2TreadmillProfiles.Needoh.BaseGain, "Game pass treadmills keep the multiplier they are sold with")
local teleportStages = {}
for _, option in desertConfig.TeleportStageOptions do
	assert(option.WinsCost == desertConfig.World3TeleportWinsCosts[option.Stage], "World 3 teleports cost World 3 Wins")
	table.insert(teleportStages, option.Stage)
end
assert(table.concat(teleportStages, ",") == "2,3,4,5,6,7,8,9,10", "World 3 offers teleports to Stages 2-10, got " .. table.concat(teleportStages, ","))
for stage = 2, 10 do
	assert((desertConfig.World3StageWinRewards[stage] or 0) > desertConfig.World2FinalWinReward * 0.5, "World 3 rewards continue past World 2")
	assert(stage == 2 or desertConfig.World3StageWinRewards[stage] > desertConfig.World3StageWinRewards[stage - 1], "World 3 rewards grow stage by stage")
end
assert(desertConfig.World3FinalWinReward > desertConfig.World3StageWinRewards[10], "The finish pays more than Stage 10")

for _, place in { { File = PlaceFiles.World1, Stages = 11 }, { File = PlaceFiles.World2, Stages = 10 } } do
	local config = loadConfig(place.File)
	assert(config.IsWorld3Place == false, place.File .. " must not be detected as World 3")
	assert(config.StageCount == place.Stages, place.File .. " keeps " .. place.Stages .. " stages")
end
print("PASS Config detects World 3 on the desert map and leaves World 1 and World 2 as they were")

-- 2. The course as the service reads it.
local composedConfig, composed, composedEnv = loadConfig(COMPOSED)
assert(composedConfig.IsWorld3Place == true and composedConfig.StageCount == 10, "The composed place is World 3, 10 stages")
composedEnv.require = function(module)
	return composedConfig
end
local Service = luau.load(SERVICE, { environment = composedEnv })()
local workspace = composed:GetService("Workspace")
local course = Service.ReadCourse(workspace)
assert(#course.Problems == 0, "The desert course has problems:\n" .. table.concat(course.Problems, "\n"))
assert(course.Spawn and course.Spawn.Parent == workspace:FindFirstChild("Lobby"), "Stage 1 starts at the lobby spawn")
-- The finish: the End, its Winstage1 (Win) and Winstage2 (x2) on its floor.
local finish = course.Finish
assert(finish and finish.End and finish.Model:GetFullName() == "Workspace.End", "The finish is the End")
assert(finish.Win.Name == "Winstage1" and finish.X2 and finish.X2.Name == "Winstage2" and finish.Skip == nil,
	"The End carries the final Win and x2 markers, and nothing to skip")
assert(finish.Checkpoint.Parent == finish.Model and finish.Checkpoint.Size.X * finish.Checkpoint.Size.Z > 100000,
	"The finish block is the End's floor")
local floorTop = finish.Checkpoint.CFrame.Position.Y + finish.Checkpoint.Size.Y / 2
for _, marker in { finish.Win, finish.X2 } do
	local offset = finish.Checkpoint.CFrame:PointToObjectSpace(marker.CFrame.Position)
	assert(math.abs(offset.X) <= finish.Checkpoint.Size.X / 2 and math.abs(offset.Z) <= finish.Checkpoint.Size.Z / 2, marker.Name .. " lies over the End's floor")
	assert(marker.CFrame.Position.Y < floorTop, marker.Name .. " is sunk into the floor (the pads stand on the floor)")
end
assert((finish.Win.CFrame.Position - finish.X2.CFrame.Position).Magnitude < 30, "The x2 pad is beside the Win pad")
assert(course.Final == finish.Checkpoint, "Until something is marked World3FinalWinStage, the finish block is the final marker")
local lastCheckpoint = course.Stages[10].Checkpoint.CFrame.Position
local spawnAt = course.Spawn.CFrame.Position
local function levelDistance(a, b)
	return roblox.Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end
assert(levelDistance(finish.Checkpoint.CFrame.Position, spawnAt) > levelDistance(lastCheckpoint, spawnAt) + 300,
	"The finish lies well past Stage 10's checkpoint")
assert(course.Stages[1] and course.Stages[1].Checkpoint == nil, "Stage 1 has no checkpoint of its own")

local function top(part)
	return (part.CFrame * roblox.CFrame.new(0, part.Size.Y / 2, 0)).Position
end
local spawnPosition = course.Spawn.CFrame.Position
local lastDistance = -1
for stage = 2, 10 do
	local entry = course.Stages[stage]
	local checkpoint = entry.Checkpoint
	assert(checkpoint.Parent.Parent == entry.Folder, "Stage " .. stage .. "'s checkpoint is its own")
	local surface = top(checkpoint)
	for _, kind in { "Win", "Skip", "X2" } do
		local pad = entry[kind]
		local offset = checkpoint.CFrame:PointToObjectSpace(pad.CFrame.Position)
		assert(math.abs(offset.X) <= checkpoint.Size.X / 2 and math.abs(offset.Z) <= checkpoint.Size.Z / 2,
			"Stage " .. stage .. " " .. kind .. " pad must stand on its checkpoint")
		assert(math.abs(pad.CFrame.Position.Y - surface.Y) < 1, "Stage " .. stage .. " " .. kind .. " pad must lie on the checkpoint's top")
	end
	local distance = (roblox.Vector3.new(surface.X, 0, surface.Z) - roblox.Vector3.new(spawnPosition.X, 0, spawnPosition.Z)).Magnitude
	assert(distance > lastDistance, "Stage " .. stage .. " must be further from the spawn than Stage " .. (stage - 1))
	lastDistance = distance
	assert((Service.GetStageReferencePosition(stage) - surface).Magnitude < 1e-3, "Stage " .. stage .. " teleports onto its checkpoint")
end
assert((Service.GetStageReferencePosition(1) - spawnPosition).Magnitude < 1e-3, "Stage 1 teleports to the spawn")
print("PASS every Stage 2-10 folder has one checkpoint with its Win, Skip and x2 pads on it, in course order; the End is the finish")

-- 3. Revives: the last checkpoint passed.
local function nearest(position)
	return (Service.GetNearestStage(position))
end
assert(nearest(spawnPosition) == 1, "The lobby is Stage 1")
for stage = 2, 10 do
	local here = Service.GetStageReferencePosition(stage)
	assert(nearest(here) == stage, "Standing on Stage " .. stage .. "'s checkpoint is Stage " .. stage)
	local before = Service.GetStageReferencePosition(stage - 1)
	-- Nine tenths of the way from the previous checkpoint's middle, but short of this
	-- checkpoint's front edge: still the previous stage, though this one is nearer.
	local checkpoint = course.Stages[stage].Checkpoint
	local direction = roblox.Vector3.new(here.X - before.X, 0, here.Z - before.Z)
	local length = direction.Magnitude
	direction = direction.Unit
	local frontEdge = length - checkpoint.Size.Z / 2
	local short = before + direction * math.min(length * 0.9, frontEdge - 5)
	assert(nearest(short) == stage - 1, string.format("A fall just before Stage %d's checkpoint revives on Stage %d, got %s", stage, stage - 1, tostring(nearest(short))))
	local onEdge = before + direction * (frontEdge + 3)
	assert(nearest(onEdge) == stage, "Stepping onto Stage " .. stage .. "'s checkpoint counts as reaching it")
end
print("PASS GetNearestStage returns the last checkpoint passed, never the next one")

-- 4. Every caller gets this service in World 3.
local facade = fs.readFile("src/common/ServerScriptService/Services/StageTeleportService.luau")
assert(string.find(facade, 'if Config.IsWorld3Place == true then\n\treturn require(game:GetService("ServerScriptService"):WaitForChild("Gameplay"):WaitForChild("World3StageTeleportService"))', 1, true),
	"Services.StageTeleportService must hand out the World 3 service in World 3")
print("PASS Services.StageTeleportService routes World 3 to World3StageTeleportService")
