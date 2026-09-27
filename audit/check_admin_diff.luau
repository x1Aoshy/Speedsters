
local fs = require('@lune/fs')
local rb = require('@lune/roblox')
local PlaceFiles = require('./place_files')

local place = rb.deserializePlace(fs.readFile(PlaceFiles.World1))
for _, inst in ipairs(place:GetDescendants()) do
    if inst.Name == 'AdminPanelService' and inst:IsA('LuaSourceContainer') then
        local src = fs.readFile('src/common/ServerScriptService/Admin/AdminPanelService.server.luau')
        print('Place len:', #inst.Source, 'Src len:', #src)
        if inst.Source == src then
            print('MATCH')
        else
            print('DIFF!')
        end
    end
end
