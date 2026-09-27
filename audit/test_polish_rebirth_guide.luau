-- audit/test_polish_rebirth_guide.luau  (2026-09-22 polish pass, point 3)
-- "The Rebirth tutorial does not show reliably." The rebirth guide used to wait while
-- AuraGuidePending was true, and that was true for the whole first-time tutorial (re-offered on
-- every join until the first Win pad) plus 180 s: a runner who reached Level 5 before the pad
-- never met it in a short session. Now, once the runner is eligible (0 rebirths, Level >= the
-- first requirement, never seen):
--   * the first-time tutorial holds it for all its steps (2026-09-24: it used to release it in
--     Step 2, ~20 s after the first treadmill, where a rebirth reset the runner before the obby);
--   * the aura guide holds it only while it is really OWED (pad claimed, aura not done or
--     dismissed), and then for at most 15 s after the runner became eligible;
--   * an open guide still holds it until that guide closes.
-- Runs the REAL code on one fake clock and one fake player: UI/RebirthController's getters, gate
-- and loop, and UI/FirstTimeTutorial's AuraGuidePending publishing, aura loop and tutorial sync
-- (extracted from the sources, the real Shared/TutorialFlow). Shared/TutorialGuide is a stub that
-- opens/closes like the real one (GuidedTutorialOpen); its Rebirth mode is covered in
-- audit/test_i18n_rebirth_guide.
--   lune run audit/test_polish_rebirth_guide.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local TutorialFlow = require("../src/common/ReplicatedStorage/Shared/TutorialFlow")

local REBIRTH = "src/common/StarterPlayer/StarterPlayerScripts/UI/RebirthController.client.luau"
local FIRST = "src/common/StarterPlayer/StarterPlayerScripts/UI/FirstTimeTutorial.client.luau"

local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end
local function read(path)
	return (fs.readFile(path):gsub("\r\n", "\n"))
