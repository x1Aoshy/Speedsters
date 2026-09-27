-- PoseHistory: the last few poses (CFrames) of a moving hazard, by server time.
--
-- The body the server holds is where a runner was about half a ping (plus the interpolation
-- buffer) ago, while every client draws a World 1 obstacle on the shared server clock. The
-- kill backstop must judge that late body against the obstacle as it was THEN, not now
-- (2026-09-25, H5: the hammers already did this; every other group killed runners already past).
-- 12 samples at 30 Hz = 0.4 s, more than the 0.25 s maximum rewind.
--
-- Pure: a ring buffer of preallocated slots, no allocation per push. Lune-safe.
local PoseHistory = {}

export type History = {
	Size: number,
	Count: number,
	Head: number,
	Times: { number },
	Poses: { any },
}

function PoseHistory.new(size: number?): History
	local n = math.max(2, math.floor(tonumber(size) or 12))
	return {
		Size = n,
		Count = 0,
		Head = 0,
		Times = table.create(n, 0),
		Poses = table.create(n, false),
	}
end

-- A push at the same time as the newest sample replaces it. A clock that stepped back (a
-- server time correction) restarts the history instead of leaving it out of order.
function PoseHistory.Push(h: History, t: number, cf: any)
	if type(t) ~= "number" or t ~= t or cf == nil then
		return
	end
	if h.Count > 0 then
		local newest = h.Times[h.Head]
		if t == newest then
			h.Poses[h.Head] = cf
			return
		elseif t < newest then
			h.Count = 0
			h.Head = 0
		end
	end
	h.Head = h.Head % h.Size + 1
	h.Times[h.Head] = t
	h.Poses[h.Head] = cf
	h.Count = math.min(h.Count + 1, h.Size)
end

-- The pose at time t: blended between the two samples around it, clamped to the oldest and
-- the newest. nil when nothing was pushed yet.
function PoseHistory.At(h: History?, t: number): any
	if not h or h.Count == 0 then
		return nil
	end
	local size = h.Size
	local newerIndex = h.Head
	local newerTime = h.Times[newerIndex]
	if type(t) ~= "number" or t ~= t or t >= newerTime then
		return h.Poses[newerIndex]
	end
	for _ = 2, h.Count do
		local olderIndex = (newerIndex - 2) % size + 1
		local olderTime = h.Times[olderIndex]
		if olderTime <= t then
			local span = newerTime - olderTime
			local alpha = if span > 0 then (t - olderTime) / span else 1
			return h.Poses[olderIndex]:Lerp(h.Poses[newerIndex], alpha)
		end
		newerIndex = olderIndex
		newerTime = olderTime
	end
	return h.Poses[newerIndex] -- older than the oldest sample: the oldest
end

-- The time span held (newest - oldest), for tests and debugging.
function PoseHistory.Span(h: History?): number
	if not h or h.Count < 2 then
		return 0
	end
	local oldest = (h.Head - h.Count) % h.Size + 1
	return h.Times[h.Head] - h.Times[oldest]
end

return PoseHistory
