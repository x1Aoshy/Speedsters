                                                                                               
                                                             
                                                                                             

local Workspace = game:GetService("Workspace")

local protected = setmetatable({}, { __mode = "k" })
local protectedCount = 0

local function isWaterName(name)
	local lower = string.lower(name)
	return lower == "water" or lower == "water1"
end

local function protectModel(object)
	if not object:IsA("Model") or not isWaterName(object.Name) or protected[object] then
		return
	end

	local ok, err = pcall(function()
		object.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)

	if ok then
		protected[object] = true
		protectedCount += 1
	else
		warn("[V306G WaterProtection] Could not make persistent: " .. object:GetFullName() .. " | " .. tostring(err))
	end
end

for _, object in ipairs(Workspace:GetDescendants()) do
	protectModel(object)
end

Workspace.DescendantAdded:Connect(function(object)
	task.defer(function()
		if object.Parent then
			protectModel(object)
		end
	end)
end)

print("[V306G WaterProtection] Water/Water1 streaming protection active. Persistent models=" .. tostring(protectedCount))
