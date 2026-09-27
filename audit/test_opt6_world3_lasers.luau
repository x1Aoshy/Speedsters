-- audit/test_opt6_world3_lasers.luau
-- World 3 ran "stuck" (2026-09-21 report). What World 3 still did on top of the two shared
-- stalls (audit/test_opt6_server_stall.luau):
--   1. Old-World-1-map scripts ran in World 3 and looked for things the desert does not have
--      (Together1/2, SafeZoneN, WinPads_TO_PLACE, Zoom, ZoomsArena, Workspace.Laser, the red
--      ball): whole-Workspace scans for the first minute and a half of every server. Each now
--      returns at its World 3 gate, before any work.
--   2. Stage 10's rotating lasers: the server wrote every bar's CFrame ten times a second while
--      every client wrote it every frame, and a client took the bar's home from the part as it
--      streamed in (already turned by the server). The bars snapped back ten times a second and
--      the beam that killed was not the one on screen. Now the server publishes the home once
--      (World3LaserHome), never moves a bar, and kills by Shared.World3HazardMotion.LaserPose,
--      the pose every client draws.
--   3. World3StageTeleportService.GetNearestStage (MovementGuard and World3Hazards ask it for
--      every player ten times a second) measured the course line on every call; it is now
--      measured once per course read, with the same answers.
--
--   lune run audit/test_opt6_world3_lasers.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local PlaceFiles = require("./place_files")

local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local LAYOUT = "src/worlds/World3/ServerScriptService/Gameplay/World3HazardLayout.luau"
local MOTION = "src/worlds/World3/ReplicatedStorage/Shared/World3HazardMotion.luau"
local SERVER = "src/worlds/World3/ServerScriptService/Gameplay/World3Hazards.server.luau"
local CLIENT = "src/worlds/World3/StarterPlayer/StarterPlayerScripts/Gameplay/World3HazardsClient.client.luau"
local TELEPORT = "src/worlds/World3/ServerScriptService/Gameplay/World3StageTeleportService.luau"

local function read(path)
	return (string.gsub(fs.readFile(path), "\r\n", "\n"))
end
local function pass(text)
	print("PASS " .. text)
end

