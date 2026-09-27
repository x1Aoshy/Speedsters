
local fs = require('@lune/fs')
local rb = require('@lune/roblox')
local PlaceFiles = require('./place_files')

local place = rb.deserializePlace(fs.readFile(PlaceFiles.World1))
for _, inst in ipairs(place:GetDescendants()) do
    if inst.Name == 'AdminPanelService' and inst:IsA('LuaSourceContainer') then
        local src = fs.readFile('src/common/ServerScriptService/Admin/AdminPanelService.server.luau')
        print('AdminPanelService Place len:', #inst.Source, 'Src len:', #src)
    elseif inst.Name == 'FirstTimeTutorial' and inst:IsA('LocalScript') then
        local src = fs.readFile('src/common/StarterPlayer/StarterPlayerScripts/UI/FirstTimeTutorial.client.luau')
        print('FirstTimeTutorial Place len:', #inst.Source, 'Src len:', #src)
    end
end
