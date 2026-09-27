local fs = require("@lune/fs")
local rb = require("@lune/roblox")
local luau = require("@lune/luau")
local process = require("@lune/process")
local serde = require("@lune/serde")
local T = require("../src/worlds/World1/ReplicatedStorage/Shared/World1Trampoline")
local W = "src/worlds/World1/"
local clientPath = W .. "StarterPlayer/StarterPlayerScripts/Gameplay/NewWorld1Trampoline.client.luau"
local serverPath = W .. "Workspace/Trampoline/Trampoline_Hitbox/Trampoline hitbox/Script.server.luau"
local dm = rb.deserializePlace(fs.readFile("World1Update3New.rbxl"))
local ws = dm:GetService("Workspace")
local pad = ws.Trampoline:FindFirstChild("Trampoline hitbox", true)
local ledge = ws.neworld1:FindFirstChild("stage10", true)
local matTop, ledgeTop = T.TopOf(pad.CFrame, pad.Size), T.TopOf(ledge.CFrame, ledge.Size)
local rise = T.Rise(matTop, ledgeTop)
local speed = T.LaunchSpeed(ws.Gravity, rise)
assert(speed > 400 and speed < 425)
assert(math.abs(matTop + T.Apex(ws.Gravity, speed) - ledgeTop - T.Clearance) < 0.001)
local barrierTop = math.huge
for _, part in ws:GetChildren() do
	if part:IsA("BasePart") and part.Name == "Barrier" and math.abs(part.CFrame.Position.Z - pad.CFrame.Position.Z) < 500 and math.abs(part.CFrame.Position.X - pad.CFrame.Position.X) < 400 then
		local top = T.TopOf(part.CFrame, part.Size)
		if top > ledgeTop then barrierTop = math.min(barrierTop, top) end
	end
end
assert(barrierTop < math.huge)
for _, fps in { 30, 60, 120, 240 } do
	local y, v, apex = matTop, speed, matTop
	for _ = 1, math.ceil(T.AscentSeconds(ws.Gravity, rise) * fps) do
		v -= ws.Gravity / fps
		y += v / fps
		apex = math.max(apex, y)
	end
	assert(apex > ledgeTop + 10, "bounce cannot clear the ledge at " .. fps .. " fps")
	assert(apex + 8 < barrierTop, "character clears the side barriers")
end
print(("PASS real geometry: %.2f studs/s; apex %.2f above ledge, below barriers at 30/60/120/240 fps"):format(speed, T.Clearance))

-- Run the actual client with controlled contact, time, character and gravity.
local heartbeat, onAdded, onRemoved
local now, rays, contact = 10, 0, true
local attrs = {}
local root = { Position = pad.CFrame.Position + rb.Vector3.new(0, 4, 0), Size = rb.Vector3.new(2, 2, 1), AssemblyLinearVelocity = rb.Vector3.new(12, -30, 18) }
local humanoid = { Health = 100, RigType = rb.Enum.HumanoidRigType.R6, HipHeight = 0, ChangeState = function() end }
local character = {
	GetAttribute = function(_, name) return attrs[name] end,
	SetAttribute = function(_, name, value) attrs[name] = value end,
	FindFirstChild = function() return root end,
	FindFirstChildOfClass = function() return humanoid end,
}
local model = {
	Parent = true,
	GetAttribute = function() return rise end,
	IsA = function() return true end,
	GetPivot = function() return pad.CFrame end,
}
local services = {
	CollectionService = {
		GetTagged = function() return { model } end,
		GetInstanceAddedSignal = function() return { Connect = function(_, f) onAdded = f end } end,
		GetInstanceRemovedSignal = function() return { Connect = function(_, f) onRemoved = f end } end,
	},
	Players = { LocalPlayer = { Character = character } },
	ReplicatedStorage = { WaitForChild = function() return { WaitForChild = function(_, name) return name end } end },
	RunService = { Heartbeat = { Connect = function(_, f) heartbeat = f end } },
	Workspace = { Gravity = ws.Gravity, Raycast = function() rays += 1; return contact and {} or nil end },
}
luau.load(fs.readFile(clientPath), { environment = {
	game = { GetService = function(_, name) return assert(services[name]) end },
	require = function(name) return if name == "Config" then { IsNewWorld1Map = true } else T end,
	os = { clock = function() return now end },
	Vector3 = rb.Vector3, Enum = rb.Enum, RaycastParams = { new = function() return {} end },
} })()
heartbeat()
assert(math.abs(root.AssemblyLinearVelocity.Y - speed) < 0.001)
assert(root.AssemblyLinearVelocity.X == 12 and root.AssemblyLinearVelocity.Z == 18)
assert(attrs.VortexLaunchUntil > now + 2)
local originalPosition = root.Position
now += 0.1
root.AssemblyLinearVelocity = rb.Vector3.new(12, 50, 18) -- simultaneous ordinary jump
heartbeat()
assert(math.abs(root.AssemblyLinearVelocity.Y - (speed - ws.Gravity * 0.1)) < 0.01)
assert(root.Position == originalPosition, "the trampoline must never teleport")
now += 0.2
root.AssemblyLinearVelocity = rb.Vector3.new(12, -5, 18)
heartbeat()
assert(root.AssemblyLinearVelocity.Y == -5, "cooldown did not prevent duplicate launch")
now += 1
contact = false
heartbeat()
assert(root.AssemblyLinearVelocity.Y == -5, "launched without contact")
contact = true
heartbeat()
assert(math.abs(root.AssemblyLinearVelocity.Y - speed) < 0.001, "landing must bounce again")
onRemoved(model)
local oldRays = rays
now += 1
heartbeat()
assert(rays == oldRays, "streamed-out trampoline still raycasts")
onAdded(model)
root.Position += rb.Vector3.new(1000, 0, 0)
root.AssemblyLinearVelocity = rb.Vector3.zero
heartbeat()
assert(rays == oldRays and root.AssemblyLinearVelocity == rb.Vector3.zero)
print("PASS actual client: contact launch, horizontal control, jump protection, cooldown, repeat landing, streaming, distance, no teleport")

