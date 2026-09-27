-- Pure maths and rules for the world-portal unlock cinematic (UI/WorldPortalCinematic).
-- No services here, so audit/test_fable_tutorial_portal runs it offline against the real places.
local Shot = {}

-- The lobby portals as authored (2026-09-20). Used to stream the lobby in when the runner is
-- far away, and as the shot itself if the real part still has not arrived.
Shot.Fallback = {
	[1] = { Position = Vector3.new(282.6, 37482.9, -1841.3), Front = Vector3.new(0, 0, 1), Size = Vector3.new(2.2, 22.9, 13.4) },
	[2] = { Position = Vector3.new(-838.2, 36642.8, -953.1), Front = Vector3.new(0.7071, 0, -0.7071), Size = Vector3.new(2.2, 22.9, 13.4) },
	[3] = { Position = Vector3.new(263.0, 110.8, 581.8), Front = Vector3.new(0, 0, -1), Size = Vector3.new(2.2, 22.9, 13.4) },
}
Shot.PortalNames = { PortalWorld2 = true, PortalWorld3 = true }
-- A lobby portal is never this far from the lobby; the big ones at the end of a track are.
Shot.LobbyRadius = 260
-- Standing this close to the portal, the runner is already looking at it.
Shot.NearPortal = 70

Shot.Timeline = {
	Open = 0.55, -- the shutter opens on the portal
	Hold = 4.6, -- the flight
	Close = 0.4, -- the shutter closes on it
	Reopen = 0.5, -- and opens again on the runner
}
Shot.Flight = {
	StartAngle = math.rad(34), EndAngle = math.rad(4),
	StartDistance = 54, EndDistance = 37,
	StartHeight = 10, EndHeight = 2.5,
	MinDistance = 16,
}

local function flat(v)
	local out = Vector3.new(v.X, 0, v.Z)
	if out.Magnitude < 1e-4 then
		return nil
	end
	return out.Unit
end

-- The portal is a thin slab: its front is the slab's thin horizontal axis, on the side
-- `reference` (a direction, e.g. portal -> lobby spawn) points to.
function Shot.Front(cframe, size, reference)
	local axis = if size.X <= size.Z then cframe.RightVector else cframe.LookVector
	local front = flat(axis)
	local toward = reference and flat(reference)
	if not front then
		return toward or Vector3.new(0, 0, 1)
	end
	if toward and front:Dot(toward) < 0 then
		front = -front
	end
	return front
end

-- The lobby portal among `parts`: the closest one to `anchor` (the lobby spawn or the
-- authored spot), and only inside the lobby.
function Shot.Pick(parts, anchor)
	local best, bestDistance = nil, Shot.LobbyRadius
	for _, part in parts do
		local distance = (part.CFrame.Position - anchor).Magnitude
		if distance < bestDistance then
			best, bestDistance = part, distance
		end
	end
	return best
end

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- Where the camera is `alpha` (0..1) of the way through the flight: it starts off to one
-- side in front of the portal and swings round to face it, drifting closer and lower.
-- `reach` (optional) is how far the camera may be from the focus before something is in the way.
function Shot.Eye(focus, front, alpha, reach)
	local flight = Shot.Flight
	local x = smooth(alpha)
	local angle = flight.StartAngle + (flight.EndAngle - flight.StartAngle) * x
	local distance = flight.StartDistance + (flight.EndDistance - flight.StartDistance) * x
	local height = flight.StartHeight + (flight.EndHeight - flight.StartHeight) * x
	if reach then
		distance = math.max(flight.MinDistance, math.min(distance, reach))
	end
	local right = Vector3.new(-front.Z, 0, front.X)
	local direction = front * math.cos(angle) + right * math.sin(angle)
	return focus + direction * distance + Vector3.new(0, height, 0)
end

-- One gate per client. The cinematic plays only when a world's unlock flag turns on while
-- the player is in the game; the flag is saved by the server and never turns off, so it
-- cannot replay on a later join, a respawn, a level up or a rebirth.
function Shot.NewGate()
	return { Baseline = {}, Played = {} }
end

function Shot.Observe(gate, world, unlocked, dataLoaded)
	if not dataLoaded then
		return false
	end
	unlocked = unlocked == true
	if gate.Baseline[world] == nil then
		gate.Baseline[world] = unlocked
		return false
	end
	if not unlocked then
		-- An admin reset: the next unlock is a new one.
		gate.Baseline[world] = false
		gate.Played[world] = nil
		return false
	end
	if gate.Baseline[world] == true or gate.Played[world] then
		return false
	end
	gate.Played[world] = true
	return true
end

return Shot
