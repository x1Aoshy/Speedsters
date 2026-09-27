--!strict
-- ReplicatedStorage/Shared/RaceFeelTier.luau — Update 4 race feel tiers (race_fx, 2026-09-25).
-- Phones are ~63% of the players at ~24 FPS and render-bound, so the race poses and VFX pick
-- one of three budgets once per race, at the Set pose (the countdown is when the CPU is idle):
--   High = not touch-only and >= 45 FPS;
--   Mid  = touch-only at >= 30 FPS, or any device at 25-45;
--   Low  = touch-only under 30, any device under 25, or a graphics quality set by hand <= 3.
-- FPS is an EMA of 1/dt over at least MinSeconds; before that the device decides (a phone
-- guesses Low: the safe side). Classify, Budget and the meter are pure, so the Lune tests
-- check them; Detect reads the device (pcall: UserSettings is not there in every context).
local U4: any = if typeof(script) == "Instance"
	then require((script :: any).Parent:WaitForChild("Update4Config", 10))
	else require("./Update4Config")

local FEEL = U4.Race.Feel
local POSE = FEEL.Pose

local RaceFeelTier = {}

RaceFeelTier.Tiers = { "High", "Mid", "Low" }
RaceFeelTier.MinSeconds = 2 -- seconds of samples before the meter is trusted
RaceFeelTier.EmaSeconds = 1 -- the meter's time constant
RaceFeelTier.HighFps = 45
RaceFeelTier.MidFps = 25
RaceFeelTier.TouchMidFps = 30
RaceFeelTier.LowQuality = 3 -- SavedQualityLevel 1-3 set by hand = Low

-- 2026-09-26 (owner): the race VFX budget per tier (Shared/RaceVfx, Shared/RaceScreenFx), from
-- Update4Config Feel.Lightning / AfterImage / Rings / Screen. No particles and no bubble any
-- more. "Own" is the local racer, "Other" each other racer:
--   Arcs x ArcPoints: the electric chains (Attachments + Beams) on the body, re-rolled ArcHz
--     times a second; the others' only on the nearest OthersArcCap inside ArcDistance.
--   Lights: the torso PointLight (the zone glow and the GO / pad / finish flash), High own only.
--   GhostEvery / GhostLife / GhostPool: the after-images (stamp cadence, life, pool of
--     silhouettes); the others share OthersGhostPool, for the nearest OthersGhostCap inside
--     GhostDistance (Low: the own racer only).
--   RingPool: the shared shock rings; another racer's inside RingDistance.
--   ScreenLines / ScreenHz / ScreenShockRings: the own racer's screen effects.
--   Distance: the furthest another racer shows anything.
local function pool(life: number, every: number?): number
	if not every or every <= 0 then
		return 0
	end
	return math.ceil(life / every - 1e-9) + 1
end

local CPU_MS = { High = 0.6, Mid = 0.35, Low = 0.25 }

local function tierBudget(name: string): any
	local lightning, ghost, rings, screen = FEEL.Lightning, FEEL.AfterImage, FEEL.Rings, FEEL.Screen
	local life = ghost.Life[name]
	local ownEvery = ghost.Every[name]
	local othersNear = ghost.OthersNearest[name] or 0
	local otherEvery = if othersNear > 0 then ghost.OtherEvery[name] else nil
	local otherArcs = lightning.OtherArcs[name] or 0
	return {
		Own = {
			Arcs = lightning.Arcs[name], ArcPoints = lightning.Points[name], ArcHz = lightning.Hz[name],
			Lights = if name == "High" then 1 else 0,
			GhostEvery = ownEvery, GhostLife = life, GhostPool = pool(life, ownEvery),
		},
		Other = {
			Distance = math.max(lightning.OtherDistance[name] or 0, ghost.OtherDistance[name] or 0, rings.OtherDistance[name] or 0),
			Arcs = otherArcs, ArcPoints = if otherArcs > 0 then 4 else 0, ArcHz = lightning.OtherHz[name] or 0,
			ArcDistance = lightning.OtherDistance[name] or 0,
			GhostEvery = otherEvery, GhostLife = life, GhostDistance = ghost.OtherDistance[name] or 0,
		},
		OthersArcCap = lightning.OthersNearest[name] or 0,
		OthersGhostCap = othersNear,
		OthersGhostPool = othersNear * pool(life, otherEvery),
		RingPool = rings.Pool[name],
		RingDistance = rings.OtherDistance[name] or 0,
		ScreenLines = screen.Lines[name],
		ScreenHz = screen.Hz[name],
		ScreenShockRings = screen.ShockRings[name],
		CpuMs = CPU_MS[name],
	}
