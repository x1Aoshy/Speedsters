local fs = require("@lune/fs")
local rb = require("@lune/roblox")

print("=== Starting Quest UI Speed and Badge Overlap Test Suite ===")

-- 1. Test QuestCatalog formatting logic
local catalogSource = fs.readFile("src/common/ReplicatedStorage/Shared/QuestCatalog.luau")
local catalogEnv = setmetatable({}, { __index = getfenv() })
local catalogFn = assert(loadstring(catalogSource, "QuestCatalog"))
setfenv(catalogFn, catalogEnv)
local Catalog = catalogFn()

local formatCases = {
	{ input = 0, expected = "0" },
	{ input = 500, expected = "500" },
	{ input = 1000, expected = "1K" },
	{ input = 1500, expected = "1.5K" },
	{ input = 10000, expected = "10K" },
	{ input = 50000, expected = "50K" },
	{ input = 500000, expected = "500K" },
	{ input = 1e6, expected = "1M" },
	{ input = 2e6, expected = "2M" },
	{ input = 1e33, expected = "1Dc" },
	-- High speed cases that previously produced 20000Dc, 50000Dc, 10000Dc, 5000Dc:
	{ input = 2e37, expected = "20Ud" },
	{ input = 5e37, expected = "50Ud" },
	{ input = 1e37, expected = "10Ud" },
	{ input = 5e36, expected = "5Ud" },
	{ input = 1e36, expected = "1Ud" },
	-- Suffixes up to Vg (tier 22, 10^63)
	{ input = 1e39, expected = "1Dd" },
	{ input = 1e42, expected = "1Td" },
	{ input = 1e45, expected = "1Qad" },
	{ input = 1e48, expected = "1Qid" },
	{ input = 1e51, expected = "1Sxd" },
	{ input = 1e54, expected = "1Spd" },
	{ input = 1e57, expected = "1Ocd" },
	{ input = 1e60, expected = "1Nod" },
	{ input = 1e63, expected = "1Vg" },
}

for _, case in ipairs(formatCases) do
	local res = Catalog.FormatNumber(case.input)
	assert(res == case.expected, string.format("FormatNumber mismatch for %e: got '%s', expected '%s'", case.input, res, case.expected))
end
print("PASS: QuestCatalog.FormatNumber correctly formats all values, including high speed tiers (20Ud, 50Ud, 10Ud, 5Ud)")

-- 2. Verify TaskText generation with high speed
local taskText20Ud = Catalog.TaskText("speed", 2e37)
assert(taskText20Ud == "Earn 20Ud Speed", "Expected 'Earn 20Ud Speed', got '" .. tostring(taskText20Ud) .. "'")
local taskText50Ud = Catalog.TaskText("speed", 5e37)
assert(taskText50Ud == "Earn 50Ud Speed", "Expected 'Earn 50Ud Speed', got '" .. tostring(taskText50Ud) .. "'")
print("PASS: QuestCatalog.TaskText produces 'Earn 20Ud Speed' and 'Earn 50Ud Speed' with zero awkward 5-digit prefixes")

-- 3. Verify RewardText generation with high speed
local speedReward1 = { Kind = "Speed", Share = 0.5 }
local rewardText10Ud = Catalog.RewardText(speedReward1, 20, 2e37)
assert(string.find(rewardText10Ud, "Ud"), "Expected speed reward text to have Ud suffix, got: " .. tostring(rewardText10Ud))
print("PASS: QuestCatalog.RewardText properly formats speed reward with clean suffix: " .. rewardText10Ud)

-- 4. Check all 3 .rbxl places
local places = {
	"World1Update3New.rbxl",
	"World2Update3new.rbxl",
	"World3Update3New.rbxl",
}

for _, p in ipairs(places) do
	print("Checking place file: " .. p)
	local dm = rb.deserializePlace(fs.readFile(p))
	
	-- Check ReplicatedStorage.Shared.QuestCatalog
	local rep = assert(dm:FindFirstChild("ReplicatedStorage"), "Missing ReplicatedStorage in " .. p)
	local shared = assert(rep:FindFirstChild("Shared"), "Missing Shared in " .. p)
	local qc = assert(shared:FindFirstChild("QuestCatalog"), "Missing QuestCatalog in " .. p)
	assert(string.find(qc.Source, '"Vg"'), "QuestCatalog in " .. p .. " is missing Vg suffix")
	assert(string.find(qc.Source, 'scaled >= 999.95'), "QuestCatalog in " .. p .. " is missing overflow carry logic")
	
	-- Check ReplicatedStorage.Shared.QuestUi
	local qu = assert(shared:FindFirstChild("QuestUi"), "Missing QuestUi in " .. p)
	assert(string.find(qu.Source, 'QuantityTextSize'), "QuestUi in " .. p .. " is missing QuantityTextSize")
	assert(string.find(qu.Source, 'Vector2.new%(1, 1%)'), "QuestUi in " .. p .. " is missing Vector2.new(1, 1)")
	
	-- Check StarterGui.QuestGui instances
	local sg = assert(dm:FindFirstChild("StarterGui"), "Missing StarterGui in " .. p)
	local qg = assert(sg:FindFirstChild("QuestGui") or sg:FindFirstChild("Quests"), "Missing QuestGui in " .. p)
	local frame = assert(qg:FindFirstChild("Frame"), "Missing Frame in " .. p)
	
	local checkedBadges = 0
	for _, card in ipairs(frame:GetChildren()) do
		if string.match(card.Name, "^Quest") or string.match(card.Name, "^Quests") then
			local rt = card:FindFirstChild("RewardTemplate")
			if rt then
				for _, item in ipairs(rt:GetChildren()) do
					if item:IsA("ImageLabel") then
						local qty = item:FindFirstChild("Quantity")
						if qty then
							assert(qty.AnchorPoint.X == 1 and qty.AnchorPoint.Y == 1, "Quantity must have AnchorPoint (1, 1)")
							assert(qty.Position.X.Scale == 1 and qty.Position.Y.Scale == 1, "Quantity must have Position (1, 0, 1, 0)")
							assert(qty.TextWrapped == false, "Quantity TextWrapped must be false")
							assert(qty.LineHeight == 1, "Quantity LineHeight must be 1")
							local cap = qty:FindFirstChild("QuantityTextSize")
							assert(cap and cap:IsA("UITextSizeConstraint"), "Quantity must have QuantityTextSize constraint")
							assert(cap.MaxTextSize == 14, "Quantity MaxTextSize must be 14")
							checkedBadges += 1
						end
					end
				end
			end
		end
	end
	assert(checkedBadges >= 9, "Expected at least 9 Quantity badges in " .. p .. ", found " .. checkedBadges)
	print(string.format("  PASS: All %d Quantity badges in %s verified with exact non-overlapping properties", checkedBadges, p))
end

print("\nALL QUEST UI TESTS PASSED SUCCESSFULLY! (100% PASS)")
