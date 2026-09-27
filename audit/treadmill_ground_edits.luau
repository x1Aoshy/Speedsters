-- audit/treadmill_ground_edits.luau  (2026-09-22)
-- Place content for the game feel pass: authored treadmills set flush on their floors.
-- The owner saw treadmill models hovering a little above the ground (World 3 only, after
-- testing). Applied by the lead's build (audit/build_fable_feel.luau through
-- audit/fable_build_lib.luau: edit(key, dm, notes) returns true when it changed the place,
-- verify(key, dm) asserts on the round-tripped place). Checked by audit/test_feel_ground.luau.
--
-- Which treadmills: every container TreadmillTraining.server.luau registers, found the way its
-- registerTreadmills() walks Workspace, with the place's own Config (loaded from src with the
-- place as its game): a Config.TreadmillBaseGains name (not an "Admin" model that only holds
-- other treadmills), World 1's neworld1 profile names, the "Model" under an "Admin", and any
-- TreadmillTrainingSourceName clone. A container inside another one counts once (the outer).
--
-- What is measured and moved is the treadmill BODY of each container (Ground.bodyOf): the Model
-- that holds the belt 'Treadmil' (the container itself for Basic/Golden/Candy). The crystal,
-- bolt, cone and Needoh decorations beside it in Diamond/Needoh/Hacker/Admin stand on or in
-- the floor; measured with them, a hovering body read flush. They stay where they are, and no
-- part of any container can be another treadmill's floor.
--
-- Measure: the lowest corner of the body's solid visible parts (world-space corners of each BasePart's
-- rotated box; Transparency >= 1 zones and hitboxes are ignored) against the floor beneath it:
-- the highest top among anchored, visible parts outside every treadmill whose XZ box overlaps
-- the treadmill's footprint and whose top is at most 0.5 above the treadmill's bottom. Visible,
-- not collidable: World 1's lobby floor ('Treadmillarea.floor for spawn') is CanCollide false
-- over a collidable part 0.35 lower, and it is the floor a player sees the treadmills stand on.
-- A gap over 0.05 studs floats: the whole body (every BasePart CFrame and each Model's
-- WorldPivot) moves straight down by the gap. Flush or sunk ones are never touched (a treadmill
-- whose parts go more than 0.5 into the floor has no floor 'under' it and is reported as sunk);
-- one with no floor at all is reported and left. A second run finds nothing to do.
--
-- Scope: World 3 only (Ground.WORLDS). The owner, after testing: "the problem only happens in
-- World 3". In World 1 and World 2 the edit changes nothing and only notes what it saw.
--
-- Measured 2026-09-22 on the root places (body bottom minus floor top): World 3 above
-- Lobby.Treadmillarea.'floor for spawn': Admin.Model 1.160, Basic 0.151, Diamond.Model 0.969,
-- Needoh.Model 1.332, Hacker.Model 1.565, all moved. Out of scope and left: World 1
-- neworld1.Needoh.Model 0.371 above its 'floor for spawn', World 2 Admin.Diamond.Model 0.234
-- above the Baseplate; every other body there is flush or sunk.
--
-- No runtime script lifts them: StageDecor returns at once in World 2 and World 3,
-- TreadmillCollisionFix only builds its own invisible decks, and World3TreadmillOverheadLabels
-- moves only its sign.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rb = require("@lune/roblox")

local Ground = {}

Ground.FLOAT_TOLERANCE = 0.05
Ground.FLOOR_REACH = 0.5
-- The places the edit moves treadmills in (see the header).
Ground.WORLDS = { World3 = true }
local CONFIG = "src/common/ReplicatedStorage/Shared/Config.luau"

-- The place's Config, as the game would build it in that place (Workspace attributes and map
-- markers decide the world).
function Ground.loadConfig(dm)
	local noSignal = { Connect = function() end, Wait = function() end }
	local function forward(real)
		return setmetatable({}, { __index = function(_, key)
			if key == "DescendantAdded" or key == "DescendantRemoving" or key == "ChildAdded" or key == "ChildRemoved" then
				return noSignal
			end
			local value = real[key]
			if type(value) == "function" then
				return function(_, ...)
					return value(real, ...)
				end
			end
			return value
		end })
	end
	local env = setmetatable({
		workspace = forward(dm:GetService("Workspace")),
		typeof = rb.typeof or typeof,
		print = function() end,
		warn = function() end,
	}, { __index = _G })
	for _, name in { "CFrame", "Vector3", "Color3", "UDim2", "UDim", "Vector2", "NumberRange", "ColorSequence",
		"ColorSequenceKeypoint", "NumberSequence", "NumberSequenceKeypoint", "BrickColor", "Enum", "Instance" } do
		env[name] = rb[name]
	end
	env.game = { PlaceId = 0, GetService = function(_, name)
		return forward(dm:GetService(name))
	end }
	return luau.load(fs.readFile(CONFIG), { environment = env, debugName = "Config" })()
