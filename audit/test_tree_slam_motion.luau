--!strict
-- audit/test_tree_slam_motion.luau
-- The slam is a pure function of the shared server clock, so every client draws
-- the same pose without the server replicating a CFrame every frame.

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local Motion = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/TreeSlamMotion.luau"), {
	environment = { math = math, tonumber = tonumber, typeof = typeof, CFrame = nil },
})()

local slam = math.rad(Motion.SlamAngleDegrees)

for index = 1, 6 do
	local uprightHold, downHold, period, stagger = Motion.CycleFor(index)

	-- Before its stagger, and while upright, the tree is at rest.
	assert(Motion.AngleAt(index, stagger - 0.01) == 0, index .. " moved before its turn")
	assert(Motion.AngleAt(index, stagger + uprightHold * 0.5) == 0, index .. " is not upright during the hold")

	-- The strike runs from 0 to the full angle across DownTime. Sampled just
	-- inside the phase, because reconstructing the exact boundary from the
	-- accumulated offsets lands a float epsilon either side of it.
	local strikeStart = stagger + uprightHold
	assert(Motion.AngleAt(index, strikeStart + 1e-6) < slam * 1e-6,
		index .. " starts the strike already tilted")
	local mid = Motion.AngleAt(index, strikeStart + Motion.DownTime * 0.5)
	assert(mid > 0 and mid < slam, index .. " strike is not progressive")
	assert(math.abs(Motion.AngleAt(index, strikeStart + Motion.DownTime) - slam) < 1e-9,
		index .. " does not reach the full slam angle")

	-- It holds down, then returns to upright.
	assert(math.abs(Motion.AngleAt(index, strikeStart + Motion.DownTime + downHold * 0.5) - slam) < 1e-9,
		index .. " does not hold at the bottom")
	local backUp = strikeStart + Motion.DownTime + downHold + Motion.UpTime
	assert(math.abs(Motion.AngleAt(index, backUp)) < 1e-6, index .. " does not return upright")

	-- Deterministic: the same time always gives the same pose, and it repeats.
	local sample = strikeStart + Motion.DownTime * 0.37
	assert(Motion.AngleAt(index, sample) == Motion.AngleAt(index, sample),
		index .. " is not deterministic")
	assert(math.abs(Motion.AngleAt(index, sample) - Motion.AngleAt(index, sample + period)) < 1e-9,
		index .. " does not repeat on its period")
end

-- Continuity: no jump between frames anywhere in a full cycle. A visible seam here
-- is exactly what the replicated tween produced.
for index = 1, 6 do
	local _, _, period = Motion.CycleFor(index)
	local step = 1 / 240
	local previous = Motion.AngleAt(index, 0)
	local largest = 0
	local t = step
	while t <= period * 2 do
		local current = Motion.AngleAt(index, t)
		largest = math.max(largest, math.abs(current - previous))
		previous = current
		t += step
	end
	-- The fastest part of the strike is the Quint ease at the very end.
	local perFrameLimit = slam * (step / Motion.DownTime) * 5.5
	assert(largest <= perFrameLimit, string.format(
		"Tree %d jumps %.4f rad in one frame (limit %.4f)", index, largest, perFrameLimit))
end

-- The trees must not all slam together.
local firstStagger = select(4, Motion.CycleFor(1))
local secondStagger = select(4, Motion.CycleFor(2))
assert(secondStagger > firstStagger, "Trees lost their stagger and now slam in unison")

-- Wiring: the server publishes, the client renders, and neither animates CFrame
-- on the server any more.
local server = fs.readFile("src/worlds/World2/ServerScriptService/Gameplay/World2TreeSlammers.server.luau")
assert(string.find(server, "TreeSlamMotion.BaseAttribute", 1, true), "The server must publish the slam constants")
assert(string.find(server, "TreeSlamMotion.StartAttribute", 1, true), "The server must publish the shared clock")
assert(not string.find(server, "TweenService:Create", 1, true),
	"The server must not tween the trees; that is what replicated as a teleport")
assert(not string.find(server, "part.CFrame = baseCFrame", 1, true),
	"The server must not write tree CFrames any more")

local client = fs.readFile("src/worlds/World2/StarterPlayer/StarterPlayerScripts/Gameplay/World2TreeSlammers.client.luau")
assert(string.find(client, "renderTreeMotion", 1, true), "The client must render the slam")
assert(string.find(client, "GetServerTimeNow", 1, true), "The client must use the shared server clock")
assert(string.find(client, "TreeSlamMotion.PoseFor", 1, true), "The client must pose from the shared module")

-- Execute the real client startup with an empty streamed Workspace, then fire one
-- frame. This caught a Luau scope bug where renderTreeMotion resolved the distance
-- helper as a nil global because its local declaration came later in the file.
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, callback)
			table.insert(callbacks, callback)
			return { Disconnect = function() end }
		end,
		Fire = function(_, ...)
			for _, callback in callbacks do
				callback(...)
			end
		end,
	}
end
local frame = signal()
local workspace = {
	GetDescendants = function() return {} end,
	DescendantAdded = signal(),
	DescendantRemoving = signal(),
}
local player = { Character = nil, CharacterAdded = signal() }
local shared = { WaitForChild = function(_, name) return name end }
local remotes = { WaitForChild = function() return { FireServer = function() end } end }
local replicated = {
	WaitForChild = function(_, name)
		return if name == "Shared" then shared else remotes
	end,
}
local services = {
	Players = { LocalPlayer = player },
	ReplicatedStorage = replicated,
	RunService = { RenderStepped = frame },
	Workspace = workspace,
}
local env = setmetatable({
	game = { GetService = function(_, name) return services[name] end },
	require = function(name)
		return if name == "Config" then { IsWorld2Place = true } else Motion
	end,
	OverlapParams = { new = function() return {} end },
	Enum = { RaycastFilterType = { Include = "Include" } },
	task = { spawn = function() end, defer = function() end },
	print = function() end,
}, { __index = _G })
luau.load(client, { environment = env })()
frame:Fire()

print("PASS tree slam: deterministic, continuous, staggered, rendered client-side from the shared clock")
