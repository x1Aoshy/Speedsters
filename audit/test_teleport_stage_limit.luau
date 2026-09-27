local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")

local configSource = fs.readFile("src/common/ReplicatedStorage/Shared/Config.luau")
local controllerSource = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/TeleportController.client.luau")
luau.compile(configSource)
luau.compile(controllerSource)

local function configForWorld(world)
	local storage = {
		GetAttribute = function(_, name)
			if name == "PlaceWorldNumber" then return world end
			return nil
		end,
	}
	local workspace = {
		GetAttribute = function() return nil end,
		FindFirstChild = function(_, name)
			if world == 1 and name == "neworld1" then return {} end
			return nil
		end,
	}
	local game = {
		PlaceId = ({ [1] = 85065221510105, [2] = 116359653478954, [3] = 128432111599629 })[world],
		GetService = function(_, name)
			assert(name == "ReplicatedStorage", name)
			return storage
		end,
	}
	return luau.load(configSource, { environment = {
		game = game,
		workspace = workspace,
		Vector3 = rb.Vector3,
		Color3 = rb.Color3,
	} })()
end

for world = 1, 3 do
	local config = configForWorld(world)
	assert(config.StageCount == (world == 1 and 11 or 10), "gameplay stage count unexpectedly changed in World " .. world)
	local maxStage = 0
	for _, option in ipairs(config.TeleportStageOptions) do
		assert(option.Stage >= 2 and option.Stage <= 10, "invalid teleport stage in World " .. world)
		maxStage = math.max(maxStage, option.Stage)
	end
	assert(maxStage == 10, "teleport menu must end at Stage 10 in World " .. world)
end

local currentPlaces = {
	"World1Update3New.rbxl",
	"World2Update3new.rbxl",
	"World3Update3New.rbxl",
}
for world, file in currentPlaces do
	local place = rb.deserializePlace(fs.readFile(file))
	local gui = assert(place:GetService("StarterGui"):FindFirstChild("StageTeleport"))
	local panel = assert(gui:FindFirstChild("StageTeleport"))
	local scroll = assert(panel:FindFirstChild("ScrollingFrame"))
	assert(not scroll:FindFirstChild("Stage11"), "World " .. world .. " still authors Stage 11")
	assert(scroll.AutomaticCanvasSize == rb.Enum.AutomaticSize.Y, "World " .. world .. " teleport scroll extent is stale")
end

assert(string.find(controllerSource, "child.Visible = stageNum <= MAX_TELEPORT_STAGE", 1, true),
	"static Stage 11 row must be hidden even if already authored in the GUI")
assert(string.find(controllerSource, "local MAX_TELEPORT_STAGE = 10", 1, true),
	"client teleport limit must remain 10")

print("PASS teleport options and authored rows stop at Stage 10 in all worlds; World 1 gameplay Stage 11 is preserved")
