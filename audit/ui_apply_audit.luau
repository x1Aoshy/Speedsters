-- One-shot transformations for the audited UI sources. Do not re-run after other edits.
local fs=require('@lune/fs')
local function edit(world,path,fn)
 local p='audit/merged/'..world..'/'..path
 if not fs.isFile(p) then return end
 local old=fs.readFile(p);local s=fn(old);if old~=s then fs.writeFile(p,s);print('EDIT',world,path) end
end
local function replace(s,a,b)
 local start,finish=s:find(a,1,true);assert(start,'Missing '..a:sub(1,80));return s:sub(1,start-1)..b..s:sub(finish+1)
end
for _,world in {'World1','World2'} do
 local ui='StarterPlayer/StarterPlayerScripts/UI/'
 for _,name in {'AbilitiesPanel','DailyRewardController','EvolveController','RebirthController','SettingsController','TeleportController','TimeGiftController','TreadmillLockPanel','UpdateLogsController'} do
  edit(world,ui..name..'.luau',function(s)
   s=s:gsub('\r\n','\n')
   -- Every removed callback invokes an action already bound to Activated.
   s=s:gsub('\n[ \t]*button%.MouseButton1Click:Connect%(onClaim%)','')
   s=s:gsub('\ncloseBtn%.MouseButton1Click:Connect%(closePanel%)','')
   for _,button in {'closeButton','CloseButton','closeBtn','close','okay'} do
    s=s:gsub('\nif '..button..':IsA%("GuiButton"%) then\n[ \t]*'..button..'%.MouseButton1Click:Connect%([^\n]+%)\nend','')
    s=s:gsub('\nif '..button..':IsA%("GuiButton"%) then\n[ \t]*'..button..'%.MouseButton1Click:Connect%(function%(%)\n[ \t]*closePanel%(%)\n[ \t]*end%)\nend','')
    s=s:gsub('\nif '..button..':IsA%("GuiButton"%) then\n[ \t]*'..button..'%.MouseButton1Click:Connect%(function%(%)\n[ \t]*clickSound:Play%(%)\n[ \t]*closePanel%(%)\n[ \t]*end%)\nend','')
    s=s:gsub('\n'..button..'%.InputBegan:Connect%(function%(input%)\n[ \t]*if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch[^\n]*then\n[ \t]*closePanel%(%)\n[ \t]*end\nend%)','')
    s=s:gsub('\n'..button..'%.InputBegan:Connect%(function%(input%)\n[ \t]*if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch[^\n]*then\n[ \t]*clickSound:Play%(%)\n[ \t]*closePanel%(%)\n[ \t]*end\nend%)','')
   end
   return s
  end)
 end
 edit(world,ui..'RankRewardPanel.luau',function(s)
  s=s:gsub('\r\n','\n')
  s=replace(s,[[updateScale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end]],[[local cameraConnection
local function bindCamera()
	if cameraConnection then cameraConnection:Disconnect() end
	local camera = workspace.CurrentCamera
	if camera then cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale) end
	updateScale()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
bindCamera()]])
  s=replace(s,'if now - lastLocalOpen < 0.75 then','if isOpen or now - lastLocalOpen < 0.75 then')
  s=replace(s,[[			if character and hit and hit:IsDescendantOf(character) then
				requestOpenFromPad()
			end]],[[			if not insidePad and character and hit and hit:IsDescendantOf(character) then
				insidePad = true
				requestOpenFromPad()
			end]])
  s=replace(s,'\tif #localPadParts == 0 then',[[	-- Streaming destroys old instances; a nonempty array can contain only stale parts.
	for index = #localPadParts, 1, -1 do
		if not localPadParts[index]:IsDescendantOf(Workspace) then table.remove(localPadParts, index) end
	end
	if #localPadParts == 0 then]])
  return s
 end)
 edit(world,'StarterPlayer/StarterPlayerScripts/Movement/World2SpeedForce.luau',function(s)
  s=s:gsub('\r\n','\n')
  s=replace(s,'local function canUse()','local function inputBlocked()\n\treturn GuiService.MenuIsOpen or GuiService.SelectedObject ~= nil or UserInputService:GetFocusedTextBox() ~= nil\nend\n\nlocal function canUse()')
  s=replace(s,'if holdActive or cutsceneActive or not canUse() then return end','if holdActive or cutsceneActive or inputBlocked() or not canUse() then return end')
  s=replace(s,'if not holdActive or mySerial ~= holdSerial or cutsceneActive or not canUse() then return end','if not holdActive or mySerial ~= holdSerial or cutsceneActive or inputBlocked() or not canUse() then return end')
  s=replace(s,'UserInputService.InputBegan:Connect(function(input, gameProcessed)',[[UserInputService.WindowFocusReleased:Connect(endHold)
UserInputService.GamepadDisconnected:Connect(endHold)
UserInputService.TextBoxFocused:Connect(endHold)
GuiService.MenuOpened:Connect(endHold)
GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()
	if GuiService.SelectedObject then endHold() end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)]])
  return s
 end)
 edit(world,'ReplicatedStorage/Shared/ConsolePanelSupport.luau',function(s)
  s=s:gsub('\r\n','\n')
  s=replace(s,'if frame:GetAttribute("SidebarLayoutManaged") or not GuiService:IsTenFootInterface() then',[[local existingScale = frame:FindFirstChildOfClass("UIScale")
		if frame:GetAttribute("SidebarLayoutManaged") or (existingScale and existingScale ~= scale) or not GuiService:IsTenFootInterface() then]])
  s=replace(s,'if UserInputService.GamepadEnabled and not GuiService.MenuIsOpen then',[[local gamepadInput = GuiService:IsTenFootInterface() or (UserInputService.GamepadEnabled and UserInputService:GetLastInputType().Name:find("Gamepad"))
		if gamepadInput and not GuiService.MenuIsOpen then]])
  return s
 end)
end
