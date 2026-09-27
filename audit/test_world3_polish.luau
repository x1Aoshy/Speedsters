-- test_world3_polish.luau
-- World 3 (Desert), step 5, against the built place:
--
--   1. Flight: World 3 runs the same flight entry points as World 1 and World 2 (shared
--      FlightService), and flight is enabled and sold there.
--   2. Leaderboards: the lobby's leaderboard1 has every screen, frame and champion stand the
--      shared board needs; 2026-09-26 (owner): UI.GlobalLeaderboardDisplay (with
--      Shared.LeaderboardChampionRig) is the one champion layer, World3LeaderboardChampions is a
--      retired comment-only stub (audit/test_leaderboard_champions checks the champions).
--   3. The Basic treadmill: World 2's starter, scaled and turned like the desert's other
--      treadmills, standing on the treadmill area's floor in the free slot before Diamond,
--      with no lock, x3 Speed, and a "Starter" sign.
local fs = require("@lune/fs")
local PlaceFiles = require("./place_files")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local Vector3 = roblox.Vector3
local manifest = serde.decode("json", fs.readFile("src/manifest.json"))
local place = roblox.deserializePlace(fs.readFile(PlaceFiles.World3))
local world2Input = roblox.deserializePlace(fs.readFile(manifest.worlds.World2.input))
local workspace = place:GetService("Workspace")

local function at(root, path)
	local current = root
	for _, name in path do
		current = current and current:FindFirstChild(name)
	end
	return current
end

-- 1. Flight ----------------------------------------------------------------------
local serverEntry = at(place, { "ServerScriptService", "Gameplay", "World3FlightAbility" })
local clientEntry = at(place, { "StarterPlayer", "StarterPlayerScripts", "Movement", "World3FlightAbility" })
assert(serverEntry and serverEntry:IsA("Script"), "World 3 must start the shared FlightService")
assert(clientEntry and clientEntry:IsA("LocalScript"), "World 3 must run the flight client")
assert(serverEntry.Source == fs.readFile("src/worlds/World2/ServerScriptService/Gameplay/World2FlightAbility.server.luau")
	and serverEntry.Source == fs.readFile("src/worlds/World1/ServerScriptService/Gameplay/World1FlightAbility.server.luau"),
	"World 3's flight entry is the one World 1 and World 2 run")
assert(string.find(serverEntry.Source, 'WaitForChild("FlightService")).Start()', 1, true), "The entry starts Core.Abilities.FlightService")
assert(clientEntry.Source == fs.readFile("src/worlds/World2/StarterPlayer/StarterPlayerScripts/Movement/World2FlightAbility.client.luau"),
	"World 3's flight client is the one World 1 and World 2 run")
assert(at(place, { "ServerScriptService", "Core", "Abilities", "FlightService" }), "FlightService is in World 3")
assert(at(place, { "ReplicatedStorage", "Shared", "FlightStamina" }), "FlightStamina is in World 3")
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
local env = setmetatable({ workspace = forward(workspace), typeof = typeof, print = function() end, warn = function() end }, { __index = _G })
for _, name in { "CFrame", "Vector3", "Color3", "UDim2", "UDim", "Vector2", "NumberRange", "ColorSequence", "ColorSequenceKeypoint", "NumberSequence", "NumberSequenceKeypoint", "BrickColor", "Enum", "Instance" } do
	env[name] = roblox[name]
end
env.game = { PlaceId = 0, GetService = function(_, name)
	return forward(place:GetService(name))
end }
local Config = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/Config.luau"), { environment = env })()
assert(Config.IsWorld3Place == true and Config.AbilityFlightEnabled == true, "Flight is enabled in World 3")
assert(string.find(fs.readFile("src/common/ServerScriptService/Economy/SpeedProductPurchases.server.luau"),
	"if (not IS_WORLD2) and Config.AbilityFlightEnabled == true and flightAbilityProductId", 1, true),
	"The flight product is sold everywhere but World 2, so in World 3")
print("PASS World 3 runs the shared flight entry points and sells flight")

-- 2. Leaderboards -------------------------------------------------------------------
local board = workspace.Lobby:FindFirstChild("leaderboard1")
assert(board and board:IsA("Model"), "The lobby's leaderboard1 model is there")
for _, category in { "Robux", "Speed", "Wins" } do
	local screen = board:FindFirstChild(category .. "_LeaderboardScreen", true)
	local frame = board:FindFirstChild(category .. "_LeaderboardFrame", true)
	local stand = board:FindFirstChild(category .. "_ChampionStandTop", true)
	assert(screen and frame and stand, category .. " needs its screen, frame and champion stand")
	assert(stand.CFrame.Position.Y < screen.CFrame.Position.Y, category .. "'s champion stands below its screen")
