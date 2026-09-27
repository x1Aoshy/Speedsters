local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")
local serde = require("@lune/serde")
local layout = require("../src/common/ReplicatedStorage/Shared/TutorialGuideLayout")
local checks = 0
for _, viewport in {{320,568}, {375,667}, {667,290}, {844,326}, {1024,700}, {1366,700}, {1920,1012}} do
	local vw,vh = viewport[1],viewport[2]
	for _, rect in {{10,10,50,50}, {vw-70,10,60,50}, {vw-90,vh-70,75,50}, {10,vh-70,50,50}, {vw*0.6,vh*0.4,80,40}, {vw*0.3,vh*0.2,70,50}} do
		local c = layout.Place(vw,vh,unpack(rect))
		assert(c.x >= 0 and c.y >= 0 and c.x+c.w <= vw and c.y+c.h <= vh, "Card outside viewport")
		local overlap = math.max(0,math.min(c.x+c.w,rect[1]+rect[3])-math.max(c.x,rect[1]))
			* math.max(0,math.min(c.y+c.h,rect[2]+rect[4])-math.max(c.y,rect[2]))
		assert(overlap == 0, "Guide hides button")
		checks += 1
	end
end
print("PASS", checks, "viewport/target layouts, including small landscape and portrait")

-- Execute the actual event closures with mocked external services, retaining lexical scope.
local source = fs.readFile("src/common/ServerScriptService/Admin/AdminAbusePanelService.server.luau")
local a = assert(source:find("local playMusic, boost, announce",1,true))
local b = assert(source:find("local function stopEvent",a,true))
local block = source:sub(a,b-1) .. [[
playMusic = function(id) record.music = id end
boost = function(stat) record[stat] = (record[stat] or 0) + 1 end
announce = function() record.announced = true end
return {start = startRainingTacos, stop = stopRainingTacos}
]]
local attrs, timers, record, serial = {}, {}, {}, 0
local env = {
	eventTokens = {}, record = record,
	Workspace = {SetAttribute = function(_,key,value) attrs[key] = value end, GetServerTimeNow = function() return 1000 end},
	HttpService = {GenerateGUID = function() serial += 1; return tostring(serial) end},
	Panel = {FireAllClients = function(_, payload) record.effect = payload end},
	Remotes = {FindFirstChild = function() return nil end},
	task = {delay = function(_,callback) table.insert(timers,callback) end},
}
local event = luau.load(block, {environment = env})()
event.start(60, {UserId = 1, Name = "Test"})
assert(attrs.AdminRainingTacosUntil == 1060 and record.music and record.announced)
assert(record.Speed == 1 and record.Wins == 1 and record.effect.duration == 60)
event.start(120, nil)
timers[1]()
assert(attrs.AdminRainingTacosUntil == 1120, "Old timer stopped restarted event")
timers[2]()
assert(attrs.AdminRainingTacosUntil == nil and record.music == nil and record.effect.duration == 0)
event.stop()
print("PASS real event closures: start, effects, boosts, restart, stale timer, expiry, repeated stop")

-- Execute model construction with Roblox datatypes and real serialized instances.
local assets = rb.deserializeModel(fs.readFile("src/ui/TacoEventAssets.rbxm"))[1]
local shared = rb.Instance.new("Folder")
assets.Parent = shared
local module = rb.Instance.new("ModuleScript")
module.Parent = shared
local visual = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/TacoVisual.luau"), {environment = {
	script = module, game = {GetService = function() return {IsClient = function() return false end} end},
	Instance = rb.Instance, Enum = rb.Enum, Color3 = rb.Color3, CFrame = rb.CFrame, Vector3 = rb.Vector3,
}})()
local part = rb.Instance.new("Part")
part.CFrame = rb.CFrame.new(1,2,3)
visual.Decorate(part, 1.1)
assert(part:FindFirstChild("OriginalTaco"), "Original mesh was not cloned")
local mesh = part.OriginalTaco
assert(math.abs(math.max(mesh.Size.X,mesh.Size.Y,mesh.Size.Z)-2.75)<0.001, "Original taco not normalized")
assert(not mesh.CanCollide and not mesh.Anchored and mesh.Massless)
assert(mesh:FindFirstChildOfClass("WeldConstraint"))
print("PASS original V40 mesh cloning, normalization and noncolliding attachment")

local effects = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Admin/AdminAbuseEffects.client.luau")
local updateStart = assert(effects:find("local function updateTacos", 1, true))
local updateEnd = assert(effects:find("-- The sky under the events", updateStart, true))
local updateSource = effects:sub(updateStart, updateEnd - 1) .. "\nreturn updateTacos"
local impacts, spawns = 0, 0
for _, groundY in {0, -120, 500} do
	local part = {Parent = true, Destroy = function(self) self.Parent = nil end}
	local list = {{Part = part, Pos = rb.Vector3.new(0, groundY + 5, 0), Drift = rb.Vector3.zero,
		Speed = 70, Born = os.clock(), Angles = rb.Vector3.zero, Rot = rb.Vector3.zero}}
	local white = rb.Color3.new(1,1,1)
	local atmosphere = {Density=0,Haze=0,Glare=0,Color=white,Decay=white}
	local world = {CurrentCamera = {CFrame=rb.CFrame.new(0,groundY+10,0)},
		Raycast = function(_, origin, delta)
			if origin.Y + delta.Y <= groundY then
				return {Instance={CanCollide=true,Transparency=1},Position=rb.Vector3.new(0,groundY,0)}
			end
			return nil
		end}
	local update = luau.load(updateSource, {environment = {
		tacosActive = function() return true end, tacosWeight = 1,
		tacos = {Music={}, Original=atmosphere, Atmosphere=table.clone(atmosphere), Tint={}},
		TACOS = {BlendSeconds=1.6,Atmosphere=atmosphere,TintColor=white,Saturation=0,Contrast=0,Brightness=0,SpawnInterval=0.14},
		lerp = function(a,b,t) return a+(b-a)*t end,
		Workspace=world, character=function() return nil,nil end, Players={GetPlayers=function() return {} end},
		tacoRayParams={},tacoList=list,nextTacoSpawn=math.huge,Vector3=rb.Vector3,CFrame=rb.CFrame,Color3=rb.Color3,
		TacoVisual={EnsureVisible=function() end},
		spawnFallingTaco=function() spawns+=1 end,tacoGroundCrash=function() impacts+=1 end,
	}})()
	update(0.1)
	assert(#list == 0 and not part.Parent, "Taco did not collide and clean up")
end
assert(impacts == 3 and spawns == 0)
print("PASS actual rain update: swept ground impact + cleanup at heights 0, -120, 500, including invisible solid floors")
fs.writeFile("output/TacosTutorialRepair/test-results.json", serde.encode("json", {
	layoutCases = checks, eventLifecycle = true, originalMesh = true, rainCollisionCases = impacts, studioPlaytest = false,
}, true))
