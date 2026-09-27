-- ReplicatedStorage/Shared/RaceTropicalLook.luau — Update 4 (2026-09-26, owner: the Green Hill
-- race should look sunny and tropical). A client-side blend, used by
-- Gameplay/RaceArenaVisuals, that only exists while the local player is inside the race arena:
--   * the Atmosphere already in Lighting (the server's ReferenceClip one): clearer and bluer;
--   * its own ColorCorrectionEffect "RaceTropicalGrade" (created on the way in, destroyed on the
--     way out; it stacks with the map's own grade): a little more saturation and contrast;
--   * Terrain water (the arena's thin layer, Gameplay/RaceArenaWater): turquoise, calm;
--   * a Clouds object only if the place already has one, and never on Low phones.
-- Blended in and out over BlendSeconds from the values it found (the "base"), and put back on
-- the way out, each property only if it still holds what this last wrote: anything else that
-- changed it meanwhile owns it now. Lighting's Brightness, Ambient, OutdoorAmbient and ClockTime
-- are never touched (Admin/AdminAbuseEffects' blendLighting owns them), and the admin sky events
-- (snow, disco, raining tacos: they blend the same Atmosphere and Clouds from a saved copy) win:
-- while one runs, and for HoldAfterEventSeconds after (their own blend-out), the look stays off;
-- Yield() drops it at once (RaceArenaVisuals calls it from the events' attribute signals, before
-- the event's first frame saves its copy). No per-frame work: RaceArenaVisuals steps it from its
-- arena-box loop (20 Hz only while the weight moves).
-- Pure: every Roblox object comes in through `deps`, so the Lune tests drive it with fakes.
local Color3 = Color3
if Color3 == nil then
	-- Lune: the datatype comes from @lune/roblox (the dynamic require keeps Script Analysis quiet).
	local lateRequire: any = require
	local ok, roblox = pcall(lateRequire, "@lune/roblox")
	if ok and type(roblox) == "table" then
		Color3 = roblox.Color3
	end
end

local Look = {}
Look.BlendSeconds = 1.5
Look.HoldAfterEventSeconds = 6
Look.AdminSkyAttributes = { "AdminSnowUntil", "AdminDiscoUntil", "AdminRainingTacosUntil" }
Look.GradeName = "RaceTropicalGrade"
-- blendLighting's (never written here).
Look.NeverTouched = { "Brightness", "Ambient", "OutdoorAmbient", "ClockTime" }

Look.Targets = {
	Atmosphere = {
		Density = 0.15, Haze = 0.3, Glare = 0.2,
		Color = Color3.fromRGB(186, 226, 255), Decay = Color3.fromRGB(92, 150, 212),
	},
	Grade = { Brightness = 0.02, Contrast = 0.06, Saturation = 0.12, TintColor = Color3.fromRGB(255, 251, 240) },
	Water = {
		WaterColor = Color3.fromRGB(24, 170, 190), WaterTransparency = 0.55, WaterWaveSize = 0.08,
		WaterWaveSpeed = 8, WaterReflectance = 0.4,
	},
	Clouds = { Cover = 0.45, Density = 0.55, Color = Color3.fromRGB(255, 255, 255) },
}
-- The grade effect starts from "no change".
Look.GradeNeutral = { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1) }

local function isColor(value: any): boolean
	return typeof(value) == "Color3"
end

local function lerp(a: any, b: any, t: number): any
	if isColor(a) and isColor(b) then
		return a:Lerp(b, t)
	end
	return a + (b - a) * t
end

-- Read back, a value is only near what was written (colours are 8-bit, numbers float32).
local function same(a: any, b: any): boolean
	if isColor(a) and isColor(b) then
		return math.abs(a.R - b.R) < 0.006 and math.abs(a.G - b.G) < 0.006 and math.abs(a.B - b.B) < 0.006
	end
	if type(a) == "number" and type(b) == "number" then
		return math.abs(a - b) <= 1e-3 * math.max(1, math.abs(a), math.abs(b))
	end
	return a == b
end

local function read(object: any, property: string): (boolean, any)
	return pcall(function()
		return object[property]
	end)
end

local function write(object: any, property: string, value: any): boolean
	return (pcall(function()
		object[property] = value
	end))
end

-- The latest end time of the admin sky events (their Workspace attributes; -inf when none).
function Look.AdminSkyEnd(attribute: (string) -> any): number
	local latest = -math.huge
	for _, name in Look.AdminSkyAttributes do
		local untilTime = tonumber(attribute(name))
		if untilTime ~= nil and untilTime == untilTime then
			latest = math.max(latest, untilTime)
		end
	end
	return latest
end

-- Whether an admin sky event is on (the same test as AdminAbuseEffects: an end time not past).
function Look.AdminSkyActive(attribute: (string) -> any, now: number): boolean
	return Look.AdminSkyEnd(attribute) > now - 1
end

export type Deps = {
	lighting: any,
	terrain: any?,
	now: () -> number,
	attribute: (string) -> any,
	newGrade: () -> any, -- a ColorCorrectionEffect named GradeName, parented to Lighting
	tier: (() -> string)?, -- "High" | "Mid" | "Low" (RaceFeelTier)
}

local Controller = {}
Controller.__index = Controller

function Look.new(deps: Deps)
	return setmetatable({
		deps = deps,
		weight = 0,
		inside = false,
		lastSkyAt = -math.huge,
		session = nil, -- { entries = { { object, property, base, target, last } }, grade = effect? }
	}, Controller)
end

function Controller:SetInside(inside: boolean)
	self.inside = inside == true
end

-- 1 while the look should show, else 0: inside the arena, and no admin sky event running or
-- ended less than HoldAfterEventSeconds ago (its own blend-out).
function Controller:Goal(): number
	local deps = self.deps
	local skyEnd = math.max(self.lastSkyAt, Look.AdminSkyEnd(deps.attribute))
	if not self.inside or deps.now() - skyEnd < Look.HoldAfterEventSeconds then
		return 0
	end
	return 1
end

function Controller:_begin()
	local deps = self.deps
	local entries = {}
	local function control(object: any, targets: { [string]: any })
		if object == nil then
			return
		end
		local properties = {}
		for property in targets do
			table.insert(properties, property)
		end
		table.sort(properties)
		for _, property in properties do
			local ok, base = read(object, property)
			if ok and base ~= nil then
				table.insert(entries, { object = object, property = property, base = base, target = targets[property], last = base })
			end
		end
	end
	local lighting = deps.lighting
	local atmosphere = nil
	pcall(function()
		atmosphere = lighting:FindFirstChildOfClass("Atmosphere")
	end)
	control(atmosphere, Look.Targets.Atmosphere)
	control(deps.terrain, Look.Targets.Water)
	local tier = "Low"
	if deps.tier then
		local ok, value = pcall(deps.tier)
		tier = if ok and type(value) == "string" then value else "Low"
	end
	if tier ~= "Low" and deps.terrain then
		local clouds = nil
		pcall(function()
			clouds = deps.terrain:FindFirstChildOfClass("Clouds")
		end)
		control(clouds, Look.Targets.Clouds)
	end
	local grade = nil
	local ok, effect = pcall(deps.newGrade)
	if ok and effect then
		grade = effect
		for property, value in Look.GradeNeutral do
			write(effect, property, value)
		end
		for property, target in Look.Targets.Grade do
			table.insert(entries, { object = effect, property = property, base = Look.GradeNeutral[property], target = target,
				last = Look.GradeNeutral[property], owned = true })
		end
	end
	self.session = { entries = entries, grade = grade, tier = tier }
	self.appliedWeight = nil
end

-- Writes the blend at the current weight; a property someone else changed is let go.
function Controller:_apply()
	local session = self.session
	if not session then
		return
	end
	for _, entry in session.entries do
		if not entry.released then
			local ok, current = read(entry.object, entry.property)
			if not ok or not same(current, entry.last) then
				entry.released = true
			else
				local value = lerp(entry.base, entry.target, self.weight)
				if write(entry.object, entry.property, value) then
					entry.last = value
				end
			end
		end
	end
end

-- Back to the base (what is still ours), grade removed.
function Controller:_finish()
	local session = self.session
	if not session then
		return
	end
	self.session = nil
	self.appliedWeight = nil
	for _, entry in session.entries do
		if not entry.released and not entry.owned then
			local ok, current = read(entry.object, entry.property)
			if ok and same(current, entry.last) then
				write(entry.object, entry.property, entry.base)
			end
		end
	end
	if session.grade then
		pcall(function()
			session.grade:Destroy()
		end)
	end
end

-- One blend step (dt seconds since the last). Writes only when the weight moved. Returns whether
-- it is still moving (RaceArenaVisuals then steps at 20 Hz instead of 4).
function Controller:Step(dt: number): boolean
	local goal = self:Goal()
	if goal == 0 and self.weight == 0 then
		self:_finish()
		return false
	end
	local rate = math.max(0, tonumber(dt) or 0) / Look.BlendSeconds
	self.weight = if goal > self.weight then math.min(goal, self.weight + rate) else math.max(goal, self.weight - rate)
	if self.weight > 0 then
		if not self.session then
			self:_begin()
		end
		if self.weight ~= self.appliedWeight then
			self:_apply()
			self.appliedWeight = self.weight
		end
	else
		self:_finish()
	end
	return self.weight ~= goal
end

-- An admin sky event started: everything back now, before the event saves its copy.
function Controller:Yield()
	self.lastSkyAt = self.deps.now()
	self.weight = 0
	self:_finish()
end

return Look