end
for _, path in {
	{ "ServerScriptService", "Social", "GlobalLeaderboards" },
	{ "StarterPlayer", "StarterPlayerScripts", "UI", "GlobalLeaderboardDisplay" },
} do
	assert(at(place, path), "World 3 runs the shared " .. path[#path])
end
-- 2026-09-26 (owner): one champion layer. World3LeaderboardChampions stood its own champions and
-- deleted the shared ones; it is retired (a comment-only stub, the build keeps authored scripts),
-- and the shared display stands them with Shared.LeaderboardChampionRig (accessories welded, only
-- the root anchored, dancing).
local function lf(text)
	return (string.gsub(text, "\r\n", "\n"))
end
local champions = at(place, { "StarterPlayer", "StarterPlayerScripts", "Gameplay", "World3LeaderboardChampions" })
local stub = lf(fs.readFile("src/worlds/World3/StarterPlayer/StarterPlayerScripts/Gameplay/World3LeaderboardChampions.client.luau"))
assert(string.gsub(string.gsub(stub, "%-%-[^\n]*", ""), "%s", "") == "", "World3LeaderboardChampions is retired in src (comments only)")
assert(champions == nil or lf(champions.Source) == stub, "World 3 carries the retired World3LeaderboardChampions stub")
local display = at(place, { "StarterPlayer", "StarterPlayerScripts", "UI", "GlobalLeaderboardDisplay" })
assert(lf(display.Source) == lf(fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/GlobalLeaderboardDisplay.client.luau")),
	"World 3 runs the current shared display (the one champion layer)")
local rigModule = at(place, { "ReplicatedStorage", "Shared", "LeaderboardChampionRig" })
assert(rigModule and rigModule:IsA("ModuleScript"), "World 3 has Shared.LeaderboardChampionRig")
print("PASS the lobby leaderboard has all its screens and stands; the shared display is the one champion layer (World3LeaderboardChampions retired)")

-- 3. The Basic treadmill -------------------------------------------------------------
local lobby = workspace.Lobby
local basic = lobby:FindFirstChild("Basic")
assert(basic and basic:IsA("Model") and basic:FindFirstChild("Treadmil", true), "The lobby has the Basic treadmill, with its belt")
for _, descendant in basic:GetDescendants() do
	assert(not descendant:IsA("LuaSourceContainer"), "The Basic treadmill carries no scripts")
end
local function beltOf(treadmill)
	local best, area = nil, 0
	for _, part in treadmill:FindFirstChild("Treadmil", true):GetDescendants() do
		if part:IsA("BasePart") and part.Size.X * part.Size.Z > area then
			best, area = part, part.Size.X * part.Size.Z
		end
	end
	return best
end
local function box(object)
	local minimum = Vector3.new(math.huge, math.huge, math.huge)
	local maximum = -minimum
	local parts = object:GetDescendants()
	if object:IsA("BasePart") then
		table.insert(parts, object)
	end
	for _, part in parts do
		if part:IsA("BasePart") then
			local cframe, half = part.CFrame, part.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local corner = (cframe * roblox.CFrame.new(sx * half.X, sy * half.Y, sz * half.Z)).Position
						minimum = Vector3.new(math.min(minimum.X, corner.X), math.min(minimum.Y, corner.Y), math.min(minimum.Z, corner.Z))
						maximum = Vector3.new(math.max(maximum.X, corner.X), math.max(maximum.Y, corner.Y), math.max(maximum.Z, corner.Z))
					end
				end
			end
		end
	end
	return minimum, maximum
end

local diamondBelt, basicBelt = beltOf(lobby.Diamond), beltOf(basic)
local world2Admin = world2Input:GetService("Workspace").Admin
local scale = diamondBelt.Size.X / beltOf(world2Admin.Diamond).Size.X
assert(math.abs(basicBelt.Size.X - beltOf(world2Admin.Golden).Size.X * scale) < 0.01, "Basic is scaled like the desert's copies of World 2's treadmills")
assert(basicBelt.CFrame.LookVector:Dot(diamondBelt.CFrame.LookVector) > 0.999
	and basicBelt.CFrame.RightVector:Dot(diamondBelt.CFrame.RightVector) > 0.999, "Basic's belt runs the same way as Diamond's")

local floor = lobby.Treadmillarea["floor for spawn"]:FindFirstChildWhichIsA("BasePart")
local floorLow, floorHigh = box(floor)
local low, high = box(basic)
assert(math.abs(low.Y - floorHigh.Y) < 0.5, string.format("Basic stands on the treadmill floor (bottom %.2f, floor %.2f)", low.Y, floorHigh.Y))
assert(low.X >= floorLow.X and high.X <= floorHigh.X and low.Z >= floorLow.Z and high.Z <= floorHigh.Z, "Basic stays inside the treadmill area")
for _, other in { "Diamond", "Needoh", "Admin", "Hacker" } do
	local otherLow, otherHigh = box(lobby[other]:FindFirstChild("Treadmil", true))
	local overlaps = low.X < otherHigh.X and high.X > otherLow.X and low.Z < otherHigh.Z and high.Z > otherLow.Z
	assert(not overlaps, "Basic must not overlap " .. other)
end
assert(high.Z < box(lobby.Diamond:FindFirstChild("Treadmil", true)).Z, "Basic comes first in the row, before Diamond")

local profile = Config.World3TreadmillProfiles.Basic
assert(profile and profile.BaseGain == 3 and profile.RequiredRebirths == nil and profile.GamePassId == nil and profile.StarterOnly == true,
	"Basic: x3 Speed, no Rebirths, no pass")
assert(Config.TreadmillBaseGains.Basic == 3, "Treadmill training pays Basic's gain")
assert(profile.DisplayText == "Starter\nx3 Speed", "Its sign reads Starter / x3 Speed")
print("PASS the Basic treadmill stands in the free slot before Diamond, scaled and turned like the others, with no lock and x3 Speed")
