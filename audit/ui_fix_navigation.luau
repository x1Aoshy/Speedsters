local fs=require('@lune/fs')
local function replace(s,a,b)
 local x,y=s:find(a,1,true);assert(x,'Missing '..a:sub(1,60));return s:sub(1,x-1)..b..s:sub(y+1)
end
for _,world in {'World1','World2'} do
 local path='audit/merged/'..world..'/StarterPlayer/StarterPlayerScripts/UI/ConsoleUiScale.luau'
 local s=fs.readFile(path):gsub('\r\n','\n')
 s=replace(s,'local activeMenuGui: ScreenGui? = nil','local activeMenuGui: ScreenGui? = nil\nlocal trackedMenus = {}\nlocal menuSerial = 0')
 s=replace(s,[[local function handleMenuOpened(gui: ScreenGui)
	activeMenuGui = gui]],[[local function handleMenuOpened(gui: ScreenGui)
	if not gui.Parent or not gui.Enabled or not findCloseOrPrimaryButton(gui) then return end
	activeMenuGui = gui]])
 s=replace(s,'\t\t\tif gui.Enabled then','\t\t\tif gui.Parent and gui.Enabled and not GuiService.MenuIsOpen then')
 local a=assert(s:find('local function handleMenuClosed',1,true));local b=assert(s:find('\nfor _, child in ipairs(playerGui:GetChildren()) do',a,true))
 s=s:sub(1,a-1)..[[local function handleMenuClosed(gui: ScreenGui)
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject = nil
	end
	if activeMenuGui ~= gui then return end
	activeMenuGui = nil
	ContextActionService:UnbindAction(ACTION_CONSOLE_BACK)
	GuiService.GuiNavigationEnabled = false
	disableVirtualCursor()
	local nextGui, newest = nil, -1
	for candidate, state in trackedMenus do
		if candidate ~= gui and candidate.Parent and candidate.Enabled and findCloseOrPrimaryButton(candidate) and state.serial > newest then
			nextGui, newest = candidate, state.serial
		end
	end
	if nextGui then handleMenuOpened(nextGui) end
	task.defer(updateGamepadHints)
end

local function hookMenu(gui: Instance)
	if not gui:IsA("ScreenGui") or not MANAGED_MENUS[gui.Name] or trackedMenus[gui] then return end
	local state = { open = false, serial = 0, queued = false, connections = {}, objects = {} }
	trackedMenus[gui] = state
	local function sync()
		state.queued = false
		if not trackedMenus[gui] then return end
		local target = gui.Enabled and findCloseOrPrimaryButton(gui)
		local isOpen = target ~= nil and target ~= false
		if isOpen and not state.open then
			state.open = true
			menuSerial += 1; state.serial = menuSerial
			handleMenuOpened(gui)
		elseif not isOpen then
			state.open = false
			handleMenuClosed(gui)
		elseif activeMenuGui == gui and isGamepadActive() and not GuiService.MenuIsOpen then
			local selected = GuiService.SelectedObject
			if not isVisibleButton(selected) or not selected:IsDescendantOf(gui) then
				target.Selectable = true
				GuiService.SelectedObject = target
			end
		end
	end
	local function scheduleSync()
		if state.queued then return end
		state.queued = true
		task.defer(sync)
	end
	local function observe(object)
		if not object:IsA("GuiObject") or state.objects[object] then return end
		local connections = { object:GetPropertyChangedSignal("Visible"):Connect(scheduleSync) }
		if object:IsA("GuiButton") then table.insert(connections, object:GetPropertyChangedSignal("Active"):Connect(scheduleSync)) end
		state.objects[object] = connections
	end
	local function forget(object)
		for _, connection in state.objects[object] or {} do connection:Disconnect() end
		state.objects[object] = nil
		scheduleSync()
	end
	for _, object in gui:GetDescendants() do observe(object) end
	table.insert(state.connections, gui:GetPropertyChangedSignal("Enabled"):Connect(scheduleSync))
	table.insert(state.connections, gui.DescendantAdded:Connect(function(object) observe(object); scheduleSync() end))
	table.insert(state.connections, gui.DescendantRemoving:Connect(forget))
	table.insert(state.connections, GuiService.MenuClosed:Connect(scheduleSync))
	table.insert(state.connections, gui.Destroying:Connect(function()
		trackedMenus[gui] = nil
		for _, connection in state.connections do connection:Disconnect() end
		for _, connections in state.objects do
			for _, connection in connections do connection:Disconnect() end
		end
		table.clear(state.objects)
		handleMenuClosed(gui)
	end))
	scheduleSync()
end
]]..s:sub(b)
 s=replace(s,[[	if isGpad then
		if activeMenuGui and activeMenuGui.Enabled then handleMenuOpened(activeMenuGui) end
		updateGamepadHints()
	end]],[[	if isGpad then
		if activeMenuGui and activeMenuGui.Enabled then handleMenuOpened(activeMenuGui) end
	else
		local selected = GuiService.SelectedObject
		if isObjectInSidebar(selected) or (selected and activeMenuGui and selected:IsDescendantOf(activeMenuGui)) then
			GuiService.SelectedObject = nil
		end
		GuiService.GuiNavigationEnabled = false
	end
	updateGamepadHints()]])
 fs.writeFile(path,s)
end
