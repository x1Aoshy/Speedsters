-- HazardNames: which map parts kill on touch, by name (moved verbatim from the character's
-- touch prediction in R15SpeedsterRun, 2026-09-25, H6), so the client that predicts a death
-- and the server that arbitrates it (Services/LocalDeathRules) use one rule.
--
-- Pure (no services, no requires): Lune tests require it directly.
local HazardNames = {}

-- nameLower / parentLower: the part's and its parent's names, lower case.
function HazardNames.IsLethalName(nameLower: string, parentLower: string): boolean
	nameLower = if type(nameLower) == "string" then nameLower else ""
	parentLower = if type(parentLower) == "string" then parentLower else ""
	return nameLower == "lava" or nameLower == "lavaup"
		or parentLower == "lava" or parentLower == "lavaup"
		or string.find(nameLower, "kill") ~= nil or string.find(nameLower, "laser") ~= nil
		or string.find(nameLower, "hazard") ~= nil or string.find(nameLower, "spike") ~= nil
		-- A parent counts only when it is the laser itself (a "Laser" model's beams), not any
		-- model with "laser" in its name: World 3's Stage 10 floor sits in a
		-- "laserplatform" model, and stepping on it killed (2026-09-18).
		or string.find(parentLower, "kill") ~= nil or parentLower == "laser" or parentLower == "lasers"
		or string.find(parentLower, "hazard") ~= nil
end

local function namesOf(part: any): (string, string)
	local nameLower = string.lower(tostring(part.Name))
	local parent = part.Parent
	local parentLower = if parent then string.lower(tostring(parent.Name)) else ""
	return nameLower, parentLower
end

-- What the character's touch prediction kills on: a lethal name or a "Kill script" child.
function HazardNames.IsNamedLethalPart(part: any): boolean
	if part == nil then
		return false
	end
	local nameLower, parentLower = namesOf(part)
	return HazardNames.IsLethalName(nameLower, parentLower) or part:FindFirstChild("Kill script") ~= nil
end

-- What the server accepts as evidence of a hazard death: the above, or any part World 1's
-- server motion marked as a hazard (hammers, presses, the rolling cylinder...).
function HazardNames.IsLethalPart(part: any): boolean
	if part == nil then
		return false
	end
	return HazardNames.IsNamedLethalPart(part) or part:GetAttribute("NewWorld1HazardKey") ~= nil
end

return HazardNames