end

local function isA(object, className: string): boolean
	return object:IsA(className)
end

-- TreadmillTraining.registerTreadmills(), without the zones: the authored containers, in
-- Workspace order, each once.
function Ground.containers(dm, config): { any }
	config = config or Ground.loadConfig(dm)
	local workspace = dm:GetService("Workspace")
	local gains = config.TreadmillBaseGains or {}
	local newWorld1 = config.IsNewWorld1Map == true and workspace:FindFirstChild(tostring(config.NewWorld1MapMarkerName or "neworld1"))
	local newWorld1Profiles = config.NewWorld1TreadmillProfiles or {}
	local found, tracked = {}, {}
	local function physical(container)
		if not (isA(container, "Model") or isA(container, "BasePart")) then
			return nil
		end
		local belt = container:FindFirstChild("Treadmil", true)
		if belt and (isA(belt, "Model") or isA(belt, "BasePart")) then
			return belt
		end
		return container
	end
	local function register(container)
		local treadmill = physical(container)
		if not treadmill or tracked[treadmill] or tracked[container] then
			return
		end
		tracked[treadmill], tracked[container] = true, true
		table.insert(found, container)
	end
	for _, descendant in workspace:GetDescendants() do
		if newWorld1 and newWorld1Profiles[descendant.Name] ~= nil and descendant:IsDescendantOf(newWorld1) then
			register(descendant)
		end
		if gains[descendant.Name] then
			local holder = false
			if isA(descendant, "Model") and descendant.Name == "Admin" then
				for _, child in descendant:GetChildren() do
					if isA(child, "Model") and (gains[child.Name] or child:FindFirstChild("Treadmil", true)) then
						holder = true
						break
					end
				end
			end
			if not holder then
				register(descendant)
			end
		end
		if isA(descendant, "Model") and descendant.Name == "Model" and descendant.Parent and descendant.Parent.Name == "Admin"
			and descendant:FindFirstChild("Treadmil", true)
		then
			register(descendant)
		end
		local sourceName = descendant:GetAttribute("TreadmillTrainingSourceName")
		if type(sourceName) == "string" and gains[sourceName] then
			register(descendant)
		end
	end
	-- A container inside another moves with it: keep the outermost.
	local outer = {}
	for _, container in found do
		local nested = false
		for _, other in found do
			if other ~= container and container:IsDescendantOf(other) then
				nested = true
				break
			end
		end
		if not nested then
			table.insert(outer, container)
		end
	end
	return outer
end

