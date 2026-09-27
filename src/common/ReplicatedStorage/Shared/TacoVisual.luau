-- Built from native geometry: visible even when external mesh assets cannot load.
local TacoVisual = {}
local assets = script.Parent:FindFirstChild("TacoEventAssets")
local template = assets and assets:FindFirstChild("Taco")
local meshFailed = false
if template and game:GetService("RunService"):IsClient() then
	task.spawn(function()
		local ok = pcall(function()
			game:GetService("ContentProvider"):PreloadAsync({template}, function(_, status)
				if status ~= Enum.AssetFetchStatus.Success then meshFailed = true end
			end)
		end)
		if not ok then meshFailed = true end
	end)
end

local function nativeGeometry(root, scale)
	root.Transparency = 1
	local function piece(name, size, offset, color, shape)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size * scale
		part.CFrame = root.CFrame * (CFrame.new(offset.Position * scale) * offset.Rotation)
		part.Color = color
		part.Shape = shape or Enum.PartType.Block
		part.Material = Enum.Material.SmoothPlastic
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CastShadow = false
		part.Parent = root
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = root, part
		weld.Parent = part
	end
	-- Two filled semicircular shell faces, open along the top for the filling.
	for _, side in {-1, 1} do
		for i = -2, 2 do
			local x = i * 0.46
			local height = math.sqrt(1.25 ^ 2 - x ^ 2)
			piece("GoldenShell", Vector3.new(0.49, height, 0.16),
				CFrame.new(x, 0.45 - height / 2, side * 0.38), Color3.fromRGB(245, 181, 49))
		end
	end
	piece("Filling", Vector3.new(2.1, 0.45, 0.72), CFrame.new(0, 0.25, 0), Color3.fromRGB(111, 55, 28), Enum.PartType.Ball)
	for i = -1, 1 do
		piece("Lettuce", Vector3.new(0.85, 0.32, 0.86), CFrame.new(i * 0.65, 0.48, 0), Color3.fromRGB(92, 190, 49), Enum.PartType.Ball)
		piece("Tomato", Vector3.new(0.3, 0.28, 0.32), CFrame.new(i * 0.62, 0.68, 0.08), Color3.fromRGB(240, 66, 43))
	end
	return root
end

function TacoVisual.Decorate(root, scale)
	root:SetAttribute("TacoVisualScale", scale)
	root.Transparency = 1
	if not template or meshFailed then return nativeGeometry(root, scale) end
	local mesh = template:Clone()
	mesh.Name = "OriginalTaco"
	mesh.Size = mesh.Size * (2.5 * scale / math.max(mesh.Size.X, mesh.Size.Y, mesh.Size.Z))
	mesh.CFrame = root.CFrame
	mesh.Anchored = false
	mesh.CanCollide, mesh.CanTouch, mesh.CanQuery = false, false, false
	mesh.Massless = true
	mesh.Parent = root
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = root, mesh
	weld.Parent = mesh
	return root
end

function TacoVisual.EnsureVisible(root)
	local mesh = root:FindFirstChild("OriginalTaco")
	if meshFailed and mesh then
		mesh:Destroy()
		nativeGeometry(root, root:GetAttribute("TacoVisualScale") or 1)
	end
end

return TacoVisual
