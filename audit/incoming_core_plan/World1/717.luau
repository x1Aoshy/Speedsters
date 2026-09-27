-- Update only the fill inside the Studio-authored track; leave panel layout alone.
local TweenService = game:GetService("TweenService")
local ProgressBar = {}

function ProgressBar.Bind(container)
	local images = {}
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("ImageLabel") then table.insert(images, child) end
	end
	table.sort(images, function(a, b)
		return a.Size.X.Scale > b.Size.X.Scale
	end)
	local fill = container:FindFirstChild("Fill") or container:FindFirstChild("ProgressFill")
	if not fill then
		for _, image in ipairs(images) do
			if image:FindFirstChildOfClass("UIGradient") then fill = image; break end
		end
	end
	fill = fill or images[2]
	local track = container:FindFirstChild("Track")
	if not track then
		for _, image in ipairs(images) do
			if image ~= fill then track = image; break end
		end
	end
	if not fill and track then
		fill = track:Clone()
		fill.Name = "ProgressFill"
		fill.Parent = container
	end
	local text = container:FindFirstChild("Exp") or container:FindFirstChildOfClass("TextLabel")
	local tween
	if track and fill then
		-- A fixed aspect ratio shrinks the fill's height when its width changes.
		for _, child in ipairs(fill:GetChildren()) do
			if child:IsA("UIAspectRatioConstraint") or child:IsA("UISizeConstraint") then child:Destroy() end
		end
		-- The authored texture has white pixels and a white opaque backing.
		-- Keep an opaque gradient fill over a dark track, with only a subtle texture.
		track.BackgroundTransparency = 0
		track.BackgroundColor3 = Color3.fromRGB(18, 40, 24)
		track.ImageColor3 = Color3.fromRGB(60, 100, 65)
		track.ImageTransparency = 0.85
		fill.BackgroundTransparency = 0
		fill.ImageTransparency = 0.85
		fill.ZIndex = math.max(fill.ZIndex, track.ZIndex + 1)
		if text then text.ZIndex = math.max(text.ZIndex, fill.ZIndex + 1) end
	end
	return function(ratio, caption)
		if text then text.Text = caption end
		if not track or not fill then return end
		if tween then tween:Cancel() end
		local size, position, anchor = track.Size, track.Position, track.AnchorPoint
		fill.AnchorPoint = Vector2.new(0, anchor.Y)
		fill.Position = UDim2.new(position.X.Scale - size.X.Scale * anchor.X,
			position.X.Offset - size.X.Offset * anchor.X, position.Y.Scale, position.Y.Offset)
		ratio = math.clamp(ratio, 0, 1)
		fill.Visible = ratio > 0
		tween = TweenService:Create(fill, TweenInfo.new(0.2), {
			Size = UDim2.new(size.X.Scale * ratio, size.X.Offset * ratio, size.Y.Scale, size.Y.Offset),
		})
		tween:Play()
	end
end

return ProgressBar
