-- test_map_physics.luau
-- The physics fixes from Sung's video (2026-09-18):
--   1. Slopes: a character walks up to 89 degrees (micro-steps between plates stopped it).
--   2. Friction: the body slides with little friction on any surface (bumps took its speed).
--   3. Air control: full from any takeoff (a jump from standing still was held to 2-7
--      studs/s and could not be steered).
--   4. World 1's rising lava climbs 2.5 times as fast.
--   5. World 1's splitting floor (slide1, slide2): once it opens it is not solid and fades
--      out fully, so no ledge of it is left to stand on; closing, it is solid again.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function has(source, needle, message)
	assert(string.find(source, needle, 1, true), message)
end

local movement = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Movement/InstantMovementController.client.luau")
has(movement, "local MAX_SLOPE_ANGLE = 89", "Slopes up to 89 degrees")
has(movement, "humanoid.MaxSlopeAngle = MAX_SLOPE_ANGLE", "...set on the character's Humanoid")
local friction = tonumber(string.match(movement, "local BODY_FRICTION = ([%d%.]+)"))
assert(friction and friction >= 0 and friction <= 0.1, "Friction 0-0.1")
has(movement, "local BODY_PHYSICS = PhysicalProperties.new(0.7, BODY_FRICTION, 0, 100, 1)", "...outweighing the floor's (FrictionWeight 100)")
has(movement, "part.CustomPhysicalProperties = BODY_PHYSICS", "...on every limb")
has(movement, "character.ChildAdded:Connect(smoothBody)", "...and on limbs that come later")
assert(not string.find(movement, "airStartRestricted", 1, true) and not string.find(movement, "AIR_START_", 1, true), "No air-speed cap after a jump from standing still")
print("PASS character: 89-degree slopes, friction " .. friction .. " on any surface, full air control from any takeoff")

local motion = fs.readFile("src/worlds/World1/ServerScriptService/Gameplay/NewWorld1ServerMotion.server.luau")
has(motion, "local LAVA_UP_SPEED = 12.65 * 2.5", "World 1's rising lava: 2.5 times as fast")
has(motion, "UpTime = LAVA_RISE_STUDS / LAVA_UP_SPEED", "...its rise timed from that speed")

-- The splitting floor, run through its whole cycle with its real code.
do
	local a = assert(string.find(motion, "local function updateSlides", 1, true))
	local b = assert(string.find(motion, "local function updateFast", a, true))
	local chunk = string.sub(motion, a, b - 1)
	local function part()
		return { Parent = true, CanCollide = true, CanTouch = true, Transparency = 0 }
	end
	local first, second = part(), part()
	local pivots = {}
	local system = {
		First = { OriginPivot = 0, Parts = { first } },
		Second = { OriginPivot = 0, Parts = { second } },
		FirstOut = 1,
		SecondOut = 1,
		PartStates = {
			[first] = { Transparency = 0, CanCollide = true, CanTouch = true },
			[second] = { Transparency = 0, CanCollide = true, CanTouch = true },
		},
	}
	local env = setmetatable({
		systems = { Slides = system },
		SLIDE_TRAVEL_TIME = tonumber(string.match(motion, "local SLIDE_TRAVEL_TIME = ([%d%.]+)")),
		SLIDE_EDGE_WAIT = tonumber(string.match(motion, "local SLIDE_EDGE_WAIT = ([%d%.]+)")),
		SLIDE_SOLID_UNTIL = tonumber(string.match(motion, "local SLIDE_SOLID_UNTIL = ([%d%.]+)")),
		sineEase = function(t)
			return 0.5 - math.cos(math.pi * t) / 2
		end,
		setRecordPivot = function(record, pivot)
			pivots[record] = pivot
		end,
	}, { __index = _G })
	-- Pivots are plain numbers here, with a Lerp of their own.
	local function pivot(value)
		return setmetatable({ Value = value }, { __index = { Lerp = function(self, other, t)
			return self.Value + ((type(other) == "table" and other.Value or other) - self.Value) * t
		end } })
	end
	system.First.OriginPivot, system.Second.OriginPivot = pivot(0), pivot(0)
	system.FirstOut, system.SecondOut = pivot(1), pivot(1)
	local updateSlides = luau.load(chunk .. "\nreturn updateSlides", { environment = env })()
	local travel, wait = env.SLIDE_TRAVEL_TIME, env.SLIDE_EDGE_WAIT
	updateSlides(0)
	assert(first.CanCollide and first.Transparency == 0, "Closed: solid and seen")
	updateSlides(travel * 0.25)
	assert(first.CanCollide, "Opening, a quarter of the way: still solid")
	updateSlides(travel + wait / 2)
	assert(not first.CanCollide and not second.CanCollide and first.Transparency > 0.99 and not first.CanTouch, "Open: nothing of it to stand on, out of sight")
	updateSlides(travel * 2 + wait * 1.5)
	assert(first.CanCollide and second.CanCollide and first.Transparency < 0.01, "Closed again: solid and seen")
	has(motion, "PartStates = partStates,", "The floor's own look and solidity are kept to put back")
	print("PASS World 1: the rising lava climbs 2.5x as fast; the splitting floor leaves no ledge while open and is whole again closed")
end

print("ALL MAP PHYSICS CHECKS PASSED")
