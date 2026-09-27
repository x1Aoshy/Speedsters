local fs=require('@lune/fs')
local function replace(s,a,b)
 local x,y=s:find(a,1,true);assert(x,'Missing '..a:sub(1,100));return s:sub(1,x-1)..b..s:sub(y+1)
end
for _,world in {'World1','World2'} do
 local root='audit/merged/'..world..'/'
 local function edit(path,fn) fs.writeFile(root..path,fn((fs.readFile(root..path):gsub('\r\n','\n')))) end
 fs.writeFile(root..'ServerScriptService/Services/DynamicCodeDefinitions.luau',fs.readFile('audit/DynamicCodeDefinitions.luau'))
 edit('StarterPlayer/StarterPlayerScripts/UI/TeleportController.luau',function(s)
  s=replace(s,'local buyButtonsByStage = {}','local quotedCosts = {}\nlocal buyButtonsByStage = {}')
  s=replace(s,'local canAfford = wins >= (option.WinsCost or 0)',[[local cost=quotedCosts[stageNum]
			local label=buyBtn:FindFirstChildOfClass("TextLabel")
			if label then label.Text=cost and (formatNumber(cost).." Wins") or "Loading price..." end
			local canAfford = cost~=nil and wins>=cost]])
  s=replace(s,'costLabel.Text = formatNumber(option.WinsCost or 0) .. " Wins"','costLabel.Text = "Loading price..."')
  s=replace(s,'if wins >= (option.WinsCost or 0) then\n\t\t\t\t\t\t\t\tTeleportAction:FireServer("Wins", stageNum)', 'if quotedCosts[stageNum] and wins >= quotedCosts[stageNum] then\n\t\t\t\t\t\t\t\tTeleportAction:FireServer("Wins", stageNum, quotedCosts[stageNum])')
  s=replace(s,'local function openPanel()','local function openPanel()\n\tTeleportAction:FireServer("Quote")')
  s=replace(s,'TeleportUpdate.OnClientEvent:Connect(function(message, messageType)','TeleportUpdate.OnClientEvent:Connect(function(message, messageType)\n\tif type(message)=="table" then\n\t\tif type(message.Costs)=="table" then\n\t\t\tquotedCosts={}\n\t\t\tfor stage,cost in pairs(message.Costs) do\n\t\t\t\tlocal n=tonumber(stage)\n\t\t\t\tif n and type(cost)=="number" and cost==cost and cost>=0 and cost<math.huge then quotedCosts[n]=cost end\n\t\t\tend\n\t\t\tupdateColors()\n\t\tend\n\t\tif message.Success==true then closePanel()\n\t\telseif message.Message and message.Message~="" then requirementFailSound:Play() end\n\t\treturn\n\tend')
  s=replace(s,'ContentProvider:PreloadAsync({requirementFailSound, clickSound})','task.spawn(function() pcall(function() ContentProvider:PreloadAsync({requirementFailSound, clickSound}) end) end)')
  s=s..'\nplayer:GetAttributeChangedSignal("PermanentWinsMultiplier"):Connect(function()\n\tquotedCosts={}\n\tupdateColors()\n\tif isOpen then TeleportAction:FireServer("Quote") end\nend)\n'
  return s
 end)
 edit('ServerScriptService/Worlds/TeleportSystem.luau',function(s)
  s=replace(s,'function(player, action, requestedStage)','function(player, action, requestedStage, displayedCost)')
  s=replace(s,'if not cost then sendUpdate(player, "Stage price is unavailable", false, requestedStage) return end','if not cost then sendUpdate(player, "Stage price is unavailable", false, requestedStage) return end\n\tif displayedCost~=cost then sendUpdate(player,"Price updated. Select the stage again to confirm.",false,requestedStage);return end')
  return s
 end)
 edit('ServerScriptService/Social/CodesSystem.luau',function(s)
  local helper=[[
local dynamicCodes
local function resolveCode(submitted)
	local definition=CodesCatalog.Get(submitted)
	if definition then return definition end
	if not dynamicCodes then
		local ok,store=pcall(function() return game:GetService("DataStoreService"):GetDataStore("AdminAbuseCodes_v1") end)
		if not ok then return nil,"unavailable" end
		dynamicCodes=require(ServerScriptService.Services.DynamicCodeDefinitions).new(store)
	end
	return dynamicCodes:Get(submitted)
end
]]
  s=replace(s,'local function performRedeem(',helper..'\nlocal function performRedeem(')
  s=replace(s,'senderAdminName: string?): (boolean, string)','senderAdminName: string?, eventId: string?): (boolean, string)')
  s=replace(s,'local definition = CodesCatalog.Get(submittedCode)','local definition,lookupError = resolveCode(submittedCode)')
  s=replace(s,'return false, "Invalid code."','return false, lookupError=="unavailable" and "Code service is unavailable. Try again shortly." or "Invalid code."')
  s=replace(s,'("code_force:" .. definition.Marker .. ":" .. DataService.NewOperationId())','("code_force:" .. definition.Marker .. ":" .. (type(eventId)=="string" and eventId or DataService.NewOperationId()))')
  return s
 end)
 edit('ServerScriptService/Admin/AdminPanelService.luau',function(s)
  s=replace(s,'senderName: string): (number, number)','senderName: string, eventId: string?): (number, number)')
  s=replace(s,'_G.SpeedsterRedeemCode(target, codeName, force, senderName)','_G.SpeedsterRedeemCode(target, codeName, force, senderName, eventId)')
  s=replace(s,'redeemCodeForPlayers(data.Code, data.Force == true, data.SenderName or "Admin")','redeemCodeForPlayers(data.Code, data.Force == true, data.SenderName or "Admin", data.EventId)')
  s=replace(s,'local granted, already = redeemCodeForPlayers(cleanCode, force, senderName)','local codeEventId=HttpService:GenerateGUID(false)\n\t\tlocal granted, already = redeemCodeForPlayers(cleanCode, force, senderName, codeEventId)')
  -- Only the code event shares the identity used for local delivery.
  s=replace(s,'Code = cleanCode,\n\t\t\t\tEventId = HttpService:GenerateGUID(false),','Code = cleanCode,\n\t\t\t\tEventId = codeEventId,')
  return s
 end)
end
print('Server-priced travel UI and durable dynamic/admin code identities integrated')
