-- StarterPlayerScripts/Gameplay/RaceArenaVisuals.client.luau — Update 4 (2026-09-25): the race
-- arena's start, drawn by every client from Workspace RacePhase / RaceGoAt (PLAN §7.4 item 6):
--   * the start gantry's five lights turn red one a second from GO - 5, all green at GO;
--   * at GO the red STOP bar drops under the floor (0.25 s, Back In) and this client's copy
--     of the StartGate collider stops colliding on the same frame (the server opens its own at
--     GO - 0.1); both come back at the next staging;
--   * the ORB's shell turns 20 degrees a second, and the arena's light fog shows, only while
--     this player is inside the arena box (|x - 6000| < 200, -200 < s < 2300). The fog's
--     previous colour and range are put back on the way out, and only if they are still ours
--     (an admin event may have changed Lighting meanwhile). Brightness, Ambient and ClockTime
--     are never touched.
--   * 2026-09-26 (Green Hill map): the sunny tropical look (Shared/RaceTropicalLook: the
--     Atmosphere, its own colour grade, the arena's water, never blendLighting's properties)
--     blends in inside the same arena box and back out on leaving; it yields at once to the
--     admin sky events (snow, disco, raining tacos), which blend the same Atmosphere.
-- Phones hide the part chevrons and calm the ORB in Gameplay/LowPowerGraphics.
-- No per-frame work: a 0.1 s loop only during the countdown, a 4 Hz check for the arena box
-- (20 Hz only while the look blends, 1.5 s on the way in or out), engine tweens for the bar and
-- the ORB.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local U4 = require(Shared:WaitForChild("Update4Config"))
local RaceTrack = require(Shared:WaitForChild("RaceTrack"))
local RaceTropicalLook = require(Shared:WaitForChild("RaceTropicalLook"))
local RaceFeelTier = require(Shared:WaitForChild("RaceFeelTier"))

local QUEUE = U4.Race.Queue
local LIGHT_OFF = Color3.fromRGB(60, 18, 18)
local LIGHT_RED = Color3.fromRGB(255, 40, 40)
local LIGHT_GREEN = Color3.fromRGB(70, 230, 90)
local STOP_DROP = 3 + 1.2 -- from y 3 to y -1.2 above the floor top
local FOG = { Color = Color3.fromRGB(196, 222, 240), Start = 450, End = 2600 }
local BOX_HALF_X, BOX_S_MIN, BOX_S_MAX = 200, -200, 2300
local ORB_SPIN_SECONDS = 18 -- 360 / 20 degrees a second

local function structure()
	local arena = Workspace:FindFirstChild("RaceArena")
	return arena and arena:FindFirstChild("Structure")
end

----------------------------------------------------------------------
-- The start: gantry lights, STOP bar, StartGate
----------------------------------------------------------------------
local stopHome = nil -- the STOP bar's CFrame at rest
local stopTween = nil
local startedFor = nil -- the goAt whose GO this client has drawn

local function lights(count, color)
	local s = structure()
	local gantry = s and s:FindFirstChild("StartGantry")
	if not gantry then
		return
	end
	for index = 1, 5 do
		local light = gantry:FindFirstChild("Light" .. index)
		if light and light:IsA("BasePart") then
			local want = if index <= count then color else LIGHT_OFF
			if light.Color ~= want then
				light.Color = want
			end
		end
	end
end

local function stopBar()
	local s = structure()
	local bar = s and s:FindFirstChild("StopBar")
	if bar and bar:IsA("BasePart") then
		if not stopHome then
			stopHome = bar.CFrame
		end
		return bar
	end
	return nil
end

local function startGate()
	local s = structure()
	local gate = s and s:FindFirstChild("StartGate")
	return if gate and gate:IsA("BasePart") then gate else nil
end

-- 2026-09-26 (owner): while the Super Sonic vs Eggman event runs (the Workspace attribute SSE_Phase, Shared/
-- SuperSonicEvent Attributes.Phase, is set) the fight uses the race map: its StartGate collides with nobody.
local EVENT_PHASE_ATTRIBUTE = "SSE_Phase"
local function eventRunning(): boolean
	local phase = Workspace:GetAttribute(EVENT_PHASE_ATTRIBUTE)
	return type(phase) == "string" and phase ~= ""
end

-- Ready for the next start: lights off, the bar up, the gate closed (locally; never while the event runs).
local function resetStart()
	startedFor = nil
	lights(0, LIGHT_OFF)
	local bar = stopBar()
	if bar and stopHome then
		if stopTween then
			stopTween:Cancel()
			stopTween = nil
		end
		bar.CFrame = stopHome
	end
	local gate = startGate()
	if gate and not eventRunning() then
		gate.CanCollide = true
	end
end

local function go(goAt)
	if startedFor == goAt then
		return
	end
	startedFor = goAt
	lights(5, LIGHT_GREEN)
	local gate = startGate()
	if gate then
		gate.CanCollide = false
	end
	local bar = stopBar()
	if bar and stopHome then
		if stopTween then
			stopTween:Cancel()
		end
		stopTween = TweenService:Create(bar, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			CFrame = stopHome - Vector3.new(0, STOP_DROP, 0),
		})
		stopTween:Play()
	end
