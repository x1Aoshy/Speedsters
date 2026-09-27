local StudUi = {}

local STUD_TEXTURE_IMAGE = "rbxassetid://6927295847"
local STUD_TILE_SIZE = UDim2.fromOffset(100, 100)

local function addCorner(instance, radius)
	local corner = instance:FindFirstChildOfClass("UICorner")

	if not corner then
		corner = Instance.new("UICorner")
		corner.Parent = instance
	end

	corner.CornerRadius = UDim.new(0, radius)
	return corner
end

                                                                          
                                                                              
function StudUi.AddSurface(parent, zIndex, cornerRadius, columns, rows)
	local oldSurface = parent:FindFirstChild("UIStudSurface")

	if oldSurface then
		oldSurface:Destroy()
	end

	parent.ClipsDescendants = true

	local texture = Instance.new("ImageLabel")
	texture.Name = "UIStudSurface"
	texture.BackgroundColor3 = parent.BackgroundColor3
	texture.BackgroundTransparency = parent.BackgroundTransparency
	texture.BorderSizePixel = 0
	texture.Position = UDim2.fromOffset(0, 0)
	texture.Size = UDim2.fromScale(1, 1)
	texture.Image = STUD_TEXTURE_IMAGE
	texture.ImageColor3 = Color3.fromRGB(255, 255, 255)
	texture.ImageTransparency = 0
	texture.ScaleType = Enum.ScaleType.Tile
	local function syncTileSize()
		if columns and rows then
			columns = math.max(1, math.floor(tonumber(columns) or 1))
			rows = math.max(1, math.floor(tonumber(rows) or 1))

			                                  
			                                                                             
			                                                                           
			                                                                            
			                                                                        
			                                                                         
			                                                                           
			                                       
			                                                                         
			local studsPerSourceTile = 3.75
			texture.TileSize = UDim2.fromScale(
				studsPerSourceTile / columns,
				studsPerSourceTile / rows
			)
		else
			texture.TileSize = STUD_TILE_SIZE
		end
	end
	syncTileSize()

	texture.Active = false
	texture.Selectable = false
	texture.ZIndex = zIndex or (parent.ZIndex + 1)
	texture.Parent = parent
	addCorner(texture, cornerRadius or 10)

	local gradient = Instance.new("UIGradient")
	gradient.Name = "StudSurfaceGradient"
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.52, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(248, 248, 248)),
	})
	gradient.Rotation = -90
	gradient.Parent = texture

	local function syncSurfaceColor()
		if texture.Parent then
			texture.BackgroundColor3 = parent.BackgroundColor3
			texture.BackgroundTransparency = parent.BackgroundTransparency
		end
	end

	parent:GetPropertyChangedSignal("BackgroundColor3"):Connect(syncSurfaceColor)
	parent:GetPropertyChangedSignal("BackgroundTransparency"):Connect(syncSurfaceColor)

	return texture
end

                                                                             
                                                                             
function StudUi.StyleButton(button, cornerRadius)
	-- ImageButtons have no text properties; only style TextButtons like this.
	-- (Setting button.Font on an ImageButton raises "Font is not a valid member".)
	local isTextButton = button:IsA("TextButton")

	if isTextButton then
		button.Font = Enum.Font.FredokaOne
	end

	local texture = StudUi.AddSurface(button, button.ZIndex + 1, cornerRadius)
	local oldText = button:FindFirstChild("ButtonText")

	if oldText then
		oldText:Destroy()
	end

	local label = Instance.new("TextLabel")
	label.Name = "ButtonText"
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 1)
	label.Active = false
	label.Selectable = false
	label.ZIndex = button.ZIndex + 2
	label.Parent = button

	local outline = Instance.new("UIStroke")
	outline.Name = "TextOutline"
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	outline.Color = Color3.fromRGB(0, 0, 0)
	outline.LineJoinMode = Enum.LineJoinMode.Round
	outline.Parent = label

	local function syncText()
		if not label.Parent then
			return
		end

		if not isTextButton then
			return
		end

		label.Font = button.Font
		label.Text = button.Text
		label.TextColor3 = button.TextColor3
		label.TextSize = button.TextSize
		label.TextScaled = button.TextScaled
		label.TextWrapped = button.TextWrapped
		label.TextXAlignment = button.TextXAlignment
		label.TextYAlignment = button.TextYAlignment
		outline.Thickness = math.clamp(math.floor((button.TextSize or 16) * 0.11), 2, 4)
	end

	syncText()
	if isTextButton then
		button.TextTransparency = 1
		button.TextStrokeTransparency = 1
	end

	for _, property in ipairs({
		"Font",
		"Text",
		"TextColor3",
		"TextSize",
		"TextScaled",
		"TextWrapped",
		"TextXAlignment",
		"TextYAlignment",
	}) do
		if isTextButton then
			button:GetPropertyChangedSignal(property):Connect(syncText)
		end
	end

	return texture, label
end

return StudUi
