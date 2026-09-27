-- test_daily_login_ui.luau
-- The Daily Login panel (Sung's review, 2026-09-18): every day the player has claimed says
-- "Claimed" and is shaded as done, not only Day 1; the next day says "Today"; later days
-- stay locked; Claim is live only when a reward is ready. Runs the controller's own card
-- setup, refresh and shading on the real panel from each place.
local fs = require("@lune/fs")
local PlaceFiles = require("./place_files")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local controller = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/DailyRewardController.client.luau")
local function between(first, last)
	local a = assert(string.find(controller, first, 1, true), "chunk " .. first)
	local b = assert(string.find(controller, last, a, true), "chunk end " .. last)
	return string.sub(controller, a, b - 1)
end
local chunk = between("local buttons = {}", "-- Every day card shipped with LayoutOrder")
	.. between("daysFrame.ZIndex = 10", "local OPEN_POS")
	.. "\nreturn cards, refresh, function(value) state = value; stateReceivedAt = os.clock(); baseSecondsRemaining = tonumber(value.SecondsRemaining) or 0 end, claimButton"

local function load(file, env)
	return luau.load(fs.readFile(file), { environment = setmetatable(env or {}, { __index = _G }) })()
end
local Data = load("src/common/ReplicatedStorage/Shared/DailyRewardsData.luau", { Color3 = roblox.Color3 })
local DailyRewards = load("src/common/ReplicatedStorage/Shared/DailyRewards.luau", {
	game = { GetService = function()
		return { WaitForChild = function(self)
			return self
		end }
	end },
	require = function()
		return Data
	end,
})

for _, world in { "World1", "World2", "World3" } do
	local place = roblox.deserializePlace(fs.readFile(PlaceFiles[world]))
	local daysFrame = place:GetService("StarterGui").DailyReward.Days31:Clone()
	local env = setmetatable({
		daysFrame = daysFrame,
		scroll = daysFrame.ScrollingFrame,
		resultLabel = daysFrame.RewardResult,
		DailyRewards = DailyRewards,
		Instance = roblox.Instance,
		Color3 = roblox.Color3,
		UDim2 = roblox.UDim2,
		UDim = roblox.UDim,
		Vector2 = roblox.Vector2,
		Enum = roblox.Enum,
	}, { __index = _G })
	local cards, refresh, setState, claimButton = luau.load(chunk, { environment = env })()

	-- Days 1-8 claimed, Day 9 ready (the review's screenshot).
	local claimedDays = {}
	for day = 1, 8 do
		table.insert(claimedDays, day)
	end
	setState({ ClaimedDays = claimedDays, NextDay = 9, CanClaim = true, SecondsRemaining = 0 })
	refresh()
	for day = 1, 8 do
		local card = cards[day]
		assert(card.Status and card.Status.Visible and card.Status.Text == "Claimed", world .. ": Day " .. day .. " says Claimed")
		assert(card.Shade and card.Shade.Visible, world .. ": Day " .. day .. " is shaded as done")
		assert(card.Status.ZIndex > card.Shade.ZIndex and card.Day.ZIndex > card.Shade.ZIndex and card.Amount.ZIndex > card.Shade.ZIndex,
			world .. ": Day " .. day .. "'s texts stay on top of the shade")
	end
	assert(cards[9].Status.Visible and cards[9].Status.Text == "Today" and not cards[9].Shade.Visible, world .. ": Day 9 is today's, not shaded")
	for day = 10, 12 do
		assert(not cards[day].Status.Visible and not cards[day].Shade.Visible, world .. ": Day " .. day .. " shows no status")
		if cards[day].Locked then
			assert(cards[day].Locked.Visible, world .. ": Day " .. day .. " is locked")
		end
	end
	assert(claimButton.Active == true, world .. ": Claim is live while Day 9 is ready")

	-- Claimed today: Day 9 turns Claimed, Claim waits for tomorrow.
	table.insert(claimedDays, 9)
	setState({ ClaimedDays = claimedDays, NextDay = 10, CanClaim = false, SecondsRemaining = 3600 })
	refresh()
	assert(cards[9].Status.Text == "Claimed" and cards[9].Shade.Visible, world .. ": the day just claimed says Claimed")
	assert(cards[10].Status.Visible == false and cards[10].Shade.Visible == false, world .. ": tomorrow's day waits")
	assert(claimButton.Active == false, world .. ": Claim is off until the next reward")

	-- An old save that lists only some days still shows every earlier day as claimed.
	setState({ ClaimedDays = { 1 }, NextDay = 5, CanClaim = true, SecondsRemaining = 0 })
	refresh()
	for day = 1, 4 do
		assert(cards[day].Status.Text == "Claimed" and cards[day].Status.Visible, world .. ": Day " .. day .. " before the next day is claimed")
	end
end
-- Sung (2026-09-18): the panel ran off the right edge and "Claim" could not be reached.
-- Measured as it really shows, it is shrunk to at most 80% of the screen each way.
do
	local fitChunk = between("-- The panel always stays whole on the screen", "-- The Claim button is always on top")
	local noSignal = { Connect = function() end }
	local screen = roblox.Vector2.new(844, 390)
	local frame = { Size = roblox.UDim2.new(0.32, 0, 0.586, 0), AbsoluteSize = roblox.Vector2.new(900, 700) }
	function frame:GetPropertyChangedSignal()
		return noSignal
	end
	local gui = { AbsoluteSize = screen }
	function gui:GetPropertyChangedSignal()
		return noSignal
	end
	local fitOnScreen = luau.load(fitChunk .. "\nreturn fitOnScreen", {
		environment = setmetatable({ daysFrame = frame, gui = gui, UDim2 = roblox.UDim2 }, { __index = _G }),
	})()
	fitOnScreen()
	local factor = frame.Size.X.Scale / 0.32
	assert(900 * factor <= 0.8 * screen.X + 0.5 and 700 * factor <= 0.8 * screen.Y + 0.5, ("An oversized panel is shrunk inside 80%% of the screen (x%.2f)"):format(factor))
	assert(math.abs(frame.Size.Y.Scale / 0.586 - factor) < 1e-6, "...evenly, keeping its shape")
	frame.Size = roblox.UDim2.new(0.32, 0, 0.586, 0)
	frame.AbsoluteSize = roblox.Vector2.new(270, 211)
	fitOnScreen()
	assert(math.abs(frame.Size.X.Scale - 0.32) < 1e-6, "A panel that fits keeps the designer's size")
	assert(string.find(controller, 'local request = Remotes:WaitForChild("DailyLoginRequest", 30)', 1, true), "The client waits for the server's remote (it used to find nothing and never claim)")
	assert(string.find(controller, "if request and claimReady() then\n\t\t\trequest:FireServer(\"Claim\")", 1, true), "Claim asks whenever the button says Claim; the server decides")
	assert(string.find(controller, "return state == nil or state.CanClaim == true or getRemainingSeconds() <= 0", 1, true), "...a countdown run out here counts")
	print("PASS Daily Login fit: an oversized panel is shrunk inside 80% of the screen; Claim waits for its remote and always asks when shown")
end

print("PASS Daily Login: every claimed day says Claimed and is shaded (not only Day 1), today says Today, later days wait, Claim only when ready, in all three places")
