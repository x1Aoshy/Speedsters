         
                                                                               
                                                                    
                                                                         

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
	Auras = "OpenAurasPanel",
	Index = "OpenIndexPanel",
	Teleport = "OpenTeleportPanel",
	Worlds = "OpenWorldsPanel",
	Playtime = "OpenPlaytimeRewardsPanel",
	Codes = "OpenCodesPanel",
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
local switchSerial = 0
local SWITCH_CLOSE_TIME = 0.24
local readyByMenu = {}
local isOpenByMenu = {}
local closeUntil = 0

local MenuEvents = {}
MenuEvents.CloseAll = closeAllMenus
MenuEvents.SwitchCloseTime = SWITCH_CLOSE_TIME

function MenuEvents.Get(eventName)
	local event = eventsByName[eventName]
	assert(event, "Unknown menu event: " .. tostring(eventName))
	return event
end

function MenuEvents.MarkReady(menuName, isOpenCallback)
	assert(MENU_EVENT_NAMES[menuName], "Unknown menu: " .. tostring(menuName))
	readyByMenu[menuName] = true
	if type(isOpenCallback) == "function" then
		isOpenByMenu[menuName] = isOpenCallback
	end
end

local function menuIsOpen(menuName)
	local callback = isOpenByMenu[menuName]
	if not callback then
		return false
	end

	local ok, result = pcall(callback)
	return ok and result == true
end

function MenuEvents.Request(menuName)
	local eventName = MENU_EVENT_NAMES[menuName]
	local targetEvent = eventName and eventsByName[eventName]
	if not targetEvent then
		return false
	end

	                                                                           
	                                                                  
	switchSerial += 1
	local thisRequest = switchSerial
	local targetWasOpen = menuIsOpen(menuName)
	local hadOpenMenu = false
	for readyMenuName in pairs(readyByMenu) do
		if menuIsOpen(readyMenuName) then
			hadOpenMenu = true
			break
		end
	end

	closeAllMenus:Fire(menuName)
	if hadOpenMenu then
		closeUntil = math.max(closeUntil, os.clock() + SWITCH_CLOSE_TIME)
	end

	                                                                        
	                                                        
	if targetWasOpen then
		return true
	end

	task.spawn(function()
		local remainingCloseTime = closeUntil - os.clock()
		if remainingCloseTime > 0 then
			task.wait(remainingCloseTime)
		end

		if thisRequest ~= switchSerial then
			return
		end

		                                                                        
		                                                                          
		                                                                   
		local readyDeadline = os.clock() + 10
		while not readyByMenu[menuName] and os.clock() < readyDeadline do
			if thisRequest ~= switchSerial then
				return
			end
			task.wait()
		end

		if not readyByMenu[menuName] then
			warn("[MenuEvents] Menu did not become ready: " .. tostring(menuName))
			return
		end
		targetEvent:Fire("LeftButtonSwitch")
	end)

	return true
end

return MenuEvents
