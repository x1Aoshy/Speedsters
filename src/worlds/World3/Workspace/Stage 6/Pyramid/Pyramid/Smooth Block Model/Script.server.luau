-- The pyramid's tunnel is a slide. Going in ragdolls the player (R6DeathRagdoll's
-- RagdollEvent), who slides down the ramp and stands up again at its lower lip, before
-- the drop. The ragdoll's own timer stands them up anyway if they get stuck on the way.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local trigger = script.Parent

local SAFETY_SECONDS = 11
-- Stand up this far before the lip. The server sees the player a little late, so the
-- distance they cover in LOOKAHEAD_SECONDS at their current speed counts as covered.
local LIP_MARGIN = 3
local LOOKAHEAD_SECONDS = 0.12
local REENTRY_SECONDS = 1.5
-- The ramp is slippery, so a ragdoll slides all the way down instead of stopping on it.
local SLIDE_FRICTION = 0.04

-- The ramp: the lowest sloped part next to the trigger (the other one is the ceiling).
local function findRamp()
	local best = nil
	for _, part in trigger.Parent:GetChildren() do
		if part:IsA("BasePart") and part ~= trigger and math.abs(part.CFrame.UpVector.Y) < 0.99 then
			if best == nil or part.CFrame.Position.Y < best.CFrame.Position.Y then
				best = part
			end
		end
	end
	return best
end

-- The ramp's centre, the unit direction down it, its half length, and the unit direction
-- and half width across it.
local function measureSlope(ramp)
	local frame, size = ramp.CFrame, ramp.Size
	local down, length, across, width = frame.RightVector, size.X, frame.LookVector, size.Z
	if math.abs(frame.LookVector.Y) > math.abs(frame.RightVector.Y) then
		down, length, across, width = frame.LookVector, size.Z, frame.RightVector, size.X
	end
	if down.Y > 0 then
		down = down * -1
	end
	return {
		Centre = frame.Position,
		Down = down,
		HalfLength = length / 2,
		Across = across,
		HalfWidth = width / 2,
	}
end

local ramp = findRamp()
local slope = ramp and measureSlope(ramp)
if ramp then
	local current = ramp.CustomPhysicalProperties or PhysicalProperties.new(ramp.Material)
	ramp.CustomPhysicalProperties = PhysicalProperties.new(current.Density, SLIDE_FRICTION, current.Elasticity, 100, current.ElasticityWeight)
end

-- Whether a player at `position`, moving at `velocity`, has reached the ramp's lower lip.
local function atLip(position, velocity)
	local offset = position - slope.Centre
	if math.abs(offset:Dot(slope.Across)) > slope.HalfWidth + 8 then
		return false
	end
	local along = offset:Dot(slope.Down) + math.max(0, velocity:Dot(slope.Down)) * LOOKAHEAD_SECONDS
	return along >= slope.HalfLength - LIP_MARGIN
end

local function setRagdoll(character, on)
	local event = character:FindFirstChild("RagdollEvent")
	if event and event:IsA("BindableEvent") then
		if on then
			event:Fire("Ragdoll", SAFETY_SECONDS)
		else
			event:Fire("Unragdoll")
		end
	else
		character:SetAttribute("RagdollDuration", SAFETY_SECONDS)
		character:SetAttribute("Ragdolled", on)
	end
end

local sliding = {} -- character -> { Root, Humanoid, Started }
local leftAt = {} -- character -> when they stood up at the lip

trigger.Touched:Connect(function(hit)
	local character = hit:FindFirstAncestorOfClass("Model")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 or not Players:GetPlayerFromCharacter(character) then
		return
	end
	if sliding[character] or (leftAt[character] and os.clock() - leftAt[character] < REENTRY_SECONDS) then
		return
	end
	sliding[character] = { Root = root, Humanoid = humanoid, Started = os.clock() }
	setRagdoll(character, true)
end)

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for character, slide in sliding do
		if character.Parent == nil or slide.Humanoid.Health <= 0 or now - slide.Started > SAFETY_SECONDS + 0.5 then
			sliding[character] = nil
		elseif slope and atLip(slide.Root.CFrame.Position, slide.Root.AssemblyLinearVelocity) then
			sliding[character] = nil
			leftAt[character] = now
			setRagdoll(character, false)
		end
	end
	for character, time in leftAt do
		if now - time > REENTRY_SECONDS then
			leftAt[character] = nil
		end
	end
end)