end

local BUDGETS = {
	High = tierBudget("High"),
	Mid = tierBudget("Mid"),
	Low = tierBudget("Low"),
}

local function copy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for key, item in value do
		out[key] = copy(item)
	end
	return out
end

local function valid(tier: any): string
	return if tier == "High" or tier == "Mid" or tier == "Low" then tier else "Low"
end
RaceFeelTier.Valid = valid

-- The quality level a player set by hand (1-10), or nil for Automatic / unknown.
function RaceFeelTier.HandQuality(level: any): number?
	local n = tonumber(level)
	if n == nil or n ~= n or n < 1 then
		return nil
	end
	return math.clamp(math.floor(n), 1, 10)
end

-- touchOnly: TouchEnabled and not KeyboardEnabled (as LowPowerGraphics). fps: nil when the
-- meter is not ready yet. quality: HandQuality (nil = Automatic).
function RaceFeelTier.Classify(touchOnly: boolean, fps: number?, quality: number?): string
	if quality ~= nil and quality <= RaceFeelTier.LowQuality then
		return "Low"
	end
	local rate = tonumber(fps)
	if rate == nil or rate ~= rate then
		return if touchOnly then "Low" else "Mid"
	end
	if touchOnly then
		return if rate >= RaceFeelTier.TouchMidFps then "Mid" else "Low"
	end
	if rate >= RaceFeelTier.HighFps then
		return "High"
	elseif rate >= RaceFeelTier.MidFps then
		return "Mid"
	end
	return "Low"
end

-- A fresh copy of the tier's budget (callers may keep it). `quality` (the hand-set graphics
-- level) is kept for the callers; the tier already accounts for it (Classify).
function RaceFeelTier.Budget(tier: string?, quality: number?): any
	local name = valid(tier)
	local budget = copy(BUDGETS[name])
	budget.Tier = name
	budget.Lod = copy(POSE.Lod[name])
	budget.StrideCap = POSE.StrideCap[name]
	return budget
end

----------------------------------------------------------------------
-- FPS meter (EMA of 1/dt)
----------------------------------------------------------------------
export type Meter = { Fps: number?, Seconds: number }

function RaceFeelTier.NewMeter(): Meter
	return { Fps = nil, Seconds = 0 }
end

function RaceFeelTier.Sample(meter: Meter, dt: number)
	local step = tonumber(dt)
	if step == nil or step ~= step or step <= 0 or step > 1 then
		return -- a hitch (loading, alt-tab) says nothing about the frame rate
	end
	local fps = math.clamp(1 / step, 1, 240)
	if meter.Fps == nil then
		meter.Fps = fps
	else
		local k = 1 - math.exp(-step / RaceFeelTier.EmaSeconds)
		meter.Fps = (meter.Fps :: number) + (fps - (meter.Fps :: number)) * k
	end
	meter.Seconds += step
end

function RaceFeelTier.Reading(meter: Meter): number?
	return if meter.Seconds >= RaceFeelTier.MinSeconds then meter.Fps else nil
end

----------------------------------------------------------------------
-- Device (Roblox only)
----------------------------------------------------------------------
function RaceFeelTier.TouchOnly(): boolean
	if typeof(game) ~= "Instance" then
		return false
	end
	local ok, touchOnly = pcall(function()
		local input = game:GetService("UserInputService")
		return input.TouchEnabled and not input.KeyboardEnabled
	end)
	return ok and touchOnly == true
end

function RaceFeelTier.DeviceQuality(): number?
	local ok, level = pcall(function()
		return (UserSettings() :: any).GameSettings.SavedQualityLevel.Value
	end)
	return if ok then RaceFeelTier.HandQuality(level) else nil
end

-- The tier for this device now, from a meter (or nil), and the hand-set quality.
function RaceFeelTier.Detect(meter: Meter?): (string, number?)
	local quality = RaceFeelTier.DeviceQuality()
	local fps = if meter then RaceFeelTier.Reading(meter) else nil
	return RaceFeelTier.Classify(RaceFeelTier.TouchOnly(), fps, quality), quality
end

return RaceFeelTier
