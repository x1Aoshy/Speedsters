                                                                               
                                                                        
  
             
                                                        
                                                                       
                                                                   
                                                                               
                                                                                

local Lighting = game:GetService("Lighting")

local EFFECT_NAME_PREFIX = "ReferenceClip_"

local function destroyConflictingLightingEffects()
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Atmosphere")
			or child:IsA("BloomEffect")
			or child:IsA("ColorCorrectionEffect")
			or child:IsA("SunRaysEffect")
			or child:IsA("DepthOfFieldEffect")
			or child:IsA("BlurEffect") then
			child:Destroy()
		end
	end
end

local function setBaseLighting()
	                                          
	Lighting.Brightness = 3.0
	Lighting.ClockTime = 14.15
	Lighting.GeographicLatitude = 35
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.34
	Lighting.ExposureCompensation = 0.16

	Lighting.Ambient = Color3.fromRGB(132, 134, 142)
	Lighting.OutdoorAmbient = Color3.fromRGB(170, 174, 181)
	Lighting.ColorShift_Top = Color3.fromRGB(8, 4, 0)
	Lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)

	Lighting.EnvironmentDiffuseScale = 0.58
	Lighting.EnvironmentSpecularScale = 0.32

	Lighting.FogColor = Color3.fromRGB(196, 220, 246)
	Lighting.FogStart = 900
	Lighting.FogEnd = 5000

	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)
end

local function createAtmosphere()
	                                          
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = EFFECT_NAME_PREFIX .. "Atmosphere"
	atmosphere.Density = 0.19
	atmosphere.Offset = 0.16
	atmosphere.Color = Color3.fromRGB(202, 226, 255)
	atmosphere.Decay = Color3.fromRGB(112, 122, 143)
	atmosphere.Glare = 0.08
	atmosphere.Haze = 0.72
	atmosphere.Parent = Lighting
end

local function createColorCorrection()
	                                          
	local effect = Instance.new("ColorCorrectionEffect")
	effect.Name = EFFECT_NAME_PREFIX .. "ColorCorrection"
	effect.Enabled = true
	effect.Brightness = 0.045
	effect.Contrast = 0.035
	effect.Saturation = 0.23
	effect.TintColor = Color3.fromRGB(255, 247, 231)
	effect.Parent = Lighting
end

local function createBloom()
	                                          
	local bloom = Instance.new("BloomEffect")
	bloom.Name = EFFECT_NAME_PREFIX .. "Bloom"
	bloom.Enabled = true
	bloom.Intensity = 0.17
	bloom.Size = 22
	bloom.Threshold = 0.88
	bloom.Parent = Lighting
end

local function createSunRays()
	                                          
	local rays = Instance.new("SunRaysEffect")
	rays.Name = EFFECT_NAME_PREFIX .. "SunRays"
	rays.Enabled = true
	rays.Intensity = 0.035
	rays.Spread = 0.82
	rays.Parent = Lighting
end

destroyConflictingLightingEffects()
setBaseLighting()
createAtmosphere()
createColorCorrection()
createBloom()
createSunRays()

                                                            
                                                                       
print("[ReferenceClipLighting] V306K exact V287 lighting active; Edit-mode Sky/Clouds untouched.")
