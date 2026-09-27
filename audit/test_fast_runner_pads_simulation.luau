local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Vector3, CFrame = roblox.Vector3, roblox.CFrame

local function signal()
	local handlers = {}
	return {
		Connect = function(_, fn)
			handlers[fn] = true
			return { Disconnect = function() handlers[fn] = nil end }
		end,
		Fire = function(_, ...)
			for fn in pairs(handlers) do
				fn(...)
			end
		end,
	}
end

print("=== Starting Fast Runner & Pad Simulation Tests ===")

-- Test 1: Verify Config values
local configSource = fs.readFile("src/common/ReplicatedStorage/Shared/Config.luau")
local rsMock = { GetAttribute = function() return 1 end }
local wsMock = { GetAttribute = function() return nil end, FindFirstChild = function() return nil end }
local Config = luau.load(configSource, {
	environment = {
		game = {
			PlaceId = 85065221510105,
			GetService = function(_, n)
				if n == "ReplicatedStorage" then return rsMock end
				if n == "Workspace" then return wsMock end
				return {}
			end
		},
		workspace = wsMock,
		ReplicatedStorage = rsMock,
		Vector3 = Vector3,
		CFrame = CFrame,
		Color3 = roblox.Color3,
		Enum = roblox.Enum,
	}
})()

assert(Config.FinalPadCooldownSeconds == 1.5, "Config.FinalPadCooldownSeconds must be 1.5")
assert(Config.World2FinalPadCooldownSeconds == 1.5, "Config.World2FinalPadCooldownSeconds must be 1.5")
print("  ✓ Config pad cooldowns are 1.5s")

-- Test 2: Verify MovementGuard with fast runner and rapid laps
local mgSource = fs.readFile("src/common/ServerScriptService/Services/MovementGuard.luau")

local mockStageCenters = {
	[1] = Vector3.new(0, 0, 0),
	[2] = Vector3.new(100, 0, 0),
	[3] = Vector3.new(200, 0, 0),
	[4] = Vector3.new(300, 0, 0),
	[5] = Vector3.new(400, 0, 0),
	[6] = Vector3.new(500, 0, 0),
	[7] = Vector3.new(600, 0, 0),
	[8] = Vector3.new(700, 0, 0),
	[9] = Vector3.new(800, 0, 0),
	[10] = Vector3.new(900, 0, 0),
	[11] = Vector3.new(1000, 0, 0),
}

local mockTeleportService = {
	GetStageReferencePosition = function(stage)
		return mockStageCenters[stage]
	end,
	GetNearestStage = function(pos)
		local nearest, minDist = nil, math.huge
		for s, c in pairs(mockStageCenters) do
			local d = (pos - c).Magnitude
			if d < minDist then
				minDist = d
				nearest = s
			end
		end
		return nearest, minDist
	end,
}

local currentTime = 100
local mgEnv = {
	game = {
		GetService = function(_, name)
			if name == "RunService" then return { Heartbeat = signal() } end
			if name == "Players" then return { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return {} end } end
			if name == "ReplicatedStorage" then return { WaitForChild = function() return { WaitForChild = function() return {} end } end } end
			if name == "Workspace" then return { GetServerTimeNow = function() return currentTime end } end
			return {}
		end,
	},
	script = { Parent = { WaitForChild = function() return {} end } },
	require = function(mod)
		if mod == mockTeleportService or mod == Config then return mod end
		return Config
	end,
	os = { clock = function() return currentTime end, time = function() return math.floor(currentTime) end },
	math = math,
	table = table,
	type = type,
	typeof = typeof,
	tonumber = tonumber,
	tostring = tostring,
	pcall = pcall,
	warn = function(...) print("[MG Warn]", ...) end,
	setmetatable = setmetatable,
	Vector3 = Vector3,
	CFrame = CFrame,
	Instance = roblox.Instance,
	RunService = { Heartbeat = signal() },
	Players = { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return {} end },
	Workspace = { GetServerTimeNow = function() return currentTime end },
}
mgEnv.script.Parent.StageTeleportService = mockTeleportService
mgEnv.require = function(item)
	if item == Config then return Config end
	return mockTeleportService
