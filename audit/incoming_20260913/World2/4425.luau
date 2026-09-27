         
                                                                              
                                                                              
                                                                               
                                                                          
                                                                          

local SERVER_REFERENCE_NAME = "SpeedsterServerAnimatorReference"
local SERVER_AUTHORITY_ATTRIBUTE = "SpeedsterServerAuthoritative"

local character = script.Parent
local humanoid = character:WaitForChild("Humanoid", 10)

if not humanoid then
	warn("[R6AnimatorAuthority] V306GY Humanoid was not available.")
	return
end

local animator = humanoid:FindFirstChildOfClass("Animator")
if not animator then
	animator = Instance.new("Animator")
	animator.Name = "Animator"
	animator.Parent = humanoid
end

                                                                              
                                                                              
                                                                            
                                                                                  
                                                                           
animator.PreferLodEnabled = false
animator:SetAttribute(SERVER_AUTHORITY_ATTRIBUTE, true)
animator:SetAttribute("SpeedsterFullFidelityAnimation", true)

local animatorReference = humanoid:FindFirstChild(SERVER_REFERENCE_NAME)
if animatorReference and not animatorReference:IsA("ObjectValue") then
	animatorReference:Destroy()
	animatorReference = nil
end

if not animatorReference then
	animatorReference = Instance.new("ObjectValue")
	animatorReference.Name = SERVER_REFERENCE_NAME
	animatorReference.Parent = humanoid
end

animatorReference.Value = animator
humanoid:SetAttribute("SpeedsterServerAnimatorReady", true)
humanoid:SetAttribute("SpeedsterAnimatorAuthorityVersion", "V306GY")
