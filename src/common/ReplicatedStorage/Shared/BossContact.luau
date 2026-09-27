-- Shared.BossContact (2026-09-21): when does a chasing boss really touch a runner?
--
-- Players said the bosses killed them "from 10 metres" and "without touching". Two things made
-- that true:
--   * Lag. The server holds each runner's character about one ping in the past, while Zoom and
--     ReverseFlash were tested where they are NOW. The runner's own screen also shows the boss
--     a little in the past. At 55 studs/s that is 10-20 studs of phantom contact.
--   * Boxes. Touched and GetPartBoundsInBox test whole part boxes (an invisible 10-stud root,
--     5-stud cubes around 1.5-stud-wide Sonic legs) and every accessory of the runner.
--
-- This module holds the pure maths the bosses share: an exact box-vs-box test with a small
-- forgiveness margin, a short history of the boss's root so the server can put the boss back
-- where the runner saw it, and the size a SpecialMesh part really draws. It asks for no service
-- when it is required (the Lune tests load it as it is).
local BossContact = {}

local function normalizeName(value)
	return (string.gsub(string.lower(tostring(value or "")), "[^%w]", ""))
end

-- The runner's body: R6 and R15 limb, torso and head names. Hats, wings, tools and effect parts
-- are also children of the character but are not the body, so they never count as contact.
BossContact.BodyPartNames = {
	head = true,
	torso = true,
	leftarm = true,
	rightarm = true,
	leftleg = true,
	rightleg = true,
	uppertorso = true,
	lowertorso = true,
	leftupperarm = true,
	leftlowerarm = true,
	lefthand = true,
	rightupperarm = true,
	rightlowerarm = true,
	righthand = true,
	leftupperleg = true,
	leftlowerleg = true,
	leftfoot = true,
	rightupperleg = true,
	rightlowerleg = true,
	rightfoot = true,
}

function BossContact.IsBodyPartName(name)
	return BossContact.BodyPartNames[normalizeName(name)] == true
end

-- The character's body parts (direct children with a body name).
function BossContact.GetBodyParts(character)
	local parts = {}
	if not character then
		return parts
	end
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("BasePart") and BossContact.BodyPartNames[normalizeName(child.Name)] then
			table.insert(parts, child)
		end
	end
	return parts
end

-- Do two boxes overlap? (separating axis test; `shrink` pulls box A's faces in by that many
-- studs.) The same maths as World1HammerMotion.BoxesOverlap, which only World 1 carries.
function BossContact.BoxesOverlap(cframeA, sizeA, cframeB, sizeB, shrink)
	local halfA = sizeA * 0.5 - Vector3.new(shrink or 0, shrink or 0, shrink or 0)
	if halfA.X <= 0 or halfA.Y <= 0 or halfA.Z <= 0 then
		return false
	end
	local halfB = sizeB * 0.5
	local axesA = { cframeA.RightVector, cframeA.UpVector, cframeA.LookVector }
	local axesB = { cframeB.RightVector, cframeB.UpVector, cframeB.LookVector }
	local extentA = { halfA.X, halfA.Y, halfA.Z }
	local extentB = { halfB.X, halfB.Y, halfB.Z }
	local offset = cframeB.Position - cframeA.Position

	local function separated(axis)
		local length = axis.Magnitude
		if length < 1e-5 then
			return false -- parallel edges: this axis decides nothing
		end
		axis = axis / length
		local radiusA, radiusB = 0, 0
		for i = 1, 3 do
			radiusA += extentA[i] * math.abs(axesA[i]:Dot(axis))
			radiusB += extentB[i] * math.abs(axesB[i]:Dot(axis))
		end
		return math.abs(offset:Dot(axis)) > radiusA + radiusB
	end

	for i = 1, 3 do
		if separated(axesA[i]) or separated(axesB[i]) then
			return false
		end
	end
	for i = 1, 3 do
		for j = 1, 3 do
			if separated(axesA[i]:Cross(axesB[j])) then
				return false
			end
		end
	end
	return true
end