end
local function between(source, first, last, message)
	local a = string.find(source, first, 1, true)
	assert(a, message .. ": start not found")
	local b = string.find(source, last, a + #first, true)
	assert(b, message .. ": end not found")
	return string.sub(source, a, b - 1)
end

for _, path in { REBIRTH, FIRST } do
	local ok, problem = pcall(luau.compile, fs.readFile(path))
	assert(ok, "SYNTAX " .. path .. ": " .. tostring(problem))
end
pass("RebirthController and FirstTimeTutorial compile")

local rebirthSource = read(REBIRTH)
local firstSource = read(FIRST)
local GETTERS = between(rebirthSource, "local function getAuthoritativeLevel()", "local updateProgress", "getters")
local GATE_AND_LOOP = string.sub(rebirthSource, (assert(string.find(rebirthSource, "-- rebirthGuideGate\n", 1, true), "gate marker")))
assert(string.find(GATE_AND_LOOP, "-- end rebirthGuideGate", 1, true), "gate end marker")
assert(string.find(GATE_AND_LOOP, 'Start(player, nil, "Rebirth")', 1, true), "the loop starts mode Rebirth")
assert(string.find(GATE_AND_LOOP, "REBIRTH_GUIDE_AURA_GRACE_SECONDS = 15", 1, true), "a 15 s aura grace")
-- FirstTimeTutorial: wantsAuraGuide .. syncTutorialState, the tutorial-state signals and the pad signal.
local FIRST_CORE = between(firstSource, "local TutorialFlow = require(", "local beginReviewStep", "aura core")
local FIRST_SIGNALS = between(firstSource, 'player:GetAttributeChangedSignal("FirstTimeTutorialActive"):Connect(function()',
	'player:GetAttributeChangedSignal("FirstTimeTutorialTransitionSerial")', "tutorial signals")
local FIRST_PAD = between(firstSource, 'player:GetAttributeChangedSignal("LastCompletedSafeZone"):Connect(function()',
	"script.Destroying", "pad signal")

----------------------------------------------------------------------
-- The fake world: clock, scheduler, player, HUD, guide
----------------------------------------------------------------------
local function newWorld(attributes)
	local world = { now = 0, tasks = {}, starts = {}, openMode = nil, failAura = false }
	local attrs = table.clone(attributes)
	local signals = {}
	local function fire(name)
		for _, fn in signals[name] or {} do fn() end
	end
	local humanoid = { Health = 100 }
	local character = {
		FindFirstChildOfClass = function(_, class) return if class == "Humanoid" then humanoid else nil end,
		FindFirstChild = function(_, name) return if name == "HumanoidRootPart" then {} else nil end,
	}
	local sidebar = { Visible = true }
	local hud = { Enabled = true, FindFirstChild = function(_, name) return if name == "LeftSideBar" then sidebar else nil end }
	local playerGui = { FindFirstChild = function(_, name) return if name == "Mainhud" then hud else nil end }
	local player
	player = {
		Parent = true,
		Character = character,
		GetAttribute = function(_, name) return attrs[name] end,
		SetAttribute = function(_, name, value)
			if attrs[name] ~= value then
				attrs[name] = value
				fire(name)
			end
		end,
		GetAttributeChangedSignal = function(_, name)
			return { Connect = function(_, fn)
				signals[name] = signals[name] or {}
				table.insert(signals[name], fn)
				return { Disconnect = function() end }
			end }
		end,
		FindFirstChild = function() return nil end,
		FindFirstChildOfClass = function(_, class) return if class == "PlayerGui" then playerGui else nil end,
	}
	world.player, world.attrs = player, attrs

	-- Scheduler on the fake clock.
	local function schedule(at, co, ...)
		table.insert(world.tasks, { at = at, co = co, args = table.pack(...) })
	end
	local function resume(co, ...)
		local ok, problem = coroutine.resume(co, ...)
		assert(ok, tostring(problem))
	end
	local task = {
		spawn = function(fn, ...)
			local co = coroutine.create(fn)
			resume(co, ...)
		end,
		wait = function(seconds)
			schedule(world.now + (seconds or 0.03), coroutine.running())
			return coroutine.yield()
		end,
		delay = function(seconds, fn, ...)
			schedule(world.now + (seconds or 0), coroutine.create(fn), ...)
		end,
		defer = function(fn, ...)
			schedule(world.now, coroutine.create(fn), ...)
		end,
	}
	function world.advance(seconds)
		local stop = world.now + seconds
		while true do
			local nextIndex, nextAt = nil, math.huge
			for index, entry in world.tasks do
				if entry.at < nextAt then nextIndex, nextAt = index, entry.at end
			end
			if not nextIndex or nextAt > stop then break end
			local entry = table.remove(world.tasks, nextIndex)
			world.now = math.max(world.now, entry.at)
			resume(entry.co, table.unpack(entry.args, 1, entry.args.n))
		end
		world.now = stop
	end

	-- Shared/TutorialGuide stub: opens like the real one (GuidedTutorialOpen), one at a time.
	local guide = {
		Start = function(p, _onComplete, mode)
			assert(p == player, "Start for the local player")
			local kind = mode or "Backpack"
			if kind == "Backpack" and world.failAura then return false end
			if world.openMode then p:SetAttribute("GuidedTutorialOpen", false) end
			world.openMode = kind
			table.insert(world.starts, { mode = kind, at = world.now })
			p:SetAttribute("GuidedTutorialOpen", true)
			return true
		end,
	}
	function world.close(seenKey)
		world.openMode = nil
		if seenKey then player:SetAttribute(seenKey, true) end
		player:SetAttribute("GuidedTutorialOpen", false)
	end
	function world.firstStart(mode)
		for _, start in world.starts do
			if start.mode == mode then return start end
		end
		return nil
	end
	local Shared = {
		TutorialGuide = "TutorialGuide",
		WaitForChild = function(_, name) return name end,
	}
	local function fakeRequire(name)
		if name == "TutorialFlow" then return TutorialFlow end
		assert(name == "TutorialGuide", "unexpected require " .. tostring(name))
		return guide
	end
	local common = {
		player = player, playerGui = playerGui, tonumber = tonumber, math = math, table = table,
		task = task, os = { clock = function() return world.now end },
		require = fakeRequire, ReplicatedStorage = { Shared = Shared }, print = function() end,
	}

	-- UI/FirstTimeTutorial (non-forced build, new World 1: the first Win pad is Stage 1).
	local firstEnv = table.clone(common)
	firstEnv.FORCE_TUTORIAL_FOR_EVERYONE = false
	firstEnv.IS_NEW_WORLD1 = true
	firstEnv.displayedStep = 0
	firstEnv.reviewActive = false
	firstEnv.reviewStep = 0
	firstEnv.playCompleteSound = function() end
	for _, name in { "setBeamVisible", "resolveTarget", "refreshBeamVisual", "destroyBeamVisual" } do
		firstEnv[name] = function() end
	end
	luau.load(FIRST_CORE .. "\n" .. FIRST_SIGNALS .. "\n" .. FIRST_PAD .. "\nsyncTutorialState()", { environment = firstEnv })()
	world.firstEnv = firstEnv

	-- UI/RebirthController: the real getters, gate and loop.
	local rebirthEnv = table.clone(common)
	rebirthEnv.currentData = { Rebirths = 0, CurrentLevel = 1, RequiredLevel = 5 }
	luau.load(GETTERS .. "\n" .. GATE_AND_LOOP, { environment = rebirthEnv })()
	return world
end

-- A new runner who can rebirth now (Level 5 of 5, 0 rebirths, data in).
local ELIGIBLE = { DataLoaded = true, Level = 5, NextRebirthLevelRequired = 5, Rebirths = 0, LastCompletedSafeZone = 0 }
local function with(extra)
	local attrs = table.clone(ELIGIBLE)
	for key, value in extra do attrs[key] = value end
	return attrs
end

----------------------------------------------------------------------
-- 1. First-time tutorial Step 2, Win pad unclaimed: held (2026-09-24). Level 5 comes ~20 s after
--    the first treadmill, mid Step 2; a rebirth there reset the runner to 8 studs/s before the
--    first obby and dimmed the screen over the tutorial's card.
----------------------------------------------------------------------
do
	local world = newWorld(with({ FirstTimeTutorialActive = true, FirstTimeTutorialStep = 2 }))
	assert(world.attrs.AuraGuidePending == false, "an unclaimed pad is not an owed aura guide")
	world.advance(60)
	assert(world.firstStart("Rebirth") == nil, "REGRESSION: the rebirth guide opened during Step 2 (claim your wins)")
	assert(#world.starts == 0, "no guide at all during the first-time tutorial")
	-- Step 2 times out without the pad: the tutorial is over, nothing is owed, rebirth goes.
	world.player:SetAttribute("FirstTimeTutorialStep", 0)
	world.player:SetAttribute("FirstTimeTutorialActive", false)
	world.advance(3.1)
	local start = world.firstStart("Rebirth")
	assert(start and start.at > 60 and start.at <= 63.1, "the rebirth guide follows the tutorial's end within ~3 s")
	assert(#world.starts == 1, "offered once")
	world.advance(30)
	assert(#world.starts == 1, "still offered once while it is up")
	pass("Step 2, pad unclaimed, Level 5: held for the whole tutorial, then offered within ~3 s of its end")
end

----------------------------------------------------------------------
-- 2. Step 1, the pause and Step 2 all hold it; the tutorial's end releases it
----------------------------------------------------------------------
do
	local world = newWorld(with({ FirstTimeTutorialActive = true, FirstTimeTutorialStep = 1 }))
	world.advance(90)
	assert(#world.starts == 0, "no guide during Step 1")
	world.player:SetAttribute("FirstTimeTutorialStep", 0) -- the server's pause between the steps
	world.advance(3)
	assert(#world.starts == 0, "no guide in the pause before Step 2")
	world.player:SetAttribute("FirstTimeTutorialStep", 2)
	world.advance(20)
	assert(#world.starts == 0, "no guide in Step 2")
	world.player:SetAttribute("FirstTimeTutorialStep", 0)
	world.player:SetAttribute("FirstTimeTutorialActive", false)
	world.advance(3.1)
	local start = world.firstStart("Rebirth")
	assert(start and start.at >= 113 and start.at <= 116.1, "the rebirth guide follows the tutorial's end within ~3 s")
	pass("Step 1, the pause and Step 2 hold the rebirth guide; it starts ~3 s after the tutorial ends")
end

----------------------------------------------------------------------
-- 3. Tutorial over, pad still unclaimed (the old 180 s "coming" hold): rebirth at once
----------------------------------------------------------------------
do
	local world = newWorld(with({ FirstTimeTutorialActive = true, FirstTimeTutorialStep = 1 }))
	world.player:SetAttribute("FirstTimeTutorialStep", 0)
	world.player:SetAttribute("FirstTimeTutorialActive", false) -- Step 2 timed out without the pad
	assert(world.attrs.AuraGuidePending == false, "the aura guide is only coming, not owed")
	world.advance(3.1)
	assert(world.firstStart("Rebirth"), "REGRESSION: the rebirth guide waited for an aura guide that is only coming")
	pass("tutorial timed out with the pad unclaimed: AuraGuidePending false, the rebirth guide starts within ~3 s")
end

----------------------------------------------------------------------
-- 4. Aura owed: the aura guide goes first, the rebirth guide after it closes
----------------------------------------------------------------------
do
	local world = newWorld(with({ FirstTimeTutorialActive = true, FirstTimeTutorialStep = 2, Level = 3 }))
	world.advance(1)
	-- The pad claim ends Step 2 (server) and makes the aura guide owed.
	world.player:SetAttribute("LastCompletedSafeZone", 1)
	world.player:SetAttribute("FirstTimeTutorialStep", 0)
	world.player:SetAttribute("FirstTimeTutorialActive", false)
	assert(world.attrs.AuraGuidePending == true, "pad claimed: the aura guide is owed")
	-- The runner reaches the rebirth level at the same moment.
	world.player:SetAttribute("Level", 5)
	world.advance(1.5)
	local aura = world.firstStart("Backpack")
	assert(aura and aura.at <= 2.5, "the owed aura guide opens first")
	world.advance(25)
	assert(world.firstStart("Rebirth") == nil, "the rebirth guide never interrupts the open aura guide")
	world.close("SpeedsterTutorialEquipDone") -- aura done (equipped) at t = 27.5
	assert(world.attrs.AuraGuidePending == false, "done: no longer owed")
	world.advance(3.1)
	local rebirth = world.firstStart("Rebirth")
	assert(rebirth and rebirth.at > 27.5 and rebirth.at <= 30.6, "the rebirth guide follows the aura guide within ~3 s")
	assert(#world.starts == 2, "aura, then rebirth, nothing else")
	pass("aura owed: the aura guide opens first, the rebirth guide ~3 s after it closes (never on top of it)")
end

----------------------------------------------------------------------
-- 5. Aura owed but it cannot open: the rebirth guide waits at most the 15 s grace
----------------------------------------------------------------------
do
	local world = newWorld(with({ FirstTimeTutorialActive = true, FirstTimeTutorialStep = 2, Level = 2 }))
	world.failAura = true -- e.g. the Backpack GUI is missing: TutorialGuide.Start refuses the aura guide
	world.player:SetAttribute("LastCompletedSafeZone", 1)
	world.player:SetAttribute("FirstTimeTutorialStep", 0)
	world.player:SetAttribute("FirstTimeTutorialActive", false)
	assert(world.attrs.AuraGuidePending == true, "owed")
	world.advance(30)
	assert(#world.starts == 0, "not eligible yet (Level 2): nothing")
	world.player:SetAttribute("Level", 5) -- eligible at t = 30: the grace counts from here
	world.advance(14.5)
	assert(world.firstStart("Rebirth") == nil, "inside the 15 s grace the owed aura guide keeps its turn")
	world.advance(4.5)
	local rebirth = world.firstStart("Rebirth")
	assert(rebirth, "REGRESSION: an owed aura guide held the rebirth guide past the grace")
	-- 15 s grace from the first 0.75 s poll that saw the runner eligible, then the 2 s quiet window
	-- (polled every 0.75 s): at most 30 + 0.75 + 15 + 2.75.
	assert(rebirth.at >= 45 and rebirth.at <= 48.6, "rebirth at " .. rebirth.at .. " s: the grace (15 s from eligibility) + the 2 s quiet window")
	assert(world.attrs.AuraGuidePending == true, "the aura guide is still owed (it follows the rebirth guide)")
	world.close("RebirthTutorialSeen")
	world.failAura = false
	world.advance(2)
	assert(world.firstStart("Backpack"), "the aura guide opens once the rebirth guide closed")
	pass("aura owed but not opening: the rebirth guide waits the 15 s grace from eligibility (not from the join), then goes; the aura guide after it")
end

----------------------------------------------------------------------
-- 6. Veterans, already seen, not eligible: never
----------------------------------------------------------------------
do
	for _, case in {
		{ with({ Rebirths = 1 }), "a runner with a rebirth" },
		{ with({ RebirthTutorialSeen = true }), "guide already seen" },
		{ with({ Level = 4 }), "Level 4 of 5" },
		{ with({ DataLoaded = false }), "data not loaded" },
		{ with({ Rebirths = 2, FirstTimeTutorialActive = true, FirstTimeTutorialStep = 2 }), "a rebirthed runner in the tutorial" },
	} do
		local world = newWorld(case[1])
		world.advance(120)
		assert(world.firstStart("Rebirth") == nil, "the rebirth guide must never show: " .. case[2])
	end
	-- Not eligible, then eligible: from that moment.
	local world = newWorld(with({ Level = 4 }))
	world.advance(20)
	assert(#world.starts == 0, "Level 4: nothing")
	world.player:SetAttribute("Level", 5)
	world.advance(3.1)
	local start = world.firstStart("Rebirth")
	assert(start and start.at > 20 and start.at <= 23.1, "reaching Level 5 offers it within ~3 s")
	pass("never for veterans, a seen guide, Level < requirement or data not loaded; offered ~3 s after reaching the level")
end

----------------------------------------------------------------------
-- 7. Eligible while another guide is open: after it closes
----------------------------------------------------------------------
do
	local world = newWorld(with({ GuidedTutorialOpen = true }))
	world.openMode = "Evolve"
	world.advance(40)
	assert(world.firstStart("Rebirth") == nil, "never on top of another guide")
	world.close("EvolveTutorialSeen")
	world.advance(3.1)
	local start = world.firstStart("Rebirth")
	assert(start and start.at > 40 and start.at <= 43.1, "starts ~3 s after the other guide closed")
	-- Also with an owed aura guide whose grace ran out while the other guide was up: the aura
	-- loop is quicker (1 s) than the rebirth quiet window, so the aura guide takes the free slot,
	-- then the rebirth guide follows it.
	local w2 = newWorld(with({ FirstTimeTutorialActive = true, FirstTimeTutorialStep = 2, GuidedTutorialOpen = true }))
	w2.openMode = "Evolve"
	w2.player:SetAttribute("LastCompletedSafeZone", 1)
	w2.player:SetAttribute("FirstTimeTutorialStep", 0)
	w2.player:SetAttribute("FirstTimeTutorialActive", false)
	w2.advance(40)
	assert(#w2.starts == 0, "nothing while the Evolve guide is up")
	w2.close("EvolveTutorialSeen")
	w2.advance(1.5)
	assert(w2.firstStart("Backpack") and w2.firstStart("Rebirth") == nil, "the aura guide takes the free slot first")
	w2.close("BackpackTutorialSeen") -- Skip
	w2.advance(3.1)
	assert(w2.firstStart("Rebirth"), "then the rebirth guide")
	pass("eligible while another guide is open: the rebirth guide waits and starts ~3 s after it closes (an owed aura guide first)")
end

print(("ALL PASSED (%d checks)"):format(passed))
