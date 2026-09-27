-- audit/test_opt6_lag_extras.luau
-- Smaller World 2 / World 3 costs found with the "stuck" report (2026-09-21), each run on the
-- real source text (and the real place where the map matters):
--   1. SpeedProductPurchases' safe-zone tracker no longer writes CurrentSafeZoneStage /
--      LastReachedStage in World 2, where World2SafeZones owns them with the world's own
--      numbering (the two loops overwrote each other ~13 times a second; each write replicated
--      and the stages quest counted every flip back up). Worlds 1 and 3 keep it.
--   2. The parked Sonic.EXE boss no longer re-pivots its rig and flips ReturningToSpawn every
--      Heartbeat, and with nobody in the area it looks for a target at its refresh rate, not
--      every frame. It still walks home and parks.
--   3. World2WallFlightBarriers never scans a character (it did once per added limb, accessory
--      and effect of every respawn); every real wall of World 2 is still found.
--   4. World2SafeZones writes World2CurrentSafeZoneNumber on change only, and still checks
--      every 0.08 s (slower would leave fast runners protected well outside a zone).
--   5. CharacterStatsAdapter leaves the sprint's WalkSpeed to the client (InstantMovement-
--      Controller) instead of knocking it down on every speed tick; the server's readers take
--      max(RealWalkSpeedSelected, WalkSpeed).
--   6. World 3's 14 map Seats (benches and chairs on the route) are switched off at start, so a
--      runner who brushes one is not sat down and snapped into it.
--
--   lune run audit/test_opt6_lag_extras.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local PlaceFiles = require("./place_files")

local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame

local function read(path)
	return (string.gsub(fs.readFile(path), "\r\n", "\n"))
end
local function pass(text)
	print("PASS " .. text)