local function partsOf(object): { any }
	local parts = {}
	if isA(object, "BasePart") then
		table.insert(parts, object)
	end
	for _, descendant in object:GetDescendants() do
		if isA(descendant, "BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

-- World-space box of a part's rotated corners: minimum, maximum.
local function boxOf(part)
	local cframe, half = part.CFrame, part.Size / 2
	local minX, minY, minZ = math.huge, math.huge, math.huge
	local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local corner = (cframe * rb.CFrame.new(sx * half.X, sy * half.Y, sz * half.Z)).Position
				minX, minY, minZ = math.min(minX, corner.X), math.min(minY, corner.Y), math.min(minZ, corner.Z)
				maxX, maxY, maxZ = math.max(maxX, corner.X), math.max(maxY, corner.Y), math.max(maxZ, corner.Z)
			end
		end
	end
	return { minX = minX, minY = minY, minZ = minZ, maxX = maxX, maxY = maxY, maxZ = maxZ }
end

local function fullName(object): string
	local names = {}
	local node = object
	while node and node.ClassName ~= "DataModel" do
		table.insert(names, 1, node.Name)
		node = node.Parent
	end
	return table.concat(names, ".")
end

-- The treadmill body of a registered container: the Model (or part) that holds the belt
-- 'Treadmil' (the container itself for Basic/Golden/Candy). Crystal, bolt, cone and Needoh
-- decorations beside it in the container are not the treadmill: they sit on or in the floor
-- and would hide a hovering body if they set the bottom.
function Ground.bodyOf(container)
	local belt = container:FindFirstChild("Treadmil", true)
	if not belt then
		return container
	end
	local holder = belt.Parent
	if holder == container or (holder and holder:IsDescendantOf(container) and isA(holder, "Model")) then
		return holder
	end
	return belt
end

-- Every registered treadmill body with its bottom, its floor and the gap between them (floor
-- nil when nothing qualifies under it).
function Ground.measure(key: string, dm, config): { any }
	local workspace = dm:GetService("Workspace")
	local containers = Ground.containers(dm, config)
	local inTreadmill = {}
	for _, container in containers do
		for _, part in partsOf(container) do
			inTreadmill[part] = true
		end
	end
	local floors = {}
	for _, part in workspace:GetDescendants() do
		if isA(part, "BasePart") and not inTreadmill[part] and part.ClassName ~= "Terrain"
			and part.Anchored and part.Transparency < 1
		then
			table.insert(floors, { part = part, box = boxOf(part) })
		end
	end
	local results = {}
	for _, container in containers do
		local low = { minX = math.huge, minY = math.huge, minZ = math.huge, maxX = -math.huge, maxY = -math.huge, maxZ = -math.huge }
		local solid = 0
		local body = Ground.bodyOf(container)
		for _, part in partsOf(body) do
			if part.Transparency < 1 then
				local box = boxOf(part)
				solid += 1
				low.minX, low.minY, low.minZ = math.min(low.minX, box.minX), math.min(low.minY, box.minY), math.min(low.minZ, box.minZ)
				low.maxX, low.maxY, low.maxZ = math.max(low.maxX, box.maxX), math.max(low.maxY, box.maxY), math.max(low.maxZ, box.maxZ)
			end
		end
		local entry = { key = key, container = container, body = body, name = fullName(body), solid = solid }
		if solid > 0 then
			entry.bottom = low.minY
			local best, bestTop = nil, -math.huge
			for _, floor in floors do
				local box = floor.box
				if box.maxY <= low.minY + Ground.FLOOR_REACH and box.maxY > bestTop
					and box.minX < low.maxX and box.maxX > low.minX and box.minZ < low.maxZ and box.maxZ > low.minZ
				then
					best, bestTop = floor.part, box.maxY
				end
			end
			if best then
				entry.floor = best
				entry.floorName = fullName(best)
				entry.floorTop = bestTop
				entry.gap = low.minY - bestTop
			else
				-- No top under it: is its bottom inside something (sunk deeper than the reach)?
				for _, floor in floors do
					local box = floor.box
					if box.minY <= low.minY and box.maxY > low.minY
						and box.minX < low.maxX and box.maxX > low.minX and box.minZ < low.maxZ and box.maxZ > low.minZ
					then
						entry.sunkInto = fullName(floor.part)
						entry.sunkDepth = math.max(entry.sunkDepth or 0, box.maxY - low.minY)
					end
				end
			end
		end
		table.insert(results, entry)
	end
	return results
end

local function floating(entry): boolean
	return entry.gap ~= nil and entry.gap > Ground.FLOAT_TOLERANCE
end
Ground.isFloating = floating

-- Moves every BasePart of a treadmill body (or any instance), and a Model's WorldPivot, by offset.
function Ground.translate(container, offset)
	for _, part in partsOf(container) do
		part.CFrame = part.CFrame + offset
	end
	local models = { container }
	for _, descendant in container:GetDescendants() do
		if isA(descendant, "Model") then
			table.insert(models, descendant)
		end
	end
	for _, model in models do
		if isA(model, "Model") then
			local ok, pivot = pcall(function()
				return model.WorldPivotData
			end)
			if ok and typeof(pivot) == "CFrame" then
				model.WorldPivotData = pivot + offset
			end
		end
	end
end

function Ground.edit(key: string, dm, notes: { string }?): boolean
	local function note(text: string)
		if notes then
			table.insert(notes, text)
		end
	end
	local changed = false
	if not Ground.WORLDS[key] then
		for _, entry in Ground.measure(key, dm) do
			if floating(entry) then
				note(("ground: %s left %.3f above %s (only World 3 is edited)"):format(entry.name, entry.gap, entry.floorName))
			end
		end
		return false
	end
	for _, entry in Ground.measure(key, dm) do
		if entry.solid == 0 then
			note(("ground: %s has no visible part, left"):format(entry.name))
		elseif entry.sunkInto then
			-- Sunk more than the reach into its floor: never lifted.
			continue
		elseif not entry.floor then
			note(("ground: %s has no floor under it, left"):format(entry.name))
		elseif floating(entry) then
			Ground.translate(entry.body, rb.Vector3.new(0, -entry.gap, 0))
			changed = true
			note(("ground: %s down %.3f onto %s"):format(entry.name, entry.gap, entry.floorName))
		end
	end
	return changed
end

function Ground.verify(key: string, dm)
	if not Ground.WORLDS[key] then
		return true
	end
	for _, entry in Ground.measure(key, dm) do
		assert(not floating(entry), ("%s: %s still floats %.3f above %s"):format(key, entry.name, entry.gap or 0, tostring(entry.floorName)))
	end
	return true
end

return Ground
