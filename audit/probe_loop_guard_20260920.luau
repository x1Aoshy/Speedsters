local fs = require("@lune/fs")
local rb = require("@lune/roblox")
local luau = require("@lune/luau")
local dm = rb.deserializePlace(fs.readFile("World1Update3New.rbxl"))
local map = dm:GetService("Workspace").neworld1
local positions = {}
for stage = 1, 11 do
	local part = assert(map:FindFirstChild("stage" .. stage, true))
	local cf, size = part.CFrame, part.Size
	local top = cf.Position.Y + (math.abs(cf.RightVector.Y)*size.X + math.abs(cf.UpVector.Y)*size.Y + math.abs(cf.LookVector.Y)*size.Z)/2
	positions[stage] = rb.Vector3.new(cf.Position.X, top, cf.Position.Z)
end
local function signal() return { Connect = function() end } end
local now = 10
local root = { Position = positions[1], Parent = true, IsA = function() return true end }
local character = { Parent = true, FindFirstChild = function() return root end, FindFirstChildOfClass = function() return { WalkSpeed = 8, Health = 100 } end }
local player = { Character = character, GetAttribute = function() return nil end }
local resolver = {
	GetStageReferencePosition = function(stage) return positions[stage] end,
	GetNearestStage = function(pos)
		local stage, distance = nil, math.huge
		for i, p in positions do
			local delta = pos - p
			local d = rb.Vector3.new(delta.X, 0, delta.Z).Magnitude + math.abs(delta.Y)*0.001
			if d < distance then stage, distance = i, d end
		end
		return stage, distance
	end,
}
local services = {
	Players = { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return {} end },
	RunService = { Heartbeat = signal() },
	ReplicatedStorage = { WaitForChild = function() return { WaitForChild = function() return { StageCount = 11, FinalPadCooldownSeconds = 1.5 } end } end },
	Workspace = { GetServerTimeNow = function() return now end },
}
local guard = luau.load(fs.readFile("src/common/ServerScriptService/Services/MovementGuard.luau"), { environment = {
	game = { GetService = function(_, name) return assert(services[name]) end },
	script = { Parent = { WaitForChild = function() return resolver end } },
	require = function(value) return value end,
	Vector3 = rb.Vector3, os = { clock = function() return now end, time = function() return 1000 end },
	_G = {}, task = { defer = function(fn) fn() end },
} })()
guard.ResetForCharacter(player, character)
now += 4 -- leave all spawn grace windows
guard.CanClaim(player, 1, false)
-- Deliberately advance in 1000-stud jumps toward stage 11, without visiting stage pads.
local origin, target = root.Position, positions[11]
local steps = math.ceil((target-origin).Magnitude / 1000)
local progress = {}
for i = 1, steps do
	now += 0.1
	root.Position = origin:Lerp(target, i/steps)
	local allowed, reason = guard.CanClaim(player, 11, true)
	table.insert(progress, guard.GetProgress(player))
	print("jump", i, "progress", guard.GetProgress(player), "allowed", allowed, "reason", reason)
end
local allowed, reason = guard.CanClaim(player, 11, true)
assert(allowed, "reproduction no longer applies: " .. tostring(reason))
assert(steps * 0.1 < 5)
print(("REPRODUCED: normal WalkSpeed=8, %d unsanctioned jumps in %.1fs, final reward authorized; progress=%s"):format(steps, steps*0.1, table.concat(progress, ",")))
-- Positive control: the guard does reject one enormous teleport.
root.Position = origin
guard.ResetForCharacter(player, character)
now += 4
guard.CanClaim(player, 1, false)
now += 0.1
root.Position = target
local blocked, blockedReason = guard.CanClaim(player, 11, true)
assert(not blocked and blockedReason == "SuspiciousMovement")
print("CONTROL PASSED: one full-distance teleport is rejected")
