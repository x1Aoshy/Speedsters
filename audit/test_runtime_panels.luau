-- Runs the actual three UI controllers against a small Roblox UI/event harness.
local fs=require('@lune/fs');local luau=require('@lune/luau');local rb=require('@lune/roblox')
local function signal()
 local s={listeners={}}
 function s:Connect(fn) table.insert(self.listeners,fn);return {Disconnect=function() end} end
 s.Once=s.Connect
 function s:Fire(...) for _,fn in self.listeners do fn(...) end end
 return s
end
local methods={}
local objects={}
local function instance(class)
 local o={props={ClassName=class,Name=class,Visible=true,Active=true,Text='',TextSize=16,ZIndex=1,BackgroundTransparency=0,BackgroundColor3=rb.Color3.new(1,1,1),Position=rb.UDim2.fromOffset(0,0),Size=rb.UDim2.fromOffset(100,100),Scale=1,AnchorPoint=rb.Vector2.zero,TextColor3=rb.Color3.new(1,1,1)},children={},events={},attrs={}}
 setmetatable(o,{__index=function(self,k)
  if methods[k] then return methods[k] end
  if self.props[k]~=nil then return self.props[k] end
  for _,c in self.children do if c.Name==k then return c end end
  if k:match('Changed$') or k:match('Added$') or k:match('Removing$') or k:match('Began$') or k:match('Ended$') or k:match('Event$') or k=='Activated' or k=='MouseButton1Click' or k=='MouseEnter' or k=='MouseLeave' or k=='Chatted' or k=='MessageReceived' or k=='Completed' then
   self.events[k]=self.events[k] or signal();return self.events[k]
  end
  return nil
 end,__newindex=function(self,k,v)
  if k=='Parent' then
   local old=self.props.Parent
   if old then local idx=table.find(old.children,self);if idx then table.remove(old.children,idx) end end
   if v then table.insert(v.children,self) end
  end
  self.props[k]=v
 end})
 table.insert(objects,o);return o
end
function methods:IsA(class)
 return self.ClassName==class or class=='Instance' or class=='GuiButton' and (self.ClassName=='TextButton' or self.ClassName=='ImageButton')
 or class=='GuiObject' and ({Frame=true,ScrollingFrame=true,TextButton=true,ImageButton=true,TextLabel=true,TextBox=true,ImageLabel=true})[self.ClassName]==true
end
function methods:FindFirstChild(name,recursive)
 for _,c in self.children do if c.Name==name then return c end end
 if recursive then for _,c in self.children do local found=c:FindFirstChild(name,true);if found then return found end end end
end
-- Like Roblox: with a timeout a missing child is nil; without one the test stops.
function methods:WaitForChild(name,timeout) local found=self:FindFirstChild(name);if found or timeout then return found end;error('Missing '..self.Name..'.'..name) end
function methods:GetChildren() return table.clone(self.children) end
function methods:GetDescendants() local all={};for _,c in self.children do table.insert(all,c);for _,d in c:GetDescendants() do table.insert(all,d) end end;return all end
function methods:FindFirstChildOfClass(class) for _,c in self.children do if c:IsA(class) then return c end end end
function methods:FindFirstChildWhichIsA(class,recursive) for _,c in recursive and self:GetDescendants() or self.children do if c:IsA(class) then return c end end end
function methods:GetPropertyChangedSignal(k) self.events[k]=self.events[k] or signal();return self.events[k] end
function methods:GetAttribute(k) return self.attrs[k] end
function methods:SetAttribute(k,v) self.attrs[k]=v end
function methods:GetAttributeChangedSignal(k) return self:GetPropertyChangedSignal('attr_'..k) end
function methods:Destroy() self.Parent=nil end
function methods:Play() end
function methods:Clone() local n=instance(self.ClassName);for k,v in self.props do if k~='Parent' then n[k]=v end end;return n end
local function child(parent,class,name) local c=instance(class);c.Name=name;c.Parent=parent;return c end
local services={}
for _,name in {'Players','ReplicatedStorage','Workspace','RunService','SoundService','UserInputService','TweenService','MarketplaceService','TextChatService','GuiService'} do services[name]=instance(name) end
services.GuiService.GetGuiInset=function() return rb.Vector2.new(0,58),rb.Vector2.zero end
local player=child(services.Players,'Player','Tester');player.UserId=5113549114;player.DisplayName='Tester'
services.Players.LocalPlayer=player;services.Players.GetPlayers=function() return {player} end
local pg=child(player,'PlayerGui','PlayerGui');local ps=child(player,'PlayerScripts','PlayerScripts')
local remotes=child(services.ReplicatedStorage,'Folder','Remotes');local shared=child(services.ReplicatedStorage,'Folder','Shared')
for _,name in {'QuestRequest','QuestUpdate','AfkRewardsRequest','AfkRewardsUpdate','AdminPanelAction','AdminPanelStatus'} do
 local r=child(remotes,'RemoteEvent',name);r.calls={};r.FireServer=function(self,payload) table.insert(self.calls,payload) end
