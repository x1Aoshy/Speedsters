local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")
local serde = require("@lune/serde")
local function config(world)
	local stub = { GetAttribute = function(_, name) return name == "PlaceWorldNumber" and world or nil end, FindFirstChild = function(_, name) return name == "neworld1" and world == 1 and {} or nil end }
	return luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/Config.luau"), { environment = { game = { PlaceId = 0, GetService = function() return stub end }, workspace = stub, Vector3 = rb.Vector3, Color3 = rb.Color3, CFrame = rb.CFrame, Enum = rb.Enum } })()
end
local source = fs.readFile("src/common/ServerScriptService/Progression/LevelProgress.server.luau")
local a = assert(source:find("local START_LEVEL", 1, true))
local b = assert(source:find("local function ensureNumber", a, true))
local requirement = luau.load(source:sub(a, b-1) .. "\nreturn getRequirement")()
local suits = luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/SuitCatalog.luau"))()
local report = {}
local c1, c2 = config(1), config(2)
for _, cosmeticProduct in { 1, 100, 1000000 } do
	local ownedIndex, elapsed = 1, 0
	for rebirths = 0, 15 do
		local cfg = if rebirths >= 7 then c2 else c1
		local profiles = if rebirths >= 7 then cfg.World2TreadmillProfiles else cfg.NewWorld1TreadmillProfiles
		local treadmill = 1
		for _, profile in profiles do
			if not profile.GamePassId and not profile.SpawnedAtRuntime and rebirths >= (profile.RequiredRebirths or 0) then treadmill = math.max(treadmill, profile.BaseGain) end
		end
		local target = cfg.RebirthFirstLevelRequired + cfg.RebirthLevelStep * rebirths
		local seconds, speedNeeded = 0, 0
		for level = 1, target-1 do
			while suits.Ordered[ownedIndex+1] and suits.Ordered[ownedIndex+1].RequiredLevel <= level and (suits.Ordered[ownedIndex+1].RequiredRebirths or 0) <= rebirths do ownedIndex += 1 end
			local need = requirement(level, rebirths == 0)
			if rebirths == 0 and level == 1 then need *= 0.23 end
			local suit = cfg.SuitSpeedGainMultipliers[suits.Ordered[ownedIndex].Id] or 1
			local rate = treadmill / cfg.TreadmillTrainingTickSeconds * suit * cfg.RebirthMultiplierPerRebirth^rebirths * cosmeticProduct
			seconds += need/rate
			speedNeeded += need
		end
		elapsed += seconds
		local row = { cosmeticProduct = cosmeticProduct, rebirth = rebirths+1, levelRequired = target, seconds = seconds, cumulativeSeconds = elapsed, speedNeeded = speedNeeded, treadmillGain = treadmill, suit = suits.Ordered[ownedIndex].Id }
		table.insert(report, row)
		if cosmeticProduct == 1000000 or rebirths < 7 and cosmeticProduct == 1 then print(serde.encode("json", row)) end
	end
end
fs.writeFile("output/LoopReview_20260920/pacing.json", serde.encode("json", report, true))
print("Assumptions: continuous best free treadmill, immediately equip unlocked suits, fixed aura*trail multiplier, no potions/VIP/events, rebirth at eligibility. Analytical training times exclude travel and earning cosmetics.")
