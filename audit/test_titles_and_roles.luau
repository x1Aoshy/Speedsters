-- audit/test_titles_and_roles.luau
-- Comprehensive verification of the Tester & Dev roles, overhead titles, and test build removal.

local fs = require("@lune/fs")
local PlaceFiles = require("./place_files")
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")

local failures = 0
local function check(condition: boolean, message: string)
	if condition then
		print("  PASS: " .. message)
	else
		print("  FAIL: " .. message)
		failures += 1
	end
end

print("=== 1. VERIFY TEST BUILD WATERMARK REMOVED ===")
local watermarkSource = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/TesterWatermarkController.client.luau")
check(string.find(watermarkSource, "%[TESTER BUILD %- AUTHORIZED%]") == nil, "src/ TesterWatermarkController does not display [TESTER BUILD - AUTHORIZED]")

for _, placeFile in ipairs(PlaceFiles.Files()) do
	local data = fs.readFile(placeFile)
	local gameInst = roblox.deserializePlace(data)
	local sc = nil
	local function search(inst)
		if inst.Name == "TesterWatermarkController" then
			sc = inst
			return
		end
		for _, c in ipairs(inst:GetChildren()) do
			search(c)
		end
	end
	search(gameInst)
	if sc then
		check(string.find(sc.Source, "%[TESTER BUILD %- AUTHORIZED%]") == nil, placeFile .. " TesterWatermarkController is disabled/cleared")
	else
		check(true, placeFile .. " has no active watermark script")
	end
end

print("\n=== 2. VERIFY TESTERS & DEVS IN CONFIG ===")
local configSource = fs.readFile("src/common/ReplicatedStorage/Shared/Config.luau")
local okCompile, errCompile = pcall(luau.compile, configSource)
check(okCompile, "Config.luau compiles cleanly" .. (if not okCompile then ": " .. tostring(errCompile) else ""))

local expectedTesters = {
	"Himothy09871",
	"RealWhisper0909",
	"jay_1231600",
	"Fabbyy_YT",
	"DripReeper",
	"techssasinbadass",
	"Supermangolflow",
}

for _, tester in ipairs(expectedTesters) do
	check(string.find(configSource, string.lower(tester), 1, true) ~= nil, "Config contains tester: " .. tester)
end

-- 2026-09-26 (owner): Gekkoh (767108248 / spartakiller45 / gekkoh) is no longer a forced DEV.
check(string.find(configSource, "[111827288] = true, -- pxuto", 1, true) ~= nil, "Config contains dev userId: 111827288")
check(string.find(configSource, '["gekkoh"] = true', 1, true) == nil and string.find(configSource, "[767108248] = true", 1, true) == nil,
	"Config no longer forces Gekkoh to DEV")

print("\n=== 3. VERIFY CHAT ROLE TAGS (VipChatTag.client.luau) ===")
local chatTagSource = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/VipChatTag.client.luau")
local okChat, errChat = pcall(luau.compile, chatTagSource)
check(okChat, "VipChatTag.client.luau compiles cleanly" .. (if not okChat then ": " .. tostring(errChat) else ""))
check(string.find(chatTagSource, "%[Tester%]") ~= nil, "VipChatTag includes [Tester] tag")
check(string.find(chatTagSource, "%[DEV%]") ~= nil, "VipChatTag includes [DEV] tag")
check(string.find(chatTagSource, "%[VIP%]") ~= nil, "VipChatTag includes [VIP] tag")

print("\n=== 4. VERIFY REPLICATEDSTORAGE.TITLES IN ALL WORLDS ===")
for _, placeFile in ipairs(PlaceFiles.Files()) do
	local data = fs.readFile(placeFile)
	local gameInst = roblox.deserializePlace(data)
	local repStorage = gameInst:FindFirstChildOfClass("ReplicatedStorage")
	local titles = repStorage and repStorage:FindFirstChild("Titles")
	check(titles ~= nil, placeFile .. " has ReplicatedStorage.Titles")
	if titles then
		local testerPart = titles:FindFirstChild("Tester")
		check(testerPart ~= nil and testerPart:IsA("BasePart"), placeFile .. " Titles has Tester part")
		if testerPart then
			local att = testerPart:FindFirstChild("Title")
			check(att ~= nil and att:IsA("Attachment"), placeFile .. " Tester has Title attachment")
			local bbg = att and att:FindFirstChild("BillboardGui")
			check(bbg ~= nil and bbg:IsA("BillboardGui"), placeFile .. " Tester has BillboardGui")
			local tl = bbg and bbg:FindFirstChild("Title")
			check(tl ~= nil and tl:IsA("TextLabel"), placeFile .. " Tester has TextLabel")
			local peCount = 0
			for _, c in ipairs(testerPart:GetChildren()) do
				if c:IsA("ParticleEmitter") then peCount += 1 end
			end
			check(peCount > 0, placeFile .. " Tester has particle emitters (count=" .. peCount .. ")")
		end

		local devPart = titles:FindFirstChild("Dev")
		check(devPart ~= nil and devPart:IsA("BasePart"), placeFile .. " Titles has Dev part")
		if devPart then
			local att = devPart:FindFirstChild("Title")
			check(att ~= nil and att:IsA("Attachment"), placeFile .. " Dev has Title attachment")
			local bbg = att and att:FindFirstChild("BillboardGui")
			check(bbg ~= nil and bbg:IsA("BillboardGui"), placeFile .. " Dev has BillboardGui")
			local tl = bbg and bbg:FindFirstChild("Title")
			check(tl ~= nil and tl:IsA("TextLabel"), placeFile .. " Dev has TextLabel")
			local peCount = 0
			for _, c in ipairs(devPart:GetChildren()) do
				if c:IsA("ParticleEmitter") then peCount += 1 end
			end
			check(peCount > 0, placeFile .. " Dev has particle emitters (count=" .. peCount .. ")")
		end
	end
end

print("\n=== 5. VERIFY SCRIPT COMPILE & FIDELITY ===")
local bsSource = fs.readFile("src/common/ServerScriptService/Bootstrap.server.luau")
local okBs, errBs = pcall(luau.compile, bsSource)
check(okBs, "Bootstrap.server.luau compiles cleanly" .. (if not okBs then ": " .. tostring(errBs) else ""))
check(string.find(bsSource, "attachTitleToCharacter", 1, true) ~= nil, "Bootstrap equips titles to characters")

local ohSource = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/OverheadStats.client.luau")
local okOh, errOh = pcall(luau.compile, ohSource)
check(okOh, "OverheadStats.client.luau compiles cleanly" .. (if not okOh then ": " .. tostring(errOh) else ""))
check(string.find(ohSource, "setupTitleAnimation", 1, true) ~= nil, "OverheadStats animates titles locally")

if failures == 0 then
	print("\nALL TITLES AND ROLES TESTS PASSED (0 failures)!")
else
	print(string.format("\nFAILED: %d errors encountered", failures))
end
assert(failures == 0, "test_titles_and_roles failed")
