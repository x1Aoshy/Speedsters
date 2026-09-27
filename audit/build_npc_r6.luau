-- audit/build_npc_r6.luau  (Update 4, 2026-09-25)
-- Converts the owner's Eggmanr6andflashr15.rbxm (two R15 rigs) to R6 with audit/u4_npc_r6 and
-- writes design/npc/LobbyCharacters.rbxm (Folder LobbyCharacters: Eggman, Flash).
--   lune run audit/build_npc_r6.luau          write
--   lune run audit/build_npc_r6.luau check    convert only
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local R6 = require("./u4_npc_r6")

local out = R6.Build()
if process.args[1] == "check" then
	print("check: converted in memory, nothing written")
	return
end
fs.writeDir("design/npc")
fs.writeFile(R6.Output, roblox.serializeModel({ out }))
local back = roblox.deserializeModel(fs.readFile(R6.Output))
assert(back[1] and back[1]:FindFirstChild("Eggman") and back[1]:FindFirstChild("Flash"), "read back")
print("wrote " .. R6.Output)
