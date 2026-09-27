--!strict
-- audit/test_flight_balance.luau
-- Flight read as permanent because only the climb cost stamina. This simulates
-- the real drain loop and caps how long a player can stay airborne, on the
-- weakest suit and the strongest one.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local function load(path, extraEnv)
	local env = {
		table = table, math = math, string = string, os = os,
		ipairs = ipairs, pairs = pairs, tonumber = tonumber, tostring = tostring,
		type = type, typeof = typeof, next = next, select = select, pcall = pcall,
		error = error, assert = assert, print = function() end, warn = function() end,
		Vector3 = roblox.Vector3, Color3 = roblox.Color3, CFrame = roblox.CFrame,
		Enum = roblox.Enum, UDim2 = roblox.UDim2,
	}
	for key, value in pairs(extraEnv or {}) do env[key] = value end
	return luau.load(fs.readFile(path), { environment = env })()
end

local stub = {}
stub.GetAttribute = function() return nil end
stub.FindFirstChild = function() return nil end
stub.WaitForChild = function() return stub end

local Config = load("src/common/ReplicatedStorage/Shared/Config.luau", {
	game = { GetService = function() return stub end, PlaceId = 85065221510105 },
	workspace = stub,
})
local FlightStamina = load("src/common/ReplicatedStorage/Shared/FlightStamina.luau")

-- Replays the server drain loop at 60 Hz: climb while powered, then glide.
local function simulate(maxStamina: number, climbSeconds: number): number
	local stamina = maxStamina
	local dt = 1 / 60
	local airtime = 0
	local minimumToPower = FlightStamina.MinimumToPower(Config, maxStamina)
	while stamina > 0 and airtime < 600 do
		local powered = airtime < climbSeconds and stamina > minimumToPower
		local exhausted
		stamina, exhausted = FlightStamina.Step(Config, stamina, maxStamina, dt, powered)
		airtime += dt
		if exhausted then break end
	end
	return airtime
end

local SUITS = {
	{ name = "base (no suit)", max = tonumber(Config.BoostStaminaDisplayBase) or 17 },
	{ name = "FlashSuit", max = 5 },
	{ name = "SonicSuit", max = 50 },
	{ name = "SuperSaiyanSonicSuit", max = 60 },
}

assert(FlightStamina.GlideDrainPerSecond(Config, 17) > 0, "Gliding must cost stamina")

local MAX_ALLOWED = 9
print("Longest airtime from a full bar (climb 0.5s, then glide):")
for _, suit in ipairs(SUITS) do
	local airtime = simulate(suit.max, 0.5)
	local ceiling = FlightStamina.MaxAirtimeSeconds(Config, suit.max)
	print(string.format("   %-24s max=%-4d  %.1fs  (analytic ceiling %.1fs)", suit.name, suit.max, airtime, ceiling))
	assert(airtime <= MAX_ALLOWED, string.format(
		"%s can stay airborne %.1fs; flight is meant to be a traversal burst, not free travel", suit.name, airtime))
	assert(ceiling < math.huge, suit.name .. " has unbounded airtime")
end

-- Every suit must fly the same. A stamina suit buys longer sprints, not a
-- different flight mechanic - and a flat cost breaks that in both directions:
-- it deletes the small suits and is free for the big ones.
local weakest = simulate(SUITS[2].max, 0.5)
local strongest = simulate(SUITS[4].max, 0.5)
assert(math.abs(strongest - weakest) <= 0.5, string.format(
	"Flight is not uniform across suits: %.2fs on the weakest vs %.2fs on the strongest",
	weakest, strongest))
print(string.format("   suit spread: %.2fs vs %.2fs (uniform)", weakest, strongest))

-- Taking off must cost a share of the bar, never a flat amount. A flat 5 meant the
-- 5-stamina FlashSuit needed a FULL bar to fly at all - reported as "flight only
-- works with full stamina".
for _, suit in ipairs(SUITS) do
	local needed = FlightStamina.MinimumToPower(Config, suit.max)
	local share = needed / suit.max
	assert(share <= 0.25, string.format(
		"%s must spend %.0f%% of its bar just to take off", suit.name, share * 100))
	assert(simulate(suit.max, 0.5) > 1.5, suit.name .. " cannot stay airborne long enough to be usable")
end
print("   every suit lifts off at the same share of its bar and flies the same")

-- A full climb must still be short enough that flight cannot replace running.
local climbOnly = simulate(60, 600)
assert(climbOnly <= 5, string.format("Powered climb lasts %.1fs on the top suit", climbOnly))
print(string.format("   pure climb, top suit: %.1fs", climbOnly))

-- Holding jump after a single jump must be what starts flight.
for _, world in ipairs({ "World1", "World2" }) do
	local client = fs.readFile(string.format(
		"src/worlds/%s/StarterPlayer/StarterPlayerScripts/Movement/%sFlightAbility.client.luau", world, world))
	assert(string.find(client, "AIRBORNE_HOLD_SECONDS", 1, true), world .. " must engage flight from a held jump")
	assert(string.find(client, "lastJumpAt = os.clock()", 1, true), world .. " must record the jump that starts flight")
	assert(string.find(client, "os.clock() - lastJumpAt >= AIRBORNE_HOLD_SECONDS", 1, true),
		world .. " must wait only the airborne hold, not the full ground timer")
end
assert((tonumber(Config.AbilityFlightAirborneHoldSeconds) or 1) <= 0.35,
	"The airborne hold must feel immediate after the jump")

print("ALL FLIGHT BALANCE CHECKS PASSED")
