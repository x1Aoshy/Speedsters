-- SkinPreview.luau
-- A skin's picture in the Index and the Evolve panel. Most skins show the catalog
-- thumbnail of their PreviewAssetId (the mask, the hair or the rig's asset). A skin worn
-- from a rig kept in ReplicatedStorage.SkinRigs (Superman, A-Train: PreviewRig) shows the
-- rig itself, a head-and-chest portrait drawn in a ViewportFrame over the image.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkinPreview = {}

SkinPreview.DefaultImage = "rbxassetid://97111421088356"
SkinPreview.ViewName = "SkinRigView"
-- The portrait: in front of the torso, level with the collar, looking back at it.
SkinPreview.CameraOffset = { Up = 0.8, Back = 6.5, FieldOfView = 30 }

function SkinPreview.Thumbnail(assetId)
	local id = tonumber(assetId)
	if not id or id <= 0 then
		return SkinPreview.DefaultImage
	end
	return "rbxthumb://type=Asset&id=" .. tostring(id) .. "&w=420&h=420"
end

function SkinPreview.FindRig(name)
	local folder = ReplicatedStorage:FindFirstChild("SkinRigs")
	local rig = folder and folder:FindFirstChild(tostring(name or ""))
	if rig and rig:IsA("Model") then
		return rig
	end
	return nil
end

-- The portrait camera for a rig: `CFrame.new(0, Up, -Back)` in the torso's frame is in
-- front of it (an R6 torso faces -Z), turned half round to look back at the chest.
function SkinPreview.CameraFor(torsoFrame)
	local offset = SkinPreview.CameraOffset
	return torsoFrame * CFrame.new(0, offset.Up, -offset.Back) * CFrame.Angles(0, math.pi, 0), offset.FieldOfView
end

-- Shows `skin` ({ PreviewRig?, PreviewAssetId? }, or nil for none) on `image`.
function SkinPreview.Apply(image, skin)
	local current = image:FindFirstChild(SkinPreview.ViewName)
	local rigName = skin and skin.PreviewRig
	local rig = rigName and SkinPreview.FindRig(rigName)
	local torso = rig and rig:FindFirstChild("Torso")
	if not rig or not torso or not torso:IsA("BasePart") then
		if current then
			current:Destroy()
		end
		image.Image = SkinPreview.Thumbnail(skin and skin.PreviewAssetId)
		return false
	end
	image.Image = ""
	if current and current:GetAttribute("Rig") == rigName then
		return true
	end
	if current then
		current:Destroy()
	end

	local view = Instance.new("ViewportFrame")
	view.Name = SkinPreview.ViewName
	view.BackgroundTransparency = 1
	view.AnchorPoint = Vector2.new(0.5, 0.5)
	view.Position = UDim2.fromScale(0.5, 0.5)
	view.Size = UDim2.fromScale(1, 1)
	view.ZIndex = image.ZIndex
	view.Ambient = Color3.fromRGB(190, 190, 200)
	view.LightColor = Color3.fromRGB(255, 255, 255)
	view.LightDirection = Vector3.new(-0.6, -1, -0.8)
	view:SetAttribute("Rig", rigName)
	local world = Instance.new("WorldModel")
	world.Parent = view
	local copy = rig:Clone()
	copy.Parent = world
	local camera = Instance.new("Camera")
	camera.CFrame, camera.FieldOfView = SkinPreview.CameraFor(copy.Torso.CFrame)
	camera.Parent = view
	view.CurrentCamera = camera
	view.Parent = image
	return true
end

return SkinPreview
