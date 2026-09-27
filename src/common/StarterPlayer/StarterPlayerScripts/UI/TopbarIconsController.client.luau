local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")
local MenuEvents = require(ReplicatedStorage.Shared:WaitForChild("MenuEvents"))
local U4 = require(ReplicatedStorage.Shared:WaitForChild("Update4Config"))
local RetentionMath = require(ReplicatedStorage.Shared:WaitForChild("RetentionMath"))

-- TopbarPlus library (renamed to "Icon" in ReplicatedStorage)
local Icon = require(ReplicatedStorage:WaitForChild("Icon"))
local hasIconController, IconController = pcall(function()
	return require(ReplicatedStorage:WaitForChild("Icon"):WaitForChild("IconController", 5))
end)
if not hasIconController or type(IconController) ~= "table" then
	IconController = nil
end

-- Game's own icon images for these exact features
local SETTINGS_IMAGE = "rbxassetid://77188882273275"
local DAILY_IMAGE = "rbxassetid://114699417085635"
local ADMIN_IMAGE = "rbxassetid://10723374641" -- Golden Crown
local AFK_IMAGE = "rbxassetid://91936490991168" -- Hourglass / Clock
local STREAK_IMAGE = "rbxassetid://111530618310401" -- the designer's flame (Streak Rewards.Icon)
local PLAYTIME_IMAGE = "rbxassetid://106015807880493" -- the designer's clock (Playtime Boost)
local COMMUNITY_IMAGE = "rbxassetid://75521963910910"
local NOTICE_RED = Color3.fromRGB(245, 45, 45)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local dailyLoginUpdate = Remotes:FindFirstChild("DailyLoginUpdate")

----------------------------------------------------------------------
-- Update 4 cleanup (2026-09-25, owner): every game icon sits on the RIGHT, one group, left
-- to right: Streak (the day count), Playtime Boost ("+30%"), Community (until claimed), then
-- Daily, AFK Rewards, Settings and the admin crown. Off the topbar: Codes (redeemed in the
-- Shop's Codes section, ShopController), Quests (Dr. Eggman in the lobby opens them through
-- MenuEvents "Quests") and Titles (its own button in the Main HUD's side menu,
-- MainHUDController). The left is Roblox's (menu, chat, the unibar): the old left icons ran
-- into it. The group ends 55 % into the screen (Shared/RetentionMath.TopbarRightLayout):
-- labels only where they fit, smaller icons on phones, and on the narrowest phones
-- Community, AFK, the crown and Daily fold (in that order) into one dropdown icon.
----------------------------------------------------------------------
local ORDER = { "Streak", "Playtime", "Community", "Daily", "Afk", "Settings", "AdminAbuse" }
local FOLD_RANK = { Community = 1, Afk = 2, AdminAbuse = 3, Daily = 4 }

local panes = {
	Daily = {
		image = DAILY_IMAGE,
		request = "Daily",
		panel = "DailyReward",
		tip = "Daily Rewards",
	},
	Settings = {
		image = SETTINGS_IMAGE,
		request = "Settings",
		panel = "Settings",
		tip = "Settings",
	},
}

-- AFK Rewards is a preview feature: its button appears for exactly the players whose panel
-- runs (Shared.FeatureGate). The Spin Wheel has no topbar button: it opens from its own
-- button beside x2 Speed on the Main HUD.
if require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FeatureGate")).IsPreviewPlayer(Players.LocalPlayer) then
	panes.Afk = {
		image = AFK_IMAGE,
		request = "Afk",
		panel = "AfkRewardsGui",
		tip = "AFK Rewards",
	}
end

-- The retention entry points (PLAN §7.7), each opening its designer panel through
-- MenuEvents; hidden during the first-time tutorial and while their feature is off.
local retention = {
	Streak = { image = STREAK_IMAGE, request = "Streak", panel = "Streak Rewards", tip = "Streak Rewards", feature = "Streak" },
	Playtime = { image = PLAYTIME_IMAGE, request = "PlaytimeBoost", panel = "Playtime Boost", tip = "Playtime Boost", feature = "PlaytimeBoost" },
	Community = { image = COMMUNITY_IMAGE, request = "Community", panel = "Community rewards", tip = "Community Rewards", feature = "Community" },
}

