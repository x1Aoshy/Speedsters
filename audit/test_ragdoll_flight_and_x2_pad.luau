local fs = require("@lune/fs")
local luau = require("@lune/luau")
local r = require("@lune/roblox")

print("[Test] Verifying Flight prohibition while Dead or Ragdolled...")

for _, world in ipairs({"World1", "World2"}) do
	local path = string.format("src/worlds/%s/StarterPlayer/StarterPlayerScripts/Movement/%sFlightAbility.client.luau", world, world)
	local content = fs.readFile(path)
	assert(content:find("local function isDeadOrRagdolled()", 1, true), world .. " must have isDeadOrRagdolled helper")
	assert(content:find("if isDeadOrRagdolled() then return end", 1, true), world .. " startFlight must guard with isDeadOrRagdolled")
	assert(content:find("humanoid:GetPropertyChangedSignal(\"PlatformStand\")", 1, true), world .. " must listen to PlatformStand")
	assert(content:find("character:GetAttributeChangedSignal(\"Ragdolled\")", 1, true), world .. " must listen to character Ragdolled attribute")
	assert(content:find("player:GetAttributeChangedSignal(\"Ragdolled\")", 1, true), world .. " must listen to player Ragdolled attribute")
end
print("PASS: Flight Ability scripts have complete dead/ragdoll checks")

local ragdollContent = fs.readFile("src/common/StarterPlayer/StarterCharacterScripts/R6DeathRagdoll.server.luau")
assert(ragdollContent:find("FlightAbilityVelocity", 1, true), "R6DeathRagdoll must destroy FlightAbilityVelocity")
assert(ragdollContent:find("FlightAbilityOrientation", 1, true), "R6DeathRagdoll must destroy FlightAbilityOrientation")
assert(ragdollContent:find("FlightAbilityAttachment", 1, true), "R6DeathRagdoll must destroy FlightAbilityAttachment")
assert(ragdollContent:find("FlightAbilityLocalActive", 1, true), "R6DeathRagdoll must clear FlightAbilityLocalActive")
print("PASS: R6DeathRagdoll cleans flight constraints on ragdoll")

local flightServiceContent = fs.readFile("src/common/ServerScriptService/Core/Abilities/FlightService.luau")
assert(flightServiceContent:find("isRagdolledOrDead", 1, true), "FlightService must check isRagdolledOrDead")
print("PASS: FlightService server authoritative guard active")

print("[Test] Verifying the x2 pads run on the permanent gamepass...")
local w2Pads = fs.readFile("src/worlds/World2/ServerScriptService/Gameplay/World2ManualStagePads.server.luau")
local nw1Pads = fs.readFile("src/worlds/World1/ServerScriptService/Gameplay/NewWorld1ManualStagePads.server.luau")
local winPads = fs.readFile("src/worlds/World1/ServerScriptService/Gameplay/WinPads.server.luau")
local speedProducts = fs.readFile("src/common/ServerScriptService/Economy/SpeedProductPurchases.server.luau")
local padService = fs.readFile("src/common/ServerScriptService/Services/DoubleWinsPad.luau")

for name, source in pairs({ World2 = w2Pads, NewWorld1 = nw1Pads }) do
	assert(source:find("DoubleWinsPad.IsEntitled(player)", 1, true), name .. " pads must ask Services.DoubleWinsPad")
	assert(source:find("DoubleWinsPad.RequestPurchase(player, pad, ", 1, true), name .. " pads must prompt through Services.DoubleWinsPad")
	assert(not source:find("3712435111", 1, true), name .. " pads must not reference the retired per-claim product")
end
assert(not winPads:find("3712435111", 1, true), "Legacy WinPads must not reference the retired per-claim product")
assert(padService:find("PromptGamePassPurchase", 1, true) and not padService:find("PromptProductPurchase", 1, true),
	"Services.DoubleWinsPad must prompt the gamepass, never a developer product")

assert(speedProducts:find('Kind = "DoubleWinsPad"', 1, true), "In-flight receipts for the retired pad product must still be honoured")
assert(speedProducts:find("grantDoubleWinsPadTransaction", 1, true), "SpeedProductPurchases must implement grantDoubleWinsPadTransaction")
assert(speedProducts:find("teleportPlayerToStart", 1, true), "SpeedProductPurchases must have teleportPlayerToStart")

local configContent = fs.readFile("src/common/ReplicatedStorage/Shared/Config.luau")
assert(configContent:find("Config.DoubleWinsPadGamePassId = 1941409601", 1, true), "The x2 pads gamepass must be 1941409601")
assert(configContent:find("Config.RetiredDoubleWinsPadProductId = 3712435111", 1, true), "3712435111 must be kept only as a retired id")
assert(configContent:find("{ Stage = 1, ProductId = 3710772221,", 1, true), "The Wins ladder x2 rung must be dashboard product 3710772221")
print("PASS: x2 pads gamepass (1941409601) and the Wins ladder x2 product (3710772221) are distinct")

local autoReconnect = fs.readFile("src/common/ServerScriptService/Infrastructure/AutoReconnect.server.luau")
assert(autoReconnect:sub(1, 23):find("if true then return end", 1, true), "AutoReconnect must be early-returned")
print("PASS: AutoReconnect deactivated to prevent DataStore queue starvation")

print("ALL RAGDOLL FLIGHT & X2 STAGE PAD CHECKS PASSED!")
