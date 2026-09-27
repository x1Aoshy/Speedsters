         
                                                                               
                                                                    
                                                                         

local Players = game:GetService("Players")

local player = Players.LocalPlayer
assert(player, "MenuEvents can only be required by a client LocalScript")

local playerScripts = player:WaitForChild("PlayerScripts")

local MENU_EVENT_NAMES = {
	Abilities = "OpenAbilitiesPanel",
	Evolve = "OpenEvolvePanel",
	Rebirth = "OpenRebirthPanel",
	Daily = "OpenDailyPanel",
	Trails = "OpenTrailsPanel",
	Trail = "OpenTrailsPanel",
	Auras = "OpenAurasPanel",
	Aura = "OpenAurasPanel",
	Index = "OpenIndexPanel",
	Backpack = "OpenBackpackPanel",
	Teleport = "OpenTeleportPanel",
	Worlds = "OpenWorldsPanel",
	Settings = "OpenSettingsPanel",
	Playtime = "OpenPlaytimeRewardsPanel",
	Shop = "OpenShopPanel",
	Codes = "OpenCodesPanel",
	UpdateLogs = "OpenUpdateLogsPanel",
	CodesModal = "OpenCodesModal",
	Treadmill = "OpenTreadmillPanel",
	Admin = "OpenAdminAbusePanel", -- the one admin panel (the old SpeedsterAdminPanelGui is retired)
	Afk = "OpenAfkPanel",
	Quests = "OpenQuestsPanel",
	Quest = "OpenQuestsPanel",
	SpinWheel = "OpenSpinWheelPanel",
	AdminAbuse = "OpenAdminAbusePanel",
}

local function getSingleBindable(name)
	local selected = nil

	for _, child in ipairs(playerScripts:GetChildren()) do
		if child.Name == name then
			if child:IsA("BindableEvent") and not selected then
				selected = child
			else
				child:Destroy()
			end
		end
	end

	if not selected then
		selected = Instance.new("BindableEvent")
		selected.Name = name
		selected.Parent = playerScripts
	end

	return selected
end

local eventsByName = {}
for _, eventName in pairs(MENU_EVENT_NAMES) do
	eventsByName[eventName] = getSingleBindable(eventName)
end

local closeAllMenus = getSingleBindable("CloseAllSpeedsterMenus")
local hudVisibilityChanged = getSingleBindable("MenuEvents_HUDVisibility")
local switchSerial = 0
local SWITCH_CLOSE_TIME = 0.24
local readyByMenu = {}
local isOpenByMenu = {}
local closeUntil = 0

local MenuEvents = {}
MenuEvents.CloseAll = closeAllMenus
MenuEvents.HUDVisibilityChanged = hudVisibilityChanged
MenuEvents.SwitchCloseTime = SWITCH_CLOSE_TIME

function MenuEvents.SetHUDVisible(visible, menuName)
	hudVisibilityChanged:Fire(visible == true, menuName)
end

function MenuEvents.Get(eventName)
	local event = eventsByName[eventName]
	if not event then
		event = getSingleBindable(eventName)
		eventsByName[eventName] = event
	end
	return event
end

function MenuEvents.MarkReady(menuName, isOpenCallback)
	if not MENU_EVENT_NAMES[menuName] then
		MENU_EVENT_NAMES[menuName] = menuName
	end
	readyByMenu[menuName] = true
	if type(isOpenCallback) == "function" then
		isOpenByMenu[menuName] = isOpenCallback
	end
end

function MenuEvents.Listen(menuName, callback)
	local eventName = MENU_EVENT_NAMES[menuName] or menuName
	local targetEvent = MenuEvents.Get(eventName)
	return targetEvent.Event:Connect(callback)
end

