-- audit/u4_race_board.luau (Update 4, titles_boards, 2026-09-25; retired 2026-09-26)
-- 2026-09-25 this helper cloned the 8 Wins_* MeshParts of the lobby's `leaderboard1` model as a
-- physical "FASTEST RACERS" board (Race_*, stamped U4Asset "RaceBoard") one row step past the
-- Wins board. 2026-09-26 (owner): the race records are the digital holo board beside The Flash
-- now (Shared/FlashGate, Gameplay/FlashGateClient), so the build no longer places that board:
-- Remove takes out the stamped Race_* parts (the next build clears them from the three places)
-- and leaves any Race_* part without the stamp where it is (someone else's; a note names it).
-- GlobalLeaderboards keeps its Race category (Optional: with no Race_* parts it binds nothing),
-- and the race titles are fed by Services/Race/RaceLeaderboard instead.
-- Kept for the Flash gate's checks: PortalView (the world-portal flight's sight lines) and the
-- exact box helpers. CFrame arithmetic only (Lune has no GetPivot, and its CFrame.lookAt is wrong).
local roblox = require("@lune/roblox")
local Vector3, CFrame = roblox.Vector3, roblox.CFrame

local Board = {}

Board.Stamp = "RaceBoard"
Board.Prefix = "Race_"
Board.Suffixes = {
	"LeaderboardFrame",
	"LeaderboardScreen",
	"LeaderboardScreenBorder",
	"ChampionStandTop",
	"ChampionStandTopOutline",
	"ChampionPillarColumn",
	"ChampionPillarBase",
	"ChampionPillarOutline",
}

local function findModel(dm)
	local workspace = dm:GetService("Workspace")
	for _, descendant in workspace:GetDescendants() do
		if descendant.Name == "leaderboard1" and descendant:IsA("Model") then
			return descendant
		end
	end
	return nil
end
Board.FindModel = findModel

-- Oriented boxes ------------------------------------------------------------------------------
local function boxOf(cframe, size)
	return {
		C = cframe.Position,
		A = { cframe.XVector, cframe.YVector, cframe.ZVector },
		H = { size.X / 2, size.Y / 2, size.Z / 2 },
	}
end

local function containsPoint(box, point)
	local offset = point - box.C
	for axis = 1, 3 do
		if math.abs(offset:Dot(box.A[axis])) > box.H[axis] + 1e-4 then
			return false
		end
	end
	return true
end

local function radiusOn(box, axis)
	return box.H[1] * math.abs(box.A[1]:Dot(axis)) + box.H[2] * math.abs(box.A[2]:Dot(axis))
		+ box.H[3] * math.abs(box.A[3]:Dot(axis))
end

-- Separating axis test: how deep the boxes overlap (the smallest overlap over all axes; 0 or
-- less when they are apart).
local function overlapDepth(a, b)
	local between = b.C - a.C
	local axes = { a.A[1], a.A[2], a.A[3], b.A[1], b.A[2], b.A[3] }
	for i = 1, 3 do
		for j = 1, 3 do
			local cross = a.A[i]:Cross(b.A[j])
			if cross.Magnitude > 1e-6 then
				table.insert(axes, cross.Unit)
			end
		end
	end
	local depth = math.huge
	for _, axis in axes do
		depth = math.min(depth, radiusOn(a, axis) + radiusOn(b, axis) - math.abs(between:Dot(axis)))
		if depth <= 0 then
			return depth
		end
	end
	return depth
end

local function lowY(box)
	return box.C.Y - radiusOn(box, Vector3.new(0, 1, 0))
end

-- Whether the segment a -> b passes through the box grown by `pad` studs (slab test).
local function segmentHitsBox(a, b, box, pad)
	local t0, t1 = 0, 1
	for axis = 1, 3 do
		local from = (a - box.C):Dot(box.A[axis])
		local delta = (b - a):Dot(box.A[axis])
		local half = box.H[axis] + pad
		if math.abs(delta) < 1e-6 then
			if math.abs(from) > half then
				return false
			end
		else
			local n, f = (-half - from) / delta, (half - from) / delta
			if n > f then
				n, f = f, n
			end
			t0, t1 = math.max(t0, n), math.min(t1, f)
			if t0 > t1 then
				return false
			end
		end
	end
	return true
end

-- The world-portal flight (UI/WorldPortalCinematic, Shared/WorldPortalShot) films the lobby portal
-- from in front of it; nothing may stand on that line of sight (audit/test_fable_tutorial_portal).
-- Returns the camera's sight lines as { from, to } segments, sampled like that test.
Board.ViewPad = 2
function Board.PortalView(worldKey)
	local worldIndex = ({ World1 = 1, World2 = 2, World3 = 3 })[worldKey]
	local fs = require("@lune/fs")
	local luau = require("@lune/luau")
	local ok, Shot = pcall(function()
		return luau.load(fs.readFile("src/common/ReplicatedStorage/Shared/WorldPortalShot.luau"), {
			debugName = "WorldPortalShot",
			environment = { Vector3 = Vector3, CFrame = CFrame, math = math, table = table, type = type, typeof = typeof, tonumber = tonumber },
		})()
	end)
	local fallback = ok and worldIndex and Shot.Fallback and Shot.Fallback[worldIndex]
	if not fallback then
		return {}
	end
	local segments = {}
	for step = 0, 40 do
		table.insert(segments, { fallback.Position, Shot.Eye(fallback.Position, fallback.Front, step / 40) })
	end
	return segments
end

-- The Race_* parts of the old board anywhere in Workspace: { stamped = {...}, foreign = {...} }.
function Board.Find(dm)
	local found = { stamped = {}, foreign = {} }
	for _, descendant in dm:GetService("Workspace"):GetDescendants() do
		if descendant:IsA("BasePart") and string.sub(descendant.Name, 1, #Board.Prefix) == Board.Prefix then
			if descendant:GetAttribute("U4Asset") == Board.Stamp then
				table.insert(found.stamped, descendant)
			else
				table.insert(found.foreign, descendant)
			end
		end
	end
	return found
end

-- 2026-09-26: takes the old board out of a place: every Race_* part stamped U4Asset "RaceBoard"
-- (the ones this helper placed). A Race_* part without the stamp stays, with a note. Returns the
-- number removed. Idempotent.
function Board.Remove(dm, notes)
	local found = Board.Find(dm)
	for _, part in found.stamped do
		part.Parent = nil
	end
	if type(notes) == "table" then
		if #found.stamped > 0 then
			table.insert(notes, string.format("old race board removed (%d Race_* parts; the holo board beside The Flash replaces it)", #found.stamped))
		end
		for _, part in found.foreign do
			table.insert(notes, "kept " .. part:GetFullName() .. " (no U4Asset stamp: not ours)")
		end
	end
	return #found.stamped
end

-- Diagnostics for tests: the Race_* parts found in `model` (by suffix).
function Board.RaceParts(model)
	local out = {}
	for _, suffix in Board.Suffixes do
		local found = model:FindFirstChild(Board.Prefix .. suffix, true)
		out[suffix] = if found and found:IsA("BasePart") then found else nil
	end
	return out
end

Board._internal = { boxOf = boxOf, overlapDepth = overlapDepth, containsPoint = containsPoint, lowY = lowY,
	segmentHitsBox = segmentHitsBox, radiusOn = radiusOn }

return Board