end
local camera=child(services.Workspace,'Camera','Camera');camera.ViewportSize=rb.Vector2.new(1280,720);services.Workspace.CurrentCamera=camera
services.RunService.IsStudio=function() return true end
services.RunService.UnbindFromRenderStep=function() end
services.UserInputService.GetFocusedTextBox=function() return nil end
services.TweenService.Create=function(_,target,_,values) return {Play=function() for k,v in values do target[k]=v end end,Cancel=function() end,Completed=signal()} end
services.RunService.RenderStepped=signal()
local events={};local close=signal();close.Event=close;local menu={CloseAll=close,MarkReady=function() end}
menu.Get=function(name) if not events[name] then events[name]={Event=signal()} end;return events[name] end
local modules={}
for _,name in {'StudUi','GamePanelStyle','MenuEvents','QuestCatalog','QuestUi','Config','FeatureGate','DesignerUiBuilder','PurchaseButtonSound','SpinWheelCatalog','UiShake','AfkEarningsLayout'} do child(shared,'ModuleScript',name) end
local designerFolder=child(shared,'Folder','DesignerUi');child(designerFolder,'ModuleScript','EarningsGui');child(designerFolder,'ModuleScript','QuestGui')
local banner=child(services.ReplicatedStorage,'ModuleScript','AdminBannerConfig')
modules.MenuEvents=menu;modules.Config={VipGamePassId=1,PreviewFeatures={UserIds={767108248},TestingPlaceIds={}}};modules.AdminBannerConfig={IsAdmin=function() return true end}
modules.PurchaseButtonSound={Play=function() end};modules.UiShake={Wiggle=function() end,Jitter=function() end}
local env={game={GetService=function(_,name) return assert(services[name],name) end,CreatorType=rb.Enum.CreatorType.User,CreatorId=1,PlaceId=0},workspace=services.Workspace,
 Instance={new=instance},Enum=rb.Enum,Vector2=rb.Vector2,Vector3=rb.Vector3,CFrame=rb.CFrame,UDim=rb.UDim,UDim2=rb.UDim2,Color3=rb.Color3,ColorSequence=rb.ColorSequence,ColorSequenceKeypoint=rb.ColorSequenceKeypoint,
 Font=rb.Font,Rect=rb.Rect,NumberSequence=rb.NumberSequence,NumberSequenceKeypoint=rb.NumberSequenceKeypoint,NumberRange=rb.NumberRange,warn=function() end,
 TweenInfo={new=function() return {} end},task={spawn=function() end,defer=function() end,delay=function() end},
 require=function(obj) return assert(modules[obj.Name],'module '..obj.Name) end}
for _,name in {'StudUi','GamePanelStyle','QuestCatalog','QuestUi','FeatureGate','DesignerUiBuilder','SpinWheelCatalog','AfkEarningsLayout'} do
 env.script=shared:FindFirstChild(name)
 modules[name]=luau.load(fs.readFile('src/common/ReplicatedStorage/Shared/'..name..'.luau'),{environment=env})()
