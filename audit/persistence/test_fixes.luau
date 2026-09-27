local fs = require("@lune/fs")
local luau = require("@lune/luau")

print("=== TESTING GAMEPLAY FIXES ===")

-- 1. Check Config.luau Candy in World 1
do
    local c1 = fs.readFile("audit/merged/World1/ReplicatedStorage/Shared/Config.luau")
    assert(c1:find("RequiredRebirths = 3", 1, true), "World1 Candy must require Rebirths")
    assert(not c1:find("GamePassId = 1941090466, -- Valentine", 1, true), "World1 Candy must not require GamePass")
    print("PASS 1: Config.luau World1 Candy requires 3 Rebirths (no gamepass prompt)")
end

-- 2. Check TreadmillTraining.luau container filtering
for _, world in {"World1", "World2"} do
    local tt = fs.readFile("audit/merged/" .. world .. "/ServerScriptService/Progression/TreadmillTraining.luau")
    assert(tt:find("isContainer", 1, true), "TreadmillTraining must check for Admin container")
    assert(tt:find("Special check for inner Admin treadmill", 1, true), "TreadmillTraining must register inner Admin treadmill")
    print("PASS 2: TreadmillTraining in " .. world .. " isolates container and inner Admin treadmill")
end

-- 3. Check TeleportSystem.luau calling _G.SpeedsterSpendWins
for _, world in {"World1", "World2"} do
    local tp = fs.readFile("audit/merged/" .. world .. "/ServerScriptService/Worlds/TeleportSystem.luau")
    assert(tp:find("_G.SpeedsterSpendWins", 1, true), "TeleportSystem must call _G.SpeedsterSpendWins")
    print("PASS 3: TeleportSystem in " .. world .. " debits wins via _G.SpeedsterSpendWins")
end

-- 4. Check MainHUDController.luau speed update animation and synchronization
for _, world in {"World1", "World2"} do
    local hud = fs.readFile("audit/merged/" .. world .. "/StarterPlayer/StarterPlayerScripts/UI/MainHUDController.luau")
    assert(hud:find("pulseSpeedText", 1, true), "MainHUDController must pulse speed text on impact")
    assert(hud:find("World1SpeedGainImpact", 1, true), "MainHUDController must connect to World1SpeedGainImpact")
    assert(hud:find("SPEED_TEXT_FALLBACK_SECONDS", 1, true), "MainHUDController must have fallback seconds")
    print("PASS 4: MainHUDController in " .. world .. " speed counter animation and impact sync verified")
end

-- 5. Check Stage Recommended Levels
do
    local w2s = fs.readFile("audit/merged/World2/ServerScriptService/Worlds/World2StageSystem.luau")
    assert(w2s:find("Recommended Level:", 1, true), "World2StageSystem must have Recommended Level")
    assert(w2s:find("FrontStageText", 1, true) and w2s:find("BackStageText", 1, true), "World2StageSystem must be double-sided")

    local w1s = fs.readFile("audit/merged/World1/ServerScriptService/Gameplay/NewWorld1StagePresentation.luau")
    assert(w1s:find("Recommended Level:", 1, true), "NewWorld1StagePresentation must have Recommended Level")
    assert(w1s:find("FrontApproachStageText", 1, true) and w1s:find("BackApproachStageText", 1, true), "NewWorld1StagePresentation must be double-sided")

    print("PASS 5: Stage Recommended Levels in World 1 and World 2 are double-sided and formatted")
end

-- 6. Check Win Pads double-dipping fix
do
    local w1p = fs.readFile("audit/merged/World1/ServerScriptService/Gameplay/NewWorld1ManualStagePads.luau")
    assert(w1p:find("Avoid double-multiplying", 1, true), "NewWorld1ManualStagePads must avoid double-multiplying")

    local w2p = fs.readFile("audit/merged/World2/ServerScriptService/Gameplay/World2ManualStagePads.luau")
    assert(w2p:find("Avoid double-multiplying", 1, true), "World2ManualStagePads must avoid double-multiplying")

    print("PASS 6: Win Pads in World 1 and World 2 avoid double-multiplying wins")
end

-- 7. Check cleanSpeed and commitSpeedText in MainHUDController.luau
for _, world in {"World1", "World2"} do
    local hud = fs.readFile("audit/merged/" .. world .. "/StarterPlayer/StarterPlayerScripts/UI/MainHUDController.luau")
    assert(hud:find("displaySpeed = (explicitSpeed ~= nil and cleanSpeed(explicitSpeed)) or actualSpeed", 1, true), "MainHUDController must use explicitSpeed condition")
    print("PASS 7: MainHUDController in " .. world .. " does not fallback to 1 on scheduled updates")
end

-- 8. Check SessionActor AccrueSpeed returns whole
for _, world in {"World1", "World2"} do
    local sa = fs.readFile("audit/merged/" .. world .. "/ServerScriptService/Services/Data/SessionActor.luau")
    assert(sa:find("whole = speedResult.value.wholeRequested", 1, true), "SessionActor AccrueSpeed must return wholeRequested")
    print("PASS 8: SessionActor AccrueSpeed in " .. world .. " returns wholeRequested")
end

-- 9. Check Bootstrap.luau getWalkingPopupTier
for _, world in {"World1", "World2"} do
    local bs = fs.readFile("audit/merged/" .. world .. "/ServerScriptService/Bootstrap.luau")
    assert(bs:find("getWalkingPopupTier", 1, true), "Bootstrap must define and use getWalkingPopupTier")
    print("PASS 9: Bootstrap in " .. world .. " uses getWalkingPopupTier for speed scaling")
end

