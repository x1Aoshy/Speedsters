-- LocalDeathRules: the server's verdict on a death only the client saw (2026-09-25, H6).
--
-- The character's touch prediction (R15SpeedsterRun) kills the local humanoid at once, which is
-- the fair answer under lag, but the server never saw that death: the player lay there until
-- the 2.5 s watchdog asked for a plain reset, losing their stage even when the prediction was
-- wrong (a safe zone, the arrival grace, a hazard the server had already moved on). Now the
-- claim is judged here: "Kill" (a real death, the usual revive offer), "Revive" (respawn at the
-- stage start, nothing lost) or "Ignore" (the server already handles it).
--
-- Pure: the arbiter (Gameplay/LocalDeathArbiter) gathers the context; Lune tests call Decide.
local HazardNames = if typeof(script) == "Instance"
	then require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("HazardNames", 10))
	else require("../../ReplicatedStorage/Shared/HazardNames")

local LocalDeathRules = {}

LocalDeathRules.BaseReach = 6 -- studs from the body to the hazard's box that always count
LocalDeathRules.MinLead = 0.2 -- seconds of travel allowed on top of half the ping
LocalDeathRules.MaxLead = 0.6
LocalDeathRules.BoostFactor = 1.7
LocalDeathRules.MaxClientTimeAge = 1 -- a claimed time older than this is judged 1 s ago
-- 2026-09-25 (final fix): a body the server sees falling faster than this (studs/s, about 0.6 s
-- of free fall, well past a jump's landing speed) is not overruled: a claim sent just before a
-- fall into the void or onto a server kill brick would otherwise dodge that death, its revive
-- offer and the stage it costs.
LocalDeathRules.FallingSpeed = 120

export type Context = {
	serverDead: boolean?, -- no humanoid, Health <= 0, or the character's Dead attribute
	safeZone: boolean?, -- SafeZoneProtected on the player or the character
	teleportInvulnerable: boolean?, -- StageTeleportInvulnerable
	arrivalGrace: boolean?, -- inside StageTeleportArrivalGraceUntil
	revivedJustNow: boolean?, -- RevivedJustNow
	raceActive: boolean?, -- RaceActive (race spikes trip, never kill)
	worldFrozen: boolean?, -- Workspace.AdminWorldFrozen (lava is ice)
	part: any?, -- the BasePart the client says killed it (nil from the watchdog)
	claimAccepted: boolean?, -- a claim for this character was already confirmed
	poseAt: ((part: any, serverTime: number) -> any)?, -- where a moving hazard was (World 1)
	now: number?, -- Workspace:GetServerTimeNow()
	clientTime: number?, -- the server time the client says it touched the part
	rootPosition: any?, -- Vector3, the server's HumanoidRootPart position
	rootSpeed: number?, -- root.AssemblyLinearVelocity.Magnitude
	rootVelocityY: number?, -- root.AssemblyLinearVelocity.Y
	walkSpeed: number?, -- RealWalkSpeedSelected
	boosting: boolean?, -- IsBoosting
	ping: number?, -- seconds
}

local function finite(value: any, fallback: number): number
	local n = tonumber(value)
	if n == nil or n ~= n or n == math.huge or n == -math.huge then
		return fallback
	end
	return n
end

-- A part only the clients move: World 1's tracks and hammers, and World 3's Stage 10 lasers
-- (each client turns the bar; the server copy stays at its home, 2026-09-25).
local function isMovingPart(part: any): boolean
	return part:GetAttribute("TrackMoving") == true or part:GetAttribute("HammerSwingMoving") == true
		or part:GetAttribute("World3LaserIndex") ~= nil
end

local function isFrozenLava(part: any, worldFrozen: boolean?): boolean
	if part:GetAttribute("AdminFrozenLava") == true then
		return true
	end
	if worldFrozen ~= true then
		return false
	end
	local nameLower = string.lower(tostring(part.Name))
	local parentLower = if part.Parent then string.lower(tostring(part.Parent.Name)) else ""
	return string.find(nameLower, "lava", 1, true) ~= nil or string.find(parentLower, "lava", 1, true) ~= nil
end

-- Distance from a point to a box (cframe, size); 0 inside.
function LocalDeathRules.DistanceToBox(point: any, cframe: any, size: any): number
	local localPoint = cframe:PointToObjectSpace(point)
	local dx = math.max(math.abs(localPoint.X) - size.X * 0.5, 0)
	local dy = math.max(math.abs(localPoint.Y) - size.Y * 0.5, 0)
	local dz = math.max(math.abs(localPoint.Z) - size.Z * 0.5, 0)
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- How far the server's body may be from the hazard and still have touched it on the client:
-- a body's reach plus how far it travels in half a ping (+ the interpolation buffer).
function LocalDeathRules.Reach(ctx: Context): number
	local ping = math.max(0, finite(ctx.ping, 0.1))
	local walk = math.max(0, finite(ctx.walkSpeed, 16)) * (if ctx.boosting == true then LocalDeathRules.BoostFactor else 1)
	local speed = math.max(math.max(0, finite(ctx.rootSpeed, 0)), walk)
	return LocalDeathRules.BaseReach + speed * math.clamp(ping * 0.5 + LocalDeathRules.MinLead, LocalDeathRules.MinLead, LocalDeathRules.MaxLead)
end

function LocalDeathRules.Decide(ctx: Context): (string, string)
	-- 1. The server already saw this death: its own flow (revive offer) handles it.
	if ctx.serverDead == true then
		return "Ignore", "Dead"
	end
	local part = ctx.part
	-- 2. Where the server never kills, a death only the client saw is always wrong.
	if ctx.safeZone == true or ctx.teleportInvulnerable == true or ctx.arrivalGrace == true
		or ctx.revivedJustNow == true or ctx.raceActive == true
		or (part ~= nil and isFrozenLava(part, ctx.worldFrozen))
	then
		return "Revive", "Protected"
	end
	-- 3-4. The watchdog (no part). 2026-09-25 (final fix): a plain death, as the old
	-- PlayerResetRequest was. A real touch always sent its claim with the part first, and that
	-- claim was judged (an overruled character's later claims never get here), so a claim with
	-- no part and nothing accepted is no evidence of anything: overruling it handed out free
	-- respawns at the stage start.
	if part == nil then
		return "Kill", if ctx.claimAccepted == true then "Accepted" else "NoEvidence"
	end
	local falling = finite(ctx.rootVelocityY, 0) < -LocalDeathRules.FallingSpeed
	-- 5. Not a hazard by the shared rule.
	if not HazardNames.IsLethalPart(part) then
		if falling then
			return "Kill", "Falling"
		end
		return "Revive", "NotLethal"
	end
	-- 6. Where the hazard was when the client touched it: the pose provider (World 1's virtual
	-- poses) for any part it knows, else the server's part. A part the clients move and the
	-- provider cannot pose is trusted, as before.
	local now = finite(ctx.now, 0)
	local cframe = nil
	if ctx.poseAt then
		local at = math.clamp(finite(ctx.clientTime, now), now - LocalDeathRules.MaxClientTimeAge, now)
		local ok, pose = pcall(ctx.poseAt, part, at)
		cframe = if ok then pose else nil
	end
	if cframe == nil then
		if isMovingPart(part) then
			return "Kill", "LegacyTrust"
		end
		cframe = part.CFrame
	end
	-- 7. Too far from where the server holds the body.
	local root = ctx.rootPosition
	if root == nil then
		return "Revive", "NoBody"
	end
	if LocalDeathRules.DistanceToBox(root, cframe, part.Size) > LocalDeathRules.Reach(ctx) then
		if falling then
			return "Kill", "Falling"
		end
		return "Revive", "TooFar"
	end
	-- 8. Confirmed.
	return "Kill", "Contact"
end

return LocalDeathRules
