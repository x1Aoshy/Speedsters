                                           
                                                            
                                                                        
                                                                              
                                                         

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local CONSOLE_SCALE = 0.72
local SCALE_NAME = "V306KY_ConsoleOnlyScale"

local function isConsole()
	local tenFoot = false
	pcall(function()
		tenFoot = GuiService:IsTenFootInterface()
	end)

	if tenFoot then
		return true
	end

	                                                                        
	                                                                            
	                                                             
	return UserInputService.GamepadEnabled
		and not UserInputService.TouchEnabled
		and not UserInputService.KeyboardEnabled
		and not UserInputService.MouseEnabled
end

if not isConsole() then
	                                                                  
	return
end

local tracked = setmetatable({}, { __mode = "k" })

local function bindExistingScale(scale)
	if tracked[scale] then
		return
	end
	tracked[scale] = true

	local applying = false
	local baseScale = tonumber(scale.Scale) or 1
	local lastAppliedScale = nil

	local function apply()
		if not scale.Parent then
			return
		end
		local targetScale = baseScale * CONSOLE_SCALE
		lastAppliedScale = targetScale
		if math.abs((tonumber(scale.Scale) or 1) - targetScale) <= 0.000001 then
			return
		end
		applying = true
		scale.Scale = targetScale
		applying = false
	end

	scale:GetPropertyChangedSignal("Scale"):Connect(function()
		if applying or not scale.Parent then
			return
		end
		local currentScale = tonumber(scale.Scale) or 1
		                                                                      
		                                                                         
		                                                        
		if lastAppliedScale and math.abs(currentScale - lastAppliedScale) <= 0.000001 then
			return
		end
		                                                                     
		                                                                     
		baseScale = currentScale
		apply()
	end)

	apply()
end

local function setupScreenGui(gui)
	if not gui:IsA("ScreenGui") then
		return
	end

	                                                                          
	                                                                                 
	local directScale = nil
	for _, child in ipairs(gui:GetChildren()) do
		if child:IsA("UIScale") and child.Name ~= SCALE_NAME then
			directScale = child
			break
		end
	end

	if directScale then
		bindExistingScale(directScale)
		return
	end

	                                                                         
	                                                                           
	                     
	local scale = gui:FindFirstChild(SCALE_NAME)
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = SCALE_NAME
		scale.Scale = CONSOLE_SCALE
		scale.Parent = gui
	else
		scale.Scale = CONSOLE_SCALE
	end
end

for _, child in ipairs(playerGui:GetChildren()) do
	setupScreenGui(child)
end

playerGui.ChildAdded:Connect(function(child)
	if child:IsA("ScreenGui") then
		task.defer(setupScreenGui, child)
	end
end)

print("[ConsoleUiScale] V306KAI active | stable console-only UI scale=" .. tostring(CONSOLE_SCALE))
