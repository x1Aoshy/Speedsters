local fs=require('@lune/fs');local luau=require('@lune/luau');local rb=require('@lune/roblox')
local expected={85065221510105,116359653478954,128432111599629}
local stub={GetAttribute=function()return nil end,FindFirstChild=function()return nil end}
for number,id in expected do
 local config=luau.load(fs.readFile('src/common/ReplicatedStorage/Shared/Config.luau'),{environment=setmetatable({
  game={PlaceId=id,GetService=function()return stub end},workspace=stub,
  Vector3=rb.Vector3,Color3=rb.Color3,Enum=rb.Enum,CFrame=rb.CFrame,UDim2=rb.UDim2,
 },{__index=_G})})()
 for n,placeId in expected do assert(config['World'..n..'PlaceId']==placeId) end
 assert(config.IsWorld2Place==(number==2));assert(config.IsWorld3Place==(number==3))
 print('PASS production world detection and destinations',number,id)
end