end

local countdownSerial = 0
local function runCountdown()
	countdownSerial += 1
	local serial = countdownSerial
	task.spawn(function()
		while serial == countdownSerial do
			local goAt = tonumber(Workspace:GetAttribute("RaceGoAt"))
			local phase = Workspace:GetAttribute("RacePhase")
			if not goAt or (phase ~= "Countdown" and phase ~= "Running") then
				return
			end
			local now = Workspace:GetServerTimeNow()
			if now >= goAt then
				go(goAt)
				return
			end
			local lit = math.clamp(math.floor(now - (goAt - QUEUE.CountdownSeconds)) + 1, 0, 5)
			lights(lit, LIGHT_RED)
			task.wait(0.1)
		end
	end)
end

local function onPhase()
	local phase = Workspace:GetAttribute("RacePhase")
	if phase == "Staging" then
		countdownSerial += 1
		resetStart()
	elseif phase == "Countdown" then
		resetStart()
		runCountdown()
	elseif phase == "Running" then
		-- The countdown loop missed GO (the arena streamed in late): draw it now.
		local goAt = tonumber(Workspace:GetAttribute("RaceGoAt"))
		if goAt and startedFor ~= goAt then
			go(goAt)
		end
	end
end
Workspace:GetAttributeChangedSignal("RacePhase"):Connect(onPhase)
task.defer(onPhase)

----------------------------------------------------------------------
-- Inside the arena: the ORB's spin and the fog
----------------------------------------------------------------------
local orbTween = nil
local savedFog = nil -- the fog before ours: { Color, Start, End }

local function spinOrb(on)
	if on and not orbTween then
		local arena = Workspace:FindFirstChild("RaceArena")
		local orb = arena and arena:FindFirstChild("RaceOrb")
		local shell = orb and orb:FindFirstChild("Shell")
		if shell and shell:IsA("BasePart") then
			shell.Orientation = Vector3.zero
			orbTween = TweenService:Create(shell, TweenInfo.new(ORB_SPIN_SECONDS, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {
				Orientation = Vector3.new(0, 360, 0),
			})
			orbTween:Play()
		end
	elseif not on and orbTween then
		orbTween:Cancel()
		orbTween = nil
	end
end

local function fog(on)
	if on and not savedFog then
		savedFog = { Color = Lighting.FogColor, Start = Lighting.FogStart, End = Lighting.FogEnd }
		Lighting.FogColor = FOG.Color
		Lighting.FogStart = FOG.Start
		Lighting.FogEnd = FOG.End
	elseif not on and savedFog then
		local saved = savedFog
		savedFog = nil
		-- Only if it is still ours: something else may own Lighting now. (Read back, a colour is
		-- only near what was written.)
		local c = Lighting.FogColor
		local ours = math.abs(c.R - FOG.Color.R) < 0.01 and math.abs(c.G - FOG.Color.G) < 0.01 and math.abs(c.B - FOG.Color.B) < 0.01
			and math.abs(Lighting.FogStart - FOG.Start) < 0.5 and math.abs(Lighting.FogEnd - FOG.End) < 0.5
		if ours then
			Lighting.FogColor = saved.Color
			Lighting.FogStart = saved.Start
			Lighting.FogEnd = saved.End
		end
	end
end

local function insideArena()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	local s, x = RaceTrack.ToLocal(root.Position)
	return math.abs(x) < BOX_HALF_X and s > BOX_S_MIN and s < BOX_S_MAX
		and math.abs(root.Position.Y - RaceTrack.Origin.Y) < 400
end

----------------------------------------------------------------------
-- Inside the arena: the tropical look (2026-09-26)
----------------------------------------------------------------------
local look = RaceTropicalLook.new({
	lighting = Lighting,
	terrain = Workspace:FindFirstChildOfClass("Terrain"),
	now = function()
		return Workspace:GetServerTimeNow()
	end,
	attribute = function(name)
		return Workspace:GetAttribute(name)
	end,
	newGrade = function()
		local grade = Instance.new("ColorCorrectionEffect")
		grade.Name = RaceTropicalLook.GradeName
		grade.Parent = Lighting
		return grade
	end,
	tier = function()
		return (RaceFeelTier.Detect())
	end,
})
-- An admin sky event starting now: the look lets go of everything before the event's first
-- frame saves the Atmosphere it blends from.
for _, name in RaceTropicalLook.AdminSkyAttributes do
	Workspace:GetAttributeChangedSignal(name):Connect(function()
		if RaceTropicalLook.AdminSkyActive(function(attribute)
			return Workspace:GetAttribute(attribute)
		end, Workspace:GetServerTimeNow()) then
			look:Yield()
		end
	end)
end

task.spawn(function()
	local last = os.clock()
	while true do
		local now = os.clock()
		local inside = insideArena()
		fog(inside)
		spinOrb(inside)
		look:SetInside(inside)
		local ok, blending = pcall(look.Step, look, now - last)
		last = now
		task.wait(if ok and blending then 0.05 else 0.25)
	end
end)