local MENU_TO_GUI = {
	Abilities = "Abilities",
	Evolve = "Evolve",
	Rebirth = "Rebirth",
	Daily = "DailyReward",
	Trails = "Backpack",
	Trail = "Backpack",
	Auras = "Backpack",
	Aura = "Backpack",
	Index = "Index",
	Backpack = "Backpack",
	Teleport = "StageTeleport",
	Worlds = "Worlds",
	Settings = "Settings",
	Playtime = "TimeGift",
	Shop = "Shop",
	Codes = "Shop",
	UpdateLogs = "Update Logs",
	CodesModal = "Codes Modal",
	RankReward = "RankRewardGui",
	Treadmill = "Treadmill",
	Admin = "AdminAbusePanelGui",
	Afk = "AfkRewardsGui",
	Quests = "QuestGui",
	Quest = "QuestGui",
	SpinWheel = "SpinWheelGui",
	AdminAbuse = "AdminAbusePanelGui",
}

local function getGuiForMenu(menuName)
	local guiName = MENU_TO_GUI[menuName] or menuName
	local playerGui = player:FindFirstChild("PlayerGui")
	if playerGui then
		local gui = playerGui:FindFirstChild(guiName)
		if gui and gui:IsA("ScreenGui") then
			return gui
		end
	end
	return nil
end

local function forceCloseAllGuis(exceptMenuName)
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then return end
	local exceptGui = exceptMenuName and (MENU_TO_GUI[exceptMenuName] or exceptMenuName)
	for _, guiName in pairs(MENU_TO_GUI) do
		if guiName ~= exceptGui then
			local gui = playerGui:FindFirstChild(guiName)
			if gui and gui:IsA("ScreenGui") and gui.Enabled then
				gui.Enabled = false
			end
		end
	end
	-- Explicit check for RankRewardGui
	if exceptGui ~= "RankRewardGui" then
		local rankGui = playerGui:FindFirstChild("RankRewardGui")
		if rankGui and rankGui:IsA("ScreenGui") and rankGui.Enabled then
			rankGui.Enabled = false
		end
	end
end

closeAllMenus.Event:Connect(function(exceptMenuName)
	forceCloseAllGuis(exceptMenuName)
	if not exceptMenuName then
		MenuEvents.SetHUDVisible(true, nil)
	end
end)

local function menuIsOpen(menuName)
	local callback = isOpenByMenu[menuName]
	if callback then
		local ok, result = pcall(callback)
		if ok and result ~= nil then
			return result == true
		end
	end
	local targetGui = getGuiForMenu(menuName)
	if targetGui and targetGui.Enabled then
		for _, child in targetGui:GetChildren() do
			if child:IsA("GuiObject") and child.Visible and child.Name ~= "Dim" and child.Name ~= "Overlay" then
				return true
			end
		end
	end

	return false
end

-- Whether any menu other than `exceptMenuName` is open right now, as each menu reports
-- through MarkReady. Windows that open by themselves wait for this to be false.
function MenuEvents.AnyOpen(exceptMenuName)
	for menuName in isOpenByMenu do
		if menuName ~= exceptMenuName and menuIsOpen(menuName) then
			return true
		end
	end
	return false
end

function MenuEvents.Request(menuName, ...)
	local eventName = MENU_EVENT_NAMES[menuName]
	local targetEvent = eventName and eventsByName[eventName]
	if not targetEvent then
		return false
	end

	switchSerial += 1

	-- Check if target is already open
	local targetGui = getGuiForMenu(menuName)
	local targetWasOpen = menuIsOpen(menuName)

	if targetWasOpen then
		if select("#", ...) > 0 then
			MenuEvents.SetHUDVisible(false, menuName)
			targetEvent:Fire("Open", ...)
			return true
		end
		-- Toggle closed
		if targetGui then
			targetGui.Enabled = false
		end
		closeAllMenus:Fire(menuName)
		targetEvent:Fire("Close")
		MenuEvents.SetHUDVisible(true, nil)
		return true
	end

	-- Force-close all other ScreenGuis instantly so they never stack on mobile
	forceCloseAllGuis(menuName)
	closeAllMenus:Fire(menuName)

	-- Fire open immediately without artificial delays
	MenuEvents.SetHUDVisible(false, menuName)
	targetEvent:Fire("Open", ...)
	return true
end

return MenuEvents
