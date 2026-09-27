local fs=require('@lune/fs')
for _,world in {'World1','World2'} do
 local p='audit/merged/'..world..'/ServerScriptService/Services/PadTouchService.luau'
 local s=fs.readFile(p)
 s=s:gsub('or not entries%[pad%] or entries%[pad%].closed then return false end','or not entries[pad] or entries[pad].closed\n  or proof.cf ~= entries[pad].hitbox.CFrame or proof.size ~= entries[pad].hitbox.Size then return false end')
 s=s:gsub('serial = player:GetAttribute%("StageTeleportProtectionSerial"%) }','serial = player:GetAttribute("StageTeleportProtectionSerial"), cf = entry.hitbox.CFrame, size = entry.hitbox.Size }')
 fs.writeFile(p,s)
end
fs.writeFile('audit/test_pad_volumes.luau',[=[-- Compatibility entrypoint: execute current production modules, not stale audit/PadTouchService.luau.
local fs = require('@lune/fs')
local luau = require('@lune/luau')
luau.load(fs.readFile('audit/test_pad_claim_contract.luau'))()
]=])
