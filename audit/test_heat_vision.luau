-- test_heat_vision.luau
-- Superman's Heat Vision Trail (2026-09-18):
--   1. HeatVisionMath: the path runs level from the feet toward the aim, MinLength..MaxLength
--      long (40 at most), short of a wall, in slabs that meet edge to edge.
--   2. The real HeatVisionService on a stand-in world (a floor at y 0, a wall ahead): only
--      the Superman skin fires it; it melts the path from the feet toward the aim, drawn by
--      beams from the eyes; it never goes through a wall; one every 18 s (a blocked shot
--      costs nothing); it lasts 3.5 s, then cools and fades.
--   3. The client: R / Y and the HUD button, aiming at the mouse, a tapped point or ahead.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")

local V3 = rb.Vector3
local function has(source, needle, message)
	assert(string.find(source, needle, 1, true), message)
end
local function near(a, b, tolerance)
	return math.abs(a - b) <= (tolerance or 1e-3)
end
local function signal()
	local s = { listeners = {} }
	function s:Connect(fn)
		table.insert(self.listeners, fn)
		return { Disconnect = function() end }
	end
	function s:Fire(...)
		for _, fn in table.clone(self.listeners) do
			fn(...)
		end
	end
	return s
end

local configSource = fs.readFile("src/common/ReplicatedStorage/Shared/Config.luau")
local block = assert(string.match(configSource, "Config%.AbilityHeatVision = (%b{})"), "Config.AbilityHeatVision")
local Config = { AbilityHeatVision = luau.load("return " .. block)() }
local mathEnv = setmetatable({ Vector3 = V3, CFrame = rb.CFrame }, { __index = _G })
local HeatVisionMath = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/HeatVisionMath.luau"), { environment = mathEnv })()
local settings = HeatVisionMath.Settings(Config)

