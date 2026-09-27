-- StarterPlayerScripts/Gameplay/RacePalmWind.client.luau — Update 4 (2026-09-26): the palms of the
-- Green Hill race map sway in the wind. Astra's controller (design/race/Astra_Recta/
-- RacePalmWind.client.luau), reviewed for phones and for robustness; one client script, nothing
-- on the server, no script per palm.
--   * A palm is any set of parts tagged RacePalmWind with WindBase and WindCrown (world
--     Vector3s), WindKind ("trunk" | "canopy"), WindTree (one id per tree; a part without one is
--     a tree of its own) and WindPhase (radians). The whole tree leans about its base by about a
--     degree; canopies also flutter about the crown. audit/u4_greenhill_arena gives these to the
--     part-built palms and to the kit's Kit_*Palm* pieces (a single-mesh palm sways as a trunk).
--   * Only the nearest trees move: 6 within 190 studs of the camera at 20 Hz on touch-only
--     devices, 14 within 380 at 30 Hz elsewhere, picked every 0.5 s. Hidden parts (the
--     RaceDecorLowPower ones on phones) are skipped. A tree that drops out goes back to rest.
--   * Changes from Astra's: every step is one Workspace:BulkMoveTo (not one CFrame write per
--     part), each tree's sway is computed once per step, a part without WindTree no longer
--     errors every half second (nil table index), trees leaving the set are put back at rest
--     once instead of every part being reset every 0.5 s, touch laptops with a keyboard count as
--     desktops (like Gameplay/LowPowerGraphics), and the Heartbeat is only connected while a palm
--     is streamed in (the arena is 1500+ studs from every lobby, so it is off almost always).
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local TAG = "RacePalmWind"
local MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local RADIUS = if MOBILE then 190 else 380
local LIMIT = if MOBILE then 6 else 14
local STEP_SECONDS = if MOBILE then 1 / 20 else 1 / 30
local SELECT_SECONDS = 0.5
local HIDDEN = 0.95

type Record = {
	part: BasePart,
	rest: CFrame,
	base: Vector3,
	crown: Vector3,
	phase: number,
	canopy: boolean,
	tree: any,
}

local records: { [BasePart]: Record } = {}
local recordCount = 0
local active: { Record } = {}
local startWind: () -> () -- (below) connects the Heartbeat while palms are there

local function register(instance: Instance)
	if records[instance :: any] or not instance:IsA("BasePart") then
		return
	end
	local part = instance :: BasePart
	local base, crown = part:GetAttribute("WindBase"), part:GetAttribute("WindCrown")
	if typeof(base) ~= "Vector3" or typeof(crown) ~= "Vector3" then
		return
	end
	local tree = part:GetAttribute("WindTree")
	records[part] = {
		part = part,
		rest = part.CFrame,
		base = base,
		crown = crown,
		phase = tonumber(part:GetAttribute("WindPhase")) or 0,
		canopy = part:GetAttribute("WindKind") == "canopy",
		tree = if tree ~= nil then tree else part,
	}
	recordCount += 1
	startWind()
end

local function unregister(instance: Instance)
	if records[instance :: any] then
		records[instance :: any] = nil
		recordCount -= 1
	end
end

local function visible(part: BasePart): boolean
	return part.Parent ~= nil and part.Transparency < HIDDEN and part.LocalTransparencyModifier < HIDDEN
end

local moveParts: { BasePart } = {}
local moveFrames: { CFrame } = {}

local function flush()
	if #moveParts > 0 then
		pcall(function()
			Workspace:BulkMoveTo(moveParts, moveFrames, Enum.BulkMoveMode.FireCFrameChanged)
		end)
	end
	table.clear(moveParts)
	table.clear(moveFrames)
end

-- The nearest LIMIT trees within RADIUS of the camera; the ones that left go back to rest.
local function selectTrees()
	local camera = Workspace.CurrentCamera
	local from = camera and camera.CFrame.Position
	local nearest = {}
	if from then
		for _, record in records do
			if visible(record.part) then
				local distance = (record.base - from).Magnitude
				if distance < RADIUS and distance < (nearest[record.tree] or math.huge) then
					nearest[record.tree] = distance
				end
			end
		end
	end
	local trees = {}
	for tree, distance in nearest do
		table.insert(trees, { tree = tree, distance = distance })
	end
	table.sort(trees, function(a, b)
		return a.distance < b.distance
	end)
	local chosen = {}
	for index = 1, math.min(LIMIT, #trees) do
		chosen[trees[index].tree] = true
	end
	for _, record in active do
		if not chosen[record.tree] and record.part.Parent then
			table.insert(moveParts, record.part)
			table.insert(moveFrames, record.rest)
		end
	end
	flush()
	local nextActive = {}
	for _, record in records do
		if chosen[record.tree] then
			table.insert(nextActive, record)
		end
	end
	active = nextActive
end

local clock, sinceSelect, sinceStep = 0, SELECT_SECONDS, 0
local connection: RBXScriptConnection? = nil
local function step(dt: number)
	if recordCount == 0 and #active == 0 then
		if connection then
			connection:Disconnect()
			connection = nil
		end
		return
	end
	clock += dt
	sinceSelect += dt
	sinceStep += dt
	if sinceSelect >= SELECT_SECONDS then
		sinceSelect = 0
		selectTrees()
	end
	if sinceStep < STEP_SECONDS or #active == 0 then
		return
	end
	sinceStep = 0
	local swayOf = {}
	for _, record in active do
		local part = record.part
		if visible(part) then
			local sway = swayOf[record.tree]
			if not sway then
				local a = math.sin(clock * 1.1 + record.phase) * 0.018
				local b = math.sin(clock * 0.83 + record.phase + 1.7) * 0.012
				local base = CFrame.new(record.base)
				sway = base * CFrame.Angles(a, 0, b) * base:Inverse()
				swayOf[record.tree] = sway
			end
			if record.canopy then
				local crown = CFrame.new(record.crown)
				local flutter = crown * CFrame.Angles(math.sin(clock * 1.5 + record.phase) * 0.038, 0,
					math.cos(clock * 1.2 + record.phase) * 0.03) * crown:Inverse()
				table.insert(moveFrames, sway * flutter * record.rest)
			else
				table.insert(moveFrames, sway * record.rest)
			end
			table.insert(moveParts, part)
		end
	end
	flush()
end

startWind = function()
	if not connection then
		sinceSelect = SELECT_SECONDS
		connection = RunService.Heartbeat:Connect(step)
	end
end

for _, instance in CollectionService:GetTagged(TAG) do
	register(instance)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(register)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(unregister)
