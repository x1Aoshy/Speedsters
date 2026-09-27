-- test_world3_lobby_and_slide.luau
-- World 3 polish, against the built place and the sources:
--
--   1. The pyramid slide: going into the tunnel ragdolls the player through RagdollEvent,
--      the ramp is slippery, and the player stands up at the ramp's lower lip (sooner when
--      moving fast); the ragdoll's own timer is the safety net.
--   2. The group reward chest: World 2's "Rank Rewards" in the open sand north of the
--      leaderboards (Sung's review, 2026-09-18: beside the spawn it stood in front of the
--      leaderboards and the AFK Zone), on the floor, turned to the spawn as in World 2,
--      clear of the way to the stages and of the other lobby features, found by RankReward.
--   3. The spin wheel and the AFK circle stand on the lobby floor, clear of each other; the
--      wheel stands in the open sand north of the treadmills, not in front of them.
--   4. The spin wheel: the lobby wheel draws sibling by sibling (prizes over the slice
--      colours), on the new stand; the hub cap covers the centre without covering a prize.
--   5. The AFK Zone HUD sits above the level bar's Speed readout on every screen size.
--   6. Windows on join: the AFK offline earnings wait until no other menu (Update Log, then
--      the daily reward) has been open for a moment.
--   7. Walk speed: World 2 walks at x0.5 and World 3 at x0.25 (1/9 until the 2026-09-22 feel pass), two separate Config numbers
--      (2026-09-22: World 3 is no longer derived from World 2).
local fs = require("@lune/fs")
local PlaceFiles = require("./place_files")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local place = roblox.deserializePlace(fs.readFile(PlaceFiles.World3))
local workspace = place:GetService("Workspace")
local lobby = workspace.Lobby

local function near(a, b, tolerance)
	return math.abs(a - b) <= (tolerance or 1e-3)
end
local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- Config, as a place with PlaceWorldNumber `world` loads it.
local function loadConfig(world, source)
	local stub = { GetAttribute = function(_, name)
		return if name == "PlaceWorldNumber" then world else nil
	end, FindFirstChild = function()
		return nil
	end }
	local env = setmetatable({ workspace = stub, typeof = typeof, print = function() end, warn = function() end }, { __index = _G })
	for _, name in { "CFrame", "Vector3", "Color3", "UDim2", "UDim", "Vector2", "NumberRange", "ColorSequence", "ColorSequenceKeypoint", "NumberSequence", "NumberSequenceKeypoint", "BrickColor", "Enum", "Instance" } do
		env[name] = roblox[name]
	end
	env.game = { PlaceId = 0, GetService = function()
		return stub
	end }
	return luau.load(source or fs.readFile("src/common/ReplicatedStorage/Shared/Config.luau"), { environment = env })()
end
local Config = loadConfig(3)
assert(Config.IsWorld3Place == true, "The test loads World 3's Config")

-- The lobby floor's top under a point.
local function floorTopAt(x, z)
	local top = -math.huge
	for _, part in lobby:GetChildren() do
		if part:IsA("BasePart") and part.CFrame.UpVector.Y > 0.99 then
			local offset = part.CFrame:PointToObjectSpace(Vector3.new(x, part.CFrame.Position.Y, z))
			local partTop = part.CFrame.Position.Y + part.Size.Y / 2
			if math.abs(offset.X) <= part.Size.X / 2 and math.abs(offset.Z) <= part.Size.Z / 2 and partTop < 100 then
				top = math.max(top, partTop)
			end
		end
	end
	return top
end