local icons = {} -- key -> Icon: the whole right group, laid out by relayout()
local iconData = {} -- key -> its pane
local moreIcon = nil
local relayoutQueued = false

local function panelIsOpen(panelName)
	local gui = playerGui:FindFirstChild(panelName)
	if not gui or not gui.Enabled then return false end
	local dim = gui:FindFirstChild("DimBackground")
	if dim and dim:IsA("GuiObject") then
		return dim.Visible == true
	end
	return gui.Enabled == true
end

-- Builds a topbar icon bound to toggle the given panel
local function buildIcon(key, data)
	local icon = Icon.new()
		:setName(key)
		:setImage(data.image)
		:setOrder(table.find(ORDER, key) or 1)
		:setSize(44, 44)
		:setImageYScale(0.85)
		:setImageRatio(1)
		:setTip(data.tip or key)
		:setRight()

	-- Reflect the panel's open state onto the icon
	local function syncToPanel()
		if panelIsOpen(data.panel) then
			icon:select()
		else
			icon:deselect()
		end
	end

	-- Clicking toggles the panel open/closed
	icon.selected:Connect(function()
		if not panelIsOpen(data.panel) then
			MenuEvents.Request(data.request)
		end
	end)
	icon.deselected:Connect(function()
		if panelIsOpen(data.panel) then
			MenuEvents.Request(data.request)
		end
	end)

	-- Keep the icon's selected state in sync if the panel is closed by its own Close button
	task.spawn(function()
		local panel = playerGui:WaitForChild(data.panel, 15)
		if panel then
			panel:GetPropertyChangedSignal("Enabled"):Connect(function()
				syncToPanel()
			end)
			local dim = panel:FindFirstChild("DimBackground")
			if dim then
				dim:GetPropertyChangedSignal("Visible"):Connect(function()
					syncToPanel()
				end)
			end
			panel.ChildAdded:Connect(function(child)
				if child.Name == "DimBackground" then
					child:GetPropertyChangedSignal("Visible"):Connect(function()
						syncToPanel()
					end)
				end
			end)
		end
	end)

	syncToPanel()
	icons[key] = icon
	iconData[key] = data
	return icon
end

-- A red notice while `isActive()`; cleared the moment it stops.
local function bindNotice(icon, isActive, attributes)
	icon:set("noticeCircleColor", NOTICE_RED, "deselected")
	icon:set("noticeCircleColor", NOTICE_RED, "selected")
	icon:set("noticeTextColor", Color3.fromRGB(255, 255, 255), "deselected")
	icon:set("noticeTextColor", Color3.fromRGB(255, 255, 255), "selected")
	local noticeEnd = Instance.new("BindableEvent")
	local function sync()
		if icon._destroyed then
			return
		end
		local active = isActive()
		if active and icon.totalNotices < 1 then
			icon:notify(noticeEnd.Event)
		elseif not active and icon.totalNotices > 0 then
			noticeEnd:Fire()
			icon:clearNotices()
		end
	end
	for _, attribute in attributes do
		LocalPlayer:GetAttributeChangedSignal(attribute):Connect(sync)
	end
	sync()
	return sync
end

local function tutorialActive()
	return LocalPlayer:GetAttribute("FirstTimeTutorialActive") == true
end

local function labelFor(key)
	if key == "Streak" then
		return tostring(math.max(0, math.floor(tonumber(LocalPlayer:GetAttribute("StreakDays")) or 0)))
	elseif key == "Playtime" then
		local pct = math.floor(tonumber(LocalPlayer:GetAttribute("PlaytimeBoostPct")) or 0)
		return if pct >= (tonumber(U4.Playtime.MaxPercent) or 100) then "MAX" else "+" .. pct .. "%"
	end
	return nil
end

local function communityGone()
	return LocalPlayer:GetAttribute("CommunityRewardClaimed") == true or not U4.IsOn("Community")
end

