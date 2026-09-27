--!strict
-- audit/test_onboarding_flow.luau
-- The first-session flow: Update Logs hand off to the daily reward, the daily
-- panel actually lands on a claimable day, and the Starter Pack offer exists at
-- all (the server side shipped without any UI to sell it).

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local Enum = roblox.Enum

local logs = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/UpdateLogsController.client.luau")
local daily = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/DailyRewardController.client.luau")
local offer = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/StarterPackOffer.client.luau")

-- 1. Closing the Update Logs opens the daily reward, not the parked codes panel.
assert(string.find(logs, 'MenuEvents.Get("OpenDailyPanel"):Fire("Open")', 1, true),
	"Closing the Update Logs must open the daily reward")
assert(not string.find(logs, 'MenuEvents.Get("OpenCodesModal"):Fire("Open")', 1, true),
	"The Update Logs must no longer chain into the parked codes panel")

-- 2. The daily panel improvements.
assert(string.find(daily, "scrollToClaimableDay", 1, true),
	"The daily panel must scroll to the day the player can claim")
assert(string.find(daily, "setClaimEnabled", 1, true),
	"The claim button must show whether there is anything to claim")
assert(string.find(daily, "table.sort(unclaimed", 1, true),
	"Day cards must resolve their labels by layout, not only by placeholder text")
assert(string.find(daily, "card.Frame.LayoutOrder = day", 1, true),
	"Day cards must carry a LayoutOrder or the list can render them out of order")
assert(string.find(daily, "Enum.FillDirection.Horizontal", 1, true),
	"The auto-scroll must follow the list's real axis; the day list is horizontal")

-- 3. The Starter Pack offer is wired end to end.
assert(string.find(offer, "StarterPackClaim:FireServer()", 1, true), "The offer must claim through the server remote")
assert(string.find(offer, "PromptGamePassPurchase", 1, true), "The offer must prompt the gamepass")
assert(string.find(offer, "alreadyOwned", 1, true), "The offer must hide once the player owns the pack")
assert(string.find(offer, "StarterPackVisibleSeconds", 1, true), "The offer must respect its timer")

local purchases = fs.readFile("src/common/ServerScriptService/Economy/SpeedProductPurchases.server.luau")
assert(string.find(purchases, "StarterPackClaim", 1, true), "The server must expose the StarterPackClaim remote")
assert(string.find(purchases, "grantStarterPackOnce", 1, true), "The server must grant the pack exactly once")

-- 4. Both worlds actually ship all three scripts.
local serde = require("@lune/serde")
local manifest = serde.decode("json", fs.readFile("src/manifest.json"))
local REQUIRED = {
	"StarterPlayer/StarterPlayerScripts/UI/StarterPackOffer",
	"StarterPlayer/StarterPlayerScripts/UI/DailyRewardController",
	"StarterPlayer/StarterPlayerScripts/UI/UpdateLogsController",
}
for _, world in ipairs({ "World1", "World2" }) do
	for _, path in ipairs(REQUIRED) do
		local found = false
		for _, row in ipairs(manifest.worlds[world].scripts) do
			if row.legacyPath == path then found = true end
		end
		assert(found, world .. " is missing " .. path)
	end
end

-- 5. The authored daily GUI still has the pieces the controller drives.
for _, place in ipairs({ "World1Update3New.rbxl", "World2Update3new.rbxl" }) do
	local game = roblox.deserializePlace(fs.readFile(place))
	local gui = game:GetService("StarterGui"):FindFirstChild("DailyReward")
	assert(gui, place .. ": DailyReward ScreenGui missing")
	local days = gui:FindFirstChild("Days31")
	assert(days, place .. ": DailyReward.Days31 missing")
	local scroll = days:FindFirstChild("ScrollingFrame")
	assert(scroll and scroll:IsA("ScrollingFrame"), place .. ": day list missing")
	local cards = 0
	for _, child in ipairs(scroll:GetChildren()) do
		if string.match(child.Name, "^Day%d+$") then cards += 1 end
	end
	-- DailyRewardsData.TotalDays is the source of truth; the frame is just named Days31.
	local totalDays = tonumber(string.match(fs.readFile("src/common/ReplicatedStorage/Shared/DailyRewardsData.luau"),
		"TotalDays%s*=%s*(%d+)")) or 30
	assert(cards == totalDays, string.format("%s: expected %d day cards, found %d", place, totalDays, cards))

	local layout = scroll:FindFirstChildOfClass("UIListLayout")
	assert(layout, place .. ": day list has no UIListLayout")
	if layout.SortOrder == Enum.SortOrder.LayoutOrder then
		local zeroed = 0
		for _, child in ipairs(scroll:GetChildren()) do
			if string.match(child.Name, "^Day%d+$") and child.LayoutOrder == 0 then zeroed += 1 end
		end
		assert(zeroed > 1, place .. ": authored LayoutOrder changed; the controller's numbering may now fight it")
	end
	assert(days:FindFirstChild("RewardResult"), place .. ": RewardResult label missing")
	print(string.format("PASS %s: daily panel has %d day cards and its result label", place, cards))
end

print("ALL ONBOARDING FLOW CHECKS PASSED")
