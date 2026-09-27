local fs = require("@lune/fs")
local PlaceFiles = require("./place_files")
local roblox = require("@lune/roblox")

print("==================================================")
print("[Test] Verifying V40 VFX & Admin Abuse Suite")
print("==================================================")

local passed = 0
local failed = 0

local function assertTest(condition: boolean, desc: string)
	if condition then
		print("PASS: " .. desc)
		passed += 1
	else
		print("FAIL: " .. desc)
		failed += 1
	end
end

-- 1. Check AdminAbuseEffects.client.luau
local effectsSource = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Admin/AdminAbuseEffects.client.luau")

assertTest(
	effectsSource:find("rbxassetid://75964117535029") ~= nil,
	"Fireworks launch sound ID 75964117535029 configured"
)
assertTest(
	effectsSource:find("rbxassetid://126237860088652") ~= nil,
	"Fireworks boom sound ID 126237860088652 configured"
)
assertTest(
	effectsSource:find("FireworkStartup") ~= nil and effectsSource:find("rbxassetid://10439119562") ~= nil,
	"FireworkStartup launch VFX with shards texture present"
)
assertTest(
	effectsSource:find("PixelBurst57") ~= nil and effectsSource:find("rbxassetid://116373783921886") ~= nil,
	"FireworkBurst V40 shockwave ring particle present"
)
assertTest(
	effectsSource:find("for i = 1, 5 do") ~= nil and effectsSource:find("show.Burst%(peak %+ offset") ~= nil,
	"Multi-burst sequence (~6 explosions) configured to match audio pops"
)
assertTest(
	effectsSource:find("updateSnowShivering") ~= nil and effectsSource:find("rootJoint%.C0") ~= nil,
	"Snow character shivering joint jitter configured"
)
assertTest(
	effectsSource:find("restoreSnowShivering") ~= nil and effectsSource:find("ColdBreathAttachment") ~= nil,
	"Snow shivering restore and cold breath vapor configured"
)

-- 2. Check AdminAbusePanelService.server.luau
local panelServiceSource = fs.readFile("src/common/ServerScriptService/Admin/AdminAbusePanelService.server.luau")

assertTest(
	panelServiceSource:find('boost%("Speed", 2') ~= nil,
	"Admin Abuse Snow event activates 2x Speed boost"
)
assertTest(
	panelServiceSource:find('boost%("Wins", 2') ~= nil,
	"Admin Abuse Confetti event activates 2x Wins boost"
)

-- 3. Check TreadmillVfxController.client.luau
local treadmillSource = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Gameplay/TreadmillVfxController.client.luau")

assertTest(
	treadmillSource:find("IsOnTreadmill") ~= nil,
	"Treadmill controller checks IsOnTreadmill attribute"
)
assertTest(
	treadmillSource:find("isOnTreadmillRaycast") ~= nil,
	"Treadmill controller has downward raycast detection"
)
assertTest(
	treadmillSource:find("rbxassetid://13828261486") ~= nil,
	"Treadmill speed lines use V40 lines texture (13828261486)"
)
assertTest(
	treadmillSource:find("rbxassetid://16846725471") ~= nil,
	"Treadmill floor pulse uses V40 floorfire texture (16846725471)"
)
assertTest(
	treadmillSource:find("DragonGingeriniFloorpart") ~= nil,
	"Treadmill controller integrates V40 DragonGingeriniFloorpart template"
)

-- 4. Check Place Files
local places = {
	{ name = PlaceFiles.World1, barriers = 24 },
	{ name = PlaceFiles.World2, barriers = 23 },
	{ name = PlaceFiles.World3, barriers = 33 },
}

for _, pinfo in ipairs(places) do
	local raw = fs.readFile(pinfo.name)
	local dm = roblox.deserializePlace(raw)

	local rs = dm:FindFirstChild("ReplicatedStorage")
	assertTest(rs ~= nil, pinfo.name .. " has ReplicatedStorage")
	local vfx = rs and rs:FindFirstChild("VfxTemplates")
	assertTest(vfx ~= nil, pinfo.name .. " has ReplicatedStorage.VfxTemplates")

	local fw = vfx and vfx:FindFirstChild("Fireworks")
	assertTest(
		fw and fw:FindFirstChild("FireworkStartup") ~= nil and fw:FindFirstChild("FireworkBurst") ~= nil,
		pinfo.name .. " has Fireworks templates (FireworkStartup & FireworkBurst)"
	)

	local tm = vfx and vfx:FindFirstChild("Treadmill")
	assertTest(
		tm and tm:FindFirstChild("DragonGingeriniFloorpart") ~= nil,
		pinfo.name .. " has Treadmill template (DragonGingeriniFloorpart)"
	)

	local sp = dm:FindFirstChild("StarterPlayer")
	local sps = sp and sp:FindFirstChild("StarterPlayerScripts")
	local gp = sps and sps:FindFirstChild("Gameplay")
	assertTest(
		gp and gp:FindFirstChild("TreadmillVfxController") ~= nil,
		pinfo.name .. " has StarterPlayerScripts.Gameplay.TreadmillVfxController"
	)

	local function isBarrierPart(part)
		if not part or not part:IsA("BasePart") then return false end
		if part:GetAttribute("IsBarrier") == true or part:GetAttribute("World2WallFlightBarrier") == true then
			return true
		end
		local name = part.Name:lower()
		if name == "barrier" or name == "barriers" or name == "wallflightbarrier" then
			return true
		end
		local parent = part.Parent
		if parent and (parent.Name:lower() == "barriers" or parent.Name == "World2WallFlightBarriers_Runtime") then
			return true
		end
		return false
	end

	-- Verify flight barriers in Workspace are strictly preserved
	local barrierCount = 0
	local ws = dm:FindFirstChild("Workspace")
	if ws then
		for _, desc in ipairs(ws:GetDescendants()) do
			if isBarrierPart(desc) then
				barrierCount += 1
			end
		end
	end
	assertTest(
		barrierCount == pinfo.barriers,
		string.format("%s preserved all %d flight barriers (found: %d)", pinfo.name, pinfo.barriers, barrierCount)
	)
end

print("==================================================")
print(string.format("RESULTS: %d PASSED, %d FAILED", passed, failed))
print("==================================================")

if failed > 0 then
	error("Test suite failed with " .. failed .. " errors")
end