local function relayout()
	local camera = Workspace.CurrentCamera
	local width = if camera then camera.ViewportSize.X else 0
	if width <= 0 then
		return
	end
	local hidden = tutorialActive()
	-- Everything out of the dropdown first, then placed again.
	-- (2026-09-25 review: a copy, walked once; Icon:leave returns early for an icon whose
	-- container is gone, and a `while #dropdownIcons > 0` loop then never ended.)
	if moreIcon then
		for _, child in table.clone(moreIcon.dropdownIcons) do
			child:leave()
		end
	end
	local items = {}
	for _, key in ORDER do
		local icon = icons[key]
		if icon and not icon._destroyed then
			local entry = retention[key]
			if entry and (hidden or not U4.IsOn(entry.feature)) then
				icon:setEnabled(false)
			else
				table.insert(items, { key = key, label = labelFor(key), fold = FOLD_RANK[key] })
			end
		end
	end
	local layout = RetentionMath.TopbarRightLayout(width, items)
	if IconController and type(IconController.setGap) == "function" then
		pcall(IconController.setGap, layout.Gap, "right")
	end
	for index, key in layout.Shown do
		local icon = icons[key]
		icon:setSize(layout.Size, layout.Size)
		icon:setOrder(index)
		if retention[key] then
			icon:setLabel(if layout.Labels then labelFor(key) or "" else "")
		end
		icon:setEnabled(true)
	end
	if #layout.Folded > 0 then
		if not moreIcon then
			moreIcon = Icon.new():setName("TopbarMore"):setRight():setImageYScale(0.85):setImageRatio(1)
			moreIcon:set("noticeCircleColor", NOTICE_RED, "deselected")
			moreIcon:set("noticeCircleColor", NOTICE_RED, "selected")
		end
		local first = iconData[layout.Folded[1]]
		moreIcon:setImage(first.image)
		moreIcon:setSize(layout.Size, layout.Size)
		moreIcon:setOrder(0) -- the group's left end
		moreIcon:setTip(first.tip)
		moreIcon:setEnabled(true)
		for _, key in layout.Folded do
			local icon = icons[key]
			if retention[key] then
				icon:setLabel("")
			end
			icon:setEnabled(true)
			icon:join(moreIcon, "dropdown")
		end
	elseif moreIcon then
		moreIcon:deselect()
		moreIcon:setEnabled(false)
	end
end

-- Many attribute changes can land in one frame (join): one layout pass for all of them.
local function queueRelayout()
	if relayoutQueued then
		return
	end
	relayoutQueued = true
	task.defer(function()
		relayoutQueued = false
		local ok, err = pcall(relayout)
		if not ok then
			warn("[TopbarIconsController] layout: " .. tostring(err))
		end
	end)
end

for _, key in ORDER do
	local data = panes[key]
	if data then
		local icon = buildIcon(key, data)
		if key == "Daily" then
			-- Notice bubble: shows while a daily gift can be claimed, and clears as
			-- soon as the icon is clicked (the claim panel opens at the same time).
			icon:set("noticeCircleColor", Color3.fromRGB(245, 45, 45), "deselected")
			icon:set("noticeCircleColor", Color3.fromRGB(245, 45, 45), "selected")
			icon:set("noticeTextColor", Color3.fromRGB(255, 255, 255), "deselected")
			icon:set("noticeTextColor", Color3.fromRGB(255, 255, 255), "selected")
			-- 2026-09-26 (owner): "verify the Daily Rewards work". Remotes.DailyLoginUpdate is made by
			-- the server at start (Social/DailyLoginSystem; the places carry none): a client that got
			-- here first used FindFirstChild, found nothing and never showed the notice. Now it waits
			-- for the remote (as UI/DailyRewardController does) and follows the server's
			-- DailyCanClaim attribute too (set on join and on every change).
			local function syncDailyNotice(canClaim)
				if canClaim == true and icon.totalNotices < 1 then
					icon:notify()
				elseif canClaim ~= true and icon.totalNotices > 0 then
					icon:clearNotices()
				end
			end
			task.spawn(function()
				local remote = dailyLoginUpdate or Remotes:WaitForChild("DailyLoginUpdate", 60)
				if remote then
					remote.OnClientEvent:Connect(function(value)
						if type(value) == "table" then
							syncDailyNotice(value.CanClaim)
						end
					end)
				end
			end)
			LocalPlayer:GetAttributeChangedSignal("DailyCanClaim"):Connect(function()
				syncDailyNotice(LocalPlayer:GetAttribute("DailyCanClaim"))
			end)
			if LocalPlayer:GetAttribute("DailyCanClaim") == true then
				syncDailyNotice(true)
			end
			icon.selected:Connect(function()
				icon:clearNotices()
			end)
		elseif key == "Afk" then
			-- Shows red notice circle while unclaimed rewards are waiting (zone accumulation or offline earnings).
			bindNotice(icon, function()
				return LocalPlayer:GetAttribute("AfkHasUnclaimed") == true
					or LocalPlayer:GetAttribute("OfflineEarningsReady") == true
					or (tonumber(LocalPlayer:GetAttribute("AfkModeSpeed")) or 0) > 0
					or (tonumber(LocalPlayer:GetAttribute("AfkModeTickets")) or 0) > 0
			end, { "AfkHasUnclaimed", "OfflineEarningsReady", "AfkModeSpeed", "AfkModeTickets" })
		end
	end
