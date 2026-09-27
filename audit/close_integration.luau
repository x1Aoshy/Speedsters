local fs=require('@lune/fs')
local function replace(s,a,b)
 local x,y=s:find(a,1,true);assert(x,'Missing '..a);return s:sub(1,x-1)..b..s:sub(y+1)
end
fs.writeFile('audit/merged/World2/ReplicatedStorage/Shared/Config.luau',fs.readFile('audit/merged/World1/ReplicatedStorage/Shared/Config.luau'))
for _,world in {'World1','World2'} do
 local root='audit/merged/'..world..'/'
 local path=root..'StarterPlayer/StarterPlayerScripts/UI/ShopController.luau'
 local s=fs.readFile(path)
 local a=s:find('if CloseBtn:IsA("GuiButton") then',s:find('CloseBtn.Activated:Connect',1,true),true)
 local b=s:find('local giftCloseBtn',a,true)
 s=s:sub(1,a-1)..s:sub(b)
 s=replace(s,'\tgiftCloseBtn.MouseButton1Click:Connect(function()\n\t\tcloseGiftPanel()\n\tend)','')
 fs.writeFile(path,s)
 path=root..'ServerScriptService/Worlds/WorldPortalService.luau';s=fs.readFile(path)
 s=replace(s,'WorldPortalAction.OnServerEvent:Connect(function(player, action, destinationWorld)','local function handlePortalAction(player, action, destinationWorld, trustedAdmin)')
 s=replace(s,'if not isPlayerAllowedToTravel(player, destinationWorld) then','if not trustedAdmin and not isPlayerAllowedToTravel(player, destinationWorld) then')
 s=replace(s,'armTeleportTimeout(player, teleporting[player])\nend)','armTeleportTimeout(player, teleporting[player])\nend\nWorldPortalAction.OnServerEvent:Connect(function(player, action, destinationWorld)\n handlePortalAction(player, action, destinationWorld, false)\nend)\n_G.SpeedsterAdminWorldTravel = function(player, destinationWorld)\n handlePortalAction(player, "Travel", destinationWorld, true)\nend')
 fs.writeFile(path,s)
 path=root..'ServerScriptService/Admin/AdminPanelService.luau';s=fs.readFile(path)
 local first=s:find('\telseif action == "TeleportWorld2" then',1,true)
 local last=s:find('\telseif action == "BroadcastAnnouncement" then',first,true)
 s=s:sub(1,first-1)..'\telseif action == "TeleportWorld2" or action == "TeleportWorld1" then\n\t\tif type(_G.SpeedsterAdminWorldTravel)=="function" then\n\t\t\t_G.SpeedsterAdminWorldTravel(player, action=="TeleportWorld2" and 2 or 1)\n\t\telse sendToast(player,false,"World travel is still loading") end\n\n'..s:sub(last)
 fs.writeFile(path,s)
end
local p='audit/persistence/test_ui.luau'
local s=fs.readFile(p):gsub("World2='world2 speedtster.rbxl'","World2='audit/incoming_20260913/World2/input.rbxl'")
fs.writeFile(p,s)
print('Integration applied')
