-- Gameplay/RaceArenaWater.server.luau — Update 4 (2026-09-26, owner: "don't leave the Green Hill
-- map in a void, put it on a thin layer of water"). Once Workspace.RaceArena exists, fills a thin
-- layer of Terrain water around it (a sand seabed under it) exactly once per server, from the
-- numbers of Update4Config.Race.Water (track-local studs around Race.Arena.Origin; see there).
--   * Idempotent: Workspace attribute RaceWaterFilled (true once filled), so a second copy of
--     this script or a re-run never fills again.
--   * Kill switch: Workspace.U4Off_RaceWater = true before the fill skips it; set later, it
--     clears the region (Air) and false fills it again. Nothing else ever clears it.
--   * Tolerant: no Terrain, a locked Terrain or a failing FillBlock only warns, once.
--   * Out of the race's way: the water's top is 8 studs under the floor (0..6), the server's
--     ground raycast ignores water (RaceServer: IgnoreWater), the corridor walls keep racers off
--     it, and no race rule reads water. The water's colour and waves are the client's, only while
--     the local player is in the arena (Shared/RaceTropicalLook), so no lobby changes.
-- Each strip of StripStuds of s is one FillBlock with a frame in between: a whole region at once
-- would hitch the server.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local U4 = require(Shared:WaitForChild("Update4Config", 30))
if type(U4) ~= "table" or type(U4.Race) ~= "table" or type(U4.Race.Water) ~= "table" then
	return
end
if type(U4.Flags) ~= "table" or type(U4.Flags.Race) ~= "table" or U4.Flags.Race.Enabled ~= true then
	return
end

local WATER = U4.Race.Water
local ORIGIN: Vector3 = U4.Race.Arena.Origin
local KILL = tostring(U4.KillAttributePrefix or "U4Off_") .. "RaceWater"
local FILLED = "RaceWaterFilled"

local warned = false
local function warnOnce(message)
	if not warned then
		warned = true
		warn("[RaceArenaWater] " .. message)
	end
end

local function material(name): Enum.Material?
	local ok, value = pcall(function()
		return (Enum.Material :: any)[name]
	end)
	return if ok then value else nil
end

-- One layer (track-local y0..y1) of the region, strip by strip. Returns false on any failure.
local function fillLayer(terrain: Terrain, y0: number, y1: number, fill: Enum.Material): boolean
	local strip = math.max(4, tonumber(WATER.StripStuds) or 400)
	local s0 = WATER.SMin
	while s0 < WATER.SMax - 1e-6 do
		local s1 = math.min(s0 + strip, WATER.SMax)
		local centre = Vector3.new(ORIGIN.X, ORIGIN.Y + (y0 + y1) * 0.5, ORIGIN.Z - (s0 + s1) * 0.5)
		local size = Vector3.new(WATER.HalfX * 2, y1 - y0, s1 - s0)
		local ok, err = pcall(function()
			terrain:FillBlock(CFrame.new(centre), size, fill)
		end)
		if not ok then
			warnOnce("FillBlock failed, the race map keeps no water: " .. tostring(err))
			return false
		end
		s0 = s1
		task.wait()
	end
	return true
end

-- Fills (wantWater) or clears the region. Returns whether it worked.
local function apply(wantWater: boolean): boolean
	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	if not terrain then
		warnOnce("no Terrain in this place: the race map keeps no water")
		return false
	end
	local water, seabed, air = material(WATER.Material or "Water"), material(WATER.SeabedMaterial or ""), material("Air")
	if wantWater then
		local ok = water ~= nil and fillLayer(terrain, WATER.Bottom, WATER.Top, water)
		if ok and seabed and tonumber(WATER.SeabedBottom) then
			ok = fillLayer(terrain, WATER.SeabedBottom, WATER.Bottom, seabed)
		end
		if ok then
			Workspace:SetAttribute(FILLED, true)
			print(string.format("[RaceArenaWater] water %d..%d and seabed %s..%d studs under the race floor, %d x %d studs",
				WATER.Bottom, WATER.Top, tostring(WATER.SeabedBottom), WATER.Bottom, WATER.HalfX * 2, WATER.SMax - WATER.SMin))
		end
		return ok
	end
	local bottom = tonumber(WATER.SeabedBottom) or WATER.Bottom
	if air and fillLayer(terrain, bottom, WATER.Top, air) then
		Workspace:SetAttribute(FILLED, false)
		return true
	end
	return false
end

local function killed(): boolean
	return Workspace:GetAttribute(KILL) == true
end

-- Brings the terrain to what the switch and the arena ask for; one pass at a time, and again if
-- the switch moved meanwhile. A failed fill is not retried (it warned).
local busy, failed = false, false
local function settle()
	if busy then
		return
	end
	busy = true
	while not failed do
		local filled = Workspace:GetAttribute(FILLED) == true
		local want = not killed() and Workspace:FindFirstChild("RaceArena") ~= nil
		if want == filled then
			break
		end
		if not apply(want) then
			failed = true
		end
	end
	busy = false
end

Workspace:GetAttributeChangedSignal(KILL):Connect(function()
	task.spawn(settle)
end)

if Workspace:FindFirstChild("RaceArena") then
	task.spawn(settle)
else
	local connection
	connection = Workspace.ChildAdded:Connect(function(child)
		if child.Name == "RaceArena" then
			connection:Disconnect()
			task.spawn(settle)
		end
	end)
end