-- 1. The pyramid slide -----------------------------------------------------------------
do
	local pyramid = workspace["Stage 6"].Pyramid.Pyramid
	local trigger = pyramid["Smooth Block Model"]
	local slideScript = trigger:FindFirstChild("Script")
	local sourcePath = "src/worlds/World3/Workspace/Stage 6/Pyramid/Pyramid/Smooth Block Model/Script.server.luau"
	assert(slideScript and slideScript.Source == fs.readFile(sourcePath), "The tunnel trigger runs the slide script")
	assert(not string.find(slideScript.Source, "Sit = true", 1, true), "Nobody is sat down any more")

	local ragdoll = place:GetService("StarterPlayer").StarterCharacterScripts:FindFirstChild("R6DeathRagdoll")
	assert(ragdoll, "Characters carry R6DeathRagdoll")
	for _, needle in { 'bindable.Name = "RagdollEvent"', 'action == "Ragdoll"', 'action == "Unragdoll"', "startRagdoll(duration)", "activeTimer = task.delay(duration" } do
		assert(string.find(ragdoll.Source, needle, 1, true), "R6DeathRagdoll: " .. needle)
	end

	-- The map: the floor ramp runs from the trigger at the top to the tunnel's end.
	local ramp = nil
	for _, part in pyramid:GetChildren() do
		if part:IsA("BasePart") and math.abs(part.CFrame.UpVector.Y) < 0.99 and (ramp == nil or part.CFrame.Position.Y < ramp.CFrame.Position.Y) then
			ramp = part
		end
	end
	assert(ramp, "The pyramid has its ramp")
	local frame = ramp.CFrame
	local down, halfLength, across, halfWidth = frame.RightVector, ramp.Size.X / 2, frame.LookVector, ramp.Size.Z / 2
	if math.abs(frame.LookVector.Y) > math.abs(frame.RightVector.Y) then
		down, halfLength, across, halfWidth = frame.LookVector, ramp.Size.Z / 2, frame.RightVector, ramp.Size.X / 2
	end
	if down.Y > 0 then
		down = down * -1
	end
	local normal = if frame.UpVector.Y > 0 then frame.UpVector else frame.UpVector * -1
	local centre = frame.Position
	local top, lip = centre - down * halfLength, centre + down * halfLength
	assert(halfLength > 60 and down.Y < -0.3, "The ramp is long and steep")
	assert(flat(top - trigger.CFrame.Position).Magnitude < 10 and math.abs(top.Y - (trigger.CFrame.Position.Y - trigger.Size.Y / 2)) < 4,
		"The trigger stands across the ramp's top")
	assert(lip.Y > 70 and lip.Y < 77 and lip.Z < -3330, "The ramp's lower lip is the tunnel's end")

	-- The script, with a clock, Players, RunService and characters of its own.
	local now = 0
	local touched, heartbeat = nil, nil
	local writes = {}
	local proxies = {}
	local function proxy(real)
		if proxies[real] then
			return proxies[real]
		end
		local object = setmetatable({}, {
			__index = function(_, key)
				if writes[real] and writes[real][key] ~= nil then
					return writes[real][key]
				elseif key == "Touched" then
					return { Connect = function(_, callback)
						touched = callback
					end }
				elseif key == "Parent" then
					return proxy(real.Parent)
				elseif key == "CustomPhysicalProperties" then
					return nil
				elseif key == "GetChildren" then
					return function()
						local children = {}
						for _, child in real:GetChildren() do
							table.insert(children, proxy(child))
						end
						return children
					end
				end
				local value = real[key]
				if type(value) == "function" then
					return function(_, ...)
						return value(real, ...)
					end
				end
				return value
			end,
			__newindex = function(_, key, value)
				writes[real] = writes[real] or {}
				writes[real][key] = value
			end,
		})
		proxies[real] = object
		return object
	end
	local players = {}
	local env = setmetatable({
		script = { Parent = proxy(trigger) },
		os = { clock = function()
			return now
		end },
		Vector3 = Vector3,
		PhysicalProperties = { new = function(first, friction, elasticity, frictionWeight, elasticityWeight)
			if type(first) ~= "number" then
				return { Density = 0.7, Friction = 0.3, Elasticity = 0.5, FrictionWeight = 1, ElasticityWeight = 1 }
			end
			return { Density = first, Friction = friction, Elasticity = elasticity, FrictionWeight = frictionWeight, ElasticityWeight = elasticityWeight }
		end },
		game = { GetService = function(_, name)
			if name == "Players" then
				return { GetPlayerFromCharacter = function(_, character)
					return players[character]
				end }
			elseif name == "RunService" then
				return { Heartbeat = { Connect = function(_, callback)
					heartbeat = callback
				end } }
			end
			error("unexpected service " .. name)
		end },
	}, { __index = _G })
	luau.load(slideScript.Source, { environment = env })()
	assert(touched and heartbeat, "The script listens to the trigger and to Heartbeat")

	local physical = writes[ramp] and writes[ramp].CustomPhysicalProperties
	assert(physical and physical.Friction <= 0.05 and physical.FrictionWeight >= 50, "The ramp is slippery, and its friction wins")

	local function newCharacter(options)
		options = options or {}
		local fired, attributes = {}, {}
		local root = { CFrame = CFrame.new(top + normal * 3), AssemblyLinearVelocity = Vector3.new(0, 0, 0) }
		local humanoid = { Health = options.Health or 100 }
		local event = { IsA = function(_, className)
			return className == "BindableEvent"
		end, Fire = function(_, ...)
			table.insert(fired, { ... })
		end }
		local character = { Parent = true, Fired = fired, Attributes = attributes }
		function character:FindFirstChildOfClass(className)
			return if className == "Humanoid" then humanoid else nil
		end
		function character:FindFirstChild(name)
			if name == "HumanoidRootPart" then
				return root
			elseif name == "RagdollEvent" and options.NoEvent ~= true then
				return event
			end
			return nil
		end
		function character:SetAttribute(name, value)
			attributes[name] = value
		end
		if options.Player ~= false then
			players[character] = { Name = "Player" }
		end
		character.Hit = { FindFirstAncestorOfClass = function(_, className)
			return if className == "Model" then character else nil
		end }
		character.At = function(along, speed, sideways)
			root.CFrame = CFrame.new(centre + down * along + normal * 3 + across * (sideways or 0))
			root.AssemblyLinearVelocity = down * (speed or 0)
		end
		return character
	end
	local function step(seconds)
		local target = now + seconds
		repeat
			now = math.min(target, now + 1 / 60)
			heartbeat(1 / 60)
		until now >= target
	end

	local a = newCharacter()
	touched(a.Hit)
	assert(#a.Fired == 1 and a.Fired[1][1] == "Ragdoll" and a.Fired[1][2] >= 10 and a.Fired[1][2] <= 12,
		"Going in ragdolls the player, with a 10-12 second safety timer")
	touched(a.Hit)
	step(0.1)
	assert(#a.Fired == 1, "Touching again while sliding does nothing")
	a.At(0, 60)
	step(0.5)
	a.At(halfLength - 10, 0)
	step(0.2)
	assert(#a.Fired == 1, "Nobody stands up halfway, or 10 studs from the lip when stopped")
	a.At(halfLength - 10, 100)
	step(1 / 60)
	assert(#a.Fired == 2 and a.Fired[2][1] == "Unragdoll", "At 100 studs/s, 10 studs from the lip is the lip already")
	step(0.5)
	touched(a.Hit)
	assert(#a.Fired == 2, "Touching the trigger right after standing up does nothing")
	step(2)
	touched(a.Hit)
	assert(#a.Fired == 3 and a.Fired[3][1] == "Ragdoll", "Later, the tunnel ragdolls again")
	a.At(halfLength + 20, 0, halfWidth + 30)
	step(0.2)
	assert(#a.Fired == 3, "Far off to the side of the ramp is not its lip")
	a.At(0, 0)
	step(12)
	a.At(halfLength - 1, 0)
	step(0.2)
	assert(#a.Fired == 3, "After the safety timer the script lets go (the ragdoll stood them up itself)")

	local b = newCharacter()
	touched(b.Hit)
	b.At(halfLength - 1, 0)
	step(1 / 60)
	assert(#b.Fired == 2 and b.Fired[2][1] == "Unragdoll", "Reaching the lip stands the player up")

	local npc = newCharacter({ Player = false })
	touched(npc.Hit)
	local dead = newCharacter({ Health = 0 })
	touched(dead.Hit)
	assert(#npc.Fired == 0 and #dead.Fired == 0, "Only living players slide")

	local bare = newCharacter({ NoEvent = true })
	touched(bare.Hit)
	assert(bare.Attributes.Ragdolled == true and bare.Attributes.RagdollDuration >= 10, "Without the event, the Ragdolled attribute does it")
	bare.At(halfLength - 1, 0)
	step(1 / 60)
	assert(bare.Attributes.Ragdolled == false, "...and stands them up at the lip")
	print("PASS the pyramid tunnel ragdolls the player, who slides down a slippery ramp and stands up at its lip (safety timer 10-12 s)")
end

-- 2. The group reward chest ---------------------------------------------------------------
local spawnPosition = lobby.SpawnLocation.CFrame.Position
local exit = lobby:FindFirstChild("Union")
assert(exit and exit:IsA("BasePart"), "The lobby's way out to the stages is there")
-- Distance from a point to the walk from the spawn to the way out.
local function offWalk(point)
	local from, to = flat(spawnPosition), flat(exit.CFrame.Position)
	local along = math.clamp((flat(point) - from):Dot((to - from).Unit), 0, (to - from).Magnitude)
	return (flat(point) - (from + (to - from).Unit * along)).Magnitude
end
local function bounds(model)
	local low, high = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local cframe, half = part.CFrame, part.Size / 2
			local extent = Vector3.new(
				math.abs(cframe.RightVector.X) * half.X + math.abs(cframe.UpVector.X) * half.Y + math.abs(cframe.LookVector.X) * half.Z,
				math.abs(cframe.RightVector.Y) * half.X + math.abs(cframe.UpVector.Y) * half.Y + math.abs(cframe.LookVector.Y) * half.Z,
				math.abs(cframe.RightVector.Z) * half.X + math.abs(cframe.UpVector.Z) * half.Y + math.abs(cframe.LookVector.Z) * half.Z)
			low = Vector3.new(math.min(low.X, cframe.Position.X - extent.X), math.min(low.Y, cframe.Position.Y - extent.Y), math.min(low.Z, cframe.Position.Z - extent.Z))
			high = Vector3.new(math.max(high.X, cframe.Position.X + extent.X), math.max(high.Y, cframe.Position.Y + extent.Y), math.max(high.Z, cframe.Position.Z + extent.Z))
		end
	end
	return low, high
end
local padPosition
do
	local rewards = lobby:FindFirstChild("Rank Rewards")
	assert(rewards and rewards:IsA("Model"), "The lobby has the group reward chest")
	local named = 0
	for _, descendant in workspace:GetDescendants() do
		local key = string.lower((string.gsub(descendant.Name, "[%s_%-]", "")))
		if key == "rankrewards" or key == "rankreward" or key == "groupreward" or key == "grouprewards" then
			named += 1
		end
	end
	assert(named == 1 and workspace:FindFirstChild("Rank Rewards", true) == rewards, "RankReward finds exactly this chest")
	for _, descendant in rewards:GetDescendants() do
		assert(not descendant:IsA("LuaSourceContainer"), "The chest carries no scripts")
	end
	local pad = rewards:FindFirstChild("Pad")
	local chest = rewards:FindFirstChild("Chest")
	assert(pad and pad:IsA("BasePart") and chest and chest:IsA("BasePart"), "The chest has its Pad and its Chest")
	padPosition = pad.CFrame.Position
	local floorTop = floorTopAt(padPosition.X, padPosition.Z)
	assert(near(floorTop, 95.606, 0.01) and near(padPosition.Y - pad.Size.Y / 2, floorTop, 0.02), "The pad lies on the lobby floor")
	local fromSpawn = flat(padPosition - spawnPosition).Magnitude
	assert(fromSpawn > 25 and fromSpawn < 200, "The chest is in the lobby")

	local low, high = bounds(rewards)
	local corner = math.max(high.X - low.X, high.Z - low.Z) / 2
	assert(offWalk(padPosition) > corner + 2, "The chest is clear of the walk from the spawn to the stages")
	local leaderboardLow, leaderboardHigh = bounds(lobby.Leaderboardarea)
	assert(low.X > leaderboardHigh.X + 2 or high.Z < leaderboardLow.Z, "The chest is clear of the leaderboards")
	-- Nothing stands in front of the leaderboards (their faces look out to +X): they are
	-- seen whole and walked up to, and the AFK circle there is free.
	local inFront = low.X < leaderboardHigh.X + 60 and high.Z > leaderboardLow.Z and low.Z < leaderboardHigh.Z
	assert(not inFront, "The chest is not in front of the leaderboards")
	assert(high.Z < leaderboardLow.Z - 5, "It stands in the open sand north of them")
	local portalLow = bounds(lobby["world 2 portal"])
	assert(high.Z < portalLow.Z - 5, "The chest is clear of the portal")
	local afk = Config.AfkZone.WorldPlacement.World3
	assert(flat(padPosition - afk).Magnitude > Config.AfkZone.SpotRadius + corner + 2, "The chest is clear of the AFK spot")
	local wheel = Config.SpinWheel.WorldPlacement.World3.Position
	assert(flat(padPosition - wheel).Magnitude > corner + 12, "The chest is clear of the spin wheel")

	-- Turned to the spawn as World 2's is: the chest sits where it sits in World 2, seen
	-- from the pad looking at the spawn.
	local manifest = require("@lune/serde").decode("json", fs.readFile("src/manifest.json"))
	local world2 = roblox.deserializePlace(fs.readFile(manifest.worlds.World2.input)):GetService("Workspace")
	local world2Rewards = world2:FindFirstChild("Rank Rewards", true)
	local function facing(position, towards)
		local direction = flat(towards - position).Unit
		return CFrame.fromMatrix(position, Vector3.new(-direction.Z, 0, direction.X), Vector3.new(0, 1, 0))
	end
	local before = facing(world2Rewards.Pad.CFrame.Position, world2.Spawn.CFrame.Position):PointToObjectSpace(world2Rewards.Chest.CFrame.Position)
	local after = facing(padPosition, spawnPosition):PointToObjectSpace(chest.CFrame.Position)
	assert((before - after).Magnitude < 0.05, "The chest faces the spawn as in World 2")

	local server = place:GetService("ServerScriptService"):FindFirstChild("RankReward", true)
	local client = place:GetService("StarterPlayer"):FindFirstChild("RankRewardPanel", true)
	assert(server and server:IsA("Script") and client and client:IsA("LocalScript"), "World 3 runs RankReward and its panel")
	assert(string.find(server.Source, 'Workspace:FindFirstChild("Rank Rewards", true)', 1, true), "RankReward looks the chest up by name")
	print(string.format("PASS the group reward chest stands in the open sand north of the leaderboards (%.0f studs from the spawn), on the floor, facing it, clear of the path and the lobby features", fromSpawn))
end

-- 3. The spin wheel and the AFK spot in the lobby ---------------------------------------
do
	local wheel = Config.SpinWheel.WorldPlacement.World3
	local afk = Config.AfkZone.WorldPlacement.World3
	assert(near(wheel.Position.X, 345) and near(wheel.Position.Z, 390) and near(afk.X, 205) and near(afk.Z, 490), "The requested places")
	-- Not in front of the treadmills (their runners face -X, toward the lobby): the way to
	-- them and the "Train Speed" wall over them stay clear.
	local treadmillLow, treadmillHigh = bounds(lobby.Treadmillarea)
	local frontOfTreadmills = wheel.Position.X > treadmillLow.X - 60 and wheel.Position.X < treadmillHigh.X
		and wheel.Position.Z > treadmillLow.Z - 10 and wheel.Position.Z < treadmillHigh.Z + 10
	assert(not frontOfTreadmills, "The wheel is not in front of the treadmills")
	assert(wheel.Position.Z < treadmillLow.Z - 20, "It stands in the open sand north of them")
	assert(near(wheel.Position.Y, floorTopAt(wheel.Position.X, wheel.Position.Z), 0.02), "The wheel stands on the floor")
	assert(near(afk.Y, floorTopAt(afk.X, afk.Z), 0.02), "The AFK spot lies on the floor")
	assert(flat(wheel.Face - spawnPosition).Magnitude < 1, "The wheel faces the spawn")
	assert(flat(wheel.Position - afk).Magnitude > Config.AfkZone.SpotRadius + 20, "They are well apart")
	assert(offWalk(afk) > Config.AfkZone.SpotRadius and offWalk(wheel.Position) > 15, "Neither is in the way to the stages")
	for _, path in { "src/common/StarterPlayer/StarterPlayerScripts/UI/SpinWheelController.client.luau", "src/common/ServerScriptService/Social/AfkZoneService.server.luau" } do
		assert(string.find(fs.readFile(path), 'elseif Config.IsWorld3Place then "World3"', 1, true), path .. " uses the World 3 placement")
	end
	print("PASS the spin wheel (north of the treadmills) and the AFK spot stand on the World 3 lobby floor, apart and out of the way")
end

-- 4. The spin wheel ------------------------------------------------------------------------
do
	local controller = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/SpinWheelController.client.luau")
	local spec = fs.readFile("src/common/ReplicatedStorage/Shared/DesignerUi/SpinWheelGui.luau")
	assert(string.find(spec, "ZIndexBehavior = Enum.ZIndexBehavior.Sibling", 1, true), "The designer's panel draws sibling by sibling")
	assert(string.find(controller, "surface.ZIndexBehavior = gui.ZIndexBehavior", 1, true), "The lobby wheel draws like the panel, so its prizes show over the colours")
	assert(not string.find(controller, 'part("Post"', 1, true) and not string.find(controller, 'part("Base"', 1, true), "The white post and the plain base are gone")
	for _, name in { '"Trim"', '"Plinth"', '"LeftLeg"', '"RightLeg"', '"Axle"', '"GoldRim"', '"NavyRim"', "texture.Texture = SpinWheelLayout.StudTexture" } do
		assert(string.find(controller, name, 1, true), "The lobby stand has " .. name)
	end

	local SpinWheelLayout = require("../src/common/ReplicatedStorage/Shared/SpinWheelLayout")
	local GuiGeometry = require("../src/common/ReplicatedStorage/Shared/GuiGeometry")
	local roots = roblox.deserializeModel(fs.readFile("design/ui/SpinWheelAndEarnings.rbxm"))
	local holder = roots[1]:FindFirstChild("SpinWheel"):FindFirstChild("Frame")
	local measure = SpinWheelLayout.Measure(holder)
	local cap = SpinWheelLayout.HubCap(measure)
	assert(near(cap.X * measure.Ratio, measure.WheelCenter.x) and near(cap.Y, measure.WheelCenter.y), "The cap is centred on the wheel's turning centre")
	assert(near(cap.Width * measure.Ratio, cap.Height) and near(cap.Height, 2 * cap.Radius), "The cap is round")
	local artOffset = math.sqrt((measure.ArtCenter.x - measure.WheelWidth / 2) ^ 2 + (measure.ArtCenter.y - measure.WheelHeight / 2) ^ 2)
	assert(cap.Radius * 0.78 > measure.ArtRadius * SpinWheelLayout.DotRadiusShare + artOffset, "The cap's gold face covers the old dot however the wheel turns")
	local middle = { x = measure.WheelWidth / 2, y = measure.WheelHeight / 2 }
	for _, slot in measure.Slots do
		for _, marker in { slot.Icon, slot.Label } do
			if marker then
				local centre = GuiGeometry.CenterIn(measure.Wheel, marker, measure.WheelWidth, measure.WheelHeight)
				local width, height = GuiGeometry.SizeIn(measure.Wheel, marker, measure.WheelWidth, measure.WheelHeight)
				local distance = math.sqrt((centre.x - middle.x) ^ 2 + (centre.y - middle.y) ^ 2)
				assert(distance - math.max(width, height) / 2 > cap.Radius * 1.08, "The cap covers no prize: " .. marker:GetFullName())
			end
		end
	end
	-- The cap is one of the panel's extras (saved in the places, made where missing).
	local extras = fs.readFile("src/common/ReplicatedStorage/Shared/SpinWheelExtras.luau")
	local capStart = assert(string.find(extras, 'holder.Name = "HubCap"', 1, true), "The panel's extras build the hub cap")
	assert(string.find(extras, "holder.ZIndex = arrow.ZIndex - 1", 1, true), "The cap sits under the arrow")
	assert(string.find(extras, "studs.Image = Layout.StudTexture", capStart, true)
		and string.find(extras, 'circle("Shadow"', capStart, true)
		and string.find(extras, 'circle("Rim"', capStart, true), "The cap has studs, a rim and a shadow")
	local decorated = assert(string.find(controller, "SpinWheelExtras.Decorate(gui", 1, true))
	assert(decorated < assert(string.find(controller, "wheelHolder:Clone()", 1, true)), "The lobby wheel's copy of the panel has the cap too")
	print("PASS the lobby wheel shows its prizes over the colours on a studded stand; the hub cap covers the centre and no prize")
end

-- 5. The AFK Zone HUD and the level bar's Speed readout ------------------------------------
do
	local source = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/AfkZoneController.client.luau")
	local py = tonumber(string.match(source, "hudLabel%.Position = UDim2%.new%(0%.5, 0, ([%d%.]+), 0%)"))
	local sx, sy = string.match(source, "hudLabel%.Size = UDim2%.new%(([%d%.]+), 0, ([%d%.]+), 0%)")
	sx, sy = tonumber(sx), tonumber(sy)
	assert(py == 0.655 and sx == 0.32 and sy == 0.025, "The HUD's requested place and size")
	assert(string.find(source, "hudLabel.AnchorPoint = Vector2.new(0.5, 1)", 1, true), "The HUD hangs from its bottom edge")

	-- Where a GuiObject is drawn inside a parent rect, with its aspect ratio constraint.
	local function rectIn(object, px, py0, pw, ph)
		local w = object.Size.X.Scale * pw + object.Size.X.Offset
		local h = object.Size.Y.Scale * ph + object.Size.Y.Offset
		local constraint = object:FindFirstChildOfClass("UIAspectRatioConstraint")
		if constraint then
			if w / h > constraint.AspectRatio then
				w = h * constraint.AspectRatio
			else
				h = w / constraint.AspectRatio
			end
		end
		local x = px + object.Position.X.Scale * pw + object.Position.X.Offset - object.AnchorPoint.X * w
		local y = py0 + object.Position.Y.Scale * ph + object.Position.Y.Offset - object.AnchorPoint.Y * h
		return x, y, w, h
	end
	local bar = place:GetService("StarterGui").Mainhud.LevelProgressBar
	for _, screen in { { 1920, 1080 }, { 1366, 768 }, { 1280, 1024 }, { 844, 390 } } do
		local x, y, w, h = rectIn(bar, 0, 0, screen[1], screen[2])
		x, y, w, h = rectIn(bar.Frame, x, y, w, h)
		local _, speedTop = rectIn(bar.Frame.Speed, x, y, w, h)
		local hudBottom = py * screen[2]
		local hudTop = hudBottom - sy * screen[2]
		assert(hudBottom < speedTop - 4 and hudTop > 0, string.format("On %dx%d the HUD (%.0f-%.0f) clears Speed (top %.0f)", screen[1], screen[2], hudTop, hudBottom, speedTop))
	end
	print("PASS the AFK Zone HUD sits above the level bar's Speed readout on 1920x1080, 1366x768, 1280x1024 and 844x390")
end

-- 6. Windows on join ------------------------------------------------------------------------
do
	local function bindable()
		return { Name = "", Event = { Connect = function() end }, Fire = function() end, IsA = function(_, className)
			return className == "BindableEvent"
		end }
	end
	local playerScripts = { GetChildren = function()
		return {}
	end }
	local localPlayer = { WaitForChild = function()
		return playerScripts
	end, FindFirstChild = function()
		return nil
	end }
	local menuEnv = setmetatable({
		game = { GetService = function()
			return { LocalPlayer = localPlayer }
		end },
		Instance = { new = function()
			return bindable()
		end },
	}, { __index = _G })
	local MenuEvents = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/MenuEvents.luau"), { environment = menuEnv })()
	local open = { UpdateLogs = false, Daily = false, Afk = false }
	for name in open do
		MenuEvents.MarkReady(name, function()
			return open[name]
		end)
	end
	assert(MenuEvents.AnyOpen("Afk") == false, "Nothing is open")
	open.UpdateLogs = true
	assert(MenuEvents.AnyOpen("Afk") == true, "The Update Log counts")
	open.UpdateLogs, open.Afk = false, true
	assert(MenuEvents.AnyOpen("Afk") == false and MenuEvents.AnyOpen() == true, "The AFK window itself does not")
	open.Afk = false

	-- The AFK controller's offer, run on a simulated clock.
	local afkSource = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/AfkRewardsController.client.luau")
	local first = assert(string.find(afkSource, "local OFFER_QUIET_SECONDS", 1, true))
	local last = assert(string.find(afkSource, "local function closePanel()", first, true))
	assert(string.find(afkSource, "local offerOfflineEarnings", 1, true) < first, "The offer is declared before the status handler uses it")
	local handler = assert(string.find(afkSource, "AfkRewardsUpdate.OnClientEvent:Connect", 1, true))
	local handlerEnd = assert(string.find(afkSource, "\nend)", handler, true))
	local handlerSource = string.sub(afkSource, handler, handlerEnd)
	assert(string.find(handlerSource, "offerOfflineEarnings()", 1, true) and not string.find(handlerSource, "openPanel(false)", 1, true),
		"Offline earnings are offered, not opened straight away")

	local now = 0
	local sleeping = {}
	local opened = 0
	-- The controller's own locals, isOpen and offline, live in `state` here (luau.load copies
	-- the environment, so the chunk reads them through a table).
	local state = { isOpen = false, offline = { eligible = true } }
	local offerEnv = setmetatable({
		MenuEvents = MenuEvents,
		state = state,
		openPanel = function()
			opened += 1
			state.isOpen = true
		end,
		os = { clock = function()
			return now
		end },
		task = {
			spawn = function(callback)
				local thread = coroutine.create(callback)
				local ok, wait = coroutine.resume(thread)
				assert(ok, wait)
				if coroutine.status(thread) == "suspended" then
					table.insert(sleeping, { Thread = thread, At = now + (wait or 0) })
				end
			end,
			wait = function(seconds)
				return coroutine.yield(seconds)
			end,
		},
	}, { __index = _G })
	local offerSource = string.gsub(string.gsub(string.sub(afkSource, first, last - 1), "%f[%w_]isOpen%f[^%w_]", "state.isOpen"), "%f[%w_]offline%f[^%w_]", "state.offline")
	local offer = luau.load(offerSource .. "\nreturn offerOfflineEarnings", { environment = offerEnv })()
	assert(type(offer) == "function", "The offer loads")
	local function run(seconds)
		local target = now + seconds
		while now < target do
			now = math.min(target, now + 0.05)
			for index = #sleeping, 1, -1 do
				local entry = sleeping[index]
				if now >= entry.At - 1e-9 then
					table.remove(sleeping, index)
					local ok, wait = coroutine.resume(entry.Thread)
					assert(ok, wait)
					if coroutine.status(entry.Thread) == "suspended" then
						table.insert(sleeping, { Thread = entry.Thread, At = now + (wait or 0) })
					end
				end
			end
		end
	end

	-- Join: the Update Log opens at 0.25 s, the AFK status arrives at 2.6 s.
	run(0.25)
	open.UpdateLogs = true
	run(2.35)
	offer()
	run(20)
	assert(opened == 0, "Not over the Update Log")
	open.UpdateLogs = false
	run(0.2)
	open.Daily = true -- closing the Update Log hands over to the daily reward
	run(10)
	assert(opened == 0, "Not over the daily reward either")
	open.Daily = false
	run(1)
	assert(opened == 0, "Not the moment the last window closes")
	run(0.5)
	assert(opened == 1, "Once nothing has been open for a moment, the earnings open")
	run(5)
	assert(opened == 1, "Only once")

	-- A newer status replaces the waiting offer; a claim meanwhile cancels it.
	state.isOpen, opened = false, 0
	open.Shop = true
	MenuEvents.MarkReady("Shop", function()
		return open.Shop
	end)
	offer()
	run(1)
	offer()
	open.Shop = false
	run(3)
	assert(opened == 1, "Two offers open the window once")
	state.isOpen, opened = false, 0
	offer()
	state.offline.eligible = false
	run(3)
	assert(opened == 0, "Nothing to offer, nothing opens")

	local updateLogs = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/UpdateLogsController.client.luau")
	assert(string.find(updateLogs, 'MenuEvents.MarkReady("UpdateLogs"', 1, true) and string.find(updateLogs, 'MenuEvents.Get("OpenDailyPanel"):Fire("Open")', 1, true),
		"The Update Log reports itself open and hands over to the daily reward")
	assert(string.find(fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/DailyRewardController.client.luau"), 'MenuEvents.MarkReady("Daily"', 1, true),
		"The daily reward reports itself open")
	print("PASS on join the Update Log opens first, then the daily reward, and the AFK earnings only after both are closed")
end

-- 7. Walk speed per world ---------------------------------------------------------------------
do
	local configs = { loadConfig(1), loadConfig(2), Config }
	assert(configs[1].IsWorld2Place ~= true and configs[1].IsWorld3Place ~= true and configs[2].IsWorld2Place == true, "Each Config knows its world")
	assert(near(configs[1].WorldWalkSpeedMultiplier, 1, 1e-9) and near(configs[2].WorldWalkSpeedMultiplier, 0.5, 1e-9) and near(configs[3].WorldWalkSpeedMultiplier, 0.25, 1e-9),
		"World 1 walks at x1, World 2 at x0.5 (the owner's 2026-09-22 choice), World 3 at x0.25")
	-- World 3 keeps its own tuning: retuning World 2 must not move it.
	local configSource = fs.readFile("src/common/ReplicatedStorage/Shared/Config.luau")
	local patched, count = string.gsub(configSource, "Config%.World2WalkSpeedMultiplier = 0%.5", "Config.World2WalkSpeedMultiplier = 0.9")
	assert(count == 1, "Config sets World2WalkSpeedMultiplier once")
	local retuned = loadConfig(3, patched)
	assert(near(retuned.World2WalkSpeedMultiplier, 0.9, 1e-9) and near(retuned.World3WalkSpeedMultiplier, 0.25, 1e-9) and near(retuned.WorldWalkSpeedMultiplier, 0.25, 1e-9),
		"World 3 stays at x0.25 when World 2 changes")
	assert(near(loadConfig(2, patched).WorldWalkSpeedMultiplier, 0.9, 1e-9), "World 2 follows its own number")

	local adapterSource = fs.readFile("src/common/ServerScriptService/Services/Stats/CharacterStatsAdapter.luau")
	local function adapterFor(config)
		local env = setmetatable({
			typeof = function()
				return "Instance"
			end,
			script = { Parent = { StatsService = {} } },
			require = function(target)
				return target
			end,
			game = { GetService = function()
				return { Shared = { Config = config } }
			end },
		}, { __index = _G })
		return luau.load(adapterSource, { environment = env })()
	end
	local function playerIn(world)
		return { GetAttribute = function(_, name)
			return if name == "CurrentWorld" then world else nil
		end }
	end
	for index, expected in { 1, 0.5, 0.25 } do
		local adapter = adapterFor(configs[index])
		assert(near(adapter.GetMovementFactors(playerIn(nil)).worldMultiplier, expected, 1e-9), "World " .. index .. "'s movement factor")
	end
	assert(near(adapterFor(configs[1]).GetMovementFactors(playerIn(3)).worldMultiplier, 0.25, 1e-9), "A player marked in World 3 walks at x0.25")

	local playerStats = fs.readFile("src/common/ServerScriptService/Progression/PlayerStats.server.luau")
	local _, uses = string.gsub(playerStats, "tonumber%(Config%.WorldWalkSpeedMultiplier%)", "")
	assert(uses == 2 and not string.find(playerStats, "World2WalkSpeedMultiplier", 1, true),
		"PlayerStats scales walk speed and WorldMovementSpeedScale by the place's own world multiplier")
	print("PASS walk speed: World 1 x1, World 2 x0.5, World 3 x0.25 (its own number, not derived from World 2)")
end
