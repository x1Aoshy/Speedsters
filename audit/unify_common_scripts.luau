local fs = require('@lune/fs')
local serde = require('@lune/serde')
local luau = require('@lune/luau')

local manifest = serde.decode('json', fs.readFile('src/manifest.json'))

-- 1. AdminPanelController
local apc = fs.readFile('src/worlds/World1/StarterPlayer/StarterPlayerScripts/UI/AdminPanelController.client.luau')
-- Add Config require
if not apc:find('local Config =', 1, true) then
    local insertPoint = assert(apc:find('local MenuEvents =', 1, true))
    apc = apc:sub(1, insertPoint - 1)
        .. 'local Config = require(ReplicatedStorage.Shared:WaitForChild("Config"))\nlocal isW2 = Config.IsWorld2Place == true\n'
        .. apc:sub(insertPoint)
end
-- Parameterize tab label
apc = apc:gsub('{ Id = "World", Label = "🌍 Mundos" }', '{ Id = "World", Label = isW2 and "🌍 Teleport" or "🌍 Mundos" }')
-- Parameterize text and action
apc = apc:gsub('wDesc%.Text = "[^"]+"', 'wDesc.Text = isW2 and "Regresa a World 1 al instante sin costo ni requisitos:" or "Viaja a World 2 al instante sin costo ni requisitos:"')
apc = apc:gsub('btnTeleport%.Text = "[^"]+"', 'btnTeleport.Text = isW2 and "🚀 TELETRANSPORTAR A WORLD 1 AHORA" or "🚀 TELETRANSPORTAR A WORLD 2 AHORA"')
apc = apc:gsub('AdminPanelAction:FireServer%({ action = "TeleportWorld2" %}%);?', 'AdminPanelAction:FireServer({ action = isW2 and "TeleportWorld1" or "TeleportWorld2" })')
apc = apc:gsub('print%("%[AdminPanelController%] V2 Initialized for World 1%. Styled cleanly to match the game UI%."%)', 'print("[AdminPanelController] V2 Initialized for " .. (isW2 and "World 2" or "World 1") .. ". Styled cleanly to match the game UI.")')

fs.writeDir('src/common/StarterPlayer/StarterPlayerScripts/UI')
fs.writeFile('src/common/StarterPlayer/StarterPlayerScripts/UI/AdminPanelController.client.luau', apc)

-- 2. RotatingLaser
local rl = fs.readFile('src/worlds/World2/ServerScriptService/Gameplay/RotatingLaser.server.luau')
fs.writeDir('src/common/ServerScriptService/Gameplay')
fs.writeFile('src/common/ServerScriptService/Gameplay/RotatingLaser.server.luau', rl)

-- 3. TogetherController
local tc = fs.readFile('src/worlds/World2/ServerScriptService/Gameplay/TogetherController.server.luau')
fs.writeFile('src/common/ServerScriptService/Gameplay/TogetherController.server.luau', tc)

-- 4. WinPadTextDistance
local wptd = fs.readFile('src/worlds/World2/StarterPlayer/StarterPlayerScripts/Gameplay/WinPadTextDistance.client.luau')
fs.writeDir('src/common/StarterPlayer/StarterPlayerScripts/Gameplay')
fs.writeFile('src/common/StarterPlayer/StarterPlayerScripts/Gameplay/WinPadTextDistance.client.luau', wptd)

-- 5. ZoomArenaAmbience
local zaa = fs.readFile('src/worlds/World2/StarterPlayer/StarterPlayerScripts/Gameplay/ZoomArenaAmbience.client.luau')
fs.writeFile('src/common/StarterPlayer/StarterPlayerScripts/Gameplay/ZoomArenaAmbience.client.luau', zaa)

-- 6. ZoomBossAnimation
local zba = fs.readFile('src/worlds/World2/StarterPlayer/StarterPlayerScripts/Gameplay/ZoomBossAnimation.client.luau')
fs.writeFile('src/common/StarterPlayer/StarterPlayerScripts/Gameplay/ZoomBossAnimation.client.luau', zba)

-- 7. ZoomBoss
local zb = fs.readFile('src/worlds/World1/ServerScriptService/Bosses/ZoomBoss.server.luau')
if not zb:find('if Config.IsWorld2Place == true then', 1, true) then
    local insertPoint = assert(zb:find('local IS_NEW_WORLD1 =', 1, true))
    zb = zb:sub(1, insertPoint - 1) .. 'if Config.IsWorld2Place == true then\n\treturn\nend\n' .. zb:sub(insertPoint)
