local fs=require('@lune/fs')
local function replace(s,a,b)
 local x,y=s:find(a,1,true);assert(x,'Missing '..a:sub(1,80));return s:sub(1,x-1)..b..s:sub(y+1)
end
for _,world in {'World1','World2'} do
 local root='audit/merged/'..world..'/'
 local function edit(path,fn) fs.writeFile(root..path,fn(fs.readFile(root..path))) end
 edit('StarterPlayer/StarterPlayerScripts/UI/RankRewardPanel.luau',function(s)
  s=replace(s,'playerGui:FindFirstChild(RankRewardGui)','playerGui:WaitForChild("RankRewardGui")')
  s=replace(s,'local dim = gui:WaitForChild("Dim")','gui.ResetOnSpawn = false\nlocal dim = gui:WaitForChild("Dim")')
  return s
 end)
 edit('StarterPlayer/StarterPlayerScripts/UI/RebirthController.luau',function(s)
  for _,button in {'rebirthButton','rebirthBuy'} do
   local start=assert(s:find('if '..button..':IsA("GuiButton") then\n    '..button..'.MouseButton1Click',1,true))
   local finish=assert(s:find('\nend',start,true));s=s:sub(1,start-1)..s:sub(finish+4)
  end
  s=replace(s,'(child.Name == "Price" or child.Name == "Name")','child.Name == "Price"')
  local start=assert(s:find('\t\t\tfor _, label in ipairs(rebirthBuy:GetDescendants()) do',1,true))
  local finish=assert(s:find('\n\t\t\tend',start,true));s=s:sub(1,start-1)..s:sub(finish+7)
  return s
 end)
 edit('ReplicatedStorage/Shared/Config.luau',function(s)
  s=replace(s,'BaseGain = 500,','BaseGain = 100,')
  s=replace(s,'DisplayText = "x500 Speed"','DisplayText = "x100 Speed"');return s
 end)
 edit('ServerScriptService/Progression/TreadmillTraining.luau',function(s)
  -- Paid models use their configured rate; event treadmills keep the event bonus.
  return replace(s,'return zone.Treadmill:GetAttribute("AdminSpawned") == true','return (tonumber(zone.RequiredGamePassId) or tonumber(zone.GamePassId) or 0) <= 0\n\t\tand zone.Treadmill:GetAttribute("AdminSpawned") == true')
 end)
 edit('StarterPlayer/StarterPlayerScripts/UI/ConsoleUiScale.luau',function(s)
  s=replace(s,'local updateGamepadHints: () -> ()','local updateGamepadHints: () -> () = function() end')
  s=replace(s,'local function findCloseOrPrimaryButton(gui: ScreenGui): GuiButton?',[[local function isVisibleButton(button)
	if not button or not button:IsA("GuiButton") or not button.Active then return false end
	local current = button
	while current and current ~= playerGui do
		if current:IsA("GuiObject") and not current.Visible then return false end
		if current:IsA("ScreenGui") and not current.Enabled then return false end
		current = current.Parent
	end
	return current == playerGui
end

local function findCloseOrPrimaryButton(gui: ScreenGui): GuiButton?]])
  s=replace(s,'desc:IsA("GuiButton") and desc.Visible','isVisibleButton(desc)')
  s=replace(s,'local function onButtonBInput(actionName, inputState, inputObject)','local function onButtonBInput(actionName, inputState, inputObject)\n\tif GuiService.MenuIsOpen then return Enum.ContextActionResult.Pass end')
  s=replace(s,'local function focusLeftSideBar()','local function focusLeftSideBar()\n\tif GuiService.MenuIsOpen then return end')
  s=replace(s,'activeMenuGui = gui\n\tGuiService.GuiNavigationEnabled = true','activeMenuGui = gui\n\tGuiService.GuiNavigationEnabled = isGamepadActive()')
  return s
 end)
 edit('StarterPlayer/StarterPlayerScripts/Movement/'..world..'FlightAbility.luau',function(s)
  s=s:gsub('GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox%(%)','GuiService.MenuIsOpen or GuiService.SelectedObject ~= nil or UserInputService:GetFocusedTextBox()')
  s=replace(s,'if not UserInputService:GetFocusedTextBox() and not GuiService.MenuIsOpen then','if not gameProcessed and not UserInputService:GetFocusedTextBox() and not GuiService.MenuIsOpen and GuiService.SelectedObject == nil then')
  s=replace(s,'GuiService.MenuOpened:Connect(releaseInputs)','GuiService.MenuOpened:Connect(releaseInputs)\nGuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()\n\tif GuiService.SelectedObject then releaseInputs() end\nend)')
  s=replace(s,'UserInputService.JumpRequest:Connect(function()','UserInputService.JumpRequest:Connect(function()\n\tif GuiService.MenuIsOpen or GuiService.SelectedObject then return end')
  return s
 end)
end
print('UI, paid treadmill and gamepad fixes integrated')