end

local MovementGuard = luau.load(mgSource, { environment = mgEnv })()

local playerAttributes = {
	RealWalkSpeedSelected = 3000,
	IsBoosting = true,
	DataLoaded = true,
}

local fakePlayer = {
	UserId = 12345,
	Name = "SpeedsterRunner",
	GetAttribute = function(_, name)
		return playerAttributes[name]
	end,
	SetAttribute = function(_, name, val)
		playerAttributes[name] = val
	end,
}

local rootPart = {
	Position = Vector3.new(0, 0, 0),
	IsA = function(_, class) return class == "BasePart" end,
	Parent = {},
}
fakePlayer.Character = {
	HumanoidRootPart = rootPart,
	FindFirstChild = function(_, name)
		if name == "HumanoidRootPart" then return rootPart end
		return nil
	end,
	FindFirstChildOfClass = function(_, class)
		if class == "Humanoid" then
			return { WalkSpeed = 3000, Health = 100 }
		end
		return nil
	end,
}
rootPart.Parent = fakePlayer.Character

MovementGuard.ResetForCharacter(fakePlayer, fakePlayer.Character)
assert(MovementGuard.GetProgress(fakePlayer) == 1, "Initial progress must be 1")
print("  ✓ MovementGuard initializes character cleanly at stage 1")

-- Simulate running at 3000 speed from stage 1 to stage 10 in 100-stud steps (each step ~0.033s)
for s = 2, 10 do
	local targetPos = mockStageCenters[s]
	currentTime += 0.033
	rootPart.Position = targetPos
	local canClaim, reason = MovementGuard.CanClaim(fakePlayer, s, false, currentTime)
	assert(canClaim == true, "High speed runner must be able to claim stage " .. s .. ", failed: " .. tostring(reason))
end
print("  ✓ High speed runner (3000 speed) reaches and claims all stages 2-10 with 0 failures")

-- Now test Final Win Pad claim
local canClaimFinal, reason = MovementGuard.CanClaim(fakePlayer, 10, true, currentTime)
assert(canClaimFinal == true, "Final pad claim must succeed on lap 1, failed: " .. tostring(reason))
MovementGuard.RecordFinalClaim(fakePlayer, currentTime)
print("  ✓ Lap 1 final pad claimed successfully")

-- Try immediately touching final pad again at t + 0.5s -> should be blocked by 1.5s cooldown
currentTime += 0.5
local canClaimTooSoon, reasonSoon = MovementGuard.CanClaim(fakePlayer, 10, true, currentTime)
assert(canClaimTooSoon == false and reasonSoon == "Cooldown", "Immediate re-touch within 0.5s must be on Cooldown")
print("  ✓ 0.5s re-touch cleanly rejected by 1.5s cooldown")

-- Now advance time by 1.6s -> lap 2 must be claimable! (Proves 180s lockout is gone!)
currentTime += 1.1
local canClaimLap2, reasonLap2 = MovementGuard.CanClaim(fakePlayer, 10, true, currentTime)
assert(canClaimLap2 == true, "Lap 2 at t + 1.6s must succeed! 180s lockout is fixed! reason: " .. tostring(reasonLap2))
print("  ✓ Lap 2 final pad claimed at t + 1.6s! (180s lockout verified eliminated)")

-- Test 3: Verify DoubleWinsPad entitlement checks
local dwpSource = fs.readFile("src/common/ServerScriptService/Services/DoubleWinsPad.luau")
local dwpEnv = {
	game = {
		GetService = function(_, name)
			if name == "MarketplaceService" then
				return {
					PromptGamePassPurchaseFinished = signal(),
					UserOwnsGamePassAsync = function() return false end,
				}
			end
			if name == "Players" then return { PlayerRemoving = signal() } end
			if name == "ReplicatedStorage" then return { WaitForChild = function() return { WaitForChild = function() return {} end } end } end
			if name == "ServerScriptService" then return { WaitForChild = function() return { WaitForChild = function() return {} end } end } end
			return {}
		end,
	},
	require = function(mod)
		if mod == Config then return Config end
		return { PadDoubleMultiplier = 2, Connect = function() end }
	end,
	os = { clock = function() return currentTime end },
	table = table,
	type = type,
	typeof = typeof,
	tonumber = tonumber,
	tostring = tostring,
	pcall = pcall,
	warn = function(...) end,
	setmetatable = setmetatable,
}
local DoubleWinsPad = luau.load(dwpSource, { environment = dwpEnv })()

