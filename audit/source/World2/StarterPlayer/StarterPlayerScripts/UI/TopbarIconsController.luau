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

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local dailyLoginUpdate = Remotes:FindFirstChild("DailyLoginUpdate")

local panes = {
	Daily = {
		image = DAILY_IMAGE,
		request = "Daily",
		panel = "DailyReward",
		order = 1,
	},
	Settings = {
		image = SETTINGS_IMAGE,
		request = "Settings",
		panel = "Settings",
		order = 2,
	},
}

local function panelIsOpen(panelName)
	local gui = playerGui:FindFirstChild(panelName)
	return gui ~= nil and gui.Enabled == true
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
		:setTip(key == "Settings" and "Settings" or "Daily Rewards")

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
		local panel = playerGui:WaitForChild(data.panel)
		panel:GetPropertyChangedSignal("Enabled"):Connect(function()
			syncToPanel()
		end)
	end)

	syncToPanel()
	return icon
end

for key, data in pairs(panes) do
	local icon = buildIcon(key, data)
	if key == "Daily" then
		-- Notice bubble: shows while a daily gift can be claimed, and clears as
		-- soon as the icon is clicked (the claim panel opens at the same time).
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
	end
end
