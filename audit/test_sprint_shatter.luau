-- test_sprint_shatter.luau
-- The sprint's sonic barrier (InstantMovementController): 100% of the chosen speed (no reduction)
-- until 3.0 s of continuous grounded sprinting, then 102% (+2% boost), SonicBurstActive (wider FOV),
-- forward impulse, and the Glass Shatter impact.
local fs = require('@lune/fs')
local luau = require('@lune/luau')
local rb = require('@lune/roblox')

local s = fs.readFile('src/common/StarterPlayer/StarterPlayerScripts/Movement/InstantMovementController.client.luau')
assert(s:find('GlassShatter', 1, true), 'The movement controller loads the screen Glass Shatter')
local a = assert(s:find('\t-- Sonic barrier build-up:', 1, true))
local b = assert(s:find('\n\tif humanoid and math.abs', a, true))
local attrs = {}
local plays = 0
local player = { GetAttribute = function(_, k) return attrs[k] end, SetAttribute = function(_, k, v) attrs[k] = v end }
local code = 'local sonicRunTimer,sonicBroken,lastSonicBurstAt=0,false,0\nlocal SONIC_BUILDUP_TIME,SONIC_COOLDOWN,SONIC_INITIAL_RATIO,SONIC_BURST_RATIO=3.0,1.0,1.0,1.02\nreturn function(moving,grounded,speed,now)\nlocal direction={Magnitude=moving and 1 or 0};local deadzone=0.1;local deltaTime=0.1;local root={AssemblyLinearVelocity=Vector3.new(speed,0,speed)};local movementWalkSpeed=100\n'
	.. s:sub(a, b - 1) .. '\nreturn movementWalkSpeed\nend'
local glass = { Play = function() plays += 1 end, Pane = function() plays += 1 end, Sphere = function() plays += 1 end }
local step = luau.load(code, { environment = { player = player, task = { defer = function(fn) fn() end }, Color3 = rb.Color3, Vector3 = rb.Vector3, GlassShatter = glass, GlassBurst = glass, CameraPunch = { Punch = function() end } } })()

for i = 1, 20 do
	assert(step(true, true, 100, i / 10) == 100, 'Walking runs at the full chosen speed')
end
assert(attrs.SonicBurstActive ~= true, 'Walking never breaks the barrier')
attrs.IsBoosting = true
assert(step(true, true, 100, 2.1) == 100, 'A sprint starts at 100% of the chosen speed (no reduction)')
for i = 22, 52 do
	step(true, true, 100, i / 10)
end
assert(attrs.SonicBurstActive == true and math.abs(step(true, true, 100, 5.3) - 102) < 0.1, 'After 3.0 s it breaks the barrier: 102% (+2% boost) and the wider FOV')
assert(plays >= 1, 'Breaking the barrier triggers the GlassShatter impact')
local playsBefore = plays
attrs.IsBoosting = false
step(true, true, 100, 5.4)
assert(attrs.SonicBurstActive == false, 'Letting go of the sprint ends it')
attrs.IsBoosting = true
for i = 55, 86 do
	step(true, true, 100, i / 10)
end
assert(attrs.SonicBurstActive == true, 'A new sprint breaks it again')
assert(plays > playsBefore, 'Breaking it again plays GlassShatter again')
print('PASS sprint: 100% initial -> 102% after 3.0 s with GlassShatter and wider FOV, again after each release')