luau.compile(fs.readFile(serverPath))
local sharedPaths = {
	"src/common/StarterPlayer/StarterPlayerScripts/Movement/InstantMovementController.client.luau",
	"src/common/StarterPlayer/StarterPlayerScripts/Movement/WallImpactAntiFling.client.luau",
}
for _, path in sharedPaths do luau.compile(fs.readFile(path)) end

if process.args[1] == "places" then
	local manifest = serde.decode("json", fs.readFile("src/manifest.json"))
	for _, place in { { "World1", "World1Update3New.rbxl" }, { "World2", "World2Update3new.rbxl" }, { "World3", "World3Update3New.rbxl" } } do
		local current = rb.deserializePlace(fs.readFile(place[2]))
		local old = rb.deserializePlace(fs.readFile("output/Backup_UI_Bridge_Loading_20260920_131825/" .. place[2]))
		local gui, oldGui = current:GetService("StarterGui").StageTeleport.StageTeleport, old:GetService("StarterGui").StageTeleport.StageTeleport
		assert(gui.Size == oldGui.Size, "panel dimensions changed")
		assert(gui.ScrollingFrame.CanvasSize == oldGui.ScrollingFrame.CanvasSize, "authored canvas not restored")
		assert(gui.ScrollingFrame.AutomaticCanvasSize == rb.Enum.AutomaticSize.None)
		assert(gui.ScrollingFrame.Stage2.Size == oldGui.ScrollingFrame.Stage2.Size)
		assert(not gui.ScrollingFrame:FindFirstChild("Stage11"))
		local wanted = table.clone(sharedPaths)
		if place[1] == "World1" then
			table.insert(wanted, clientPath)
			table.insert(wanted, serverPath)
			table.insert(wanted, W .. "ReplicatedStorage/Shared/World1Trampoline.luau")
			assert(current:GetService("Workspace").Trampoline:HasTag(T.Tag))
			assert(current:GetService("Workspace").Trampoline:FindFirstChild("Trampoline hitbox", true).Velocity == rb.Vector3.zero)
		end
		for _, path in wanted do
			local found = false
			for _, row in manifest.worlds[place[1]].scripts do
				if row.source == path then
					local node = current
					for _, segment in row.segments do node = assert(node:FindFirstChild(segment)) end
					assert(node.Source == fs.readFile(path), place[1] .. ": outdated " .. path)
					found = true
				end
			end
			assert(found, "missing manifest row " .. path)
		end
		print("PASS " .. place[1] .. ": restored UI matches backup; embedded movement/trampoline sources match")
	end
end
print("ALL PASSED")
