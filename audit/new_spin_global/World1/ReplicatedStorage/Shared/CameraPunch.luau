-- CameraPunch.luau
-- One-off camera kicks for the local player (the Sonic Burst's burst):
--   * an FOV punch (Shared.SonicBurstMath.FovOffset: up at once, then an elastic settle)
--     that SpeedsterClient adds on top of its own smoothed FOV, so the two never fight;
--   * a short micro-shake, applied after the camera scripts each frame and put back
--     before them (the exact CFrame is restored: undoing with an inverse drifts at the sky
--     lobbies' height).
local RunService = game:GetService("RunService")

local SonicBurstMath = require(script.Parent:WaitForChild("SonicBurstMath"))

local CameraPunch = {}

local punchAt = -math.huge
local punchSize = 0

function CameraPunch.Fov(size: number)
	punchAt = os.clock()
	punchSize = tonumber(size) or 0
end

function CameraPunch.FovOffset(now: number?): number
	return SonicBurstMath.FovOffset((now or os.clock()) - punchAt, punchSize)
end

local stopShake = nil

function CameraPunch.Shake(duration: number, strength: number)
	if stopShake then
		stopShake()
	end
	local name = "CameraPunchShake"
	local started = os.clock()
	local shaken = nil -- { Camera, CFrame before the shake }

	local function restore()
		if shaken then
			if shaken.Camera.Parent then
				shaken.Camera.CFrame = shaken.Before
			end
			shaken = nil
		end
	end
	local function stop()
		RunService:UnbindFromRenderStep(name .. "Before")
		RunService:UnbindFromRenderStep(name)
		restore()
		if stopShake == stop then
			stopShake = nil
		end
	end
	stopShake = stop

	RunService:BindToRenderStep(name .. "Before", Enum.RenderPriority.Camera.Value - 1, restore)
	RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 2, function()
		local t = os.clock() - started
		if t >= duration then
			stop()
			return
		end
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local fade = (1 - t / duration) ^ 2 * strength
		local before = camera.CFrame
		camera.CFrame = before
			* CFrame.new(math.sin(t * 97) * 0.08 * fade, math.cos(t * 113) * 0.06 * fade, 0)
			* CFrame.Angles(math.sin(t * 83) * 0.012 * fade, 0, math.cos(t * 101) * 0.018 * fade)
		shaken = { Camera = camera, Before = before }
	end)
end

return CameraPunch