end

-- The admin panel (the Admin Abuse Panel; the old SpeedsterAdminPanelGui is retired): its
-- one topbar icon appears once the server confirms who may use it
-- (Admin/AdminAbusePanelService), on live servers as well as in Studio.
-- The AdminAbusePanelAllowed attribute is there from the first frame; the message is a
-- second way in.
local abuseIcon = nil
local function addAdminIcon()
	if abuseIcon then
		return
	end
	abuseIcon = buildIcon("AdminAbuse", {
		image = ADMIN_IMAGE,
		request = "AdminAbuse",
		panel = "AdminAbusePanelGui",
		tip = "Admin Panel (F2)",
	})
	queueRelayout()
end
if LocalPlayer:GetAttribute("AdminAbusePanelAllowed") == true then
	addAdminIcon()
end
LocalPlayer:GetAttributeChangedSignal("AdminAbusePanelAllowed"):Connect(function()
	if LocalPlayer:GetAttribute("AdminAbusePanelAllowed") == true then
		addAdminIcon()
	end
end)
task.spawn(function()
	local abuseRemote = Remotes:WaitForChild("AdminAbusePanel", 30)
	if not abuseRemote then
		return
	end
	abuseRemote.OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and payload.kind == "Permission" and payload.allowed == true then
			addAdminIcon()
		end
	end)
end)

----------------------------------------------------------------------
-- The retention icons: Streak (a notice while a milestone reward waits), Playtime Boost and
-- Community (a notice until claimed; the icon goes for good once claimed or switched off).
----------------------------------------------------------------------
local function removeCommunity()
	local icon = icons.Community
	if icon then
		icons.Community = nil
		pcall(function()
			icon:destroy()
		end)
		queueRelayout()
	end
end

for _, key in ORDER do
	local data = retention[key]
	if data and not (key == "Community" and communityGone()) then
		local icon = buildIcon(key, data)
		icon:setEnabled(false) -- placed (and shown) by the first layout pass
		if key == "Streak" then
			bindNotice(icon, function()
				return LocalPlayer:GetAttribute("StreakRewardPending") == true and U4.IsOn("Streak")
			end, { "StreakRewardPending" })
		elseif key == "Community" then
			bindNotice(icon, function()
				return not communityGone()
			end, { "CommunityRewardClaimed" })
		end
	end
end

LocalPlayer:GetAttributeChangedSignal("CommunityRewardClaimed"):Connect(function()
	if communityGone() then
		removeCommunity()
	end
end)
for _, attribute in { "StreakDays", "PlaytimeBoostPct", "FirstTimeTutorialActive" } do
	LocalPlayer:GetAttributeChangedSignal(attribute):Connect(queueRelayout)
end
-- The kill switches (Workspace U4Off_<Feature>) replicate; a feature switched off hides its
-- icon at once (Community's goes for good).
for key, data in retention do
	Workspace:GetAttributeChangedSignal(U4.KillAttributePrefix .. data.feature):Connect(function()
		if key == "Community" and communityGone() then
			removeCommunity()
		end
		queueRelayout()
	end)
end
local cameraConnection = nil
local function bindCamera()
	if cameraConnection then
		cameraConnection:Disconnect()
	end
	local camera = Workspace.CurrentCamera
	if camera then
		cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(queueRelayout)
	end
	queueRelayout()
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
bindCamera()
