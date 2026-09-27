local fs=require('@lune/fs');local luau=require('@lune/luau');local rb=require('@lune/roblox')
local source=fs.readFile('src/worlds/World1/ServerScriptService/Gameplay/NewWorld1ServerMotion.server.luau')
local a=assert(source:find('local previousRootByPlayer =',1,true))
local b=assert(source:find('local function getGroupCenters',a,true))
local sample=luau.load(source:sub(a,b-1)..'\nreturn samplePreviousRoot')()
local serial=1
local player={GetAttribute=function() return serial end}
local character={};local root={Position=rb.Vector3.new(10,0,0)}
assert(sample(player,character,root)==root.Position)
root.Position=rb.Vector3.new(20,0,0)
assert(sample(player,character,root)==rb.Vector3.new(10,0,0),'ordinary sweep lost')
local newCharacter={};local newRoot={Position=rb.Vector3.new(1000,0,0)}
assert(sample(player,newCharacter,newRoot)==newRoot.Position,'respawn swept through old hazards')
local replacement={Position=rb.Vector3.new(2000,0,0)}
assert(sample(player,newCharacter,replacement)==replacement.Position,'root replacement swept old path')
serial=2;replacement.Position=rb.Vector3.new(-2000,0,0)
assert(sample(player,newCharacter,replacement)==replacement.Position,'teleport serial retained old sweep')
print('PASS hazard motion history: ordinary movement retained, respawn/root replacement/teleport discontinuities reset')
