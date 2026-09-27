local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")
local MenuEvents = require(ReplicatedStorage.Shared:WaitForChild("MenuEvents"))

-- TopbarPlus library (renamed to "Icon" in ReplicatedStorage)
local Icon = require(ReplicatedStorage:WaitForChild("Icon"))

-- Game's own icon images for these exact features
local SETTINGS_IMAGE = "rbxassetid://77188882273275"
local DAILY_IMAGE = "rbxassetid://114699417085635"
local ADMIN_IMAGE = "rbxassetid://10723374641" -- Golden Crown

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local dailyLoginUpdate = Remotes:FindFirstChild("DailyLoginUpdate")

local Config = require(ReplicatedStorage.Shared:WaitForChild("Config"))
-- The game's own codes artwork, taken from the Shop's Codes section.
local CODES_IMAGE = tostring(Config.CodesTopbarIconImage or "rbxassetid://138738878130228")

local AFK_IMAGE = "rbxassetid://91936490991168" -- Hourglass / Clock
local QUESTS_IMAGE = "rbxassetid://10734975692" -- Quests / Shield

local panes = {
	Daily = {
		image = DAILY_IMAGE,
		request = "Daily",
		panel = "DailyReward",
		order = 1,
		tip = "Daily Rewards",
	},
	Codes = {
		image = CODES_IMAGE,
		request = "Codes",
		-- "Codes" opens the Shop on its Codes section, so the Shop GUI is what
		-- reflects this icon's open state.
		panel = "Shop",
		order = 2,
		tip = "Redeem Codes",
	},
	Settings = {
		image = SETTINGS_IMAGE,
		request = "Settings",
		panel = "Settings",
		order = 3,
		tip = "Settings",
	},
}

-- Quests and AFK Rewards are preview features: their buttons appear for exactly the players
-- whose panels run (Shared.FeatureGate). The Spin Wheel has no topbar button: it opens from
-- its own button beside x2 Speed on the Main HUD.
if require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FeatureGate")).IsPreviewPlayer(Players.LocalPlayer) then
	panes.Quests = {
		image = QUESTS_IMAGE,
		request = "Quests",
		panel = "QuestGui",
		order = 4,
		tip = "Quests",
	}
	panes.Afk = {
		image = AFK_IMAGE,
		request = "Afk",
		panel = "AfkRewardsGui",
		order = 5,
		tip = "AFK Rewards",
	}
end

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
		:setRight()
		:setOrder(data.order or 1)
		:setSize(44, 44)
		:setImageYScale(0.85)
		:setImageRatio(1)
		:setTip(data.tip or key)

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
	return icon
end

for key, data in pairs(panes) do
	local icon = buildIcon(key, data)
	if key == "Daily" then
		-- Notice bubble: shows while a daily gift can be claimed, and clears as
		-- soon as the icon is clicked (the claim panel opens at the same time).
		icon:set("noticeCircleColor", Color3.fromRGB(245, 45, 45), "deselected")
		icon:set("noticeCircleColor", Color3.fromRGB(245, 45, 45), "selected")
		icon:set("noticeTextColor", Color3.fromRGB(255, 255, 255), "deselected")
		icon:set("noticeTextColor", Color3.fromRGB(255, 255, 255), "selected")
		if dailyLoginUpdate then
			dailyLoginUpdate.OnClientEvent:Connect(function(value)
				if type(value) ~= "table" then
					return
				end
				if value.CanClaim == true and icon.totalNotices < 1 then
					icon:notify()
				elseif value.CanClaim ~= true and icon.totalNotices > 0 then
					icon:clearNotices()
				end
			end)
		end
		icon.selected:Connect(function()
			icon:clearNotices()
		end)
	elseif key == "Quests" then
		-- Shows red notice circle while quests are available to pick or rewards are ready to claim.
		local questNoticeEnd = Instance.new("BindableEvent")
		local function syncQuestNotice()
			icon:set("noticeCircleColor", Color3.fromRGB(245, 45, 45), "deselected")
			icon:set("noticeCircleColor", Color3.fromRGB(245, 45, 45), "selected")
			icon:set("noticeTextColor", Color3.fromRGB(255, 255, 255), "deselected")
			icon:set("noticeTextColor", Color3.fromRGB(255, 255, 255), "selected")
			local active = LocalPlayer:GetAttribute("QuestRewardReady") == true
				or LocalPlayer:GetAttribute("QuestAvailable") == true
				or (LocalPlayer:GetAttribute("QuestAvailable") == nil and LocalPlayer:GetAttribute("QuestRewardReady") == nil)
			if active and icon.totalNotices < 1 then
				icon:notify(questNoticeEnd.Event)
			elseif not active and icon.totalNotices > 0 then
				questNoticeEnd:Fire()
				icon:clearNotices()
			end
		end
		LocalPlayer:GetAttributeChangedSignal("QuestRewardReady"):Connect(syncQuestNotice)
		LocalPlayer:GetAttributeChangedSignal("QuestAvailable"):Connect(syncQuestNotice)
		syncQuestNotice()
	elseif key == "Afk" then
		-- Shows red notice circle while unclaimed rewards are waiting (zone accumulation or offline earnings).
		local afkNoticeEnd = Instance.new("BindableEvent")
		local function syncAfkNotice()
			icon:set("noticeCircleColor", Color3.fromRGB(245, 45, 45), "deselected")
			icon:set("noticeCircleColor", Color3.fromRGB(245, 45, 45), "selected")
			icon:set("noticeTextColor", Color3.fromRGB(255, 255, 255), "deselected")
			icon:set("noticeTextColor", Color3.fromRGB(255, 255, 255), "selected")
			local unclaimed = LocalPlayer:GetAttribute("AfkHasUnclaimed") == true
				or LocalPlayer:GetAttribute("OfflineEarningsReady") == true
				or (tonumber(LocalPlayer:GetAttribute("AfkModeSpeed")) or 0) > 0
				or (tonumber(LocalPlayer:GetAttribute("AfkModeTickets")) or 0) > 0
			if unclaimed and icon.totalNotices < 1 then
				icon:notify(afkNoticeEnd.Event)
			elseif not unclaimed and icon.totalNotices > 0 then
				afkNoticeEnd:Fire()
				icon:clearNotices()
			end
		end
		LocalPlayer:GetAttributeChangedSignal("AfkHasUnclaimed"):Connect(syncAfkNotice)
		LocalPlayer:GetAttributeChangedSignal("OfflineEarningsReady"):Connect(syncAfkNotice)
		LocalPlayer:GetAttributeChangedSignal("AfkModeSpeed"):Connect(syncAfkNotice)
		LocalPlayer:GetAttributeChangedSignal("AfkModeTickets"):Connect(syncAfkNotice)
		syncAfkNotice()
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
		order = 8,
		tip = "Admin Panel (F2)",
	})
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
