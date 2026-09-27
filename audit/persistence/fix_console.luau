local fs=require('@lune/fs')
local function replace(s,a,b)
 local x,y=s:find(a,1,true);assert(x,'Missing '..a:sub(1,95));return s:sub(1,x-1)..b..s:sub(y+1)
end
for _,world in {'World1','World2'} do
 local root='audit/merged/'..world..'/'
 local function edit(path,fn) fs.writeFile(root..path,fn(fs.readFile(root..path))) end
 edit('StarterPlayer/StarterPlayerScripts/UI/ConsoleUiScale.luau',function(s)
  s=replace(s,'Enum.ContextActionPriority.Default.Value','Enum.ContextActionPriority.Medium.Value')
  s=replace(s,'return isConsole or UserInputService.GamepadEnabled or UserInputService:GetLastInputType().Name:find("Gamepad") ~= nil','return isConsole or (UserInputService.GamepadEnabled and UserInputService:GetLastInputType().Name:find("Gamepad") ~= nil)')
  s=replace(s,'\tif isGpad then\n\t\tupdateGamepadHints()','\tif isGpad then\n\t\tif activeMenuGui and activeMenuGui.Enabled then handleMenuOpened(activeMenuGui) end\n\t\tupdateGamepadHints()')
  s=replace(s,'UserInputService:GetPropertyChangedSignal("MouseBehavior"):Connect(updateGamepadHints)',[[
UserInputService.GamepadDisconnected:Connect(function()
	if #UserInputService:GetConnectedGamepads()==0 then
		GuiService.SelectedObject=nil
		GuiService.GuiNavigationEnabled=false
		hintsContainer.Visible=false
	end
end)
UserInputService:GetPropertyChangedSignal("MouseBehavior"):Connect(updateGamepadHints)]])
  return s
 end)
 edit('StarterPlayer/StarterPlayerScripts/Movement/CtrlShiftLock.luau',function(s)
  s=replace(s,'if GuiService.SelectedObject ~= nil then','if GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() or GuiService.SelectedObject ~= nil then')
  s=replace(s,'function(actionName, inputState, inputObject)\n\t\tif inputState','function(actionName, inputState, inputObject)\n\t\tif GuiService.MenuIsOpen or GuiService.SelectedObject or UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end\n\t\tif inputState')
  s=replace(s,'-- Start with ShiftLock OFF','GuiService.MenuOpened:Connect(function() applyShiftLock(false) end)\nUserInputService.GamepadDisconnected:Connect(function() applyShiftLock(false) end)\n\n-- Start with ShiftLock OFF')
  return s
 end)
 edit('StarterPlayer/StarterPlayerScripts/Movement/SpeedsterClient.luau',function(s)
  s=replace(s,'local Debris = game:GetService("Debris")','local Debris = game:GetService("Debris")\nlocal GuiService = game:GetService("GuiService")')
  s=replace(s,'local function setBoosting(value)','local function setBoosting(value)\n\tif value and (GuiService.MenuIsOpen or GuiService.SelectedObject or UserInputService:GetFocusedTextBox()) then value = false end')
  s=replace(s,'local function handleBoostAction(actionName, inputState, inputObject)','local function handleBoostAction(actionName, inputState, inputObject)\n\tif GuiService.MenuIsOpen or GuiService.SelectedObject or UserInputService:GetFocusedTextBox() then\n\t\tsetBoosting(false)\n\t\treturn Enum.ContextActionResult.Pass\n\tend\n\tif inputState == Enum.UserInputState.Cancel then setBoosting(false); return Enum.ContextActionResult.Pass end')
  s=replace(s,'local lastHardwareBoostState = false','local lastHardwareBoostState = false\nlocal function cancelBoostInput()\n\tlastHardwareBoostState = false\n\tsetBoosting(false)\nend\nUserInputService.GamepadDisconnected:Connect(cancelBoostInput)\nUserInputService.WindowFocusReleased:Connect(cancelBoostInput)\nGuiService.MenuOpened:Connect(cancelBoostInput)\nGuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function() if GuiService.SelectedObject then cancelBoostInput() end end)')
  return s
 end)
end
print('Gamepad sidebar binding, D-pad navigation and stuck sprint input fixed')
