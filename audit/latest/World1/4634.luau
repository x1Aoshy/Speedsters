                                                   
  
                
                                                             
                                                          
  
                                                                                
                                                                            
                                                                             

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local SOURCE_NAME = "Confetti"
local RUNTIME_NAME = "LevelUpConfettiTemplate"

local function normalizeName(value)
	return tostring(value or ""):lower():gsub("[^%w]", "")
end

local function findSource()
	local direct = ServerStorage:FindFirstChild(SOURCE_NAME)
	if direct then
		return direct
	end
	local wanted = normalizeName(SOURCE_NAME)
	for _, object in ipairs(ServerStorage:GetDescendants()) do
		if normalizeName(object.Name) == wanted then
			return object
		end
	end
	return nil
end

local function hasEmitter(object)
	if object:IsA("ParticleEmitter") then
		return true
	end
	return object:FindFirstChildWhichIsA("ParticleEmitter", true) ~= nil
end

local function publishTemplate(source)
	if not source or not source.Parent or not hasEmitter(source) then
		return false
	end

	local old = ReplicatedStorage:FindFirstChild(RUNTIME_NAME)
	if old then
		old:Destroy()
	end

	local clone = source:Clone()
	clone.Name = RUNTIME_NAME
	clone:SetAttribute("LevelUpConfettiTemplate", true)
	clone:SetAttribute("SourceName", source.Name)
	clone.Parent = ReplicatedStorage

	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			descendant.Enabled = false
		end
	end
	if clone:IsA("ParticleEmitter") then
		clone.Enabled = false
	end

	print("[LevelUpConfettiTemplate] V306IG published exact ServerStorage Confetti VFX to clients.")
	return true
end

local source = findSource()
if source then
	publishTemplate(source)
else
	warn("[LevelUpConfettiTemplate] Put the supplied confetti.rbxm in ServerStorage and keep the top-level Part named 'Confetti'.")
end

                                                                              
                                          
ServerStorage.DescendantAdded:Connect(function(object)
	if ReplicatedStorage:FindFirstChild(RUNTIME_NAME) then
		return
	end
	if normalizeName(object.Name) == normalizeName(SOURCE_NAME) then
		task.defer(function()
			publishTemplate(object)
		end)
	end
end)
