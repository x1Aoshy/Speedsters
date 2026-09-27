local fs = require('@lune/fs')
local serde = require('@lune/serde')
local luau = require('@lune/luau')

local s1 = fs.readFile('src/worlds/World1/ReplicatedFirst/SpawnFloorSurfaceFix.client.luau')
fs.writeDir('src/common/ReplicatedFirst')
fs.writeFile('src/common/ReplicatedFirst/SpawnFloorSurfaceFix.client.luau', s1)

local manifest = serde.decode('json', fs.readFile('src/manifest.json'))
local target = 'src/common/ReplicatedFirst/SpawnFloorSurfaceFix.client.luau'

for world, data in manifest.worlds do
    for _, row in data.scripts do
        if row.path == 'ReplicatedFirst.SpawnFloorSurfaceFix' then
            row.source = target
        end
    end
end

local commonCount = 0
local counted = {}
for world, data in manifest.worlds do
    for _, row in data.scripts do
        if row.source:sub(1, 11) == 'src/common/' and not counted[row.source] then
            counted[row.source] = true
            commonCount += 1
        end
    end
end

manifest.commonSources = commonCount
fs.writeFile('src/manifest.json', serde.encode('json', manifest, true))

pcall(function() fs.removeFile('src/worlds/World1/ReplicatedFirst/SpawnFloorSurfaceFix.client.luau') end)
pcall(function() fs.removeFile('src/worlds/World2/ReplicatedFirst/SpawnFloorSurfaceFix.client.luau') end)

print('PASS unified SpawnFloorSurfaceFix, total common: ' .. commonCount)