end
fs.writeDir('src/common/ServerScriptService/Bosses')
fs.writeFile('src/common/ServerScriptService/Bosses/ZoomBoss.server.luau', zb)

-- 8. TreadmillCollisionFix
local tcf = fs.readFile('src/worlds/World2/ServerScriptService/Progression/TreadmillCollisionFix.server.luau')
fs.writeDir('src/common/ServerScriptService/Progression')
fs.writeFile('src/common/ServerScriptService/Progression/TreadmillCollisionFix.server.luau', tcf)

-- 9. TreadmillOverheadPerspective
local top = fs.readFile('src/worlds/World2/StarterPlayer/StarterPlayerScripts/Gameplay/TreadmillOverheadPerspective.client.luau')
fs.writeFile('src/common/StarterPlayer/StarterPlayerScripts/Gameplay/TreadmillOverheadPerspective.client.luau', top)

-- 10. TreadmillRebirthBillboardScale
local trbs = fs.readFile('src/worlds/World2/StarterPlayer/StarterPlayerScripts/Gameplay/TreadmillRebirthBillboardScale.client.luau')
fs.writeFile('src/common/StarterPlayer/StarterPlayerScripts/Gameplay/TreadmillRebirthBillboardScale.client.luau', trbs)

-- 11. World2StageSystem
local w2ss = fs.readFile('src/worlds/World2/ServerScriptService/Worlds/World2StageSystem.server.luau')
fs.writeDir('src/common/ServerScriptService/Worlds')
fs.writeFile('src/common/ServerScriptService/Worlds/World2StageSystem.server.luau', w2ss)

-- Map of unified target paths
local unifiedPaths = {
    ['StarterPlayer.StarterPlayerScripts.UI.AdminPanelController'] = 'src/common/StarterPlayer/StarterPlayerScripts/UI/AdminPanelController.client.luau',
    ['ServerScriptService.Gameplay.RotatingLaser'] = 'src/common/ServerScriptService/Gameplay/RotatingLaser.server.luau',
    ['ServerScriptService.Gameplay.TogetherController'] = 'src/common/ServerScriptService/Gameplay/TogetherController.server.luau',
    ['StarterPlayer.StarterPlayerScripts.Gameplay.WinPadTextDistance'] = 'src/common/StarterPlayer/StarterPlayerScripts/Gameplay/WinPadTextDistance.client.luau',
    ['StarterPlayer.StarterPlayerScripts.Gameplay.ZoomArenaAmbience'] = 'src/common/StarterPlayer/StarterPlayerScripts/Gameplay/ZoomArenaAmbience.client.luau',
    ['StarterPlayer.StarterPlayerScripts.Gameplay.ZoomBossAnimation'] = 'src/common/StarterPlayer/StarterPlayerScripts/Gameplay/ZoomBossAnimation.client.luau',
    ['ServerScriptService.Bosses.ZoomBoss'] = 'src/common/ServerScriptService/Bosses/ZoomBoss.server.luau',
    ['ServerScriptService.Progression.TreadmillCollisionFix'] = 'src/common/ServerScriptService/Progression/TreadmillCollisionFix.server.luau',
    ['StarterPlayer.StarterPlayerScripts.Gameplay.TreadmillOverheadPerspective'] = 'src/common/StarterPlayer/StarterPlayerScripts/Gameplay/TreadmillOverheadPerspective.client.luau',
    ['StarterPlayer.StarterPlayerScripts.Gameplay.TreadmillRebirthBillboardScale'] = 'src/common/StarterPlayer/StarterPlayerScripts/Gameplay/TreadmillRebirthBillboardScale.client.luau',
    ['ServerScriptService.Worlds.World2StageSystem'] = 'src/common/ServerScriptService/Worlds/World2StageSystem.server.luau',
}

local filesToRemove = {}

for world, data in manifest.worlds do
    for _, row in data.scripts do
        local target = unifiedPaths[row.path]
        if target then
            if row.source ~= target then
                table.insert(filesToRemove, row.source)
                row.source = target
            end
        end
    end
end

-- Count unique common sources
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

-- Clean up replaced files
for _, file in ipairs(filesToRemove) do
    if fs.isFile(file) then
        pcall(function() fs.removeFile(file) end)
    end
end

-- Compile all sources
for path in counted do
    local s = fs.readFile(path)
    local ok, err = pcall(luau.compile, s)
    assert(ok, 'Compilation error in ' .. path .. ': ' .. tostring(err))
end

print('PASS: Successfully unified 11 scripts into src/common! Total common sources: ' .. commonCount)
