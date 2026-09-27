-- StarterPlayerScripts/Race/RaceInputClient.client.luau — Update 4 (2026-09-25): the single owner
-- of race input and of the local race prediction (PLAN §7.4 item 1).
--   * Charge (the countdown's last 3 s): hold Shift / Space / the left mouse button, the R2/L2
--     trigger or A, or the touch CHARGE button. Every press and release is a server-clock edge;
--     the cumulative list goes to RaceChargeInput on each edge (at most every 0.08 s) and once
--     more with final=true at GO. The gauge is RaceChargeMath.Evaluate of the same edges, so
--     what the player sees is what the server's judge replays.
--   * Sprint (the race): hold Shift, R2/L2 or the touch BOOST button (Space and A jump). Only
--     the edges go to RaceSprint. A charge held through GO turns into the sprint on that frame.
--   * Prediction (Heartbeat, only while RaceActive): RaceMath.Step with the player's forward
--     input, the race pool and the predicted start grade (switched to the server's grade when
--     RaceEvent Start arrives, from the current tau), a local spike check (the server confirms
--     with Stumble) and the server's Corrections. It writes the local-only attributes the
--     movement controller, the HUD and the race feel read: RaceLocalSpeed (the walk speed; 0
--     on the grid), RaceChargeLocal, RaceStaminaLocal, RaceLocalSuper, and for the HUD
--     RaceChargeHeld, RaceChargeAssist, RacePredictedGrade, RaceAccelLocal.
--   * 2026-09-25 (owner: never walk in a race): from GO the racer runs down the track by
--     itself (RaceAutoRun, read by InstantMovementController; the input steers, see
--     RaceMath.AutoRunDirection), never under RaceMath's run floor, and in the staging box or
--     after the finish at the racer's own cruise instead of a half-speed jog.
-- 2026-09-26 (owner: console first-class): the whole race plays on a gamepad, no mouse or keyboard:
--   charge (countdown) ButtonA or ButtonR2 (ButtonL2 too), analog triggers past 0.35 / under 0.20;
--   sprint (race)      ButtonR2 (ButtonL2 too); ButtonA jumps from GO, as Space does on a keyboard;
--   steering           the left thumbstick (native MoveDirection, RaceMath.AutoRunDirection);
--   leave              ButtonSelect / View (UI/RaceHudController), results and the race panel through
--                      ConsolePanelSupport (A picks, B is LOBBY / close).
-- The race has no drift, quick turn or lane change, so nothing is bound to ButtonX. The HUD shows
-- these buttons' glyphs while a gamepad is the last input (RaceHudController PAD_GLYPHS: keep the
-- two lists in step; audit/test_u4_gamepad checks they are).
-- ContextActionService binds "RaceAction" above SpeedsterClient's sprint only while RaceActive;
-- the Heartbeat runs only then too. Nothing here decides a reward: the server replays the edges
-- and runs its own model (Services/Race/RaceService, RaceChargeJudge).
-- During the countdown the humanoid's jump is zeroed: no jumps on the grid, and on touch
-- Roblox hides its jump button (Space and A charge then). It is restored at GO and on every
-- exit (the unlock, death, respawn, leaving the race).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local HapticService = game:GetService("HapticService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local U4 = require(Shared:WaitForChild("Update4Config"))
local RaceMath = require(Shared:WaitForChild("RaceMath"))
local RaceChargeMath = require(Shared:WaitForChild("RaceChargeMath"))
local RaceTrack = require(Shared:WaitForChild("RaceTrack"))

-- The race remotes exist only where Gameplay/RaceServer runs with the feature on.
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
local RaceSprint = Remotes and Remotes:WaitForChild("RaceSprint", 60)
local RaceChargeInput = Remotes and Remotes:WaitForChild("RaceChargeInput", 30)
local RaceEvent = Remotes and Remotes:WaitForChild("RaceEvent", 30)
if not (RaceSprint and RaceChargeInput and RaceEvent) then
	return
end

local RACE = U4.Race
local CHARGE = RACE.Charge
local QUEUE = RACE.Queue
local STAMINA = RACE.Stamina
local SUPER = RACE.Super
local SOUNDS = RACE.Feel.Sounds
local TURBINE = RACE.Feel.Turbine or { Pitch = { 0.8, 1.3 }, Volume = { 0.35, 0.35 } }

local ACTION = "RaceAction"
local ACTION_PRIORITY = Enum.ContextActionPriority.High.Value + 200
local TRIGGER_PRESS, TRIGGER_RELEASE = 0.35, 0.20
local SEND_INTERVAL = 0.08 -- the server collapses faster packets (LatestStateLimiter 0.08)
local FORWARD = Vector3.new(0, 0, -1) -- down the track
-- In the arena but not racing (waiting in the staging box, after the finish): the racer's own
-- cruise. 2026-09-25 (owner: never walk in a race): it was half of the base cruise, a walk.
local function cruiseSpeed(): number
	local cruise = tonumber(player:GetAttribute("RaceCruiseSpeed"))
	if cruise and cruise == cruise and cruise > 0 then
		return cruise
	end
	return RaceMath.CruiseSpeed(tonumber(player:GetAttribute("RawSpeed")) or 1)
end
local CAMERA_ALIGN_STUDS = 30
local SPEED_EPSILON = 0.05
local UNLOCK_GRACE = 0.5 -- s after GO in which RaceMovementLocked is the unlock still on its way

-- One race's context, from RaceEvent Staged (or the attributes when that event was missed).
local race = nil
-- The inputs holding the race action right now (keys, triggers, mouse, the touch button).
local holding = {}
local heartbeat = nil
local bound = false
local jumpJar = nil -- { humanoid, height, power } while the jump is zeroed
local jumpedSinceStep = false
local characterConnections = {}
local misses = 0 -- consecutive Ok/Stall starts this session (RaceChargeJudge's assist rule)
local lastAttr = {}

local function now()
	return Workspace:GetServerTimeNow()
end

local function finite(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- Local-only attributes (a client's SetAttribute never replicates); written only on change.
local function setLocal(name, value)
	if lastAttr[name] ~= value then
		lastAttr[name] = value
		player:SetAttribute(name, value)
	end
end

local function clearLocals()
	for _, name in { "RaceLocalSpeed", "RaceChargeLocal", "RaceStaminaLocal", "RaceLocalSuper", "RaceChargeHeld",
		"RaceChargeAssist", "RacePredictedGrade", "RaceAccelLocal", "RaceLocalStumbleAt", "RaceAutoRun",
		"RaceBoostUntil", "RaceBoostAt" } do
		setLocal(name, nil)
	end
end

local function humanoidOf()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return humanoid, root
end

local function soundsOn()
	return player:GetAttribute("SoundEffects") ~= false and player:GetAttribute("Muted") ~= true
end

local function reducedMotion()
	local ok, value = pcall(function()
		return GuiService.ReducedMotionEnabled
	end)
	return ok and value == true
end

----------------------------------------------------------------------
-- Sounds and haptics (made once; only ids already used live)
----------------------------------------------------------------------
local function makeSound(name, id, volume, looped)
	if type(id) ~= "string" or id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = "Race" .. name
	sound.SoundId = id
	sound.Volume = volume
	sound.Looped = looped == true
	sound.Parent = SoundService
	return sound
end
local hum = makeSound("ChargeHum", SOUNDS.ChargeHum, 0.35, true)
local humLevel = nil -- the gauge step the turbine's pitch and volume were last set for
local zoneTick = makeSound("ZoneTick", SOUNDS.ZoneTick, 0.5, false)
local overheat = makeSound("Overheat", SOUNDS.Overheat, 0.45, false)

local function play(sound)
	if sound and soundsOn() then
		sound.TimePosition = 0
		sound:Play()
	end
end

local function stopHum()
	humLevel = nil
	if hum and hum.IsPlaying then
		hum:Stop()
	end
end

local function gamepadActive()
	local last = UserInputService:GetLastInputType()
	return last.Name:find("Gamepad") ~= nil
end

-- The gamepad's motors: only on a gamepad, never with reduced motion, set only on a change.
local motorLevel = {}
local function motor(kind, value)
	if reducedMotion() or not gamepadActive() then
		value = 0
	end
	local level = math.floor(value * 20 + 0.5) / 20
	if (motorLevel[kind] or 0) == level then
		return
	end
	motorLevel[kind] = level
	pcall(function()
		HapticService:SetMotor(Enum.UserInputType.Gamepad1, kind, level)
	end)
end

local function motorsOff()
	motor(Enum.VibrationMotor.Small, 0)
	motor(Enum.VibrationMotor.Large, 0)
end

----------------------------------------------------------------------
-- The jump on the grid
----------------------------------------------------------------------
local function zeroJump()
	local humanoid = humanoidOf()
	if not humanoid or (jumpJar and jumpJar.humanoid == humanoid) then
		return
	end
	jumpJar = { humanoid = humanoid, height = humanoid.JumpHeight, power = humanoid.JumpPower }
	humanoid.JumpHeight = 0
	humanoid.JumpPower = 0
end

-- Put back what was there, unless something else changed it meanwhile.
local function restoreJump()
	local jar = jumpJar
	jumpJar = nil
	if jar and jar.humanoid and jar.humanoid.Parent then
		if jar.humanoid.JumpHeight == 0 then
			jar.humanoid.JumpHeight = jar.height
		end
		if jar.humanoid.JumpPower == 0 then
			jar.humanoid.JumpPower = jar.power
		end
	end
end

----------------------------------------------------------------------
-- Charge edges and the sprint
----------------------------------------------------------------------
local function assisted()
	return misses >= CHARGE.AssistAfterMisses
end

local function graced()
	return (tonumber(player:GetAttribute("RaceFinishes")) or 0) < CHARGE.GraceRaces
end

local function sendCharge(final)
	local r = race
	if not r then
		return
	end
	r.lastSendAt = os.clock()
	r.sendPending = false
	pcall(RaceChargeInput.FireServer, RaceChargeInput, r.id, r.edges, final == true)
end

-- On each edge; a second edge inside SEND_INTERVAL goes out when the interval closes.
local function queueSend()
	local r = race
	if not r or r.finalSent then
		return
	end
	local wait = SEND_INTERVAL - (os.clock() - (r.lastSendAt or -math.huge))
	if wait <= 0 then
		sendCharge(false)
	elseif not r.sendPending then
		r.sendPending = true
		task.delay(wait, function()
			if race == r and r.sendPending and not r.finalSent then
				sendCharge(false)
			end
		end)
	end
end

-- Mirrors the judge's clamp (RaceChargeJudge.AcceptEdges) so the local gauge replays exactly
-- what the server will: inside [openAt, goAt], at least MinPress after the previous edge.
local function recordEdge(t)
	local r = race
	if not r or r.finalSent or #r.edges >= CHARGE.MaxEdges then
		return
	end
	local previous = r.edges[#r.edges]
	local low = math.max(r.openAt, if previous then previous + CHARGE.MinPress else -math.huge)
	if low > r.goAt then
		return
	end
	table.insert(r.edges, math.clamp(t, low, r.goAt))
	queueSend()
end

local function setSprint(on)
	local r = race
	if not r then
		return
	end
	r.sprintWanted = on
	if r.sprintSent ~= on then
		r.sprintSent = on
		pcall(RaceSprint.FireServer, RaceSprint, on)
	end
end

local function pressed()
	return next(holding) ~= nil
end

-- The phase of the local race: "charge" (countdown, before GO), "run" (racing), nil.
local function mode()
	local r = race
	if not r then
		return nil
	end
	local state = player:GetAttribute("RaceState")
	if not r.model then
		if state == "Staged" and now() >= r.goAt - QUEUE.CountdownSeconds - 0.25 then
			return "charge"
		end
		return nil
	end
	-- 2026-09-25 review: from GO, not from the "Racing" state a ping later: a sprint let go in
	-- that gap was never sent and stayed on.
	if state == "Racing" or (state == "Staged" and now() >= r.goAt) then
		return "run"
	end
	return nil
end

-- The held state changed (any source): an edge for the charge, the sprint while running.
local function holdChanged()
	local r = race
	if not r then
		return
	end
	local isHeld = pressed()
	setLocal("RaceChargeHeld", isHeld)
	local m = mode()
	if m == "charge" then
		local t = now()
		if t >= r.openAt and t <= r.goAt then
			local wantPress = #r.edges % 2 == 0
			if isHeld == wantPress then
				recordEdge(t)
			end
		end
	elseif m == "run" then
		setSprint(isHeld)
	end
end

local function hold(source, on)
	local was = holding[source] == true
	if on == was then
		return
	end
	holding[source] = if on then true else nil
	holdChanged()
end

local function releaseAll()
	table.clear(holding)
	setLocal("RaceChargeHeld", false)
end

----------------------------------------------------------------------
-- Input bindings (only while RaceActive)
----------------------------------------------------------------------
-- By KeyCode name.
local SPRINT_KEYS = { LeftShift = true, RightShift = true, ButtonR2 = true, ButtonL2 = true }
-- Space and A charge during the countdown and jump during the race.
local CHARGE_ONLY_KEYS = { Space = true, ButtonA = true }

local function onAction(_, state, input)
	local m = mode()
	local key = input.KeyCode
	local source = key.Name
	-- 2026-09-25 (final fix): a release is recorded whatever the phase. A Space / A press made in
	-- the countdown and let go after GO used to pass the charge-only filter below unrecorded:
	-- the sprint then stayed on for the whole race.
	if (state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel) and holding[source] then
		hold(source, false)
		return if SPRINT_KEYS[source] then Enum.ContextActionResult.Sink else Enum.ContextActionResult.Pass
	end
	if not m or UserInputService:GetFocusedTextBox() then
		return Enum.ContextActionResult.Pass
	end
	if CHARGE_ONLY_KEYS[source] and m ~= "charge" then
		return Enum.ContextActionResult.Pass
	end
	if not SPRINT_KEYS[source] and not CHARGE_ONLY_KEYS[source] then
		return Enum.ContextActionResult.Pass
	end
	if state == Enum.UserInputState.Cancel then
		hold(source, false)
		return Enum.ContextActionResult.Pass
	end
	if source == "ButtonR2" or source == "ButtonL2" then
		-- Analog triggers: pressed past 0.35, released under 0.20 (no chatter in between).
		-- A digital trigger reports Begin/End with Z = 0.
		local z = input.Position.Z
		if state == Enum.UserInputState.End or (state ~= Enum.UserInputState.Begin and z <= TRIGGER_RELEASE) then
			hold(source, false)
		elseif z >= TRIGGER_PRESS or (state == Enum.UserInputState.Begin and z <= 0) then
			hold(source, true)
		end
		return Enum.ContextActionResult.Sink
	end
	if state == Enum.UserInputState.Begin then
		hold(source, true)
	elseif state == Enum.UserInputState.End then
		hold(source, false)
	end
	return Enum.ContextActionResult.Sink
end

local function bindInputs()
	if bound then
		return
	end
	bound = true
	ContextActionService:BindActionAtPriority(ACTION, onAction, false, ACTION_PRIORITY,
		Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.Space,
		Enum.KeyCode.ButtonR2, Enum.KeyCode.ButtonL2, Enum.KeyCode.ButtonA)
end

local function unbindInputs()
	if not bound then
		return
	end
	bound = false
	ContextActionService:UnbindAction(ACTION)
	releaseAll()
end

-- The left mouse button charges too (not over a GUI: gameProcessed).
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if bound and not gameProcessed and input.UserInputType == Enum.UserInputType.MouseButton1 and mode() == "charge" then
		hold("Mouse", true)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if holding.Mouse and input.UserInputType == Enum.UserInputType.MouseButton1 then
		hold("Mouse", false)
	end
end)
-- A lost window focus never leaves a key held.
UserInputService.WindowFocusReleased:Connect(function()
	if bound then
		releaseAll()
		holdChanged()
	end
end)

-- The touch CHARGE / BOOST button (UI/RaceHudController builds it in RaceHud).
local touchInput = nil
local wiredButton = nil
local function wireActionButton(button)
	if wiredButton == button then
		return
	end
	wiredButton = button
	button.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		if touchInput then
			return
		end
		touchInput = input
		hold("Touch", true)
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input == touchInput then
			touchInput = nil
			hold("Touch", false)
		end
	end)
end
-- 2026-09-25 review: whenever RaceHud arrives (the HUD controller waits for its own remotes
-- first), not only inside a fixed window.
task.spawn(function()
	local playerGui = player:WaitForChild("PlayerGui", 30)
	if not playerGui then
		return
	end
	local function tryHud(child)
		if child.Name == "RaceHud" and child:IsA("ScreenGui") then
			local button = child:FindFirstChild("Action")
			if button and button:IsA("GuiButton") then
				wireActionButton(button)
			end
		end
	end
	playerGui.ChildAdded:Connect(tryHud)
	for _, child in playerGui:GetChildren() do
		tryHud(child)
	end
end)

----------------------------------------------------------------------
-- The race context
----------------------------------------------------------------------
local function paramsFrom(cruise, sprint, sprintSeconds, regenFactor)
	local vc = if finite(cruise) and cruise > 0 then cruise else RACE.Speed.BaseCruise
	return {
		Vc = vc,
		Vs = if finite(sprint) and sprint > 0 then sprint else vc * RACE.Speed.SprintMultiplier,
		b = 0,
		sprintSeconds = if finite(sprintSeconds) and sprintSeconds > 0 then sprintSeconds else STAMINA.SprintBaseSeconds,
		regenFactor = if finite(regenFactor) then math.clamp(regenFactor, 0.5, 4) else 1,
	}
end

local function newRace(id, goAt, params, slot, pads)
	stopHum()
	motorsOff()
	race = {
		id = id,
		goAt = goAt,
		openAt = goAt - QUEUE.ChargeOpenLeadSeconds,
		params = params,
		slot = slot,
		pads = pads or {}, -- 2026-09-25: the race's speed pads (Staged; none when it was missed)
		edges = {},
		opened = false,
		finalSent = false,
		model = nil,
		sprintWanted = false,
		sprintSent = false,
		lastS = nil,
		cameraAligned = false,
		wasInZone = false,
		wasVenting = false,
		super = false,
	}
	setLocal("RacePredictedGrade", nil)
	setLocal("RaceChargeAssist", assisted())
	setLocal("RaceStaminaLocal", 1)
	setLocal("RaceChargeLocal", 0)
	setLocal("RaceLocalSuper", false)
	setLocal("RaceBoostUntil", nil)
end

-- The race context from the attributes (a Staged event missed or arriving late).
local function raceFromAttributes()
	local id = Workspace:GetAttribute("RaceId")
	local goAt = Workspace:GetAttribute("RaceGoAt")
	if not finite(id) or not finite(goAt) then
		return
	end
	-- RaceService stages the racers before it writes RaceId/RaceGoAt: a GO already past is the
	-- last race's (its Staged event follows at once).
	if goAt <= now() then
		return
	end
	-- The Staged event may have set this race up already, and the Workspace attributes can
	-- still be the last race's for a moment: never replace a context with an older one.
	if race and (race.id == id or race.goAt >= goAt) then
		return
	end
	newRace(id, goAt, paramsFrom(player:GetAttribute("RaceCruiseSpeed"), player:GetAttribute("RaceSprintSpeed"),
		player:GetAttribute("RaceSprintSeconds"), player:GetAttribute("RaceRegenFactor")), player:GetAttribute("RaceSlot"))
end

-- GO: the final charge packet, the predicted grade, the model, the jump back.
local function startModel()
	local r = race
	if not r or r.model then
		return
	end
	if not r.finalSent then
		r.finalSent = true
		sendCharge(true)
	end
	local assist = assisted()
	local result = RaceChargeMath.Evaluate(r.edges, r.openAt, r.goAt, r.goAt, nil, assist)
	local grade = RaceChargeMath.Outcome(result, nil, graced(), assist)
	if r.serverGrade then
		grade = r.serverGrade
	end
	local _, root = humanoidOf()
	local s0 = 0
	if root then
		local s = RaceTrack.ToLocal(root.Position)
		s0 = math.min(s, 0)
	end
	r.model = RaceMath.NewState(r.params, grade, nil, r.goAt, s0)
	r.model.pool = math.clamp(1 - RaceChargeMath.StaminaCost(result.HeldSeconds), 0, 1)
	r.heldSeconds = result.HeldSeconds
	setLocal("RacePredictedGrade", grade)
	-- The gauge keeps its value at GO for the HUD's last look (it fades 0.8 s later).
	setLocal("RaceChargeLocal", math.floor(result.G * 1000 + 0.5) / 1000)
	stopHum()
	motor(Enum.VibrationMotor.Small, 0)
	if grade == "Perfect" then
		motor(Enum.VibrationMotor.Large, 0.8)
		task.delay(0.15, function()
			motor(Enum.VibrationMotor.Large, 0)
		end)
	end
	restoreJump()
	-- Space and A jump from GO on (only Shift, the triggers and the touch button sprint), so a
	-- charge held on them ends here; the release is not waited for.
	if holding.Space or holding.ButtonA then
		holding.Space, holding.ButtonA = nil, nil
		setLocal("RaceChargeHeld", pressed())
	end
	-- Holding the charge through GO is the sprint, on this very frame.
	if pressed() then
		setSprint(true)
	end
end

local function endRace()
	if race and race.sprintSent then
		setSprint(false)
	end
	race = nil
	stopHum()
	motorsOff()
	restoreJump()
end

----------------------------------------------------------------------
-- Heartbeat: the prediction (connected only while RaceActive)
----------------------------------------------------------------------
local function alignCamera(root)
	local camera = Workspace.CurrentCamera
	if camera and camera.CameraType == Enum.CameraType.Custom then
		-- Behind the racer, looking down the track (-Z). CFrame.new(eye, target) is fine in the
		-- game (CFrame.lookAt is only wrong in Lune).
		local eye = root.Position + Vector3.new(0, 6, 16)
		camera.CFrame = CFrame.new(eye, root.Position + Vector3.new(0, 2, -20))
	end
end

local function stepCharge(r, t)
	if not r.opened and t >= r.openAt then
		r.opened = true
		-- Held when the window opens: the press counts from the opening (as the judge clamps it).
		if pressed() and #r.edges == 0 then
			recordEdge(r.openAt)
		end
	end
	if t < r.openAt then
		setLocal("RaceChargeLocal", 0)
		return
	end
	local assist = assisted()
	local result = RaceChargeMath.Evaluate(r.edges, r.openAt, r.goAt, math.min(t, r.goAt), nil, assist)
	local g = result.G
	setLocal("RaceChargeLocal", math.floor(g * 1000 + 0.5) / 1000)
	setLocal("RaceStaminaLocal", math.floor(math.clamp(1 - RaceChargeMath.StaminaCost(result.HeldSeconds), 0, 1) * 1000 + 0.5) / 1000)
	local zoneLo, zoneHi = RaceChargeMath.Bands(nil, assist)
	local inZone = g >= zoneLo and g <= zoneHi
	if inZone and not r.wasInZone then
		play(zoneTick)
	end
	r.wasInZone = inZone
	if result.Venting and not r.wasVenting then
		play(overheat)
	end
	r.wasVenting = result.Venting
	if hum then
		if result.Held and not result.Venting and soundsOn() then
			-- 2026-09-26 (owner): a sonic turbine spinning up: pitch and volume climb with the gauge
			-- (Feel.Turbine), in small steps (two property writes at most per change).
			local level = math.floor(math.clamp(g, 0, 1) * 40 + 0.5) / 40
			if humLevel ~= level then
				humLevel = level
				hum.PlaybackSpeed = TURBINE.Pitch[1] + (TURBINE.Pitch[2] - TURBINE.Pitch[1]) * level ^ 1.3
				hum.Volume = TURBINE.Volume[1] + (TURBINE.Volume[2] - TURBINE.Volume[1]) * level
			end
			if not hum.IsPlaying then
				hum:Play()
			end
		else
			stopHum()
		end
	end
	motor(Enum.VibrationMotor.Small, if result.Held then 0.4 * g else 0)
end

local function onHeartbeat(dt)
	local t = now()
	local r = race
	local humanoid, root = humanoidOf()
	local state = player:GetAttribute("RaceState")
	local locked = player:GetAttribute("RaceMovementLocked") == true

	if r and not r.model then
		if state == "Staged" or state == "Racing" then
			stepCharge(r, t)
			if t >= r.goAt then
				startModel()
			end
		end
		-- The countdown only (the lock and InstantMovementController hold the racer before it).
		if state == "Staged" and t < r.goAt and Workspace:GetAttribute("RacePhase") == "Countdown" then
			zeroJump()
		end
		if not r.cameraAligned and root and r.slot then
			if (root.Position - RaceTrack.SlotPosition(r.slot)).Magnitude < CAMERA_ALIGN_STUDS then
				r.cameraAligned = true
				alignCamera(root)
			end
		end
	end

	local speed = cruiseSpeed()
	local model = r and r.model
	local autoRun = false
	if model and root then
		local step = math.clamp(dt, 0, 0.1)
		local forward = 0
		local grounded = true
		-- From GO the server's model runs with full input; the "Racing" state lands a ping later.
		local racing = state == "Racing" or (state == "Staged" and t >= r.goAt)
		-- 2026-09-25 (owner: never walk in a race): once let go the racer runs down the track by
		-- itself and the input steers (RaceMath.AutoRunDirection; InstantMovementController moves
		-- along the same direction while RaceAutoRun is on).
		autoRun = racing and not locked
		if humanoid then
			local move = humanoid.MoveDirection
			if autoRun then
				local _, z = RaceMath.AutoRunDirection(move.X, move.Z)
				forward = RaceMath.ForwardInput(-z)
			else
				forward = RaceMath.ForwardInput(move:Dot(FORWARD))
			end
			grounded = humanoid.FloorMaterial ~= Enum.Material.Air
		end
		-- 2026-09-25 review: the lock lifts a ping (+ a 20 Hz tick) after GO, and a false start
		-- holds 0.3 s past it. The model runs from GO as the server's does (full input), so the
		-- launch speed is there when the racer is let go instead of decaying on the grid.
		local unlocking = locked and t < r.goAt + UNLOCK_GRACE
		if unlocking then
			forward = 1
		end
		RaceMath.Step(model, {
			forward = if racing and (unlocking or not locked) then forward else 0,
			sprint = racing and r.sprintWanted == true,
			grounded = grounded,
			jumped = jumpedSinceStep,
		}, step, r.params, t)
		jumpedSinceStep = false
		-- Spikes: the path since the last frame (never a tile skipped at 24 FPS); the server
		-- decides with its own swept test and answers Stumble.
		local s, x, y = RaceTrack.ToLocal(root.Position)
		-- 2026-09-26: as if standing at RootHeight, like the server (RaceService Validator lift):
		-- a tall avatar or the Silver Surfer's board is not a jump over every spike row.
		if humanoid then
			y -= RaceTrack.RootLift(RaceTrack.StandHeight(humanoid.RigType.Name, humanoid.HipHeight, root.Size.Y))
		end
		if racing and r.lastS then
			local tile = RaceTrack.SweptSpike(r.lastS, r.lastX, s, x, r.lastY, y)
			if tile and RaceMath.SpikeHit(model, t) then
				setLocal("RaceLocalStumbleAt", t)
			end
		end
		-- 2026-09-25: speed pads, predicted at once on the exact footprint (the server grants
		-- within a margin of it, so it never refuses a boost this frame saw). RaceBoostUntil /
		-- RaceBoostAt (server clock) drive the HUD's BOOST! and the pad's feel (RacePoseClient).
		if racing and r.lastS then
			local pad, fraction = RaceTrack.SweptPad(r.pads, r.lastS, r.lastX, r.lastY, s, x, y, 0)
			if pad then
				local at = t - step * (1 - fraction)
				if RaceMath.PadHit(model, pad.boost, pad.seconds, at) then
					setLocal("RaceBoostAt", at)
				end
				setLocal("RaceBoostUntil", model.boostUntil)
			end
		end
		r.lastS, r.lastX, r.lastY = s, x, y
		setLocal("RaceStaminaLocal", math.floor(model.pool * 1000 + 0.5) / 1000)
		setLocal("RaceAccelLocal", math.floor(RaceMath.Accel(model) * 10 + 0.5) / 10)
		local vs = r.params.Vs
		if not r.super and model.v >= SUPER.LocalEnterFraction * vs then
			r.super = true
		elseif r.super and model.v < SUPER.ExitFraction * vs then
			r.super = false
		end
		setLocal("RaceLocalSuper", r.super)
		if racing then
			speed = model.v
		elseif state == "Finished" then
			speed = cruiseSpeed()
		end
	end
	if locked or (state == "Staged" and not model) then
		speed = 0
	end
	setLocal("RaceAutoRun", autoRun)
	local rounded = math.floor(speed * 10 + 0.5) / 10
	if math.abs((lastAttr.RaceLocalSpeed or -1) - rounded) >= SPEED_EPSILON then
		setLocal("RaceLocalSpeed", rounded)
	end
end

----------------------------------------------------------------------
-- Active / not active
----------------------------------------------------------------------
local function activate()
	if heartbeat then
		return
	end
	setLocal("RaceLocalSpeed", cruiseSpeed())
	bindInputs()
	heartbeat = RunService.Heartbeat:Connect(onHeartbeat)
	if player:GetAttribute("RaceState") == "Staged" then
		raceFromAttributes()
	end
end

local function deactivate()
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	unbindInputs()
	endRace()
	clearLocals()
end

local function refreshActive()
	if player:GetAttribute("RaceActive") == true then
		activate()
	else
		deactivate()
	end
end

player:GetAttributeChangedSignal("RaceActive"):Connect(refreshActive)
player:GetAttributeChangedSignal("RaceState"):Connect(function()
	local state = player:GetAttribute("RaceState")
	if state == "Staged" then
		raceFromAttributes()
	elseif state == "Racing" then
		if race and not race.model and now() >= race.goAt - 0.05 then
			startModel()
		end
		-- The sprint as held now (edges are sent only on change): on if a key is held through GO.
		if race and race.model then
			setSprint(pressed())
		end
	elseif state == "Queued" or state == "" or state == nil then
		-- Requeued after a race or out of it: this race is over.
		endRace()
		setLocal("RacePredictedGrade", nil)
		setLocal("RaceLocalSuper", false)
		setLocal("RaceChargeLocal", nil)
	end
end)
player:GetAttributeChangedSignal("RaceMovementLocked"):Connect(function()
	if player:GetAttribute("RaceMovementLocked") ~= true then
		restoreJump()
	end
end)

----------------------------------------------------------------------
-- The ground profile (2026-09-25, Astra's map): the server's encoded raycast of the arena
-- (Gameplay/RaceServer), decoded into RaceTrack so the spike / pad heights here are the same
-- numbers the server judges with. Flat until it arrives (the builder's arena is flat anyway).
----------------------------------------------------------------------
local function refreshProfile()
	local decoded = RaceTrack.DecodeProfile(Workspace:GetAttribute("RaceGroundProfile"))
	RaceTrack.SetProfile(decoded)
end
Workspace:GetAttributeChangedSignal("RaceGroundProfile"):Connect(refreshProfile)
refreshProfile()

----------------------------------------------------------------------
-- Server events
----------------------------------------------------------------------
RaceEvent.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" or type(payload.kind) ~= "string" then
		return
	end
	local kind = payload.kind
	if kind == "Staged" then
		if finite(payload.raceId) and finite(payload.goAt) then
			newRace(payload.raceId, payload.goAt, paramsFrom(payload.cruise, payload.sprint, payload.sprintSeconds, payload.regenFactor),
				if finite(payload.slot) then payload.slot else nil, RaceTrack.PadsFromPayload(payload.pads))
		end
	elseif kind == "Start" then
		local grade = payload.grade
		if type(grade) == "string" and CHARGE.Launch[grade] ~= nil then
			misses = if grade == "Perfect" or grade == "Good" then 0 else misses + 1
			if race then
				race.serverGrade = grade
				if race.model and race.model.grade ~= grade then
					-- The server's grade from the current tau (StartMultiplier reads now - goAt).
					race.model.grade = grade
				end
			end
		end
	elseif kind == "Stumble" then
		local r = race
		if r and r.model and finite(payload.untilT) then
			local t = now()
			if t < payload.untilT and r.model.stumbleUntil < t then
				RaceMath.SpikeHit(r.model, t)
				r.model.stumbleUntil = payload.untilT
				setLocal("RaceLocalStumbleAt", t)
			end
		end
	elseif kind == "Correction" then
		local r = race
		if r and r.model and finite(payload.s) and finite(payload.v) then
			r.model.s = payload.s
			r.model.v = math.max(0, payload.v)
			r.lastS = nil
		end
	elseif kind == "Unqueued" then
		endRace()
	end
end)

----------------------------------------------------------------------
-- The character
----------------------------------------------------------------------
local function watchCharacter(character)
	for _, connection in characterConnections do
		connection:Disconnect()
	end
	table.clear(characterConnections)
	jumpJar = nil
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	table.insert(characterConnections, humanoid.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Jumping and race and race.model then
			jumpedSinceStep = true
		end
	end))
	table.insert(characterConnections, humanoid.Died:Connect(function()
		restoreJump()
		releaseAll()
		stopHum()
		motorsOff()
	end))
end

player.CharacterAdded:Connect(watchCharacter)
player.CharacterRemoving:Connect(function()
	restoreJump()
	releaseAll()
	stopHum()
	motorsOff()
end)
if player.Character then
	task.spawn(watchCharacter, player.Character)
end

refreshActive()
