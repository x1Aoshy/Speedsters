                                                        

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

if game.PlaceId ~= 96501592055150 and game.PlaceId ~= 116359653478954 and not RunService:IsStudio() then
	return
end

local CLOSE_DISTANCE = 18
local FAR_DISTANCE = 117
local CLOSE_WIDTH = 170
local CLOSE_HEIGHT = 39
local CLOSE_TEXT_SIZE = 26
local FAR_SCALE = 0.52
local UPDATE_INTERVAL = 1 / 30

local tracked = setmetatable({}, { __mode = "k" })
local elapsed = 0

local function tryTrack(object)
	if not object or not object:IsA("BasePart") or object:GetAttribute("World2ManualPad") ~= true then
		return
	end
	local billboard = object:FindFirstChild("World2ManualPadBillboard")
	local label = billboard and billboard:FindFirstChild("PadText")
	if billboard and billboard:IsA("BillboardGui") and label and label:IsA("TextLabel") then
		tracked[object] = { Billboard = billboard, Label = label }
	end
end

for _, object in ipairs(Workspace:GetDescendants()) do
	tryTrack(object)
end

Workspace.DescendantAdded:Connect(function(object)
	if object:IsA("BasePart") then
		task.defer(tryTrack, object)
	elseif object.Name == "World2ManualPadBillboard" or object.Name == "PadText" then
		local part = object:FindFirstAncestorWhichIsA("BasePart")
		if part then task.defer(tryTrack, part) end
	end
end)

Workspace.DescendantRemoving:Connect(function(object)
	if object:IsA("BasePart") then
		tracked[object] = nil
	end
end)

RunService.RenderStepped:Connect(function(deltaTime)
	elapsed += deltaTime
	if elapsed < UPDATE_INTERVAL then return end
	elapsed = 0
	local camera = Workspace.CurrentCamera
	if not camera then return end
	local cameraPosition = camera.CFrame.Position
	for pad, entry in pairs(tracked) do
		if not pad.Parent or not entry.Billboard.Parent or not entry.Label.Parent then
			tracked[pad] = nil
		else
			local distance = (cameraPosition - pad.Position).Magnitude
			local alpha = math.clamp((distance - CLOSE_DISTANCE) / (FAR_DISTANCE - CLOSE_DISTANCE), 0, 1)
			local scale = 1 - ((1 - FAR_SCALE) * alpha)
			entry.Billboard.Size = UDim2.fromOffset(
				math.max(1, math.round(CLOSE_WIDTH * scale)),
				math.max(1, math.round(CLOSE_HEIGHT * scale))
			)
			entry.Label.TextScaled = false
			entry.Label.TextSize = math.max(10, math.round(CLOSE_TEXT_SIZE * scale))
		end
	end
end)
