local fs=require('@lune/fs')
local function replace(s,a,b)
 local x,y=s:find(a,1,true);assert(x,'Missing '..a:sub(1,100));return s:sub(1,x-1)..b..s:sub(y+1)
end
for _,world in {'World1','World2'} do
 local root='audit/merged/'..world..'/'
 local function edit(path,fn) fs.writeFile(root..path,fn((fs.readFile(root..path):gsub('\r\n','\n')))) end
 fs.writeFile(root..'ServerScriptService/Services/RemoteGuard.luau',fs.readFile('audit/RemoteGuard.luau'))
 edit('ServerScriptService/Services/Data/ProfileReducers.luau',function(s)
  s=replace(s,'if command.equipped and not table.find(profile.OwnedUpgrades,"Flight") then','if command.equipped and not table.find(profile.OwnedUpgrades,"Flight") and (profile.TemporaryFlightRemainingSeconds or 0)<=0 then')
  s=replace(s,'if added < 0 or added ~= added or added == math.huge then','if type(added) ~= "number" or added < 0 or added ~= added or added == math.huge then')
  s=replace(s,'\t\tif grant.kind == "TemporaryFlight" then\n\t\t\treturn originalApplyCommand(profile,command,nowUnix)\n\t\tend',[[
		if grant.kind == "TemporaryFlight" then
			local result=originalApplyCommand(profile,command,nowUnix)
			if result.ok and (profile.TemporaryFlightRemainingSeconds or 0)>0 then
				for _,marker in {"__AbilityEquipStateInitialized","__AbilityEquipped_Flight"} do
					if not table.find(profile.OwnedUpgrades,marker) then table.insert(profile.OwnedUpgrades,marker) end
				end
			end
			return result
		end]])
  s=replace(s,'\t\tif not finite(grant.multiplier) or grant.multiplier<1 then','\t\tif grant.kind~="SpeedPotion" and grant.kind~="WinsPotion" then return invalid("Unknown buff kind") end\n\t\tif not finite(grant.multiplier) or grant.multiplier<1 then')
  return s
 end)
 edit('ServerScriptService/Services/Stats/StatsProjection.luau',function(s)
  s=replace(s,'local owned=table.find(upgrades,"Flight")~=nil',[[local remaining=profile.TemporaryFlightRemainingSeconds or 0
		local expiry=if remaining>0 then (view.buffSampleUnix or os.time())+remaining else 0
		player:SetAttribute("TemporaryFlightExpireUnix",expiry)
		local owned=table.find(upgrades,"Flight")~=nil or expiry>os.time()]])
  return s
 end)
 edit('ServerScriptService/Services/PotionServer.luau',function(s)
  local start=assert(s:find('function PotionServer.GrantTemporaryFlight(',1,true))
  local finish=assert(s:find('\nfunction PotionServer.GetRemainingTemporaryFlightSeconds',start,true))
  return s:sub(1,start-1)..[[
function PotionServer.GrantTemporaryFlight(player,durationMinutes,granterName,operationId)
	if not player or player.Parent~=Players then return nil end
	local mins=tonumber(durationMinutes) or 20
	if mins~=mins or math.abs(mins)==math.huge or mins<=0 then return nil end
	local DataService=require(script.Parent.Data.DataService)
	local handle=DataService.GetHandle(player.UserId)
	if not handle then return nil end
	local duration=math.min(86400*30,math.floor(mins*60))
	local id=operationId or DataService.NewOperationId()
	local result=DataService.Commit(handle,{operationId=id,fingerprint="temporary-flight:"..duration,commands={{kind="GrantBuff",grant={kind="TemporaryFlight",addedSeconds=duration}}}})
	if result.kind~="Committed" and result.kind~="AlreadyCommitted" then return nil end
	local expire=cleanNonNegative(player:GetAttribute("TemporaryFlightExpireUnix"))
	local message="Flight active for "..makeDurationText(mins).."!"
	local function notify()
		fireBoost(player,{Type="TemporaryFlight",Message=message,RemainingSeconds=math.max(0,expire-now())})
	end
	notify()
	return {ExpireUnix=expire,Notify=notify}
end
]]..s:sub(finish)
 end)
 edit('ServerScriptService/Social/CodesSystem.luau',function(s)
  s=replace(s,'local definition = CodesCatalog.Get(submittedCode)','if type(submittedCode)~="string" or #submittedCode>64 then return false,"Invalid code." end\n\tlocal definition = CodesCatalog.Get(submittedCode)')
  s=replace(s,'("code_force:" .. definition.Marker .. ":" .. tostring(os.clock()))','("code_force:" .. definition.Marker .. ":" .. DataService.NewOperationId())')
  s=replace(s,'\t\tlocal PotionServer = require(ServerScriptService:WaitForChild("Services"):WaitForChild("PotionServer"))\n\t\tPotionServer.GrantTemporaryFlight(player, definition.FlightMinutes, senderAdminName or "Gekkoh")\n\t\tplayer:SetAttribute("FlightAbilityOwned", true)\n\t\tplayer:SetAttribute("FlightAbilityEquipped", true)\n\t\tplayer:SetAttribute("EquippedAbility", "Flight")','\t\t-- GrantBuff and equipment markers were committed together above; projection owns the timer.')
  return s
 end)
 edit('ServerScriptService/Bootstrap.luau',function(s)
  s=replace(s,'local UpdateLogClosed = getOrCreateRemote("UpdateLogClosed")','local UpdateLogClosed = getOrCreateRemote("UpdateLogClosed")\nlocal RemoteGuard = require(ServerScriptService.Services.RemoteGuard)')
  s=replace(s,'SettingsUpdate.OnServerEvent:Connect(','RemoteGuard.Connect(SettingsUpdate, 0.05, ')
  s=replace(s,'UpdateLogClosed.OnServerEvent:Connect(','RemoteGuard.Connect(UpdateLogClosed, 0.5, ')
  s=replace(s,'\tplayer:SetAttribute("LastSeenUpdateLog", game.PlaceVersion)\n','')
  s=replace(s,'DataService.SetPreference(handle, "LastSeenUpdateLog", game.PlaceVersion)','DataService.Commit(handle,{operationId="update-log:"..game.PlaceVersion,fingerprint="update-log:"..game.PlaceVersion,commands={{kind="SetPersistent",key="LastSeenUpdateLog",value=game.PlaceVersion,monotonic=true}}})')
  return s
 end)
 for _,spec in {
  {'ServerScriptService/Economy/AuraShopSystem.luau',{'AuraShopAction'}},
  {'ServerScriptService/Economy/TrailShopSystem.luau',{'TrailShopAction'}},
  {'ServerScriptService/Economy/SkinSystem.luau',{'EquipSkin','SkinIndexAction'}},
  {'ServerScriptService/Progression/RankReward.luau',{'RankRewardEvent'}},
 } do
  edit(spec[1],function(s)
   s='local RemoteGuard = require(game:GetService("ServerScriptService").Services.RemoteGuard)\n'..s
   for _,remote in spec[2] do
    local anchor=remote..'.OnServerEvent:Connect('
    if s:find(anchor,1,true) then s=replace(s,anchor,'RemoteGuard.Connect('..remote..', 0.25, ') end
   end
   return s
  end)
 end
 edit('StarterPlayer/StarterPlayerScripts/UI/ShopController.luau',function(s)
  -- Activated is the cross-device event; registering the mouse alias fires twice.
  s=s:gsub('[^\n]*%.MouseButton1Click:Connect%(closeGiftPanel%)\n','')
  s=s:gsub('[^\n]*%.MouseButton1Click:Connect%(closeShop%)\n','')
  return s
 end)
end
print('Root review: temporary flight, authoritative update-log and bounded remote handlers integrated')
