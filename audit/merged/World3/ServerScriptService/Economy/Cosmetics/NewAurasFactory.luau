--!strict
-- src/ServerScriptService/Economy/Cosmetics/NewAurasFactory.luau
-- Pure programmatic factory for the 8 authored auras from the AURAS collection.
-- Built with 100% fidelity to the original .rbxm visual effects.

local CollectionService: any = nil
pcall(function()
	CollectionService = game:GetService("CollectionService")
end)

local NewAurasFactory = {}

local function buildAura08(auraFolder: Folder)
	local refMap = {}
	local pendingRefs = {}

	do
		local v_0 = Instance.new("Model")
		v_0.Name = "Aura08"
		refMap["0"] = v_0
		v_0:SetAttribute("CosmeticType", "Aura")
		v_0:SetAttribute("CosmeticId", "Aura08")
		v_0:SetAttribute("TargetPart", "HumanoidRootPart")
		v_0:SetAttribute("SupportsR6", true)
		v_0:SetAttribute("SupportsR15", true)
		v_0.Parent = auraFolder
	do
		local v_1 = Instance.new("CFrameValue")
		v_1.Name = "LocalOffset"
		refMap["2"] = v_1
		v_1.Value = CFrame.new(0.000, -0.500, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_1.Parent = v_0
	end
	do
		local v_2 = Instance.new("Part")
		v_2.Name = "EffectHolder"
		refMap["1"] = v_2
		v_2.Anchored = false
		v_2.CanCollide = false
		v_2.CanTouch = false
		v_2.CanQuery = false
		v_2.Massless = true
		v_2.CastShadow = false
		v_2.Transparency = 1.00
		v_2.Size = Vector3.new(5.000, 5.000, 5.000)
		v_2.CFrame = CFrame.new(71.300, 2.500, -5.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_2.Color = Color3.fromRGB(163, 162, 165)
		v_2.Parent = v_0
	do
		local v_3 = Instance.new("ParticleEmitter")
		v_3.Name = "Less Chromatic Line"
		refMap["3"] = v_3
		v_3.Texture = "rbxassetid://106048361727685"
		v_3.Rate = 40.00
		v_3.Speed = NumberRange.new(10.00, 10.00)
		v_3.Lifetime = NumberRange.new(2.00, 2.00)
		v_3.RotSpeed = NumberRange.new(0.00, 0.00)
		v_3.Rotation = NumberRange.new(90.00, 90.00)
		v_3.SpreadAngle = Vector2.new(90.0, -90.0)
		v_3.LightEmission = 1.00
		v_3.LightInfluence = 0.00
		v_3.LockedToPart = true
		v_3.ZOffset = -2.00
		v_3.Drag = 5.00
		v_3.Acceleration = Vector3.new(0.000, 15.000, 0.000)
		v_3.VelocityInheritance = 0.00
		v_3.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_3.EmissionDirection = Enum.NormalId.Bottom
		v_3.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_3.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.1176, 0.5137, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.6549, 0.8235, 1.0000))})
		v_3.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.50, 0.186, 0.151), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_3.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.30, 1.000, 0.000), NumberSequenceKeypoint.new(0.64, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_3.Enabled = true
		v_3.Parent = v_2
	end
	do
		local v_4 = Instance.new("ParticleEmitter")
		v_4.Name = "Water19"
		refMap["4"] = v_4
		v_4.Texture = "rbxassetid://16866011849"
		v_4.Rate = 20.00
		v_4.Speed = NumberRange.new(2.00, 2.00)
		v_4.Lifetime = NumberRange.new(1.00, 1.00)
		v_4.RotSpeed = NumberRange.new(-29.00, 28.00)
		v_4.Rotation = NumberRange.new(-360.00, 360.00)
		v_4.SpreadAngle = Vector2.new(360.0, -360.0)
		v_4.LightEmission = 1.00
		v_4.LightInfluence = 0.00
		v_4.LockedToPart = true
		v_4.ZOffset = -2.00
		v_4.Drag = 0.00
		v_4.Acceleration = Vector3.new(0.000, 3.000, 0.000)
		v_4.VelocityInheritance = 0.00
		v_4.Orientation = Enum.ParticleOrientation.FacingCamera
		v_4.EmissionDirection = Enum.NormalId.Top
		v_4.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_4.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.1176, 0.5137, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.6549, 0.8235, 1.0000))})
		v_4.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.248, 0.000), NumberSequenceKeypoint.new(1.00, 0.435, 0.000)})
		v_4.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.50, 0.255, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_4.Enabled = true
		v_4.Parent = v_2
	end
	do
		local v_5 = Instance.new("ParticleEmitter")
		v_5.Name = "Water Overlay 2"
		refMap["5"] = v_5
		v_5.Texture = "rbxassetid://83309204524962"
		v_5.Rate = 40.00
		v_5.Speed = NumberRange.new(1.00, 1.00)
		v_5.Lifetime = NumberRange.new(1.00, 1.00)
		v_5.RotSpeed = NumberRange.new(-29.00, 28.00)
		v_5.Rotation = NumberRange.new(-360.00, 360.00)
		v_5.SpreadAngle = Vector2.new(360.0, -360.0)
		v_5.LightEmission = 1.00
		v_5.LightInfluence = 0.00
		v_5.LockedToPart = true
		v_5.ZOffset = -2.00
		v_5.Drag = 0.00
		v_5.Acceleration = Vector3.new(0.000, 2.000, 0.000)
		v_5.VelocityInheritance = 0.00
		v_5.Orientation = Enum.ParticleOrientation.FacingCamera
		v_5.EmissionDirection = Enum.NormalId.Top
		v_5.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_5.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.1176, 0.5137, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.6549, 0.8235, 1.0000))})
		v_5.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 4.348, 0.000), NumberSequenceKeypoint.new(1.00, 2.919, 2.360)})
		v_5.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.50, 0.255, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_5.Enabled = true
		v_5.Parent = v_2
	end
	do
		local v_6 = Instance.new("ParticleEmitter")
		v_6.Name = "Bubble Pop"
		refMap["6"] = v_6
		v_6.Texture = "rbxassetid://129193843051009"
		v_6.Rate = 40.00
		v_6.Speed = NumberRange.new(1.00, 1.00)
		v_6.Lifetime = NumberRange.new(1.00, 1.00)
		v_6.RotSpeed = NumberRange.new(-29.00, 28.00)
		v_6.Rotation = NumberRange.new(-360.00, 360.00)
		v_6.SpreadAngle = Vector2.new(360.0, -360.0)
		v_6.LightEmission = 1.00
		v_6.LightInfluence = 0.00
		v_6.LockedToPart = true
		v_6.ZOffset = -2.00
		v_6.Drag = 0.00
		v_6.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_6.VelocityInheritance = 0.00
		v_6.Orientation = Enum.ParticleOrientation.FacingCamera
		v_6.EmissionDirection = Enum.NormalId.Top
		v_6.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_6.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.1176, 0.5137, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.6549, 0.8235, 1.0000))})
		v_6.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.124, 0.000), NumberSequenceKeypoint.new(0.49, 0.373, 0.151), NumberSequenceKeypoint.new(0.50, 1.118, 0.155), NumberSequenceKeypoint.new(0.51, 0.311, 0.159), NumberSequenceKeypoint.new(1.00, 0.311, 0.311)})
		v_6.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.50, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_6.Enabled = true
		v_6.Parent = v_2
	end
	do
		local v_7 = Instance.new("Attachment")
		v_7.Name = "Attachment"
		refMap["7"] = v_7
		v_7.CFrame = CFrame.new(0.000, 6.198, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_7.Parent = v_2
	do
		local v_8 = Instance.new("SpotLight")
		v_8.Name = "SpotLight"
		refMap["8"] = v_8
		v_8.Brightness = 5.00
		v_8.Range = 10.00
		v_8.Angle = 90.00
		v_8.Face = Enum.NormalId.Bottom
		v_8.Color = Color3.new(0.0667, 0.5961, 1.0000)
		v_8.Enabled = true
		v_8.Parent = v_7
	end
	end
	do
		local v_9 = Instance.new("ParticleEmitter")
		v_9.Name = "water current spec 4"
		refMap["9"] = v_9
		v_9.Texture = "rbxassetid://112322969979301"
		v_9.Rate = 40.00
		v_9.Speed = NumberRange.new(0.00, 0.00)
		v_9.Lifetime = NumberRange.new(2.00, 2.00)
		v_9.RotSpeed = NumberRange.new(-29.00, 28.00)
		v_9.Rotation = NumberRange.new(-360.00, 360.00)
		v_9.SpreadAngle = Vector2.new(360.0, -360.0)
		v_9.LightEmission = 1.00
		v_9.LightInfluence = 0.00
		v_9.LockedToPart = true
		v_9.ZOffset = -3.00
		v_9.Drag = 0.00
		v_9.Acceleration = Vector3.new(0.000, 2.000, 0.000)
		v_9.VelocityInheritance = 0.00
		v_9.Orientation = Enum.ParticleOrientation.FacingCamera
		v_9.EmissionDirection = Enum.NormalId.Top
		v_9.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_9.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.1176, 0.5137, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.6549, 0.8235, 1.0000))})
		v_9.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 3.106, 0.000), NumberSequenceKeypoint.new(1.00, 4.658, 1.056)})
		v_9.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.50, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_9.Enabled = true
		v_9.Parent = v_2
	end
	do
		local v_10 = Instance.new("ParticleEmitter")
		v_10.Name = "Erica Water Wave Blur 8x8"
		refMap["10"] = v_10
		v_10.Texture = "rbxassetid://123266658426840"
		v_10.Rate = 40.00
		v_10.Speed = NumberRange.new(1.00, 1.00)
		v_10.Lifetime = NumberRange.new(2.00, 2.00)
		v_10.RotSpeed = NumberRange.new(-29.00, 28.00)
		v_10.Rotation = NumberRange.new(-360.00, 360.00)
		v_10.SpreadAngle = Vector2.new(360.0, -360.0)
		v_10.LightEmission = 1.00
		v_10.LightInfluence = 0.00
		v_10.LockedToPart = true
		v_10.ZOffset = -2.00
		v_10.Drag = 0.00
		v_10.Acceleration = Vector3.new(0.000, 2.000, 0.000)
		v_10.VelocityInheritance = 0.00
		v_10.Orientation = Enum.ParticleOrientation.FacingCamera
		v_10.EmissionDirection = Enum.NormalId.Top
		v_10.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8
		v_10.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.1176, 0.5137, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.6549, 0.8235, 1.0000))})
		v_10.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 3.106, 0.000), NumberSequenceKeypoint.new(1.00, 4.658, 1.056)})
		v_10.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.50, 0.870, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_10.Enabled = true
		v_10.Parent = v_2
	end
	do
		local v_11 = Instance.new("ParticleEmitter")
		v_11.Name = "Glowing Water"
		refMap["11"] = v_11
		v_11.Texture = "rbxassetid://100867778640864"
		v_11.Rate = 20.00
		v_11.Speed = NumberRange.new(1.00, 1.00)
		v_11.Lifetime = NumberRange.new(1.00, 1.00)
		v_11.RotSpeed = NumberRange.new(-29.00, 28.00)
		v_11.Rotation = NumberRange.new(-360.00, 360.00)
		v_11.SpreadAngle = Vector2.new(360.0, -360.0)
		v_11.LightEmission = 1.00
		v_11.LightInfluence = 0.00
		v_11.LockedToPart = true
		v_11.ZOffset = -2.00
		v_11.Drag = 0.00
		v_11.Acceleration = Vector3.new(0.000, 3.000, 0.000)
		v_11.VelocityInheritance = 0.00
		v_11.Orientation = Enum.ParticleOrientation.FacingCamera
		v_11.EmissionDirection = Enum.NormalId.Top
		v_11.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_11.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.1176, 0.5137, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.6549, 0.8235, 1.0000))})
		v_11.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.248, 0.000), NumberSequenceKeypoint.new(1.00, 0.373, 0.248)})
		v_11.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.50, 0.255, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_11.Enabled = true
		v_11.Parent = v_2
	end
	do
		local v_12 = Instance.new("ParticleEmitter")
		v_12.Name = "Bubble Pop"
		refMap["12"] = v_12
		v_12.Texture = "rbxassetid://129193843051009"
		v_12.Rate = 10.00
		v_12.Speed = NumberRange.new(10.00, 10.00)
		v_12.Lifetime = NumberRange.new(2.00, 2.00)
		v_12.RotSpeed = NumberRange.new(0.00, 0.00)
		v_12.Rotation = NumberRange.new(-360.00, 360.00)
		v_12.SpreadAngle = Vector2.new(360.0, -360.0)
		v_12.LightEmission = 1.00
		v_12.LightInfluence = 0.00
		v_12.LockedToPart = true
		v_12.ZOffset = -2.00
		v_12.Drag = 5.00
		v_12.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_12.VelocityInheritance = 0.00
		v_12.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_12.EmissionDirection = Enum.NormalId.Bottom
		v_12.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_12.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.1176, 0.5137, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.6549, 0.8235, 1.0000))})
		v_12.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.124, 0.000), NumberSequenceKeypoint.new(0.49, 0.373, 0.151), NumberSequenceKeypoint.new(0.50, 1.118, 0.155), NumberSequenceKeypoint.new(0.51, 0.311, 0.159), NumberSequenceKeypoint.new(1.00, 0.311, 0.311)})
		v_12.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.30, 1.000, 0.000), NumberSequenceKeypoint.new(0.64, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_12.Enabled = true
		v_12.Parent = v_2
	end
	do
		local v_13 = Instance.new("ParticleEmitter")
		v_13.Name = "Pixelated Bubbles"
		refMap["13"] = v_13
		v_13.Texture = "rbxassetid://117574267244309"
		v_13.Rate = 40.00
		v_13.Speed = NumberRange.new(1.00, 1.00)
		v_13.Lifetime = NumberRange.new(1.00, 1.00)
		v_13.RotSpeed = NumberRange.new(0.00, 0.00)
		v_13.Rotation = NumberRange.new(0.00, 0.00)
		v_13.SpreadAngle = Vector2.new(360.0, -360.0)
		v_13.LightEmission = 1.00
		v_13.LightInfluence = 0.00
		v_13.LockedToPart = true
		v_13.ZOffset = -2.00
		v_13.Drag = 0.00
		v_13.Acceleration = Vector3.new(0.000, 2.000, 0.000)
		v_13.VelocityInheritance = 0.00
		v_13.Orientation = Enum.ParticleOrientation.FacingCamera
		v_13.EmissionDirection = Enum.NormalId.Top
		v_13.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_13.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.1176, 0.5137, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.6549, 0.8235, 1.0000))})
		v_13.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.683, 0.497)})
		v_13.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.50, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_13.Enabled = true
		v_13.Parent = v_2
	end
	do
		local v_14 = Instance.new("ParticleEmitter")
		v_14.Name = "Blinking Spec"
		refMap["14"] = v_14
		v_14.Texture = "rbxassetid://16501229582"
		v_14.Rate = 40.00
		v_14.Speed = NumberRange.new(1.00, 1.00)
		v_14.Lifetime = NumberRange.new(2.00, 2.00)
		v_14.RotSpeed = NumberRange.new(-29.00, 28.00)
		v_14.Rotation = NumberRange.new(-360.00, 360.00)
		v_14.SpreadAngle = Vector2.new(360.0, -360.0)
		v_14.LightEmission = 1.00
		v_14.LightInfluence = 0.00
		v_14.LockedToPart = true
		v_14.ZOffset = -2.00
		v_14.Drag = 0.00
		v_14.Acceleration = Vector3.new(0.000, 2.000, 0.000)
		v_14.VelocityInheritance = 0.00
		v_14.Orientation = Enum.ParticleOrientation.FacingCamera
		v_14.EmissionDirection = Enum.NormalId.Top
		v_14.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8
		v_14.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.1176, 0.5137, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.6549, 0.8235, 1.0000))})
		v_14.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.200, 0.000), NumberSequenceKeypoint.new(0.50, 0.497, 0.000), NumberSequenceKeypoint.new(1.00, 0.200, 0.000)})
		v_14.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.50, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_14.Enabled = true
		v_14.Parent = v_2
	end
	end
	end

	for _, pending in ipairs(pendingRefs) do
		local target = refMap[pending.ref]
		if target then
			pending.obj[pending.prop] = target
		end
	end
end

local function buildAura09(auraFolder: Folder)
	local refMap = {}
	local pendingRefs = {}

	do
		local v_0 = Instance.new("Model")
		v_0.Name = "Aura09"
		refMap["0"] = v_0
		v_0:SetAttribute("CosmeticType", "Aura")
		v_0:SetAttribute("CosmeticId", "Aura09")
		v_0:SetAttribute("TargetPart", "HumanoidRootPart")
		v_0:SetAttribute("SupportsR6", true)
		v_0:SetAttribute("SupportsR15", true)
		v_0.Parent = auraFolder
	do
		local v_1 = Instance.new("CFrameValue")
		v_1.Name = "LocalOffset"
		refMap["2"] = v_1
		v_1.Value = CFrame.new(0.000, -0.500, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_1.Parent = v_0
	end
	do
		local v_2 = Instance.new("Part")
		v_2.Name = "EffectHolder"
		refMap["1"] = v_2
		v_2.Anchored = false
		v_2.CanCollide = false
		v_2.CanTouch = false
		v_2.CanQuery = false
		v_2.Massless = true
		v_2.CastShadow = false
		v_2.Transparency = 1.00
		v_2.Size = Vector3.new(5.000, 5.400, 5.000)
		v_2.CFrame = CFrame.new(32.500, 2.800, -187.500, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_2.Color = Color3.fromRGB(163, 162, 165)
		v_2.Parent = v_0
	do
		local v_3 = Instance.new("Attachment")
		v_3.Name = "SpotAttachment"
		refMap["3"] = v_3
		v_3.CFrame = CFrame.new(0.000, 6.694, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_3.Parent = v_2
	do
		local v_4 = Instance.new("SpotLight")
		v_4.Name = "SpotLight"
		refMap["4"] = v_4
		v_4.Brightness = 5.00
		v_4.Range = 12.00
		v_4.Angle = 90.00
		v_4.Face = Enum.NormalId.Bottom
		v_4.Color = Color3.new(0.7961, 0.4471, 1.0000)
		v_4.Enabled = true
		v_4.Parent = v_3
	end
	end
	do
		local v_5 = Instance.new("ParticleEmitter")
		v_5.Name = "Smudged Star"
		refMap["5"] = v_5
		v_5.Texture = "rbxassetid://89272816038619"
		v_5.Rate = 20.00
		v_5.Speed = NumberRange.new(1.00, 1.00)
		v_5.Lifetime = NumberRange.new(1.00, 1.00)
		v_5.RotSpeed = NumberRange.new(-28.00, 28.00)
		v_5.Rotation = NumberRange.new(-360.00, 360.00)
		v_5.SpreadAngle = Vector2.new(360.0, -360.0)
		v_5.LightEmission = 1.00
		v_5.LightInfluence = 0.00
		v_5.LockedToPart = true
		v_5.ZOffset = 0.00
		v_5.Drag = 0.00
		v_5.Acceleration = Vector3.new(0.000, 5.000, 0.000)
		v_5.VelocityInheritance = 0.00
		v_5.Orientation = Enum.ParticleOrientation.FacingCamera
		v_5.EmissionDirection = Enum.NormalId.Top
		v_5.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_5.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.8588, 0.2941, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.7059, 0.5922, 1.0000))})
		v_5.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.47, 0.248, 0.000), NumberSequenceKeypoint.new(0.50, 0.435, 0.000), NumberSequenceKeypoint.new(0.53, 0.186, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_5.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.50, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_5.Enabled = true
		v_5.Parent = v_2
	end
	do
		local v_6 = Instance.new("ParticleEmitter")
		v_6.Name = "Simple Glowing Star InOut4x4"
		refMap["6"] = v_6
		v_6.Texture = "rbxassetid://137532295078891"
		v_6.Rate = 20.00
		v_6.Speed = NumberRange.new(0.00, 0.00)
		v_6.Lifetime = NumberRange.new(1.00, 1.00)
		v_6.RotSpeed = NumberRange.new(-28.00, 28.00)
		v_6.Rotation = NumberRange.new(-360.00, 360.00)
		v_6.SpreadAngle = Vector2.new(360.0, -360.0)
		v_6.LightEmission = 1.00
		v_6.LightInfluence = 0.00
		v_6.LockedToPart = true
		v_6.ZOffset = 0.00
		v_6.Drag = 0.00
		v_6.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_6.VelocityInheritance = 0.00
		v_6.Orientation = Enum.ParticleOrientation.FacingCamera
		v_6.EmissionDirection = Enum.NormalId.Top
		v_6.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_6.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.8588, 0.2941, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.7059, 0.5922, 1.0000))})
		v_6.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.47, 0.248, 0.000), NumberSequenceKeypoint.new(0.50, 0.435, 0.000), NumberSequenceKeypoint.new(0.53, 0.186, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_6.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.50, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_6.Enabled = true
		v_6.Parent = v_2
	end
	do
		local v_7 = Instance.new("ParticleEmitter")
		v_7.Name = "Bright Chromatic Faint Smoke"
		refMap["7"] = v_7
		v_7.Texture = "rbxassetid://73995009163702"
		v_7.Rate = 20.00
		v_7.Speed = NumberRange.new(1.00, 1.00)
		v_7.Lifetime = NumberRange.new(2.00, 2.00)
		v_7.RotSpeed = NumberRange.new(-28.00, 28.00)
		v_7.Rotation = NumberRange.new(-360.00, 360.00)
		v_7.SpreadAngle = Vector2.new(360.0, -360.0)
		v_7.LightEmission = 1.00
		v_7.LightInfluence = 0.00
		v_7.LockedToPart = true
		v_7.ZOffset = -3.00
		v_7.Drag = 0.00
		v_7.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_7.VelocityInheritance = 0.00
		v_7.Orientation = Enum.ParticleOrientation.FacingCamera
		v_7.EmissionDirection = Enum.NormalId.Top
		v_7.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_7.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.8588, 0.2941, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.7059, 0.5922, 1.0000))})
		v_7.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.988, 0.000), NumberSequenceKeypoint.new(1.00, 2.609, 1.801)})
		v_7.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.43, 1.000, 0.000), NumberSequenceKeypoint.new(0.59, 1.000, 0.000), NumberSequenceKeypoint.new(0.69, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_7.Enabled = true
		v_7.Parent = v_2
	end
	do
		local v_8 = Instance.new("ParticleEmitter")
		v_8.Name = "Growing Smoke FX"
		refMap["8"] = v_8
		v_8.Texture = "rbxassetid://16511598488"
		v_8.Rate = 20.00
		v_8.Speed = NumberRange.new(0.00, 0.00)
		v_8.Lifetime = NumberRange.new(2.00, 2.00)
		v_8.RotSpeed = NumberRange.new(-28.00, 28.00)
		v_8.Rotation = NumberRange.new(-360.00, 360.00)
		v_8.SpreadAngle = Vector2.new(360.0, -360.0)
		v_8.LightEmission = 1.00
		v_8.LightInfluence = 0.00
		v_8.LockedToPart = true
		v_8.ZOffset = -3.00
		v_8.Drag = 0.00
		v_8.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_8.VelocityInheritance = 0.00
		v_8.Orientation = Enum.ParticleOrientation.FacingCamera
		v_8.EmissionDirection = Enum.NormalId.Top
		v_8.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8
		v_8.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.8588, 0.2941, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.7059, 0.5922, 1.0000))})
		v_8.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 2.857, 0.000), NumberSequenceKeypoint.new(1.00, 4.286, 1.801)})
		v_8.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.43, 1.000, 0.000), NumberSequenceKeypoint.new(0.59, 1.000, 0.000), NumberSequenceKeypoint.new(0.69, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_8.Enabled = true
		v_8.Parent = v_2
	end
	do
		local v_9 = Instance.new("ParticleEmitter")
		v_9.Name = "Blinking Spec"
		refMap["9"] = v_9
		v_9.Texture = "rbxassetid://16501229582"
		v_9.Rate = 40.00
		v_9.Speed = NumberRange.new(10.00, 14.00)
		v_9.Lifetime = NumberRange.new(2.00, 2.00)
		v_9.RotSpeed = NumberRange.new(-28.00, 28.00)
		v_9.Rotation = NumberRange.new(-360.00, 360.00)
		v_9.SpreadAngle = Vector2.new(360.0, -360.0)
		v_9.LightEmission = 1.00
		v_9.LightInfluence = 0.00
		v_9.LockedToPart = true
		v_9.ZOffset = -3.00
		v_9.Drag = 5.00
		v_9.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_9.VelocityInheritance = 0.00
		v_9.Orientation = Enum.ParticleOrientation.FacingCamera
		v_9.EmissionDirection = Enum.NormalId.Top
		v_9.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8
		v_9.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.8588, 0.2941, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.7059, 0.5922, 1.0000))})
		v_9.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.186, 0.000), NumberSequenceKeypoint.new(1.00, 0.248, 0.000)})
		v_9.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.43, 1.000, 0.000), NumberSequenceKeypoint.new(0.59, 1.000, 0.000), NumberSequenceKeypoint.new(0.69, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_9.Enabled = true
		v_9.Parent = v_2
	end
	do
		local v_10 = Instance.new("ParticleEmitter")
		v_10.Name = "Floating Animated Spec"
		refMap["10"] = v_10
		v_10.Texture = "rbxassetid://15441262724"
		v_10.Rate = 40.00
		v_10.Speed = NumberRange.new(8.00, 12.00)
		v_10.Lifetime = NumberRange.new(2.00, 2.00)
		v_10.RotSpeed = NumberRange.new(-28.00, 28.00)
		v_10.Rotation = NumberRange.new(-360.00, 360.00)
		v_10.SpreadAngle = Vector2.new(360.0, -360.0)
		v_10.LightEmission = 1.00
		v_10.LightInfluence = 0.00
		v_10.LockedToPart = true
		v_10.ZOffset = -3.00
		v_10.Drag = 5.00
		v_10.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_10.VelocityInheritance = 0.00
		v_10.Orientation = Enum.ParticleOrientation.FacingCamera
		v_10.EmissionDirection = Enum.NormalId.Top
		v_10.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8
		v_10.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.8588, 0.2941, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.7059, 0.5922, 1.0000))})
		v_10.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.50, 0.186, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_10.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.43, 1.000, 0.000), NumberSequenceKeypoint.new(0.59, 1.000, 0.000), NumberSequenceKeypoint.new(0.69, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_10.Enabled = true
		v_10.Parent = v_2
	end
	do
		local v_11 = Instance.new("ParticleEmitter")
		v_11.Name = "Blurred Spec 1"
		refMap["11"] = v_11
		v_11.Texture = "rbxassetid://12591789267"
		v_11.Rate = 40.00
		v_11.Speed = NumberRange.new(0.00, 0.00)
		v_11.Lifetime = NumberRange.new(2.00, 2.00)
		v_11.RotSpeed = NumberRange.new(-28.00, 28.00)
		v_11.Rotation = NumberRange.new(-360.00, 360.00)
		v_11.SpreadAngle = Vector2.new(360.0, -360.0)
		v_11.LightEmission = 1.00
		v_11.LightInfluence = 0.00
		v_11.LockedToPart = true
		v_11.ZOffset = -2.00
		v_11.Drag = 0.00
		v_11.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_11.VelocityInheritance = 0.00
		v_11.Orientation = Enum.ParticleOrientation.FacingCamera
		v_11.EmissionDirection = Enum.NormalId.Top
		v_11.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_11.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.8588, 0.2941, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.7059, 0.5922, 1.0000))})
		v_11.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 4.658, 0.000), NumberSequenceKeypoint.new(1.00, 6.894, 1.801)})
		v_11.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.43, 1.000, 0.000), NumberSequenceKeypoint.new(0.59, 1.000, 0.000), NumberSequenceKeypoint.new(0.69, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_11.Enabled = true
		v_11.Parent = v_2
	end
	do
		local v_12 = Instance.new("ParticleEmitter")
		v_12.Name = "Bright Faint Smoke"
		refMap["12"] = v_12
		v_12.Texture = "rbxassetid://93892874388231"
		v_12.Rate = 20.00
		v_12.Speed = NumberRange.new(0.00, 0.00)
		v_12.Lifetime = NumberRange.new(2.00, 2.00)
		v_12.RotSpeed = NumberRange.new(-28.00, 28.00)
		v_12.Rotation = NumberRange.new(-360.00, 360.00)
		v_12.SpreadAngle = Vector2.new(360.0, -360.0)
		v_12.LightEmission = 1.00
		v_12.LightInfluence = 0.00
		v_12.LockedToPart = true
		v_12.ZOffset = -2.00
		v_12.Drag = 0.00
		v_12.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_12.VelocityInheritance = 0.00
		v_12.Orientation = Enum.ParticleOrientation.FacingCamera
		v_12.EmissionDirection = Enum.NormalId.Top
		v_12.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_12.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.8588, 0.2941, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.7059, 0.5922, 1.0000))})
		v_12.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 4.286, 0.000), NumberSequenceKeypoint.new(1.00, 6.273, 1.801)})
		v_12.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.43, 1.000, 0.000), NumberSequenceKeypoint.new(0.59, 1.000, 0.000), NumberSequenceKeypoint.new(0.69, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_12.Enabled = true
		v_12.Parent = v_2
	end
	do
		local v_13 = Instance.new("WeldConstraint")
		v_13.Name = "WeldConstraint"
		refMap["13"] = v_13
		v_13.Parent = v_2
	end
	do
		local v_14 = Instance.new("Attachment")
		v_14.Name = "ParticleLinesAttachemnt"
		refMap["14"] = v_14
		v_14.CFrame = CFrame.new(0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_14.Parent = v_2
	do
		local v_15 = Instance.new("ParticleEmitter")
		v_15.Name = "Less Chromatic Line"
		refMap["15"] = v_15
		v_15.Texture = "rbxassetid://106048361727685"
		v_15.Rate = 45.00
		v_15.Speed = NumberRange.new(18.00, 22.00)
		v_15.Lifetime = NumberRange.new(1.00, 1.00)
		v_15.RotSpeed = NumberRange.new(0.00, 0.00)
		v_15.Rotation = NumberRange.new(90.00, 90.00)
		v_15.SpreadAngle = Vector2.new(360.0, -360.0)
		v_15.LightEmission = 1.00
		v_15.LightInfluence = 0.00
		v_15.LockedToPart = true
		v_15.ZOffset = -3.00
		v_15.Drag = 5.00
		v_15.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_15.VelocityInheritance = 0.00
		v_15.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_15.EmissionDirection = Enum.NormalId.Top
		v_15.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_15.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.8588, 0.2941, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.7059, 0.5922, 1.0000))})
		v_15.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.124, 0.000), NumberSequenceKeypoint.new(1.00, 0.373, 0.000)})
		v_15.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.50, 0.000, 0.000), NumberSequenceKeypoint.new(0.71, 0.863, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_15.Enabled = true
		v_15.Parent = v_14
	end
	do
		local v_16 = Instance.new("ParticleEmitter")
		v_16.Name = "Offcentered Glowing Line"
		refMap["16"] = v_16
		v_16.Texture = "rbxassetid://6865222957"
		v_16.Rate = 45.00
		v_16.Speed = NumberRange.new(18.00, 22.00)
		v_16.Lifetime = NumberRange.new(1.00, 1.00)
		v_16.RotSpeed = NumberRange.new(0.00, 0.00)
		v_16.Rotation = NumberRange.new(90.00, 90.00)
		v_16.SpreadAngle = Vector2.new(360.0, -360.0)
		v_16.LightEmission = 1.00
		v_16.LightInfluence = 0.00
		v_16.LockedToPart = true
		v_16.ZOffset = -3.00
		v_16.Drag = 5.00
		v_16.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_16.VelocityInheritance = 0.00
		v_16.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_16.EmissionDirection = Enum.NormalId.Top
		v_16.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_16.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.8588, 0.2941, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.7059, 0.5922, 1.0000))})
		v_16.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.500, 0.000), NumberSequenceKeypoint.new(1.00, 0.500, 0.000)})
		v_16.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.50, 0.000, 0.000), NumberSequenceKeypoint.new(0.71, 0.863, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_16.Enabled = true
		v_16.Parent = v_14
	end
	end
	end
	do
		local v_17 = Instance.new("Part")
		v_17.Name = "OrbitCenter"
		refMap["17"] = v_17
		v_17.Anchored = false
		v_17.CanCollide = false
		v_17.CanTouch = false
		v_17.CanQuery = false
		v_17.Massless = true
		v_17.CastShadow = false
		v_17.Transparency = 1.00
		v_17.Size = Vector3.new(1.000, 1.000, 1.000)
		v_17.CFrame = CFrame.new(32.500, 3.000, -187.500, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_17.Color = Color3.fromRGB(163, 162, 165)
		v_17.Parent = v_0
	do
		local v_18 = Instance.new("Motor6D")
		v_18.Name = "Orbit1Motor"
		refMap["18"] = v_18
		v_18.C0 = CFrame.new(0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_18.C1 = CFrame.new(4.000, 1.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		table.insert(pendingRefs, { obj = v_18, prop = "Part0", ref = "17" })
		table.insert(pendingRefs, { obj = v_18, prop = "Part1", ref = "null" })
		v_18.Parent = v_17
	end
	do
		local v_19 = Instance.new("Motor6D")
		v_19.Name = "Orbit2Motor"
		refMap["19"] = v_19
		v_19.C0 = CFrame.new(0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_19.C1 = CFrame.new(-4.000, 1.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		table.insert(pendingRefs, { obj = v_19, prop = "Part0", ref = "17" })
		table.insert(pendingRefs, { obj = v_19, prop = "Part1", ref = "null" })
		v_19.Parent = v_17
	end
	do
		local v_20 = Instance.new("WeldConstraint")
		v_20.Name = "OrbitCenter_Weld"
		refMap["20"] = v_20
		v_20.Parent = v_17
	end
	end
	do
		local v_21 = Instance.new("Part")
		v_21.Name = "Orbit1"
		refMap["21"] = v_21
		v_21.Anchored = false
		v_21.CanCollide = false
		v_21.CanTouch = false
		v_21.CanQuery = false
		v_21.Massless = true
		v_21.CastShadow = false
		v_21.Transparency = 1.00
		v_21.Size = Vector3.new(1.000, 1.000, 1.000)
		v_21.CFrame = CFrame.new(28.500, 2.000, -187.500, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_21.Color = Color3.fromRGB(163, 162, 165)
		v_21.Parent = v_0
	do
		local v_22 = Instance.new("Attachment")
		v_22.Name = "StarAtachment"
		refMap["22"] = v_22
		v_22.CFrame = CFrame.new(0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_22.Parent = v_21
	do
		local v_23 = Instance.new("ParticleEmitter")
		v_23.Name = "Smudged Star"
		refMap["23"] = v_23
		v_23.Texture = "rbxassetid://89272816038619"
		v_23.Rate = 10.00
		v_23.Speed = NumberRange.new(0.00, 0.00)
		v_23.Lifetime = NumberRange.new(1.00, 1.00)
		v_23.RotSpeed = NumberRange.new(0.00, 0.00)
		v_23.Rotation = NumberRange.new(0.00, 0.00)
		v_23.SpreadAngle = Vector2.new(360.0, -360.0)
		v_23.LightEmission = 1.00
		v_23.LightInfluence = 0.00
		v_23.LockedToPart = true
		v_23.ZOffset = 0.00
		v_23.Drag = 0.00
		v_23.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_23.VelocityInheritance = 0.00
		v_23.Orientation = Enum.ParticleOrientation.FacingCamera
		v_23.EmissionDirection = Enum.NormalId.Top
		v_23.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_23.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.8588, 0.2941, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.7059, 0.5922, 1.0000))})
		v_23.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.311, 0.000), NumberSequenceKeypoint.new(1.00, 2.112, 1.000)})
		v_23.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.50, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_23.Enabled = true
		v_23.Parent = v_22
	end
	do
		local v_24 = Instance.new("ParticleEmitter")
		v_24.Name = "Impact6122"
		refMap["24"] = v_24
		v_24.Texture = "rbxassetid://115257157082446"
		v_24.Rate = 12.00
		v_24.Speed = NumberRange.new(0.00, 0.00)
		v_24.Lifetime = NumberRange.new(1.00, 1.00)
		v_24.RotSpeed = NumberRange.new(-29.00, 28.00)
		v_24.Rotation = NumberRange.new(-360.00, 360.00)
		v_24.SpreadAngle = Vector2.new(360.0, -360.0)
		v_24.LightEmission = 1.00
		v_24.LightInfluence = 0.00
		v_24.LockedToPart = true
		v_24.ZOffset = 0.00
		v_24.Drag = 0.00
		v_24.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_24.VelocityInheritance = 0.00
		v_24.Orientation = Enum.ParticleOrientation.FacingCamera
		v_24.EmissionDirection = Enum.NormalId.Top
		v_24.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_24.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.8588, 0.2941, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.7059, 0.5922, 1.0000))})
		v_24.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.683, 0.683)})
		v_24.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.50, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_24.Enabled = true
		v_24.Parent = v_22
	end
	do
		local v_25 = Instance.new("ParticleEmitter")
		v_25.Name = "Circle4"
		refMap["25"] = v_25
		v_25.Texture = "rbxassetid://16877851515"
		v_25.Rate = 12.00
		v_25.Speed = NumberRange.new(0.00, 0.00)
		v_25.Lifetime = NumberRange.new(1.00, 1.00)
		v_25.RotSpeed = NumberRange.new(-29.00, 28.00)
		v_25.Rotation = NumberRange.new(-360.00, 360.00)
		v_25.SpreadAngle = Vector2.new(360.0, -360.0)
		v_25.LightEmission = 1.00
		v_25.LightInfluence = 0.00
		v_25.LockedToPart = true
		v_25.ZOffset = 0.00
		v_25.Drag = 0.00
		v_25.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_25.VelocityInheritance = 0.00
		v_25.Orientation = Enum.ParticleOrientation.FacingCamera
		v_25.EmissionDirection = Enum.NormalId.Top
		v_25.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_25.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.8588, 0.2941, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.7059, 0.5922, 1.0000))})
		v_25.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 1.366, 0.500)})
		v_25.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.50, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_25.Enabled = true
		v_25.Parent = v_22
	end
	end
	do
		local v_26 = Instance.new("ParticleEmitter")
		v_26.Name = "Smudged Star"
		refMap["26"] = v_26
		v_26.Texture = "rbxassetid://89272816038619"
		v_26.Rate = 12.00
		v_26.Speed = NumberRange.new(0.00, 0.00)
		v_26.Lifetime = NumberRange.new(1.00, 1.00)
		v_26.RotSpeed = NumberRange.new(-29.00, 28.00)
		v_26.Rotation = NumberRange.new(-360.00, 360.00)
		v_26.SpreadAngle = Vector2.new(360.0, -360.0)
		v_26.LightEmission = 1.00
		v_26.LightInfluence = 0.00
		v_26.LockedToPart = false
		v_26.ZOffset = 0.00
		v_26.Drag = 0.00
		v_26.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_26.VelocityInheritance = 0.00
		v_26.Orientation = Enum.ParticleOrientation.FacingCamera
		v_26.EmissionDirection = Enum.NormalId.Top
		v_26.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_26.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.8588, 0.2941, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.7059, 0.5922, 1.0000))})
		v_26.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.48, 0.311, 0.000), NumberSequenceKeypoint.new(0.50, 1.491, 0.000), NumberSequenceKeypoint.new(0.52, 0.248, 0.000), NumberSequenceKeypoint.new(1.00, 0.186, 0.000)})
		v_26.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.50, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_26.Enabled = true
		v_26.Parent = v_21
	end
	do
		local v_27 = Instance.new("Attachment")
		v_27.Name = "Attachment"
		refMap["27"] = v_27
		v_27.CFrame = CFrame.new(0.000, 0.000, -1.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_27.Parent = v_21
	do
		local v_28 = Instance.new("Trail")
		v_28.Name = "Beam11"
		refMap["28"] = v_28
		v_28.Texture = "rbxassetid://16892453445"
		v_28.Lifetime = 0.50
		v_28.MinLength = 0.00
		v_28.LightEmission = 1.00
		v_28.LightInfluence = 0.00
		v_28.FaceCamera = true
		v_28.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.9686, 0.5059, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.7569, 0.3412, 1.0000))})
		v_28.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.50, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_28.Enabled = true
		table.insert(pendingRefs, { obj = v_28, prop = "Attachment0", ref = "27" })
		table.insert(pendingRefs, { obj = v_28, prop = "Attachment1", ref = "29" })
		v_28.Parent = v_27
	end
	do
		local v_29 = Instance.new("Trail")
		v_29.Name = "Beam123"
		refMap["30"] = v_29
		v_29.Texture = "rbxassetid://136624058127139"
		v_29.Lifetime = 0.55
		v_29.MinLength = 0.00
		v_29.LightEmission = 1.00
		v_29.LightInfluence = 0.00
		v_29.FaceCamera = true
		v_29.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.9686, 0.5059, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.7569, 0.3412, 1.0000))})
		v_29.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.50, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_29.Enabled = true
		table.insert(pendingRefs, { obj = v_29, prop = "Attachment0", ref = "27" })
		table.insert(pendingRefs, { obj = v_29, prop = "Attachment1", ref = "29" })
		v_29.Parent = v_27
	end
	end
	do
		local v_30 = Instance.new("Attachment")
		v_30.Name = "Attachment"
		refMap["29"] = v_30
		v_30.CFrame = CFrame.new(0.000, 0.000, 1.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_30.Parent = v_21
	end
	do
		local v_31 = Instance.new("WeldConstraint")
		v_31.Name = "Orbit1_Weld"
		refMap["31"] = v_31
		v_31.Parent = v_21
	end
	end
	do
		local v_32 = Instance.new("Part")
		v_32.Name = "Orbit2"
		refMap["32"] = v_32
		v_32.Anchored = false
		v_32.CanCollide = false
		v_32.CanTouch = false
		v_32.CanQuery = false
		v_32.Massless = true
		v_32.CastShadow = false
		v_32.Transparency = 1.00
		v_32.Size = Vector3.new(1.000, 1.000, 1.000)
		v_32.CFrame = CFrame.new(36.500, 2.000, -187.500, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_32.Color = Color3.fromRGB(163, 162, 165)
		v_32.Parent = v_0
	do
		local v_33 = Instance.new("Attachment")
		v_33.Name = "Attachment"
		refMap["33"] = v_33
		v_33.CFrame = CFrame.new(0.000, 0.000, -1.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_33.Parent = v_32
	do
		local v_34 = Instance.new("Trail")
		v_34.Name = "Beam11"
		refMap["34"] = v_34
		v_34.Texture = "rbxassetid://16892453445"
		v_34.Lifetime = 0.50
		v_34.MinLength = 0.00
		v_34.LightEmission = 1.00
		v_34.LightInfluence = 0.00
		v_34.FaceCamera = true
		v_34.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.9686, 0.5059, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.7569, 0.3412, 1.0000))})
		v_34.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.50, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_34.Enabled = true
		table.insert(pendingRefs, { obj = v_34, prop = "Attachment0", ref = "33" })
		table.insert(pendingRefs, { obj = v_34, prop = "Attachment1", ref = "35" })
		v_34.Parent = v_33
	end
	do
		local v_35 = Instance.new("Trail")
		v_35.Name = "Beam123"
		refMap["36"] = v_35
		v_35.Texture = "rbxassetid://136624058127139"
		v_35.Lifetime = 0.55
		v_35.MinLength = 0.00
		v_35.LightEmission = 1.00
		v_35.LightInfluence = 0.00
		v_35.FaceCamera = true
		v_35.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.9686, 0.5059, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.7569, 0.3412, 1.0000))})
		v_35.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.50, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_35.Enabled = true
		table.insert(pendingRefs, { obj = v_35, prop = "Attachment0", ref = "33" })
		table.insert(pendingRefs, { obj = v_35, prop = "Attachment1", ref = "35" })
		v_35.Parent = v_33
	end
	end
	do
		local v_36 = Instance.new("Attachment")
		v_36.Name = "Attachment"
		refMap["35"] = v_36
		v_36.CFrame = CFrame.new(0.000, 0.000, 1.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_36.Parent = v_32
	end
	do
		local v_37 = Instance.new("ParticleEmitter")
		v_37.Name = "Smudged Star"
		refMap["37"] = v_37
		v_37.Texture = "rbxassetid://89272816038619"
		v_37.Rate = 12.00
		v_37.Speed = NumberRange.new(0.00, 0.00)
		v_37.Lifetime = NumberRange.new(1.00, 1.00)
		v_37.RotSpeed = NumberRange.new(-29.00, 28.00)
		v_37.Rotation = NumberRange.new(-360.00, 360.00)
		v_37.SpreadAngle = Vector2.new(360.0, -360.0)
		v_37.LightEmission = 1.00
		v_37.LightInfluence = 0.00
		v_37.LockedToPart = false
		v_37.ZOffset = 0.00
		v_37.Drag = 0.00
		v_37.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_37.VelocityInheritance = 0.00
		v_37.Orientation = Enum.ParticleOrientation.FacingCamera
		v_37.EmissionDirection = Enum.NormalId.Top
		v_37.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_37.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.8588, 0.2941, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.7059, 0.5922, 1.0000))})
		v_37.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.48, 0.311, 0.000), NumberSequenceKeypoint.new(0.50, 1.491, 0.000), NumberSequenceKeypoint.new(0.52, 0.248, 0.000), NumberSequenceKeypoint.new(1.00, 0.186, 0.000)})
		v_37.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.50, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_37.Enabled = true
		v_37.Parent = v_32
	end
	do
		local v_38 = Instance.new("Attachment")
		v_38.Name = "StarAtachment"
		refMap["38"] = v_38
		v_38.CFrame = CFrame.new(0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_38.Parent = v_32
	do
		local v_39 = Instance.new("ParticleEmitter")
		v_39.Name = "Smudged Star"
		refMap["39"] = v_39
		v_39.Texture = "rbxassetid://89272816038619"
		v_39.Rate = 10.00
		v_39.Speed = NumberRange.new(0.00, 0.00)
		v_39.Lifetime = NumberRange.new(1.00, 1.00)
		v_39.RotSpeed = NumberRange.new(0.00, 0.00)
		v_39.Rotation = NumberRange.new(0.00, 0.00)
		v_39.SpreadAngle = Vector2.new(360.0, -360.0)
		v_39.LightEmission = 1.00
		v_39.LightInfluence = 0.00
		v_39.LockedToPart = true
		v_39.ZOffset = 0.00
		v_39.Drag = 0.00
		v_39.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_39.VelocityInheritance = 0.00
		v_39.Orientation = Enum.ParticleOrientation.FacingCamera
		v_39.EmissionDirection = Enum.NormalId.Top
		v_39.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_39.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.8588, 0.2941, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.7059, 0.5922, 1.0000))})
		v_39.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.311, 0.000), NumberSequenceKeypoint.new(1.00, 2.112, 1.000)})
		v_39.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.50, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_39.Enabled = true
		v_39.Parent = v_38
	end
	do
		local v_40 = Instance.new("ParticleEmitter")
		v_40.Name = "Impact6122"
		refMap["40"] = v_40
		v_40.Texture = "rbxassetid://115257157082446"
		v_40.Rate = 12.00
		v_40.Speed = NumberRange.new(0.00, 0.00)
		v_40.Lifetime = NumberRange.new(1.00, 1.00)
		v_40.RotSpeed = NumberRange.new(-29.00, 28.00)
		v_40.Rotation = NumberRange.new(-360.00, 360.00)
		v_40.SpreadAngle = Vector2.new(360.0, -360.0)
		v_40.LightEmission = 1.00
		v_40.LightInfluence = 0.00
		v_40.LockedToPart = true
		v_40.ZOffset = 0.00
		v_40.Drag = 0.00
		v_40.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_40.VelocityInheritance = 0.00
		v_40.Orientation = Enum.ParticleOrientation.FacingCamera
		v_40.EmissionDirection = Enum.NormalId.Top
		v_40.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_40.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.8588, 0.2941, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.7059, 0.5922, 1.0000))})
		v_40.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.683, 0.683)})
		v_40.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.50, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_40.Enabled = true
		v_40.Parent = v_38
	end
	do
		local v_41 = Instance.new("ParticleEmitter")
		v_41.Name = "Circle4"
		refMap["41"] = v_41
		v_41.Texture = "rbxassetid://16877851515"
		v_41.Rate = 12.00
		v_41.Speed = NumberRange.new(0.00, 0.00)
		v_41.Lifetime = NumberRange.new(1.00, 1.00)
		v_41.RotSpeed = NumberRange.new(-29.00, 28.00)
		v_41.Rotation = NumberRange.new(-360.00, 360.00)
		v_41.SpreadAngle = Vector2.new(360.0, -360.0)
		v_41.LightEmission = 1.00
		v_41.LightInfluence = 0.00
		v_41.LockedToPart = true
		v_41.ZOffset = 0.00
		v_41.Drag = 0.00
		v_41.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_41.VelocityInheritance = 0.00
		v_41.Orientation = Enum.ParticleOrientation.FacingCamera
		v_41.EmissionDirection = Enum.NormalId.Top
		v_41.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_41.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.8588, 0.2941, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.7059, 0.5922, 1.0000))})
		v_41.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 1.366, 0.500)})
		v_41.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.50, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_41.Enabled = true
		v_41.Parent = v_38
	end
	end
	do
		local v_42 = Instance.new("WeldConstraint")
		v_42.Name = "Orbit2_Weld"
		refMap["42"] = v_42
		v_42.Parent = v_32
	end
	end
	end

	for _, pending in ipairs(pendingRefs) do
		local target = refMap[pending.ref]
		if target then
			pending.obj[pending.prop] = target
		end
	end
end

local function buildAura10(auraFolder: Folder)
	local refMap = {}
	local pendingRefs = {}

	do
		local v_0 = Instance.new("Model")
		v_0.Name = "Aura10"
		refMap["0"] = v_0
		v_0:SetAttribute("CosmeticType", "Aura")
		v_0:SetAttribute("CosmeticId", "Aura10")
		v_0:SetAttribute("TargetPart", "HumanoidRootPart")
		v_0:SetAttribute("SupportsR6", true)
		v_0:SetAttribute("SupportsR15", true)
		v_0.Parent = auraFolder
	do
		local v_1 = Instance.new("CFrameValue")
		v_1.Name = "LocalOffset"
		refMap["2"] = v_1
		v_1.Value = CFrame.new(0.000, -0.500, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_1.Parent = v_0
	end
	do
		local v_2 = Instance.new("Part")
		v_2.Name = "EffectHolder"
		refMap["1"] = v_2
		v_2.Anchored = false
		v_2.CanCollide = false
		v_2.CanTouch = false
		v_2.CanQuery = false
		v_2.Massless = true
		v_2.CastShadow = false
		v_2.Transparency = 1.00
		v_2.Size = Vector3.new(4.000, 6.000, 3.000)
		v_2.CFrame = CFrame.new(-140.500, 22.000, -29.000, 0.000, 0.000, -1.000, 0.000, 1.000, 0.000, 1.000, 0.000, 0.000)
		v_2.Color = Color3.fromRGB(163, 162, 165)
		v_2.Parent = v_0
	do
		local v_3 = Instance.new("Attachment")
		v_3.Name = "Attachment"
		refMap["3"] = v_3
		v_3.CFrame = CFrame.new(0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_3.Parent = v_2
	do
		local v_4 = Instance.new("ParticleEmitter")
		v_4.Name = "windfs"
		refMap["4"] = v_4
		v_4.Texture = "rbxassetid://135128020878697"
		v_4.Rate = 2.00
		v_4.Speed = NumberRange.new(0.00, 0.00)
		v_4.Lifetime = NumberRange.new(1.00, 1.50)
		v_4.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_4.Rotation = NumberRange.new(-360.00, 360.00)
		v_4.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_4.LightEmission = 0.00
		v_4.LightInfluence = 0.00
		v_4.LockedToPart = true
		v_4.ZOffset = 2.09
		v_4.Drag = 2.00
		v_4.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_4.VelocityInheritance = 0.00
		v_4.Orientation = Enum.ParticleOrientation.FacingCamera
		v_4.EmissionDirection = Enum.NormalId.Top
		v_4.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(0.22, Color3.new(0.0000, 0.3125, 0.1380)), ColorSequenceKeypoint.new(0.56, Color3.new(0.0000, 0.0000, 0.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0000, 0.0000, 0.0000))})
		v_4.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 3.532, 0.000), NumberSequenceKeypoint.new(0.48, 5.112, 0.000), NumberSequenceKeypoint.new(1.00, 5.577, 0.000)})
		v_4.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_4.Enabled = true
		v_4.Parent = v_3
	end
	do
		local v_5 = Instance.new("ParticleEmitter")
		v_5.Name = "cat spec 8"
		refMap["5"] = v_5
		v_5.Texture = "rbxassetid://101658731548844"
		v_5.Rate = 2.00
		v_5.Speed = NumberRange.new(10.00, 20.00)
		v_5.Lifetime = NumberRange.new(0.40, 1.00)
		v_5.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_5.Rotation = NumberRange.new(-360.00, 360.00)
		v_5.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_5.LightEmission = 0.00
		v_5.LightInfluence = 0.00
		v_5.LockedToPart = false
		v_5.ZOffset = 2.02
		v_5.Drag = 4.00
		v_5.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_5.VelocityInheritance = 0.00
		v_5.Orientation = Enum.ParticleOrientation.FacingCamera
		v_5.EmissionDirection = Enum.NormalId.Top
		v_5.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_5.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_5.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_5.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_5.Enabled = true
		v_5.Parent = v_3
	end
	do
		local v_6 = Instance.new("ParticleEmitter")
		v_6.Name = "grainy shockwave 2"
		refMap["6"] = v_6
		v_6.Texture = "rbxassetid://16509144751"
		v_6.Rate = 2.00
		v_6.Speed = NumberRange.new(0.00, 0.00)
		v_6.Lifetime = NumberRange.new(0.40, 1.00)
		v_6.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_6.Rotation = NumberRange.new(-360.00, 360.00)
		v_6.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_6.LightEmission = 0.00
		v_6.LightInfluence = 0.00
		v_6.LockedToPart = true
		v_6.ZOffset = 2.00
		v_6.Drag = 2.00
		v_6.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_6.VelocityInheritance = 0.00
		v_6.Orientation = Enum.ParticleOrientation.FacingCamera
		v_6.EmissionDirection = Enum.NormalId.Top
		v_6.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_6.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.533, 0.000), NumberSequenceKeypoint.new(0.48, 3.667, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_6.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.63, 0.343, 0.000), NumberSequenceKeypoint.new(0.89, 0.643, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_6.Enabled = true
		v_6.Parent = v_3
	end
	do
		local v_7 = Instance.new("ParticleEmitter")
		v_7.Name = "cursed energy 2"
		refMap["7"] = v_7
		v_7.Texture = "rbxassetid://78422400450982"
		v_7.Rate = 2.00
		v_7.Speed = NumberRange.new(0.00, 0.00)
		v_7.Lifetime = NumberRange.new(0.40, 1.00)
		v_7.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_7.Rotation = NumberRange.new(-360.00, 360.00)
		v_7.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_7.LightEmission = 0.00
		v_7.LightInfluence = 0.00
		v_7.LockedToPart = true
		v_7.ZOffset = 1.04
		v_7.Drag = 2.00
		v_7.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_7.VelocityInheritance = 0.00
		v_7.Orientation = Enum.ParticleOrientation.FacingCamera
		v_7.EmissionDirection = Enum.NormalId.Top
		v_7.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_7.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.862, 0.000), NumberSequenceKeypoint.new(0.48, 4.143, 0.000), NumberSequenceKeypoint.new(1.00, 4.519, 0.000)})
		v_7.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_7.Enabled = true
		v_7.Parent = v_3
	end
	do
		local v_8 = Instance.new("PointLight")
		v_8.Name = "PointLight"
		refMap["8"] = v_8
		v_8.Brightness = 2.00
		v_8.Range = 8.00
		v_8.Shadows = false
		v_8.Color = Color3.new(0.0980, 1.0000, 0.4980)
		v_8.Enabled = true
		v_8.Parent = v_3
	end
	do
		local v_9 = Instance.new("ParticleEmitter")
		v_9.Name = "Thin realistic shockwave"
		refMap["9"] = v_9
		v_9.Texture = "rbxassetid://12906276200"
		v_9.Rate = 2.00
		v_9.Speed = NumberRange.new(0.00, 0.00)
		v_9.Lifetime = NumberRange.new(0.40, 1.00)
		v_9.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_9.Rotation = NumberRange.new(-360.00, 360.00)
		v_9.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_9.LightEmission = 0.00
		v_9.LightInfluence = 0.00
		v_9.LockedToPart = true
		v_9.ZOffset = 2.05
		v_9.Drag = 2.00
		v_9.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_9.VelocityInheritance = 0.00
		v_9.Orientation = Enum.ParticleOrientation.FacingCamera
		v_9.EmissionDirection = Enum.NormalId.Top
		v_9.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_9.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_9.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.533, 0.000), NumberSequenceKeypoint.new(0.48, 3.667, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_9.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.63, 0.343, 0.000), NumberSequenceKeypoint.new(0.89, 0.643, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_9.Enabled = true
		v_9.Parent = v_3
	end
	do
		local v_10 = Instance.new("ParticleEmitter")
		v_10.Name = "Cursed Energy Disperse 8x8"
		refMap["10"] = v_10
		v_10.Texture = "rbxassetid://97051019398375"
		v_10.Rate = 2.00
		v_10.Speed = NumberRange.new(0.00, 0.00)
		v_10.Lifetime = NumberRange.new(0.40, 1.00)
		v_10.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_10.Rotation = NumberRange.new(-360.00, 360.00)
		v_10.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_10.LightEmission = 0.00
		v_10.LightInfluence = 0.00
		v_10.LockedToPart = true
		v_10.ZOffset = 2.04
		v_10.Drag = 2.00
		v_10.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_10.VelocityInheritance = 0.00
		v_10.Orientation = Enum.ParticleOrientation.FacingCamera
		v_10.EmissionDirection = Enum.NormalId.Top
		v_10.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8
		v_10.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_10.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.533, 0.000), NumberSequenceKeypoint.new(0.48, 3.667, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_10.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_10.Enabled = true
		v_10.Parent = v_3
	end
	do
		local v_11 = Instance.new("ParticleEmitter")
		v_11.Name = "Fire45"
		refMap["11"] = v_11
		v_11.Texture = "rbxassetid://16860419961"
		v_11.Rate = 3.00
		v_11.Speed = NumberRange.new(0.00, 0.00)
		v_11.Lifetime = NumberRange.new(0.70, 2.00)
		v_11.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_11.Rotation = NumberRange.new(-360.00, 360.00)
		v_11.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_11.LightEmission = 0.00
		v_11.LightInfluence = 0.00
		v_11.LockedToPart = true
		v_11.ZOffset = 2.03
		v_11.Drag = 2.00
		v_11.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_11.VelocityInheritance = 0.00
		v_11.Orientation = Enum.ParticleOrientation.FacingCamera
		v_11.EmissionDirection = Enum.NormalId.Top
		v_11.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_11.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0980, 1.0000, 0.4980)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0980, 1.0000, 0.4980))})
		v_11.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 5.724, 0.000), NumberSequenceKeypoint.new(0.48, 8.285, 0.000), NumberSequenceKeypoint.new(1.00, 9.038, 0.000)})
		v_11.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_11.Enabled = true
		v_11.Parent = v_3
	end
	do
		local v_12 = Instance.new("ParticleEmitter")
		v_12.Name = "cursed energy3421"
		refMap["12"] = v_12
		v_12.Texture = "rbxassetid://17006172452"
		v_12.Rate = 2.00
		v_12.Speed = NumberRange.new(0.00, 0.00)
		v_12.Lifetime = NumberRange.new(0.40, 1.00)
		v_12.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_12.Rotation = NumberRange.new(-360.00, 360.00)
		v_12.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_12.LightEmission = 0.00
		v_12.LightInfluence = 0.00
		v_12.LockedToPart = true
		v_12.ZOffset = 1.01
		v_12.Drag = 2.00
		v_12.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_12.VelocityInheritance = 0.00
		v_12.Orientation = Enum.ParticleOrientation.FacingCamera
		v_12.EmissionDirection = Enum.NormalId.Top
		v_12.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_12.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_12.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.862, 0.000), NumberSequenceKeypoint.new(0.48, 4.143, 0.000), NumberSequenceKeypoint.new(1.00, 4.519, 0.000)})
		v_12.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.317, 0.000), NumberSequenceKeypoint.new(0.86, 0.683, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_12.Enabled = true
		v_12.Parent = v_3
	end
	do
		local v_13 = Instance.new("ParticleEmitter")
		v_13.Name = "Light Ray"
		refMap["13"] = v_13
		v_13.Texture = "rbxassetid://14128173698"
		v_13.Rate = 4.00
		v_13.Speed = NumberRange.new(0.00, 0.00)
		v_13.Lifetime = NumberRange.new(0.40, 1.00)
		v_13.RotSpeed = NumberRange.new(30.00, 50.00)
		v_13.Rotation = NumberRange.new(180.00, 180.00)
		v_13.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_13.LightEmission = 0.00
		v_13.LightInfluence = 0.00
		v_13.LockedToPart = true
		v_13.ZOffset = 1.00
		v_13.Drag = 2.00
		v_13.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_13.VelocityInheritance = 0.00
		v_13.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_13.EmissionDirection = Enum.NormalId.Top
		v_13.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_13.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0980, 1.0000, 0.4980)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0980, 1.0000, 0.4980))})
		v_13.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.15, 2.504, 0.715), NumberSequenceKeypoint.new(0.42, 3.688, 0.779), NumberSequenceKeypoint.new(1.00, 4.043, 0.909)})
		v_13.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.263, 0.000), NumberSequenceKeypoint.new(0.85, 0.557, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_13.Enabled = true
		v_13.Parent = v_3
	end
	do
		local v_14 = Instance.new("ParticleEmitter")
		v_14.Name = "cursed energy spec"
		refMap["14"] = v_14
		v_14.Texture = "rbxassetid://85688545954016"
		v_14.Rate = 2.00
		v_14.Speed = NumberRange.new(10.00, 20.00)
		v_14.Lifetime = NumberRange.new(0.40, 1.00)
		v_14.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_14.Rotation = NumberRange.new(-360.00, 360.00)
		v_14.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_14.LightEmission = 0.00
		v_14.LightInfluence = 0.00
		v_14.LockedToPart = false
		v_14.ZOffset = 2.04
		v_14.Drag = 4.00
		v_14.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_14.VelocityInheritance = 0.00
		v_14.Orientation = Enum.ParticleOrientation.FacingCamera
		v_14.EmissionDirection = Enum.NormalId.Top
		v_14.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_14.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_14.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_14.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_14.Enabled = true
		v_14.Parent = v_3
	end
	do
		local v_15 = Instance.new("ParticleEmitter")
		v_15.Name = "Fire45"
		refMap["15"] = v_15
		v_15.Texture = "rbxassetid://16860419961"
		v_15.Rate = 3.00
		v_15.Speed = NumberRange.new(0.00, 0.00)
		v_15.Lifetime = NumberRange.new(0.40, 1.00)
		v_15.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_15.Rotation = NumberRange.new(-360.00, 360.00)
		v_15.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_15.LightEmission = 0.00
		v_15.LightInfluence = 0.00
		v_15.LockedToPart = true
		v_15.ZOffset = 2.03
		v_15.Drag = 2.00
		v_15.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_15.VelocityInheritance = 0.00
		v_15.Orientation = Enum.ParticleOrientation.FacingCamera
		v_15.EmissionDirection = Enum.NormalId.Top
		v_15.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_15.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_15.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 5.067, 0.000), NumberSequenceKeypoint.new(0.48, 7.333, 0.000), NumberSequenceKeypoint.new(1.00, 8.000, 0.000)})
		v_15.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_15.Enabled = true
		v_15.Parent = v_3
	end
	do
		local v_16 = Instance.new("ParticleEmitter")
		v_16.Name = "Thin realistic shockwave"
		refMap["16"] = v_16
		v_16.Texture = "rbxassetid://12906276200"
		v_16.Rate = 2.00
		v_16.Speed = NumberRange.new(0.00, 0.00)
		v_16.Lifetime = NumberRange.new(0.40, 1.00)
		v_16.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_16.Rotation = NumberRange.new(-360.00, 360.00)
		v_16.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_16.LightEmission = 0.00
		v_16.LightInfluence = 0.00
		v_16.LockedToPart = true
		v_16.ZOffset = 2.07
		v_16.Drag = 2.00
		v_16.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_16.VelocityInheritance = 0.00
		v_16.Orientation = Enum.ParticleOrientation.FacingCamera
		v_16.EmissionDirection = Enum.NormalId.Top
		v_16.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_16.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_16.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 3.751, 0.000), NumberSequenceKeypoint.new(0.48, 5.429, 0.000), NumberSequenceKeypoint.new(1.00, 5.923, 0.000)})
		v_16.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.63, 0.343, 0.000), NumberSequenceKeypoint.new(0.89, 0.643, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_16.Enabled = true
		v_16.Parent = v_3
	end
	do
		local v_17 = Instance.new("ParticleEmitter")
		v_17.Name = "cursed energy 2"
		refMap["17"] = v_17
		v_17.Texture = "rbxassetid://78422400450982"
		v_17.Rate = 2.00
		v_17.Speed = NumberRange.new(0.00, 0.00)
		v_17.Lifetime = NumberRange.new(0.40, 1.00)
		v_17.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_17.Rotation = NumberRange.new(-360.00, 360.00)
		v_17.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_17.LightEmission = 0.00
		v_17.LightInfluence = 0.00
		v_17.LockedToPart = true
		v_17.ZOffset = 2.07
		v_17.Drag = 2.00
		v_17.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_17.VelocityInheritance = 0.00
		v_17.Orientation = Enum.ParticleOrientation.FacingCamera
		v_17.EmissionDirection = Enum.NormalId.Top
		v_17.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_17.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.533, 0.000), NumberSequenceKeypoint.new(0.48, 3.667, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_17.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_17.Enabled = true
		v_17.Parent = v_3
	end
	do
		local v_18 = Instance.new("ParticleEmitter")
		v_18.Name = "Fire54"
		refMap["18"] = v_18
		v_18.Texture = "rbxassetid://17006155963"
		v_18.Rate = 3.00
		v_18.Speed = NumberRange.new(0.00, 0.00)
		v_18.Lifetime = NumberRange.new(0.40, 1.00)
		v_18.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_18.Rotation = NumberRange.new(-360.00, 360.00)
		v_18.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_18.LightEmission = 0.00
		v_18.LightInfluence = 0.00
		v_18.LockedToPart = true
		v_18.ZOffset = 1.04
		v_18.Drag = 2.00
		v_18.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_18.VelocityInheritance = 0.00
		v_18.Orientation = Enum.ParticleOrientation.FacingCamera
		v_18.EmissionDirection = Enum.NormalId.Top
		v_18.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_18.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0980, 1.0000, 0.4980)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0980, 1.0000, 0.4980))})
		v_18.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.533, 0.000), NumberSequenceKeypoint.new(0.48, 3.667, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_18.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_18.Enabled = true
		v_18.Parent = v_3
	end
	do
		local v_19 = Instance.new("ParticleEmitter")
		v_19.Name = "Slash22"
		refMap["19"] = v_19
		v_19.Texture = "rbxassetid://121148164489745"
		v_19.Rate = 2.00
		v_19.Speed = NumberRange.new(0.00, 0.00)
		v_19.Lifetime = NumberRange.new(0.40, 1.00)
		v_19.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_19.Rotation = NumberRange.new(-360.00, 360.00)
		v_19.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_19.LightEmission = 0.00
		v_19.LightInfluence = 0.00
		v_19.LockedToPart = true
		v_19.ZOffset = 1.04
		v_19.Drag = 2.00
		v_19.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_19.VelocityInheritance = 0.00
		v_19.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_19.EmissionDirection = Enum.NormalId.Top
		v_19.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_19.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_19.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 3.410, 0.000), NumberSequenceKeypoint.new(0.48, 4.936, 0.000), NumberSequenceKeypoint.new(1.00, 5.385, 0.000)})
		v_19.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_19.Enabled = true
		v_19.Parent = v_3
	end
	do
		local v_20 = Instance.new("ParticleEmitter")
		v_20.Name = "Strange VFX"
		refMap["20"] = v_20
		v_20.Texture = "rbxassetid://18369800560"
		v_20.Rate = 3.00
		v_20.Speed = NumberRange.new(0.00, 0.00)
		v_20.Lifetime = NumberRange.new(0.70, 2.00)
		v_20.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_20.Rotation = NumberRange.new(-360.00, 360.00)
		v_20.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_20.LightEmission = 0.00
		v_20.LightInfluence = 0.00
		v_20.LockedToPart = true
		v_20.ZOffset = 1.02
		v_20.Drag = 2.00
		v_20.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_20.VelocityInheritance = 0.00
		v_20.Orientation = Enum.ParticleOrientation.FacingCamera
		v_20.EmissionDirection = Enum.NormalId.Top
		v_20.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_20.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_20.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.862, 0.000), NumberSequenceKeypoint.new(0.48, 4.143, 0.000), NumberSequenceKeypoint.new(1.00, 4.519, 0.000)})
		v_20.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_20.Enabled = true
		v_20.Parent = v_3
	end
	do
		local v_21 = Instance.new("ParticleEmitter")
		v_21.Name = "dis dark circle"
		refMap["21"] = v_21
		v_21.Texture = "rbxassetid://83617429710480"
		v_21.Rate = 2.00
		v_21.Speed = NumberRange.new(0.00, 0.00)
		v_21.Lifetime = NumberRange.new(0.40, 1.00)
		v_21.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_21.Rotation = NumberRange.new(-360.00, 360.00)
		v_21.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_21.LightEmission = 0.00
		v_21.LightInfluence = 0.00
		v_21.LockedToPart = true
		v_21.ZOffset = 2.05
		v_21.Drag = 2.00
		v_21.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_21.VelocityInheritance = 0.00
		v_21.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_21.EmissionDirection = Enum.NormalId.Top
		v_21.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_21.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.533, 0.000), NumberSequenceKeypoint.new(0.48, 3.667, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_21.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_21.Enabled = true
		v_21.Parent = v_3
	end
	do
		local v_22 = Instance.new("ParticleEmitter")
		v_22.Name = "cat spec 3"
		refMap["22"] = v_22
		v_22.Texture = "rbxassetid://136781994057492"
		v_22.Rate = 2.00
		v_22.Speed = NumberRange.new(10.00, 20.00)
		v_22.Lifetime = NumberRange.new(0.40, 1.00)
		v_22.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_22.Rotation = NumberRange.new(-360.00, 360.00)
		v_22.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_22.LightEmission = 0.00
		v_22.LightInfluence = 0.00
		v_22.LockedToPart = false
		v_22.ZOffset = 2.20
		v_22.Drag = 4.00
		v_22.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_22.VelocityInheritance = 0.00
		v_22.Orientation = Enum.ParticleOrientation.FacingCamera
		v_22.EmissionDirection = Enum.NormalId.Top
		v_22.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_22.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_22.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_22.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_22.Enabled = true
		v_22.Parent = v_3
	end
	do
		local v_23 = Instance.new("ParticleEmitter")
		v_23.Name = "cat spec 3"
		refMap["23"] = v_23
		v_23.Texture = "rbxassetid://136781994057492"
		v_23.Rate = 2.00
		v_23.Speed = NumberRange.new(12.93, 25.87)
		v_23.Lifetime = NumberRange.new(0.40, 1.00)
		v_23.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_23.Rotation = NumberRange.new(-360.00, 360.00)
		v_23.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_23.LightEmission = 0.00
		v_23.LightInfluence = 0.00
		v_23.LockedToPart = false
		v_23.ZOffset = 2.04
		v_23.Drag = 4.00
		v_23.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_23.VelocityInheritance = 0.00
		v_23.Orientation = Enum.ParticleOrientation.FacingCamera
		v_23.EmissionDirection = Enum.NormalId.Top
		v_23.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_23.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_23.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.996, 0.000), NumberSequenceKeypoint.new(0.73, 0.621, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_23.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_23.Enabled = true
		v_23.Parent = v_3
	end
	do
		local v_24 = Instance.new("ParticleEmitter")
		v_24.Name = "Fire54"
		refMap["24"] = v_24
		v_24.Texture = "rbxassetid://17006155963"
		v_24.Rate = 3.00
		v_24.Speed = NumberRange.new(0.00, 0.00)
		v_24.Lifetime = NumberRange.new(0.70, 2.00)
		v_24.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_24.Rotation = NumberRange.new(-360.00, 360.00)
		v_24.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_24.LightEmission = 0.00
		v_24.LightInfluence = 0.00
		v_24.LockedToPart = true
		v_24.ZOffset = 1.07
		v_24.Drag = 2.00
		v_24.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_24.VelocityInheritance = 0.00
		v_24.Orientation = Enum.ParticleOrientation.FacingCamera
		v_24.EmissionDirection = Enum.NormalId.Top
		v_24.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_24.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_24.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.862, 0.000), NumberSequenceKeypoint.new(0.48, 4.143, 0.000), NumberSequenceKeypoint.new(1.00, 4.519, 0.000)})
		v_24.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_24.Enabled = true
		v_24.Parent = v_3
	end
	do
		local v_25 = Instance.new("ParticleEmitter")
		v_25.Name = "cat spec 7"
		refMap["25"] = v_25
		v_25.Texture = "rbxassetid://90414839644727"
		v_25.Rate = 2.00
		v_25.Speed = NumberRange.new(12.93, 25.87)
		v_25.Lifetime = NumberRange.new(0.40, 1.00)
		v_25.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_25.Rotation = NumberRange.new(-360.00, 360.00)
		v_25.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_25.LightEmission = 0.00
		v_25.LightInfluence = 0.00
		v_25.LockedToPart = false
		v_25.ZOffset = 2.02
		v_25.Drag = 4.00
		v_25.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_25.VelocityInheritance = 0.00
		v_25.Orientation = Enum.ParticleOrientation.FacingCamera
		v_25.EmissionDirection = Enum.NormalId.Top
		v_25.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_25.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_25.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.996, 0.000), NumberSequenceKeypoint.new(0.73, 0.621, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_25.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_25.Enabled = true
		v_25.Parent = v_3
	end
	do
		local v_26 = Instance.new("ParticleEmitter")
		v_26.Name = "cat spec 8"
		refMap["26"] = v_26
		v_26.Texture = "rbxassetid://101658731548844"
		v_26.Rate = 2.00
		v_26.Speed = NumberRange.new(12.93, 25.87)
		v_26.Lifetime = NumberRange.new(0.40, 1.00)
		v_26.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_26.Rotation = NumberRange.new(-360.00, 360.00)
		v_26.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_26.LightEmission = 0.00
		v_26.LightInfluence = 0.00
		v_26.LockedToPart = false
		v_26.ZOffset = 2.05
		v_26.Drag = 4.00
		v_26.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_26.VelocityInheritance = 0.00
		v_26.Orientation = Enum.ParticleOrientation.FacingCamera
		v_26.EmissionDirection = Enum.NormalId.Top
		v_26.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_26.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_26.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.996, 0.000), NumberSequenceKeypoint.new(0.73, 0.621, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_26.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_26.Enabled = true
		v_26.Parent = v_3
	end
	do
		local v_27 = Instance.new("ParticleEmitter")
		v_27.Name = "grainy shockwave 2"
		refMap["27"] = v_27
		v_27.Texture = "rbxassetid://16509144751"
		v_27.Rate = 2.00
		v_27.Speed = NumberRange.new(0.00, 0.00)
		v_27.Lifetime = NumberRange.new(0.40, 1.00)
		v_27.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_27.Rotation = NumberRange.new(-360.00, 360.00)
		v_27.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_27.LightEmission = 0.00
		v_27.LightInfluence = 0.00
		v_27.LockedToPart = true
		v_27.ZOffset = 2.04
		v_27.Drag = 2.00
		v_27.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_27.VelocityInheritance = 0.00
		v_27.Orientation = Enum.ParticleOrientation.FacingCamera
		v_27.EmissionDirection = Enum.NormalId.Top
		v_27.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_27.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 3.751, 0.000), NumberSequenceKeypoint.new(0.48, 5.429, 0.000), NumberSequenceKeypoint.new(1.00, 5.923, 0.000)})
		v_27.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.63, 0.343, 0.000), NumberSequenceKeypoint.new(0.89, 0.643, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_27.Enabled = true
		v_27.Parent = v_3
	end
	do
		local v_28 = Instance.new("ParticleEmitter")
		v_28.Name = "Triangle Top"
		refMap["28"] = v_28
		v_28.Texture = "rbxassetid://15009885079"
		v_28.Rate = 4.00
		v_28.Speed = NumberRange.new(0.00, 0.00)
		v_28.Lifetime = NumberRange.new(0.40, 1.00)
		v_28.RotSpeed = NumberRange.new(0.00, 0.00)
		v_28.Rotation = NumberRange.new(0.00, 0.00)
		v_28.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_28.LightEmission = 0.00
		v_28.LightInfluence = 0.00
		v_28.LockedToPart = true
		v_28.ZOffset = 1.00
		v_28.Drag = 2.00
		v_28.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_28.VelocityInheritance = 0.00
		v_28.Orientation = Enum.ParticleOrientation.FacingCamera
		v_28.EmissionDirection = Enum.NormalId.Top
		v_28.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8
		v_28.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0980, 1.0000, 0.4980)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0980, 1.0000, 0.4980))})
		v_28.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.15, 3.423, 0.978), NumberSequenceKeypoint.new(0.42, 5.042, 1.065), NumberSequenceKeypoint.new(1.00, 5.528, 1.243)})
		v_28.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.263, 0.000), NumberSequenceKeypoint.new(0.85, 0.557, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_28.Enabled = true
		v_28.Parent = v_3
	end
	do
		local v_29 = Instance.new("ParticleEmitter")
		v_29.Name = "Cursed Energy Disperse 8x8"
		refMap["29"] = v_29
		v_29.Texture = "rbxassetid://97051019398375"
		v_29.Rate = 2.00
		v_29.Speed = NumberRange.new(0.00, 0.00)
		v_29.Lifetime = NumberRange.new(0.40, 1.00)
		v_29.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_29.Rotation = NumberRange.new(-360.00, 360.00)
		v_29.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_29.LightEmission = 0.00
		v_29.LightInfluence = 0.00
		v_29.LockedToPart = true
		v_29.ZOffset = 1.05
		v_29.Drag = 2.00
		v_29.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_29.VelocityInheritance = 0.00
		v_29.Orientation = Enum.ParticleOrientation.FacingCamera
		v_29.EmissionDirection = Enum.NormalId.Top
		v_29.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8
		v_29.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_29.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.862, 0.000), NumberSequenceKeypoint.new(0.48, 4.143, 0.000), NumberSequenceKeypoint.new(1.00, 4.519, 0.000)})
		v_29.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_29.Enabled = true
		v_29.Parent = v_3
	end
	do
		local v_30 = Instance.new("ParticleEmitter")
		v_30.Name = "Cat 3"
		refMap["30"] = v_30
		v_30.Texture = "rbxassetid://77336442156503"
		v_30.Rate = 2.00
		v_30.Speed = NumberRange.new(0.00, 0.00)
		v_30.Lifetime = NumberRange.new(0.40, 1.00)
		v_30.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_30.Rotation = NumberRange.new(-360.00, 360.00)
		v_30.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_30.LightEmission = 0.00
		v_30.LightInfluence = 0.00
		v_30.LockedToPart = true
		v_30.ZOffset = 2.01
		v_30.Drag = 2.00
		v_30.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_30.VelocityInheritance = 0.00
		v_30.Orientation = Enum.ParticleOrientation.FacingCamera
		v_30.EmissionDirection = Enum.NormalId.Top
		v_30.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_30.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_30.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.533, 0.000), NumberSequenceKeypoint.new(0.48, 3.667, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_30.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.263, 0.000), NumberSequenceKeypoint.new(0.85, 0.557, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_30.Enabled = true
		v_30.Parent = v_3
	end
	do
		local v_31 = Instance.new("ParticleEmitter")
		v_31.Name = "Strange VFX"
		refMap["31"] = v_31
		v_31.Texture = "rbxassetid://18369800560"
		v_31.Rate = 3.00
		v_31.Speed = NumberRange.new(0.00, 0.00)
		v_31.Lifetime = NumberRange.new(0.40, 1.00)
		v_31.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_31.Rotation = NumberRange.new(-360.00, 360.00)
		v_31.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_31.LightEmission = 0.00
		v_31.LightInfluence = 0.00
		v_31.LockedToPart = true
		v_31.ZOffset = 1.01
		v_31.Drag = 2.00
		v_31.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_31.VelocityInheritance = 0.00
		v_31.Orientation = Enum.ParticleOrientation.FacingCamera
		v_31.EmissionDirection = Enum.NormalId.Top
		v_31.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_31.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_31.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.533, 0.000), NumberSequenceKeypoint.new(0.48, 3.667, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_31.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_31.Enabled = true
		v_31.Parent = v_3
	end
	do
		local v_32 = Instance.new("ParticleEmitter")
		v_32.Name = "cursed energy spec"
		refMap["32"] = v_32
		v_32.Texture = "rbxassetid://85688545954016"
		v_32.Rate = 2.00
		v_32.Speed = NumberRange.new(10.00, 20.00)
		v_32.Lifetime = NumberRange.new(0.40, 1.00)
		v_32.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_32.Rotation = NumberRange.new(-360.00, 360.00)
		v_32.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_32.LightEmission = 0.00
		v_32.LightInfluence = 0.00
		v_32.LockedToPart = false
		v_32.ZOffset = 2.11
		v_32.Drag = 4.00
		v_32.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_32.VelocityInheritance = 0.00
		v_32.Orientation = Enum.ParticleOrientation.FacingCamera
		v_32.EmissionDirection = Enum.NormalId.Top
		v_32.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_32.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_32.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_32.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_32.Enabled = true
		v_32.Parent = v_3
	end
	do
		local v_33 = Instance.new("ParticleEmitter")
		v_33.Name = "Bright Horizontal Star Glare 2"
		refMap["33"] = v_33
		v_33.Texture = "rbxassetid://131904221700198"
		v_33.Rate = 4.00
		v_33.Speed = NumberRange.new(0.00, 0.00)
		v_33.Lifetime = NumberRange.new(0.40, 1.00)
		v_33.RotSpeed = NumberRange.new(0.00, 0.00)
		v_33.Rotation = NumberRange.new(0.00, 0.00)
		v_33.SpreadAngle = Vector2.new(0.0, 0.0)
		v_33.LightEmission = 0.00
		v_33.LightInfluence = 0.00
		v_33.LockedToPart = true
		v_33.ZOffset = 1.00
		v_33.Drag = 2.00
		v_33.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_33.VelocityInheritance = 0.00
		v_33.Orientation = Enum.ParticleOrientation.FacingCamera
		v_33.EmissionDirection = Enum.NormalId.Top
		v_33.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_33.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0980, 1.0000, 0.4980)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0980, 1.0000, 0.4980))})
		v_33.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.15, 3.267, 0.000), NumberSequenceKeypoint.new(0.39, 4.317, 0.000), NumberSequenceKeypoint.new(1.00, 5.000, 0.000)})
		v_33.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.263, 0.000), NumberSequenceKeypoint.new(0.85, 0.557, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_33.Enabled = true
		v_33.Parent = v_3
	end
	do
		local v_34 = Instance.new("ParticleEmitter")
		v_34.Name = "cat spec 7"
		refMap["34"] = v_34
		v_34.Texture = "rbxassetid://90414839644727"
		v_34.Rate = 2.00
		v_34.Speed = NumberRange.new(10.00, 20.00)
		v_34.Lifetime = NumberRange.new(0.40, 1.00)
		v_34.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_34.Rotation = NumberRange.new(-360.00, 360.00)
		v_34.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_34.LightEmission = 0.00
		v_34.LightInfluence = 0.00
		v_34.LockedToPart = false
		v_34.ZOffset = 2.04
		v_34.Drag = 4.00
		v_34.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_34.VelocityInheritance = 0.00
		v_34.Orientation = Enum.ParticleOrientation.FacingCamera
		v_34.EmissionDirection = Enum.NormalId.Top
		v_34.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_34.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_34.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_34.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_34.Enabled = true
		v_34.Parent = v_3
	end
	do
		local v_35 = Instance.new("ParticleEmitter")
		v_35.Name = "Strange VFX"
		refMap["35"] = v_35
		v_35.Texture = "rbxassetid://18369800560"
		v_35.Rate = 1.00
		v_35.Speed = NumberRange.new(0.00, 0.00)
		v_35.Lifetime = NumberRange.new(1.00, 2.00)
		v_35.RotSpeed = NumberRange.new(0.00, 0.00)
		v_35.Rotation = NumberRange.new(90.00, 90.00)
		v_35.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_35.LightEmission = 0.00
		v_35.LightInfluence = 0.00
		v_35.LockedToPart = true
		v_35.ZOffset = 1.03
		v_35.Drag = 2.00
		v_35.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_35.VelocityInheritance = 0.00
		v_35.Orientation = Enum.ParticleOrientation.FacingCamera
		v_35.EmissionDirection = Enum.NormalId.Top
		v_35.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_35.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_35.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 5.067, 0.000), NumberSequenceKeypoint.new(0.48, 7.333, 0.000), NumberSequenceKeypoint.new(1.00, 8.000, 0.000)})
		v_35.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.600, 0.000), NumberSequenceKeypoint.new(1.00, 0.600, 0.000)})
		v_35.Enabled = true
		v_35.Parent = v_3
	end
	do
		local v_36 = Instance.new("ParticleEmitter")
		v_36.Name = "Slightly glowing"
		refMap["36"] = v_36
		v_36.Texture = "rbxassetid://14152113700"
		v_36.Rate = 2.00
		v_36.Speed = NumberRange.new(0.00, 0.00)
		v_36.Lifetime = NumberRange.new(0.40, 1.00)
		v_36.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_36.Rotation = NumberRange.new(-360.00, 360.00)
		v_36.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_36.LightEmission = 0.00
		v_36.LightInfluence = 0.00
		v_36.LockedToPart = true
		v_36.ZOffset = 2.09
		v_36.Drag = 2.00
		v_36.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_36.VelocityInheritance = 0.00
		v_36.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_36.EmissionDirection = Enum.NormalId.Top
		v_36.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_36.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_36.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.533, 0.000), NumberSequenceKeypoint.new(0.48, 3.667, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_36.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_36.Enabled = true
		v_36.Parent = v_3
	end
	do
		local v_37 = Instance.new("ParticleEmitter")
		v_37.Name = "Cursed Energy Disperse 8x8"
		refMap["37"] = v_37
		v_37.Texture = "rbxassetid://97051019398375"
		v_37.Rate = 2.00
		v_37.Speed = NumberRange.new(14.00, 20.00)
		v_37.Lifetime = NumberRange.new(0.40, 1.00)
		v_37.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_37.Rotation = NumberRange.new(-360.00, 360.00)
		v_37.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_37.LightEmission = 0.00
		v_37.LightInfluence = 0.00
		v_37.LockedToPart = true
		v_37.ZOffset = 1.02
		v_37.Drag = 7.00
		v_37.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_37.VelocityInheritance = 0.00
		v_37.Orientation = Enum.ParticleOrientation.FacingCamera
		v_37.EmissionDirection = Enum.NormalId.Top
		v_37.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8
		v_37.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_37.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.862, 0.000), NumberSequenceKeypoint.new(0.48, 4.143, 0.000), NumberSequenceKeypoint.new(1.00, 4.519, 0.000)})
		v_37.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.317, 0.000), NumberSequenceKeypoint.new(0.86, 0.683, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_37.Enabled = true
		v_37.Parent = v_3
	end
	do
		local v_38 = Instance.new("ParticleEmitter")
		v_38.Name = "cursed energy3421"
		refMap["38"] = v_38
		v_38.Texture = "rbxassetid://17006172452"
		v_38.Rate = 2.00
		v_38.Speed = NumberRange.new(0.00, 0.00)
		v_38.Lifetime = NumberRange.new(0.40, 1.00)
		v_38.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_38.Rotation = NumberRange.new(-360.00, 360.00)
		v_38.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_38.LightEmission = 0.00
		v_38.LightInfluence = 0.00
		v_38.LockedToPart = true
		v_38.ZOffset = 2.10
		v_38.Drag = 2.00
		v_38.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_38.VelocityInheritance = 0.00
		v_38.Orientation = Enum.ParticleOrientation.FacingCamera
		v_38.EmissionDirection = Enum.NormalId.Top
		v_38.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_38.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_38.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.533, 0.000), NumberSequenceKeypoint.new(0.48, 3.667, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_38.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.317, 0.000), NumberSequenceKeypoint.new(0.86, 0.683, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_38.Enabled = true
		v_38.Parent = v_3
	end
	do
		local v_39 = Instance.new("ParticleEmitter")
		v_39.Name = "Triangle Gradient Lens"
		refMap["39"] = v_39
		v_39.Texture = "rbxassetid://108684954560019"
		v_39.Rate = 4.00
		v_39.Speed = NumberRange.new(0.00, 0.00)
		v_39.Lifetime = NumberRange.new(0.40, 1.00)
		v_39.RotSpeed = NumberRange.new(30.00, 50.00)
		v_39.Rotation = NumberRange.new(180.00, 180.00)
		v_39.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_39.LightEmission = 0.00
		v_39.LightInfluence = 0.00
		v_39.LockedToPart = true
		v_39.ZOffset = 1.00
		v_39.Drag = 2.00
		v_39.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_39.VelocityInheritance = 0.00
		v_39.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_39.EmissionDirection = Enum.NormalId.Top
		v_39.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_39.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0980, 1.0000, 0.4980)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0980, 1.0000, 0.4980))})
		v_39.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.15, 2.504, 0.715), NumberSequenceKeypoint.new(0.42, 3.688, 0.779), NumberSequenceKeypoint.new(1.00, 4.043, 0.909)})
		v_39.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.263, 0.000), NumberSequenceKeypoint.new(0.85, 0.557, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_39.Enabled = true
		v_39.Parent = v_3
	end
	do
		local v_40 = Instance.new("ParticleEmitter")
		v_40.Name = "cursed energy1"
		refMap["40"] = v_40
		v_40.Texture = "rbxassetid://112387970399345"
		v_40.Rate = 2.00
		v_40.Speed = NumberRange.new(0.00, 0.00)
		v_40.Lifetime = NumberRange.new(0.40, 1.00)
		v_40.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_40.Rotation = NumberRange.new(-360.00, 360.00)
		v_40.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_40.LightEmission = 0.00
		v_40.LightInfluence = 0.00
		v_40.LockedToPart = true
		v_40.ZOffset = 1.03
		v_40.Drag = 2.00
		v_40.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_40.VelocityInheritance = 0.00
		v_40.Orientation = Enum.ParticleOrientation.FacingCamera
		v_40.EmissionDirection = Enum.NormalId.Top
		v_40.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_40.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.862, 0.000), NumberSequenceKeypoint.new(0.48, 4.143, 0.000), NumberSequenceKeypoint.new(1.00, 4.519, 0.000)})
		v_40.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_40.Enabled = true
		v_40.Parent = v_3
	end
	end
	do
		local v_41 = Instance.new("Attachment")
		v_41.Name = "Attachment"
		refMap["41"] = v_41
		v_41.CFrame = CFrame.new(0.000, -3.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_41.Parent = v_2
	do
		local v_42 = Instance.new("ParticleEmitter")
		v_42.Name = "cursed energy 2"
		refMap["42"] = v_42
		v_42.Texture = "rbxassetid://78422400450982"
		v_42.Rate = 2.00
		v_42.Speed = NumberRange.new(0.00, 0.00)
		v_42.Lifetime = NumberRange.new(1.00, 2.00)
		v_42.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_42.Rotation = NumberRange.new(-360.00, 360.00)
		v_42.SpreadAngle = Vector2.new(0.0, 0.0)
		v_42.LightEmission = 0.00
		v_42.LightInfluence = 0.00
		v_42.LockedToPart = true
		v_42.ZOffset = 1.03
		v_42.Drag = 0.00
		v_42.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_42.VelocityInheritance = 0.00
		v_42.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_42.EmissionDirection = Enum.NormalId.Top
		v_42.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0000, 0.6598, 0.2906)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0000, 0.6598, 0.2906))})
		v_42.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.17, 3.840, 0.000), NumberSequenceKeypoint.new(1.00, 6.227, 0.000)})
		v_42.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.247, 0.000), NumberSequenceKeypoint.new(0.90, 0.577, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_42.Enabled = true
		v_42.Parent = v_41
	end
	do
		local v_43 = Instance.new("ParticleEmitter")
		v_43.Name = "Smokey Crescent"
		refMap["43"] = v_43
		v_43.Texture = "rbxassetid://17085222506"
		v_43.Rate = 2.00
		v_43.Speed = NumberRange.new(0.00, 0.00)
		v_43.Lifetime = NumberRange.new(1.00, 2.00)
		v_43.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_43.Rotation = NumberRange.new(-360.00, 360.00)
		v_43.SpreadAngle = Vector2.new(-30.0, 20.0)
		v_43.LightEmission = 0.00
		v_43.LightInfluence = 0.00
		v_43.LockedToPart = true
		v_43.ZOffset = 1.03
		v_43.Drag = 0.00
		v_43.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_43.VelocityInheritance = 0.00
		v_43.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_43.EmissionDirection = Enum.NormalId.Top
		v_43.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_43.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(0.24, Color3.new(0.0000, 0.2692, 0.1202)), ColorSequenceKeypoint.new(0.45, Color3.new(0.0000, 0.0000, 0.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0000, 0.0000, 0.0000))})
		v_43.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.17, 3.700, 0.000), NumberSequenceKeypoint.new(1.00, 6.000, 0.000)})
		v_43.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_43.Enabled = true
		v_43.Parent = v_41
	end
	do
		local v_44 = Instance.new("ParticleEmitter")
		v_44.Name = "windfs"
		refMap["44"] = v_44
		v_44.Texture = "rbxassetid://135128020878697"
		v_44.Rate = 2.00
		v_44.Speed = NumberRange.new(0.00, 0.00)
		v_44.Lifetime = NumberRange.new(1.00, 2.00)
		v_44.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_44.Rotation = NumberRange.new(-360.00, 360.00)
		v_44.SpreadAngle = Vector2.new(-30.0, 20.0)
		v_44.LightEmission = 0.00
		v_44.LightInfluence = 0.00
		v_44.LockedToPart = true
		v_44.ZOffset = 1.04
		v_44.Drag = 0.00
		v_44.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_44.VelocityInheritance = 0.00
		v_44.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_44.EmissionDirection = Enum.NormalId.Top
		v_44.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(0.24, Color3.new(0.0000, 0.2692, 0.1202)), ColorSequenceKeypoint.new(0.45, Color3.new(0.0000, 0.0000, 0.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0000, 0.0000, 0.0000))})
		v_44.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.17, 3.700, 0.000), NumberSequenceKeypoint.new(1.00, 6.000, 0.000)})
		v_44.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_44.Enabled = true
		v_44.Parent = v_41
	end
	do
		local v_45 = Instance.new("ParticleEmitter")
		v_45.Name = "another shockwave"
		refMap["45"] = v_45
		v_45.Texture = "rbxassetid://13582043821"
		v_45.Rate = 2.00
		v_45.Speed = NumberRange.new(0.00, 0.00)
		v_45.Lifetime = NumberRange.new(1.00, 2.00)
		v_45.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_45.Rotation = NumberRange.new(-360.00, 360.00)
		v_45.SpreadAngle = Vector2.new(0.0, 0.0)
		v_45.LightEmission = 0.00
		v_45.LightInfluence = 0.00
		v_45.LockedToPart = true
		v_45.ZOffset = 2.01
		v_45.Drag = 0.00
		v_45.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_45.VelocityInheritance = 0.00
		v_45.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_45.EmissionDirection = Enum.NormalId.Top
		v_45.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0980, 1.0000, 0.4980)), ColorSequenceKeypoint.new(0.24, Color3.new(0.0000, 0.2692, 0.1202)), ColorSequenceKeypoint.new(0.45, Color3.new(0.0000, 0.0000, 0.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0000, 0.0000, 0.0000))})
		v_45.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.17, 5.639, 0.000), NumberSequenceKeypoint.new(0.49, 8.504, 0.000), NumberSequenceKeypoint.new(1.00, 9.144, 0.000)})
		v_45.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.427, 0.000), NumberSequenceKeypoint.new(0.54, 0.627, 0.000), NumberSequenceKeypoint.new(0.76, 0.737, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_45.Enabled = true
		v_45.Parent = v_41
	end
	do
		local v_46 = Instance.new("ParticleEmitter")
		v_46.Name = "Thin realistic shockwave"
		refMap["46"] = v_46
		v_46.Texture = "rbxassetid://12906276200"
		v_46.Rate = 2.00
		v_46.Speed = NumberRange.new(0.00, 0.00)
		v_46.Lifetime = NumberRange.new(1.00, 2.00)
		v_46.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_46.Rotation = NumberRange.new(-360.00, 360.00)
		v_46.SpreadAngle = Vector2.new(-30.0, 20.0)
		v_46.LightEmission = 0.00
		v_46.LightInfluence = 0.00
		v_46.LockedToPart = true
		v_46.ZOffset = 1.07
		v_46.Drag = 0.00
		v_46.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_46.VelocityInheritance = 0.00
		v_46.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_46.EmissionDirection = Enum.NormalId.Top
		v_46.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_46.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0000, 0.6598, 0.2906)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0000, 0.6598, 0.2906))})
		v_46.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.17, 5.586, 0.000), NumberSequenceKeypoint.new(1.00, 9.058, 0.000)})
		v_46.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.247, 0.000), NumberSequenceKeypoint.new(0.90, 0.577, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_46.Enabled = true
		v_46.Parent = v_41
	end
	do
		local v_47 = Instance.new("ParticleEmitter")
		v_47.Name = "weird shockwave"
		refMap["47"] = v_47
		v_47.Texture = "rbxassetid://16940431172"
		v_47.Rate = 2.00
		v_47.Speed = NumberRange.new(0.00, 0.00)
		v_47.Lifetime = NumberRange.new(1.00, 2.00)
		v_47.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_47.Rotation = NumberRange.new(-360.00, 360.00)
		v_47.SpreadAngle = Vector2.new(0.0, 0.0)
		v_47.LightEmission = 0.00
		v_47.LightInfluence = 0.00
		v_47.LockedToPart = true
		v_47.ZOffset = 1.04
		v_47.Drag = 0.00
		v_47.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_47.VelocityInheritance = 0.00
		v_47.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_47.EmissionDirection = Enum.NormalId.Top
		v_47.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(0.24, Color3.new(0.0000, 0.2692, 0.1202)), ColorSequenceKeypoint.new(0.45, Color3.new(0.0000, 0.0000, 0.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0000, 0.0000, 0.0000))})
		v_47.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.17, 4.256, 0.000), NumberSequenceKeypoint.new(0.49, 6.419, 0.000), NumberSequenceKeypoint.new(1.00, 6.902, 0.000)})
		v_47.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.180, 0.000), NumberSequenceKeypoint.new(0.59, 0.370, 0.000), NumberSequenceKeypoint.new(0.82, 0.617, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_47.Enabled = true
		v_47.Parent = v_41
	end
	do
		local v_48 = Instance.new("ParticleEmitter")
		v_48.Name = "grainy shockwave 2"
		refMap["48"] = v_48
		v_48.Texture = "rbxassetid://16509144751"
		v_48.Rate = 2.00
		v_48.Speed = NumberRange.new(0.00, 0.00)
		v_48.Lifetime = NumberRange.new(1.00, 2.00)
		v_48.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_48.Rotation = NumberRange.new(-360.00, 360.00)
		v_48.SpreadAngle = Vector2.new(0.0, 0.0)
		v_48.LightEmission = 0.00
		v_48.LightInfluence = 0.00
		v_48.LockedToPart = true
		v_48.ZOffset = 1.02
		v_48.Drag = 0.00
		v_48.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_48.VelocityInheritance = 0.00
		v_48.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_48.EmissionDirection = Enum.NormalId.Top
		v_48.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(0.24, Color3.new(0.0000, 0.2692, 0.1202)), ColorSequenceKeypoint.new(0.45, Color3.new(0.0000, 0.0000, 0.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0000, 0.0000, 0.0000))})
		v_48.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.17, 5.639, 0.000), NumberSequenceKeypoint.new(0.49, 8.504, 0.000), NumberSequenceKeypoint.new(1.00, 9.144, 0.000)})
		v_48.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.427, 0.000), NumberSequenceKeypoint.new(0.54, 0.627, 0.000), NumberSequenceKeypoint.new(0.76, 0.737, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_48.Enabled = true
		v_48.Parent = v_41
	end
	do
		local v_49 = Instance.new("ParticleEmitter")
		v_49.Name = "cursed energy 2"
		refMap["49"] = v_49
		v_49.Texture = "rbxassetid://78422400450982"
		v_49.Rate = 2.00
		v_49.Speed = NumberRange.new(0.00, 0.00)
		v_49.Lifetime = NumberRange.new(1.00, 2.00)
		v_49.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_49.Rotation = NumberRange.new(-360.00, 360.00)
		v_49.SpreadAngle = Vector2.new(0.0, 0.0)
		v_49.LightEmission = 0.00
		v_49.LightInfluence = 0.00
		v_49.LockedToPart = true
		v_49.ZOffset = 1.01
		v_49.Drag = 0.00
		v_49.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_49.VelocityInheritance = 0.00
		v_49.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_49.EmissionDirection = Enum.NormalId.Top
		v_49.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0000, 0.6598, 0.2906)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0000, 0.6598, 0.2906))})
		v_49.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.17, 4.745, 0.000), NumberSequenceKeypoint.new(1.00, 7.694, 0.000)})
		v_49.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.247, 0.000), NumberSequenceKeypoint.new(0.90, 0.577, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_49.Enabled = true
		v_49.Parent = v_41
	end
	end
	do
		local v_50 = Instance.new("Attachment")
		v_50.Name = "Attachment"
		refMap["50"] = v_50
		v_50.CFrame = CFrame.new(0.000, -3.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_50.Parent = v_2
	do
		local v_51 = Instance.new("ParticleEmitter")
		v_51.Name = "Slightly glowing"
		refMap["51"] = v_51
		v_51.Texture = "rbxassetid://14152113700"
		v_51.Rate = 2.00
		v_51.Speed = NumberRange.new(0.00, 0.00)
		v_51.Lifetime = NumberRange.new(1.00, 2.00)
		v_51.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_51.Rotation = NumberRange.new(-360.00, 360.00)
		v_51.SpreadAngle = Vector2.new(0.0, 0.0)
		v_51.LightEmission = 0.00
		v_51.LightInfluence = 0.00
		v_51.LockedToPart = true
		v_51.ZOffset = 2.00
		v_51.Drag = 0.00
		v_51.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_51.VelocityInheritance = 0.00
		v_51.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_51.EmissionDirection = Enum.NormalId.Top
		v_51.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_51.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0980, 1.0000, 0.4980)), ColorSequenceKeypoint.new(0.24, Color3.new(0.0000, 0.2692, 0.1202)), ColorSequenceKeypoint.new(0.45, Color3.new(0.0000, 0.0000, 0.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0000, 0.0000, 0.0000))})
		v_51.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.17, 4.037, 0.000), NumberSequenceKeypoint.new(0.49, 6.557, 0.000), NumberSequenceKeypoint.new(1.00, 7.000, 0.000)})
		v_51.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_51.Enabled = true
		v_51.Parent = v_50
	end
	do
		local v_52 = Instance.new("ParticleEmitter")
		v_52.Name = "dis dark circle 2"
		refMap["52"] = v_52
		v_52.Texture = "rbxassetid://87272078452382"
		v_52.Rate = 2.00
		v_52.Speed = NumberRange.new(0.00, 0.00)
		v_52.Lifetime = NumberRange.new(1.00, 2.00)
		v_52.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_52.Rotation = NumberRange.new(-360.00, 360.00)
		v_52.SpreadAngle = Vector2.new(0.0, 0.0)
		v_52.LightEmission = 0.00
		v_52.LightInfluence = 0.00
		v_52.LockedToPart = true
		v_52.ZOffset = 1.03
		v_52.Drag = 0.00
		v_52.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_52.VelocityInheritance = 0.00
		v_52.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_52.EmissionDirection = Enum.NormalId.Top
		v_52.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0980, 1.0000, 0.4980)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0980, 1.0000, 0.4980))})
		v_52.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.17, 4.037, 0.000), NumberSequenceKeypoint.new(0.49, 6.557, 0.000), NumberSequenceKeypoint.new(1.00, 7.000, 0.000)})
		v_52.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.62, 0.213, 0.000), NumberSequenceKeypoint.new(0.84, 0.467, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_52.Enabled = true
		v_52.Parent = v_50
	end
	end
	do
		local v_53 = Instance.new("Part")
		v_53.Name = "inwardbezier"
		refMap["53"] = v_53
		v_53.Anchored = false
		v_53.CanCollide = false
		v_53.CanTouch = false
		v_53.CanQuery = false
		v_53.Massless = true
		v_53.CastShadow = false
		v_53.Transparency = 1.00
		v_53.Size = Vector3.new(10.000, 10.000, 10.000)
		v_53.CFrame = CFrame.new(-140.543, 22.026, -29.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_53.Color = Color3.fromRGB(248, 248, 248)
		v_53.Parent = v_2
	do
		local v_54 = Instance.new("Attachment")
		v_54.Name = "Bezier"
		refMap["54"] = v_54
		v_54.CFrame = CFrame.new(0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_54.Parent = v_53
	do
		local v_55 = Instance.new("Attachment")
		v_55.Name = "End"
		refMap["55"] = v_55
		v_55.CFrame = CFrame.new(0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_55.Parent = v_54
	end
	do
		local v_56 = Instance.new("Attachment")
		v_56.Name = "Points"
		refMap["56"] = v_56
		v_56.CFrame = CFrame.new(0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_56.Parent = v_54
	do
		local v_57 = Instance.new("Attachment")
		v_57.Name = "2"
		refMap["57"] = v_57
		v_57.CFrame = CFrame.new(0.898, -0.143, -15.205, -0.000, 0.000, -1.000, 0.000, 1.000, 0.000, 1.000, 0.000, -0.000)
		v_57.Parent = v_56
	do
		local v_58 = Instance.new("Attachment")
		v_58.Name = "T1"
		refMap["58"] = v_58
		v_58.CFrame = CFrame.new(2.300, 6.629, 1.667, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_58.Parent = v_57
	end
	end
	do
		local v_59 = Instance.new("Attachment")
		v_59.Name = "1"
		refMap["59"] = v_59
		v_59.CFrame = CFrame.new(0.000, 0.000, 3.716, 0.000, 0.000, -1.000, 0.000, 1.000, 0.000, 1.000, 0.000, 0.000)
		v_59.Parent = v_56
	do
		local v_60 = Instance.new("Attachment")
		v_60.Name = "T0"
		refMap["60"] = v_60
		v_60.CFrame = CFrame.new(-2.589, -7.266, -0.197, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_60.Parent = v_59
	end
	end
	end
	do
		local v_61 = Instance.new("Part")
		v_61.Name = "Part"
		refMap["61"] = v_61
		v_61.Anchored = false
		v_61.CanCollide = false
		v_61.CanTouch = false
		v_61.CanQuery = false
		v_61.Massless = true
		v_61.CastShadow = false
		v_61.Transparency = 1.00
		v_61.Size = Vector3.new(0.400, 0.400, 0.400)
		v_61.CFrame = CFrame.new(-140.543, 22.026, -29.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_61.Color = Color3.fromRGB(248, 248, 248)
		v_61.Parent = v_54
	do
		local v_62 = Instance.new("Trail")
		v_62.Name = "cursed energy trail 2"
		refMap["62"] = v_62
		v_62.Texture = "rbxassetid://119952780050980"
		v_62.Lifetime = 0.30
		v_62.MinLength = 0.00
		v_62.LightEmission = 0.00
		v_62.LightInfluence = 0.00
		v_62.FaceCamera = true
		v_62.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0980, 1.0000, 0.4980)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0980, 1.0000, 0.4980))})
		v_62.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.17, 0.287, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_62.Enabled = true
		table.insert(pendingRefs, { obj = v_62, prop = "Attachment0", ref = "63" })
		table.insert(pendingRefs, { obj = v_62, prop = "Attachment1", ref = "64" })
		v_62.Parent = v_61
	end
	do
		local v_63 = Instance.new("Attachment")
		v_63.Name = "1"
		refMap["64"] = v_63
		v_63.CFrame = CFrame.new(-0.031, 0.000, -0.301, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_63.Parent = v_61
	end
	do
		local v_64 = Instance.new("Attachment")
		v_64.Name = "0"
		refMap["63"] = v_64
		v_64.CFrame = CFrame.new(-0.022, 0.000, 0.316, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_64.Parent = v_61
	end
	end
	end
	do
		local v_65 = Instance.new("Attachment")
		v_65.Name = "Bezier"
		refMap["65"] = v_65
		v_65.CFrame = CFrame.new(0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_65.Parent = v_53
	do
		local v_66 = Instance.new("Attachment")
		v_66.Name = "Points"
		refMap["66"] = v_66
		v_66.CFrame = CFrame.new(0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_66.Parent = v_65
	do
		local v_67 = Instance.new("Attachment")
		v_67.Name = "2"
		refMap["67"] = v_67
		v_67.CFrame = CFrame.new(0.898, -0.143, -15.205, -0.000, 0.000, -1.000, 0.000, 1.000, 0.000, 1.000, 0.000, -0.000)
		v_67.Parent = v_66
	do
		local v_68 = Instance.new("Attachment")
		v_68.Name = "T1"
		refMap["68"] = v_68
		v_68.CFrame = CFrame.new(2.300, 6.629, 1.667, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_68.Parent = v_67
	end
	end
	do
		local v_69 = Instance.new("Attachment")
		v_69.Name = "1"
		refMap["69"] = v_69
		v_69.CFrame = CFrame.new(0.000, 0.000, 3.716, 0.000, 0.000, -1.000, 0.000, 1.000, 0.000, 1.000, 0.000, 0.000)
		v_69.Parent = v_66
	do
		local v_70 = Instance.new("Attachment")
		v_70.Name = "T0"
		refMap["70"] = v_70
		v_70.CFrame = CFrame.new(-2.589, -7.266, -0.197, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_70.Parent = v_69
	end
	end
	end
	do
		local v_71 = Instance.new("Attachment")
		v_71.Name = "End"
		refMap["71"] = v_71
		v_71.CFrame = CFrame.new(0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_71.Parent = v_65
	end
	do
		local v_72 = Instance.new("Part")
		v_72.Name = "Part"
		refMap["72"] = v_72
		v_72.Anchored = false
		v_72.CanCollide = false
		v_72.CanTouch = false
		v_72.CanQuery = false
		v_72.Massless = true
		v_72.CastShadow = false
		v_72.Transparency = 1.00
		v_72.Size = Vector3.new(0.400, 0.400, 0.400)
		v_72.CFrame = CFrame.new(-140.543, 22.026, -29.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_72.Color = Color3.fromRGB(248, 248, 248)
		v_72.Parent = v_65
	do
		local v_73 = Instance.new("Attachment")
		v_73.Name = "1"
		refMap["73"] = v_73
		v_73.CFrame = CFrame.new(-0.031, 0.000, -0.269, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_73.Parent = v_72
	end
	do
		local v_74 = Instance.new("Trail")
		v_74.Name = "Beam88"
		refMap["74"] = v_74
		v_74.Texture = "rbxassetid://133860736415104"
		v_74.Lifetime = 0.30
		v_74.MinLength = 0.00
		v_74.LightEmission = 0.00
		v_74.LightInfluence = 0.00
		v_74.FaceCamera = true
		v_74.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0980, 1.0000, 0.4980)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0980, 1.0000, 0.4980))})
		v_74.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_74.Enabled = true
		table.insert(pendingRefs, { obj = v_74, prop = "Attachment0", ref = "75" })
		table.insert(pendingRefs, { obj = v_74, prop = "Attachment1", ref = "73" })
		v_74.Parent = v_72
	end
	do
		local v_75 = Instance.new("Attachment")
		v_75.Name = "0"
		refMap["75"] = v_75
		v_75.CFrame = CFrame.new(-0.023, 0.000, 0.284, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_75.Parent = v_72
	end
	end
	end
	do
		local v_76 = Instance.new("WeldConstraint")
		v_76.Name = "inwardbezier_Weld"
		refMap["76"] = v_76
		v_76.Parent = v_53
	end
	end
	do
		local v_77 = Instance.new("Attachment")
		v_77.Name = "Attachment"
		refMap["77"] = v_77
		v_77.CFrame = CFrame.new(0.000, 1.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_77.Parent = v_2
	do
		local v_78 = Instance.new("ParticleEmitter")
		v_78.Name = "cursed energy 3"
		refMap["78"] = v_78
		v_78.Texture = "rbxassetid://17006174840"
		v_78.Rate = 1.00
		v_78.Speed = NumberRange.new(0.00, 0.00)
		v_78.Lifetime = NumberRange.new(2.00, 2.00)
		v_78.RotSpeed = NumberRange.new(0.00, 0.00)
		v_78.Rotation = NumberRange.new(0.00, 0.00)
		v_78.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_78.LightEmission = 0.00
		v_78.LightInfluence = 0.00
		v_78.LockedToPart = true
		v_78.ZOffset = 0.01
		v_78.Drag = 2.00
		v_78.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_78.VelocityInheritance = 0.00
		v_78.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
		v_78.EmissionDirection = Enum.NormalId.Top
		v_78.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_78.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 5.484, 0.000), NumberSequenceKeypoint.new(0.48, 7.938, 0.000), NumberSequenceKeypoint.new(1.00, 8.659, 0.000)})
		v_78.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.360, 0.000), NumberSequenceKeypoint.new(0.63, 0.567, 0.000), NumberSequenceKeypoint.new(0.82, 0.740, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_78.Enabled = true
		v_78.Parent = v_77
	end
	do
		local v_79 = Instance.new("ParticleEmitter")
		v_79.Name = "cursed energy min"
		refMap["79"] = v_79
		v_79.Texture = "rbxassetid://125843391083656"
		v_79.Rate = 1.00
		v_79.Speed = NumberRange.new(0.00, 0.00)
		v_79.Lifetime = NumberRange.new(2.00, 2.00)
		v_79.RotSpeed = NumberRange.new(0.00, 0.00)
		v_79.Rotation = NumberRange.new(0.00, 0.00)
		v_79.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_79.LightEmission = 0.00
		v_79.LightInfluence = 0.00
		v_79.LockedToPart = true
		v_79.ZOffset = 0.02
		v_79.Drag = 2.00
		v_79.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_79.VelocityInheritance = 0.00
		v_79.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
		v_79.EmissionDirection = Enum.NormalId.Top
		v_79.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_79.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 4.439, 0.000), NumberSequenceKeypoint.new(0.48, 6.424, 0.000), NumberSequenceKeypoint.new(1.00, 7.008, 0.000)})
		v_79.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.360, 0.000), NumberSequenceKeypoint.new(0.63, 0.567, 0.000), NumberSequenceKeypoint.new(0.82, 0.740, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_79.Enabled = true
		v_79.Parent = v_77
	end
	do
		local v_80 = Instance.new("ParticleEmitter")
		v_80.Name = "Iso cursed"
		refMap["80"] = v_80
		v_80.Texture = "rbxassetid://102330699321283"
		v_80.Rate = 1.00
		v_80.Speed = NumberRange.new(0.00, 0.00)
		v_80.Lifetime = NumberRange.new(2.00, 2.00)
		v_80.RotSpeed = NumberRange.new(0.00, 0.00)
		v_80.Rotation = NumberRange.new(0.00, 0.00)
		v_80.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_80.LightEmission = 0.00
		v_80.LightInfluence = 0.00
		v_80.LockedToPart = true
		v_80.ZOffset = 0.02
		v_80.Drag = 2.00
		v_80.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_80.VelocityInheritance = 0.00
		v_80.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
		v_80.EmissionDirection = Enum.NormalId.Top
		v_80.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_80.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 5.484, 0.000), NumberSequenceKeypoint.new(0.48, 7.938, 0.000), NumberSequenceKeypoint.new(1.00, 8.659, 0.000)})
		v_80.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.360, 0.000), NumberSequenceKeypoint.new(0.63, 0.567, 0.000), NumberSequenceKeypoint.new(0.82, 0.740, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_80.Enabled = true
		v_80.Parent = v_77
	end
	end
	do
		local v_81 = Instance.new("Part")
		v_81.Name = "Part"
		refMap["81"] = v_81
		v_81.Anchored = false
		v_81.CanCollide = false
		v_81.CanTouch = false
		v_81.CanQuery = false
		v_81.Massless = true
		v_81.CastShadow = false
		v_81.Transparency = 1.00
		v_81.Size = Vector3.new(8.000, 1.000, 7.000)
		v_81.CFrame = CFrame.new(-140.500, 19.531, -29.000, 0.000, 0.000, -1.000, 0.000, 1.000, 0.000, 1.000, 0.000, 0.000)
		v_81.Color = Color3.fromRGB(163, 162, 165)
		v_81.Parent = v_2
	do
		local v_82 = Instance.new("ParticleEmitter")
		v_82.Name = "Sideways Spec 17"
		refMap["82"] = v_82
		v_82.Texture = "rbxassetid://8599882518"
		v_82.Rate = 2.00
		v_82.Speed = NumberRange.new(10.00, 20.00)
		v_82.Lifetime = NumberRange.new(0.40, 1.00)
		v_82.RotSpeed = NumberRange.new(0.00, 0.00)
		v_82.Rotation = NumberRange.new(90.00, 90.00)
		v_82.SpreadAngle = Vector2.new(-30.0, 30.0)
		v_82.LightEmission = 0.00
		v_82.LightInfluence = 0.00
		v_82.LockedToPart = false
		v_82.ZOffset = 2.05
		v_82.Drag = 4.00
		v_82.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_82.VelocityInheritance = 0.00
		v_82.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_82.EmissionDirection = Enum.NormalId.Top
		v_82.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_82.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_82.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_82.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_82.Enabled = true
		v_82.Parent = v_81
	end
	do
		local v_83 = Instance.new("ParticleEmitter")
		v_83.Name = "Coloured Diagonal Smoke"
		refMap["83"] = v_83
		v_83.Texture = "rbxassetid://13724252630"
		v_83.Rate = 1.00
		v_83.Speed = NumberRange.new(10.00, 20.00)
		v_83.Lifetime = NumberRange.new(1.00, 2.00)
		v_83.RotSpeed = NumberRange.new(0.00, 0.00)
		v_83.Rotation = NumberRange.new(15.00, 15.00)
		v_83.SpreadAngle = Vector2.new(0.0, 0.0)
		v_83.LightEmission = 0.00
		v_83.LightInfluence = 0.00
		v_83.LockedToPart = false
		v_83.ZOffset = 2.03
		v_83.Drag = 4.00
		v_83.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_83.VelocityInheritance = 0.00
		v_83.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
		v_83.EmissionDirection = Enum.NormalId.Top
		v_83.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_83.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0980, 1.0000, 0.4980)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0980, 1.0000, 0.4980))})
		v_83.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.430, 0.000), NumberSequenceKeypoint.new(0.42, 3.670, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_83.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.427, 0.000), NumberSequenceKeypoint.new(0.39, 0.553, 0.000), NumberSequenceKeypoint.new(0.75, 0.720, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_83.Enabled = true
		v_83.Parent = v_81
	end
	do
		local v_84 = Instance.new("ParticleEmitter")
		v_84.Name = "Sideways Spec 102"
		refMap["84"] = v_84
		v_84.Texture = "rbxassetid://80742887810818"
		v_84.Rate = 1.00
		v_84.Speed = NumberRange.new(10.00, 20.00)
		v_84.Lifetime = NumberRange.new(0.40, 1.00)
		v_84.RotSpeed = NumberRange.new(0.00, 0.00)
		v_84.Rotation = NumberRange.new(90.00, 90.00)
		v_84.SpreadAngle = Vector2.new(-50.0, 50.0)
		v_84.LightEmission = 0.00
		v_84.LightInfluence = 0.00
		v_84.LockedToPart = false
		v_84.ZOffset = 3.00
		v_84.Drag = 4.00
		v_84.Acceleration = Vector3.new(0.000, -20.000, 0.000)
		v_84.VelocityInheritance = 0.00
		v_84.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_84.EmissionDirection = Enum.NormalId.Top
		v_84.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_84.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_84.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_84.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_84.Enabled = true
		v_84.Parent = v_81
	end
	do
		local v_85 = Instance.new("ParticleEmitter")
		v_85.Name = "Realistic Smoke 10"
		refMap["85"] = v_85
		v_85.Texture = "rbxassetid://82219367698334"
		v_85.Rate = 1.00
		v_85.Speed = NumberRange.new(10.00, 20.00)
		v_85.Lifetime = NumberRange.new(1.00, 2.00)
		v_85.RotSpeed = NumberRange.new(0.00, 0.00)
		v_85.Rotation = NumberRange.new(0.00, 0.00)
		v_85.SpreadAngle = Vector2.new(0.0, 0.0)
		v_85.LightEmission = 0.00
		v_85.LightInfluence = 0.00
		v_85.LockedToPart = false
		v_85.ZOffset = 2.06
		v_85.Drag = 4.00
		v_85.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_85.VelocityInheritance = 0.00
		v_85.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
		v_85.EmissionDirection = Enum.NormalId.Top
		v_85.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_85.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_85.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.430, 0.000), NumberSequenceKeypoint.new(0.42, 3.670, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_85.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.427, 0.000), NumberSequenceKeypoint.new(0.39, 0.553, 0.000), NumberSequenceKeypoint.new(0.75, 0.720, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_85.Enabled = true
		v_85.Parent = v_81
	end
	do
		local v_86 = Instance.new("ParticleEmitter")
		v_86.Name = "Sideways Spec 17"
		refMap["86"] = v_86
		v_86.Texture = "rbxassetid://8599882518"
		v_86.Rate = 1.00
		v_86.Speed = NumberRange.new(10.00, 20.00)
		v_86.Lifetime = NumberRange.new(0.40, 1.00)
		v_86.RotSpeed = NumberRange.new(0.00, 0.00)
		v_86.Rotation = NumberRange.new(90.00, 90.00)
		v_86.SpreadAngle = Vector2.new(-50.0, 50.0)
		v_86.LightEmission = 0.00
		v_86.LightInfluence = 0.00
		v_86.LockedToPart = false
		v_86.ZOffset = 3.10
		v_86.Drag = 4.00
		v_86.Acceleration = Vector3.new(0.000, -20.000, 0.000)
		v_86.VelocityInheritance = 0.00
		v_86.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_86.EmissionDirection = Enum.NormalId.Top
		v_86.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_86.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_86.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_86.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_86.Enabled = true
		v_86.Parent = v_81
	end
	do
		local v_87 = Instance.new("ParticleEmitter")
		v_87.Name = "Sideways Spec 12"
		refMap["87"] = v_87
		v_87.Texture = "rbxassetid://1269254614"
		v_87.Rate = 1.00
		v_87.Speed = NumberRange.new(10.00, 20.00)
		v_87.Lifetime = NumberRange.new(0.40, 1.00)
		v_87.RotSpeed = NumberRange.new(0.00, 0.00)
		v_87.Rotation = NumberRange.new(90.00, 90.00)
		v_87.SpreadAngle = Vector2.new(-50.0, 50.0)
		v_87.LightEmission = 0.00
		v_87.LightInfluence = 0.00
		v_87.LockedToPart = false
		v_87.ZOffset = 3.03
		v_87.Drag = 4.00
		v_87.Acceleration = Vector3.new(0.000, -20.000, 0.000)
		v_87.VelocityInheritance = 0.00
		v_87.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_87.EmissionDirection = Enum.NormalId.Top
		v_87.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_87.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_87.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_87.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_87.Enabled = true
		v_87.Parent = v_81
	end
	do
		local v_88 = Instance.new("ParticleEmitter")
		v_88.Name = "Sideways Spec 15"
		refMap["88"] = v_88
		v_88.Texture = "rbxassetid://6763809313"
		v_88.Rate = 2.00
		v_88.Speed = NumberRange.new(10.00, 20.00)
		v_88.Lifetime = NumberRange.new(0.40, 1.00)
		v_88.RotSpeed = NumberRange.new(0.00, 0.00)
		v_88.Rotation = NumberRange.new(90.00, 90.00)
		v_88.SpreadAngle = Vector2.new(-30.0, 30.0)
		v_88.LightEmission = 0.00
		v_88.LightInfluence = 0.00
		v_88.LockedToPart = false
		v_88.ZOffset = 2.02
		v_88.Drag = 4.00
		v_88.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_88.VelocityInheritance = 0.00
		v_88.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_88.EmissionDirection = Enum.NormalId.Top
		v_88.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_88.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_88.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_88.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_88.Enabled = true
		v_88.Parent = v_81
	end
	do
		local v_89 = Instance.new("ParticleEmitter")
		v_89.Name = "cursed energy spec"
		refMap["89"] = v_89
		v_89.Texture = "rbxassetid://85688545954016"
		v_89.Rate = 2.00
		v_89.Speed = NumberRange.new(10.00, 20.00)
		v_89.Lifetime = NumberRange.new(0.40, 1.00)
		v_89.RotSpeed = NumberRange.new(0.00, 0.00)
		v_89.Rotation = NumberRange.new(90.00, 90.00)
		v_89.SpreadAngle = Vector2.new(-30.0, 30.0)
		v_89.LightEmission = 0.00
		v_89.LightInfluence = 0.00
		v_89.LockedToPart = false
		v_89.ZOffset = 2.04
		v_89.Drag = 4.00
		v_89.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_89.VelocityInheritance = 0.00
		v_89.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_89.EmissionDirection = Enum.NormalId.Top
		v_89.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_89.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_89.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_89.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_89.Enabled = true
		v_89.Parent = v_81
	end
	do
		local v_90 = Instance.new("ParticleEmitter")
		v_90.Name = "Sideways Spec 15"
		refMap["90"] = v_90
		v_90.Texture = "rbxassetid://6763809313"
		v_90.Rate = 1.00
		v_90.Speed = NumberRange.new(10.00, 20.00)
		v_90.Lifetime = NumberRange.new(0.40, 1.00)
		v_90.RotSpeed = NumberRange.new(0.00, 0.00)
		v_90.Rotation = NumberRange.new(90.00, 90.00)
		v_90.SpreadAngle = Vector2.new(-50.0, 50.0)
		v_90.LightEmission = 0.00
		v_90.LightInfluence = 0.00
		v_90.LockedToPart = false
		v_90.ZOffset = 3.08
		v_90.Drag = 4.00
		v_90.Acceleration = Vector3.new(0.000, -20.000, 0.000)
		v_90.VelocityInheritance = 0.00
		v_90.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_90.EmissionDirection = Enum.NormalId.Top
		v_90.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_90.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_90.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_90.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_90.Enabled = true
		v_90.Parent = v_81
	end
	do
		local v_91 = Instance.new("ParticleEmitter")
		v_91.Name = "cursed energy spec"
		refMap["91"] = v_91
		v_91.Texture = "rbxassetid://85688545954016"
		v_91.Rate = 2.00
		v_91.Speed = NumberRange.new(10.00, 20.00)
		v_91.Lifetime = NumberRange.new(0.40, 1.00)
		v_91.RotSpeed = NumberRange.new(0.00, 0.00)
		v_91.Rotation = NumberRange.new(90.00, 90.00)
		v_91.SpreadAngle = Vector2.new(-30.0, 30.0)
		v_91.LightEmission = 0.00
		v_91.LightInfluence = 0.00
		v_91.LockedToPart = false
		v_91.ZOffset = 2.04
		v_91.Drag = 4.00
		v_91.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_91.VelocityInheritance = 0.00
		v_91.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_91.EmissionDirection = Enum.NormalId.Top
		v_91.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_91.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_91.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_91.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_91.Enabled = true
		v_91.Parent = v_81
	end
	do
		local v_92 = Instance.new("ParticleEmitter")
		v_92.Name = "Sideways Spec 15"
		refMap["92"] = v_92
		v_92.Texture = "rbxassetid://6763809313"
		v_92.Rate = 1.00
		v_92.Speed = NumberRange.new(10.00, 20.00)
		v_92.Lifetime = NumberRange.new(0.40, 1.00)
		v_92.RotSpeed = NumberRange.new(0.00, 0.00)
		v_92.Rotation = NumberRange.new(90.00, 90.00)
		v_92.SpreadAngle = Vector2.new(-50.0, 50.0)
		v_92.LightEmission = 0.00
		v_92.LightInfluence = 0.00
		v_92.LockedToPart = false
		v_92.ZOffset = 3.09
		v_92.Drag = 4.00
		v_92.Acceleration = Vector3.new(0.000, -20.000, 0.000)
		v_92.VelocityInheritance = 0.00
		v_92.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_92.EmissionDirection = Enum.NormalId.Top
		v_92.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_92.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_92.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_92.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_92.Enabled = true
		v_92.Parent = v_81
	end
	do
		local v_93 = Instance.new("ParticleEmitter")
		v_93.Name = "fire realistic"
		refMap["93"] = v_93
		v_93.Texture = "rbxassetid://115973544312399"
		v_93.Rate = 1.00
		v_93.Speed = NumberRange.new(10.00, 20.00)
		v_93.Lifetime = NumberRange.new(1.00, 2.00)
		v_93.RotSpeed = NumberRange.new(0.00, 0.00)
		v_93.Rotation = NumberRange.new(0.00, 0.00)
		v_93.SpreadAngle = Vector2.new(0.0, 0.0)
		v_93.LightEmission = 0.00
		v_93.LightInfluence = 0.00
		v_93.LockedToPart = false
		v_93.ZOffset = 2.03
		v_93.Drag = 4.00
		v_93.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_93.VelocityInheritance = 0.00
		v_93.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
		v_93.EmissionDirection = Enum.NormalId.Top
		v_93.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_93.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.430, 0.000), NumberSequenceKeypoint.new(0.42, 3.670, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_93.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.427, 0.000), NumberSequenceKeypoint.new(0.39, 0.553, 0.000), NumberSequenceKeypoint.new(0.75, 0.720, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_93.Enabled = true
		v_93.Parent = v_81
	end
	do
		local v_94 = Instance.new("ParticleEmitter")
		v_94.Name = "Sideways Spec 102"
		refMap["94"] = v_94
		v_94.Texture = "rbxassetid://80742887810818"
		v_94.Rate = 1.00
		v_94.Speed = NumberRange.new(10.00, 20.00)
		v_94.Lifetime = NumberRange.new(0.40, 1.00)
		v_94.RotSpeed = NumberRange.new(0.00, 0.00)
		v_94.Rotation = NumberRange.new(90.00, 90.00)
		v_94.SpreadAngle = Vector2.new(-50.0, 50.0)
		v_94.LightEmission = 0.00
		v_94.LightInfluence = 0.00
		v_94.LockedToPart = false
		v_94.ZOffset = 3.03
		v_94.Drag = 4.00
		v_94.Acceleration = Vector3.new(0.000, -20.000, 0.000)
		v_94.VelocityInheritance = 0.00
		v_94.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_94.EmissionDirection = Enum.NormalId.Top
		v_94.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_94.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.0990, 1.0000, 0.4984)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0990, 1.0000, 0.4984))})
		v_94.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_94.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_94.Enabled = true
		v_94.Parent = v_81
	end
	do
		local v_95 = Instance.new("WeldConstraint")
		v_95.Name = "Part_Weld"
		refMap["95"] = v_95
		v_95.Parent = v_81
	end
	end
	end
	end

	for _, pending in ipairs(pendingRefs) do
		local target = refMap[pending.ref]
		if target then
			pending.obj[pending.prop] = target
		end
	end
end

local function buildAura11(auraFolder: Folder)
	local refMap = {}
	local pendingRefs = {}

	do
		local v_0 = Instance.new("Model")
		v_0.Name = "Aura11"
		refMap["0"] = v_0
		v_0:SetAttribute("CosmeticType", "Aura")
		v_0:SetAttribute("CosmeticId", "Aura11")
		v_0:SetAttribute("TargetPart", "HumanoidRootPart")
		v_0:SetAttribute("SupportsR6", true)
		v_0:SetAttribute("SupportsR15", true)
		v_0.Parent = auraFolder
	do
		local v_1 = Instance.new("CFrameValue")
		v_1.Name = "LocalOffset"
		refMap["2"] = v_1
		v_1.Value = CFrame.new(0.000, -0.500, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_1.Parent = v_0
	end
	do
		local v_2 = Instance.new("Part")
		v_2.Name = "EffectHolder"
		refMap["1"] = v_2
		v_2.Anchored = false
		v_2.CanCollide = false
		v_2.CanTouch = false
		v_2.CanQuery = false
		v_2.Massless = true
		v_2.CastShadow = false
		v_2.Transparency = 1.00
		v_2.Size = Vector3.new(4.000, 6.000, 3.000)
		v_2.CFrame = CFrame.new(-140.500, 22.000, -60.000, 0.000, 0.000, -1.000, 0.000, 1.000, 0.000, 1.000, 0.000, 0.000)
		v_2.Color = Color3.fromRGB(163, 162, 165)
		v_2.Parent = v_0
	do
		local v_3 = Instance.new("Part")
		v_3.Name = "inwardbezier"
		refMap["3"] = v_3
		v_3.Anchored = false
		v_3.CanCollide = false
		v_3.CanTouch = false
		v_3.CanQuery = false
		v_3.Massless = true
		v_3.CastShadow = false
		v_3.Transparency = 1.00
		v_3.Size = Vector3.new(10.000, 10.000, 10.000)
		v_3.CFrame = CFrame.new(-140.543, 22.031, -60.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_3.Color = Color3.fromRGB(248, 248, 248)
		v_3.Parent = v_2
	do
		local v_4 = Instance.new("Attachment")
		v_4.Name = "Bezier"
		refMap["4"] = v_4
		v_4.CFrame = CFrame.new(0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_4.Parent = v_3
	do
		local v_5 = Instance.new("Attachment")
		v_5.Name = "Points"
		refMap["5"] = v_5
		v_5.CFrame = CFrame.new(0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_5.Parent = v_4
	do
		local v_6 = Instance.new("Attachment")
		v_6.Name = "2"
		refMap["6"] = v_6
		v_6.CFrame = CFrame.new(0.898, -0.143, -15.205, -0.000, 0.000, -1.000, 0.000, 1.000, 0.000, 1.000, 0.000, -0.000)
		v_6.Parent = v_5
	do
		local v_7 = Instance.new("Attachment")
		v_7.Name = "T1"
		refMap["7"] = v_7
		v_7.CFrame = CFrame.new(2.300, 6.629, 1.667, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_7.Parent = v_6
	end
	end
	do
		local v_8 = Instance.new("Attachment")
		v_8.Name = "1"
		refMap["8"] = v_8
		v_8.CFrame = CFrame.new(0.000, 0.000, 3.716, 0.000, 0.000, -1.000, 0.000, 1.000, 0.000, 1.000, 0.000, 0.000)
		v_8.Parent = v_5
	do
		local v_9 = Instance.new("Attachment")
		v_9.Name = "T0"
		refMap["9"] = v_9
		v_9.CFrame = CFrame.new(-2.589, -7.266, -0.197, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_9.Parent = v_8
	end
	end
	end
	do
		local v_10 = Instance.new("Attachment")
		v_10.Name = "End"
		refMap["10"] = v_10
		v_10.CFrame = CFrame.new(0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_10.Parent = v_4
	end
	do
		local v_11 = Instance.new("Part")
		v_11.Name = "Part"
		refMap["11"] = v_11
		v_11.Anchored = false
		v_11.CanCollide = false
		v_11.CanTouch = false
		v_11.CanQuery = false
		v_11.Massless = true
		v_11.CastShadow = false
		v_11.Transparency = 1.00
		v_11.Size = Vector3.new(0.400, 0.400, 0.400)
		v_11.CFrame = CFrame.new(-140.543, 22.031, -60.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_11.Color = Color3.fromRGB(248, 248, 248)
		v_11.Parent = v_4
	do
		local v_12 = Instance.new("Attachment")
		v_12.Name = "0"
		refMap["12"] = v_12
		v_12.CFrame = CFrame.new(-0.023, 0.000, 0.284, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_12.Parent = v_11
	end
	do
		local v_13 = Instance.new("Trail")
		v_13.Name = "Beam88"
		refMap["13"] = v_13
		v_13.Texture = "rbxassetid://133860736415104"
		v_13.Lifetime = 0.30
		v_13.MinLength = 0.00
		v_13.LightEmission = 0.00
		v_13.LightInfluence = 0.00
		v_13.FaceCamera = true
		v_13.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_13.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_13.Enabled = true
		table.insert(pendingRefs, { obj = v_13, prop = "Attachment0", ref = "12" })
		table.insert(pendingRefs, { obj = v_13, prop = "Attachment1", ref = "14" })
		v_13.Parent = v_11
	end
	do
		local v_14 = Instance.new("Attachment")
		v_14.Name = "1"
		refMap["14"] = v_14
		v_14.CFrame = CFrame.new(-0.031, 0.000, -0.269, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_14.Parent = v_11
	end
	end
	end
	do
		local v_15 = Instance.new("Attachment")
		v_15.Name = "Bezier"
		refMap["15"] = v_15
		v_15.CFrame = CFrame.new(0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_15.Parent = v_3
	do
		local v_16 = Instance.new("Attachment")
		v_16.Name = "Points"
		refMap["16"] = v_16
		v_16.CFrame = CFrame.new(0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_16.Parent = v_15
	do
		local v_17 = Instance.new("Attachment")
		v_17.Name = "2"
		refMap["17"] = v_17
		v_17.CFrame = CFrame.new(0.898, -0.143, -15.205, -0.000, 0.000, -1.000, 0.000, 1.000, 0.000, 1.000, 0.000, -0.000)
		v_17.Parent = v_16
	do
		local v_18 = Instance.new("Attachment")
		v_18.Name = "T1"
		refMap["18"] = v_18
		v_18.CFrame = CFrame.new(2.300, 6.629, 1.667, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_18.Parent = v_17
	end
	end
	do
		local v_19 = Instance.new("Attachment")
		v_19.Name = "1"
		refMap["19"] = v_19
		v_19.CFrame = CFrame.new(0.000, 0.000, 3.716, 0.000, 0.000, -1.000, 0.000, 1.000, 0.000, 1.000, 0.000, 0.000)
		v_19.Parent = v_16
	do
		local v_20 = Instance.new("Attachment")
		v_20.Name = "T0"
		refMap["20"] = v_20
		v_20.CFrame = CFrame.new(-2.589, -7.266, -0.197, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_20.Parent = v_19
	end
	end
	end
	do
		local v_21 = Instance.new("Attachment")
		v_21.Name = "End"
		refMap["21"] = v_21
		v_21.CFrame = CFrame.new(0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_21.Parent = v_15
	end
	do
		local v_22 = Instance.new("Part")
		v_22.Name = "Part"
		refMap["22"] = v_22
		v_22.Anchored = false
		v_22.CanCollide = false
		v_22.CanTouch = false
		v_22.CanQuery = false
		v_22.Massless = true
		v_22.CastShadow = false
		v_22.Transparency = 1.00
		v_22.Size = Vector3.new(0.400, 0.400, 0.400)
		v_22.CFrame = CFrame.new(-140.543, 22.031, -60.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_22.Color = Color3.fromRGB(248, 248, 248)
		v_22.Parent = v_15
	do
		local v_23 = Instance.new("Attachment")
		v_23.Name = "0"
		refMap["23"] = v_23
		v_23.CFrame = CFrame.new(-0.022, 0.000, 0.316, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_23.Parent = v_22
	end
	do
		local v_24 = Instance.new("Trail")
		v_24.Name = "cursed energy trail 2"
		refMap["24"] = v_24
		v_24.Texture = "rbxassetid://119952780050980"
		v_24.Lifetime = 0.30
		v_24.MinLength = 0.00
		v_24.LightEmission = 0.00
		v_24.LightInfluence = 0.00
		v_24.FaceCamera = true
		v_24.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_24.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.17, 0.287, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_24.Enabled = true
		table.insert(pendingRefs, { obj = v_24, prop = "Attachment0", ref = "23" })
		table.insert(pendingRefs, { obj = v_24, prop = "Attachment1", ref = "25" })
		v_24.Parent = v_22
	end
	do
		local v_25 = Instance.new("Attachment")
		v_25.Name = "1"
		refMap["25"] = v_25
		v_25.CFrame = CFrame.new(-0.031, 0.000, -0.301, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_25.Parent = v_22
	end
	end
	end
	do
		local v_26 = Instance.new("WeldConstraint")
		v_26.Name = "inwardbezier_Weld"
		refMap["26"] = v_26
		v_26.Parent = v_3
	end
	end
	do
		local v_27 = Instance.new("Attachment")
		v_27.Name = "Attachment"
		refMap["27"] = v_27
		v_27.CFrame = CFrame.new(0.000, -3.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_27.Parent = v_2
	do
		local v_28 = Instance.new("ParticleEmitter")
		v_28.Name = "windfs"
		refMap["28"] = v_28
		v_28.Texture = "rbxassetid://135128020878697"
		v_28.Rate = 2.00
		v_28.Speed = NumberRange.new(0.00, 0.00)
		v_28.Lifetime = NumberRange.new(1.00, 2.00)
		v_28.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_28.Rotation = NumberRange.new(-360.00, 360.00)
		v_28.SpreadAngle = Vector2.new(-30.0, 20.0)
		v_28.LightEmission = 0.00
		v_28.LightInfluence = 0.00
		v_28.LockedToPart = true
		v_28.ZOffset = 1.04
		v_28.Drag = 0.00
		v_28.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_28.VelocityInheritance = 0.00
		v_28.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_28.EmissionDirection = Enum.NormalId.Top
		v_28.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(0.24, Color3.new(0.3845, 0.1347, 0.1376)), ColorSequenceKeypoint.new(0.45, Color3.new(0.1487, 0.0526, 0.0529)), ColorSequenceKeypoint.new(1.00, Color3.new(0.1216, 0.0431, 0.0431))})
		v_28.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.17, 3.700, 0.000), NumberSequenceKeypoint.new(1.00, 6.000, 0.000)})
		v_28.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_28.Enabled = true
		v_28.Parent = v_27
	end
	do
		local v_29 = Instance.new("ParticleEmitter")
		v_29.Name = "another shockwave"
		refMap["29"] = v_29
		v_29.Texture = "rbxassetid://13582043821"
		v_29.Rate = 2.00
		v_29.Speed = NumberRange.new(0.00, 0.00)
		v_29.Lifetime = NumberRange.new(1.00, 2.00)
		v_29.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_29.Rotation = NumberRange.new(-360.00, 360.00)
		v_29.SpreadAngle = Vector2.new(0.0, 0.0)
		v_29.LightEmission = 0.00
		v_29.LightInfluence = 0.00
		v_29.LockedToPart = true
		v_29.ZOffset = 2.01
		v_29.Drag = 0.00
		v_29.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_29.VelocityInheritance = 0.00
		v_29.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_29.EmissionDirection = Enum.NormalId.Top
		v_29.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(0.24, Color3.new(0.3845, 0.1347, 0.1376)), ColorSequenceKeypoint.new(0.45, Color3.new(0.1487, 0.0526, 0.0529)), ColorSequenceKeypoint.new(1.00, Color3.new(0.1216, 0.0431, 0.0431))})
		v_29.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.17, 5.639, 0.000), NumberSequenceKeypoint.new(0.49, 8.504, 0.000), NumberSequenceKeypoint.new(1.00, 9.144, 0.000)})
		v_29.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.427, 0.000), NumberSequenceKeypoint.new(0.54, 0.627, 0.000), NumberSequenceKeypoint.new(0.76, 0.737, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_29.Enabled = true
		v_29.Parent = v_27
	end
	do
		local v_30 = Instance.new("ParticleEmitter")
		v_30.Name = "Thin realistic shockwave"
		refMap["30"] = v_30
		v_30.Texture = "rbxassetid://12906276200"
		v_30.Rate = 2.00
		v_30.Speed = NumberRange.new(0.00, 0.00)
		v_30.Lifetime = NumberRange.new(1.00, 2.00)
		v_30.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_30.Rotation = NumberRange.new(-360.00, 360.00)
		v_30.SpreadAngle = Vector2.new(-30.0, 20.0)
		v_30.LightEmission = 0.00
		v_30.LightInfluence = 0.00
		v_30.LockedToPart = true
		v_30.ZOffset = 1.07
		v_30.Drag = 0.00
		v_30.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_30.VelocityInheritance = 0.00
		v_30.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_30.EmissionDirection = Enum.NormalId.Top
		v_30.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_30.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.6745, 0.2353, 0.2431)), ColorSequenceKeypoint.new(1.00, Color3.new(0.6745, 0.2353, 0.2431))})
		v_30.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.17, 5.586, 0.000), NumberSequenceKeypoint.new(1.00, 9.058, 0.000)})
		v_30.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.247, 0.000), NumberSequenceKeypoint.new(0.90, 0.577, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_30.Enabled = true
		v_30.Parent = v_27
	end
	do
		local v_31 = Instance.new("ParticleEmitter")
		v_31.Name = "weird shockwave"
		refMap["31"] = v_31
		v_31.Texture = "rbxassetid://16940431172"
		v_31.Rate = 2.00
		v_31.Speed = NumberRange.new(0.00, 0.00)
		v_31.Lifetime = NumberRange.new(1.00, 2.00)
		v_31.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_31.Rotation = NumberRange.new(-360.00, 360.00)
		v_31.SpreadAngle = Vector2.new(0.0, 0.0)
		v_31.LightEmission = 0.00
		v_31.LightInfluence = 0.00
		v_31.LockedToPart = true
		v_31.ZOffset = 1.04
		v_31.Drag = 0.00
		v_31.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_31.VelocityInheritance = 0.00
		v_31.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_31.EmissionDirection = Enum.NormalId.Top
		v_31.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(0.24, Color3.new(0.3845, 0.1347, 0.1376)), ColorSequenceKeypoint.new(0.45, Color3.new(0.1487, 0.0526, 0.0529)), ColorSequenceKeypoint.new(1.00, Color3.new(0.1216, 0.0431, 0.0431))})
		v_31.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.17, 4.256, 0.000), NumberSequenceKeypoint.new(0.49, 6.419, 0.000), NumberSequenceKeypoint.new(1.00, 6.902, 0.000)})
		v_31.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.180, 0.000), NumberSequenceKeypoint.new(0.59, 0.370, 0.000), NumberSequenceKeypoint.new(0.82, 0.617, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_31.Enabled = true
		v_31.Parent = v_27
	end
	do
		local v_32 = Instance.new("ParticleEmitter")
		v_32.Name = "grainy shockwave 2"
		refMap["32"] = v_32
		v_32.Texture = "rbxassetid://16509144751"
		v_32.Rate = 2.00
		v_32.Speed = NumberRange.new(0.00, 0.00)
		v_32.Lifetime = NumberRange.new(1.00, 2.00)
		v_32.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_32.Rotation = NumberRange.new(-360.00, 360.00)
		v_32.SpreadAngle = Vector2.new(0.0, 0.0)
		v_32.LightEmission = 0.00
		v_32.LightInfluence = 0.00
		v_32.LockedToPart = true
		v_32.ZOffset = 1.02
		v_32.Drag = 0.00
		v_32.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_32.VelocityInheritance = 0.00
		v_32.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_32.EmissionDirection = Enum.NormalId.Top
		v_32.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(0.24, Color3.new(0.3845, 0.1347, 0.1376)), ColorSequenceKeypoint.new(0.45, Color3.new(0.1487, 0.0526, 0.0529)), ColorSequenceKeypoint.new(1.00, Color3.new(0.1216, 0.0431, 0.0431))})
		v_32.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.17, 5.639, 0.000), NumberSequenceKeypoint.new(0.49, 8.504, 0.000), NumberSequenceKeypoint.new(1.00, 9.144, 0.000)})
		v_32.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.427, 0.000), NumberSequenceKeypoint.new(0.54, 0.627, 0.000), NumberSequenceKeypoint.new(0.76, 0.737, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_32.Enabled = true
		v_32.Parent = v_27
	end
	do
		local v_33 = Instance.new("ParticleEmitter")
		v_33.Name = "cursed energy 2"
		refMap["33"] = v_33
		v_33.Texture = "rbxassetid://78422400450982"
		v_33.Rate = 2.00
		v_33.Speed = NumberRange.new(0.00, 0.00)
		v_33.Lifetime = NumberRange.new(1.00, 2.00)
		v_33.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_33.Rotation = NumberRange.new(-360.00, 360.00)
		v_33.SpreadAngle = Vector2.new(0.0, 0.0)
		v_33.LightEmission = 0.00
		v_33.LightInfluence = 0.00
		v_33.LockedToPart = true
		v_33.ZOffset = 1.01
		v_33.Drag = 0.00
		v_33.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_33.VelocityInheritance = 0.00
		v_33.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_33.EmissionDirection = Enum.NormalId.Top
		v_33.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.6745, 0.2353, 0.2431)), ColorSequenceKeypoint.new(1.00, Color3.new(0.6745, 0.2353, 0.2431))})
		v_33.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.17, 4.745, 0.000), NumberSequenceKeypoint.new(1.00, 7.694, 0.000)})
		v_33.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.247, 0.000), NumberSequenceKeypoint.new(0.90, 0.577, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_33.Enabled = true
		v_33.Parent = v_27
	end
	do
		local v_34 = Instance.new("ParticleEmitter")
		v_34.Name = "cursed energy 2"
		refMap["34"] = v_34
		v_34.Texture = "rbxassetid://78422400450982"
		v_34.Rate = 2.00
		v_34.Speed = NumberRange.new(0.00, 0.00)
		v_34.Lifetime = NumberRange.new(1.00, 2.00)
		v_34.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_34.Rotation = NumberRange.new(-360.00, 360.00)
		v_34.SpreadAngle = Vector2.new(0.0, 0.0)
		v_34.LightEmission = 0.00
		v_34.LightInfluence = 0.00
		v_34.LockedToPart = true
		v_34.ZOffset = 1.03
		v_34.Drag = 0.00
		v_34.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_34.VelocityInheritance = 0.00
		v_34.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_34.EmissionDirection = Enum.NormalId.Top
		v_34.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.6745, 0.2353, 0.2431)), ColorSequenceKeypoint.new(1.00, Color3.new(0.6745, 0.2353, 0.2431))})
		v_34.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.17, 3.840, 0.000), NumberSequenceKeypoint.new(1.00, 6.227, 0.000)})
		v_34.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.247, 0.000), NumberSequenceKeypoint.new(0.90, 0.577, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_34.Enabled = true
		v_34.Parent = v_27
	end
	do
		local v_35 = Instance.new("ParticleEmitter")
		v_35.Name = "Smokey Crescent"
		refMap["35"] = v_35
		v_35.Texture = "rbxassetid://17085222506"
		v_35.Rate = 2.00
		v_35.Speed = NumberRange.new(0.00, 0.00)
		v_35.Lifetime = NumberRange.new(1.00, 2.00)
		v_35.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_35.Rotation = NumberRange.new(-360.00, 360.00)
		v_35.SpreadAngle = Vector2.new(-30.0, 20.0)
		v_35.LightEmission = 0.00
		v_35.LightInfluence = 0.00
		v_35.LockedToPart = true
		v_35.ZOffset = 1.03
		v_35.Drag = 0.00
		v_35.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_35.VelocityInheritance = 0.00
		v_35.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_35.EmissionDirection = Enum.NormalId.Top
		v_35.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_35.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(0.24, Color3.new(0.3845, 0.1347, 0.1376)), ColorSequenceKeypoint.new(0.45, Color3.new(0.1487, 0.0526, 0.0529)), ColorSequenceKeypoint.new(1.00, Color3.new(0.1216, 0.0431, 0.0431))})
		v_35.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.17, 3.700, 0.000), NumberSequenceKeypoint.new(1.00, 6.000, 0.000)})
		v_35.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_35.Enabled = true
		v_35.Parent = v_27
	end
	end
	do
		local v_36 = Instance.new("Attachment")
		v_36.Name = "Attachment"
		refMap["36"] = v_36
		v_36.CFrame = CFrame.new(0.000, -3.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_36.Parent = v_2
	do
		local v_37 = Instance.new("ParticleEmitter")
		v_37.Name = "dis dark circle 2"
		refMap["37"] = v_37
		v_37.Texture = "rbxassetid://87272078452382"
		v_37.Rate = 2.00
		v_37.Speed = NumberRange.new(0.00, 0.00)
		v_37.Lifetime = NumberRange.new(1.00, 2.00)
		v_37.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_37.Rotation = NumberRange.new(-360.00, 360.00)
		v_37.SpreadAngle = Vector2.new(0.0, 0.0)
		v_37.LightEmission = 0.00
		v_37.LightInfluence = 0.00
		v_37.LockedToPart = true
		v_37.ZOffset = 1.03
		v_37.Drag = 0.00
		v_37.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_37.VelocityInheritance = 0.00
		v_37.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_37.EmissionDirection = Enum.NormalId.Top
		v_37.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_37.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.17, 4.037, 0.000), NumberSequenceKeypoint.new(0.49, 6.557, 0.000), NumberSequenceKeypoint.new(1.00, 7.000, 0.000)})
		v_37.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.62, 0.213, 0.000), NumberSequenceKeypoint.new(0.84, 0.467, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_37.Enabled = true
		v_37.Parent = v_36
	end
	do
		local v_38 = Instance.new("ParticleEmitter")
		v_38.Name = "Slightly glowing"
		refMap["38"] = v_38
		v_38.Texture = "rbxassetid://14152113700"
		v_38.Rate = 2.00
		v_38.Speed = NumberRange.new(0.00, 0.00)
		v_38.Lifetime = NumberRange.new(1.00, 2.00)
		v_38.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_38.Rotation = NumberRange.new(-360.00, 360.00)
		v_38.SpreadAngle = Vector2.new(0.0, 0.0)
		v_38.LightEmission = 0.00
		v_38.LightInfluence = 0.00
		v_38.LockedToPart = true
		v_38.ZOffset = 2.00
		v_38.Drag = 0.00
		v_38.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_38.VelocityInheritance = 0.00
		v_38.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_38.EmissionDirection = Enum.NormalId.Top
		v_38.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_38.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(0.24, Color3.new(0.3845, 0.1347, 0.1376)), ColorSequenceKeypoint.new(0.45, Color3.new(0.1487, 0.0526, 0.0529)), ColorSequenceKeypoint.new(1.00, Color3.new(0.1216, 0.0431, 0.0431))})
		v_38.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.17, 4.037, 0.000), NumberSequenceKeypoint.new(0.49, 6.557, 0.000), NumberSequenceKeypoint.new(1.00, 7.000, 0.000)})
		v_38.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_38.Enabled = true
		v_38.Parent = v_36
	end
	end
	do
		local v_39 = Instance.new("Attachment")
		v_39.Name = "Attachment"
		refMap["39"] = v_39
		v_39.CFrame = CFrame.new(0.000, 1.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_39.Parent = v_2
	do
		local v_40 = Instance.new("ParticleEmitter")
		v_40.Name = "cursed energy 3"
		refMap["40"] = v_40
		v_40.Texture = "rbxassetid://17006174840"
		v_40.Rate = 1.00
		v_40.Speed = NumberRange.new(0.00, 0.00)
		v_40.Lifetime = NumberRange.new(2.00, 2.00)
		v_40.RotSpeed = NumberRange.new(0.00, 0.00)
		v_40.Rotation = NumberRange.new(0.00, 0.00)
		v_40.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_40.LightEmission = 0.00
		v_40.LightInfluence = 0.00
		v_40.LockedToPart = true
		v_40.ZOffset = 0.01
		v_40.Drag = 2.00
		v_40.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_40.VelocityInheritance = 0.00
		v_40.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
		v_40.EmissionDirection = Enum.NormalId.Top
		v_40.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_40.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 5.484, 0.000), NumberSequenceKeypoint.new(0.48, 7.938, 0.000), NumberSequenceKeypoint.new(1.00, 8.659, 0.000)})
		v_40.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.360, 0.000), NumberSequenceKeypoint.new(0.63, 0.567, 0.000), NumberSequenceKeypoint.new(0.82, 0.740, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_40.Enabled = true
		v_40.Parent = v_39
	end
	do
		local v_41 = Instance.new("ParticleEmitter")
		v_41.Name = "Iso cursed"
		refMap["41"] = v_41
		v_41.Texture = "rbxassetid://102330699321283"
		v_41.Rate = 1.00
		v_41.Speed = NumberRange.new(0.00, 0.00)
		v_41.Lifetime = NumberRange.new(2.00, 2.00)
		v_41.RotSpeed = NumberRange.new(0.00, 0.00)
		v_41.Rotation = NumberRange.new(0.00, 0.00)
		v_41.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_41.LightEmission = 0.00
		v_41.LightInfluence = 0.00
		v_41.LockedToPart = true
		v_41.ZOffset = 0.02
		v_41.Drag = 2.00
		v_41.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_41.VelocityInheritance = 0.00
		v_41.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
		v_41.EmissionDirection = Enum.NormalId.Top
		v_41.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_41.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 5.484, 0.000), NumberSequenceKeypoint.new(0.48, 7.938, 0.000), NumberSequenceKeypoint.new(1.00, 8.659, 0.000)})
		v_41.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.360, 0.000), NumberSequenceKeypoint.new(0.63, 0.567, 0.000), NumberSequenceKeypoint.new(0.82, 0.740, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_41.Enabled = true
		v_41.Parent = v_39
	end
	do
		local v_42 = Instance.new("ParticleEmitter")
		v_42.Name = "Triangle Top"
		refMap["42"] = v_42
		v_42.Texture = "rbxassetid://15009885079"
		v_42.Rate = 4.00
		v_42.Speed = NumberRange.new(0.00, 0.00)
		v_42.Lifetime = NumberRange.new(0.40, 1.00)
		v_42.RotSpeed = NumberRange.new(0.00, 0.00)
		v_42.Rotation = NumberRange.new(0.00, 0.00)
		v_42.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_42.LightEmission = 0.00
		v_42.LightInfluence = 0.00
		v_42.LockedToPart = true
		v_42.ZOffset = 1.00
		v_42.Drag = 2.00
		v_42.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_42.VelocityInheritance = 0.00
		v_42.Orientation = Enum.ParticleOrientation.FacingCamera
		v_42.EmissionDirection = Enum.NormalId.Top
		v_42.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8
		v_42.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_42.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.15, 2.900, 0.828), NumberSequenceKeypoint.new(0.42, 4.272, 0.902), NumberSequenceKeypoint.new(1.00, 4.683, 1.053)})
		v_42.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.263, 0.000), NumberSequenceKeypoint.new(0.85, 0.557, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_42.Enabled = true
		v_42.Parent = v_39
	end
	do
		local v_43 = Instance.new("ParticleEmitter")
		v_43.Name = "cursed energy min"
		refMap["43"] = v_43
		v_43.Texture = "rbxassetid://125843391083656"
		v_43.Rate = 1.00
		v_43.Speed = NumberRange.new(0.00, 0.00)
		v_43.Lifetime = NumberRange.new(2.00, 2.00)
		v_43.RotSpeed = NumberRange.new(0.00, 0.00)
		v_43.Rotation = NumberRange.new(0.00, 0.00)
		v_43.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_43.LightEmission = 0.00
		v_43.LightInfluence = 0.00
		v_43.LockedToPart = true
		v_43.ZOffset = 0.02
		v_43.Drag = 2.00
		v_43.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_43.VelocityInheritance = 0.00
		v_43.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
		v_43.EmissionDirection = Enum.NormalId.Top
		v_43.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_43.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 4.439, 0.000), NumberSequenceKeypoint.new(0.48, 6.424, 0.000), NumberSequenceKeypoint.new(1.00, 7.008, 0.000)})
		v_43.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.360, 0.000), NumberSequenceKeypoint.new(0.63, 0.567, 0.000), NumberSequenceKeypoint.new(0.82, 0.740, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_43.Enabled = true
		v_43.Parent = v_39
	end
	end
	do
		local v_44 = Instance.new("Attachment")
		v_44.Name = "Attachment"
		refMap["44"] = v_44
		v_44.CFrame = CFrame.new(0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_44.Parent = v_2
	do
		local v_45 = Instance.new("ParticleEmitter")
		v_45.Name = "cat spec 7"
		refMap["45"] = v_45
		v_45.Texture = "rbxassetid://90414839644727"
		v_45.Rate = 2.00
		v_45.Speed = NumberRange.new(12.93, 25.87)
		v_45.Lifetime = NumberRange.new(0.40, 1.00)
		v_45.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_45.Rotation = NumberRange.new(-360.00, 360.00)
		v_45.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_45.LightEmission = 0.00
		v_45.LightInfluence = 0.00
		v_45.LockedToPart = false
		v_45.ZOffset = 2.02
		v_45.Drag = 4.00
		v_45.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_45.VelocityInheritance = 0.00
		v_45.Orientation = Enum.ParticleOrientation.FacingCamera
		v_45.EmissionDirection = Enum.NormalId.Top
		v_45.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_45.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_45.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.996, 0.000), NumberSequenceKeypoint.new(0.73, 0.621, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_45.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_45.Enabled = true
		v_45.Parent = v_44
	end
	do
		local v_46 = Instance.new("ParticleEmitter")
		v_46.Name = "Cursed Energy Disperse 8x8"
		refMap["46"] = v_46
		v_46.Texture = "rbxassetid://97051019398375"
		v_46.Rate = 2.00
		v_46.Speed = NumberRange.new(14.00, 20.00)
		v_46.Lifetime = NumberRange.new(0.40, 1.00)
		v_46.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_46.Rotation = NumberRange.new(-360.00, 360.00)
		v_46.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_46.LightEmission = 0.00
		v_46.LightInfluence = 0.00
		v_46.LockedToPart = true
		v_46.ZOffset = 1.02
		v_46.Drag = 7.00
		v_46.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_46.VelocityInheritance = 0.00
		v_46.Orientation = Enum.ParticleOrientation.FacingCamera
		v_46.EmissionDirection = Enum.NormalId.Top
		v_46.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8
		v_46.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_46.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.862, 0.000), NumberSequenceKeypoint.new(0.48, 4.143, 0.000), NumberSequenceKeypoint.new(1.00, 4.519, 0.000)})
		v_46.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.317, 0.000), NumberSequenceKeypoint.new(0.86, 0.683, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_46.Enabled = true
		v_46.Parent = v_44
	end
	do
		local v_47 = Instance.new("ParticleEmitter")
		v_47.Name = "Fire54"
		refMap["47"] = v_47
		v_47.Texture = "rbxassetid://17006155963"
		v_47.Rate = 3.00
		v_47.Speed = NumberRange.new(0.00, 0.00)
		v_47.Lifetime = NumberRange.new(0.70, 2.00)
		v_47.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_47.Rotation = NumberRange.new(-360.00, 360.00)
		v_47.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_47.LightEmission = 0.00
		v_47.LightInfluence = 0.00
		v_47.LockedToPart = true
		v_47.ZOffset = 1.07
		v_47.Drag = 2.00
		v_47.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_47.VelocityInheritance = 0.00
		v_47.Orientation = Enum.ParticleOrientation.FacingCamera
		v_47.EmissionDirection = Enum.NormalId.Top
		v_47.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_47.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_47.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.862, 0.000), NumberSequenceKeypoint.new(0.48, 4.143, 0.000), NumberSequenceKeypoint.new(1.00, 4.519, 0.000)})
		v_47.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_47.Enabled = true
		v_47.Parent = v_44
	end
	do
		local v_48 = Instance.new("ParticleEmitter")
		v_48.Name = "Thin realistic shockwave"
		refMap["48"] = v_48
		v_48.Texture = "rbxassetid://12906276200"
		v_48.Rate = 2.00
		v_48.Speed = NumberRange.new(0.00, 0.00)
		v_48.Lifetime = NumberRange.new(0.40, 1.00)
		v_48.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_48.Rotation = NumberRange.new(-360.00, 360.00)
		v_48.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_48.LightEmission = 0.00
		v_48.LightInfluence = 0.00
		v_48.LockedToPart = true
		v_48.ZOffset = 2.07
		v_48.Drag = 2.00
		v_48.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_48.VelocityInheritance = 0.00
		v_48.Orientation = Enum.ParticleOrientation.FacingCamera
		v_48.EmissionDirection = Enum.NormalId.Top
		v_48.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_48.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_48.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 3.751, 0.000), NumberSequenceKeypoint.new(0.48, 5.429, 0.000), NumberSequenceKeypoint.new(1.00, 5.923, 0.000)})
		v_48.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.63, 0.343, 0.000), NumberSequenceKeypoint.new(0.89, 0.643, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_48.Enabled = true
		v_48.Parent = v_44
	end
	do
		local v_49 = Instance.new("ParticleEmitter")
		v_49.Name = "cursed energy 2"
		refMap["49"] = v_49
		v_49.Texture = "rbxassetid://78422400450982"
		v_49.Rate = 2.00
		v_49.Speed = NumberRange.new(0.00, 0.00)
		v_49.Lifetime = NumberRange.new(0.40, 1.00)
		v_49.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_49.Rotation = NumberRange.new(-360.00, 360.00)
		v_49.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_49.LightEmission = 0.00
		v_49.LightInfluence = 0.00
		v_49.LockedToPart = true
		v_49.ZOffset = 1.04
		v_49.Drag = 2.00
		v_49.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_49.VelocityInheritance = 0.00
		v_49.Orientation = Enum.ParticleOrientation.FacingCamera
		v_49.EmissionDirection = Enum.NormalId.Top
		v_49.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_49.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.862, 0.000), NumberSequenceKeypoint.new(0.48, 4.143, 0.000), NumberSequenceKeypoint.new(1.00, 4.519, 0.000)})
		v_49.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_49.Enabled = true
		v_49.Parent = v_44
	end
	do
		local v_50 = Instance.new("ParticleEmitter")
		v_50.Name = "Slightly glowing"
		refMap["50"] = v_50
		v_50.Texture = "rbxassetid://14152113700"
		v_50.Rate = 2.00
		v_50.Speed = NumberRange.new(0.00, 0.00)
		v_50.Lifetime = NumberRange.new(0.40, 1.00)
		v_50.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_50.Rotation = NumberRange.new(-360.00, 360.00)
		v_50.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_50.LightEmission = 0.00
		v_50.LightInfluence = 0.00
		v_50.LockedToPart = true
		v_50.ZOffset = 2.09
		v_50.Drag = 2.00
		v_50.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_50.VelocityInheritance = 0.00
		v_50.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_50.EmissionDirection = Enum.NormalId.Top
		v_50.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_50.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_50.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.533, 0.000), NumberSequenceKeypoint.new(0.48, 3.667, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_50.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_50.Enabled = true
		v_50.Parent = v_44
	end
	do
		local v_51 = Instance.new("ParticleEmitter")
		v_51.Name = "Light Ray"
		refMap["51"] = v_51
		v_51.Texture = "rbxassetid://14128173698"
		v_51.Rate = 4.00
		v_51.Speed = NumberRange.new(0.00, 0.00)
		v_51.Lifetime = NumberRange.new(0.40, 1.00)
		v_51.RotSpeed = NumberRange.new(30.00, 50.00)
		v_51.Rotation = NumberRange.new(0.00, 0.00)
		v_51.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_51.LightEmission = 0.00
		v_51.LightInfluence = 0.00
		v_51.LockedToPart = true
		v_51.ZOffset = 1.00
		v_51.Drag = 2.00
		v_51.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_51.VelocityInheritance = 0.00
		v_51.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_51.EmissionDirection = Enum.NormalId.Top
		v_51.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_51.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_51.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.15, 2.504, 0.715), NumberSequenceKeypoint.new(0.42, 3.688, 0.779), NumberSequenceKeypoint.new(1.00, 4.043, 0.909)})
		v_51.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.263, 0.000), NumberSequenceKeypoint.new(0.85, 0.557, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_51.Enabled = true
		v_51.Parent = v_44
	end
	do
		local v_52 = Instance.new("ParticleEmitter")
		v_52.Name = "cursed energy spec"
		refMap["52"] = v_52
		v_52.Texture = "rbxassetid://85688545954016"
		v_52.Rate = 2.00
		v_52.Speed = NumberRange.new(10.00, 20.00)
		v_52.Lifetime = NumberRange.new(0.40, 1.00)
		v_52.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_52.Rotation = NumberRange.new(-360.00, 360.00)
		v_52.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_52.LightEmission = 0.00
		v_52.LightInfluence = 0.00
		v_52.LockedToPart = false
		v_52.ZOffset = 2.04
		v_52.Drag = 4.00
		v_52.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_52.VelocityInheritance = 0.00
		v_52.Orientation = Enum.ParticleOrientation.FacingCamera
		v_52.EmissionDirection = Enum.NormalId.Top
		v_52.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_52.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_52.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_52.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_52.Enabled = true
		v_52.Parent = v_44
	end
	do
		local v_53 = Instance.new("ParticleEmitter")
		v_53.Name = "dis dark circle"
		refMap["53"] = v_53
		v_53.Texture = "rbxassetid://83617429710480"
		v_53.Rate = 2.00
		v_53.Speed = NumberRange.new(0.00, 0.00)
		v_53.Lifetime = NumberRange.new(0.40, 1.00)
		v_53.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_53.Rotation = NumberRange.new(-360.00, 360.00)
		v_53.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_53.LightEmission = 0.00
		v_53.LightInfluence = 0.00
		v_53.LockedToPart = true
		v_53.ZOffset = 2.05
		v_53.Drag = 2.00
		v_53.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_53.VelocityInheritance = 0.00
		v_53.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_53.EmissionDirection = Enum.NormalId.Top
		v_53.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_53.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.533, 0.000), NumberSequenceKeypoint.new(0.48, 3.667, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_53.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_53.Enabled = true
		v_53.Parent = v_44
	end
	do
		local v_54 = Instance.new("ParticleEmitter")
		v_54.Name = "Triangle Gradient Lens"
		refMap["54"] = v_54
		v_54.Texture = "rbxassetid://108684954560019"
		v_54.Rate = 4.00
		v_54.Speed = NumberRange.new(0.00, 0.00)
		v_54.Lifetime = NumberRange.new(0.40, 1.00)
		v_54.RotSpeed = NumberRange.new(30.00, 50.00)
		v_54.Rotation = NumberRange.new(0.00, 0.00)
		v_54.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_54.LightEmission = 0.00
		v_54.LightInfluence = 0.00
		v_54.LockedToPart = true
		v_54.ZOffset = 1.00
		v_54.Drag = 2.00
		v_54.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_54.VelocityInheritance = 0.00
		v_54.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_54.EmissionDirection = Enum.NormalId.Top
		v_54.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_54.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_54.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.15, 2.504, 0.715), NumberSequenceKeypoint.new(0.42, 3.688, 0.779), NumberSequenceKeypoint.new(1.00, 4.043, 0.909)})
		v_54.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.263, 0.000), NumberSequenceKeypoint.new(0.85, 0.557, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_54.Enabled = true
		v_54.Parent = v_44
	end
	do
		local v_55 = Instance.new("ParticleEmitter")
		v_55.Name = "cat spec 7"
		refMap["55"] = v_55
		v_55.Texture = "rbxassetid://90414839644727"
		v_55.Rate = 2.00
		v_55.Speed = NumberRange.new(10.00, 20.00)
		v_55.Lifetime = NumberRange.new(0.40, 1.00)
		v_55.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_55.Rotation = NumberRange.new(-360.00, 360.00)
		v_55.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_55.LightEmission = 0.00
		v_55.LightInfluence = 0.00
		v_55.LockedToPart = false
		v_55.ZOffset = 2.04
		v_55.Drag = 4.00
		v_55.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_55.VelocityInheritance = 0.00
		v_55.Orientation = Enum.ParticleOrientation.FacingCamera
		v_55.EmissionDirection = Enum.NormalId.Top
		v_55.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_55.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_55.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_55.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_55.Enabled = true
		v_55.Parent = v_44
	end
	do
		local v_56 = Instance.new("ParticleEmitter")
		v_56.Name = "cat spec 3"
		refMap["56"] = v_56
		v_56.Texture = "rbxassetid://136781994057492"
		v_56.Rate = 2.00
		v_56.Speed = NumberRange.new(10.00, 20.00)
		v_56.Lifetime = NumberRange.new(0.40, 1.00)
		v_56.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_56.Rotation = NumberRange.new(-360.00, 360.00)
		v_56.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_56.LightEmission = 0.00
		v_56.LightInfluence = 0.00
		v_56.LockedToPart = false
		v_56.ZOffset = 2.20
		v_56.Drag = 4.00
		v_56.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_56.VelocityInheritance = 0.00
		v_56.Orientation = Enum.ParticleOrientation.FacingCamera
		v_56.EmissionDirection = Enum.NormalId.Top
		v_56.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_56.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_56.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_56.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_56.Enabled = true
		v_56.Parent = v_44
	end
	do
		local v_57 = Instance.new("PointLight")
		v_57.Name = "PointLight"
		refMap["57"] = v_57
		v_57.Brightness = 2.00
		v_57.Range = 8.00
		v_57.Shadows = false
		v_57.Color = Color3.new(1.0000, 0.3490, 0.3588)
		v_57.Enabled = true
		v_57.Parent = v_44
	end
	do
		local v_58 = Instance.new("ParticleEmitter")
		v_58.Name = "cursed energy1"
		refMap["58"] = v_58
		v_58.Texture = "rbxassetid://112387970399345"
		v_58.Rate = 2.00
		v_58.Speed = NumberRange.new(0.00, 0.00)
		v_58.Lifetime = NumberRange.new(0.40, 1.00)
		v_58.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_58.Rotation = NumberRange.new(-360.00, 360.00)
		v_58.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_58.LightEmission = 0.00
		v_58.LightInfluence = 0.00
		v_58.LockedToPart = true
		v_58.ZOffset = 1.03
		v_58.Drag = 2.00
		v_58.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_58.VelocityInheritance = 0.00
		v_58.Orientation = Enum.ParticleOrientation.FacingCamera
		v_58.EmissionDirection = Enum.NormalId.Top
		v_58.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_58.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.862, 0.000), NumberSequenceKeypoint.new(0.48, 4.143, 0.000), NumberSequenceKeypoint.new(1.00, 4.519, 0.000)})
		v_58.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_58.Enabled = true
		v_58.Parent = v_44
	end
	do
		local v_59 = Instance.new("ParticleEmitter")
		v_59.Name = "cursed energy 2"
		refMap["59"] = v_59
		v_59.Texture = "rbxassetid://78422400450982"
		v_59.Rate = 2.00
		v_59.Speed = NumberRange.new(0.00, 0.00)
		v_59.Lifetime = NumberRange.new(0.40, 1.00)
		v_59.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_59.Rotation = NumberRange.new(-360.00, 360.00)
		v_59.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_59.LightEmission = 0.00
		v_59.LightInfluence = 0.00
		v_59.LockedToPart = true
		v_59.ZOffset = 2.07
		v_59.Drag = 2.00
		v_59.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_59.VelocityInheritance = 0.00
		v_59.Orientation = Enum.ParticleOrientation.FacingCamera
		v_59.EmissionDirection = Enum.NormalId.Top
		v_59.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_59.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.533, 0.000), NumberSequenceKeypoint.new(0.48, 3.667, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_59.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_59.Enabled = true
		v_59.Parent = v_44
	end
	do
		local v_60 = Instance.new("ParticleEmitter")
		v_60.Name = "Fire45"
		refMap["60"] = v_60
		v_60.Texture = "rbxassetid://16860419961"
		v_60.Rate = 3.00
		v_60.Speed = NumberRange.new(0.00, 0.00)
		v_60.Lifetime = NumberRange.new(0.40, 1.00)
		v_60.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_60.Rotation = NumberRange.new(-360.00, 360.00)
		v_60.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_60.LightEmission = 0.00
		v_60.LightInfluence = 0.00
		v_60.LockedToPart = true
		v_60.ZOffset = 2.03
		v_60.Drag = 2.00
		v_60.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_60.VelocityInheritance = 0.00
		v_60.Orientation = Enum.ParticleOrientation.FacingCamera
		v_60.EmissionDirection = Enum.NormalId.Top
		v_60.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_60.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_60.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 5.067, 0.000), NumberSequenceKeypoint.new(0.48, 7.333, 0.000), NumberSequenceKeypoint.new(1.00, 8.000, 0.000)})
		v_60.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_60.Enabled = true
		v_60.Parent = v_44
	end
	do
		local v_61 = Instance.new("ParticleEmitter")
		v_61.Name = "cat spec 8"
		refMap["61"] = v_61
		v_61.Texture = "rbxassetid://101658731548844"
		v_61.Rate = 2.00
		v_61.Speed = NumberRange.new(12.93, 25.87)
		v_61.Lifetime = NumberRange.new(0.40, 1.00)
		v_61.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_61.Rotation = NumberRange.new(-360.00, 360.00)
		v_61.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_61.LightEmission = 0.00
		v_61.LightInfluence = 0.00
		v_61.LockedToPart = false
		v_61.ZOffset = 2.05
		v_61.Drag = 4.00
		v_61.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_61.VelocityInheritance = 0.00
		v_61.Orientation = Enum.ParticleOrientation.FacingCamera
		v_61.EmissionDirection = Enum.NormalId.Top
		v_61.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_61.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_61.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.996, 0.000), NumberSequenceKeypoint.new(0.73, 0.621, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_61.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_61.Enabled = true
		v_61.Parent = v_44
	end
	do
		local v_62 = Instance.new("ParticleEmitter")
		v_62.Name = "grainy shockwave 2"
		refMap["62"] = v_62
		v_62.Texture = "rbxassetid://16509144751"
		v_62.Rate = 2.00
		v_62.Speed = NumberRange.new(0.00, 0.00)
		v_62.Lifetime = NumberRange.new(0.40, 1.00)
		v_62.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_62.Rotation = NumberRange.new(-360.00, 360.00)
		v_62.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_62.LightEmission = 0.00
		v_62.LightInfluence = 0.00
		v_62.LockedToPart = true
		v_62.ZOffset = 2.04
		v_62.Drag = 2.00
		v_62.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_62.VelocityInheritance = 0.00
		v_62.Orientation = Enum.ParticleOrientation.FacingCamera
		v_62.EmissionDirection = Enum.NormalId.Top
		v_62.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_62.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 3.751, 0.000), NumberSequenceKeypoint.new(0.48, 5.429, 0.000), NumberSequenceKeypoint.new(1.00, 5.923, 0.000)})
		v_62.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.63, 0.343, 0.000), NumberSequenceKeypoint.new(0.89, 0.643, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_62.Enabled = true
		v_62.Parent = v_44
	end
	do
		local v_63 = Instance.new("ParticleEmitter")
		v_63.Name = "Strange VFX"
		refMap["63"] = v_63
		v_63.Texture = "rbxassetid://18369800560"
		v_63.Rate = 3.00
		v_63.Speed = NumberRange.new(0.00, 0.00)
		v_63.Lifetime = NumberRange.new(0.70, 2.00)
		v_63.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_63.Rotation = NumberRange.new(-360.00, 360.00)
		v_63.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_63.LightEmission = 0.00
		v_63.LightInfluence = 0.00
		v_63.LockedToPart = true
		v_63.ZOffset = 1.02
		v_63.Drag = 2.00
		v_63.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_63.VelocityInheritance = 0.00
		v_63.Orientation = Enum.ParticleOrientation.FacingCamera
		v_63.EmissionDirection = Enum.NormalId.Top
		v_63.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_63.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_63.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.862, 0.000), NumberSequenceKeypoint.new(0.48, 4.143, 0.000), NumberSequenceKeypoint.new(1.00, 4.519, 0.000)})
		v_63.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_63.Enabled = true
		v_63.Parent = v_44
	end
	do
		local v_64 = Instance.new("ParticleEmitter")
		v_64.Name = "Thin realistic shockwave"
		refMap["64"] = v_64
		v_64.Texture = "rbxassetid://12906276200"
		v_64.Rate = 2.00
		v_64.Speed = NumberRange.new(0.00, 0.00)
		v_64.Lifetime = NumberRange.new(0.40, 1.00)
		v_64.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_64.Rotation = NumberRange.new(-360.00, 360.00)
		v_64.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_64.LightEmission = 0.00
		v_64.LightInfluence = 0.00
		v_64.LockedToPart = true
		v_64.ZOffset = 2.05
		v_64.Drag = 2.00
		v_64.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_64.VelocityInheritance = 0.00
		v_64.Orientation = Enum.ParticleOrientation.FacingCamera
		v_64.EmissionDirection = Enum.NormalId.Top
		v_64.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_64.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_64.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.533, 0.000), NumberSequenceKeypoint.new(0.48, 3.667, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_64.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.63, 0.343, 0.000), NumberSequenceKeypoint.new(0.89, 0.643, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_64.Enabled = true
		v_64.Parent = v_44
	end
	do
		local v_65 = Instance.new("ParticleEmitter")
		v_65.Name = "windfs"
		refMap["65"] = v_65
		v_65.Texture = "rbxassetid://135128020878697"
		v_65.Rate = 2.00
		v_65.Speed = NumberRange.new(0.00, 0.00)
		v_65.Lifetime = NumberRange.new(1.00, 1.50)
		v_65.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_65.Rotation = NumberRange.new(-360.00, 360.00)
		v_65.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_65.LightEmission = 0.00
		v_65.LightInfluence = 0.00
		v_65.LockedToPart = true
		v_65.ZOffset = 2.09
		v_65.Drag = 2.00
		v_65.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_65.VelocityInheritance = 0.00
		v_65.Orientation = Enum.ParticleOrientation.FacingCamera
		v_65.EmissionDirection = Enum.NormalId.Top
		v_65.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(0.22, Color3.new(0.4167, 0.1458, 0.1503)), ColorSequenceKeypoint.new(0.56, Color3.new(0.1753, 0.0617, 0.0640)), ColorSequenceKeypoint.new(1.00, Color3.new(0.1333, 0.0471, 0.0490))})
		v_65.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 3.532, 0.000), NumberSequenceKeypoint.new(0.48, 5.112, 0.000), NumberSequenceKeypoint.new(1.00, 5.577, 0.000)})
		v_65.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_65.Enabled = true
		v_65.Parent = v_44
	end
	do
		local v_66 = Instance.new("ParticleEmitter")
		v_66.Name = "Cursed Energy Disperse 8x8"
		refMap["66"] = v_66
		v_66.Texture = "rbxassetid://97051019398375"
		v_66.Rate = 2.00
		v_66.Speed = NumberRange.new(0.00, 0.00)
		v_66.Lifetime = NumberRange.new(0.40, 1.00)
		v_66.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_66.Rotation = NumberRange.new(-360.00, 360.00)
		v_66.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_66.LightEmission = 0.00
		v_66.LightInfluence = 0.00
		v_66.LockedToPart = true
		v_66.ZOffset = 2.04
		v_66.Drag = 2.00
		v_66.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_66.VelocityInheritance = 0.00
		v_66.Orientation = Enum.ParticleOrientation.FacingCamera
		v_66.EmissionDirection = Enum.NormalId.Top
		v_66.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8
		v_66.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_66.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.533, 0.000), NumberSequenceKeypoint.new(0.48, 3.667, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_66.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_66.Enabled = true
		v_66.Parent = v_44
	end
	do
		local v_67 = Instance.new("ParticleEmitter")
		v_67.Name = "cursed energy3421"
		refMap["67"] = v_67
		v_67.Texture = "rbxassetid://17006172452"
		v_67.Rate = 2.00
		v_67.Speed = NumberRange.new(0.00, 0.00)
		v_67.Lifetime = NumberRange.new(0.40, 1.00)
		v_67.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_67.Rotation = NumberRange.new(-360.00, 360.00)
		v_67.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_67.LightEmission = 0.00
		v_67.LightInfluence = 0.00
		v_67.LockedToPart = true
		v_67.ZOffset = 2.10
		v_67.Drag = 2.00
		v_67.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_67.VelocityInheritance = 0.00
		v_67.Orientation = Enum.ParticleOrientation.FacingCamera
		v_67.EmissionDirection = Enum.NormalId.Top
		v_67.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_67.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_67.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.533, 0.000), NumberSequenceKeypoint.new(0.48, 3.667, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_67.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.317, 0.000), NumberSequenceKeypoint.new(0.86, 0.683, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_67.Enabled = true
		v_67.Parent = v_44
	end
	do
		local v_68 = Instance.new("ParticleEmitter")
		v_68.Name = "Bright Horizontal Star Glare 2"
		refMap["68"] = v_68
		v_68.Texture = "rbxassetid://131904221700198"
		v_68.Rate = 4.00
		v_68.Speed = NumberRange.new(0.00, 0.00)
		v_68.Lifetime = NumberRange.new(0.40, 1.00)
		v_68.RotSpeed = NumberRange.new(0.00, 0.00)
		v_68.Rotation = NumberRange.new(0.00, 0.00)
		v_68.SpreadAngle = Vector2.new(0.0, 0.0)
		v_68.LightEmission = 0.00
		v_68.LightInfluence = 0.00
		v_68.LockedToPart = true
		v_68.ZOffset = 1.00
		v_68.Drag = 2.00
		v_68.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_68.VelocityInheritance = 0.00
		v_68.Orientation = Enum.ParticleOrientation.FacingCamera
		v_68.EmissionDirection = Enum.NormalId.Top
		v_68.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_68.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_68.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.15, 3.267, 0.000), NumberSequenceKeypoint.new(0.39, 4.317, 0.000), NumberSequenceKeypoint.new(1.00, 5.000, 0.000)})
		v_68.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.263, 0.000), NumberSequenceKeypoint.new(0.85, 0.557, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_68.Enabled = true
		v_68.Parent = v_44
	end
	do
		local v_69 = Instance.new("ParticleEmitter")
		v_69.Name = "cat spec 3"
		refMap["69"] = v_69
		v_69.Texture = "rbxassetid://136781994057492"
		v_69.Rate = 2.00
		v_69.Speed = NumberRange.new(12.93, 25.87)
		v_69.Lifetime = NumberRange.new(0.40, 1.00)
		v_69.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_69.Rotation = NumberRange.new(-360.00, 360.00)
		v_69.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_69.LightEmission = 0.00
		v_69.LightInfluence = 0.00
		v_69.LockedToPart = false
		v_69.ZOffset = 2.04
		v_69.Drag = 4.00
		v_69.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_69.VelocityInheritance = 0.00
		v_69.Orientation = Enum.ParticleOrientation.FacingCamera
		v_69.EmissionDirection = Enum.NormalId.Top
		v_69.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_69.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_69.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.996, 0.000), NumberSequenceKeypoint.new(0.73, 0.621, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_69.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_69.Enabled = true
		v_69.Parent = v_44
	end
	do
		local v_70 = Instance.new("ParticleEmitter")
		v_70.Name = "Slash22"
		refMap["70"] = v_70
		v_70.Texture = "rbxassetid://121148164489745"
		v_70.Rate = 2.00
		v_70.Speed = NumberRange.new(0.00, 0.00)
		v_70.Lifetime = NumberRange.new(0.40, 1.00)
		v_70.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_70.Rotation = NumberRange.new(-360.00, 360.00)
		v_70.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_70.LightEmission = 0.00
		v_70.LightInfluence = 0.00
		v_70.LockedToPart = true
		v_70.ZOffset = 1.04
		v_70.Drag = 2.00
		v_70.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_70.VelocityInheritance = 0.00
		v_70.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_70.EmissionDirection = Enum.NormalId.Top
		v_70.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_70.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_70.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 3.410, 0.000), NumberSequenceKeypoint.new(0.48, 4.936, 0.000), NumberSequenceKeypoint.new(1.00, 5.385, 0.000)})
		v_70.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_70.Enabled = true
		v_70.Parent = v_44
	end
	do
		local v_71 = Instance.new("ParticleEmitter")
		v_71.Name = "Fire54"
		refMap["71"] = v_71
		v_71.Texture = "rbxassetid://17006155963"
		v_71.Rate = 3.00
		v_71.Speed = NumberRange.new(0.00, 0.00)
		v_71.Lifetime = NumberRange.new(0.40, 1.00)
		v_71.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_71.Rotation = NumberRange.new(-360.00, 360.00)
		v_71.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_71.LightEmission = 0.00
		v_71.LightInfluence = 0.00
		v_71.LockedToPart = true
		v_71.ZOffset = 1.04
		v_71.Drag = 2.00
		v_71.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_71.VelocityInheritance = 0.00
		v_71.Orientation = Enum.ParticleOrientation.FacingCamera
		v_71.EmissionDirection = Enum.NormalId.Top
		v_71.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_71.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_71.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.533, 0.000), NumberSequenceKeypoint.new(0.48, 3.667, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_71.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_71.Enabled = true
		v_71.Parent = v_44
	end
	do
		local v_72 = Instance.new("ParticleEmitter")
		v_72.Name = "Strange VFX"
		refMap["72"] = v_72
		v_72.Texture = "rbxassetid://18369800560"
		v_72.Rate = 1.00
		v_72.Speed = NumberRange.new(0.00, 0.00)
		v_72.Lifetime = NumberRange.new(1.00, 2.00)
		v_72.RotSpeed = NumberRange.new(0.00, 0.00)
		v_72.Rotation = NumberRange.new(90.00, 90.00)
		v_72.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_72.LightEmission = 0.00
		v_72.LightInfluence = 0.00
		v_72.LockedToPart = true
		v_72.ZOffset = 1.03
		v_72.Drag = 2.00
		v_72.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_72.VelocityInheritance = 0.00
		v_72.Orientation = Enum.ParticleOrientation.FacingCamera
		v_72.EmissionDirection = Enum.NormalId.Top
		v_72.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_72.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_72.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 5.067, 0.000), NumberSequenceKeypoint.new(0.48, 7.333, 0.000), NumberSequenceKeypoint.new(1.00, 8.000, 0.000)})
		v_72.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.600, 0.000), NumberSequenceKeypoint.new(1.00, 0.600, 0.000)})
		v_72.Enabled = true
		v_72.Parent = v_44
	end
	do
		local v_73 = Instance.new("ParticleEmitter")
		v_73.Name = "Cursed Energy Disperse 8x8"
		refMap["73"] = v_73
		v_73.Texture = "rbxassetid://97051019398375"
		v_73.Rate = 2.00
		v_73.Speed = NumberRange.new(0.00, 0.00)
		v_73.Lifetime = NumberRange.new(0.40, 1.00)
		v_73.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_73.Rotation = NumberRange.new(-360.00, 360.00)
		v_73.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_73.LightEmission = 0.00
		v_73.LightInfluence = 0.00
		v_73.LockedToPart = true
		v_73.ZOffset = 1.05
		v_73.Drag = 2.00
		v_73.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_73.VelocityInheritance = 0.00
		v_73.Orientation = Enum.ParticleOrientation.FacingCamera
		v_73.EmissionDirection = Enum.NormalId.Top
		v_73.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8
		v_73.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_73.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.862, 0.000), NumberSequenceKeypoint.new(0.48, 4.143, 0.000), NumberSequenceKeypoint.new(1.00, 4.519, 0.000)})
		v_73.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_73.Enabled = true
		v_73.Parent = v_44
	end
	do
		local v_74 = Instance.new("ParticleEmitter")
		v_74.Name = "cursed energy spec"
		refMap["74"] = v_74
		v_74.Texture = "rbxassetid://85688545954016"
		v_74.Rate = 2.00
		v_74.Speed = NumberRange.new(10.00, 20.00)
		v_74.Lifetime = NumberRange.new(0.40, 1.00)
		v_74.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_74.Rotation = NumberRange.new(-360.00, 360.00)
		v_74.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_74.LightEmission = 0.00
		v_74.LightInfluence = 0.00
		v_74.LockedToPart = false
		v_74.ZOffset = 2.11
		v_74.Drag = 4.00
		v_74.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_74.VelocityInheritance = 0.00
		v_74.Orientation = Enum.ParticleOrientation.FacingCamera
		v_74.EmissionDirection = Enum.NormalId.Top
		v_74.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_74.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_74.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_74.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_74.Enabled = true
		v_74.Parent = v_44
	end
	do
		local v_75 = Instance.new("ParticleEmitter")
		v_75.Name = "Fire45"
		refMap["75"] = v_75
		v_75.Texture = "rbxassetid://16860419961"
		v_75.Rate = 3.00
		v_75.Speed = NumberRange.new(0.00, 0.00)
		v_75.Lifetime = NumberRange.new(0.70, 2.00)
		v_75.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_75.Rotation = NumberRange.new(-360.00, 360.00)
		v_75.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_75.LightEmission = 0.00
		v_75.LightInfluence = 0.00
		v_75.LockedToPart = true
		v_75.ZOffset = 2.03
		v_75.Drag = 2.00
		v_75.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_75.VelocityInheritance = 0.00
		v_75.Orientation = Enum.ParticleOrientation.FacingCamera
		v_75.EmissionDirection = Enum.NormalId.Top
		v_75.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_75.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_75.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 5.724, 0.000), NumberSequenceKeypoint.new(0.48, 8.285, 0.000), NumberSequenceKeypoint.new(1.00, 9.038, 0.000)})
		v_75.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_75.Enabled = true
		v_75.Parent = v_44
	end
	do
		local v_76 = Instance.new("ParticleEmitter")
		v_76.Name = "cat spec 8"
		refMap["76"] = v_76
		v_76.Texture = "rbxassetid://101658731548844"
		v_76.Rate = 2.00
		v_76.Speed = NumberRange.new(10.00, 20.00)
		v_76.Lifetime = NumberRange.new(0.40, 1.00)
		v_76.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_76.Rotation = NumberRange.new(-360.00, 360.00)
		v_76.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_76.LightEmission = 0.00
		v_76.LightInfluence = 0.00
		v_76.LockedToPart = false
		v_76.ZOffset = 2.02
		v_76.Drag = 4.00
		v_76.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_76.VelocityInheritance = 0.00
		v_76.Orientation = Enum.ParticleOrientation.FacingCamera
		v_76.EmissionDirection = Enum.NormalId.Top
		v_76.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_76.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_76.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_76.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_76.Enabled = true
		v_76.Parent = v_44
	end
	do
		local v_77 = Instance.new("ParticleEmitter")
		v_77.Name = "Strange VFX"
		refMap["77"] = v_77
		v_77.Texture = "rbxassetid://18369800560"
		v_77.Rate = 3.00
		v_77.Speed = NumberRange.new(0.00, 0.00)
		v_77.Lifetime = NumberRange.new(0.40, 1.00)
		v_77.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_77.Rotation = NumberRange.new(-360.00, 360.00)
		v_77.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_77.LightEmission = 0.00
		v_77.LightInfluence = 0.00
		v_77.LockedToPart = true
		v_77.ZOffset = 1.01
		v_77.Drag = 2.00
		v_77.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_77.VelocityInheritance = 0.00
		v_77.Orientation = Enum.ParticleOrientation.FacingCamera
		v_77.EmissionDirection = Enum.NormalId.Top
		v_77.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_77.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_77.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.533, 0.000), NumberSequenceKeypoint.new(0.48, 3.667, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_77.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_77.Enabled = true
		v_77.Parent = v_44
	end
	do
		local v_78 = Instance.new("ParticleEmitter")
		v_78.Name = "Cat 3"
		refMap["78"] = v_78
		v_78.Texture = "rbxassetid://77336442156503"
		v_78.Rate = 2.00
		v_78.Speed = NumberRange.new(0.00, 0.00)
		v_78.Lifetime = NumberRange.new(0.40, 1.00)
		v_78.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_78.Rotation = NumberRange.new(-360.00, 360.00)
		v_78.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_78.LightEmission = 0.00
		v_78.LightInfluence = 0.00
		v_78.LockedToPart = true
		v_78.ZOffset = 2.01
		v_78.Drag = 2.00
		v_78.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_78.VelocityInheritance = 0.00
		v_78.Orientation = Enum.ParticleOrientation.FacingCamera
		v_78.EmissionDirection = Enum.NormalId.Top
		v_78.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_78.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_78.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.533, 0.000), NumberSequenceKeypoint.new(0.48, 3.667, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_78.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.263, 0.000), NumberSequenceKeypoint.new(0.85, 0.557, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_78.Enabled = true
		v_78.Parent = v_44
	end
	do
		local v_79 = Instance.new("ParticleEmitter")
		v_79.Name = "grainy shockwave 2"
		refMap["79"] = v_79
		v_79.Texture = "rbxassetid://16509144751"
		v_79.Rate = 2.00
		v_79.Speed = NumberRange.new(0.00, 0.00)
		v_79.Lifetime = NumberRange.new(0.40, 1.00)
		v_79.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_79.Rotation = NumberRange.new(-360.00, 360.00)
		v_79.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_79.LightEmission = 0.00
		v_79.LightInfluence = 0.00
		v_79.LockedToPart = true
		v_79.ZOffset = 2.00
		v_79.Drag = 2.00
		v_79.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_79.VelocityInheritance = 0.00
		v_79.Orientation = Enum.ParticleOrientation.FacingCamera
		v_79.EmissionDirection = Enum.NormalId.Top
		v_79.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_79.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.533, 0.000), NumberSequenceKeypoint.new(0.48, 3.667, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_79.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.63, 0.343, 0.000), NumberSequenceKeypoint.new(0.89, 0.643, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_79.Enabled = true
		v_79.Parent = v_44
	end
	do
		local v_80 = Instance.new("ParticleEmitter")
		v_80.Name = "cursed energy3421"
		refMap["80"] = v_80
		v_80.Texture = "rbxassetid://17006172452"
		v_80.Rate = 2.00
		v_80.Speed = NumberRange.new(0.00, 0.00)
		v_80.Lifetime = NumberRange.new(0.40, 1.00)
		v_80.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_80.Rotation = NumberRange.new(-360.00, 360.00)
		v_80.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_80.LightEmission = 0.00
		v_80.LightInfluence = 0.00
		v_80.LockedToPart = true
		v_80.ZOffset = 1.01
		v_80.Drag = 2.00
		v_80.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_80.VelocityInheritance = 0.00
		v_80.Orientation = Enum.ParticleOrientation.FacingCamera
		v_80.EmissionDirection = Enum.NormalId.Top
		v_80.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_80.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_80.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.862, 0.000), NumberSequenceKeypoint.new(0.48, 4.143, 0.000), NumberSequenceKeypoint.new(1.00, 4.519, 0.000)})
		v_80.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.317, 0.000), NumberSequenceKeypoint.new(0.86, 0.683, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_80.Enabled = true
		v_80.Parent = v_44
	end
	end
	do
		local v_81 = Instance.new("Part")
		v_81.Name = "Part"
		refMap["81"] = v_81
		v_81.Anchored = false
		v_81.CanCollide = false
		v_81.CanTouch = false
		v_81.CanQuery = false
		v_81.Massless = true
		v_81.CastShadow = false
		v_81.Transparency = 1.00
		v_81.Size = Vector3.new(8.000, 1.000, 7.000)
		v_81.CFrame = CFrame.new(-140.500, 19.531, -60.000, 0.000, 0.000, -1.000, 0.000, 1.000, 0.000, 1.000, 0.000, 0.000)
		v_81.Color = Color3.fromRGB(163, 162, 165)
		v_81.Parent = v_2
	do
		local v_82 = Instance.new("ParticleEmitter")
		v_82.Name = "fire realistic"
		refMap["82"] = v_82
		v_82.Texture = "rbxassetid://115973544312399"
		v_82.Rate = 1.00
		v_82.Speed = NumberRange.new(10.00, 20.00)
		v_82.Lifetime = NumberRange.new(1.00, 2.00)
		v_82.RotSpeed = NumberRange.new(0.00, 0.00)
		v_82.Rotation = NumberRange.new(0.00, 0.00)
		v_82.SpreadAngle = Vector2.new(0.0, 0.0)
		v_82.LightEmission = 0.00
		v_82.LightInfluence = 0.00
		v_82.LockedToPart = false
		v_82.ZOffset = 2.03
		v_82.Drag = 4.00
		v_82.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_82.VelocityInheritance = 0.00
		v_82.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
		v_82.EmissionDirection = Enum.NormalId.Top
		v_82.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_82.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.430, 0.000), NumberSequenceKeypoint.new(0.42, 3.670, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_82.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.427, 0.000), NumberSequenceKeypoint.new(0.39, 0.553, 0.000), NumberSequenceKeypoint.new(0.75, 0.720, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_82.Enabled = true
		v_82.Parent = v_81
	end
	do
		local v_83 = Instance.new("ParticleEmitter")
		v_83.Name = "cursed energy spec"
		refMap["83"] = v_83
		v_83.Texture = "rbxassetid://85688545954016"
		v_83.Rate = 2.00
		v_83.Speed = NumberRange.new(10.00, 20.00)
		v_83.Lifetime = NumberRange.new(0.40, 1.00)
		v_83.RotSpeed = NumberRange.new(0.00, 0.00)
		v_83.Rotation = NumberRange.new(90.00, 90.00)
		v_83.SpreadAngle = Vector2.new(-30.0, 30.0)
		v_83.LightEmission = 0.00
		v_83.LightInfluence = 0.00
		v_83.LockedToPart = false
		v_83.ZOffset = 2.04
		v_83.Drag = 4.00
		v_83.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_83.VelocityInheritance = 0.00
		v_83.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_83.EmissionDirection = Enum.NormalId.Top
		v_83.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_83.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_83.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_83.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_83.Enabled = true
		v_83.Parent = v_81
	end
	do
		local v_84 = Instance.new("ParticleEmitter")
		v_84.Name = "Sideways Spec 17"
		refMap["84"] = v_84
		v_84.Texture = "rbxassetid://8599882518"
		v_84.Rate = 1.00
		v_84.Speed = NumberRange.new(10.00, 20.00)
		v_84.Lifetime = NumberRange.new(0.40, 1.00)
		v_84.RotSpeed = NumberRange.new(0.00, 0.00)
		v_84.Rotation = NumberRange.new(90.00, 90.00)
		v_84.SpreadAngle = Vector2.new(-50.0, 50.0)
		v_84.LightEmission = 0.00
		v_84.LightInfluence = 0.00
		v_84.LockedToPart = false
		v_84.ZOffset = 3.10
		v_84.Drag = 4.00
		v_84.Acceleration = Vector3.new(0.000, -20.000, 0.000)
		v_84.VelocityInheritance = 0.00
		v_84.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_84.EmissionDirection = Enum.NormalId.Top
		v_84.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_84.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_84.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_84.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_84.Enabled = true
		v_84.Parent = v_81
	end
	do
		local v_85 = Instance.new("ParticleEmitter")
		v_85.Name = "Sideways Spec 12"
		refMap["85"] = v_85
		v_85.Texture = "rbxassetid://1269254614"
		v_85.Rate = 1.00
		v_85.Speed = NumberRange.new(10.00, 20.00)
		v_85.Lifetime = NumberRange.new(0.40, 1.00)
		v_85.RotSpeed = NumberRange.new(0.00, 0.00)
		v_85.Rotation = NumberRange.new(90.00, 90.00)
		v_85.SpreadAngle = Vector2.new(-50.0, 50.0)
		v_85.LightEmission = 0.00
		v_85.LightInfluence = 0.00
		v_85.LockedToPart = false
		v_85.ZOffset = 3.03
		v_85.Drag = 4.00
		v_85.Acceleration = Vector3.new(0.000, -20.000, 0.000)
		v_85.VelocityInheritance = 0.00
		v_85.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_85.EmissionDirection = Enum.NormalId.Top
		v_85.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_85.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_85.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_85.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_85.Enabled = true
		v_85.Parent = v_81
	end
	do
		local v_86 = Instance.new("ParticleEmitter")
		v_86.Name = "Sideways Spec 15"
		refMap["86"] = v_86
		v_86.Texture = "rbxassetid://6763809313"
		v_86.Rate = 1.00
		v_86.Speed = NumberRange.new(10.00, 20.00)
		v_86.Lifetime = NumberRange.new(0.40, 1.00)
		v_86.RotSpeed = NumberRange.new(0.00, 0.00)
		v_86.Rotation = NumberRange.new(90.00, 90.00)
		v_86.SpreadAngle = Vector2.new(-50.0, 50.0)
		v_86.LightEmission = 0.00
		v_86.LightInfluence = 0.00
		v_86.LockedToPart = false
		v_86.ZOffset = 3.08
		v_86.Drag = 4.00
		v_86.Acceleration = Vector3.new(0.000, -20.000, 0.000)
		v_86.VelocityInheritance = 0.00
		v_86.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_86.EmissionDirection = Enum.NormalId.Top
		v_86.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_86.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_86.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_86.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_86.Enabled = true
		v_86.Parent = v_81
	end
	do
		local v_87 = Instance.new("ParticleEmitter")
		v_87.Name = "Sideways Spec 15"
		refMap["87"] = v_87
		v_87.Texture = "rbxassetid://6763809313"
		v_87.Rate = 2.00
		v_87.Speed = NumberRange.new(10.00, 20.00)
		v_87.Lifetime = NumberRange.new(0.40, 1.00)
		v_87.RotSpeed = NumberRange.new(0.00, 0.00)
		v_87.Rotation = NumberRange.new(90.00, 90.00)
		v_87.SpreadAngle = Vector2.new(-30.0, 30.0)
		v_87.LightEmission = 0.00
		v_87.LightInfluence = 0.00
		v_87.LockedToPart = false
		v_87.ZOffset = 2.02
		v_87.Drag = 4.00
		v_87.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_87.VelocityInheritance = 0.00
		v_87.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_87.EmissionDirection = Enum.NormalId.Top
		v_87.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_87.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_87.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_87.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_87.Enabled = true
		v_87.Parent = v_81
	end
	do
		local v_88 = Instance.new("ParticleEmitter")
		v_88.Name = "Coloured Diagonal Smoke"
		refMap["88"] = v_88
		v_88.Texture = "rbxassetid://13724252630"
		v_88.Rate = 1.00
		v_88.Speed = NumberRange.new(10.00, 20.00)
		v_88.Lifetime = NumberRange.new(1.00, 2.00)
		v_88.RotSpeed = NumberRange.new(0.00, 0.00)
		v_88.Rotation = NumberRange.new(15.00, 15.00)
		v_88.SpreadAngle = Vector2.new(0.0, 0.0)
		v_88.LightEmission = 0.00
		v_88.LightInfluence = 0.00
		v_88.LockedToPart = false
		v_88.ZOffset = 2.03
		v_88.Drag = 4.00
		v_88.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_88.VelocityInheritance = 0.00
		v_88.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
		v_88.EmissionDirection = Enum.NormalId.Top
		v_88.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_88.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_88.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.430, 0.000), NumberSequenceKeypoint.new(0.42, 3.670, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_88.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.427, 0.000), NumberSequenceKeypoint.new(0.39, 0.553, 0.000), NumberSequenceKeypoint.new(0.75, 0.720, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_88.Enabled = true
		v_88.Parent = v_81
	end
	do
		local v_89 = Instance.new("ParticleEmitter")
		v_89.Name = "Sideways Spec 15"
		refMap["89"] = v_89
		v_89.Texture = "rbxassetid://6763809313"
		v_89.Rate = 1.00
		v_89.Speed = NumberRange.new(10.00, 20.00)
		v_89.Lifetime = NumberRange.new(0.40, 1.00)
		v_89.RotSpeed = NumberRange.new(0.00, 0.00)
		v_89.Rotation = NumberRange.new(90.00, 90.00)
		v_89.SpreadAngle = Vector2.new(-50.0, 50.0)
		v_89.LightEmission = 0.00
		v_89.LightInfluence = 0.00
		v_89.LockedToPart = false
		v_89.ZOffset = 3.09
		v_89.Drag = 4.00
		v_89.Acceleration = Vector3.new(0.000, -20.000, 0.000)
		v_89.VelocityInheritance = 0.00
		v_89.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_89.EmissionDirection = Enum.NormalId.Top
		v_89.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_89.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_89.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_89.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_89.Enabled = true
		v_89.Parent = v_81
	end
	do
		local v_90 = Instance.new("ParticleEmitter")
		v_90.Name = "Realistic Smoke 10"
		refMap["90"] = v_90
		v_90.Texture = "rbxassetid://82219367698334"
		v_90.Rate = 1.00
		v_90.Speed = NumberRange.new(10.00, 20.00)
		v_90.Lifetime = NumberRange.new(1.00, 2.00)
		v_90.RotSpeed = NumberRange.new(0.00, 0.00)
		v_90.Rotation = NumberRange.new(0.00, 0.00)
		v_90.SpreadAngle = Vector2.new(0.0, 0.0)
		v_90.LightEmission = 0.00
		v_90.LightInfluence = 0.00
		v_90.LockedToPart = false
		v_90.ZOffset = 2.06
		v_90.Drag = 4.00
		v_90.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_90.VelocityInheritance = 0.00
		v_90.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
		v_90.EmissionDirection = Enum.NormalId.Top
		v_90.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_90.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_90.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.430, 0.000), NumberSequenceKeypoint.new(0.42, 3.670, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_90.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.427, 0.000), NumberSequenceKeypoint.new(0.39, 0.553, 0.000), NumberSequenceKeypoint.new(0.75, 0.720, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_90.Enabled = true
		v_90.Parent = v_81
	end
	do
		local v_91 = Instance.new("ParticleEmitter")
		v_91.Name = "Sideways Spec 102"
		refMap["91"] = v_91
		v_91.Texture = "rbxassetid://80742887810818"
		v_91.Rate = 1.00
		v_91.Speed = NumberRange.new(10.00, 20.00)
		v_91.Lifetime = NumberRange.new(0.40, 1.00)
		v_91.RotSpeed = NumberRange.new(0.00, 0.00)
		v_91.Rotation = NumberRange.new(90.00, 90.00)
		v_91.SpreadAngle = Vector2.new(-50.0, 50.0)
		v_91.LightEmission = 0.00
		v_91.LightInfluence = 0.00
		v_91.LockedToPart = false
		v_91.ZOffset = 3.03
		v_91.Drag = 4.00
		v_91.Acceleration = Vector3.new(0.000, -20.000, 0.000)
		v_91.VelocityInheritance = 0.00
		v_91.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_91.EmissionDirection = Enum.NormalId.Top
		v_91.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_91.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_91.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_91.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_91.Enabled = true
		v_91.Parent = v_81
	end
	do
		local v_92 = Instance.new("ParticleEmitter")
		v_92.Name = "Sideways Spec 17"
		refMap["92"] = v_92
		v_92.Texture = "rbxassetid://8599882518"
		v_92.Rate = 2.00
		v_92.Speed = NumberRange.new(10.00, 20.00)
		v_92.Lifetime = NumberRange.new(0.40, 1.00)
		v_92.RotSpeed = NumberRange.new(0.00, 0.00)
		v_92.Rotation = NumberRange.new(90.00, 90.00)
		v_92.SpreadAngle = Vector2.new(-30.0, 30.0)
		v_92.LightEmission = 0.00
		v_92.LightInfluence = 0.00
		v_92.LockedToPart = false
		v_92.ZOffset = 2.05
		v_92.Drag = 4.00
		v_92.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_92.VelocityInheritance = 0.00
		v_92.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_92.EmissionDirection = Enum.NormalId.Top
		v_92.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_92.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_92.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_92.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_92.Enabled = true
		v_92.Parent = v_81
	end
	do
		local v_93 = Instance.new("ParticleEmitter")
		v_93.Name = "cursed energy spec"
		refMap["93"] = v_93
		v_93.Texture = "rbxassetid://85688545954016"
		v_93.Rate = 2.00
		v_93.Speed = NumberRange.new(10.00, 20.00)
		v_93.Lifetime = NumberRange.new(0.40, 1.00)
		v_93.RotSpeed = NumberRange.new(0.00, 0.00)
		v_93.Rotation = NumberRange.new(90.00, 90.00)
		v_93.SpreadAngle = Vector2.new(-30.0, 30.0)
		v_93.LightEmission = 0.00
		v_93.LightInfluence = 0.00
		v_93.LockedToPart = false
		v_93.ZOffset = 2.04
		v_93.Drag = 4.00
		v_93.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_93.VelocityInheritance = 0.00
		v_93.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_93.EmissionDirection = Enum.NormalId.Top
		v_93.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_93.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_93.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_93.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_93.Enabled = true
		v_93.Parent = v_81
	end
	do
		local v_94 = Instance.new("ParticleEmitter")
		v_94.Name = "Sideways Spec 102"
		refMap["94"] = v_94
		v_94.Texture = "rbxassetid://80742887810818"
		v_94.Rate = 1.00
		v_94.Speed = NumberRange.new(10.00, 20.00)
		v_94.Lifetime = NumberRange.new(0.40, 1.00)
		v_94.RotSpeed = NumberRange.new(0.00, 0.00)
		v_94.Rotation = NumberRange.new(90.00, 90.00)
		v_94.SpreadAngle = Vector2.new(-50.0, 50.0)
		v_94.LightEmission = 0.00
		v_94.LightInfluence = 0.00
		v_94.LockedToPart = false
		v_94.ZOffset = 3.00
		v_94.Drag = 4.00
		v_94.Acceleration = Vector3.new(0.000, -20.000, 0.000)
		v_94.VelocityInheritance = 0.00
		v_94.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_94.EmissionDirection = Enum.NormalId.Top
		v_94.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_94.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3490, 0.3588)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3490, 0.3588))})
		v_94.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_94.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_94.Enabled = true
		v_94.Parent = v_81
	end
	do
		local v_95 = Instance.new("WeldConstraint")
		v_95.Name = "Part_Weld"
		refMap["95"] = v_95
		v_95.Parent = v_81
	end
	end
	end
	end

	for _, pending in ipairs(pendingRefs) do
		local target = refMap[pending.ref]
		if target then
			pending.obj[pending.prop] = target
		end
	end
end

local function buildAura12(auraFolder: Folder)
	local refMap = {}
	local pendingRefs = {}

	do
		local v_0 = Instance.new("Model")
		v_0.Name = "Aura12"
		refMap["0"] = v_0
		v_0:SetAttribute("CosmeticType", "Aura")
		v_0:SetAttribute("CosmeticId", "Aura12")
		v_0:SetAttribute("TargetPart", "HumanoidRootPart")
		v_0:SetAttribute("SupportsR6", true)
		v_0:SetAttribute("SupportsR15", true)
		v_0.Parent = auraFolder
	do
		local v_1 = Instance.new("CFrameValue")
		v_1.Name = "LocalOffset"
		refMap["2"] = v_1
		v_1.Value = CFrame.new(0.000, -0.500, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_1.Parent = v_0
	end
	do
		local v_2 = Instance.new("Part")
		v_2.Name = "EffectHolder"
		refMap["1"] = v_2
		v_2.Anchored = false
		v_2.CanCollide = false
		v_2.CanTouch = false
		v_2.CanQuery = false
		v_2.Massless = true
		v_2.CastShadow = false
		v_2.Transparency = 1.00
		v_2.Size = Vector3.new(4.000, 6.000, 3.000)
		v_2.CFrame = CFrame.new(-140.500, 22.000, -44.000, 0.000, 0.000, -1.000, 0.000, 1.000, 0.000, 1.000, 0.000, 0.000)
		v_2.Color = Color3.fromRGB(163, 162, 165)
		v_2.Parent = v_0
	do
		local v_3 = Instance.new("Attachment")
		v_3.Name = "Attachment"
		refMap["3"] = v_3
		v_3.CFrame = CFrame.new(0.000, 1.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_3.Parent = v_2
	do
		local v_4 = Instance.new("ParticleEmitter")
		v_4.Name = "Iso cursed"
		refMap["4"] = v_4
		v_4.Texture = "rbxassetid://102330699321283"
		v_4.Rate = 1.00
		v_4.Speed = NumberRange.new(0.00, 0.00)
		v_4.Lifetime = NumberRange.new(2.00, 2.00)
		v_4.RotSpeed = NumberRange.new(0.00, 0.00)
		v_4.Rotation = NumberRange.new(0.00, 0.00)
		v_4.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_4.LightEmission = 0.00
		v_4.LightInfluence = 0.00
		v_4.LockedToPart = true
		v_4.ZOffset = 0.02
		v_4.Drag = 2.00
		v_4.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_4.VelocityInheritance = 0.00
		v_4.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
		v_4.EmissionDirection = Enum.NormalId.Top
		v_4.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_4.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 5.484, 0.000), NumberSequenceKeypoint.new(0.48, 7.938, 0.000), NumberSequenceKeypoint.new(1.00, 8.659, 0.000)})
		v_4.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.360, 0.000), NumberSequenceKeypoint.new(0.63, 0.567, 0.000), NumberSequenceKeypoint.new(0.82, 0.740, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_4.Enabled = true
		v_4.Parent = v_3
	end
	do
		local v_5 = Instance.new("ParticleEmitter")
		v_5.Name = "cursed energy min"
		refMap["5"] = v_5
		v_5.Texture = "rbxassetid://125843391083656"
		v_5.Rate = 1.00
		v_5.Speed = NumberRange.new(0.00, 0.00)
		v_5.Lifetime = NumberRange.new(2.00, 2.00)
		v_5.RotSpeed = NumberRange.new(0.00, 0.00)
		v_5.Rotation = NumberRange.new(0.00, 0.00)
		v_5.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_5.LightEmission = 0.00
		v_5.LightInfluence = 0.00
		v_5.LockedToPart = true
		v_5.ZOffset = 0.02
		v_5.Drag = 2.00
		v_5.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_5.VelocityInheritance = 0.00
		v_5.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
		v_5.EmissionDirection = Enum.NormalId.Top
		v_5.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_5.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 4.439, 0.000), NumberSequenceKeypoint.new(0.48, 6.424, 0.000), NumberSequenceKeypoint.new(1.00, 7.008, 0.000)})
		v_5.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.360, 0.000), NumberSequenceKeypoint.new(0.63, 0.567, 0.000), NumberSequenceKeypoint.new(0.82, 0.740, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_5.Enabled = true
		v_5.Parent = v_3
	end
	do
		local v_6 = Instance.new("ParticleEmitter")
		v_6.Name = "cursed energy 3"
		refMap["6"] = v_6
		v_6.Texture = "rbxassetid://17006174840"
		v_6.Rate = 1.00
		v_6.Speed = NumberRange.new(0.00, 0.00)
		v_6.Lifetime = NumberRange.new(2.00, 2.00)
		v_6.RotSpeed = NumberRange.new(0.00, 0.00)
		v_6.Rotation = NumberRange.new(0.00, 0.00)
		v_6.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_6.LightEmission = 0.00
		v_6.LightInfluence = 0.00
		v_6.LockedToPart = true
		v_6.ZOffset = 0.01
		v_6.Drag = 2.00
		v_6.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_6.VelocityInheritance = 0.00
		v_6.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
		v_6.EmissionDirection = Enum.NormalId.Top
		v_6.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_6.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 5.484, 0.000), NumberSequenceKeypoint.new(0.48, 7.938, 0.000), NumberSequenceKeypoint.new(1.00, 8.659, 0.000)})
		v_6.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.360, 0.000), NumberSequenceKeypoint.new(0.63, 0.567, 0.000), NumberSequenceKeypoint.new(0.82, 0.740, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_6.Enabled = true
		v_6.Parent = v_3
	end
	end
	do
		local v_7 = Instance.new("Attachment")
		v_7.Name = "Attachment"
		refMap["7"] = v_7
		v_7.CFrame = CFrame.new(0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_7.Parent = v_2
	do
		local v_8 = Instance.new("ParticleEmitter")
		v_8.Name = "cat spec 8"
		refMap["8"] = v_8
		v_8.Texture = "rbxassetid://101658731548844"
		v_8.Rate = 2.00
		v_8.Speed = NumberRange.new(12.93, 25.87)
		v_8.Lifetime = NumberRange.new(0.40, 1.00)
		v_8.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_8.Rotation = NumberRange.new(-360.00, 360.00)
		v_8.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_8.LightEmission = 0.00
		v_8.LightInfluence = 0.00
		v_8.LockedToPart = false
		v_8.ZOffset = 2.05
		v_8.Drag = 4.00
		v_8.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_8.VelocityInheritance = 0.00
		v_8.Orientation = Enum.ParticleOrientation.FacingCamera
		v_8.EmissionDirection = Enum.NormalId.Top
		v_8.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_8.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_8.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.996, 0.000), NumberSequenceKeypoint.new(0.73, 0.621, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_8.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_8.Enabled = true
		v_8.Parent = v_7
	end
	do
		local v_9 = Instance.new("ParticleEmitter")
		v_9.Name = "Slash22"
		refMap["9"] = v_9
		v_9.Texture = "rbxassetid://121148164489745"
		v_9.Rate = 2.00
		v_9.Speed = NumberRange.new(0.00, 0.00)
		v_9.Lifetime = NumberRange.new(0.40, 1.00)
		v_9.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_9.Rotation = NumberRange.new(-360.00, 360.00)
		v_9.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_9.LightEmission = 0.00
		v_9.LightInfluence = 0.00
		v_9.LockedToPart = true
		v_9.ZOffset = 1.04
		v_9.Drag = 2.00
		v_9.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_9.VelocityInheritance = 0.00
		v_9.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_9.EmissionDirection = Enum.NormalId.Top
		v_9.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_9.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_9.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 3.410, 0.000), NumberSequenceKeypoint.new(0.48, 4.936, 0.000), NumberSequenceKeypoint.new(1.00, 5.385, 0.000)})
		v_9.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_9.Enabled = true
		v_9.Parent = v_7
	end
	do
		local v_10 = Instance.new("ParticleEmitter")
		v_10.Name = "Bright Horizontal Star Glare 2"
		refMap["10"] = v_10
		v_10.Texture = "rbxassetid://131904221700198"
		v_10.Rate = 4.00
		v_10.Speed = NumberRange.new(0.00, 0.00)
		v_10.Lifetime = NumberRange.new(0.40, 1.00)
		v_10.RotSpeed = NumberRange.new(0.00, 0.00)
		v_10.Rotation = NumberRange.new(0.00, 0.00)
		v_10.SpreadAngle = Vector2.new(0.0, 0.0)
		v_10.LightEmission = 0.00
		v_10.LightInfluence = 0.00
		v_10.LockedToPart = true
		v_10.ZOffset = 1.00
		v_10.Drag = 2.00
		v_10.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_10.VelocityInheritance = 0.00
		v_10.Orientation = Enum.ParticleOrientation.FacingCamera
		v_10.EmissionDirection = Enum.NormalId.Top
		v_10.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_10.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5922, 0.2431, 0.8549)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5922, 0.2431, 0.8549))})
		v_10.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.15, 3.267, 0.000), NumberSequenceKeypoint.new(0.39, 4.317, 0.000), NumberSequenceKeypoint.new(1.00, 5.000, 0.000)})
		v_10.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.263, 0.000), NumberSequenceKeypoint.new(0.85, 0.557, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_10.Enabled = true
		v_10.Parent = v_7
	end
	do
		local v_11 = Instance.new("ParticleEmitter")
		v_11.Name = "dis dark circle"
		refMap["11"] = v_11
		v_11.Texture = "rbxassetid://83617429710480"
		v_11.Rate = 2.00
		v_11.Speed = NumberRange.new(0.00, 0.00)
		v_11.Lifetime = NumberRange.new(0.40, 1.00)
		v_11.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_11.Rotation = NumberRange.new(-360.00, 360.00)
		v_11.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_11.LightEmission = 0.00
		v_11.LightInfluence = 0.00
		v_11.LockedToPart = true
		v_11.ZOffset = 2.05
		v_11.Drag = 2.00
		v_11.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_11.VelocityInheritance = 0.00
		v_11.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_11.EmissionDirection = Enum.NormalId.Top
		v_11.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_11.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.533, 0.000), NumberSequenceKeypoint.new(0.48, 3.667, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_11.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_11.Enabled = true
		v_11.Parent = v_7
	end
	do
		local v_12 = Instance.new("ParticleEmitter")
		v_12.Name = "Strange VFX"
		refMap["12"] = v_12
		v_12.Texture = "rbxassetid://18369800560"
		v_12.Rate = 3.00
		v_12.Speed = NumberRange.new(0.00, 0.00)
		v_12.Lifetime = NumberRange.new(0.40, 1.00)
		v_12.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_12.Rotation = NumberRange.new(-360.00, 360.00)
		v_12.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_12.LightEmission = 0.00
		v_12.LightInfluence = 0.00
		v_12.LockedToPart = true
		v_12.ZOffset = 1.01
		v_12.Drag = 2.00
		v_12.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_12.VelocityInheritance = 0.00
		v_12.Orientation = Enum.ParticleOrientation.FacingCamera
		v_12.EmissionDirection = Enum.NormalId.Top
		v_12.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_12.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_12.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.533, 0.000), NumberSequenceKeypoint.new(0.48, 3.667, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_12.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_12.Enabled = true
		v_12.Parent = v_7
	end
	do
		local v_13 = Instance.new("ParticleEmitter")
		v_13.Name = "Triangle Gradient Lens"
		refMap["13"] = v_13
		v_13.Texture = "rbxassetid://108684954560019"
		v_13.Rate = 4.00
		v_13.Speed = NumberRange.new(0.00, 0.00)
		v_13.Lifetime = NumberRange.new(0.40, 1.00)
		v_13.RotSpeed = NumberRange.new(30.00, 50.00)
		v_13.Rotation = NumberRange.new(0.00, 0.00)
		v_13.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_13.LightEmission = 0.00
		v_13.LightInfluence = 0.00
		v_13.LockedToPart = true
		v_13.ZOffset = 1.00
		v_13.Drag = 2.00
		v_13.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_13.VelocityInheritance = 0.00
		v_13.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_13.EmissionDirection = Enum.NormalId.Top
		v_13.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_13.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5922, 0.2431, 0.8549)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5922, 0.2431, 0.8549))})
		v_13.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.15, 2.504, 0.715), NumberSequenceKeypoint.new(0.42, 3.688, 0.779), NumberSequenceKeypoint.new(1.00, 4.043, 0.909)})
		v_13.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.263, 0.000), NumberSequenceKeypoint.new(0.85, 0.557, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_13.Enabled = true
		v_13.Parent = v_7
	end
	do
		local v_14 = Instance.new("ParticleEmitter")
		v_14.Name = "Cat 3"
		refMap["14"] = v_14
		v_14.Texture = "rbxassetid://77336442156503"
		v_14.Rate = 2.00
		v_14.Speed = NumberRange.new(0.00, 0.00)
		v_14.Lifetime = NumberRange.new(0.40, 1.00)
		v_14.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_14.Rotation = NumberRange.new(-360.00, 360.00)
		v_14.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_14.LightEmission = 0.00
		v_14.LightInfluence = 0.00
		v_14.LockedToPart = true
		v_14.ZOffset = 2.01
		v_14.Drag = 2.00
		v_14.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_14.VelocityInheritance = 0.00
		v_14.Orientation = Enum.ParticleOrientation.FacingCamera
		v_14.EmissionDirection = Enum.NormalId.Top
		v_14.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_14.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_14.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.533, 0.000), NumberSequenceKeypoint.new(0.48, 3.667, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_14.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.263, 0.000), NumberSequenceKeypoint.new(0.85, 0.557, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_14.Enabled = true
		v_14.Parent = v_7
	end
	do
		local v_15 = Instance.new("ParticleEmitter")
		v_15.Name = "cursed energy spec"
		refMap["15"] = v_15
		v_15.Texture = "rbxassetid://85688545954016"
		v_15.Rate = 2.00
		v_15.Speed = NumberRange.new(10.00, 20.00)
		v_15.Lifetime = NumberRange.new(0.40, 1.00)
		v_15.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_15.Rotation = NumberRange.new(-360.00, 360.00)
		v_15.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_15.LightEmission = 0.00
		v_15.LightInfluence = 0.00
		v_15.LockedToPart = false
		v_15.ZOffset = 2.11
		v_15.Drag = 4.00
		v_15.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_15.VelocityInheritance = 0.00
		v_15.Orientation = Enum.ParticleOrientation.FacingCamera
		v_15.EmissionDirection = Enum.NormalId.Top
		v_15.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_15.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_15.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_15.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_15.Enabled = true
		v_15.Parent = v_7
	end
	do
		local v_16 = Instance.new("ParticleEmitter")
		v_16.Name = "Fire45"
		refMap["16"] = v_16
		v_16.Texture = "rbxassetid://16860419961"
		v_16.Rate = 3.00
		v_16.Speed = NumberRange.new(0.00, 0.00)
		v_16.Lifetime = NumberRange.new(0.40, 1.00)
		v_16.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_16.Rotation = NumberRange.new(-360.00, 360.00)
		v_16.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_16.LightEmission = 0.00
		v_16.LightInfluence = 0.00
		v_16.LockedToPart = true
		v_16.ZOffset = 2.03
		v_16.Drag = 2.00
		v_16.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_16.VelocityInheritance = 0.00
		v_16.Orientation = Enum.ParticleOrientation.FacingCamera
		v_16.EmissionDirection = Enum.NormalId.Top
		v_16.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_16.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_16.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 5.067, 0.000), NumberSequenceKeypoint.new(0.48, 7.333, 0.000), NumberSequenceKeypoint.new(1.00, 8.000, 0.000)})
		v_16.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_16.Enabled = true
		v_16.Parent = v_7
	end
	do
		local v_17 = Instance.new("PointLight")
		v_17.Name = "PointLight"
		refMap["17"] = v_17
		v_17.Brightness = 3.00
		v_17.Range = 8.00
		v_17.Shadows = false
		v_17.Color = Color3.new(0.5922, 0.2431, 0.8549)
		v_17.Enabled = true
		v_17.Parent = v_7
	end
	do
		local v_18 = Instance.new("ParticleEmitter")
		v_18.Name = "Fire54"
		refMap["18"] = v_18
		v_18.Texture = "rbxassetid://17006155963"
		v_18.Rate = 3.00
		v_18.Speed = NumberRange.new(0.00, 0.00)
		v_18.Lifetime = NumberRange.new(0.70, 2.00)
		v_18.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_18.Rotation = NumberRange.new(-360.00, 360.00)
		v_18.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_18.LightEmission = 0.00
		v_18.LightInfluence = 0.00
		v_18.LockedToPart = true
		v_18.ZOffset = 1.07
		v_18.Drag = 2.00
		v_18.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_18.VelocityInheritance = 0.00
		v_18.Orientation = Enum.ParticleOrientation.FacingCamera
		v_18.EmissionDirection = Enum.NormalId.Top
		v_18.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_18.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5922, 0.2431, 0.8549)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5922, 0.2431, 0.8549))})
		v_18.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.862, 0.000), NumberSequenceKeypoint.new(0.48, 4.143, 0.000), NumberSequenceKeypoint.new(1.00, 4.519, 0.000)})
		v_18.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_18.Enabled = true
		v_18.Parent = v_7
	end
	do
		local v_19 = Instance.new("ParticleEmitter")
		v_19.Name = "Fire54"
		refMap["19"] = v_19
		v_19.Texture = "rbxassetid://17006155963"
		v_19.Rate = 3.00
		v_19.Speed = NumberRange.new(0.00, 0.00)
		v_19.Lifetime = NumberRange.new(0.40, 1.00)
		v_19.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_19.Rotation = NumberRange.new(-360.00, 360.00)
		v_19.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_19.LightEmission = 0.00
		v_19.LightInfluence = 0.00
		v_19.LockedToPart = true
		v_19.ZOffset = 1.04
		v_19.Drag = 2.00
		v_19.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_19.VelocityInheritance = 0.00
		v_19.Orientation = Enum.ParticleOrientation.FacingCamera
		v_19.EmissionDirection = Enum.NormalId.Top
		v_19.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_19.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_19.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.533, 0.000), NumberSequenceKeypoint.new(0.48, 3.667, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_19.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_19.Enabled = true
		v_19.Parent = v_7
	end
	do
		local v_20 = Instance.new("ParticleEmitter")
		v_20.Name = "cursed energy spec"
		refMap["20"] = v_20
		v_20.Texture = "rbxassetid://85688545954016"
		v_20.Rate = 2.00
		v_20.Speed = NumberRange.new(10.00, 20.00)
		v_20.Lifetime = NumberRange.new(0.40, 1.00)
		v_20.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_20.Rotation = NumberRange.new(-360.00, 360.00)
		v_20.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_20.LightEmission = 0.00
		v_20.LightInfluence = 0.00
		v_20.LockedToPart = false
		v_20.ZOffset = 2.04
		v_20.Drag = 4.00
		v_20.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_20.VelocityInheritance = 0.00
		v_20.Orientation = Enum.ParticleOrientation.FacingCamera
		v_20.EmissionDirection = Enum.NormalId.Top
		v_20.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_20.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_20.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_20.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_20.Enabled = true
		v_20.Parent = v_7
	end
	do
		local v_21 = Instance.new("ParticleEmitter")
		v_21.Name = "cat spec 3"
		refMap["21"] = v_21
		v_21.Texture = "rbxassetid://136781994057492"
		v_21.Rate = 2.00
		v_21.Speed = NumberRange.new(10.00, 20.00)
		v_21.Lifetime = NumberRange.new(0.40, 1.00)
		v_21.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_21.Rotation = NumberRange.new(-360.00, 360.00)
		v_21.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_21.LightEmission = 0.00
		v_21.LightInfluence = 0.00
		v_21.LockedToPart = false
		v_21.ZOffset = 2.20
		v_21.Drag = 4.00
		v_21.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_21.VelocityInheritance = 0.00
		v_21.Orientation = Enum.ParticleOrientation.FacingCamera
		v_21.EmissionDirection = Enum.NormalId.Top
		v_21.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_21.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_21.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_21.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_21.Enabled = true
		v_21.Parent = v_7
	end
	do
		local v_22 = Instance.new("ParticleEmitter")
		v_22.Name = "Thin realistic shockwave"
		refMap["22"] = v_22
		v_22.Texture = "rbxassetid://12906276200"
		v_22.Rate = 2.00
		v_22.Speed = NumberRange.new(0.00, 0.00)
		v_22.Lifetime = NumberRange.new(0.40, 1.00)
		v_22.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_22.Rotation = NumberRange.new(-360.00, 360.00)
		v_22.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_22.LightEmission = 0.00
		v_22.LightInfluence = 0.00
		v_22.LockedToPart = true
		v_22.ZOffset = 2.07
		v_22.Drag = 2.00
		v_22.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_22.VelocityInheritance = 0.00
		v_22.Orientation = Enum.ParticleOrientation.FacingCamera
		v_22.EmissionDirection = Enum.NormalId.Top
		v_22.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_22.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_22.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 3.751, 0.000), NumberSequenceKeypoint.new(0.48, 5.429, 0.000), NumberSequenceKeypoint.new(1.00, 5.923, 0.000)})
		v_22.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.63, 0.343, 0.000), NumberSequenceKeypoint.new(0.89, 0.643, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_22.Enabled = true
		v_22.Parent = v_7
	end
	do
		local v_23 = Instance.new("ParticleEmitter")
		v_23.Name = "windfs"
		refMap["23"] = v_23
		v_23.Texture = "rbxassetid://135128020878697"
		v_23.Rate = 2.00
		v_23.Speed = NumberRange.new(0.00, 0.00)
		v_23.Lifetime = NumberRange.new(1.00, 1.50)
		v_23.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_23.Rotation = NumberRange.new(-360.00, 360.00)
		v_23.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_23.LightEmission = 0.00
		v_23.LightInfluence = 0.00
		v_23.LockedToPart = true
		v_23.ZOffset = 2.09
		v_23.Drag = 2.00
		v_23.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_23.VelocityInheritance = 0.00
		v_23.Orientation = Enum.ParticleOrientation.FacingCamera
		v_23.EmissionDirection = Enum.NormalId.Top
		v_23.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(0.22, Color3.new(0.1704, 0.0499, 0.2626)), ColorSequenceKeypoint.new(0.56, Color3.new(0.0000, 0.0000, 0.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0000, 0.0000, 0.0000))})
		v_23.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 3.532, 0.000), NumberSequenceKeypoint.new(0.48, 5.112, 0.000), NumberSequenceKeypoint.new(1.00, 5.577, 0.000)})
		v_23.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_23.Enabled = true
		v_23.Parent = v_7
	end
	do
		local v_24 = Instance.new("ParticleEmitter")
		v_24.Name = "Strange VFX"
		refMap["24"] = v_24
		v_24.Texture = "rbxassetid://18369800560"
		v_24.Rate = 3.00
		v_24.Speed = NumberRange.new(0.00, 0.00)
		v_24.Lifetime = NumberRange.new(0.70, 2.00)
		v_24.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_24.Rotation = NumberRange.new(-360.00, 360.00)
		v_24.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_24.LightEmission = 0.00
		v_24.LightInfluence = 0.00
		v_24.LockedToPart = true
		v_24.ZOffset = 1.02
		v_24.Drag = 2.00
		v_24.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_24.VelocityInheritance = 0.00
		v_24.Orientation = Enum.ParticleOrientation.FacingCamera
		v_24.EmissionDirection = Enum.NormalId.Top
		v_24.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_24.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_24.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.862, 0.000), NumberSequenceKeypoint.new(0.48, 4.143, 0.000), NumberSequenceKeypoint.new(1.00, 4.519, 0.000)})
		v_24.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_24.Enabled = true
		v_24.Parent = v_7
	end
	do
		local v_25 = Instance.new("ParticleEmitter")
		v_25.Name = "Thin realistic shockwave"
		refMap["25"] = v_25
		v_25.Texture = "rbxassetid://12906276200"
		v_25.Rate = 2.00
		v_25.Speed = NumberRange.new(0.00, 0.00)
		v_25.Lifetime = NumberRange.new(0.40, 1.00)
		v_25.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_25.Rotation = NumberRange.new(-360.00, 360.00)
		v_25.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_25.LightEmission = 0.00
		v_25.LightInfluence = 0.00
		v_25.LockedToPart = true
		v_25.ZOffset = 2.05
		v_25.Drag = 2.00
		v_25.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_25.VelocityInheritance = 0.00
		v_25.Orientation = Enum.ParticleOrientation.FacingCamera
		v_25.EmissionDirection = Enum.NormalId.Top
		v_25.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_25.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5922, 0.2431, 0.8549)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5922, 0.2431, 0.8549))})
		v_25.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.533, 0.000), NumberSequenceKeypoint.new(0.48, 3.667, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_25.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.63, 0.343, 0.000), NumberSequenceKeypoint.new(0.89, 0.643, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_25.Enabled = true
		v_25.Parent = v_7
	end
	do
		local v_26 = Instance.new("ParticleEmitter")
		v_26.Name = "cat spec 7"
		refMap["26"] = v_26
		v_26.Texture = "rbxassetid://90414839644727"
		v_26.Rate = 2.00
		v_26.Speed = NumberRange.new(12.93, 25.87)
		v_26.Lifetime = NumberRange.new(0.40, 1.00)
		v_26.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_26.Rotation = NumberRange.new(-360.00, 360.00)
		v_26.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_26.LightEmission = 0.00
		v_26.LightInfluence = 0.00
		v_26.LockedToPart = false
		v_26.ZOffset = 2.02
		v_26.Drag = 4.00
		v_26.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_26.VelocityInheritance = 0.00
		v_26.Orientation = Enum.ParticleOrientation.FacingCamera
		v_26.EmissionDirection = Enum.NormalId.Top
		v_26.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_26.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_26.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.996, 0.000), NumberSequenceKeypoint.new(0.73, 0.621, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_26.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_26.Enabled = true
		v_26.Parent = v_7
	end
	do
		local v_27 = Instance.new("ParticleEmitter")
		v_27.Name = "Fire45"
		refMap["27"] = v_27
		v_27.Texture = "rbxassetid://16860419961"
		v_27.Rate = 3.00
		v_27.Speed = NumberRange.new(0.00, 0.00)
		v_27.Lifetime = NumberRange.new(0.70, 2.00)
		v_27.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_27.Rotation = NumberRange.new(-360.00, 360.00)
		v_27.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_27.LightEmission = 0.00
		v_27.LightInfluence = 0.00
		v_27.LockedToPart = true
		v_27.ZOffset = 2.03
		v_27.Drag = 2.00
		v_27.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_27.VelocityInheritance = 0.00
		v_27.Orientation = Enum.ParticleOrientation.FacingCamera
		v_27.EmissionDirection = Enum.NormalId.Top
		v_27.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_27.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_27.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 5.724, 0.000), NumberSequenceKeypoint.new(0.48, 8.285, 0.000), NumberSequenceKeypoint.new(1.00, 9.038, 0.000)})
		v_27.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_27.Enabled = true
		v_27.Parent = v_7
	end
	do
		local v_28 = Instance.new("ParticleEmitter")
		v_28.Name = "cursed energy3421"
		refMap["28"] = v_28
		v_28.Texture = "rbxassetid://17006172452"
		v_28.Rate = 2.00
		v_28.Speed = NumberRange.new(0.00, 0.00)
		v_28.Lifetime = NumberRange.new(0.40, 1.00)
		v_28.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_28.Rotation = NumberRange.new(-360.00, 360.00)
		v_28.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_28.LightEmission = 0.00
		v_28.LightInfluence = 0.00
		v_28.LockedToPart = true
		v_28.ZOffset = 1.01
		v_28.Drag = 2.00
		v_28.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_28.VelocityInheritance = 0.00
		v_28.Orientation = Enum.ParticleOrientation.FacingCamera
		v_28.EmissionDirection = Enum.NormalId.Top
		v_28.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_28.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_28.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.862, 0.000), NumberSequenceKeypoint.new(0.48, 4.143, 0.000), NumberSequenceKeypoint.new(1.00, 4.519, 0.000)})
		v_28.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.317, 0.000), NumberSequenceKeypoint.new(0.86, 0.683, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_28.Enabled = true
		v_28.Parent = v_7
	end
	do
		local v_29 = Instance.new("ParticleEmitter")
		v_29.Name = "Slightly glowing"
		refMap["29"] = v_29
		v_29.Texture = "rbxassetid://14152113700"
		v_29.Rate = 2.00
		v_29.Speed = NumberRange.new(0.00, 0.00)
		v_29.Lifetime = NumberRange.new(0.40, 1.00)
		v_29.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_29.Rotation = NumberRange.new(-360.00, 360.00)
		v_29.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_29.LightEmission = 0.00
		v_29.LightInfluence = 0.00
		v_29.LockedToPart = true
		v_29.ZOffset = 2.09
		v_29.Drag = 2.00
		v_29.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_29.VelocityInheritance = 0.00
		v_29.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_29.EmissionDirection = Enum.NormalId.Top
		v_29.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_29.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_29.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.533, 0.000), NumberSequenceKeypoint.new(0.48, 3.667, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_29.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_29.Enabled = true
		v_29.Parent = v_7
	end
	do
		local v_30 = Instance.new("ParticleEmitter")
		v_30.Name = "Cursed Energy Disperse 8x8"
		refMap["30"] = v_30
		v_30.Texture = "rbxassetid://97051019398375"
		v_30.Rate = 2.00
		v_30.Speed = NumberRange.new(0.00, 0.00)
		v_30.Lifetime = NumberRange.new(0.40, 1.00)
		v_30.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_30.Rotation = NumberRange.new(-360.00, 360.00)
		v_30.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_30.LightEmission = 0.00
		v_30.LightInfluence = 0.00
		v_30.LockedToPart = true
		v_30.ZOffset = 2.04
		v_30.Drag = 2.00
		v_30.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_30.VelocityInheritance = 0.00
		v_30.Orientation = Enum.ParticleOrientation.FacingCamera
		v_30.EmissionDirection = Enum.NormalId.Top
		v_30.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8
		v_30.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_30.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.533, 0.000), NumberSequenceKeypoint.new(0.48, 3.667, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_30.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_30.Enabled = true
		v_30.Parent = v_7
	end
	do
		local v_31 = Instance.new("ParticleEmitter")
		v_31.Name = "grainy shockwave 2"
		refMap["31"] = v_31
		v_31.Texture = "rbxassetid://16509144751"
		v_31.Rate = 2.00
		v_31.Speed = NumberRange.new(0.00, 0.00)
		v_31.Lifetime = NumberRange.new(0.40, 1.00)
		v_31.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_31.Rotation = NumberRange.new(-360.00, 360.00)
		v_31.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_31.LightEmission = 0.00
		v_31.LightInfluence = 0.00
		v_31.LockedToPart = true
		v_31.ZOffset = 2.04
		v_31.Drag = 2.00
		v_31.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_31.VelocityInheritance = 0.00
		v_31.Orientation = Enum.ParticleOrientation.FacingCamera
		v_31.EmissionDirection = Enum.NormalId.Top
		v_31.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_31.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 3.751, 0.000), NumberSequenceKeypoint.new(0.48, 5.429, 0.000), NumberSequenceKeypoint.new(1.00, 5.923, 0.000)})
		v_31.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.63, 0.343, 0.000), NumberSequenceKeypoint.new(0.89, 0.643, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_31.Enabled = true
		v_31.Parent = v_7
	end
	do
		local v_32 = Instance.new("ParticleEmitter")
		v_32.Name = "Light Ray"
		refMap["32"] = v_32
		v_32.Texture = "rbxassetid://14128173698"
		v_32.Rate = 4.00
		v_32.Speed = NumberRange.new(0.00, 0.00)
		v_32.Lifetime = NumberRange.new(0.40, 1.00)
		v_32.RotSpeed = NumberRange.new(30.00, 50.00)
		v_32.Rotation = NumberRange.new(0.00, 0.00)
		v_32.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_32.LightEmission = 0.00
		v_32.LightInfluence = 0.00
		v_32.LockedToPart = true
		v_32.ZOffset = 1.00
		v_32.Drag = 2.00
		v_32.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_32.VelocityInheritance = 0.00
		v_32.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_32.EmissionDirection = Enum.NormalId.Top
		v_32.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_32.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5922, 0.2431, 0.8549)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5922, 0.2431, 0.8549))})
		v_32.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.15, 2.504, 0.715), NumberSequenceKeypoint.new(0.42, 3.688, 0.779), NumberSequenceKeypoint.new(1.00, 4.043, 0.909)})
		v_32.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.263, 0.000), NumberSequenceKeypoint.new(0.85, 0.557, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_32.Enabled = true
		v_32.Parent = v_7
	end
	do
		local v_33 = Instance.new("ParticleEmitter")
		v_33.Name = "Triangle Top"
		refMap["33"] = v_33
		v_33.Texture = "rbxassetid://15009885079"
		v_33.Rate = 4.00
		v_33.Speed = NumberRange.new(0.00, 0.00)
		v_33.Lifetime = NumberRange.new(0.40, 1.00)
		v_33.RotSpeed = NumberRange.new(0.00, 0.00)
		v_33.Rotation = NumberRange.new(0.00, 0.00)
		v_33.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_33.LightEmission = 0.00
		v_33.LightInfluence = 0.00
		v_33.LockedToPart = true
		v_33.ZOffset = 1.00
		v_33.Drag = 2.00
		v_33.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_33.VelocityInheritance = 0.00
		v_33.Orientation = Enum.ParticleOrientation.FacingCamera
		v_33.EmissionDirection = Enum.NormalId.Top
		v_33.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8
		v_33.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5922, 0.2431, 0.8549)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5922, 0.2431, 0.8549))})
		v_33.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.15, 3.423, 0.978), NumberSequenceKeypoint.new(0.42, 5.042, 1.065), NumberSequenceKeypoint.new(1.00, 5.528, 1.243)})
		v_33.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.263, 0.000), NumberSequenceKeypoint.new(0.85, 0.557, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_33.Enabled = true
		v_33.Parent = v_7
	end
	do
		local v_34 = Instance.new("ParticleEmitter")
		v_34.Name = "Strange VFX"
		refMap["34"] = v_34
		v_34.Texture = "rbxassetid://18369800560"
		v_34.Rate = 1.00
		v_34.Speed = NumberRange.new(0.00, 0.00)
		v_34.Lifetime = NumberRange.new(1.00, 2.00)
		v_34.RotSpeed = NumberRange.new(0.00, 0.00)
		v_34.Rotation = NumberRange.new(90.00, 90.00)
		v_34.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_34.LightEmission = 0.00
		v_34.LightInfluence = 0.00
		v_34.LockedToPart = true
		v_34.ZOffset = 1.03
		v_34.Drag = 2.00
		v_34.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_34.VelocityInheritance = 0.00
		v_34.Orientation = Enum.ParticleOrientation.FacingCamera
		v_34.EmissionDirection = Enum.NormalId.Top
		v_34.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_34.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_34.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 5.067, 0.000), NumberSequenceKeypoint.new(0.48, 7.333, 0.000), NumberSequenceKeypoint.new(1.00, 8.000, 0.000)})
		v_34.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.600, 0.000), NumberSequenceKeypoint.new(1.00, 0.600, 0.000)})
		v_34.Enabled = true
		v_34.Parent = v_7
	end
	do
		local v_35 = Instance.new("ParticleEmitter")
		v_35.Name = "cursed energy 2"
		refMap["35"] = v_35
		v_35.Texture = "rbxassetid://78422400450982"
		v_35.Rate = 2.00
		v_35.Speed = NumberRange.new(0.00, 0.00)
		v_35.Lifetime = NumberRange.new(0.40, 1.00)
		v_35.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_35.Rotation = NumberRange.new(-360.00, 360.00)
		v_35.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_35.LightEmission = 0.00
		v_35.LightInfluence = 0.00
		v_35.LockedToPart = true
		v_35.ZOffset = 2.07
		v_35.Drag = 2.00
		v_35.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_35.VelocityInheritance = 0.00
		v_35.Orientation = Enum.ParticleOrientation.FacingCamera
		v_35.EmissionDirection = Enum.NormalId.Top
		v_35.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_35.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.533, 0.000), NumberSequenceKeypoint.new(0.48, 3.667, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_35.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_35.Enabled = true
		v_35.Parent = v_7
	end
	do
		local v_36 = Instance.new("ParticleEmitter")
		v_36.Name = "Cursed Energy Disperse 8x8"
		refMap["36"] = v_36
		v_36.Texture = "rbxassetid://97051019398375"
		v_36.Rate = 2.00
		v_36.Speed = NumberRange.new(0.00, 0.00)
		v_36.Lifetime = NumberRange.new(0.40, 1.00)
		v_36.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_36.Rotation = NumberRange.new(-360.00, 360.00)
		v_36.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_36.LightEmission = 0.00
		v_36.LightInfluence = 0.00
		v_36.LockedToPart = true
		v_36.ZOffset = 1.05
		v_36.Drag = 2.00
		v_36.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_36.VelocityInheritance = 0.00
		v_36.Orientation = Enum.ParticleOrientation.FacingCamera
		v_36.EmissionDirection = Enum.NormalId.Top
		v_36.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8
		v_36.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_36.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.862, 0.000), NumberSequenceKeypoint.new(0.48, 4.143, 0.000), NumberSequenceKeypoint.new(1.00, 4.519, 0.000)})
		v_36.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_36.Enabled = true
		v_36.Parent = v_7
	end
	do
		local v_37 = Instance.new("ParticleEmitter")
		v_37.Name = "Cursed Energy Disperse 8x8"
		refMap["37"] = v_37
		v_37.Texture = "rbxassetid://97051019398375"
		v_37.Rate = 2.00
		v_37.Speed = NumberRange.new(14.00, 20.00)
		v_37.Lifetime = NumberRange.new(0.40, 1.00)
		v_37.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_37.Rotation = NumberRange.new(-360.00, 360.00)
		v_37.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_37.LightEmission = 0.00
		v_37.LightInfluence = 0.00
		v_37.LockedToPart = true
		v_37.ZOffset = 1.02
		v_37.Drag = 7.00
		v_37.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_37.VelocityInheritance = 0.00
		v_37.Orientation = Enum.ParticleOrientation.FacingCamera
		v_37.EmissionDirection = Enum.NormalId.Top
		v_37.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8
		v_37.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_37.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.862, 0.000), NumberSequenceKeypoint.new(0.48, 4.143, 0.000), NumberSequenceKeypoint.new(1.00, 4.519, 0.000)})
		v_37.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.317, 0.000), NumberSequenceKeypoint.new(0.86, 0.683, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_37.Enabled = true
		v_37.Parent = v_7
	end
	do
		local v_38 = Instance.new("ParticleEmitter")
		v_38.Name = "cursed energy 2"
		refMap["38"] = v_38
		v_38.Texture = "rbxassetid://78422400450982"
		v_38.Rate = 2.00
		v_38.Speed = NumberRange.new(0.00, 0.00)
		v_38.Lifetime = NumberRange.new(0.40, 1.00)
		v_38.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_38.Rotation = NumberRange.new(-360.00, 360.00)
		v_38.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_38.LightEmission = 0.00
		v_38.LightInfluence = 0.00
		v_38.LockedToPart = true
		v_38.ZOffset = 1.04
		v_38.Drag = 2.00
		v_38.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_38.VelocityInheritance = 0.00
		v_38.Orientation = Enum.ParticleOrientation.FacingCamera
		v_38.EmissionDirection = Enum.NormalId.Top
		v_38.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_38.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.862, 0.000), NumberSequenceKeypoint.new(0.48, 4.143, 0.000), NumberSequenceKeypoint.new(1.00, 4.519, 0.000)})
		v_38.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_38.Enabled = true
		v_38.Parent = v_7
	end
	do
		local v_39 = Instance.new("ParticleEmitter")
		v_39.Name = "grainy shockwave 2"
		refMap["39"] = v_39
		v_39.Texture = "rbxassetid://16509144751"
		v_39.Rate = 2.00
		v_39.Speed = NumberRange.new(0.00, 0.00)
		v_39.Lifetime = NumberRange.new(0.40, 1.00)
		v_39.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_39.Rotation = NumberRange.new(-360.00, 360.00)
		v_39.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_39.LightEmission = 0.00
		v_39.LightInfluence = 0.00
		v_39.LockedToPart = true
		v_39.ZOffset = 2.00
		v_39.Drag = 2.00
		v_39.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_39.VelocityInheritance = 0.00
		v_39.Orientation = Enum.ParticleOrientation.FacingCamera
		v_39.EmissionDirection = Enum.NormalId.Top
		v_39.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_39.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.533, 0.000), NumberSequenceKeypoint.new(0.48, 3.667, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_39.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.63, 0.343, 0.000), NumberSequenceKeypoint.new(0.89, 0.643, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_39.Enabled = true
		v_39.Parent = v_7
	end
	do
		local v_40 = Instance.new("ParticleEmitter")
		v_40.Name = "cursed energy1"
		refMap["40"] = v_40
		v_40.Texture = "rbxassetid://112387970399345"
		v_40.Rate = 2.00
		v_40.Speed = NumberRange.new(0.00, 0.00)
		v_40.Lifetime = NumberRange.new(0.40, 1.00)
		v_40.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_40.Rotation = NumberRange.new(-360.00, 360.00)
		v_40.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_40.LightEmission = 0.00
		v_40.LightInfluence = 0.00
		v_40.LockedToPart = true
		v_40.ZOffset = 1.03
		v_40.Drag = 2.00
		v_40.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_40.VelocityInheritance = 0.00
		v_40.Orientation = Enum.ParticleOrientation.FacingCamera
		v_40.EmissionDirection = Enum.NormalId.Top
		v_40.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_40.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.862, 0.000), NumberSequenceKeypoint.new(0.48, 4.143, 0.000), NumberSequenceKeypoint.new(1.00, 4.519, 0.000)})
		v_40.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_40.Enabled = true
		v_40.Parent = v_7
	end
	do
		local v_41 = Instance.new("ParticleEmitter")
		v_41.Name = "cat spec 8"
		refMap["41"] = v_41
		v_41.Texture = "rbxassetid://101658731548844"
		v_41.Rate = 2.00
		v_41.Speed = NumberRange.new(10.00, 20.00)
		v_41.Lifetime = NumberRange.new(0.40, 1.00)
		v_41.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_41.Rotation = NumberRange.new(-360.00, 360.00)
		v_41.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_41.LightEmission = 0.00
		v_41.LightInfluence = 0.00
		v_41.LockedToPart = false
		v_41.ZOffset = 2.02
		v_41.Drag = 4.00
		v_41.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_41.VelocityInheritance = 0.00
		v_41.Orientation = Enum.ParticleOrientation.FacingCamera
		v_41.EmissionDirection = Enum.NormalId.Top
		v_41.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_41.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_41.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_41.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_41.Enabled = true
		v_41.Parent = v_7
	end
	do
		local v_42 = Instance.new("ParticleEmitter")
		v_42.Name = "cursed energy3421"
		refMap["42"] = v_42
		v_42.Texture = "rbxassetid://17006172452"
		v_42.Rate = 2.00
		v_42.Speed = NumberRange.new(0.00, 0.00)
		v_42.Lifetime = NumberRange.new(0.40, 1.00)
		v_42.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_42.Rotation = NumberRange.new(-360.00, 360.00)
		v_42.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_42.LightEmission = 0.00
		v_42.LightInfluence = 0.00
		v_42.LockedToPart = true
		v_42.ZOffset = 2.10
		v_42.Drag = 2.00
		v_42.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_42.VelocityInheritance = 0.00
		v_42.Orientation = Enum.ParticleOrientation.FacingCamera
		v_42.EmissionDirection = Enum.NormalId.Top
		v_42.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_42.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_42.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.533, 0.000), NumberSequenceKeypoint.new(0.48, 3.667, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_42.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.317, 0.000), NumberSequenceKeypoint.new(0.86, 0.683, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_42.Enabled = true
		v_42.Parent = v_7
	end
	do
		local v_43 = Instance.new("ParticleEmitter")
		v_43.Name = "cat spec 7"
		refMap["43"] = v_43
		v_43.Texture = "rbxassetid://90414839644727"
		v_43.Rate = 2.00
		v_43.Speed = NumberRange.new(10.00, 20.00)
		v_43.Lifetime = NumberRange.new(0.40, 1.00)
		v_43.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_43.Rotation = NumberRange.new(-360.00, 360.00)
		v_43.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_43.LightEmission = 0.00
		v_43.LightInfluence = 0.00
		v_43.LockedToPart = false
		v_43.ZOffset = 2.04
		v_43.Drag = 4.00
		v_43.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_43.VelocityInheritance = 0.00
		v_43.Orientation = Enum.ParticleOrientation.FacingCamera
		v_43.EmissionDirection = Enum.NormalId.Top
		v_43.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_43.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_43.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_43.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_43.Enabled = true
		v_43.Parent = v_7
	end
	do
		local v_44 = Instance.new("ParticleEmitter")
		v_44.Name = "cat spec 3"
		refMap["44"] = v_44
		v_44.Texture = "rbxassetid://136781994057492"
		v_44.Rate = 2.00
		v_44.Speed = NumberRange.new(12.93, 25.87)
		v_44.Lifetime = NumberRange.new(0.40, 1.00)
		v_44.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_44.Rotation = NumberRange.new(-360.00, 360.00)
		v_44.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_44.LightEmission = 0.00
		v_44.LightInfluence = 0.00
		v_44.LockedToPart = false
		v_44.ZOffset = 2.04
		v_44.Drag = 4.00
		v_44.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_44.VelocityInheritance = 0.00
		v_44.Orientation = Enum.ParticleOrientation.FacingCamera
		v_44.EmissionDirection = Enum.NormalId.Top
		v_44.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_44.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_44.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.996, 0.000), NumberSequenceKeypoint.new(0.73, 0.621, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_44.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_44.Enabled = true
		v_44.Parent = v_7
	end
	end
	do
		local v_45 = Instance.new("Part")
		v_45.Name = "inwardbezier"
		refMap["45"] = v_45
		v_45.Anchored = false
		v_45.CanCollide = false
		v_45.CanTouch = false
		v_45.CanQuery = false
		v_45.Massless = true
		v_45.CastShadow = false
		v_45.Transparency = 1.00
		v_45.Size = Vector3.new(10.000, 10.000, 10.000)
		v_45.CFrame = CFrame.new(-140.543, 22.026, -44.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_45.Color = Color3.fromRGB(248, 248, 248)
		v_45.Parent = v_2
	do
		local v_46 = Instance.new("Attachment")
		v_46.Name = "Bezier"
		refMap["46"] = v_46
		v_46.CFrame = CFrame.new(0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_46.Parent = v_45
	do
		local v_47 = Instance.new("Attachment")
		v_47.Name = "Points"
		refMap["47"] = v_47
		v_47.CFrame = CFrame.new(0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_47.Parent = v_46
	do
		local v_48 = Instance.new("Attachment")
		v_48.Name = "1"
		refMap["48"] = v_48
		v_48.CFrame = CFrame.new(0.000, 0.000, 3.716, 0.000, 0.000, -1.000, 0.000, 1.000, 0.000, 1.000, 0.000, 0.000)
		v_48.Parent = v_47
	do
		local v_49 = Instance.new("Attachment")
		v_49.Name = "T0"
		refMap["49"] = v_49
		v_49.CFrame = CFrame.new(-2.589, -7.266, -0.197, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_49.Parent = v_48
	end
	end
	do
		local v_50 = Instance.new("Attachment")
		v_50.Name = "2"
		refMap["50"] = v_50
		v_50.CFrame = CFrame.new(0.898, -0.143, -15.205, -0.000, 0.000, -1.000, 0.000, 1.000, 0.000, 1.000, 0.000, -0.000)
		v_50.Parent = v_47
	do
		local v_51 = Instance.new("Attachment")
		v_51.Name = "T1"
		refMap["51"] = v_51
		v_51.CFrame = CFrame.new(2.300, 6.629, 1.667, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_51.Parent = v_50
	end
	end
	end
	do
		local v_52 = Instance.new("Attachment")
		v_52.Name = "End"
		refMap["52"] = v_52
		v_52.CFrame = CFrame.new(0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_52.Parent = v_46
	end
	do
		local v_53 = Instance.new("Part")
		v_53.Name = "Part"
		refMap["53"] = v_53
		v_53.Anchored = false
		v_53.CanCollide = false
		v_53.CanTouch = false
		v_53.CanQuery = false
		v_53.Massless = true
		v_53.CastShadow = false
		v_53.Transparency = 1.00
		v_53.Size = Vector3.new(0.400, 0.400, 0.400)
		v_53.CFrame = CFrame.new(-140.543, 22.026, -44.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_53.Color = Color3.fromRGB(248, 248, 248)
		v_53.Parent = v_46
	do
		local v_54 = Instance.new("Attachment")
		v_54.Name = "0"
		refMap["54"] = v_54
		v_54.CFrame = CFrame.new(-0.022, 0.000, 0.316, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_54.Parent = v_53
	end
	do
		local v_55 = Instance.new("Trail")
		v_55.Name = "cursed energy trail 2"
		refMap["55"] = v_55
		v_55.Texture = "rbxassetid://119952780050980"
		v_55.Lifetime = 0.30
		v_55.MinLength = 0.00
		v_55.LightEmission = 0.00
		v_55.LightInfluence = 0.00
		v_55.FaceCamera = true
		v_55.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5922, 0.2431, 0.8549)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5922, 0.2431, 0.8549))})
		v_55.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.17, 0.287, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_55.Enabled = true
		table.insert(pendingRefs, { obj = v_55, prop = "Attachment0", ref = "54" })
		table.insert(pendingRefs, { obj = v_55, prop = "Attachment1", ref = "56" })
		v_55.Parent = v_53
	end
	do
		local v_56 = Instance.new("Attachment")
		v_56.Name = "1"
		refMap["56"] = v_56
		v_56.CFrame = CFrame.new(-0.031, 0.000, -0.301, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_56.Parent = v_53
	end
	end
	end
	do
		local v_57 = Instance.new("Attachment")
		v_57.Name = "Bezier"
		refMap["57"] = v_57
		v_57.CFrame = CFrame.new(0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_57.Parent = v_45
	do
		local v_58 = Instance.new("Attachment")
		v_58.Name = "End"
		refMap["58"] = v_58
		v_58.CFrame = CFrame.new(0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_58.Parent = v_57
	end
	do
		local v_59 = Instance.new("Attachment")
		v_59.Name = "Points"
		refMap["59"] = v_59
		v_59.CFrame = CFrame.new(0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_59.Parent = v_57
	do
		local v_60 = Instance.new("Attachment")
		v_60.Name = "2"
		refMap["60"] = v_60
		v_60.CFrame = CFrame.new(0.898, -0.143, -15.205, -0.000, 0.000, -1.000, 0.000, 1.000, 0.000, 1.000, 0.000, -0.000)
		v_60.Parent = v_59
	do
		local v_61 = Instance.new("Attachment")
		v_61.Name = "T1"
		refMap["61"] = v_61
		v_61.CFrame = CFrame.new(2.300, 6.629, 1.667, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_61.Parent = v_60
	end
	end
	do
		local v_62 = Instance.new("Attachment")
		v_62.Name = "1"
		refMap["62"] = v_62
		v_62.CFrame = CFrame.new(0.000, 0.000, 3.716, 0.000, 0.000, -1.000, 0.000, 1.000, 0.000, 1.000, 0.000, 0.000)
		v_62.Parent = v_59
	do
		local v_63 = Instance.new("Attachment")
		v_63.Name = "T0"
		refMap["63"] = v_63
		v_63.CFrame = CFrame.new(-2.589, -7.266, -0.197, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_63.Parent = v_62
	end
	end
	end
	do
		local v_64 = Instance.new("Part")
		v_64.Name = "Part"
		refMap["64"] = v_64
		v_64.Anchored = false
		v_64.CanCollide = false
		v_64.CanTouch = false
		v_64.CanQuery = false
		v_64.Massless = true
		v_64.CastShadow = false
		v_64.Transparency = 1.00
		v_64.Size = Vector3.new(0.400, 0.400, 0.400)
		v_64.CFrame = CFrame.new(-140.543, 22.026, -44.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_64.Color = Color3.fromRGB(248, 248, 248)
		v_64.Parent = v_57
	do
		local v_65 = Instance.new("Attachment")
		v_65.Name = "0"
		refMap["65"] = v_65
		v_65.CFrame = CFrame.new(-0.023, 0.000, 0.284, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_65.Parent = v_64
	end
	do
		local v_66 = Instance.new("Trail")
		v_66.Name = "Beam88"
		refMap["66"] = v_66
		v_66.Texture = "rbxassetid://133860736415104"
		v_66.Lifetime = 0.30
		v_66.MinLength = 0.00
		v_66.LightEmission = 0.00
		v_66.LightInfluence = 0.00
		v_66.FaceCamera = true
		v_66.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5922, 0.2431, 0.8549)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5922, 0.2431, 0.8549))})
		v_66.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_66.Enabled = true
		table.insert(pendingRefs, { obj = v_66, prop = "Attachment0", ref = "65" })
		table.insert(pendingRefs, { obj = v_66, prop = "Attachment1", ref = "67" })
		v_66.Parent = v_64
	end
	do
		local v_67 = Instance.new("Attachment")
		v_67.Name = "1"
		refMap["67"] = v_67
		v_67.CFrame = CFrame.new(-0.031, 0.000, -0.269, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_67.Parent = v_64
	end
	end
	end
	do
		local v_68 = Instance.new("WeldConstraint")
		v_68.Name = "inwardbezier_Weld"
		refMap["68"] = v_68
		v_68.Parent = v_45
	end
	end
	do
		local v_69 = Instance.new("Attachment")
		v_69.Name = "Attachment"
		refMap["69"] = v_69
		v_69.CFrame = CFrame.new(0.000, -3.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_69.Parent = v_2
	do
		local v_70 = Instance.new("ParticleEmitter")
		v_70.Name = "Slightly glowing"
		refMap["70"] = v_70
		v_70.Texture = "rbxassetid://14152113700"
		v_70.Rate = 2.00
		v_70.Speed = NumberRange.new(0.00, 0.00)
		v_70.Lifetime = NumberRange.new(1.00, 2.00)
		v_70.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_70.Rotation = NumberRange.new(-360.00, 360.00)
		v_70.SpreadAngle = Vector2.new(0.0, 0.0)
		v_70.LightEmission = 0.00
		v_70.LightInfluence = 0.00
		v_70.LockedToPart = true
		v_70.ZOffset = 2.00
		v_70.Drag = 0.00
		v_70.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_70.VelocityInheritance = 0.00
		v_70.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_70.EmissionDirection = Enum.NormalId.Top
		v_70.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_70.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(0.24, Color3.new(0.1477, 0.0430, 0.2262)), ColorSequenceKeypoint.new(0.45, Color3.new(0.0000, 0.0000, 0.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0000, 0.0000, 0.0000))})
		v_70.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.17, 4.037, 0.000), NumberSequenceKeypoint.new(0.49, 6.557, 0.000), NumberSequenceKeypoint.new(1.00, 7.000, 0.000)})
		v_70.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_70.Enabled = true
		v_70.Parent = v_69
	end
	do
		local v_71 = Instance.new("ParticleEmitter")
		v_71.Name = "dis dark circle 2"
		refMap["71"] = v_71
		v_71.Texture = "rbxassetid://87272078452382"
		v_71.Rate = 2.00
		v_71.Speed = NumberRange.new(0.00, 0.00)
		v_71.Lifetime = NumberRange.new(1.00, 2.00)
		v_71.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_71.Rotation = NumberRange.new(-360.00, 360.00)
		v_71.SpreadAngle = Vector2.new(0.0, 0.0)
		v_71.LightEmission = 0.00
		v_71.LightInfluence = 0.00
		v_71.LockedToPart = true
		v_71.ZOffset = 1.03
		v_71.Drag = 0.00
		v_71.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_71.VelocityInheritance = 0.00
		v_71.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_71.EmissionDirection = Enum.NormalId.Top
		v_71.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5922, 0.2431, 0.8549)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5922, 0.2431, 0.8549))})
		v_71.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.17, 4.037, 0.000), NumberSequenceKeypoint.new(0.49, 6.557, 0.000), NumberSequenceKeypoint.new(1.00, 7.000, 0.000)})
		v_71.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.62, 0.213, 0.000), NumberSequenceKeypoint.new(0.84, 0.467, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_71.Enabled = true
		v_71.Parent = v_69
	end
	end
	do
		local v_72 = Instance.new("Attachment")
		v_72.Name = "Attachment"
		refMap["72"] = v_72
		v_72.CFrame = CFrame.new(0.000, -3.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_72.Parent = v_2
	do
		local v_73 = Instance.new("ParticleEmitter")
		v_73.Name = "cursed energy 2"
		refMap["73"] = v_73
		v_73.Texture = "rbxassetid://78422400450982"
		v_73.Rate = 2.00
		v_73.Speed = NumberRange.new(0.00, 0.00)
		v_73.Lifetime = NumberRange.new(1.00, 2.00)
		v_73.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_73.Rotation = NumberRange.new(-360.00, 360.00)
		v_73.SpreadAngle = Vector2.new(0.0, 0.0)
		v_73.LightEmission = 0.00
		v_73.LightInfluence = 0.00
		v_73.LockedToPart = true
		v_73.ZOffset = 1.01
		v_73.Drag = 0.00
		v_73.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_73.VelocityInheritance = 0.00
		v_73.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_73.EmissionDirection = Enum.NormalId.Top
		v_73.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3593, 0.1054, 0.5544)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3593, 0.1054, 0.5544))})
		v_73.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.17, 4.745, 0.000), NumberSequenceKeypoint.new(1.00, 7.694, 0.000)})
		v_73.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.247, 0.000), NumberSequenceKeypoint.new(0.90, 0.577, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_73.Enabled = true
		v_73.Parent = v_72
	end
	do
		local v_74 = Instance.new("ParticleEmitter")
		v_74.Name = "Thin realistic shockwave"
		refMap["74"] = v_74
		v_74.Texture = "rbxassetid://12906276200"
		v_74.Rate = 2.00
		v_74.Speed = NumberRange.new(0.00, 0.00)
		v_74.Lifetime = NumberRange.new(1.00, 2.00)
		v_74.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_74.Rotation = NumberRange.new(-360.00, 360.00)
		v_74.SpreadAngle = Vector2.new(-30.0, 20.0)
		v_74.LightEmission = 0.00
		v_74.LightInfluence = 0.00
		v_74.LockedToPart = true
		v_74.ZOffset = 1.07
		v_74.Drag = 0.00
		v_74.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_74.VelocityInheritance = 0.00
		v_74.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_74.EmissionDirection = Enum.NormalId.Top
		v_74.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_74.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3593, 0.1054, 0.5544)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3593, 0.1054, 0.5544))})
		v_74.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.17, 5.586, 0.000), NumberSequenceKeypoint.new(1.00, 9.058, 0.000)})
		v_74.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.247, 0.000), NumberSequenceKeypoint.new(0.90, 0.577, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_74.Enabled = true
		v_74.Parent = v_72
	end
	do
		local v_75 = Instance.new("ParticleEmitter")
		v_75.Name = "weird shockwave"
		refMap["75"] = v_75
		v_75.Texture = "rbxassetid://16940431172"
		v_75.Rate = 2.00
		v_75.Speed = NumberRange.new(0.00, 0.00)
		v_75.Lifetime = NumberRange.new(1.00, 2.00)
		v_75.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_75.Rotation = NumberRange.new(-360.00, 360.00)
		v_75.SpreadAngle = Vector2.new(0.0, 0.0)
		v_75.LightEmission = 0.00
		v_75.LightInfluence = 0.00
		v_75.LockedToPart = true
		v_75.ZOffset = 1.04
		v_75.Drag = 0.00
		v_75.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_75.VelocityInheritance = 0.00
		v_75.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_75.EmissionDirection = Enum.NormalId.Top
		v_75.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(0.24, Color3.new(0.1477, 0.0430, 0.2262)), ColorSequenceKeypoint.new(0.45, Color3.new(0.0000, 0.0000, 0.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0000, 0.0000, 0.0000))})
		v_75.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.17, 4.256, 0.000), NumberSequenceKeypoint.new(0.49, 6.419, 0.000), NumberSequenceKeypoint.new(1.00, 6.902, 0.000)})
		v_75.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.180, 0.000), NumberSequenceKeypoint.new(0.59, 0.370, 0.000), NumberSequenceKeypoint.new(0.82, 0.617, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_75.Enabled = true
		v_75.Parent = v_72
	end
	do
		local v_76 = Instance.new("ParticleEmitter")
		v_76.Name = "windfs"
		refMap["76"] = v_76
		v_76.Texture = "rbxassetid://135128020878697"
		v_76.Rate = 2.00
		v_76.Speed = NumberRange.new(0.00, 0.00)
		v_76.Lifetime = NumberRange.new(1.00, 2.00)
		v_76.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_76.Rotation = NumberRange.new(-360.00, 360.00)
		v_76.SpreadAngle = Vector2.new(-30.0, 20.0)
		v_76.LightEmission = 0.00
		v_76.LightInfluence = 0.00
		v_76.LockedToPart = true
		v_76.ZOffset = 1.04
		v_76.Drag = 0.00
		v_76.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_76.VelocityInheritance = 0.00
		v_76.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_76.EmissionDirection = Enum.NormalId.Top
		v_76.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5922, 0.2431, 0.8549)), ColorSequenceKeypoint.new(0.24, Color3.new(0.1477, 0.0430, 0.2262)), ColorSequenceKeypoint.new(0.45, Color3.new(0.0000, 0.0000, 0.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0000, 0.0000, 0.0000))})
		v_76.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.17, 3.700, 0.000), NumberSequenceKeypoint.new(1.00, 6.000, 0.000)})
		v_76.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_76.Enabled = true
		v_76.Parent = v_72
	end
	do
		local v_77 = Instance.new("ParticleEmitter")
		v_77.Name = "another shockwave"
		refMap["77"] = v_77
		v_77.Texture = "rbxassetid://13582043821"
		v_77.Rate = 2.00
		v_77.Speed = NumberRange.new(0.00, 0.00)
		v_77.Lifetime = NumberRange.new(1.00, 2.00)
		v_77.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_77.Rotation = NumberRange.new(-360.00, 360.00)
		v_77.SpreadAngle = Vector2.new(0.0, 0.0)
		v_77.LightEmission = 0.00
		v_77.LightInfluence = 0.00
		v_77.LockedToPart = true
		v_77.ZOffset = 2.01
		v_77.Drag = 0.00
		v_77.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_77.VelocityInheritance = 0.00
		v_77.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_77.EmissionDirection = Enum.NormalId.Top
		v_77.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(0.24, Color3.new(0.1477, 0.0430, 0.2262)), ColorSequenceKeypoint.new(0.45, Color3.new(0.0000, 0.0000, 0.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0000, 0.0000, 0.0000))})
		v_77.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.17, 5.639, 0.000), NumberSequenceKeypoint.new(0.49, 8.504, 0.000), NumberSequenceKeypoint.new(1.00, 9.144, 0.000)})
		v_77.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.427, 0.000), NumberSequenceKeypoint.new(0.54, 0.627, 0.000), NumberSequenceKeypoint.new(0.76, 0.737, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_77.Enabled = true
		v_77.Parent = v_72
	end
	do
		local v_78 = Instance.new("ParticleEmitter")
		v_78.Name = "cursed energy 2"
		refMap["78"] = v_78
		v_78.Texture = "rbxassetid://78422400450982"
		v_78.Rate = 2.00
		v_78.Speed = NumberRange.new(0.00, 0.00)
		v_78.Lifetime = NumberRange.new(1.00, 2.00)
		v_78.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_78.Rotation = NumberRange.new(-360.00, 360.00)
		v_78.SpreadAngle = Vector2.new(0.0, 0.0)
		v_78.LightEmission = 0.00
		v_78.LightInfluence = 0.00
		v_78.LockedToPart = true
		v_78.ZOffset = 1.03
		v_78.Drag = 0.00
		v_78.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_78.VelocityInheritance = 0.00
		v_78.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_78.EmissionDirection = Enum.NormalId.Top
		v_78.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3593, 0.1054, 0.5544)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3593, 0.1054, 0.5544))})
		v_78.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.17, 3.840, 0.000), NumberSequenceKeypoint.new(1.00, 6.227, 0.000)})
		v_78.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.247, 0.000), NumberSequenceKeypoint.new(0.90, 0.577, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_78.Enabled = true
		v_78.Parent = v_72
	end
	do
		local v_79 = Instance.new("ParticleEmitter")
		v_79.Name = "Smokey Crescent"
		refMap["79"] = v_79
		v_79.Texture = "rbxassetid://17085222506"
		v_79.Rate = 2.00
		v_79.Speed = NumberRange.new(0.00, 0.00)
		v_79.Lifetime = NumberRange.new(1.00, 2.00)
		v_79.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_79.Rotation = NumberRange.new(-360.00, 360.00)
		v_79.SpreadAngle = Vector2.new(-30.0, 20.0)
		v_79.LightEmission = 0.00
		v_79.LightInfluence = 0.00
		v_79.LockedToPart = true
		v_79.ZOffset = 1.03
		v_79.Drag = 0.00
		v_79.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_79.VelocityInheritance = 0.00
		v_79.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_79.EmissionDirection = Enum.NormalId.Top
		v_79.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_79.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(0.24, Color3.new(0.1477, 0.0430, 0.2262)), ColorSequenceKeypoint.new(0.45, Color3.new(0.0000, 0.0000, 0.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0000, 0.0000, 0.0000))})
		v_79.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.17, 3.700, 0.000), NumberSequenceKeypoint.new(1.00, 6.000, 0.000)})
		v_79.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_79.Enabled = true
		v_79.Parent = v_72
	end
	do
		local v_80 = Instance.new("ParticleEmitter")
		v_80.Name = "grainy shockwave 2"
		refMap["80"] = v_80
		v_80.Texture = "rbxassetid://16509144751"
		v_80.Rate = 2.00
		v_80.Speed = NumberRange.new(0.00, 0.00)
		v_80.Lifetime = NumberRange.new(1.00, 2.00)
		v_80.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_80.Rotation = NumberRange.new(-360.00, 360.00)
		v_80.SpreadAngle = Vector2.new(0.0, 0.0)
		v_80.LightEmission = 0.00
		v_80.LightInfluence = 0.00
		v_80.LockedToPart = true
		v_80.ZOffset = 1.02
		v_80.Drag = 0.00
		v_80.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_80.VelocityInheritance = 0.00
		v_80.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_80.EmissionDirection = Enum.NormalId.Top
		v_80.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(0.24, Color3.new(0.1477, 0.0430, 0.2262)), ColorSequenceKeypoint.new(0.45, Color3.new(0.0000, 0.0000, 0.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0000, 0.0000, 0.0000))})
		v_80.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.17, 5.639, 0.000), NumberSequenceKeypoint.new(0.49, 8.504, 0.000), NumberSequenceKeypoint.new(1.00, 9.144, 0.000)})
		v_80.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.427, 0.000), NumberSequenceKeypoint.new(0.54, 0.627, 0.000), NumberSequenceKeypoint.new(0.76, 0.737, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_80.Enabled = true
		v_80.Parent = v_72
	end
	end
	do
		local v_81 = Instance.new("Part")
		v_81.Name = "Part"
		refMap["81"] = v_81
		v_81.Anchored = false
		v_81.CanCollide = false
		v_81.CanTouch = false
		v_81.CanQuery = false
		v_81.Massless = true
		v_81.CastShadow = false
		v_81.Transparency = 1.00
		v_81.Size = Vector3.new(8.000, 1.000, 7.000)
		v_81.CFrame = CFrame.new(-140.500, 19.531, -44.000, 0.000, 0.000, -1.000, 0.000, 1.000, 0.000, 1.000, 0.000, 0.000)
		v_81.Color = Color3.fromRGB(163, 162, 165)
		v_81.Parent = v_2
	do
		local v_82 = Instance.new("ParticleEmitter")
		v_82.Name = "Sideways Spec 15"
		refMap["82"] = v_82
		v_82.Texture = "rbxassetid://6763809313"
		v_82.Rate = 2.00
		v_82.Speed = NumberRange.new(10.00, 20.00)
		v_82.Lifetime = NumberRange.new(0.40, 1.00)
		v_82.RotSpeed = NumberRange.new(0.00, 0.00)
		v_82.Rotation = NumberRange.new(90.00, 90.00)
		v_82.SpreadAngle = Vector2.new(-30.0, 30.0)
		v_82.LightEmission = 0.00
		v_82.LightInfluence = 0.00
		v_82.LockedToPart = false
		v_82.ZOffset = 2.02
		v_82.Drag = 4.00
		v_82.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_82.VelocityInheritance = 0.00
		v_82.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_82.EmissionDirection = Enum.NormalId.Top
		v_82.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_82.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_82.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_82.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_82.Enabled = true
		v_82.Parent = v_81
	end
	do
		local v_83 = Instance.new("ParticleEmitter")
		v_83.Name = "cursed energy spec"
		refMap["83"] = v_83
		v_83.Texture = "rbxassetid://85688545954016"
		v_83.Rate = 2.00
		v_83.Speed = NumberRange.new(10.00, 20.00)
		v_83.Lifetime = NumberRange.new(0.40, 1.00)
		v_83.RotSpeed = NumberRange.new(0.00, 0.00)
		v_83.Rotation = NumberRange.new(90.00, 90.00)
		v_83.SpreadAngle = Vector2.new(-30.0, 30.0)
		v_83.LightEmission = 0.00
		v_83.LightInfluence = 0.00
		v_83.LockedToPart = false
		v_83.ZOffset = 2.04
		v_83.Drag = 4.00
		v_83.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_83.VelocityInheritance = 0.00
		v_83.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_83.EmissionDirection = Enum.NormalId.Top
		v_83.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_83.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_83.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_83.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_83.Enabled = true
		v_83.Parent = v_81
	end
	do
		local v_84 = Instance.new("ParticleEmitter")
		v_84.Name = "Sideways Spec 15"
		refMap["84"] = v_84
		v_84.Texture = "rbxassetid://6763809313"
		v_84.Rate = 1.00
		v_84.Speed = NumberRange.new(10.00, 20.00)
		v_84.Lifetime = NumberRange.new(0.40, 1.00)
		v_84.RotSpeed = NumberRange.new(0.00, 0.00)
		v_84.Rotation = NumberRange.new(90.00, 90.00)
		v_84.SpreadAngle = Vector2.new(-50.0, 50.0)
		v_84.LightEmission = 0.00
		v_84.LightInfluence = 0.00
		v_84.LockedToPart = false
		v_84.ZOffset = 3.09
		v_84.Drag = 4.00
		v_84.Acceleration = Vector3.new(0.000, -20.000, 0.000)
		v_84.VelocityInheritance = 0.00
		v_84.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_84.EmissionDirection = Enum.NormalId.Top
		v_84.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_84.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_84.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_84.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_84.Enabled = true
		v_84.Parent = v_81
	end
	do
		local v_85 = Instance.new("ParticleEmitter")
		v_85.Name = "Sideways Spec 12"
		refMap["85"] = v_85
		v_85.Texture = "rbxassetid://1269254614"
		v_85.Rate = 1.00
		v_85.Speed = NumberRange.new(10.00, 20.00)
		v_85.Lifetime = NumberRange.new(0.40, 1.00)
		v_85.RotSpeed = NumberRange.new(0.00, 0.00)
		v_85.Rotation = NumberRange.new(90.00, 90.00)
		v_85.SpreadAngle = Vector2.new(-50.0, 50.0)
		v_85.LightEmission = 0.00
		v_85.LightInfluence = 0.00
		v_85.LockedToPart = false
		v_85.ZOffset = 3.03
		v_85.Drag = 4.00
		v_85.Acceleration = Vector3.new(0.000, -20.000, 0.000)
		v_85.VelocityInheritance = 0.00
		v_85.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_85.EmissionDirection = Enum.NormalId.Top
		v_85.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_85.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_85.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_85.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_85.Enabled = true
		v_85.Parent = v_81
	end
	do
		local v_86 = Instance.new("ParticleEmitter")
		v_86.Name = "cursed energy spec"
		refMap["86"] = v_86
		v_86.Texture = "rbxassetid://85688545954016"
		v_86.Rate = 2.00
		v_86.Speed = NumberRange.new(10.00, 20.00)
		v_86.Lifetime = NumberRange.new(0.40, 1.00)
		v_86.RotSpeed = NumberRange.new(0.00, 0.00)
		v_86.Rotation = NumberRange.new(90.00, 90.00)
		v_86.SpreadAngle = Vector2.new(-30.0, 30.0)
		v_86.LightEmission = 0.00
		v_86.LightInfluence = 0.00
		v_86.LockedToPart = false
		v_86.ZOffset = 2.04
		v_86.Drag = 4.00
		v_86.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_86.VelocityInheritance = 0.00
		v_86.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_86.EmissionDirection = Enum.NormalId.Top
		v_86.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_86.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_86.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_86.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_86.Enabled = true
		v_86.Parent = v_81
	end
	do
		local v_87 = Instance.new("ParticleEmitter")
		v_87.Name = "Sideways Spec 15"
		refMap["87"] = v_87
		v_87.Texture = "rbxassetid://6763809313"
		v_87.Rate = 1.00
		v_87.Speed = NumberRange.new(10.00, 20.00)
		v_87.Lifetime = NumberRange.new(0.40, 1.00)
		v_87.RotSpeed = NumberRange.new(0.00, 0.00)
		v_87.Rotation = NumberRange.new(90.00, 90.00)
		v_87.SpreadAngle = Vector2.new(-50.0, 50.0)
		v_87.LightEmission = 0.00
		v_87.LightInfluence = 0.00
		v_87.LockedToPart = false
		v_87.ZOffset = 3.08
		v_87.Drag = 4.00
		v_87.Acceleration = Vector3.new(0.000, -20.000, 0.000)
		v_87.VelocityInheritance = 0.00
		v_87.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_87.EmissionDirection = Enum.NormalId.Top
		v_87.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_87.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_87.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_87.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_87.Enabled = true
		v_87.Parent = v_81
	end
	do
		local v_88 = Instance.new("ParticleEmitter")
		v_88.Name = "Sideways Spec 102"
		refMap["88"] = v_88
		v_88.Texture = "rbxassetid://80742887810818"
		v_88.Rate = 1.00
		v_88.Speed = NumberRange.new(10.00, 20.00)
		v_88.Lifetime = NumberRange.new(0.40, 1.00)
		v_88.RotSpeed = NumberRange.new(0.00, 0.00)
		v_88.Rotation = NumberRange.new(90.00, 90.00)
		v_88.SpreadAngle = Vector2.new(-50.0, 50.0)
		v_88.LightEmission = 0.00
		v_88.LightInfluence = 0.00
		v_88.LockedToPart = false
		v_88.ZOffset = 3.00
		v_88.Drag = 4.00
		v_88.Acceleration = Vector3.new(0.000, -20.000, 0.000)
		v_88.VelocityInheritance = 0.00
		v_88.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_88.EmissionDirection = Enum.NormalId.Top
		v_88.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_88.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_88.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_88.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_88.Enabled = true
		v_88.Parent = v_81
	end
	do
		local v_89 = Instance.new("ParticleEmitter")
		v_89.Name = "Realistic Smoke 10"
		refMap["89"] = v_89
		v_89.Texture = "rbxassetid://82219367698334"
		v_89.Rate = 1.00
		v_89.Speed = NumberRange.new(10.00, 20.00)
		v_89.Lifetime = NumberRange.new(1.00, 2.00)
		v_89.RotSpeed = NumberRange.new(0.00, 0.00)
		v_89.Rotation = NumberRange.new(0.00, 0.00)
		v_89.SpreadAngle = Vector2.new(0.0, 0.0)
		v_89.LightEmission = 0.00
		v_89.LightInfluence = 0.00
		v_89.LockedToPart = false
		v_89.ZOffset = 2.06
		v_89.Drag = 4.00
		v_89.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_89.VelocityInheritance = 0.00
		v_89.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
		v_89.EmissionDirection = Enum.NormalId.Top
		v_89.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_89.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_89.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.430, 0.000), NumberSequenceKeypoint.new(0.42, 3.670, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_89.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.427, 0.000), NumberSequenceKeypoint.new(0.39, 0.553, 0.000), NumberSequenceKeypoint.new(0.75, 0.720, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_89.Enabled = true
		v_89.Parent = v_81
	end
	do
		local v_90 = Instance.new("ParticleEmitter")
		v_90.Name = "Sideways Spec 17"
		refMap["90"] = v_90
		v_90.Texture = "rbxassetid://8599882518"
		v_90.Rate = 1.00
		v_90.Speed = NumberRange.new(10.00, 20.00)
		v_90.Lifetime = NumberRange.new(0.40, 1.00)
		v_90.RotSpeed = NumberRange.new(0.00, 0.00)
		v_90.Rotation = NumberRange.new(90.00, 90.00)
		v_90.SpreadAngle = Vector2.new(-50.0, 50.0)
		v_90.LightEmission = 0.00
		v_90.LightInfluence = 0.00
		v_90.LockedToPart = false
		v_90.ZOffset = 3.10
		v_90.Drag = 4.00
		v_90.Acceleration = Vector3.new(0.000, -20.000, 0.000)
		v_90.VelocityInheritance = 0.00
		v_90.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_90.EmissionDirection = Enum.NormalId.Top
		v_90.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_90.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_90.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_90.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_90.Enabled = true
		v_90.Parent = v_81
	end
	do
		local v_91 = Instance.new("ParticleEmitter")
		v_91.Name = "fire realistic"
		refMap["91"] = v_91
		v_91.Texture = "rbxassetid://115973544312399"
		v_91.Rate = 1.00
		v_91.Speed = NumberRange.new(10.00, 20.00)
		v_91.Lifetime = NumberRange.new(1.00, 2.00)
		v_91.RotSpeed = NumberRange.new(0.00, 0.00)
		v_91.Rotation = NumberRange.new(0.00, 0.00)
		v_91.SpreadAngle = Vector2.new(0.0, 0.0)
		v_91.LightEmission = 0.00
		v_91.LightInfluence = 0.00
		v_91.LockedToPart = false
		v_91.ZOffset = 2.03
		v_91.Drag = 4.00
		v_91.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_91.VelocityInheritance = 0.00
		v_91.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
		v_91.EmissionDirection = Enum.NormalId.Top
		v_91.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_91.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.430, 0.000), NumberSequenceKeypoint.new(0.42, 3.670, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_91.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.427, 0.000), NumberSequenceKeypoint.new(0.39, 0.553, 0.000), NumberSequenceKeypoint.new(0.75, 0.720, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_91.Enabled = true
		v_91.Parent = v_81
	end
	do
		local v_92 = Instance.new("ParticleEmitter")
		v_92.Name = "Sideways Spec 102"
		refMap["92"] = v_92
		v_92.Texture = "rbxassetid://80742887810818"
		v_92.Rate = 1.00
		v_92.Speed = NumberRange.new(10.00, 20.00)
		v_92.Lifetime = NumberRange.new(0.40, 1.00)
		v_92.RotSpeed = NumberRange.new(0.00, 0.00)
		v_92.Rotation = NumberRange.new(90.00, 90.00)
		v_92.SpreadAngle = Vector2.new(-50.0, 50.0)
		v_92.LightEmission = 0.00
		v_92.LightInfluence = 0.00
		v_92.LockedToPart = false
		v_92.ZOffset = 3.03
		v_92.Drag = 4.00
		v_92.Acceleration = Vector3.new(0.000, -20.000, 0.000)
		v_92.VelocityInheritance = 0.00
		v_92.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_92.EmissionDirection = Enum.NormalId.Top
		v_92.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_92.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5922, 0.2431, 0.8549)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5922, 0.2431, 0.8549))})
		v_92.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_92.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_92.Enabled = true
		v_92.Parent = v_81
	end
	do
		local v_93 = Instance.new("ParticleEmitter")
		v_93.Name = "Sideways Spec 17"
		refMap["93"] = v_93
		v_93.Texture = "rbxassetid://8599882518"
		v_93.Rate = 2.00
		v_93.Speed = NumberRange.new(10.00, 20.00)
		v_93.Lifetime = NumberRange.new(0.40, 1.00)
		v_93.RotSpeed = NumberRange.new(0.00, 0.00)
		v_93.Rotation = NumberRange.new(90.00, 90.00)
		v_93.SpreadAngle = Vector2.new(-30.0, 30.0)
		v_93.LightEmission = 0.00
		v_93.LightInfluence = 0.00
		v_93.LockedToPart = false
		v_93.ZOffset = 2.05
		v_93.Drag = 4.00
		v_93.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_93.VelocityInheritance = 0.00
		v_93.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_93.EmissionDirection = Enum.NormalId.Top
		v_93.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_93.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_93.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_93.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_93.Enabled = true
		v_93.Parent = v_81
	end
	do
		local v_94 = Instance.new("ParticleEmitter")
		v_94.Name = "Coloured Diagonal Smoke"
		refMap["94"] = v_94
		v_94.Texture = "rbxassetid://13724252630"
		v_94.Rate = 1.00
		v_94.Speed = NumberRange.new(10.00, 20.00)
		v_94.Lifetime = NumberRange.new(1.00, 2.00)
		v_94.RotSpeed = NumberRange.new(0.00, 0.00)
		v_94.Rotation = NumberRange.new(15.00, 15.00)
		v_94.SpreadAngle = Vector2.new(0.0, 0.0)
		v_94.LightEmission = 0.00
		v_94.LightInfluence = 0.00
		v_94.LockedToPart = false
		v_94.ZOffset = 2.03
		v_94.Drag = 4.00
		v_94.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_94.VelocityInheritance = 0.00
		v_94.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
		v_94.EmissionDirection = Enum.NormalId.Top
		v_94.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_94.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5914, 0.2429, 0.8561)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5914, 0.2429, 0.8561))})
		v_94.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.430, 0.000), NumberSequenceKeypoint.new(0.42, 3.670, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_94.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.427, 0.000), NumberSequenceKeypoint.new(0.39, 0.553, 0.000), NumberSequenceKeypoint.new(0.75, 0.720, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_94.Enabled = true
		v_94.Parent = v_81
	end
	do
		local v_95 = Instance.new("WeldConstraint")
		v_95.Name = "Part_Weld"
		refMap["95"] = v_95
		v_95.Parent = v_81
	end
	end
	end
	end

	for _, pending in ipairs(pendingRefs) do
		local target = refMap[pending.ref]
		if target then
			pending.obj[pending.prop] = target
		end
	end
end

local function buildAura13(auraFolder: Folder)
	local refMap = {}
	local pendingRefs = {}

	do
		local v_0 = Instance.new("Model")
		v_0.Name = "Aura13"
		refMap["0"] = v_0
		v_0:SetAttribute("CosmeticType", "Aura")
		v_0:SetAttribute("CosmeticId", "Aura13")
		v_0:SetAttribute("TargetPart", "HumanoidRootPart")
		v_0:SetAttribute("SupportsR6", true)
		v_0:SetAttribute("SupportsR15", true)
		v_0.Parent = auraFolder
	do
		local v_1 = Instance.new("CFrameValue")
		v_1.Name = "LocalOffset"
		refMap["2"] = v_1
		v_1.Value = CFrame.new(0.000, -0.500, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_1.Parent = v_0
	end
	do
		local v_2 = Instance.new("Part")
		v_2.Name = "EffectHolder"
		refMap["1"] = v_2
		v_2.Anchored = false
		v_2.CanCollide = false
		v_2.CanTouch = false
		v_2.CanQuery = false
		v_2.Massless = true
		v_2.CastShadow = false
		v_2.Transparency = 1.00
		v_2.Size = Vector3.new(4.000, 6.000, 3.000)
		v_2.CFrame = CFrame.new(-140.500, 22.000, -14.000, 0.000, 0.000, -1.000, 0.000, 1.000, 0.000, 1.000, 0.000, 0.000)
		v_2.Color = Color3.fromRGB(163, 162, 165)
		v_2.Parent = v_0
	do
		local v_3 = Instance.new("Part")
		v_3.Name = "inwardbezier"
		refMap["3"] = v_3
		v_3.Anchored = false
		v_3.CanCollide = false
		v_3.CanTouch = false
		v_3.CanQuery = false
		v_3.Massless = true
		v_3.CastShadow = false
		v_3.Transparency = 1.00
		v_3.Size = Vector3.new(10.000, 10.000, 10.000)
		v_3.CFrame = CFrame.new(-140.543, 22.031, -14.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_3.Color = Color3.fromRGB(248, 248, 248)
		v_3.Parent = v_2
	do
		local v_4 = Instance.new("Attachment")
		v_4.Name = "Bezier"
		refMap["4"] = v_4
		v_4.CFrame = CFrame.new(0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_4.Parent = v_3
	do
		local v_5 = Instance.new("Part")
		v_5.Name = "Part"
		refMap["5"] = v_5
		v_5.Anchored = false
		v_5.CanCollide = false
		v_5.CanTouch = false
		v_5.CanQuery = false
		v_5.Massless = true
		v_5.CastShadow = false
		v_5.Transparency = 1.00
		v_5.Size = Vector3.new(0.400, 0.400, 0.400)
		v_5.CFrame = CFrame.new(-140.543, 22.031, -14.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_5.Color = Color3.fromRGB(248, 248, 248)
		v_5.Parent = v_4
	do
		local v_6 = Instance.new("Attachment")
		v_6.Name = "0"
		refMap["6"] = v_6
		v_6.CFrame = CFrame.new(-0.022, 0.000, 0.316, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_6.Parent = v_5
	end
	do
		local v_7 = Instance.new("Attachment")
		v_7.Name = "1"
		refMap["7"] = v_7
		v_7.CFrame = CFrame.new(-0.031, 0.000, -0.301, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_7.Parent = v_5
	end
	do
		local v_8 = Instance.new("Trail")
		v_8.Name = "cursed energy trail 2"
		refMap["8"] = v_8
		v_8.Texture = "rbxassetid://119952780050980"
		v_8.Lifetime = 0.30
		v_8.MinLength = 0.00
		v_8.LightEmission = 0.00
		v_8.LightInfluence = 0.00
		v_8.FaceCamera = true
		v_8.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_8.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.17, 0.287, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_8.Enabled = true
		table.insert(pendingRefs, { obj = v_8, prop = "Attachment0", ref = "6" })
		table.insert(pendingRefs, { obj = v_8, prop = "Attachment1", ref = "7" })
		v_8.Parent = v_5
	end
	end
	do
		local v_9 = Instance.new("Attachment")
		v_9.Name = "Points"
		refMap["9"] = v_9
		v_9.CFrame = CFrame.new(0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_9.Parent = v_4
	do
		local v_10 = Instance.new("Attachment")
		v_10.Name = "2"
		refMap["10"] = v_10
		v_10.CFrame = CFrame.new(0.898, -0.143, -15.205, -0.000, 0.000, -1.000, 0.000, 1.000, 0.000, 1.000, 0.000, -0.000)
		v_10.Parent = v_9
	do
		local v_11 = Instance.new("Attachment")
		v_11.Name = "T1"
		refMap["11"] = v_11
		v_11.CFrame = CFrame.new(2.300, 6.629, 1.667, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_11.Parent = v_10
	end
	end
	do
		local v_12 = Instance.new("Attachment")
		v_12.Name = "1"
		refMap["12"] = v_12
		v_12.CFrame = CFrame.new(0.000, 0.000, 3.716, 0.000, 0.000, -1.000, 0.000, 1.000, 0.000, 1.000, 0.000, 0.000)
		v_12.Parent = v_9
	do
		local v_13 = Instance.new("Attachment")
		v_13.Name = "T0"
		refMap["13"] = v_13
		v_13.CFrame = CFrame.new(-2.589, -7.266, -0.197, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_13.Parent = v_12
	end
	end
	end
	do
		local v_14 = Instance.new("Attachment")
		v_14.Name = "End"
		refMap["14"] = v_14
		v_14.CFrame = CFrame.new(0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_14.Parent = v_4
	end
	end
	do
		local v_15 = Instance.new("Attachment")
		v_15.Name = "Bezier"
		refMap["15"] = v_15
		v_15.CFrame = CFrame.new(0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_15.Parent = v_3
	do
		local v_16 = Instance.new("Attachment")
		v_16.Name = "Points"
		refMap["16"] = v_16
		v_16.CFrame = CFrame.new(0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_16.Parent = v_15
	do
		local v_17 = Instance.new("Attachment")
		v_17.Name = "2"
		refMap["17"] = v_17
		v_17.CFrame = CFrame.new(0.898, -0.143, -15.205, -0.000, 0.000, -1.000, 0.000, 1.000, 0.000, 1.000, 0.000, -0.000)
		v_17.Parent = v_16
	do
		local v_18 = Instance.new("Attachment")
		v_18.Name = "T1"
		refMap["18"] = v_18
		v_18.CFrame = CFrame.new(2.300, 6.629, 1.667, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_18.Parent = v_17
	end
	end
	do
		local v_19 = Instance.new("Attachment")
		v_19.Name = "1"
		refMap["19"] = v_19
		v_19.CFrame = CFrame.new(0.000, 0.000, 3.716, 0.000, 0.000, -1.000, 0.000, 1.000, 0.000, 1.000, 0.000, 0.000)
		v_19.Parent = v_16
	do
		local v_20 = Instance.new("Attachment")
		v_20.Name = "T0"
		refMap["20"] = v_20
		v_20.CFrame = CFrame.new(-2.589, -7.266, -0.197, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_20.Parent = v_19
	end
	end
	end
	do
		local v_21 = Instance.new("Attachment")
		v_21.Name = "End"
		refMap["21"] = v_21
		v_21.CFrame = CFrame.new(0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_21.Parent = v_15
	end
	do
		local v_22 = Instance.new("Part")
		v_22.Name = "Part"
		refMap["22"] = v_22
		v_22.Anchored = false
		v_22.CanCollide = false
		v_22.CanTouch = false
		v_22.CanQuery = false
		v_22.Massless = true
		v_22.CastShadow = false
		v_22.Transparency = 1.00
		v_22.Size = Vector3.new(0.400, 0.400, 0.400)
		v_22.CFrame = CFrame.new(-140.543, 22.031, -14.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_22.Color = Color3.fromRGB(248, 248, 248)
		v_22.Parent = v_15
	do
		local v_23 = Instance.new("Attachment")
		v_23.Name = "0"
		refMap["23"] = v_23
		v_23.CFrame = CFrame.new(-0.023, 0.000, 0.284, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_23.Parent = v_22
	end
	do
		local v_24 = Instance.new("Trail")
		v_24.Name = "Beam88"
		refMap["24"] = v_24
		v_24.Texture = "rbxassetid://133860736415104"
		v_24.Lifetime = 0.30
		v_24.MinLength = 0.00
		v_24.LightEmission = 0.00
		v_24.LightInfluence = 0.00
		v_24.FaceCamera = true
		v_24.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_24.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_24.Enabled = true
		table.insert(pendingRefs, { obj = v_24, prop = "Attachment0", ref = "23" })
		table.insert(pendingRefs, { obj = v_24, prop = "Attachment1", ref = "25" })
		v_24.Parent = v_22
	end
	do
		local v_25 = Instance.new("Attachment")
		v_25.Name = "1"
		refMap["25"] = v_25
		v_25.CFrame = CFrame.new(-0.031, 0.000, -0.269, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_25.Parent = v_22
	end
	end
	end
	do
		local v_26 = Instance.new("WeldConstraint")
		v_26.Name = "inwardbezier_Weld"
		refMap["26"] = v_26
		v_26.Parent = v_3
	end
	end
	do
		local v_27 = Instance.new("Attachment")
		v_27.Name = "Attachment"
		refMap["27"] = v_27
		v_27.CFrame = CFrame.new(0.000, -3.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_27.Parent = v_2
	do
		local v_28 = Instance.new("ParticleEmitter")
		v_28.Name = "Thin realistic shockwave"
		refMap["28"] = v_28
		v_28.Texture = "rbxassetid://12906276200"
		v_28.Rate = 2.00
		v_28.Speed = NumberRange.new(0.00, 0.00)
		v_28.Lifetime = NumberRange.new(1.00, 2.00)
		v_28.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_28.Rotation = NumberRange.new(-360.00, 360.00)
		v_28.SpreadAngle = Vector2.new(-30.0, 20.0)
		v_28.LightEmission = 0.00
		v_28.LightInfluence = 0.00
		v_28.LockedToPart = true
		v_28.ZOffset = 1.07
		v_28.Drag = 0.00
		v_28.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_28.VelocityInheritance = 0.00
		v_28.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_28.EmissionDirection = Enum.NormalId.Top
		v_28.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_28.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.2353, 0.5725, 0.6745)), ColorSequenceKeypoint.new(1.00, Color3.new(0.2353, 0.5725, 0.6745))})
		v_28.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.17, 5.586, 0.000), NumberSequenceKeypoint.new(1.00, 9.058, 0.000)})
		v_28.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.247, 0.000), NumberSequenceKeypoint.new(0.90, 0.577, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_28.Enabled = true
		v_28.Parent = v_27
	end
	do
		local v_29 = Instance.new("ParticleEmitter")
		v_29.Name = "weird shockwave"
		refMap["29"] = v_29
		v_29.Texture = "rbxassetid://16940431172"
		v_29.Rate = 2.00
		v_29.Speed = NumberRange.new(0.00, 0.00)
		v_29.Lifetime = NumberRange.new(1.00, 2.00)
		v_29.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_29.Rotation = NumberRange.new(-360.00, 360.00)
		v_29.SpreadAngle = Vector2.new(0.0, 0.0)
		v_29.LightEmission = 0.00
		v_29.LightInfluence = 0.00
		v_29.LockedToPart = true
		v_29.ZOffset = 1.04
		v_29.Drag = 0.00
		v_29.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_29.VelocityInheritance = 0.00
		v_29.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_29.EmissionDirection = Enum.NormalId.Top
		v_29.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(0.24, Color3.new(0.1347, 0.3250, 0.3845)), ColorSequenceKeypoint.new(0.45, Color3.new(0.0526, 0.1250, 0.1487)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0431, 0.1020, 0.1216))})
		v_29.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.17, 4.256, 0.000), NumberSequenceKeypoint.new(0.49, 6.419, 0.000), NumberSequenceKeypoint.new(1.00, 6.902, 0.000)})
		v_29.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.180, 0.000), NumberSequenceKeypoint.new(0.59, 0.370, 0.000), NumberSequenceKeypoint.new(0.82, 0.617, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_29.Enabled = true
		v_29.Parent = v_27
	end
	do
		local v_30 = Instance.new("ParticleEmitter")
		v_30.Name = "windfs"
		refMap["30"] = v_30
		v_30.Texture = "rbxassetid://135128020878697"
		v_30.Rate = 2.00
		v_30.Speed = NumberRange.new(0.00, 0.00)
		v_30.Lifetime = NumberRange.new(1.00, 2.00)
		v_30.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_30.Rotation = NumberRange.new(-360.00, 360.00)
		v_30.SpreadAngle = Vector2.new(-30.0, 20.0)
		v_30.LightEmission = 0.00
		v_30.LightInfluence = 0.00
		v_30.LockedToPart = true
		v_30.ZOffset = 1.04
		v_30.Drag = 0.00
		v_30.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_30.VelocityInheritance = 0.00
		v_30.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_30.EmissionDirection = Enum.NormalId.Top
		v_30.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(0.24, Color3.new(0.1347, 0.3250, 0.3845)), ColorSequenceKeypoint.new(0.45, Color3.new(0.0526, 0.1250, 0.1487)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0431, 0.1020, 0.1216))})
		v_30.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.17, 3.700, 0.000), NumberSequenceKeypoint.new(1.00, 6.000, 0.000)})
		v_30.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_30.Enabled = true
		v_30.Parent = v_27
	end
	do
		local v_31 = Instance.new("ParticleEmitter")
		v_31.Name = "another shockwave"
		refMap["31"] = v_31
		v_31.Texture = "rbxassetid://13582043821"
		v_31.Rate = 2.00
		v_31.Speed = NumberRange.new(0.00, 0.00)
		v_31.Lifetime = NumberRange.new(1.00, 2.00)
		v_31.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_31.Rotation = NumberRange.new(-360.00, 360.00)
		v_31.SpreadAngle = Vector2.new(0.0, 0.0)
		v_31.LightEmission = 0.00
		v_31.LightInfluence = 0.00
		v_31.LockedToPart = true
		v_31.ZOffset = 2.01
		v_31.Drag = 0.00
		v_31.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_31.VelocityInheritance = 0.00
		v_31.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_31.EmissionDirection = Enum.NormalId.Top
		v_31.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(0.24, Color3.new(0.1347, 0.3250, 0.3845)), ColorSequenceKeypoint.new(0.45, Color3.new(0.0526, 0.1250, 0.1487)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0431, 0.1020, 0.1216))})
		v_31.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.17, 5.639, 0.000), NumberSequenceKeypoint.new(0.49, 8.504, 0.000), NumberSequenceKeypoint.new(1.00, 9.144, 0.000)})
		v_31.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.427, 0.000), NumberSequenceKeypoint.new(0.54, 0.627, 0.000), NumberSequenceKeypoint.new(0.76, 0.737, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_31.Enabled = true
		v_31.Parent = v_27
	end
	do
		local v_32 = Instance.new("ParticleEmitter")
		v_32.Name = "Smokey Crescent"
		refMap["32"] = v_32
		v_32.Texture = "rbxassetid://17085222506"
		v_32.Rate = 2.00
		v_32.Speed = NumberRange.new(0.00, 0.00)
		v_32.Lifetime = NumberRange.new(1.00, 2.00)
		v_32.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_32.Rotation = NumberRange.new(-360.00, 360.00)
		v_32.SpreadAngle = Vector2.new(-30.0, 20.0)
		v_32.LightEmission = 0.00
		v_32.LightInfluence = 0.00
		v_32.LockedToPart = true
		v_32.ZOffset = 1.03
		v_32.Drag = 0.00
		v_32.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_32.VelocityInheritance = 0.00
		v_32.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_32.EmissionDirection = Enum.NormalId.Top
		v_32.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_32.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(0.24, Color3.new(0.1347, 0.3250, 0.3845)), ColorSequenceKeypoint.new(0.45, Color3.new(0.0526, 0.1250, 0.1487)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0431, 0.1020, 0.1216))})
		v_32.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.17, 3.700, 0.000), NumberSequenceKeypoint.new(1.00, 6.000, 0.000)})
		v_32.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_32.Enabled = true
		v_32.Parent = v_27
	end
	do
		local v_33 = Instance.new("ParticleEmitter")
		v_33.Name = "cursed energy 2"
		refMap["33"] = v_33
		v_33.Texture = "rbxassetid://78422400450982"
		v_33.Rate = 2.00
		v_33.Speed = NumberRange.new(0.00, 0.00)
		v_33.Lifetime = NumberRange.new(1.00, 2.00)
		v_33.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_33.Rotation = NumberRange.new(-360.00, 360.00)
		v_33.SpreadAngle = Vector2.new(0.0, 0.0)
		v_33.LightEmission = 0.00
		v_33.LightInfluence = 0.00
		v_33.LockedToPart = true
		v_33.ZOffset = 1.03
		v_33.Drag = 0.00
		v_33.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_33.VelocityInheritance = 0.00
		v_33.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_33.EmissionDirection = Enum.NormalId.Top
		v_33.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.2353, 0.5725, 0.6745)), ColorSequenceKeypoint.new(1.00, Color3.new(0.2353, 0.5725, 0.6745))})
		v_33.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.17, 3.840, 0.000), NumberSequenceKeypoint.new(1.00, 6.227, 0.000)})
		v_33.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.247, 0.000), NumberSequenceKeypoint.new(0.90, 0.577, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_33.Enabled = true
		v_33.Parent = v_27
	end
	do
		local v_34 = Instance.new("ParticleEmitter")
		v_34.Name = "grainy shockwave 2"
		refMap["34"] = v_34
		v_34.Texture = "rbxassetid://16509144751"
		v_34.Rate = 2.00
		v_34.Speed = NumberRange.new(0.00, 0.00)
		v_34.Lifetime = NumberRange.new(1.00, 2.00)
		v_34.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_34.Rotation = NumberRange.new(-360.00, 360.00)
		v_34.SpreadAngle = Vector2.new(0.0, 0.0)
		v_34.LightEmission = 0.00
		v_34.LightInfluence = 0.00
		v_34.LockedToPart = true
		v_34.ZOffset = 1.02
		v_34.Drag = 0.00
		v_34.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_34.VelocityInheritance = 0.00
		v_34.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_34.EmissionDirection = Enum.NormalId.Top
		v_34.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(0.24, Color3.new(0.1347, 0.3250, 0.3845)), ColorSequenceKeypoint.new(0.45, Color3.new(0.0526, 0.1250, 0.1487)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0431, 0.1020, 0.1216))})
		v_34.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.17, 5.639, 0.000), NumberSequenceKeypoint.new(0.49, 8.504, 0.000), NumberSequenceKeypoint.new(1.00, 9.144, 0.000)})
		v_34.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.427, 0.000), NumberSequenceKeypoint.new(0.54, 0.627, 0.000), NumberSequenceKeypoint.new(0.76, 0.737, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_34.Enabled = true
		v_34.Parent = v_27
	end
	do
		local v_35 = Instance.new("ParticleEmitter")
		v_35.Name = "cursed energy 2"
		refMap["35"] = v_35
		v_35.Texture = "rbxassetid://78422400450982"
		v_35.Rate = 2.00
		v_35.Speed = NumberRange.new(0.00, 0.00)
		v_35.Lifetime = NumberRange.new(1.00, 2.00)
		v_35.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_35.Rotation = NumberRange.new(-360.00, 360.00)
		v_35.SpreadAngle = Vector2.new(0.0, 0.0)
		v_35.LightEmission = 0.00
		v_35.LightInfluence = 0.00
		v_35.LockedToPart = true
		v_35.ZOffset = 1.01
		v_35.Drag = 0.00
		v_35.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_35.VelocityInheritance = 0.00
		v_35.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_35.EmissionDirection = Enum.NormalId.Top
		v_35.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.2353, 0.5725, 0.6745)), ColorSequenceKeypoint.new(1.00, Color3.new(0.2353, 0.5725, 0.6745))})
		v_35.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.17, 4.745, 0.000), NumberSequenceKeypoint.new(1.00, 7.694, 0.000)})
		v_35.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.247, 0.000), NumberSequenceKeypoint.new(0.90, 0.577, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_35.Enabled = true
		v_35.Parent = v_27
	end
	end
	do
		local v_36 = Instance.new("Attachment")
		v_36.Name = "Attachment"
		refMap["36"] = v_36
		v_36.CFrame = CFrame.new(0.000, 1.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_36.Parent = v_2
	do
		local v_37 = Instance.new("ParticleEmitter")
		v_37.Name = "cursed energy 3"
		refMap["37"] = v_37
		v_37.Texture = "rbxassetid://17006174840"
		v_37.Rate = 1.00
		v_37.Speed = NumberRange.new(0.00, 0.00)
		v_37.Lifetime = NumberRange.new(2.00, 2.00)
		v_37.RotSpeed = NumberRange.new(0.00, 0.00)
		v_37.Rotation = NumberRange.new(0.00, 0.00)
		v_37.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_37.LightEmission = 0.00
		v_37.LightInfluence = 0.00
		v_37.LockedToPart = true
		v_37.ZOffset = 0.01
		v_37.Drag = 2.00
		v_37.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_37.VelocityInheritance = 0.00
		v_37.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
		v_37.EmissionDirection = Enum.NormalId.Top
		v_37.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_37.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 5.484, 0.000), NumberSequenceKeypoint.new(0.48, 7.938, 0.000), NumberSequenceKeypoint.new(1.00, 8.659, 0.000)})
		v_37.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.360, 0.000), NumberSequenceKeypoint.new(0.63, 0.567, 0.000), NumberSequenceKeypoint.new(0.82, 0.740, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_37.Enabled = true
		v_37.Parent = v_36
	end
	do
		local v_38 = Instance.new("ParticleEmitter")
		v_38.Name = "Iso cursed"
		refMap["38"] = v_38
		v_38.Texture = "rbxassetid://102330699321283"
		v_38.Rate = 1.00
		v_38.Speed = NumberRange.new(0.00, 0.00)
		v_38.Lifetime = NumberRange.new(2.00, 2.00)
		v_38.RotSpeed = NumberRange.new(0.00, 0.00)
		v_38.Rotation = NumberRange.new(0.00, 0.00)
		v_38.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_38.LightEmission = 0.00
		v_38.LightInfluence = 0.00
		v_38.LockedToPart = true
		v_38.ZOffset = 0.02
		v_38.Drag = 2.00
		v_38.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_38.VelocityInheritance = 0.00
		v_38.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
		v_38.EmissionDirection = Enum.NormalId.Top
		v_38.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_38.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 5.484, 0.000), NumberSequenceKeypoint.new(0.48, 7.938, 0.000), NumberSequenceKeypoint.new(1.00, 8.659, 0.000)})
		v_38.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.360, 0.000), NumberSequenceKeypoint.new(0.63, 0.567, 0.000), NumberSequenceKeypoint.new(0.82, 0.740, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_38.Enabled = true
		v_38.Parent = v_36
	end
	do
		local v_39 = Instance.new("ParticleEmitter")
		v_39.Name = "cursed energy min"
		refMap["39"] = v_39
		v_39.Texture = "rbxassetid://125843391083656"
		v_39.Rate = 1.00
		v_39.Speed = NumberRange.new(0.00, 0.00)
		v_39.Lifetime = NumberRange.new(2.00, 2.00)
		v_39.RotSpeed = NumberRange.new(0.00, 0.00)
		v_39.Rotation = NumberRange.new(0.00, 0.00)
		v_39.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_39.LightEmission = 0.00
		v_39.LightInfluence = 0.00
		v_39.LockedToPart = true
		v_39.ZOffset = 0.02
		v_39.Drag = 2.00
		v_39.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_39.VelocityInheritance = 0.00
		v_39.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
		v_39.EmissionDirection = Enum.NormalId.Top
		v_39.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_39.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 4.439, 0.000), NumberSequenceKeypoint.new(0.48, 6.424, 0.000), NumberSequenceKeypoint.new(1.00, 7.008, 0.000)})
		v_39.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.360, 0.000), NumberSequenceKeypoint.new(0.63, 0.567, 0.000), NumberSequenceKeypoint.new(0.82, 0.740, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_39.Enabled = true
		v_39.Parent = v_36
	end
	do
		local v_40 = Instance.new("ParticleEmitter")
		v_40.Name = "Triangle Top"
		refMap["40"] = v_40
		v_40.Texture = "rbxassetid://15009885079"
		v_40.Rate = 4.00
		v_40.Speed = NumberRange.new(0.00, 0.00)
		v_40.Lifetime = NumberRange.new(0.40, 1.00)
		v_40.RotSpeed = NumberRange.new(0.00, 0.00)
		v_40.Rotation = NumberRange.new(0.00, 0.00)
		v_40.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_40.LightEmission = 0.00
		v_40.LightInfluence = 0.00
		v_40.LockedToPart = true
		v_40.ZOffset = 1.00
		v_40.Drag = 2.00
		v_40.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_40.VelocityInheritance = 0.00
		v_40.Orientation = Enum.ParticleOrientation.FacingCamera
		v_40.EmissionDirection = Enum.NormalId.Top
		v_40.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8
		v_40.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_40.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.15, 2.900, 0.828), NumberSequenceKeypoint.new(0.42, 4.272, 0.902), NumberSequenceKeypoint.new(1.00, 4.683, 1.053)})
		v_40.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.263, 0.000), NumberSequenceKeypoint.new(0.85, 0.557, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_40.Enabled = true
		v_40.Parent = v_36
	end
	end
	do
		local v_41 = Instance.new("Attachment")
		v_41.Name = "Attachment"
		refMap["41"] = v_41
		v_41.CFrame = CFrame.new(0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_41.Parent = v_2
	do
		local v_42 = Instance.new("ParticleEmitter")
		v_42.Name = "cursed energy 2"
		refMap["42"] = v_42
		v_42.Texture = "rbxassetid://78422400450982"
		v_42.Rate = 2.00
		v_42.Speed = NumberRange.new(0.00, 0.00)
		v_42.Lifetime = NumberRange.new(0.40, 1.00)
		v_42.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_42.Rotation = NumberRange.new(-360.00, 360.00)
		v_42.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_42.LightEmission = 0.00
		v_42.LightInfluence = 0.00
		v_42.LockedToPart = true
		v_42.ZOffset = 2.07
		v_42.Drag = 2.00
		v_42.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_42.VelocityInheritance = 0.00
		v_42.Orientation = Enum.ParticleOrientation.FacingCamera
		v_42.EmissionDirection = Enum.NormalId.Top
		v_42.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_42.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.533, 0.000), NumberSequenceKeypoint.new(0.48, 3.667, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_42.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_42.Enabled = true
		v_42.Parent = v_41
	end
	do
		local v_43 = Instance.new("ParticleEmitter")
		v_43.Name = "cursed energy1"
		refMap["43"] = v_43
		v_43.Texture = "rbxassetid://112387970399345"
		v_43.Rate = 2.00
		v_43.Speed = NumberRange.new(0.00, 0.00)
		v_43.Lifetime = NumberRange.new(0.40, 1.00)
		v_43.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_43.Rotation = NumberRange.new(-360.00, 360.00)
		v_43.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_43.LightEmission = 0.00
		v_43.LightInfluence = 0.00
		v_43.LockedToPart = true
		v_43.ZOffset = 1.03
		v_43.Drag = 2.00
		v_43.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_43.VelocityInheritance = 0.00
		v_43.Orientation = Enum.ParticleOrientation.FacingCamera
		v_43.EmissionDirection = Enum.NormalId.Top
		v_43.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_43.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.862, 0.000), NumberSequenceKeypoint.new(0.48, 4.143, 0.000), NumberSequenceKeypoint.new(1.00, 4.519, 0.000)})
		v_43.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_43.Enabled = true
		v_43.Parent = v_41
	end
	do
		local v_44 = Instance.new("ParticleEmitter")
		v_44.Name = "Fire45"
		refMap["44"] = v_44
		v_44.Texture = "rbxassetid://16860419961"
		v_44.Rate = 3.00
		v_44.Speed = NumberRange.new(0.00, 0.00)
		v_44.Lifetime = NumberRange.new(0.40, 1.00)
		v_44.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_44.Rotation = NumberRange.new(-360.00, 360.00)
		v_44.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_44.LightEmission = 0.00
		v_44.LightInfluence = 0.00
		v_44.LockedToPart = true
		v_44.ZOffset = 2.03
		v_44.Drag = 2.00
		v_44.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_44.VelocityInheritance = 0.00
		v_44.Orientation = Enum.ParticleOrientation.FacingCamera
		v_44.EmissionDirection = Enum.NormalId.Top
		v_44.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_44.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_44.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 5.067, 0.000), NumberSequenceKeypoint.new(0.48, 7.333, 0.000), NumberSequenceKeypoint.new(1.00, 8.000, 0.000)})
		v_44.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_44.Enabled = true
		v_44.Parent = v_41
	end
	do
		local v_45 = Instance.new("ParticleEmitter")
		v_45.Name = "cursed energy spec"
		refMap["45"] = v_45
		v_45.Texture = "rbxassetid://85688545954016"
		v_45.Rate = 2.00
		v_45.Speed = NumberRange.new(10.00, 20.00)
		v_45.Lifetime = NumberRange.new(0.40, 1.00)
		v_45.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_45.Rotation = NumberRange.new(-360.00, 360.00)
		v_45.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_45.LightEmission = 0.00
		v_45.LightInfluence = 0.00
		v_45.LockedToPart = false
		v_45.ZOffset = 2.04
		v_45.Drag = 4.00
		v_45.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_45.VelocityInheritance = 0.00
		v_45.Orientation = Enum.ParticleOrientation.FacingCamera
		v_45.EmissionDirection = Enum.NormalId.Top
		v_45.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_45.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_45.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_45.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_45.Enabled = true
		v_45.Parent = v_41
	end
	do
		local v_46 = Instance.new("ParticleEmitter")
		v_46.Name = "Cursed Energy Disperse 8x8"
		refMap["46"] = v_46
		v_46.Texture = "rbxassetid://97051019398375"
		v_46.Rate = 2.00
		v_46.Speed = NumberRange.new(14.00, 20.00)
		v_46.Lifetime = NumberRange.new(0.40, 1.00)
		v_46.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_46.Rotation = NumberRange.new(-360.00, 360.00)
		v_46.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_46.LightEmission = 0.00
		v_46.LightInfluence = 0.00
		v_46.LockedToPart = true
		v_46.ZOffset = 1.02
		v_46.Drag = 7.00
		v_46.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_46.VelocityInheritance = 0.00
		v_46.Orientation = Enum.ParticleOrientation.FacingCamera
		v_46.EmissionDirection = Enum.NormalId.Top
		v_46.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8
		v_46.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_46.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.862, 0.000), NumberSequenceKeypoint.new(0.48, 4.143, 0.000), NumberSequenceKeypoint.new(1.00, 4.519, 0.000)})
		v_46.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.317, 0.000), NumberSequenceKeypoint.new(0.86, 0.683, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_46.Enabled = true
		v_46.Parent = v_41
	end
	do
		local v_47 = Instance.new("ParticleEmitter")
		v_47.Name = "cat spec 7"
		refMap["47"] = v_47
		v_47.Texture = "rbxassetid://90414839644727"
		v_47.Rate = 2.00
		v_47.Speed = NumberRange.new(12.93, 25.87)
		v_47.Lifetime = NumberRange.new(0.40, 1.00)
		v_47.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_47.Rotation = NumberRange.new(-360.00, 360.00)
		v_47.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_47.LightEmission = 0.00
		v_47.LightInfluence = 0.00
		v_47.LockedToPart = false
		v_47.ZOffset = 2.02
		v_47.Drag = 4.00
		v_47.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_47.VelocityInheritance = 0.00
		v_47.Orientation = Enum.ParticleOrientation.FacingCamera
		v_47.EmissionDirection = Enum.NormalId.Top
		v_47.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_47.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_47.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.996, 0.000), NumberSequenceKeypoint.new(0.73, 0.621, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_47.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_47.Enabled = true
		v_47.Parent = v_41
	end
	do
		local v_48 = Instance.new("ParticleEmitter")
		v_48.Name = "Light Ray"
		refMap["48"] = v_48
		v_48.Texture = "rbxassetid://14128173698"
		v_48.Rate = 4.00
		v_48.Speed = NumberRange.new(0.00, 0.00)
		v_48.Lifetime = NumberRange.new(0.40, 1.00)
		v_48.RotSpeed = NumberRange.new(30.00, 50.00)
		v_48.Rotation = NumberRange.new(0.00, 0.00)
		v_48.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_48.LightEmission = 0.00
		v_48.LightInfluence = 0.00
		v_48.LockedToPart = true
		v_48.ZOffset = 1.00
		v_48.Drag = 2.00
		v_48.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_48.VelocityInheritance = 0.00
		v_48.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_48.EmissionDirection = Enum.NormalId.Top
		v_48.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_48.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_48.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.15, 2.504, 0.715), NumberSequenceKeypoint.new(0.42, 3.688, 0.779), NumberSequenceKeypoint.new(1.00, 4.043, 0.909)})
		v_48.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.263, 0.000), NumberSequenceKeypoint.new(0.85, 0.557, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_48.Enabled = true
		v_48.Parent = v_41
	end
	do
		local v_49 = Instance.new("ParticleEmitter")
		v_49.Name = "Strange VFX"
		refMap["49"] = v_49
		v_49.Texture = "rbxassetid://18369800560"
		v_49.Rate = 3.00
		v_49.Speed = NumberRange.new(0.00, 0.00)
		v_49.Lifetime = NumberRange.new(0.70, 2.00)
		v_49.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_49.Rotation = NumberRange.new(-360.00, 360.00)
		v_49.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_49.LightEmission = 0.00
		v_49.LightInfluence = 0.00
		v_49.LockedToPart = true
		v_49.ZOffset = 1.02
		v_49.Drag = 2.00
		v_49.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_49.VelocityInheritance = 0.00
		v_49.Orientation = Enum.ParticleOrientation.FacingCamera
		v_49.EmissionDirection = Enum.NormalId.Top
		v_49.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_49.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_49.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.862, 0.000), NumberSequenceKeypoint.new(0.48, 4.143, 0.000), NumberSequenceKeypoint.new(1.00, 4.519, 0.000)})
		v_49.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_49.Enabled = true
		v_49.Parent = v_41
	end
	do
		local v_50 = Instance.new("ParticleEmitter")
		v_50.Name = "Cat 3"
		refMap["50"] = v_50
		v_50.Texture = "rbxassetid://77336442156503"
		v_50.Rate = 2.00
		v_50.Speed = NumberRange.new(0.00, 0.00)
		v_50.Lifetime = NumberRange.new(0.40, 1.00)
		v_50.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_50.Rotation = NumberRange.new(-360.00, 360.00)
		v_50.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_50.LightEmission = 0.00
		v_50.LightInfluence = 0.00
		v_50.LockedToPart = true
		v_50.ZOffset = 2.01
		v_50.Drag = 2.00
		v_50.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_50.VelocityInheritance = 0.00
		v_50.Orientation = Enum.ParticleOrientation.FacingCamera
		v_50.EmissionDirection = Enum.NormalId.Top
		v_50.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_50.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_50.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.533, 0.000), NumberSequenceKeypoint.new(0.48, 3.667, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_50.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.263, 0.000), NumberSequenceKeypoint.new(0.85, 0.557, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_50.Enabled = true
		v_50.Parent = v_41
	end
	do
		local v_51 = Instance.new("ParticleEmitter")
		v_51.Name = "Thin realistic shockwave"
		refMap["51"] = v_51
		v_51.Texture = "rbxassetid://12906276200"
		v_51.Rate = 2.00
		v_51.Speed = NumberRange.new(0.00, 0.00)
		v_51.Lifetime = NumberRange.new(0.40, 1.00)
		v_51.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_51.Rotation = NumberRange.new(-360.00, 360.00)
		v_51.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_51.LightEmission = 0.00
		v_51.LightInfluence = 0.00
		v_51.LockedToPart = true
		v_51.ZOffset = 2.07
		v_51.Drag = 2.00
		v_51.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_51.VelocityInheritance = 0.00
		v_51.Orientation = Enum.ParticleOrientation.FacingCamera
		v_51.EmissionDirection = Enum.NormalId.Top
		v_51.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_51.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_51.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 3.751, 0.000), NumberSequenceKeypoint.new(0.48, 5.429, 0.000), NumberSequenceKeypoint.new(1.00, 5.923, 0.000)})
		v_51.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.63, 0.343, 0.000), NumberSequenceKeypoint.new(0.89, 0.643, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_51.Enabled = true
		v_51.Parent = v_41
	end
	do
		local v_52 = Instance.new("ParticleEmitter")
		v_52.Name = "cursed energy 2"
		refMap["52"] = v_52
		v_52.Texture = "rbxassetid://78422400450982"
		v_52.Rate = 2.00
		v_52.Speed = NumberRange.new(0.00, 0.00)
		v_52.Lifetime = NumberRange.new(0.40, 1.00)
		v_52.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_52.Rotation = NumberRange.new(-360.00, 360.00)
		v_52.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_52.LightEmission = 0.00
		v_52.LightInfluence = 0.00
		v_52.LockedToPart = true
		v_52.ZOffset = 1.04
		v_52.Drag = 2.00
		v_52.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_52.VelocityInheritance = 0.00
		v_52.Orientation = Enum.ParticleOrientation.FacingCamera
		v_52.EmissionDirection = Enum.NormalId.Top
		v_52.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_52.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.862, 0.000), NumberSequenceKeypoint.new(0.48, 4.143, 0.000), NumberSequenceKeypoint.new(1.00, 4.519, 0.000)})
		v_52.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_52.Enabled = true
		v_52.Parent = v_41
	end
	do
		local v_53 = Instance.new("ParticleEmitter")
		v_53.Name = "cat spec 8"
		refMap["53"] = v_53
		v_53.Texture = "rbxassetid://101658731548844"
		v_53.Rate = 2.00
		v_53.Speed = NumberRange.new(10.00, 20.00)
		v_53.Lifetime = NumberRange.new(0.40, 1.00)
		v_53.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_53.Rotation = NumberRange.new(-360.00, 360.00)
		v_53.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_53.LightEmission = 0.00
		v_53.LightInfluence = 0.00
		v_53.LockedToPart = false
		v_53.ZOffset = 2.02
		v_53.Drag = 4.00
		v_53.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_53.VelocityInheritance = 0.00
		v_53.Orientation = Enum.ParticleOrientation.FacingCamera
		v_53.EmissionDirection = Enum.NormalId.Top
		v_53.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_53.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_53.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_53.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_53.Enabled = true
		v_53.Parent = v_41
	end
	do
		local v_54 = Instance.new("ParticleEmitter")
		v_54.Name = "Thin realistic shockwave"
		refMap["54"] = v_54
		v_54.Texture = "rbxassetid://12906276200"
		v_54.Rate = 2.00
		v_54.Speed = NumberRange.new(0.00, 0.00)
		v_54.Lifetime = NumberRange.new(0.40, 1.00)
		v_54.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_54.Rotation = NumberRange.new(-360.00, 360.00)
		v_54.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_54.LightEmission = 0.00
		v_54.LightInfluence = 0.00
		v_54.LockedToPart = true
		v_54.ZOffset = 2.05
		v_54.Drag = 2.00
		v_54.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_54.VelocityInheritance = 0.00
		v_54.Orientation = Enum.ParticleOrientation.FacingCamera
		v_54.EmissionDirection = Enum.NormalId.Top
		v_54.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_54.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_54.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.533, 0.000), NumberSequenceKeypoint.new(0.48, 3.667, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_54.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.63, 0.343, 0.000), NumberSequenceKeypoint.new(0.89, 0.643, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_54.Enabled = true
		v_54.Parent = v_41
	end
	do
		local v_55 = Instance.new("ParticleEmitter")
		v_55.Name = "grainy shockwave 2"
		refMap["55"] = v_55
		v_55.Texture = "rbxassetid://16509144751"
		v_55.Rate = 2.00
		v_55.Speed = NumberRange.new(0.00, 0.00)
		v_55.Lifetime = NumberRange.new(0.40, 1.00)
		v_55.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_55.Rotation = NumberRange.new(-360.00, 360.00)
		v_55.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_55.LightEmission = 0.00
		v_55.LightInfluence = 0.00
		v_55.LockedToPart = true
		v_55.ZOffset = 2.00
		v_55.Drag = 2.00
		v_55.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_55.VelocityInheritance = 0.00
		v_55.Orientation = Enum.ParticleOrientation.FacingCamera
		v_55.EmissionDirection = Enum.NormalId.Top
		v_55.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_55.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.533, 0.000), NumberSequenceKeypoint.new(0.48, 3.667, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_55.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.63, 0.343, 0.000), NumberSequenceKeypoint.new(0.89, 0.643, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_55.Enabled = true
		v_55.Parent = v_41
	end
	do
		local v_56 = Instance.new("ParticleEmitter")
		v_56.Name = "Bright Horizontal Star Glare 2"
		refMap["56"] = v_56
		v_56.Texture = "rbxassetid://131904221700198"
		v_56.Rate = 4.00
		v_56.Speed = NumberRange.new(0.00, 0.00)
		v_56.Lifetime = NumberRange.new(0.40, 1.00)
		v_56.RotSpeed = NumberRange.new(0.00, 0.00)
		v_56.Rotation = NumberRange.new(0.00, 0.00)
		v_56.SpreadAngle = Vector2.new(0.0, 0.0)
		v_56.LightEmission = 0.00
		v_56.LightInfluence = 0.00
		v_56.LockedToPart = true
		v_56.ZOffset = 1.00
		v_56.Drag = 2.00
		v_56.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_56.VelocityInheritance = 0.00
		v_56.Orientation = Enum.ParticleOrientation.FacingCamera
		v_56.EmissionDirection = Enum.NormalId.Top
		v_56.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_56.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_56.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.15, 3.267, 0.000), NumberSequenceKeypoint.new(0.39, 4.317, 0.000), NumberSequenceKeypoint.new(1.00, 5.000, 0.000)})
		v_56.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.263, 0.000), NumberSequenceKeypoint.new(0.85, 0.557, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_56.Enabled = true
		v_56.Parent = v_41
	end
	do
		local v_57 = Instance.new("ParticleEmitter")
		v_57.Name = "dis dark circle"
		refMap["57"] = v_57
		v_57.Texture = "rbxassetid://83617429710480"
		v_57.Rate = 2.00
		v_57.Speed = NumberRange.new(0.00, 0.00)
		v_57.Lifetime = NumberRange.new(0.40, 1.00)
		v_57.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_57.Rotation = NumberRange.new(-360.00, 360.00)
		v_57.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_57.LightEmission = 0.00
		v_57.LightInfluence = 0.00
		v_57.LockedToPart = true
		v_57.ZOffset = 2.05
		v_57.Drag = 2.00
		v_57.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_57.VelocityInheritance = 0.00
		v_57.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_57.EmissionDirection = Enum.NormalId.Top
		v_57.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_57.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.533, 0.000), NumberSequenceKeypoint.new(0.48, 3.667, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_57.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_57.Enabled = true
		v_57.Parent = v_41
	end
	do
		local v_58 = Instance.new("ParticleEmitter")
		v_58.Name = "Triangle Gradient Lens"
		refMap["58"] = v_58
		v_58.Texture = "rbxassetid://108684954560019"
		v_58.Rate = 4.00
		v_58.Speed = NumberRange.new(0.00, 0.00)
		v_58.Lifetime = NumberRange.new(0.40, 1.00)
		v_58.RotSpeed = NumberRange.new(30.00, 50.00)
		v_58.Rotation = NumberRange.new(0.00, 0.00)
		v_58.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_58.LightEmission = 0.00
		v_58.LightInfluence = 0.00
		v_58.LockedToPart = true
		v_58.ZOffset = 1.00
		v_58.Drag = 2.00
		v_58.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_58.VelocityInheritance = 0.00
		v_58.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_58.EmissionDirection = Enum.NormalId.Top
		v_58.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_58.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_58.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.15, 2.504, 0.715), NumberSequenceKeypoint.new(0.42, 3.688, 0.779), NumberSequenceKeypoint.new(1.00, 4.043, 0.909)})
		v_58.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.263, 0.000), NumberSequenceKeypoint.new(0.85, 0.557, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_58.Enabled = true
		v_58.Parent = v_41
	end
	do
		local v_59 = Instance.new("ParticleEmitter")
		v_59.Name = "Slash22"
		refMap["59"] = v_59
		v_59.Texture = "rbxassetid://121148164489745"
		v_59.Rate = 2.00
		v_59.Speed = NumberRange.new(0.00, 0.00)
		v_59.Lifetime = NumberRange.new(0.40, 1.00)
		v_59.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_59.Rotation = NumberRange.new(-360.00, 360.00)
		v_59.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_59.LightEmission = 0.00
		v_59.LightInfluence = 0.00
		v_59.LockedToPart = true
		v_59.ZOffset = 1.04
		v_59.Drag = 2.00
		v_59.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_59.VelocityInheritance = 0.00
		v_59.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_59.EmissionDirection = Enum.NormalId.Top
		v_59.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_59.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_59.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 3.410, 0.000), NumberSequenceKeypoint.new(0.48, 4.936, 0.000), NumberSequenceKeypoint.new(1.00, 5.385, 0.000)})
		v_59.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_59.Enabled = true
		v_59.Parent = v_41
	end
	do
		local v_60 = Instance.new("ParticleEmitter")
		v_60.Name = "Fire54"
		refMap["60"] = v_60
		v_60.Texture = "rbxassetid://17006155963"
		v_60.Rate = 3.00
		v_60.Speed = NumberRange.new(0.00, 0.00)
		v_60.Lifetime = NumberRange.new(0.70, 2.00)
		v_60.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_60.Rotation = NumberRange.new(-360.00, 360.00)
		v_60.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_60.LightEmission = 0.00
		v_60.LightInfluence = 0.00
		v_60.LockedToPart = true
		v_60.ZOffset = 1.07
		v_60.Drag = 2.00
		v_60.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_60.VelocityInheritance = 0.00
		v_60.Orientation = Enum.ParticleOrientation.FacingCamera
		v_60.EmissionDirection = Enum.NormalId.Top
		v_60.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_60.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_60.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.862, 0.000), NumberSequenceKeypoint.new(0.48, 4.143, 0.000), NumberSequenceKeypoint.new(1.00, 4.519, 0.000)})
		v_60.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_60.Enabled = true
		v_60.Parent = v_41
	end
	do
		local v_61 = Instance.new("ParticleEmitter")
		v_61.Name = "Strange VFX"
		refMap["61"] = v_61
		v_61.Texture = "rbxassetid://18369800560"
		v_61.Rate = 3.00
		v_61.Speed = NumberRange.new(0.00, 0.00)
		v_61.Lifetime = NumberRange.new(0.40, 1.00)
		v_61.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_61.Rotation = NumberRange.new(-360.00, 360.00)
		v_61.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_61.LightEmission = 0.00
		v_61.LightInfluence = 0.00
		v_61.LockedToPart = true
		v_61.ZOffset = 1.01
		v_61.Drag = 2.00
		v_61.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_61.VelocityInheritance = 0.00
		v_61.Orientation = Enum.ParticleOrientation.FacingCamera
		v_61.EmissionDirection = Enum.NormalId.Top
		v_61.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_61.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_61.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.533, 0.000), NumberSequenceKeypoint.new(0.48, 3.667, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_61.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_61.Enabled = true
		v_61.Parent = v_41
	end
	do
		local v_62 = Instance.new("ParticleEmitter")
		v_62.Name = "grainy shockwave 2"
		refMap["62"] = v_62
		v_62.Texture = "rbxassetid://16509144751"
		v_62.Rate = 2.00
		v_62.Speed = NumberRange.new(0.00, 0.00)
		v_62.Lifetime = NumberRange.new(0.40, 1.00)
		v_62.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_62.Rotation = NumberRange.new(-360.00, 360.00)
		v_62.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_62.LightEmission = 0.00
		v_62.LightInfluence = 0.00
		v_62.LockedToPart = true
		v_62.ZOffset = 2.04
		v_62.Drag = 2.00
		v_62.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_62.VelocityInheritance = 0.00
		v_62.Orientation = Enum.ParticleOrientation.FacingCamera
		v_62.EmissionDirection = Enum.NormalId.Top
		v_62.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_62.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 3.751, 0.000), NumberSequenceKeypoint.new(0.48, 5.429, 0.000), NumberSequenceKeypoint.new(1.00, 5.923, 0.000)})
		v_62.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.63, 0.343, 0.000), NumberSequenceKeypoint.new(0.89, 0.643, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_62.Enabled = true
		v_62.Parent = v_41
	end
	do
		local v_63 = Instance.new("ParticleEmitter")
		v_63.Name = "Strange VFX"
		refMap["63"] = v_63
		v_63.Texture = "rbxassetid://18369800560"
		v_63.Rate = 1.00
		v_63.Speed = NumberRange.new(0.00, 0.00)
		v_63.Lifetime = NumberRange.new(1.00, 2.00)
		v_63.RotSpeed = NumberRange.new(0.00, 0.00)
		v_63.Rotation = NumberRange.new(90.00, 90.00)
		v_63.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_63.LightEmission = 0.00
		v_63.LightInfluence = 0.00
		v_63.LockedToPart = true
		v_63.ZOffset = 1.03
		v_63.Drag = 2.00
		v_63.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_63.VelocityInheritance = 0.00
		v_63.Orientation = Enum.ParticleOrientation.FacingCamera
		v_63.EmissionDirection = Enum.NormalId.Top
		v_63.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_63.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_63.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 5.067, 0.000), NumberSequenceKeypoint.new(0.48, 7.333, 0.000), NumberSequenceKeypoint.new(1.00, 8.000, 0.000)})
		v_63.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.600, 0.000), NumberSequenceKeypoint.new(1.00, 0.600, 0.000)})
		v_63.Enabled = true
		v_63.Parent = v_41
	end
	do
		local v_64 = Instance.new("ParticleEmitter")
		v_64.Name = "cat spec 3"
		refMap["64"] = v_64
		v_64.Texture = "rbxassetid://136781994057492"
		v_64.Rate = 2.00
		v_64.Speed = NumberRange.new(12.93, 25.87)
		v_64.Lifetime = NumberRange.new(0.40, 1.00)
		v_64.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_64.Rotation = NumberRange.new(-360.00, 360.00)
		v_64.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_64.LightEmission = 0.00
		v_64.LightInfluence = 0.00
		v_64.LockedToPart = false
		v_64.ZOffset = 2.04
		v_64.Drag = 4.00
		v_64.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_64.VelocityInheritance = 0.00
		v_64.Orientation = Enum.ParticleOrientation.FacingCamera
		v_64.EmissionDirection = Enum.NormalId.Top
		v_64.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_64.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_64.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.996, 0.000), NumberSequenceKeypoint.new(0.73, 0.621, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_64.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_64.Enabled = true
		v_64.Parent = v_41
	end
	do
		local v_65 = Instance.new("ParticleEmitter")
		v_65.Name = "cursed energy3421"
		refMap["65"] = v_65
		v_65.Texture = "rbxassetid://17006172452"
		v_65.Rate = 2.00
		v_65.Speed = NumberRange.new(0.00, 0.00)
		v_65.Lifetime = NumberRange.new(0.40, 1.00)
		v_65.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_65.Rotation = NumberRange.new(-360.00, 360.00)
		v_65.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_65.LightEmission = 0.00
		v_65.LightInfluence = 0.00
		v_65.LockedToPart = true
		v_65.ZOffset = 2.10
		v_65.Drag = 2.00
		v_65.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_65.VelocityInheritance = 0.00
		v_65.Orientation = Enum.ParticleOrientation.FacingCamera
		v_65.EmissionDirection = Enum.NormalId.Top
		v_65.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_65.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_65.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.533, 0.000), NumberSequenceKeypoint.new(0.48, 3.667, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_65.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.317, 0.000), NumberSequenceKeypoint.new(0.86, 0.683, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_65.Enabled = true
		v_65.Parent = v_41
	end
	do
		local v_66 = Instance.new("ParticleEmitter")
		v_66.Name = "Fire45"
		refMap["66"] = v_66
		v_66.Texture = "rbxassetid://16860419961"
		v_66.Rate = 3.00
		v_66.Speed = NumberRange.new(0.00, 0.00)
		v_66.Lifetime = NumberRange.new(0.70, 2.00)
		v_66.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_66.Rotation = NumberRange.new(-360.00, 360.00)
		v_66.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_66.LightEmission = 0.00
		v_66.LightInfluence = 0.00
		v_66.LockedToPart = true
		v_66.ZOffset = 2.03
		v_66.Drag = 2.00
		v_66.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_66.VelocityInheritance = 0.00
		v_66.Orientation = Enum.ParticleOrientation.FacingCamera
		v_66.EmissionDirection = Enum.NormalId.Top
		v_66.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_66.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_66.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 5.724, 0.000), NumberSequenceKeypoint.new(0.48, 8.285, 0.000), NumberSequenceKeypoint.new(1.00, 9.038, 0.000)})
		v_66.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_66.Enabled = true
		v_66.Parent = v_41
	end
	do
		local v_67 = Instance.new("ParticleEmitter")
		v_67.Name = "cat spec 8"
		refMap["67"] = v_67
		v_67.Texture = "rbxassetid://101658731548844"
		v_67.Rate = 2.00
		v_67.Speed = NumberRange.new(12.93, 25.87)
		v_67.Lifetime = NumberRange.new(0.40, 1.00)
		v_67.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_67.Rotation = NumberRange.new(-360.00, 360.00)
		v_67.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_67.LightEmission = 0.00
		v_67.LightInfluence = 0.00
		v_67.LockedToPart = false
		v_67.ZOffset = 2.05
		v_67.Drag = 4.00
		v_67.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_67.VelocityInheritance = 0.00
		v_67.Orientation = Enum.ParticleOrientation.FacingCamera
		v_67.EmissionDirection = Enum.NormalId.Top
		v_67.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_67.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_67.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.996, 0.000), NumberSequenceKeypoint.new(0.73, 0.621, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_67.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_67.Enabled = true
		v_67.Parent = v_41
	end
	do
		local v_68 = Instance.new("ParticleEmitter")
		v_68.Name = "windfs"
		refMap["68"] = v_68
		v_68.Texture = "rbxassetid://135128020878697"
		v_68.Rate = 2.00
		v_68.Speed = NumberRange.new(0.00, 0.00)
		v_68.Lifetime = NumberRange.new(1.00, 1.50)
		v_68.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_68.Rotation = NumberRange.new(-360.00, 360.00)
		v_68.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_68.LightEmission = 0.00
		v_68.LightInfluence = 0.00
		v_68.LockedToPart = true
		v_68.ZOffset = 2.09
		v_68.Drag = 2.00
		v_68.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_68.VelocityInheritance = 0.00
		v_68.Orientation = Enum.ParticleOrientation.FacingCamera
		v_68.EmissionDirection = Enum.NormalId.Top
		v_68.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(0.22, Color3.new(0.1458, 0.3535, 0.4167)), ColorSequenceKeypoint.new(0.56, Color3.new(0.0617, 0.1493, 0.1753)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0471, 0.1137, 0.1333))})
		v_68.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 3.532, 0.000), NumberSequenceKeypoint.new(0.48, 5.112, 0.000), NumberSequenceKeypoint.new(1.00, 5.577, 0.000)})
		v_68.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_68.Enabled = true
		v_68.Parent = v_41
	end
	do
		local v_69 = Instance.new("ParticleEmitter")
		v_69.Name = "cat spec 3"
		refMap["69"] = v_69
		v_69.Texture = "rbxassetid://136781994057492"
		v_69.Rate = 2.00
		v_69.Speed = NumberRange.new(10.00, 20.00)
		v_69.Lifetime = NumberRange.new(0.40, 1.00)
		v_69.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_69.Rotation = NumberRange.new(-360.00, 360.00)
		v_69.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_69.LightEmission = 0.00
		v_69.LightInfluence = 0.00
		v_69.LockedToPart = false
		v_69.ZOffset = 2.20
		v_69.Drag = 4.00
		v_69.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_69.VelocityInheritance = 0.00
		v_69.Orientation = Enum.ParticleOrientation.FacingCamera
		v_69.EmissionDirection = Enum.NormalId.Top
		v_69.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_69.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_69.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_69.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_69.Enabled = true
		v_69.Parent = v_41
	end
	do
		local v_70 = Instance.new("ParticleEmitter")
		v_70.Name = "cat spec 7"
		refMap["70"] = v_70
		v_70.Texture = "rbxassetid://90414839644727"
		v_70.Rate = 2.00
		v_70.Speed = NumberRange.new(10.00, 20.00)
		v_70.Lifetime = NumberRange.new(0.40, 1.00)
		v_70.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_70.Rotation = NumberRange.new(-360.00, 360.00)
		v_70.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_70.LightEmission = 0.00
		v_70.LightInfluence = 0.00
		v_70.LockedToPart = false
		v_70.ZOffset = 2.04
		v_70.Drag = 4.00
		v_70.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_70.VelocityInheritance = 0.00
		v_70.Orientation = Enum.ParticleOrientation.FacingCamera
		v_70.EmissionDirection = Enum.NormalId.Top
		v_70.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_70.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_70.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_70.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_70.Enabled = true
		v_70.Parent = v_41
	end
	do
		local v_71 = Instance.new("ParticleEmitter")
		v_71.Name = "Fire54"
		refMap["71"] = v_71
		v_71.Texture = "rbxassetid://17006155963"
		v_71.Rate = 3.00
		v_71.Speed = NumberRange.new(0.00, 0.00)
		v_71.Lifetime = NumberRange.new(0.40, 1.00)
		v_71.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_71.Rotation = NumberRange.new(-360.00, 360.00)
		v_71.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_71.LightEmission = 0.00
		v_71.LightInfluence = 0.00
		v_71.LockedToPart = true
		v_71.ZOffset = 1.04
		v_71.Drag = 2.00
		v_71.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_71.VelocityInheritance = 0.00
		v_71.Orientation = Enum.ParticleOrientation.FacingCamera
		v_71.EmissionDirection = Enum.NormalId.Top
		v_71.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_71.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_71.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.533, 0.000), NumberSequenceKeypoint.new(0.48, 3.667, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_71.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_71.Enabled = true
		v_71.Parent = v_41
	end
	do
		local v_72 = Instance.new("ParticleEmitter")
		v_72.Name = "Slightly glowing"
		refMap["72"] = v_72
		v_72.Texture = "rbxassetid://14152113700"
		v_72.Rate = 2.00
		v_72.Speed = NumberRange.new(0.00, 0.00)
		v_72.Lifetime = NumberRange.new(0.40, 1.00)
		v_72.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_72.Rotation = NumberRange.new(-360.00, 360.00)
		v_72.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_72.LightEmission = 0.00
		v_72.LightInfluence = 0.00
		v_72.LockedToPart = true
		v_72.ZOffset = 2.09
		v_72.Drag = 2.00
		v_72.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_72.VelocityInheritance = 0.00
		v_72.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_72.EmissionDirection = Enum.NormalId.Top
		v_72.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_72.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_72.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.533, 0.000), NumberSequenceKeypoint.new(0.48, 3.667, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_72.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_72.Enabled = true
		v_72.Parent = v_41
	end
	do
		local v_73 = Instance.new("ParticleEmitter")
		v_73.Name = "cursed energy3421"
		refMap["73"] = v_73
		v_73.Texture = "rbxassetid://17006172452"
		v_73.Rate = 2.00
		v_73.Speed = NumberRange.new(0.00, 0.00)
		v_73.Lifetime = NumberRange.new(0.40, 1.00)
		v_73.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_73.Rotation = NumberRange.new(-360.00, 360.00)
		v_73.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_73.LightEmission = 0.00
		v_73.LightInfluence = 0.00
		v_73.LockedToPart = true
		v_73.ZOffset = 1.01
		v_73.Drag = 2.00
		v_73.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_73.VelocityInheritance = 0.00
		v_73.Orientation = Enum.ParticleOrientation.FacingCamera
		v_73.EmissionDirection = Enum.NormalId.Top
		v_73.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_73.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_73.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.862, 0.000), NumberSequenceKeypoint.new(0.48, 4.143, 0.000), NumberSequenceKeypoint.new(1.00, 4.519, 0.000)})
		v_73.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.60, 0.317, 0.000), NumberSequenceKeypoint.new(0.86, 0.683, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_73.Enabled = true
		v_73.Parent = v_41
	end
	do
		local v_74 = Instance.new("ParticleEmitter")
		v_74.Name = "Cursed Energy Disperse 8x8"
		refMap["74"] = v_74
		v_74.Texture = "rbxassetid://97051019398375"
		v_74.Rate = 2.00
		v_74.Speed = NumberRange.new(0.00, 0.00)
		v_74.Lifetime = NumberRange.new(0.40, 1.00)
		v_74.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_74.Rotation = NumberRange.new(-360.00, 360.00)
		v_74.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_74.LightEmission = 0.00
		v_74.LightInfluence = 0.00
		v_74.LockedToPart = true
		v_74.ZOffset = 1.05
		v_74.Drag = 2.00
		v_74.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_74.VelocityInheritance = 0.00
		v_74.Orientation = Enum.ParticleOrientation.FacingCamera
		v_74.EmissionDirection = Enum.NormalId.Top
		v_74.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8
		v_74.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_74.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.862, 0.000), NumberSequenceKeypoint.new(0.48, 4.143, 0.000), NumberSequenceKeypoint.new(1.00, 4.519, 0.000)})
		v_74.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_74.Enabled = true
		v_74.Parent = v_41
	end
	do
		local v_75 = Instance.new("ParticleEmitter")
		v_75.Name = "Cursed Energy Disperse 8x8"
		refMap["75"] = v_75
		v_75.Texture = "rbxassetid://97051019398375"
		v_75.Rate = 2.00
		v_75.Speed = NumberRange.new(0.00, 0.00)
		v_75.Lifetime = NumberRange.new(0.40, 1.00)
		v_75.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_75.Rotation = NumberRange.new(-360.00, 360.00)
		v_75.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_75.LightEmission = 0.00
		v_75.LightInfluence = 0.00
		v_75.LockedToPart = true
		v_75.ZOffset = 2.04
		v_75.Drag = 2.00
		v_75.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_75.VelocityInheritance = 0.00
		v_75.Orientation = Enum.ParticleOrientation.FacingCamera
		v_75.EmissionDirection = Enum.NormalId.Top
		v_75.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8
		v_75.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_75.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.533, 0.000), NumberSequenceKeypoint.new(0.48, 3.667, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_75.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_75.Enabled = true
		v_75.Parent = v_41
	end
	do
		local v_76 = Instance.new("PointLight")
		v_76.Name = "PointLight"
		refMap["76"] = v_76
		v_76.Brightness = 2.00
		v_76.Range = 8.00
		v_76.Shadows = false
		v_76.Color = Color3.new(0.3490, 0.8471, 1.0000)
		v_76.Enabled = true
		v_76.Parent = v_41
	end
	do
		local v_77 = Instance.new("ParticleEmitter")
		v_77.Name = "cursed energy spec"
		refMap["77"] = v_77
		v_77.Texture = "rbxassetid://85688545954016"
		v_77.Rate = 2.00
		v_77.Speed = NumberRange.new(10.00, 20.00)
		v_77.Lifetime = NumberRange.new(0.40, 1.00)
		v_77.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_77.Rotation = NumberRange.new(-360.00, 360.00)
		v_77.SpreadAngle = Vector2.new(-360.0, 360.0)
		v_77.LightEmission = 0.00
		v_77.LightInfluence = 0.00
		v_77.LockedToPart = false
		v_77.ZOffset = 2.11
		v_77.Drag = 4.00
		v_77.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_77.VelocityInheritance = 0.00
		v_77.Orientation = Enum.ParticleOrientation.FacingCamera
		v_77.EmissionDirection = Enum.NormalId.Top
		v_77.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_77.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_77.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_77.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_77.Enabled = true
		v_77.Parent = v_41
	end
	end
	do
		local v_78 = Instance.new("Attachment")
		v_78.Name = "Attachment"
		refMap["78"] = v_78
		v_78.CFrame = CFrame.new(0.000, -3.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_78.Parent = v_2
	do
		local v_79 = Instance.new("ParticleEmitter")
		v_79.Name = "Slightly glowing"
		refMap["79"] = v_79
		v_79.Texture = "rbxassetid://14152113700"
		v_79.Rate = 2.00
		v_79.Speed = NumberRange.new(0.00, 0.00)
		v_79.Lifetime = NumberRange.new(1.00, 2.00)
		v_79.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_79.Rotation = NumberRange.new(-360.00, 360.00)
		v_79.SpreadAngle = Vector2.new(0.0, 0.0)
		v_79.LightEmission = 0.00
		v_79.LightInfluence = 0.00
		v_79.LockedToPart = true
		v_79.ZOffset = 2.00
		v_79.Drag = 0.00
		v_79.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_79.VelocityInheritance = 0.00
		v_79.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_79.EmissionDirection = Enum.NormalId.Top
		v_79.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_79.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(0.24, Color3.new(0.1347, 0.3250, 0.3845)), ColorSequenceKeypoint.new(0.45, Color3.new(0.0526, 0.1250, 0.1487)), ColorSequenceKeypoint.new(1.00, Color3.new(0.0431, 0.1020, 0.1216))})
		v_79.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.17, 4.037, 0.000), NumberSequenceKeypoint.new(0.49, 6.557, 0.000), NumberSequenceKeypoint.new(1.00, 7.000, 0.000)})
		v_79.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_79.Enabled = true
		v_79.Parent = v_78
	end
	do
		local v_80 = Instance.new("ParticleEmitter")
		v_80.Name = "dis dark circle 2"
		refMap["80"] = v_80
		v_80.Texture = "rbxassetid://87272078452382"
		v_80.Rate = 2.00
		v_80.Speed = NumberRange.new(0.00, 0.00)
		v_80.Lifetime = NumberRange.new(1.00, 2.00)
		v_80.RotSpeed = NumberRange.new(-30.00, 20.00)
		v_80.Rotation = NumberRange.new(-360.00, 360.00)
		v_80.SpreadAngle = Vector2.new(0.0, 0.0)
		v_80.LightEmission = 0.00
		v_80.LightInfluence = 0.00
		v_80.LockedToPart = true
		v_80.ZOffset = 1.03
		v_80.Drag = 0.00
		v_80.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_80.VelocityInheritance = 0.00
		v_80.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
		v_80.EmissionDirection = Enum.NormalId.Top
		v_80.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_80.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.17, 4.037, 0.000), NumberSequenceKeypoint.new(0.49, 6.557, 0.000), NumberSequenceKeypoint.new(1.00, 7.000, 0.000)})
		v_80.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.62, 0.213, 0.000), NumberSequenceKeypoint.new(0.84, 0.467, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_80.Enabled = true
		v_80.Parent = v_78
	end
	end
	do
		local v_81 = Instance.new("Part")
		v_81.Name = "Part"
		refMap["81"] = v_81
		v_81.Anchored = false
		v_81.CanCollide = false
		v_81.CanTouch = false
		v_81.CanQuery = false
		v_81.Massless = true
		v_81.CastShadow = false
		v_81.Transparency = 1.00
		v_81.Size = Vector3.new(8.000, 1.000, 7.000)
		v_81.CFrame = CFrame.new(-140.500, 19.531, -14.000, 0.000, 0.000, -1.000, 0.000, 1.000, 0.000, 1.000, 0.000, 0.000)
		v_81.Color = Color3.fromRGB(163, 162, 165)
		v_81.Parent = v_2
	do
		local v_82 = Instance.new("ParticleEmitter")
		v_82.Name = "Sideways Spec 15"
		refMap["82"] = v_82
		v_82.Texture = "rbxassetid://6763809313"
		v_82.Rate = 1.00
		v_82.Speed = NumberRange.new(10.00, 20.00)
		v_82.Lifetime = NumberRange.new(0.40, 1.00)
		v_82.RotSpeed = NumberRange.new(0.00, 0.00)
		v_82.Rotation = NumberRange.new(90.00, 90.00)
		v_82.SpreadAngle = Vector2.new(-50.0, 50.0)
		v_82.LightEmission = 0.00
		v_82.LightInfluence = 0.00
		v_82.LockedToPart = false
		v_82.ZOffset = 3.08
		v_82.Drag = 4.00
		v_82.Acceleration = Vector3.new(0.000, -20.000, 0.000)
		v_82.VelocityInheritance = 0.00
		v_82.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_82.EmissionDirection = Enum.NormalId.Top
		v_82.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_82.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_82.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_82.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_82.Enabled = true
		v_82.Parent = v_81
	end
	do
		local v_83 = Instance.new("ParticleEmitter")
		v_83.Name = "Sideways Spec 12"
		refMap["83"] = v_83
		v_83.Texture = "rbxassetid://1269254614"
		v_83.Rate = 1.00
		v_83.Speed = NumberRange.new(10.00, 20.00)
		v_83.Lifetime = NumberRange.new(0.40, 1.00)
		v_83.RotSpeed = NumberRange.new(0.00, 0.00)
		v_83.Rotation = NumberRange.new(90.00, 90.00)
		v_83.SpreadAngle = Vector2.new(-50.0, 50.0)
		v_83.LightEmission = 0.00
		v_83.LightInfluence = 0.00
		v_83.LockedToPart = false
		v_83.ZOffset = 3.03
		v_83.Drag = 4.00
		v_83.Acceleration = Vector3.new(0.000, -20.000, 0.000)
		v_83.VelocityInheritance = 0.00
		v_83.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_83.EmissionDirection = Enum.NormalId.Top
		v_83.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_83.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_83.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_83.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_83.Enabled = true
		v_83.Parent = v_81
	end
	do
		local v_84 = Instance.new("ParticleEmitter")
		v_84.Name = "Coloured Diagonal Smoke"
		refMap["84"] = v_84
		v_84.Texture = "rbxassetid://13724252630"
		v_84.Rate = 1.00
		v_84.Speed = NumberRange.new(10.00, 20.00)
		v_84.Lifetime = NumberRange.new(1.00, 2.00)
		v_84.RotSpeed = NumberRange.new(0.00, 0.00)
		v_84.Rotation = NumberRange.new(15.00, 15.00)
		v_84.SpreadAngle = Vector2.new(0.0, 0.0)
		v_84.LightEmission = 0.00
		v_84.LightInfluence = 0.00
		v_84.LockedToPart = false
		v_84.ZOffset = 2.03
		v_84.Drag = 4.00
		v_84.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_84.VelocityInheritance = 0.00
		v_84.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
		v_84.EmissionDirection = Enum.NormalId.Top
		v_84.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_84.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_84.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.430, 0.000), NumberSequenceKeypoint.new(0.42, 3.670, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_84.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.427, 0.000), NumberSequenceKeypoint.new(0.39, 0.553, 0.000), NumberSequenceKeypoint.new(0.75, 0.720, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_84.Enabled = true
		v_84.Parent = v_81
	end
	do
		local v_85 = Instance.new("ParticleEmitter")
		v_85.Name = "fire realistic"
		refMap["85"] = v_85
		v_85.Texture = "rbxassetid://115973544312399"
		v_85.Rate = 1.00
		v_85.Speed = NumberRange.new(10.00, 20.00)
		v_85.Lifetime = NumberRange.new(1.00, 2.00)
		v_85.RotSpeed = NumberRange.new(0.00, 0.00)
		v_85.Rotation = NumberRange.new(0.00, 0.00)
		v_85.SpreadAngle = Vector2.new(0.0, 0.0)
		v_85.LightEmission = 0.00
		v_85.LightInfluence = 0.00
		v_85.LockedToPart = false
		v_85.ZOffset = 2.03
		v_85.Drag = 4.00
		v_85.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_85.VelocityInheritance = 0.00
		v_85.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
		v_85.EmissionDirection = Enum.NormalId.Top
		v_85.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_85.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.430, 0.000), NumberSequenceKeypoint.new(0.42, 3.670, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_85.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.427, 0.000), NumberSequenceKeypoint.new(0.39, 0.553, 0.000), NumberSequenceKeypoint.new(0.75, 0.720, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_85.Enabled = true
		v_85.Parent = v_81
	end
	do
		local v_86 = Instance.new("ParticleEmitter")
		v_86.Name = "Sideways Spec 17"
		refMap["86"] = v_86
		v_86.Texture = "rbxassetid://8599882518"
		v_86.Rate = 1.00
		v_86.Speed = NumberRange.new(10.00, 20.00)
		v_86.Lifetime = NumberRange.new(0.40, 1.00)
		v_86.RotSpeed = NumberRange.new(0.00, 0.00)
		v_86.Rotation = NumberRange.new(90.00, 90.00)
		v_86.SpreadAngle = Vector2.new(-50.0, 50.0)
		v_86.LightEmission = 0.00
		v_86.LightInfluence = 0.00
		v_86.LockedToPart = false
		v_86.ZOffset = 3.10
		v_86.Drag = 4.00
		v_86.Acceleration = Vector3.new(0.000, -20.000, 0.000)
		v_86.VelocityInheritance = 0.00
		v_86.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_86.EmissionDirection = Enum.NormalId.Top
		v_86.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_86.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_86.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_86.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_86.Enabled = true
		v_86.Parent = v_81
	end
	do
		local v_87 = Instance.new("ParticleEmitter")
		v_87.Name = "Sideways Spec 15"
		refMap["87"] = v_87
		v_87.Texture = "rbxassetid://6763809313"
		v_87.Rate = 2.00
		v_87.Speed = NumberRange.new(10.00, 20.00)
		v_87.Lifetime = NumberRange.new(0.40, 1.00)
		v_87.RotSpeed = NumberRange.new(0.00, 0.00)
		v_87.Rotation = NumberRange.new(90.00, 90.00)
		v_87.SpreadAngle = Vector2.new(-30.0, 30.0)
		v_87.LightEmission = 0.00
		v_87.LightInfluence = 0.00
		v_87.LockedToPart = false
		v_87.ZOffset = 2.02
		v_87.Drag = 4.00
		v_87.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_87.VelocityInheritance = 0.00
		v_87.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_87.EmissionDirection = Enum.NormalId.Top
		v_87.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_87.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_87.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_87.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_87.Enabled = true
		v_87.Parent = v_81
	end
	do
		local v_88 = Instance.new("ParticleEmitter")
		v_88.Name = "cursed energy spec"
		refMap["88"] = v_88
		v_88.Texture = "rbxassetid://85688545954016"
		v_88.Rate = 2.00
		v_88.Speed = NumberRange.new(10.00, 20.00)
		v_88.Lifetime = NumberRange.new(0.40, 1.00)
		v_88.RotSpeed = NumberRange.new(0.00, 0.00)
		v_88.Rotation = NumberRange.new(90.00, 90.00)
		v_88.SpreadAngle = Vector2.new(-30.0, 30.0)
		v_88.LightEmission = 0.00
		v_88.LightInfluence = 0.00
		v_88.LockedToPart = false
		v_88.ZOffset = 2.04
		v_88.Drag = 4.00
		v_88.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_88.VelocityInheritance = 0.00
		v_88.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_88.EmissionDirection = Enum.NormalId.Top
		v_88.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_88.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_88.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_88.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_88.Enabled = true
		v_88.Parent = v_81
	end
	do
		local v_89 = Instance.new("ParticleEmitter")
		v_89.Name = "cursed energy spec"
		refMap["89"] = v_89
		v_89.Texture = "rbxassetid://85688545954016"
		v_89.Rate = 2.00
		v_89.Speed = NumberRange.new(10.00, 20.00)
		v_89.Lifetime = NumberRange.new(0.40, 1.00)
		v_89.RotSpeed = NumberRange.new(0.00, 0.00)
		v_89.Rotation = NumberRange.new(90.00, 90.00)
		v_89.SpreadAngle = Vector2.new(-30.0, 30.0)
		v_89.LightEmission = 0.00
		v_89.LightInfluence = 0.00
		v_89.LockedToPart = false
		v_89.ZOffset = 2.04
		v_89.Drag = 4.00
		v_89.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_89.VelocityInheritance = 0.00
		v_89.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_89.EmissionDirection = Enum.NormalId.Top
		v_89.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_89.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_89.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_89.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_89.Enabled = true
		v_89.Parent = v_81
	end
	do
		local v_90 = Instance.new("ParticleEmitter")
		v_90.Name = "Realistic Smoke 10"
		refMap["90"] = v_90
		v_90.Texture = "rbxassetid://82219367698334"
		v_90.Rate = 1.00
		v_90.Speed = NumberRange.new(10.00, 20.00)
		v_90.Lifetime = NumberRange.new(1.00, 2.00)
		v_90.RotSpeed = NumberRange.new(0.00, 0.00)
		v_90.Rotation = NumberRange.new(0.00, 0.00)
		v_90.SpreadAngle = Vector2.new(0.0, 0.0)
		v_90.LightEmission = 0.00
		v_90.LightInfluence = 0.00
		v_90.LockedToPart = false
		v_90.ZOffset = 2.06
		v_90.Drag = 4.00
		v_90.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_90.VelocityInheritance = 0.00
		v_90.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
		v_90.EmissionDirection = Enum.NormalId.Top
		v_90.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_90.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_90.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.14, 2.430, 0.000), NumberSequenceKeypoint.new(0.42, 3.670, 0.000), NumberSequenceKeypoint.new(1.00, 4.000, 0.000)})
		v_90.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.427, 0.000), NumberSequenceKeypoint.new(0.39, 0.553, 0.000), NumberSequenceKeypoint.new(0.75, 0.720, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_90.Enabled = true
		v_90.Parent = v_81
	end
	do
		local v_91 = Instance.new("ParticleEmitter")
		v_91.Name = "Sideways Spec 102"
		refMap["91"] = v_91
		v_91.Texture = "rbxassetid://80742887810818"
		v_91.Rate = 1.00
		v_91.Speed = NumberRange.new(10.00, 20.00)
		v_91.Lifetime = NumberRange.new(0.40, 1.00)
		v_91.RotSpeed = NumberRange.new(0.00, 0.00)
		v_91.Rotation = NumberRange.new(90.00, 90.00)
		v_91.SpreadAngle = Vector2.new(-50.0, 50.0)
		v_91.LightEmission = 0.00
		v_91.LightInfluence = 0.00
		v_91.LockedToPart = false
		v_91.ZOffset = 3.00
		v_91.Drag = 4.00
		v_91.Acceleration = Vector3.new(0.000, -20.000, 0.000)
		v_91.VelocityInheritance = 0.00
		v_91.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_91.EmissionDirection = Enum.NormalId.Top
		v_91.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_91.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_91.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_91.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_91.Enabled = true
		v_91.Parent = v_81
	end
	do
		local v_92 = Instance.new("ParticleEmitter")
		v_92.Name = "Sideways Spec 15"
		refMap["92"] = v_92
		v_92.Texture = "rbxassetid://6763809313"
		v_92.Rate = 1.00
		v_92.Speed = NumberRange.new(10.00, 20.00)
		v_92.Lifetime = NumberRange.new(0.40, 1.00)
		v_92.RotSpeed = NumberRange.new(0.00, 0.00)
		v_92.Rotation = NumberRange.new(90.00, 90.00)
		v_92.SpreadAngle = Vector2.new(-50.0, 50.0)
		v_92.LightEmission = 0.00
		v_92.LightInfluence = 0.00
		v_92.LockedToPart = false
		v_92.ZOffset = 3.09
		v_92.Drag = 4.00
		v_92.Acceleration = Vector3.new(0.000, -20.000, 0.000)
		v_92.VelocityInheritance = 0.00
		v_92.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_92.EmissionDirection = Enum.NormalId.Top
		v_92.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_92.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_92.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_92.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_92.Enabled = true
		v_92.Parent = v_81
	end
	do
		local v_93 = Instance.new("ParticleEmitter")
		v_93.Name = "Sideways Spec 102"
		refMap["93"] = v_93
		v_93.Texture = "rbxassetid://80742887810818"
		v_93.Rate = 1.00
		v_93.Speed = NumberRange.new(10.00, 20.00)
		v_93.Lifetime = NumberRange.new(0.40, 1.00)
		v_93.RotSpeed = NumberRange.new(0.00, 0.00)
		v_93.Rotation = NumberRange.new(90.00, 90.00)
		v_93.SpreadAngle = Vector2.new(-50.0, 50.0)
		v_93.LightEmission = 0.00
		v_93.LightInfluence = 0.00
		v_93.LockedToPart = false
		v_93.ZOffset = 3.03
		v_93.Drag = 4.00
		v_93.Acceleration = Vector3.new(0.000, -20.000, 0.000)
		v_93.VelocityInheritance = 0.00
		v_93.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_93.EmissionDirection = Enum.NormalId.Top
		v_93.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_93.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_93.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_93.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_93.Enabled = true
		v_93.Parent = v_81
	end
	do
		local v_94 = Instance.new("ParticleEmitter")
		v_94.Name = "Sideways Spec 17"
		refMap["94"] = v_94
		v_94.Texture = "rbxassetid://8599882518"
		v_94.Rate = 2.00
		v_94.Speed = NumberRange.new(10.00, 20.00)
		v_94.Lifetime = NumberRange.new(0.40, 1.00)
		v_94.RotSpeed = NumberRange.new(0.00, 0.00)
		v_94.Rotation = NumberRange.new(90.00, 90.00)
		v_94.SpreadAngle = Vector2.new(-30.0, 30.0)
		v_94.LightEmission = 0.00
		v_94.LightInfluence = 0.00
		v_94.LockedToPart = false
		v_94.ZOffset = 2.05
		v_94.Drag = 4.00
		v_94.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_94.VelocityInheritance = 0.00
		v_94.Orientation = Enum.ParticleOrientation.VelocityParallel
		v_94.EmissionDirection = Enum.NormalId.Top
		v_94.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_94.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3490, 0.8471, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3490, 0.8471, 1.0000))})
		v_94.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.21, 0.770, 0.000), NumberSequenceKeypoint.new(0.73, 0.480, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_94.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_94.Enabled = true
		v_94.Parent = v_81
	end
	do
		local v_95 = Instance.new("WeldConstraint")
		v_95.Name = "Part_Weld"
		refMap["95"] = v_95
		v_95.Parent = v_81
	end
	end
	end
	end

	for _, pending in ipairs(pendingRefs) do
		local target = refMap[pending.ref]
		if target then
			pending.obj[pending.prop] = target
		end
	end
end

local function buildAura14(auraFolder: Folder)
	local refMap = {}
	local pendingRefs = {}

	do
		local v_0 = Instance.new("Model")
		v_0.Name = "Aura14"
		refMap["0"] = v_0
		v_0:SetAttribute("CosmeticType", "Aura")
		v_0:SetAttribute("CosmeticId", "Aura14")
		v_0:SetAttribute("TargetPart", "HumanoidRootPart")
		v_0:SetAttribute("SupportsR6", true)
		v_0:SetAttribute("SupportsR15", true)
		v_0.Parent = auraFolder
	do
		local v_1 = Instance.new("CFrameValue")
		v_1.Name = "LocalOffset"
		refMap["2"] = v_1
		v_1.Value = CFrame.new(0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_1.Parent = v_0
	end
	do
		local v_2 = Instance.new("Part")
		v_2.Name = "EffectHolder"
		refMap["1"] = v_2
		v_2.Anchored = false
		v_2.CanCollide = false
		v_2.CanTouch = false
		v_2.CanQuery = false
		v_2.Massless = true
		v_2.CastShadow = false
		v_2.Transparency = 1.00
		v_2.Size = Vector3.new(2.000, 2.000, 1.000)
		v_2.Parent = v_0
	do
		local v_3 = Instance.new("Attachment")
		v_3.Name = "Wing"
		refMap["3"] = v_3
		v_3.CFrame = CFrame.new(-0.571, 0.334, 0.500, -0.766, -0.166, -0.621, -0.166, -0.882, 0.442, -0.621, 0.442, 0.648)
		v_3.Parent = v_2
	do
		local v_4 = Instance.new("Attachment")
		v_4.Name = "Particles2"
		refMap["4"] = v_4
		v_4.CFrame = CFrame.new(-0.593, -0.000, 4.093, 0.521, -0.000, 0.853, 0.000, 1.000, 0.000, -0.853, 0.000, 0.521)
		v_4.Parent = v_3
	do
		local v_5 = Instance.new("ParticleEmitter")
		v_5.Name = "PinkSpec1"
		refMap["5"] = v_5
		v_5.Texture = "rbxassetid://16879789169"
		v_5.Rate = 100.00
		v_5.Speed = NumberRange.new(5.00, 50.00)
		v_5.Lifetime = NumberRange.new(0.30, 0.30)
		v_5.RotSpeed = NumberRange.new(0.00, 0.00)
		v_5.Rotation = NumberRange.new(-1000.00, 1000.00)
		v_5.SpreadAngle = Vector2.new(15.0, 15.0)
		v_5.LightEmission = 0.50
		v_5.LightInfluence = 0.00
		v_5.LockedToPart = true
		v_5.ZOffset = -0.50
		v_5.Drag = 35.00
		v_5.Acceleration = Vector3.new(50.000, 0.000, 0.000)
		v_5.VelocityInheritance = 0.00
		v_5.Orientation = Enum.ParticleOrientation.FacingCamera
		v_5.EmissionDirection = Enum.NormalId.Back
		v_5.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_5.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3059, 0.6078)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3059, 0.6078))})
		v_5.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.12, 0.312, 0.077), NumberSequenceKeypoint.new(0.21, 0.375, 0.125), NumberSequenceKeypoint.new(0.47, 0.250, 0.083), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_5.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_5.Enabled = true
		v_5.Parent = v_4
	end
	do
		local v_6 = Instance.new("ParticleEmitter")
		v_6.Name = "WingFlame2"
		refMap["6"] = v_6
		v_6.Texture = "rbxassetid://16860219678"
		v_6.Rate = 25.00
		v_6.Speed = NumberRange.new(25.00, 175.00)
		v_6.Lifetime = NumberRange.new(0.20, 0.20)
		v_6.RotSpeed = NumberRange.new(0.00, 0.00)
		v_6.Rotation = NumberRange.new(-1000.00, 1000.00)
		v_6.SpreadAngle = Vector2.new(3.0, 3.0)
		v_6.LightEmission = -1.00
		v_6.LightInfluence = 0.00
		v_6.LockedToPart = true
		v_6.ZOffset = -0.10
		v_6.Drag = 1000.00
		v_6.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_6.VelocityInheritance = 0.00
		v_6.Orientation = Enum.ParticleOrientation.FacingCamera
		v_6.EmissionDirection = Enum.NormalId.Back
		v_6.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_6.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3333, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3333, 1.0000))})
		v_6.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 4.262, 0.000)})
		v_6.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_6.Enabled = true
		v_6.Parent = v_4
	end
	do
		local v_7 = Instance.new("ParticleEmitter")
		v_7.Name = "BlackSpec1"
		refMap["7"] = v_7
		v_7.Texture = "rbxassetid://16879789169"
		v_7.Rate = 100.00
		v_7.Speed = NumberRange.new(5.00, 50.00)
		v_7.Lifetime = NumberRange.new(0.30, 0.30)
		v_7.RotSpeed = NumberRange.new(0.00, 0.00)
		v_7.Rotation = NumberRange.new(-1000.00, 1000.00)
		v_7.SpreadAngle = Vector2.new(15.0, 15.0)
		v_7.LightEmission = 1.00
		v_7.LightInfluence = 0.00
		v_7.LockedToPart = true
		v_7.ZOffset = -0.50
		v_7.Drag = 35.00
		v_7.Acceleration = Vector3.new(50.000, 0.000, 0.000)
		v_7.VelocityInheritance = 0.00
		v_7.Orientation = Enum.ParticleOrientation.FacingCamera
		v_7.EmissionDirection = Enum.NormalId.Back
		v_7.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_7.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3333, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3333, 1.0000))})
		v_7.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.12, 0.312, 0.077), NumberSequenceKeypoint.new(0.21, 0.375, 0.125), NumberSequenceKeypoint.new(0.47, 0.250, 0.083), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_7.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_7.Enabled = true
		v_7.Parent = v_4
	end
	do
		local v_8 = Instance.new("ParticleEmitter")
		v_8.Name = "WingFlame1"
		refMap["8"] = v_8
		v_8.Texture = "rbxassetid://17506974962"
		v_8.Rate = 250.00
		v_8.Speed = NumberRange.new(25.00, 175.00)
		v_8.Lifetime = NumberRange.new(0.20, 0.20)
		v_8.RotSpeed = NumberRange.new(0.00, 0.00)
		v_8.Rotation = NumberRange.new(-1000.00, 1000.00)
		v_8.SpreadAngle = Vector2.new(3.0, 3.0)
		v_8.LightEmission = 1.00
		v_8.LightInfluence = 0.00
		v_8.LockedToPart = true
		v_8.ZOffset = -0.10
		v_8.Drag = 200.00
		v_8.Acceleration = Vector3.new(200.000, 0.000, 0.000)
		v_8.VelocityInheritance = 0.00
		v_8.Orientation = Enum.ParticleOrientation.FacingCamera
		v_8.EmissionDirection = Enum.NormalId.Back
		v_8.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_8.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.0784, 0.7529)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.0784, 0.7529))})
		v_8.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 1.803, 0.000)})
		v_8.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_8.Enabled = true
		v_8.Parent = v_4
	end
	end
	do
		local v_9 = Instance.new("Beam")
		v_9.Name = "WingBeam1"
		refMap["9"] = v_9
		v_9.Texture = "rbxassetid://16892446507"
		v_9.TextureLength = 8.00
		v_9.TextureSpeed = 4.00
		v_9.TextureMode = Enum.TextureMode.Static
		v_9.LightEmission = 0.50
		v_9.LightInfluence = 0.00
		v_9.Width0 = 0.50
		v_9.Width1 = 5.00
		v_9.Segments = 25
		v_9.CurveSize0 = 0.00
		v_9.CurveSize1 = 4.00
		v_9.FaceCamera = true
		v_9.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.6667, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.6667, 1.0000))})
		v_9.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.13, 0.494, 0.000), NumberSequenceKeypoint.new(0.83, 0.681, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_9.Enabled = true
		table.insert(pendingRefs, { obj = v_9, prop = "Attachment0", ref = "10" })
		table.insert(pendingRefs, { obj = v_9, prop = "Attachment1", ref = "11" })
		v_9.Parent = v_3
	end
	do
		local v_10 = Instance.new("Attachment")
		v_10.Name = "A1"
		refMap["11"] = v_10
		v_10.CFrame = CFrame.new(2.000, -0.000, 5.200, 1.000, 0.000, -0.000, -0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_10.Parent = v_3
	end
	do
		local v_11 = Instance.new("Beam")
		v_11.Name = "MainBeam1"
		refMap["12"] = v_11
		v_11.Texture = "rbxassetid://86053242044615"
		v_11.TextureLength = 8.00
		v_11.TextureSpeed = 4.00
		v_11.TextureMode = Enum.TextureMode.Static
		v_11.LightEmission = 0.50
		v_11.LightInfluence = 0.00
		v_11.Width0 = 0.20
		v_11.Width1 = 4.50
		v_11.Segments = 25
		v_11.CurveSize0 = 0.00
		v_11.CurveSize1 = 4.00
		v_11.FaceCamera = true
		v_11.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.0000, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.0000, 1.0000))})
		v_11.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.11, 0.269, 0.000), NumberSequenceKeypoint.new(0.85, 0.494, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_11.Enabled = true
		table.insert(pendingRefs, { obj = v_11, prop = "Attachment0", ref = "10" })
		table.insert(pendingRefs, { obj = v_11, prop = "Attachment1", ref = "11" })
		v_11.Parent = v_3
	end
	do
		local v_12 = Instance.new("Attachment")
		v_12.Name = "A0"
		refMap["10"] = v_12
		v_12.CFrame = CFrame.new(0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_12.Parent = v_3
	end
	do
		local v_13 = Instance.new("Attachment")
		v_13.Name = "Particles"
		refMap["13"] = v_13
		v_13.CFrame = CFrame.new(-0.294, -0.000, -0.059, 0.980, 0.000, -0.198, -0.000, 1.000, 0.000, 0.198, 0.000, 0.980)
		v_13.Parent = v_3
	do
		local v_14 = Instance.new("ParticleEmitter")
		v_14.Name = "BlackSpec1"
		refMap["14"] = v_14
		v_14.Texture = "rbxassetid://16879789169"
		v_14.Rate = 100.00
		v_14.Speed = NumberRange.new(5.00, 50.00)
		v_14.Lifetime = NumberRange.new(0.30, 0.30)
		v_14.RotSpeed = NumberRange.new(0.00, 0.00)
		v_14.Rotation = NumberRange.new(-1000.00, 1000.00)
		v_14.SpreadAngle = Vector2.new(15.0, 15.0)
		v_14.LightEmission = 1.00
		v_14.LightInfluence = 0.00
		v_14.LockedToPart = true
		v_14.ZOffset = -0.50
		v_14.Drag = 15.00
		v_14.Acceleration = Vector3.new(50.000, 0.000, 0.000)
		v_14.VelocityInheritance = 0.00
		v_14.Orientation = Enum.ParticleOrientation.FacingCamera
		v_14.EmissionDirection = Enum.NormalId.Back
		v_14.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_14.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3333, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3333, 1.0000))})
		v_14.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.12, 0.312, 0.077), NumberSequenceKeypoint.new(0.21, 0.375, 0.125), NumberSequenceKeypoint.new(0.47, 0.250, 0.083), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_14.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_14.Enabled = true
		v_14.Parent = v_13
	end
	do
		local v_15 = Instance.new("ParticleEmitter")
		v_15.Name = "WingFlame1"
		refMap["15"] = v_15
		v_15.Texture = "rbxassetid://17506974962"
		v_15.Rate = 250.00
		v_15.Speed = NumberRange.new(25.00, 175.00)
		v_15.Lifetime = NumberRange.new(0.20, 0.20)
		v_15.RotSpeed = NumberRange.new(0.00, 0.00)
		v_15.Rotation = NumberRange.new(-1000.00, 1000.00)
		v_15.SpreadAngle = Vector2.new(3.0, 3.0)
		v_15.LightEmission = 1.00
		v_15.LightInfluence = 0.00
		v_15.LockedToPart = true
		v_15.ZOffset = -0.10
		v_15.Drag = 75.00
		v_15.Acceleration = Vector3.new(200.000, 0.000, 0.000)
		v_15.VelocityInheritance = 0.00
		v_15.Orientation = Enum.ParticleOrientation.FacingCamera
		v_15.EmissionDirection = Enum.NormalId.Back
		v_15.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_15.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.0784, 0.7529)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.0784, 0.7529))})
		v_15.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.10, 0.161, 0.000), NumberSequenceKeypoint.new(0.20, 0.313, 0.000), NumberSequenceKeypoint.new(0.30, 0.456, 0.000), NumberSequenceKeypoint.new(0.40, 0.587, 0.000), NumberSequenceKeypoint.new(0.50, 0.705, 0.000), NumberSequenceKeypoint.new(0.60, 0.808, 0.000), NumberSequenceKeypoint.new(0.70, 0.892, 0.000), NumberSequenceKeypoint.new(0.80, 0.955, 0.000), NumberSequenceKeypoint.new(0.90, 0.991, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_15.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_15.Enabled = true
		v_15.Parent = v_13
	end
	do
		local v_16 = Instance.new("ParticleEmitter")
		v_16.Name = "WingFlame2"
		refMap["16"] = v_16
		v_16.Texture = "rbxassetid://16860219678"
		v_16.Rate = 25.00
		v_16.Speed = NumberRange.new(25.00, 175.00)
		v_16.Lifetime = NumberRange.new(0.20, 0.20)
		v_16.RotSpeed = NumberRange.new(0.00, 0.00)
		v_16.Rotation = NumberRange.new(-1000.00, 1000.00)
		v_16.SpreadAngle = Vector2.new(3.0, 3.0)
		v_16.LightEmission = -1.00
		v_16.LightInfluence = 0.00
		v_16.LockedToPart = true
		v_16.ZOffset = -0.10
		v_16.Drag = 75.00
		v_16.Acceleration = Vector3.new(200.000, 0.000, 0.000)
		v_16.VelocityInheritance = 0.00
		v_16.Orientation = Enum.ParticleOrientation.FacingCamera
		v_16.EmissionDirection = Enum.NormalId.Back
		v_16.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_16.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3333, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3333, 1.0000))})
		v_16.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.10, 0.322, 0.000), NumberSequenceKeypoint.new(0.20, 0.627, 0.000), NumberSequenceKeypoint.new(0.30, 0.911, 0.000), NumberSequenceKeypoint.new(0.40, 1.174, 0.000), NumberSequenceKeypoint.new(0.50, 1.410, 0.000), NumberSequenceKeypoint.new(0.60, 1.615, 0.000), NumberSequenceKeypoint.new(0.70, 1.784, 0.000), NumberSequenceKeypoint.new(0.80, 1.910, 0.000), NumberSequenceKeypoint.new(0.90, 1.982, 0.000), NumberSequenceKeypoint.new(1.00, 2.000, 0.000), NumberSequenceKeypoint.new(1.00, 2.000, 0.000)})
		v_16.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_16.Enabled = true
		v_16.Parent = v_13
	end
	do
		local v_17 = Instance.new("ParticleEmitter")
		v_17.Name = "PinkSpec1"
		refMap["17"] = v_17
		v_17.Texture = "rbxassetid://16879789169"
		v_17.Rate = 100.00
		v_17.Speed = NumberRange.new(5.00, 50.00)
		v_17.Lifetime = NumberRange.new(0.30, 0.30)
		v_17.RotSpeed = NumberRange.new(0.00, 0.00)
		v_17.Rotation = NumberRange.new(-1000.00, 1000.00)
		v_17.SpreadAngle = Vector2.new(15.0, 15.0)
		v_17.LightEmission = 0.50
		v_17.LightInfluence = 0.00
		v_17.LockedToPart = true
		v_17.ZOffset = -0.50
		v_17.Drag = 15.00
		v_17.Acceleration = Vector3.new(50.000, 0.000, 0.000)
		v_17.VelocityInheritance = 0.00
		v_17.Orientation = Enum.ParticleOrientation.FacingCamera
		v_17.EmissionDirection = Enum.NormalId.Back
		v_17.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_17.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3059, 0.6078)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3059, 0.6078))})
		v_17.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.12, 0.312, 0.077), NumberSequenceKeypoint.new(0.21, 0.375, 0.125), NumberSequenceKeypoint.new(0.47, 0.250, 0.083), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_17.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_17.Enabled = true
		v_17.Parent = v_13
	end
	end
	do
		local v_18 = Instance.new("Beam")
		v_18.Name = "BlackAuraWave1"
		refMap["18"] = v_18
		v_18.Texture = "rbxassetid://89185242534188"
		v_18.TextureLength = 8.00
		v_18.TextureSpeed = 4.00
		v_18.TextureMode = Enum.TextureMode.Static
		v_18.LightEmission = 1.00
		v_18.LightInfluence = 0.00
		v_18.Width0 = 0.50
		v_18.Width1 = 5.00
		v_18.Segments = 25
		v_18.CurveSize0 = 0.00
		v_18.CurveSize1 = 4.00
		v_18.FaceCamera = true
		v_18.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3059, 0.6196)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3059, 0.6196))})
		v_18.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.13, 0.494, 0.000), NumberSequenceKeypoint.new(0.83, 0.681, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_18.Enabled = true
		table.insert(pendingRefs, { obj = v_18, prop = "Attachment0", ref = "10" })
		table.insert(pendingRefs, { obj = v_18, prop = "Attachment1", ref = "11" })
		v_18.Parent = v_3
	end
	end
	do
		local v_19 = Instance.new("Attachment")
		v_19.Name = "Wing"
		refMap["19"] = v_19
		v_19.CFrame = CFrame.new(0.571, 0.334, 0.500, 0.766, -0.166, 0.621, -0.166, 0.882, 0.442, -0.621, -0.442, 0.648)
		v_19.Parent = v_2
	do
		local v_20 = Instance.new("Attachment")
		v_20.Name = "A0"
		refMap["20"] = v_20
		v_20.CFrame = CFrame.new(0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_20.Parent = v_19
	end
	do
		local v_21 = Instance.new("Beam")
		v_21.Name = "MainBeam1"
		refMap["21"] = v_21
		v_21.Texture = "rbxassetid://86053242044615"
		v_21.TextureLength = 8.00
		v_21.TextureSpeed = 4.00
		v_21.TextureMode = Enum.TextureMode.Static
		v_21.LightEmission = 0.50
		v_21.LightInfluence = 0.00
		v_21.Width0 = 0.20
		v_21.Width1 = 4.50
		v_21.Segments = 25
		v_21.CurveSize0 = 0.00
		v_21.CurveSize1 = 4.00
		v_21.FaceCamera = true
		v_21.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.0000, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.0000, 1.0000))})
		v_21.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.11, 0.269, 0.000), NumberSequenceKeypoint.new(0.85, 0.494, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_21.Enabled = true
		table.insert(pendingRefs, { obj = v_21, prop = "Attachment0", ref = "20" })
		table.insert(pendingRefs, { obj = v_21, prop = "Attachment1", ref = "22" })
		v_21.Parent = v_19
	end
	do
		local v_22 = Instance.new("Beam")
		v_22.Name = "BlackAuraWave1"
		refMap["23"] = v_22
		v_22.Texture = "rbxassetid://89185242534188"
		v_22.TextureLength = 8.00
		v_22.TextureSpeed = 4.00
		v_22.TextureMode = Enum.TextureMode.Static
		v_22.LightEmission = 1.00
		v_22.LightInfluence = 0.00
		v_22.Width0 = 0.50
		v_22.Width1 = 5.00
		v_22.Segments = 25
		v_22.CurveSize0 = 0.00
		v_22.CurveSize1 = 4.00
		v_22.FaceCamera = true
		v_22.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3059, 0.6196)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3059, 0.6196))})
		v_22.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.13, 0.494, 0.000), NumberSequenceKeypoint.new(0.83, 0.681, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_22.Enabled = true
		table.insert(pendingRefs, { obj = v_22, prop = "Attachment0", ref = "20" })
		table.insert(pendingRefs, { obj = v_22, prop = "Attachment1", ref = "22" })
		v_22.Parent = v_19
	end
	do
		local v_23 = Instance.new("Beam")
		v_23.Name = "WingBeam1"
		refMap["24"] = v_23
		v_23.Texture = "rbxassetid://16892446507"
		v_23.TextureLength = 8.00
		v_23.TextureSpeed = 4.00
		v_23.TextureMode = Enum.TextureMode.Static
		v_23.LightEmission = 0.50
		v_23.LightInfluence = 0.00
		v_23.Width0 = 0.50
		v_23.Width1 = 5.00
		v_23.Segments = 25
		v_23.CurveSize0 = 0.00
		v_23.CurveSize1 = 4.00
		v_23.FaceCamera = true
		v_23.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.6667, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.6667, 1.0000))})
		v_23.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.13, 0.494, 0.000), NumberSequenceKeypoint.new(0.83, 0.681, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_23.Enabled = true
		table.insert(pendingRefs, { obj = v_23, prop = "Attachment0", ref = "20" })
		table.insert(pendingRefs, { obj = v_23, prop = "Attachment1", ref = "22" })
		v_23.Parent = v_19
	end
	do
		local v_24 = Instance.new("Attachment")
		v_24.Name = "Particles2"
		refMap["25"] = v_24
		v_24.CFrame = CFrame.new(-0.593, -0.000, 4.093, 0.521, -0.000, 0.853, 0.000, 1.000, 0.000, -0.853, 0.000, 0.521)
		v_24.Parent = v_19
	do
		local v_25 = Instance.new("ParticleEmitter")
		v_25.Name = "BlackSpec1"
		refMap["26"] = v_25
		v_25.Texture = "rbxassetid://16879789169"
		v_25.Rate = 100.00
		v_25.Speed = NumberRange.new(5.00, 50.00)
		v_25.Lifetime = NumberRange.new(0.30, 0.30)
		v_25.RotSpeed = NumberRange.new(0.00, 0.00)
		v_25.Rotation = NumberRange.new(-1000.00, 1000.00)
		v_25.SpreadAngle = Vector2.new(15.0, 15.0)
		v_25.LightEmission = 1.00
		v_25.LightInfluence = 0.00
		v_25.LockedToPart = true
		v_25.ZOffset = -0.50
		v_25.Drag = 35.00
		v_25.Acceleration = Vector3.new(50.000, 0.000, 0.000)
		v_25.VelocityInheritance = 0.00
		v_25.Orientation = Enum.ParticleOrientation.FacingCamera
		v_25.EmissionDirection = Enum.NormalId.Back
		v_25.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_25.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3333, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3333, 1.0000))})
		v_25.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.12, 0.312, 0.077), NumberSequenceKeypoint.new(0.21, 0.375, 0.125), NumberSequenceKeypoint.new(0.47, 0.250, 0.083), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_25.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_25.Enabled = true
		v_25.Parent = v_24
	end
	do
		local v_26 = Instance.new("ParticleEmitter")
		v_26.Name = "WingFlame1"
		refMap["27"] = v_26
		v_26.Texture = "rbxassetid://17506974962"
		v_26.Rate = 250.00
		v_26.Speed = NumberRange.new(25.00, 175.00)
		v_26.Lifetime = NumberRange.new(0.20, 0.20)
		v_26.RotSpeed = NumberRange.new(0.00, 0.00)
		v_26.Rotation = NumberRange.new(-1000.00, 1000.00)
		v_26.SpreadAngle = Vector2.new(3.0, 3.0)
		v_26.LightEmission = 1.00
		v_26.LightInfluence = 0.00
		v_26.LockedToPart = true
		v_26.ZOffset = -0.10
		v_26.Drag = 200.00
		v_26.Acceleration = Vector3.new(200.000, 0.000, 0.000)
		v_26.VelocityInheritance = 0.00
		v_26.Orientation = Enum.ParticleOrientation.FacingCamera
		v_26.EmissionDirection = Enum.NormalId.Back
		v_26.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_26.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.0784, 0.7529)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.0784, 0.7529))})
		v_26.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 1.803, 0.000)})
		v_26.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_26.Enabled = true
		v_26.Parent = v_24
	end
	do
		local v_27 = Instance.new("ParticleEmitter")
		v_27.Name = "WingFlame2"
		refMap["28"] = v_27
		v_27.Texture = "rbxassetid://16860219678"
		v_27.Rate = 25.00
		v_27.Speed = NumberRange.new(25.00, 175.00)
		v_27.Lifetime = NumberRange.new(0.20, 0.20)
		v_27.RotSpeed = NumberRange.new(0.00, 0.00)
		v_27.Rotation = NumberRange.new(-1000.00, 1000.00)
		v_27.SpreadAngle = Vector2.new(3.0, 3.0)
		v_27.LightEmission = -1.00
		v_27.LightInfluence = 0.00
		v_27.LockedToPart = true
		v_27.ZOffset = -0.10
		v_27.Drag = 1000.00
		v_27.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_27.VelocityInheritance = 0.00
		v_27.Orientation = Enum.ParticleOrientation.FacingCamera
		v_27.EmissionDirection = Enum.NormalId.Back
		v_27.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_27.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3333, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3333, 1.0000))})
		v_27.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 4.262, 0.000)})
		v_27.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_27.Enabled = true
		v_27.Parent = v_24
	end
	do
		local v_28 = Instance.new("ParticleEmitter")
		v_28.Name = "PinkSpec1"
		refMap["29"] = v_28
		v_28.Texture = "rbxassetid://16879789169"
		v_28.Rate = 100.00
		v_28.Speed = NumberRange.new(5.00, 50.00)
		v_28.Lifetime = NumberRange.new(0.30, 0.30)
		v_28.RotSpeed = NumberRange.new(0.00, 0.00)
		v_28.Rotation = NumberRange.new(-1000.00, 1000.00)
		v_28.SpreadAngle = Vector2.new(15.0, 15.0)
		v_28.LightEmission = 0.50
		v_28.LightInfluence = 0.00
		v_28.LockedToPart = true
		v_28.ZOffset = -0.50
		v_28.Drag = 35.00
		v_28.Acceleration = Vector3.new(50.000, 0.000, 0.000)
		v_28.VelocityInheritance = 0.00
		v_28.Orientation = Enum.ParticleOrientation.FacingCamera
		v_28.EmissionDirection = Enum.NormalId.Back
		v_28.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_28.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3059, 0.6078)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3059, 0.6078))})
		v_28.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.12, 0.312, 0.077), NumberSequenceKeypoint.new(0.21, 0.375, 0.125), NumberSequenceKeypoint.new(0.47, 0.250, 0.083), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_28.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_28.Enabled = true
		v_28.Parent = v_24
	end
	end
	do
		local v_29 = Instance.new("Attachment")
		v_29.Name = "Particles"
		refMap["30"] = v_29
		v_29.CFrame = CFrame.new(-0.294, -0.000, -0.059, 0.980, 0.000, -0.198, -0.000, 1.000, 0.000, 0.198, 0.000, 0.980)
		v_29.Parent = v_19
	do
		local v_30 = Instance.new("ParticleEmitter")
		v_30.Name = "WingFlame2"
		refMap["31"] = v_30
		v_30.Texture = "rbxassetid://16860219678"
		v_30.Rate = 25.00
		v_30.Speed = NumberRange.new(25.00, 175.00)
		v_30.Lifetime = NumberRange.new(0.20, 0.20)
		v_30.RotSpeed = NumberRange.new(0.00, 0.00)
		v_30.Rotation = NumberRange.new(-1000.00, 1000.00)
		v_30.SpreadAngle = Vector2.new(3.0, 3.0)
		v_30.LightEmission = -1.00
		v_30.LightInfluence = 0.00
		v_30.LockedToPart = true
		v_30.ZOffset = -0.10
		v_30.Drag = 75.00
		v_30.Acceleration = Vector3.new(200.000, 0.000, 0.000)
		v_30.VelocityInheritance = 0.00
		v_30.Orientation = Enum.ParticleOrientation.FacingCamera
		v_30.EmissionDirection = Enum.NormalId.Back
		v_30.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_30.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3333, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3333, 1.0000))})
		v_30.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.10, 0.322, 0.000), NumberSequenceKeypoint.new(0.20, 0.627, 0.000), NumberSequenceKeypoint.new(0.30, 0.911, 0.000), NumberSequenceKeypoint.new(0.40, 1.174, 0.000), NumberSequenceKeypoint.new(0.50, 1.410, 0.000), NumberSequenceKeypoint.new(0.60, 1.615, 0.000), NumberSequenceKeypoint.new(0.70, 1.784, 0.000), NumberSequenceKeypoint.new(0.80, 1.910, 0.000), NumberSequenceKeypoint.new(0.90, 1.982, 0.000), NumberSequenceKeypoint.new(1.00, 2.000, 0.000), NumberSequenceKeypoint.new(1.00, 2.000, 0.000)})
		v_30.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_30.Enabled = true
		v_30.Parent = v_29
	end
	do
		local v_31 = Instance.new("ParticleEmitter")
		v_31.Name = "PinkSpec1"
		refMap["32"] = v_31
		v_31.Texture = "rbxassetid://16879789169"
		v_31.Rate = 100.00
		v_31.Speed = NumberRange.new(5.00, 50.00)
		v_31.Lifetime = NumberRange.new(0.30, 0.30)
		v_31.RotSpeed = NumberRange.new(0.00, 0.00)
		v_31.Rotation = NumberRange.new(-1000.00, 1000.00)
		v_31.SpreadAngle = Vector2.new(15.0, 15.0)
		v_31.LightEmission = 0.50
		v_31.LightInfluence = 0.00
		v_31.LockedToPart = true
		v_31.ZOffset = -0.50
		v_31.Drag = 15.00
		v_31.Acceleration = Vector3.new(50.000, 0.000, 0.000)
		v_31.VelocityInheritance = 0.00
		v_31.Orientation = Enum.ParticleOrientation.FacingCamera
		v_31.EmissionDirection = Enum.NormalId.Back
		v_31.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_31.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3059, 0.6078)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3059, 0.6078))})
		v_31.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.12, 0.312, 0.077), NumberSequenceKeypoint.new(0.21, 0.375, 0.125), NumberSequenceKeypoint.new(0.47, 0.250, 0.083), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_31.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_31.Enabled = true
		v_31.Parent = v_29
	end
	do
		local v_32 = Instance.new("ParticleEmitter")
		v_32.Name = "BlackSpec1"
		refMap["33"] = v_32
		v_32.Texture = "rbxassetid://16879789169"
		v_32.Rate = 100.00
		v_32.Speed = NumberRange.new(5.00, 50.00)
		v_32.Lifetime = NumberRange.new(0.30, 0.30)
		v_32.RotSpeed = NumberRange.new(0.00, 0.00)
		v_32.Rotation = NumberRange.new(-1000.00, 1000.00)
		v_32.SpreadAngle = Vector2.new(15.0, 15.0)
		v_32.LightEmission = 1.00
		v_32.LightInfluence = 0.00
		v_32.LockedToPart = true
		v_32.ZOffset = -0.50
		v_32.Drag = 15.00
		v_32.Acceleration = Vector3.new(50.000, 0.000, 0.000)
		v_32.VelocityInheritance = 0.00
		v_32.Orientation = Enum.ParticleOrientation.FacingCamera
		v_32.EmissionDirection = Enum.NormalId.Back
		v_32.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_32.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3333, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3333, 1.0000))})
		v_32.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.12, 0.312, 0.077), NumberSequenceKeypoint.new(0.21, 0.375, 0.125), NumberSequenceKeypoint.new(0.47, 0.250, 0.083), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_32.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_32.Enabled = true
		v_32.Parent = v_29
	end
	do
		local v_33 = Instance.new("ParticleEmitter")
		v_33.Name = "WingFlame1"
		refMap["34"] = v_33
		v_33.Texture = "rbxassetid://17506974962"
		v_33.Rate = 250.00
		v_33.Speed = NumberRange.new(25.00, 175.00)
		v_33.Lifetime = NumberRange.new(0.20, 0.20)
		v_33.RotSpeed = NumberRange.new(0.00, 0.00)
		v_33.Rotation = NumberRange.new(-1000.00, 1000.00)
		v_33.SpreadAngle = Vector2.new(3.0, 3.0)
		v_33.LightEmission = 1.00
		v_33.LightInfluence = 0.00
		v_33.LockedToPart = true
		v_33.ZOffset = -0.10
		v_33.Drag = 75.00
		v_33.Acceleration = Vector3.new(200.000, 0.000, 0.000)
		v_33.VelocityInheritance = 0.00
		v_33.Orientation = Enum.ParticleOrientation.FacingCamera
		v_33.EmissionDirection = Enum.NormalId.Back
		v_33.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
		v_33.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.0784, 0.7529)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.0784, 0.7529))})
		v_33.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(0.10, 0.161, 0.000), NumberSequenceKeypoint.new(0.20, 0.313, 0.000), NumberSequenceKeypoint.new(0.30, 0.456, 0.000), NumberSequenceKeypoint.new(0.40, 0.587, 0.000), NumberSequenceKeypoint.new(0.50, 0.705, 0.000), NumberSequenceKeypoint.new(0.60, 0.808, 0.000), NumberSequenceKeypoint.new(0.70, 0.892, 0.000), NumberSequenceKeypoint.new(0.80, 0.955, 0.000), NumberSequenceKeypoint.new(0.90, 0.991, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_33.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_33.Enabled = true
		v_33.Parent = v_29
	end
	end
	do
		local v_34 = Instance.new("Attachment")
		v_34.Name = "A1"
		refMap["22"] = v_34
		v_34.CFrame = CFrame.new(2.000, -0.000, 5.200, 1.000, 0.000, -0.000, -0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_34.Parent = v_19
	end
	end
	end
	end

	for _, pending in ipairs(pendingRefs) do
		local target = refMap[pending.ref]
		if target then
			pending.obj[pending.prop] = target
		end
	end
end

local function buildAura15(auraFolder: Folder)
	local refMap = {}
	local pendingRefs = {}

	do
		local v_0 = Instance.new("Model")
		v_0.Name = "Aura15"
		refMap["0"] = v_0
		v_0:SetAttribute("CosmeticType", "Aura")
		v_0:SetAttribute("CosmeticId", "Aura15")
		v_0:SetAttribute("TargetPart", "HumanoidRootPart")
		v_0:SetAttribute("SupportsR6", true)
		v_0:SetAttribute("SupportsR15", true)
		v_0.Parent = auraFolder
	do
		local v_1 = Instance.new("CFrameValue")
		v_1.Name = "LocalOffset"
		refMap["2"] = v_1
		v_1.Value = CFrame.new(0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_1.Parent = v_0
	end
	do
		local v_2 = Instance.new("Part")
		v_2.Name = "EffectHolder"
		refMap["1"] = v_2
		v_2.Anchored = false
		v_2.CanCollide = false
		v_2.CanTouch = false
		v_2.CanQuery = false
		v_2.Massless = true
		v_2.CastShadow = false
		v_2.Transparency = 1.00
		v_2.Size = Vector3.new(2.000, 2.000, 1.000)
		v_2.Parent = v_0
	do
		local v_3 = Instance.new("Attachment")
		v_3.Name = "KingIconDoodle"
		refMap["3"] = v_3
		v_3.CFrame = CFrame.new(0.000, 2.807, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_3.Parent = v_2
	do
		local v_4 = Instance.new("ParticleEmitter")
		v_4.Name = "ParticleEmitter"
		refMap["4"] = v_4
		v_4.Texture = "rbxassetid://106539409304542"
		v_4.Rate = 2.00
		v_4.Speed = NumberRange.new(0.00, 0.00)
		v_4.Lifetime = NumberRange.new(5.00, 10.00)
		v_4.RotSpeed = NumberRange.new(0.00, 0.00)
		v_4.Rotation = NumberRange.new(0.00, 0.00)
		v_4.SpreadAngle = Vector2.new(0.0, 0.0)
		v_4.LightEmission = 0.00
		v_4.LightInfluence = 0.00
		v_4.LockedToPart = true
		v_4.ZOffset = 2.00
		v_4.Drag = 0.00
		v_4.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_4.VelocityInheritance = 0.00
		v_4.Orientation = Enum.ParticleOrientation.FacingCamera
		v_4.EmissionDirection = Enum.NormalId.Top
		v_4.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_4.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.6863, 0.5294, 0.3255)), ColorSequenceKeypoint.new(1.00, Color3.new(0.6863, 0.5294, 0.3255))})
		v_4.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_4.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_4.Enabled = true
		v_4.Parent = v_3
	end
	end
	do
		local v_5 = Instance.new("Attachment")
		v_5.Name = "wtvtsisIconDoodle"
		refMap["5"] = v_5
		v_5.CFrame = CFrame.new(-0.697, -1.038, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_5.Parent = v_2
	do
		local v_6 = Instance.new("ParticleEmitter")
		v_6.Name = "ParticleEmitter"
		refMap["6"] = v_6
		v_6.Texture = "rbxassetid://113829952921724"
		v_6.Rate = 2.00
		v_6.Speed = NumberRange.new(0.00, 0.00)
		v_6.Lifetime = NumberRange.new(5.00, 10.00)
		v_6.RotSpeed = NumberRange.new(0.00, 0.00)
		v_6.Rotation = NumberRange.new(0.00, 0.00)
		v_6.SpreadAngle = Vector2.new(0.0, 0.0)
		v_6.LightEmission = 0.00
		v_6.LightInfluence = 0.00
		v_6.LockedToPart = true
		v_6.ZOffset = 2.00
		v_6.Drag = 0.00
		v_6.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_6.VelocityInheritance = 0.00
		v_6.Orientation = Enum.ParticleOrientation.FacingCamera
		v_6.EmissionDirection = Enum.NormalId.Top
		v_6.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_6.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.9804, 0.7098, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.9804, 0.7098, 1.0000))})
		v_6.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.700, 0.000), NumberSequenceKeypoint.new(1.00, 0.700, 0.000)})
		v_6.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_6.Enabled = true
		v_6.Parent = v_5
	end
	end
	do
		local v_7 = Instance.new("Attachment")
		v_7.Name = "randomgoytsisIconDoodle"
		refMap["7"] = v_7
		v_7.CFrame = CFrame.new(-2.230, 2.743, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_7.Parent = v_2
	do
		local v_8 = Instance.new("ParticleEmitter")
		v_8.Name = "ParticleEmitter"
		refMap["8"] = v_8
		v_8.Texture = "rbxassetid://116039852161057"
		v_8.Rate = 2.00
		v_8.Speed = NumberRange.new(0.00, 0.00)
		v_8.Lifetime = NumberRange.new(5.00, 10.00)
		v_8.RotSpeed = NumberRange.new(0.00, 0.00)
		v_8.Rotation = NumberRange.new(0.00, 0.00)
		v_8.SpreadAngle = Vector2.new(0.0, 0.0)
		v_8.LightEmission = 0.00
		v_8.LightInfluence = 0.00
		v_8.LockedToPart = true
		v_8.ZOffset = 2.00
		v_8.Drag = 0.00
		v_8.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_8.VelocityInheritance = 0.00
		v_8.Orientation = Enum.ParticleOrientation.FacingCamera
		v_8.EmissionDirection = Enum.NormalId.Top
		v_8.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_8.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 1.0000, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 1.0000, 1.0000))})
		v_8.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.800, 0.000), NumberSequenceKeypoint.new(1.00, 0.800, 0.000)})
		v_8.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_8.Enabled = true
		v_8.Parent = v_7
	end
	end
	do
		local v_9 = Instance.new("Attachment")
		v_9.Name = "SunIconDoodle"
		refMap["9"] = v_9
		v_9.CFrame = CFrame.new(2.145, 2.807, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_9.Parent = v_2
	do
		local v_10 = Instance.new("ParticleEmitter")
		v_10.Name = "ParticleEmitter"
		refMap["10"] = v_10
		v_10.Texture = "rbxassetid://88431730556422"
		v_10.Rate = 2.00
		v_10.Speed = NumberRange.new(0.00, 0.00)
		v_10.Lifetime = NumberRange.new(5.00, 10.00)
		v_10.RotSpeed = NumberRange.new(0.00, 0.00)
		v_10.Rotation = NumberRange.new(0.00, 0.00)
		v_10.SpreadAngle = Vector2.new(0.0, 0.0)
		v_10.LightEmission = 0.00
		v_10.LightInfluence = 0.00
		v_10.LockedToPart = true
		v_10.ZOffset = 2.00
		v_10.Drag = 0.00
		v_10.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_10.VelocityInheritance = 0.00
		v_10.Orientation = Enum.ParticleOrientation.FacingCamera
		v_10.EmissionDirection = Enum.NormalId.Top
		v_10.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_10.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.9725, 0.5725)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.9725, 0.5725))})
		v_10.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_10.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_10.Enabled = true
		v_10.Parent = v_9
	end
	end
	do
		local v_11 = Instance.new("Attachment")
		v_11.Name = "CloudIconDoodle"
		refMap["11"] = v_11
		v_11.CFrame = CFrame.new(2.145, 1.985, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_11.Parent = v_2
	do
		local v_12 = Instance.new("ParticleEmitter")
		v_12.Name = "ParticleEmitter"
		refMap["12"] = v_12
		v_12.Texture = "rbxassetid://134174212748707"
		v_12.Rate = 2.00
		v_12.Speed = NumberRange.new(0.00, 0.00)
		v_12.Lifetime = NumberRange.new(5.00, 10.00)
		v_12.RotSpeed = NumberRange.new(0.00, 0.00)
		v_12.Rotation = NumberRange.new(0.00, 0.00)
		v_12.SpreadAngle = Vector2.new(0.0, 0.0)
		v_12.LightEmission = 0.00
		v_12.LightInfluence = 0.00
		v_12.LockedToPart = true
		v_12.ZOffset = 3.00
		v_12.Drag = 0.00
		v_12.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_12.VelocityInheritance = 0.00
		v_12.Orientation = Enum.ParticleOrientation.FacingCamera
		v_12.EmissionDirection = Enum.NormalId.Top
		v_12.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_12.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 1.0000, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 1.0000, 1.0000))})
		v_12.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_12.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_12.Enabled = true
		v_12.Parent = v_11
	end
	end
	do
		local v_13 = Instance.new("Attachment")
		v_13.Name = "randommad?tsisIconDoodle"
		refMap["13"] = v_13
		v_13.CFrame = CFrame.new(-2.747, 3.350, 0.000, 0.906, -0.423, 0.000, 0.423, 0.906, -0.000, 0.000, 0.000, 1.000)
		v_13.Parent = v_2
	do
		local v_14 = Instance.new("ParticleEmitter")
		v_14.Name = "msg"
		refMap["14"] = v_14
		v_14.Texture = "rbxassetid://84140306529330"
		v_14.Rate = 2.00
		v_14.Speed = NumberRange.new(0.00, 0.00)
		v_14.Lifetime = NumberRange.new(5.00, 10.00)
		v_14.RotSpeed = NumberRange.new(0.00, 0.00)
		v_14.Rotation = NumberRange.new(-25.00, -25.00)
		v_14.SpreadAngle = Vector2.new(0.0, 0.0)
		v_14.LightEmission = 0.00
		v_14.LightInfluence = 0.00
		v_14.LockedToPart = true
		v_14.ZOffset = 3.00
		v_14.Drag = 0.00
		v_14.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_14.VelocityInheritance = 0.00
		v_14.Orientation = Enum.ParticleOrientation.FacingCamera
		v_14.EmissionDirection = Enum.NormalId.Top
		v_14.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_14.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 1.0000, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 1.0000, 1.0000))})
		v_14.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.800, 0.000), NumberSequenceKeypoint.new(1.00, 0.800, 0.000)})
		v_14.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_14.Enabled = true
		v_14.Parent = v_13
	end
	end
	do
		local v_15 = Instance.new("Attachment")
		v_15.Name = "wtvtsisIconDoodle"
		refMap["15"] = v_15
		v_15.CFrame = CFrame.new(1.300, -1.470, -0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_15.Parent = v_2
	do
		local v_16 = Instance.new("ParticleEmitter")
		v_16.Name = "ParticleEmitter"
		refMap["16"] = v_16
		v_16.Texture = "rbxassetid://74843486156502"
		v_16.Rate = 2.00
		v_16.Speed = NumberRange.new(0.00, 0.00)
		v_16.Lifetime = NumberRange.new(5.00, 10.00)
		v_16.RotSpeed = NumberRange.new(0.00, 0.00)
		v_16.Rotation = NumberRange.new(0.00, 0.00)
		v_16.SpreadAngle = Vector2.new(0.0, 0.0)
		v_16.LightEmission = 0.00
		v_16.LightInfluence = 0.00
		v_16.LockedToPart = true
		v_16.ZOffset = 2.00
		v_16.Drag = 0.00
		v_16.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_16.VelocityInheritance = 0.00
		v_16.Orientation = Enum.ParticleOrientation.FacingCamera
		v_16.EmissionDirection = Enum.NormalId.Top
		v_16.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_16.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5294, 0.6392, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5294, 0.6392, 1.0000))})
		v_16.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.800, 0.000), NumberSequenceKeypoint.new(1.00, 0.800, 0.000)})
		v_16.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_16.Enabled = true
		v_16.Parent = v_15
	end
	end
	do
		local v_17 = Instance.new("Attachment")
		v_17.Name = "randommad?tsisIconDoodle"
		refMap["17"] = v_17
		v_17.CFrame = CFrame.new(-2.735, 3.400, -0.000, 0.906, -0.423, -0.000, 0.423, 0.906, 0.000, 0.000, -0.000, 1.000)
		v_17.Parent = v_2
	do
		local v_18 = Instance.new("ParticleEmitter")
		v_18.Name = "msg"
		refMap["18"] = v_18
		v_18.Texture = "rbxassetid://123739701346737"
		v_18.Rate = 2.00
		v_18.Speed = NumberRange.new(0.00, 0.00)
		v_18.Lifetime = NumberRange.new(5.00, 10.00)
		v_18.RotSpeed = NumberRange.new(0.00, 0.00)
		v_18.Rotation = NumberRange.new(-25.00, -25.00)
		v_18.SpreadAngle = Vector2.new(0.0, 0.0)
		v_18.LightEmission = 0.00
		v_18.LightInfluence = 0.00
		v_18.LockedToPart = true
		v_18.ZOffset = 3.50
		v_18.Drag = 0.00
		v_18.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_18.VelocityInheritance = 0.00
		v_18.Orientation = Enum.ParticleOrientation.FacingCamera
		v_18.EmissionDirection = Enum.NormalId.Top
		v_18.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_18.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.8980, 0.5255, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.8980, 0.5255, 1.0000))})
		v_18.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.300, 0.000), NumberSequenceKeypoint.new(1.00, 0.300, 0.000)})
		v_18.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_18.Enabled = true
		v_18.Parent = v_17
	end
	end
	do
		local v_19 = Instance.new("Attachment")
		v_19.Name = "randommad?tsisIconDoodle"
		refMap["19"] = v_19
		v_19.CFrame = CFrame.new(-1.572, 3.297, -0.000, 0.766, 0.643, -0.000, -0.643, 0.766, -0.000, 0.000, 0.000, 1.000)
		v_19.Parent = v_2
	do
		local v_20 = Instance.new("ParticleEmitter")
		v_20.Name = "msg"
		refMap["20"] = v_20
		v_20.Texture = "rbxassetid://89851631261786"
		v_20.Rate = 2.00
		v_20.Speed = NumberRange.new(0.00, 0.00)
		v_20.Lifetime = NumberRange.new(5.00, 10.00)
		v_20.RotSpeed = NumberRange.new(0.00, 0.00)
		v_20.Rotation = NumberRange.new(25.00, 25.00)
		v_20.SpreadAngle = Vector2.new(0.0, 0.0)
		v_20.LightEmission = 0.00
		v_20.LightInfluence = 0.00
		v_20.LockedToPart = true
		v_20.ZOffset = 3.50
		v_20.Drag = 0.00
		v_20.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_20.VelocityInheritance = 0.00
		v_20.Orientation = Enum.ParticleOrientation.FacingCamera
		v_20.EmissionDirection = Enum.NormalId.Top
		v_20.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_20.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.3294, 0.3294)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.3294, 0.3294))})
		v_20.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.800, 0.000), NumberSequenceKeypoint.new(1.00, 0.800, 0.000)})
		v_20.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_20.Enabled = true
		v_20.Parent = v_19
	end
	end
	do
		local v_21 = Instance.new("Attachment")
		v_21.Name = "glow"
		refMap["21"] = v_21
		v_21.CFrame = CFrame.new(0.000, 0.170, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000, 0.000, 0.000, 0.000, 1.000)
		v_21.Parent = v_2
	do
		local v_22 = Instance.new("ParticleEmitter")
		v_22.Name = "glowokay"
		refMap["22"] = v_22
		v_22.Texture = "rbxassetid://6673021984"
		v_22.Rate = 2.00
		v_22.Speed = NumberRange.new(0.00, 0.00)
		v_22.Lifetime = NumberRange.new(5.00, 10.00)
		v_22.RotSpeed = NumberRange.new(0.00, 0.00)
		v_22.Rotation = NumberRange.new(0.00, 0.00)
		v_22.SpreadAngle = Vector2.new(0.0, 0.0)
		v_22.LightEmission = 0.00
		v_22.LightInfluence = 0.00
		v_22.LockedToPart = true
		v_22.ZOffset = -1.00
		v_22.Drag = 0.00
		v_22.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_22.VelocityInheritance = 0.00
		v_22.Orientation = Enum.ParticleOrientation.FacingCamera
		v_22.EmissionDirection = Enum.NormalId.Top
		v_22.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_22.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.6863, 0.6863, 0.6863)), ColorSequenceKeypoint.new(1.00, Color3.new(0.6863, 0.6863, 0.6863))})
		v_22.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 4.500, 0.000), NumberSequenceKeypoint.new(1.00, 4.500, 0.000)})
		v_22.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 1.000, 0.000), NumberSequenceKeypoint.new(0.50, 0.907, 0.000), NumberSequenceKeypoint.new(1.00, 1.000, 0.000)})
		v_22.Enabled = true
		v_22.Parent = v_21
	end
	end
	end
	do
		local v_23 = Instance.new("Part")
		v_23.Name = "plantgoystuff"
		refMap["23"] = v_23
		v_23.Anchored = false
		v_23.CanCollide = false
		v_23.CanTouch = false
		v_23.CanQuery = false
		v_23.Massless = true
		v_23.CastShadow = false
		v_23.Transparency = 1.00
		v_23.Size = Vector3.new(4.790, 0.001, 3.760)
		v_23.CFrame = CFrame.new(-89.556, 31.226, -34.059, -0.676, 0.000, -0.737, 0.000, 1.000, 0.000, 0.737, 0.000, -0.676)
		v_23.Color = Color3.fromRGB(163, 162, 165)
		v_23.Parent = v_0
	do
		local v_24 = Instance.new("ParticleEmitter")
		v_24.Name = "ParticleEmitter"
		refMap["24"] = v_24
		v_24.Texture = "rbxassetid://126464083910829"
		v_24.Rate = 2.00
		v_24.Speed = NumberRange.new(0.00, 0.00)
		v_24.Lifetime = NumberRange.new(1.00, 1.00)
		v_24.RotSpeed = NumberRange.new(0.00, 0.00)
		v_24.Rotation = NumberRange.new(0.00, 0.00)
		v_24.SpreadAngle = Vector2.new(0.0, 0.0)
		v_24.LightEmission = 0.00
		v_24.LightInfluence = 0.00
		v_24.LockedToPart = true
		v_24.ZOffset = 1.00
		v_24.Drag = 0.00
		v_24.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_24.VelocityInheritance = 0.00
		v_24.Orientation = Enum.ParticleOrientation.FacingCamera
		v_24.EmissionDirection = Enum.NormalId.Top
		v_24.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_24.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.5961, 1.0000, 0.4863)), ColorSequenceKeypoint.new(1.00, Color3.new(0.5961, 1.0000, 0.4863))})
		v_24.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.800, 0.000), NumberSequenceKeypoint.new(0.90, 0.800, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_24.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_24.Enabled = true
		v_24.Parent = v_23
	end
	do
		local v_25 = Instance.new("ParticleEmitter")
		v_25.Name = "ParticleEmitter"
		refMap["25"] = v_25
		v_25.Texture = "rbxassetid://76043763689412"
		v_25.Rate = 2.00
		v_25.Speed = NumberRange.new(2.00, 5.00)
		v_25.Lifetime = NumberRange.new(1.00, 1.00)
		v_25.RotSpeed = NumberRange.new(-12.00, 12.00)
		v_25.Rotation = NumberRange.new(-360.00, 360.00)
		v_25.SpreadAngle = Vector2.new(0.0, 0.0)
		v_25.LightEmission = 0.00
		v_25.LightInfluence = 0.00
		v_25.LockedToPart = true
		v_25.ZOffset = 2.00
		v_25.Drag = 0.00
		v_25.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_25.VelocityInheritance = 0.00
		v_25.Orientation = Enum.ParticleOrientation.FacingCamera
		v_25.EmissionDirection = Enum.NormalId.Top
		v_25.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_25.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.8510, 0.8314)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.8510, 0.8314))})
		v_25.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.400, 0.000), NumberSequenceKeypoint.new(0.90, 0.400, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_25.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_25.Enabled = true
		v_25.Parent = v_23
	end
	do
		local v_26 = Instance.new("ParticleEmitter")
		v_26.Name = "ParticleEmitter"
		refMap["26"] = v_26
		v_26.Texture = "rbxassetid://121700335287213"
		v_26.Rate = 2.00
		v_26.Speed = NumberRange.new(2.00, 5.00)
		v_26.Lifetime = NumberRange.new(1.00, 1.00)
		v_26.RotSpeed = NumberRange.new(-12.00, 12.00)
		v_26.Rotation = NumberRange.new(-360.00, 360.00)
		v_26.SpreadAngle = Vector2.new(0.0, 0.0)
		v_26.LightEmission = 0.00
		v_26.LightInfluence = 0.00
		v_26.LockedToPart = true
		v_26.ZOffset = 2.00
		v_26.Drag = 0.00
		v_26.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_26.VelocityInheritance = 0.00
		v_26.Orientation = Enum.ParticleOrientation.FacingCamera
		v_26.EmissionDirection = Enum.NormalId.Top
		v_26.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_26.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(0.3451, 0.2980, 1.0000)), ColorSequenceKeypoint.new(1.00, Color3.new(0.3451, 0.2980, 1.0000))})
		v_26.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.400, 0.000), NumberSequenceKeypoint.new(0.90, 0.400, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_26.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_26.Enabled = true
		v_26.Parent = v_23
	end
	do
		local v_27 = Instance.new("ParticleEmitter")
		v_27.Name = "ParticleEmitter"
		refMap["27"] = v_27
		v_27.Texture = "rbxassetid://72993119874716"
		v_27.Rate = 2.00
		v_27.Speed = NumberRange.new(2.00, 5.00)
		v_27.Lifetime = NumberRange.new(1.00, 1.00)
		v_27.RotSpeed = NumberRange.new(-12.00, 12.00)
		v_27.Rotation = NumberRange.new(-360.00, 360.00)
		v_27.SpreadAngle = Vector2.new(0.0, 0.0)
		v_27.LightEmission = 0.00
		v_27.LightInfluence = 0.00
		v_27.LockedToPart = true
		v_27.ZOffset = 2.00
		v_27.Drag = 0.00
		v_27.Acceleration = Vector3.new(0.000, 0.000, 0.000)
		v_27.VelocityInheritance = 0.00
		v_27.Orientation = Enum.ParticleOrientation.FacingCamera
		v_27.EmissionDirection = Enum.NormalId.Top
		v_27.FlipbookLayout = Enum.ParticleFlipbookLayout.None
		v_27.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, Color3.new(1.0000, 0.9137, 0.5961)), ColorSequenceKeypoint.new(1.00, Color3.new(1.0000, 0.9137, 0.5961))})
		v_27.Size = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.400, 0.000), NumberSequenceKeypoint.new(0.90, 0.400, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_27.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0.00, 0.000, 0.000), NumberSequenceKeypoint.new(1.00, 0.000, 0.000)})
		v_27.Enabled = true
		v_27.Parent = v_23
	end
	do
		local v_28 = Instance.new("WeldConstraint")
		v_28.Name = "plantgoystuff_Weld"
		refMap["28"] = v_28
		v_28.Parent = v_23
	end
	end
	end

	for _, pending in ipairs(pendingRefs) do
		local target = refMap[pending.ref]
		if target then
			pending.obj[pending.prop] = target
		end
	end
end

function NewAurasFactory.Build(auraFolder: Folder)
	local existing_Aura08 = auraFolder:FindFirstChild("Aura08")
	if existing_Aura08 then existing_Aura08:Destroy() end
	buildAura08(auraFolder)
	local existing_Aura09 = auraFolder:FindFirstChild("Aura09")
	if existing_Aura09 then existing_Aura09:Destroy() end
	buildAura09(auraFolder)
	local existing_Aura10 = auraFolder:FindFirstChild("Aura10")
	if existing_Aura10 then existing_Aura10:Destroy() end
	buildAura10(auraFolder)
	local existing_Aura11 = auraFolder:FindFirstChild("Aura11")
	if existing_Aura11 then existing_Aura11:Destroy() end
	buildAura11(auraFolder)
	local existing_Aura12 = auraFolder:FindFirstChild("Aura12")
	if existing_Aura12 then existing_Aura12:Destroy() end
	buildAura12(auraFolder)
	local existing_Aura13 = auraFolder:FindFirstChild("Aura13")
	if existing_Aura13 then existing_Aura13:Destroy() end
	buildAura13(auraFolder)
	local existing_Aura14 = auraFolder:FindFirstChild("Aura14")
	if existing_Aura14 then existing_Aura14:Destroy() end
	buildAura14(auraFolder)
	local existing_Aura15 = auraFolder:FindFirstChild("Aura15")
	if existing_Aura15 then existing_Aura15:Destroy() end
	buildAura15(auraFolder)
	if CollectionService then
		for _, child in ipairs(auraFolder:GetChildren()) do
			if child:IsA("Model") then
				CollectionService:AddTag(child, "LoadVFXTextures")
			end
		end
	end
	return true
end

return NewAurasFactory
