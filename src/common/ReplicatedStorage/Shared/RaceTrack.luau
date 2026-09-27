--!strict
-- ReplicatedStorage/Shared/RaceTrack.luau — Update 4 race track geometry (pure; client, server
-- and Lune tests). Every number is Update4Config.Race.Track.
-- Frame: O = Race.Arena.Origin is the centre of the start line on the floor top; the track runs
-- along -Z (the default look vector of CFrame.new(pos), so no CFrame.lookAt anywhere: it is
-- wrong in Lune). s = O.Z - Z is the distance past the start line, x = X - O.X, y = Y - O.Y.
-- 2026-09-25: y is measured at the HumanoidRootPart; an R6 root stands 3 studs over the floor,
-- so the spike height test (y < tile + 3) is "not jumping".
-- 2026-09-25 (owner: Astra's map has gentle hills): every height test is against the ground
-- under the racer, Ground(s, x), from the current profile (SetProfile; flat by default, the
-- builder's arena). ToLocal's y stays relative to Origin.Y; SpikeAt / SweptSpike / InCorridor /
-- the slots take that y and subtract the ground themselves, so callers did not change. The
-- profile is a grid of heights (studs over Origin.Y) every U4.Race.Ground.Step studs of s in the
-- U4.Race.Ground.Columns, linear in s and across; Encode / Decode turn it into the Workspace
-- attribute RaceGroundProfile (the server's raycast, RaceServer), the same numbers on both sides.
-- Speed pads (U4.Race.Pads): PadsFromParts reads SpeedPad parts into footprints; SweptPad finds
-- the first pad a path crosses with the feet on it.
local Vector3, CFrame = Vector3, CFrame
if Vector3 == nil or CFrame == nil then
	-- Lune: the datatypes come from @lune/roblox (the dynamic require keeps Script Analysis quiet).
	local lateRequire: any = require
	local ok, roblox = pcall(lateRequire, "@lune/roblox")
	if ok and type(roblox) == "table" then
		Vector3, CFrame = roblox.Vector3, roblox.CFrame
	end
end

local U4: any = if typeof(script) == "Instance"
	then require((script :: any).Parent:WaitForChild("Update4Config", 10))
	else require("./Update4Config")

local TRACK = U4.Race.Track
local SPIKES = U4.Race.Spikes
local VALIDATION = U4.Race.Validation
local ORIGIN: Vector3 = U4.Race.Arena.Origin

local RaceTrack = {}

RaceTrack.Origin = ORIGIN
RaceTrack.Length = TRACK.Length
RaceTrack.RunOut = TRACK.RunOut
RaceTrack.Width = TRACK.Width
RaceTrack.Lanes = TRACK.Lanes
RaceTrack.LaneWidth = TRACK.LaneWidth
RaceTrack.StagingDepth = TRACK.StagingDepth
RaceTrack.SlotCount = TRACK.Lanes * #TRACK.SlotRows
-- A root standing on the floor (R6).
RaceTrack.RootHeight = 3

-- Lane centre across the track: -31.5, -22.5, ... 31.5 for 8 lanes of 9.
function RaceTrack.LaneX(lane: number): number
	return -(TRACK.Lanes - 1) * 0.5 * TRACK.LaneWidth + TRACK.LaneWidth * (lane - 1)
end

function RaceTrack.ToLocal(position: Vector3): (number, number, number)
	return ORIGIN.Z - position.Z, position.X - ORIGIN.X, position.Y - ORIGIN.Y
end

function RaceTrack.ToWorld(s: number, x: number, y: number): Vector3
	return Vector3.new(ORIGIN.X + x, ORIGIN.Y + y, ORIGIN.Z - s)
end

----------------------------------------------------------------------
-- The ground profile (2026-09-25, owner: gentle hills)
----------------------------------------------------------------------
local GROUND = U4.Race.Ground
local PADS = U4.Race.Pads
-- Samples from the back of the staging box to the end wall.
RaceTrack.ProfileS0 = -TRACK.StagingDepth
RaceTrack.ProfileS1 = TRACK.Length + TRACK.RunOut
RaceTrack.ProfileStep = GROUND.Step
RaceTrack.ProfileCount = math.floor((RaceTrack.ProfileS1 - RaceTrack.ProfileS0) / GROUND.Step + 0.5) + 1
RaceTrack.ProfileColumns = table.clone(GROUND.Columns)
local MAX_SLOPE_ALLOWANCE = 0.05 -- a map steeper than the contract never opens the envelope more

export type Profile = {
	Step: number,
	S0: number,
	Count: number,
	Columns: { number },
	Heights: { { number } }, -- [column][sample], studs over Origin.Y (multiples of 0.01)
	Flat: boolean,
	Allowance: number, -- the steepest slope's extra path length (sqrt(1 + g^2) - 1)
}

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- Flat, Allowance from the heights (called whenever a profile is made).
local function finish(profile: any): Profile
	local flat, allowance = true, 0
	for _, column in profile.Heights do
		for index, h in column do
			if h ~= 0 then
				flat = false
			end
			local nextH = column[index + 1]
			if nextH then
				local grade = (nextH - h) / profile.Step
				allowance = math.max(allowance, math.sqrt(1 + grade * grade) - 1)
			end
		end
	end
	profile.Flat = flat
	profile.Allowance = math.min(allowance, MAX_SLOPE_ALLOWANCE)
	return profile
end

local function quantize(h: number): number
	local centi = math.floor(math.clamp(h, -GROUND.MaxHeight, GROUND.MaxHeight) * 100 + 0.5)
	return centi / 100
end

function RaceTrack.FlatProfile(): Profile
	local heights = {}
	for column = 1, #RaceTrack.ProfileColumns do
		heights[column] = table.create(RaceTrack.ProfileCount, 0)
	end
	return finish({
		Step = RaceTrack.ProfileStep, S0 = RaceTrack.ProfileS0, Count = RaceTrack.ProfileCount,
		Columns = table.clone(RaceTrack.ProfileColumns), Heights = heights,
	})
end

-- A profile from a sampler(s, x) -> height over Origin.Y (nil = not found: the last good height
-- of that column, 0 at the start). Heights are rounded to 0.01 so Encode/Decode are exact.
function RaceTrack.BuildProfile(sampler: (number, number) -> number?): Profile
	local heights = {}
	for column, x in RaceTrack.ProfileColumns do
		local list = table.create(RaceTrack.ProfileCount, 0)
		local last = 0
		for index = 1, RaceTrack.ProfileCount do
			local s = RaceTrack.ProfileS0 + (index - 1) * RaceTrack.ProfileStep
			local ok, h = pcall(sampler, s, x)
			if ok and finite(h) then
				last = quantize(h :: number)
			end
			list[index] = last
		end
		heights[column] = list
	end
	return finish({
		Step = RaceTrack.ProfileStep, S0 = RaceTrack.ProfileS0, Count = RaceTrack.ProfileCount,
		Columns = table.clone(RaceTrack.ProfileColumns), Heights = heights,
	})
end

-- "RG1;step;s0;count;x1,x2,x3;" then one run-length list per column ("h*n,h*n", h in
-- centi-studs), columns separated by "|". The builder's flat arena is "...;0*547|0*547|0*547".
function RaceTrack.EncodeProfile(profile: Profile): string
	local columns = {}
	for _, x in profile.Columns do
		table.insert(columns, tostring(x))
	end
	local parts = {}
	for _, list in profile.Heights do
		local runs = {}
		local value, count = nil, 0
		for _, h in list do
			local centi = math.floor(h * 100 + 0.5)
			if centi == value then
				count += 1
			else
				if value ~= nil then
					table.insert(runs, value .. "*" .. count)
				end
				value, count = centi, 1
			end
		end
		if value ~= nil then
			table.insert(runs, value .. "*" .. count)
		end
		table.insert(parts, table.concat(runs, ","))
	end
	return string.format("RG1;%s;%s;%d;%s;%s", tostring(profile.Step), tostring(profile.S0), profile.Count,
		table.concat(columns, ","), table.concat(parts, "|"))
end

-- The profile of an encoded string, or nil when anything is off (never throws).
function RaceTrack.DecodeProfile(text: any): Profile?
	if type(text) ~= "string" or #text > 200000 then
		return nil
	end
	local step, s0, count, columnText, body = string.match(text, "^RG1;([%d%.%-]+);([%d%.%-]+);(%d+);([%d%.%-,]+);(.*)$")
	local stepN, s0N, countN = tonumber(step), tonumber(s0), tonumber(count)
	if not (stepN and s0N and countN) or stepN <= 0 or countN < 2 or countN > 5000 then
		return nil
	end
	local columns = {}
	for value in string.gmatch(columnText :: string, "[^,]+") do
		local x = tonumber(value)
		if not x then
			return nil
		end
		table.insert(columns, x)
	end
	local columnBodies = string.split(body :: string, "|")
	if #columns < 1 or #columns > 8 or #columnBodies ~= #columns then
		return nil
	end
	local heights = {}
	for column, runsText in columnBodies do
		local list = {}
		for value, times in string.gmatch(runsText, "(%-?%d+)%*(%d+)") do
			local centi, n = tonumber(value), tonumber(times)
			if not (centi and n) or math.abs(centi) > GROUND.MaxHeight * 100 or #list + n > countN then
				return nil
			end
			for _ = 1, n do
				table.insert(list, centi / 100)
			end
		end
		if #list ~= countN then
			return nil
		end
		heights[column] = list
	end
	return finish({ Step = stepN, S0 = s0N, Count = countN, Columns = columns, Heights = heights })
end

local currentProfile: Profile = RaceTrack.FlatProfile()

-- The profile every height test uses (the server's raycast, or the client's decoded copy).
function RaceTrack.SetProfile(profile: Profile?)
	currentProfile = profile or RaceTrack.FlatProfile()
end

function RaceTrack.GetProfile(): Profile
	return currentProfile
end

-- The ground's height over Origin.Y at (s, x) on a profile (the current one by default).
function RaceTrack.Ground(s: number, x: number, profile: Profile?): number
	local p = profile or currentProfile
	if p.Flat then
		return 0
	end
	local u = math.clamp(((tonumber(s) or 0) - p.S0) / p.Step, 0, p.Count - 1)
	local i = math.floor(u)
	local f = u - i
	local function at(column: number): number
		local list = p.Heights[column]
		local a = list[i + 1]
		local b = list[math.min(i + 2, p.Count)]
		return a + (b - a) * f
	end
	local columns = p.Columns
	local cx = math.clamp(tonumber(x) or 0, columns[1], columns[#columns])
	for column = 1, #columns - 1 do
		local x0, x1 = columns[column], columns[column + 1]
		if cx <= x1 then
			local w = if x1 > x0 then (cx - x0) / (x1 - x0) else 0
			return at(column) + (at(column + 1) - at(column)) * w
		end
	end
	return at(#columns)
end

-- A root's height over the ground under it (y from ToLocal).
function RaceTrack.HeightAboveGround(s: number, x: number, y: number): number
	return y - RaceTrack.Ground(s, x)
end

-- Where a root stands on the ground at (s, x) (a CFrame facing -Z).
function RaceTrack.GroundCFrame(s: number, x: number): CFrame
	return CFrame.new(RaceTrack.ToWorld(s, x, RaceTrack.Ground(s, x) + RaceTrack.RootHeight))
end

-- What a map breaks of the contract (§2b): slopes over MaxSlopeDegrees, steps over
-- MaxStepStuds between samples, a start (staging box and line) or finish that is not flat at
-- Origin.Y. Returns a list of messages (empty = fine).
function RaceTrack.CheckProfile(profile: Profile): { string }
	local issues = {}
	local maxGrade = math.tan(math.rad(GROUND.MaxSlopeDegrees))
	for column, list in profile.Heights do
		for index, h in list do
			local s = profile.S0 + (index - 1) * profile.Step
			local nextH = list[index + 1]
			if nextH then
				local rise = math.abs(nextH - h)
				if rise > GROUND.MaxStepStuds + 1e-6 then
					table.insert(issues, string.format("step of %.2f studs at s %d (x %g)", rise, s, profile.Columns[column]))
				elseif rise / profile.Step > maxGrade + 1e-6 then
					table.insert(issues, string.format("slope of %.1f degrees at s %d (x %g)", math.deg(math.atan(rise / profile.Step)), s, profile.Columns[column]))
				end
			end
			local flatZone = s <= 4 or math.abs(s - TRACK.Length) <= 8
			if flatZone and math.abs(h) > 0.05 then
				table.insert(issues, string.format("not flat at Y = Origin.Y at s %d (x %g): %.2f", s, profile.Columns[column], h))
			end
			if #issues >= 20 then
				return issues
			end
		end
	end
	return issues
end

----------------------------------------------------------------------
-- Speed pads (2026-09-25)
----------------------------------------------------------------------
export type Pad = { s0: number, s1: number, x0: number, x1: number, top: number, boost: number, seconds: number, name: string? }

local function clampNumber(value: any, default: number, low: number, high: number): number
	local n = tonumber(value)
	if n == nil or n ~= n then
		n = default
	end
	return math.clamp(n :: number, low, high)
end

-- A pad's footprint from its part (CFrame, Size, attributes Boost / Seconds): the box of its 8
-- corners in the track frame. Works for a pad yawed or tilted with the ground.
function RaceTrack.PadFromPart(part: any): Pad?
	local ok, pad = pcall(function()
		local cf, size = part.CFrame, part.Size
		local s0, s1, x0, x1, top = math.huge, -math.huge, math.huge, -math.huge, -math.huge
		for _, dx in { -0.5, 0.5 } do
			for _, dy in { -0.5, 0.5 } do
				for _, dz in { -0.5, 0.5 } do
					local corner = cf * Vector3.new(size.X * dx, size.Y * dy, size.Z * dz)
					local s, x, y = RaceTrack.ToLocal(corner)
					s0, s1, x0, x1, top = math.min(s0, s), math.max(s1, s), math.min(x0, x), math.max(x1, x), math.max(top, y)
				end
			end
		end
		return {
			s0 = s0, s1 = s1, x0 = x0, x1 = x1, top = top,
			boost = clampNumber(part:GetAttribute("Boost"), PADS.DefaultBoost, 1, PADS.MaxBoost),
			seconds = clampNumber(part:GetAttribute("Seconds"), PADS.DefaultSeconds, 0.1, PADS.MaxSeconds),
			name = part.Name,
		}
	end)
	return if ok then pad else nil
end

-- Every "SpeedPad" part of a folder (RaceArena.SpeedPads), sorted along the track, at most
-- MaxPads.
function RaceTrack.PadsFromParts(parts: { any }): { Pad }
	local list = {}
	for _, part in parts do
		local isPad = false
		pcall(function()
			isPad = part:IsA("BasePart") and part.Name == "SpeedPad"
		end)
		if isPad then
			local pad = RaceTrack.PadFromPart(part)
			if pad and pad.s1 > pad.s0 and pad.x1 > pad.x0 then
				table.insert(list, pad)
			end
		end
	end
	table.sort(list, function(a, b)
		return a.s0 < b.s0
	end)
	while #list > PADS.MaxPads do
		table.remove(list)
	end
	return list
end

-- The pads as plain numbers for a remote (the Staged payload) and back (sanitised).
function RaceTrack.PadsToPayload(pads: { Pad }): { { number } }
	local out = {}
	for _, pad in pads do
		table.insert(out, { pad.s0, pad.s1, pad.x0, pad.x1, pad.top, pad.boost, pad.seconds })
	end
	return out
end

function RaceTrack.PadsFromPayload(payload: any): { Pad }
	local list = {}
	if type(payload) ~= "table" then
		return list
	end
	for _, row in payload do
		if type(row) == "table" and #list < PADS.MaxPads then
			local ok = true
			for k = 1, 7 do
				ok = ok and finite(row[k])
			end
			if ok and row[2] > row[1] and row[4] > row[3] then
				table.insert(list, {
					s0 = row[1], s1 = row[2], x0 = row[3], x1 = row[4], top = row[5],
					boost = math.clamp(row[6], 1, PADS.MaxBoost), seconds = math.clamp(row[7], 0.1, PADS.MaxSeconds),
				})
			end
		end
	end
	return list
end

-- The first pad the root's path (s0,x0,y0) -> (s1,x1,y1) crosses with the feet on it: s and x
-- inside the footprint grown by `margin`, the feet (root - RootHeight) within FeetBelow..
-- FeetAbove (+ margin) of the pad's top where the path enters it. Returns the pad and the
-- fraction of the path where it enters (0 when it starts on the pad).
function RaceTrack.SweptPad(pads: { Pad }?, s0: number, x0: number, y0: number, s1: number, x1: number, y1: number, margin: number?): (Pad?, number)
	if not pads or #pads == 0 then
		return nil, 0
	end
	local m = tonumber(margin) or 0
	local ds, dx = s1 - s0, x1 - x0
	local best, bestT = nil, math.huge
	for _, pad in pads do
		if math.max(s0, s1) >= pad.s0 - m and math.min(s0, s1) <= pad.s1 + m then
			local low, high = 0, 1
			local hit = true
			for axis = 1, 2 do
				local origin = if axis == 1 then s0 else x0
				local delta = if axis == 1 then ds else dx
				local lo = (if axis == 1 then pad.s0 else pad.x0) - m
				local hi = (if axis == 1 then pad.s1 else pad.x1) + m
				if math.abs(delta) < 1e-9 then
					if origin < lo or origin > hi then
						hit = false
						break
					end
				else
					local a, b = (lo - origin) / delta, (hi - origin) / delta
					if a > b then
						a, b = b, a
					end
					low, high = math.max(low, a), math.min(high, b)
					if low > high then
						hit = false
						break
					end
				end
			end
			if hit and low < bestT then
				local feet = y0 + (y1 - y0) * low - RaceTrack.RootHeight
				local rel = feet - pad.top
				if rel >= -(PADS.FeetBelow + m) and rel <= PADS.FeetAbove + m then
					best, bestT = pad, low
				end
			end
		end
	end
	return best, if best then bestT else 0
end

-- Grid slot i (1..16): row A (s -10) holds slots 1-8, row B (s -22) slots 9-16.
function RaceTrack.SlotLocal(index: number): (number, number)
	local lanes = TRACK.Lanes
	local i = math.clamp(math.floor(tonumber(index) or 1), 1, RaceTrack.SlotCount)
	local row = math.ceil(i / lanes)
	local lane = ((i - 1) % lanes) + 1
	return TRACK.SlotRows[row], RaceTrack.LaneX(lane)
end

function RaceTrack.SlotPosition(index: number): Vector3
	local s, x = RaceTrack.SlotLocal(index)
	return RaceTrack.ToWorld(s, x, RaceTrack.Ground(s, x) + RaceTrack.RootHeight)
end

-- Facing -Z (down the track): the default orientation of CFrame.new.
function RaceTrack.SlotCFrame(index: number): CFrame
	return CFrame.new(RaceTrack.SlotPosition(index))
end

-- Where Race Gate joiners wait for the next race: behind the grid, inside the staging box.
function RaceTrack.WaitCFrame(seed: number?): CFrame
	local lane = ((math.floor(tonumber(seed) or 0) % TRACK.Lanes) + TRACK.Lanes) % TRACK.Lanes + 1
	return RaceTrack.GroundCFrame(-40, RaceTrack.LaneX(lane))
end

function RaceTrack.DistanceLeft(s: number): number
	return math.max(0, TRACK.Length - s)
end

-- y from ToLocal; the height limit is over the ground under the racer (2026-09-25).
function RaceTrack.InCorridor(s: number, x: number, y: number): boolean
	return math.abs(x) <= VALIDATION.CorridorHalfWidth
		and s >= VALIDATION.CorridorSMin and s <= VALIDATION.CorridorSMax
		and y - RaceTrack.Ground(s, x) <= VALIDATION.CorridorYMax
end

-- Spike tiles: 4 fields of 2 rows; the blocked lanes always leave 4 free lanes per row.
-- 2026-09-26 (owner: spaced and staggered): a field has as many rows as SpikeBlocked lists for
-- it (2 or 3), SpikeRowGap (90) apart; consecutive rows are complementary (no straight lane is
-- free through two rows), every row leaves 4 lanes free.
export type SpikeTile = { s: number, x: number, field: number, row: number, lane: number }
export type SpikeRow = { s: number, field: number, row: number, blocked: { number }, free: { number } }
local tiles: { SpikeTile } = {}
local tilesByField: { { SpikeTile } } = {}
local rows: { SpikeRow } = {}
local fieldEnd: { number } = {} -- the s of each field's last row
for field, s0 in TRACK.SpikeFields do
	tilesByField[field] = {}
	fieldEnd[field] = s0
	local fieldRows = TRACK.SpikeBlocked[field] or {}
	for row, blocked in fieldRows do
		if #blocked > 0 then
			local s = s0 + (row - 1) * TRACK.SpikeRowGap
			fieldEnd[field] = math.max(fieldEnd[field], s)
			local isBlocked, free = {}, {}
			for _, lane in blocked do
				isBlocked[lane] = true
				local tile = { s = s, x = RaceTrack.LaneX(lane), field = field, row = row, lane = lane }
				table.insert(tiles, tile)
				table.insert(tilesByField[field], tile)
			end
			for lane = 1, TRACK.Lanes do
				if not isBlocked[lane] then
					table.insert(free, lane)
				end
			end
			table.insert(rows, { s = s, field = field, row = row, blocked = table.clone(blocked), free = free })
		end
	end
end
table.sort(rows, function(a, b)
	return a.s < b.s
end)

function RaceTrack.SpikeTiles(): { SpikeTile }
	return tiles
end

-- Every spike row along the track (sorted by s): its s, field, row, blocked and free lanes.
function RaceTrack.SpikeRows(): { SpikeRow }
	return rows
end

-- True when s is inside a spike field (its first row to its last) grown by `margin` studs (the
-- builder keeps its chevrons off the fields).
function RaceTrack.InSpikeField(s: number, margin: number?): boolean
	local m = tonumber(margin) or 0
	for field, s0 in TRACK.SpikeFields do
		if s >= s0 - m and s <= fieldEnd[field] + m then
			return true
		end
	end
	return false
end

-- Half extent of the hit box around a tile centre: tile/2 - inset + the character's half width.
function RaceTrack.SpikeReach(shrink: number?): number
	return TRACK.SpikeTile * 0.5 - SPIKES.HitInset + SPIKES.CharacterHalfWidth - (tonumber(shrink) or 0)
end

function RaceTrack.SpikeHeight(): number
	return TRACK.SpikeTileHeight + SPIKES.MaxHeightAbove
end

-- The fields whose rows can be reached from [sLow, sHigh].
local function fieldsNear(sLow: number, sHigh: number, reach: number): { number }
	local out = {}
	for field, s0 in TRACK.SpikeFields do
		if sHigh >= s0 - reach and sLow <= fieldEnd[field] + reach then
			table.insert(out, field)
		end
	end
	return out
end

-- y from ToLocal: the spike height is over the ground under the racer (2026-09-25).
function RaceTrack.SpikeAt(s: number, x: number, y: number, shrink: number?): SpikeTile?
	if y - RaceTrack.Ground(s, x) >= RaceTrack.SpikeHeight() then
		return nil
	end
	local reach = RaceTrack.SpikeReach(shrink)
	if reach <= 0 then
		return nil
	end
	for _, field in fieldsNear(s, s, reach) do
		for _, tile in tilesByField[field] do
			if math.abs(x - tile.x) <= reach and math.abs(s - tile.s) <= reach then
				return tile
			end
		end
	end
	return nil
end

-- The first tile the segment (s0,x0) -> (s1,x1) crosses (slab test against the hit box);
-- both height samples (y from ToLocal, measured over the ground under each: 2026-09-25) must be
-- under the spike height (a jump over the row clears it).
function RaceTrack.SweptSpike(s0: number, x0: number, s1: number, x1: number, y0: number, y1: number, shrink: number?): SpikeTile?
	local height = RaceTrack.SpikeHeight()
	if y0 - RaceTrack.Ground(s0, x0) >= height or y1 - RaceTrack.Ground(s1, x1) >= height then
		return nil
	end
	local reach = RaceTrack.SpikeReach(shrink)
	if reach <= 0 then
		return nil
	end
	local ds, dx = s1 - s0, x1 - x0
	local best: SpikeTile? = nil
	local bestT = math.huge
	for _, field in fieldsNear(math.min(s0, s1), math.max(s0, s1), reach) do
		for _, tile in tilesByField[field] do
			local low, high = 0, 1
			local hit = true
			for axis = 1, 2 do
				local origin = if axis == 1 then s0 - tile.s else x0 - tile.x
				local delta = if axis == 1 then ds else dx
				if math.abs(delta) < 1e-9 then
					if math.abs(origin) > reach then
						hit = false
						break
					end
				else
					local a, b = (-reach - origin) / delta, (reach - origin) / delta
					if a > b then
						a, b = b, a
					end
					low, high = math.max(low, a), math.min(high, b)
					if low > high then
						hit = false
						break
					end
				end
			end
			if hit and low < bestT then
				best, bestT = tile, low
			end
		end
	end
	return best
end

----------------------------------------------------------------------
-- Standing height and ground adhesion (2026-09-26, owner: Sonic Dash speeds)
----------------------------------------------------------------------
local ADHESION = U4.Race.Adhesion

-- Where a standing root sits over the floor: an R15 root's HipHeight plus half the root, an R6
-- root's 2-stud legs plus half the root plus its HipHeight (0, or a skin's lift such as the
-- Silver Surfer's board). rigType: "R6" / "R15" (Enum name). Anything odd = RootHeight.
function RaceTrack.StandHeight(rigType: any, hipHeight: any, rootSizeY: any): number
	local hip = tonumber(hipHeight) or 0
	local half = (tonumber(rootSizeY) or 2) * 0.5
	if hip ~= hip or half ~= half then
		return RaceTrack.RootHeight
	end
	local stand = if tostring(rigType) == "R6" then 2 + half + hip else hip + half
	if not (stand > 0.5 and stand < 20) then
		return RaceTrack.RootHeight
	end
	return stand
end

-- How far a racer's standing root is over RootHeight (0..MaxLift). The spike and pad height
-- tests take it off the root's y, so a taller avatar or a hovering board is no spike immunity;
-- never negative, so a racer can never make the spikes reach higher than for everyone else.
function RaceTrack.RootLift(standHeight: any): number
	local stand = tonumber(standHeight)
	if stand == nil or stand ~= stand then
		return 0
	end
	return math.clamp(stand - RaceTrack.RootHeight, 0, ADHESION.MaxLift)
end

-- The upward speed (studs/s) a racer's root may have now, not jumping: the ground's own rise
-- along its horizontal motion (the profile's grade over LookSeconds of travel, 1..MaxLook studs
-- ahead) minus Pull x how far the root floats over its standing height past DeadBand (a root
-- under it may rise at Pull x the gap: the humanoid gets back up). Returns vy capped, or vy
-- itself when the root is more than SnapStuds over the ground (a real fall, another racer's
-- head: physics decides). Never adds upward speed. (s, x, y) from ToLocal; vs, vx the velocity
-- along s (-Z) and x; stand = StandHeight.
function RaceTrack.AdhesionVelocity(s: number, x: number, y: number, vs: number, vx: number, vy: number, stand: number?): number
	if not (finite(s) and finite(x) and finite(y) and finite(vs) and finite(vx) and finite(vy)) then
		return vy
	end
	local ground = RaceTrack.Ground(s, x)
	local hover = y - ground - (tonumber(stand) or RaceTrack.RootHeight)
	if hover > ADHESION.SnapStuds then
		return vy
	end
	local speed = math.sqrt(vs * vs + vx * vx)
	local rise = 0
	if speed > 1e-3 then
		local look = math.clamp(speed * ADHESION.LookSeconds, 1, ADHESION.MaxLook)
		local ahead = RaceTrack.Ground(s + vs / speed * look, x + vx / speed * look)
		rise = (ahead - ground) / look * speed
	end
	local over = if hover > ADHESION.DeadBand then hover - ADHESION.DeadBand elseif hover < 0 then hover else 0
	return math.min(vy, rise - ADHESION.Pull * over)
end

return RaceTrack