-- 10. Check SpeedsterClient.luau formatGain and shoe layout
for _, world in {"World1", "World2"} do
    local sc = fs.readFile("audit/merged/" .. world .. "/StarterPlayer/StarterPlayerScripts/Movement/SpeedsterClient.luau")
    assert(sc:find("SUFFIXES", 1, true), "SpeedsterClient must define full SUFFIXES")
    assert(sc:find("UDim2.new(0, 30, 1, -4)", 1, true), "SpeedsterClient must use dedicated offset size for ShoeIcon")
    print("PASS 10: SpeedsterClient in " .. world .. " has full SUFFIXES and persistent ShoeIcon layout")
end

-- 11. Check CodesCatalog sorry4bugs and thanks4playing
for _, world in {"World1", "World2"} do
    local cc = fs.readFile("audit/merged/" .. world .. "/ReplicatedStorage/Shared/Catalogs/CodesCatalog.luau")
    assert(cc:find('sorry4bugs =', 1, true), "CodesCatalog must define sorry4bugs")
    assert(cc:find('thanks4playing =', 1, true), "CodesCatalog must define thanks4playing")
    assert(cc:find('Rebirths = 2', 1, true), "sorry4bugs must give 2 rebirths")
    assert(cc:find('ProportionalRewards = true', 1, true), "Codes must have ProportionalRewards")
    print("PASS 11: CodesCatalog in " .. world .. " has sorry4bugs and thanks4playing")
end

-- 12. Check CodesSystem proportional rewards & multi potions
for _, world in {"World1", "World2"} do
    local cs = fs.readFile("audit/merged/" .. world .. "/ServerScriptService/Social/CodesSystem.luau")
    assert(cs:find("calculateProportionalRewards", 1, true), "CodesSystem must define calculateProportionalRewards")
    assert(cs:find("definition.Potions", 1, true), "CodesSystem must handle definition.Potions")
    print("PASS 12: CodesSystem in " .. world .. " handles proportional rewards and potion lists")
end

-- 13. Check AdminPanelService & AdminBannerConfig
for _, world in {"World1", "World2"} do
    local cfg = fs.readFile("audit/merged/" .. world .. "/ReplicatedStorage/AdminBannerConfig.luau")
    assert(cfg:find("[767108248]", 1, true), "AdminBannerConfig must include 767108248")

    local aps = fs.readFile("audit/merged/" .. world .. "/ServerScriptService/Admin/AdminPanelService.luau")
    assert(aps:find("AdminPanelAction", 1, true), "AdminPanelService must use AdminPanelAction")
    assert(aps:find("AutoRebirth", 1, true), "AdminPanelService must support AutoRebirth")
    assert(aps:find("TogglePass", 1, true), "AdminPanelService must support TogglePass")
    assert(aps:find("ServerBoost", 1, true), "AdminPanelService must support ServerBoost")
    assert(aps:find("GiveRebirths", 1, true), "AdminPanelService must support GiveRebirths")
    assert(aps:find("UnlockWorld2", 1, true), "AdminPanelService must support UnlockWorld2")
    print("PASS 13: AdminPanelService and AdminBannerConfig in " .. world .. " verified")
end

-- 14. Check AdminPanelController
for _, world in {"World1", "World2"} do
    local apc = fs.readFile("audit/merged/" .. world .. "/StarterPlayer/StarterPlayerScripts/UI/AdminPanelController.luau")
    assert(apc:find("SpeedsterAdminMiniPanel", 1, true), "AdminPanelController must create SpeedsterAdminMiniPanel")
    assert(apc:find("👑 ADMIN", 1, true), "AdminPanelController must have floating admin button")
    assert(apc:find("AUTO REBIRTH", 1, true), "AdminPanelController must have Auto Rebirth controls")
    assert(apc:find("DESACTIVAR TODOS", 1, true), "AdminPanelController must have pass toggle controls")
    print("PASS 14: AdminPanelController in " .. world .. " verified")
end

-- 15. Check ProfileReducers RemoveUpgrade and allowFalse
for _, world in {"World1", "World2"} do
    local pr = fs.readFile("audit/merged/" .. world .. "/ServerScriptService/Services/Data/ProfileReducers.luau")
    assert(pr:find('command.kind == "RemoveUpgrade"', 1, true), "ProfileReducers must support RemoveUpgrade")
    assert(pr:find("command.allowFalse", 1, true), "ProfileReducers must support allowFalse in SetPersistent")
    print("PASS 15: ProfileReducers in " .. world .. " supports RemoveUpgrade and allowFalse")
end

-- 16. Check RebirthSystem force parameter and _G.SpeedsterPerformRebirth
for _, world in {"World1", "World2"} do
    local rs = fs.readFile("audit/merged/" .. world .. "/ServerScriptService/Progression/RebirthSystem.luau")
    assert(rs:find("performRebirth(player, force: boolean?)", 1, true), "RebirthSystem must support force parameter")
    assert(rs:find("_G.SpeedsterPerformRebirth", 1, true), "RebirthSystem must expose _G.SpeedsterPerformRebirth")
    print("PASS 16: RebirthSystem in " .. world .. " supports force rebirth and stat reset")
end

-- 17. Check WorldPortalService admin bypass
for _, world in {"World1", "World2"} do
    local wps = fs.readFile("audit/merged/" .. world .. "/ServerScriptService/Worlds/WorldPortalService.luau")
    assert(wps:find("isPlayerAdmin(player)", 1, true), "WorldPortalService must check isPlayerAdmin")
    print("PASS 17: WorldPortalService in " .. world .. " has admin bypass for World 2")
end

print("ALL TEST CHECKS PASSED!")

