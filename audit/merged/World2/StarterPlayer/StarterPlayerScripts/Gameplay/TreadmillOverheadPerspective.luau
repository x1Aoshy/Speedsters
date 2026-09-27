local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
if Config.IsWorld2Place == true then
	return
end

         
                                                                        
                                                                           
                                                                               
                                                          

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GUI_NAME = "V306HK_TreadmillOverhead"
local CONTENT_ROOT_NAME = "ContentRoot"
local PERSPECTIVE_SCALE_NAME = "PerspectiveScale"

                                                                        
                                                                      
local FULL_SIZE_DISTANCE = 38
local MINIMUM_SCALE = 0.08
local MAXIMUM_SCALE = 1
local CHANGE_EPSILON = 0.001

local tracked = {}
local pending = {}

local function getWorldPosition(gui)
	local worldOffset = gui.StudsOffsetWorldSpace
	local adornee = gui.Adornee
	if adornee and adornee:IsA("Attachment") then
		return adornee.WorldPosition + worldOffset
	elseif adornee and adornee:IsA("BasePart") then
		return adornee.Position + worldOffset
	elseif adornee and adornee:IsA("Model") then
		return adornee:GetPivot().Position + worldOffset
	end

	local parent = gui.Parent
	if parent and parent:IsA("Attachment") then
		return parent.WorldPosition + worldOffset
	elseif parent and parent:IsA("BasePart") then
		return parent.Position + worldOffset
	elseif parent and parent:IsA("Model") then
		return parent:GetPivot().Position + worldOffset
	end
	return nil
end

local function bindWhenReady(gui)
	if pending[gui] or tracked[gui] then
		return
	end
	pending[gui] = true

	task.spawn(function()
		local contentRoot = gui:FindFirstChild(CONTENT_ROOT_NAME)
			or gui:WaitForChild(CONTENT_ROOT_NAME, 10)
		local perspectiveScale = contentRoot
			and (contentRoot:FindFirstChild(PERSPECTIVE_SCALE_NAME)
				or contentRoot:WaitForChild(PERSPECTIVE_SCALE_NAME, 10))

		pending[gui] = nil
		if gui.Parent
			and contentRoot
			and perspectiveScale
			and perspectiveScale:IsA("UIScale")
		then
			tracked[gui] = perspectiveScale
		end
	end)
end

local function consider(instance)
	if instance:IsA("BillboardGui")
		and instance.Name == GUI_NAME
	then
		bindWhenReady(instance)
	end
end

for _, instance in ipairs(Workspace:GetDescendants()) do
	consider(instance)
end

Workspace.DescendantAdded:Connect(consider)
Workspace.DescendantRemoving:Connect(function(instance)
	if tracked[instance] then
		tracked[instance] = nil
	end
	if pending[instance] then
		pending[instance] = nil
	end
end)

RunService.RenderStepped:Connect(function()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local cameraPosition = camera.CFrame.Position
	for gui, perspectiveScale in pairs(tracked) do
		if not gui.Parent or not perspectiveScale.Parent then
			tracked[gui] = nil
		else
			local worldPosition = getWorldPosition(gui)
			if worldPosition then
				local distance = math.max(1, (cameraPosition - worldPosition).Magnitude)
				local targetScale = math.clamp(
					FULL_SIZE_DISTANCE / distance,
					MINIMUM_SCALE,
					MAXIMUM_SCALE
				)
				if math.abs(perspectiveScale.Scale - targetScale) >= CHANGE_EPSILON then
					perspectiveScale.Scale = targetScale
				end
			end
		end
	end
end)

print("[TreadmillOverheadPerspective] V306HK ready | whole label scales together | full size through 38 studs | natural 1/d distance falloff")
