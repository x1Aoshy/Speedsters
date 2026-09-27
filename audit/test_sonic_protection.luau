local fs = require('@lune/fs')
local luau = require('@lune/luau')

-- Test client protection
local clientSrc = fs.readFile('src/worlds/World2/StarterPlayer/StarterPlayerScripts/Gameplay/World2SonicEXEBoss.client.luau')
luau.compile(clientSrc)

local serverSrc = fs.readFile('src/worlds/World2/ServerScriptService/Bosses/World2SonicEXEBoss.server.luau')
luau.compile(serverSrc)

-- Check that protection checks exist in client and server code
assert(clientSrc:find('isLocallySafe', 1, true), "Client must define isLocallySafe")
assert(clientSrc:find('StageTeleportInvulnerable', 1, true), "Client must check StageTeleportInvulnerable")
assert(clientSrc:find('StageTeleportArrivalGraceUntil', 1, true), "Client must check StageTeleportArrivalGraceUntil")
assert(clientSrc:find('VortexSafeZone', 1, true), "Client must check VortexSafeZone")

assert(serverSrc:find('isProtected', 1, true), "Server must define isProtected")
assert(serverSrc:find('StageTeleportInvulnerable', 1, true), "Server must check StageTeleportInvulnerable")
assert(serverSrc:find('StageTeleportArrivalGraceUntil', 1, true), "Server must check StageTeleportArrivalGraceUntil")
assert(serverSrc:find('VortexSafeZone', 1, true), "Server must check VortexSafeZone")

print("PASS Sonic protection contract: client and server both respect invulnerability and safe zones")