-- Test DoubleWinsPadUnlocked
playerAttributes.DoubleWinsPadUnlocked = true
playerAttributes.TwoXVictoryOwned = nil
assert(DoubleWinsPad.IsEntitled(fakePlayer) == true, "DoubleWinsPadUnlocked must entitle player")

-- Test TwoXVictoryOwned
playerAttributes.DoubleWinsPadUnlocked = nil
playerAttributes.TwoXVictoryOwned = true
assert(DoubleWinsPad.IsEntitled(fakePlayer) == true, "TwoXVictoryOwned must entitle player")

playerAttributes.TwoXVictoryOwned = nil
assert(DoubleWinsPad.IsEntitled(fakePlayer) == false, "Unowned player must not be entitled")
print("  ✓ DoubleWinsPad entitlement works with both DoubleWinsPadUnlocked and TwoXVictoryOwned")

-- Test 4: Verify PadTouchService with extreme speed runner
local ptsSource = fs.readFile("src/common/ServerScriptService/Services/PadTouchService.luau")
local heartbeatSignal = signal()
local mockWorkspace = { GetServerTimeNow = function() return currentTime end }
local function makePart(size, cf)
	local p = setmetatable({
		Size = size or Vector3.new(1, 1, 1),
		CFrame = cf or CFrame.new(),
		Parent = mockWorkspace,
		signals = {},
		Destroying = signal(),
	}, {
		__index = function(t, k)
			if k == "Position" then return t.CFrame.Position end
		end,
		__newindex = function(t, k, v)
			rawset(t, k, v)
		end,
	})
	function p:GetAttribute() return nil end
	function p:GetPropertyChangedSignal(name)
		self.signals[name] = self.signals[name] or signal()
		return self.signals[name]
	end
	p.GetAttributeChangedSignal = p.GetPropertyChangedSignal
	function p:IsDescendantOf(other) return self.Parent ~= nil and other == mockWorkspace end
	function p:Destroy() self.Destroying:Fire(); self.Parent = nil end
	return p
end

local mockPlayers = { PlayerRemoving = signal(), GetPlayers = function() return { fakePlayer } end }
fakePlayer.Parent = mockPlayers

local ptsEnv = {
	game = {
		GetService = function(_, name)
			if name == "RunService" then return { Heartbeat = heartbeatSignal } end
			if name == "Players" then return mockPlayers end
			if name == "Workspace" then return mockWorkspace end
			return {}
		end,
	},
	task = { spawn = function(fn) fn() end, delay = function(_, fn) fn() end },
	os = { clock = function() return currentTime end, time = function() return math.floor(currentTime) end },
	table = table,
	type = type,
	typeof = typeof,
	tonumber = tonumber,
	tostring = tostring,
	pcall = pcall,
	warn = function(...) print("[PTS WARN]", ...) end,
	assert = assert,
	setmetatable = setmetatable,
	Vector3 = Vector3,
	CFrame = CFrame,
	Instance = { new = function() return makePart() end },
	RunService = { Heartbeat = heartbeatSignal },
	Players = mockPlayers,
	Workspace = mockWorkspace,
}

local PadTouchService = luau.load(ptsSource, { environment = ptsEnv })()

-- Create a mock pad at (500, 0, 0)
local padPart = makePart(Vector3.new(14, 1, 14), CFrame.new(500, 0.5, 0))

local touches = 0
local conn = PadTouchService.Connect(padPart, function(hit)
	touches += 1
	return true
end)

