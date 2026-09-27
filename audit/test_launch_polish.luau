-- test_launch_polish.luau
-- Verifies the final pre-launch polish items:
-- 1. CosmeticCatalog strikethrough pricing (-7% to -8%)
-- 2. GamePass gift products wiring (non-nil ProductIds)
-- 3. SpinWheel 50M Wins Golden Trophy icon (rbxassetid://15540211845)
-- 4. Mobile responsiveness & scaling (Backpack, DailyLogin, MessageHandler)
-- 5. Topbar Quests icon fix
-- 6. Tester Watermark HUD controller

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local failures = 0
local function check(condition, message)
	if not condition then
		failures += 1
		print("FAIL " .. message)
	end
end

-- 1. CosmeticCatalog
local catalogSource = fs.readFile("src/common/ReplicatedStorage/Shared/CosmeticCatalog.luau")
local okCompile, errCompile = pcall(luau.compile, catalogSource)
check(okCompile, "CosmeticCatalog compiles: " .. tostring(errCompile))

local stubInstance = {}
stubInstance.GetAttribute = function() return nil end
stubInstance.FindFirstChild = function() return nil end
stubInstance.WaitForChild = function() return stubInstance end

local dummyEnv = setmetatable({
	game = { GetService = function() return stubInstance end, PlaceId = 85065221510105 },
	workspace = stubInstance,
	Color3 = roblox.Color3,
	UDim2 = roblox.UDim2,
	UDim = roblox.UDim,
	Vector2 = roblox.Vector2,
	Vector3 = roblox.Vector3,
	Enum = roblox.Enum,
}, { __index = _G })

local Catalog = luau.load(catalogSource, { environment = dummyEnv })()
check(Catalog ~= nil, "Catalog loaded")

local greenAura = Catalog.GetEntry("Aura", "Aura10")
check(greenAura ~= nil, "Aura10 exists")
check(greenAura and greenAura.RobuxPrice == 159, "Aura10 RobuxPrice is 159 R$")
check(greenAura and greenAura.OriginalRobuxPrice == 199, "Aura10 OriginalRobuxPrice is 199 R$")

local redAura = Catalog.GetEntry("Aura", "Aura11")
check(redAura and redAura.RobuxPrice == 199, "Aura11 RobuxPrice is 199 R$")
check(redAura and redAura.OriginalRobuxPrice == 249, "Aura11 OriginalRobuxPrice is 249 R$")

local electricTrail = Catalog.GetEntry("Trail", "Trail08")
check(electricTrail and electricTrail.RobuxPrice == 60, "Trail08 RobuxPrice is 60 R$")
check(electricTrail and electricTrail.OriginalRobuxPrice == 199, "Trail08 OriginalRobuxPrice is 199 R$")

local aura67 = Catalog.GetEntry("Aura", "Aura67")
check(aura67 and aura67.Exclusive == "SpinWheel", "Aura67 remains SpinWheel exclusive")
check(aura67 and aura67.RobuxPrice == nil, "Aura67 has no Robux price")

-- 2. Config GamePass Gifts
local configSource = fs.readFile("src/common/ReplicatedStorage/Shared/Config.luau")
local Config = luau.load(configSource, { environment = dummyEnv })()
check(Config.GamePassGiftProducts ~= nil, "Config.GamePassGiftProducts exists")
for _, entry in ipairs(Config.GamePassGiftProducts or {}) do
	check(entry.ProductId ~= nil and entry.ProductId > 0, "GamePass " .. tostring(entry.Name) .. " has active ProductId: " .. tostring(entry.ProductId))
end

-- 3. SpinWheel 50M Wins icon
local spinCatalogSource = fs.readFile("src/common/ReplicatedStorage/Shared/SpinWheelCatalog.luau")
local SpinCatalog = luau.load(spinCatalogSource, { environment = dummyEnv })()
check(SpinCatalog.IconImages.Wins == "rbxassetid://15540211845", "SpinCatalog.IconImages.Wins is Golden Trophy 15540211845")

local spinModel = roblox.deserializeModel(fs.readFile("src/ui/SpinWheelGui.rbxm"))[1]
local winsSpin = spinModel:FindFirstChild("Frame"):FindFirstChild("WinsSpin")
check(winsSpin ~= nil, "SpinWheelGui has WinsSpin button")
local winsIcon = winsSpin and winsSpin:FindFirstChildOfClass("ImageLabel")
check(winsIcon ~= nil, "WinsSpin has ImageLabel")
local spinExtrasSource = fs.readFile("src/common/ReplicatedStorage/Shared/SpinWheelExtras.luau")
check(string.find(spinExtrasSource, 'icon.Image = "rbxassetid://15540211845"', 1, true) ~= nil, "SpinWheelExtras sets Golden Trophy icon 15540211845")

-- 4. Mobile Responsiveness (Backpack, DailyLogin, Messages)
local backpackSource = fs.readFile("src/common/StarterGui/Backpack/BackpackScript.client.luau")
check(string.find(backpackSource, "PHONE_CARD_SCALE = 0.72", 1, true) ~= nil, "Backpack PHONE_CARD_SCALE is 0.72")
check(string.find(backpackSource, "formatRobuxSaleText", 1, true) ~= nil, "Backpack formatRobuxSaleText exists")
check(string.find(backpackSource, "SaleBadge", 1, true) ~= nil, "Backpack SaleBadge exists")

local dailySource = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/DailyRewardController.client.luau")
check(string.find(dailySource, "OPEN_POS = UDim2.new(0.5, 0, 0.44, 0)", 1, true) ~= nil, "DailyReward OPEN_POS shifted up to 0.44")
check(string.find(dailySource, "FIT_SHARE = 0.76", 1, true) ~= nil, "DailyReward FIT_SHARE is 0.76")

local msgSource = fs.readFile("src/common/StarterGui/Messages/MessageHandler.client.luau")
check(string.find(msgSource, "CARD_HEIGHT = 46", 1, true) ~= nil, "MessageHandler CARD_HEIGHT is 46")
check(string.find(msgSource, "CARD_MIN_WIDTH = 340", 1, true) ~= nil, "MessageHandler CARD_MIN_WIDTH is 340")

-- 5. Quests left the topbar (Update 4, 2026-09-25): they open from the Dr. Eggman lobby NPC.
local topbarSource = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/TopbarIconsController.client.luau")
check(string.find(topbarSource, 'request = "Quests"', 1, true) == nil, "Quests open from Dr. Eggman, not the topbar")

-- 6. Tester Watermark HUD
check(fs.isFile("src/common/StarterPlayer/StarterPlayerScripts/UI/TesterWatermarkController.client.luau"), "TesterWatermarkController exists")
local watermarkSource = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/TesterWatermarkController.client.luau")
local okW, errW = pcall(luau.compile, watermarkSource)
check(okW, "TesterWatermarkController compiles clean: " .. tostring(errW))
check(string.find(watermarkSource, "%[TESTER BUILD %- AUTHORIZED%]") == nil, "Tester watermark displays [TESTER BUILD - AUTHORIZED] removed per user request")

if failures == 0 then
	print("ALL LAUNCH POLISH AUDITS PASSED CLEANLY (0 failures)")
else
	print(string.format("FAILED: %d errors in launch polish audit", failures))
end
assert(failures == 0, "Test launch polish failed")