----------------------------------------------------------------------
-- 1. The old-World-1-map scripts return at their World 3 gate
----------------------------------------------------------------------
-- Each script runs against a world of stand-ins that write down every call made on them. In
-- World 3 the only calls allowed are the services and the Config lookup; the same script with
-- an old World 1 Config must get to real work (so the check is not empty).
do
	local GATED = {
		"src/common/ServerScriptService/Gameplay/StageDecor.server.luau",
		"src/common/ServerScriptService/Gameplay/TogetherController.server.luau",
		"src/common/ServerScriptService/Gameplay/WinPadStagePlacement.server.luau",
		"src/common/ServerScriptService/Gameplay/RotatingLaser.server.luau",
		"src/common/ServerScriptService/Bosses/ZoomBoss.server.luau",
		"src/common/StarterPlayer/StarterPlayerScripts/Gameplay/RotatingLaserVisual.client.luau",
		"src/common/StarterPlayer/StarterPlayerScripts/Gameplay/RedBallContact.client.luau",
		"src/common/StarterPlayer/StarterPlayerScripts/Gameplay/ZoomBossAnimation.client.luau",
		"src/common/StarterPlayer/StarterPlayerScripts/Gameplay/ZoomArenaAmbience.client.luau",
	}
	local CONFIG_PATH = "game.GetService(ReplicatedStorage).WaitForChild(Shared).WaitForChild(Config)"
	local function run(path, config)
		local log = {}
		local budget = 5000
		local make
		make = function(label)
			return setmetatable({ __label = label }, {
				__index = function(_, key)
					budget -= 1
					if budget <= 0 then
						error("budget")
					end
					return make(label .. "." .. tostring(key))
				end,
				__call = function(_, _receiver, argument)
					local called = label .. "(" .. tostring(argument) .. ")"
					table.insert(log, called)
					budget -= 1
					if budget <= 0 then
						error("budget")
					end
					return make(called)
				end,
			})
		end
		local env = setmetatable({
			game = make("game"),
			workspace = make("workspace"),
			script = make("script"),
			task = make("task"),
			Instance = make("Instance"),
			require = function(target)
				if type(target) == "table" and rawget(target, "__label") == CONFIG_PATH then
					return config
				end
				table.insert(log, "require")
				return make("required")
			end,
			print = function() end,
			warn = function() end,
		}, { __index = _G })
		for _, name in { "CFrame", "Vector3", "Vector2", "Color3", "UDim2", "UDim", "NumberRange", "NumberSequence", "NumberSequenceKeypoint", "ColorSequence", "ColorSequenceKeypoint", "Enum", "TweenInfo", "BrickColor", "PhysicalProperties" } do
			rawset(env, name, roblox[name] or make(name))
		end
		local ok, problem = pcall(function()
			luau.load(read(path), { environment = env })()
		end)
		local work = {}
		for _, called in log do
			local allowed = string.match(called, "^game%.GetService%(%w+%)$") ~= nil
				or called == "game.GetService(ReplicatedStorage).WaitForChild(Shared)"
				or called == CONFIG_PATH
			if not allowed then
				table.insert(work, called)
			end
		end
		return ok, problem, work
	end
	for _, path in GATED do
		local name = string.match(path, "([^/]+)%.%a+%.luau$")
		local ok, problem, work = run(path, { IsWorld3Place = true })
		assert(ok, name .. " must return cleanly in World 3: " .. tostring(problem))
		assert(#work == 0, name .. " does work in World 3 before returning: " .. table.concat(work, ", ", 1, math.min(#work, 5)))
		local _, stoppedBy, oldMapWork = run(path, {})
		assert(#oldMapWork > 0, name .. ": the old-map run should reach real work (the check would be empty); it stopped at " .. tostring(stoppedBy))
	end
	pass(#GATED .. " old-World-1-map scripts return at their World 3 gate before any work (and still work on the old map)")
end

----------------------------------------------------------------------
-- The real World 3 place, the stage service and the layout
----------------------------------------------------------------------
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
local Config = luau.load(read("src/common/ReplicatedStorage/Shared/Config.luau"), { environment = configEnv })()
assert(Config.IsWorld3Place == true, "The World 3 place's Config must be World 3")

local serverClock = 5000
local added, removing = signal(), signal()
local workspaceProxy = forward(realWorkspace, {
	DescendantAdded = added,
	DescendantRemoving = removing,
	GetServerTimeNow = function()
		return serverClock
	end,
	Raycast = function()
		return nil
	end,
	-- The server's Stage 10 fixes and its anchoring pass are not what this test is about.
	FindFirstChild = function()
		return nil
	end,
	GetDescendants = function()
		return {}
	end,
})
local modules = { Config = Config }
local sharedFolder = { WaitForChild = function(_, name)
	return { __module = name }
end }
local function loadStages(workspaceStandIn)
	local stageEnv = environment({
		game = { GetService = function(_, name)
			if name == "Workspace" then
				return workspaceStandIn
			end
			return { WaitForChild = function()
				return sharedFolder
			end }
		end },
		require = function(target)
			return modules[target.__module]
		end,
	})
	return luau.load(read(TELEPORT), { environment = stageEnv })()
end
-- The course service reads the real map (its own Workspace stand-in: every real call).
local stageWorkspace = forward(realWorkspace, { DescendantAdded = added, DescendantRemoving = removing })
local Stages = loadStages(stageWorkspace)
modules.World3StageTeleportService = Stages
local Motion = luau.load(read(MOTION), { environment = environment() })()
modules.World3HazardMotion = Motion
modules.BridgeRampPlan = {}
local Layout = luau.load(read(LAYOUT), { environment = environment() })()
local templates = place:GetService("ServerStorage"):FindFirstChild("World3HazardTemplates")

----------------------------------------------------------------------
-- 2. The server publishes each bar's home and never moves a bar
----------------------------------------------------------------------
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
			return { FindFirstChild = function()
				return selfHitRemote
			end }
		end
		return nil
	end,
}
-- Stand-ins for the map's lasers (and the other deadly parts) that write down every write.
local laserWrites = {}
local realLasers = {}
local function recorder(real, list)
	local fields = { Touched = signal(), Attributes = {}, Name = real.Name }
	function fields.SetAttribute(_, key, value)
		fields.Attributes[key] = value
	end
	function fields.GetAttribute(_, key)
		return fields.Attributes[key]
	end
	function fields.PivotTo()
		table.insert(list, "PivotTo")
	end
	return setmetatable({}, {
		__index = fields,
		__newindex = function(_, key, value)
			table.insert(list, key)
			fields[key] = value
		end,
	})
end
modules.World3HazardLayout = {
	BoundsOf = Layout.BoundsOf,
	Collapse = Layout.Collapse,
	Read = function(_, stages, templatesFolder)
		local read = Layout.Read(realWorkspace, stages, templatesFolder)
		for index, part in read.LaserParts do
			realLasers[index] = part
			read.LaserParts[index] = recorder(part, laserWrites)
		end
		for _, list in { read.CactusParts, read.VoidParts } do
			for index, part in list do
				list[index] = recorder(part, {})
			end
		end
		-- Nothing but the lasers is looked at here.
		read.CollapseParts = {}
		read.QuicksandParts = {}
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
		CollectionService = { AddTag = function() end },
		Players = playersService,
		ReplicatedStorage = replicated,
		RunService = { Heartbeat = heartbeat },
		ServerStorage = { FindFirstChild = function(_, name)
			return if name == "World3HazardTemplates" then templates else nil
		end },
		Workspace = workspaceProxy,
	})[name], name)