end
modules.EarningsGui=luau.load(fs.readFile('src/common/ReplicatedStorage/Shared/DesignerUi/EarningsGui.luau'),{environment=env})()
modules.QuestGui=luau.load(fs.readFile('src/common/ReplicatedStorage/Shared/DesignerUi/QuestGui.luau'),{environment=env})()
for _,name in {'QuestController','AfkRewardsController','AdminPanelController'} do
 env.script=instance('LocalScript')
 luau.load(fs.readFile('src/common/StarterPlayer/StarterPlayerScripts/UI/'..name..'.client.luau'),{environment=env})()
 print('PASS constructed '..name)
end
-- Quests and AFK are preview features. This harness reports IsStudio, so each controller
-- must BUILD here; the retired old admin panel must build nothing, even in Studio.
assert(pg:FindFirstChild('QuestGui') ~= nil, 'QuestGui must build inside Studio')
assert(pg:FindFirstChild('AfkRewardsGui') ~= nil, 'AfkRewardsGui must build inside Studio')
assert(pg:FindFirstChild('AfkRewardsGui'):FindFirstChild('Earnings') ~= nil, 'The AFK panel must be the designer Earnings layout')
assert(pg:FindFirstChild('SpeedsterAdminPanelGui') == nil, 'The old SpeedsterAdminPanelGui is retired and must not build')

-- And each must carry the gate that keeps it off a live server.
for _, name in { 'QuestController', 'AfkRewardsController' } do
 local source = fs.readFile('src/common/StarterPlayer/StarterPlayerScripts/UI/' .. name .. '.client.luau')
 assert(source:find('IsPreviewPlayer', 1, true), name .. ' must be gated by Shared.FeatureGate')
 assert(not source:find('if true then', 1, true), name .. ' must not be hard-disabled any more')
end
local adminSource = fs.readFile('src/common/StarterPlayer/StarterPlayerScripts/UI/AdminPanelController.client.luau')
assert(adminSource:gsub('%-%-[^\n]*', ''):match('^%s*$'), 'AdminPanelController is retired and must hold no code')
print('PASS live UI event routes; quests/afk build in Studio and are gated off live; the old admin panel is retired')

