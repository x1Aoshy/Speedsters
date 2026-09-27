local fs=require('@lune/fs')
local rb=require('@lune/roblox')
local serde=require('@lune/serde')
local manifest=serde.decode('json',fs.readFile('src/manifest.json'))
local files={World1='World1Update3New.rbxl',World2='World2Update3new.rbxl',World3='World3Update3New.rbxl'}
local sources={
 'src/common/ReplicatedStorage/Shared/Config.luau',
 'src/common/ReplicatedStorage/Shared/DailyRewardsData.luau',
 'src/common/ReplicatedStorage/Shared/QuestCatalog.luau',
 'src/common/ServerScriptService/Services/FunnelAnalytics.luau',
 'src/common/ServerScriptService/Progression/RebirthSystem.server.luau',
 'src/common/ServerScriptService/Social/AfkZoneService.server.luau',
 'src/common/StarterPlayer/StarterPlayerScripts/UI/FirstTimeTutorial.client.luau',
 'src/common/StarterPlayer/StarterPlayerScripts/UI/StarterPackOffer.client.luau',
}
fs.writeDir('scratch/core_loop_baseline')
for world,file in files do
 local dm=rb.deserializePlace(fs.readFile(file))
 local rows={};for _,r in manifest.worlds[world].scripts do rows[r.source]=r end
 for _,path in sources do
  local row=assert(rows[path],world..' missing '..path)
  local node=dm
  for _,segment in row.segments do node=assert(node:FindFirstChild(segment),segment) end
  local canonical=fs.readFile(path)
  fs.writeFile('scratch/core_loop_baseline/'..world..'_'..path:match('[^/]+$'),node.Source)
  print(world,path:match('[^/]+$'),node.Source==canonical and 'MATCH' or 'DIFF',serde.hash('sha256',node.Source))
 end
end
