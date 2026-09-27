-- test_u4_topbar.luau (Update 4, retention workstream, 2026-09-25)
-- The topbar entry points (PLAN §7.7 §5, as the owner's UI cleanup of 2026-09-25 changed
-- them: every icon moved to the RIGHT, away from Roblox's chat / unibar on the left, and
-- Titles moved to the Main HUD's side menu; blocks 1-2 used to check the left layout):
--   1. UI/TopbarIconsController: every icon built with setRight(), one ordered group
--      Streak / Playtime / Community / Daily / AFK / Settings / crown; the three retention
--      icons open their panels through MenuEvents; Community destroyed once claimed or
--      switched off; retention icons hidden during the tutorial; no Titles, Codes or Quests;
--   2. Shared/RetentionMath.TopbarRightLayout: on 640x360, 667x375, 812x375 and 844x390 phones
--      the group starts after 0.55 W (TopbarPlus: 48 px in from the right, each icon + the
--      gap), every icon reachable, Streak and Playtime always on the bar; desktops keep labels;
--   3. DailyRewardController opens the Streak panel once after the first close when a reward
--      waits (not in the tutorial); BoostNotifier shows Type "Retention" toasts.
-- Run: lune run audit/test_u4_topbar.luau   (from the project root)
local fs = require("@lune/fs")
local M = require("../src/common/ReplicatedStorage/Shared/RetentionMath")

local UI = "src/common/StarterPlayer/StarterPlayerScripts/UI/"
local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end
local function read(path)
	return (fs.readFile(path):gsub("\r\n", "\n"))
end
local function has(source, needle, message)
	assert(string.find(source, needle, 1, true), message .. " (missing: " .. needle .. ")")
end

do
	local source = read(UI .. "TopbarIconsController.client.luau")
	has(source, "\t\t:setTip(data.tip or key)\n\t\t:setRight()\n", "buildIcon aligns every icon right")
	assert(not string.find(source, "setLeft", 1, true) and not string.find(source, "setMid", 1, true), "nothing on the left (Roblox's) or in the top centre")
	has(source, 'local ORDER = { "Streak", "Playtime", "Community", "Daily", "Afk", "Settings", "AdminAbuse" }', "one group, in order")
	for _, pair in { { "Streak", "Streak Rewards" }, { "PlaytimeBoost", "Playtime Boost" }, { "Community", "Community rewards" } } do
		has(source, string.format('request = "%s", panel = "%s"', pair[1], pair[2]), pair[1] .. " opens its designer panel")
	end
	for _, gone in { 'request = "Titles"', 'request = "Codes"', 'request = "Quests"', "TitlesNewCount" } do
		assert(not string.find(source, gone, 1, true), "off the topbar: " .. gone)
	end
	has(source, 'LocalPlayer:GetAttribute("CommunityRewardClaimed") == true or not U4.IsOn("Community")', "Community goes when claimed or off")
	has(source, "icon:destroy()", "the Community icon is destroyed")
	has(source, "removeCommunity()", "removeCommunity wired")
	has(source, 'LocalPlayer:GetAttribute("FirstTimeTutorialActive") == true', "hidden during the tutorial")
	has(source, "if entry and (hidden or not U4.IsOn(entry.feature)) then", "...the retention icons only, and while switched off")
	has(source, '"StreakRewardPending"', "Streak notice")
	has(source, "RetentionMath.TopbarRightLayout(width, items)", "layout from the pure module")
	has(source, 'pcall(IconController.setGap, layout.Gap, "right")', "the gap of the right group")
	has(source, "MenuEvents.Request(data.request)", "icons open panels through MenuEvents")
	for _, key in { "Daily", "Settings" } do
		has(source, key .. " = {", "pane " .. key .. " kept")
	end
	pass("TopbarIconsController: every icon right-aligned in one ordered group, Community destroyed when claimed/off, tutorial hides the retention icons, no Titles / Codes / Quests")
end

do
	local full = {
		{ key = "Streak", label = "21" },
		{ key = "Playtime", label = "+100%" },
		{ key = "Community", fold = 1 },
		{ key = "Daily", fold = 4 },
		{ key = "Afk", fold = 2 },
		{ key = "Settings" },
	}
	for _, screen in { { 640, 360 }, { 667, 375 }, { 812, 375 }, { 844, 390 } } do
		local width = screen[1]
		for _, items in { full, { full[1], full[2], full[4], full[5], full[6] } } do
			local layout = M.TopbarRightLayout(width, items)
			assert(layout.StartX >= 0.55 * width, string.format("%dx%d: starts at %.1f < %.1f", width, screen[2], layout.StartX, 0.55 * width))
			local icons = #layout.Shown + (if #layout.Folded > 0 then 1 else 0)
			assert(48 + 44 * icons <= 0.45 * width, string.format("%dx%d: estimate %d icons", width, screen[2], icons))
			assert(not layout.Labels, "no labels on a phone")
			assert(#layout.Shown + #layout.Folded == #items, "every icon is reachable")
			assert(layout.Shown[1] == "Streak" and layout.Shown[2] == "Playtime", "Streak and Playtime always on the bar, first")
		end
	end
	local narrow = M.TopbarRightLayout(667, full)
	assert(#narrow.Folded == 2 and narrow.Folded[1] == "Community" and narrow.Folded[2] == "Afk", "667: Community and AFK fold into one icon")
	local wide = M.TopbarRightLayout(844, full)
	assert(#wide.Folded == 0 and #wide.Shown == 6 and wide.Size == 40, "844: all six on the bar, 40 px")
	local desktop = M.TopbarRightLayout(1920, full)
	assert(desktop.Labels and desktop.Size == 44 and #desktop.Shown == 6 and desktop.StartX >= 0.55 * 1920, "desktop: 44 px with labels")
	pass("TopbarRightLayout: 640x360, 667x375, 812x375 and 844x390 start after 0.55 W (TopbarPlus offsets and the estimate), Community / AFK fold first, desktop keeps labels")
end

do
	local daily = read(UI .. "DailyRewardController.client.luau")
	has(daily, "openStreakAfterFirstClose()", "called when the Daily finishes closing")
	has(daily, 'player:GetAttribute("StreakRewardPending") ~= true or player:GetAttribute("FirstTimeTutorialActive") == true', "only with a reward waiting, never in the tutorial")
	has(daily, "if streakOfferDone then return end", "once per session")
	has(daily, 'MenuEvents.Request("Streak")', "opens the Streak panel")
	local instantStart = string.find(daily, "if instant then", 1, true)
	local instantEnd = string.find(daily, "if isClosing then return end", instantStart, true)
	assert(instantStart and instantEnd and not string.find(string.sub(daily, instantStart, instantEnd), "openStreakAfterFirstClose", 1, true),
		"the instant close (another menu opening) never offers the Streak panel")
	local notifier = read("src/common/StarterPlayer/StarterPlayerScripts/Gameplay/BoostNotifier.client.luau")
	has(notifier, 'payload.Type == "Retention"', "BoostNotifier takes Retention toasts")
	has(notifier, 'GetAttribute("HidePopups") == true', "HidePopups still honoured")
	for _, name in { "PlaytimeBoostController", "StreakRewardsController" } do
		local source = read(UI .. name .. ".client.luau")
		has(source, "MenuPanelLayout.BindPhoneFit(", name .. " phone fit")
		has(source, "ConsolePanelSupport.Bind(", name .. " gamepad")
		has(source, "MenuEvents.MarkReady(", name .. " MarkReady")
		has(source, "ModalJuice.WatchGui(gui)", name .. " ModalJuice")
		assert(not string.find(source, ':FindFirstChild("Speed")', 1, true) and not string.find(source, ':FindFirstChild("Item1")', 1, true),
			name .. ": duplicated names are never looked up by FindFirstChild")
	end
	pass("Daily -> Streak once after the first close, Retention toasts, both panels bound (phone, gamepad, MenuEvents)")
end

print(string.format("\n%d checks passed", passed))