-- Turning AFK Mode on opens the Earnings panel as its overlay (2026-09-18: AFK Mode
-- replaced the AFK Zone circle): clean designer cards without fills, how long the player
-- has been AFK, the Speed and Spin Tickets paid, the countdowns, and Exit AFK.
do
 modules.Config.AfkZone={RewardIntervalSeconds=60,TicketIntervalSeconds=600}
 services.Workspace.GetServerTimeNow=function() return 5000 end
 player:SetAttribute('AfkModeRewardIn',15);player:SetAttribute('AfkModeTicketIn',300);player:SetAttribute('AfkModeSpeed',12000);player:SetAttribute('AfkModeTickets',2)
 player:SetAttribute('AfkModeSince',services.Workspace:GetServerTimeNow()-125)
 player:SetAttribute('AfkModeActive',true)
 player:GetAttributeChangedSignal('AfkModeActive'):Fire()
 local afkGui=pg:FindFirstChild('AfkRewardsGui')
 assert(afkGui.Enabled==true,'Turning AFK Mode on must open the Earnings panel')
 local earnings=afkGui:FindFirstChild('Earnings')
 local speedCard=earnings:FindFirstChild('Speed')
 local winsCard
 for _,child in earnings:GetChildren() do if child.Name=='Fire' and child:FindFirstChild('Icon') then winsCard=child end end
 assert(speedCard and winsCard,'Both cards must exist')
 assert(speedCard:FindFirstChild('AfkFill')==nil and winsCard:FindFirstChild('AfkFill')==nil,'Cards must remain clean without fills')
 local NBSP=utf8.char(160)
 local function plain(text) return (string.gsub(text,NBSP,' ')) end
 local speedLabel=speedCard:FindFirstChild('Speed')
 assert(plain(speedLabel.Text)=='+12K Speed!','The Speed card shows the Speed AFK Mode has paid')
 local timer=earnings:FindFirstChild('AfkTimer')
 assert(timer and plain(timer.Text)=='Speed in 0:15 | Spin in 5:00','The timer shows both countdowns: '..plain(timer.Text))
 -- The designer's text settings stay exactly as designed: with TextWrapped off, TextScaled
 -- sizes by height and the text grows out of its box. Texts use no-break spaces instead,
 -- so they never wrap into lines drawn on top of each other.
 for _,label in {speedLabel,timer,earnings:FindFirstChild('Claim'):FindFirstChild('Name')} do
  assert(label.TextWrapped==true and label.TextScaled==true,label.Name..' must keep TextWrapped and TextScaled on')
  assert(label.LineHeight <= 1.0,label.Name..' must have clean LineHeight')
 end
 local claim=earnings:FindFirstChild('Claim')
 local claimGradient=claim:FindFirstChildOfClass('UIGradient')
 assert(claimGradient and claimGradient.Enabled==true,'Exit AFK is always ready')
 assert(plain(claim:FindFirstChild('Name').Text)=='Exit AFK','The button reads Exit AFK')
 local winsLabel=winsCard:FindFirstChild('Speed')
 assert(plain(winsLabel.Text)=='+2','The other card counts the Spin Tickets paid')
 assert(winsCard:FindFirstChild('Icon').Image=='rbxassetid://135011356419232','...with the flame icon')
  local title
  for _,child in earnings:GetChildren() do if child.Name=='Name' and child:IsA('TextLabel') and plain(child.Text)=='AFK Mode' then title=child end end
  assert(title,'The panel is titled AFK Mode')
  local subtitleOk=false
  for _,child in earnings:GetChildren() do if child.Name=='Name' and child:IsA('TextLabel') and string.find(plain(child.Text),'AFK for 2:0',1,true) then subtitleOk=true end end
  assert(subtitleOk,'It shows how long the player has been AFK')
  player:SetAttribute('AfkModeSpeed',36000)
  player:GetAttributeChangedSignal('AfkModeSpeed'):Fire()
  assert(plain(speedLabel.Text)=='+36K Speed!','The Speed card follows each payment')
  local requests=remotes:FindFirstChild('AfkRewardsRequest').calls
  local before=#requests
  claim.Activated:Fire()
  assert(#requests==before+1 and requests[#requests].action=='ExitAfk','Exit AFK asks the server to turn it off')
  player:SetAttribute('AfkModeActive',false)
  player:GetAttributeChangedSignal('AfkModeActive'):Fire()
  print('PASS AFK Mode opens the clean designer Earnings panel as its overlay: time, Speed, Spin Tickets, countdowns, Exit AFK')
end

-- Exercise the real AFK server with an actor-backed profile and a controllable clock.
local Actor=require('../src/common/ServerScriptService/Services/Data/SessionActor')
local Adapter=require('../src/common/ServerScriptService/Services/Data/DataStoreAdapter')
local now=3000000
local clock={UnixNow=function() return now end,MonotonicNow=function() return now end}
local store=Adapter.CreateMock({['Player_'..player.UserId]={Version=306,Speed=1,Wins=0,LastLogoutTimestamp=now-3600}})
local actor=Actor.new({userId=player.UserId,sessionId='afk-runtime',storeAdapter=store,clock=clock})
local opened=actor:Open();assert(opened.ok);local handle=opened.value
local commits={};local pendingOnce=false
modules.DataService={GetHandle=function() return handle end,Inspect=function(h) return actor:Inspect(h) end,
 Commit=function(h,request)
  table.insert(commits,request.operationId)
  if pendingOnce then pendingOnce=false;return {kind='Pending'} end
  return actor:Commit(h,request)
 end}
modules.ServerRateLimiter={Allow=function() return true end}
services.ServerScriptService=instance('ServerScriptService')
local folder=child(services.ServerScriptService,'Folder','Services')
child(folder,'ModuleScript','ServerRateLimiter')
local data=child(folder,'Folder','Data');child(data,'ModuleScript','DataService')
player:SetAttribute('DataLoaded',true);player:SetAttribute('Level',1)
for _,name in {'AfkRewardsRequest','AfkRewardsUpdate'} do
 remotes[name].FireClient=function(self,_,payload) self.lastPayload=payload end
end
env.os=table.clone(os);env.os.time=function() return now end;env._G={}
-- Runs a fresh copy of a preview service and reports whether a request reached the panel.
local function serves(source, request, reply, message, studio, userId)
 services.RunService.IsStudio=function() return studio end
 player.UserId=userId
 remotes[request].events={};remotes[reply].lastPayload=nil
 luau.load(source,{environment=env})()
 remotes[request].OnServerEvent:Fire(player,message)
 return remotes[reply].lastPayload~=nil
end
local afkSource=fs.readFile('src/common/ServerScriptService/Social/AfkRewardsService.server.luau')
assert(not serves(afkSource,'AfkRewardsRequest','AfkRewardsUpdate',{action='RequestStatus'},false,5113549114),
 'On a live server the AFK service must ignore players outside the preview')
assert(serves(afkSource,'AfkRewardsRequest','AfkRewardsUpdate',{action='RequestStatus'},false,767108248),
 'On a live server the AFK service must serve the preview account (GekkoH)')
assert(serves(afkSource,'AfkRewardsRequest','AfkRewardsUpdate',{action='RequestStatus'},true,5113549114),
 'In Studio the AFK service must serve everyone')
player.UserId=5113549114
print('PASS real AFK service: preview accounts on live servers, everyone in Studio')
-- Render-step harness for camera-relative shards and shake cleanup.
services.Lighting=instance('Lighting');services.Debris={AddItem=function() end}
local bindings={}
services.RunService.BindToRenderStep=function(_,name,priority,fn) bindings[name]={priority=priority,fn=fn} end
services.RunService.UnbindFromRenderStep=function(_,name) bindings[name]=nil end
camera.CFrame=rb.CFrame.new(0,10,0);camera.FieldOfView=70;camera.ViewportSize=rb.Vector2.new(1280,720)
local shatterSource=fs.readFile('src/common/ReplicatedStorage/Shared/GlassShatter.luau')
local shatter=luau.load(shatterSource,{environment=env})()
-- A preview feature: the gate is what keeps it off a live server for everyone else.
assert(shatterSource:find('FeatureGate.IsPreviewPlayer', 1, true), 'GlassShatter must be gated by Shared.FeatureGate')
assert(not shatterSource:find('if true then', 1, true), 'GlassShatter must not be hard-disabled any more')
services.RunService.IsStudio=function() return false end
shatter.Play({PlaySound=false,CameraPunch=true})
assert(camera:FindFirstChild('SpeedsterGlassShards') == nil, 'Shards must not spawn on a live server')
assert(next(bindings) == nil, 'Render bindings must not be registered on a live server')
services.RunService.IsStudio=function() return true end
print('PASS shatter: gated by the preview gate, inert on a live server')
-- Exercise actual quest service synchronization and its claim dispatcher.
local operation=0
modules.DataService.NewOperationId=function() operation+=1;return 'quest-runtime-'..operation end
remotes.QuestUpdate.FireClient=function(self,_,payload) self.lastPayload=payload end
env.os.clock=function() return now end
local questSource=fs.readFile('src/common/ServerScriptService/Social/QuestService.server.luau')
assert(not serves(questSource,'QuestRequest','QuestUpdate',{action='RequestState'},false,5113549114),
 'On a live server the quest service must ignore players outside the preview')
assert(serves(questSource,'QuestRequest','QuestUpdate',{action='RequestState'},false,767108248),
 'On a live server the quest service must serve the preview account (GekkoH)')
assert(serves(questSource,'QuestRequest','QuestUpdate',{action='RequestState'},true,5113549114),
 'In Studio the quest service must serve everyone')
assert(serves(questSource,'QuestRequest','QuestUpdate',{action='State'},true,5113549114),
 'The panel asks for its state with State')
player.UserId=5113549114
print('PASS real quest service: preview accounts on live servers, everyone in Studio')

-- Choose Your Destiny end to end: the real service on the actor-backed profile, and the
-- real panel drawing what it sends.
do
 local Catalog=modules.QuestCatalog
 local request,update=remotes.QuestRequest,remotes.QuestUpdate
 local function ask(message) request.OnServerEvent:Fire(player,message);return update.lastPayload end
 local fresh=ask({action='RequestState'})
 local day=math.floor(now/86400)
 local paths=Catalog.PathsFor(day)
 assert(fresh and #fresh.Paths==3 and fresh.Choice==0 and fresh.Claimed==false,'Three quests to choose from, none chosen')
 for index,path in fresh.Paths do
  assert(path.Id==paths[index].Id and #path.Tasks==3 and #path.Rewards==#paths[index].Rewards,'Quest '..index..' is the catalog quest')
  for _,task in path.Tasks do assert(task.Text~='' and task.Icon~='' and task.Progress==0,'Tasks read well and start at zero') end
 end
 assert(actor:Commit(handle,{operationId='before-pick',fingerprint='before-pick',commands={{kind='QuestProgress',metric='stages',amount=5},{kind='QuestProgress',metric='wins',amount=1}}}).kind=='Committed')
 local chosen=ask({action='Choose',choice=2})
 assert(chosen.Choice==2 and chosen.success==true,'Picking quest 2')
 for _,task in chosen.Paths[2].Tasks do assert(task.Progress==0,'The pick counts from its moment: '..task.Metric) end
 assert(ask({action='Choose',choice=1}).Choice==2 and update.lastPayload.success==false,'One pick a day')
 assert(ask({action='Choose',index=1}).Choice==2 and update.lastPayload.success==false,'...also asked the older way')
 assert(ask({action='Claim'}).Claimed==false and update.lastPayload.success==false,'Nothing to claim yet')
 local work={}
 for _,task in chosen.Paths[2].Tasks do table.insert(work,{kind='QuestProgress',metric=task.Metric,amount=task.Target}) end
 assert(actor:Commit(handle,{operationId='quest-work',fingerprint='quest-work',commands=work}).kind=='Committed')
 local complete=ask({action='State'})
 assert(complete.Paths[2].Complete==true,'Every task done')
 for _,task in complete.Paths[2].Tasks do assert(task.Progress==task.Target,'Bars full: '..task.Metric) end
 local before=actor:Inspect(handle).value.profile
 local claimed=ask({action='Claim'})
 local after=actor:Inspect(handle).value.profile
 assert(claimed.Claimed==true and claimed.success==true,'Claimed')
 for _,reward in paths[2].Rewards do
  local amount=Catalog.RewardAmount(reward,1,before.Speed)
  if reward.Kind=='Wins' then assert(after.Wins-before.Wins==amount,'Wins paid')
  elseif reward.Kind=='Speed' then assert(after.Speed-before.Speed==amount,'Speed paid')
  elseif reward.Kind=='SpinTicket' then assert((after.SpinTickets or 0)-(before.SpinTickets or 0)==amount,'Spin tickets paid')
  elseif reward.Kind=='PotionSpeed' then assert((after.PotionSpeedRemainingSeconds or 0)-(before.PotionSpeedRemainingSeconds or 0)==amount*60,'Speed potion paid')
  elseif reward.Kind=='PotionWins' then assert((after.PotionWinsRemainingSeconds or 0)-(before.PotionWinsRemainingSeconds or 0)==amount*60,'Wins potion paid') end
 end
 ask({action='Claim'})
 assert(actor:Inspect(handle).value.profile.Wins==after.Wins,'Pays once')

 -- The panel draws each of those states, on the designer's layout (design/ui/Quests.rbxm)
 -- finished by Shared.QuestUi.
 local NBSP=utf8.char(160)
 local function plain(text) return (string.gsub(text,NBSP,' ')) end
 local function clockText(seconds) return string.format('%02d:%02d:%02d',seconds//3600,seconds%3600//60,seconds%60) end
 local questGui=pg:FindFirstChild('QuestGui')
 assert(questGui.ZIndexBehavior==rb.Enum.ZIndexBehavior.Sibling,'The quest panel draws sibling by sibling')
 assert(questGui.ResetOnSpawn==false and questGui.Enabled==false,'Kept across respawns, closed until opened')
 local frame=questGui:FindFirstChild('Frame')
 assert(plain(frame:FindFirstChild('Title').Text)=='Choose your destiny','The designer\'s title')
 local closeX=frame:FindFirstChild('Close')
 assert(closeX and closeX.ClassName=='ImageButton' and closeX.Image=='rbxassetid://110882579806743','The round close image button')
 assert(questGui:FindFirstChild('Dim') and frame:FindFirstChild('UIScale') and frame:FindFirstChild('UIScale').ClassName=='UIScale','A backdrop, and the panel\'s one UIScale')
 local cards={}
 for index=1,3 do cards[index]=frame:FindFirstChild('Quest'..index);assert(cards[index],'Card '..index) end
 assert(cards[1].Position.X.Scale<cards[2].Position.X.Scale and cards[2].Position.X.Scale<cards[3].Position.X.Scale,'The designer\'s cards, left to right')
 local designSize=cards[1].Size
 update.OnClientEvent:Fire(fresh)
 local shown=plain(frame:FindFirstChild('Timer').Text)
 assert(shown=='🕒 Resets in: '..clockText(fresh.TimeLeft) or shown=='🕒 Resets in: '..clockText(fresh.TimeLeft-1),'The countdown under the title: '..shown)
 for index=1,3 do
  local card,path=cards[index],fresh.Paths[index]
  local list=card:FindFirstChild('list')
  for taskIndex=1,3 do
   local row=list:FindFirstChild('Task'..taskIndex)
   local task=path.Tasks[taskIndex]
   assert(row.Visible and plain(row:FindFirstChild('Title').Text)==task.Text and row:FindFirstChild('Bar').Visible==false,'Task text, no bar before the pick')
   assert(row:FindFirstChild('Icon').Image==Catalog.Metrics[task.Metric].Image,'The task\'s own icon')
  end
  assert(list:FindFirstChild('Task4').Visible==false,'The fourth row is not needed')
  local items=0
  for rewardIndex=1,4 do
   local item=card:FindFirstChild('RewardTemplate'):FindFirstChild('Reward'..rewardIndex)
   local reward=path.Rewards[rewardIndex]
   assert(item.Visible==(reward~=nil),'Reward '..rewardIndex..' shows only when the quest has it')
   if reward then
    items+=1
    assert(item.Image==reward.Icon and plain(item:FindFirstChild('Quantity').Text)==reward.Text,'The reward\'s icon and amount')
   end
  end
  assert(items==#path.Rewards,'Card '..index..' shows every reward')
  assert(plain(card:FindFirstChild('Choose'):FindFirstChild('Name').Text)=='Choose' and card:FindFirstChild('Shade').Visible==false,'Choose, nothing dimmed')
 end
 local choose=cards[2]:FindFirstChild('Choose')
 local label=choose:FindFirstChild('Name')
 local press=choose:FindFirstChild('PressScale')
 -- The press and the bounce back.
 choose.InputBegan:Fire({UserInputType=rb.Enum.UserInputType.MouseButton1})
 assert(press.Scale==0.95,'Pressing shrinks the button')
 choose.InputEnded:Fire({UserInputType=rb.Enum.UserInputType.MouseButton1})
 assert(press.Scale==1,'...and it bounces back')
 request.calls={}
 choose.Activated:Fire()
 assert(plain(label.Text)=='Confirm?' and #request.calls==0,'The first tap asks to confirm')
 choose.Activated:Fire()
 assert(request.calls[1] and request.calls[1].action=='Choose' and request.calls[1].choice==2,'The second tap picks it')
 update.OnClientEvent:Fire(chosen)
 assert(cards[1]:FindFirstChild('Shade').Visible==true and plain(cards[1]:FindFirstChild('Choose'):FindFirstChild('Name').Text)=='Locked','The other quests dim and lock')
 assert(plain(label.Text)=='In Progress' and cards[2]:FindFirstChild('Glow').Enabled==true,'The picked quest glows')
 local firstRow=cards[2]:FindFirstChild('list'):FindFirstChild('Task1')
 local firstTask=chosen.Paths[2].Tasks[1]
 assert(firstRow:FindFirstChild('Bar').Visible==true,'...and shows its bars')
 assert(plain(firstRow:FindFirstChild('Title').Text)==firstTask.Text..' ('..firstTask.ProgressText..')','Live progress on the task: '..plain(firstRow:FindFirstChild('Title').Text))
 update.OnClientEvent:Fire(complete)
 assert(plain(label.Text)=='Claim!' and player:GetAttribute('QuestRewardReady')==true,'Claim!, and the topbar icon lights up')
 assert(press.Scale>1,'Claim! pulses')
 assert(string.find(plain(firstRow:FindFirstChild('Title').Text),'(Done!)',1,true) and firstRow:FindFirstChild('Bar'):FindFirstChild('Fill').Size.X.Scale==1,'Done tasks say so, with full bars')
 request.calls={}
 choose.Activated:Fire()
 assert(request.calls[1] and request.calls[1].action=='Claim','Claim asks the server')
 local pieces=#frame:FindFirstChild('Confetti'):GetChildren()
 update.OnClientEvent:Fire(claimed)
 assert(plain(label.Text)=='Claimed ✓' and player:GetAttribute('QuestRewardReady')==false,'Claimed')
 assert(cards[2]:FindFirstChild('Badge').Visible==true and plain(cards[2]:FindFirstChild('Badge').Text)=='COMPLETED','A COMPLETED badge')
 assert(#frame:FindFirstChild('Confetti'):GetChildren()>=pieces+20,'Confetti for the claim')

 -- Opening pops the panel in and asks for a fresh state.
 request.calls={}
 menu.Get('OpenQuestsPanel').Event:Fire('Open')
 assert(questGui.Enabled==true and frame:FindFirstChild('UIScale').Scale==1,'Open: the panel pops to full size')
 -- "Open" is answered with the state too (and counts the quests funnel's first step).
 assert(request.calls[1] and (request.calls[1].action=='Open' or request.calls[1].action=='State'),'Opening asks for the state')
 -- Phones: a compact window with the cards fitted to its height; a wide screen puts the
 -- designer's layout back.
 local scroller=frame:FindFirstChild('Scroller')
 assert(scroller.Visible==false and cards[1].Parent==frame,'A 1280x720 screen shows the designer\'s layout')
 services.UserInputService.TouchEnabled=true
 camera.ViewportSize=rb.Vector2.new(844,390)
 camera:GetPropertyChangedSignal('ViewportSize'):Fire()
 assert(scroller.Visible==true and cards[1].Parent==scroller and cards[3].Parent==scroller,'A phone scrolls the cards')
 assert(cards[1].Size.X.Offset>=100 and cards[2].Position.X.Offset>cards[1].Position.X.Offset,'...side by side')
 assert(frame.Size.Y.Offset<=390*0.84+1 and frame.Size.X.Offset<=844*0.92+1,'...in a compact window, not the whole screen')
 assert(frame:FindFirstChild('Close').Size.X.Offset>=32,'...with a close button big enough to tap')
 services.UserInputService.TouchEnabled=false
 camera.ViewportSize=rb.Vector2.new(1280,720)
 camera:GetPropertyChangedSignal('ViewportSize'):Fire()
 assert(scroller.Visible==false and cards[1].Parent==frame and cards[1].Size==designSize,'Back on a wide screen, the designer\'s layout')

 -- A new day, a new choice.
 now+=86400
 local nextDay=ask({action='RequestState'})
 assert(nextDay.Choice==0 and nextDay.Claimed==false,'A new day brings a new choice')
 now-=86400
 print('PASS Choose Your Destiny: real service and the designer panel - countdown, pick with confirm, glow and live bars, pulsing Claim!, pays once with confetti, phone scroll, new day new pick')
end
