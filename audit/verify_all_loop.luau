-- Comprehensive test loop runner to verify all systems, syntax, and logic 12 times consecutively.
local fs = require('@lune/fs')
local luau = require('@lune/luau')
local serde = require('@lune/serde')
local process = require('@lune/process')

local TOTAL_ITERATIONS = 12

local function log(msg)
    print(string.format("[%s] %s", os.date("%X"), msg))
end

log("Starting comprehensive multi-iteration verification suite (Target: " .. TOTAL_ITERATIONS .. " iterations)")

local function walkDir(path, list)
    list = list or {}
    for _, item in ipairs(fs.readDir(path)) do
        local full = path .. "/" .. item
        if fs.isDir(full) then
            walkDir(full, list)
        elseif item:sub(-5) == ".luau" then
            table.insert(list, full)
        end
    end
    return list
end

local allSources = {}
walkDir("src/common", allSources)
walkDir("src/worlds", allSources)

log(string.format("Discovered %d canonical source files in src/", #allSources))

local testCommands = {
    { cmd = "audit/test_pad_claim_contract.luau", desc = "Pad Claim Contract (World 1 & 2)" },
    { cmd = "audit/test_pad_volumes.luau", desc = "Pad Volume Compatibility Entrypoint" },
    { cmd = "audit/test_stage_transactions.luau", args = {"World1"}, desc = "Stage Transactions World 1 (2PC, Refunds, Teleport)" },
    { cmd = "audit/test_stage_transactions.luau", args = {"World2"}, desc = "Stage Transactions World 2 (2PC, Refunds, Teleport)" },
    { cmd = "audit/test_hazard_contact_review.luau", desc = "Hazard Contact Review (Presser, Hammer, Tree)" },
    { cmd = "audit/test_hazard_history.luau", desc = "Hazard History Discontinuity Reset" },
    { cmd = "audit/persistence/test_geko_flight.luau", desc = "Geko Flight & Giveaway Suite" },
    { cmd = "audit/test_stamina_replication.luau", desc = "Stamina Replication at 4Hz" },
    { cmd = "audit/test_flight_start.luau", desc = "FlightService Start & Side-Effect Free Require" },
    { cmd = "audit/persistence/test_regression.luau", args = {"World1"}, desc = "Regression & Persistence World 1" },
    { cmd = "audit/persistence/test_regression.luau", args = {"World2"}, desc = "Regression & Persistence World 2" },
    { cmd = "audit/test_new_persistence.luau", desc = "New Persistence (Pending Trips & Dynamic Codes)" },
    { cmd = "audit/test_bridge_wiring.luau", desc = "Bridge Wiring & Attribute Commits" },
    { cmd = "audit/test_announcements.luau", desc = "Global Announcements (Filter Fail-Closed, RichText Escape)" },
    { cmd = "audit/test_gift_identity.luau", desc = "Gift Identity & Idempotent Ledger" },
    { cmd = "audit/test_gift_cancel.luau", desc = "Gift Prompt Cancellation Lifecycle" },
    { cmd = "audit/test_guards.luau", desc = "RemoteGuard, Settings & Save State Validation" },
    { cmd = "audit/test_confetti.luau", desc = "Confetti Cap (240 limit, 10Hz throttle, server owned)" },
    { cmd = "audit/test_potion_sync.luau", desc = "Potion & Multiplier Synchronization Suite" },
    { cmd = "audit/test_ragdoll_and_admin_panel.luau", desc = "Ragdoll Respawn & Admin Panel Suite" },
    { cmd = "audit/test_revive_regression.luau", desc = "Revive Prompt, Purchase & Respawn Regression Suite" },
    { cmd = "audit/test_quests_afk_persistence.luau", desc = "Quests & AFK Rewards Persistence Suite" },
    { cmd = "audit/test_runtime_panels.luau", desc = "Runtime Panels (Admin, Quests, AFK, UI Layouts) Suite" },
    { cmd = "audit/test_sprint_shatter.luau", desc = "Sprint GlassShatter & Camera Shake Suite" },
    { cmd = "audit/test_sonic_protection.luau", desc = "Sonic EXE Boss Hazard Protection Suite" },
    { cmd = "audit/world2_pad_prompt_probe.luau", desc = "World 2 Pad Prompt & Standing Resumption Probe" },
    { cmd = "audit/test_ragdoll_flight_and_x2_pad.luau", desc = "Ragdoll Flight Prohibition & x2 Pad Product Suite" },
    { cmd = "audit/test_authored_auras_and_shatter.luau", desc = "Authored Auras & Sonic Barrier Glass Shatter Suite" },
    { cmd = "audit/test_flight_balance.luau", desc = "Flight Airtime Budget & Hold-To-Fly Input" },
    { cmd = "audit/test_update3_audit.luau", desc = "Update 3 Audit: Skins, Shop, Ladder, Studio Gating" },
    { cmd = "audit/test_gift_panel.luau", desc = "Gift List Canvas, Thumbnails & Eligibility" },
    { cmd = "audit/test_tree_slam_motion.luau", desc = "World 2 Tree Slam Rendered Client-Side" },
    { cmd = "audit/test_music_playlist.luau", desc = "Background Music Playlist & Single Owner" },
    { cmd = "audit/test_onboarding_flow.luau", desc = "Update Log -> Daily Reward -> Starter Pack Offer" },
    { cmd = "audit/test_promo_codes.luau", desc = "Promo Codes Retired To BOOST Only" },
    { cmd = "audit/test_monetization_structure.luau", desc = "Wins SKU Boundary & Flight Stamina Cost" },
    { cmd = "audit/test_cosmetic_geometry.luau", desc = "Cosmetic Trail/Aura Authored Geometry" },
    { cmd = "audit/test_backpack_layout.luau", desc = "Backpack Trail/Aura Menu Layout" },
    { cmd = "audit/persistence/compile_merged.luau", desc = "Compile Merged Sources" },
    { cmd = "audit/build_core.luau", desc = "Core Build & Authored Graph Preservation" },
    { cmd = "audit/verify_rbxl_contents.luau", desc = "Shipped .rbxl Files Match src" },
}

local summary = {}

for iteration = 1, TOTAL_ITERATIONS do
    log(string.format("=== ITERATION %d of %d ===", iteration, TOTAL_ITERATIONS))
    
    -- 1. Check syntax compilation on every source in src/
    local syntaxErrors = 0
    for _, file in ipairs(allSources) do
        local content = fs.readFile(file)
        local ok, err = pcall(luau.compile, content)
        if not ok then
            error(string.format("[ITERATION %d] Syntax error in %s: %s", iteration, file, tostring(err)))
        end
    end
    
    -- 2. Run every test suite
    for idx, test in ipairs(testCommands) do
        print(string.format("  [%s] [%d/%d] %s", os.date("%X"), idx, #testCommands, test.desc))
        local args = { "run", test.cmd }
        if test.args then
            for _, a in ipairs(test.args) do
                table.insert(args, a)
            end
        end
        local res = process.exec("lune", args)
        if not res.ok or res.code ~= 0 then
            error(string.format("[ITERATION %d] FAILED %s (code %d):\n%s\n%s",
                iteration, test.desc, res.code, res.stdout or "", res.stderr or ""))
        end
    end
    
    table.insert(summary, string.format("Iteration %d: All %d sources compiled cleanly, all %d test suites PASSED with exit code 0",
        iteration, #allSources, #testCommands))
    log(string.format("Iteration %d: 100%% PASSED without errors or flakes.", iteration))
end

log("==================================================================")
log(string.format("VERIFICATION COMPLETE: %d of %d ITERATIONS PASSED PERFECTLY (100%% SUCCESS)", #summary, TOTAL_ITERATIONS))
for _, line in ipairs(summary) do
    print("  ✓ " .. line)
end
log("==================================================================")
