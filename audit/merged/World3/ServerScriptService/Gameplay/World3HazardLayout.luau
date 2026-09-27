-- World3HazardLayout.luau
-- Reads World 3's hazards off the desert map, once, from what the designer built:
--
--   Stage 1  Cactus        every part of the "Cactus" folder's cactus models.
--   Stage 2  Tumbleweeds   one lane in each gap between the raised strips of the floor,
--                          rolling across its full width (the map's tumbleweed is the look).
--   Stage 3  Roadrunners   two birds zigzagging the length of the long platform.
--   Stage 5  Quicksand     every part of the "Quicksand Part" model.
--   Stage 6  Collapsing    the flat parkour platforms (not the pillars, walls or conveyor).
--   Stage 7  Carts         one cart shuttling on each rail line (the map's wagons are the look).
--   Stage 8  Serpent       the canyon from Stage 8's checkpoint to Stage 9's; the "Pit"
--                          rings are the dugouts to hide in. The modeller's Snake is its look.
--   Stage 9  Scorpions     lanes across the trail from Stage 9's checkpoint to Stage 10's, each
--                          as wide as the trail is clear there (the rocks and caves at its
--                          sides stay out of the way). The modeller's Scorpion is the look.
--   Stage 10 Crumbling     the flat platforms in "Action Parts": they shake, fall and return.
--            Lasers        the red "laser" bars, on a cycle (Shared.World3HazardMotion.Laser):
--                          they kill only while on.
--            Void          the parts in the "Void" folder kill on touch.
--            Sandstorm     the stage's area, where clients raise a sandstorm.
--   Void     for each stage, a kill height 25 studs under the lowest floor of that stage;
--            Stage 10's is Stage10VoidBelowCheckpoint under its checkpoint (see below).
--
-- `Client` holds plain numbers only (see Shared.World3HazardMotion) so it can travel as
-- JSON; the rest (parts, boxes, heights) stays on the server.

local World3HazardLayout = {}

World3HazardLayout.VoidDepth = 25
-- Stage 10's route is stepping stones, platforms and the laser floors, none lower than 2.5
-- studs under its checkpoint's top; the rocks under the stones have ledges from 10.4 studs
-- under it down that a fall could strand a player on. Its void is this far under the
-- checkpoint's top, so a character (root about 3 over its feet) standing on any stone is
-- well above it and one on any ledge is under it (2026-09-18 pre-launch review: the
-- modeller's void layer at y 25 left falls landing on ledges 90 studs above it, alive and
-- stuck).
World3HazardLayout.Stage10VoidBelowCheckpoint = 5
World3HazardLayout.CollapseMaxThickness = 6
World3HazardLayout.SerpentWallMargin = 20
-- Stage 6's platforms shake for 0.6 s and return after 3 s; Stage 10's (the brief) shake for
-- 0.7 s and return after 3.5 s.
World3HazardLayout.Collapse = {
	[6] = { Shake = 0.6, Back = 3 },
	[10] = { Shake = 2.0, Back = 3.5 },
}
World3HazardLayout.CrumbleMaxThickness = 12
World3HazardLayout.ScorpionLaneSpacing = 64
World3HazardLayout.ScorpionEndGap = 40 -- no lane this close to either checkpoint
World3HazardLayout.ScorpionMinSpan = 60
World3HazardLayout.ScorpionWallGap = 4
World3HazardLayout.ScorpionBlockerHeight = 8 -- what stands this tall over the trail is in the way
World3HazardLayout.ScorpionSize = { Length = 16, Width = 12.8, Height = 10.4 } -- when no template

local function boundsOf(object)
	local minimum = { math.huge, math.huge, math.huge }
	local maximum = { -math.huge, -math.huge, -math.huge }
	local list = if object:IsA("BasePart") then { object } else object:GetDescendants()
	for _, part in list do
		if part:IsA("BasePart") then
			local cframe, half = part.CFrame, part.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local corner = (cframe * CFrame.new(sx * half.X, sy * half.Y, sz * half.Z)).Position
						minimum[1], maximum[1] = math.min(minimum[1], corner.X), math.max(maximum[1], corner.X)
						minimum[2], maximum[2] = math.min(minimum[2], corner.Y), math.max(maximum[2], corner.Y)
						minimum[3], maximum[3] = math.min(minimum[3], corner.Z), math.max(maximum[3], corner.Z)
					end
				end
			end
		end
	end
	if minimum[1] == math.huge then
		return nil
	end
	return { MinX = minimum[1], MinY = minimum[2], MinZ = minimum[3], MaxX = maximum[1], MaxY = maximum[2], MaxZ = maximum[3] }
end
World3HazardLayout.BoundsOf = boundsOf

local function grow(box, by)
	return { MinX = box.MinX - by, MinY = box.MinY - by, MinZ = box.MinZ - by, MaxX = box.MaxX + by, MaxY = box.MaxY + by, MaxZ = box.MaxZ + by }
end

local function topY(part)
	local cframe, half = part.CFrame, part.Size / 2
	return cframe.Position.Y
		+ math.abs(cframe.RightVector.Y) * half.X
		+ math.abs(cframe.UpVector.Y) * half.Y
		+ math.abs(cframe.LookVector.Y) * half.Z
end

local function partsIn(object)
	local parts = {}
	if object then
		for _, descendant in object:GetDescendants() do
			if descendant:IsA("BasePart") then
				table.insert(parts, descendant)
			end
		end
	end
	return parts
end

local function readable(part, property, fallback)
	local ok, value = pcall(function()
		return part[property]
	end)
	return if ok and value ~= nil then value else fallback
end

-- A part the void counts as floor: solid, visible, wide enough to stand on, not lava.
local function isFloor(part, root)
	if part.Name == "Baseplate" and part.Parent == root then
		return false
	end
	if part.Name == "Lava" or part:FindFirstChild("Kill script") or string.lower(part.Name) == "laser" then
		return false
	end
	if readable(part, "CanCollide", true) ~= true or readable(part, "Transparency", 0) >= 0.95 then
		return false
	end
	if part.Size.X * part.Size.Z < 16 then
		return false
	end
	local current = part.Parent
	while current and current ~= root do
		if string.sub(current.Name, -8) == "_Runtime" or string.find(string.lower(current.Name), "void", 1, true) then
			return false
		end
		current = current.Parent
	end
	return true
end

-- The parts in a folder whose name says "void" (Stage 10's "Void (SCRIPT THE KILL)").
local function voidParts(folder)
	local parts = {}
	for _, descendant in folder:GetDescendants() do
		if descendant:IsA("BasePart") then
			local current = descendant.Parent
			while current and current ~= folder do
				if string.find(string.lower(current.Name), "void", 1, true) then
					table.insert(parts, descendant)
					break
				end
				current = current.Parent
			end
		end
	end
	return parts
end

-- `templates` is where the modeller's Snake and Scorpion wait (ServerStorage's
-- World3HazardTemplates); without it the scorpions get a default size.
function World3HazardLayout.Read(root, stages, templates)
	local layout = {
		Client = { Tumbleweeds = {}, Roadrunners = {}, Carts = {}, Serpent = nil, Scorpions = {}, Sandstorm = nil },
		CactusParts = {},
		QuicksandParts = {},
		CollapseParts = {},
		CollapseStages = {},
		LaserParts = {},
		LaserBoxes = {},
		VoidParts = {},
		VoidPlanes = {},
		Regions = {},
		Templates = {},
		Problems = {},
	}
	local function problem(text)
		table.insert(layout.Problems, text)
	end
	local function stageFolder(stage)
		local folder = root:FindFirstChild("Stage " .. stage)
		if not folder then
			problem("Stage " .. stage .. " folder is missing")
		end
		return folder
	end

	-- Stage 1: cactus.
	local stage1 = stageFolder(1)
	layout.CactusParts = partsIn(stage1 and stage1:FindFirstChild("Cactus"))
	if #layout.CactusParts == 0 then
		problem("Stage 1 has no cactus")
	end

	-- Stage 2: a tumbleweed lane in every gap between the raised strips.
	local stage2 = stageFolder(2)
	local main = stage2 and stage2:FindFirstChild("Main")
	local platform = main and main:FindFirstChild("Platform")
	local tumbleweed = main and main:FindFirstChild("Tumbleweed")
	if platform and tumbleweed then
		layout.Templates.Tumbleweed = tumbleweed
		local weedBox = boundsOf(tumbleweed)
		local radius = math.max(weedBox.MaxX - weedBox.MinX, weedBox.MaxY - weedBox.MinY, weedBox.MaxZ - weedBox.MinZ) / 2
		local floor, strips = nil, {}
		for _, child in platform:GetChildren() do
			if child:IsA("BasePart") then
				local box = boundsOf(child)
				if box.MaxZ - box.MinZ < 20 then
					table.insert(strips, box)
				elseif not floor or topY(child) > floor.Top then
					floor = { Box = box, Top = topY(child) }
				end
			end
		end
		table.sort(strips, function(a, b)
			return a.MaxZ > b.MaxZ
		end)
		if floor then
			for index = 1, #strips - 1 do
				local gapStart, gapEnd = strips[index].MinZ, strips[index + 1].MaxZ
				if gapStart - gapEnd >= radius * 2 then
					local lane = #layout.Client.Tumbleweeds + 1
					local leftToRight = lane % 2 == 1
					local fromX, toX = floor.Box.MinX - radius * 2, floor.Box.MaxX + radius * 2
					table.insert(layout.Client.Tumbleweeds, {
						XFrom = if leftToRight then fromX else toX,
						XTo = if leftToRight then toX else fromX,
						Z = (gapStart + gapEnd) / 2,
						FloorY = floor.Top,
						Radius = radius,
						Speed = 34 + lane * 5,
						Offset = lane * 1.7,
					})
				end
			end
			layout.Regions.Tumbleweed = grow(floor.Box, 25)
		end
	end
	if #layout.Client.Tumbleweeds == 0 then
		problem("Stage 2 has no tumbleweed lanes")
	end

	-- Stage 3: two roadrunners zigzagging the platform.
	local stage3 = stageFolder(3)
	local runway = stage3 and stage3:FindFirstChild("Platform")
	if runway then
		local top, topBox = -math.huge, nil
		for _, part in partsIn(runway) do
			if topY(part) > top then
				top, topBox = topY(part), boundsOf(part)
			end
		end
		local centreX = (topBox.MinX + topBox.MaxX) / 2
		for index = 1, 2 do
			table.insert(layout.Client.Roadrunners, {
				ZFrom = topBox.MaxZ - 25,
				ZTo = topBox.MinZ + 25,
				CenterX = centreX,
				Amplitude = (topBox.MaxX - topBox.MinX) / 2 - 30,
				Wavelength = 180,
				FloorY = top,
				Height = 9,
				Radius = 4.5,
				Speed = 58,
				Offset = (index - 1) * ((topBox.MaxZ - topBox.MinZ) - 50) / 58,
			})
		end
		layout.Regions.Roadrunner = grow(topBox, 25)
	else
		problem("Stage 3 has no platform")
	end

	-- Stage 5: quicksand.
	local stage5 = stageFolder(5)
	layout.QuicksandParts = partsIn(stage5 and stage5:FindFirstChild("Quicksand Part"))
	if #layout.QuicksandParts == 0 then
		problem("Stage 5 has no quicksand")
	end

	-- Stage 6: the flat parkour platforms collapse.
	local stage6 = stageFolder(6)
	local parkour = stage6 and stage6:FindFirstChild("Parkour")
	if parkour then
		for _, child in parkour:GetChildren() do
			if child:IsA("BasePart") and child.Name ~= "Conveyor" and child.Name ~= "Lava"
				and child.Size.Y <= World3HazardLayout.CollapseMaxThickness
			then
				table.insert(layout.CollapseParts, child)
				layout.CollapseStages[child] = 6
			end
		end
	end
	if #layout.CollapseParts == 0 then
		problem("Stage 6 has no collapsing platforms")
	end

	-- Stage 7: a cart on every rail line.
	local stage7 = stageFolder(7)
	local rails = stage7 and stage7:FindFirstChild("Rails")
	local wagons = {}
	if stage7 then
		for _, descendant in stage7:GetDescendants() do
			if descendant:IsA("Model") and descendant.Name == "Small Wagon" then
				table.insert(wagons, descendant)
			end
		end
	end
	layout.Templates.Wagons = wagons
	if rails and wagons[1] then
		local wagon = boundsOf(wagons[1])
		local lines = {}
		for _, line in rails:GetChildren() do
			local box = line:IsA("Model") and boundsOf(line)
			if box then
				table.insert(lines, box)
			end
		end
		table.sort(lines, function(a, b)
			return a.MaxZ > b.MaxZ
		end)
		local all = nil
		for index, box in lines do
			table.insert(layout.Client.Carts, {
				XMin = box.MinX,
				XMax = box.MaxX,
				Z = (box.MinZ + box.MaxZ) / 2,
				BaseY = wagon.MinY,
				Length = wagon.MaxX - wagon.MinX,
				Width = wagon.MaxZ - wagon.MinZ,
				Height = wagon.MaxY - wagon.MinY,
				Speed = 36 + (index % 3) * 9,
				Offset = index * 2.3,
			})
			all = if all
				then { MinX = math.min(all.MinX, box.MinX), MinY = math.min(all.MinY, box.MinY), MinZ = math.min(all.MinZ, box.MinZ), MaxX = math.max(all.MaxX, box.MaxX), MaxY = math.max(all.MaxY, box.MaxY), MaxZ = math.max(all.MaxZ, box.MaxZ) }
				else box
		end
		layout.Regions.Cart = grow(all, 25)
	else
		problem("Stage 7 has no rails or wagons")
	end

	-- Stage 8: the serpent sweeps from the end of its canyon (Stage 9's checkpoint; on an
	-- older map, the finish) back to Stage 8's checkpoint.
	local stage8 = stageFolder(8)
	local markers = stages.GetStageMarkers(8)
	local nextMarkers = stages.StageCount >= 9 and stages.GetStageMarkers(9) or nil
	local finish = stages.GetFinish()
	local canyonEnd = (nextMarkers and nextMarkers.Checkpoint) or (finish and finish.Checkpoint)
	local pits = stage8 and stage8:FindFirstChild("Pit")
	if markers and markers.Checkpoint and canyonEnd and pits then
		local checkpoint = boundsOf(markers.Checkpoint)
		local finishBox = boundsOf(canyonEnd)
		local towardFinish = if finishBox.MinZ < checkpoint.MinZ then -1 else 1
		local dugouts = {}
		for _, pit in pits:GetChildren() do
			local box = boundsOf(pit)
			if box then
				table.insert(dugouts, {
					X = (box.MinX + box.MaxX) / 2,
					Z = (box.MinZ + box.MaxZ) / 2,
					Radius = math.min(box.MaxX - box.MinX, box.MaxZ - box.MinZ) / 2 - 1.5,
				})
			end
		end
		layout.Client.Serpent = {
			ZStart = if towardFinish < 0 then finishBox.MaxZ else finishBox.MinZ,
			ZEnd = if towardFinish < 0 then checkpoint.MinZ else checkpoint.MaxZ,
			XMin = checkpoint.MinX + World3HazardLayout.SerpentWallMargin,
			XMax = checkpoint.MaxX - World3HazardLayout.SerpentWallMargin,
			FloorY = topY(markers.Checkpoint),
			Height = 14,
			HeadRadius = 6,
			BodyRadius = 3.6,
			BodyLength = 80,
			Speed = 125,
			WarnTime = 3,
			Period = 16,
			Offset = 0,
			Dugouts = dugouts,
		}
		local serpent = layout.Client.Serpent
		layout.Regions.Serpent = grow({
			MinX = serpent.XMin, MaxX = serpent.XMax,
			MinY = serpent.FloorY - 2, MaxY = serpent.FloorY + serpent.Height,
			MinZ = math.min(serpent.ZStart, serpent.ZEnd), MaxZ = math.max(serpent.ZStart, serpent.ZEnd),
		}, 25)
		if #dugouts == 0 then
			problem("Stage 8 has no dugouts")
		end
	else
		problem("Stage 8 has no checkpoint, canyon end or pits")
	end

	-- Stage 9: scorpion lanes across the trail, between Stage 9's checkpoint and Stage 10's.
	if stages.StageCount >= 10 then
		local stage9 = stageFolder(9)
		local from, to = stages.GetStageMarkers(9), stages.GetStageMarkers(10)
		if stage9 and from and from.Checkpoint and to and to.Checkpoint then
			local fromBox, toBox = boundsOf(from.Checkpoint), boundsOf(to.Checkpoint)
			local nearZ = if fromBox.MinZ > toBox.MaxZ then fromBox.MinZ else fromBox.MaxZ
			local farZ = if fromBox.MinZ > toBox.MaxZ then toBox.MaxZ else toBox.MinZ
			local ahead = if farZ < nearZ then -1 else 1
			-- The trail: the widest floor in Stage 9 lying between the two checkpoints.
			local trail, trailBox, trailArea = nil, nil, 0
			for _, part in partsIn(stage9) do
				if isFloor(part, root) then
					local box = boundsOf(part)
					local area = (box.MaxX - box.MinX) * (box.MaxZ - box.MinZ)
					if area > trailArea and box.MaxZ > math.min(nearZ, farZ) and box.MinZ < math.max(nearZ, farZ) then
						trail, trailBox, trailArea = part, box, area
					end
				end
			end
			if trail then
				local floorY = topY(trail)
				local size = World3HazardLayout.ScorpionSize
				local template = templates and templates:FindFirstChild("Scorpion")
				if template and template:IsA("BasePart") then
					size = { Length = template.Size.Z, Width = template.Size.X, Height = template.Size.Y }
				end
				-- What stands in the way on the trail: rocks and caves, anything tall enough.
				local blockers = {}
				for _, part in partsIn(stage9) do
					if part ~= trail and readable(part, "CanCollide", true) == true then
						local box = boundsOf(part)
						if box.MaxY > floorY + World3HazardLayout.ScorpionBlockerHeight and box.MinY < floorY + size.Height
							and (box.MaxX - box.MinX) * (box.MaxZ - box.MinZ) >= 20
						then
							table.insert(blockers, box)
						end
					end
				end
				local z = nearZ + ahead * World3HazardLayout.ScorpionEndGap
				local lane = 0
				while (farZ - z) * ahead >= World3HazardLayout.ScorpionEndGap do
					-- The clear stretches across the trail at this lane, and the widest of them.
					local free = { { trailBox.MinX + World3HazardLayout.ScorpionWallGap, trailBox.MaxX - World3HazardLayout.ScorpionWallGap } }
					for _, box in blockers do
						if box.MinZ < z + size.Width / 2 + 2 and box.MaxZ > z - size.Width / 2 - 2 then
							local cut = {}
							for _, span in free do
								local left, right = box.MinX - World3HazardLayout.ScorpionWallGap, box.MaxX + World3HazardLayout.ScorpionWallGap
								if right <= span[1] or left >= span[2] then
									table.insert(cut, span)
								else
									if left > span[1] then
										table.insert(cut, { span[1], left })
									end
									if right < span[2] then
										table.insert(cut, { right, span[2] })
									end
								end
							end
							free = cut
						end
					end
					local best = nil
					for _, span in free do
						if not best or span[2] - span[1] > best[2] - best[1] then
							best = span
						end
					end
					if best and best[2] - best[1] - size.Length >= World3HazardLayout.ScorpionMinSpan then
						lane += 1
						local outward = lane % 2 == 1
						local fromX, toX = best[1] + size.Length / 2, best[2] - size.Length / 2
						table.insert(layout.Client.Scorpions, {
							XFrom = if outward then fromX else toX,
							XTo = if outward then toX else fromX,
							Z = z,
							FloorY = floorY,
							Length = size.Length,
							Width = size.Width,
							Height = size.Height,
							Speed = 26 + (lane % 3) * 6,
							Pause = 0.6,
							Offset = lane * 1.9,
						})
					end
					z += ahead * World3HazardLayout.ScorpionLaneSpacing
				end
				layout.Regions.Scorpion = grow({
					MinX = trailBox.MinX, MaxX = trailBox.MaxX,
					MinY = floorY - 2, MaxY = floorY + size.Height + 4,
					MinZ = math.min(nearZ, farZ), MaxZ = math.max(nearZ, farZ),
				}, 25)
			end
		end
		if #layout.Client.Scorpions == 0 then
			problem("Stage 9 has no scorpion lanes")
		end

		-- Stage 10: the crumbling platforms, the lasers, the void and the sandstorm's area.
		local stage10 = stageFolder(10)
		local action = stage10 and stage10:FindFirstChild("Action Parts")
		if action then
			for _, child in action:GetChildren() do
				if child:IsA("BasePart") and child.Name ~= "Conveyor" and string.lower(child.Name) ~= "laser"
					and child.CFrame.UpVector.Y > 0.99 and child.Size.Y <= World3HazardLayout.CrumbleMaxThickness
					and child.Size.X * child.Size.Z >= 400 and readable(child, "CanCollide", true) == true
				then
					table.insert(layout.CollapseParts, child)
					layout.CollapseStages[child] = 10
				end
			end
		end
		if stage10 then
			for _, part in partsIn(stage10) do
				if string.lower(part.Name) == "laser" then
					table.insert(layout.LaserParts, part)
					table.insert(layout.LaserBoxes, World3HazardLayout.BoundsOf(part))
				end
			end
			layout.VoidParts = voidParts(stage10)
			-- The modeller's void layer is the stage's void: a fall dies on it (touch) or at
			-- its top (height). Stage 10's rock pillars reach far below it, so the lowest-floor
			-- rule would put the void under the Baseplate.
			for _, part in layout.VoidParts do
				layout.VoidTop = math.max(layout.VoidTop or -math.huge, topY(part))
			end
			local area = boundsOf(stage10)
			if area then
				layout.Client.Sandstorm = grow(area, 30)
			end
		end
		if not layout.CollapseStages or not next(layout.CollapseStages) then
			problem("No collapsing platforms")
		end
		local crumbling = 0
		for _, stage in layout.CollapseStages do
			if stage == 10 then
				crumbling += 1
			end
		end
		if crumbling == 0 then
			problem("Stage 10 has no crumbling platforms")
		end
		if #layout.VoidParts == 0 then
			problem("Stage 10 has no void")
		end
		if not layout.Client.Sandstorm then
			problem("Stage 10 has no area for the sandstorm")
		end
	end

	-- The void: 25 studs under the lowest floor of every stage.
	local lowest = {}
	for _, part in root:GetDescendants() do
		if part:IsA("BasePart") and part.ClassName ~= "Terrain" and isFloor(part, root) then
			local centre = part.CFrame.Position
			local top = topY(part)
			local stage = stages.GetNearestStage(Vector3.new(centre.X, top, centre.Z))
			if stage and (not lowest[stage] or top < lowest[stage]) then
				lowest[stage] = top
			end
		end
	end
	for stage = 1, stages.StageCount do
		if lowest[stage] then
			layout.VoidPlanes[stage] = lowest[stage] - World3HazardLayout.VoidDepth
		else
			problem("Stage " .. stage .. " has no floor for the void")
		end
	end
	if layout.VoidTop and stages.StageCount >= 10 then
		local plane = layout.VoidTop
		local checkpoint = stages.GetStageReferencePosition and stages.GetStageReferencePosition(10)
		if checkpoint then
			plane = math.max(plane, checkpoint.Y - World3HazardLayout.Stage10VoidBelowCheckpoint)
		end
		layout.VoidPlanes[10] = math.max(layout.VoidPlanes[10] or -math.huge, plane)
	end
	return layout
end

return World3HazardLayout
