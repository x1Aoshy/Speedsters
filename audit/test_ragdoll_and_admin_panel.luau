--!strict
-- Test suite verifying Ragdoll Respawn lifecycle, Reset Authority, and Admin Panel entrypoints.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function assertMatch(content: string, pattern: string, desc: string)
	if not string.find(content, pattern) then
		error("Contract violation: " .. desc .. " pattern not found: " .. pattern)
	end
end

-- 1. Check R6DeathRagdoll.server.luau
local ragdollSrc = fs.readFile("src/common/StarterPlayer/StarterCharacterScripts/R6DeathRagdoll.server.luau")
luau.compile(ragdollSrc)
assertMatch(ragdollSrc, "hasRespawned", "R6DeathRagdoll must track hasRespawned guard")
assertMatch(ragdollSrc, "player:LoadCharacter%(%)", "R6DeathRagdoll must call player:LoadCharacter() on respawn timer")
assertMatch(ragdollSrc, "Players%.RespawnTime", "R6DeathRagdoll must respect Players.RespawnTime")
assertMatch(ragdollSrc, "character%.Destroying", "R6DeathRagdoll must handle character destruction / void fall")
assertMatch(ragdollSrc, "PlayerResetRequest", "R6DeathRagdoll must listen to PlayerResetRequest")

-- 2. Check InstantMovementController.client.luau (ResetButtonCallback hook)
local movementSrc = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Movement/InstantMovementController.client.luau")
luau.compile(movementSrc)
assertMatch(movementSrc, "ResetButtonCallback", "InstantMovementController must hook ResetButtonCallback")
assertMatch(movementSrc, "PlayerResetRequest", "InstantMovementController must notify PlayerResetRequest")

-- 3. Check TopbarIconsController.client.luau: one admin icon, for the one admin panel,
-- shown once the server confirms the player may use it.
local topbarSrc = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/TopbarIconsController.client.luau")
luau.compile(topbarSrc)
assertMatch(topbarSrc, 'buildIcon%("AdminAbuse"', "TopbarIconsController must build the admin panel's icon")
assertMatch(topbarSrc, 'panel%s*=%s*"AdminAbusePanelGui"', "The admin icon must follow AdminAbusePanelGui")
assertMatch(topbarSrc, 'payload%.kind == "Permission" and payload%.allowed == true', "The admin icon must wait for the server's permission")
assert(not string.find(topbarSrc, 'buildIcon("Admin",', 1, true) and not string.find(topbarSrc, 'panel = "SpeedsterAdminPanelGui"', 1, true),
	"Contract violation: the old admin panel's topbar icon must be gone")

-- 4. The old AdminPanelController is retired; the admin panel owns the entry points.
local adminUiSrc = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/UI/AdminPanelController.client.luau")
luau.compile(adminUiSrc)
assert(string.match((string.gsub(adminUiSrc, "%-%-[^\n]*", "")), "^%s*$"), "Contract violation: AdminPanelController must be retired (no code)")
local panelSrc = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Admin/AdminAbusePanelController.client.luau")
luau.compile(panelSrc)
assertMatch(panelSrc, 'payload%.kind == "OpenUI"', "The admin panel must open on OpenUI (/admin, /panel)")
assertMatch(panelSrc, 'action == "OpenBar"', "The admin panel must open on the announcement command's OpenBar")
assertMatch(panelSrc, 'KeyCode%.F2', "F2 must open the admin panel")

-- 5. Check AdminPanelService.server.luau
local adminServSrc = fs.readFile("src/common/ServerScriptService/Admin/AdminPanelService.server.luau")
luau.compile(adminServSrc)
assertMatch(adminServSrc, 'player:SetAttribute%("AdminCommands"', "AdminPanelService must set AdminCommands attribute on join")
assertMatch(adminServSrc, 'PlayerResetRequest', "AdminPanelService must handle PlayerResetRequest")
assertMatch(adminServSrc, ';admin', "AdminPanelService must support ;admin chat command on server")
assertMatch(adminServSrc, 'kind%s*=%s*"OpenUI"', "AdminPanelService must fire OpenUI on chat command")

-- 6. Check ChatBoostCommands.server.luau
local chatCmdSrc = fs.readFile("src/common/ServerScriptService/Admin/ChatBoostCommands.server.luau")
luau.compile(chatCmdSrc)
assertMatch(chatCmdSrc, '/admin', "ChatBoostCommands must handle /admin chat command")
assertMatch(chatCmdSrc, ';admin', "ChatBoostCommands must handle ;admin chat command")
assertMatch(chatCmdSrc, 'kind%s*=%s*"OpenUI"', "ChatBoostCommands must fire OpenUI")

print("PASS test_ragdoll_and_admin_panel: all contracts, respawn logic, and admin entrypoints verified!")
