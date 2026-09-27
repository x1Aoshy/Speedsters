local fs=require('@lune/fs');local r=require('@lune/roblox');local luau=require('@lune/luau')
for world,file in {World1='World1 Speedtercorrect.rbxl',World2='audit/incoming_20260913/World2/input.rbxl'} do
	local root='audit/merged/'..world..'/'
	local place=r.deserializePlace(fs.readFile(file))
	local buy=place:GetService('StarterGui'):FindFirstChild('Rebirth'):FindFirstChild('Rebirth'):FindFirstChild('RebirthBuy')
	local originals={};for _,i in buy:GetDescendants() do if i:IsA('TextLabel') and i.Name=='Name' then originals[i]=i.Text end end
	local s=fs.readFile(root..'StarterPlayer/StarterPlayerScripts/UI/RebirthController.luau')
	local start=assert(s:find('local priceLabel =',1,true));local finish=assert(s:find('RebirthUpdate.OnClientEvent',start,true))
	luau.load(s:sub(start,finish-1),{environment={rebirthBuy=buy,Config={RebirthPriceRobux=14,RebirthProductId=1},task={spawn=function(fn) fn() end},MarketplaceService={GetProductInfo=function() return {PriceInRobux=19} end},Enum=r.Enum}})()
	assert(buy:FindFirstChild('Price').Text=='19')
	for i,text in originals do assert(i.Text==text,'Rebirth action/description replaced by price') end
	s=fs.readFile(root..'StarterPlayer/StarterPlayerScripts/UI/RankRewardPanel.luau')
	local line=s:match('local gui = ([^\n]+)');local gui={}
	assert(luau.load('return '..line,{environment={playerGui={WaitForChild=function(_,name) assert(name=='RankRewardGui');return gui end}}})()==gui)
	print('PASS '..world..' rebirth updates only Price; rank resolves the correct GUI name')
	s=fs.readFile(root..'StarterPlayer/StarterPlayerScripts/Movement/SpeedsterClient.luau')
	start=assert(s:find('local function handleBoostAction',1,true));finish=assert(s:find('\nContextActionService:BindActionAtPriority',start,true))
	local guiService={SelectedObject={}}
	local boosting
	local handle=luau.load(s:sub(start,finish-1)..'\nreturn handleBoostAction',{environment={windowFocused=true,player={GetAttribute=function() return false end},GuiService=guiService,UserInputService={GetFocusedTextBox=function() return nil end},Enum=r.Enum,setBoosting=function(value) boosting=value end}})()
	local input={KeyCode=r.Enum.KeyCode.ButtonL2,Position=r.Vector3.new(0,0,1)}
	assert(handle('',r.Enum.UserInputState.Begin,input)==r.Enum.ContextActionResult.Pass and boosting==false)
	guiService.SelectedObject=nil
	assert(handle('',r.Enum.UserInputState.Begin,input)==r.Enum.ContextActionResult.Sink and boosting==true)
	assert(handle('',r.Enum.UserInputState.Cancel,input)==r.Enum.ContextActionResult.Pass and boosting==false)
	s=fs.readFile(root..'StarterPlayer/StarterPlayerScripts/Movement/CtrlShiftLock.luau')
	start=assert(s:find('function(actionName, inputState, inputObject)',1,true));finish=assert(s:find('\n\tend,',start,true))
	local toggles=0
	local shift=luau.load('return '..s:sub(start,finish)..'end',{environment={player={GetAttribute=function() return false end},GuiService=guiService,UserInputService={GetFocusedTextBox=function() return nil end},Enum=r.Enum,toggleShiftLock=function() toggles+=1 end}})()
	guiService.SelectedObject={}
	assert(shift('',r.Enum.UserInputState.Begin,{KeyCode=r.Enum.KeyCode.DPadDown})==r.Enum.ContextActionResult.Pass and toggles==0)
	guiService.SelectedObject=nil
	assert(shift('',r.Enum.UserInputState.Begin,{KeyCode=r.Enum.KeyCode.ButtonL3})==r.Enum.ContextActionResult.Sink and toggles==1)
	s=fs.readFile(root..'StarterPlayer/StarterPlayerScripts/UI/ConsoleUiScale.luau')
	for class,member in s:gmatch('Enum%.([%w_]+)%.([%w_]+)') do assert(r.Enum[class][member],class..'.'..member) end
	print('PASS '..world..' D-pad and triggers pass through in menus; cancel stops sprint; navigation enums resolve')
end
