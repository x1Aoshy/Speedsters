local fs=require('@lune/fs');local rb=require('@lune/roblox')
for _,entry in require('./place_files').Places do
 local w=entry.key
 local dm=rb.deserializePlace(fs.readFile(entry.file))
 local source=dm:GetService('ReplicatedStorage').Shared.Config.Source
 assert(source:find('Config.World1PlaceId = 85065221510105',1,true))
 assert(source:find('Config.World2PlaceId = 116359653478954',1,true))
 assert(source:find('Config.World3PlaceId = 128432111599629',1,true))
 local body=false;local banner=false
 for _,i in dm:GetService('StarterGui')['Update Logs']:GetDescendants() do
  if i:IsA('TextLabel') then
   if i.Text:find('NEW CONTENT',1,true) then
    for _,s in {'World 3: Desert','UPDATE3: 2x Speed for 15 min','NEWWORLD: 2x Speed for 20 min','ADMINPARTY: 2x Wins for 15 min','BOOST: 2x Speed and 2x Wins for 15 min'} do assert(i.Text:find(s,1,true),s) end
    body=true
   elseif i.Name=='Code' then banner=i.Text:find('UPDATE3',1,true)~=nil and i.Text:find('ADMINPARTY',1,true)~=nil end
  end
 end
 assert(body and banner);print('PASS saved production IDs, Update Log and code banner',w)
end
