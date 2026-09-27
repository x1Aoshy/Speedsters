-- test_u4_race_client_static.luau (Update 4, race_client, 2026-09-25)
-- Source checks of the race client (PLAN §7.4 items 1-2, 6, 8 and the client-cost rule):
--   * every new client file compiles; no Workspace-wide GetDescendants; WaitForChild on the
--     race remotes always has a timeout;
--   * SpeedsterClient.setBoosting refuses a sprint while RaceActive (and lets go on entering),
--     its FOV loop takes RaceFovTarget; SonicBurstClient's SprintHeld listener and touch button
--     stand aside while RaceActive;
--   * InstantMovementController takes RaceLocalSpeed while RaceActive, 0 and no jumps while
--     RaceMovementLocked, and never bounces off a RaceArenaPart;
--   * RaceInputClient binds "RaceAction" (above SpeedsterClient's sprint) and connects its
--     Heartbeat only while RaceActive, unbinds / disconnects on the way out, restores the jump
--     on every exit path (GO, unlock, death, CharacterRemoving, the race's end), sends only
--     edges, the cumulative charge list and the final packet;
--   * at most 2 per-frame connections across the race client while racing (RaceInputClient's
--     Heartbeat + RaceHudController's RenderStepped), each disconnected outside races;
--   * RaceHudController hides the interface as "Race" keeping RaceHud, RaceResults, "TouchGui";
--   * RaceRequest "Join" sources are only the client ones (Hud, Invite, Results, Panel);
--   * LowPowerGraphics hides RaceDecorLowPower parts and calms the ORB;
--   * review fixes: sprint from GO, no stale race context, results decisions, words via RaceText.
--   * 2026-09-25 (owner): never a walk in a race (R15SpeedsterRun plays the fast run while
--     RaceActive; InstantMovementController runs down the track by itself under RaceAutoRun;
--     RaceInputClient feeds the model the same direction and waits at the racer's cruise, not a
--     jog); the charge is Shift (+ R2 and the touch button) and the HUD throbs while it is held;
--     the server takes the Flash NPC's { action = "Join", source = "Npc", category } payload.
--   * 2026-09-26 (owner's phone playtest): the results, the race panel and the sign-up are fitted
--     through RaceUiBuilder.FitWindow in their ScreenGui's room (top bar, notch), touch included.
-- Run: lune run audit/test_u4_race_client_static.luau   (from the project root)
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local ROOT = "src/common/StarterPlayer/StarterPlayerScripts/"
local FILES = {
	Input = ROOT .. "Race/RaceInputClient.client.luau",
	Hud = ROOT .. "UI/RaceHudController.client.luau",
	Lobby = ROOT .. "UI/RaceLobbyController.client.luau",
	Arena = ROOT .. "Gameplay/RaceArenaVisuals.client.luau",
}
local CHANGED = {
	Movement = ROOT .. "Movement/InstantMovementController.client.luau",
	Run = "src/common/StarterPlayer/StarterCharacterScripts/R15SpeedsterRun.client.luau",
	Server = "src/common/ServerScriptService/Gameplay/RaceServer.server.luau",
	Speedster = ROOT .. "Movement/SpeedsterClient.client.luau",
	Sonic = ROOT .. "Movement/SonicBurstClient.client.luau",
	LowPower = ROOT .. "Gameplay/LowPowerGraphics.client.luau",
}

local passed = 0
local function pass(text)
	passed += 1
	print("PASS " .. text)
end

local source = {}
for key, path in FILES do
	source[key] = fs.readFile(path)
end
for key, path in CHANGED do
	source[key] = fs.readFile(path)
end

-- The body of `local function name(` up to the first line that is exactly "end" at its indent.
local function functionBody(text, name)
	local start = string.find(text, "local function " .. name .. "%(")
	assert(start, "function " .. name .. " not found")
	local indent = string.match(string.sub(text, 1, start), "\n([\t ]*)$") or ""
	local finish = string.find(text, "\n" .. indent .. "end\n", start, true)
	assert(finish, "end of " .. name .. " not found")
	return string.sub(text, start, finish)
end

-- The block of `anchor` (plain) up to the first "\nend)" after it.
local function blockAfter(text, anchor)
	local start = string.find(text, anchor, 1, true)
	assert(start, "anchor not found: " .. anchor)
	local finish = string.find(text, "\nend)", start, true)
	assert(finish, "end of the block after " .. anchor)
	return string.sub(text, start, finish)
end

local function count(text, pattern)
	local n = 0
	for _ in string.gmatch(text, pattern) do
		n += 1
	end
	return n
end

-- 1. Compiles; no Workspace-wide scans; timeouts on the race remotes.
do
	for key, text in source do
		local ok, problem = pcall(luau.compile, text)
		assert(ok, key .. " does not compile: " .. tostring(problem))
	end
	for key in FILES do
		local text = source[key]
		assert(not string.find(text, "orkspace:GetDescendants()", 1, true), key .. ": a Workspace-wide GetDescendants")
		assert(not string.find(text, "BindToRenderStep", 1, true), key .. ": BindToRenderStep (per-frame work outside the budget)")
		-- The race remotes, the race's ScreenGuis and the arena come and go; Shared modules do not.
		for _, name in { "Remotes", "RaceRequest", "RaceSprint", "RaceChargeInput", "RaceEvent", "RaceLive", "FunnelReport",
			"RaceHud", "RaceGate", "RaceArena", "Mainhud", "Action" } do
			assert(not string.find(text, 'WaitForChild("' .. name .. '")', 1, true), key .. ": WaitForChild(\"" .. name .. "\") without a timeout")
		end
		assert(not string.find(text, 'Workspace:WaitForChild%(".-"%)'), key .. ": Workspace:WaitForChild without a timeout")
	end
	pass("the race client compiles; no Workspace-wide scans; every race remote waited for with a timeout")
end

-- 2. SpeedsterClient: no BoostState/SprintHeld while racing; FOV from RaceFovTarget.
do
	local setBoosting = functionBody(source.Speedster, "setBoosting")
	local guard = string.find(setBoosting, 'GetAttribute("RaceActive") == true then value = false', 1, true)
	local fire = string.find(setBoosting, "BoostState:FireServer", 1, true)
	assert(guard and fire and guard < fire, "setBoosting forces false while RaceActive, before BoostState is sent")
	assert(string.find(source.Speedster, 'GetAttributeChangedSignal("RaceActive")', 1, true), "a sprint held on entering a race lets go")
	local fov = blockAfter(source.Speedster, "RunService.RenderStepped:Connect(function(dt)")
	assert(string.find(fov, 'GetAttribute("RaceFovTarget")', 1, true) and string.find(fov, "CameraPunch.FovOffset()", 1, true),
		"the FOV loop takes RaceFovTarget and keeps CameraPunch")
	pass("SpeedsterClient: setBoosting refuses while RaceActive, lets go on entry, FOV loop reads RaceFovTarget")
end

-- 3. SonicBurstClient: the SprintHeld listener and the touch button stand aside while racing.
do
	local listener = blockAfter(source.Sonic, 'player:GetAttributeChangedSignal("SprintHeld"):Connect(function()')
	local guard = string.find(listener, 'GetAttribute("RaceActive") == true', 1, true)
	local start = string.find(listener, "startCharge()", 1, true)
	assert(guard and start and guard < start, "SprintHeld is ignored while RaceActive (before any charge starts)")
	assert(string.find(listener, "cancelCharge()", 1, true), "a charge running when the race starts is called off")
	assert(string.find(source.Sonic, 'cooldownEndsAt or player:GetAttribute("RaceActive") == true', 1, true), "the touch Burst button does nothing in a race")
	pass("SonicBurstClient: SprintHeld and the touch button ignored while RaceActive")
end

-- 4. InstantMovementController.
do
	local m = source.Movement
	local apply = functionBody(m, "applyMovement")
	assert(string.find(apply, 'GetAttribute("RaceLocalSpeed")', 1, true), "applyMovement reads RaceLocalSpeed")
	assert(string.find(apply, 'GetAttribute("RaceMovementLocked")', 1, true), "applyMovement reads RaceMovementLocked")
	assert(string.find(apply, 'GetAttribute("IsBoosting") == true and not raceActive', 1, true), "no sprint boost or sonic build-up in a race")
	local override = string.find(apply, "movementWalkSpeed = if raceLocked then 0", 1, true)
	local sonic = string.find(apply, "movementWalkSpeed *= sonicRatio", 1, true)
	local write = string.find(apply, "humanoid.WalkSpeed = movementWalkSpeed", 1, true)
	assert(override and sonic and write and sonic < override and override < write,
		"the race speed replaces the composed speed (after the sonic ratio, before WalkSpeed)")
	local locked = string.find(apply, "\n\tif raceLocked then\n", 1, true)
	assert(locked, "the locked branch")
	local lockedBlock = string.sub(apply, locked, (string.find(apply, "\n\tend\n", locked, true)))
	assert(string.find(lockedBlock, "humanoid.Jump = false", 1, true) and string.find(lockedBlock, "return", 1, true),
		"locked: no jump, no movement")
	local bounce = functionBody(m, "isExcludedBouncePart")
	assert(string.find(bounce, 'GetAttribute("RaceArenaPart") == true', 1, true), "arena parts never bounce")
	-- 2026-09-25 (owner: never walk): racing, no input runs down the track and the input steers.
	local auto = string.find(apply, 'GetAttribute("RaceAutoRun") == true', 1, true)
	local steer = string.find(apply, "direction = autoRunDirection(direction)", 1, true)
	local deadzone = string.find(apply, "local deadzone = ", 1, true)
	local firstUse = string.find(apply, "direction.Magnitude", 1, true)
	assert(auto and steer and deadzone and firstUse and auto < steer and steer < firstUse, "RaceAutoRun turns the input into the auto-run direction before any use")
	local helper = functionBody(m, "autoRunDirection")
	assert(string.find(helper, "raceMath.AutoRunDirection(direction.X, direction.Z)", 1, true), "the same direction as RaceMath.AutoRunDirection")
	assert(not string.find(helper, "WaitForChild", 1, true) and string.find(helper, "pcall(require", 1, true), "never waits on Heartbeat, never breaks movement")
	assert(string.find(m, "local RACE_FALLBACK_WALK_SPEED = 100", 1, true), "the fallback before the prediction writes is the base race cruise, not a walk")
	-- 2026-09-26 (owner: Sonic Dash speeds): ground adhesion while racing, never while jumping,
	-- RaceTrack required lazily under pcall, applied to the vertical speed every branch writes.
	local adhesion = functionBody(m, "raceGroundAdhesion")
	assert(string.find(adhesion, 'GetAttribute("RaceAutoRun") ~= true', 1, true) and string.find(adhesion, "raceJumping", 1, true)
		and string.find(adhesion, "raceTrack.AdhesionVelocity(", 1, true) and string.find(adhesion, "pcall(require", 1, true)
		and not string.find(adhesion, "WaitForChild", 1, true), "adhesion: racing only, not while jumping, lazy pcall require")
	local capAt = string.find(apply, "verticalVelocity = raceGroundAdhesion(verticalVelocity, currentVelocity, state, now)", 1, true)
	local firstWrite = string.find(apply, "root.AssemblyLinearVelocity =", 1, true)
	assert(capAt and firstWrite and capAt < firstWrite, "the cap comes before any velocity write")
	pass("InstantMovementController: RaceLocalSpeed while RaceActive, 0 and no jumps while locked, RaceArenaPart not bounced, auto-run under RaceAutoRun, ground adhesion")
end

-- 5. RaceInputClient: bound only while RaceActive, every exit restores the jump.
do
	local s = source.Input
	local bind = functionBody(s, "bindInputs")
	assert(string.find(bind, "BindActionAtPriority(ACTION", 1, true), "bindInputs binds RaceAction")
	assert(string.find(s, "Enum.ContextActionPriority.High.Value + 200", 1, true), "above SpeedsterClient's sprint (High + 100)")
	local unbind = functionBody(s, "unbindInputs")
	assert(string.find(unbind, "UnbindAction(ACTION)", 1, true), "unbindInputs unbinds")
	local activate = functionBody(s, "activate")
	assert(string.find(activate, "bindInputs()", 1, true) and string.find(activate, "RunService.Heartbeat:Connect", 1, true), "activate binds and connects")
	local deactivate = functionBody(s, "deactivate")
	assert(string.find(deactivate, "heartbeat:Disconnect()", 1, true) and string.find(deactivate, "unbindInputs()", 1, true)
		and string.find(deactivate, "endRace()", 1, true) and string.find(deactivate, "clearLocals()", 1, true), "deactivate undoes all of it")
	local refresh = functionBody(s, "refreshActive")
	assert(string.find(refresh, 'GetAttribute("RaceActive") == true', 1, true), "driven by RaceActive")
	assert(count(s, "BindActionAtPriority%(") == 1 and count(s, "Heartbeat:Connect") == 1, "one binding, one Heartbeat")
	-- The jump: zeroed only in bindable places, restored at GO, unlock, death, respawn, the end.
	assert(string.find(functionBody(s, "startModel"), "restoreJump()", 1, true), "GO restores the jump")
	assert(string.find(functionBody(s, "endRace"), "restoreJump()", 1, true), "the race's end restores the jump")
	assert(string.find(blockAfter(s, 'player:GetAttributeChangedSignal("RaceMovementLocked")'), "restoreJump()", 1, true), "unlock restores the jump")
	assert(string.find(blockAfter(s, "player.CharacterRemoving:Connect"), "restoreJump()", 1, true), "CharacterRemoving restores the jump")
	local died = string.find(s, "humanoid.Died:Connect", 1, true)
	assert(died and string.find(string.sub(s, died, died + 200), "restoreJump()", 1, true), "death restores the jump")
	-- The remotes: the sprint only on change, the charge list + the final at GO.
	assert(string.find(functionBody(s, "setSprint"), "if r.sprintSent ~= on then", 1, true), "RaceSprint only on edges")
	assert(string.find(functionBody(s, "startModel"), "sendCharge(true)", 1, true), "the final charge packet at GO")
	assert(string.find(functionBody(s, "recordEdge"), "CHARGE.MinPress", 1, true) and string.find(functionBody(s, "recordEdge"), "CHARGE.MaxEdges", 1, true),
		"edges clamped like the judge (MinPress apart, at most MaxEdges)")
	-- Local-only attributes it owns.
	for _, name in { "RaceLocalSpeed", "RaceChargeLocal", "RaceStaminaLocal", "RaceLocalSuper" } do
		assert(string.find(s, 'setLocal("' .. name .. '"', 1, true), "writes " .. name)
	end
	-- 2026-09-25 (final fix): a Space / A charge released after GO no longer leaves the sprint on.
	local action = functionBody(s, "onAction")
	local release = string.find(action, "(state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel) and holding[source]", 1, true)
	local chargeOnly = string.find(action, 'CHARGE_ONLY_KEYS[source] and m ~= "charge"', 1, true)
	local noMode = string.find(action, "if not m or UserInputService:GetFocusedTextBox()", 1, true)
	assert(release and chargeOnly and noMode and release < noMode and release < chargeOnly, "releases are recorded before the phase filters")
	local go = functionBody(s, "startModel")
	local drop = string.find(go, "holding.Space, holding.ButtonA = nil, nil", 1, true)
	local carry = string.find(go, "if pressed() then", 1, true)
	assert(drop and carry and drop < carry, "GO drops the Space / A charge before the held sprint carries over")
	pass("RaceInputClient: RaceAction and Heartbeat only while RaceActive; jump restored on GO/unlock/death/respawn/end; edges only; releases always recorded")
end

-- 6. Per-frame budget: at most 2 connections, each disconnected outside races.
do
	local total = 0
	for key in FILES do
		local text = source[key]
		local n = count(text, "RunService%.RenderStepped:Connect") + count(text, "RunService%.Heartbeat:Connect") + count(text, "RunService%.Stepped:Connect")
		total += n
	end
	assert(total <= 2, "per-frame connections in the race client: " .. total)
	local hud = source.Hud
	assert(count(hud, "RunService%.RenderStepped:Connect") == 1, "the HUD's one RenderStepped")
	assert(string.find(functionBody(hud, "hideHud"), "renderConnection:Disconnect()", 1, true), "the HUD's RenderStepped is disconnected when it hides")
	assert(string.find(functionBody(hud, "showHud"), "if not renderConnection then", 1, true), "never connected twice")
	assert(count(source.Lobby, "RunService") == 0 and count(source.Arena, "RunService") == 0, "the lobby and the arena visuals have no per-frame work")
	pass(("per-frame connections: %d (Heartbeat prediction + RenderStepped HUD), each disconnected"):format(total))
end

-- 7. The HUD hides the interface as "Race", keeping its own and TouchGui by name.
do
	local hud = source.Hud
	-- 2026-09-26 (owner): and the race's screen effects (Shared/RaceScreenFx).
	assert(string.find(hud, 'InterfaceHider.Hide(HIDER_OWNER, { hud, results, "TouchGui", "RaceScreenFx" })', 1, true), "Hide keeps RaceHud, RaceResults, TouchGui, RaceScreenFx")
	assert(string.find(hud, 'local HIDER_OWNER = "Race"', 1, true), "owner Race")
	assert(string.find(functionBody(hud, "hideHud"), "InterfaceHider.Show(HIDER_OWNER)", 1, true), "Show on the way out")
	pass("RaceHudController: InterfaceHider Race keeps RaceHud, RaceResults, TouchGui and RaceScreenFx; Show on exit")
end

-- 8. Join sources and remote arguments.
do
	local allowed = { Hud = true, Invite = true, Results = true, Panel = true, Npc = true }
	local joins = 0
	for key in FILES do
		for joinSource in string.gmatch(source[key], 'RaceRequest, "Join", "(%a+)"') do
			assert(allowed[joinSource], key .. ": Join source " .. joinSource .. " is not a client source")
			joins += 1
		end
		assert(not string.find(source[key], '"Join", "Gate"', 1, true), key .. ": the Gate source belongs to the pad")
	end
	assert(joins >= 4, "joins from the HUD button, the invite, the results and the panel (" .. joins .. ")")
	-- 2026-09-25: the server takes the Flash NPC's table payload and its category.
	local server = source.Server
	assert(string.find(server, "local CLIENT_JOIN_SOURCES = { Hud = true, Invite = true, Results = true, Panel = true, Npc = true }", 1, true), "Npc is a client join source")
	assert(string.find(server, 'rawget(payload, "action")', 1, true) and string.find(server, 'rawget(payload, "source")', 1, true)
		and string.find(server, 'rawget(payload, "category")', 1, true), "the { action, source, category } table payload is read")
	assert(string.find(server, 'service:Join(player, "Npc", category)', 1, true) and string.find(server, "CATEGORIES[category]", 1, true), "Npc joins carry a checked category")
	assert(string.find(server, 'player:SetAttribute("RaceBracket", bracket)', 1, true), "RaceBracket published for the NPC menu")
	pass("RaceRequest Join sources: Hud / Invite / Results / Panel from the race client, Npc (with a category) from the lobby NPC")
end

-- 9. LowPowerGraphics: part chevrons hidden, the ORB calmer (touch-only devices).
do
	local low = source.LowPower
	local gate = string.find(low, "if not (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled) then", 1, true)
	local tag = string.find(low, '"RaceDecorLowPower"', 1, true)
	assert(gate and tag and gate < tag, "the race decor is handled after the touch-only gate")
	assert(string.find(low, "GetInstanceAddedSignal(LOW_POWER_TAG)", 1, true) and string.find(low, "GetTagged(LOW_POWER_TAG)", 1, true), "tagged now and as they stream in")
	assert(string.find(low, "ORB_SPARKS_RATE = 4", 1, true), "ORB sparks at 4")
	pass("LowPowerGraphics: RaceDecorLowPower hidden as it streams in, ORB sparks 4/s")
end

-- 10. Review fixes (2026-09-25): the sprint from GO, no stale race context, the results
-- window's decisions, and every word through RaceText.
do
	local s = source.Input
	local mode = functionBody(s, "mode")
	assert(string.find(mode, 'state == "Staged" and now() >= r.goAt', 1, true),
		"mode(): the sprint is live from GO, not only from the Racing state a ping later")
	assert(string.find(functionBody(s, "raceFromAttributes"), "if goAt <= now() then", 1, true),
		"raceFromAttributes refuses the last race's RaceGoAt (written after the racers are staged)")
	assert(string.find(s, "setSprint(pressed())", 1, true), "Racing re-sends the held state (a sprint let go in the gap is off)")
	assert(string.find(s, "local unlocking = locked and t < r.goAt + UNLOCK_GRACE", 1, true),
		"the model runs from GO while the unlock is on its way")
	assert(not string.find(s, 'WaitForChild("RaceHud", ', 1, true) and string.find(s, "playerGui.ChildAdded:Connect(tryHud)", 1, true),
		"the touch button is wired whenever RaceHud arrives")

	local hud = source.Hud
	local again = functionBody(hud, "goAgain")
	assert(string.find(again, 'state == "Finished"', 1, true) and string.find(again, '"AutoRequeue", true', 1, true),
		"RACE AGAIN before the Results keeps the auto-requeue instead of a second Join")
	assert(string.find(hud, 'if you and decided ~= "again" then', 1, true), "the Results do not reopen for a racer who chose RACE AGAIN")
	assert(string.find(hud, "n = lastN", 1, true) and not string.find(hud, "n = live and live.n", 1, true),
		"the field size survives the HUD hiding before the Results")

	-- Every key the controllers ask for exists in English, and the builders' fixed English
	-- titles are replaced by the player's language.
	local RaceText = require("../src/common/ReplicatedStorage/Shared/RaceText")
	for _, key in { "Hud", "Lobby" } do
		for name in string.gmatch(source[key], 'text%("(%w+)"') do
			assert(RaceText.Strings.en[name], key .. ": RaceText has no key " .. name)
		end
	end
	assert(string.find(hud, 'window.Title.Text = text("ResultsTitle")', 1, true) and string.find(hud, 'chip.Text = text("You")', 1, true),
		"results title and YOU chips localised")
	local lobby = source.Lobby
	assert(string.find(lobby, 'window.Title.Text = text("Race")', 1, true) and string.find(lobby, 'right.Fastest.Text = text("Fastest")', 1, true)
		and string.find(lobby, "text(tabButton.Name)", 1, true), "panel title, FASTEST RACERS and the tabs localised")
	for _, name in { "Weekly", "AllTime" } do
		assert(RaceText.Strings.en[name], "tab key " .. name)
	end
	pass("review fixes: sprint from GO, no stale context, results decisions, every word via RaceText")
end

-- 11. Never a walk, and the charge on Shift (2026-09-25, owner).
do
	local run = source.Run
	local update = functionBody(run, "updateMovePlaybackSpeed")
	assert(string.find(update, "if inRace() then", 1, true) and string.find(update, 'GetAttribute("RaceLocalSpeed")', 1, true)
		and string.find(update, "RACE_MIN_PLAYBACK, RACE_MAX_PLAYBACK", 1, true), "in a race the move track plays the race speed, clamped to the fast band")
	local minimum = tonumber(string.match(run, "local RACE_MIN_PLAYBACK = ([%d%.]+)"))
	assert(minimum and minimum >= 1.48, "never slower than the 100-150 studs/s run (" .. tostring(minimum) .. ")")
	assert(string.find(functionBody(run, "inRace"), 'GetAttribute("RaceActive") == true', 1, true), "RaceActive: staged, countdown, running, staging box")
	assert(string.find(run, "not raceJumped and os.clock() - since < RACE_AIR_GRACE", 1, true), "seam hops keep the run; real jumps still jump")

	local s = source.Input
	local bind = functionBody(s, "bindInputs")
	for _, key in { "LeftShift", "RightShift", "ButtonR2" } do
		assert(string.find(bind, "Enum.KeyCode." .. key, 1, true), "the charge / sprint is bound to " .. key)
	end
	assert(string.find(s, "local SPRINT_KEYS = { LeftShift = true, RightShift = true, ButtonR2 = true, ButtonL2 = true }", 1, true), "Shift and R2 charge and sprint")
	local RaceText = require("../src/common/ReplicatedStorage/Shared/RaceText")
	assert(string.find(RaceText.Strings.en.HoldKey, "[SHIFT]", 1, true), "the hint says HOLD [SHIFT]")
	assert(string.find(s, 'setLocal("RaceAutoRun", autoRun)', 1, true) and string.find(s, "RaceMath.AutoRunDirection(move.X, move.Z)", 1, true),
		"RaceAutoRun from GO, and the model gets the auto-run direction")
	assert(not string.find(s, "BaseCruise * 0.5", 1, true) and string.find(s, "local speed = cruiseSpeed()", 1, true), "waiting / finished: the racer's cruise, never a half-speed jog")
	assert(string.find(functionBody(s, "cruiseSpeed"), 'GetAttribute("RaceCruiseSpeed")', 1, true), "...from the server's RaceCruiseSpeed")

	local hud = source.Hud
	assert(string.find(hud, 'if charging and player:GetAttribute("RaceChargeHeld") == true then', 1, true)
		and string.find(hud, "gaugePulse.Scale = pulse", 1, true) and string.find(hud, "ringPulse.Scale = pulse", 1, true), "the gauge and the ring throb while the charge is held")
	assert(string.find(hud, 'if grade == "Perfect" and not reduced then', 1, true), "a Perfect start flashes (not with reduced motion)")
	pass("never a walk: fast run playback >= " .. minimum .. "x while RaceActive, auto-run, cruise while waiting; charge on Shift / R2 / touch; the HUD throbs while held")
end

-- 12. Hills and speed pads (2026-09-25, Astra's map): one ground profile for both sides, pads
-- predicted by the client and granted by the server, their feel.
do
	local s = source.Input
	assert(string.find(s, 'Workspace:GetAttributeChangedSignal("RaceGroundProfile"):Connect(refreshProfile)', 1, true)
		and string.find(s, 'RaceTrack.SetProfile(decoded)', 1, true) and string.find(s, 'RaceTrack.DecodeProfile(Workspace:GetAttribute("RaceGroundProfile"))', 1, true),
		"the client decodes the server's ground profile")
	assert(string.find(s, "RaceTrack.SweptPad(r.pads, r.lastS, r.lastX, r.lastY, s, x, y, 0)", 1, true) and string.find(s, "RaceMath.PadHit(model, pad.boost, pad.seconds, at)", 1, true),
		"pads predicted on the exact footprint")
	assert(string.find(s, 'setLocal("RaceBoostAt", at)', 1, true) and string.find(s, 'setLocal("RaceBoostUntil", model.boostUntil)', 1, true), "RaceBoostAt / RaceBoostUntil for the HUD and the feel")
	assert(string.find(s, "RaceTrack.PadsFromPayload(payload.pads)", 1, true), "the pads come from the Staged payload")
	local server = source.Server
	assert(string.find(server, 'Workspace:SetAttribute("RaceGroundProfile", encoded)', 1, true) and string.find(server, "RaceTrack.SetProfile(RaceTrack.DecodeProfile(encoded) or profile)", 1, true),
		"the server publishes the profile and judges with its decoded copy")
	assert(string.find(server, "params.RespectCanCollide = true", 1, true) and string.find(server, 'child.Name == "RaceArena"', 1, true), "raycast on the collidable floor, again when the arena is replaced")
	assert(string.find(server, "pads = readPads,", 1, true) and string.find(server, 'arena:FindFirstChild("SpeedPads")', 1, true), "the pads are read from RaceArena.SpeedPads")
	local hud = source.Hud
	assert(string.find(hud, 'GetAttributeChangedSignal("RaceBoostAt")', 1, true) and string.find(hud, 'text("PadBoost")', 1, true)
		and string.find(hud, 'GetAttribute("RaceBoostUntil")', 1, true), "the HUD shows BOOST! and a gold bar while boosted")
	local pose = fs.readFile(ROOT .. "Race/RacePoseClient.client.luau")
	assert(string.find(pose, "RaceVfx.PadBoost(racer.Character", 1, true) and string.find(pose, "CameraPunch.Fov(PAD_PUNCH", 1, true), "the pad's ring, arcs and FOV kick")
	local service = fs.readFile("src/common/ServerScriptService/Services/Race/RaceService.luau")
	assert(not string.find(service, "RaceTrack.RootHeight)))", 1, true) and string.find(service, "RaceTrack.GroundCFrame(c.s, x)", 1, true)
		and string.find(service, "RaceTrack.HeightAboveGround(s, x, y) < VALIDATION.FallY", 1, true), "corrections, falls and recoveries stand on the ground under the racer")
	pass("hills and pads: the client decodes the server's profile, predicts pads, shows BOOST! and the pad's feel; the server raycasts, publishes, reads the pads; pivots on the ground")
end

-- 13. 2026-09-26 (owner's phone playtest: the results and the sign-up were very big on a phone):
-- the three windows are fitted by RaceUiBuilder.FitWindow (LobbyNpcUi.Fit) in their ScreenGui's
-- room (under the top bar, inside the notch; the viewport less the top bar until it is
-- measured), for touch screens too, again whenever that room changes; the old whole-screen
-- rule is gone.
do
	local npcClient = fs.readFile(ROOT .. "Gameplay/LobbyNpcsClient.client.luau")
	local fits = {
		{ "Hud", source.Hud, "fitResults", "results", "RaceUiBuilder.FitWindow(kit.env, window, RaceUiBuilder.ArrangeResults, RESULTS_SIZES," },
		{ "Lobby", source.Lobby, "fitPanel", "panelGui", "RaceUiBuilder.FitWindow(kit.env, window, RaceUiBuilder.ArrangePanel, PANEL_SIZES," },
		{ "LobbyNpcsClient", npcClient, "fitScale", "dialog", "LobbyNpcUi.Fit(kit.env, window," },
	}
	for _, entry in fits do
		local name, text, fn, gui, call = entry[1], entry[2], entry[3], entry[4], entry[5]
		local body = functionBody(text, fn)
		assert(string.find(body, "local room = " .. gui .. ".AbsoluteSize", 1, true), name .. ": " .. fn .. " measures " .. gui .. "'s room")
		assert(string.find(body, "view.Y - GuiService:GetGuiInset().Y", 1, true), name .. ": the viewport less the top bar until the room is measured")
		assert(string.find(body, call, 1, true) and string.find(body, "view.X, view.Y, room.X, room.Y, UserInputService.TouchEnabled)", 1, true),
			name .. ": " .. fn .. " goes through FitWindow with the viewport, the room and touch")
		assert(string.find(text, gui .. ':GetPropertyChangedSignal("AbsoluteSize"):Connect(', 1, true), name .. ": refitted when the room changes")
		assert(not string.find(text, "RaceUiBuilder.FitScale(", 1, true) and not string.find(text, "LobbyNpcUi.FitScale(", 1, true), name .. ": the old whole-screen FitScale")
	end
	assert(string.find(functionBody(source.Hud, "fitResults"), "window.FitScale.Scale = fit.Scale", 1, true), "the results' FitScale is the fit's")
	assert(string.find(functionBody(source.Lobby, "open"), "fitPanel()", 1, true), "the panel is fitted as it opens")
	assert(string.find(functionBody(npcClient, "openDialog"), "local target = fitScale()", 1, true), "the sign-up is fitted as it opens")
	pass("windows: results, race panel and sign-up fitted in their ScreenGui's room (top bar, notch) through FitWindow, touch included, refitted on resize")
end

print(("ALL PASSED (%d groups)"):format(passed))
