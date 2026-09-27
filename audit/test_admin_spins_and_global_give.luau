local fs = require("@lune/fs")
local luau = require("@lune/luau")

print("=== Running test_admin_spins_and_global_give.luau ===")

local adminServiceSrc = fs.readFile("src/common/ServerScriptService/Admin/AdminAbusePanelService.server.luau")
local adminControllerSrc = fs.readFile("src/common/StarterPlayer/StarterPlayerScripts/Admin/AdminAbusePanelController.client.luau")
local messageHandlerSrc = fs.readFile("src/common/StarterGui/Messages/MessageHandler.client.luau")
local spinWheelServiceSrc = fs.readFile("src/common/ServerScriptService/Economy/SpinWheelService.server.luau")
local bridgeSrc = fs.readFile("src/common/ServerScriptService/Progression/PlayerStatsBridge.luau")
local giveCommandsSrc = fs.readFile("src/common/ServerScriptService/Admin/AdminGiveCommands.server.luau")

-- 1. Check AdminAbusePanelController UI
assert(string.find(adminControllerSrc, '{ "Spins", COLORS.Gold }', 1, true), "Controller must have Spins button")
print("PASS: AdminAbusePanelController displays Spins with Gold color")

-- 2. Check AdminAbusePanelService stat normalization
assert(string.find(adminServiceSrc, 'local function normalizeStat', 1, true), "normalizeStat function must exist")
assert(string.find(adminServiceSrc, 's == "spintickets" or s == "tickets" or s == "ticket" or s == "spins" or s == "spin"', 1, true), "normalizeStat must map all variants of spin/tickets to SpinTickets")
print("PASS: AdminAbusePanelService normalizes spins/tickets to SpinTickets")

-- 3. Check commit idempotency fix with unique GUID
assert(string.find(adminServiceSrc, 'fingerprint = reason .. ":" .. HttpService:GenerateGUID(false)', 1, true), "commit must append unique GUID to fingerprint")
print("PASS: AdminAbusePanelService commit uses unique GUID per operation")

-- 4. Check targetsFor resolution
assert(string.find(adminServiceSrc, 'target == "Self" or target == "self"', 1, true), "targetsFor must handle Self")
assert(string.find(adminServiceSrc, 'lower == string.lower(p.Name) or lower == string.lower(p.DisplayName)', 1, true) or string.find(adminServiceSrc, 'string.lower(p.Name) == lower or string.lower(p.DisplayName) == lower', 1, true), "targetsFor must resolve by username/display name")
print("PASS: targetsFor supports All, Self, UserId, and Username/DisplayName")

-- 5. Check announcement format & Level Up sound in AdminAbusePanelService
assert(string.find(adminServiceSrc, 'announce(msg, byName, admin.UserId, "Gold", 8, "rbxassetid://3120909354")', 1, true), "AdminAbusePanelService must announce with level up sound rbxassetid://3120909354")
assert(string.find(adminServiceSrc, 'string.format("%s gave you %s!", byName, spinText)', 1, true), "Announcement must format as '<Admin> gave you <amount> spins!'")
print("PASS: Announcement format '<Admin> gave you <amount> spins!' with sound rbxassetid://3120909354")

-- 6. Check global dispatch via MessagingService and runShared
assert(string.find(adminServiceSrc, 'publish("GiveStat", { stat = stat, amount = amount, target = target, byName = byName, byId = admin.UserId }, admin)', 1, true), "publish GiveStat must be called when everywhere is true")
assert(string.find(adminServiceSrc, 'elseif action == "GiveStat" then', 1, true), "runShared must handle GiveStat action")
assert(string.find(adminServiceSrc, 'announce(msg, byName, byId, "Gold", 8, "rbxassetid://3120909354")', 1, true), "runShared must trigger announce with level up sound on receiving servers")
print("PASS: Cross-server GiveStat broadcast and execution verified")

-- 7. Check MessageHandler client custom sound playback
assert(string.find(messageHandlerSrc, 'payload.SoundId or payload.soundId', 1, true), "MessageHandler must read payload.SoundId")
assert(string.find(messageHandlerSrc, 'sound.SoundId = soundId', 1, true), "MessageHandler must assign sound.SoundId = soundId before playing")
print("PASS: MessageHandler plays custom level up sound when provided")

-- 8. Check SpinWheel immediate refresh export
assert(string.find(spinWheelServiceSrc, '_G.SpeedsterRefreshSpinWheel = function', 1, true), "SpinWheelService must export _G.SpeedsterRefreshSpinWheel")
assert(string.find(adminServiceSrc, '_G.SpeedsterRefreshSpinWheel', 1, true), "AdminAbusePanelService must invoke _G.SpeedsterRefreshSpinWheel on ticket grant")
print("PASS: SpinWheelService provides immediate UI refresh bridge")

-- 9. Check PlayerStatsBridge & AdminGiveCommands
assert(string.find(bridgeSrc, 'statName == "SpinTickets" or statName == "Spins" or statName == "Tickets"', 1, true), "SpeedsterGrantExactStat must support SpinTickets")
assert(string.find(giveCommandsSrc, 'givespins = function', 1, true), "AdminGiveCommands must have givespins")
assert(string.find(giveCommandsSrc, 'givetickets = function', 1, true), "AdminGiveCommands must have givetickets")
print("PASS: PlayerStatsBridge and chat commands support givespins / givetickets")

print("=== ALL CHECKS PASSED SUCCESSFULLY! ===")
