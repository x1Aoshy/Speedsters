local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
if Config.IsWorld2Place == true then
	return
end

                                                                                            
                                                                                             

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BILLBOARD_NAME = "RebirthRequirementBillboard_V306S"
local BASE_WIDTH = 176
local BASE_HEIGHT = 42
local REFERENCE_DISTANCE = 35
local MIN_SCALE = 0.35
local MAX_SCALE = 1.35

local tracked = {}

local function track(instance)
	if instance:IsA("BillboardGui") and instance.Name == BILLBOARD_NAME then
		tracked[instance] = true
	end
end

local function untrack(instance)
	tracked[instance] = nil
end

for _, instance in ipairs(Workspace:GetDescendants()) do
	track(instance)
end

Workspace.DescendantAdded:Connect(track)
Workspace.DescendantRemoving:Connect(untrack)

RunService.RenderStepped:Connect(function()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	for billboard in pairs(tracked) do
		if billboard.Parent == nil then
			tracked[billboard] = nil
		else
			local adornee = billboard.Adornee
			if adornee and adornee:IsA("BasePart") then
				local distance = (camera.CFrame.Position - adornee.Position).Magnitude
				local scale = math.clamp(REFERENCE_DISTANCE / math.max(distance, 1), MIN_SCALE, MAX_SCALE)
				billboard.Size = UDim2.fromOffset(
					math.round(BASE_WIDTH * scale),
					math.round(BASE_HEIGHT * scale)
				)
			end
		end
	end
end)

print("[TreadmillRebirthBillboardScale] V306T loaded. Rebirth labels grow when close and shrink with distance.")