----------------------------------------------------------------------
-- 1. The numbers
----------------------------------------------------------------------
do
	assert(settings.MaxLength == 40 and settings.BridgeSeconds == 3.5 and settings.CooldownSeconds == 18, "40 studs, 3.5 s, 18 s cooldown")
	assert(settings.SkinId == "SupermanSuit", "Superman's own skill")
	assert(HeatVisionMath.Length(settings, 100, nil) == 40, "Never longer than 40 studs")
	assert(HeatVisionMath.Length(settings, 2, nil) == settings.MinLength, "Never shorter than the minimum")
	assert(HeatVisionMath.Length(settings, 25, nil) == 25, "As far as the aim")
	assert(near(HeatVisionMath.Length(settings, 40, 12), 12 - HeatVisionMath.WallClearance), "Short of a wall")
	local direction = HeatVisionMath.FlatDirection(V3.new(3, -8, 4))
	assert(near(direction.Y, 0) and near(direction.Magnitude, 1) and near(direction.X, 0.6), "Level, toward the aim")
	local start = V3.new(10, 5, 20)
	local slabs = HeatVisionMath.Segments(settings, start, direction, 23)
	assert(#slabs == 5, "Slabs no longer than " .. settings.SegmentLength .. " studs")
	local covered = 0
	for index, slab in slabs do
		local top = slab.CFrame.Position.Y + slab.Size.Y / 2
		assert(near(top, start.Y + HeatVisionMath.Lift), "Its top is level with the floor at the feet")
		assert(slab.CFrame.LookVector:Dot(direction) > 0.999 and near(slab.Size.X, settings.Width), "Along the way, as wide as set")
		assert(index == 1 or slab.Delay > slabs[index - 1].Delay, "Drawn out from the feet")
		covered += slab.Size.Z - 0.05
	end
	assert(near(covered, 23), "Edge to edge, the whole length")
	local first, last = slabs[1], slabs[#slabs]
	local firstStart = first.CFrame.Position - direction * (first.Size.Z - 0.05) / 2
	local lastEnd = last.CFrame.Position + direction * (last.Size.Z - 0.05) / 2
	assert(near(V3.new(firstStart.X - start.X, 0, firstStart.Z - start.Z).Magnitude, 0, 1e-2), "It starts at the feet")
	assert(near(V3.new(lastEnd.X - start.X, 0, lastEnd.Z - start.Z).Magnitude, 23, 1e-2), "...and ends 23 studs on")
	print("PASS numbers: level from the feet toward the aim, 10-40 studs, short of walls, slabs edge to edge")
end

----------------------------------------------------------------------
-- 2. The server
----------------------------------------------------------------------
local function world()
	local clock = 1000
	local wallZ = nil
	local delayed = {}
	local debris = {}
	local container = rb.Instance.new("Folder")
	local paths = rb.Instance.new("Folder")
	paths.Name = "HeatVisionPaths"
	paths.Parent = container
	local request = { OnServerEvent = signal() }
	function request:IsA(class)
		return class == "RemoteEvent"
	end
	local playersList = {}
	local Players = { PlayerRemoving = signal() }
	function Players:GetPlayers()
		return playersList
	end
	local workspace = {
		FindFirstChild = function(_, name)
			return container:FindFirstChild(name)
		end,
		GetServerTimeNow = function()
			return clock
		end,
		-- A floor at y 0 everywhere, and a wall across the way at z = wallZ.
		Raycast = function(_, origin, direction)
			if direction.Y < 0 and origin.Y >= 0 and origin.Y + direction.Y <= 0 then
				return { Position = V3.new(origin.X, 0, origin.Z) }
			end
			if wallZ and direction.Z < 0 and origin.Z > wallZ and origin.Z + direction.Z <= wallZ then
				return { Position = V3.new(origin.X, origin.Y, wallZ) }
			end
			return nil
		end,
	}
	local services = {
		Debris = { AddItem = function(_, item, seconds)
			table.insert(debris, { Item = item, Seconds = seconds })
		end },
		Players = Players,
		ReplicatedStorage = { WaitForChild = function(_, name)
			if name == "Remotes" then
				return { FindFirstChild = function(_, child)
					return if child == "HeatVision" then request else nil
				end }
			end
			return { WaitForChild = function(_, module)
				return { Name = module }
			end }
		end },
		ServerScriptService = { WaitForChild = function()
			return { WaitForChild = function()
				return { Name = "ServerRateLimiter" }
			end }
		end },
		TweenService = { Create = function(_, target, _, goals)
			return { Play = function()
				for key, value in goals do
					target[key] = value
				end
			end }
		end },
		Workspace = workspace,
	}
	local modules = {
		Config = Config,
		HeatVisionMath = HeatVisionMath,
		ServerRateLimiter = { Allow = function()
			return true
		end },
	}
	local env = setmetatable({
		game = { GetService = function(_, name)
			return assert(services[name], name)
		end },
		require = function(object)
			return assert(modules[object.Name], object.Name)
		end,
		Instance = rb.Instance,
		Vector3 = V3,
		Vector2 = rb.Vector2,
		CFrame = rb.CFrame,
		Color3 = rb.Color3,
		ColorSequence = rb.ColorSequence,
		NumberSequence = rb.NumberSequence,
		NumberSequenceKeypoint = rb.NumberSequenceKeypoint,
		NumberRange = rb.NumberRange,
		Enum = rb.Enum,
		TweenInfo = { new = function()
			return {}
		end },
		RaycastParams = { new = function()
			return {}
		end },
		print = function() end,
		task = { delay = function(seconds, fn)
			table.insert(delayed, { At = clock + seconds, Fn = fn })
		end },
	}, { __index = _G })
	luau.load(fs.readFile("src/common/ServerScriptService/Core/Abilities/HeatVisionService.server.luau"), { environment = env })()

	local function makePlayer(skin)
		local character = rb.Instance.new("Model")
		local root = rb.Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.CFrame = rb.CFrame.new(0, 3, 0)
		root.Parent = character
		local head = rb.Instance.new("Part")
		head.Name = "Head"
		head.CFrame = rb.CFrame.new(0, 4.5, 0)
		head.Parent = character
		local humanoid = rb.Instance.new("Humanoid")
		humanoid.Health = 100 -- (Lune's Humanoid has no default Health)
		humanoid.Parent = character
		local attributes = { EquippedSkin = skin }
		local player = {
			UserId = 7,
			Character = character,
			GetAttribute = function(_, name)
				return attributes[name]
			end,
			SetAttribute = function(_, name, value)
				attributes[name] = value
			end,
			Attributes = attributes,
		}
		table.insert(playersList, player)
		return player
	end
	-- Runs everything due by `seconds` from now, in time order.
	local function advance(seconds)
		local stop = clock + seconds
		while true do
			table.sort(delayed, function(a, b)
				return a.At < b.At
			end)
			local nextOne = delayed[1]
			if not nextOne or nextOne.At > stop then
				break
			end
			table.remove(delayed, 1)
			clock = math.max(clock, nextOne.At)
			nextOne.Fn()
		end
		clock = stop
	end
	return {
		makePlayer = makePlayer,
		fire = function(player, target)
			request.OnServerEvent:Fire(player, { Target = target })
		end,
		advance = advance,
		paths = paths,
		debris = debris,
		setWall = function(z)
			wallZ = z
		end,
	}
end

local function slabsOf(paths)
	local list = {}
	for _, model in paths:GetChildren() do
		for _, part in model:GetChildren() do
			if part:IsA("BasePart") and part.Name == "MoltenPath" then
				table.insert(list, part)
			end
		end
	end
	return list
end

local function reach(slabs)
	local farthest = 0
	for _, part in slabs do
		farthest = math.max(farthest, -(part.CFrame.Position.Z - part.Size.Z / 2))
	end
	return farthest
end

do
	local w = world()
	local plain = w.makePlayer("FlashSuit")
	w.fire(plain, V3.new(0, 0, -25))
	w.advance(1)
	assert(#w.paths:GetChildren() == 0 and plain.Attributes.HeatVisionReadyAt == nil, "Only the Superman skin has Heat Vision")

	local superman = w.makePlayer("SupermanSuit")
	w.fire(superman, V3.new(0, 0, -25))
	local model = w.paths:GetChildren()[1]
	assert(model, "Superman melts a path")
	local beams = 0
	for _, child in model:GetChildren() do
		if child:IsA("Beam") then
			beams += 1
			assert(child.Attachment0 and child.Attachment0.Parent == superman.Character.Head, "The beams come from his eyes")
		end
	end
	assert(beams == 2, "Two red beams")
	assert(superman.Attributes.HeatVisionReadyAt == 1001 + 18, "Ready again in 18 s (fired at 1001)")
	w.advance(settings.DrawSeconds + 0.05)
	local slabs = slabsOf(w.paths)
	assert(#slabs == 5 and near(reach(slabs), 25, 0.1), "The path reaches the aim, 25 studs on")
	for _, part in slabs do
		assert(part.Anchored and part.CanCollide and not part.CanTouch, "Solid to stand on, touching nothing")
		assert(part.Material == rb.Enum.Material.CrackedLava and part:FindFirstChild("Embers"), "Molten rock, with embers")
		assert(near(part.CFrame.Position.Y + part.Size.Y / 2, HeatVisionMath.Lift), "Level with the floor at his feet")
		assert(not string.find(string.lower(part.Name), "lava", 1, true), "Nothing counts it as lava")
	end
	w.advance(0.3)
	assert(#model:GetChildren() == #slabs, "The beams are gone once the path is drawn")

	w.fire(superman, V3.new(0, 0, -25))
	assert(#w.paths:GetChildren() == 1, "Not again before the cooldown")
	w.advance(settings.BridgeSeconds - 0.3)
	for _, part in slabs do
		assert(part.Transparency == 1 and part.Material == rb.Enum.Material.Basalt, "After 3.5 s it cools to rock and fades")
	end
	local removed = false
	for _, entry in w.debris do
		removed = removed or entry.Item == model
	end
	assert(removed, "...and goes away")

	w.advance(18)
	w.setWall(-18)
	w.fire(superman, V3.new(0, 0, -60))
	w.advance(1)
	local blocked = {}
	for _, part in slabsOf(w.paths) do
		if part.Transparency < 1 then
			table.insert(blocked, part)
		end
	end
	assert(#blocked > 0 and reach(blocked) <= 18 - HeatVisionMath.WallClearance + 0.05, "It stops short of a wall (" .. reach(blocked) .. ")")

	local other = w.makePlayer("SupermanSuit")
	w.setWall(-2)
	w.fire(other, V3.new(0, 0, -30))
	assert(other.Attributes.HeatVisionReadyAt == nil, "A wall right in front: no path, and no cooldown spent")
	other.Attributes.AfkModeActive = true
	w.setWall(nil)
	w.fire(other, V3.new(0, 0, -30))
	assert(other.Attributes.HeatVisionReadyAt == nil, "Not in AFK Mode")
	print("PASS server: Superman only, a path of molten rock from the feet to the aim drawn by beams from the eyes, never through a wall, 3.5 s then cool and gone, every 18 s")
end

----------------------------------------------------------------------
-- 3. The client and the build
----------------------------------------------------------------------
do
	local client = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Movement/HeatVisionClient.client.luau")
	has(client, "ContextActionService:BindAction(ACTION, onAction, false, Enum.KeyCode.R, Enum.KeyCode.ButtonY)", "R on a keyboard, Y on a gamepad")
	has(client, "fire(if pointer then worldPointAt(UserInputService:GetMouseLocation()) else forwardPoint())", "The mouse's point on a PC, else where the camera looks (Shift Lock, gamepad)")
	has(client, "fire(worldPointAt(Vector2.new(input.Position.X, input.Position.Y)))", "On a touch screen, the tapped point")
	has(client, "button.Visible = equipped()", "The button shows while Superman is worn")
	has(client, "cover.Size = UDim2.fromScale(1, math.clamp(left / settings.CooldownSeconds, 0, 1))", "...with the cooldown draining")
	local build = fs.readFile("audit/build_core.luau")
	has(build, "{source='src/ui/HeatVisionButton.rbxm',parent={'StarterGui','Mainhud'},name='HeatVisionButton'}", "The button is saved in the Main HUD")
	local button = rb.deserializeModel(fs.readFile("src/ui/HeatVisionButton.rbxm"))[1]
	assert(button.Name == "HeatVisionButton" and button.Visible == false, "Hidden until worn")
	assert(button:FindFirstChild("Icon") and button.Icon:FindFirstChild("Eyes") and button:FindFirstChild("Cooldown") and button:FindFirstChild("KeyHint"), "Eyes, the cooldown cover and the key's hint")
	for _, d in button:GetDescendants() do
		assert(not d:IsA("LuaSourceContainer"), "No script in the button")
	end
	print("PASS client: R / Y and the HUD button (the designer's Sprint button with eyes and beams), aimed at the mouse, a tap or ahead")
end

print("ALL HEAT VISION CHECKS PASSED")
