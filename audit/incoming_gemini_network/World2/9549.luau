         
                                                                          
                                                                           
                                                                           

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
if Config.IsWorld2Place == true or Config.IsNewWorld1Map == true then
	return
end

local RENDER_BINDING_NAME = "VortexRotatingLaserVisualV306DU"
local TAU = math.pi * 2

local laser = Workspace:WaitForChild("Laser", 30)
if not laser or not (laser:IsA("BasePart") or laser:IsA("Model")) then
	warn("[RotatingLaserVisual] Workspace.Laser was not found as a BasePart or Model.")
	return
end

local cachedKnobPosition = nil
local cachedInitialPivot = nil
local cachedRelativePivot = nil

local function refreshCachedPivot()
	local knobPosition = laser:GetAttribute("VortexLaserKnobPosition")
	local initialPivot = laser:GetAttribute("VortexLaserInitialPivot")
	if typeof(knobPosition) ~= "Vector3" or typeof(initialPivot) ~= "CFrame" then
		cachedKnobPosition = nil
		cachedInitialPivot = nil
		cachedRelativePivot = nil
		return
	end

	if knobPosition ~= cachedKnobPosition or initialPivot ~= cachedInitialPivot then
		cachedKnobPosition = knobPosition
		cachedInitialPivot = initialPivot
		cachedRelativePivot = CFrame.new(knobPosition):ToObjectSpace(initialPivot)
	end
end

laser:GetAttributeChangedSignal("VortexLaserKnobPosition"):Connect(refreshCachedPivot)
laser:GetAttributeChangedSignal("VortexLaserInitialPivot"):Connect(refreshCachedPivot)
refreshCachedPivot()

RunService:UnbindFromRenderStep(RENDER_BINDING_NAME)
RunService:BindToRenderStep(RENDER_BINDING_NAME, Enum.RenderPriority.Last.Value, function()
	if not laser.Parent or laser:GetAttribute("VortexLaserEnabled") ~= true then
		return
	end

	if not cachedRelativePivot or not cachedKnobPosition then
		refreshCachedPivot()
		if not cachedRelativePivot or not cachedKnobPosition then
			return
		end
	end

	local startServerTime = tonumber(laser:GetAttribute("VortexLaserStartServerTime"))
	local angularSpeed = tonumber(laser:GetAttribute("VortexLaserAngularSpeed"))
	if not startServerTime or not angularSpeed or angularSpeed <= 0 then
		return
	end

	local elapsed = math.max(0, Workspace:GetServerTimeNow() - startServerTime)
	local angle = (elapsed * angularSpeed) % TAU
	local targetPivot = CFrame.new(cachedKnobPosition)
		* CFrame.Angles(0, angle, 0)
		* cachedRelativePivot
	laser:PivotTo(targetPivot)
end)

script.Destroying:Connect(function()
	RunService:UnbindFromRenderStep(RENDER_BINDING_NAME)
end)

print("[RotatingLaserVisual] V306DU render-step smoothing active.")