-- Runner at position 300, moving to 600 at speed 5000 in dt = 0.05s
-- Distance = 300 studs, crosses the pad at 500!
playerAttributes.RealWalkSpeedSelected = 5000
playerAttributes.IsBoosting = true
rootPart.Position = Vector3.new(300, 3, 0)
currentTime += 0.05
heartbeatSignal:Fire(0.05)

-- Now step past the pad to 600
rootPart.Position = Vector3.new(600, 3, 0)
currentTime += 0.05
heartbeatSignal:Fire(0.05)

assert(touches == 1, "PadTouchService must detect fast runner crossing pad (touches: " .. tostring(touches) .. ")")
print("  ✓ PadTouchService swept contact detected fast runner crossing pad at 5000 speed")

-- Test 5: Verify RewardPadClaims + touchReady retry behavior
local rpcSource = fs.readFile("src/common/ServerScriptService/Services/RewardPadClaims.luau")
local committedWins = 0
local mockDataService = {
	GetHandle = function(userId)
		return { userId = userId, sessionId = "sim1", generation = 1 }
	end,
	NewOperationId = function()
		return "op_test_" .. tostring(os.clock())
	end,
	Commit = function(handle, req)
		committedWins += req.commands[1].amount
		return { kind = "Committed" }
	end,
}

local rpcEnv = {
	game = {
		GetService = function(_, name)
			if name == "Players" then return mockPlayers end
			if name == "Workspace" then return mockWorkspace end
			return {}
		end,
	},
	script = {
		Parent = {
			Data = { DataService = mockDataService },
			MovementGuard = MovementGuard,
			PadTouchService = PadTouchService,
		},
	},
	require = function(mod)
		return mod
	end,
	os = { clock = function() return currentTime end },
	math = math,
	table = table,
	type = type,
	typeof = typeof,
	tonumber = tonumber,
	tostring = tostring,
	pcall = pcall,
	warn = function(...) end,
	setmetatable = setmetatable,
	Players = mockPlayers,
	Workspace = mockWorkspace,
	_G = {
		SpeedsterGetWinsMultiplier = function() return 2 end,
	},
}

local RewardPadClaims = luau.load(rpcSource, { environment = rpcEnv })()

-- Test claiming at pad
local testPad = makePart(Vector3.new(14, 1, 14), CFrame.new(0, 0.5, 0))
rootPart.Position = Vector3.new(0, 3, 0) -- Character is at pad
currentTime += 1

local returnSuccess = true
local grantedAmount = 0
local claimSuccess = RewardPadClaims.Claim(
	fakePlayer,
	testPad,
	100, -- base reward 100
	1,
	false,
	function(p)
		if not returnSuccess then return false end
		rootPart.Position = Vector3.new(100, 3, 0) -- Teleported away from pad
		return true
	end,
	function(amount)
		grantedAmount = amount
	end
)

assert(claimSuccess == true, "Claim at pad must succeed")
assert(grantedAmount == 200, "Reward must have account multiplier applied (100 * 2 = 200), got: " .. tostring(grantedAmount))
print("  ✓ RewardPadClaims successfully claimed 200 wins (base 100 * x2 mult)")

-- Test retry after return failure: verify cooldown is NOT locked
returnSuccess = false
rootPart.Position = Vector3.new(0, 3, 0)
currentTime += 0.1

local failedClaim = RewardPadClaims.Claim(
	fakePlayer,
	testPad,
	100,
	1,
	false,
	function(p)
		return false -- return failed
	end
)
assert(failedClaim == false, "Claim with failing returnToStart must return false")

-- Now retry immediately with return working: must succeed (no stuck claims)
returnSuccess = true
local retryClaim = RewardPadClaims.Claim(
	fakePlayer,
	testPad,
	100,
	1,
	false,
	function(p)
		rootPart.Position = Vector3.new(100, 3, 0)
		return true
	end,
	function(amount)
		grantedAmount = amount
	end
)
assert(retryClaim == true, "Subsequent claim retry after failure must succeed immediately")
print("  ✓ Failed claim does not lock player out; retry succeeds immediately")

print("=== ALL SIMULATION TESTS PASSED (100% SUCCESS) ===")