-- The box a part really draws. A SpecialMesh scales the drawing, not the part, so Sonic's
-- 5.08-stud leg cubes draw 1.5-stud-wide legs. The answer is never bigger than part.Size on
-- any axis: a mesh drawn bigger than its part (Sonic's 1.1 sphere head) keeps the part's box,
-- so no hitbox grows. A FileMesh's scale is in mesh units, not studs, so it keeps part.Size.
function BossContact.VisibleSize(part)
	local size = part.Size
	local mesh = part:FindFirstChildOfClass("SpecialMesh")
	if not mesh then
		return size
	end
	local meshType = mesh.MeshType and mesh.MeshType.Name or "FileMesh"
	if meshType == "FileMesh" then
		return size
	end
	-- Head, Brick, Cylinder, Sphere (its diameter on each axis is Size * Scale) and the rest.
	local drawn = size * mesh.Scale
	return Vector3.new(
		math.min(size.X, math.abs(drawn.X)),
		math.min(size.Y, math.abs(drawn.Y)),
		math.min(size.Z, math.abs(drawn.Z))
	)
end

-- A short history of one CFrame (the boss's root), newest last. `capacity` samples are kept
-- (64 is about a second at 60 Hz). A step longer than `maxJump` studs between two samples is a
-- snap or a teleport, not a walk: the history starts again there, so a rewound boss never
-- stands at the spot it was teleported away from.
local History = {}
History.__index = History

function BossContact.NewHistory(capacity, maxJump)
	return setmetatable({
		Capacity = math.max(2, math.floor(capacity or 64)),
		MaxJump = maxJump or math.huge,
		Samples = {},
	}, History)
end

function History:Clear()
	table.clear(self.Samples)
end

function History:Record(now, cframe)
	local samples = self.Samples
	local newest = samples[#samples]
	if newest then
		if now < newest.Time then
			table.clear(samples)
		elseif (cframe.Position - newest.CFrame.Position).Magnitude > self.MaxJump then
			table.clear(samples)
		end
	end
	table.insert(samples, { Time = now, CFrame = cframe })
	if #samples > self.Capacity then
		table.remove(samples, 1)
	end
end

-- Where the CFrame was at `time`, blended between the two samples around it. Before the oldest
-- sample it answers the oldest, after the newest the newest, and nil with no sample at all.
function History:At(time)
	local samples = self.Samples
	local count = #samples
	if count == 0 then
		return nil
	end
	if time >= samples[count].Time then
		return samples[count].CFrame
	end
	if time <= samples[1].Time then
		return samples[1].CFrame
	end
	for index = count - 1, 1, -1 do
		local older = samples[index]
		if older.Time <= time then
			local newer = samples[index + 1]
			local span = newer.Time - older.Time
			local alpha = if span > 0 then (time - older.Time) / span else 1
			return older.CFrame:Lerp(newer.CFrame, alpha)
		end
	end
	return samples[1].CFrame
end

-- Where a boss part was when the root was at `pastRootCFrame`: the part keeps its place on the
-- body and the body turns with the root, so a boss that turned is rewound turned.
function BossContact.Rewind(pastRootCFrame, currentRootCFrame, partCFrame)
	return pastRootCFrame * currentRootCFrame:Inverse() * partCFrame
end

-- How far back to put the boss for one runner: their ping plus a little for interpolation,
-- never more than `maxSeconds`. A missing or broken ping reads as 0.1 s.
function BossContact.RewindSeconds(ping, extraSeconds, maxSeconds)
	local seconds = tonumber(ping)
	if not seconds or seconds ~= seconds or seconds < 0 then
		seconds = 0.1
	end
	return math.clamp(seconds + (extraSeconds or 0), 0, maxSeconds or math.huge)
end

-- Does any boss part touch any body part? `sizes` maps a boss part to the box to test (its
-- visible size); a part not in it is measured with VisibleSize. With both root CFrames the boss
-- parts are rewound first. Returns true plus the two parts that touched.
function BossContact.CharacterTouches(bossParts, bodyParts, shrink, pastRootCFrame, currentRootCFrame, sizes)
	local rewind = pastRootCFrame and currentRootCFrame and pastRootCFrame * currentRootCFrame:Inverse() or nil
	for _, bossPart in ipairs(bossParts) do
		if bossPart.Parent then
			local bossCFrame = if rewind then rewind * bossPart.CFrame else bossPart.CFrame
			local bossSize = (sizes and sizes[bossPart]) or BossContact.VisibleSize(bossPart)
			local bossReach = bossSize.Magnitude * 0.5
			for _, bodyPart in ipairs(bodyParts) do
				if bodyPart.Parent then
					local bodyCFrame = bodyPart.CFrame
					if (bodyCFrame.Position - bossCFrame.Position).Magnitude <= bossReach + bodyPart.Size.Magnitude * 0.5
						and BossContact.BoxesOverlap(bossCFrame, bossSize, bodyCFrame, bodyPart.Size, shrink)
					then
						return true, bossPart, bodyPart
					end
				end
			end
		end
	end
	return false
end

return BossContact
