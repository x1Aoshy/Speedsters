local fs=require('@lune/fs')
local luau=require('@lune/luau')
local rb=require('@lune/roblox')
local server=fs.readFile('src/common/ServerScriptService/Economy/SpeedProductPurchases.server.luau')
local ui=fs.readFile('src/common/StarterPlayer/StarterPlayerScripts/UI/RevivePrompt.client.luau')
local ragdoll=fs.readFile('src/common/StarterPlayer/StarterCharacterScripts/R6DeathRagdoll.server.luau')
for _,s in {server,ui,ragdoll} do luau.compile(s) end
local a=assert(server:find('local function grantReviveTransaction(',1,true))
local b=assert(server:find('local function grantFreeInfiniteRevive(',a,true))
local pending,offers={},{}
local loads,landings=0,0
local failLoad,missingStage,failTeleport=false,false,false
-- Creator Hub funnel steps reported by the revive (Monetization_Revive).
local funnelSteps={}
local function character(dead)
 local hum={Health=if dead then 0 else 100,GetState=function() return if dead then 'Dead' else 'Running' end}
 local root={Parent=true,AssemblyLinearVelocity=0,AssemblyAngularVelocity=0}
 return {Parent=true,hum=hum,root=root,FindFirstChildOfClass=function(self) return self.hum end,
 GetAttribute=function(_,name) return name=='Dead' and dead end,GetPivot=function() return 'spawn' end,
 PivotTo=function(self,pivot) self.pivot=pivot end}
end
local p={Parent=true,Name='Test',attrs={ReviveStageAtDeath=4},Character=character(true)}
function p:GetAttribute(k) return self.attrs[k] end
function p:SetAttribute(k,v) self.attrs[k]=v end
function p:LoadCharacter() if failLoad then error('load failed') end loads+=1;self.Character=character(false) end
local grant=luau.load(server:sub(a,b-1)..'\nreturn grantReviveTransaction',{environment={
 pendingRevivePurchases=pending,activeReviveOffers=offers,cleanStage=function(s) return s end,
 Enum={HumanoidStateType={Dead='Dead'}},task={delay=function() end},
 ReviveCommerce={FireClient=function(_,_,msg) assert(msg.Type=='Granted' and msg.Stage==4) end},
 StageTeleportService={GetStageReferencePosition=function() return not missingStage end,
 TeleportPlayer=function(player,stage)
 assert(stage==4 and player.Character.hum.Health>0)
 if failTeleport then return false,'stage unavailable' end
 landings+=1;player.Character.pivot='safe stage 4';return true
 end},
 waitForLivingCharacter=function(player) local c=player.Character;return c,c.hum,c.root end,
 FunnelAnalytics={Step=function(_,funnel,step,session) table.insert(funnelSteps,{funnel,step,session});return true end},
}})()
for i=1,3 do
 p.Character=character(true)
 pending[p]={Stage=4,DeathCFrame='hazard',ExpiresAt=os.clock()+60}
 local tx=assert(grant(p));tx.Commit()
 assert(p.Character.pivot=='safe stage 4' and pending[p]==nil)
end
assert(loads==3 and landings==3,'Every repeated death must receive a fresh character and stage landing')
assert(#funnelSteps==3,'Each paid revive logs RevivePrompt_Purchased once')
for _,step in funnelSteps do assert(step[1]=='Monetization_Revive' and step[2]==2,'Purchased is step 2 of Monetization_Revive') end
pending[p]={Stage=4,Free=true,ExpiresAt=os.clock()+60};p.Character=character(false)
local freeTx=assert(grant(p));freeTx.Commit()
assert(#funnelSteps==3,'A free Infinite Revives revive is not a purchase')
local tx=assert(grant(p));tx.Commit();assert(loads==3,'Already respawned players need no extra reload')
p.Character=character(true);failLoad=true
assert(grant(p)==nil and p.attrs.RevivedJustNow==false)
failLoad=false;failTeleport=true
assert(grant(p)==nil and p.attrs.RevivedJustNow==false)
failTeleport=false;missingStage=true
assert(grant(p)==nil)
local start=assert(ui:find('local function findChild(',1,true))
local finish=assert(ui:find('local holder =',start,true))
local find=luau.load(ui:sub(start,finish-1)..'\nreturn findChild')()
local frame=rb.Instance.new('Frame')
local title=rb.Instance.new('TextLabel');title.Name='ReviveText';title.Parent=frame
assert(find(frame,{'Price','PriceLabel'},'TextLabel')==nil,'Missing price must not reuse title')
local price=rb.Instance.new('TextLabel');price.Name='Price';price.Parent=frame
assert(find(frame,{'Price','PriceLabel'},'TextLabel')==price)
print('PASS: compilation, repeated deaths, delayed purchase after respawn, load/teleport failures, and distinct UI labels')