end
local function between(source, first, last, label)
	local a = assert(string.find(source, first, 1, true), label .. ": start moved")
	local b = assert(string.find(source, last, a + #first, true), label .. ": end moved")
	return string.sub(source, a, b - 1)
end
local function env(values)
	return setmetatable(values, { __index = _G })
end

-- A stand-in that counts every attribute write, per name.
local function attributed(initial)
	local object = { Attributes = initial or {}, Writes = {} }
	function object:GetAttribute(key)
		return self.Attributes[key]
	end
	function object:SetAttribute(key, value)
		self.Writes[key] = (self.Writes[key] or 0) + 1
		self.Attributes[key] = value
	end
	return object
end
local function writes(object, key)
	return object.Writes[key] or 0
end

----------------------------------------------------------------------
-- 1. SpeedProductPurchases' tracker: World 2's stage attributes belong to World2SafeZones
----------------------------------------------------------------------
do
	local source = read("src/common/ServerScriptService/Economy/SpeedProductPurchases.server.luau")
	local slice = between(source, "local stage = findSafeZoneStageAtPosition(root.Position)", "if root.Position.Y > -10 then", "SPP tracker")
	local function tick(isWorld2, zone, player)
		luau.load("local player, root = ...\n" .. slice, { environment = env({
			IS_WORLD2 = isWorld2,
			findSafeZoneStageAtPosition = function()
				return zone
			end,
		}) })(player, { Position = Vector3.new() })
	end
	-- World 2: standing in SafeZone3.2, which World2SafeZones counts as Stage 4.
	local player = attributed({ CurrentSafeZoneStage = 4, LastReachedStage = 4 })
	for _ = 1, 20 do
		tick(true, 3, player)
	end
	assert(writes(player, "CurrentSafeZoneStage") == 0 and writes(player, "LastReachedStage") == 0, "World 2: the tracker leaves both attributes to World2SafeZones")
	assert(player:GetAttribute("LastReachedStage") == 4, "...so the stage stays the world's own number")
	-- Worlds 1 and 3 keep it, on change only.
	local elsewhere = attributed({})
	for _ = 1, 20 do
		tick(false, 3, elsewhere)
	end
	assert(elsewhere:GetAttribute("CurrentSafeZoneStage") == 3 and elsewhere:GetAttribute("LastReachedStage") == 3, "Worlds 1 and 3: the tracker still sets the stage")
	assert(writes(elsewhere, "CurrentSafeZoneStage") == 1 and writes(elsewhere, "LastReachedStage") == 1, "...once, not on every tick")
	tick(false, nil, elsewhere)
	assert(elsewhere:GetAttribute("CurrentSafeZoneStage") == 0 and elsewhere:GetAttribute("LastReachedStage") == 3, "...and clears the zone on leaving it")
	pass("the safe-zone tracker leaves World 2's CurrentSafeZoneStage / LastReachedStage to World2SafeZones; Worlds 1 and 3 unchanged")
end

----------------------------------------------------------------------
-- 2. The parked Sonic.EXE boss is quiet
----------------------------------------------------------------------
do
	local source = read("src/worlds/World2/ServerScriptService/Bosses/World2SonicEXEBoss.server.luau")
	local function constant(name)
		return assert(tonumber(string.match(source, "\nlocal " .. name .. " = ([%d%.]+)")), name)
	end
	local chunk = between(source, "local function isProtected(player, character)", "\nprint(", "Sonic boss")
	local clock = 100
	local counts = { pivots = 0, searches = 0 }
	local root = { Position = Vector3.new(0, 5, 0), Anchored = true, AssemblyLinearVelocity = Vector3.zero, AssemblyAngularVelocity = Vector3.zero, Parent = true }
	function root:SetNetworkOwner() end
	local humanoid = { Health = 100, Parent = true, WalkSpeed = constant("SONIC_WALK_SPEED") }
	function humanoid:Move() end
	function humanoid:ChangeState() end
	local boss = attributed({})
	boss.Parent = true
	function boss:PivotTo()
		counts.pivots += 1
		root.Position = Vector3.new(0, 5, 0)
	end
	local heartbeat = nil
	local inArea = {}
	local players = {}
	luau.load(chunk, { environment = env({
		boss = boss, root = root, humanoid = humanoid,
		configuredParts = {}, spawnPivot = CFrame.new(0, 5, 0), spawnRootPosition = Vector3.new(0, 5, 0),
		horizontal = function(v)
			return Vector3.new(v.X, 0, v.Z)
		end,
		horizontalUnit = function(v)
			local flat = Vector3.new(v.X, 0, v.Z)
			return if flat.Magnitude < 0.001 then nil else flat.Unit
		end,
		isInsideSixSevenArea = function(position)
			return inArea[position] == true
		end,
		contactRemote = { OnServerEvent = { Connect = function() end }, FireClient = function() end },
		Players = { GetPlayers = function()
			counts.searches += 1
			return players
		end },
		RunService = { Heartbeat = { Connect = function(_, fn)
			heartbeat = fn
			return { Disconnect = function() end }
		end } },
		Workspace = { GetAttribute = function()
			return nil
		end },
		os = { clock = function()
			return clock
		end },
		Vector3 = Vector3, CFrame = CFrame, Enum = roblox.Enum,
		RETURN_TO_SPAWN_ARRIVAL_DISTANCE = constant("RETURN_TO_SPAWN_ARRIVAL_DISTANCE"),
		TARGET_REFRESH_INTERVAL = constant("TARGET_REFRESH_INTERVAL"),
		TARGET_LEAD_SECONDS = constant("TARGET_LEAD_SECONDS"),
		MAX_TARGET_LEAD_STUDS = constant("MAX_TARGET_LEAD_STUDS"),
		STEERING_RESPONSE = constant("STEERING_RESPONSE"),
		ARRIVAL_DISTANCE = constant("ARRIVAL_DISTANCE"),
		SONIC_WALK_SPEED = constant("SONIC_WALK_SPEED"),
		SONIC_CHASE_EDGE = constant("SONIC_CHASE_EDGE"),
		SONIC_MIN_CHASE_SPEED = constant("SONIC_MIN_CHASE_SPEED"),
	}) })()
	assert(heartbeat, "The boss runs on Heartbeat")
	local function frames(n)
		for _ = 1, n do
			clock += 1 / 60
			heartbeat(1 / 60)
		end
	end
	-- Parked at spawn (the script parks it once at start), nobody in the area: one second.
	counts.pivots, counts.searches, boss.Writes = 0, 0, {}
	frames(60)
	assert(counts.pivots == 0, "Parked, the rig is not pivoted again (" .. counts.pivots .. " in a second)")
	assert(writes(boss, "ReturningToSpawn") == 0 and writes(boss, "TrackingActive") == 0, "...and writes no attribute")
	assert(counts.searches <= 20, "With nobody to chase it looks for a target at its refresh rate, not every frame (" .. counts.searches .. " searches in 60 frames)")
	assert(counts.searches >= 10, "...but it does keep looking (" .. counts.searches .. ")")
	-- Knocked away from home (as after a chase): it walks back, then parks exactly once.
	root.Position = Vector3.new(12, 5, 0)
	frames(3)
	assert(boss:GetAttribute("ReturningToSpawn") == true and root.Anchored == false, "Away from home it walks back")
	root.Position = Vector3.new(0.1, 5, 0)
	counts.pivots = 0
	frames(30)
	assert(counts.pivots == 1 and boss:GetAttribute("ReturningToSpawn") == false and root.Anchored == true, "Home again it parks once, exactly on its spawn")
	-- A player walks into the area: the chase starts within one refresh.
	local targetRoot = { Position = Vector3.new(30, 5, 0), AssemblyLinearVelocity = Vector3.zero, IsA = function()
		return true
	end }
	inArea[targetRoot.Position] = true
	local character = attributed({})
	function character:FindFirstChildOfClass()
		return { Health = 100 }
	end
	function character:FindFirstChild(name)
		return if name == "HumanoidRootPart" then targetRoot else nil
	end
	table.insert(players, attributed({}))
	players[1].Character, players[1].UserId = character, 1
	-- A World 2 entrant at 6 Rebirths + Level 50 and x0.5 runs about 22.6 studs/s (2026-09-22).
	players[1]:SetAttribute("RealWalkSpeedMax", 22.6)
	frames(5)
	assert(boss:GetAttribute("TrackingActive") == true and boss:GetAttribute("CurrentTargetUserId") == 1, "A player in the area is chased within a few frames")
	local edge, cap = constant("SONIC_CHASE_EDGE"), constant("SONIC_WALK_SPEED")
	assert(math.abs(humanoid.WalkSpeed - 22.6 * edge) < 0.01, "Sonic keeps his x" .. edge .. " edge over a slow runner (" .. humanoid.WalkSpeed .. ")")
	assert(humanoid.WalkSpeed > 22.6 * 1.7, "...still a little faster than that runner's sprint")
	players[1]:SetAttribute("RealWalkSpeedMax", 90)
	frames(2)
	assert(humanoid.WalkSpeed == cap, "A fast runner meets the old full speed, never more (" .. humanoid.WalkSpeed .. ")")
	players[1]:SetAttribute("RealWalkSpeedMax", 2)
	frames(2)
	assert(humanoid.WalkSpeed == constant("SONIC_MIN_CHASE_SPEED"), "A crawling runner still meets the floor speed")
	players[1]:SetAttribute("RealWalkSpeedMax", nil)
	frames(2)
	assert(humanoid.WalkSpeed == cap, "No speed known: the old full speed")
	pass("the parked Sonic.EXE boss neither re-pivots nor writes attributes, searches at its refresh rate, still walks home and parks once, and still chases, at x" .. edge .. " the runner's full speed (30..57.7)")
end

----------------------------------------------------------------------
-- 3. World2WallFlightBarriers: characters are never scanned; every real wall still is
----------------------------------------------------------------------
local world2 = roblox.deserializePlace(fs.readFile(PlaceFiles.World2))
do
	local source = read("src/worlds/World2/ServerScriptService/Gameplay/World2WallFlightBarriers.server.luau")
	local getWallBody = luau.load(between(source, "local function normalizeName(value)", "local function destroyBarrier(wall)", "wall body")
		.. "\nreturn getWallBody", { environment = env({ Vector3 = Vector3 }) })()
	local walls = 0
	for _, model in world2:GetService("Workspace"):GetDescendants() do
		if model:IsA("Model") and getWallBody(model) then
			walls += 1
			assert(model:FindFirstChildOfClass("Humanoid") == nil, model:GetFullName() .. " is a wall with a Humanoid: the character skip would miss it")
		end
	end
	assert(walls > 0, "World 2 has walls that get a flight barrier")

	local root = roblox.Instance.new("Folder")
	local refreshed = {}
	local refresh = luau.load(between(source, "local function refreshAncestorWalls(instance)", "local startupCount = 0", "refresh")
		.. "\nreturn refreshAncestorWalls", { environment = env({
			Workspace = root,
			createOrRefreshBarrier = function(model)
				refreshed[model] = (refreshed[model] or 0) + 1
			end,
		}) })()
	local character = roblox.Instance.new("Model")
	roblox.Instance.new("Humanoid").Parent = character
	local limb = roblox.Instance.new("Part")
	limb.Parent = character
	character.Parent = root
	local wall = roblox.Instance.new("Model")
	for _, name in { "Model", "Rock", "Rock", "Tree", "Tree" } do
		local child = roblox.Instance.new("Model")
		child.Name = name
		child.Parent = wall
	end
	local stone = roblox.Instance.new("Part")
	stone.Parent = wall.Model
	wall.Parent = root
	refresh(limb)
	assert(refreshed[character] == nil, "A character's new limb does not scan the character")
	refresh(stone)
	assert(refreshed[wall] == 1 and refreshed[wall.Model] == 1, "A wall's new part still refreshes the wall")
	pass(string.format("wall flight barriers never scan a character; the %d real walls of World 2 hold no Humanoid, so none is skipped", walls))
end

----------------------------------------------------------------------
-- 4. World2SafeZones: the zone number on change only; the check stays at 0.08 s
----------------------------------------------------------------------
do
	local source = read("src/worlds/World2/ServerScriptService/Gameplay/World2SafeZones.server.luau")
	assert(string.find(source, "\nlocal CHECK_INTERVAL = 0.08\n", 1, true), "World2SafeZones still checks every 0.08 s (a slower check leaves fast runners protected well outside a zone)")
	local chunk = between(source, "local function logicalStageForZoneNumber(zoneNumber)", "local function isZoneObject(object)", "logical stage")
		.. between(source, "local function pointInsideBounds(point, bounds)", "\nfor _, player in ipairs(Players:GetPlayers()) do", "update")
		.. "\nreturn updatePlayer"
	local zoneCentre = Vector3.new(100, 50, 100)
	local updatePlayer = luau.load(chunk, { environment = env({
		STAGE_COUNT = 10, FIRST_SAFE_ZONE_NUMBER = 1, SIDE_PADDING = 0.75, BELOW_PADDING = 2, HEIGHT_ABOVE = 12,
		SAFE_ZONE_ATTRIBUTE = "SafeZoneProtected", SAFE_ZONE_FORCE_FIELD = "VortexSafeZoneForceField",
		boundsCache = { [3] = { CFrame = CFrame.new(zoneCentre), Size = Vector3.new(40, 4, 40) } },
		Instance = { new = function()
			local field = { Parent = nil }
			function field:IsA(class)
				return class == "ForceField"
			end
			function field:Destroy()
				self.Parent = nil
			end
			return field
		end },
		_G = {},
	}) })()
	local root = { Position = zoneCentre + Vector3.new(0, 3, 0), IsA = function()
		return true
	end }
	local character = attributed({})
	character.Parent = true
	function character:FindFirstChild(name)
		return if name == "HumanoidRootPart" then root else nil
	end
	function character:FindFirstChildOfClass()
		return { Health = 100, MaxHealth = 100 }
	end
	local player = attributed({})
	player.Character = character
	for _ = 1, 12 do
		updatePlayer(player)
	end
	assert(player:GetAttribute("World2CurrentSafeZoneNumber") == 3 and player:GetAttribute("CurrentSafeZoneStage") == 4, "In SafeZone3.2: zone 3, Stage 4")
	assert(writes(player, "World2CurrentSafeZoneNumber") == 1, "...the zone number written once, not every check (" .. writes(player, "World2CurrentSafeZoneNumber") .. ")")
	root.Position = zoneCentre + Vector3.new(200, 3, 0)
	for _ = 1, 12 do
		updatePlayer(player)
	end
	assert(player:GetAttribute("World2CurrentSafeZoneNumber") == nil and writes(player, "World2CurrentSafeZoneNumber") == 2, "Out of it: cleared once")
	pass("World2SafeZones writes the zone number on change only and still checks every 0.08 s")
end

----------------------------------------------------------------------
-- 5. CharacterStatsAdapter: the client owns the sprint's WalkSpeed
----------------------------------------------------------------------
do
	local source = read("src/common/ServerScriptService/Services/Stats/CharacterStatsAdapter.luau")
	local function adapterFor(config)
		local stats = { CalculateWalkSpeed = function(_, _, factors)
			return { ok = true, value = 90 * factors.worldMultiplier }
		end }
		return luau.load(source, { environment = env({
			typeof = function(value)
				return if type(value) == "table" and rawget(value, "IsInstance") then "Instance" else typeof(value)
			end,
			script = { IsInstance = true, Parent = { StatsService = stats } },
			require = function(target)
				return target
			end,
			game = { GetService = function()
				return { Shared = { Config = config } }
			end },
		}) })()
	end
	local function playerWith(boosting)
		local speeds = {}
		local humanoid = setmetatable({}, { __newindex = function(_, key, value)
			if key == "WalkSpeed" then
				table.insert(speeds, value)
			end
		end })
		local character = { IsInstance = true, FindFirstChildOfClass = function()
			return humanoid
		end }
		local player = attributed({ IsBoosting = boosting, WalkSpeedMode = "Red" })
		player.Character = character
		return player, speeds
	end
	local adapter = adapterFor({})
	local sprinter, sprintSpeeds = playerWith(true)
	assert(adapter.Update(sprinter, 1e9) == 90, "The selected speed")
	assert(#sprintSpeeds == 0, "Sprinting: the server does not write WalkSpeed over the client's boosted one")
	assert(sprinter:GetAttribute("RealWalkSpeedSelected") == 90, "...the client still gets the selected speed to boost")
	local runner, runSpeeds = playerWith(false)
	adapter.Update(runner, 1e9)
	assert(#runSpeeds == 1 and runSpeeds[1] == 90, "Not sprinting: the server sets WalkSpeed as before")
	-- Without the InstantMovementController the server applies the boost itself, as before.
	local legacy, legacySpeeds = playerWith(true)
	adapterFor({ InstantMovementControllerEnabled = false }).Update(legacy, 1e9)
	assert(#legacySpeeds == 1 and math.abs(legacySpeeds[1] - 90 * 1.7) < 1e-9, "No InstantMovementController: the server writes the boosted speed")
	-- The server's readers of WalkSpeed take the larger of it and the selected attribute.
	for _, reader in {
		{ "src/common/ServerScriptService/Services/MovementGuard.luau", "math.max(selected, humanoid and humanoid.WalkSpeed or 0)" },
		{ "src/common/ServerScriptService/Services/PadTouchService.luau", "math.max(selected, humanoid and humanoid.WalkSpeed or 0)" },
		{ "src/common/ServerScriptService/Services/PadTouchService.luau", "math.max(selected, humanoid.WalkSpeed)" },
	} do
		assert(string.find(read(reader[1]), reader[2], 1, true), reader[1] .. " must read WalkSpeed as " .. reader[2])
	end
	pass("the server leaves the sprint's WalkSpeed to the client, keeps writing it otherwise, and its readers take max(attribute, WalkSpeed)")
end

----------------------------------------------------------------------
-- 6. World 3's map Seats are switched off at start
----------------------------------------------------------------------
do
	local world3 = roblox.deserializePlace(fs.readFile(PlaceFiles.World3))
	local workspace = world3:GetService("Workspace")
	local source = read("src/worlds/World3/ServerScriptService/Gameplay/World3Hazards.server.luau")
	local chunk = between(source, "-- Performance: ensure all static map parts in Workspace are anchored", "\nlocal planes = {}", "anchoring pass")
	local function seats()
		local on, off = 0, 0
		for _, part in workspace:GetDescendants() do
			if part.ClassName == "Seat" or part.ClassName == "VehicleSeat" then
				if part.Disabled then
					off += 1
				else
					on += 1
				end
			end
		end
		return on, off
	end
	local before = seats()
	assert(before == 14, "The place carries 14 live Seats on the course (" .. before .. ")")
	luau.load(chunk, { environment = env({
		Workspace = workspace,
		Players = { GetPlayers = function()
			return {}
		end },
	}) })()
	local on, off = seats()
	assert(on == 0 and off == 14, string.format("After the start-up pass no Seat can sit a runner down (%d on, %d off)", on, off))
	pass("World 3's 14 map Seats are switched off at start")
end