end }
local Server = luau.load(read(SERVER), { environment = serverEnv })()
assert(#Server.Layout.LaserParts == 2 and #Server.Layout.LaserHomes == 2, "Stage 10's two bars, each with its home")

local homes = {}
for index, part in Server.Layout.LaserParts do
	local home = part:GetAttribute("World3LaserHome")
	assert(typeof(home) == "CFrame" and home == realLasers[index].CFrame and Server.Layout.LaserHomes[index] == home,
		"Laser " .. index .. " publishes where it was built")
	homes[index] = { CFrame = home, Box = Server.Layout.LaserBoxes[index], Size = realLasers[index].Size }
	-- The modeller laid the bars on their side (their own Z is the world's up): the kill test
	-- must not take the bar's own axes for the world's.
	assert(math.abs(home.RightVector.Y) < 1e-3, "Laser " .. index .. " lies level")
end

local function makePlayer(position)
	local attributes = {}
	local humanoid = { Health = 100 }
	local root = { Position = position }
	local character = {}
	function character:FindFirstChildOfClass(class)
		return if class == "Humanoid" then humanoid else nil
	end
	function character:FindFirstChild(name)
		return if name == "HumanoidRootPart" then root else nil
	end
	function character:GetAttribute()
		return nil
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

do
	table.clear(laserWrites)
	-- A player on Stage 10 but nowhere near the bars, so the loop runs its whole course.
	makePlayer(Stages.GetStageReferencePosition(10) + Vector3.new(0, 3, 0))
	local settings = Motion.Laser
	for step = 1, math.ceil(settings.Period * 2 / 0.05) do
		serverClock = 5000 + step * 0.05
		heartbeat:Fire(0.05)
	end
	assert(#laserWrites == 0, "The server writes nothing to a laser while it runs: " .. table.concat(laserWrites, ", "))
	table.clear(players)
	pass("the server publishes each bar's home once (World3LaserHome) and writes nothing to a bar over two whole cycles")
end

----------------------------------------------------------------------
-- 3. The bar a client draws is the bar the server kills with, even one that streams in late
----------------------------------------------------------------------
do
	local clientSource = read(CLIENT)
	local a = assert(string.find(clientSource, "local LASER_LOOK = {", 1, true), "client chunk")
	local b = assert(string.find(clientSource, "----------------------------------------------------------------------\n-- Every frame", a, true), "client chunk end")
	local visuals = roblox.Instance.new("Folder")
	local settings = Motion.Laser
	local offSeconds = settings.Period - settings.OnSeconds - settings.WarnSeconds
	-- Laser 1 on, and well past the server's LaserServerLag.
	local onAt = offSeconds + settings.WarnSeconds + 0.9
	local beams = {}
	for index = 1, 2 do
		local beam = roblox.Instance.new("Part")
		beam.Name = "laser"
		beam.Size = homes[index].Size
		beam:SetAttribute("World3LaserIndex", index)
		beam:SetAttribute("World3LaserHome", Server.Layout.LaserParts[index]:GetAttribute("World3LaserHome"))
		-- It streams in part-way round: as the server used to leave it, or as any earlier write did.
		beam.CFrame = Motion.LaserPose(homes[index].CFrame, index, 3.3)
		beam.Parent = visuals
		beams[index] = beam
	end
	local arrived = beams[1].CFrame
	local drawLasers = luau.load(string.sub(clientSource, a, b - 1) .. "\nreturn drawLasers", { environment = environment({
		Motion = Motion,
		DRAW_DISTANCE = 700,
		CollectionService = {
			GetTagged = function(_, tag)
				assert(tag == "World3Laser", tag)
				return beams
			end,
			GetInstanceAddedSignal = function()
				return signal()
			end,
			GetInstanceRemovedSignal = function()
				return signal()
			end,
		},
	}) })()
	local root = { Position = homes[1].CFrame.Position + Vector3.new(0, 3, 30) }

	local function same(x, y)
		return (x.Position - y.Position).Magnitude < 1e-3
			and x.RightVector:Dot(y.RightVector) > 0.99999 and x.LookVector:Dot(y.LookVector) > 0.99999
	end
	for step = 0, 50 do
		local t = step * settings.Period / 25
		drawLasers(t, root)
		for index, beam in beams do
			assert(same(beam.CFrame, Motion.LaserPose(homes[index].CFrame, index, t)),
				string.format("Laser %d at %.2f s is drawn where the server's pose puts it", index, t))
			-- Points along the drawn bar touch it by the server's test (a root just under it, a
			-- head reaching up into it); points beside it, or clear above it, do not.
			local box = homes[index].Box
			local thickness = math.min(box.MaxX - box.MinX, box.MaxZ - box.MinZ)
			local height = box.MaxY - box.MinY
			local across = Vector3.new(0, 1, 0):Cross(beam.CFrame.RightVector).Unit
			local server = function(point)
				return Motion.LaserPoseTouches(homes[index].CFrame, box, index, t, point)
			end
			for _, along in { -60, -30, 0, 30, 60 } do
				local on = beam.CFrame * Vector3.new(along, 0, 0)
				assert(server(on) and server(on - Vector3.new(0, height / 2 + 2, 0)), "The drawn bar is where the server kills")
				assert(not server(on + across * (thickness / 2 + 2)) and not server(on - across * (thickness / 2 + 2)), "...not beside it")
				assert(not server(on + Vector3.new(0, height / 2 + 3.5, 0)), "...nor clear over it")
			end
		end
	end

	-- The whole server, at one moment: death under the drawn bar, none where the old client
	-- would have drawn it (turning about the pose it streamed in at).
	drawLasers(onAt, root)
	local drawnPoint = beams[1].CFrame * Vector3.new(40, 0, 0)
	local oldClientPoint = Motion.LaserPose(arrived, 1, onAt) * Vector3.new(40, 0, 0)
	assert((drawnPoint - oldClientPoint).Magnitude > 20, "The test's two points are far apart")
	local underDrawn = makePlayer(drawnPoint)
	local underOld = makePlayer(oldClientPoint)
	serverClock = 5000 + onAt
	Server.Step(0.1)
	assert(underDrawn.Humanoid.Health == 0 and underDrawn:GetAttribute("World3LastHazard") == "Laser", "Standing under the bar on screen dies")
	assert(underOld.Humanoid.Health > 0, "Standing where a late-streamed bar used to be drawn is safe: it is not there")
	table.clear(players)

	-- Without the published home (never expected), the part as it arrives is the home: the
	-- server no longer moves it, so that is where it was built.
	local bare = roblox.Instance.new("Part")
	bare.CFrame = homes[2].CFrame
	bare:SetAttribute("World3LaserIndex", 2)
	beams = { bare }
	local drawBare = luau.load(string.sub(clientSource, a, b - 1) .. "\nreturn drawLasers", { environment = environment({
		Motion = Motion,
		DRAW_DISTANCE = 700,
		CollectionService = {
			GetTagged = function()
				return beams
			end,
			GetInstanceAddedSignal = function()
				return signal()
			end,
			GetInstanceRemovedSignal = function()
				return signal()
			end,
		},
	}) })()
	bare.Parent = visuals
	drawBare(onAt, root)
	drawBare(onAt + 0.4, root)
	assert(same(bare.CFrame, Motion.LaserPose(homes[2].CFrame, 2, onAt + 0.4)), "A bar with no published home turns about where it arrived, not where it was last frame")
	pass("every frame, for both bars, the drawn beam is the server's deadly beam, also for a bar that streams in part-way round")
end

----------------------------------------------------------------------
-- 4. GetNearestStage: the course line measured once, the same answers on the real map
----------------------------------------------------------------------
do
	-- The line as it was measured before, on every call (reference copy of the old code).
	local function bounds(object)
		if not object or not object.Parent then
			return nil, nil
		end
		return object.CFrame, object.Size
	end
	local function topCentre(object)
		local cframe, size = bounds(object)
		return cframe and (cframe * CFrame.new(0, size.Y / 2, 0)).Position or nil
	end
	local function flat(v)
		return Vector3.new(v.X, 0, v.Z)
	end
	local function halfDepthAlong(object, direction)
		local cframe, size = bounds(object)
		if not cframe then
			return 0
		end
		return math.abs(cframe.RightVector:Dot(direction)) * size.X / 2
			+ math.abs(cframe.UpVector:Dot(direction)) * size.Y / 2
			+ math.abs(cframe.LookVector:Dot(direction)) * size.Z / 2
	end
	local function reference(position)
		local reached = 1
		local previous = Stages.GetStageReferencePosition(1)
		for stage = 2, Stages.StageCount do
			local markers = Stages.GetStageMarkers(stage)
			local checkpoint = markers and markers.Checkpoint
			local here = checkpoint and topCentre(checkpoint)
			if here then
				local from = previous or here
				local segment = flat(here - from)
				if segment.Magnitude > 1 then
					local direction = segment.Unit
					if flat(position - from):Dot(direction) >= segment.Magnitude - halfDepthAlong(checkpoint, direction) then
						reached = stage
					end
				end
				previous = here
			end
		end
		local at = Stages.GetStageReferencePosition(reached)
		return reached, at and flat(position - at).Magnitude or nil
	end

	local seed = 20260921
	local function random()
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	local points = {}
	for _ = 1, 8000 do
		local y = if random() < 0.1 then 37500 + random() * 50 else random() * 300
		table.insert(points, Vector3.new(random() * 420, y, 900 - random() * 9900))
	end
	-- Right on every checkpoint's reach too, where a rounding slip would show.
	for stage = 2, Stages.StageCount do
		local here = Stages.GetStageReferencePosition(stage)
		for dz = -30, 30, 0.5 do
			table.insert(points, here + Vector3.new(0, 3, dz))
		end
	end
	local function compare(label)
		local seen = {}
		for _, point in points do
			local a, ad = Stages.GetNearestStage(point)
			local b, bd = reference(point)
			assert(a == b and math.abs((ad or -1) - (bd or -1)) < 1e-6,
				string.format("%s: GetNearestStage(%s) = %s, %s; measured every call: %s, %s", label, tostring(point), tostring(a), tostring(ad), tostring(b), tostring(bd)))
			seen[a] = true
		end
		local stages = 0
		for _ in seen do
			stages += 1
		end
		assert(stages == Stages.StageCount, label .. ": the points cover every stage (" .. stages .. ")")
	end
	compare("first read")
	-- A piece of the course added (or removed) starts a new read, and the line with it.
	added:Fire(roblox.Instance.new("SpawnLocation"))
	compare("after a new read")
	local t0 = os.clock()
	for _, point in points do
		Stages.GetNearestStage(point)
	end
	local cached = os.clock() - t0
	t0 = os.clock()
	for _, point in points do
		reference(point)
	end
	local measured = os.clock() - t0
	pass(string.format("GetNearestStage gives the old answers on %d points of the real map, before and after a new course read (%.1f us a call, measured every call %.1f us, in Lune)",
		#points, cached / #points * 1e6, measured / #points * 1e6))
end
